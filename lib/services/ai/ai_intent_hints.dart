class AiIntentHints {
  static const String edit = 'edit';
  static const String createPage = 'create_page';
  static const String subpage = 'subpage';

  static const Map<String, Map<String, List<String>>> _catalog = {
    'es': {
      edit: [
        'edita',
        'editar',
        'modifica',
        'modificar',
        'actualiza',
        'actualizar',
        'anade',
        'agrega',
        'tabla',
        'columna',
        'bloque',
      ],
      createPage: [
        'genera una pagina',
        'generar una pagina',
        'crear una pagina',
        'crea una pagina',
        'creame una pagina',
        'nueva pagina',
        'hazme una pagina',
      ],
      subpage: [
        'subpagina',
        'sub pagina',
        'sub-pagina',
        'hija',
        'dentro de esta pagina',
        'dentro de la pagina actual',
        'en esta pagina',
        'bajo esta pagina',
      ],
    },
    'en': {
      edit: ['edit', 'update', 'modify', 'add', 'table', 'column', 'block'],
      createPage: ['new page', 'create page', 'generate page'],
      subpage: [
        'sub-page',
        'subpage',
        'child page',
        'inside this page',
        'under this page',
        'inside current page',
        'under current page',
      ],
    },
  };

  static List<String> hintsFor({
    required String intent,
    required String languageCode,
  }) {
    final normalizedLang = languageCode.trim().toLowerCase();
    final lang = normalizedLang.split(RegExp(r'[-_]')).first;
    if (lang == 'es') {
      return List<String>.from(_catalog['es']?[intent] ?? const []);
    }
    if (lang == 'en') {
      return List<String>.from(_catalog['en']?[intent] ?? const []);
    }
    return [
      ...?_catalog['en']?[intent],
      ...?_catalog['es']?[intent],
    ];
  }
}
