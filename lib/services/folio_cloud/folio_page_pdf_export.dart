import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Offset, Rect;

import 'package:markdown/markdown.dart' as md;
import 'package:pdf/pdf.dart' as pw;
import 'package:printing/printing.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../../models/block.dart';
import '../../models/folio_page.dart';
import '../integrations/integrations_markdown_codec.dart';
import 'folio_page_html_export.dart';
import 'quill_delta_export.dart';

/// PDF con el mismo HTML que la exportación web cuando la plataforma soporta
/// [Printing.convertHtml] (p. ej. algunas plataformas móviles).
///
/// En Windows/desktop suele usarse el maquetador Syncfusion con estilos WYSIWYG
/// (colores y formato desde Quill Delta).
Future<Uint8List> folioPageExportPdfBytes({
  required FolioPage page,
  required String pagePublishedSubtitle,
  String? appIconDataUri,
}) async {
  final info = await Printing.info();
  if (info.canConvertHtml) {
    final html = folioPageExportHtmlDocument(
      page,
      appIconDataUri: appIconDataUri,
      pagePublishedSubtitle: pagePublishedSubtitle,
    );
    return Printing.convertHtml(
      html: html,
      format: pw.PdfPageFormat.a4,
    );
  }
  return Uint8List.fromList(
    _folioPdfExportSyncfusion(page, pagePublishedSubtitle),
  );
}

class _FolioPdfCtx {
  _FolioPdfCtx(this.doc)
      : page = doc.pages.add(),
        y = margin;

  final PdfDocument doc;
  PdfPage page;
  double y;

  static const double margin = 36;

  PdfGraphics get graphics => page.graphics;

  double contentWidth() => page.getClientSize().width - 2 * margin;

  double bottom() => page.getClientSize().height - margin;

  void ensureSpace(double blockHeight) {
    if (y + blockHeight > bottom()) {
      page = doc.pages.add();
      y = margin;
    }
  }
}

bool _folioPdfBlockAllowsRich(FolioBlock b) {
  switch (b.type) {
    case 'paragraph':
    case 'h1':
    case 'h2':
    case 'h3':
    case 'quote':
    case 'bullet':
    case 'numbered':
    case 'todo':
      return true;
    default:
      return false;
  }
}

bool _folioPdfHasDelta(FolioBlock b) =>
    b.richTextDeltaJson != null && b.richTextDeltaJson!.trim().isNotEmpty;

