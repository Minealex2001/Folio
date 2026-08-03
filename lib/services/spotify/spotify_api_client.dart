import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

import '../../models/spotify_integration_state.dart';
import '../../config/folio_backend_config.dart';
import '../folio_cloud/folio_cloud_identity.dart';
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
    this.shuffleState = false,
    this.repeatState = 'off',
    this.contextUri,
    this.contextType,
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
  final bool shuffleState;
  /// `off` | `track` | `context`
  final String repeatState;
  final String? contextUri;
  final String? contextType;
  final bool premiumRequired;
  final bool noActiveDevice;
  final bool noContent;

  static const empty = SpotifyPlaybackSnapshot(noContent: true);

  String? get trackId {
    final uri = trackUri?.trim() ?? '';
    if (!uri.startsWith('spotify:')) return null;
    final parts = uri.split(':');
    return parts.length >= 3 ? parts.last : null;
  }

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
    bool? shuffleState,
    String? repeatState,
    String? contextUri,
    String? contextType,
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
      shuffleState: shuffleState ?? this.shuffleState,
      repeatState: repeatState ?? this.repeatState,
      contextUri: contextUri ?? this.contextUri,
      contextType: contextType ?? this.contextType,
      premiumRequired: premiumRequired ?? this.premiumRequired,
      noActiveDevice: noActiveDevice ?? this.noActiveDevice,
      noContent: noContent ?? this.noContent,
    );
  }
}

/// Cola de reproducción actual.
class SpotifyQueueSnapshot {
  const SpotifyQueueSnapshot({
    this.currentlyPlaying,
    this.queue = const [],
  });

  final SpotifyTrackSummary? currentlyPlaying;
  final List<SpotifyTrackSummary> queue;
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

/// Dispositivo Spotify Connect disponible (incluye "Folio" cuando el SDK
/// local está listo y activo).
class SpotifyDevice {
  const SpotifyDevice({
    required this.id,
    required this.name,
    required this.type,
    this.isActive = false,
    this.isRestricted = false,
    this.volumePercent,
  });

  final String id;
  final String name;
  final String type;
  final bool isActive;
  final bool isRestricted;
  final int? volumePercent;
}

/// Resultado de búsqueda / listado de canciones.
class SpotifyTrackSummary {
  const SpotifyTrackSummary({
    required this.id,
    required this.name,
    required this.uri,
    required this.artistName,
    this.albumName,
    this.albumArtUrl,
    this.durationMs = 0,
  });

  final String id;
  final String name;
  final String uri;
  final String artistName;
  final String? albumName;
  final String? albumArtUrl;
  final int durationMs;
}

/// Página paginada de tracks (liked / playlist / álbum).
class SpotifyTrackPage {
  const SpotifyTrackPage({
    required this.items,
    required this.hasMore,
    required this.nextOffset,
  });

  final List<SpotifyTrackSummary> items;
  final bool hasMore;
  final int nextOffset;
}

/// Resumen de álbum para búsqueda / detalle.
class SpotifyAlbumSummary {
  const SpotifyAlbumSummary({
    required this.id,
    required this.name,
    required this.uri,
    required this.artistName,
    this.imageUrl,
    this.trackCount,
  });

  final String id;
  final String name;
  final String uri;
  final String artistName;
  final String? imageUrl;
  final int? trackCount;
}

/// Resumen de artista para búsqueda.
class SpotifyArtistSummary {
  const SpotifyArtistSummary({
    required this.id,
    required this.name,
    required this.uri,
    this.imageUrl,
  });

  final String id;
  final String name;
  final String uri;
  final String? imageUrl;
}

/// Resultado de búsqueda multi-tipo.
class SpotifySearchResults {
  const SpotifySearchResults({
    this.tracks = const [],
    this.albums = const [],
    this.artists = const [],
    this.playlists = const [],
  });

  final List<SpotifyTrackSummary> tracks;
  final List<SpotifyAlbumSummary> albums;
  final List<SpotifyArtistSummary> artists;
  final List<SpotifyPlaylistSummary> playlists;

  bool get isEmpty =>
      tracks.isEmpty && albums.isEmpty && artists.isEmpty && playlists.isEmpty;
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

