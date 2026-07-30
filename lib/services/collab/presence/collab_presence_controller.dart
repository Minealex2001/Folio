import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../collab_stomp_transport.dart';

/// Snapshot de un peer remoto visto en la sala (cursor/selección + metadata).
@immutable
class CollabPeerPresence {
  const CollabPeerPresence({
    required this.uid,
    required this.clientId,
    required this.displayName,
    required this.lastSeenMs,
    this.pageId,
    this.blockId,
    this.offset,
    this.selectionEndBlockId,
    this.selectionEndOffset,
    this.color,
  });

  final String uid;
  final String clientId;
  final String displayName;
  final int lastSeenMs;
  final String? pageId;
  final String? blockId;
  final int? offset;
  final String? selectionEndBlockId;
  final int? selectionEndOffset;
  final String? color;
}

/// Presencia y cursores en vivo para una sala de colaboración.
///
/// Es puramente efímera y cosmética: no hay persistencia server-side ni
/// cifrado E2E (a diferencia del contenido de la página). La limpieza de
/// peers "fantasma" es responsabilidad de este controlador vía TTL — cada
/// peer expira si no llega un heartbeat en [peerTtl], porque una
/// desconexión abrupta (proceso matado por el SO, dispositivo en sueño
/// profundo) no siempre llega a notificar `presence.leave` al servidor.
class CollabPresenceController extends ChangeNotifier {
  CollabPresenceController({
    required CollabStompTransport transport,
    required String? Function() localUidProvider,
    required String? Function() localDisplayNameProvider,
    Duration heartbeatInterval = const Duration(seconds: 8),
    Duration peerTtl = const Duration(seconds: 20),
    Duration cursorThrottle = const Duration(milliseconds: 130),
  }) : _transport = transport,
       _localUidProvider = localUidProvider,
       _localDisplayNameProvider = localDisplayNameProvider,
       _heartbeatInterval = heartbeatInterval,
       _peerTtl = peerTtl,
       _cursorThrottle = cursorThrottle;

  final CollabStompTransport _transport;
  final String? Function() _localUidProvider;
  final String? Function() _localDisplayNameProvider;
  final Duration _heartbeatInterval;
  final Duration _peerTtl;
  final Duration _cursorThrottle;
  final String _clientId = _generateClientId();

  String? _roomId;
  Timer? _heartbeatTimer;
  Timer? _ttlTimer;
  Timer? _throttleTimer;

  String? _pageId;
  String? _blockId;
  int? _offset;
  String? _selectionEndBlockId;
  int? _selectionEndOffset;

  final Map<String, CollabPeerPresence> _peersByClientId = {};

  List<CollabPeerPresence> get peers =>
      List.unmodifiable(_peersByClientId.values);

  List<CollabPeerPresence> peersOnPage(String pageId) =>
      peers.where((p) => p.pageId == pageId).toList(growable: false);

  bool get isAttached => _roomId != null;

  /// Empieza a emitir heartbeats de presencia para [roomId] y a limpiar peers
  /// vencidos periódicamente. Llamar tras conectar el STOMP transport.
  void attach(String roomId) {
    if (_roomId == roomId) return;
    detach();
    _roomId = roomId;
    _broadcastNow();
    _heartbeatTimer = Timer.periodic(
      _heartbeatInterval,
      (_) => _broadcastNow(),
    );
    _ttlTimer = Timer.periodic(const Duration(seconds: 5), (_) => _evictStale());
  }

  void detach() {
    final roomId = _roomId;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _ttlTimer?.cancel();
    _ttlTimer = null;
    _throttleTimer?.cancel();
    _throttleTimer = null;
    if (roomId != null) {
      _transport.sendPresenceLeave(roomId, {'clientId': _clientId});
    }
    _roomId = null;
    _pageId = null;
    _blockId = null;
    _offset = null;
    _selectionEndBlockId = null;
    _selectionEndOffset = null;
    if (_peersByClientId.isNotEmpty) {
      _peersByClientId.clear();
      notifyListeners();
    }
  }

  /// Actualiza la posición local de cursor/selección y programa un broadcast
  /// (con throttle para no saturar el canal en movimientos rápidos).
  void updateLocalCursor({
    String? pageId,
    String? blockId,
    int? offset,
    String? selectionEndBlockId,
    int? selectionEndOffset,
  }) {
    _pageId = pageId;
    _blockId = blockId;
    _offset = offset;
    _selectionEndBlockId = selectionEndBlockId;
    _selectionEndOffset = selectionEndOffset;
    if (_throttleTimer?.isActive ?? false) return;
    _throttleTimer = Timer(_cursorThrottle, _broadcastNow);
  }

  void _broadcastNow() {
    final roomId = _roomId;
    if (roomId == null) return;
    _transport.sendPresenceUpdate(roomId, {
      'displayName': _localDisplayNameProvider() ?? '',
      'clientId': _clientId,
      'pageId': _pageId,
      'blockId': _blockId,
      'offset': _offset,
      'selectionEndBlockId': _selectionEndBlockId,
      'selectionEndOffset': _selectionEndOffset,
    });
  }

  /// Procesa un mensaje entrante de `/topic/collab/{roomId}/presence`.
  void handleIncoming(Map<String, dynamic> json) {
    final clientId = '${json['clientId'] ?? ''}';
    if (clientId.isEmpty || clientId == _clientId) {
      return; // eco del propio broadcast (el servidor retransmite a todos los suscriptores).
    }
    final type = '${json['type'] ?? ''}';
    if (type == 'presence.leave') {
      if (_peersByClientId.remove(clientId) != null) notifyListeners();
      return;
    }
    if (type != 'presence.update') return;
    final uid = '${json['uid'] ?? ''}';
    if (uid.isEmpty || uid == _localUidProvider()) return;
    _peersByClientId[clientId] = CollabPeerPresence(
      uid: uid,
      clientId: clientId,
      displayName: '${json['displayName'] ?? ''}',
      pageId: json['pageId'] as String?,
      blockId: json['blockId'] as String?,
      offset: (json['offset'] as num?)?.toInt(),
      selectionEndBlockId: json['selectionEndBlockId'] as String?,
      selectionEndOffset: (json['selectionEndOffset'] as num?)?.toInt(),
      color: json['color'] as String?,
      lastSeenMs:
          (json['ts'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch,
    );
    notifyListeners();
  }

  void _evictStale() {
    final cutoff =
        DateTime.now().millisecondsSinceEpoch - _peerTtl.inMilliseconds;
    final before = _peersByClientId.length;
    _peersByClientId.removeWhere((_, p) => p.lastSeenMs < cutoff);
    if (_peersByClientId.length != before) notifyListeners();
  }

  @override
  void dispose() {
    detach();
    super.dispose();
  }

  static final Random _rng = Random();

  static String _generateClientId() =>
      List.generate(16, (_) => _rng.nextInt(16).toRadixString(16)).join();
}
