import 'dart:typed_data';

/// Solo web. En otras plataformas no debe llamarse.
void folioTriggerBrowserDownload(String filename, Uint8List bytes) {
  throw UnsupportedError('folioTriggerBrowserDownload is web-only');
}
