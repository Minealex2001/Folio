import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folio/data/folio_cloud_pack_format.dart';
import 'package:folio/services/folio_cloud/folio_cloud_blob_codec.dart';
import 'package:folio/services/folio_cloud/folio_cloud_pack_crypto.dart';

void main() {
  group('folio_cloud_blob_codec', () {
    test('round-trip gzip envelope for compressible role', () {
      final plain = Uint8List.fromList(
        utf8.encode('hola ' * 20000), // texto repetido → gzip ayuda
      );
      final prepared = prepareCloudBlobPlainChunks(
        plain: plain,
        role: 'vault_bin',
      );
      expect(prepared.compression, FolioCloudBlobCompression.gzip);
      expect(prepared.chunks, hasLength(1));
      expect(prepared.chunks.first[0], kFolioCloudBlobEnvelopeGzip);

      final restored = decodeCloudBlobPlainChunks(prepared.chunks);
      expect(restored, plain);
    });

    test('skips gzip for already-compressed attachment extension', () {
      final plain = Uint8List.fromList(List<int>.generate(80 * 1024, (i) => i));
      final prepared = prepareCloudBlobPlainChunks(
        plain: plain,
        role: 'attachment',
        attachmentRelativePath: 'attachments/photo.png',
      );
      expect(prepared.compression, FolioCloudBlobCompression.none);
      expect(prepared.chunks.first[0], kFolioCloudBlobEnvelopeRaw);
      expect(decodeCloudBlobPlainChunks(prepared.chunks), plain);
    });

    test('splits into multiple chunks under small max', () {
      final plain = Uint8List.fromList(
        List<int>.generate(1000, (i) => i % 251),
      );
      final prepared = prepareCloudBlobPlainChunks(
        plain: plain,
        role: 'vault_bin',
        maxChunkPlainBytes: 200,
        forceCompress: false,
      );
      // forceCompress false + vault_bin still compresses; may be 1 chunk if
      // gzip shrinks a lot. Force no-compress path via raw role + skip.
      final preparedRaw = prepareCloudBlobPlainChunks(
        plain: plain,
        role: 'vault_keys', // not compressible
        maxChunkPlainBytes: 200,
      );
      expect(preparedRaw.chunks.length, greaterThan(1));
      final restored = decodeCloudBlobPlainChunks(preparedRaw.chunks);
      expect(restored, plain);
      // Keep analyzer happy if compression path also works.
      expect(decodeCloudBlobPlainChunks(prepared.chunks), plain);
    });

    test('legacyRaw decode returns bytes unchanged', () {
      final legacy = Uint8List.fromList([1, 2, 3, 4]);
      expect(
        decodeCloudBlobEnvelope(legacy, legacyRaw: true),
        legacy,
      );
    });
  });

  group('cloud-pack format v2 chunks', () {
    test('parses and validates chunked vault_bin items', () {
      final fixed = <FolioCloudPackSnapshotItem>[
        FolioCloudPackSnapshotItem(
          role: FolioCloudPackBlobRole.backupManifest,
          blobId: 'aa' * 32,
        ),
        FolioCloudPackSnapshotItem(
          role: FolioCloudPackBlobRole.vaultBin,
          blobId: 'bb' * 32,
          chunkIndex: 0,
          chunkCount: 2,
          compression: FolioCloudBlobCompression.gzip,
        ),
        FolioCloudPackSnapshotItem(
          role: FolioCloudPackBlobRole.vaultBin,
          blobId: 'cc' * 32,
          chunkIndex: 1,
          chunkCount: 2,
          compression: FolioCloudBlobCompression.gzip,
        ),
      ];
      final manifest = FolioCloudPackSnapshotManifest(
        formatVersion: 2,
        createdAtUtc: '2026-01-01T00:00:00.000Z',
        items: fixed,
        contentFingerprint: 'dd' * 32,
      );
      final parsed =
          FolioCloudPackSnapshotManifest.fromJsonBytes(manifest.toUtf8Bytes());
      expect(parsed, isNotNull);
      expect(parsed!.formatVersion, 2);
      expect(parsed.items, hasLength(3));
      expect(parsed.items.where((e) => e.role == FolioCloudPackBlobRole.vaultBin),
          hasLength(2));
    });

    test('rejects incomplete chunk set', () {
      final bad = FolioCloudPackSnapshotManifest(
        formatVersion: 2,
        createdAtUtc: '2026-01-01T00:00:00.000Z',
        items: [
          FolioCloudPackSnapshotItem(
            role: FolioCloudPackBlobRole.backupManifest,
            blobId: 'aa' * 32,
          ),
          FolioCloudPackSnapshotItem(
            role: FolioCloudPackBlobRole.vaultBin,
            blobId: 'bb' * 32,
            chunkIndex: 0,
            chunkCount: 2,
          ),
          // missing chunk 1
        ],
      );
      expect(
        FolioCloudPackSnapshotManifest.fromJsonBytes(bad.toUtf8Bytes()),
        isNull,
      );
    });

    test('still reads format version 1 manifests', () {
      final v1Json = jsonEncode({
        'formatVersion': 1,
        'createdAtUtc': '2026-01-01T00:00:00.000Z',
        'items': [
          {'role': 'manifest', 'blobId': 'aa' * 32},
          {'role': 'vault_bin', 'blobId': 'bb' * 32},
        ],
      });
      final parsed = FolioCloudPackSnapshotManifest.fromJsonBytes(
        utf8.encode(v1Json),
      );
      expect(parsed, isNotNull);
      expect(parsed!.formatVersion, 1);
    });
  });

  group('encrypt/decrypt round-trip with chunked envelope', () {
    test('cipher chunks decrypt and reassemble', () async {
      final key = SecretKey(List<int>.filled(32, 7));
      // Datos poco comprimibles + rol no-gzip → varios trozos seguros.
      final plain = Uint8List.fromList(
        List<int>.generate(5000, (i) => (i * 37 + 11) % 256),
      );
      final prepared = prepareCloudBlobPlainChunks(
        plain: plain,
        role: 'vault_keys',
        maxChunkPlainBytes: 1024,
      );
      expect(prepared.chunks.length, greaterThan(1));

      final cipherChunks = <Uint8List>[];
      for (var i = 0; i < prepared.chunks.length; i++) {
        final cipher = await cloudPackEncryptPlainBlob(
          plain: prepared.chunks[i],
          packKey: key,
          role: 'vaultKeys:chunk:$i/${prepared.chunks.length}',
        );
        expect(cipher.length, lessThan(256 * 1024 * 1024));
        cipherChunks.add(cipher);
      }

      final decrypted = <Uint8List>[];
      for (final c in cipherChunks) {
        decrypted.add(await cloudPackDecryptBytes(blob: c, packKey: key));
      }
      final restored = decodeCloudBlobPlainChunks(decrypted);
      expect(restored, plain);
    });
  });
}
