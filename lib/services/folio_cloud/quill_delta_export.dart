import 'dart:convert';

import 'package:dart_quill_delta/dart_quill_delta.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// Escapes plain text for HTML (body fragments).
String folioEscapeHtml(String s) {
  return s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
}

String? folioCssColorOrNull(String raw) {
  final t = raw.trim();
  if (t.isEmpty) return null;
  if (t.contains(';') || t.contains('url(') || t.toLowerCase().contains('expression')) {
    return null;
  }
  final lower = t.toLowerCase();
  if (lower == 'transparent') return 'transparent';
  final hex = RegExp(r'^#([0-9a-f]{3}|[0-9a-f]{6}|[0-9a-f]{8})$', caseSensitive: false);
  if (hex.hasMatch(t)) return t;
  const named = {
    'black',
    'white',
    'red',
    'green',
    'blue',
    'yellow',
    'orange',
    'purple',
    'gray',
    'grey',
  };
  if (named.contains(lower)) return lower;
  return null;
}

PdfColor? folioPdfColorOrNull(String? raw) {
  final css = raw == null ? null : folioCssColorOrNull(raw);
  if (css == null || css == 'transparent') return null;
  final t = css.trim();
  if (!t.startsWith('#')) return null;
  var h = t.substring(1);
  if (h.length == 3) {
    h = h.split('').map((c) => '$c$c').join();
  }
  if (h.length != 6) return null;
  final v = int.tryParse(h, radix: 16);
  if (v == null) return null;
  final r = (v >> 16) & 0xff;
  final g = (v >> 8) & 0xff;
  final b = v & 0xff;
  return PdfColor(r, g, b);
}

String? folioSafeHrefOrNull(String raw) {
  final t = raw.trim();
  if (t.isEmpty) return null;
  final lower = t.toLowerCase();
  if (lower.startsWith('javascript:') ||
      lower.startsWith('vbscript:') ||
      lower.startsWith('data:')) {
    return null;
  }
  return folioEscapeHtml(t);
}

/// Convierte Delta JSON (lista de ops Quill) a HTML inline seguro (sin envolver en bloque).
String folioQuillDeltaJsonToInlineHtml(
  String? jsonStr, {
  required String fallbackMarkdown,
}) {
  final fromDelta = _deltaJsonToInlineHtmlOrNull(jsonStr);
  if (fromDelta != null && fromDelta.isNotEmpty) {
    return fromDelta;
  }
  return folioEscapeHtml(fallbackMarkdown).replaceAll('\n', '<br>');
}

String? _deltaJsonToInlineHtmlOrNull(String? jsonStr) {
  if (jsonStr == null || jsonStr.trim().isEmpty) return null;
  try {
    final raw = jsonDecode(jsonStr);
    if (raw is! List) return null;
    final delta = Delta.fromJson(raw);
    final buf = StringBuffer();
    for (final op in delta.toList()) {
      if (op.key != Operation.insertKey) continue;
      final d = op.data;
      if (d is! String) {
        buf.write('<span class="folio-embed">…</span>');
        continue;
      }
      buf.write(_deltaInsertToHtml(d, op.attributes));
    }
    var s = buf.toString();
    while (s.endsWith('<br>')) {
      s = s.substring(0, s.length - 4);
    }
    return s.isEmpty ? null : s;
  } catch (_) {
    return null;
  }
}

String _deltaInsertToHtml(String text, Map<String, dynamic>? attrs) {
  final esc = folioEscapeHtml(text);
  final parts = esc.split('\n');
  var s = parts.join('<br>');
  return _applyQuillAttrsToHtml(s, attrs);
}

String _applyQuillAttrsToHtml(String inner, Map<String, dynamic>? attrs) {
  if (attrs == null || attrs.isEmpty) return inner;
  var s = inner;

  if (attrs['code'] == true) {
    s = '<code>$s</code>';
  }

  final link = attrs['link'];
  if (link is String && link.isNotEmpty) {
    final h = folioSafeHrefOrNull(link);
    if (h != null) {
      s = '<a href="$h" rel="noopener noreferrer" target="_blank">$s</a>';
    }
  }

  final style = <String>[];
  final c = attrs['color'];
  if (c is String && c.isNotEmpty) {
    final css = folioCssColorOrNull(c);
    if (css != null) style.add('color:$css');
  }
  final bg = attrs['background'];
  if (bg is String && bg.isNotEmpty) {
    final css = folioCssColorOrNull(bg);
    if (css != null) style.add('background-color:$css');
  }
  if (style.isNotEmpty) {
    s = '<span style="${style.join(';')}">$s</span>';
  }

  if (attrs['strike'] == true) s = '<s>$s</s>';
  if (attrs['underline'] == true) s = '<u>$s</u>';
  if (attrs['italic'] == true) s = '<em>$s</em>';
  if (attrs['bold'] == true) s = '<strong>$s</strong>';
  return s;
}

