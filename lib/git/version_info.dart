/// Información de una versión (revisión o snapshot) para mostrar en historial.
///
/// Abstracción que funciona igual para:
/// - Formato viejo (pageRevisions en memoria)
/// - Formato nuevo (snapshots en disco)

class VersionInfo {
  VersionInfo({
    required this.versionId,
    required this.timestamp,
    required this.label,
    required this.source,
    this.deviceId,
    this.pageCount,
  });

  /// ID único de la versión (revisionId o snapshotId)
  final String versionId;

  /// Timestamp de creación (ms desde epoch)
  final int timestamp;

  /// Etiqueta legible para mostrar al usuario
  final String label;

  /// Fuente: "memory" (pageRevision) o "snapshot"
  final String source;

  /// Dispositivo que creó la versión (solo en snapshots)
  final String? deviceId;

  /// Número de páginas en esta versión (opcional)
  final int? pageCount;

  /// Formatea el timestamp como string legible
  String get formattedTime {
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  /// Indica si esta versión es del formato antiguo (en memoria)
  bool get isLegacy => source == 'memory';

  /// Indica si esta versión es un snapshot (persistente)
  bool get isSnapshot => source == 'snapshot';

  @override
  String toString() => 'VersionInfo($versionId, $formattedTime, $label)';
}
