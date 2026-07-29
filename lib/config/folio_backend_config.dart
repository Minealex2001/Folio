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
import 'folio_local_secrets.dart';

class FolioBackendConfig {
  FolioBackendConfig._();

  static const String _modeDefine = String.fromEnvironment(
    'FOLIO_BACKEND_MODE',
    defaultValue: '',
  );

  static const String _baseUrlDefine = String.fromEnvironment(
    'FOLIO_BACKEND_BASE_URL',
    defaultValue: '',
  );

  /// Base URL del API Spring (sin barra final). Vacío si no se definió.
  static String get baseUrl {
    final fromDefine = _baseUrlDefine.trim();
    if (fromDefine.isNotEmpty) return fromDefine;
    return FolioLocalSecrets.folioBackendBaseUrl.trim();
  }

  /// Tras Fase 30 (Firebase decomisionado) el cliente es Spring-only.
  static bool get useSpring => true;

  /// Alias legible para logs / UI de diagnóstico.
  static String get modeLabel => 'spring';

  /// URL base efectiva. Exige [baseUrl] no vacío.
  static String get apiBaseUrl {
    final trimmed = baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
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
}
