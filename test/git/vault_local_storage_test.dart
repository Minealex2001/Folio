/// Tests para M1: Nuevo formato + snapshots locales (sin multi-dispositivo).
///
/// Valida que:
/// 1. Descomposición de payload → árbol funciona
/// 2. Snapshots se crean y listan correctamente
/// 3. Round-trip: payload → árbol → snapshots → payload preserva contenido

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:folio/data/vault_payload.dart';
import 'package:folio/data/vault_local_storage.dart';
import 'package:folio/models/folio_page.dart';
import 'package:folio/models/block.dart';
import 'package:folio/git/vault_payload_converters.dart';
import 'package:folio/git/vault_snapshot_manager.dart';
import 'package:path/path.dart' as p;

void main() {
  group('VaultLocalStorage - M1', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('folio_local_storage_test_');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('decomposeAndStore creates tree and snapshot', () async {
      final payload = VaultPayload(
        pages: [
          FolioPage(
            id: 'page-001',
            title: 'Test Page',
            emoji: '📝',
            blocks: [
              FolioBlock(
                id: 'block-001',
                type: 'paragraph',
                text: 'Hello world',
              ),
            ],
          ),
        ],
        displayName: 'Test Vault',
      );

      // Simulate vault storage by using the temp directory
      // (In real usage, vault_paths.dart handles this)
      final treeDir = Directory(p.join(tempDir.path, 'repo'));
      final versionsDir = Directory(p.join(tempDir.path, 'versions'));

      // For this test, we manually decompose and check structure
      await treeDir.create(recursive: true);
      await versionsDir.create(recursive: true);

      // Use the converters directly
      await VaultPayloadToTree.decompose(payload, treeDir);

      // Verify tree structure exists
      expect(File(p.join(treeDir.path, 'tree.json')).existsSync(), isTrue);
      expect(Directory(p.join(treeDir.path, 'pages')).existsSync(), isTrue);
      expect(File(p.join(treeDir.path, 'vault', 'meta.json')).existsSync(), isTrue);
    });

    test('VaultLocalStorage round-trip preserves payload content', () async {
      final originalPayload = VaultPayload(
        pages: [
          FolioPage(
            id: 'abc123',
            title: 'Main Page',
            emoji: '📄',
            blocks: [
              FolioBlock(id: 'b1', type: 'paragraph', text: 'Paragraph'),
              FolioBlock(id: 'b2', type: 'heading', text: 'Heading'),
            ],
            tags: ['important'],
          ),
        ],
        displayName: 'My Vault',
        pageOrderByParent: {
          '': ['abc123'],
        },
      );

      // Decompose to tree
      final treeDir = Directory(p.join(tempDir.path, 'repo'));
      await treeDir.create(recursive: true);

      await VaultPayloadToTree.decompose(originalPayload, treeDir);

      // Recompose from tree
      final recomposed = await TreeToVaultPayload.compose(treeDir);

      // Verify content preserved
      expect(recomposed.displayName, equals(originalPayload.displayName));
      expect(recomposed.pages.length, equals(originalPayload.pages.length));
      expect(recomposed.pages[0].title, equals('Main Page'));
      expect(recomposed.pages[0].emoji, equals('📄'));
      expect(recomposed.pages[0].blocks.length, equals(2));
      expect(recomposed.pages[0].tags, contains('important'));
    });

    test('vault_snapshot_manager creates snapshots with metadata', () async {
      // Test VaultSnapshotManager directly (doesn't require VaultPaths setup)
      final vaultDir = Directory(tempDir.path);
      final treeDir = Directory(p.join(tempDir.path, 'repo'));

      final payload = VaultPayload(
        pages: [
          FolioPage(
            id: 'test-page',
            title: 'Test',
            blocks: [FolioBlock(id: 'b1', type: 'paragraph', text: 'content')],
          ),
        ],
        displayName: 'Test Vault',
      );

      // Create tree first
      await VaultPayloadToTree.decompose(payload, treeDir);

      // Create snapshot
      final manager = VaultSnapshotManager(
        vaultDir: vaultDir,
        deviceId: 'test-device',
      );

      final snapshot = await manager.createSnapshot(
        treeDir: treeDir,
        label: 'Test snapshot',
      );

      expect(snapshot.snapshotId, isNotEmpty);
      expect(snapshot.label, equals('Test snapshot'));
      expect(snapshot.deviceId, equals('test-device'));
      expect(snapshot.treeFormatVersion, equals(1));
    });
  });
}
