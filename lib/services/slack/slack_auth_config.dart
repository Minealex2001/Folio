/// Configuración OAuth Slack (Fase 2). Client ID vía secretos / dart-define.
abstract final class SlackAuthConfig {
  static const String officialClientId = '';

  static const List<String> defaultScopes = [
    'chat:write',
    'commands',
    'incoming-webhook',
  ];

  /// Puerto loopback fijo (≠ Jira 45747, Spotify 45748).
  static const int oauthLoopbackPort = 45749;

  static Uri get loopbackRedirectUri =>
      Uri.parse('http://127.0.0.1:$oauthLoopbackPort/callback');
}
