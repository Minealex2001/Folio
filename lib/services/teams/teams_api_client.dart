import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../models/teams_integration_state.dart';
import '../integrations/integration_api_exception.dart';
import '../integrations/integration_webhook_transport.dart';

class TeamsApiException extends IntegrationApiException {
  const TeamsApiException(
    super.message, {
    super.statusCode,
    super.body,
    super.uri,
    super.method,
  });

  @override
  String get exceptionName => 'TeamsApiException';
}

/// Cliente Teams: Graph channel message si hay token+ids; si no, webhook Workflow.
class TeamsApiClient {
  TeamsApiClient({
    required TeamsConnection connection,
    IntegrationWebhookTransport? transport,
    http.Client? httpClient,
  })  : _transport = transport ?? IntegrationWebhookTransport(),
        _connection = connection,
        _http = httpClient ?? http.Client();

  final IntegrationWebhookTransport _transport;
  final TeamsConnection _connection;
  final http.Client _http;

  TeamsConnection get connection => _connection;

  Future<void> registerConnection() async {
    if (!_connection.hasWebhook) return;
    await _transport.registerConnection(
      provider: 'teams',
      connectionId: _connection.id,
      webhookUrl: _connection.webhookUrl,
    );
  }

  Future<void> postMessage(String text) async {
    if (_connection.hasGraphToken &&
        _connection.teamId.trim().isNotEmpty &&
        _connection.channelId.trim().isNotEmpty) {
      await _postViaGraph(text);
      return;
    }
    if (!_connection.hasWebhook) {
      throw const TeamsApiException(
        'Teams connection has neither webhook nor Graph channel',
      );
    }
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
        connectionId: _connection.id,
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

  Future<void> _postViaGraph(String text) async {
    final uri = Uri.parse(
      'https://graph.microsoft.com/v1.0/teams/${_connection.teamId}'
      '/channels/${_connection.channelId}/messages',
    );
    final res = await _http.post(
      uri,
      headers: {
        'Authorization': 'Bearer ${_connection.accessToken}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'body': {'contentType': 'text', 'content': text},
      }),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw TeamsApiException(
        'Graph channel message HTTP ${res.statusCode}',
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
