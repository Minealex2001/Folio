import 'package:markdown/markdown.dart' as md;

import '../../models/folio_page.dart';
import '../integrations/integrations_markdown_codec.dart';
import 'folio_web_export_config.dart';

String _folioEscapeHtml(String s) {
  return s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
}

String _folioSlugifyCalloutKind(String raw) {
  final k = raw.trim().toLowerCase();
  switch (k) {
    case 'tip':
      return 'tip';
    case 'important':
      return 'important';
    case 'warning':
      return 'warning';
    case 'caution':
      return 'caution';
    case 'note':
    default:
      return 'note';
  }
}

String _folioTransformCalloutBlockquotes(String html) {
  // markdownToHtml convierte `> [!WARNING]` en un <blockquote> cuyo primer <p>
  // suele ser "[!WARNING]" (a veces con saltos/espacios). Transformamos esos
  // blockquotes a un <aside> con clases para poder estilarlos como Folio.
  final blockquoteRe = RegExp(r'<blockquote>([\s\S]*?)</blockquote>');
  return html.replaceAllMapped(blockquoteRe, (m) {
    final inner = m.group(1) ?? '';
    final firstP = RegExp(
      r'^\s*<p>\s*\[!\s*(NOTE|TIP|IMPORTANT|WARNING|CAUTION)\s*\]\s*</p>',
      caseSensitive: false,
    ).firstMatch(inner);
    if (firstP == null) return m.group(0) ?? '';

    final kindRaw = firstP.group(1) ?? 'NOTE';
    final kind = _folioSlugifyCalloutKind(kindRaw);
    final body = inner.substring(firstP.end).trim();
    final bodyHtml = body.isEmpty
        ? '<p></p>'
        : '<div class="folio-callout__body">$body</div>';
    return '<aside class="folio-callout folio-callout--$kind" role="note">'
        '<div class="folio-callout__bar" aria-hidden="true"></div>'
        '<div class="folio-callout__content">'
        '<div class="folio-callout__title">${kindRaw.toUpperCase()}</div>'
        '$bodyHtml'
        '</div>'
        '</aside>';
  });
}

/// SVG mínimo cuando no hay icono embebido (data URI).
const String _folioPromoSvgFallback =
    '<svg xmlns="http://www.w3.org/2000/svg" width="40" height="40" viewBox="0 0 40 40" aria-hidden="true" class="folio-promo__icon folio-promo__icon-svg">'
    '<rect width="40" height="40" rx="10" fill="currentColor" opacity="0.18"/>'
    '<text x="20" y="27" text-anchor="middle" fill="currentColor" font-family="ui-sans-serif,system-ui,sans-serif" font-size="18" font-weight="700">F</text>'
    '</svg>';

String _folioPromoBarHtml(String? appIconDataUri) {
  final esc = _folioEscapeHtml;
  final href = folioWebExportResolvedDownloadHref();
  final logo = appIconDataUri != null && appIconDataUri.trim().isNotEmpty
      ? '<img class="folio-promo__icon" src="${esc(appIconDataUri.trim())}" width="40" height="40" alt="" decoding="async">'
      : _folioPromoSvgFallback;

  final cta = href != null
      ? '<a class="folio-promo__cta" href="${esc(href)}" rel="noopener noreferrer" target="_blank" aria-label="Descargar la aplicación Folio">Descargar Folio</a>'
      : '<span class="folio-promo__cta folio-promo__cta--static" aria-disabled="true">Descargar Folio</span>';

  final storeLinks = <String>[];
  void addStore(String label, String url) {
    final u = url.trim();
    if (u.isEmpty) return;
    storeLinks.add(
      '<a class="folio-promo__store" href="${esc(u)}" rel="noopener noreferrer" target="_blank">$label</a>',
    );
  }

  addStore('Android', folioWebExportPlayUrl);
  addStore('iOS', folioWebExportAppStoreUrl);
  addStore('Windows', folioWebExportMicrosoftStoreUrl);

  final storesHtml = storeLinks.isEmpty
      ? ''
      : '<div class="folio-promo__stores" role="navigation" aria-label="Enlaces a tiendas">${storeLinks.join('<span class="folio-promo__sep" aria-hidden="true">·</span>')}</div>';

  return '<aside class="folio-promo" role="complementary">\n'
      '<div class="folio-promo__inner">\n'
      '<div class="folio-promo__brand">\n'
      '$logo\n'
      '<div class="folio-promo__text">\n'
      '<span class="folio-promo__name">Folio</span>\n'
      '<span class="folio-promo__tagline">Vista web · Para editar y sincronizar, usa Folio en tu dispositivo.</span>\n'
      '</div>\n'
      '</div>\n'
      '<div class="folio-promo__actions">\n'
      '$cta\n'
      '$storesHtml\n'
      '</div>\n'
      '</div>\n'
      '</aside>\n';
}

