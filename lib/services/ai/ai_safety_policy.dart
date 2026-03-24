import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

import '../../app/app_settings.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class AiSafetyPolicy {
  const AiSafetyPolicy();

  static String detectMimeType(String filePath) {
    final lower = filePath.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.bmp')) return 'image/bmp';
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.md') || lower.endsWith('.markdown'))
      return 'text/markdown';
    if (lower.endsWith('.json')) return 'application/json';
    if (lower.endsWith('.csv')) return 'text/csv';
    if (lower.endsWith('.txt')) return 'text/plain';
    return 'application/octet-stream';
  }

  static bool isImageMimeType(String mimeType) => mimeType.startsWith('image/');

  static Future<String?> readImageAsBase64(File file) async {
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) return null;
    return base64Encode(bytes);
  }

  static bool isLocalhostHost(String host) {
    final h = host.trim().toLowerCase();
    return h == 'localhost' || h == '127.0.0.1' || h == '::1';
  }

  static Uri? parseAndNormalizeUrl(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return null;
    final parsed = Uri.tryParse(value);
    if (parsed == null) return null;
    if (!parsed.hasScheme ||
        !(parsed.scheme == 'http' || parsed.scheme == 'https')) {
      return null;
    }
    if (parsed.host.trim().isEmpty) return null;
    return parsed;
  }

  static bool isEndpointAllowed({
    required Uri uri,
    required AiEndpointMode mode,
    required bool remoteConfirmed,
  }) {
    if (mode == AiEndpointMode.allowRemote) {
      return isLocalhostHost(uri.host) || remoteConfirmed;
    }
    return isLocalhostHost(uri.host);
  }

  static String? validateEndpoint({
    required String rawUrl,
    required AiEndpointMode mode,
    required bool remoteConfirmed,
  }) {
    final uri = parseAndNormalizeUrl(rawUrl);
    if (uri == null) {
      return 'URL inválida. Usa http://host:puerto.';
    }
    if (!isEndpointAllowed(
      uri: uri,
      mode: mode,
      remoteConfirmed: remoteConfirmed,
    )) {
      return 'Endpoint remoto no permitido sin confirmación.';
    }
    return null;
  }

  static Future<String?> readAttachmentAsContext(File file) async {
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) return null;
    final fileName = file.uri.pathSegments.isEmpty
        ? file.path
        : file.uri.pathSegments.last;
    final ext = file.path.toLowerCase();
    if (ext.endsWith('.pdf')) {
      final extracted = _extractPdfText(bytes);
      if (extracted != null && extracted.trim().isNotEmpty) {
        const maxChars = 20000;
        final safe = extracted.length > maxChars
            ? '${extracted.substring(0, maxChars)}\n...[pdf truncado]'
            : extracted;
        return safe;
      }
    }
    final isTexty =
        ext.endsWith('.txt') ||
        ext.endsWith('.md') ||
        ext.endsWith('.markdown') ||
        ext.endsWith('.json') ||
        ext.endsWith('.yaml') ||
        ext.endsWith('.yml') ||
        ext.endsWith('.csv') ||
        ext.endsWith('.xml') ||
        ext.endsWith('.html') ||
        ext.endsWith('.htm') ||
        ext.endsWith('.dart') ||
        ext.endsWith('.js') ||
        ext.endsWith('.ts') ||
        ext.endsWith('.tsx') ||
        ext.endsWith('.jsx') ||
        ext.endsWith('.py') ||
        ext.endsWith('.java') ||
        ext.endsWith('.go') ||
        ext.endsWith('.rs') ||
        ext.endsWith('.c') ||
        ext.endsWith('.cpp') ||
        ext.endsWith('.h');
    const maxChars = 12000;
    if (isTexty) {
      var text = utf8.decode(bytes, allowMalformed: true);
      if (text.length > maxChars) {
        text = '${text.substring(0, maxChars)}\n...[truncado]';
      }
      return text;
    }

    // Para binarios (pdf, docx, imágenes, etc.) mandamos metadatos + muestra
    // para que la IA al menos reciba contexto del adjunto en vez de ignorarlo.
    final sampleLen = bytes.length < 1200 ? bytes.length : 1200;
    final sample = base64Encode(bytes.sublist(0, sampleLen));
    return 'Adjunto binario no textual.\n'
        'Nombre: $fileName\n'
        'Extensión: $ext\n'
        'Tamaño(bytes): ${bytes.length}\n'
        'Muestra(base64, inicio):\n$sample\n'
        '...[muestra truncada]';
  }

  static String? _extractPdfText(Uint8List bytes) {
    try {
      final doc = PdfDocument(inputBytes: bytes);
      final extractor = PdfTextExtractor(doc);
      final text = extractor.extractText();
      doc.dispose();
      return text;
    } catch (_) {
      return null;
    }
  }
}
