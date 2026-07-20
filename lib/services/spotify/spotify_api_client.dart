import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

import '../../firebase_options.dart';
import '../../models/spotify_integration_state.dart';
import '../folio_cloud/folio_cloud_callable.dart';
import 'spotify_auth_service.dart';

/// Resultado de la reproducción actual en Spotify.
class SpotifyPlaybackSnapshot {
  const SpotifyPlaybackSnapshot({
    this.trackName,
    this.artistName,
    this.albumArtUrl,
    this.isPlaying = false,
    this.progressMs = 0,
    this.durationMs = 0,
    this.deviceName,
    this.trackUri,
    this.volumePercent,
    this.premiumRequired = false,
    this.noActiveDevice = false,
    this.noContent = false,
  });

  final String? trackName;
  final String? artistName;
  final String? albumArtUrl;
  final bool isPlaying;
  final int progressMs;
  final int durationMs;
  final String? deviceName;
  final String? trackUri;
  /// Volumen del dispositivo activo (0–100), si Spotify lo reporta.
  final int? volumePercent;
  final bool premiumRequired;
  final bool noActiveDevice;
  final bool noContent;

  static const empty = SpotifyPlaybackSnapshot(noContent: true);

  SpotifyPlaybackSnapshot copyWith({
    String? trackName,
    String? artistName,
    String? albumArtUrl,
    bool? isPlaying,
    int? progressMs,
    int? durationMs,
    String? deviceName,
    String? trackUri,
    int? volumePercent,
    bool? premiumRequired,
    bool? noActiveDevice,
    bool? noContent,
  }) {
    return SpotifyPlaybackSnapshot(
      trackName: trackName ?? this.trackName,
      artistName: artistName ?? this.artistName,
      albumArtUrl: albumArtUrl ?? this.albumArtUrl,
      isPlaying: isPlaying ?? this.isPlaying,
      progressMs: progressMs ?? this.progressMs,
      durationMs: durationMs ?? this.durationMs,
      deviceName: deviceName ?? this.deviceName,
      trackUri: trackUri ?? this.trackUri,
      volumePercent: volumePercent ?? this.volumePercent,
      premiumRequired: premiumRequired ?? this.premiumRequired,
      noActiveDevice: noActiveDevice ?? this.noActiveDevice,
      noContent: noContent ?? this.noContent,
    );
  }
}

class SpotifyPlaylistSummary {
  const SpotifyPlaylistSummary({
    required this.id,
    required this.name,
    required this.uri,
    this.imageUrl,
    this.trackCount,
  });

  final String id;
  final String name;
  final String uri;
  final String? imageUrl;
  final int? trackCount;
}

/// Página de resultados de playlists del usuario.
class SpotifyPlaylistPage {
  const SpotifyPlaylistPage({
    required this.items,
    required this.hasMore,
    required this.nextOffset,
  });

  final List<SpotifyPlaylistSummary> items;
  final bool hasMore;
  final int nextOffset;
}

typedef SpotifyTokenRefreshCallback = Future<SpotifyConnection> Function(
  SpotifyConnection updated,
);

/// Cliente HTTP para la Web API de Spotify con refresh automático de token.
class SpotifyApiClient {
  SpotifyApiClient({
    required SpotifyConnection connection,
    required this.onConnectionUpdated,
    http.Client? client,
    SpotifyAuthService? authService,
  })  : _connection = connection,
        _client = client ?? http.Client(),
        _auth = authService ?? SpotifyAuthService(client: client);

  SpotifyConnection _connection;
  final SpotifyTokenRefreshCallback onConnectionUpdated;
  final http.Client _client;
  final SpotifyAuthService _auth;

  SpotifyConnection get connection => _connection;

  /// Actualiza el token en el cliente existente sin recrearlo.
  void updateConnection(SpotifyConnection updated) {
    _connection = updated;
  }