  /// Devuelve un access token vigente, refrescándolo primero si hace falta.
  /// Usado por el host del dispositivo local para alimentar al Web Playback
  /// SDK con un token siempre fresco.
  Future<String> freshAccessToken() async {
    final conn = await _ensureFreshToken();
    return conn.accessToken;
  }

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
    final scope = (tokenJson['scope'] as String? ?? '').trim();
    final updated = _connection.copyWith(
      accessToken: accessToken,
      refreshToken: newRefresh,
      expiresAt: DateTime.now().toUtc().add(Duration(seconds: expiresIn)),
      grantedScopes: scope.isEmpty
          ? null
          : scope.split(' ').where((s) => s.isNotEmpty).toList(growable: false),
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
    Uri targetUri, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    if (!folioCloudHasSession()) {
      throw StateError('Sesión Folio Cloud requerida (proxy Spotify Web).');
    }
    final uid = folioCloudCurrentUid();
    if (uid == null || uid.isEmpty) {
      throw StateError('Sesión Folio Cloud requerida para API Spotify en Web.');
    }
    final idToken = await folioCloudBearerToken();
    if (idToken == null || idToken.isEmpty) {
      throw StateError('Sesión Folio Cloud requerida para API Spotify en Web.');
    }
    final proxyUri = Uri.parse(
      '${FolioBackendConfig.apiV1Prefix}/integrations/spotify/api-proxy',
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
            'path':
                '${targetUri.path}${targetUri.hasQuery ? '?${targetUri.query}' : ''}',
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
    final shuffle = map['shuffle_state'] == true;
    final repeat = (map['repeat_state'] as String? ?? 'off').trim();
    String? contextUri;
    String? contextType;
    final context = map['context'];
    if (context is Map) {
      contextUri = (context['uri'] as String?)?.trim();
      contextType = (context['type'] as String?)?.trim();
    }
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
      shuffleState: shuffle,
      repeatState: repeat.isEmpty ? 'off' : repeat,
      contextUri: contextUri,
      contextType: contextType,
    );
  }

