import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'audio_mixer_service.dart';
import 'whisper_service.dart';

class DiarizationService {
  DiarizationService._();
  static final DiarizationService instance = DiarizationService._();

  final Map<String, _DiarizationSession> _sessions = {};

  String? lastError;

  void startSession(String sessionId) {
    final safe = sessionId.trim();
    if (safe.isEmpty) return;
    _sessions[safe] = _DiarizationSession();
  }

  void endSession(String sessionId) {
    final safe = sessionId.trim();
    if (safe.isEmpty) return;
    _sessions.remove(safe);
  }

  /// Asigna speakers desde vectores de turno precomputados (tests / debugging).
  /// Conserva memoria de sesión: el mismo perfil reaparece como el mismo ID.
  @visibleForTesting
  String? diarizeFromTurnVectors({
    required String sessionId,
    required List<({String text, List<double> vector})> turns,
  }) {
    final safeSession = sessionId.trim();
    if (safeSession.isEmpty || turns.isEmpty) return null;
    final session = _sessions.putIfAbsent(safeSession, _DiarizationSession.new);
    final candidates = <_TurnCandidate>[];
    for (final t in turns) {
      final text = t.text.trim();
      if (text.isEmpty) continue;
      candidates.add(
        _TurnCandidate(
          text: text,
          feature: _TurnFeature(vector: List<double>.from(t.vector), weight: 1),
        ),
      );
    }
    if (candidates.isEmpty) return null;
    final lines = _linesFromTurnCandidates(session: session, turns: candidates);
    if (lines.isEmpty) return null;
    return lines.join('\n');
  }

  /// Diarización local sin backend.
  ///
  /// Estrategia:
  /// 1) Intenta tinydiarize (marcadores de turno) si el modelo lo soporta.
  /// 2) Segmenta turnos por silencio, salto acústico y cambio de dominancia
  ///    mic/system ([channelWindows]).
  /// 3) Asigna Speaker N vía perfiles de sesión (memoria entre chunks, N ilimitado).
  /// [channelWindows]: energías mic/system por ventana (~250 ms) del mixer.
  /// [channelHint]: legacy; solo se usa si no hay ventanas y el fallback es
  /// un único turno silencioso. No limita a 2 speakers en el path principal.
  Future<String?> diarizeChunk({
    required File audioChunk,
    required String transcript,
    required String language,
    required String sessionId,
    String? channelHint,
    List<ChannelEnergyWindow> channelWindows = const <ChannelEnergyWindow>[],
  }) async {
    final safeTranscript = transcript.trim();
    if (safeTranscript.isEmpty) return null;
    final safeSession = sessionId.trim();
    if (safeSession.isEmpty) return null;

    lastError = null;

    try {
      final session = _sessions.putIfAbsent(
        safeSession,
        _DiarizationSession.new,
      );

      // Motor opcional: Whisper local con tinydiarize (solo fronteras de turno).
      final iaTurns = await _tryWhisperLocalTurns(
        audioChunk: audioChunk,
        language: language,
      );
      if (iaTurns.isNotEmpty) {
        final formatted = await _renderWithSessionSpeakers(
          session: session,
          audioChunk: audioChunk,
          turns: iaTurns,
          fallbackTranscript: safeTranscript,
          channelWindows: channelWindows,
        );
        if (formatted != null && formatted.trim().isNotEmpty) {
          return formatted;
        }
      } else {
        final whisperErr = WhisperService.instance.lastError;
        if (whisperErr != null && whisperErr.trim().isNotEmpty) {
          lastError = 'Fallback heuristico: $whisperErr';
        }
      }

      // Heurístico local: turnos + clustering N-way con memoria de sesión.
      final sentences = _splitSentences(safeTranscript);
      if (sentences.isEmpty) return null;

      final turnFeatures = await _extractTurnFeaturesFromAudio(
        audioChunk,
        channelWindows: channelWindows,
      );

      final turnTexts = _distributeTextAcrossTurns(
        rawTranscript: safeTranscript,
        sentenceFallback: sentences,
        turns: turnFeatures,
      );

      final turnCandidates = <_TurnCandidate>[];
      for (var i = 0; i < turnTexts.length; i++) {
        final text = turnTexts[i].trim();
        if (text.isEmpty) continue;
        final feature = i < turnFeatures.length
            ? turnFeatures[i]
            : _TurnFeature.silent();
        turnCandidates.add(_TurnCandidate(text: text, feature: feature));
      }

      final lines = _linesFromTurnCandidates(session: session, turns: turnCandidates);

      if (lines.isEmpty) {
        final feature = turnFeatures.isNotEmpty
            ? turnFeatures.first
            : _featureFromChannelHint(channelHint);
        final speaker = session.assignSpeaker(feature);
        return 'Speaker $speaker: $safeTranscript';
      }
      return lines.join('\n');
    } catch (e) {
      lastError = e.toString();
      return null;
    }
  }

