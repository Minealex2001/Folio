import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';

import '../../config/folio_backend_config.dart';
import '../app_logger.dart';
import '../folio_cloud/folio_cloud_identity.dart';

typedef CollabStompJsonHandler = void Function(Map<String, dynamic> json);

/// Cliente STOMP hacia `FolioBackendConfig.collabWsUrl` (Spring `/ws/collab`).
///
/// Protocolo:
/// - CONNECT con `Authorization: Bearer <JWT>` (o header `token`)
/// - SUBSCRIBE `/topic/collab/{roomId}` (contenido)
/// - SUBSCRIBE `/topic/collab/{roomId}/presence` (presencia/cursores, efímero)
/// - SUBSCRIBE `/topic/collab/{roomId}/chat` (chat de sala)
/// - SUBSCRIBE `/user/queue/collab-errors`
/// - SEND `/app/collab/{roomId}/update` (JSON CollabRoomUpdateRequest)
/// - SEND `/app/collab/{roomId}/presence` y `/app/collab/{roomId}/presence/leave`
/// - SEND `/app/collab/{roomId}/chat`
///
/// Presencia usa un topic separado del de contenido (no un switch por `type`
/// sobre el mismo topic) porque tiene un ciclo de vida distinto: efímero,
/// sin escritura en DB, y con su propio throttle. Ver plan de colaboración.
class CollabStompTransport {
  StompClient? _client;
  String? _roomId;
  CollabStompJsonHandler? _onRoomUpdate;
  CollabStompJsonHandler? _onPresence;
  CollabStompJsonHandler? _onChat;
  CollabStompJsonHandler? _onError;
  VoidCallback? _onConnected;
  bool _active = false;
  Completer<void>? _connectCompleter;

  bool get isConnected => _client?.connected == true;

  /// Conecta (o reconecta) y suscribe a la sala [roomId].
  Future<void> connect({
    required String roomId,
    required CollabStompJsonHandler onRoomUpdate,
    CollabStompJsonHandler? onPresence,
    CollabStompJsonHandler? onChat,
    CollabStompJsonHandler? onError,
    VoidCallback? onConnected,
  }) async {
    await disconnect();
    _roomId = roomId;
    _onRoomUpdate = onRoomUpdate;
    _onPresence = onPresence;
    _onChat = onChat;
    _onError = onError;
    _onConnected = onConnected;
    _active = true;

    final token = await folioCloudBearerToken();
    if (token == null || token.isEmpty) {
      throw StateError('not_signed_in');
    }

    final completer = Completer<void>();
    _connectCompleter = completer;

    final url = FolioBackendConfig.collabWsUrl;
    AppLogger.info(
      'collab stomp connect',
      tag: 'collab',
      context: {'url': url, 'roomId': roomId},
    );

    _client = StompClient(
      config: StompConfig(
        url: url,
        stompConnectHeaders: {
          'Authorization': 'Bearer $token',
          'token': token,
        },
        reconnectDelay: const Duration(seconds: 5),
        connectionTimeout: const Duration(seconds: 12),
        heartbeatIncoming: const Duration(seconds: 10),
        heartbeatOutgoing: const Duration(seconds: 10),
        beforeConnect: () async {
          if (!_active) return;
          final fresh = await folioCloudBearerToken();
          if (fresh == null || fresh.isEmpty) {
            throw StateError('not_signed_in');
          }
          // beforeConnect no muta headers del config ya creado; el cliente
          // reutiliza stompConnectHeaders. Refresco vía reconnect tras 401.
        },
        onConnect: _onStompConnect,
        onDisconnect: (frame) {
          AppLogger.info('collab stomp disconnect', tag: 'collab');
        },
        onStompError: (frame) {
          final msg = frame.body ?? frame.headers['message'] ?? 'stomp_error';
          AppLogger.warn(
            'collab stomp error',
            tag: 'collab',
            context: {'message': msg},
          );
          _onError?.call({'error': 'stomp_error', 'message': msg});
          _failConnect(StateError(msg));
        },
        onWebSocketError: (error) {
          final errMsg = '$error';
          AppLogger.warn(
            'collab ws error',
            tag: 'collab',
            context: {'error': errMsg},
          );
          _onError?.call({'error': 'ws_error', 'message': errMsg});
          _failConnect(error is Object ? error : StateError(errMsg));
        },
        onDebugMessage: (msg) {
          if (kDebugMode) {
            AppLogger.info(
              'collab stomp debug',
              tag: 'collab',
              context: {'msg': msg},
            );
          }
        },
      ),
    );

    _client!.activate();
    await completer.future.timeout(
      const Duration(seconds: 15),
      onTimeout: () {
        throw TimeoutException('collab_stomp_connect_timeout');
      },
    );
  }

