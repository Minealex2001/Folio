import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../app/app_settings.dart' show CustomIconEntry;
import '../core/errors/folio_exception.dart';
import '../l10n/generated/app_localizations.dart';
import 'custom_icons/custom_icon_blob_store.dart';

class CustomIconImportException extends FolioException {
  const CustomIconImportException(super.message);
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

  CustomIconBlobStore get _store => CustomIconBlobStore.instance;

  Future<CustomIconEntry> importFromBytes({
    required AppLocalizations l10n,
    required List<int> bytes,
    required String mimeType,
    String? label,
    String? source,
  }) async {
    final normalizedMime = mimeType.toLowerCase().trim();
    if (!_supportedMimeTypes.contains(normalizedMime)) {
      throw CustomIconImportException(l10n.customIconImportUnsupportedFormat);
    }
    if (bytes.isEmpty) {
      throw CustomIconImportException(l10n.customIconImportUnsupportedFormat);
    }
    if (bytes.length > maxBytes) {
      throw CustomIconImportException(
        normalizedMime == 'image/svg+xml'
            ? l10n.customIconImportSvgTooLarge
            : l10n.customIconImportEmbeddedImageTooLarge,
      );
    }
    if (normalizedMime == 'image/svg+xml' && !_looksLikeSvg(bytes)) {
      throw CustomIconImportException(l10n.customIconImportInvalidSvg);
    }
    final extension = _extensionForMimeType(normalizedMime);
    if (extension == null) {
      throw CustomIconImportException(l10n.customIconImportUnsupportedFormat);
    }
    final id = _uuid.v4();
    final payload = normalizedMime == 'image/svg+xml'
        ? utf8.encode(utf8.decode(bytes, allowMalformed: true).trim())
        : bytes;
    final storageKey = await _store.write(
      id: id,
      extension: extension,
      bytes: payload,
    );
    return CustomIconEntry(
      id: id,
      label: _sanitizeLabel(
        label,
        fallback: l10n.customIconLabelImported,
      ),
      source: source?.trim() ?? '',
      filePath: storageKey,
      mimeType: normalizedMime,
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<CustomIconEntry> importFromSource({
    required AppLocalizations l10n,
    required String source,
    String? label,
    Future<({int statusCode, String? contentType, List<int> bytes})> Function(
      Uri uri,
    )?
    fetchRemote,
  }) async {
    final raw = source.trim();
    if (raw.isEmpty) {
      throw CustomIconImportException(l10n.customIconImportEmptySource);
    }
    if (raw.startsWith('data:image/')) {
      return _importFromDataUri(l10n, raw, label: label);
    }
    final uri = Uri.tryParse(raw);
    if (uri == null || !uri.hasScheme) {
      throw CustomIconImportException(l10n.customIconImportInvalidUrl);
    }
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      throw CustomIconImportException(l10n.customIconImportHttpHttpsOnly);
    }
    return _importFromRemoteUri(
      l10n,
      uri,
      label: label,
      fetchRemote: fetchRemote,
    );
  }

  Future<CustomIconEntry> _importFromDataUri(
    AppLocalizations l10n,
    String source, {
    String? label,
  }) async {
    final uriData = UriData.parse(source);
    final mimeType = uriData.mimeType.toLowerCase();
    final id = _uuid.v4();
    if (!_supportedMimeTypes.contains(mimeType)) {
      throw CustomIconImportException(l10n.customIconImportDataUriMimeList);
    }
    final extension = _extensionForMimeType(mimeType);
    if (extension == null) {
      throw CustomIconImportException(l10n.customIconImportUnsupportedFormat);
    }
    late final List<int> payload;
    if (mimeType == 'image/svg+xml') {
      final svg = uriData.contentAsString(encoding: utf8).trim();
      if (!svg.contains('<svg')) {
        throw CustomIconImportException(l10n.customIconImportInvalidSvg);
      }
      payload = utf8.encode(svg);
      if (payload.length > maxBytes) {
        throw CustomIconImportException(l10n.customIconImportSvgTooLarge);
      }
    } else {
      payload = uriData.contentAsBytes();
      if (payload.length > maxBytes) {
        throw CustomIconImportException(
          l10n.customIconImportEmbeddedImageTooLarge,
        );
      }
    }
    final storageKey = await _store.write(
      id: id,
      extension: extension,
      bytes: payload,
    );
    return CustomIconEntry(
      id: id,
      label: _sanitizeLabel(
        label,
        fallback: l10n.customIconLabelDefault,
      ),
      source: source,
      filePath: storageKey,
      mimeType: mimeType,
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<CustomIconEntry> _importFromRemoteUri(
    AppLocalizations l10n,
    Uri uri, {
    String? label,
    Future<({int statusCode, String? contentType, List<int> bytes})> Function(
      Uri uri,
    )?
    fetchRemote,
  }) async {
    // En suites con TestWidgetsFlutterBinding, el HttpClient del SDK devuelve 400
    // siempre. Esta inyección permite tests deterministas sin red real.
    try {
      late final int statusCode;
      late final String mimeType;
      late final List<int> bytes;

      if (fetchRemote != null) {
        final snap = await fetchRemote(uri);
        statusCode = snap.statusCode;
        mimeType = (snap.contentType ?? '').toLowerCase().trim();
        bytes = snap.bytes;
      } else {
        final response = await http
            .get(uri)
            .timeout(const Duration(seconds: 12));
        statusCode = response.statusCode;
        mimeType = (response.headers['content-type'] ?? '')
            .split(';')
            .first
            .trim()
            .toLowerCase();
        bytes = response.bodyBytes;
      }

      if (statusCode < 200 || statusCode >= 300) {
        throw CustomIconImportException(
          l10n.customIconImportDownloadFailed(statusCode.toString()),
        );
      }
      if (bytes.isEmpty) {
        throw CustomIconImportException(l10n.customIconImportUnsupportedFormat);
      }
      if (bytes.length > maxBytes) {
        throw CustomIconImportException(l10n.customIconImportRemoteTooLarge);
      }
      final resolvedMimeType = _resolveMimeType(uri, mimeType, bytes);
      final extension = _extensionForMimeType(resolvedMimeType);
      if (extension == null) {
        throw CustomIconImportException(l10n.customIconImportUnsupportedFormat);
      }
      final id = _uuid.v4();
      final storageKey = await _store.write(
        id: id,
        extension: extension,
        bytes: bytes,
      );
      return CustomIconEntry(
        id: id,
        label: _sanitizeLabel(
          label,
          fallback: _fallbackLabelFromUri(l10n, uri),
        ),
        source: uri.toString(),
        filePath: storageKey,
        mimeType: resolvedMimeType,
        createdAtMs: DateTime.now().millisecondsSinceEpoch,
      );
    } on CustomIconImportException {
      rethrow;
    } on TimeoutException {
      throw CustomIconImportException(l10n.customIconImportConnectFailed);
    } on http.ClientException catch (e) {
      final msg = e.message.toLowerCase();
      if (msg.contains('certificate') ||
          msg.contains('handshake') ||
          msg.contains('ssl') ||
          msg.contains('tls')) {
        throw CustomIconImportException(l10n.customIconImportCertFailed);
      }
      throw CustomIconImportException(l10n.customIconImportConnectFailed);
    }
  }

  /// Restaura un icono con [id] conocido (perfil Folio Cloud).
  Future<String> writeIconBytesWithId({
    required String id,
    required List<int> bytes,
    required String mimeType,
  }) async {
    final normalizedMime = mimeType.toLowerCase().trim();
    final extension = _extensionForMimeType(normalizedMime);
    if (extension == null) {
      throw const CustomIconImportException('Unsupported icon mime');
    }
    if (bytes.isEmpty || bytes.length > maxBytes) {
      throw const CustomIconImportException('Icon size invalid');
    }
    final safeId = id.trim();
    if (safeId.isEmpty) {
      throw const CustomIconImportException('Icon id empty');
    }
    final payload = normalizedMime == 'image/svg+xml'
        ? utf8.encode(utf8.decode(bytes, allowMalformed: true).trim())
        : bytes;
    return _store.write(
      id: safeId,
      extension: extension,
      bytes: payload,
    );
  }

  /// Deletes blob bytes for a stored icon (no-op if missing).
  Future<void> deleteIconBytes(String storageKey) =>
      _store.delete(storageKey);

  String _sanitizeLabel(String? label, {required String fallback}) {
    final trimmed = label?.trim() ?? '';
    if (trimmed.isNotEmpty) return trimmed;
    return fallback;
  }

  String _fallbackLabelFromUri(AppLocalizations l10n, Uri uri) {
    final name = uri.pathSegments.isEmpty ? '' : uri.pathSegments.last.trim();
    if (name.isEmpty) return l10n.customIconLabelImported;
    final withoutExt = name.replaceAll(RegExp(r'\.[A-Za-z0-9]+$'), '');
    return withoutExt.isEmpty ? l10n.customIconLabelImported : withoutExt;
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
