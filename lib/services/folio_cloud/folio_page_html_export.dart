import 'package:markdown/markdown.dart' as md;

import '../../models/folio_page.dart';
import '../run2doc/run2doc_markdown_codec.dart';

String _folioEscapeHtml(String s) {
  return s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
}

/// HTML mínimo para [publishHtmlPage] (contenido vía Markdown de la página).
String folioPageExportHtmlDocument(FolioPage page) {
  final mdBody = FolioMarkdownCodec.exportPage(
    page,
    includeFrontMatter: false,
  );
  final bodyHtml = md.markdownToHtml(
    mdBody,
    extensionSet: md.ExtensionSet.gitHubFlavored,
  );
  final title = page.title.trim().isEmpty ? 'Folio' : page.title.trim();
  final t = _folioEscapeHtml(title);
  return '<!DOCTYPE html>\n'
      '<html lang="es">\n'
      '<head>\n'
      '<meta charset="utf-8">\n'
      '<meta name="viewport" content="width=device-width, initial-scale=1">\n'
      '<title>$t</title>\n'
      '<style>\n'
      'body{font-family:system-ui,sans-serif;line-height:1.55;max-width:42rem;'
      'margin:2rem auto;padding:0 1rem;color:#111;}\n'
      'pre,code{background:#f4f4f5;padding:0.15em 0.35em;border-radius:4px;font-size:0.9em;}\n'
      'pre{padding:1rem;overflow:auto}\n'
      'img{max-width:100%;height:auto}\n'
      'table{border-collapse:collapse;width:100%;}\n'
      'th,td{border:1px solid #ddd;padding:0.35rem 0.5rem;}\n'
      '</style>\n'
      '</head>\n'
      '<body>\n'
      '<main class="folio-export">\n'
      '$bodyHtml\n'
      '</main>\n'
      '</body>\n'
      '</html>\n';
}
