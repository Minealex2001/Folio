import 'package:flutter/foundation.dart' show kIsWeb;

/// Origen de la app web oficial (enlaces de usuario: shares, reset, verify).
///
/// Hosts canónicos:
/// - producción: [productionBaseUrl] (`folio.minealexgames.com`)
/// - beta: [betaBaseUrl] (`foliobeta.minealexgames.com`)
///
/// Hosts futuros en `folio.com.es` se reconocen ya (migración gradual; de
/// momento solo el API beta usa `api-beta.folio.com.es`).
///
/// En Flutter web, si la página corre en beta o prod, los links usan ese origen.
/// Override opcional: `--dart-define=FOLIO_WEB_BASE_URL=https://foliobeta.minealexgames.com`
/// (p. ej. builds de escritorio que deben copiar enlaces beta).
class FolioWebUrls {
  FolioWebUrls._();

  static const String productionBaseUrl = 'https://folio.minealexgames.com';
  static const String productionHost = 'folio.minealexgames.com';
  static const String betaBaseUrl = 'https://foliobeta.minealexgames.com';
  static const String betaHost = 'foliobeta.minealexgames.com';

  /// Dominio de producto en migración (reconocido; aún no canónico en release).
  static const String nextProductionHost = 'folio.com.es';
  static const String nextBetaHost = 'beta.folio.com.es';

  static const String _webBaseUrlDefine = String.fromEnvironment(
    'FOLIO_WEB_BASE_URL',
    defaultValue: '',
  );

  /// `true` si [host] es la app oficial (prod o beta, canónico o next).
  static bool isOfficialFolioWebHost(String? host) {
    final h = (host ?? '').trim().toLowerCase();
    if (h.isEmpty) return false;
    return isProductionWebHost(h) || isBetaWebHost(h);
  }

  static bool isBetaWebHost(String? host) {
    final h = (host ?? '').trim().toLowerCase();
    return h == betaHost ||
        h.endsWith('.$betaHost') ||
        h == nextBetaHost ||
        h.endsWith('.$nextBetaHost');
  }

  static bool isProductionWebHost(String? host) {
    final h = (host ?? '').trim().toLowerCase();
    // `beta.folio.com.es` también termina en `.folio.com.es`.
    if (isBetaWebHost(h)) return false;
    return h == productionHost ||
        h.endsWith('.$productionHost') ||
        h == nextProductionHost ||
        h == 'www.$nextProductionHost' ||
        h.endsWith('.$nextProductionHost');
  }

  /// Base sin barra final (prod / beta / define / localhost).
  static String get folioWebBaseUrl => resolveWebBaseUrl(
        isWeb: kIsWeb,
        currentUri: kIsWeb ? Uri.base : null,
        defineOverride: _webBaseUrlDefine,
      );

  /// Resuelve la base de la app web. Expuesto para tests.
  static String resolveWebBaseUrl({
    required bool isWeb,
    Uri? currentUri,
    String? defineOverride,
  }) {
    final fromDefine = (defineOverride ?? '').trim().replaceAll(RegExp(r'/+$'), '');
    if (fromDefine.isNotEmpty) return fromDefine;

    if (isWeb && currentUri != null) {
      final host = currentUri.host.toLowerCase();
      if (isBetaWebHost(host) || isProductionWebHost(host)) {
        return currentUri.origin.replaceAll(RegExp(r'/+$'), '');
      }
      if (host == 'localhost' ||
          host == '127.0.0.1' ||
          host.endsWith('.localhost')) {
        return currentUri.origin.replaceAll(RegExp(r'/+$'), '');
      }
    }
    return productionBaseUrl;
  }

  static String vaultPublicShareUrl(String token) {
    final t = token.trim();
    if (t.isEmpty) return folioWebBaseUrl;
    return '$folioWebBaseUrl/s/${Uri.encodeComponent(t)}';
  }