/// Fragmento de texto para maquetación PDF (Syncfusion).
class FolioPdfWord {
  FolioPdfWord({
    required this.text,
    required this.font,
    required this.brush,
    this.back,
    this.hardBreak = false,
  });

  /// Si [hardBreak] es true, [text] se ignora y se fuerza salto de línea.
  final String text;
  final PdfFont font;
  final PdfBrush brush;
  final PdfColor? back;
  final bool hardBreak;
}

class FolioPdfFontCache {
  FolioPdfFontCache._(this._size);

  factory FolioPdfFontCache(double size) => FolioPdfFontCache._(size);

  final double _size;

  PdfFont get _reg => PdfStandardFont(PdfFontFamily.helvetica, _size);

  PdfFont get _bold => PdfStandardFont(
        PdfFontFamily.helvetica,
        _size,
        style: PdfFontStyle.bold,
      );

  PdfFont get _italic => PdfStandardFont(
        PdfFontFamily.helvetica,
        _size,
        style: PdfFontStyle.italic,
      );

  PdfFont get _boldItalic => PdfStandardFont(
        PdfFontFamily.helvetica,
        _size,
        multiStyle: [PdfFontStyle.bold, PdfFontStyle.italic],
      );

  PdfFont get _code => PdfStandardFont(PdfFontFamily.courier, _size * 0.95);

  PdfFont fontFor({
    required bool bold,
    required bool italic,
    required bool code,
  }) {
    if (code) return _code;
    if (bold && italic) return _boldItalic;
    if (bold) return _bold;
    if (italic) return _italic;
    return _reg;
  }
}

List<FolioPdfWord> folioQuillDeltaJsonToPdfWords(
  String? jsonStr, {
  required double fontSize,
  required PdfColor defaultColor,
  required FolioPdfFontCache fonts,
}) {
  final out = <FolioPdfWord>[];
  void addPlainWords(String text, Map<String, dynamic>? attrs) {
    final bold = attrs?['bold'] == true;
    final italic = attrs?['italic'] == true;
    final code = attrs?['code'] == true;
    final font = fonts.fontFor(bold: bold, italic: italic, code: code);
    final colorRaw = attrs == null ? null : attrs['color'];
    final fg = colorRaw is String ? folioPdfColorOrNull(colorRaw) : null;
    final brush = PdfSolidBrush(fg ?? defaultColor);
    final bgRaw = attrs == null ? null : attrs['background'];
    final bg = bgRaw is String ? folioPdfColorOrNull(bgRaw) : null;

    final lines = text.split('\n');
    for (var li = 0; li < lines.length; li++) {
      if (li > 0) {
        out.add(
          FolioPdfWord(
            text: '',
            font: font,
            brush: brush,
            hardBreak: true,
          ),
        );
      }
      final line = lines[li];
      final words = line.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
      for (final w in words) {
        out.add(FolioPdfWord(text: w, font: font, brush: brush, back: bg));
      }
    }
  }

  if (jsonStr == null || jsonStr.trim().isEmpty) {
    return out;
  }
  try {
    final raw = jsonDecode(jsonStr);
    if (raw is! List) return out;
    final delta = Delta.fromJson(raw);
    for (final op in delta.toList()) {
      if (op.key != Operation.insertKey) continue;
      final d = op.data;
      if (d is! String) continue;
      addPlainWords(d, op.attributes);
    }
  } catch (_) {}
  return out;
}

List<FolioPdfWord> folioPlainMarkdownToPdfWords(
  String markdown,
  double fontSize,
  PdfColor defaultColor,
) {
  final fonts = FolioPdfFontCache(fontSize);
  final font = fonts.fontFor(bold: false, italic: false, code: false);
  final brush = PdfSolidBrush(defaultColor);
  return markdown
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .map((w) => FolioPdfWord(text: w, font: font, brush: brush))
      .toList();
}
