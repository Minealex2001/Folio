import 'package:flutter_test/flutter_test.dart';
import 'package:folio/services/audio_mixer_service.dart';
import 'package:folio/services/diarization_service.dart';

void main() {
  group('ChannelEnergyWindow', () {
    test('micRatio y dominant discriminan mic vs system', () {
      const micHeavy = ChannelEnergyWindow(micRms: 0.4, sysRms: 0.05);
      expect(micHeavy.dominant, 'mic');
      expect(micHeavy.micRatio, greaterThan(0.7));

      const sysHeavy = ChannelEnergyWindow(micRms: 0.05, sysRms: 0.4);
      expect(sysHeavy.dominant, 'system');
      expect(sysHeavy.micRatio, lessThan(0.3));

      const mixed = ChannelEnergyWindow(micRms: 0.2, sysRms: 0.2);
      expect(mixed.dominant, 'mixed');
      expect(mixed.micRatio, closeTo(0.5, 0.01));
    });
  });

  group('DiarizationService — memoria N speakers', () {
    late DiarizationService diarization;

    setUp(() {
      diarization = DiarizationService.instance;
      diarization.endSession('test-session');
      diarization.startSession('test-session');
    });

    tearDown(() {
      diarization.endSession('test-session');
    });

    // Vectores: [rms, zcr, slope, centroid, micRatio]
    List<double> micVoice([double energy = 0.2]) =>
        <double>[energy, 0.12, 0.05, 0.4, 0.9];
    List<double> remoteA([double energy = 0.18]) =>
        <double>[energy, 0.22, 0.08, 0.55, 0.1];
    List<double> remoteB([double energy = 0.35]) =>
        <double>[energy, 0.55, 0.35, 0.15, 0.05];

    test('voces distintas crean Speaker 1 y Speaker 2', () {
      final out = diarization.diarizeFromTurnVectors(
        sessionId: 'test-session',
        turns: [
          (text: 'hola soy yo en el micro', vector: micVoice()),
          (text: 'hola desde la llamada', vector: remoteA()),
        ],
      );
      expect(out, isNotNull);
      expect(out!, contains('Speaker 1:'));
      expect(out, contains('Speaker 2:'));
      expect(out, isNot(contains('Speaker 1: hola soy yo en el micro\nSpeaker 1:')));
    });

    test('misma voz en chunk posterior reusa el mismo Speaker', () {
      final first = diarization.diarizeFromTurnVectors(
        sessionId: 'test-session',
        turns: [
          (text: 'primera intervencion local', vector: micVoice()),
          (text: 'respuesta remota alfa', vector: remoteA()),
        ],
      );
      expect(first, isNotNull);

      final second = diarization.diarizeFromTurnVectors(
        sessionId: 'test-session',
        turns: [
          (text: 'vuelvo a hablar yo', vector: micVoice(0.21)),
        ],
      );
      expect(second, isNotNull);
      expect(second!, startsWith('Speaker 1:'));
    });

    test('tres voces distintas pueden crear Speaker 3', () {
      // Primera pasada: abrir Speaker 1 (mic) y 2 (remoto A).
      final first = diarization.diarizeFromTurnVectors(
        sessionId: 'test-session',
        turns: [
          (text: 'micro local uno.', vector: micVoice()),
          (text: 'remoto alfa uno.', vector: remoteA()),
        ],
      );
      expect(first, contains('Speaker 1:'));
      expect(first, contains('Speaker 2:'));

      // Segunda: voz remota B muy distinta (zcr/centroid) + repetición (novel hits).
      final mid = diarization.diarizeFromTurnVectors(
        sessionId: 'test-session',
        turns: [
          (text: 'remoto beta intro.', vector: remoteB()),
          (text: 'remoto beta sigue.', vector: remoteB(0.17)),
        ],
      );
      expect(mid, isNotNull);

      final again = diarization.diarizeFromTurnVectors(
        sessionId: 'test-session',
        turns: [
          (text: 'remoto beta otra vez.', vector: remoteB(0.165)),
          (text: 'y el micro otra vez.', vector: micVoice(0.19)),
        ],
      );
      expect(again, isNotNull);

      final all = '$first\n$mid\n$again';
      final speakers = RegExp(r'Speaker (\d+):')
          .allMatches(all)
          .map((m) => int.parse(m.group(1)!))
          .toSet();
      expect(speakers, containsAll(<int>[1, 2]));
      expect(speakers.reduce((a, b) => a > b ? a : b), greaterThanOrEqualTo(3));
    });
  });
}
