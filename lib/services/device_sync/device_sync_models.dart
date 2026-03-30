enum SyncPeerDiscoverySource { localDiscovery, relaySignaling, manualCode }

enum SyncControllerState { stopped, searching, active }

class SyncPeer {
  const SyncPeer({
    required this.peerId,
    required this.deviceName,
    required this.lastSeenAtMs,
    required this.paired,
    required this.source,
    this.pairingCode,
  });

  final String peerId;
  final String deviceName;
  final int lastSeenAtMs;
  final bool paired;
  final SyncPeerDiscoverySource source;
  final String? pairingCode;

  SyncPeer copyWith({
    String? peerId,
    String? deviceName,
    int? lastSeenAtMs,
    bool? paired,
    SyncPeerDiscoverySource? source,
    String? pairingCode,
  }) {
    return SyncPeer(
      peerId: peerId ?? this.peerId,
      deviceName: deviceName ?? this.deviceName,
      lastSeenAtMs: lastSeenAtMs ?? this.lastSeenAtMs,
      paired: paired ?? this.paired,
      source: source ?? this.source,
      pairingCode: pairingCode ?? this.pairingCode,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'peerId': peerId,
      'deviceName': deviceName,
      'lastSeenAtMs': lastSeenAtMs,
      'paired': paired,
      'source': source.name,
      if (pairingCode != null && pairingCode!.isNotEmpty)
        'pairingCode': pairingCode,
    };
  }

  factory SyncPeer.fromJson(Map raw) {
    final sourceRaw = (raw['source'] as String? ?? '').trim();
    final source = SyncPeerDiscoverySource.values.firstWhere(
      (value) => value.name == sourceRaw,
      orElse: () => SyncPeerDiscoverySource.manualCode,
    );
    return SyncPeer(
      peerId: (raw['peerId'] as String? ?? '').trim(),
      deviceName: (raw['deviceName'] as String? ?? '').trim(),
      lastSeenAtMs: (raw['lastSeenAtMs'] as num?)?.toInt() ?? 0,
      paired: raw['paired'] == true,
      source: source,
      pairingCode: (raw['pairingCode'] as String?)?.trim(),
    );
  }
}

class SyncPairingCode {
  const SyncPairingCode({required this.code, required this.expiresAtMs});

  final String code;
  final int expiresAtMs;

  bool get isExpired => DateTime.now().millisecondsSinceEpoch >= expiresAtMs;
}

/// Solicitud entrante de vinculación (mostrar diálogo en el dispositivo receptor).
class IncomingPairRequest {
  const IncomingPairRequest({
    required this.requesterId,
    required this.requesterName,
    required this.pairingCode,
    required this.requestNonce,
    required this.sharedEmojis,
  });

  final String requesterId;
  final String requesterName;
  final String pairingCode;
  final String requestNonce;
  final List<String> sharedEmojis;

  /// Nombre para mostrar; puede ser vacío si el otro dispositivo no lo envió.
  String get trimmedRequesterName => requesterName.trim();
}
