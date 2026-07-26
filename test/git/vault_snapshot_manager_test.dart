/// Cobertura del motor de snapshots usado como baseline persistido del sync
/// por página: encadenado automático (`parentSnapshotId`), detección de
/// páginas cambiadas sin tocar la red (`changedPageIds`), y reconstrucción
/// de un payload completo a partir de un snapshot antiguo (`loadPayload`)
/// sin mutar el árbol en vivo.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:folio/data/vault_local_storage.dart';
import 'package:folio/data/vault_payload.dart';
import 'package:folio/git/vault_snapshot_manager.dart';
import 'package:folio/models/block.dart';
import 'package:folio/models/folio_page.dart';
import 'package:path/path.dart' as p;

FolioPage _page(String id, {String title = 'Page', String text = 'hello'}) {
  return FolioPage(
    id: id,
    title: title,
    blocks: [FolioBlock(id: '${id}_b0', type: 'paragraph', text: text)],
  );
}

void main() {
  group('VaultSnapshotManager', () {
    late Directory vaultDir;
    late Directory treeDir;

    setUp(() async {
      final tempDir = Directory.systemTemp.createTempSync(
        'folio_snapshot_manager_test_',
      );
      vaultDir = Directory(p.join(tempDir.path, 'vault'))
        ..createSync(recursive: true);
      treeDir = Directory(p.join(vaultDir.path, 'repo'));
    });

    tearDown(() {
      final parent = vaultDir.parent;
      if (parent.existsSync()) {
        parent.deleteSync(recursive: true);
      }
    });

    test('createSnapshot encadena automáticamente al más reciente', () async {
      await VaultLocalStorage.decomposeAndStoreAt(
        vaultDir,
        VaultPayload(pages: [_page('a')]),
      );
      final manager = VaultSnapshotManager(
        vaultDir: vaultDir,
        deviceId: 'device-1',
      );

      final first = await manager.createSnapshot(treeDir: treeDir);
      expect(first.parentSnapshotId, isNull);

      final second = await manager.createSnapshot(treeDir: treeDir);
      expect(second.parentSnapshotId, first.snapshotId);

      final third = await manager.createSnapshot(treeDir: treeDir);
      expect(third.parentSnapshotId, second.snapshotId);
    });

    test(
      'changedPageIds detecta solo las páginas realmente mutadas',
      () async {
        await VaultLocalStorage.decomposeAndStoreAt(
          vaultDir,
          VaultPayload(
            pages: [_page('a'), _page('b'), _page('c')],
          ),
        );
        final manager = VaultSnapshotManager(
          vaultDir: vaultDir,
          deviceId: 'device-1',
        );
        final baseline = await manager.createSnapshot(treeDir: treeDir);

        // Solo se muta 'b' (título distinto); 'a' y 'c' quedan igual.
        await VaultLocalStorage.decomposeAndStoreAt(
          vaultDir,
          VaultPayload(
            pages: [_page('a'), _page('b', title: 'B editada'), _page('c')],
          ),
        );

        final changed = await manager.changedPageIds(treeDir, baseline);
        expect(changed.pageIds, {'b'});
        expect(changed.restChanged, isFalse);
      },
    );

    test(
      'changedPageIds detecta cambios fuera de pages/ (resto de la libreta)',
      () async {
        await VaultLocalStorage.decomposeAndStoreAt(
          vaultDir,
          VaultPayload(pages: [_page('a')], displayName: 'Original'),
        );
        final manager = VaultSnapshotManager(
          vaultDir: vaultDir,
          deviceId: 'device-1',
        );
        final baseline = await manager.createSnapshot(treeDir: treeDir);

        await VaultLocalStorage.decomposeAndStoreAt(
          vaultDir,
          VaultPayload(pages: [_page('a')], displayName: 'Renombrada'),
        );

        final changed = await manager.changedPageIds(treeDir, baseline);
        expect(changed.pageIds, isEmpty);
        expect(changed.restChanged, isTrue);
      },
    );

    test(
      'loadPayload reconstruye un snapshot antiguo sin tocar el árbol en vivo',
      () async {
        await VaultLocalStorage.decomposeAndStoreAt(
          vaultDir,
          VaultPayload(pages: [_page('a', title: 'Original')]),
        );
        final manager = VaultSnapshotManager(
          vaultDir: vaultDir,
          deviceId: 'device-1',
        );
        final snapshot = await manager.createSnapshot(treeDir: treeDir);

        // Mutar el árbol EN VIVO después de tomar el snapshot.
        await VaultLocalStorage.decomposeAndStoreAt(
          vaultDir,
          VaultPayload(pages: [_page('a', title: 'Mutada después')]),
        );

        final restored = await manager.loadPayload(snapshot.snapshotId);
        expect(restored, isNotNull);
        expect(restored!.pages.single.title, 'Original');

        // El árbol en vivo no debe haberse alterado por loadPayload.
        final live = await VaultLocalStorage.loadFromTreeAt(vaultDir);
        expect(live!.pages.single.title, 'Mutada después');
      },
    );
  });
}
