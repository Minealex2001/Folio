/// Recuperación offline de la libreta NTTData desde `vault.bin.bak`.
///
/// **No uses `dart run`**: Folio depende de Flutter y falla con errores de
/// `Offset` / `PointerDeviceKind`. Usa el test:
///
/// ```powershell
/// $env:FOLIO_RECOVERY_PASSWORD = 'TU_CLAVE'
/// flutter test test/recovery/recover_nttdata_from_bak_test.dart --reporter expanded
/// # Si el dry-run está bien:
/// $env:FOLIO_RECOVERY_APPLY = '1'
/// flutter test test/recovery/recover_nttdata_from_bak_test.dart --reporter expanded
/// ```
library;

import 'dart:io';

import 'package:folio/crypto/vault_crypto.dart';
import 'package:folio/data/vault_payload.dart';
import 'package:folio/git/vault_migration_tool.dart';
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

Future<void> main(List<String> args) async {
  final password = _arg(args, 'password');
  final apply = args.contains('--apply');
  if (password == null || password.isEmpty) {
    stderr.writeln(
      'Uso: dart run tool/recover_nttdata_from_bak.dart '
      '--password=... [--apply]',
    );
    exit(64);
  }

  final home = Platform.environment['APPDATA'] ?? '';
  final vaultDir = Directory(p.join(home, 'Folio', 'folio_vaults', _kVaultId));
  final bakFile = File(p.join(vaultDir.path, 'vault.bin.bak'));
  final keysFile = File(p.join(vaultDir.path, 'vault.keys'));
  final repoDir = Directory(p.join(vaultDir.path, 'repo'));

  if (!bakFile.existsSync() || !keysFile.existsSync()) {
    stderr.writeln('Falta vault.bin.bak o vault.keys en ${vaultDir.path}');
    exit(1);
  }

  stdout.writeln('Descifrando bak (${bakFile.lengthSync()} bytes)...');
  late final List<int> dekBytes;
  try {
    dekBytes = await VaultCrypto.unwrapDek(
      wrapped: await keysFile.readAsBytes(),
      password: password,
    );
  } catch (e) {
    stderr.writeln('Contraseña incorrecta o vault.keys ilegible: $e');
    exit(2);
  }

  final dek = await VaultCrypto.dekFromBytes(dekBytes);
  final clear = await VaultCrypto.decryptPayload(
    blob: await bakFile.readAsBytes(),
    dek: dek,
  );
  final payload = VaultPayload.decodeUtf8(clear);

  stdout.writeln(
    'Payload bak: ${payload.pages.length} páginas, '
    'historial en ${payload.pageRevisions.length} páginas',
  );

  final bakTypes = <String, int>{};
  for (final page in payload.pages) {
    for (final b in page.blocks) {
      bakTypes[b.type] = (bakTypes[b.type] ?? 0) + 1;
    }
  }
  stdout.writeln('Tipos en bak (contenido actual de páginas):');
  final sorted = bakTypes.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  for (final e in sorted.take(25)) {
    stdout.writeln('  ${e.value.toString().padLeft(5)} ${e.key}');
  }

  for (final page in payload.pages) {
    final special = page.blocks.where((b) => !_kPlainTypes.contains(b.type));
    if (special.isEmpty) continue;
    final counts = <String, int>{};
    for (final b in special) {
      counts[b.type] = (counts[b.type] ?? 0) + 1;
    }
    stdout.writeln(
      '  BAK "${page.title}" (${page.id.substring(0, 8)}…): $counts',
    );
  }

  if (repoDir.existsSync()) {
    final treePayload = await TreeToVaultPayload.compose(repoDir);
    stdout.writeln('\nÁrbol actual: ${treePayload.pages.length} páginas');
    final treeById = {for (final pg in treePayload.pages) pg.id: pg};
    for (final page in payload.pages) {
      final cur = treeById[page.id];
      final bakN = page.blocks.length;
      final curN = cur?.blocks.length ?? -1;
      final bakKanban = page.blocks.where((b) => b.type == 'kanban').length;
      final curKanban =
          cur?.blocks.where((b) => b.type == 'kanban').length ?? 0;
      if (bakN != curN || bakKanban != curKanban || page.title != cur?.title) {
        stdout.writeln(
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
    stdout.writeln(
      'ORPHAN REV ${entry.key.substring(0, 8)}… '
      'title="${latest.title}" revs=${entry.value.length}',
    );
  }
  stdout.writeln(
    'Páginas borradas con bloques especiales aún en historial: '
    '$orphanSpecial',
  );

  if (!apply) {
    stdout.writeln(
      '\nDry-run. Con --apply se restaura repo/ desde el bak y se '
      'regeneran snapshots (el árbol actual se renombra, no se borra).',
    );
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
    stdout.writeln('Árbol anterior → ${backupRepo.path}');
  }
  final versionsDir = Directory(p.join(vaultDir.path, 'versions'));
  if (versionsDir.existsSync()) {
    final backupVersions = Directory(
      p.join(vaultDir.path, 'versions.before-recovery-$stamp'),
    );
    await versionsDir.rename(backupVersions.path);
    stdout.writeln('Snapshots anteriores → ${backupVersions.path}');
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

  // Páginas eliminadas que solo existen en revisiones → se recuperan
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

    await VaultPayloadToTree.writePageFiles(repoDir, orphan);
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
    // Dejar la última revisión como contenido vivo
    await VaultPayloadToTree.writePageFiles(repoDir, orphan);
    stdout.writeln('Restaurada página huérfana: ${orphan.title}');
  }

  await VaultPayloadToTree.decompose(payload, repoDir);
  await snapMgr.createSnapshot(
    treeDir: repoDir,
    label: 'Recovery from vault.bin.bak',
    parentSnapshotId: parentId,
  );
  snaps++;

  await VaultMigrationTool.writeTreeFormatVersion(1);
  stdout.writeln('Listo. Snapshots creados: $snaps');
  stdout.writeln('Abre Folio, desbloquea NTTData y revisa Tareas / kanban.');
}

String? _arg(List<String> args, String name) {
  final prefix = '--$name=';
  for (final a in args) {
    if (a.startsWith(prefix)) return a.substring(prefix.length);
  }
  return null;
}
