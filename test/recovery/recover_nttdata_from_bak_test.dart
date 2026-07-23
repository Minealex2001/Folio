/// Dry-run / apply recovery for NTTData from vault.bin.bak.
///
/// ```powershell
/// $env:FOLIO_RECOVERY_PASSWORD = '...'
/// flutter test test/recovery/recover_nttdata_from_bak_test.dart
/// $env:FOLIO_RECOVERY_APPLY = '1'
/// flutter test test/recovery/recover_nttdata_from_bak_test.dart
/// ```
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:folio/crypto/vault_crypto.dart';
import 'package:folio/data/vault_payload.dart';
import 'package:folio/git/vault_payload_converters.dart';
import 'package:folio/git/vault_snapshot_manager.dart';
import 'package:folio/models/folio_page.dart';
import 'package:folio/models/folio_page_revision.dart';
import 'package:path/path.dart' as p;

const _kVaultId = '139c1239-06e3-44e4-8798-4cff54678366';

const _kPlainTypes = {
  'paragraph',
  'h1',
  'h2',
  'h3',
  'bullet',
  'numbered',
  'todo',
  'divider',
  'quote',
  'callout',
  'code',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('recover NTTData from vault.bin.bak', () async {
    final password = Platform.environment['FOLIO_RECOVERY_PASSWORD'] ?? '';
    final apply = Platform.environment['FOLIO_RECOVERY_APPLY'] == '1';
    expect(
      password,
      isNotEmpty,
      reason: 'Define FOLIO_RECOVERY_PASSWORD en el entorno',
    );

    final home = Platform.environment['APPDATA'] ?? '';
    final vaultDir = Directory(
      p.join(home, 'Folio', 'folio_vaults', _kVaultId),
    );
    final bakFile = File(p.join(vaultDir.path, 'vault.bin.bak'));
    final keysFile = File(p.join(vaultDir.path, 'vault.keys'));
    final repoDir = Directory(p.join(vaultDir.path, 'repo'));

    expect(bakFile.existsSync(), isTrue);
    expect(keysFile.existsSync(), isTrue);

    // ignore: avoid_print
    print('Descifrando bak (${bakFile.lengthSync()} bytes)...');
    final dekBytes = await VaultCrypto.unwrapDek(
      wrapped: await keysFile.readAsBytes(),
      password: password,
    );
    final dek = await VaultCrypto.dekFromBytes(dekBytes);
    final clear = await VaultCrypto.decryptPayload(
      blob: await bakFile.readAsBytes(),
      dek: dek,
    );
    final payload = VaultPayload.decodeUtf8(clear);

    // ignore: avoid_print
    print(
      'Payload bak: ${payload.pages.length} páginas, '
      'historial en ${payload.pageRevisions.length} páginas',
    );

    final bakTypes = <String, int>{};
    for (final page in payload.pages) {
      for (final b in page.blocks) {
        bakTypes[b.type] = (bakTypes[b.type] ?? 0) + 1;
      }
    }
    final sorted = bakTypes.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    // ignore: avoid_print
    print('Tipos en bak:');
    for (final e in sorted.take(25)) {
      // ignore: avoid_print
      print('  ${e.value.toString().padLeft(5)} ${e.key}');
    }

    for (final page in payload.pages) {
      final special = page.blocks.where((b) => !_kPlainTypes.contains(b.type));
      if (special.isEmpty) continue;
      final counts = <String, int>{};
      for (final b in special) {
        counts[b.type] = (counts[b.type] ?? 0) + 1;
      }
      // ignore: avoid_print
      print('  BAK "${page.title}": $counts');
    }

    if (repoDir.existsSync()) {
      final treePayload = await TreeToVaultPayload.compose(repoDir);
      // ignore: avoid_print
      print('Árbol actual: ${treePayload.pages.length} páginas');
      final treeById = {for (final pg in treePayload.pages) pg.id: pg};
      for (final page in payload.pages) {
        final cur = treeById[page.id];
        final bakN = page.blocks.length;
        final curN = cur?.blocks.length ?? -1;
        final bakKanban = page.blocks.where((b) => b.type == 'kanban').length;
        final curKanban =
            cur?.blocks.where((b) => b.type == 'kanban').length ?? 0;
        if (bakN != curN ||
            bakKanban != curKanban ||
            page.title != cur?.title) {
          // ignore: avoid_print
          print(
            'DIFF "${page.title}" bakBlocks=$bakN treeBlocks=$curN '
            'bakKanban=$bakKanban treeKanban=$curKanban '
            'treeTitle="${cur?.title ?? 'MISSING'}"',
          );
        }
      }
    }

    final liveIds = payload.pages.map((pg) => pg.id).toSet();
    var orphanSpecial = 0;
    for (final entry in payload.pageRevisions.entries) {
      if (liveIds.contains(entry.key) || entry.value.isEmpty) continue;
      final latest = (List<FolioPageRevision>.of(entry.value)
            ..sort((a, b) => b.savedAtMs.compareTo(a.savedAtMs)))
          .first;
      final hasSpecial = latest.blocksJson.any((m) {
        final t = m['type'] as String? ?? '';
        return !_kPlainTypes.contains(t);
      });
      if (!hasSpecial) continue;
      orphanSpecial++;
      // ignore: avoid_print
      print(
        'ORPHAN REV title="${latest.title}" revs=${entry.value.length}',
      );
    }
    // ignore: avoid_print
    print('Huérfanas con especiales en historial: $orphanSpecial');

    if (!apply) {
      // ignore: avoid_print
      print('Dry-run OK. FOLIO_RECOVERY_APPLY=1 para restaurar.');
      return;
    }

    final stamp = DateTime.now()
        .toUtc()
        .toIso8601String()
        .replaceAll(':', '')
        .replaceAll('.', '');

    if (repoDir.existsSync()) {
      final backupRepo = Directory(
        p.join(vaultDir.path, 'repo.before-recovery-$stamp'),
      );
      await repoDir.rename(backupRepo.path);
      // ignore: avoid_print
      print('Árbol anterior → ${backupRepo.path}');
    }
    final versionsDir = Directory(p.join(vaultDir.path, 'versions'));
    if (versionsDir.existsSync()) {
      final backupVersions = Directory(
        p.join(vaultDir.path, 'versions.before-recovery-$stamp'),
      );
      await versionsDir.rename(backupVersions.path);
      // ignore: avoid_print
      print('Snapshots anteriores → ${backupVersions.path}');
    }

    await repoDir.create(recursive: true);
    await VaultPayloadToTree.decompose(payload, repoDir);

    final snapMgr = VaultSnapshotManager(
      vaultDir: vaultDir,
      deviceId: 'recovery-tool',
    );
    await snapMgr.init();

    var snaps = 0;
    String? parentId;
    final pagesById = {for (final page in payload.pages) page.id: page};

    for (final entry in payload.pageRevisions.entries) {
      final current = pagesById[entry.key];
      if (current == null) continue;
      final revisions = List<FolioPageRevision>.of(entry.value)
        ..sort((a, b) => a.savedAtMs.compareTo(b.savedAtMs));
      for (final rev in revisions) {
        final pageAtRev = FolioPage(
          id: current.id,
          title: rev.title,
          emoji: current.emoji,
          parentId: current.parentId,
          isFolder: current.isFolder,
          trashedAt: current.trashedAt,
          collabRoomId: current.collabRoomId,
          lastImportInfo: current.lastImportInfo,
          blocks: rev.decodeBlocks(),
          properties: List.of(current.properties),
          tags: List.of(current.tags),
        );
        await VaultPayloadToTree.writePageFiles(repoDir, pageAtRev);
        final snap = await snapMgr.createSnapshot(
          treeDir: repoDir,
          label: rev.title.isNotEmpty ? rev.title : null,
          parentSnapshotId: parentId,
        );
        parentId = snap.snapshotId;
        snaps++;
      }
    }

    for (final entry in payload.pageRevisions.entries) {
      if (pagesById.containsKey(entry.key) || entry.value.isEmpty) continue;
      final revisions = List<FolioPageRevision>.of(entry.value)
        ..sort((a, b) => a.savedAtMs.compareTo(b.savedAtMs));
      final last = revisions.last;
      final orphan = FolioPage(
        id: entry.key,
        title: last.title.isNotEmpty ? last.title : 'Recovered page',
        blocks: last.decodeBlocks(),
      );
      final hasSpecial =
          orphan.blocks.any((b) => !_kPlainTypes.contains(b.type));
      if (!hasSpecial && orphan.blocks.length <= 1) continue;

      for (final rev in revisions) {
        final pageAtRev = FolioPage(
          id: entry.key,
          title: rev.title,
          blocks: rev.decodeBlocks(),
        );
        await VaultPayloadToTree.writePageFiles(repoDir, pageAtRev);
        final snap = await snapMgr.createSnapshot(
          treeDir: repoDir,
          label: rev.title.isNotEmpty ? rev.title : null,
          parentSnapshotId: parentId,
        );
        parentId = snap.snapshotId;
        snaps++;
      }
      await VaultPayloadToTree.writePageFiles(repoDir, orphan);
      // ignore: avoid_print
      print('Restaurada página huérfana: ${orphan.title}');
    }

    await VaultPayloadToTree.decompose(payload, repoDir);
    await snapMgr.createSnapshot(
      treeDir: repoDir,
      label: 'Recovery from vault.bin.bak',
      parentSnapshotId: parentId,
    );
    snaps++;
    // No usar writeTreeFormatVersion(): requiere libreta activa en VaultPaths.
    final formatFile = File(p.join(vaultDir.path, 'vault.format'));
    await formatFile.writeAsString('1', flush: true);
    // ignore: avoid_print
    print('Listo. Snapshots creados: $snaps');

    final verify = await TreeToVaultPayload.compose(repoDir);
    // ignore: avoid_print
    print('Verificación compose: ${verify.pages.length} páginas');
    final tareas = verify.pages.where((pg) => pg.title == 'Tareas').toList();
    expect(verify.pages.length, greaterThan(0));
    expect(tareas, isNotEmpty);
    expect(tareas.first.blocks.any((b) => b.type == 'kanban'), isTrue);
  }, timeout: const Timeout(Duration(minutes: 30)));
}
