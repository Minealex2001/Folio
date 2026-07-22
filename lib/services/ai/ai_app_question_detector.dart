/// Heurística bilingüe para detectar cuándo un mensaje del usuario pregunta
/// sobre la propia app Folio ("¿cómo hago X en Folio?") en vez de pedir
/// contenido/acciones sobre sus notas. Sigue el mismo estilo de catálogo por
/// idioma que `ai_intent_hints.dart`.
class AiAppQuestionDetector {
  static const _questionMarkersEs = [
    'como hago',
    'como puedo',
    'como se',
    'como funciona',
    'donde esta',
    'donde estan',
    'donde puedo',
    'que es',
    'para que sirve',
    'se puede',
    'puedo',
    'hay alguna forma',
    'hay algun atajo',
  ];

  static const _questionMarkersEn = [
    'how do i',
    'how can i',
    'how does',
    'where is',
    'where are',
    'where can i',
    'what is',
    'what does',
    'is there a way',
    'is there a shortcut',
    'can i',
    'does folio',
  ];

  static const _appNouns = [
    // ES
    'pagina',
    'paginas',
    'bloque',
    'bloques',
    'libreta',
    'carpeta',
    'carpetas',
    'papelera',
    'etiqueta',
    'etiquetas',
    'atajo',
    'atajos',
    'sincronizacion',
    'colaboracion',
    'cifrado',
    'plantilla',
    'exportar',
    'importar',
    'quill',
    'folio',
    // EN
    'page',
    'pages',
    'block',
    'blocks',
    'notebook',
    'folder',
    'folders',
    'trash',
    'tag',
    'tags',
    'shortcut',
    'shortcuts',
    'sync',
    'collab',
    'collaboration',
    'encryption',
    'template',
    'export',
    'import',
  ];

  static String _normalize(String raw) {
    var s = raw.toLowerCase().trim();
    const replacements = {
      'á': 'a',
      'é': 'e',
      'í': 'i',
      'ó': 'o',
      'ú': 'u',
      'ñ': 'n',
    };
    replacements.forEach((k, v) => s = s.replaceAll(k, v));
    return s;
  }

  /// `true` si [prompt] tiene forma de pregunta sobre la app (marcador de
  /// pregunta + sustantivo de dominio de Folio, o directamente `?` + un
  /// sustantivo de dominio).
  static bool looksLikeAppQuestion(String prompt, {String languageCode = 'es'}) {
    final p = _normalize(prompt);
    if (p.isEmpty) return false;

    final hasAppNoun = _appNouns.any(p.contains);
    if (!hasAppNoun) return false;

    final hasQuestionMarker =
        _questionMarkersEs.any(p.contains) || _questionMarkersEn.any(p.contains);
    final hasQuestionMark = prompt.contains('?');

    return hasQuestionMarker || hasQuestionMark;
  }
}
