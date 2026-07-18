import 'dart:convert';

/// Entrada de la cola de conflictos de sync (bloque o legado de libreta).
class SyncConflictEntry {
  const SyncConflictEntry({
    required this.id,
    required this.fromPeerId,
    required this.createdAtMs,
    required this.remoteFingerprint,
    required this.remoteSnapshotBytes,
    required this.remotePageCount,
    this.pageId,
    this.blockId,
    this.remoteBlockJson,
    this.localBlockJson,
  });

  final String id;
  final String fromPeerId;
  final int createdAtMs;
  final String remoteFingerprint;
  final List<int> remoteSnapshotBytes;
  final int remotePageCount;

  /// Conflicto granular de bloque (null = legado a nivel de libreta).
  final String? pageId;
  final String? blockId;
  final Map<String, dynamic>? remoteBlockJson;
  final Map<String, dynamic>? localBlockJson;

  bool get isBlockConflict =>
      pageId != null &&
      pageId!.isNotEmpty &&
      blockId != null &&
      blockId!.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'id': id,
        'fromPeerId': fromPeerId,
        'createdAtMs': createdAtMs,
        'remoteFingerprint': remoteFingerprint,
        'remotePageCount': remotePageCount,
        if (pageId != null) 'pageId': pageId,
        if (blockId != null) 'blockId': blockId,
        if (localBlockJson != null) 'localBlockJson': localBlockJson,
        if (remoteBlockJson != null) 'remoteBlockJson': remoteBlockJson,
        // Snapshot legado: solo si no hay conflicto de bloque (más liviano).
        if (!isBlockConflict && remoteSnapshotBytes.isNotEmpty)
          'remoteSnapshotB64': base64Encode(remoteSnapshotBytes),
      };

  static SyncConflictEntry? fromJson(Map<String, dynamic> j) {
    final id = '${j['id'] ?? ''}'.trim();
    if (id.isEmpty) return null;
    final fp = '${j['remoteFingerprint'] ?? ''}'.trim();
    List<int> snap = const [];
    final b64 = '${j['remoteSnapshotB64'] ?? ''}'.trim();
    if (b64.isNotEmpty) {
      try {
        snap = base64Decode(b64);
      } catch (_) {
        snap = const [];
      }
    }
    Map<String, dynamic>? localJson;
    Map<String, dynamic>? remoteJson;
    final lj = j['localBlockJson'];
    final rj = j['remoteBlockJson'];
    if (lj is Map) localJson = Map<String, dynamic>.from(lj);
    if (rj is Map) remoteJson = Map<String, dynamic>.from(rj);
    return SyncConflictEntry(
      id: id,
      fromPeerId: '${j['fromPeerId'] ?? ''}'.trim(),
      createdAtMs: (j['createdAtMs'] as num?)?.toInt() ?? 0,
      remoteFingerprint: fp,
      remoteSnapshotBytes: snap,
      remotePageCount: (j['remotePageCount'] as num?)?.toInt() ?? 0,
      pageId: '${j['pageId'] ?? ''}'.trim().isEmpty
          ? null
          : '${j['pageId']}'.trim(),
      blockId: '${j['blockId'] ?? ''}'.trim().isEmpty
          ? null
          : '${j['blockId']}'.trim(),
      localBlockJson: localJson,
      remoteBlockJson: remoteJson,
    );
  }
}
