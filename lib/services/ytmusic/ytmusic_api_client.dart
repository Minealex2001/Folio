import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config/folio_backend_config.dart';
import '../../models/ytmusic_integration_state.dart';
import '../folio_cloud/folio_cloud_identity.dart';
import 'ytmusic_auth_service.dart';

class YtMusicTrack {
  const YtMusicTrack({
    required this.videoId,
    required this.title,
    this.artists = const [],
    this.albumArtUrl,
    this.durationMs = 0,
    this.playlistId,
  });

  final String videoId;
  final String title;
  final List<String> artists;
  final String? albumArtUrl;
  final int durationMs;
  final String? playlistId;

  String get artistLabel => artists.where((a) => a.trim().isNotEmpty).join(', ');

  String get watchUrl => 'https://music.youtube.com/watch?v=$videoId';
}

class YtMusicPlaylistSummary {
  const YtMusicPlaylistSummary({
    required this.id,
    required this.title,
    this.thumbUrl,
    this.trackCount,
  });

  final String id;
  final String title;
  final String? thumbUrl;
  final int? trackCount;
}

class YtMusicSearchResults {
  const YtMusicSearchResults({
    this.songs = const [],
    this.playlists = const [],
    this.albums = const [],
  });

  final List<YtMusicTrack> songs;
  final List<YtMusicPlaylistSummary> playlists;
  final List<YtMusicPlaylistSummary> albums;
}

/// Cliente YouTube Data API v3 vía FolioBackend (OAuth, como Spotify).
class YtMusicApiClient {
  YtMusicApiClient({
    required this.connection,
    required this.onConnectionUpdated,
    http.Client? httpClient,
    YtMusicAuthService? auth,
  })  : _http = httpClient ?? http.Client(),
        _auth = auth ?? YtMusicAuthService();

  YtMusicConnection connection;
  final void Function(YtMusicConnection updated) onConnectionUpdated;
  final http.Client _http;
  final YtMusicAuthService _auth;

  Future<YtMusicConnection> _ensureToken() async {
    if (!connection.isExpired) return connection;
    final refreshed = await _auth.refresh(connection);
    connection = refreshed;
    onConnectionUpdated(refreshed);
    return refreshed;
  }

  Future<Map<String, dynamic>> dataApi(
    String path,
    Map<String, String> query,
  ) async {
    final conn = await _ensureToken();
    if (conn.isBrowser || conn.accessToken.isEmpty) {
      throw StateError(
        'ytmusic_reconnect: Conecta YouTube Music de nuevo (Ajustes → Conectar).',
      );
    }
    if (!folioCloudHasSession()) {
      throw StateError('Folio Cloud session required for YouTube Music.');
    }
    final idToken = await folioCloudBearerToken();
    if (idToken == null || idToken.isEmpty) {
      throw StateError('Folio Cloud session required for YouTube Music.');
    }
    final resp = await _http.post(
      Uri.parse(
        '${FolioBackendConfig.apiV1Prefix}/integrations/ytmusic/data-api-proxy',
      ),
      headers: {
        'content-type': 'application/json',
        'authorization': 'Bearer $idToken',
      },
      body: jsonEncode({
        'accessToken': conn.accessToken,
        'path': path,
        'query': query,
      }),
    );
    final map = jsonDecode(resp.body);
    if (map is! Map) throw StateError('ytmusic_bad_proxy');
    final status = (map['status'] as num?)?.toInt() ?? resp.statusCode;
    final payload = map['body'];
    if (status < 200 || status >= 300) {
      throw StateError('ytmusic_data_api_$status: $payload');
    }
    if (payload is Map) return Map<String, dynamic>.from(payload);
    return <String, dynamic>{'raw': payload};
  }