String _folioFooterHtml() {
  final esc = _folioEscapeHtml;
  final href = folioWebExportResolvedDownloadHref();
  final cta = href != null
      ? '<div><a class="folio-footer__cta" href="${esc(href)}" rel="noopener noreferrer" target="_blank">Descargar Folio</a></div>\n'
      : '';
  return '<footer class="folio-footer">\n'
      '<div>Folio · Publicación web</div>\n'
      '$cta'
      '</footer>\n';
}

/// Documento HTML completo para una página publicada (export real o demo en ajustes).
///
/// [documentTitle] y [pageHeading] se escapan para `<title>` y `<h1>`.
/// [pageSubtitle] se escapa para el subtítulo bajo el título.
/// [bodyHtml] debe ser HTML ya generado (p. ej. Markdown → HTML).
String folioWebExportShellHtml({
  required String documentTitle,
  required String pageHeading,
  required String pageSubtitle,
  required String bodyHtml,
  String? appIconDataUri,
}) {
  final dt = _folioEscapeHtml(documentTitle);
  final ph = _folioEscapeHtml(pageHeading);
  final ps = _folioEscapeHtml(pageSubtitle);
  final promo = _folioPromoBarHtml(appIconDataUri);
  final footer = _folioFooterHtml();
  final favicon = appIconDataUri != null && appIconDataUri.trim().isNotEmpty
      ? '<link rel="icon" href="${_folioEscapeHtml(appIconDataUri.trim())}">\n'
      : '';

  return '<!DOCTYPE html>\n'
      '<html lang="es">\n'
      '<head>\n'
      '<meta charset="utf-8">\n'
      '<meta name="viewport" content="width=device-width, initial-scale=1">\n'
      '<meta name="color-scheme" content="light dark">\n'
      '$favicon'
      '<title>$dt</title>\n'
      '<style>\n'
      ':root{--bg:#0b0c0f;--panel:#11131a;--text:#e9eaf0;--muted:#a7adbb;'
      '--border:rgba(255,255,255,.12);--link:#7cb7ff;--linkHover:#a6d2ff;'
      '--codeBg:rgba(255,255,255,.06);--codeBorder:rgba(255,255,255,.10);'
      '--shadow:0 12px 30px rgba(0,0,0,.35);--radius:14px;--radiusSm:10px;'
      '--max:860px;--pad:20px;--mono:ui-monospace,SFMono-Regular,Menlo,Monaco,Consolas,"Liberation Mono","Courier New",monospace;'
      '--sans:ui-sans-serif,system-ui,-apple-system,Segoe UI,Roboto,Helvetica,Arial,"Apple Color Emoji","Segoe UI Emoji";'
      '--calloutNote:#66a3ff;--calloutTip:#6ee7b7;--calloutImportant:#fbbf24;--calloutWarning:#fb7185;--calloutCaution:#f97316;}\n'
      '@media (prefers-color-scheme: light){:root{--bg:#f6f7fb;--panel:#ffffff;--text:#0f172a;--muted:#475569;'
      '--border:rgba(15,23,42,.12);--link:#0b63f6;--linkHover:#084fc5;--codeBg:rgba(15,23,42,.05);--codeBorder:rgba(15,23,42,.10);'
      '--shadow:0 12px 30px rgba(2,6,23,.12);}}\n'
      'html,body{height:100%;}\n'
      'body{margin:0;background:var(--bg);color:var(--text);font-family:var(--sans);line-height:1.6;}\n'
      '.folio-shell{min-height:100%;padding:32px 16px 48px;}\n'
      '.folio-promo{position:sticky;top:0;z-index:10;max-width:var(--max);margin:0 auto 16px;padding:14px 16px;background:var(--panel);border:1px solid var(--border);border-radius:var(--radius);box-shadow:var(--shadow);}\n'
      '.folio-promo__inner{display:flex;flex-wrap:wrap;align-items:center;justify-content:space-between;gap:14px;}\n'
      '.folio-promo__brand{display:flex;align-items:center;gap:12px;min-width:0;flex:1 1 220px;}\n'
      '.folio-promo__icon{flex-shrink:0;width:40px;height:40px;border-radius:10px;display:block;}\n'
      '.folio-promo__icon-svg{color:var(--link);}\n'
      '.folio-promo__text{display:flex;flex-direction:column;gap:2px;min-width:0;}\n'
      '.folio-promo__name{font-weight:700;font-size:15px;letter-spacing:-.02em;line-height:1.2;color:var(--text);}\n'
      '.folio-promo__tagline{font-size:12px;line-height:1.35;color:var(--muted);}\n'
      '.folio-promo__actions{display:flex;flex-wrap:wrap;align-items:center;gap:10px 14px;justify-content:flex-end;}\n'
      '.folio-promo__cta{display:inline-flex;align-items:center;justify-content:center;padding:10px 18px;font-size:14px;font-weight:600;border-radius:999px;background:var(--link);color:#fff;text-decoration:none;line-height:1.2;border:none;cursor:pointer;}\n'
      '.folio-promo__cta:hover{background:var(--linkHover);color:#fff;text-decoration:none;}\n'
      '.folio-promo__cta:focus-visible{outline:2px solid var(--linkHover);outline-offset:2px;}\n'
      '.folio-promo__cta--static{background:rgba(255,255,255,.12);color:var(--muted);cursor:default;}\n'
      '@media (prefers-color-scheme: light){.folio-promo__cta--static{background:rgba(15,23,42,.08);color:var(--muted);}}\n'
      '.folio-promo__stores{display:flex;flex-wrap:wrap;align-items:center;gap:6px;font-size:12px;color:var(--muted);}\n'
      '.folio-promo__store{color:var(--link);text-decoration:none;}\n'
      '.folio-promo__store:hover{text-decoration:underline;color:var(--linkHover);}\n'
      '.folio-promo__store:focus-visible{outline:2px solid var(--link);outline-offset:2px;border-radius:4px;}\n'
      '.folio-promo__sep{opacity:.5;user-select:none;}\n'
      '.folio-card{max-width:var(--max);margin:0 auto;background:var(--panel);border:1px solid var(--border);border-radius:var(--radius);box-shadow:var(--shadow);}\n'
      '.folio-header{padding:28px clamp(18px,3vw,var(--pad)) 8px;}\n'
      '.folio-title{margin:0;font-size:clamp(26px,3.6vw,40px);letter-spacing:-.02em;line-height:1.15;}\n'
      '.folio-subtitle{margin:10px 0 0;color:var(--muted);font-size:14px;}\n'
      '.folio-content{padding:12px clamp(18px,3vw,var(--pad)) 28px;}\n'
      '.folio-content > :first-child{margin-top:0;}\n'
      '.folio-content p{margin:14px 0;}\n'
      '.folio-content h1,.folio-content h2,.folio-content h3{margin:24px 0 10px;line-height:1.2;letter-spacing:-.015em;}\n'
      '.folio-content h1{font-size:1.65rem;}\n'
      '.folio-content h2{font-size:1.35rem;}\n'
      '.folio-content h3{font-size:1.1rem;}\n'
      '.folio-content a{color:var(--link);text-decoration:none;text-underline-offset:3px;}\n'
      '.folio-content a:hover{color:var(--linkHover);text-decoration:underline;}\n'
      '.folio-content a:focus-visible{outline:2px solid var(--link);outline-offset:2px;border-radius:8px;}\n'
      '.folio-content hr{border:none;border-top:1px solid var(--border);margin:24px 0;}\n'
      '.folio-content ul,.folio-content ol{padding-left:1.4rem;margin:14px 0;}\n'
      '.folio-content li{margin:6px 0;}\n'
      '.folio-content blockquote{margin:16px 0;padding:12px 14px;border-left:3px solid var(--border);color:var(--muted);background:rgba(255,255,255,.03);border-radius:12px;}\n'
      '.folio-content img{max-width:100%;height:auto;border-radius:12px;border:1px solid var(--border);}\n'
      '.folio-content code{font-family:var(--mono);font-size:.92em;background:var(--codeBg);border:1px solid var(--codeBorder);padding:.18em .38em;border-radius:8px;}\n'
      '.folio-content pre{margin:16px 0;padding:14px 14px;overflow:auto;background:var(--codeBg);border:1px solid var(--codeBorder);border-radius:12px;}\n'
      '.folio-content pre code{background:transparent;border:none;padding:0;font-size:.92em;}\n'
      '.folio-content table{border-collapse:separate;border-spacing:0;width:100%;margin:16px 0;border:1px solid var(--border);border-radius:12px;overflow:hidden;}\n'
      '.folio-content thead th{font-weight:650;color:var(--text);background:rgba(255,255,255,.04);}\n'
      '.folio-content th,.folio-content td{padding:10px 12px;border-bottom:1px solid var(--border);}\n'
      '.folio-content tr:last-child td{border-bottom:none;}\n'
      '.folio-content tbody tr:nth-child(2n){background:rgba(255,255,255,.02);}\n'
      '.folio-content details{margin:14px 0;border:1px solid var(--border);border-radius:12px;background:rgba(255,255,255,.02);}\n'
      '.folio-content summary{cursor:pointer;list-style:none;padding:10px 12px;font-weight:600;}\n'
      '.folio-content summary::-webkit-details-marker{display:none;}\n'
      '.folio-content details[open] summary{border-bottom:1px solid var(--border);}\n'
      '.folio-content details > *:not(summary){padding:10px 12px;}\n'
      '.folio-callout{display:flex;gap:12px;margin:16px 0;border:1px solid var(--border);border-radius:14px;background:rgba(255,255,255,.02);overflow:hidden;}\n'
      '.folio-callout__bar{width:6px;background:var(--calloutNote);}\n'
      '.folio-callout--tip .folio-callout__bar{background:var(--calloutTip);}\n'
      '.folio-callout--important .folio-callout__bar{background:var(--calloutImportant);}\n'
      '.folio-callout--warning .folio-callout__bar{background:var(--calloutWarning);}\n'
      '.folio-callout--caution .folio-callout__bar{background:var(--calloutCaution);}\n'
      '.folio-callout__content{padding:12px 14px;min-width:0;}\n'
      '.folio-callout__title{font-size:12px;letter-spacing:.08em;text-transform:uppercase;color:var(--muted);margin:0 0 6px;}\n'
      '.folio-callout__body > :first-child{margin-top:0;}\n'
      '.folio-callout__body > :last-child{margin-bottom:0;}\n'
      '.folio-footer{padding:14px clamp(18px,3vw,var(--pad)) 20px;border-top:1px solid var(--border);color:var(--muted);font-size:12px;}\n'
      '.folio-footer__cta{display:inline-block;margin-top:8px;color:var(--link);text-decoration:none;font-weight:600;font-size:13px;}\n'
      '.folio-footer__cta:hover{text-decoration:underline;color:var(--linkHover);}\n'
      '.folio-footer__cta:focus-visible{outline:2px solid var(--link);outline-offset:2px;border-radius:6px;}\n'
      '</style>\n'
      '</head>\n'
      '<body>\n'
      '<div class="folio-shell">\n'
      '$promo'
      '<article class="folio-card">\n'
      '<header class="folio-header">\n'
      '<h1 class="folio-title">$ph</h1>\n'
      '<div class="folio-subtitle">$ps</div>\n'
      '</header>\n'
      '<main class="folio-content">\n'
      '$bodyHtml\n'
      '</main>\n'
      '$footer'
      '</article>\n'
      '</div>\n'
      '</body>\n'
      '</html>\n';
}

/// HTML para [publishHtmlPage] (contenido vía Markdown de la página).
String folioPageExportHtmlDocument(
  FolioPage page, {
  String? appIconDataUri,
  required String pagePublishedSubtitle,
}) {
  final mdBody = FolioMarkdownCodec.exportPage(page, includeFrontMatter: false);
  var bodyHtml = md.markdownToHtml(
    mdBody,
    extensionSet: md.ExtensionSet.gitHubFlavored,
  );
  bodyHtml = _folioTransformCalloutBlockquotes(bodyHtml);
  final title = page.title.trim().isEmpty ? 'Folio' : page.title.trim();
  return folioWebExportShellHtml(
    documentTitle: title,
    pageHeading: title,
    pageSubtitle: pagePublishedSubtitle,
    bodyHtml: bodyHtml,
    appIconDataUri: appIconDataUri,
  );
}
