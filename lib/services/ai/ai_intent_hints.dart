class AiIntentHints {
  static const String edit = 'edit';
  static const String createPage = 'create_page';
  static const String subpage = 'subpage';

  static const Map<String, Map<String, List<String>>> _catalog = {
    'es': {
      edit: [
        'corrige',
        'corregir',
        'edita',
        'editar',
        'modifica',
        'modificar',
        'ajusta',
        'ajustar',
        'reescribe',
        'reescribir',
        'mejora',
        'mejorar',
        'actualiza',
        'actualizar',
        'anade',
        'anadir',
        'agrega',
        'agregar',
        'cambia',
        'cambiar',
        'renombra',
        'renombrar',
        'completa',
        'completar',
        'tabla',
        'columna',
        'bloque',
        'bloques',
        'pagina actual',
        'esta pagina',
        'texto actual',
      ],
      createPage: [
        'genera una pagina',
        'generar una pagina',
        'crear una pagina',
        'crea una pagina',
        'creame una pagina',
        'haz una pagina',
        'nueva pagina',
        'hazme una pagina',
        'genera una nota',
        'crea una nota',
        'nueva nota',
        'crea un documento',
        'nuevo documento',
        'desde cero',
      ],
      subpage: [
        'subpagina',
        'sub pagina',
        'sub-pagina',
        'hija',
        'hija de',
        'dentro de esta pagina',
        'dentro de la pagina actual',
        'debajo de esta pagina',
        'en esta pagina',
        'bajo esta pagina',
      ],
    },
    'en': {
      edit: [
        'edit',
        'update',
        'modify',
        'rewrite',
        'improve',
        'fix',
        'adjust',
        'rename',
        'add',
        'table',
        'column',
        'block',
        'blocks',
        'current page',
        'this page',
      ],
      createPage: [
        'new page',
        'create page',
        'generate page',
        'create a page',
        'make a page',
        'new note',
        'create note',
        'new document',
        'create document',
        'from scratch',
      ],
      subpage: [
        'sub-page',
        'subpage',
        'child page',
        'child of this page',
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