  Future<YtMusicSearchResults> search(String query) async {
    final q = query.trim();
    if (q.isEmpty) return const YtMusicSearchResults();
    final videos = await dataApi('search', {
      'part': 'snippet',
      'type': 'video',
      'videoCategoryId': '10',
      'maxResults': '25',
      'q': q,
    });
    final playlistsJson = await dataApi('search', {
      'part': 'snippet',
      'type': 'playlist',
      'maxResults': '15',
      'q': q,
    });
    return YtMusicSearchResults(
      songs: _tracksFromSearch(videos),
      playlists: _playlistsFromSearch(playlistsJson),
    );
  }

  Future<List<YtMusicPlaylistSummary>> libraryPlaylists() async {
    final json = await dataApi('playlists', {
      'part': 'snippet,contentDetails',
      'mine': 'true',
      'maxResults': '50',
    });
    final items = json['items'];
    if (items is! List) return const [];
    final out = <YtMusicPlaylistSummary>[];
    for (final item in items) {
      if (item is! Map) continue;
      final m = Map<String, dynamic>.from(item);
      final id = _str(m['id']);
      final snippet = m['snippet'];
      if (id.isEmpty || snippet is! Map) continue;
      final sn = Map<String, dynamic>.from(snippet);
      final title = _str(sn['title']);
      if (title.isEmpty) continue;
      final details = m['contentDetails'];
      int? count;
      if (details is Map) {
        count = int.tryParse(_str(details['itemCount']));
      }
      out.add(
        YtMusicPlaylistSummary(
          id: id,
          title: title,
          thumbUrl: _thumbFromSnippet(sn),
          trackCount: count,
        ),
      );
    }
    return out;
  }

  Future<List<YtMusicTrack>> browseTracks(String playlistId) async {
    var id = playlistId.trim();
    if (id.startsWith('VL')) id = id.substring(2);
    final json = await dataApi('playlistItems', {
      'part': 'snippet,contentDetails',
      'playlistId': id,
      'maxResults': '50',
    });
    return _tracksFromPlaylistItems(json, playlistId: id);
  }

  Future<List<YtMusicTrack>> likedSongs() async {
    final json = await dataApi('videos', {
      'part': 'snippet,contentDetails',
      'myRating': 'like',
      'maxResults': '50',
    });
    return _tracksFromVideos(json);
  }

  Future<YtMusicTrack?> playerMeta(String videoId) async {
    final json = await dataApi('videos', {
      'part': 'snippet,contentDetails',
      'id': videoId,
    });
    final tracks = _tracksFromVideos(json);
    return tracks.isEmpty ? null : tracks.first;
  }

  static List<YtMusicTrack> _tracksFromSearch(Map<String, dynamic> json) {
    final items = json['items'];
    if (items is! List) return const [];
    final out = <YtMusicTrack>[];
    for (final item in items) {
      if (item is! Map) continue;
      final m = Map<String, dynamic>.from(item);
      final idObj = m['id'];
      String videoId = '';
      if (idObj is Map) {
        videoId = _str(idObj['videoId']);
      } else {
        videoId = _str(idObj);
      }
      final snippet = m['snippet'];
      if (videoId.isEmpty || snippet is! Map) continue;
      final sn = Map<String, dynamic>.from(snippet);
      final title = _str(sn['title']);
      if (title.isEmpty) continue;
      out.add(
        YtMusicTrack(
          videoId: videoId,
          title: title,
          artists: [_str(sn['channelTitle'])].where((a) => a.isNotEmpty).toList(),
          albumArtUrl: _thumbFromSnippet(sn),
        ),
      );
    }
    return _uniqueTracks(out);
  }

  static List<YtMusicPlaylistSummary> _playlistsFromSearch(
    Map<String, dynamic> json,
  ) {
    final items = json['items'];
    if (items is! List) return const [];
    final out = <YtMusicPlaylistSummary>[];
    for (final item in items) {
      if (item is! Map) continue;
      final m = Map<String, dynamic>.from(item);
      final idObj = m['id'];
      String playlistId = '';
      if (idObj is Map) {
        playlistId = _str(idObj['playlistId']);
      } else {
        playlistId = _str(idObj);
      }
      final snippet = m['snippet'];
      if (playlistId.isEmpty || snippet is! Map) continue;
      final sn = Map<String, dynamic>.from(snippet);
      final title = _str(sn['title']);
      if (title.isEmpty) continue;
      out.add(
        YtMusicPlaylistSummary(
          id: playlistId,
          title: title,
          thumbUrl: _thumbFromSnippet(sn),
        ),
      );
    }
    return out;
  }