  Future<SpotifyConnection> _ensureFreshToken() async {
    if (!_connection.isExpired) return _connection;
    final tokenJson = await _auth.exchangeRefreshToken(
      refreshToken: _connection.refreshToken,
    );
    final accessToken = (tokenJson['access_token'] as String? ?? '').trim();
    if (accessToken.isEmpty) {
      throw StateError('Refresh Spotify no devolvió access_token.');
    }
    final expiresIn = (tokenJson['expires_in'] as num?)?.toInt() ?? 3600;
    final newRefresh =
        (tokenJson['refresh_token'] as String? ?? _connection.refreshToken).trim();
    final updated = _connection.copyWith(
      accessToken: accessToken,
      refreshToken: newRefresh,
      expiresAt: DateTime.now().toUtc().add(Duration(seconds: expiresIn)),
    );
    _connection = updated;
    await onConnectionUpdated(updated);
    return updated;
  }

  Future<http.Response> _request(
    String method,
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    await _ensureFreshToken();
    if (kIsWeb) {
      return _proxyViaCloud(method, uri, headers: headers, body: body);
    }
    final h = <String, String>{
      'authorization': 'Bearer ${_connection.accessToken}',
      ...?headers,
    };
    switch (method.toUpperCase()) {
      case 'GET':
        return _client.get(uri, headers: h).timeout(const Duration(seconds: 25));
      case 'PUT':
        return _client
            .put(uri, headers: h, body: body)
            .timeout(const Duration(seconds: 25));
      case 'POST':
        return _client
            .post(uri, headers: h, body: body)
            .timeout(const Duration(seconds: 25));
      default:
        throw ArgumentError('Método HTTP no soportado: $method');
    }
  }

  Future<http.Response> _proxyViaCloud(
    String method,
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    if (Firebase.apps.isEmpty) {
      throw StateError('Firebase no inicializado (proxy Spotify Web).');
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('Sesión Firebase requerida para API Spotify en Web.');
    }
    final idToken = await user.getIdToken();
    final projectId = DefaultFirebaseOptions.currentPlatform.projectId;
    final proxyUri = Uri.parse(
      'https://$kFolioCloudFunctionsRegion-$projectId.cloudfunctions.net/folioSpotifyApiProxy',
    );
    return _client
        .post(
          proxyUri,
          headers: {
            'content-type': 'application/json; charset=utf-8',
            'authorization': 'Bearer $idToken',
          },
          body: jsonEncode({
            'method': method.toUpperCase(),
            'path': '${uri.path}${uri.hasQuery ? '?${uri.query}' : ''}',
            'accessToken': _connection.accessToken,
            if (body != null) 'body': body is String ? body : jsonEncode(body),
            if (headers != null && headers.isNotEmpty) 'headers': headers,
          }),
        )
        .timeout(const Duration(seconds: 30));
  }

  Future<Map<String, dynamic>> getProfile() async {
    final resp = await _request('GET', Uri.https('api.spotify.com', '/v1/me'));
    return _decodeMap(resp);
  }

