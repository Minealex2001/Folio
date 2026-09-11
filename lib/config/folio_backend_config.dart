/// Cutover Firebase → Spring Boot (Fase 29–30): backend = Spring únicamente.
///
/// Config (prioridad: `--dart-define` > [FolioLocalSecrets]):
///
/// ```bash
/// flutter run -d windows --dart-define=FOLIO_BACKEND_BASE_URL=https://….up.railway.app
/// ```
///
/// Local (compose): `http://127.0.0.1:18080`. En Windows usa `127.0.0.1`, no
/// `localhost` (CEF/Cursor suele ocupar `:8080`).
///
/// Fallback de host (filtros corporativos que bloquean `*.folio.com.es`):
/// - `api.folio.com.es` → `backendfolio.minealexgames.com`
/// - `api-beta.folio.com.es` → `backendfoliobeta.minealexgames.com`
///
/// Tras el primer éxito por el host de respaldo, la sesión sticky usa ese
/// origen el resto del proceso (HTTP + WebSocket collab).
import 'package:flutter/foundation.dart';

import 'folio_local_secrets.dart';

class FolioBackendConfig {
  FolioBackendConfig._();

  static const String _baseUrlDefine = String.fromEnvironment(
    'FOLIO_BACKEND_BASE_URL',
    defaultValue: '',
  );

  /// Host canónico de producto (prod).
  static const String canonicalApiHost = 'api.folio.com.es';

  /// Host canónico de producto (beta).
  static const String canonicalApiBetaHost = 'api-beta.folio.com.es';

  /// Respaldo Minealex (prod) cuando el canónico está bloqueado.
  static const String fallbackApiBaseUrl =
      'https://backendfolio.minealexgames.com';

  /// Respaldo Minealex (beta) cuando el canónico beta está bloqueado.
  static const String fallbackApiBetaBaseUrl =
      'https://backendfoliobeta.minealexgames.com';

  /// Override de sesión tras activar el fallback (sin barra final).
  static String? _sessionBaseUrlOverride;

  /// Base URL del API Spring (sin barra final). Vacío si no se definió.
  ///
  /// No aplica el sticky de fallback; usar [apiBaseUrl] / [configuredBaseUrl]
  /// según el caso.
  static String get baseUrl {
    final fromDefine = _baseUrlDefine.trim();
    if (fromDefine.isNotEmpty) return fromDefine;
    return FolioLocalSecrets.folioBackendBaseUrl.trim();
  }

  /// Base configurada (define/secrets), sin sticky de sesión.
  static String get configuredBaseUrl =>
      baseUrl.trim().replaceAll(RegExp(r'/+$'), '');

  /// Tras Fase 30 (Firebase decomisionado) el cliente es Spring-only.
  static bool get useSpring => true;

  /// Alias legible para logs / UI de diagnóstico.
  static String get modeLabel => 'spring';

  /// `true` si esta sesión ya pegó al host de respaldo.
  static bool get isUsingHostFallback =>
      (_sessionBaseUrlOverride ?? '').trim().isNotEmpty;

  /// Host de respaldo sticky actual, o `null`.
  static String? get sessionBaseUrlOverride => _sessionBaseUrlOverride;

  /// URL base efectiva. Exige [baseUrl] no vacío.
  ///
  /// Si el fallback de host está activo, devuelve ese origen.
  static String get apiBaseUrl {
    final override = _sessionBaseUrlOverride?.trim().replaceAll(
      RegExp(r'/+$'),
      '',
    );
    if (override != null && override.isNotEmpty) return override;

    final trimmed = configuredBaseUrl;
    if (trimmed.isEmpty) {
      throw StateError(
        'FOLIO_BACKEND_BASE_URL is required '
        '(Railway: https://….up.railway.app — local: http://127.0.0.1:18080)',
      );
    }
    return trimmed;
  }

  /// Prefijo REST v1.
  static String get apiV1Prefix => '${apiBaseUrl}/api/v1';

