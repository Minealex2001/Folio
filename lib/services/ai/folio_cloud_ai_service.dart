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

/// Por encima de esto, el JSON de `ink` en la respuesta se considera corrupto y no
/// se aplica al controlador (evita mostrar millones de gotas por datos erróneos).
const int _kMaxPlausibleInkTotalFromCallable = 500000;

bool _looksLikeUpstreamLlmRejection(String d) {
  final l = d.toLowerCase();
  return l.contains('upstreampowerup') ||
      l.contains('upstream') && l.contains('powerup') ||
      l.contains('ink/tags') ||
      l.contains('403 forbidden') ||
      l.contains('openai.com') ||
      l.contains('incorrect api key') ||
      l.contains('invalid_api_key') ||
      l.contains('rate limit') ||
      l.contains('rate_limit') ||
      (l.contains('401') && l.contains('unauthorized')) ||
      (l.contains('403') && l.contains('quota'));
}

String _upstreamLlmVsFolioInkMessage() {
  return 'El proveedor de IA en la nube (OpenAI) rechazó la petición por clave, cuota, '
      'facturación o modelo en el servidor; no es el mismo límite que las gotas Folio del '
      'panel. Quien despliega Functions debe revisar OPENAI_API_KEY y límites en '
      'platform.openai.com. Si el saldo de gotas parece imposible (p. ej. millones), '
      'revisa el campo ink en Firestore para tu usuario.';
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
          : 'Folio Cloud requiere suscripción activa e IA en la nube en tu plan. '
              'Revisa Ajustes → Folio Cloud.';
    case 'resource-exhausted':
      return 'No quedan gotas de tinta suficientes. Compra un tintero o espera la recarga mensual.';
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

/// Hosted AI via Cloud Functions (keys stay on server). Requires Folio Cloud subscription.
///
/// La callable solo recibe texto (`prompt` + `operationKind`): no se envían adjuntos ni
/// historial estructurado; el historial se aplana en [_mergePrompt].
class FolioCloudAiService implements AiService {
  FolioCloudAiService({FolioCloudEntitlementsController? entitlements})
      : _entitlements = entitlements;

  final FolioCloudEntitlementsController? _entitlements;

  @override
  String get providerName => 'folio_cloud';

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
          request.maxTokens != null;
      final payload = <String, dynamic>{
        'prompt': (hasStructured ? request.prompt.trim() : _mergePrompt(request)),
        'operationKind': request.cloudInkOperation ?? 'default',
        if (request.systemPrompt != null && request.systemPrompt!.trim().isNotEmpty)
          'systemPrompt': request.systemPrompt!.trim(),
        if (request.messages.isNotEmpty)
          'messages': request.messages
              .map(
                (m) => <String, dynamic>{
                  'role': m.role,
                  'content': m.content,
                },
              )
              .toList(),
        if (request.responseSchema != null) 'responseSchema': request.responseSchema,
        if (request.temperature != null) 'temperature': request.temperature,
        if (request.maxTokens != null) 'maxTokens': request.maxTokens,
      };
      final res = await callFolioHttpsCallable(
        'folioCloudAiComplete',
        payload,
      );
      final raw = res;
      final text = raw is Map ? '${raw['text'] ?? ''}' : '';
      final inkRaw = raw is Map ? raw['ink'] : null;
      final ent = _entitlements;
      if (inkRaw is Map && ent != null) {
        final monthly = (inkRaw['monthlyBalance'] as num?)?.toInt();
        final purchased = (inkRaw['purchasedBalance'] as num?)?.toInt();
        if (monthly != null &&
            purchased != null &&
            monthly >= 0 &&
            purchased >= 0 &&
            monthly + purchased <= _kMaxPlausibleInkTotalFromCallable) {
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
      );
    } on FirebaseFunctionsException catch (e) {
      throw FolioCloudAiException(
        _mapFolioCloudAiError(e),
        functionsCode: e.code,
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
