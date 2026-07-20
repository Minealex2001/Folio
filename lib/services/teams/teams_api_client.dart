import '../../models/teams_integration_state.dart';
import '../integrations/integration_webhook_transport.dart';

class TeamsApiException implements Exception {
  const TeamsApiException(
    this.message, {
    this.statusCode,
    this.body,
    this.uri,
    this.method,
  });
  final String message;
  final int? statusCode;
  final String? body;
  final String? uri;
  final String? method;

  @override
  String toString() {
    final code = statusCode;
    final m = (method ?? '').trim().isEmpty ? '' : '${method!.trim()} ';
    final u = (uri ?? '').trim().isEmpty ? '' : ' ${uri!.trim()}';
    final b = (body ?? '').trim().isEmpty ? '' : ' | body=${body!.trim()}';
    return 'TeamsApiException($code): $m$message$u$b';
  }
}

/// Cliente delgado sobre la URL de webhook de un Workflow de Teams ("Post to
/// a channel when a webhook request is received" — el reemplazo actual del
/// conector O365 ya retirado). Fase 1: sin OAuth ni Graph API; ver el plan
/// para fases futuras.
class TeamsApiClient {
  TeamsApiClient({
    required TeamsConnection connection,
    IntegrationWebhookTransport? transport,
  })  : _transport = transport ?? IntegrationWebhookTransport(),
        _connection = connection;

  final IntegrationWebhookTransport _transport;
  final TeamsConnection _connection;

  TeamsConnection get connection => _connection;

  /// Publica [text] en el canal vinculado, como una Adaptive Card mínima
  /// (formato requerido por los webhooks de Workflows de Teams).
  Future<void> postMessage(String text) async {
    final payload = <String, Object?>{
      'type': 'message',
      'attachments': [
        {
          'contentType': 'application/vnd.microsoft.card.adaptive',
          'content': {
            r'$schema': 'http://adaptivecards.io/schemas/adaptive-card.json',
            'type': 'AdaptiveCard',
            'version': '1.4',
            'body': [
              {'type': 'TextBlock', 'text': text, 'wrap': true},
            ],
          },
        },
      ],
    };
    try {
      await _transport.postJson(
        provider: 'teams',
        webhookUrl: _connection.webhookUrl,
        payload: payload,
      );
    } on IntegrationWebhookTransportException catch (e) {
      throw TeamsApiException(
        e.message,
        statusCode: e.statusCode,
        body: e.body,
        uri: e.uri,
        method: 'POST',
      );
    }
  }

  /// Verifica que la URL de webhook es válida enviando un mensaje de prueba.
  Future<void> verifyConnection({required String testMessage}) =>
      postMessage(testMessage);
}
