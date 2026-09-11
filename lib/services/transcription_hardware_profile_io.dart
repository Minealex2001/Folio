import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;

import '../core/perf/folio_perf_trace.dart';
import 'transcription_hardware_common.dart';

/// Lee CPU/RAM y recomienda modelo Whisper; marca si el equipo es demasiado débil.
class TranscriptionHardwareProfile {
  TranscriptionHardwareProfile._();

  static TranscriptionHardwareSnapshot? _cache;
  static DateTime? _cacheAt;
  static Future<TranscriptionHardwareSnapshot>? _inFlight;

  static const Duration _ttl = Duration(minutes: 5);

  /// Lectura con caché breve para no invocar PowerShell/sysctl en cada chunk.
  ///
  /// SÍNCRONA y potencialmente BLOQUEANTE en cache miss (en Windows lanza
  /// PowerShell con `Process.runSync`). No debe llamarse desde `build()`; para
  /// eso está [loadCachedAsync] + [cachedSnapshotOrNull]. Se mantiene tal cual
  /// para los llamadores que ya asumían esta semántica.
  static TranscriptionHardwareSnapshot loadCached() {
    final cached = cachedSnapshotOrNull;
    if (cached != null) return cached;
    final snap = load();
    _cache = snap;
    _cacheAt = DateTime.now();
    return snap;
  }

  /// Cache válida (< TTL) si la hay, o `null`. Nunca lanza procesos ni bloquea.
  static TranscriptionHardwareSnapshot? get cachedSnapshotOrNull {
    final cached = _cache;
    final at = _cacheAt;
    if (cached != null && at != null && DateTime.now().difference(at) < _ttl) {
      return cached;
    }
    return null;
  }

  /// Instantánea segura e inmediata para el primer pintado: CPUs reales +
  /// `totalRamBytes` desconocido. Es exactamente lo que [load] devuelve cuando
  /// la lectura de RAM falla, así que las heurísticas de modelo/viabilidad se
  /// comportan igual que en ese fallback.
  static TranscriptionHardwareSnapshot safeFallback() =>
      _buildSnapshot(Platform.numberOfProcessors.clamp(1, 65536), null);

  /// Versión NO bloqueante de [loadCached]: si hay cache válida la devuelve ya;
  /// si no, lee la RAM con `Process.run` (async) fuera del UI isolate del
  /// llamador, puebla la misma cache y devuelve el resultado. Varias llamadas
  /// concurrentes comparten un único trabajo en vuelo (dedup).
  static Future<TranscriptionHardwareSnapshot> loadCachedAsync() {
    final cached = cachedSnapshotOrNull;
    if (cached != null) return Future<TranscriptionHardwareSnapshot>.value(cached);
    return _inFlight ??= _computeAsync().whenComplete(() {
      _inFlight = null;
    });
  }

  static Future<TranscriptionHardwareSnapshot> _computeAsync() async {
    final swLoad = FolioPerfTrace.begin();
    final cpus = Platform.numberOfProcessors.clamp(1, 65536);
    final swRam = FolioPerfTrace.begin();
    final ram = await _readTotalRamBytesAsync();
    final ramUs = FolioPerfTrace.us(swRam);
    final snap = _buildSnapshot(cpus, ram);
    _cache = snap;
    _cacheAt = DateTime.now();

    if (FolioPerfTrace.enabled) {
      FolioPerfTrace.log('hwProfile.loadAsync', {
        'platform': Platform.operatingSystem,
        'cpus': cpus,
        'ramBytes': ram ?? -1,
        'readTotalRam_ms': FolioPerfTrace.ms(ramUs),
        'total_ms': FolioPerfTrace.ms(FolioPerfTrace.us(swLoad)),
      });
    }
    return snap;
  }

  static TranscriptionHardwareSnapshot load() {
    // Instrumentación opt-in (FOLIO_PERF_TRACE): mide `load()` completo y, por
    // separado, `_readTotalRamBytes()` (que en Windows lanza PowerShell
    // síncrono). No cambia comportamiento.
    final swLoad = FolioPerfTrace.begin();
    final cpus = Platform.numberOfProcessors.clamp(1, 65536);
    final swRam = FolioPerfTrace.begin();
    final ram = _readTotalRamBytes();
    final ramUs = FolioPerfTrace.us(swRam);
    final snap = _buildSnapshot(cpus, ram);

    if (FolioPerfTrace.enabled) {
      FolioPerfTrace.log('hwProfile.load', {
        'platform': Platform.operatingSystem,
        'cpus': cpus,
        'ramBytes': ram ?? -1,
        'readTotalRam_ms': FolioPerfTrace.ms(ramUs),
        'total_ms': FolioPerfTrace.ms(FolioPerfTrace.us(swLoad)),
      });
    }
    return snap;
  }

