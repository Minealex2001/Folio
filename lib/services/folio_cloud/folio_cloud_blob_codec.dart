import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

/// Tamaño máximo de cada trozo en claro (antes de cifrar) para que el
/// ciphertext AES-GCM quede por debajo de [kFolioStorageMaxObjectBytes]
/// (256 MiB). 128 MiB deja margen para nonce + MAC + overhead.
const int kFolioCloudBlobChunkPlainBytes = 128 * 1024 * 1024;

/// Envelope pre-cifrado: el plaintext que se cifra es `[flag][payload]`.
/// `0x00` = bytes crudos (sin gzip); `0x01` = payload gzip.
const int kFolioCloudBlobEnvelopeRaw = 0x00;
const int kFolioCloudBlobEnvelopeGzip = 0x01;

/// Extensiones que ya están comprimidas: comprimir de nuevo suele agrandar.
const _kAlreadyCompressedExts = <String>{
  '.png',
  '.jpg',
  '.jpeg',
  '.gif',
  '.webp',
  '.avif',
  '.heic',
  '.heif',
  '.mp4',
  '.m4a',
  '.mp3',
  '.aac',
  '.ogg',
  '.opus',
  '.flac',
  '.zip',
  '.gz',
  '.tgz',
  '.bz2',
  '.xz',
  '.7z',
  '.rar',
  '.pdf',
  '.docx',
  '.xlsx',
  '.pptx',
  '.odt',
  '.ods',
  '.odp',
  '.apk',
  '.wasm',
};

enum FolioCloudBlobCompression {
  none,
  gzip,
}

String folioCloudBlobCompressionWire(FolioCloudBlobCompression c) {
  switch (c) {
    case FolioCloudBlobCompression.none:
      return 'none';
    case FolioCloudBlobCompression.gzip:
      return 'gzip';
  }
}

FolioCloudBlobCompression? folioCloudBlobCompressionParse(String? w) {
  switch (w?.trim().toLowerCase()) {
    case null:
    case '':
    case 'none':
      return FolioCloudBlobCompression.none;
    case 'gzip':
      return FolioCloudBlobCompression.gzip;
    default:
      return null;
  }
}

/// True si el path de adjunto conviene no comprimir (ya comprimido).
bool folioCloudBlobShouldSkipCompressionForPath(String? relativePath) {
  if (relativePath == null || relativePath.isEmpty) return false;
  final ext = p.extension(relativePath).toLowerCase();
  return _kAlreadyCompressedExts.contains(ext);
}

/// Roles cloud-pack / device-sync que suelen ser texto o binarios
/// altamente comprimibles.
bool folioCloudBlobRoleIsCompressible(String role) {
  final r = role.trim().toLowerCase();
  if (r == 'vault_bin' ||
      r == 'vaultbin' ||
      r == 'manifest' ||
      r == 'backupmanifest' ||
      r == 'vault_mode' ||
      r == 'vaultmode') {
    return true;
  }
  // Device-sync: pages y vault rest son JSON.
  if (r.startsWith('device-sync-page:') ||
      r == 'device-sync-vault' ||
      r.startsWith('device-sync-att:')) {
    return true;
  }
  return false;
}

/// Resultado de preparar un blob lógico (posiblemente troceado).
class FolioCloudPreparedPlainChunks {
  const FolioCloudPreparedPlainChunks({
    required this.chunks,
    required this.compression,
  });

  /// Cada elemento es el plaintext a cifrar (`[envelope][payload]` partido).
  final List<Uint8List> chunks;
  final FolioCloudBlobCompression compression;
}

List<int> _gzipEncode(List<int> plain) {
  return GZipEncoder().encode(plain, level: 6);
}

List<int> _gzipDecode(List<int> compressed) {
  final decoded = GZipDecoder().decodeBytes(compressed);
  return decoded;
}

