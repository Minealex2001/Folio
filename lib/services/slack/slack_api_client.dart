import '../../models/slack_integration_state.dart';
import '../integrations/integration_webhook_transport.dart';

class SlackApiException implements Exception {
  const SlackApiException(
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
    return 'SlackApiException($code): $m$message$u$b';
  }
}

/// Cliente delgado sobre la Incoming Webhook URL de un canal de Slack
/// (Fase 1: sin OAuth ni bot token; ver `docs`/plan para fases futuras).
class SlackApiClient {
  SlackApiClient({
    required SlackConnection connection,
    IntegrationWebhookTransport? transport,
  })  : _transport = transport ?? IntegrationWebhookTransport(),
        _connection = connection;

  final IntegrationWebhookTransport _transport;
  final SlackConnection _connection;

  SlackConnection get connection => _connection;

  /// Publica [text] en el canal vinculado a la Incoming Webhook URL.
  Future<void> postMessage(String text) async {
    try {
      await _transport.postJson(
        provider: 'slack',
        webhookUrl: _connection.webhookUrl,
        payload: {'text': text},
      );
    } on IntegrationWebhookTransportException catch (e) {
      throw SlackApiException(
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
