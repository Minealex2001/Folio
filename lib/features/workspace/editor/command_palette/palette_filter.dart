import 'palette_command.dart';

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
  final filtered = normalized.isEmpty
      ? List<PaletteCommand>.of(commands)
      : commands.where((c) {
          return c.id.toLowerCase().contains(normalized) ||
              c.label.toLowerCase().contains(normalized) ||
              c.hint.toLowerCase().contains(normalized);
        }).toList();

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
