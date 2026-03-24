import 'dart:convert';

/// Contenido de un bloque de columnas (2–3 columnas de texto Markdown).
class FolioColumnsData {
  FolioColumnsData({required this.columns})
    : assert(columns.length >= 2 && columns.length <= 3);

  final List<String> columns;

  static FolioColumnsData empty() =>
      FolioColumnsData(columns: ['', '']);

  String encode() => jsonEncode({
    'v': 1,
    'columns': columns,
  });

  static FolioColumnsData? tryParse(String raw) {
    if (raw.trim().isEmpty) return null;
    try {
      final m = jsonDecode(raw);
      if (m is! Map) return null;
      final list = (m['columns'] as List<dynamic>?) ?? [];
      final cols = list.map((e) => e.toString()).toList();
      if (cols.length < 2) {
        return FolioColumnsData(columns: [cols.elementAt(0), '']);
      }
      if (cols.length > 3) {
        return FolioColumnsData(columns: cols.take(3).toList());
      }
      return FolioColumnsData(columns: cols);
    } catch (_) {
      return null;
    }
  }
}