  static List<YtMusicTrack> _tracksFromPlaylistItems(
    Map<String, dynamic> json, {
    String? playlistId,
  }) {
    final items = json['items'];
    if (items is! List) return const [];
    final out = <YtMusicTrack>[];
    for (final item in items) {
      if (item is! Map) continue;
      final m = Map<String, dynamic>.from(item);
      final details = m['contentDetails'];
      final snippet = m['snippet'];
      if (snippet is! Map) continue;
      final sn = Map<String, dynamic>.from(snippet);
      var videoId = '';
      if (details is Map) {
        videoId = _str(details['videoId']);
      }
      if (videoId.isEmpty) {
        final res = sn['resourceId'];
        if (res is Map) videoId = _str(res['videoId']);
      }
      final title = _str(sn['title']);
      if (videoId.isEmpty || title.isEmpty || title == 'Private video') continue;
      out.add(
        YtMusicTrack(
          videoId: videoId,
          title: title,
          artists: [_str(sn['videoOwnerChannelTitle'])]
              .where((a) => a.isNotEmpty)
              .toList(),
          albumArtUrl: _thumbFromSnippet(sn),
          playlistId: playlistId,
        ),
      );
    }
    return _uniqueTracks(out);
  }

  static List<YtMusicTrack> _tracksFromVideos(Map<String, dynamic> json) {
    final items = json['items'];
    if (items is! List) return const [];
    final out = <YtMusicTrack>[];
    for (final item in items) {
      if (item is! Map) continue;
      final m = Map<String, dynamic>.from(item);
      final videoId = _str(m['id']);
      final snippet = m['snippet'];
      if (videoId.isEmpty || snippet is! Map) continue;
      final sn = Map<String, dynamic>.from(snippet);
      final title = _str(sn['title']);
      if (title.isEmpty) continue;
      final details = m['contentDetails'];
      var durationMs = 0;
      if (details is Map) {
        durationMs = _iso8601DurationMs(_str(details['duration']));
      }
      out.add(
        YtMusicTrack(
          videoId: videoId,
          title: title,
          artists: [_str(sn['channelTitle'])].where((a) => a.isNotEmpty).toList(),
          albumArtUrl: _thumbFromSnippet(sn),
          durationMs: durationMs,
        ),
      );
    }
    return _uniqueTracks(out);
  }

  static List<YtMusicTrack> _uniqueTracks(List<YtMusicTrack> input) {
    final seen = <String>{};
    final out = <YtMusicTrack>[];
    for (final t in input) {
      if (seen.add(t.videoId)) out.add(t);
    }
    return out;
  }

  static String _str(Object? v) {
    if (v == null) return '';
    if (v is String) return v.trim();
    return '$v'.trim();
  }

  static String? _thumbFromSnippet(Map<String, dynamic> snippet) {
    final thumbs = snippet['thumbnails'];
    if (thumbs is! Map) return null;
    for (final key in ['maxres', 'standard', 'high', 'medium', 'default']) {
      final t = thumbs[key];
      if (t is Map) {
        final url = _str(t['url']);
        if (url.isNotEmpty) return url;
      }
    }
    return null;
  }

  /// Parsea duraciones ISO-8601 tipo `PT3M21S`.
  static int _iso8601DurationMs(String raw) {
    if (raw.isEmpty) return 0;
    final m = RegExp(r'^PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?$').firstMatch(raw);
    if (m == null) return 0;
    final h = int.tryParse(m.group(1) ?? '') ?? 0;
    final min = int.tryParse(m.group(2) ?? '') ?? 0;
    final s = int.tryParse(m.group(3) ?? '') ?? 0;
    return ((h * 3600) + (min * 60) + s) * 1000;
  }
}
