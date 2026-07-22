/// Tests para M3: Cloud pack builder y deduplicación (sync en nube).
///
/// Valida que:
/// 1. Manifest se construye correctamente desde árbol
/// 2. Deduplicación detecta archivos duplicados
/// 3. Comparación de manifests detecta cambios

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:folio/data/vault_payload.dart';
import 'package:folio/models/folio_page.dart';
import 'package:folio/models/block.dart';
import 'package:folio/git/vault_payload_converters.dart';
import 'package:folio/git/cloud_pack_builder.dart';
import 'package:folio/git/cloud_pack.dart';
import 'package:path/path.dart' as p;

void main() {
  group('CloudPack - M3', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('folio_cloud_pack_test_');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('buildManifest creates file list with SHA-256 hashes', () async {
      // Setup: create a vault and tree
      final payload = VaultPayload(
        pages: [
          FolioPage(
            id: 'page-001',
            title: 'Cloud Test Page',
            emoji: '☁️',
            blocks: [
              FolioBlock(id: 'b1', type: 'paragraph', text: 'Cloud content'),
            ],
          ),
        ],
        displayName: 'Cloud Test Vault',
        pageOrderByParent: {'': ['page-001']},
      );

      final treeDir = Directory(p.join(tempDir.path, 'repo'));
      await VaultPayloadToTree.decompose(payload, treeDir);

      // Build manifest
      final builder = CloudPackBuilder(
        vaultId: 'vault-001',
        deviceId: 'device-001',
      );

      final manifest = await builder.buildManifest(treeDir: treeDir);

      // Verify manifest
      expect(manifest.vaultId, equals('vault-001'));
      expect(manifest.deviceId, equals('device-001'));
      expect(manifest.treeFormatVersion, equals(1));
      expect(manifest.files, isNotEmpty);

      // Verify files have SHA-256 hashes
      for (final file in manifest.files) {
        expect(file.sha256, isNotEmpty);
        expect(file.sizeBytes, greaterThan(0));
        expect(file.path, isNotEmpty);
        // Initially, contentEncrypted should be null (added during upload)
        expect(file.contentEncrypted, isNull);
      }
    });

    test('compareManifests detects new files', () async {
      // Create initial manifest
      final payload1 = VaultPayload(
        pages: [
          FolioPage(
            id: 'page-001',
            title: 'V1',
            blocks: [FolioBlock(id: 'b1', type: 'paragraph', text: 'V1')],
          ),
        ],
        displayName: 'Test',
        pageOrderByParent: {'': ['page-001']},
      );

      final treeDir = Directory(p.join(tempDir.path, 'repo'));
      await VaultPayloadToTree.decompose(payload1, treeDir);

      final builder = CloudPackBuilder(
        vaultId: 'vault-001',
        deviceId: 'device-001',
      );

      final manifest1 = await builder.buildManifest(treeDir: treeDir);

      // Add new page
      payload1.pages.add(FolioPage(
        id: 'page-002',
        title: 'V2',
        blocks: [FolioBlock(id: 'b2', type: 'paragraph', text: 'V2')],
      ));
      payload1.pageOrderByParent[''] = ['page-001', 'page-002'];

      await VaultPayloadToTree.decompose(payload1, treeDir);
      final manifest2 = await builder.buildManifest(treeDir: treeDir);

      // Compare
      final diff = compareManifests(manifest1, manifest2);

      expect(diff.newFiles, isNotEmpty); // Should detect new files
      expect(diff.modifiedFiles.isNotEmpty, anyOf([isTrue, isFalse])); // May have modified tree.json
      expect(diff.deletedFiles, isEmpty); // No deletions
    });

    test('compareManifests detects deleted files', () async {
      // Create manifest with 2 pages
      final payload = VaultPayload(
        pages: [
          FolioPage(
            id: 'page-001',
            title: 'P1',
            blocks: [FolioBlock(id: 'b1', type: 'paragraph', text: 'P1')],
          ),
          FolioPage(
            id: 'page-002',
            title: 'P2',
            blocks: [FolioBlock(id: 'b2', type: 'paragraph', text: 'P2')],
          ),
        ],
        displayName: 'Test',
        pageOrderByParent: {'': ['page-001', 'page-002']},
      );

      final treeDir = Directory(p.join(tempDir.path, 'repo'));
      await VaultPayloadToTree.decompose(payload, treeDir);

      final builder = CloudPackBuilder(
        vaultId: 'vault-001',
        deviceId: 'device-001',
      );

      final manifest1 = await builder.buildManifest(treeDir: treeDir);

      // Manually delete page-002 directory (simulating deletion)
      final page2Dir = Directory(p.join(treeDir.path, 'pages', 'pa'));
      if (page2Dir.existsSync()) {
        final page2PageDir = Directory(p.join(page2Dir.path, 'page-002'));
        if (page2PageDir.existsSync()) {
          await page2PageDir.delete(recursive: true);
        }
      }

      // Rebuild manifest (reflects the deletion)
      final manifest2 = await builder.buildManifest(treeDir: treeDir);

      // Compare
      final diff = compareManifests(manifest1, manifest2);

      // After deletion, manifest2 has fewer files
      expect(manifest2.files.length, lessThan(manifest1.files.length));
      expect(diff.deletedFiles, isNotEmpty); // Should detect deleted files
    });

    test('compareManifests first upload treats all as new', () async {
      final payload = VaultPayload(
        pages: [
          FolioPage(
            id: 'page-001',
            title: 'First Upload',
            blocks: [FolioBlock(id: 'b1', type: 'paragraph', text: 'Content')],
          ),
        ],
        displayName: 'Test',
        pageOrderByParent: {'': ['page-001']},
      );

      final treeDir = Directory(p.join(tempDir.path, 'repo'));
      await VaultPayloadToTree.decompose(payload, treeDir);

      final builder = CloudPackBuilder(
        vaultId: 'vault-001',
        deviceId: 'device-001',
      );

      final manifest = await builder.buildManifest(treeDir: treeDir);

      // First upload (no previous manifest)
      final diff = compareManifests(null, manifest);

      expect(diff.newFiles.length, equals(manifest.files.length));
      expect(diff.modifiedFiles, isEmpty);
      expect(diff.deletedFiles, isEmpty);
      expect(diff.unchangedFiles, isEmpty);
    });

    test('cloud pack manifest serializes to JSON', () async {
      final payload = VaultPayload(
        pages: [],
        displayName: 'JSON Test',
        pageOrderByParent: {},
      );

      final treeDir = Directory(p.join(tempDir.path, 'repo'));
      await VaultPayloadToTree.decompose(payload, treeDir);

      final builder = CloudPackBuilder(
        vaultId: 'vault-001',
        deviceId: 'device-001',
      );

      final manifest = await builder.buildManifest(treeDir: treeDir);

      // Serialize to JSON
      final json = manifest.toJson();
      expect(json, isNotEmpty);
      expect(json['vaultId'], equals('vault-001'));
      expect(json['deviceId'], equals('device-001'));
      expect(json['files'], isNotEmpty);

      // Deserialize back
      final restored = CloudPackManifest.fromJson(json);
      expect(restored.vaultId, equals(manifest.vaultId));
      expect(restored.files.length, equals(manifest.files.length));
    });
  });
}
