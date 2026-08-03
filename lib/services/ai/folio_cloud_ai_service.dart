import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config/folio_backend_config.dart';
import '../folio_cloud/folio_cloud_callable.dart';
import '../folio_cloud/folio_cloud_entitlements.dart';
import '../folio_cloud/folio_cloud_http_client.dart';
import 'ai_service.dart';
import 'ai_types.dart';

import '../../services/folio_cloud/folio_cloud_exception.dart';
import '../../services/folio_cloud/folio_cloud_identity.dart';
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

String _mapFolioCloudAiError(FolioCloudException e) {
  final code = e.code;
  final details = e.message.trim();
  switch (code) {
    case 'unauthenticated':
      return 'Inicia sesión en Folio Cloud (cuenta en la nube en Ajustes).';
    case 'permission-denied':
      return details.isNotEmpty
          ? details
          : 'Quill Cloud requiere suscripción Folio Cloud con Quill Cloud o tinta comprada. '
              'Revisa Ajustes → Folio Cloud.';
    case 'resource-exhausted':
      return details.isNotEmpty
          ? details
          : 'No quedan gotas de tinta suficientes. Compra un tintero, espera la recarga mensual si tienes suscripción activa o usa Quill en local.';
    case 'unavailable':
      return details.isNotEmpty
          ? details
          : 'El servicio de Quill Cloud no está disponible temporalmente. Reintenta en unos segundos.';
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
      return 'Error del servicio Quill ($code).';
    default:
      if (details.isNotEmpty) return details;
      return 'Error del servicio Quill ($code).';
  }
}