String _folioPdfMdToPlain(String mdChunk) {
  final html = md.markdownToHtml(mdChunk, extensionSet: md.ExtensionSet.gitHubFlavored);
  return html
      .replaceAll(RegExp(r'<[^>]+>'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

/// Syncfusion puede devolver ancho ~0 al medir solo `' '` en fuentes estándar PDF,
/// lo que en Windows dejaba todas las palabras pegadas en el fallback sin HTML.
double _folioPdfInterWordSpace(PdfFont font) {
  final measured = font.measureString(' ').width;
  final minByEm = font.size * 0.22;
  return math.max(measured, minByEm);
}

double _folioLineWidth(List<FolioPdfWord> line) {
  if (line.isEmpty) return 0;
  var w = 0.0;
  for (var i = 0; i < line.length; i++) {
    final piece = line[i];
    if (piece.hardBreak) continue;
    if (i > 0 && !line[i - 1].hardBreak) {
      w += _folioPdfInterWordSpace(line[i - 1].font);
    }
    w += piece.font.measureString(piece.text).width;
  }
  return w;
}

double _folioPdfDrawWords(
  _FolioPdfCtx ctx,
  List<FolioPdfWord> words,
  double x0,
  double maxW,
) {
  var line = <FolioPdfWord>[];

  void flushLine() {
    if (line.isEmpty) return;
    var lineH = 0.0;
    for (final w in line) {
      if (w.hardBreak) continue;
      lineH = math.max(lineH, w.font.height);
    }
    if (lineH <= 0) lineH = 12;
    ctx.ensureSpace(lineH + 6);
    var cx = x0;
    for (var i = 0; i < line.length; i++) {
      final w = line[i];
      if (w.hardBreak) continue;
      if (i > 0 && !line[i - 1].hardBreak) {
        cx += _folioPdfInterWordSpace(line[i - 1].font);
      }
      final sz = w.font.measureString(w.text);
      if (w.back != null) {
        ctx.graphics.drawRectangle(
          brush: PdfSolidBrush(w.back!),
          bounds: Rect.fromLTWH(cx, ctx.y - 1, sz.width, lineH + 2),
        );
      }
      ctx.graphics.drawString(
        w.text,
        w.font,
        brush: w.brush,
        bounds: Rect.fromLTWH(cx, ctx.y, sz.width, lineH + 2),
      );
      cx += sz.width;
    }
    ctx.y += lineH * 1.18;
    line = [];
  }

  for (final w in words) {
    if (w.hardBreak) {
      flushLine();
      ctx.y += 2;
      continue;
    }
    final trial = [...line, w];
    if (_folioLineWidth(trial) > maxW && line.isNotEmpty) {
      flushLine();
      line = [w];
    } else {
      line = trial;
    }
  }
  flushLine();
  return ctx.y;
}

List<FolioPdfWord> _folioPdfWordsForBlock(
  FolioBlock block,
  String mdChunk,
  double fontSize,
  PdfColor defaultColor, {
  PdfFont? forceFont,
  PdfBrush? forceBrush,
}) {
  List<FolioPdfWord> words;
  if (_folioPdfBlockAllowsRich(block) && _folioPdfHasDelta(block)) {
    final fonts = FolioPdfFontCache(fontSize);
    words = folioQuillDeltaJsonToPdfWords(
      block.richTextDeltaJson,
      fontSize: fontSize,
      defaultColor: defaultColor,
      fonts: fonts,
    );
    if (words.isEmpty) {
      words = folioPlainMarkdownToPdfWords(block.text, fontSize, defaultColor);
    }
  } else {
    words = folioPlainMarkdownToPdfWords(
      _folioPdfMdToPlain(mdChunk),
      fontSize,
      defaultColor,
    );
  }

  if (forceFont != null) {
    final b = forceBrush ?? PdfSolidBrush(defaultColor);
    return words
        .map(
          (w) => FolioPdfWord(
            text: w.text,
            font: forceFont,
            brush: b,
            back: w.back,
            hardBreak: w.hardBreak,
          ),
        )
        .toList();
  }
  return words;
}

void _folioPdfDrawPlainTitle(_FolioPdfCtx ctx, String text, PdfFont font, PdfBrush brush) {
  final words = text
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .map((w) => FolioPdfWord(text: w, font: font, brush: brush))
      .toList();
  _folioPdfDrawWords(ctx, words, _FolioPdfCtx.margin, ctx.contentWidth());
}

List<int> _folioPdfExportSyncfusion(FolioPage page, String pagePublishedSubtitle) {
  final doc = PdfDocument();
  final ctx = _FolioPdfCtx(doc);

  final title = page.title.trim().isEmpty ? 'Folio' : page.title.trim();
  final titleFont = PdfStandardFont(PdfFontFamily.helvetica, 22, style: PdfFontStyle.bold);
  final subFont = PdfStandardFont(PdfFontFamily.helvetica, 11);
  final bodyColor = PdfColor(15, 23, 42);
  final muted = PdfColor(71, 85, 105);
  final brushBody = PdfSolidBrush(bodyColor);
  final brushMuted = PdfSolidBrush(muted);

  _folioPdfDrawPlainTitle(ctx, title, titleFont, brushBody);
  ctx.y += 4;
  _folioPdfDrawPlainTitle(ctx, pagePublishedSubtitle, subFont, brushMuted);
  ctx.y += 16;

  final counters = <int, int>{};
  final contentW = ctx.contentWidth();

  for (final block in page.blocks) {
    final mdChunk = FolioMarkdownCodec.exportBlockMarkdown(block, page, counters);
    if (mdChunk == null || mdChunk.trim().isEmpty) continue;

    if (block.type == 'toggle' && mdChunk.trim().startsWith('<details')) {
      ctx.ensureSpace(24);
      _folioPdfDrawPlainTitle(
        ctx,
        _folioPdfMdToPlain(block.text).isEmpty ? '[toggle]' : _folioPdfMdToPlain(block.text),
        PdfStandardFont(PdfFontFamily.helvetica, 11),
        brushMuted,
      );
      ctx.y += 8;
      continue;
    }

    switch (block.type) {
      case 'divider':
        ctx.ensureSpace(14);
        ctx.graphics.drawLine(
          PdfPen(PdfColor(200, 200, 200), width: 0.8),
          Offset(_FolioPdfCtx.margin, ctx.y),
          Offset(_FolioPdfCtx.margin + contentW, ctx.y),
        );
        ctx.y += 16;
        break;
      case 'code':
      case 'mermaid':
      case 'equation':
        ctx.ensureSpace(28);
        final codeFont = PdfStandardFont(PdfFontFamily.courier, 9);
        final plain = block.text.trimRight();
        ctx.graphics.drawRectangle(
          brush: PdfSolidBrush(PdfColor(246, 247, 251)),
          bounds: Rect.fromLTWH(_FolioPdfCtx.margin, ctx.y, contentW, 0),
        );
        ctx.y += 6;
        final cw = codeFont.measureString(plain).width > contentW - 16
            ? contentW - 16
            : contentW - 16;
        final codeWords = folioPlainMarkdownToPdfWords(plain, 9, PdfColor(30, 41, 59));
        _folioPdfDrawWords(ctx, codeWords, _FolioPdfCtx.margin + 8, cw);
        ctx.y += 6;
        break;
      case 'h1':
        final words = _folioPdfWordsForBlock(
          block,
          mdChunk,
          20,
          bodyColor,
          forceFont: PdfStandardFont(PdfFontFamily.helvetica, 20, style: PdfFontStyle.bold),
          forceBrush: brushBody,
        );
        _folioPdfDrawWords(ctx, words, _FolioPdfCtx.margin, contentW);
        ctx.y += 8;
        break;
      case 'h2':
        final words = _folioPdfWordsForBlock(
          block,
          mdChunk,
          17,
          bodyColor,
          forceFont: PdfStandardFont(PdfFontFamily.helvetica, 17, style: PdfFontStyle.bold),
          forceBrush: brushBody,
        );
        _folioPdfDrawWords(ctx, words, _FolioPdfCtx.margin, contentW);
        ctx.y += 8;
        break;
      case 'h3':
        final words = _folioPdfWordsForBlock(
          block,
          mdChunk,
          14,
          bodyColor,
          forceFont: PdfStandardFont(PdfFontFamily.helvetica, 14, style: PdfFontStyle.bold),
          forceBrush: brushBody,
        );
        _folioPdfDrawWords(ctx, words, _FolioPdfCtx.margin, contentW);
        ctx.y += 8;
        break;
      case 'quote':
        final qFont = PdfStandardFont(PdfFontFamily.helvetica, 11, style: PdfFontStyle.italic);
        final words = _folioPdfWordsForBlock(
          block,
          mdChunk,
          11,
          muted,
          forceFont: qFont,
          forceBrush: brushMuted,
        );
        _folioPdfDrawWords(ctx, words, _FolioPdfCtx.margin + 12, contentW - 12);
        ctx.y += 8;
        break;
      case 'bullet':
      case 'todo':
      case 'numbered':
        ctx.ensureSpace(18);
        final mark = block.type == 'numbered'
            ? '• '
            : block.type == 'todo'
                ? (block.checked == true ? '☑ ' : '☐ ')
                : '• ';
        ctx.graphics.drawString(
          mark,
          PdfStandardFont(PdfFontFamily.helvetica, 12),
          brush: brushBody,
          bounds: Rect.fromLTWH(_FolioPdfCtx.margin, ctx.y, 28, 18),
        );
        final words = _folioPdfWordsForBlock(block, mdChunk, 12, bodyColor);
        _folioPdfDrawWords(ctx, words, _FolioPdfCtx.margin + 22, contentW - 22);
        ctx.y += 4;
        break;
      default:
        final words = _folioPdfWordsForBlock(block, mdChunk, 12, bodyColor);
        _folioPdfDrawWords(ctx, words, _FolioPdfCtx.margin, contentW);
        ctx.y += 6;
        break;
    }
  }

  final bytes = doc.saveSync();
  doc.dispose();
  return bytes;
}
