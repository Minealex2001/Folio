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

  /// Igual que [tryParse] pero nunca descarta contenido: si [raw] no es JSON de
  /// toggle válido pero contiene texto (formato antiguo en texto plano), lo
  /// conserva como cuerpo en vez de vaciarlo.
  static FolioToggleData parseOrLegacy(String raw) {
    return tryParse(raw) ?? FolioToggleData(title: '', body: raw);
  }
}