  _TurnFeature _featureFromChannelHint(String? channelHint) {
    switch (channelHint) {
      case 'mic':
        return const _TurnFeature(
          vector: <double>[0.08, 0.08, 0.04, 0.5, 0.85],
          weight: 1,
        );
      case 'system':
        return const _TurnFeature(
          vector: <double>[0.08, 0.08, 0.04, 0.5, 0.15],
          weight: 1,
        );
      default:
        return _TurnFeature.silent();
    }
  }

  Future<String?> _renderWithSessionSpeakers({
    required _DiarizationSession session,
    required File audioChunk,
    required List<_TurnCandidate> turns,
    required String fallbackTranscript,
    List<ChannelEnergyWindow> channelWindows = const <ChannelEnergyWindow>[],
  }) async {
    final turnFeatures = await _extractTurnFeaturesFromAudio(
      audioChunk,
      channelWindows: channelWindows,
    );
    final featureCount = math.max(1, turnFeatures.length);
    final enriched = <_TurnCandidate>[];
    for (var i = 0; i < turns.length; i++) {
      final t = turns[i];
      if (t.text.trim().isEmpty) continue;
      final featureIndex = (i * featureCount ~/ turns.length).clamp(
        0,
        featureCount - 1,
      );
      final feature = featureIndex < turnFeatures.length
          ? turnFeatures[featureIndex]
          : (t.feature ?? _TurnFeature.silent());
      enriched.add(
        _TurnCandidate(
          text: t.text.trim(),
          speakerHint: t.speakerHint,
          feature: feature,
        ),
      );
    }

    final lines = _linesFromTurnCandidates(session: session, turns: enriched);

    if (lines.isNotEmpty) return lines.join('\n');
    if (fallbackTranscript.isEmpty) return null;
    final speaker = session.assignSpeaker(
      turnFeatures.isNotEmpty ? turnFeatures.first : _TurnFeature.silent(),
    );
    return 'Speaker $speaker: $fallbackTranscript';
  }

  List<String> _linesFromTurnCandidates({
    required _DiarizationSession session,
    required List<_TurnCandidate> turns,
  }) {
    final normalizedTurns = turns
        .map(
          (t) => _TurnCandidate(
            text: t.text.trim(),
            speakerHint: t.speakerHint,
            feature: t.feature,
          ),
        )
        .where((t) => t.text.isNotEmpty)
        .toList();
    if (normalizedTurns.isEmpty) return const <String>[];

    final assignments = <_TurnAssignment>[];
    for (final turn in normalizedTurns) {
      final feature = turn.feature ?? _TurnFeature.silent();
      // Solo usar speakerHint cuando el motor aporta un ID real (p.ej. etiqueta
      // parseada). No usar hints 0/1 alternados — limitaría a 2 speakers.
      final speaker = turn.speakerHint == null
          ? session.assignSpeaker(feature)
          : session.assignSpeakerFromHint(turn.speakerHint!, feature);
      assignments.add(_TurnAssignment(speakerId: speaker, text: turn.text));
    }

    final smoothed = _smoothAssignments(assignments);
    final compacted = _mergeConsecutiveAssignments(smoothed);
    return compacted.map((a) => 'Speaker ${a.speakerId}: ${a.text}').toList();
  }

  Future<List<_TurnFeature>> _extractTurnFeaturesFromAudio(
    File audioChunk, {
    List<ChannelEnergyWindow> channelWindows = const <ChannelEnergyWindow>[],
  }) async {
    final samples = await _readWavPcm16Mono(audioChunk);
    if (samples.isEmpty) return <_TurnFeature>[_TurnFeature.silent()];
    final extracted = _extractTurnFeatures(
      samples,
      channelWindows: channelWindows,
    );
    if (extracted.isEmpty) return <_TurnFeature>[_TurnFeature.silent()];
    return extracted;
  }

