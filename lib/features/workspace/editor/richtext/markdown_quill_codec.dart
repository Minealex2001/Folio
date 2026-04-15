import 'package:dart_quill_delta/dart_quill_delta.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;

/// Codec mínimo Markdown (subset Folio) <-> Quill Document.
///
/// Soporta:
/// - **bold**
/// - _italic_
/// - ~~strike~~
/// - `code`
/// - <u>underline</u>
/// - [label](url) (atributo link)
///
/// Nota: es un parser intencionalmente simple (sin anidado complejo).
class FolioMarkdownQuillCodec {
  static quill.Document markdownToDocument(String markdown) {
    final delta = Delta();
    final runs = _parseRuns(markdown);
    for (final r in runs) {
      delta.insert(r.text, r.attrs);
    }
    // Quill espera terminar con newline para bloques.
    if (runs.isEmpty || !runs.last.text.endsWith('\n')) {
      delta.insert('\n');
    }
    return quill.Document.fromDelta(delta);
  }

  static String documentToMarkdown(quill.Document doc) {
    final buf = StringBuffer();
    for (final op in doc.toDelta().toList()) {
      final data = op.data;
      if (data is! String) continue;
      final attrs = (op.attributes ?? const <String, dynamic>{});
      // Quill termina con '\n' de bloque; lo mantenemos tal cual.
      var text = data;

      final isCode = attrs.containsKey(quill.Attribute.codeBlock.key) ||
          attrs.containsKey(quill.Attribute.inlineCode.key);
      if (isCode) {
        // Inline code: si contiene `, no intentamos envolver.
        if (!text.contains('`')) {
          buf.write('`$text`');
        } else {
          buf.write(text);
        }
        continue;
      }

      final link = attrs[quill.Attribute.link.key];
      final isBold = attrs.containsKey(quill.Attribute.bold.key);
      final isItalic = attrs.containsKey(quill.Attribute.italic.key);
      final isStrike = attrs.containsKey(quill.Attribute.strikeThrough.key);
      final isUnderline = attrs.containsKey(quill.Attribute.underline.key);

      String wrap(String t) {
        var out = t;
        if (isUnderline) out = '<u>$out</u>';
        if (isStrike) out = '~~$out~~';
        if (isItalic) out = '_${out}_';
        if (isBold) out = '**$out**';
        return out;
      }

      if (link is String && link.isNotEmpty) {
        final label = wrap(text);
        buf.write('[$label]($link)');
      } else {
        buf.write(wrap(text));
      }
    }
    return buf.toString();
  }
}

class _Run {
  const _Run(this.text, this.attrs);
  final String text;
  final Map<String, dynamic>? attrs;
}

List<_Run> _parseRuns(String src) {
  final out = <_Run>[];
  var i = 0;

  void emit(String text, Map<String, dynamic>? attrs) {
    if (text.isEmpty) return;
    out.add(_Run(text, attrs));
  }

  // Busca el siguiente match más cercano de un set de patrones.
  while (i < src.length) {
    final rest = src.substring(i);

    _Match? best;
    for (final m in <_Match?>[
      _matchLink(rest),
      _matchInline('**', '**', rest),
      _matchInline('~~', '~~', rest),
      _matchInline('_', '_', rest),
      _matchInline('`', '`', rest),
      _matchUnderline(rest),
    ]) {
      if (m == null) continue;
      if (best == null || m.start < best.start) best = m;
    }

    if (best == null) {
      emit(rest, null);
      break;
    }

    if (best.start > 0) {
      emit(rest.substring(0, best.start), null);
    }

    emit(best.inner, best.attrs);
    i += best.start + best.len;
  }

  return out;
}

class _Match {
  const _Match({
    required this.start,
    required this.len,
    required this.inner,
    required this.attrs,
  });
  final int start;
  final int len;
  final String inner;
  final Map<String, dynamic>? attrs;
}

_Match? _matchInline(String left, String right, String s) {
  final start = s.indexOf(left);
  if (start < 0) return null;
  final end = s.indexOf(right, start + left.length);
  if (end < 0) return null;
  final inner = s.substring(start + left.length, end);
  if (inner.isEmpty) return null;
  final attrs = switch (left) {
    '**' => {quill.Attribute.bold.key: true},
    '_' => {quill.Attribute.italic.key: true},
    '~~' => {quill.Attribute.strikeThrough.key: true},
    '`' => {quill.Attribute.inlineCode.key: true},
    _ => null,
  };
  return _Match(
    start: start,
    len: (end + right.length) - start,
    inner: inner,
    attrs: attrs,
  );
}

_Match? _matchUnderline(String s) {
  const left = '<u>';
  const right = '</u>';
  final start = s.indexOf(left);
  if (start < 0) return null;
  final end = s.indexOf(right, start + left.length);
  if (end < 0) return null;
  final inner = s.substring(start + left.length, end);
  if (inner.isEmpty) return null;
  return _Match(
    start: start,
    len: (end + right.length) - start,
    inner: inner,
    attrs: {quill.Attribute.underline.key: true},
  );
}

_Match? _matchLink(String s) {
  final open = s.indexOf('[');
  if (open < 0) return null;
  final close = s.indexOf('](', open + 1);
  if (close < 0) return null;
  final end = s.indexOf(')', close + 2);
  if (end < 0) return null;
  final label = s.substring(open + 1, close);
  final url = s.substring(close + 2, end).trim();
  if (label.isEmpty || url.isEmpty) return null;
  return _Match(
    start: open,
    len: (end + 1) - open,
    inner: label,
    attrs: {quill.Attribute.link.key: url},
  );
}

