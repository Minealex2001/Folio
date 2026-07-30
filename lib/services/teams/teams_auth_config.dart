/// Configuración OAuth Microsoft Teams / Graph (Fase 2).
abstract final class TeamsAuthConfig {
  static const String officialClientId = '';

  static const List<String> defaultScopes = [
    'openid',
    'offline_access',
    'ChannelMessage.Send',
  ];

  static const int oauthLoopbackPort = 45750;

  static const String oauthProvider = 'teams';

  static Uri get loopbackRedirectUri =>
      Uri.parse('http://127.0.0.1:$oauthLoopbackPort/callback');

  /// Redirect en Android/iOS: registrar en Azure App Registration → Redirect URIs.
  static Uri get mobileRedirectUri =>
      Uri.parse('folio://oauth/$oauthProvider/callback');

  static const String authorizeUrl =
      'https://login.microsoftonline.com/common/oauth2/v2.0/authorize';
  static const String tokenUrl =
      'https://login.microsoftonline.com/common/oauth2/v2.0/token';
}
