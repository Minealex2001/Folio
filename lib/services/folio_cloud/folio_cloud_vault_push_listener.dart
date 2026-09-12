import 'dart:async';
import 'dart:convert';

import 'package:stomp_dart_client/stomp_dart_client.dart';

import '../../config/folio_backend_config.dart';
import '../app_logger.dart';
import 'folio_cloud_identity.dart';

/// Escucha `/user/queue/vault-events` — push del backend tras un
/// `finalize` de device-sync/backup/profile — para disparar un refresco de
/// meta remota sin esperar al próximo tick del poll.
///
/// Reutiliza el mismo endpoint STOMP que la colaboración (`/ws/collab`, ver
/// `CollabStompAuthInterceptor`) en vez de uno nuevo: Spring solo admite un
/// `@EnableWebSocketMessageBroker` en toda la app, y un segundo endpoint
/// hermano compartiría igualmente el canal de entrada — más simple y sin
/// riesgo añadir el destino nuevo al canal ya existente.
///
/// Es puramente un disparador adicional: el poll existente en
/// `FolioCloudDeviceSyncController` sigue activo como respaldo ante huecos de
/// reconexión (app suspendida, red inestable), con cadencia reducida.
class FolioCloudVaultPushListener {
  FolioCloudVaultPushListener({
    required void Function(Map<String, dynamic> payload) onVaultEvent,
  }) : _onVaultEvent = onVaultEvent;

  final void Function(Map<String, dynamic> payload) _onVaultEvent;
  StompClient? _client;
  bool _active = false;

  Future<void> connect() async {
    if (_active) return;
    if (!folioCloudHasSession()) return;
    final token = await folioCloudBearerToken();
    if (token == null || token.isEmpty) return;
    _active = true;

    _client = StompClient(
      config: StompConfig(
        url: FolioBackendConfig.collabWsUrl,
        stompConnectHeaders: {
          'Authorization': 'Bearer $token',
          'token': token,
        },
        reconnectDelay: const Duration(seconds: 10),
        connectionTimeout: const Duration(seconds: 12),
        heartbeatIncoming: const Duration(seconds: 10),
        heartbeatOutgoing: const Duration(seconds: 10),
        onConnect: (frame) {
          if (!_active) return;
          _client?.subscribe(
            destination: '/user/queue/vault-events',
            callback: (frame) {
              if (!_active) return;
              final body = frame.body;
              Map<String, dynamic> payload = const {};
              if (body != null && body.isNotEmpty) {
                try {
                  final decoded = jsonDecode(body);
                  if (decoded is Map) {
                    payload = Map<String, dynamic>.from(decoded);
                  }
                } catch (_) {}
              }
              _onVaultEvent(payload);
            },
          );
        },
        onWebSocketError: (error) {
          AppLogger.debug(
            'vault push listener ws error',
            tag: 'cloud_sync',
            context: {'error': '$error'},
          );
        },
        onStompError: (frame) {
          AppLogger.debug(
            'vault push listener stomp error',
            tag: 'cloud_sync',
            context: {'message': frame.body ?? frame.headers['message'] ?? ''},
          );
        },
      ),
    );
    _client!.activate();
  }

  Future<void> disconnect() async {
    _active = false;
    final client = _client;
    _client = null;
    if (client != null) {
      try {
        client.deactivate();
      } catch (_) {}
    }
  }
}
