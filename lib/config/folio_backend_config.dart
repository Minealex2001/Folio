/// Cutover Firebase → Spring Boot (Fase 29): modo backend en compile-time.
///
/// Default = **Firebase** (comportamiento actual). Activar Spring:
///
/// ```bash
/// flutter run -d windows --dart-define=FOLIO_BACKEND_MODE=spring \
///   --dart-define=FOLIO_BACKEND_BASE_URL=http://127.0.0.1:18080
/// ```
///
/// En Windows usa `127.0.0.1` (no `localhost`): Dart resuelve `localhost` a IPv4
/// y el puerto 8080 suele estar ocupado por el remote debugging de CEF/Cursor.
/// El compose publica el API en **18080** por defecto.
///
/// Rollback: omitir los defines (o `FOLIO_BACKEND_MODE=firebase`).
class FolioBackendConfig {
  FolioBackendConfig._();

  static const String _mode = String.fromEnvironment(
    'FOLIO_BACKEND_MODE',
    defaultValue: 'firebase',
  );

  /// Base URL del API Spring (sin barra final). Vacío si no se definió.
  static const String baseUrl = String.fromEnvironment(
    'FOLIO_BACKEND_BASE_URL',
    defaultValue: '',
  );

  /// `true` cuando el build apunta al backend Spring (`FOLIO_BACKEND_MODE=spring`).
  static bool get useSpring {
    final m = _mode.trim().toLowerCase();
    return m == 'spring' || m == 'springboot' || m == 'backend';
  }

  /// Alias legible para logs / UI de diagnóstico.
  static String get modeLabel => useSpring ? 'spring' : 'firebase';

  /// URL base efectiva. En modo Spring exige [baseUrl] no vacío.
  static String get apiBaseUrl {
    final trimmed = baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    if (trimmed.isEmpty) {
      throw StateError(
        'FOLIO_BACKEND_BASE_URL is required when FOLIO_BACKEND_MODE=spring '
        '(e.g. http://127.0.0.1:18080)',
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
}
