/// Fase 8 (métricas) y Fase 10 (nudges) de la evolución de `meeting_note`.
///
/// `MeetingMetricsService` es cálculo puro sobre el transcript acumulado
/// (líneas `Speaker N: ...`) + duración transcurrida — sin pipeline de
/// captura nuevo. Explícitamente fuera de alcance y NO cubierto aquí porque
/// no existe: puntuación de engagement, inferencia de sentimiento/emoción,
/// identificación biométrica.
import 'package:flutter_test/flutter_test.dart';
import 'package:folio/services/meeting_note_metrics_service.dart';

void main() {
  final service = MeetingMetricsService.instance;

  group('computeSnapshot', () {
    test('transcript vacío da snapshot en cero, sin dividir por cero', () {
      final snapshot = service.computeSnapshot(
        transcript: '',
        elapsed: Duration.zero,
      );
      expect(snapshot.totalWords, 0);
      expect(snapshot.wordsPerMinute, 0);
      expect(snapshot.questionCount, 0);
      expect(snapshot.longestMonologueWords, 0);
      expect(snapshot.talkRatioBySpeaker, isEmpty);
    });

    test('cuenta palabras por speaker y calcula talk ratio', () {
      final snapshot = service.computeSnapshot(
        transcript:
            'Speaker 1: hola a todos como estan hoy\n'
            'Speaker 2: bien gracias',
        elapsed: const Duration(minutes: 1),
      );
      // Speaker 1: "hola a todos como estan hoy" = 6 palabras.
      // Speaker 2: "bien gracias" = 2 palabras. Total = 8.
      expect(snapshot.totalWords, 8);
      expect(snapshot.speakerWordCounts['Speaker 1'], 6);
      expect(snapshot.speakerWordCounts['Speaker 2'], 2);
      expect(snapshot.talkRatioBySpeaker['Speaker 1'], closeTo(6 / 8, 0.001));
      expect(snapshot.wordsPerMinute, closeTo(8, 0.001));
    });

    test('cuenta preguntas por la presencia de "?"', () {
      final snapshot = service.computeSnapshot(
        transcript:
            'Speaker 1: cual era el limite acordado? y la fecha?\n'
            'Speaker 2: no lo recuerdo',
        elapsed: const Duration(minutes: 1),
      );
      expect(snapshot.questionCount, 2);
    });

    test('longestMonologueWords acumula turnos consecutivos del mismo speaker', () {
      final snapshot = service.computeSnapshot(
        transcript:
            'Speaker 1: primera parte del monologo\n'
            'Speaker 1: segunda parte que sigue\n'
            'Speaker 2: interrupcion corta\n'
            'Speaker 1: nuevo turno mas corto',
        elapsed: const Duration(minutes: 2),
      );
      // Speaker 1 acumulado en las dos primeras líneas: 4 + 4 = 8 palabras
      // ("primera parte del monologo", "segunda parte que sigue").
      expect(snapshot.longestMonologueWords, 8);
    });

    test('elapsed cero no lanza (wpm queda en 0, no Infinity/NaN)', () {
      final snapshot = service.computeSnapshot(
        transcript: 'Speaker 1: hola',
        elapsed: Duration.zero,
      );
      expect(snapshot.wordsPerMinute, 0);
      expect(snapshot.wordsPerMinute.isFinite, isTrue);
    });

    test('línea sin prefijo "Speaker N:" se cuenta como "unknown"', () {
      final snapshot = service.computeSnapshot(
        transcript: 'texto suelto sin diarizar',
        elapsed: const Duration(minutes: 1),
      );
      expect(snapshot.speakerWordCounts['unknown'], 4);
    });
  });

  group('toJson/fromJson round-trip', () {
    test('conserva todos los campos', () {
      final snapshot = service.computeSnapshot(
        transcript: 'Speaker 1: hola que tal\nSpeaker 2: bien y tu?',
        elapsed: const Duration(minutes: 1),
      );
      final roundTripped = MeetingNoteMetricsSnapshot.fromJson(
        snapshot.toJson(),
      );
      expect(roundTripped.totalWords, snapshot.totalWords);
      expect(roundTripped.questionCount, snapshot.questionCount);
      expect(
        roundTripped.longestMonologueWords,
        snapshot.longestMonologueWords,
      );
      expect(roundTripped.speakerWordCounts, snapshot.speakerWordCounts);
      expect(roundTripped.wordsPerMinute, snapshot.wordsPerMinute);
    });
  });

  group('checkMonologueNudge — Fase 10', () {
    test('sin datos (wpm 0) no dispara nudge', () {
      final result = service.checkMonologueNudge(
        snapshot: MeetingNoteMetricsSnapshot.empty,
        lastNudgeAt: null,
        now: DateTime(2026, 1, 1),
      );
      expect(result, isNull);
    });

    test('monólogo por debajo del umbral no dispara nudge', () {
      // 30 palabras a 60 wpm = 30s de monólogo estimado, por debajo de 3min.
      const snapshot = MeetingNoteMetricsSnapshot(
        wordsPerMinute: 60,
        questionCount: 0,
        longestMonologueWords: 30,
        speakerWordCounts: {'Speaker 1': 30},
        totalWords: 30,
      );
      final result = service.checkMonologueNudge(
        snapshot: snapshot,
        lastNudgeAt: null,
        now: DateTime(2026, 1, 1),
      );
      expect(result, isNull);
    });

    test('monólogo por encima del umbral dispara nudge si no hay rate-limit activo', () {
      // 300 palabras a 100 wpm = 3min exactos.
      const snapshot = MeetingNoteMetricsSnapshot(
        wordsPerMinute: 100,
        questionCount: 0,
        longestMonologueWords: 300,
        speakerWordCounts: {'Speaker 1': 300},
        totalWords: 300,
      );
      final result = service.checkMonologueNudge(
        snapshot: snapshot,
        lastNudgeAt: null,
        now: DateTime(2026, 1, 1),
      );
      expect(result, 'monologue_long');
    });

    test('respeta el rate-limit: no repite antes de minGap', () {
      const snapshot = MeetingNoteMetricsSnapshot(
        wordsPerMinute: 100,
        questionCount: 0,
        longestMonologueWords: 300,
        speakerWordCounts: {'Speaker 1': 300},
        totalWords: 300,
      );
      final now = DateTime(2026, 1, 1, 12, 0);
      final result = service.checkMonologueNudge(
        snapshot: snapshot,
        lastNudgeAt: now.subtract(const Duration(minutes: 1)),
        now: now,
      );
      expect(result, isNull);
    });

    test('dispara de nuevo pasado minGap', () {
      const snapshot = MeetingNoteMetricsSnapshot(
        wordsPerMinute: 100,
        questionCount: 0,
        longestMonologueWords: 300,
        speakerWordCounts: {'Speaker 1': 300},
        totalWords: 300,
      );
      final now = DateTime(2026, 1, 1, 12, 0);
      final result = service.checkMonologueNudge(
        snapshot: snapshot,
        lastNudgeAt: now.subtract(const Duration(minutes: 3)),
        now: now,
      );
      expect(result, 'monologue_long');
    });
  });
}
