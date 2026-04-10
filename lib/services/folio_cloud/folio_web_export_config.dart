/// URLs públicas de descarga o landing para el HTML publicado en la web.
///
/// El botón principal usa [folioWebExportPrimaryUrl] si no está vacío; si no,
/// la primera tienda con URL definida (Play → App Store → Microsoft Store).
const String folioWebExportPrimaryUrl = '';

const String folioWebExportPlayUrl = '';
const String folioWebExportAppStoreUrl = '';
const String folioWebExportMicrosoftStoreUrl = '';

String _trimUrl(String s) => s.trim();

/// Href del CTA principal, o null si no hay ninguna URL configurada.
String? folioWebExportResolvedDownloadHref() {
  if (_trimUrl(folioWebExportPrimaryUrl).isNotEmpty) {
    return _trimUrl(folioWebExportPrimaryUrl);
  }
  if (_trimUrl(folioWebExportPlayUrl).isNotEmpty) {
    return _trimUrl(folioWebExportPlayUrl);
  }
  if (_trimUrl(folioWebExportAppStoreUrl).isNotEmpty) {
    return _trimUrl(folioWebExportAppStoreUrl);
  }
  if (_trimUrl(folioWebExportMicrosoftStoreUrl).isNotEmpty) {
    return _trimUrl(folioWebExportMicrosoftStoreUrl);
  }
  return null;
}