/// Normaliza respuestas HTTP del backend (p. ej. Spring Security 401 sin
/// `status: unauthenticated`) a un código que [_mapFolioCloudAiError] entiende.
({String code, String message}) _normalizeCloudAiHttpFailure({
  required int statusCode,
  required String message,
  required String code,
}) {
  final msg = message.trim().isEmpty ? 'HTTP $statusCode' : message.trim();
  final lower = '${msg.toLowerCase()} $code';
  if (statusCode == 401 ||
      lower.contains('unauthenticated') ||
      lower.contains('unauthorized') ||
      RegExp(r'\b401\b').hasMatch(msg)) {
    return (code: 'unauthenticated', message: msg);
  }
  if (statusCode == 403 || lower.contains('permission-denied')) {
    return (code: 'permission-denied', message: msg);
  }
  if (statusCode == 429 || lower.contains('resource-exhausted')) {
    return (code: 'resource-exhausted', message: msg);
  }
  return (code: code, message: msg);
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

  /// Streaming real vía SSE (`POST /api/v1/ai/complete-stream`) — antes esto
  /// emitía un único chunk final porque el transporte era una Cloud Function
  /// `onCall` (respuesta única, sin SSE); con el backend Spring de larga
  /// duración ya no aplica esa limitación.
  ///
  /// Ante HTTP 401 reintenta una vez con [folioCloudBearerToken] `forceRefresh`
  /// (mismo patrón que [callFolioHttpsCallable]): la UI puede seguir “con
  /// sesión” mientras el access JWT ha caducado.
  @override
  Stream<AiCompletionChunk> completeStream(AiCompletionRequest request) async* {
    if (!folioCloudHasSession()) {
      throw StateError('Not signed in');
    }

    final uri = Uri.parse('${FolioBackendConfig.apiV1Prefix}/ai/complete-stream');
    final payload = jsonEncode(_buildCompletePayload(request));

    http.StreamedResponse? resp;
    Object? lastSendError;
    for (var attempt = 0; attempt < 2; attempt++) {
      final token = await folioCloudBearerToken(forceRefresh: attempt > 0);
      if (token == null || token.isEmpty) {
        throw StateError('Not signed in');
      }

      final httpReq = http.Request('POST', uri)
        ..headers['Authorization'] = 'Bearer $token'
        ..headers['Content-Type'] = 'application/json; charset=utf-8'
        ..headers['Accept'] = 'text/event-stream'
        ..body = payload;

      try {
        resp = await folioCloudHttpClient.send(httpReq);
      } catch (e) {
        lastSendError = e;
        resp = null;
        break;
      }

      if (resp.statusCode == 401 && attempt == 0) {
        // Descarta el cuerpo para liberar la conexión antes del reintento.
        await resp.stream.drain<void>();
        continue;
      }
      break;
    }

    if (resp == null) {
      throw FolioCloudAiException(
        _mapFolioCloudAiError(
          FolioCloudException(
            message: '${lastSendError ?? 'unavailable'}',
            code: 'unavailable',
          ),
        ),
        functionsCode: 'unavailable',
      );
    }

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      final body = await resp.stream.bytesToString();
      String message = 'HTTP ${resp.statusCode}';
      String code = 'unavailable';
      try {
        final decoded = jsonDecode(body);
        if (decoded is Map) {
          message = '${decoded['message'] ?? decoded['error'] ?? message}';
          final status = decoded['status'] ?? decoded['error'];
          if (status != null) {
            code = '$status'.toLowerCase().replaceAll('_', '-');
          }
        }
      } catch (_) {}
      final normalized = _normalizeCloudAiHttpFailure(
        statusCode: resp.statusCode,
        message: message,
        code: code,
      );
      throw FolioCloudAiException(
        _mapFolioCloudAiError(
          FolioCloudException(
            message: normalized.message,
            code: normalized.code,
          ),
        ),
        functionsCode: normalized.code,
      );
    }

    String? currentEvent;
    final lines =
        resp.stream.transform(utf8.decoder).transform(const LineSplitter());
    await for (final line in lines) {
      if (line.isEmpty) {
        currentEvent = null;
        continue;
      }
      if (line.startsWith('event:')) {
        currentEvent = line.substring(6).trim();
        continue;
      }
      if (!line.startsWith('data:')) continue;
      final dataStr = line.substring(5).trim();
      if (dataStr.isEmpty) continue;
      final obj = jsonDecode(dataStr);
      if (currentEvent == 'delta') {
        final delta = obj is Map ? '${obj['textDelta'] ?? ''}' : '';
        if (delta.isNotEmpty) {
          yield AiCompletionChunk(textDelta: delta);
        }
      } else if (currentEvent == 'done') {
        final toolCalls = obj is Map ? _parseToolCalls(obj['toolCalls']) : null;
        final inkRaw = obj is Map ? obj['ink'] : null;
        final ent = _entitlements;
        if (inkRaw is Map && ent != null) {
          final monthly = (inkRaw['monthlyBalance'] as num?)?.toInt();
          final purchased = (inkRaw['purchasedBalance'] as num?)?.toInt();
          if (monthly != null &&
              purchased != null &&
              monthly >= 0 &&
              purchased >= 0) {
            ent.applyInkBalancesFromCloudAi(
              monthlyBalance: monthly,
              purchasedBalance: purchased,
            );
          }
        }
        yield AiCompletionChunk(isFinal: true, toolCalls: toolCalls);
      }
    }
  }

  Map<String, dynamic> _buildCompletePayload(AiCompletionRequest request) {
    final hasStructured =
        request.messages.isNotEmpty ||
        (request.systemPrompt != null &&
            request.systemPrompt!.trim().isNotEmpty) ||
        request.responseSchema != null ||
        request.temperature != null ||
        request.maxTokens != null ||
        request.tools.isNotEmpty;
    return <String, dynamic>{
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
    if (!folioCloudHasSession()) { throw StateError('Not signed in'); }
    try {
      final res = await callFolioHttpsCallable(
        'folioCloudAiComplete',
        _buildCompletePayload(request),
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
    } on FolioCloudException catch (e) {
      throw FolioCloudAiException(
        _mapFolioCloudAiError(e),
        functionsCode: e.code,
      );
    } catch (e) {
      if (e is StateError) rethrow;
      throw FolioCloudAiException(
        _mapFolioCloudAiError(
          FolioCloudException(
            message: e.toString(),
            code: 'unavailable',
          ),
        ),
        functionsCode: 'unavailable',
      );
    }
  }

  @override
  bool get supportsImageGeneration => true;

  @override
  Future<AiImageGenerationResult> generateImage({
    required String prompt,
    String? pageContextText,
  }) async {
    if (!folioCloudHasSession()) { throw StateError('Not signed in'); }
    try {
      final payload = <String, dynamic>{
        'prompt': prompt.trim(),
        if (pageContextText != null && pageContextText.trim().isNotEmpty)
          'pageContextText': pageContextText.trim(),
        'operationKind': 'generate_image',
      };
      final res = await callFolioHttpsCallable('folioCloudGenerateImage', payload);
      final raw = res;
      final b64 = raw is Map ? '${raw['imageBase64'] ?? ''}' : '';
      if (b64.isEmpty) {
        throw StateError('El servicio de IA devolvió una respuesta de imagen vacía');
      }
      final mimeType = raw is Map ? '${raw['mimeType'] ?? 'image/png'}' : 'image/png';
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
      return AiImageGenerationResult(bytes: base64Decode(b64), mimeType: mimeType);
    } on FolioCloudException catch (e) {
      throw FolioCloudAiException(
        _mapFolioCloudAiError(e),
        functionsCode: e.code,
      );
    } catch (e) {
      if (e is StateError) rethrow;
      throw FolioCloudAiException(
        _mapFolioCloudAiError(
          FolioCloudException(
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
    if (!folioCloudHasSession()) throw StateError('Not signed in');
    final uid = folioCloudCurrentUid();
    if (uid == null || uid.isEmpty) {
      throw StateError('Inicia sesión en la cuenta Folio Cloud (Ajustes).');
    }
    final token = await folioCloudBearerToken();
    if (token == null || token.isEmpty) {
      throw StateError('Inicia sesión en la cuenta Folio Cloud (Ajustes).');
    }
  }

  @override
  Future<List<String>> listModels() async => const ['folio-cloud'];
}
