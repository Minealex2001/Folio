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

    test('decompose creates tree structure without snapshot', () async {
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

    test('decomposeAndStoreAt refuses empty overwrite of non-empty tree', () async {
      final vaultDir = Directory(tempDir.path);
      final treeDir = Directory(p.join(tempDir.path, 'repo'));
      final full = VaultPayload(
        pages: [
          FolioPage(
            id: 'keep-me',
            title: 'Keep',
            blocks: [FolioBlock(id: 'b1', type: 'paragraph', text: 'x')],
          ),
        ],
        displayName: 'V',
        pageOrderByParent: {
          '': ['keep-me'],
        },
      );
      await VaultPayloadToTree.decompose(full, treeDir);
      expect(VaultLocalStorage.countPageDirs(treeDir), 1);

      await expectLater(
        VaultLocalStorage.decomposeAndStoreAt(
          vaultDir,
          VaultPayload(pages: [], displayName: 'V'),
        ),
        throwsA(isA<VaultEmptyOverwriteException>()),
      );
      expect(VaultLocalStorage.countPageDirs(treeDir), 1);
      expect(File(p.join(treeDir.path, 'tree.json')).existsSync(), isTrue);
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

      // Los hashes del manifest deben ser SHA-256 reales (64 hex chars),
      // no el placeholder antiguo.
      expect(snapshot.fileManifest, isNotEmpty);
      for (final entry in snapshot.fileManifest) {
        expect(entry.sha256, hasLength(64));
        expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(entry.sha256), isTrue);
      }

      // El snapshot debe haber escrito un .zip real con contenido.
      final zipFile = File(
        p.join(tempDir.path, 'versions', '${snapshot.snapshotId}.zip'),
      );
      expect(zipFile.existsSync(), isTrue);
      expect(zipFile.lengthSync(), greaterThan(0));
    });

    test('restoreSnapshot restores tree content from a real snapshot', () async {
      final vaultDir = Directory(tempDir.path);
      final treeDir = Directory(p.join(tempDir.path, 'repo'));

      final payload = VaultPayload(
        pages: [
          FolioPage(
            id: 'restore-page',
            title: 'Before restore',
            blocks: [
              FolioBlock(id: 'b1', type: 'paragraph', text: 'original content'),
            ],
          ),
        ],
        displayName: 'Restore Test Vault',
      );

      await VaultPayloadToTree.decompose(payload, treeDir);

      final manager = VaultSnapshotManager(
        vaultDir: vaultDir,
        deviceId: 'test-device',
      );
      final snapshot = await manager.createSnapshot(
        treeDir: treeDir,
        label: 'Before edit',
      );

      // Simula una edición posterior modificando el árbol en disco.
      final editedPayload = VaultPayload(
        pages: [
          FolioPage(
            id: 'restore-page',
            title: 'After edit',
            blocks: [
              FolioBlock(id: 'b1', type: 'paragraph', text: 'edited content'),
            ],
          ),
        ],
        displayName: 'Restore Test Vault',
      );
      await VaultPayloadToTree.decompose(editedPayload, treeDir);

      final editedRecomposed = await TreeToVaultPayload.compose(treeDir);
      expect(editedRecomposed.pages[0].title, equals('After edit'));

      // Restaura el snapshot anterior y confirma que el contenido vuelve.
      final restored = await manager.restoreSnapshot(
        snapshot.snapshotId,
        treeDir,
      );
      expect(restored, isTrue);

      final restoredPayload = await TreeToVaultPayload.compose(treeDir);
      expect(restoredPayload.pages[0].title, equals('Before restore'));
      expect(
        restoredPayload.pages[0].blocks[0].text,
        equals('original content'),
      );
    });
  });
}
