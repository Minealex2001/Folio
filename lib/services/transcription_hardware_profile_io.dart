import 'dart:io';

import 'transcription_hardware_common.dart';

/// Lee CPU/RAM y recomienda modelo Whisper; marca si el equipo es demasiado débil.
class TranscriptionHardwareProfile {
  TranscriptionHardwareProfile._();

  static TranscriptionHardwareSnapshot? _cache;
  static DateTime? _cacheAt;

  /// Lectura con caché breve para no invocar PowerShell/sysctl en cada chunk.
  static TranscriptionHardwareSnapshot loadCached() {
    final now = DateTime.now();
    final cached = _cache;
    final at = _cacheAt;
    if (cached != null &&
        at != null &&
        now.difference(at) < const Duration(minutes: 5)) {
      return cached;
    }
    final snap = load();
    _cache = snap;
    _cacheAt = now;
    return snap;
  }

  static TranscriptionHardwareSnapshot load() {
    final cpus = Platform.numberOfProcessors.clamp(1, 65536);
    final ram = _readTotalRamBytes();
    final viable = computeLocalTranscriptionViable(
      logicalCpuCount: cpus,
      totalRamBytes: ram,
    );
    final modelId = recommendWhisperModelId(
      logicalCpuCount: cpus,
      totalRamBytes: totalRamBytesForWhisperHeuristics(ram),
    );

    return TranscriptionHardwareSnapshot(
      logicalCpuCount: cpus,
      totalRamBytes: ram,
      recommendedWhisperModelId: modelId,
      isLocalTranscriptionViable: viable,
    );
  }

  static int? _readTotalRamBytes() {
    try {
      if (Platform.isWindows) {
        return _windowsTotalPhysBytes();
      }
      if (Platform.isMacOS) {
        return _macTotalRamBytes();
      }
      if (Platform.isLinux) {
        return _linuxMemTotalBytes();
      }
    } catch (_) {}
    return null;
  }

  static int? _windowsTotalPhysBytes() {
    final r = Process.runSync(
      'powershell.exe',
      const [
        '-NoProfile',
        '-Command',
        '(Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory',
      ],
      runInShell: false,
    );
    if (r.exitCode != 0) return null;
    final line = '${r.stdout}'.trim();
    if (line.isEmpty) return null;
    final n = int.tryParse(line);
    if (n == null || n <= 0) return null;
    return n;
  }

  static int? _macTotalRamBytes() {
    final r = Process.runSync('sysctl', ['-n', 'hw.memsize']);
    if (r.exitCode != 0) return null;
    final line = '${r.stdout}'.trim();
    if (line.isEmpty) return null;
    final n = int.tryParse(line);
    if (n == null || n <= 0) return null;
    return n;
  }

  static int? _linuxMemTotalBytes() {
    final f = File('/proc/meminfo');
    if (!f.existsSync()) return null;
    final lines = f.readAsLinesSync();
    for (final line in lines) {
      if (!line.startsWith('MemTotal:')) continue;
      final parts = line.split(RegExp(r'\s+'));
      if (parts.length < 3) return null;
      final kb = int.tryParse(parts[1]);
      if (kb == null || kb <= 0) return null;
      return kb * 1024;
    }
    return null;
  }
}
