/// Fundamenta las respuestas de Quill sobre preguntas de la app en el
/// contenido real de `docs/FEATURES.md`, en vez de depender de lo que el
/// modelo "cree" que hace Folio. Dado que el documento es pequeño (~1300
/// líneas, ~24 secciones), un matching simple por solapamiento de palabras
/// clave es suficiente — no hace falta un índice vectorial/embeddings.
class FolioDocSection {
  const FolioDocSection({required this.heading, required this.body, required this.level});

  /// Texto del encabezado sin los `#` (p. ej. "23. Asistente IA Quill").
  final String heading;
  final String body;

  /// Número de `#` del encabezado (2 = `##`, 3 = `###`, ...).
  final int level;

  String toContextBlock({int maxChars = 2000}) {
    final trimmedBody = body.trim();
    final truncated = trimmedBody.length > maxChars
        ? '${trimmedBody.substring(0, maxChars)}…'
        : trimmedBody;
    return '## $heading\n$truncated';
  }
}

class FolioDocsGrounding {
  const FolioDocsGrounding(this._sections);

  final List<FolioDocSection> _sections;

  static final RegExp _headingLine = RegExp(r'^(#{2,6})\s+(.*)$');

  /// Parsea un markdown con encabezados `##`/`###`/... en secciones planas:
  /// cada encabezado inicia una sección que incluye todo el texto hasta el
  /// siguiente encabezado (de cualquier nivel) o el final del documento.
  factory FolioDocsGrounding.parse(String markdown) {
    final sections = <FolioDocSection>[];
    String? currentHeading;
    int currentLevel = 2;
    final currentBody = StringBuffer();
    // Normaliza CRLF -> LF: con finales \r\n, `(.*)$ ` no consume el `\r`
    // sobrante (no es tratado como parte de `.`) y el encabezado no matchea.
    final normalized = markdown.replaceAll('\r\n', '\n');

    void flush() {
      if (currentHeading == null) return;
      sections.add(
        FolioDocSection(heading: currentHeading, body: currentBody.toString(), level: currentLevel),
      );
      currentBody.clear();
    }

    for (final line in normalized.split('\n')) {
      final match = _headingLine.firstMatch(line);
      if (match != null) {
        flush();
        currentLevel = match.group(1)?.length ?? 2;
        currentHeading = (match.group(2) ?? '').trim();
        continue;
      }
      if (currentHeading != null) {
        currentBody.writeln(line);
      }
    }
    flush();

    return FolioDocsGrounding(sections);
  }

  static String _normalizeToken(String raw) {
    var s = raw.toLowerCase();
    const replacements = {'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u', 'ñ': 'n'};
    replacements.forEach((k, v) => s = s.replaceAll(k, v));
    return s;
  }

  static List<String> _tokenize(String text) {
    return _normalizeToken(text)
        .split(RegExp(r'[^a-z0-9]+'))
        .where((t) => t.length >= 3)
        .toList();
  }

  /// Secciones más relevantes para [query], ordenadas por relevancia
  /// descendente. Puntúa por solapamiento de términos: coincidencias en el
  /// encabezado pesan más que en el cuerpo. Devuelve `[]` si ningún término
  /// coincide (evita citar contenido no relacionado).
  List<FolioDocSection> matchSections(String query, {int maxSections = 3}) {
    final terms = _tokenize(query).toSet();
    if (terms.isEmpty) return const [];

    final scored = <(FolioDocSection, int)>[];
    for (final section in _sections) {
      final headingTokens = _tokenize(section.heading).toSet();
      final bodyLower = _normalizeToken(section.body);
      var score = 0;
      for (final term in terms) {
        if (headingTokens.contains(term)) score += 3;
        if (bodyLower.contains(term)) score += 1;
      }
      if (score > 0) scored.add((section, score));
    }

    scored.sort((a, b) => b.$2.compareTo(a.$2));
    return scored.take(maxSections).map((e) => e.$1).toList(growable: false);
  }

  int get sectionCount => _sections.length;
}