  Future<void> play({
    String? contextUri,
    List<String>? uris,
    String? offsetUri,
    int? offsetPosition,
    String? deviceId,
  }) async {
    final query = <String, String>{};
    final trimmedDevice = deviceId?.trim() ?? '';
    if (trimmedDevice.isNotEmpty) {
      query['device_id'] = trimmedDevice;
    }
    final uri = Uri.https(
      'api.spotify.com',
      '/v1/me/player/play',
      query.isEmpty ? null : query,
    );
    Map<String, Object?>? bodyMap;
    if (uris != null && uris.isNotEmpty) {
      bodyMap = {'uris': uris};
    } else if (contextUri != null && contextUri.isNotEmpty) {
      bodyMap = {'context_uri': contextUri};
      if (offsetUri != null && offsetUri.isNotEmpty) {
        bodyMap['offset'] = {'uri': offsetUri};
      } else if (offsetPosition != null && offsetPosition >= 0) {
        bodyMap['offset'] = {'position': offsetPosition};
      }
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

  /// Transfiere la reproducción al dispositivo [deviceId] (p.ej. el device_id
  /// que reporta el Web Playback SDK local de Folio). Esto lo activa como
  /// dispositivo Spotify Connect, visible desde otros clientes del usuario.
  Future<void> transferPlayback(String deviceId, {bool play = true}) async {
    final resp = await _request(
      'PUT',
      Uri.https('api.spotify.com', '/v1/me/player'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({
        'device_ids': [deviceId],
        'play': play,
      }),
    );
    _throwIfPlaybackError(resp);
  }

  /// Lista los dispositivos Spotify Connect disponibles para el usuario.
  Future<List<SpotifyDevice>> listDevices() async {
    final resp = await _request(
      'GET',
      Uri.https('api.spotify.com', '/v1/me/player/devices'),
    );
    if (resp.statusCode < 200 || resp.statusCode >= 300) return const [];
    final map = _tryDecodeMap(resp.body);
    final devices = map?['devices'];
    if (devices is! List) return const [];
    final out = <SpotifyDevice>[];
    for (final raw in devices) {
      if (raw is! Map) continue;
      final m = Map<String, dynamic>.from(raw);
      final id = (m['id'] as String? ?? '').trim();
      final name = (m['name'] as String? ?? '').trim();
      if (id.isEmpty || name.isEmpty) continue;
      out.add(
        SpotifyDevice(
          id: id,
          name: name,
          type: (m['type'] as String? ?? '').trim(),
          isActive: m['is_active'] == true,
          isRestricted: m['is_restricted'] == true,
          volumePercent: (m['volume_percent'] as num?)?.toInt(),
        ),
      );
    }
    return out;
  }

  /// Cola actual (`GET /v1/me/player/queue`).
  Future<SpotifyQueueSnapshot> getQueue() async {
    final resp = await _request(
      'GET',
      Uri.https('api.spotify.com', '/v1/me/player/queue'),
    );
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      return const SpotifyQueueSnapshot();
    }
    final map = _tryDecodeMap(resp.body);
    if (map == null) return const SpotifyQueueSnapshot();
    SpotifyTrackSummary? current;
    final playing = map['currently_playing'];
    if (playing is Map) {
      current = _parseTrackMap(Map<String, dynamic>.from(playing));
    }
    final queueRaw = map['queue'];
    final queue = <SpotifyTrackSummary>[];
    if (queueRaw is List) {
      for (final raw in queueRaw) {
        if (raw is! Map) continue;
        final parsed = _parseTrackMap(Map<String, dynamic>.from(raw));
        if (parsed != null) queue.add(parsed);
      }
    }
    return SpotifyQueueSnapshot(currentlyPlaying: current, queue: queue);
  }

  /// Añade un URI a la cola (`POST /v1/me/player/queue`).
  Future<void> addToQueue(String spotifyUri) async {
    final uri = spotifyUri.trim();
    if (uri.isEmpty) return;
    final resp = await _request(
      'POST',
      Uri.https('api.spotify.com', '/v1/me/player/queue', {'uri': uri}),
    );
    _throwIfPlaybackError(resp);
  }

  Future<void> setShuffle(bool state) async {
    final resp = await _request(
      'PUT',
      Uri.https('api.spotify.com', '/v1/me/player/shuffle', {
        'state': state ? 'true' : 'false',
      }),
    );
    _throwIfPlaybackError(resp);
  }

  /// [state]: `off` | `track` | `context`
  Future<void> setRepeat(String state) async {
    final s = state.trim().isEmpty ? 'off' : state.trim();
    final resp = await _request(
      'PUT',
      Uri.https('api.spotify.com', '/v1/me/player/repeat', {'state': s}),
    );
    _throwIfPlaybackError(resp);
  }

  /// Busca canciones por texto libre (`GET /v1/search`, solo tracks).
  Future<List<SpotifyTrackSummary>> search(String query, {int limit = 20}) async {
    final results = await searchCatalog(query, limit: limit);
    return results.tracks;
  }

  /// Búsqueda multi-tipo: tracks, albums, artists, playlists.
  Future<SpotifySearchResults> searchCatalog(
    String query, {
    int limit = 12,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const SpotifySearchResults();
    final resp = await _request(
      'GET',
      Uri.https('api.spotify.com', '/v1/search', {
        'q': trimmed,
        'type': 'track,album,artist,playlist',
        'limit': '$limit',
      }),
    );
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      return const SpotifySearchResults();
    }
    final map = _tryDecodeMap(resp.body);
    if (map == null) return const SpotifySearchResults();
    return SpotifySearchResults(
      tracks: _parseTrackList(map['tracks']),
      albums: _parseAlbumList(map['albums']),
      artists: _parseArtistList(map['artists']),
      playlists: _parsePlaylistList(map['playlists']),
    );
  }

  /// Pistas reproducidas recientemente.
  Future<List<SpotifyTrackSummary>> getRecentlyPlayed({int limit = 20}) async {
    final resp = await _request(
      'GET',
      Uri.https('api.spotify.com', '/v1/me/player/recently-played', {
        'limit': '$limit',
      }),
    );
    if (resp.statusCode < 200 || resp.statusCode >= 300) return const [];
    final map = _tryDecodeMap(resp.body);
    final items = map?['items'];
    if (items is! List) return const [];
    final out = <SpotifyTrackSummary>[];
    final seen = <String>{};
    for (final raw in items) {
      if (raw is! Map) continue;
      final track = raw['track'];
      if (track is! Map) continue;
      final parsed = _parseTrackMap(Map<String, dynamic>.from(track));
      if (parsed == null || !seen.add(parsed.id)) continue;
      out.add(parsed);
    }
    return out;
  }

  /// Canciones guardadas (Me gusta).
  Future<SpotifyTrackPage> getSavedTracks({
    int limit = 50,
    int offset = 0,
  }) async {
    final resp = await _request(
      'GET',
      Uri.https('api.spotify.com', '/v1/me/tracks', {
        'limit': '$limit',
        'offset': '$offset',
      }),
    );
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      return const SpotifyTrackPage(items: [], hasMore: false, nextOffset: 0);
    }
    final map = _tryDecodeMap(resp.body);
    if (map == null) {
      return const SpotifyTrackPage(items: [], hasMore: false, nextOffset: 0);
    }
    final items = map['items'];
    final out = <SpotifyTrackSummary>[];
    if (items is List) {
      for (final raw in items) {
        if (raw is! Map) continue;
        final track = raw['track'];
        if (track is! Map) continue;
        final parsed = _parseTrackMap(Map<String, dynamic>.from(track));
        if (parsed != null) out.add(parsed);
      }
    }
    final total = (map['total'] as num?)?.toInt();
    final nextOffset = offset + out.length;
    final hasMore =
        map['next'] != null || (total != null && nextOffset < total);
    return SpotifyTrackPage(
      items: out,
      hasMore: hasMore,
      nextOffset: nextOffset,
    );
  }

  /// Tracks de una playlist.
  Future<SpotifyTrackPage> getPlaylistTracks(
    String playlistId, {
    int limit = 50,
    int offset = 0,
  }) async {
    final id = playlistId.trim();
    if (id.isEmpty) {
      return const SpotifyTrackPage(items: [], hasMore: false, nextOffset: 0);
    }
    final resp = await _request(
      'GET',
      Uri.https('api.spotify.com', '/v1/playlists/$id/tracks', {
        'limit': '$limit',
        'offset': '$offset',
        'fields':
            'total,next,items(track(id,name,uri,duration_ms,artists(name),album(name,images)))',
      }),
    );
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      return const SpotifyTrackPage(items: [], hasMore: false, nextOffset: 0);
    }
    final map = _tryDecodeMap(resp.body);
    if (map == null) {
      return const SpotifyTrackPage(items: [], hasMore: false, nextOffset: 0);
    }
    final items = map['items'];
    final out = <SpotifyTrackSummary>[];
    if (items is List) {
      for (final raw in items) {
        if (raw is! Map) continue;
        final track = raw['track'];
        if (track is! Map) continue;
        final parsed = _parseTrackMap(Map<String, dynamic>.from(track));
        if (parsed != null) out.add(parsed);
      }
    }
    final total = (map['total'] as num?)?.toInt();
    final nextOffset = offset + out.length;
    final hasMore =
        map['next'] != null || (total != null && nextOffset < total);
    return SpotifyTrackPage(
      items: out,
      hasMore: hasMore,
      nextOffset: nextOffset,
    );
  }

