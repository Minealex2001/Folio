import 'dart:convert';

/// Modo de autenticación InnerTube.
enum YtMusicAuthMode {
  /// OAuth device-flow (TV). Google suele rechazarlo en InnerTube WEB_REMIX.
  oauth,

  /// Cookies + SAPISIDHASH del navegador (recomendado).
  browser,
}

/// Estado de la integración YouTube Music.
class YtMusicIntegrationState {
  const YtMusicIntegrationState({this.connections = const []});

  final List<YtMusicConnection> connections;

  static const YtMusicIntegrationState empty = YtMusicIntegrationState();

  Map<String, Object?> toJson() => <String, Object?>{
        'connections':
            connections.map((c) => c.toJson()).toList(growable: false),
      };

  static YtMusicIntegrationState fromJson(Object? raw) {
    if (raw is! Map) return empty;
    final m = Map<String, dynamic>.from(raw);
    final conns = <YtMusicConnection>[];
    final rawConnections = m['connections'];
    if (rawConnections is List) {
      for (final item in rawConnections) {
        if (item is Map) {
          final c = YtMusicConnection.tryParse(Map<String, dynamic>.from(item));
          if (c != null) conns.add(c);
        }
      }
    }
    return YtMusicIntegrationState(connections: List.unmodifiable(conns));
  }

  String encode() => jsonEncode(toJson());
}

class YtMusicConnection {
  const YtMusicConnection({
    required this.id,
    required this.label,
    required this.authMode,
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
    this.cookie,
    this.authUser,
    this.visitorId,
    this.channelId,
    this.displayName,
  });

  final String id;
  final String label;
  final YtMusicAuthMode authMode;
  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;

  /// Cookie cruda del navegador (modo [YtMusicAuthMode.browser]).
  final String? cookie;

  /// Valor de `x-goog-authuser`.
  final String? authUser;

  /// Valor de `x-goog-visitor-id` (opcional).
  final String? visitorId;

  final String? channelId;
  final String? displayName;

  bool get isBrowser => authMode == YtMusicAuthMode.browser;

  bool get isExpired {
    if (isBrowser) return false;
    return DateTime.now()
        .toUtc()
        .isAfter(expiresAt.toUtc().subtract(const Duration(minutes: 2)));
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'label': label,
        'authMode': authMode.name,
        'accessToken': accessToken,
        'refreshToken': refreshToken,
        'expiresAt': expiresAt.toUtc().toIso8601String(),
        if (cookie != null && cookie!.isNotEmpty) 'cookie': cookie,
        if (authUser != null && authUser!.isNotEmpty) 'authUser': authUser,
        if (visitorId != null && visitorId!.isNotEmpty) 'visitorId': visitorId,
        if (channelId != null) 'channelId': channelId,
        if (displayName != null) 'displayName': displayName,
      };

  YtMusicConnection copyWith({
    String? id,
    String? label,
    YtMusicAuthMode? authMode,
    String? accessToken,
    String? refreshToken,
    DateTime? expiresAt,
    String? cookie,
    String? authUser,
    String? visitorId,
    String? channelId,
    String? displayName,
  }) {
    return YtMusicConnection(
      id: id ?? this.id,
      label: label ?? this.label,
      authMode: authMode ?? this.authMode,
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      expiresAt: expiresAt ?? this.expiresAt,
      cookie: cookie ?? this.cookie,
      authUser: authUser ?? this.authUser,
      visitorId: visitorId ?? this.visitorId,
      channelId: channelId ?? this.channelId,
      displayName: displayName ?? this.displayName,
    );
  }

  static YtMusicAuthMode _parseMode(Object? raw) {
    final s = '$raw'.trim().toLowerCase();
    if (s == 'browser') return YtMusicAuthMode.browser;
    return YtMusicAuthMode.oauth;
  }

  static YtMusicConnection? tryParse(Map<String, dynamic> m) {
    final id = (m['id'] as String?)?.trim() ?? '';
    if (id.isEmpty) return null;

    final cookie = (m['cookie'] as String?)?.trim();
    var mode = _parseMode(m['authMode']);
    if ((cookie ?? '').isNotEmpty && m['authMode'] == null) {
      mode = YtMusicAuthMode.browser;
    }

    final accessToken = (m['accessToken'] as String?)?.trim() ?? '';
    final refreshToken = (m['refreshToken'] as String?)?.trim() ?? '';
    final expiresRaw = m['expiresAt'];
    final expiresAt = expiresRaw is String
        ? DateTime.tryParse(expiresRaw)?.toUtc()
        : null;

    if (mode == YtMusicAuthMode.browser) {
      if ((cookie ?? '').isEmpty) return null;
      return YtMusicConnection(
        id: id,
        label: ((m['label'] as String?)?.trim().isNotEmpty ?? false)
            ? (m['label'] as String).trim()
            : 'YouTube Music',
        authMode: YtMusicAuthMode.browser,
        accessToken: accessToken,
        refreshToken: refreshToken.isEmpty ? 'browser' : refreshToken,
        expiresAt: expiresAt ??
            DateTime.now().toUtc().add(const Duration(days: 365)),
        cookie: cookie,
        authUser: (m['authUser'] as String?)?.trim() ?? '0',
        visitorId: (m['visitorId'] as String?)?.trim(),
        channelId: (m['channelId'] as String?)?.trim(),
        displayName: (m['displayName'] as String?)?.trim(),
      );
    }

    if (accessToken.isEmpty || refreshToken.isEmpty || expiresAt == null) {
      return null;
    }
    return YtMusicConnection(
      id: id,
      label: ((m['label'] as String?)?.trim().isNotEmpty ?? false)
          ? (m['label'] as String).trim()
          : 'YouTube Music',
      authMode: YtMusicAuthMode.oauth,
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresAt: expiresAt,
      channelId: (m['channelId'] as String?)?.trim(),
      displayName: (m['displayName'] as String?)?.trim(),
    );
  }
}