  Future<SpotifyPlaybackSnapshot> getCurrentlyPlaying() async {
    final resp = await _request(
      'GET',
      Uri.https('api.spotify.com', '/v1/me/player/currently-playing'),
    );
    if (resp.statusCode == 204) {
      return const SpotifyPlaybackSnapshot(noContent: true);
    }
    if (resp.statusCode == 401) {
      return const SpotifyPlaybackSnapshot(premiumRequired: true);
    }
    if (resp.statusCode == 403) {
      final body = resp.body.toLowerCase();
      if (body.contains('premium')) {
        return const SpotifyPlaybackSnapshot(premiumRequired: true);
      }
      return const SpotifyPlaybackSnapshot(noActiveDevice: true);
    }
    if (resp.statusCode == 404) {
      return const SpotifyPlaybackSnapshot(noActiveDevice: true);
    }
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      return const SpotifyPlaybackSnapshot(noContent: true);
    }
    final map = _tryDecodeMap(resp.body);
    if (map == null) return const SpotifyPlaybackSnapshot(noContent: true);
    return _snapshotFromPlayerJson(map, currentlyPlaying: true);
  }

  Future<SpotifyPlaybackSnapshot> getPlaybackState() async {
    final resp = await _request(
      'GET',
      Uri.https('api.spotify.com', '/v1/me/player'),
    );
    if (resp.statusCode == 204) {
      return const SpotifyPlaybackSnapshot(noContent: true);
    }
    if (resp.statusCode == 403) {
      return const SpotifyPlaybackSnapshot(premiumRequired: true);
    }
    if (resp.statusCode == 404) {
      return const SpotifyPlaybackSnapshot(noActiveDevice: true);
    }
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      return const SpotifyPlaybackSnapshot(noContent: true);
    }
    final map = _tryDecodeMap(resp.body);
    if (map == null) return const SpotifyPlaybackSnapshot(noContent: true);
    return _snapshotFromPlayerJson(map, currentlyPlaying: false);
  }

  SpotifyPlaybackSnapshot _snapshotFromPlayerJson(
    Map<String, dynamic> map, {
    required bool currentlyPlaying,
  }) {
    final isPlaying = map['is_playing'] == true;
    final progress = (map['progress_ms'] as num?)?.toInt() ?? 0;
    final device = map['device'];
    final deviceName =
        device is Map ? (device['name'] as String? ?? '').trim() : '';
    final volumePercent = device is Map
        ? (device['volume_percent'] as num?)?.toInt()
        : null;
    final track = map['item'];
    if (track is! Map) {
      return SpotifyPlaybackSnapshot(
        isPlaying: isPlaying,
        progressMs: progress,
        deviceName: deviceName.isEmpty ? null : deviceName,
        volumePercent: volumePercent,
        noContent: true,
      );
    }
    final trackMap = Map<String, dynamic>.from(track);
    final name = (trackMap['name'] as String? ?? '').trim();
    final artists = trackMap['artists'];
    var artist = '';
    if (artists is List && artists.isNotEmpty) {
      final first = artists.first;
      if (first is Map) {
        artist = (first['name'] as String? ?? '').trim();
      }
    }
    final album = trackMap['album'];
    String? artUrl;
    if (album is Map) {
      final images = album['images'];
      if (images is List && images.isNotEmpty) {
        final img = images.first;
        if (img is Map) {
          artUrl = (img['url'] as String?)?.trim();
        }
      }
    }
    final duration = (trackMap['duration_ms'] as num?)?.toInt() ?? 0;
    final uri = (trackMap['uri'] as String? ?? '').trim();
    return SpotifyPlaybackSnapshot(
      trackName: name.isEmpty ? null : name,
      artistName: artist.isEmpty ? null : artist,
      albumArtUrl: artUrl,
      isPlaying: isPlaying,
      progressMs: progress,
      durationMs: duration,
      deviceName: deviceName.isEmpty ? null : deviceName,
      trackUri: uri.isEmpty ? null : uri,
      volumePercent: volumePercent,
    );
  }

  Future<void> play({String? contextUri, List<String>? uris}) async {
    final uri = Uri.https('api.spotify.com', '/v1/me/player/play');
    Map<String, Object?>? bodyMap;
    if (uris != null && uris.isNotEmpty) {
      bodyMap = {'uris': uris};
    } else if (contextUri != null && contextUri.isNotEmpty) {
      bodyMap = {'context_uri': contextUri};
    }
    final body = bodyMap != null ? jsonEncode(bodyMap) : null;
    final resp = await _request(
      'PUT',
      uri,
      headers: body != null ? {'content-type': 'application/json'} : null,
      body: body,
    );
    _throwIfPlaybackError(resp);
  }

  Future<void> pause() async {
    final resp = await _request(
      'PUT',
      Uri.https('api.spotify.com', '/v1/me/player/pause'),
    );
    _throwIfPlaybackError(resp);
  }

  Future<void> skipNext() async {
    final resp = await _request(
      'POST',
      Uri.https('api.spotify.com', '/v1/me/player/next'),
    );
    _throwIfPlaybackError(resp);
  }

  Future<void> skipPrevious() async {
    final resp = await _request(
      'POST',
      Uri.https('api.spotify.com', '/v1/me/player/previous'),
    );
    _throwIfPlaybackError(resp);
  }

  /// Volumen del dispositivo activo (0–100). Requiere Premium.
  Future<void> setVolume(int volumePercent) async {
    final percent = volumePercent.clamp(0, 100);
    final resp = await _request(
      'PUT',
      Uri.https('api.spotify.com', '/v1/me/player/volume', {
        'volume_percent': '$percent',
      }),
    );
    _throwIfPlaybackError(resp);
  }

  /// Salta a la posición [positionMs] de la pista actual.
  Future<void> seek(int positionMs) async {
    final pos = positionMs < 0 ? 0 : positionMs;
    final resp = await _request(
      'PUT',
      Uri.https('api.spotify.com', '/v1/me/player/seek', {
        'position_ms': '$pos',
      }),
    );
    _throwIfPlaybackError(resp);
  }

  void _throwIfPlaybackError(http.Response resp) {
    if (resp.statusCode >= 200 && resp.statusCode < 300) return;
    if (resp.statusCode == 403) {
      throw StateError('spotify_premium_required');
    }
    if (resp.statusCode == 404) {
      throw StateError('spotify_no_active_device');
    }
    throw StateError(
      'Spotify playback error (${resp.statusCode}): ${resp.body}',
    );
  }

  Future<SpotifyPlaylistPage> listUserPlaylists({
    int limit = 50,
    int offset = 0,
  }) async {
    final resp = await _request(
      'GET',
      Uri.https('api.spotify.com', '/v1/me/playlists', {
        'limit': '$limit',
        'offset': '$offset',
      }),
    );
    final map = _decodeMap(resp);
    final items = map['items'];
    if (items is! List) {
      return const SpotifyPlaylistPage(items: [], hasMore: false, nextOffset: 0);
    }
    final out = <SpotifyPlaylistSummary>[];
    for (final raw in items) {
      if (raw is! Map) continue;
      final m = Map<String, dynamic>.from(raw);
      final id = (m['id'] as String? ?? '').trim();
      final name = (m['name'] as String? ?? '').trim();
      final uri = (m['uri'] as String? ?? '').trim();
      if (id.isEmpty || name.isEmpty || uri.isEmpty) continue;
      String? imageUrl;
      final images = m['images'];
      if (images is List && images.isNotEmpty) {
        final img = images.first;
        if (img is Map) {
          imageUrl = (img['url'] as String?)?.trim();
        }
      }
      int? trackCount;
      final tracks = m['tracks'];
      if (tracks is Map) {
        trackCount = (tracks['total'] as num?)?.toInt();
      }
      out.add(
        SpotifyPlaylistSummary(
          id: id,
          name: name,
          uri: uri,
          imageUrl: imageUrl,
          trackCount: trackCount,
        ),
      );
    }
    final total = (map['total'] as num?)?.toInt();
    final nextOffset = offset + out.length;
    final hasMore = map['next'] != null ||
        (total != null && nextOffset < total);
    return SpotifyPlaylistPage(
      items: out,
      hasMore: hasMore,
      nextOffset: nextOffset,
    );
  }

  Future<bool> verifyConnection() async {
    try {
      final profile = await getProfile();
      return (profile['id'] as String? ?? '').trim().isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Map<String, dynamic> _decodeMap(http.Response resp) {
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw StateError(
        'Spotify API error (${resp.statusCode}): ${resp.body}',
      );
    }
    if (kIsWeb) {
      final outer = _tryDecodeMap(resp.body);
      if (outer != null && outer.containsKey('status')) {
        final status = (outer['status'] as num?)?.toInt() ?? 0;
        final body = outer['body'];
        if (status >= 200 && status < 300) {
          if (body is Map) return Map<String, dynamic>.from(body);
          if (body is String && body.isNotEmpty) {
            final inner = _tryDecodeMap(body);
            if (inner != null) return inner;
          }
          return const {};
        }
        throw StateError('Spotify proxy error ($status): $body');
      }
    }
    final map = _tryDecodeMap(resp.body);
    if (map == null) {
      throw StateError('Respuesta inválida de Spotify API.');
    }
    return map;
  }

  Map<String, dynamic>? _tryDecodeMap(String body) {
    if (body.trim().isEmpty) return const {};
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return null;
  }
}
