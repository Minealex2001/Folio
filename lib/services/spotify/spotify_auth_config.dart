/// Configuración pública de la app oficial de Folio en Spotify Developer.
abstract final class SpotifyAuthConfig {
  /// Client ID público (no es secreto; se expone en la URL de autorización).
  ///
  /// Sustituir tras registrar la app en Spotify Developer Dashboard.
  static const String officialClientId = '';

  static const List<String> defaultScopes = [
    'user-read-playback-state',
    'user-modify-playback-state',
    'user-read-currently-playing',
    'playlist-read-private',
  ];

  /// Puerto loopback fijo (distinto al de Jira `45747`).
  static const int oauthLoopbackPort = 45748;

  static const String oauthProvider = 'spotify';

  static Uri get loopbackRedirectUri =>
      Uri.parse('http://127.0.0.1:$oauthLoopbackPort/callback');

  /// Redirect en Android/iOS: registrar en Spotify Dashboard → Redirect URIs.
  static Uri get mobileRedirectUri =>
      Uri.parse('folio://oauth/$oauthProvider/callback');
}