  /// Tracks de un álbum.
  Future<SpotifyTrackPage> getAlbumTracks(
    String albumId, {
    int limit = 50,
    int offset = 0,
    String? albumArtUrl,
    String? albumName,
  }) async {
    final id = albumId.trim();
    if (id.isEmpty) {
      return const SpotifyTrackPage(items: [], hasMore: false, nextOffset: 0);
    }
    final resp = await _request(
      'GET',
      Uri.https('api.spotify.com', '/v1/albums/$id/tracks', {
        'limit': '$limit',
        'offset': '$offset',
      }),
    );
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      return const SpotifyTrackPage(items: [], hasMore: false, nextOffset: 0);
    }
    final map = _tryDecodeMap(resp.body);
    if (map == null) {
      return const SpotifyTrackPage(items: [], hasMore: false, nextOffset: 0);
    }
    final items = map['items'];
    final out = <SpotifyTrackSummary>[];
    if (items is List) {
      for (final raw in items) {
        if (raw is! Map) continue;
        final parsed = _parseTrackMap(
          Map<String, dynamic>.from(raw),
          fallbackArtUrl: albumArtUrl,
          fallbackAlbumName: albumName,
        );
        if (parsed != null) out.add(parsed);
      }
    }
    final total = (map['total'] as num?)?.toInt();
    final nextOffset = offset + out.length;
    final hasMore =
        map['next'] != null || (total != null && nextOffset < total);
    return SpotifyTrackPage(
      items: out,
      hasMore: hasMore,
      nextOffset: nextOffset,
    );
  }

  /// Top tracks de un artista.
  Future<List<SpotifyTrackSummary>> getArtistTopTracks(String artistId) async {
    final id = artistId.trim();
    if (id.isEmpty) return const [];
    final resp = await _request(
      'GET',
      Uri.https('api.spotify.com', '/v1/artists/$id/top-tracks', {
        'market': 'ES',
      }),
    );
    if (resp.statusCode < 200 || resp.statusCode >= 300) return const [];
    final map = _tryDecodeMap(resp.body);
    return _parseTrackList(map);
  }

