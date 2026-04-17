import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../../crypto/vault_crypto.dart';
import '../../data/folio_cloud_pack_format.dart';

/// Cifra un archivo del pack con nonce determinístico (deduplicación en Storage).
Future<Uint8List> cloudPackEncryptPlainBlob({
  required List<int> plain,
  required SecretKey packKey,
  required List<int> nonceBasis,
}) =>
    VaultCrypto.encryptPayloadDeterministicPack(
      plain: plain,
      dek: packKey,
      nonceBasis: nonceBasis,
    );

/// Cifra el snapshot con nonce aleatorio (cada revisión es distinta).
Future<Uint8List> cloudPackEncryptBytes({
  required List<int> plain,
  required SecretKey packKey,
}) =>
    VaultCrypto.encryptPayload(plain: plain, dek: packKey);

/// Descifra un blob cloud-pack.
Future<Uint8List> cloudPackDecryptBytes({
  required List<int> blob,
  required SecretKey packKey,
}) =>
    VaultCrypto.decryptPayload(blob: blob, dek: packKey);

/// `blobId` = SHA-256 del ciphertext completo (opaco para el servidor).
Future<String> cloudPackBlobIdFromCipherBytes(List<int> cipherBytes) async {
  final h = await Sha256().hash(cipherBytes);
  return _hexLower(h.bytes);
}

String _hexLower(List<int> bytes) {
  final sb = StringBuffer();
  for (final b in bytes) {
    sb.write(b.toRadixString(16).padLeft(2, '0'));
  }
  return sb.toString();
}

/// Cifra el manifiesto del snapshot para subirlo como `.bin`.
Future<Uint8List> cloudPackEncryptSnapshotManifest(
  FolioCloudPackSnapshotManifest manifest,
  SecretKey packKey,
) async {
  final plain = manifest.toUtf8Bytes();
  return cloudPackEncryptBytes(plain: plain, packKey: packKey);
}

/// Descifra y parsea el manifiesto del snapshot.
Future<FolioCloudPackSnapshotManifest?> cloudPackDecryptSnapshotManifest({
  required List<int> cipherBlob,
  required SecretKey packKey,
}) async {
  try {
    final clear = await cloudPackDecryptBytes(blob: cipherBlob, packKey: packKey);
    return FolioCloudPackSnapshotManifest.fromJsonBytes(clear);
  } catch (_) {
    return null;
  }
}

bool cloudPackIsValidBlobId(String id) {
  final s = id.trim().toLowerCase();
  return s.length == 64 && RegExp(r'^[0-9a-f]+$').hasMatch(s);
}
