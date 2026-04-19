import 'dart:html' as html;
import 'dart:typed_data';

/// Dispara la descarga de [bytes] como [filename] en el navegador.
void folioTriggerBrowserDownload(String filename, Uint8List bytes) {
  final blob = html.Blob([bytes]);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..download = filename
    ..style.display = 'none';
  html.document.body!.append(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
}