  SpotifyTrackSummary? _parseTrackMap(
    Map<String, dynamic> m, {
    String? fallbackArtUrl,
    String? fallbackAlbumName,
  }) {
    final id = (m['id'] as String? ?? '').trim();
    final name = (m['name'] as String? ?? '').trim();
    final uri = (m['uri'] as String? ?? '').trim();
    if (id.isEmpty || name.isEmpty || uri.isEmpty) return null;
    var artist = '';
    final artists = m['artists'];
    if (artists is List && artists.isNotEmpty) {
      final first = artists.first;
      if (first is Map) artist = (first['name'] as String? ?? '').trim();
    }
    String? artUrl = fallbackArtUrl;
    String? albumName = fallbackAlbumName;
    final album = m['album'];
    if (album is Map) {
      final rawAlbumName = (album['name'] as String? ?? '').trim();
      if (rawAlbumName.isNotEmpty) albumName = rawAlbumName;
      final images = album['images'];
      if (images is List && images.isNotEmpty) {
        final img = images.first;
        if (img is Map) artUrl = (img['url'] as String?)?.trim() ?? artUrl;
      }
    }
    return SpotifyTrackSummary(
      id: id,
      name: name,
      uri: uri,
      artistName: artist,
      albumName: albumName,
      albumArtUrl: artUrl,
      durationMs: (m['duration_ms'] as num?)?.toInt() ?? 0,
    );
  }

  List<SpotifyTrackSummary> _parseTrackList(Object? container) {
    if (container is Map) {
      final items = container['items'] ?? container['tracks'];
      if (items is! List) return const [];
      final out = <SpotifyTrackSummary>[];
      for (final raw in items) {
        if (raw is! Map) continue;
        final parsed = _parseTrackMap(Map<String, dynamic>.from(raw));
        if (parsed != null) out.add(parsed);
      }
      return out;
    }
    if (container is List) {
      final out = <SpotifyTrackSummary>[];
      for (final raw in container) {
        if (raw is! Map) continue;
        final parsed = _parseTrackMap(Map<String, dynamic>.from(raw));
        if (parsed != null) out.add(parsed);
      }
      return out;
    }
    return const [];
  }

  List<SpotifyAlbumSummary> _parseAlbumList(Object? container) {
    if (container is! Map) return const [];
    final items = container['items'];
    if (items is! List) return const [];
    final out = <SpotifyAlbumSummary>[];
    for (final raw in items) {
      if (raw is! Map) continue;
      final m = Map<String, dynamic>.from(raw);
      final id = (m['id'] as String? ?? '').trim();
      final name = (m['name'] as String? ?? '').trim();
      final uri = (m['uri'] as String? ?? '').trim();
      if (id.isEmpty || name.isEmpty || uri.isEmpty) continue;
      var artist = '';
      final artists = m['artists'];
      if (artists is List && artists.isNotEmpty) {
        final first = artists.first;
        if (first is Map) artist = (first['name'] as String? ?? '').trim();
      }
      String? imageUrl;
      final images = m['images'];
      if (images is List && images.isNotEmpty) {
        final img = images.first;
        if (img is Map) imageUrl = (img['url'] as String?)?.trim();
      }
      out.add(
        SpotifyAlbumSummary(
          id: id,
          name: name,
          uri: uri,
          artistName: artist,
          imageUrl: imageUrl,
          trackCount: (m['total_tracks'] as num?)?.toInt(),
        ),
      );
    }
    return out;
  }

  List<SpotifyArtistSummary> _parseArtistList(Object? container) {
    if (container is! Map) return const [];
    final items = container['items'];
    if (items is! List) return const [];
    final out = <SpotifyArtistSummary>[];
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
        if (img is Map) imageUrl = (img['url'] as String?)?.trim();
      }
      out.add(
        SpotifyArtistSummary(
          id: id,
          name: name,
          uri: uri,
          imageUrl: imageUrl,
        ),
      );
    }
    return out;
  }

  List<SpotifyPlaylistSummary> _parsePlaylistList(Object? container) {
    if (container is! Map) return const [];
    final items = container['items'];
    if (items is! List) return const [];
    final out = <SpotifyPlaylistSummary>[];
    for (final raw in items) {
      if (raw is! Map) continue;
      // Search may return null playlist entries.
      if (raw.isEmpty) continue;
      final m = Map<String, dynamic>.from(raw);
      final id = (m['id'] as String? ?? '').trim();
      final name = (m['name'] as String? ?? '').trim();
      final uri = (m['uri'] as String? ?? '').trim();
      if (id.isEmpty || name.isEmpty || uri.isEmpty) continue;
      String? imageUrl;
      final images = m['images'];
      if (images is List && images.isNotEmpty) {
        final img = images.first;
        if (img is Map) imageUrl = (img['url'] as String?)?.trim();
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
    return out;
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