  /// WebSocket collab (STOMP). Deriva de [apiBaseUrl] (`http`→`ws`, `https`→`wss`).
  static String get collabWsUrl {
    final base = apiBaseUrl;
    if (base.startsWith('https://')) {
      return 'wss://${base.substring('https://'.length)}/ws/collab';
    }
    if (base.startsWith('http://')) {
      return 'ws://${base.substring('http://'.length)}/ws/collab';
    }
    return '$base/ws/collab';
  }

  /// Base de respaldo para [primaryBaseUrl] si el host es canónico bloqueable.
  ///
  /// Devuelve `null` si no hay mapeo (Railway raw, localhost, ya en Minealex…).
  static String? fallbackBaseUrlFor(String primaryBaseUrl) {
    final trimmed = primaryBaseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    if (trimmed.isEmpty) return null;
    final uri = Uri.tryParse(trimmed);
    final host = (uri?.host ?? '').toLowerCase();
    if (host.isEmpty) return null;
    return fallbackBaseUrlForHost(host);
  }

  /// Igual que [fallbackBaseUrlFor] pero a partir del hostname.
  static String? fallbackBaseUrlForHost(String host) {
    final h = host.trim().toLowerCase();
    if (h == canonicalApiHost || h == 'www.$canonicalApiHost') {
      return fallbackApiBaseUrl;
    }
    if (h == canonicalApiBetaHost) {
      return fallbackApiBetaBaseUrl;
    }
    return null;
  }

  /// Reescribe [uri] al host de respaldo si aplica; si no, `null`.
  static Uri? rewriteUriWithFallback(Uri uri) {
    final fallbackBase = fallbackBaseUrlForHost(uri.host);
    if (fallbackBase == null) return null;
    final fallbackUri = Uri.parse(fallbackBase);
    return uri.replace(
      scheme: fallbackUri.scheme,
      host: fallbackUri.host,
      port: fallbackUri.hasPort ? fallbackUri.port : null,
    );
  }

  /// Activa el sticky de sesión hacia [fallbackBaseUrl].
  static void activateHostFallback(String fallbackBaseUrl) {
    final trimmed = fallbackBaseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    if (trimmed.isEmpty) return;
    if (_sessionBaseUrlOverride == trimmed) return;
    _sessionBaseUrlOverride = trimmed;
  }

  /// Si [uri] apunta a un host canónico con respaldo y aún no hay sticky,
  /// activa el sticky y devuelve la URI reescrita. Si no aplica, `null`.
  static Uri? activateHostFallbackForUri(Uri uri) {
    final rewritten = rewriteUriWithFallback(uri);
    if (rewritten == null) return null;
    final fallbackBase = fallbackBaseUrlForHost(uri.host);
    if (fallbackBase != null) {
      activateHostFallback(fallbackBase);
    }
    return rewritten;
  }

  /// Reescribe [uri] si el sticky ya apunta a otro host (p. ej. URI antigua).
  static Uri applySessionHostOverride(Uri uri) {
    final override = _sessionBaseUrlOverride?.trim().replaceAll(
      RegExp(r'/+$'),
      '',
    );
    if (override == null || override.isEmpty) return uri;
    final overrideUri = Uri.parse(override);
    if (uri.host.toLowerCase() == overrideUri.host.toLowerCase()) {
      return uri;
    }
    // Solo reescribir hosts del API Folio (canónico o el configurado original).
    final configuredHost =
        Uri.tryParse(configuredBaseUrl)?.host.toLowerCase() ?? '';
    final h = uri.host.toLowerCase();
    final isFolioApiHost = h == canonicalApiHost ||
        h == canonicalApiBetaHost ||
        h == 'www.$canonicalApiHost' ||
        (configuredHost.isNotEmpty && h == configuredHost);
    if (!isFolioApiHost) return uri;
    return uri.replace(
      scheme: overrideUri.scheme,
      host: overrideUri.host,
      port: overrideUri.hasPort ? overrideUri.port : null,
    );
  }

  /// Limpia el sticky (tests / reinicio de sesión de red).
  @visibleForTesting
  static void debugResetHostFallback() {
    _sessionBaseUrlOverride = null;
  }
}
