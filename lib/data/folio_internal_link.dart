/// Enlaces internos entre páginas: `folio://open/<pageId>` (id codificado en el path).
String folioPageLinkUri(String pageId) {
  final enc = Uri.encodeComponent(pageId);
  return 'folio://open/$enc';
}

/// Devuelve el id de página si [href] es un enlace [folioPageLinkUri], si no `null`.
String? folioPageIdFromFolioUri(String? href) {
  if (href == null) return null;
  final u = Uri.tryParse(href.trim());
  if (u == null || u.scheme != 'folio') return null;
  if (u.host != 'open') return null;
  if (u.pathSegments.length != 1) return null;
  return Uri.decodeComponent(u.pathSegments.first);
}
