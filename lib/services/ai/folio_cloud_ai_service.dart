import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../folio_cloud/folio_cloud_callable.dart';
import '../folio_cloud/folio_cloud_entitlements.dart';
import 'ai_service.dart';
import 'ai_types.dart';

/// Error legible tras [FolioCloudAiService.complete].
class FolioCloudAiException implements Exception {
  FolioCloudAiException(this.message, {this.functionsCode});
  final String message;
  final String? functionsCode;
  @override
  String toString() => message;

  bool get isInkExhausted => functionsCode == 'resource-exhausted';
}

bool _looksLikeUpstreamLlmRejection(String d) {
  final l = d.toLowerCase();
  return l.contains('upstreampowerup') ||
      l.contains('upstream') && l.contains('powerup') ||
      l.contains('ink/tags') ||
      l.contains('403 forbidden') ||
      l.contains('incorrect api key') ||
      l.contains('invalid_api_key') ||
      l.contains('rate limit') ||
      l.contains('rate_limit') ||
      (l.contains('401') && l.contains('unauthorized')) ||
      (l.contains('403') && l.contains('quota'));
}

String _upstreamLlmVsFolioInkMessage() {
  return 'Quill Cloud rechazó la petición por clave, cuota, facturación o modelo en el '
      'servidor; no es el mismo límite que las gotas Folio del panel. Quien opera el '
      'backend debe revisar la configuración de inferencia de Quill Cloud y los límites '
      'del proveedor. Si el saldo de gotas parece imposible (p. ej. millones), revisa '
      'el campo ink en Firestore para tu usuario.';
}

String _mapFolioCloudAiError(FirebaseFunctionsException e) {
  final code = e.code;
  final details = (e.message ?? '').trim();
  switch (code) {
    case 'unauthenticated':
      return 'Inicia sesión en Folio Cloud (cuenta en la nube en Ajustes).';
    case 'permission-denied':
      return details.isNotEmpty
          ? details
          : 'La IA en la nube requiere suscripción Folio Cloud con IA en la nube o tinta comprada. '
              'Revisa Ajustes → Folio Cloud.';
    case 'resource-exhausted':
      return details.isNotEmpty
          ? details
          : 'No quedan gotas de tinta suficientes. Compra un tintero, espera la recarga mensual si tienes suscripción activa o usa IA local.';
    case 'unavailable':
      return details.isNotEmpty
          ? details
          : 'El servicio de IA en la nube no está disponible temporalmente. Reintenta en unos segundos.';
    case 'invalid-argument':
      return details.isNotEmpty ? details : 'Petición inválida.';
    case 'failed-precondition':
      if (_looksLikeUpstreamLlmRejection(details)) {
        return _upstreamLlmVsFolioInkMessage();
      }
      return details.isNotEmpty ? details : 'No se puede completar la acción.';
    case 'internal':
      if (_looksLikeUpstreamLlmRejection(details)) {
        return _upstreamLlmVsFolioInkMessage();
      }
      if (details.isNotEmpty) return details;
      return 'Error del servicio IA ($code).';
    default:
      if (details.isNotEmpty) return details;
      return 'Error del servicio IA ($code).';
  }
}

/// Hosted AI via Cloud Functions (keys stay on server). Requires Folio Cloud
/// subscription with cloud AI, or purchased ink without subscription.
///
/// Cuando la petición trae `systemPrompt`/`messages`/`responseSchema`/`tools`
/// (turnos con historial o del bucle de tool-calling), se envían estructurados
/// tal cual a la Cloud Function, que a su vez los reenvía a la API de OpenAI
/// sin diferencia funcional con `openai_compatible_ai_service.dart`. Solo el
/// modo "simple" sin nada de eso aplana el historial en texto plano vía
/// [_mergePrompt] (compatibilidad con llamadas antiguas sin turno estructurado).
/// No se envían adjuntos de archivo/imagen a la nube (limitación existente,
/// no introducida por el tool-calling).
class FolioCloudAiService implements AiService {
  FolioCloudAiService({FolioCloudEntitlementsController? entitlements})
      : _entitlements = entitlements;

  final FolioCloudEntitlementsController? _entitlements;

  @override
  String get providerName => 'folio_cloud';

  // La Cloud Function `folioCloudAiComplete` (functions/src/index.ts) reenvía
  // `tools`/`toolChoice` tal cual a la API de chat completions de OpenAI y
  // devuelve `toolCalls` ya parseadas — mismo nivel de soporte que el
  // proveedor OpenAI-compatible local, no una emulación de segunda categoría.
  @override
  bool get supportsNativeToolCalling => true;

  // TODO(quill-tools): streaming real requiere un transporte distinto al de
  // una Cloud Function `onCall` (que devuelve una única respuesta, no SSE) —
  // deliberadamente fuera de alcance de la paridad de tool-calling. De
  // momento emite el resultado completo como un único chunk final.
  @override
  Stream<AiCompletionChunk> completeStream(AiCompletionRequest request) async* {
    final result = await complete(request);
    yield AiCompletionChunk(
      textDelta: result.text,
      isFinal: true,
      usage: result.usage,
      toolCalls: result.toolCalls,
    );
  }

  /// El turno actual del usuario ya va dentro de [AiCompletionRequest.prompt] (p. ej.
  /// «Mensaje del usuario:» en el agente o guía + mensaje en chat); no duplicar el último
  /// `[user]` al aplanar el hilo para la nube.
  List<AiChatMessage> _historyForCloudMerge(List<AiChatMessage> messages) {
    if (messages.isEmpty) return messages;
    if (messages.last.role != 'user') return messages;
    if (messages.length == 1) return const [];
    return messages.sublist(0, messages.length - 1);
  }

