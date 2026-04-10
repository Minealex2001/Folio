import '../../../models/block.dart';

/// Entradas para el índice de página (H1–H3) y navegación a bloque.
typedef PageOutlineEntry = ({String id, String text, int level});

List<PageOutlineEntry> pageOutlineEntriesFromBlocks(List<FolioBlock> blocks) {
  final entries = <PageOutlineEntry>[];
  for (final b in blocks) {
    final level = switch (b.type) {
      'h1' => 1,
      'h2' => 2,
      'h3' => 3,
      _ => 0,
    };
    if (level == 0) continue;
    final t = b.text.trim();
    if (t.isEmpty) continue;
    entries.add((id: b.id, text: t, level: level));
  }
  return entries;
}
