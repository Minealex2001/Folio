import '../../models/folio_page.dart';

/// Spike de recuperación ligera (sin embeddings): tokeniza títulos y texto breve.
class FolioVaultLightSearch {
  FolioVaultLightSearch(this.pages);

  final List<FolioPage> pages;

  static Set<String> _tokens(String s) {
    return s
        .toLowerCase()
        .split(RegExp(r'[^\p{L}\p{N}]+', unicode: true))
        .where((e) => e.length > 1)
        .toSet();
  }

  /// Devuelve ids de página ordenados por solapamiento de tokens con [query].
  List<String> rankPageIds(String query, {int maxResults = 8}) {
    final qTokens = _tokens(query);
    if (qTokens.isEmpty) return [];
    final scored = <({String id, int score})>[];
    for (final p in pages) {
      final title = p.title.trim();
      final blob = StringBuffer(title)..write(' ');
      for (final b in p.blocks.take(12)) {
        blob.write(b.text);
        blob.write(' ');
      }
      final pTokens = _tokens(blob.toString());
      var score = 0;
      for (final t in qTokens) {
        if (pTokens.contains(t)) score++;
      }
      if (score > 0) {
        scored.add((id: p.id, score: score));
      }
    }
    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.take(maxResults).map((e) => e.id).toList();
  }
}
