/// Tests para M4: P2P sync con nuevo formato.
///
/// Valida que:
/// 1. Pack header se crea correctamente
/// 2. Árbol se comprime a ZIP sin pérdida
/// 3. ZIP se descomprime idénticamente
/// 4. Estadísticas de compresión son correctas

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:folio/data/vault_payload.dart';
import 'package:folio/models/folio_page.dart';
import 'package:folio/models/block.dart';
import 'package:folio/git/vault_payload_converters.dart';
import 'package:folio/git/p2p_sync_packager.dart';
import 'package:folio/git/p2p_sync_pack.dart';
import 'package:path/path.dart' as p;

void main() {
  group('P2PSync - M4', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('folio_p2p_sync_test_');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('createPackHeader with tree information', () async {
      // Setup: create a vault tree
      final payload = VaultPayload(
        pages: [
          FolioPage(
            id: 'p2p-page-001',
            title: 'P2P Test Page',
            emoji: '📡',
            blocks: [
              FolioBlock(id: 'b1', type: 'paragraph', text: 'P2P sync content'),
            ],
          ),
        ],
        displayName: 'P2P Test Vault',
        pageOrderByParent: {'': ['p2p-page-001']},
      );

      final treeDir = Directory(p.join(tempDir.path, 'repo'));
      await VaultPayloadToTree.decompose(payload, treeDir);

      // Create pack header
      final packager = P2PSyncPackager(
        vaultId: 'vault-p2p-001',
        sourceDeviceId: 'device-p2p-001',
      );

      final header = await packager.createPackHeader(
        treeDir: treeDir,
        snapshotId: 'snap-001',
        snapshotLabel: 'P2P snapshot',
      );

      // Verify header
      expect(header.vaultId, equals('vault-p2p-001'));
      expect(header.sourceDeviceId, equals('device-p2p-001'));
      expect(header.formatVersion, equals(1));
      expect(header.treeFormatVersion, equals(1));
      expect(header.fileCount, greaterThan(0));
      expect(header.uncompressedSizeBytes, greaterThan(0));
      expect(header.compressedSizeBytes, greaterThan(0));
      expect(header.compressedSizeBytes, lessThan(header.uncompressedSizeBytes));
      expect(header.snapshotId, equals('snap-001'));
      expect(header.snapshotLabel, equals('P2P snapshot'));
      expect(header.compressionRatio, isPositive);
    });

    test('compressTreeToZip creates valid ZIP', () async {
      final payload = VaultPayload(
        pages: [
          FolioPage(
            id: 'zip-page',
            title: 'ZIP Test',
            blocks: [FolioBlock(id: 'b1', type: 'paragraph', text: 'Content')],
          ),
        ],
        displayName: 'ZIP Test',
        pageOrderByParent: {'': ['zip-page']},
      );

      final treeDir = Directory(p.join(tempDir.path, 'repo'));
      await VaultPayloadToTree.decompose(payload, treeDir);

      final packager = P2PSyncPackager(
        vaultId: 'vault-zip',
        sourceDeviceId: 'device-zip',
      );

      // Compress to ZIP
      final zipBytes = await packager.compressTreeToZip(treeDir);

      expect(zipBytes, isNotEmpty);
      // ZIP signature (magic bytes)
      expect(zipBytes[0], equals(0x50)); // 'P'
      expect(zipBytes[1], equals(0x4B)); // 'K'
    });

    test('decompressZip restores tree without data loss', () async {
      // Create original tree
      final payload = VaultPayload(
        pages: [
          FolioPage(
            id: 'decomp-page',
            title: 'Decompress Test',
            emoji: '📦',
            blocks: [
              FolioBlock(id: 'b1', type: 'paragraph', text: 'Test content'),
            ],
            tags: ['tag1', 'tag2'],
          ),
        ],
        displayName: 'Decompress Test',
        pageOrderByParent: {'': ['decomp-page']},
      );

      final treeDir = Directory(p.join(tempDir.path, 'repo'));
      await VaultPayloadToTree.decompose(payload, treeDir);

      // Compress
      final packager = P2PSyncPackager(
        vaultId: 'vault-decomp',
        sourceDeviceId: 'device-decomp',
      );

      final zipBytes = await packager.compressTreeToZip(treeDir);

      // Decompress to new directory
      final restoredDir =
          await packager.decompressZip(zipBytes, 'folio_decomp_test_');

      try {
        // Verify restored tree matches original
        final restoredPayload = await TreeToVaultPayload.compose(restoredDir);

        expect(restoredPayload.displayName, equals(payload.displayName));
        expect(restoredPayload.pages.length, equals(payload.pages.length));
        expect(
          restoredPayload.pages[0].title,
          equals(payload.pages[0].title),
        );
        expect(
          restoredPayload.pages[0].blocks[0].text,
          equals(payload.pages[0].blocks[0].text),
        );
        expect(restoredPayload.pages[0].tags, equals(['tag1', 'tag2']));
      } finally {
        // Cleanup restored directory
        if (restoredDir.existsSync()) {
          restoredDir.deleteSync(recursive: true);
        }
      }
    });

    test('compression stats calculated correctly', () async {
      final payload = VaultPayload(
        pages: [
          FolioPage(
            id: 'stats-page',
            title: 'Stats Test',
            blocks: [FolioBlock(id: 'b1', type: 'paragraph', text: 'Data')],
          ),
        ],
        displayName: 'Stats',
        pageOrderByParent: {'': ['stats-page']},
      );

      final treeDir = Directory(p.join(tempDir.path, 'repo'));
      await VaultPayloadToTree.decompose(payload, treeDir);

      final packager = P2PSyncPackager(
        vaultId: 'vault-stats',
        sourceDeviceId: 'device-stats',
      );

      final header = await packager.createPackHeader(treeDir: treeDir);

      // Calculate stats
      final stats = calculateSyncStats(
        uncompressedBytes: header.uncompressedSizeBytes,
        compressedBytes: header.compressedSizeBytes,
        fileCount: header.fileCount,
        durationMs: 100, // 100ms
      );

      expect(stats.uncompressed, equals(header.uncompressedSizeBytes));
      expect(stats.compressed, equals(header.compressedSizeBytes));
      expect(stats.fileCount, equals(header.fileCount));
      expect(stats.compressionRatio, isPositive);
      expect(stats.throughputMBps, greaterThan(0));

      // Verify toString
      final statsStr = stats.toString();
      expect(statsStr, contains('files='));
      expect(statsStr, contains('MB'));
    });

    test('pack header serializes to JSON', () async {
      final header = P2PSyncPackHeader(
        vaultId: 'vault-json',
        formatVersion: 1,
        timestamp: DateTime.now().millisecondsSinceEpoch,
        sourceDeviceId: 'device-json',
        treeFormatVersion: 1,
        fileCount: 10,
        compressedSizeBytes: 5000,
        uncompressedSizeBytes: 10000,
        snapshotId: 'snap-json',
        snapshotLabel: 'JSON test',
      );

      final json = header.toJson();
      expect(json['vaultId'], equals('vault-json'));
      expect(json['fileCount'], equals(10));

      final restored = P2PSyncPackHeader.fromJson(json);
      expect(restored.vaultId, equals(header.vaultId));
      expect(restored.fileCount, equals(header.fileCount));
    });
  });
}
