/// URLs públicas de estado Folio Cloud en Minealex Games.
class FolioStatusUrls {
  FolioStatusUrls._();

  static const String defaultApiUrl =
      'https://minealexgames.com/api/folio/status';

  static const String _apiUrlDefine = String.fromEnvironment(
    'FOLIO_STATUS_API_URL',
    defaultValue: '',
  );

  /// Idiomas con página de estado en minealexgames.com.
  static const Set<String> knownStatusPageLangs = {
    'es',
    'en',
    'ca',
    'eu',
    'gl',
    'pt',
  };

  /// Endpoint JSON público (servicios, incidencias, historial).
  static String get apiUrl {
    final fromDefine = _apiUrlDefine.trim().replaceAll(RegExp(r'/+$'), '');
    if (fromDefine.isNotEmpty) return fromDefine;
    return defaultApiUrl;
  }

  /// Página web “Más info” — canónica: `https://minealexgames.com/es/folio/status`.
  static Uri statusPageUri({String? languageCode}) {
    final raw = (languageCode ?? 'es').trim().toLowerCase();
    final lang = knownStatusPageLangs.contains(raw) ? raw : 'es';
    return Uri.parse('https://minealexgames.com/$lang/folio/status');
  }
}
