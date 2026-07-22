import '../../models/discord_integration_state.dart';
import '../integrations/integration_api_exception.dart';
import '../integrations/integration_webhook_transport.dart';

class DiscordApiException extends IntegrationApiException {
  const DiscordApiException(
    super.message, {
    super.statusCode,
    super.body,
    super.uri,
    super.method,
  });

  @override
  String get exceptionName => 'DiscordApiException';
}

/// Cliente Incoming Webhook de Discord (mismo molde que Slack Fase 1).
class DiscordApiClient {
  DiscordApiClient({
    required DiscordConnection connection,
    IntegrationWebhookTransport? transport,
  })  : _transport = transport ?? IntegrationWebhookTransport(),
        _connection = connection;

  final IntegrationWebhookTransport _transport;
  final DiscordConnection _connection;

  DiscordConnection get connection => _connection;

  Future<void> registerConnection() => _transport.registerConnection(
        provider: 'discord',
        connectionId: _connection.id,
        webhookUrl: _connection.webhookUrl,
      );

  Future<void> postMessage(String text) async {
    try {
      await _transport.postJson(
        provider: 'discord',
        connectionId: _connection.id,
        webhookUrl: _connection.webhookUrl,
        payload: {'content': text},
      );
    } on IntegrationWebhookTransportException catch (e) {
      throw DiscordApiException(
        e.message,
        statusCode: e.statusCode,
        body: e.body,
        uri: e.uri,
        method: 'POST',
      );
    }
  }

  Future<void> verifyConnection({required String testMessage}) async {
    await registerConnection();
    await postMessage(testMessage);
  }
}
