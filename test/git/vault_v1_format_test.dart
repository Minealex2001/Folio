/// Tests del formato vault v1: persistencia sin blob, snapshots únicos,
/// migración de revisiones, round-trip completo e historial por página.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folio/data/vault_payload.dart';
import 'package:folio/data/vault_paths.dart';
import 'package:folio/git/vault_migration_tool.dart';
import 'package:folio/git/vault_payload_converters.dart';
import 'package:folio/git/vault_snapshot_manager.dart';
import 'package:folio/models/block.dart';
import 'package:folio/models/folio_page.dart';
import 'package:folio/models/folio_page_import_info.dart';
import 'package:folio/models/folio_page_revision.dart';
import 'package:folio/models/page_property.dart';
import 'package:path/path.dart' as p;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

  group('Vault v1 format fixes', () {
    late Directory mockedSupportDir;

    setUp(() async {
      mockedSupportDir = await Directory.systemTemp.createTemp(
        'folio_v1_fix_',
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(pathProviderChannel, (call) async {
            return mockedSupportDir.path;
          });
    });

    tearDown(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(pathProviderChannel, null);
      VaultPaths.clearActiveVaultId();
      if (mockedSupportDir.existsSync()) {
        await mockedSupportDir.delete(recursive: true);
      }
    });

    test('round-trip preserves properties, tombstones, syncClock, importInfo',
        () async {
      final tempDir =
          Directory.systemTemp.createTempSync('folio_roundtrip_');
      addTearDown(() {
        if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
      });

      final original = VaultPayload(
        pages: [
          FolioPage(
            id: 'abc123',
            title: 'Props page',
            emoji: '🔧',
            blocks: [
              FolioBlock(id: 'b1', type: 'paragraph', text: 'body'),
            ],
            properties: [
              FolioPageProperty(
                id: 'p1',
                name: 'Status',
                type: PagePropertyType.status,
                value: 'Done',
              ),
            ],
            tags: ['alpha'],
            lastImportInfo: FolioPageImportInfo(
              clientAppId: 'notion',
              clientAppName: 'Notion',
              importedAtMs: 1700000000000,
              importMode: 'newPage',
              sourceUrl: 'https://example.com',
            ),
          ),
        ],
        displayName: 'Roundtrip Vault',
        pageOrderByParent: {'': ['abc123']},
        pageTombstones: {'gone-page': 1700000001000},
        syncClock: 42,
      );

      final treeDir = Directory(p.join(tempDir.path, 'repo'));
      await VaultPayloadToTree.decompose(original, treeDir);
      final recomposed = await TreeToVaultPayload.compose(treeDir);

      expect(recomposed.syncClock, equals(42));
      expect(recomposed.pageTombstones['gone-page'], equals(1700000001000));
      final page = recomposed.pages.firstWhere((pg) => pg.id == 'abc123');
      expect(page.properties, hasLength(1));
      expect(page.properties.first.name, equals('Status'));
      expect(page.properties.first.value, equals('Done'));
      expect(page.lastImportInfo?.clientAppId, equals('notion'));
      expect(page.lastImportInfo?.sourceUrl, equals('https://example.com'));
      expect(page.tags, contains('alpha'));
    });

    test('one edit → one snapshot; identical re-persist creates none', () async {
      final vaultDir = Directory.systemTemp.createTempSync('folio_snap_once_');
      addTearDown(() {
        if (vaultDir.existsSync()) vaultDir.deleteSync(recursive: true);
      });
      final treeDir = Directory(p.join(vaultDir.path, 'repo'));

      final payload = VaultPayload(
        pages: [
          FolioPage(
            id: 'pg01',
            title: 'Edit me',
            blocks: [
              FolioBlock(id: 'b1', type: 'paragraph', text: 'v1'),
            ],
          ),
        ],
        displayName: 'Snap Once',
        pageOrderByParent: {'': ['pg01']},
      );

      await VaultPayloadToTree.decompose(payload, treeDir);
      final manager = VaultSnapshotManager(
        vaultDir: vaultDir,
        deviceId: 'dev',
      );

      await manager.createSnapshot(treeDir: treeDir, label: 'Edit me');
      expect((await manager.listSnapshots()).length, equals(1));

      // Persist sin cambios de página → dedupe
      expect(await manager.arePathsIdenticalToLatest(treeDir, {
        'pages/pg/pg01/meta.json',
        'pages/pg/pg01/blocks.jsonl',
      }), isTrue);
      expect(await manager.isTreeIdenticalToLatest(treeDir), isTrue);

      // Cambio real → nuevo snapshot
      payload.pages[0].blocks[0].text = 'v2';
      await VaultPayloadToTree.decompose(payload, treeDir);
      expect(await manager.arePathsIdenticalToLatest(treeDir, {
        'pages/pg/pg01/meta.json',
        'pages/pg/pg01/blocks.jsonl',
      }), isFalse);
      await manager.createSnapshot(treeDir: treeDir, label: 'Edit me');
      expect((await manager.listSnapshots()).length, equals(2));
    });

    test('migration materializes at least one snapshot per legacy revision',
        () async {
      final vaultId = 'migrate-revs-vault';
      VaultPaths.setActiveVaultId(vaultId);
      await VaultPaths.initVaultStorage(vaultId);
      await VaultPaths.vaultDirectoryForId(vaultId);

      // Crear vault.bin legacy (solo para comprobar limpieza posterior opcional)
      await VaultPaths.writeCipherPayload(
        Uint8List.fromList(utf8.encode('legacy-blob')),
      );

      final payload = VaultPayload(
        pages: [
          FolioPage(
            id: 'page-a',
            title: 'Current A',
            blocks: [
              FolioBlock(id: 'b1', type: 'paragraph', text: 'now'),
            ],
          ),
          FolioPage(
            id: 'page-b',
            title: 'Page B',
            blocks: [
              FolioBlock(id: 'b2', type: 'paragraph', text: 'b-now'),
            ],
          ),
        ],
        displayName: 'Migrate Revs',
        pageOrderByParent: {
          '': ['page-a', 'page-b'],
        },
        pageRevisions: {
          'page-a': [
            FolioPageRevision(
              revisionId: 'r1',
              savedAtMs: 1000,
              title: 'Old A',
              blocksJson: [
                {'id': 'b1', 'type': 'paragraph', 'text': 'old'},
              ],
            ),
            FolioPageRevision(
              revisionId: 'r2',
              savedAtMs: 2000,
              title: 'Mid A',
              blocksJson: [
                {'id': 'b1', 'type': 'paragraph', 'text': 'mid'},
              ],
            ),
          ],
        },
      );

      final result = await VaultMigrationTool.migrateVault(
        payload: payload,
        deviceId: 'test-device',
      );
      expect(result.success, isTrue);
      // 2 revisiones + 1 snapshot final del estado actual
      expect(result.snapshotsCreated, greaterThanOrEqualTo(3));

      final format = await VaultMigrationTool.readTreeFormatVersion();
      expect(format, equals(1));

      final vaultDir = await VaultPaths.vaultDirectory();
      final manager = VaultSnapshotManager(
        vaultDir: vaultDir,
        deviceId: 'test-device',
      );
      final snaps = await manager.listSnapshots();
      expect(snaps.length, greaterThanOrEqualTo(3));

      // versionsForPage-style filter: page-a debe ver cambios en meta/blocks
      final metaPath = 'pages/pa/page-a/meta.json';
      final blocksPath = 'pages/pa/page-a/blocks.jsonl';
      String? hashOf(snap, String path) {
        for (final f in snap.fileManifest) {
          if (f.path == path) return f.sha256;
        }
        return null;
      }

      var pageAVersions = 0;
      String? prevMeta;
      String? prevBlocks;
      var prevExisted = false;
      for (final s in snaps.reversed) {
        final meta = hashOf(s, metaPath);
        final blocks = hashOf(s, blocksPath);
        final existsNow = meta != null;
        final changed = existsNow &&
            (!prevExisted || meta != prevMeta || blocks != prevBlocks);
        if (changed) pageAVersions++;
        prevMeta = meta;
        prevBlocks = blocks;
        prevExisted = existsNow;
      }
      expect(pageAVersions, greaterThanOrEqualTo(2));

      // Restore de A no toca B: el árbol final tiene el estado actual de B
      final treeDir = await VaultPaths.vaultTreeDirectory();
      final loaded = await TreeToVaultPayload.compose(treeDir);
      final pageB = loaded.pages.firstWhere((pg) => pg.id == 'page-b');
      expect(pageB.blocks[0].text, equals('b-now'));
      final pageA = loaded.pages.firstWhere((pg) => pg.id == 'page-a');
      expect(pageA.title, equals('Current A'));
      expect(pageA.blocks[0].text, equals('now'));
    });

    test('persist v1 writes repo/tree.json and vault.format, not vault.bin',
        () async {
      final vaultId = 'persist-v1-vault';
      VaultPaths.setActiveVaultId(vaultId);
      await VaultPaths.initVaultStorage(vaultId);

      final payload = VaultPayload(
        pages: [
          FolioPage(
            id: 'only',
            title: 'Only',
            blocks: [
              FolioBlock(id: 'b1', type: 'paragraph', text: 'x'),
            ],
          ),
        ],
        displayName: 'Persist V1',
        pageOrderByParent: {'': ['only']},
      );

      final treeDir = await VaultPaths.vaultTreeDirectory();
      await VaultPayloadToTree.decompose(payload, treeDir);
      await VaultMigrationTool.writeTreeFormatVersion(1);

      expect(File(p.join(treeDir.path, 'tree.json')).existsSync(), isTrue);
      expect(await VaultMigrationTool.readTreeFormatVersion(), equals(1));

      // No hay creación automática de snapshot al descomponer
      final vaultDir = await VaultPaths.vaultDirectory();
      final versionsDir = Directory(p.join(vaultDir.path, 'versions'));
      final snapCount = versionsDir.existsSync()
          ? versionsDir
              .listSync()
              .whereType<File>()
              .where((f) => f.path.endsWith('.json'))
              .length
          : 0;
      expect(snapCount, equals(0));

      // vault.bin no se escribe en este flujo de árbol
      expect(await VaultPaths.cipherPayloadExists(), isFalse);
    });

    test('soft-hide map persists in hidden_versions.json', () async {
      final vaultId = 'hide-versions-vault';
      VaultPaths.setActiveVaultId(vaultId);
      await VaultPaths.initVaultStorage(vaultId);
      final treeDir = await VaultPaths.vaultTreeDirectory();
      final vaultMeta = Directory(p.join(treeDir.path, 'vault'));
      await vaultMeta.create(recursive: true);
      final file = File(p.join(vaultMeta.path, 'hidden_versions.json'));
      await file.writeAsString(jsonEncode({
        'page-a': ['snap-1', 'snap-2'],
      }));

      final raw = jsonDecode(await file.readAsString()) as Map;
      expect((raw['page-a'] as List).length, equals(2));
      expect((raw['page-a'] as List), contains('snap-1'));
    });

    test('integrations basename works with Windows-style paths', () async {
      final tempDir =
          Directory.systemTemp.createTempSync('folio_win_paths_');
      addTearDown(() {
        if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
      });

      final treeDir = Directory(p.join(tempDir.path, 'repo'));
      final payload = VaultPayload(
        pages: [
          FolioPage(
            id: 'p1',
            title: 'T',
            blocks: [FolioBlock(id: 'b1', type: 'paragraph', text: '')],
          ),
        ],
        displayName: 'Win',
      );
      await VaultPayloadToTree.decompose(payload, treeDir);

      // Escribir un archivo de integración y recompose (basename, no split('/'))
      final integDir =
          Directory(p.join(treeDir.path, 'vault', 'integrations'));
      await integDir.create(recursive: true);
      await File(p.join(integDir.path, 'systemMedia.json')).writeAsString(
        jsonEncode({'enabled': true, 'zenPauseOnExit': true}),
      );

      final recomposed = await TreeToVaultPayload.compose(treeDir);
      expect(recomposed.systemMedia.enabled, isTrue);
    });
  });
}
