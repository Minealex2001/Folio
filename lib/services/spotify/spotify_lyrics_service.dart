import 'dart:convert';

import 'package:http/http.dart' as http;

/// Línea de letra sincronizada (LRC).
class SpotifyLyricLine {
  const SpotifyLyricLine({required this.ms, required this.text});

  final int ms;
  final String text;
}

/// Letras sincronizadas vía LRCLIB (Spotify no expone lyrics en Web API).
class SpotifyLyricsService {
  SpotifyLyricsService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  final Map<String, List<SpotifyLyricLine>> _cache = {};

  Future<List<SpotifyLyricLine>> fetchSyncedLyrics({
    required String trackId,
    required String title,
    required String artist,
    required int durationMs,
  }) async {
    final key = trackId.trim().isNotEmpty
        ? trackId.trim()
        : '${artist.trim()}|${title.trim()}|$durationMs';
    final cached = _cache[key];
    if (cached != null) return cached;

    final query = <String, String>{
      'track_name': title.trim(),
      'artist_name': artist.trim(),
      if (durationMs > 0) 'duration': '${(durationMs / 1000).round()}',
    };
    try {
      final resp = await _client
          .get(Uri.https('lrclib.net', '/api/get', query))
          .timeout(const Duration(seconds: 8));
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        _cache[key] = const [];
        return const [];
      }
      final decoded = jsonDecode(resp.body);
      if (decoded is! Map) {
        _cache[key] = const [];
        return const [];
      }
      final synced = (decoded['syncedLyrics'] as String? ?? '').trim();
      final plain = (decoded['plainLyrics'] as String? ?? '').trim();
      final lines = synced.isNotEmpty
          ? parseLrc(synced)
          : (plain.isEmpty
              ? const <SpotifyLyricLine>[]
              : plain
                  .split('\n')
                  .where((l) => l.trim().isNotEmpty)
                  .map((l) => SpotifyLyricLine(ms: 0, text: l.trim()))
                  .toList(growable: false));
      _cache[key] = lines;
      return lines;
    } catch (_) {
      _cache[key] = const [];
      return const [];
    }
  }

  /// Parsea formato LRC `[mm:ss.xx] texto`.
  static List<SpotifyLyricLine> parseLrc(String raw) {
    final re = RegExp(r'\[(\d{1,2}):(\d{2})(?:\.(\d{1,3}))?\](.*)');
    final out = <SpotifyLyricLine>[];
    for (final line in raw.split('\n')) {
      final m = re.firstMatch(line.trim());
      if (m == null) continue;
      final min = int.tryParse(m.group(1) ?? '') ?? 0;
      final sec = int.tryParse(m.group(2) ?? '') ?? 0;
      final fracRaw = m.group(3) ?? '0';
      final frac = int.tryParse(fracRaw.padRight(3, '0').substring(0, 3)) ?? 0;
      final text = (m.group(4) ?? '').trim();
      if (text.isEmpty) continue;
      out.add(SpotifyLyricLine(ms: min * 60000 + sec * 1000 + frac, text: text));
    }
    out.sort((a, b) => a.ms.compareTo(b.ms));
    return out;
  }

  static int activeLineIndex(List<SpotifyLyricLine> lines, int progressMs) {
    if (lines.isEmpty) return -1;
    var idx = 0;
    for (var i = 0; i < lines.length; i++) {
      if (lines[i].ms <= progressMs) {
        idx = i;
      } else {
        break;
      }
    }
    return idx;
  }
}
