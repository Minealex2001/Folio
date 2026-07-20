import 'dart:convert';

import 'package:http/http.dart' as http;

/// Tipo de recurso Spotify (track, album, playlist, episode).
class FolioSpotifyRef {
  const FolioSpotifyRef({required this.type, required this.id});

  final String type;
  final String id;
}

/// Parsea URLs `open.spotify.com` / `spotify:` y devuelve referencia o `null`.
FolioSpotifyRef? folioSpotifyRefFromUrl(String? raw) {
  if (raw == null) return null;
  final u = raw.trim();
  if (u.isEmpty) return null;

  if (u.startsWith('spotify:')) {
    final parts = u.split(':');
    if (parts.length >= 3) {
      final type = parts[1];
      final id = parts[2].split('?').first;
      if (_isValidSpotifyType(type) && id.isNotEmpty) {
        return FolioSpotifyRef(type: type, id: id);
      }
    }
    return null;
  }

  final uri = Uri.tryParse(u);
  if (uri == null || !uri.hasScheme) return null;
  if (uri.scheme != 'http' && uri.scheme != 'https') return null;
  final host = uri.host.toLowerCase();
  if (host != 'open.spotify.com' && !host.endsWith('.spotify.com')) {
    return null;
  }
  final segments = uri.pathSegments;
  if (segments.length < 2) return null;
  final type = segments[0];
  final id = segments[1].split('?').first;
  if (!_isValidSpotifyType(type) || id.isEmpty) return null;
  return FolioSpotifyRef(type: type, id: id);
}

bool _isValidSpotifyType(String type) =>
    type == 'track' ||
    type == 'album' ||
    type == 'playlist' ||
    type == 'episode' ||
    type == 'show' ||
    type == 'artist';

String folioSpotifyEmbedUrl(String type, String id) =>
    'https://open.spotify.com/embed/$type/$id';

String folioSpotifyOpenUrl(String type, String id) =>
    'https://open.spotify.com/$type/$id';

/// URI de recurso para la Web API (`spotify:track:…`, `spotify:playlist:…`, …).
String folioSpotifyUri(String type, String id) => 'spotify:$type:$id';

/// Metadatos públicos vía oEmbed (sin auth).
class SpotifyOEmbedData {
  const SpotifyOEmbedData({this.title, this.thumbnailUrl, this.html});

  final String? title;
  final String? thumbnailUrl;
  final String? html;
}

Future<SpotifyOEmbedData?> fetchSpotifyOEmbed(String pageUrl) async {
  final ref = folioSpotifyRefFromUrl(pageUrl);
  if (ref == null) return null;
  final canonical = folioSpotifyOpenUrl(ref.type, ref.id);
  final uri = Uri.https('open.spotify.com', '/oembed', {'url': canonical});
  try {
    final resp = await http.get(uri).timeout(const Duration(seconds: 12));
    if (resp.statusCode < 200 || resp.statusCode >= 300) return null;
    final decoded = jsonDecode(resp.body);
    if (decoded is! Map) return null;
    final m = Map<String, dynamic>.from(decoded);
    return SpotifyOEmbedData(
      title: (m['title'] as String?)?.trim(),
      thumbnailUrl: (m['thumbnail_url'] as String?)?.trim(),
      html: (m['html'] as String?)?.trim(),
    );
  } catch (_) {
    return null;
  }
}
