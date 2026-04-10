import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/app_settings.dart';
import '../platform/android_multicast_lock.dart';
import 'device_sync_models.dart';

class _PendingPairAck {
  _PendingPairAck({
    required this.requestNonce,
    required this.remoteDeviceName,
    required this.alsoToHost,
  }) : completer = Completer<bool>();

  final String requestNonce;
  final String remoteDeviceName;
  final InternetAddress? alsoToHost;
  final Completer<bool> completer;
  Timer? retryTimer;
  bool localConfirmed = false;
  bool remoteConfirmed = false;
}

class DeviceSyncController extends ChangeNotifier {
  DeviceSyncController({
    required AppSettings appSettings,
    void Function(String message)? onEvent,
    void Function(IncomingPairRequest request)? onIncomingPairRequest,
    Future<List<int>?> Function()? onExportSnapshot,
    Future<bool> Function(List<int> snapshot, String fromPeerId)?
    onImportSnapshot,
  }) : _settings = appSettings,
       _onEvent = onEvent,
       _onIncomingPairRequest = onIncomingPairRequest,
       _onExportSnapshot = onExportSnapshot,
       _onImportSnapshot = onImportSnapshot;

  final AppSettings _settings;
  final void Function(String message)? _onEvent;
  final void Function(IncomingPairRequest request)? _onIncomingPairRequest;
  final Future<List<int>?> Function()? _onExportSnapshot;
  final Future<bool> Function(List<int> snapshot, String fromPeerId)?
  _onImportSnapshot;
  final Random _random = Random.secure();
  static const String _pairedPeersKey = 'folio_device_sync_paired_peers_v1';
  static const int _discoveryPort = 45839;
  static const int _syncStreamPort = 45840;
  static const Duration _helloInterval = Duration(seconds: 4);
  static const Duration _discoveryStaleAfter = Duration(seconds: 18);
  static const Duration _pairRequestRetryInterval = Duration(milliseconds: 400);
  static const Duration _pairAcceptBurstGap = Duration(milliseconds: 120);
  static const Duration _snapshotPullMinInterval = Duration(seconds: 20);
  static const Duration _reconcileInterval = Duration(seconds: 10);
  static final InternetAddress _multicastGroup = InternetAddress(
    '239.255.42.99',
  );

  final List<SyncPeer> _peers = <SyncPeer>[];
  final Map<String, SyncPeer> _discoveredById = <String, SyncPeer>{};
  final Map<String, _PendingPairAck> _pendingPairAcks =
      <String, _PendingPairAck>{};
  final Map<String, InternetAddress> _peerLastUdpHost =
      <String, InternetAddress>{};
  final Map<String, int> _lastSnapshotPullByPeer = <String, int>{};
  final Set<String> _pendingSnapshotPushPeers = <String>{};
  IncomingPairRequest? _incomingPairRequest;
  InternetAddress? _incomingPairReplyHost;
  IncomingPairRequest? _acceptedIncomingPairRequest;
  InternetAddress? _acceptedIncomingPairReplyHost;
  bool _incomingRequesterConfirmed = false;
  bool _acceptedIncomingRequesterConfirmed = false;
  final Set<InternetAddress> _broadcastTargets = <InternetAddress>{
    InternetAddress('255.255.255.255'),
    _multicastGroup,
  };
  Timer? _discoveryPulse;
  Timer? _pendingPushRetryPulse;
  Timer? _reconcilePulse;
  Timer? _helloTimer;
  RawDatagramSocket? _udp;
  ServerSocket? _syncServer;
  SyncControllerState _state = SyncControllerState.stopped;
  SyncPairingCode? _activePairingCode;
  bool _restartingUdp = false;