  /// Misma construcción de snapshot para el camino sync y el async: mismas
  /// heurísticas, mismo resultado dados los mismos `cpus`/`ram`.
  static TranscriptionHardwareSnapshot _buildSnapshot(int cpus, int? ram) {
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
    debugSyncRamReadCount++;
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

  static Future<int?> _readTotalRamBytesAsync() async {
    debugAsyncRamReadCount++;
    final override = debugRamReadOverride;
    if (override != null) {
      try {
        return await override();
      } catch (_) {
        return null;
      }
    }
    try {
      if (Platform.isWindows) {
        return await _windowsTotalPhysBytesAsync();
      }
      if (Platform.isMacOS) {
        return await _macTotalRamBytesAsync();
      }
      if (Platform.isLinux) {
        // Lectura de /proc/meminfo: I/O de fichero, sub-ms, sin proceso.
        return _linuxMemTotalBytes();
      }
    } catch (_) {}
    return null;
  }

  static int? _windowsTotalPhysBytes() {
    final swPs = FolioPerfTrace.begin();
    final r = Process.runSync(
      'powershell.exe',
      const [
        '-NoProfile',
        '-Command',
        '(Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory',
      ],
      runInShell: false,
    );
    if (FolioPerfTrace.enabled) {
      FolioPerfTrace.log('hwProfile.powershellRunSync', {
        'ms': FolioPerfTrace.ms(FolioPerfTrace.us(swPs)),
        'exitCode': r.exitCode,
      });
    }
    return _parsePhysBytes(r.exitCode, r.stdout);
  }

  static Future<int?> _windowsTotalPhysBytesAsync() async {
    final swPs = FolioPerfTrace.begin();
    final r = await Process.run(
      'powershell.exe',
      const [
        '-NoProfile',
        '-Command',
        '(Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory',
      ],
      runInShell: false,
    );
    if (FolioPerfTrace.enabled) {
      FolioPerfTrace.log('hwProfile.powershellRun', {
        'ms': FolioPerfTrace.ms(FolioPerfTrace.us(swPs)),
        'exitCode': r.exitCode,
      });
    }
    return _parsePhysBytes(r.exitCode, r.stdout);
  }

  static int? _parsePhysBytes(int exitCode, Object? stdout) {
    if (exitCode != 0) return null;
    final line = '$stdout'.trim();
    if (line.isEmpty) return null;
    final n = int.tryParse(line);
    if (n == null || n <= 0) return null;
    return n;
  }

  static int? _macTotalRamBytes() {
    final r = Process.runSync('sysctl', ['-n', 'hw.memsize']);
    return _parsePhysBytes(r.exitCode, r.stdout);
  }

  static Future<int?> _macTotalRamBytesAsync() async {
    final r = await Process.run('sysctl', ['-n', 'hw.memsize']);
    return _parsePhysBytes(r.exitCode, r.stdout);
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

  // --- Instrumentación de tests (H2). Coste cero en release. ---

  /// Nº de veces que se ha ejecutado la lectura de RAM SÍNCRONA (la que puede
  /// bloquear el UI isolate). Un `build()` correcto de Settings → Quill no debe
  /// incrementarlo.
  @visibleForTesting
  static int debugSyncRamReadCount = 0;

  /// Nº de veces que se ha ejecutado la lectura de RAM ASÍNCRONA.
  @visibleForTesting
  static int debugAsyncRamReadCount = 0;

  /// Si se define, [loadCachedAsync] usa esto en vez de lanzar un proceso real
  /// (tests deterministas: valor fijo, `null` = fallo, o `throw`).
  @visibleForTesting
  static Future<int?> Function()? debugRamReadOverride;

  @visibleForTesting
  static void debugResetForTests() {
    _cache = null;
    _cacheAt = null;
    _inFlight = null;
    debugSyncRamReadCount = 0;
    debugAsyncRamReadCount = 0;
    debugRamReadOverride = null;
  }

  @visibleForTesting
  static void debugSeedCache(TranscriptionHardwareSnapshot snap) {
    _cache = snap;
    _cacheAt = DateTime.now();
  }
}