/// Comprime (si conviene) y trocea [plain] en partes ≤ [maxChunkPlainBytes].
///
/// El stream cifrado es siempre `[flag][payload]` partido en ventanas de
/// [maxChunkPlainBytes] (un solo trozo si cabe entero).
FolioCloudPreparedPlainChunks prepareCloudBlobPlainChunks({
  required List<int> plain,
  required String role,
  String? attachmentRelativePath,
  int maxChunkPlainBytes = kFolioCloudBlobChunkPlainBytes,
  bool forceCompress = false,
}) {
  assert(maxChunkPlainBytes > 1);

  final skipByPath = folioCloudBlobShouldSkipCompressionForPath(
    attachmentRelativePath,
  );
  final isAttachment =
      role.toLowerCase().contains('attachment') ||
      role.toLowerCase().startsWith('device-sync-att:');

  final bool shouldCompress;
  if (forceCompress) {
    shouldCompress = true;
  } else if (skipByPath) {
    shouldCompress = false;
  } else if (isAttachment) {
    // Adjuntos no precomprimidos: gzip si pesan algo.
    shouldCompress = plain.length > 64 * 1024;
  } else {
    shouldCompress = folioCloudBlobRoleIsCompressible(role);
  }

  late final Uint8List enveloped;
  late final FolioCloudBlobCompression compression;

  if (shouldCompress) {
    final compressed = _gzipEncode(plain);
    // Si gzip no ayuda, guardar raw (ahorra CPU en restore).
    if (compressed.length < plain.length) {
      enveloped = Uint8List(1 + compressed.length);
      enveloped[0] = kFolioCloudBlobEnvelopeGzip;
      enveloped.setRange(1, enveloped.length, compressed);
      compression = FolioCloudBlobCompression.gzip;
    } else {
      enveloped = Uint8List(1 + plain.length);
      enveloped[0] = kFolioCloudBlobEnvelopeRaw;
      enveloped.setRange(1, enveloped.length, plain);
      compression = FolioCloudBlobCompression.none;
    }
  } else {
    enveloped = Uint8List(1 + plain.length);
    enveloped[0] = kFolioCloudBlobEnvelopeRaw;
    enveloped.setRange(1, enveloped.length, plain);
    compression = FolioCloudBlobCompression.none;
  }

  if (enveloped.length <= maxChunkPlainBytes) {
    return FolioCloudPreparedPlainChunks(
      chunks: [enveloped],
      compression: compression,
    );
  }

  final chunks = <Uint8List>[];
  for (var offset = 0; offset < enveloped.length; offset += maxChunkPlainBytes) {
    final end = (offset + maxChunkPlainBytes).clamp(0, enveloped.length);
    chunks.add(Uint8List.fromList(enveloped.sublist(offset, end)));
  }
  return FolioCloudPreparedPlainChunks(
    chunks: chunks,
    compression: compression,
  );
}

/// Reensambla trozos envelope y devuelve el plaintext original.
Uint8List decodeCloudBlobPlainChunks(List<Uint8List> chunks) {
  if (chunks.isEmpty) {
    throw StateError('cloud blob: empty chunks');
  }
  final builder = BytesBuilder(copy: false);
  for (final c in chunks) {
    builder.add(c);
  }
  final enveloped = builder.takeBytes();
  return decodeCloudBlobEnvelope(enveloped);
}

/// Decodifica un blob envelope único `[flag][payload]` (o legacy sin flag).
///
/// Compatibilidad: blobs cloud-pack v1 se cifraban sin envelope. Si el
/// llamador sabe que es legacy, pasa [legacyRaw] = true y se trata todo el
/// buffer como payload crudo. Si [legacyRaw] es false y el primer byte no es
/// un flag conocido, también se trata como legacy (defensivo).
Uint8List decodeCloudBlobEnvelope(
  List<int> enveloped, {
  bool legacyRaw = false,
}) {
  if (enveloped.isEmpty) return Uint8List(0);
  if (legacyRaw) {
    return Uint8List.fromList(enveloped);
  }
  final flag = enveloped[0];
  if (flag == kFolioCloudBlobEnvelopeRaw) {
    return Uint8List.fromList(enveloped.sublist(1));
  }
  if (flag == kFolioCloudBlobEnvelopeGzip) {
    return Uint8List.fromList(_gzipDecode(enveloped.sublist(1)));
  }
  // Blob pre-envelope (cloud-pack v1): sin prefijo.
  return Uint8List.fromList(enveloped);
}
