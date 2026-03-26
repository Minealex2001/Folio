import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../app/app_settings.dart';

class CustomIconImportException implements Exception {
  const CustomIconImportException(this.message);

  final String message;

  @override
  String toString() => message;
}

class CustomIconImportService {
  static const int maxBytes = 512 * 1024;
  static const _uuid = Uuid();
  static const Set<String> _supportedMimeTypes = <String>{
    'image/png',
    'image/svg+xml',
    'image/gif',
    'image/webp',
  };

  Future<CustomIconEntry> importFromSource({
    required String source,
    String? label,
  }) async {
    final raw = source.trim();
    if (raw.isEmpty) {
      throw const CustomIconImportException('La fuente del icono está vacía.');
    }
    if (raw.startsWith('data:image/')) {
      return _importFromDataUri(raw, label: label);
    }
    final uri = Uri.tryParse(raw);
    if (uri == null || !uri.hasScheme) {
      throw const CustomIconImportException('La URL del icono no es válida.');
    }
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      throw const CustomIconImportException(
        'Solo se admiten URLs http o https.',
      );
    }
    return _importFromRemoteUri(uri, label: label);
  }

  Future<CustomIconEntry> _importFromDataUri(
    String source, {
    String? label,
  }) async {
    final uriData = UriData.parse(source);
    final mimeType = uriData.mimeType.toLowerCase();
    final id = _uuid.v4();
    if (!_supportedMimeTypes.contains(mimeType)) {
      throw const CustomIconImportException(
        'Solo se admiten data:image/svg+xml, data:image/gif, data:image/webp o data:image/png.',
      );
    }
    final extension = _extensionForMimeType(mimeType);
    if (extension == null) {
      throw const CustomIconImportException(
        'Formato no compatible. Usa SVG, PNG, GIF o WebP.',
      );
    }
    final file = await _createTargetFile(id, extension);
    if (mimeType == 'image/svg+xml') {
      final svg = uriData.contentAsString(encoding: utf8).trim();
      if (!svg.contains('<svg')) {
        throw const CustomIconImportException('El SVG copiado no es válido.');
      }
      final bytes = utf8.encode(svg);
      if (bytes.length > maxBytes) {
        throw const CustomIconImportException(
          'El SVG es demasiado grande para importarlo.',
        );
      }
      await file.writeAsString(svg, flush: true);
    } else {
      final bytes = uriData.contentAsBytes();
      if (bytes.length > maxBytes) {
        throw const CustomIconImportException(
          'La imagen embebida es demasiado grande para importarla.',
        );
      }
      await file.writeAsBytes(bytes, flush: true);
    }
    return CustomIconEntry(
      id: id,
      label: _sanitizeLabel(label, fallback: 'Custom icon'),
      source: source,
      filePath: file.path,
      mimeType: mimeType,
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<CustomIconEntry> _importFromRemoteUri(Uri uri, {String? label}) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 12);
    try {
      final request = await client.getUrl(uri);
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw CustomIconImportException(
          'No se pudo descargar el icono (${response.statusCode}).',
        );
      }
      final contentType = response.headers.contentType;
      final mimeType =
          '${contentType?.primaryType ?? ''}/${contentType?.subType ?? ''}'
              .toLowerCase()
              .trim();
      final bytes = <int>[];
      await for (final chunk in response) {
        bytes.addAll(chunk);
        if (bytes.length > maxBytes) {
          throw const CustomIconImportException(
            'El icono remoto es demasiado grande.',
          );
        }
      }
      final resolvedMimeType = _resolveMimeType(uri, mimeType, bytes);
      final extension = _extensionForMimeType(resolvedMimeType);
      if (extension == null) {
        throw const CustomIconImportException(
          'Formato no compatible. Usa SVG, PNG, GIF o WebP.',
        );
      }
      final id = _uuid.v4();
      final file = await _createTargetFile(id, extension);
      await file.writeAsBytes(bytes, flush: true);
      return CustomIconEntry(
        id: id,
        label: _sanitizeLabel(label, fallback: _fallbackLabelFromUri(uri)),
        source: uri.toString(),
        filePath: file.path,
        mimeType: resolvedMimeType,
        createdAtMs: DateTime.now().millisecondsSinceEpoch,
      );
    } on CustomIconImportException {
      rethrow;
    } on SocketException {
      throw const CustomIconImportException(
        'No se pudo conectar para descargar el icono.',
      );
    } on HandshakeException {
      throw const CustomIconImportException(
        'Fallo de certificado al descargar el icono.',
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<File> _createTargetFile(String id, String extension) async {
    final root = await getApplicationSupportDirectory();
    final dir = Directory(p.join(root.path, 'custom_icons'));
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    return File(p.join(dir.path, '$id$extension'));
  }

  String _sanitizeLabel(String? label, {required String fallback}) {
    final trimmed = label?.trim() ?? '';
    if (trimmed.isNotEmpty) return trimmed;
    return fallback;
  }

  String _fallbackLabelFromUri(Uri uri) {
    final name = uri.pathSegments.isEmpty ? '' : uri.pathSegments.last.trim();
    if (name.isEmpty) return 'Imported icon';
    final withoutExt = name.replaceAll(RegExp(r'\.[A-Za-z0-9]+$'), '');
    return withoutExt.isEmpty ? 'Imported icon' : withoutExt;
  }

  String _resolveMimeType(Uri uri, String mimeType, List<int> bytes) {
    if (_supportedMimeTypes.contains(mimeType)) {
      return mimeType;
    }
    final path = uri.path.toLowerCase();
    if (path.endsWith('.png')) return 'image/png';
    if (path.endsWith('.svg')) return 'image/svg+xml';
    if (path.endsWith('.gif')) return 'image/gif';
    if (path.endsWith('.webp')) return 'image/webp';
    if (_looksLikePng(bytes)) return 'image/png';
    if (_looksLikeSvg(bytes)) return 'image/svg+xml';
    if (_looksLikeGif(bytes)) return 'image/gif';
    if (_looksLikeWebp(bytes)) return 'image/webp';
    return mimeType;
  }

  String? _extensionForMimeType(String mimeType) {
    switch (mimeType) {
      case 'image/png':
        return '.png';
      case 'image/svg+xml':
        return '.svg';
      case 'image/gif':
        return '.gif';
      case 'image/webp':
        return '.webp';
      default:
        return null;
    }
  }

  bool _looksLikePng(List<int> bytes) {
    if (bytes.length < 8) return false;
    const signature = <int>[137, 80, 78, 71, 13, 10, 26, 10];
    for (var i = 0; i < signature.length; i++) {
      if (bytes[i] != signature[i]) return false;
    }
    return true;
  }

  bool _looksLikeSvg(List<int> bytes) {
    final text = utf8.decode(bytes, allowMalformed: true).trimLeft();
    return text.startsWith('<svg') || text.startsWith('<?xml');
  }

  bool _looksLikeGif(List<int> bytes) {
    if (bytes.length < 6) return false;
    return bytes[0] == 0x47 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x38 &&
        (bytes[4] == 0x37 || bytes[4] == 0x39) &&
        bytes[5] == 0x61;
  }

  bool _looksLikeWebp(List<int> bytes) {
    if (bytes.length < 12) return false;
    return bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50;
  }
}
