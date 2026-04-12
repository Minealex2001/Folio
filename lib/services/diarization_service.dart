import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

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

  /// Diarización local sin backend.
  ///
  /// Estrategia:
  /// 1) Segmenta texto por frases.
  /// 2) Detecta cambios de voz aproximados en el WAV por energia + ZCR.
  /// 3) Asigna etiquetas Speaker 1/2 alternando en los turnos estimados.
  Future<String?> diarizeChunk({
    required File audioChunk,
    required String transcript,
    required String language,
    required String sessionId,
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

      // Motor principal: Whisper local con tinydiarize.
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

      // Fallback: heurístico local actual.
      final sentences = _splitSentences(safeTranscript);
      if (sentences.isEmpty) return null;

      final turnTexts = _distributeTextAcrossTurns(
        rawTranscript: safeTranscript,
        sentenceFallback: sentences,
        turns: await _extractTurnFeaturesFromAudio(audioChunk),
      );

      final turnCandidates = turnTexts
          .map((t) => _TurnCandidate(text: t))
          .toList();

      final lines = await _linesFromTurns(
        session: session,
        audioChunk: audioChunk,
        turns: turnCandidates,
      );

      if (lines.isEmpty) {
        final speaker = session.assignSpeaker(_TurnFeature.silent());
        return 'Speaker $speaker: $safeTranscript';
      }
      return lines.join('\n');
    } catch (e) {
      lastError = e.toString();
      return null;
    }
  }

  Future<String?> _renderWithSessionSpeakers({
    required _DiarizationSession session,
    required File audioChunk,
    required List<_TurnCandidate> turns,
    required String fallbackTranscript,
  }) async {
    final lines = await _linesFromTurns(
      session: session,
      audioChunk: audioChunk,
      turns: turns,
    );

    if (lines.isNotEmpty) return lines.join('\n');
    if (fallbackTranscript.isEmpty) return null;
    final speaker = session.assignSpeaker(_TurnFeature.silent());
    return 'Speaker $speaker: $fallbackTranscript';
  }

  Future<List<String>> _linesFromTurns({
    required _DiarizationSession session,
    required File audioChunk,
    required List<_TurnCandidate> turns,
  }) async {
    final normalizedTurns = turns
        .map(
          (t) =>
              _TurnCandidate(text: t.text.trim(), speakerHint: t.speakerHint),
        )
        .where((t) => t.text.isNotEmpty)
        .toList();
    if (normalizedTurns.isEmpty) return const <String>[];

    final turnFeatures = await _extractTurnFeaturesFromAudio(audioChunk);
    final featureCount = math.max(1, turnFeatures.length);

    final assignments = <_TurnAssignment>[];
    for (var i = 0; i < normalizedTurns.length; i++) {
      final featureIndex = (i * featureCount ~/ normalizedTurns.length).clamp(
        0,
        featureCount - 1,
      );
      final feature = featureIndex < turnFeatures.length
          ? turnFeatures[featureIndex]
          : _TurnFeature.silent();
      final turn = normalizedTurns[i];
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
    File audioChunk,
  ) async {
    final samples = await _readWavPcm16Mono(audioChunk);
    if (samples.isEmpty) return <_TurnFeature>[_TurnFeature.silent()];
    final extracted = _extractTurnFeatures(samples);
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

    final labeled = <_TurnCandidate>[];
    for (var i = 0; i < parts.length; i++) {
      final p = parts[i];
      final parsed = _parseInlineSpeakerPrefix(p);
      if (parsed != null) {
        labeled.add(parsed);
      } else {
        // Cuando Whisper marca cambio de turno pero no ID de speaker,
        // alternamos hints para evitar colapso inmediato al heurístico.
        labeled.add(_TurnCandidate(text: p, speakerHint: i % 2));
      }
    }
    return labeled;
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
      // Fallback para transcripciones extremadamente cortas.
      return _distributeSentencesFallback(sentenceFallback, turnCount);
    }

    // Evita explosión de líneas: si hay muchos turnos de audio, limitarlos
    // en función de la cantidad de palabras transcritas.
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

    while (assigned > words.length) {
      for (var i = effectiveTurns - 1; i >= 0 && assigned > words.length; i--) {
        if (counts[i] > 1) {
          counts[i]--;
          assigned--;
        }
      }
      if (counts.every((c) => c == 1)) break;
    }

    while (assigned < words.length) {
      for (var i = 0; i < effectiveTurns && assigned < words.length; i++) {
        counts[i]++;
        assigned++;
      }
    }

    var cursor = 0;
    for (var i = 0; i < effectiveTurns; i++) {
      final take = counts[i];
      if (take <= 0 || cursor >= words.length) continue;
      final end = math.min(words.length, cursor + take);
      output[i] = words.sublist(cursor, end).join(' ').trim();
      cursor = end;
    }

    if (cursor < words.length) {
      final rest = words.sublist(cursor).join(' ').trim();
      final idx = effectiveTurns - 1;
      output[idx] = output[idx].isEmpty ? rest : '${output[idx]} $rest';
    }

    return output;
  }

  String _joinText(String left, String right) {
    final a = left.trimRight();
    final b = right.trimLeft();
    if (a.isEmpty) return b;
    if (b.isEmpty) return a;
    if (a.endsWith('-')) return '$a$b';
    if (RegExp(r'^[,.;:!?\)]').hasMatch(b)) return '$a$b';
    return '$a $b';
  }

  List<_TurnAssignment> _smoothAssignments(List<_TurnAssignment> input) {
    if (input.length <= 1) return input;
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

    // Solo consideramos continuidad cuando el nuevo bloque es corto (cola de frase)
    // o cuando el bloque anterior era claramente incompleto.
    final shortTail = curWords <= 5;
    final previousLooksIncomplete = prevWords <= 4;

    final prevHasStrongEnd = RegExp(r'[\.\!\?…]["”’\)\]]*$').hasMatch(prev);
    if (!prevHasStrongEnd) {
      if (!shortTail && !previousLooksIncomplete) return false;
      return true;
    }

    if (RegExp(r'^[a-záéíóúñü]').hasMatch(cur)) return shortTail;
    if (RegExp(r'^[,.;:\)\]]').hasMatch(cur)) return true;
    if (RegExp(
      r'^(y|e|o|u|de|que|pero|pues|entonces|ademas|además|and|but|or|so|because|then)\b',
      caseSensitive: false,
    ).hasMatch(cur)) {
      return shortTail || previousLooksIncomplete;
    }

    if (previousLooksIncomplete && shortTail) return true;

    return false;
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

  Future<List<int>> _readWavPcm16Mono(File file) async {
    final bytes = await file.readAsBytes();
    if (bytes.length <= 44) return const [];

    final bd = ByteData.sublistView(bytes);
    // Header WAV mínimo: canal en offset 22, bits por sample en 34, data en 44.
    final channels = bd.getUint16(22, Endian.little);
    final bitsPerSample = bd.getUint16(34, Endian.little);
    if (bitsPerSample != 16) return const [];

    final pcmOffset = 44;
    final out = <int>[];
    for (var i = pcmOffset; i + 1 < bytes.length; i += 2 * channels) {
      // Si es estéreo, tomamos canal 0.
      final lo = bytes[i];
      final hi = bytes[i + 1];
      var v = (hi << 8) | lo;
      if (v > 32767) v -= 65536;
      out.add(v);
    }
    return out;
  }

  List<_TurnFeature> _extractTurnFeatures(List<int> samples) {
    // Frame de 20ms a 16kHz.
    const frame = 320;
    if (samples.length < frame * 2) return const <_TurnFeature>[];

    final feats = <_FrameFeature>[];
    for (var i = 0; i + frame <= samples.length; i += frame) {
      feats.add(_computeFrameFeature(samples, i, frame));
    }
    if (feats.isEmpty) return const <_TurnFeature>[];

    final meanEnergy =
        feats.map((f) => f.energy).reduce((a, b) => a + b) / feats.length;
    final silenceThreshold = meanEnergy * 0.48;

    final turns = <_TurnFeature>[];
    var current = <_FrameFeature>[];
    var silenceRun = 0;

    for (var i = 0; i < feats.length; i++) {
      final f = feats[i];
      final voiced = f.energy >= silenceThreshold;

      if (!voiced) {
        silenceRun++;
        if (silenceRun >= 8 && current.isNotEmpty) {
          turns.add(_TurnFeature.fromFrames(current));
          current = <_FrameFeature>[];
        }
        continue;
      }

      silenceRun = 0;
      if (current.isNotEmpty) {
        final prev = current.last;
        final jump = _featureDistance(prev.vector, f.vector);
        if (jump > 0.33 && current.length >= 4) {
          turns.add(_TurnFeature.fromFrames(current));
          current = <_FrameFeature>[];
        }
      }
      current.add(f);
    }

    if (current.isNotEmpty) {
      turns.add(_TurnFeature.fromFrames(current));
    }

    return turns;
  }

  _FrameFeature _computeFrameFeature(List<int> s, int start, int size) {
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
      // Aproximación de centroid espectral con peso por índice.
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
      vector: <double>[rms, zcr, slope, centroid],
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

  factory _TurnFeature.silent() =>
      const _TurnFeature(vector: <double>[0.04, 0.08, 0.04, 0.5], weight: 1);

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

    // Umbrales con histéresis para mantener IDs estables y permitir multi-speaker.
    const acceptThreshold = 0.115;
    const keepLastThreshold = 0.165;

    // Cuando solo hay un speaker, bajar la barrera para abrir el segundo.
    final novelThreshold = _profiles.length <= 1 ? 0.155 : 0.235;

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
      // Para la primera bifurcación (crear speaker 2), evitamos pegarnos tanto al último.
      final effectiveKeepLast = _profiles.length <= 1
          ? 0.125
          : keepLastThreshold;
      if (dLast <= effectiveKeepLast) {
        _pendingNovel = null;
        _pendingNovelCount = 0;
        _update(last, turn.vector);
        return last.id;
      }
    }

    // Evita crear un speaker nuevo por un único fallo aislado.
    if (bestDist > novelThreshold) {
      if (_pendingNovel != null &&
          _distance(_pendingNovel!, turn.vector) <= 0.135) {
        _pendingNovelCount++;
      } else {
        _pendingNovel = List<double>.from(turn.vector);
        _pendingNovelCount = 1;
      }

      final requiredNovelHits = _profiles.length <= 1 ? 1 : 2;
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
    // No actualizamos centroides en fallback incierto para no arrastrar un speaker
    // y terminar absorbiendo voces distintas en Speaker 1.
    final chosen = best ?? _profiles.first;
    if (bestDist <= acceptThreshold) {
      _update(chosen, turn.vector);
    }
    _lastSpeaker = chosen.id;
    return chosen.id;
  }

  void _update(_SpeakerProfile p, List<double> v) {
    final alpha = 1.0 / (p.seen + 1);
    for (var i = 0; i < p.centroid.length; i++) {
      p.centroid[i] = (p.centroid[i] * (1 - alpha)) + (v[i] * alpha);
    }
    p.seen++;
  }

  double _distance(List<double> a, List<double> b) {
    if (a.length != b.length || a.isEmpty) return 1.0;

    // Pesos por dimensión: energía y zcr suelen diferenciar mejor voces.
    const w = <double>[0.34, 0.30, 0.22, 0.14];
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

    // Distancia híbrida: más sensible que coseno puro.
    return (manhattan * 0.62) + (angular * 0.38);
  }
}

class _TurnAssignment {
  _TurnAssignment({required this.speakerId, required this.text});

  int speakerId;
  final String text;

  _TurnAssignment copy() => _TurnAssignment(speakerId: speakerId, text: text);
}

class _TurnCandidate {
  _TurnCandidate({required this.text, this.speakerHint});

  final String text;
  final int? speakerHint;
}
