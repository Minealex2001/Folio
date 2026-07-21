import '../../models/slack_integration_state.dart';
import '../integrations/integration_api_exception.dart';
import '../integrations/integration_webhook_transport.dart';

class SlackApiException extends IntegrationApiException {
  const SlackApiException(
    super.message, {
    super.statusCode,
    super.body,
    super.uri,
    super.method,
  });

  @override
  String get exceptionName => 'SlackApiException';
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

  /// Registra esta conexión server-side (requerido en Web antes de poder
  /// relayar mensajes vía folioIntegrationWebhookProxy).
  Future<void> registerConnection() => _transport.registerConnection(
        provider: 'slack',
        connectionId: _connection.id,
        webhookUrl: _connection.webhookUrl,
      );

  /// Publica [text] en el canal vinculado a la Incoming Webhook URL.
  Future<void> postMessage(String text) async {
    try {
      await _transport.postJson(
        provider: 'slack',
        connectionId: _connection.id,
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

  /// Registra la conexión (si aplica) y verifica que la URL de webhook es
  /// válida enviando un mensaje de prueba.
  Future<void> verifyConnection({required String testMessage}) async {
    await registerConnection();
    await postMessage(testMessage);
  }
}