  String _mergePrompt(AiCompletionRequest request) {
    final b = StringBuffer(request.prompt.trim());
    for (final m in _historyForCloudMerge(request.messages)) {
      b.write('\n[${m.role}] ${m.content}');
    }
    return b.toString();
  }

  /// Codifica un mensaje del historial para la Cloud Function, incluyendo
  /// tool-calls del asistente y resultados de tool — mismo formato que
  /// `openai_compatible_ai_service.dart`, porque el backend los reenvía tal
  /// cual a la misma API de OpenAI.
  Map<String, dynamic> _encodeHistoryMessage(AiChatMessage m) {
    if (m.role == 'tool') {
      return {
        'role': 'tool',
        'tool_call_id': m.toolCallId ?? '',
        'content': m.content,
      };
    }
    if (m.role == 'assistant' && m.toolCalls != null && m.toolCalls!.isNotEmpty) {
      return {
        'role': 'assistant',
        'content': m.content,
        'tool_calls': m.toolCalls!
            .map(
              (c) => {
                'id': c.id,
                'function': {'name': c.name, 'arguments': jsonEncode(c.arguments)},
              },
            )
            .toList(),
      };
    }
    return {'role': m.role, 'content': m.content};
  }

  List<AiToolCall>? _parseToolCalls(dynamic raw) {
    if (raw is! List || raw.isEmpty) return null;
    return raw.whereType<Map>().map((entry) {
      final fn = (entry['function'] as Map?) ?? const {};
      Map<String, dynamic> args = const {};
      final rawArgs = fn['arguments'];
      if (rawArgs is String && rawArgs.trim().isNotEmpty) {
        try {
          final decoded = jsonDecode(rawArgs);
          if (decoded is Map) args = Map<String, dynamic>.from(decoded);
        } catch (_) {
          // El modelo devolvió argumentos no-JSON; se deja vacío y el
          // ejecutor del tool decide cómo reaccionar.
        }
      }
      return AiToolCall(
        id: entry['id'] as String? ?? '',
        name: fn['name'] as String? ?? '',
        arguments: args,
      );
    }).toList();
  }

  @override
  Future<AiCompletionResult> complete(AiCompletionRequest request) async {
    if (Firebase.apps.isEmpty) {
      throw StateError('Firebase not initialized');
    }
    try {
      final hasStructured =
          request.messages.isNotEmpty ||
          (request.systemPrompt != null &&
              request.systemPrompt!.trim().isNotEmpty) ||
          request.responseSchema != null ||
          request.temperature != null ||
          request.maxTokens != null ||
          request.tools.isNotEmpty;
      final payload = <String, dynamic>{
        'prompt': (hasStructured ? request.prompt.trim() : _mergePrompt(request)),
        'operationKind': request.cloudInkOperation ?? 'default',
        if (request.systemPrompt != null && request.systemPrompt!.trim().isNotEmpty)
          'systemPrompt': request.systemPrompt!.trim(),
        if (request.messages.isNotEmpty)
          'messages': request.messages.map(_encodeHistoryMessage).toList(),
        if (request.responseSchema != null) 'responseSchema': request.responseSchema,
        if (request.temperature != null) 'temperature': request.temperature,
        if (request.maxTokens != null) 'maxTokens': request.maxTokens,
        if (request.tools.isNotEmpty) ...{
          'tools': request.tools.map((t) => t.toJsonSchema()).toList(),
          'toolChoice': request.toolChoice ?? 'auto',
        },
      };
      final res = await callFolioHttpsCallable(
        'folioCloudAiComplete',
        payload,
      );
      final raw = res;
      final text = raw is Map ? '${raw['text'] ?? ''}' : '';
      final toolCalls = raw is Map ? _parseToolCalls(raw['toolCalls']) : null;
      final inkRaw = raw is Map ? raw['ink'] : null;
      final ent = _entitlements;
      if (inkRaw is Map && ent != null) {
        final monthly = (inkRaw['monthlyBalance'] as num?)?.toInt();
        final purchased = (inkRaw['purchasedBalance'] as num?)?.toInt();
        if (monthly != null && purchased != null && monthly >= 0 && purchased >= 0) {
          ent.applyInkBalancesFromCloudAi(
            monthlyBalance: monthly,
            purchasedBalance: purchased,
          );
        }
      }
      return AiCompletionResult(
        text: text.trim(),
        provider: providerName,
        model: request.model,
        toolCalls: toolCalls,
      );
    } on FirebaseFunctionsException catch (e) {
      throw FolioCloudAiException(
        _mapFolioCloudAiError(e),
        functionsCode: e.code,
      );
    } catch (e) {
      if (e is StateError) rethrow;
      throw FolioCloudAiException(
        _mapFolioCloudAiError(
          FirebaseFunctionsException(
            message: e.toString(),
            code: 'unavailable',
          ),
        ),
        functionsCode: 'unavailable',
      );
    }
  }

  @override
  Future<void> ping() async {
    if (Firebase.apps.isEmpty) throw StateError('Firebase not initialized');
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('Inicia sesión en la cuenta Folio Cloud (Ajustes).');
    }
    await user.getIdToken();
  }

  @override
  Future<List<String>> listModels() async => const ['folio-cloud'];
}
