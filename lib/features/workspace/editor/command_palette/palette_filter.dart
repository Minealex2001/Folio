import 'palette_command.dart';

/// Fase 1 del roadmap de producto (Command Center) — grupos de sinónimos en
/// lenguaje natural (ES/EN) que no aparecen literalmente en ningún
/// `id`/`label`/`hint`, mapeados a un fragmento de `id` que sí los
/// identifica. Deliberadamente una capa ligera de intención por
/// palabras-clave, NO un parser NL genérico ni una llamada a un modelo: el
/// propio roadmap acota esto a "despachar a los `PaletteCommand`
/// existentes", con búsqueda semántica explícitamente fuera de alcance
/// (stretch). Cuando el filtro literal (`filterPaletteCommands`) no
/// encuentra nada, se prueba esta capa antes de mostrar "sin resultados".
const Map<String, List<String>> _kPaletteNlIntentGroups = {
  'cmd_workspace_new_page': [
    'crear pagina', 'crear página', 'crear folio', 'nueva pagina',
    'nueva página', 'nuevo folio', 'create a page', 'create page',
    'new page', 'add page',
  ],
  'cmd_workspace_search': [
    'buscar', 'encontrar', 'search for', 'find', 'look for', 'lookup',
  ],
  'cmd_workspace_settings': [
    'ajustes', 'configuracion', 'configuración', 'preferencias',
    'preferences', 'options',
  ],
  'cmd_ai_summarize': [
    'resume esto', 'resumir', 'haz un resumen', 'sumariza', 'summarize this',
    'give me a summary', 'tldr',
  ],
  'cmd_ai_continue': [
    'continua escribiendo', 'sigue escribiendo', 'continue writing',
    'keep writing',
  ],
  'cmd_ai_explain': [
    'explica esto', 'explicame', 'explícame', 'explain this', 'what does this mean',
  ],
  'cmd_ai_action_items': [
    'extrae tareas', 'saca las tareas', 'extract action items',
    'extract tasks', 'pull out tasks',
  ],
  'cmd_ai_todo': ['crear tarea', 'nueva tarea', 'create a task', 'new task', 'add a todo'],
  'cmd_ai_mindmap': ['mapa mental', 'crea un mapa mental', 'mind map', 'mindmap'],
  'cmd_ai_table': ['crea una tabla', 'hazlo tabla', 'make a table', 'turn into a table'],
  'cmd_ai_improve': ['mejora esto', 'mejora el texto', 'improve this', 'make it better'],
  'cmd_ai_translate': ['traduce esto', 'traducir', 'translate this'],
};

/// Fase C1 del rediseño UX del editor — filtro/ranking del Command Palette.
/// Mismo enfoque que `BlockEditorState._catalogFilteredForSlash` (Fase G1):
/// substring sobre id/label/hint + orden estable original como desempate —
/// una sola forma de rankear "cosas que aparecen en un menú de comandos" en
/// todo el editor, no una segunda librería de fuzzy-matching.
List<PaletteCommand> filterPaletteCommands(
  List<PaletteCommand> commands,
  String query, {
  Map<String, int> recentScores = const {},
}) {
  final normalized = query.trim().toLowerCase();
  var filtered = normalized.isEmpty
      ? List<PaletteCommand>.of(commands)
      : commands.where((c) {
          return c.id.toLowerCase().contains(normalized) ||
              c.label.toLowerCase().contains(normalized) ||
              c.hint.toLowerCase().contains(normalized);
        }).toList();

  // Fase 1 del roadmap de producto — el filtro literal no encontró nada
  // pero la query parece una frase (varias palabras): antes de rendirse,
  // prueba la capa de intención por sinónimos.
  if (filtered.isEmpty &&
      normalized.isNotEmpty &&
      normalized.contains(' ')) {
    filtered = _nlIntentMatches(commands, normalized);
  }

  if (filtered.length < 2) return filtered;
  final originalIndex = {for (var i = 0; i < commands.length; i++) commands[i].id: i};
  filtered.sort((a, b) {
    final aScore = recentScores[a.id] ?? 0;
    final bScore = recentScores[b.id] ?? 0;
    if (aScore != bScore) return bScore.compareTo(aScore);
    return (originalIndex[a.id] ?? 0).compareTo(originalIndex[b.id] ?? 0);
  });
  return filtered;
}

List<PaletteCommand> _nlIntentMatches(
  List<PaletteCommand> commands,
  String normalizedQuery,
) {
  final matchedIds = <String>{};
  for (final entry in _kPaletteNlIntentGroups.entries) {
    for (final trigger in entry.value) {
      if (normalizedQuery.contains(trigger)) {
        matchedIds.add(entry.key);
        break;
      }
    }
  }
  if (matchedIds.isEmpty) return const [];
  return commands.where((c) => matchedIds.contains(c.id)).toList();
}
