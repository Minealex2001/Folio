import 'package:flutter/services.dart' show rootBundle;

import 'folio_docs_grounding.dart';

/// Carga perezosa y cacheada de `docs/FEATURES.md` (empaquetado como asset,
/// ver `pubspec.yaml`) para fundamentar las respuestas de Quill sobre
/// preguntas de la app en contenido real en vez de en lo que el modelo
/// "cree" que hace Folio.
class FolioDocsGroundingLoader {
  FolioDocsGroundingLoader._();

  static FolioDocsGrounding? _cached;

  /// Devuelve `null` si el asset no pudo cargarse (no debe romper el chat).
  static Future<FolioDocsGrounding?> load() async {
    final cached = _cached;
    if (cached != null) return cached;
    try {
      final markdown = await rootBundle.loadString('docs/FEATURES.md');
      final parsed = FolioDocsGrounding.parse(markdown);
      _cached = parsed;
      return parsed;
    } catch (_) {
      return null;
    }
  }
}
