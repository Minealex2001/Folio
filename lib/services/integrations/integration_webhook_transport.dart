import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

import '../folio_cloud/folio_cloud_callable.dart';

import '../../services/folio_cloud/folio_cloud_exception.dart';
/// Envío HTTP a webhooks de Slack/Teams. En Web usa el proxy callable para evitar CORS.
class IntegrationWebhookTransport {
  IntegrationWebhookTransport({http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  static const Duration _httpTimeout = Duration(seconds: 30);

  final http.Client _http;

  /// Registra la conexión en el backend: antes solo se registraba en Web (para
  /// poder relayarla vía [postJson] y evitar CORS — folioIntegrationWebhookProxy
  /// no acepta una webhookUrl arbitraria del cliente, solo un connectionId ya
  /// registrado por su dueño). Ahora se registra en toda plataforma porque el
  /// outbox de notificaciones salientes del backend (entrega durable,
  /// sobrevive el cierre de la app) también necesita resolver el connectionId
  /// del lado del servidor — ver `OutboundNotificationOutboxService`.
  Future<void> registerConnection({
    required String provider,
    required String connectionId,
    required String webhookUrl,
  }) async {
    await callFolioHttpsCallable('folioUpsertIntegrationWebhookConnection', {
      'provider': provider,
      'connectionId': connectionId,
      'webhookUrl': webhookUrl,
    });
  }

  Future<void> postJson({
    required String provider,
    required String connectionId,
    required String webhookUrl,
    required Map<String, Object?> payload,
  }) async {
    if (kIsWeb) {
      try {
        await callFolioHttpsCallable('folioIntegrationWebhookProxy', {
          'provider': provider,
          'connectionId': connectionId,
          'payload': payload,
        });
      } on FolioCloudException catch (e) {
        // Connections created before the server-side registration step
        // existed won't be found yet — register once (self-healing) and
        // retry, instead of permanently breaking pre-existing connections.
        if (e.code.toLowerCase() != 'not-found') rethrow;
        await registerConnection(
          provider: provider,
          connectionId: connectionId,
          webhookUrl: webhookUrl,
        );
        await callFolioHttpsCallable('folioIntegrationWebhookProxy', {
          'provider': provider,
          'connectionId': connectionId,
          'payload': payload,
        });
      }
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
