import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

import '../folio_cloud/folio_cloud_callable.dart';

/// Envío HTTP a webhooks de Slack/Teams. En Web usa el proxy callable para evitar CORS.
class IntegrationWebhookTransport {
  IntegrationWebhookTransport({http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  static const Duration _httpTimeout = Duration(seconds: 30);

  final http.Client _http;

  Future<void> postJson({
    required String provider,
    required String webhookUrl,
    required Map<String, Object?> payload,
  }) async {
    if (kIsWeb) {
      await callFolioHttpsCallable('folioIntegrationWebhookProxy', {
        'provider': provider,
        'webhookUrl': webhookUrl,
        'payload': payload,
      });
      return;
    }

    final uri = Uri.parse(webhookUrl);
    final resp = await _http
        .post(
          uri,
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        )
        .timeout(_httpTimeout);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw IntegrationWebhookTransportException(
        'post failed',
        statusCode: resp.statusCode,
        body: resp.body,
        uri: uri.toString(),
      );
    }
  }
}

class IntegrationWebhookTransportException implements Exception {
  const IntegrationWebhookTransportException(
    this.message, {
    this.statusCode,
    this.body,
    this.uri,
  });

  final String message;
  final int? statusCode;
  final String? body;
  final String? uri;

  @override
  String toString() {
    final code = statusCode;
    final u = (uri ?? '').trim().isEmpty ? '' : ' ${uri!.trim()}';
    final b = (body ?? '').trim().isEmpty ? '' : ' | body=${body!.trim()}';
    return 'IntegrationWebhookTransportException($code): $message$u$b';
  }
}