  Future<List<_TurnCandidate>> _tryWhisperLocalTurns({
    required File audioChunk,
    required String language,
  }) async {
    final raw = await WhisperService.instance.transcribeWithTdrzRaw(
      audioChunk,
      language: language == 'auto' ? null : language,
    );
    if (raw.trim().isEmpty) return const <_TurnCandidate>[];

    // Acepta distintas variantes de marcador de cambio de hablante.
    final normalized = raw
        .replaceAll(
          RegExp(
            r'\[\d{2}:\d{2}:\d{2}\.\d{3}\s*-->\s*\d{2}:\d{2}:\d{2}\.\d{3}\]',
          ),
          ' ',
        )
        .replaceAll(
          RegExp(r'\[\s*SPEAKER_TURN\s*\]', caseSensitive: false),
          '[SPEAKER_TURN]',
        )
        .replaceAll(
          RegExp(r'\bspeaker\s*turn\b', caseSensitive: false),
          '[SPEAKER_TURN]',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (!normalized.contains('[SPEAKER_TURN]')) {
      // Si no hay marcador explícito, intentamos parsear líneas por speaker.
      return _parseSpeakerLabeledLines(normalized);
    }

    final parts = normalized
        .split('[SPEAKER_TURN]')
        .map((p) => p.replaceAll(RegExp(r'\s+'), ' ').trim())
        .where((p) => p.isNotEmpty)
        .toList();

    if (parts.isEmpty) return const <_TurnCandidate>[];

    // Solo fronteras de turno: sin hint 0/1. El clustering de sesión asigna IDs.
    return parts.map((p) {
      final parsed = _parseInlineSpeakerPrefix(p);
      if (parsed != null) return parsed;
      return _TurnCandidate(text: p);
    }).toList();
  }

  List<_TurnCandidate> _parseSpeakerLabeledLines(String raw) {
    final lines = raw
        .split(RegExp(r'\r?\n'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    if (lines.isEmpty) return const <_TurnCandidate>[];

    final out = <_TurnCandidate>[];
    for (final line in lines) {
      final parsed = _parseInlineSpeakerPrefix(line);
      if (parsed != null) {
        out.add(parsed);
      }
    }
    return out;
  }

  _TurnCandidate? _parseInlineSpeakerPrefix(String line) {
    final patterns = <RegExp>[
      RegExp(r'^\[\s*speaker\s*[_ ]?(\d+)\s*\]\s*(.+)$', caseSensitive: false),
      RegExp(r'^speaker\s*[_ ]?(\d+)\s*:\s*(.+)$', caseSensitive: false),
      RegExp(r'^\(\s*speaker\s*[_ ]?(\d+)\s*\)\s*(.+)$', caseSensitive: false),
    ];
    for (final rx in patterns) {
      final m = rx.firstMatch(line);
      if (m == null) continue;
      final hint = int.tryParse(m.group(1) ?? '');
      final text = (m.group(2) ?? '').trim();
      if (hint == null || text.isEmpty) continue;
      return _TurnCandidate(text: text, speakerHint: hint);
    }
    return null;
  }

  List<String> _splitSentences(String text) {
    final compact = text
        .replaceAll('\r\n', '\n')
        .replaceAll(RegExp(r'\n+'), ' ')
        .trim();
    if (compact.isEmpty) return const [];

    final parts = compact
        .split(RegExp(r'(?<=[\.!\?])\s+|\s*[;:]\s+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    if (parts.length <= 1) {
      return compact
          .split(RegExp(r'\s{2,}'))
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }

    return parts;
  }

  List<String> _distributeTextAcrossTurns({
    required String rawTranscript,
    required List<String> sentenceFallback,
    required List<_TurnFeature> turns,
  }) {
    final turnCount = math.max(1, turns.length);
    if (turnCount == 1) return <String>[rawTranscript.trim()];

    final words = rawTranscript
        .trim()
        .split(RegExp(r'\s+'))
        .map((w) => w.trim())
        .where((w) => w.isNotEmpty)
        .toList();

    if (words.length < 2) {
      return _distributeSentencesFallback(sentenceFallback, turnCount);
    }

    const minWordsPerTurn = 5;
    final maxTurnsByWords = math.max(1, words.length ~/ minWordsPerTurn);
    final effectiveTurns = math.max(1, math.min(turnCount, maxTurnsByWords));
    final output = List<String>.filled(turnCount, '', growable: false);

    final totalWeight = turns
        .take(effectiveTurns)
        .map((t) => t.weight)
        .fold<double>(0.0, (a, b) => a + b);

    final counts = List<int>.filled(effectiveTurns, 0, growable: false);
    var assigned = 0;

    for (var i = 0; i < effectiveTurns; i++) {
      final weight = totalWeight <= 1e-9
          ? 1.0
          : (turns[i].weight / totalWeight);
      final c = math.max(1, (words.length * weight).round());
      counts[i] = c;
      assigned += c;
    }

    // Ajuste para cuadrar exactamente el número de palabras.
    var diff = words.length - assigned;
    var cursor = 0;
    while (diff != 0 && effectiveTurns > 0) {
      if (diff > 0) {
        counts[cursor % effectiveTurns]++;
        diff--;
      } else if (counts[cursor % effectiveTurns] > 1) {
        counts[cursor % effectiveTurns]--;
        diff++;
      }
      cursor++;
      if (cursor > words.length * 2) break;
    }

    var offset = 0;
    for (var i = 0; i < effectiveTurns; i++) {
      final end = math.min(words.length, offset + counts[i]);
      if (offset < end) {
        output[i] = words.sublist(offset, end).join(' ');
      }
      offset = end;
    }
    if (offset < words.length && effectiveTurns > 0) {
      final tail = words.sublist(offset).join(' ');
      output[effectiveTurns - 1] = output[effectiveTurns - 1].isEmpty
          ? tail
          : '${output[effectiveTurns - 1]} $tail';
    }
    return output;
  }

  List<_TurnAssignment> _smoothAssignments(List<_TurnAssignment> input) {
    if (input.length <= 1) return input.map((a) => a.copy()).toList();
    final out = <_TurnAssignment>[input.first.copy()];

    for (var i = 1; i < input.length; i++) {
      final prev = out.last;
      final cur = input[i].copy();

      if (cur.speakerId != prev.speakerId &&
          _looksLikeContinuation(prev.text, cur.text)) {
        cur.speakerId = prev.speakerId;
      }

      out.add(cur);
    }
    return out;
  }

  List<_TurnAssignment> _mergeConsecutiveAssignments(
    List<_TurnAssignment> input,
  ) {
    if (input.isEmpty) return const <_TurnAssignment>[];
    final out = <_TurnAssignment>[input.first.copy()];
    for (var i = 1; i < input.length; i++) {
      final cur = input[i];
      final prev = out.last;
      if (cur.speakerId == prev.speakerId) {
        out[out.length - 1] = _TurnAssignment(
          speakerId: prev.speakerId,
          text: _joinText(prev.text, cur.text),
        );
      } else {
        out.add(cur.copy());
      }
    }
    return out;
  }

  bool _looksLikeContinuation(String previousText, String currentText) {
    final prev = previousText.trimRight();
    final cur = currentText.trimLeft();
    if (prev.isEmpty || cur.isEmpty) return false;

    final prevWords = prev
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .length;
    final curWords = cur
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .length;

    final shortTail = curWords <= 5;
    final previousLooksIncomplete = prevWords <= 4;

    final prevHasStrongEnd = RegExp(r'[\.\!\?…]["”’\)\]]*$').hasMatch(prev);
    if (prevHasStrongEnd) {
      // Tras fin de frase no absorber el siguiente turno (nuevo speaker).
      // Solo colas tipográficas o conectores de 1–2 palabras.
      if (RegExp(r'^[,.;:\)\]]').hasMatch(cur)) return true;
      if (curWords <= 2 &&
          RegExp(
            r'^(y|e|o|u|and|but|or|so)\b',
            caseSensitive: false,
          ).hasMatch(cur)) {
        return true;
      }
      return false;
    }

    // Frase anterior incompleta: solo fusionar cola corta.
    return previousLooksIncomplete && shortTail;
  }

  List<String> _distributeSentencesFallback(
    List<String> sentences,
    int turnCount,
  ) {
    final out = List<String>.filled(turnCount, '', growable: false);
    if (sentences.isEmpty) return out;
    for (var i = 0; i < sentences.length; i++) {
      final turnIndex = (i * turnCount ~/ sentences.length).clamp(
        0,
        turnCount - 1,
      );
      final text = sentences[i].trim();
      if (text.isEmpty) continue;
      out[turnIndex] = out[turnIndex].isEmpty
          ? text
          : '${out[turnIndex]} $text';
    }
    return out;
  }

  String _joinText(String a, String b) {
    final left = a.trimRight();
    final right = b.trimLeft();
    if (left.isEmpty) return right;
    if (right.isEmpty) return left;
    return '$left $right';
  }

  Future<List<int>> _readWavPcm16Mono(File file) async {
    final bytes = await file.readAsBytes();
    if (bytes.length <= 44) return const [];

    final bd = ByteData.sublistView(bytes);
    final channels = bd.getUint16(22, Endian.little);
    final bitsPerSample = bd.getUint16(34, Endian.little);
    if (bitsPerSample != 16) return const [];

    final pcmOffset = 44;
    final out = <int>[];
    for (var i = pcmOffset; i + 1 < bytes.length; i += 2 * channels) {
      final lo = bytes[i];
      final hi = bytes[i + 1];
      var v = (hi << 8) | lo;
      if (v > 32767) v -= 65536;
      out.add(v);
    }
    return out;
  }

  List<_TurnFeature> _extractTurnFeatures(
    List<int> samples, {
    List<ChannelEnergyWindow> channelWindows = const <ChannelEnergyWindow>[],
  }) {
    // Frame de 20ms a 16kHz.
    const frame = 320;
    const windowSamples = AudioMixerService.windowSamples; // 4000 (~250ms)
    if (samples.length < frame * 2) return const <_TurnFeature>[];

    final feats = <_FrameFeature>[];
    for (var i = 0; i + frame <= samples.length; i += frame) {
      final windowIdx = channelWindows.isEmpty
          ? -1
          : (i ~/ windowSamples).clamp(0, channelWindows.length - 1);
      final micRatio = windowIdx >= 0
          ? channelWindows[windowIdx].micRatio
          : 0.5;
      feats.add(_computeFrameFeature(samples, i, frame, micRatio: micRatio));
    }
    if (feats.isEmpty) return const <_TurnFeature>[];

    final meanEnergy =
        feats.map((f) => f.energy).reduce((a, b) => a + b) / feats.length;
    final silenceThreshold = meanEnergy * 0.48;

    String? dominanceAt(int frameIndex) {
      if (channelWindows.isEmpty) return null;
      final samplePos = frameIndex * frame;
      final wi = (samplePos ~/ windowSamples).clamp(
        0,
        channelWindows.length - 1,
      );
      return channelWindows[wi].dominant;
    }

    final turns = <_TurnFeature>[];
    var current = <_FrameFeature>[];
    var silenceRun = 0;
    String? lastDominance;

    for (var i = 0; i < feats.length; i++) {
      final f = feats[i];
      final voiced = f.energy >= silenceThreshold;
      final dominance = dominanceAt(i);

      if (!voiced) {
        silenceRun++;
        if (silenceRun >= 6 && current.isNotEmpty) {
          turns.add(_TurnFeature.fromFrames(current));
          current = <_FrameFeature>[];
          lastDominance = null;
        }
        continue;
      }

      silenceRun = 0;

      // Frontera fuerte: cambio claro de canal dominante mic ↔ system.
      if (dominance != null &&
          dominance != 'mixed' &&
          lastDominance != null &&
          lastDominance != 'mixed' &&
          dominance != lastDominance &&
          current.length >= 3) {
        turns.add(_TurnFeature.fromFrames(current));
        current = <_FrameFeature>[];
      }

      if (current.isNotEmpty) {
        final prev = current.last;
        final jump = _featureDistance(prev.vector, f.vector);
        // Umbral un poco más sensible para no colapsar voces distintas.
        if (jump > 0.28 && current.length >= 4) {
          turns.add(_TurnFeature.fromFrames(current));
          current = <_FrameFeature>[];
        }
      }
      current.add(f);
      if (dominance != null && dominance != 'mixed') {
        lastDominance = dominance;
      }
    }

    if (current.isNotEmpty) {
      turns.add(_TurnFeature.fromFrames(current));
    }

    return turns;
  }

  _FrameFeature _computeFrameFeature(
    List<int> s,
    int start,
    int size, {
    double micRatio = 0.5,
  }) {
    double sumSq = 0;
    double sumDiff = 0;
    double weightedAbs = 0;
    double absTotal = 0;
    var zc = 0;

    var prev = s[start];
    for (var i = start; i < start + size; i++) {
      final cur = s[i];
      final f = cur / 32768.0;
      sumSq += f * f;
      absTotal += f.abs();

      if (i > start) {
        final d = ((cur - prev).abs() / 32768.0);
        sumDiff += d;
      }
      if ((cur >= 0 && prev < 0) || (cur < 0 && prev >= 0)) {
        zc++;
      }
      final localIdx = (i - start + 1).toDouble();
      weightedAbs += localIdx * f.abs();
      prev = cur;
    }

    final rms = math.sqrt(sumSq / size);
    final zcr = zc / size;
    final slope = sumDiff / size;
    final centroid = absTotal <= 1e-9 ? 0.0 : (weightedAbs / absTotal) / size;

    return _FrameFeature(
      energy: rms,
      vector: <double>[rms, zcr, slope, centroid, micRatio.clamp(0.0, 1.0)],
    );
  }

  double _featureDistance(List<double> a, List<double> b) {
    if (a.length != b.length || a.isEmpty) return 1.0;
    double dot = 0;
    double na = 0;
    double nb = 0;
    for (var i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      na += a[i] * a[i];
      nb += b[i] * b[i];
    }
    if (na <= 1e-9 || nb <= 1e-9) return 1.0;
    final cos = dot / (math.sqrt(na) * math.sqrt(nb));
    return 1.0 - cos.clamp(-1.0, 1.0);
  }
}

class _FrameFeature {
  const _FrameFeature({required this.energy, required this.vector});

  final double energy;
  final List<double> vector;
}

class _TurnFeature {
  const _TurnFeature({required this.vector, required this.weight});

  final List<double> vector;
  final double weight;

  factory _TurnFeature.silent() => const _TurnFeature(
    vector: <double>[0.04, 0.08, 0.04, 0.5, 0.5],
    weight: 1,
  );

  factory _TurnFeature.fromFrames(List<_FrameFeature> frames) {
    if (frames.isEmpty) return _TurnFeature.silent();
    final len = frames.first.vector.length;
    final acc = List<double>.filled(len, 0);
    var w = 0.0;
    for (final f in frames) {
      final fw = (f.energy * 3.0).clamp(0.2, 2.0);
      for (var i = 0; i < len; i++) {
        acc[i] += f.vector[i] * fw;
      }
      w += fw;
    }
    if (w <= 1e-9) return _TurnFeature.silent();
    for (var i = 0; i < len; i++) {
      acc[i] /= w;
    }
    return _TurnFeature(vector: acc, weight: w);
  }
}

class _SpeakerProfile {
  _SpeakerProfile({required this.id, required this.centroid});

  final int id;
  final List<double> centroid;
  int seen = 1;
}

class _DiarizationSession {
  final List<_SpeakerProfile> _profiles = <_SpeakerProfile>[];
  final Map<int, int> _hintToSpeakerId = <int, int>{};
  int _nextId = 1;
  int? _lastSpeaker;
  List<double>? _pendingNovel;
  int _pendingNovelCount = 0;

  int assignSpeakerFromHint(int hint, _TurnFeature turn) {
    final mappedId = _hintToSpeakerId[hint];
    if (mappedId != null) {
      final profile = _profiles.firstWhere(
        (p) => p.id == mappedId,
        orElse: () {
          final created = _SpeakerProfile(
            id: mappedId,
            centroid: List<double>.from(turn.vector),
          );
          _profiles.add(created);
          return created;
        },
      );
      _update(profile, turn.vector);
      _lastSpeaker = profile.id;
      return profile.id;
    }

    final id = _nextId++;
    _hintToSpeakerId[hint] = id;
    _profiles.add(
      _SpeakerProfile(id: id, centroid: List<double>.from(turn.vector)),
    );
    _lastSpeaker = id;
    return id;
  }

  int assignSpeaker(_TurnFeature turn) {
    if (_profiles.isEmpty) {
      final id = _nextId++;
      _profiles.add(
        _SpeakerProfile(id: id, centroid: List<double>.from(turn.vector)),
      );
      _lastSpeaker = id;
      return id;
    }

    _SpeakerProfile? best;
    var bestDist = double.infinity;
    for (final p in _profiles) {
      final d = _distance(p.centroid, turn.vector);
      if (d < bestDist) {
        bestDist = d;
        best = p;
      }
    }

    // Umbrales con histéresis: IDs estables + apertura a Speaker 3+.
    const acceptThreshold = 0.105;
    const keepLastThreshold = 0.145;

    // Primera bifurcación más fácil; siguientes también razonables.
    final novelThreshold = _profiles.length <= 1
        ? 0.135
        : (_profiles.length <= 2 ? 0.155 : 0.175);

    if (best != null && bestDist <= acceptThreshold) {
      _pendingNovel = null;
      _pendingNovelCount = 0;
      _update(best, turn.vector);
      _lastSpeaker = best.id;
      return best.id;
    }

    if (_lastSpeaker != null) {
      final last = _profiles.firstWhere((p) => p.id == _lastSpeaker);
      final dLast = _distance(last.centroid, turn.vector);
      final effectiveKeepLast = _profiles.length <= 1
          ? 0.115
          : keepLastThreshold;
      if (dLast <= effectiveKeepLast) {
        _pendingNovel = null;
        _pendingNovelCount = 0;
        _update(last, turn.vector);
        return last.id;
      }
    }

    // Evita crear un speaker nuevo por un único fallo aislado (salvo 1→2).
    if (bestDist > novelThreshold) {
      if (_pendingNovel != null &&
          _distance(_pendingNovel!, turn.vector) <= 0.125) {
        _pendingNovelCount++;
      } else {
        _pendingNovel = List<double>.from(turn.vector);
        _pendingNovelCount = 1;
      }

      final requiredNovelHits = _profiles.length <= 2 ? 1 : 2;
      if (_pendingNovelCount >= requiredNovelHits) {
        final id = _nextId++;
        final profile = _SpeakerProfile(
          id: id,
          centroid: List<double>.from(turn.vector),
        );
        _profiles.add(profile);
        _pendingNovel = null;
        _pendingNovelCount = 0;
        _lastSpeaker = id;
        return id;
      }
    }

    // Fallback estable: mejor speaker existente.
    final chosen = best ?? _profiles.first;
    if (bestDist <= acceptThreshold) {
      _update(chosen, turn.vector);
    }
    _lastSpeaker = chosen.id;
    return chosen.id;
  }

  void _update(_SpeakerProfile p, List<double> v) {
    if (p.centroid.length != v.length) {
      // Dimensiones nuevas (p.ej. micRatio): reinicia centroide.
      for (var i = 0; i < p.centroid.length && i < v.length; i++) {
        p.centroid[i] = v[i];
      }
      while (p.centroid.length < v.length) {
        p.centroid.add(v[p.centroid.length]);
      }
      p.seen++;
      return;
    }
    final alpha = 1.0 / (p.seen + 1);
    for (var i = 0; i < p.centroid.length; i++) {
      p.centroid[i] = (p.centroid[i] * (1 - alpha)) + (v[i] * alpha);
    }
    p.seen++;
  }

  double _distance(List<double> a, List<double> b) {
    if (a.length != b.length || a.isEmpty) return 1.0;

    // rms, zcr, slope, centroid, micRatio
    const w = <double>[0.22, 0.18, 0.12, 0.10, 0.38];
    double manhattan = 0;
    double dot = 0;
    double na = 0;
    double nb = 0;

    for (var i = 0; i < a.length; i++) {
      final wi = i < w.length ? w[i] : 1.0 / a.length;
      final ai = a[i];
      final bi = b[i];
      manhattan += (ai - bi).abs() * wi;
      dot += ai * bi * wi;
      na += ai * ai * wi;
      nb += bi * bi * wi;
    }

    if (na <= 1e-9 || nb <= 1e-9) return manhattan.clamp(0.0, 1.0);
    final cos = (dot / (math.sqrt(na) * math.sqrt(nb))).clamp(-1.0, 1.0);
    final angular = 1.0 - cos;

    var dist = (manhattan * 0.62) + (angular * 0.38);

    // Canal muy distinto (mic vs system) → empujar a novel speaker.
    if (a.length > 4 && b.length > 4) {
      final micDelta = (a[4] - b[4]).abs();
      if (micDelta > 0.45) {
        dist = math.max(dist, 0.22 + (micDelta - 0.45) * 0.5);
      }
    }

    return dist.clamp(0.0, 1.0);
  }
}

class _TurnAssignment {
  _TurnAssignment({required this.speakerId, required this.text});

  int speakerId;
  final String text;

  _TurnAssignment copy() => _TurnAssignment(speakerId: speakerId, text: text);
}

class _TurnCandidate {
  _TurnCandidate({required this.text, this.speakerHint, this.feature});

  final String text;
  final int? speakerHint;
  final _TurnFeature? feature;
}
