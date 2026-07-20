import 'dart:convert';

/// Estado de la integración con Spotify: conexiones OAuth y preferencias de
/// reproducción (playlist de enfoque, modo zen).
class SpotifyIntegrationState {
  const SpotifyIntegrationState({this.connections = const []});

  final List<SpotifyConnection> connections;

  static const SpotifyIntegrationState empty = SpotifyIntegrationState();

  Map<String, Object?> toJson() => <String, Object?>{
        'connections': connections.map((c) => c.toJson()).toList(growable: false),
      };

  static SpotifyIntegrationState fromJson(Object? raw) {
    if (raw is! Map) return empty;
    final m = Map<String, dynamic>.from(raw);
    final conns = <SpotifyConnection>[];
    final rawConnections = m['connections'];
    if (rawConnections is List) {
      for (final item in rawConnections) {
        if (item is Map) {
          final c = SpotifyConnection.tryParse(Map<String, dynamic>.from(item));
          if (c != null) conns.add(c);
        }
      }
    }
    return SpotifyIntegrationState(connections: List.unmodifiable(conns));
  }

  String encode() => jsonEncode(toJson());
}

/// Una cuenta de Spotify conectada vía OAuth 2.0 + PKCE.
class SpotifyConnection {
  const SpotifyConnection({
    required this.id,
    required this.label,
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
    this.spotifyUserId,
    this.displayName,
    this.focusPlaylistUri,
    this.focusPlaylistName,
    this.zenAutoPlay = false,
    this.zenPauseOnExit = true,
  });

  final String id;
  final String label;
  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;
  final String? spotifyUserId;
  final String? displayName;
  /// URI `spotify:playlist:...` para modo zen.
  final String? focusPlaylistUri;
  final String? focusPlaylistName;
  final bool zenAutoPlay;
  final bool zenPauseOnExit;

  bool get isExpired =>
      DateTime.now().toUtc().isAfter(expiresAt.toUtc().subtract(const Duration(minutes: 2)));

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'label': label,
        'accessToken': accessToken,
        'refreshToken': refreshToken,
        'expiresAt': expiresAt.toUtc().millisecondsSinceEpoch,
        if (spotifyUserId != null && spotifyUserId!.isNotEmpty)
          'spotifyUserId': spotifyUserId,
        if (displayName != null && displayName!.isNotEmpty) 'displayName': displayName,
        if (focusPlaylistUri != null && focusPlaylistUri!.isNotEmpty)
          'focusPlaylistUri': focusPlaylistUri,
        if (focusPlaylistName != null && focusPlaylistName!.isNotEmpty)
          'focusPlaylistName': focusPlaylistName,
        'zenAutoPlay': zenAutoPlay,
        'zenPauseOnExit': zenPauseOnExit,
      };

  static SpotifyConnection? tryParse(Map<String, dynamic> map) {
    final id = (map['id'] as String? ?? '').trim();
    final label = (map['label'] as String? ?? '').trim();
    final accessToken = (map['accessToken'] as String? ?? '').trim();
    final refreshToken = (map['refreshToken'] as String? ?? '').trim();
    final expiresRaw = map['expiresAt'];
    if (id.isEmpty || label.isEmpty || accessToken.isEmpty || refreshToken.isEmpty) {
      return null;
    }
    DateTime expiresAt;
    if (expiresRaw is num) {
      expiresAt = DateTime.fromMillisecondsSinceEpoch(expiresRaw.toInt(), isUtc: true);
    } else if (expiresRaw is String) {
      final parsed = int.tryParse(expiresRaw);
      if (parsed == null) return null;
      expiresAt = DateTime.fromMillisecondsSinceEpoch(parsed, isUtc: true);
    } else {
      return null;
    }
    return SpotifyConnection(
      id: id,
      label: label,
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresAt: expiresAt,
      spotifyUserId: (map['spotifyUserId'] as String?)?.trim(),
      displayName: (map['displayName'] as String?)?.trim(),
      focusPlaylistUri: (map['focusPlaylistUri'] as String?)?.trim(),
      focusPlaylistName: (map['focusPlaylistName'] as String?)?.trim(),
      zenAutoPlay: map['zenAutoPlay'] == true,
      zenPauseOnExit: map['zenPauseOnExit'] != false,
    );
  }

  SpotifyConnection copyWith({
    String? label,
    String? accessToken,
    String? refreshToken,
    DateTime? expiresAt,
    String? spotifyUserId,
    String? displayName,
    String? focusPlaylistUri,
    String? focusPlaylistName,
    bool? zenAutoPlay,
    bool? zenPauseOnExit,
    bool clearFocusPlaylist = false,
  }) {
    return SpotifyConnection(
      id: id,
      label: label ?? this.label,
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      expiresAt: expiresAt ?? this.expiresAt,
      spotifyUserId: spotifyUserId ?? this.spotifyUserId,
      displayName: displayName ?? this.displayName,
      focusPlaylistUri:
          clearFocusPlaylist ? null : (focusPlaylistUri ?? this.focusPlaylistUri),
      focusPlaylistName:
          clearFocusPlaylist ? null : (focusPlaylistName ?? this.focusPlaylistName),
      zenAutoPlay: zenAutoPlay ?? this.zenAutoPlay,
      zenPauseOnExit: zenPauseOnExit ?? this.zenPauseOnExit,
    );
  }
}
