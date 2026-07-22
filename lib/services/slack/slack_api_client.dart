import 'dart:convert';

import 'package:http/http.dart' as http;

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

/// Cliente Slack: Bot API (`chat.postMessage`) si hay token; si no, Incoming Webhook.
class SlackApiClient {
  SlackApiClient({
    required SlackConnection connection,
    IntegrationWebhookTransport? transport,
    http.Client? httpClient,
  })  : _transport = transport ?? IntegrationWebhookTransport(),
        _connection = connection,
        _http = httpClient ?? http.Client();

  final IntegrationWebhookTransport _transport;
  final SlackConnection _connection;
  final http.Client _http;

  SlackConnection get connection => _connection;

  Future<void> registerConnection() async {
    if (!_connection.hasWebhook) return;
    await _transport.registerConnection(
      provider: 'slack',
      connectionId: _connection.id,
      webhookUrl: _connection.webhookUrl,
    );
  }

  Future<void> postMessage(String text) async {
    if (_connection.hasBotToken && _connection.channelId.trim().isNotEmpty) {
      await _postViaBotApi(text);
      return;
    }
    if (!_connection.hasWebhook) {
      throw const SlackApiException(
        'Slack connection has neither webhook nor bot channel',
      );
    }
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

  Future<void> _postViaBotApi(String text) async {
    final uri = Uri.parse('https://slack.com/api/chat.postMessage');
    final res = await _http.post(
      uri,
      headers: {
        'Authorization': 'Bearer ${_connection.accessToken}',
        'Content-Type': 'application/json; charset=utf-8',
      },
      body: jsonEncode({
        'channel': _connection.channelId,
        'text': text,
      }),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw SlackApiException(
        'chat.postMessage HTTP ${res.statusCode}',
        statusCode: res.statusCode,
        body: res.body,
        uri: uri.toString(),
        method: 'POST',
      );
    }
    final decoded = jsonDecode(res.body);
    if (decoded is Map && decoded['ok'] != true) {
      throw SlackApiException(
        'chat.postMessage denied: ${decoded['error']}',
        statusCode: res.statusCode,
        body: res.body,
        uri: uri.toString(),
        method: 'POST',
      );
    }
  }

  Future<void> verifyConnection({required String testMessage}) async {
    await registerConnection();
    await postMessage(testMessage);
  }
}
