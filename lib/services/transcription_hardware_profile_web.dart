import 'package:flutter/foundation.dart' show visibleForTesting;

import 'transcription_hardware_common.dart';

/// Versión web: sin `dart:io`; las notas de reunión con Whisper no aplican en el navegador.
class TranscriptionHardwareProfile {
  TranscriptionHardwareProfile._();

  static TranscriptionHardwareSnapshot loadCached() => load();

  static TranscriptionHardwareSnapshot? get cachedSnapshotOrNull => load();

  static TranscriptionHardwareSnapshot safeFallback() => load();

  static Future<TranscriptionHardwareSnapshot> loadCachedAsync() =>
      Future<TranscriptionHardwareSnapshot>.value(load());

  static TranscriptionHardwareSnapshot load() {
    return const TranscriptionHardwareSnapshot(
      logicalCpuCount: 4,
      totalRamBytes: null,
      recommendedWhisperModelId: 'base',
      isLocalTranscriptionViable: true,
    );
  }

  // Paridad de API con la versión io (instrumentación de tests). No-ops en web.
  @visibleForTesting
  static int debugSyncRamReadCount = 0;
  @visibleForTesting
  static int debugAsyncRamReadCount = 0;
  @visibleForTesting
  static Future<int?> Function()? debugRamReadOverride;
  @visibleForTesting
  static void debugResetForTests() {}
  @visibleForTesting
  static void debugSeedCache(TranscriptionHardwareSnapshot snap) {}
}
