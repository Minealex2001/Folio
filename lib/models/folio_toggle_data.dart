import 'dart:convert';

/// Contenido de un bloque toggle (título + cuerpo).
class FolioToggleData {
  FolioToggleData({required this.title, required this.body});

  final String title;
  final String body;

  static FolioToggleData empty() => FolioToggleData(title: '', body: '');

  String encode() => jsonEncode({
        'v': 1,
        'title': title,
        'body': body,
      });

  static FolioToggleData? tryParse(String raw) {
    if (raw.trim().isEmpty) return FolioToggleData.empty();
    try {
      final m = jsonDecode(raw);
      if (m is! Map) return null;
      return FolioToggleData(
        title: (m['title'] as String?) ?? '',
        body: (m['body'] as String?) ?? '',
      );
    } catch (_) {
      return null;
    }
  }
}