  /// URL a mostrar/copiar: prioriza [token] + base local (prod/beta).
  /// Si solo hay [publicUrlFromApi], reescribe hosts oficiales y el viewer legacy del API.
  static String resolveVaultPublicShareUrl({
    String? token,
    String? publicUrlFromApi,
  }) {
    final t = token?.trim() ?? '';
    if (t.isNotEmpty) return vaultPublicShareUrl(t);

    final raw = publicUrlFromApi?.trim() ?? '';
    if (raw.isEmpty) return folioWebBaseUrl;

    final uri = Uri.tryParse(raw);
    if (uri == null) return raw;

    // Legacy: …/api/v1/vault-shares/public/{token}/view → /s/{token}
    final segs = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    final viewIdx = segs.indexOf('view');
    if (viewIdx > 0 && segs[viewIdx - 1].isNotEmpty) {
      final maybeToken = segs[viewIdx - 1];
      final publicIdx = segs.indexOf('public');
      if (publicIdx >= 0 && publicIdx + 1 == viewIdx - 1) {
        return vaultPublicShareUrl(maybeToken);
      }
    }

    // …/s/{token} en folio o beta → reescribe al origen actual
    if (segs.length >= 2 && segs[0] == 's' && segs[1].isNotEmpty) {
      return vaultPublicShareUrl(Uri.decodeComponent(segs[1]));
    }

    if (isOfficialFolioWebHost(uri.host)) {
      return '$folioWebBaseUrl${uri.path}${uri.hasQuery ? '?${uri.query}' : ''}';
    }

    return raw;
  }

  static String resetPasswordUrl(String token) {
    return Uri.parse('$folioWebBaseUrl/reset-password')
        .replace(queryParameters: {'token': token.trim()})
        .toString();
  }

  static String verifyEmailUrl(String token) {
    return Uri.parse('$folioWebBaseUrl/verify-email')
        .replace(queryParameters: {'token': token.trim()})
        .toString();
  }

  static String verifyStudentEmailUrl(String token) {
    return Uri.parse('$folioWebBaseUrl/verify-student-email')
        .replace(queryParameters: {'token': token.trim()})
        .toString();
  }
}

/// Rutas públicas de Flutter web (sin vault lock / onboarding).
/// Válidas en hosts canónicos Minealex y futuros `*.folio.com.es`.
sealed class FolioWebPublicRoute {
  const FolioWebPublicRoute();

  static FolioWebPublicRoute? match(Uri uri) {
    final path = uri.path;
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();

    if (segments.length == 2 && segments[0] == 's') {
      final token = Uri.decodeComponent(segments[1]).trim();
      if (token.isNotEmpty) return FolioWebPublicShareRoute(token);
    }

    if (path == '/reset-password' ||
        (segments.length == 1 && segments[0] == 'reset-password')) {
      final token = (uri.queryParameters['token'] ?? '').trim();
      return FolioWebResetPasswordRoute(token);
    }

    if (path == '/verify-email' ||
        (segments.length == 1 && segments[0] == 'verify-email')) {
      final token = (uri.queryParameters['token'] ?? '').trim();
      return FolioWebVerifyEmailRoute(token);
    }

    if (path == '/verify-student-email' ||
        (segments.length == 1 && segments[0] == 'verify-student-email')) {
      final token = (uri.queryParameters['token'] ?? '').trim();
      return FolioWebVerifyStudentEmailRoute(token);
    }

    return null;
  }
}

final class FolioWebPublicShareRoute extends FolioWebPublicRoute {
  const FolioWebPublicShareRoute(this.token);
  final String token;
}

final class FolioWebResetPasswordRoute extends FolioWebPublicRoute {
  const FolioWebResetPasswordRoute(this.token);
  final String token;
}

final class FolioWebVerifyEmailRoute extends FolioWebPublicRoute {
  const FolioWebVerifyEmailRoute(this.token);
  final String token;
}

final class FolioWebVerifyStudentEmailRoute extends FolioWebPublicRoute {
  const FolioWebVerifyStudentEmailRoute(this.token);
  final String token;
}