  void _onStompConnect(StompFrame frame) {
    final client = _client;
    final roomId = _roomId;
    if (client == null || roomId == null || !_active) return;

    client.subscribe(
      destination: '/topic/collab/$roomId',
      callback: (frame) {
        final map = _parseJson(frame.body);
        if (map == null) return;
        _onRoomUpdate?.call(map);
      },
    );
    client.subscribe(
      destination: '/topic/collab/$roomId/presence',
      callback: (frame) {
        final map = _parseJson(frame.body);
        if (map == null) return;
        _onPresence?.call(map);
      },
    );
    client.subscribe(
      destination: '/topic/collab/$roomId/chat',
      callback: (frame) {
        final map = _parseJson(frame.body);
        if (map == null) return;
        _onChat?.call(map);
      },
    );
    client.subscribe(
      destination: '/user/queue/collab-errors',
      callback: (frame) {
        final map = _parseJson(frame.body);
        if (map == null) return;
        _onError?.call(map);
      },
    );

    AppLogger.info(
      'collab stomp subscribed',
      tag: 'collab',
      context: {'roomId': roomId},
    );
    _onConnected?.call();
    final c = _connectCompleter;
    if (c != null && !c.isCompleted) {
      c.complete();
    }
  }

  void _failConnect(Object error) {
    final c = _connectCompleter;
    if (c != null && !c.isCompleted) {
      c.completeError(error);
    }
  }

  /// SEND update de contenido (E2E seal / content).
  void sendRoomUpdate(String roomId, Map<String, dynamic> body) {
    final client = _client;
    if (client == null || !client.connected) {
      throw StateError('stomp_not_connected');
    }
    client.send(
      destination: '/app/collab/$roomId/update',
      body: jsonEncode(body),
      headers: const {'content-type': 'application/json'},
    );
  }

  /// SEND mensaje de chat (contentCipher ya cifrado E2E por el llamador).
  void sendChatMessage(String roomId, String contentCipher) {
    final client = _client;
    if (client == null || !client.connected) {
      throw StateError('stomp_not_connected');
    }
    client.send(
      destination: '/app/collab/$roomId/chat',
      body: jsonEncode({'contentCipher': contentCipher}),
      headers: const {'content-type': 'application/json'},
    );
  }

  /// SEND heartbeat/actualización de presencia y cursor (sin cifrar, efímero).
  void sendPresenceUpdate(String roomId, Map<String, dynamic> body) {
    final client = _client;
    if (client == null || !client.connected) return;
    client.send(
      destination: '/app/collab/$roomId/presence',
      body: jsonEncode(body),
      headers: const {'content-type': 'application/json'},
    );
  }

  /// SEND anuncio explícito de salida de presencia (cierre limpio de la vista).
  void sendPresenceLeave(String roomId, Map<String, dynamic> body) {
    final client = _client;
    if (client == null || !client.connected) return;
    client.send(
      destination: '/app/collab/$roomId/presence/leave',
      body: jsonEncode(body),
      headers: const {'content-type': 'application/json'},
    );
  }

  Future<void> disconnect() async {
    _active = false;
    final client = _client;
    _client = null;
    _roomId = null;
    _onRoomUpdate = null;
    _onPresence = null;
    _onChat = null;
    _onError = null;
    _onConnected = null;
    final c = _connectCompleter;
    _connectCompleter = null;
    if (c != null && !c.isCompleted) {
      c.completeError(StateError('stomp_disconnected'));
    }
    if (client != null) {
      try {
        client.deactivate();
      } catch (_) {}
    }
  }

  static Map<String, dynamic>? _parseJson(String? body) {
    if (body == null || body.isEmpty) return null;
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) {
        return decoded.map((k, v) => MapEntry('$k', v));
      }
    } catch (_) {}
    return null;
  }
}
