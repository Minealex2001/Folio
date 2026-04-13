import 'transcription_hardware_common.dart';

/// Versión web: sin `dart:io`; las notas de reunión con Whisper no aplican en el navegador.
class TranscriptionHardwareProfile {
  TranscriptionHardwareProfile._();

  static TranscriptionHardwareSnapshot loadCached() => load();

  static TranscriptionHardwareSnapshot load() {
    return const TranscriptionHardwareSnapshot(
      logicalCpuCount: 4,
      totalRamBytes: null,
      recommendedWhisperModelId: 'base',
      isLocalTranscriptionViable: true,
    );
  }
}
