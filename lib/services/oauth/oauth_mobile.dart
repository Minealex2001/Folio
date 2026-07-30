import 'package:flutter/foundation.dart' show kIsWeb;

import 'oauth_platform_io.dart'
    if (dart.library.html) 'oauth_platform_stub.dart' as platform;

/// True en Android/iOS nativo (no Web).
bool get oauthUsesMobileDeepLink =>
    !kIsWeb && platform.isAndroidOrIos;

/// Providers con redirect `folio://oauth/<provider>/callback`.
abstract final class OAuthMobileRedirect {
  static const String scheme = 'folio';
  static const String host = 'oauth';

  static Uri callbackUri(String provider) {
    final p = provider.trim().toLowerCase();
    return Uri(scheme: scheme, host: host, path: '/$p/callback');
  }

  static bool matchesProvider(Uri uri, String provider) {
    if (uri.scheme.toLowerCase() != scheme) return false;
    if ((uri.host).toLowerCase() != host) return false;
    final expected = '/${provider.trim().toLowerCase()}/callback';
    return uri.path == expected || uri.path == '$expected/';
  }
}
