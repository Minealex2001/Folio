/// Umbrales orientativos para recomendar modelo Whisper local y decidir viabilidad.
class TranscriptionHardwareThresholds {
  const TranscriptionHardwareThresholds._();

  /// RAM mínima razonable para intentar Whisper local (sin override).
  static const int minRamBytesForLocal = 3 * 1024 * 1024 * 1024;

  /// CPUs lógicos mínimos para transcripción local recomendada.
  static const int minLogicalCpusForLocal = 2;

  /// Por debajo de esto se recomienda modelo `tiny`.
  static const int ramBytesPreferTiny = 8 * 1024 * 1024 * 1024;

  static const int cpusPreferTiny = 4;

  /// A partir de esto (y CPUs altas) se puede recomendar `small`.
  static const int ramBytesPreferSmall = 16 * 1024 * 1024 * 1024;

  static const int cpusPreferSmall = 8;

  /// Umbral para recomendar `medium` (q8).
  static const int ramBytesPreferMedium = 20 * 1024 * 1024 * 1024;

  static const int cpusPreferMedium = 10;

  /// Umbral para recomendar `turbo` (large v3 turbo q8).
  static const int ramBytesPreferTurbo = 32 * 1024 * 1024 * 1024;

  static const int cpusPreferTurbo = 12;
}

/// GB enteros tras redondear bytes a GiB y, si queda impar, subir al siguiente par.
/// Compensa lecturas de RAM del SO algo por debajo del módulo instalado.
int reportedRamGbRoundedEven(int totalRamBytes) {
  var gb = (totalRamBytes / (1024 * 1024 * 1024)).round();
  if (gb > 0 && gb.isOdd) gb += 1;
  return gb;
}

/// Misma corrección que la etiqueta de UI, en bytes, solo para umbrales de modelo.
int? totalRamBytesForWhisperHeuristics(int? rawTotalRamBytes) {
  final b = rawTotalRamBytes;
  if (b == null || b <= 0) return b;
  final gb = reportedRamGbRoundedEven(b);
  return gb * 1024 * 1024 * 1024;
}

/// Instantánea de hardware para transcripción local.
class TranscriptionHardwareSnapshot {
  const TranscriptionHardwareSnapshot({
    required this.logicalCpuCount,
    required this.totalRamBytes,
    required this.recommendedWhisperModelId,
    required this.isLocalTranscriptionViable,
  });

  final int logicalCpuCount;
  final int? totalRamBytes;
  final String recommendedWhisperModelId;
  final bool isLocalTranscriptionViable;

  /// Etiqueta corta de RAM para UI (p. ej. "8 GB", "—").
  ///
  /// Tras redondear a GB enteros, si el resultado es impar se usa el siguiente
  /// par (p. ej. 31 → 32). En Windows `TotalPhysicalMemory` suele ser algo
  /// menor que el módulo instalado por memoria reservada, y sin esto un equipo
  /// de 32 GB puede mostrarse como 31 GB.
  String ramLabelForUi(String unknownLabel) {
    final b = totalRamBytes;
    if (b == null || b <= 0) return unknownLabel;
    final gb = reportedRamGbRoundedEven(b);
    return '$gb GB';
  }
}

String recommendWhisperModelId({
  required int logicalCpuCount,
  required int? totalRamBytes,
}) {
  final ram = totalRamBytes;
  final c = logicalCpuCount;
  final lowRam = ram != null && ram < TranscriptionHardwareThresholds.ramBytesPreferTiny;
  final lowCpu = c < TranscriptionHardwareThresholds.cpusPreferTiny;
  if (lowRam || lowCpu) return 'tiny';

  if (ram != null &&
      ram >= TranscriptionHardwareThresholds.ramBytesPreferTurbo &&
      c >= TranscriptionHardwareThresholds.cpusPreferTurbo) {
    return 'turbo';
  }
  if (ram != null &&
      ram >= TranscriptionHardwareThresholds.ramBytesPreferMedium &&
      c >= TranscriptionHardwareThresholds.cpusPreferMedium) {
    return 'medium';
  }

  if (ram == null) {
    if (c >= TranscriptionHardwareThresholds.cpusPreferTurbo) return 'medium';
    if (c >= TranscriptionHardwareThresholds.cpusPreferSmall) return 'small';
    return 'base';
  }

  final highRam = ram >= TranscriptionHardwareThresholds.ramBytesPreferSmall;
  final highCpu = c >= TranscriptionHardwareThresholds.cpusPreferSmall;
  if (highRam && highCpu) return 'small';

  return 'base';
}

bool computeLocalTranscriptionViable({
  required int logicalCpuCount,
  required int? totalRamBytes,
}) {
  return logicalCpuCount >= TranscriptionHardwareThresholds.minLogicalCpusForLocal &&
      (totalRamBytes == null ||
          totalRamBytes >= TranscriptionHardwareThresholds.minRamBytesForLocal);
}