  SyncControllerState get state => _state;
  SyncPairingCode? get activePairingCode => _activePairingCode;
  IncomingPairRequest? get incomingPairRequest => _incomingPairRequest;
  bool get isPairingModeActive =>
      _activePairingCode != null && !_activePairingCode!.isExpired;
  List<SyncPeer> get peers => List.unmodifiable(_peers);
  List<SyncPeer> get discoveredPeers {
    final now = DateTime.now().millisecondsSinceEpoch;
    final maxAge = _discoveryStaleAfter.inMilliseconds;
    final list =
        _discoveredById.values
            .where(
              (peer) =>
                  now - peer.lastSeenAtMs <= maxAge &&
                  !_peers.any((paired) => paired.peerId == peer.peerId),
            )
            .toList(growable: false)
          ..sort((a, b) => b.lastSeenAtMs.compareTo(a.lastSeenAtMs));
    return list;
  }

  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_pairedPeersKey);
      if (raw == null || raw.trim().isEmpty) {
        _peers.clear();
        notifyListeners();
        return;
      }
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      final parsed = decoded
          .whereType<Map>()
          .map(SyncPeer.fromJson)
          .where((peer) => peer.peerId.isNotEmpty)
          .toList();
      _peers
        ..clear()
        ..addAll(parsed);
      notifyListeners();
    } catch (_) {
      // Si falla la lectura no interrumpimos el arranque.
    }
  }

  Future<void> start() async {
    if (_state != SyncControllerState.stopped) return;
    _state = SyncControllerState.searching;
    notifyListeners();
    await AndroidMulticastLock.acquire();
    final discoveryOk = await _startUdpDiscovery();
    if (!discoveryOk) {
      _tearDownUdpStack();
      await AndroidMulticastLock.release();
      notifyListeners();
      return;
    }
    await _startSnapshotServer();
    _ensureDiscoveryPulse();
    notifyListeners();
    _onEvent?.call(
      _localized('Sincronizacion activada.', 'Device sync enabled.'),
    );
  }

  void _tearDownUdpStack() {
    _discoveryPulse?.cancel();
    _discoveryPulse = null;
    _pendingPushRetryPulse?.cancel();
    _pendingPushRetryPulse = null;
    _reconcilePulse?.cancel();
    _reconcilePulse = null;
    _helloTimer?.cancel();
    _helloTimer = null;
    _udp?.close();
    _udp = null;
    _syncServer?.close();
    _syncServer = null;
    _broadcastTargets
      ..clear()
      ..add(InternetAddress('255.255.255.255'))
      ..add(_multicastGroup);
    _discoveredById.clear();
    _peerLastUdpHost.clear();
    _lastSnapshotPullByPeer.clear();
    _pendingSnapshotPushPeers.clear();
    _incomingPairRequest = null;
    _incomingPairReplyHost = null;
    _acceptedIncomingPairRequest = null;
    _acceptedIncomingPairReplyHost = null;
    _incomingRequesterConfirmed = false;
    _acceptedIncomingRequesterConfirmed = false;
    _activePairingCode = null;
    _state = SyncControllerState.stopped;
  }

  Future<void> stop() async {
    _tearDownUdpStack();
    await AndroidMulticastLock.release();
    notifyListeners();
  }

  void refreshSettingsSnapshot() {
    if (!_settings.syncEnabled && _state != SyncControllerState.stopped) {
      unawaited(stop());
      return;
    }
    if (_settings.syncEnabled && _state == SyncControllerState.stopped) {
      unawaited(start());
      return;
    }
    notifyListeners();
  }

  SyncPairingCode generatePairingCode({
    Duration ttl = const Duration(minutes: 2),
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final code = _generateToken(10);
    final pairing = SyncPairingCode(
      code: code,
      expiresAtMs: now + ttl.inMilliseconds,
    );
    _activePairingCode = pairing;
    _broadcastHello();
    notifyListeners();
    return pairing;
  }

  List<String> sharedPairingEmojisForPeer(SyncPeer peer) {
    final localCode = _activePairingCode;
    final remoteCode = (peer.pairingCode ?? '').trim();
    if (localCode == null || localCode.isExpired || remoteCode.isEmpty) {
      return const <String>[];
    }
    return _buildSharedPairingEmojis(localCode.code, remoteCode);
  }

  /// Respuesta del usuario al diálogo de solicitud entrante (desde la UI).
  Future<void> respondIncomingPair(bool accept) async {
    final req = _incomingPairRequest;
    final replyHost = _incomingPairReplyHost;
    if (req == null) return;
    _incomingPairRequest = null;
    _incomingPairReplyHost = null;
    notifyListeners();

    final requesterId = req.requesterId;
    final displayName = req.trimmedRequesterName.isEmpty
        ? _localized('Dispositivo Folio', 'Folio device')
        : req.trimmedRequesterName;

    if (!accept) {
      _incomingRequesterConfirmed = false;
      _emitPairAccept(
        toDeviceId: requesterId,
        approved: false,
        requestNonce: req.requestNonce,
        alsoToHost: replyHost,
      );
      return;
    }

    final activeCode = _activePairingCode;
    if (activeCode == null ||
        activeCode.isExpired ||
        activeCode.code != req.pairingCode) {
      _incomingRequesterConfirmed = false;
      _emitPairAccept(
        toDeviceId: requesterId,
        approved: false,
        requestNonce: req.requestNonce,
        alsoToHost: replyHost,
      );
      _onEvent?.call(
        _localized(
          'El codigo de vinculacion expiro o ya no coincide.',
          'The link code expired or no longer matches.',
        ),
      );
      return;
    }

    _emitPairAcceptBurst(
      toDeviceId: requesterId,
      approved: true,
      requestNonce: req.requestNonce,
      alsoToHost: replyHost,
    );
    _acceptedIncomingPairRequest = req;
    _acceptedIncomingPairReplyHost = replyHost;
    _acceptedIncomingRequesterConfirmed = _incomingRequesterConfirmed;
    _incomingRequesterConfirmed = false;
    if (_acceptedIncomingRequesterConfirmed) {
      await _finalizeIncomingAcceptedPair(req, replyHost);
    }
  }

  Future<bool> submitPairingCode(
    String code, {
    String? remoteDeviceName,
    String? peerId,
  }) async {
    final input = code.trim();
    if (input.length < 6) return false;
    final now = DateTime.now().millisecondsSinceEpoch;
    SyncPeer match;
    final targetPeerId = (peerId ?? '').trim();
    if (targetPeerId.isNotEmpty) {
      final targetedPeer = _discoveredById[targetPeerId];
      final isFresh =
          targetedPeer != null &&
          now - targetedPeer.lastSeenAtMs <=
              _discoveryStaleAfter.inMilliseconds;
      match = isFresh
          ? targetedPeer
          : const SyncPeer(
              peerId: '',
              deviceName: '',
              lastSeenAtMs: 0,
              paired: false,
              source: SyncPeerDiscoverySource.manualCode,
            );
    } else {
      match = _discoveredById.values.firstWhere(
        (peer) =>
            (peer.pairingCode ?? '').trim() == input &&
            now - peer.lastSeenAtMs <= _discoveryStaleAfter.inMilliseconds,
        orElse: () => const SyncPeer(
          peerId: '',
          deviceName: '',
          lastSeenAtMs: 0,
          paired: false,
          source: SyncPeerDiscoverySource.manualCode,
        ),
      );
    }
    if (match.peerId.isEmpty) {
      return false;
    }
    final unicastTo = _peerLastUdpHost[match.peerId];
    final requestNonce = _generateToken(10);
    final safeName = (remoteDeviceName ?? '').trim().isEmpty
        ? match.deviceName
        : remoteDeviceName!.trim();
    final pendingAck = _PendingPairAck(
      requestNonce: requestNonce,
      remoteDeviceName: safeName,
      alsoToHost: unicastTo,
    );
    _pendingPairAcks[match.peerId] = pendingAck;
    _sendPairRequest(
      targetDeviceId: match.peerId,
      pairingCode: input,
      requestNonce: requestNonce,
      alsoToHost: unicastTo,
    );
    pendingAck.retryTimer = Timer.periodic(_pairRequestRetryInterval, (_) {
      if (pendingAck.completer.isCompleted) return;
      _sendPairRequest(
        targetDeviceId: match.peerId,
        pairingCode: input,
        requestNonce: requestNonce,
        alsoToHost: unicastTo,
      );
    });
    unawaited(_awaitOutgoingPairCompletion(match.peerId, pendingAck));
    return true;
  }

  Future<bool> submitEmojiPairingRequest(SyncPeer peer) async {
    final remoteCode = (peer.pairingCode ?? '').trim();
    final localCode = _activePairingCode;
    if (peer.peerId.trim().isEmpty) return false;
    if (remoteCode.isEmpty || localCode == null || localCode.isExpired) {
      return false;
    }
    return submitPairingCode(
      remoteCode,
      remoteDeviceName: peer.deviceName,
      peerId: peer.peerId,
    );
  }

  Future<void> confirmOutgoingPair(String peerId) async {
    final safePeerId = peerId.trim();
    final pending = _pendingPairAcks[safePeerId];
    if (safePeerId.isEmpty || pending == null) return;
    pending.localConfirmed = true;
    _emitPairConfirmBurst(
      toDeviceId: safePeerId,
      requestNonce: pending.requestNonce,
      alsoToHost: pending.alsoToHost,
    );
    if (pending.remoteConfirmed && !pending.completer.isCompleted) {
      pending.completer.complete(true);
    }
  }

  void cancelOutgoingPair(String peerId) {
    final safePeerId = peerId.trim();
    final pending = _pendingPairAcks.remove(safePeerId);
    pending?.retryTimer?.cancel();
    if (pending != null && !pending.completer.isCompleted) {
      pending.completer.complete(false);
    }
  }

  void _ensureDiscoveryPulse() {
    _discoveryPulse?.cancel();
    _discoveryPulse = Timer.periodic(const Duration(seconds: 8), (_) {
      if (_state == SyncControllerState.stopped) return;
      final now = DateTime.now().millisecondsSinceEpoch;
      var removedAny = false;
      final staleKeys = <String>[];
      for (final entry in _discoveredById.entries) {
        if (now - entry.value.lastSeenAtMs >
            _discoveryStaleAfter.inMilliseconds) {
          staleKeys.add(entry.key);
        }
      }
      for (final key in staleKeys) {
        _discoveredById.remove(key);
        // Conserva la ultima IP conocida para permitir push unicast
        // aunque el anuncio LAN momentaneamente no llegue.
        removedAny = true;
      }
      if (removedAny &&
          _state == SyncControllerState.active &&
          discoveredPeers.isEmpty) {
        _state = SyncControllerState.searching;
      }
      notifyListeners();
    });
    _pendingPushRetryPulse?.cancel();
    _pendingPushRetryPulse = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_state == SyncControllerState.stopped) return;
      if (_pendingSnapshotPushPeers.isEmpty) return;
      for (final peerId in _pendingSnapshotPushPeers.toList(growable: false)) {
        unawaited(_flushPendingSnapshotForPeer(peerId));
      }
    });
    _reconcilePulse?.cancel();
    _reconcilePulse = Timer.periodic(_reconcileInterval, (_) {
      if (_state == SyncControllerState.stopped) return;
      unawaited(_runSyncReconciliationTick());
    });
  }

  Future<void> _runSyncReconciliationTick() async {
    await _refreshBroadcastTargets();
    _broadcastHello();
    if (_peers.isEmpty) return;
    for (final peer in _peers) {
      if (!peer.paired) continue;
      final peerId = peer.peerId;
      if (_pendingSnapshotPushPeers.contains(peerId)) {
        unawaited(_flushPendingSnapshotForPeer(peerId));
        continue;
      }
      if (_peerLastUdpHost.containsKey(peerId)) {
        unawaited(_maybePullSnapshotFromPeer(peerId));
      } else {
        // Trigger para recuperar ruta de red con peers ya vinculados.
        _emitSnapshotPing(toDeviceId: peerId);
      }
    }
  }

  Future<bool> _startUdpDiscovery() async {
    try {
      final socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        _discoveryPort,
        reuseAddress: true,
        reusePort: !Platform.isWindows,
      );
      socket.broadcastEnabled = true;
      socket.multicastLoopback = true;
      _udp = socket;
      await _refreshBroadcastTargets();
      await _joinMulticastGroup(socket);
      socket.listen(_onUdpEvent);
      _helloTimer?.cancel();
      _helloTimer = Timer.periodic(_helloInterval, (_) => _broadcastHello());
      _broadcastHello();
      return true;
    } catch (e) {
      _onEvent?.call(
        _localized(
          'No se pudo iniciar descubrimiento LAN: $e',
          'Could not start LAN discovery: $e',
        ),
      );
      return false;
    }
  }

  Future<void> _refreshBroadcastTargets() async {
    final targets = <InternetAddress>{
      InternetAddress('255.255.255.255'),
      _multicastGroup,
    };
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        includeLinkLocal: false,
        type: InternetAddressType.IPv4,
      );
      for (final iface in interfaces) {
        for (final address in iface.addresses) {
          final raw = address.rawAddress;
          if (raw.length != 4) continue;
          if (raw[0] == 169 && raw[1] == 254) continue;
          final octets = <int>[raw[0], raw[1], raw[2], 255];
          targets.add(InternetAddress(octets.join('.')));
        }
      }
    } catch (_) {
      // Si no podemos enumerar interfaces, seguimos con broadcast global.
    }
    _broadcastTargets
      ..clear()
      ..addAll(targets);
  }

  Future<void> _joinMulticastGroup(RawDatagramSocket socket) async {
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        includeLinkLocal: false,
        type: InternetAddressType.IPv4,
      );
      var joinedAny = false;
      for (final iface in interfaces) {
        try {
          socket.joinMulticast(_multicastGroup, iface);
          joinedAny = true;
        } catch (_) {
          // Algunas interfaces no aceptan multicast; seguimos con las demas.
        }
      }
      if (!joinedAny) {
        socket.joinMulticast(_multicastGroup);
      }
    } catch (_) {
      try {
        socket.joinMulticast(_multicastGroup);
      } catch (_) {
        // Si falla, seguimos con broadcast tradicional.
      }
    }
  }

  void _onUdpEvent(RawSocketEvent event) {
    if (event == RawSocketEvent.closed) {
      unawaited(_restartUdpDiscovery());
      return;
    }
    if (event != RawSocketEvent.read) return;
    final socket = _udp;
    if (socket == null) return;
    Datagram? datagram;
    do {
      datagram = socket.receive();
      if (datagram == null) continue;
      _consumeDatagram(datagram);
    } while (datagram != null);
  }

  Future<void> _restartUdpDiscovery() async {
    if (_restartingUdp || _state == SyncControllerState.stopped) return;
    _restartingUdp = true;
    try {
      _helloTimer?.cancel();
      _helloTimer = null;
      _udp?.close();
      _udp = null;
      final ok = await _startUdpDiscovery();
      if (!ok) {
        _onEvent?.call(
          _localized(
            'Reintentando conectividad LAN de sincronizacion...',
            'Retrying sync LAN connectivity...',
          ),
        );
      }
    } finally {
      _restartingUdp = false;
    }
  }

  void _consumeDatagram(Datagram datagram) {
    try {
      final body = utf8.decode(datagram.data, allowMalformed: true);
      final map = jsonDecode(body);
      if (map is! Map) return;
      final type = (map['type'] as String? ?? '').trim();
      switch (type) {
        case 'folio.sync.hello':
          _consumeHello(map, datagram.address);
          break;
        case 'folio.sync.pair_request':
          unawaited(_consumePairRequest(map, datagram.address));
          break;
        case 'folio.sync.pair_accept':
          _consumePairAccept(map, datagram.address);
          break;
        case 'folio.sync.pair_confirm':
          _consumePairConfirm(map, datagram.address);
          break;
        case 'folio.sync.paired_notice':
          unawaited(_consumePairedNotice(map, datagram.address));
          break;
        case 'folio.sync.snapshot_ping':
          _consumeSnapshotPing(map, datagram.address);
          break;
        default:
          break;
      }
    } catch (_) {
      // Ignora payloads que no pertenezcan al protocolo.
    }
  }

  void _consumeHello(Map map, InternetAddress remoteHost) {
    final deviceId = (map['deviceId'] as String? ?? '').trim();
    if (deviceId.isEmpty || deviceId == _settings.syncDeviceId) return;
    final isHelloReply = map['helloReply'] == true;
    _peerLastUdpHost[deviceId] = remoteHost;
    final deviceName = (map['deviceName'] as String? ?? '').trim();
    final pairingCode = _stringField(map, 'pairingCode');
    final now = DateTime.now().millisecondsSinceEpoch;
    _discoveredById[deviceId] = SyncPeer(
      peerId: deviceId,
      deviceName: deviceName.isEmpty
          ? _localized('Dispositivo Folio', 'Folio device')
          : deviceName,
      lastSeenAtMs: now,
      paired: _peers.any((peer) => peer.peerId == deviceId),
      source: SyncPeerDiscoverySource.localDiscovery,
      pairingCode: pairingCode.isEmpty ? null : pairingCode,
    );
    if (_state == SyncControllerState.searching) {
      _state = SyncControllerState.active;
    }
    if (!isHelloReply) {
      _sendHelloDirect(remoteHost);
    }
    if (_peers.any((p) => p.peerId == deviceId && p.paired)) {
      if (_pendingSnapshotPushPeers.contains(deviceId)) {
        unawaited(_flushPendingSnapshotForPeer(deviceId));
      } else {
        unawaited(_maybePullSnapshotFromPeer(deviceId));
      }
    }
    notifyListeners();
  }

  Future<void> _consumePairRequest(Map map, InternetAddress remoteHost) async {
    final target = (map['targetDeviceId'] as String? ?? '').trim();
    if (target != _settings.syncDeviceId) return;
    final requesterId = (map['requesterDeviceId'] as String? ?? '').trim();
    if (requesterId.isEmpty || requesterId == _settings.syncDeviceId) return;
    _peerLastUdpHost[requesterId] = remoteHost;
    final requesterName = (map['requesterDeviceName'] as String? ?? '').trim();
    final pairingCode = _stringField(map, 'pairingCode');
    final requesterPairingCode = _stringField(map, 'requesterPairingCode');
    final requestNonce = _stringField(map, 'requestNonce');
    final activeCode = _activePairingCode;
    final approved =
        activeCode != null &&
        !activeCode.isExpired &&
        activeCode.code == pairingCode;
    if (!approved) {
      if (_peers.any((p) => p.peerId == requesterId && p.paired)) {
        return;
      }
      _onEvent?.call(
        _localized(
          'Intento de vinculacion: codigo incorrecto o sin codigo activo en este dispositivo. Genera un codigo aqui y usa el mismo en el otro equipo.',
          'Link attempt: wrong code, or no active code on this device. Generate a code here and enter it on the other device.',
        ),
      );
      _emitPairAccept(
        toDeviceId: requesterId,
        approved: false,
        requestNonce: requestNonce,
        alsoToHost: remoteHost,
      );
      return;
    }

    final pending = _incomingPairRequest;
    if (pending != null) {
      if (pending.requesterId == requesterId &&
          pending.pairingCode == pairingCode &&
          pending.requestNonce == requestNonce) {
        return;
      }
      _emitPairAccept(
        toDeviceId: requesterId,
        approved: false,
        requestNonce: requestNonce,
        alsoToHost: remoteHost,
      );
      return;
    }

    _incomingPairRequest = IncomingPairRequest(
      requesterId: requesterId,
      requesterName: requesterName,
      pairingCode: pairingCode,
      requestNonce: requestNonce,
      sharedEmojis: _buildSharedPairingEmojis(
        activeCode.code,
        requesterPairingCode,
      ),
    );
    _incomingPairReplyHost = remoteHost;
    _incomingRequesterConfirmed = false;
    notifyListeners();
    _onIncomingPairRequest?.call(_incomingPairRequest!);
  }

  void _consumePairAccept(Map map, InternetAddress remoteHost) {
    final target = (map['targetDeviceId'] as String? ?? '').trim();
    if (target != _settings.syncDeviceId) return;
    final fromDeviceId = (map['fromDeviceId'] as String? ?? '').trim();
    if (fromDeviceId.isEmpty) return;
    _peerLastUdpHost[fromDeviceId] = remoteHost;
    final approved = map['approved'] == true;
    final requestNonce = _stringField(map, 'requestNonce');
    final pending = _pendingPairAcks[fromDeviceId];
    if (pending == null || pending.completer.isCompleted) return;
    if (requestNonce.isNotEmpty && pending.requestNonce != requestNonce) {
      return;
    }
    if (!approved) {
      pending.completer.complete(false);
      return;
    }
    pending.remoteConfirmed = true;
    if (pending.localConfirmed) {
      pending.completer.complete(true);
    }
  }

  void _consumePairConfirm(Map map, InternetAddress remoteHost) {
    final target = _stringField(map, 'targetDeviceId');
    if (target != _settings.syncDeviceId) return;
    final fromDeviceId = _stringField(map, 'fromDeviceId');
    if (fromDeviceId.isEmpty || fromDeviceId == _settings.syncDeviceId) {
      return;
    }
    _peerLastUdpHost[fromDeviceId] = remoteHost;
    final requestNonce = _stringField(map, 'requestNonce');
    final accepted = _acceptedIncomingPairRequest;
    if (accepted != null &&
        accepted.requesterId == fromDeviceId &&
        accepted.requestNonce == requestNonce) {
      _acceptedIncomingRequesterConfirmed = true;
      unawaited(
        _finalizeIncomingAcceptedPair(
          accepted,
          _acceptedIncomingPairReplyHost ?? remoteHost,
        ),
      );
      return;
    }
    final incoming = _incomingPairRequest;
    if (incoming != null &&
        incoming.requesterId == fromDeviceId &&
        incoming.requestNonce == requestNonce) {
      _incomingRequesterConfirmed = true;
    }
  }

  void _sendPairRequest({
    required String targetDeviceId,
    required String pairingCode,
    required String requestNonce,
    InternetAddress? alsoToHost,
  }) {
    final requesterPairingCode = _activePairingCode;
    final payload = <String, Object?>{
      'type': 'folio.sync.pair_request',
      'targetDeviceId': targetDeviceId,
      'requesterDeviceId': _settings.syncDeviceId,
      'requesterDeviceName': _settings.syncDeviceName,
      'requesterPairingCode': requesterPairingCode?.code,
      'pairingCode': pairingCode,
      'requestNonce': requestNonce,
      'ts': DateTime.now().millisecondsSinceEpoch,
    };
    _emitUdp(payload, alsoToHost: alsoToHost);
  }

  void _emitPairAccept({
    required String toDeviceId,
    required bool approved,
    String? requestNonce,
    InternetAddress? alsoToHost,
  }) {
    final payload = <String, Object?>{
      'type': 'folio.sync.pair_accept',
      'targetDeviceId': toDeviceId,
      'fromDeviceId': _settings.syncDeviceId,
      'approved': approved,
      if ((requestNonce ?? '').trim().isNotEmpty)
        'requestNonce': requestNonce!.trim(),
      'ts': DateTime.now().millisecondsSinceEpoch,
    };
    _emitUdp(payload, alsoToHost: alsoToHost);
  }

  void _emitPairConfirm({
    required String toDeviceId,
    required String requestNonce,
    InternetAddress? alsoToHost,
  }) {
    final payload = <String, Object?>{
      'type': 'folio.sync.pair_confirm',
      'targetDeviceId': toDeviceId,
      'fromDeviceId': _settings.syncDeviceId,
      'requestNonce': requestNonce,
      'ts': DateTime.now().millisecondsSinceEpoch,
    };
    _emitUdp(payload, alsoToHost: alsoToHost);
  }

  void _emitPairAcceptBurst({
    required String toDeviceId,
    required bool approved,
    String? requestNonce,
    InternetAddress? alsoToHost,
  }) {
    _emitPairAccept(
      toDeviceId: toDeviceId,
      approved: approved,
      requestNonce: requestNonce,
      alsoToHost: alsoToHost,
    );
    unawaited(() async {
      await Future<void>.delayed(_pairAcceptBurstGap);
      if (_udp == null) return;
      _emitPairAccept(
        toDeviceId: toDeviceId,
        approved: approved,
        requestNonce: requestNonce,
        alsoToHost: alsoToHost,
      );
      await Future<void>.delayed(_pairAcceptBurstGap);
      if (_udp == null) return;
      _emitPairAccept(
        toDeviceId: toDeviceId,
        approved: approved,
        requestNonce: requestNonce,
        alsoToHost: alsoToHost,
      );
    }());
  }

  void _emitPairConfirmBurst({
    required String toDeviceId,
    required String requestNonce,
    InternetAddress? alsoToHost,
  }) {
    _emitPairConfirm(
      toDeviceId: toDeviceId,
      requestNonce: requestNonce,
      alsoToHost: alsoToHost,
    );
    unawaited(() async {
      await Future<void>.delayed(_pairAcceptBurstGap);
      if (_udp == null) return;
      _emitPairConfirm(
        toDeviceId: toDeviceId,
        requestNonce: requestNonce,
        alsoToHost: alsoToHost,
      );
      await Future<void>.delayed(_pairAcceptBurstGap);
      if (_udp == null) return;
      _emitPairConfirm(
        toDeviceId: toDeviceId,
        requestNonce: requestNonce,
        alsoToHost: alsoToHost,
      );
    }());
  }

  Future<void> _awaitOutgoingPairCompletion(
    String peerId,
    _PendingPairAck pending,
  ) async {
    var accepted = false;
    try {
      accepted = await pending.completer.future.timeout(
        const Duration(seconds: 90),
      );
    } catch (_) {
      accepted = false;
    } finally {
      pending.retryTimer?.cancel();
      if (identical(_pendingPairAcks[peerId], pending)) {
        _pendingPairAcks.remove(peerId);
      }
    }
    if (!accepted) return;
    await _finalizePairingWithPeer(
      peerId: peerId,
      displayName: pending.remoteDeviceName,
      alsoToHost: pending.alsoToHost,
      successMessageEs: 'Dispositivo enlazado correctamente.',
      successMessageEn: 'Device linked successfully.',
    );
  }

  Future<void> _finalizeIncomingAcceptedPair(
    IncomingPairRequest request,
    InternetAddress? replyHost,
  ) async {
    final stillAccepted = _acceptedIncomingPairRequest;
    if (stillAccepted == null ||
        stillAccepted.requesterId != request.requesterId ||
        stillAccepted.requestNonce != request.requestNonce) {
      return;
    }
    _acceptedIncomingPairRequest = null;
    _acceptedIncomingPairReplyHost = null;
    _acceptedIncomingRequesterConfirmed = false;
    await _finalizePairingWithPeer(
      peerId: request.requesterId,
      displayName: request.trimmedRequesterName.isEmpty
          ? _localized('Dispositivo Folio', 'Folio device')
          : request.trimmedRequesterName,
      alsoToHost: replyHost,
      successMessageEs: 'Dispositivo enlazado desde solicitud remota.',
      successMessageEn: 'Device linked from remote request.',
    );
  }

  Future<void> _finalizePairingWithPeer({
    required String peerId,
    required String displayName,
    required InternetAddress? alsoToHost,
    required String successMessageEs,
    required String successMessageEn,
  }) async {
    _activePairingCode = null;
    await _markPeerPaired(
      SyncPeer(
        peerId: peerId,
        deviceName: displayName,
        lastSeenAtMs: DateTime.now().millisecondsSinceEpoch,
        paired: true,
        source: SyncPeerDiscoverySource.localDiscovery,
      ),
    );
    _broadcastHello();
    _emitPairedNoticeBurst(
      toDeviceId: peerId,
      peerName: _settings.syncDeviceName,
      alsoToHost: alsoToHost,
    );
    _onEvent?.call(_localized(successMessageEs, successMessageEn));
  }

  void _emitPairedNotice({
    required String toDeviceId,
    required String peerName,
    InternetAddress? alsoToHost,
  }) {
    final payload = <String, Object?>{
      'type': 'folio.sync.paired_notice',
      'targetDeviceId': toDeviceId,
      'fromDeviceId': _settings.syncDeviceId,
      'fromDeviceName': peerName,
      'ts': DateTime.now().millisecondsSinceEpoch,
    };
    _emitUdp(payload, alsoToHost: alsoToHost);
  }

  void _emitPairedNoticeBurst({
    required String toDeviceId,
    required String peerName,
    InternetAddress? alsoToHost,
  }) {
    _emitPairedNotice(
      toDeviceId: toDeviceId,
      peerName: peerName,
      alsoToHost: alsoToHost,
    );
    unawaited(() async {
      await Future<void>.delayed(_pairAcceptBurstGap);
      if (_udp == null) return;
      _emitPairedNotice(
        toDeviceId: toDeviceId,
        peerName: peerName,
        alsoToHost: alsoToHost,
      );
      await Future<void>.delayed(_pairAcceptBurstGap);
      if (_udp == null) return;
      _emitPairedNotice(
        toDeviceId: toDeviceId,
        peerName: peerName,
        alsoToHost: alsoToHost,
      );
    }());
  }

  void _emitSnapshotPing({
    required String toDeviceId,
    InternetAddress? alsoToHost,
  }) {
    final payload = <String, Object?>{
      'type': 'folio.sync.snapshot_ping',
      'targetDeviceId': toDeviceId,
      'fromDeviceId': _settings.syncDeviceId,
      'ts': DateTime.now().millisecondsSinceEpoch,
    };
    _emitUdp(payload, alsoToHost: alsoToHost);
  }

  void _consumeSnapshotPing(Map map, InternetAddress remoteHost) {
    final target = _stringField(map, 'targetDeviceId');
    if (target != _settings.syncDeviceId) return;
    final fromDeviceId = _stringField(map, 'fromDeviceId');
    if (fromDeviceId.isEmpty || fromDeviceId == _settings.syncDeviceId) return;
    _peerLastUdpHost[fromDeviceId] = remoteHost;
    if (_peers.any((p) => p.peerId == fromDeviceId && p.paired)) {
      if (_pendingSnapshotPushPeers.contains(fromDeviceId)) {
        unawaited(_flushPendingSnapshotForPeer(fromDeviceId));
      } else {
        unawaited(_maybePullSnapshotFromPeer(fromDeviceId, force: true));
      }
    }
  }

  Future<void> _consumePairedNotice(Map map, InternetAddress remoteHost) async {
    final target = _stringField(map, 'targetDeviceId');
    if (target != _settings.syncDeviceId) return;
    final fromDeviceId = _stringField(map, 'fromDeviceId');
    if (fromDeviceId.isEmpty || fromDeviceId == _settings.syncDeviceId) return;
    _peerLastUdpHost[fromDeviceId] = remoteHost;
    final fromDeviceName = _stringField(map, 'fromDeviceName');
    final fallbackName = _localized('Dispositivo Folio', 'Folio device');
    final existing = _discoveredById[fromDeviceId];
    final displayName = fromDeviceName.isNotEmpty
        ? fromDeviceName
        : (existing?.deviceName ?? fallbackName);
    await _markPeerPaired(
      SyncPeer(
        peerId: fromDeviceId,
        deviceName: displayName,
        lastSeenAtMs: DateTime.now().millisecondsSinceEpoch,
        paired: true,
        source: SyncPeerDiscoverySource.localDiscovery,
      ),
    );
    if (_pendingSnapshotPushPeers.contains(fromDeviceId)) {
      unawaited(_flushPendingSnapshotForPeer(fromDeviceId));
    }
  }

  void _broadcastHello() {
    final code = _activePairingCode;
    final pairingCode = code != null && !code.isExpired
        ? code.code.trim()
        : null;
    final payload = <String, Object?>{
      'type': 'folio.sync.hello',
      'deviceId': _settings.syncDeviceId,
      'deviceName': _settings.syncDeviceName,
      'pairingCode': pairingCode,
      'helloReply': false,
      'ts': DateTime.now().millisecondsSinceEpoch,
    };
    _emitUdp(payload);
  }

  void _sendHelloDirect(InternetAddress host) {
    final code = _activePairingCode;
    final pairingCode = code != null && !code.isExpired
        ? code.code.trim()
        : null;
    final payload = <String, Object?>{
      'type': 'folio.sync.hello',
      'deviceId': _settings.syncDeviceId,
      'deviceName': _settings.syncDeviceName,
      'pairingCode': pairingCode,
      'helloReply': true,
      'ts': DateTime.now().millisecondsSinceEpoch,
    };
    _emitUdpUnicast(payload, host);
  }

  void _emitUdp(Map<String, Object?> payload, {InternetAddress? alsoToHost}) {
    final socket = _udp;
    if (socket == null) return;
    final bytes = utf8.encode(jsonEncode(payload));
    if (alsoToHost != null) {
      try {
        socket.send(bytes, alsoToHost, _discoveryPort);
      } catch (_) {}
    }
    for (final target in _broadcastTargets) {
      try {
        socket.send(bytes, target, _discoveryPort);
      } catch (_) {}
    }
  }

  void _emitUdpUnicast(Map<String, Object?> payload, InternetAddress host) {
    final socket = _udp;
    if (socket == null) return;
    final bytes = utf8.encode(jsonEncode(payload));
    try {
      socket.send(bytes, host, _discoveryPort);
    } catch (_) {}
  }

  Future<void> _startSnapshotServer() async {
    try {
      _syncServer?.close();
      final server = await ServerSocket.bind(
        InternetAddress.anyIPv4,
        _syncStreamPort,
        shared: true,
      );
      _syncServer = server;
      server.listen((socket) {
        unawaited(_handleSnapshotConnection(socket));
      });
    } catch (e) {
      _onEvent?.call(
        _localized(
          'No se pudo iniciar servidor de sincronizacion: $e',
          'Could not start synchronization server: $e',
        ),
      );
    }
  }

  Future<void> _handleSnapshotConnection(Socket socket) async {
    try {
      final line = await utf8.decoder
          .bind(socket)
          .transform(const LineSplitter())
          .first
          .timeout(const Duration(seconds: 12));
      final raw = jsonDecode(line);
      if (raw is! Map) return;
      final type = _stringField(raw, 'type');
      if (type == 'folio.sync.snapshot_request') {
        final toDeviceId = _stringField(raw, 'toDeviceId');
        if (toDeviceId != _settings.syncDeviceId) return;
        final fromDeviceId = _stringField(raw, 'fromDeviceId');
        final requestId = _stringField(raw, 'requestId');
        final exporter = _onExportSnapshot;
        final snapshot = exporter == null ? null : await exporter();
        final ok = snapshot != null && snapshot.isNotEmpty;
        final response = <String, Object?>{
          'type': 'folio.sync.snapshot_response',
          'requestId': requestId,
          'toDeviceId': fromDeviceId,
          'fromDeviceId': _settings.syncDeviceId,
          'ok': ok,
          if (ok) 'snapshotB64': base64Encode(snapshot),
        };
        socket.write('${jsonEncode(response)}\n');
        await socket.flush();
        return;
      }
      if (type == 'folio.sync.snapshot_push') {
        final toDeviceId = _stringField(raw, 'toDeviceId');
        if (toDeviceId != _settings.syncDeviceId) return;
        final fromDeviceId = _stringField(raw, 'fromDeviceId');
        final requestId = _stringField(raw, 'requestId');
        final snapshotB64 = _stringField(raw, 'snapshotB64');
        final importer = _onImportSnapshot;
        var ok = false;
        if (importer != null &&
            snapshotB64.isNotEmpty &&
            fromDeviceId.isNotEmpty) {
          try {
            final bytes = base64Decode(snapshotB64);
            ok = await importer(bytes, fromDeviceId);
            if (ok) {
              await _settings.setSyncLastSuccessMs(
                DateTime.now().millisecondsSinceEpoch,
              );
            }
          } catch (_) {
            ok = false;
          }
        }
        final response = <String, Object?>{
          'type': 'folio.sync.snapshot_push_ack',
          'requestId': requestId,
          'toDeviceId': fromDeviceId,
          'fromDeviceId': _settings.syncDeviceId,
          'ok': ok,
        };
        socket.write('${jsonEncode(response)}\n');
        await socket.flush();
      }
    } catch (_) {
      // Ignora conexiones incompletas.
    } finally {
      try {
        await socket.close();
      } catch (_) {}
    }
  }

  Future<void> _maybePullSnapshotFromPeer(
    String peerId, {
    bool force = false,
  }) async {
    final host = _peerLastUdpHost[peerId];
    final importer = _onImportSnapshot;
    if (host == null || importer == null) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (!force) {
      final last = _lastSnapshotPullByPeer[peerId] ?? 0;
      if (now - last < _snapshotPullMinInterval.inMilliseconds) {
        return;
      }
    }
    _lastSnapshotPullByPeer[peerId] = now;

    final requestId = _generateToken(12);
    Socket? socket;
    try {
      socket = await Socket.connect(
        host,
        _syncStreamPort,
        timeout: const Duration(seconds: 5),
      );
      final request = <String, Object?>{
        'type': 'folio.sync.snapshot_request',
        'requestId': requestId,
        'toDeviceId': peerId,
        'fromDeviceId': _settings.syncDeviceId,
      };
      socket.write('${jsonEncode(request)}\n');
      await socket.flush();
      final line = await utf8.decoder
          .bind(socket)
          .transform(const LineSplitter())
          .first
          .timeout(const Duration(seconds: 20));
      final raw = jsonDecode(line);
      if (raw is! Map) return;
      if (_stringField(raw, 'type') != 'folio.sync.snapshot_response') return;
      if (_stringField(raw, 'requestId') != requestId) return;
      if (_stringField(raw, 'toDeviceId') != _settings.syncDeviceId) return;
      if (_stringField(raw, 'fromDeviceId') != peerId) return;
      if (raw['ok'] != true) return;
      final snapshotB64 = _stringField(raw, 'snapshotB64');
      if (snapshotB64.isEmpty) return;
      final bytes = base64Decode(snapshotB64);
      final applied = await importer(bytes, peerId);
      if (applied) {
        await _settings.setSyncLastSuccessMs(
          DateTime.now().millisecondsSinceEpoch,
        );
      }
    } catch (_) {
      // No bloquea emparejamiento si no hay snapshot disponible.
    } finally {
      try {
        await socket?.close();
      } catch (_) {}
    }
  }

  Future<bool> _pushSnapshotToPeer(String peerId) async {
    final host = _peerLastUdpHost[peerId];
    final exporter = _onExportSnapshot;
    if (host == null || exporter == null) return false;
    final snapshot = await exporter();
    if (snapshot == null || snapshot.isEmpty) return false;
    final requestId = _generateToken(12);
    Socket? socket;
    try {
      socket = await Socket.connect(
        host,
        _syncStreamPort,
        timeout: const Duration(seconds: 5),
      );
      final request = <String, Object?>{
        'type': 'folio.sync.snapshot_push',
        'requestId': requestId,
        'toDeviceId': peerId,
        'fromDeviceId': _settings.syncDeviceId,
        'snapshotB64': base64Encode(snapshot),
      };
      socket.write('${jsonEncode(request)}\n');
      await socket.flush();
      final line = await utf8.decoder
          .bind(socket)
          .transform(const LineSplitter())
          .first
          .timeout(const Duration(seconds: 20));
      final raw = jsonDecode(line);
      if (raw is! Map) return false;
      if (_stringField(raw, 'type') != 'folio.sync.snapshot_push_ack') {
        return false;
      }
      if (_stringField(raw, 'requestId') != requestId) return false;
      if (_stringField(raw, 'toDeviceId') != _settings.syncDeviceId) {
        return false;
      }
      if (_stringField(raw, 'fromDeviceId') != peerId) return false;
      if (raw['ok'] == true) {
        await _settings.setSyncLastSuccessMs(
          DateTime.now().millisecondsSinceEpoch,
        );
        return true;
      }
      return false;
    } catch (_) {
      // Si falla push directo, deja que el flujo pull intente recuperar.
      return false;
    } finally {
      try {
        await socket?.close();
      } catch (_) {}
    }
  }

  Future<void> _flushPendingSnapshotForPeer(String peerId) async {
    if (!_pendingSnapshotPushPeers.contains(peerId)) return;
    final pushed = await _pushSnapshotToPeer(peerId);
    if (pushed) {
      _pendingSnapshotPushPeers.remove(peerId);
      return;
    }
    _emitSnapshotPing(toDeviceId: peerId, alsoToHost: _peerLastUdpHost[peerId]);
  }

  void onLocalSnapshotPersisted() {
    if (_state == SyncControllerState.stopped) return;
    if (_peers.isEmpty) return;
    for (final peer in _peers) {
      if (!peer.paired) continue;
      _pendingSnapshotPushPeers.add(peer.peerId);
      _emitSnapshotPing(
        toDeviceId: peer.peerId,
        alsoToHost: _peerLastUdpHost[peer.peerId],
      );
      unawaited(_flushPendingSnapshotForPeer(peer.peerId));
      unawaited(() async {
        await Future<void>.delayed(const Duration(milliseconds: 900));
        if (_state == SyncControllerState.stopped) return;
        if (!_pendingSnapshotPushPeers.contains(peer.peerId)) return;
        _emitSnapshotPing(
          toDeviceId: peer.peerId,
          alsoToHost: _peerLastUdpHost[peer.peerId],
        );
        await _flushPendingSnapshotForPeer(peer.peerId);
      }());
    }
  }

  void _upsertPeer(SyncPeer peer) {
    final index = _peers.indexWhere((item) => item.peerId == peer.peerId);
    if (index == -1) {
      _peers.add(peer);
      return;
    }
    _peers[index] = peer;
  }

  Future<void> _markPeerPaired(SyncPeer peer) async {
    _upsertPeer(peer.copyWith(paired: true));
    final discovered = _discoveredById[peer.peerId];
    if (discovered != null) {
      _discoveredById[peer.peerId] = discovered.copyWith(
        paired: true,
        deviceName: peer.deviceName,
        lastSeenAtMs: DateTime.now().millisecondsSinceEpoch,
      );
    }
    _state = SyncControllerState.active;
    await _persistPeers();
    await _settings.setSyncLastSuccessMs(DateTime.now().millisecondsSinceEpoch);
    if (_pendingSnapshotPushPeers.contains(peer.peerId)) {
      unawaited(_flushPendingSnapshotForPeer(peer.peerId));
    } else {
      unawaited(_maybePullSnapshotFromPeer(peer.peerId, force: true));
    }
    notifyListeners();
  }

  Future<void> revokePeer(String peerId) async {
    final safe = peerId.trim();
    if (safe.isEmpty) return;
    final before = _peers.length;
    _peers.removeWhere((peer) => peer.peerId == safe);
    _pendingSnapshotPushPeers.remove(safe);
    if (_peers.length == before) return;
    await _persistPeers();
    notifyListeners();
  }

  Future<void> _persistPeers() async {
    final p = await SharedPreferences.getInstance();
    final json = jsonEncode(_peers.map((peer) => peer.toJson()).toList());
    await p.setString(_pairedPeersKey, json);
  }

  String _generateDigits(int length) {
    final b = StringBuffer();
    for (var i = 0; i < length; i++) {
      b.write(_random.nextInt(10));
    }
    return b.toString();
  }

  String _generateToken(int length) {
    const alphabet = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final b = StringBuffer();
    for (var i = 0; i < length; i++) {
      b.write(alphabet[_random.nextInt(alphabet.length)]);
    }
    return b.toString();
  }

  List<String> _buildSharedPairingEmojis(String a, String b) {
    final left = a.trim();
    final right = b.trim();
    if (left.isEmpty || right.isEmpty) return const <String>[];
    final ordered = [left, right]..sort();
    final seed = '${ordered[0]}|${ordered[1]}';
    const emojiTable = <String>[
      '🐶',
      '🐱',
      '🦊',
      '🐼',
      '🐵',
      '🦁',
      '🐸',
      '🐙',
      '🐬',
      '🦋',
      '🌵',
      '🌸',
      '🍀',
      '🍎',
      '🍋',
      '🍇',
      '🍕',
      '🍩',
      '⚽',
      '🎸',
      '🚲',
      '🚀',
      '🧩',
      '🎈',
      '⭐',
      '🌈',
      '🔥',
      '❄️',
      '🌙',
      '☀️',
      '🧠',
      '📚',
      '🖊️',
      '🔒',
      '🛰️',
      '🎧',
      '🕹️',
      '🎯',
      '🧪',
      '🛟',
    ];
    var hash = 0xcbf29ce484222325;
    const prime = 0x100000001b3;
    for (final unit in seed.codeUnits) {
      hash ^= unit;
      hash = (hash * prime) & 0xffffffffffffffff;
    }
    final emojis = <String>[];
    var cursor = hash;
    for (var i = 0; i < 3; i++) {
      final index = cursor % emojiTable.length;
      emojis.add(emojiTable[index]);
      cursor =
          ((cursor ~/ emojiTable.length) ^ (hash >> (i * 11))) &
          0xffffffffffffffff;
    }
    return emojis;
  }

  String _localized(String es, String en) =>
      _settings.locale?.languageCode == 'es' ? es : en;

  static String _stringField(Map map, String key) {
    final v = map[key];
    if (v == null) return '';
    if (v is String) return v.trim();
    return '$v'.trim();
  }

  @override
  void dispose() {
    _tearDownUdpStack();
    unawaited(AndroidMulticastLock.release());
    super.dispose();
  }
}
