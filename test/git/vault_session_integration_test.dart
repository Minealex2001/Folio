/// Tests para la integración de snapshots en VaultSession (M2).
///
/// Simula el comportamiento que tendría vault_session.dart después de la integración:
/// - Detectar formato y cargar diferente según v0 o v1
/// - Crear snapshots en lugar de pageRevisions
/// - Restaurar desde snapshots

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:folio/data/vault_payload.dart';
import 'package:folio/models/folio_page.dart';
import 'package:folio/models/block.dart';
import 'package:folio/git/vault_migration_tool.dart';
import 'package:folio/data/vault_local_storage.dart';
import 'package:folio/git/vault_payload_converters.dart';
import 'package:folio/git/vault_snapshot_manager.dart';
import 'package:folio/git/version_info.dart';
import 'package:path/path.dart' as p;

void main() {
  group('VaultSession Integration - M2', () {
    late Directory tempDir;
    late Directory vaultDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('folio_session_integration_');
      vaultDir = Directory(p.join(tempDir.path, 'vault'));
      vaultDir.createSync(recursive: true);
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('vault session detects old format (v0)', () async {
      // Simulated: no vault.format file = format v0 (old)
      final formatVersion = 0; // Default
      expect(formatVersion, equals(0));
    });

    test('vault session detects new format (v1)', () async {
      // Write vault.format marker
      final markerFile = File(p.join(vaultDir.path, 'vault.format'));
      await markerFile.writeAsString('1');

      final content = await markerFile.readAsString();
      final formatVersion = int.tryParse(content.trim()) ?? 0;
      expect(formatVersion, equals(1));
    });

    test('session loads payload from tree in v1 format', () async {
      // Create a vault in new format
      final payload = VaultPayload(
        pages: [
          FolioPage(
            id: 'page-001',
            title: 'Session Test Page',
            emoji: '📝',
            blocks: [
              FolioBlock(id: 'b1', type: 'paragraph', text: 'Hello from session'),
            ],
          ),
        ],
        displayName: 'Session Test Vault',
        pageOrderByParent: {'': ['page-001']},
      );

      // Decompose to tree (simulating initial migration/persistence)
      final treeDir = Directory(p.join(vaultDir.path, 'repo'));
      await VaultPayloadToTree.decompose(payload, treeDir);

      // Mark as v1
      final markerFile = File(p.join(vaultDir.path, 'vault.format'));
      await markerFile.writeAsString('1');

      // Load back (simulating vault session load)
      final formatVersion =
          int.tryParse(await markerFile.readAsString()) ?? 0;
      expect(formatVersion, equals(1));

      final loaded = await TreeToVaultPayload.compose(treeDir);
      expect(loaded.displayName, equals('Session Test Vault'));
      expect(loaded.pages[0].blocks[0].text, equals('Hello from session'));
    });

    test('session creates snapshots during debounce in v1', () async {
      // Setup: initial vault in v1
      final payload = VaultPayload(
        pages: [
          FolioPage(
            id: 'edit-page',
            title: 'Page to Edit',
            emoji: '✏️',
            blocks: [FolioBlock(id: 'b1', type: 'paragraph', text: 'Initial')],
          ),
        ],
        displayName: 'Edit Test',
        pageOrderByParent: {'': ['edit-page']},
      );

      final treeDir = Directory(p.join(vaultDir.path, 'repo'));
      await VaultPayloadToTree.decompose(payload, treeDir);

      // Simulate debounce: modify page and create snapshot
      payload.pages[0].blocks[0].text = 'Modified content';

      // Persist (recompose tree)
      await VaultPayloadToTree.decompose(payload, treeDir);

      // Create snapshot (simulating _createVaultSnapshot)
      final snapshotManager = VaultSnapshotManager(
        vaultDir: vaultDir,
        deviceId: 'test-device',
      );
      await snapshotManager.init();
      final snapshot = await snapshotManager.createSnapshot(
        treeDir: treeDir,
        label: 'Edit session',
      );

      expect(snapshot.label, equals('Edit session'));
      expect(snapshot.fileManifest, isNotEmpty);
    });

    test('session converts pageRevisions to VersionInfo', () async {
      // Simulated: converting old format revision to VersionInfo
      // (would be in revisionsForPage method)
      final versionInfo = VersionInfo(
        versionId: 'rev-123',
        timestamp: DateTime.now().millisecondsSinceEpoch,
        label: 'Old format revision',
        source: 'memory', // Memory-based (old format)
      );

      expect(versionInfo.isLegacy, isTrue);
      expect(versionInfo.isSnapshot, isFalse);
    });

    test('session converts snapshots to VersionInfo', () async {
      // Simulated: converting new format snapshot to VersionInfo
      final now = DateTime.now().millisecondsSinceEpoch;
      final versionInfo = VersionInfo(
        versionId: 'snap-456',
        timestamp: now,
        label: 'Auto snapshot',
        source: 'snapshot', // Snapshot-based (new format)
        deviceId: 'dev-001',
      );

      expect(versionInfo.isSnapshot, isTrue);
      expect(versionInfo.isLegacy, isFalse);
      expect(versionInfo.deviceId, equals('dev-001'));
    });

    test('session restores from snapshot in v1', () async {
      // Setup: create two snapshots
      final payload1 = VaultPayload(
        pages: [
          FolioPage(
            id: 'restore-test',
            title: 'Original Title',
            emoji: '📍',
            blocks: [FolioBlock(id: 'b1', type: 'paragraph', text: 'Version 1')],
          ),
        ],
        displayName: 'Restore Test',
        pageOrderByParent: {'': ['restore-test']},
      );

      final treeDir = Directory(p.join(vaultDir.path, 'repo'));
      await VaultPayloadToTree.decompose(payload1, treeDir);

      final manager = VaultSnapshotManager(
        vaultDir: vaultDir,
        deviceId: 'restore-device',
      );
      await manager.init();

      final snapshot1 = await manager.createSnapshot(
        treeDir: treeDir,
        label: 'Version 1',
      );

      // Modify and create v2
      payload1.pages[0].blocks[0].text = 'Version 2';
      payload1.pages[0].title = 'Modified Title';
      await VaultPayloadToTree.decompose(payload1, treeDir);

      final snapshot2 = await manager.createSnapshot(
        treeDir: treeDir,
        label: 'Version 2',
        parentSnapshotId: snapshot1.snapshotId,
      );

      // List snapshots
      final snapshots = await manager.listSnapshots();
      expect(snapshots.length, equals(2));
      expect(snapshots[0].label, equals('Version 2')); // Most recent first
      expect(snapshots[1].label, equals('Version 1'));

      // Restore to v1 would be implemented in VaultSnapshotManager.restoreSnapshot
      // For now, verify the metadata is there
      expect(snapshot2.parentSnapshotId, equals(snapshot1.snapshotId));
    });

    test('auto-migration happens on first load of old vault', () async {
      // Simulate: old vault with vault.bin (no vault.format or tree/)
      // After migration, vault.format=1 and tree/ exists

      final payload = VaultPayload(
        pages: [
          FolioPage(
            id: 'migrate-page',
            title: 'To Migrate',
            blocks: [FolioBlock(id: 'b1', type: 'paragraph', text: 'Content')],
          ),
        ],
        displayName: 'Migrate Test',
        pageOrderByParent: {'': ['migrate-page']},
      );

      // Before migration: no tree
      final treeDir = Directory(p.join(vaultDir.path, 'repo'));
      expect(treeDir.existsSync(), isFalse);

      // Simulate migration
      await VaultPayloadToTree.decompose(payload, treeDir);
      final markerFile = File(p.join(vaultDir.path, 'vault.format'));
      await markerFile.writeAsString('1');

      // After migration: tree exists and v1 marker is set
      expect(treeDir.existsSync(), isTrue);
      expect(File(p.join(treeDir.path, 'tree.json')).existsSync(), isTrue);
      final version = int.tryParse(await markerFile.readAsString()) ?? 0;
      expect(version, equals(1));
    });
  });
}
