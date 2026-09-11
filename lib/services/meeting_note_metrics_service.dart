/// Métricas de conversación (Fase 8 de la evolución de `meeting_note`,
/// inspirado en las "Conversation Metrics" de Call.md).
///
/// Cálculo puro sobre el transcript acumulado (líneas `Speaker N: ...`,
/// producidas por `DiarizationService`) y la duración transcurrida —
/// ningún pipeline de captura nuevo. Explícitamente NO incluye: puntuación
/// de "engagement", inferencia de sentimiento/emoción, ni nada que
/// identifique biométricamente a un hablante — solo conteos/ratios/
/// duraciones sobre texto.
library;

/// Snapshot inmutable de métricas en un instante dado.
class MeetingNoteMetricsSnapshot {
  const MeetingNoteMetricsSnapshot({
    required this.wordsPerMinute,
    required this.questionCount,
    required this.longestMonologueWords,
    required this.speakerWordCounts,
    required this.totalWords,
  });

  static const empty = MeetingNoteMetricsSnapshot(
    wordsPerMinute: 0,
    questionCount: 0,
    longestMonologueWords: 0,
    speakerWordCounts: <String, int>{},
    totalWords: 0,
  );

  final double wordsPerMinute;
  final int questionCount;

  /// Palabras del turno ininterrumpido más largo de un mismo speaker (no es
  /// duración real en segundos — se aproxima a partir de [wordsPerMinute]
  /// cuando se necesita, ver `MeetingMetricsService.checkMonologueNudge`).
  final int longestMonologueWords;
  final Map<String, int> speakerWordCounts;
  final int totalWords;

  /// Proporción de palabras por speaker (0..1). Mapa vacío si aún no hay
  /// palabras contadas.
  Map<String, double> get talkRatioBySpeaker {
    if (totalWords <= 0) return const <String, double>{};
    return {
      for (final entry in speakerWordCounts.entries)
        entry.key: entry.value / totalWords,
    };
  }

  Map<String, Object?> toJson() => {
    'wordsPerMinute': wordsPerMinute,
    'questionCount': questionCount,
    'longestMonologueWords': longestMonologueWords,
    'speakerWordCounts': speakerWordCounts,
    'totalWords': totalWords,
  };

  factory MeetingNoteMetricsSnapshot.fromJson(Map<String, Object?> j) {
    final rawSpeakers = j['speakerWordCounts'];
    return MeetingNoteMetricsSnapshot(
      wordsPerMinute: (j['wordsPerMinute'] as num?)?.toDouble() ?? 0,
      questionCount: (j['questionCount'] as num?)?.toInt() ?? 0,
      longestMonologueWords: (j['longestMonologueWords'] as num?)?.toInt() ?? 0,
      speakerWordCounts: rawSpeakers is Map
          ? rawSpeakers.map(
              (k, v) => MapEntry('$k', (v as num?)?.toInt() ?? 0),
            )
          : const <String, int>{},
      totalWords: (j['totalWords'] as num?)?.toInt() ?? 0,
    );
  }
}

class MeetingMetricsService {
  MeetingMetricsService._();
  static final MeetingMetricsService instance = MeetingMetricsService._();

  static final RegExp _speakerLinePrefix = RegExp(r'^Speaker (\d+): (.*)$');

  /// Calcula un snapshot de métricas a partir del transcript acumulado y la
  /// duración transcurrida de la grabación. Puro: mismo input -> mismo
  /// output, sin estado interno.
  MeetingNoteMetricsSnapshot computeSnapshot({
    required String transcript,
    required Duration elapsed,
  }) {
    final lines = transcript
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    final speakerWordCounts = <String, int>{};
    var totalWords = 0;
    var questionCount = 0;
    var longestMonologueWords = 0;
    String? currentSpeaker;
    var currentRunWords = 0;

    for (final line in lines) {
      final match = _speakerLinePrefix.firstMatch(line);
      final speaker = match != null ? 'Speaker ${match.group(1)}' : 'unknown';
      final text = match != null ? (match.group(2) ?? '') : line;

      final words = text
          .split(RegExp(r'\s+'))
          .where((w) => w.isNotEmpty)
          .length;
      totalWords += words;
      speakerWordCounts[speaker] = (speakerWordCounts[speaker] ?? 0) + words;
      questionCount += '?'.allMatches(text).length;

      if (speaker == currentSpeaker) {
        currentRunWords += words;
      } else {
        currentSpeaker = speaker;
        currentRunWords = words;
      }
      if (currentRunWords > longestMonologueWords) {
        longestMonologueWords = currentRunWords;
      }
    }

    final minutes = elapsed.inSeconds / 60.0;
    final wpm = minutes > 0 ? totalWords / minutes : 0.0;

    return MeetingNoteMetricsSnapshot(
      wordsPerMinute: wpm,
      questionCount: questionCount,
      longestMonologueWords: longestMonologueWords,
      speakerWordCounts: speakerWordCounts,
      totalWords: totalWords,
    );
  }

  /// Fase 10: nudge de "llevas hablando mucho rato sin pausa" — neutral,
  /// factual, rate-limited. NO es una puntuación de comportamiento ni tiene
  /// tono de "coaching personal"; solo compara un umbral de duración
  /// estimada (palabras del turno actual / WPM medio de la sesión) contra
  /// [monologueThreshold], y respeta [minGap] desde el último nudge para no
  /// ser invasivo. Devuelve un código corto (para que el llamador localice
  /// el texto) o `null` si no aplica.
  String? checkMonologueNudge({
    required MeetingNoteMetricsSnapshot snapshot,
    required DateTime? lastNudgeAt,
    required DateTime now,
    Duration monologueThreshold = const Duration(minutes: 3),
    Duration minGap = const Duration(minutes: 2),
  }) {
    if (snapshot.wordsPerMinute <= 0 || snapshot.longestMonologueWords <= 0) {
      return null;
    }
    final monologueSeconds =
        (snapshot.longestMonologueWords / snapshot.wordsPerMinute) * 60;
    if (monologueSeconds < monologueThreshold.inSeconds) return null;
    if (lastNudgeAt != null && now.difference(lastNudgeAt) < minGap) {
      return null;
    }
    return 'monologue_long';
  }
}
