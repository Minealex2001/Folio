/// Regresión: `VaultLocalStorage` debe serializar lecturas/escrituras del
/// árbol por libreta. Antes de este fix, una sesión activa (autosave/pull)
/// y el sync headless de la MISMA libreta podían tocar `repo/`/`repo.tmp` a
/// la vez sin ningún candado compartido — en producción esto produjo una
/// lectura a medio mover (`loadFromTreeAt` viendo 0 páginas mientras el
/// disco tenía 30) que disparó la guarda anti-vaciado innecesariamente. Ver
/// vault_local_storage.dart (`_vaultLocks`/`_withVaultLock`).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:folio/data/vault_local_storage.dart';
import 'package:folio/data/vault_payload.dart';
import 'package:folio/models/block.dart';
import 'package:folio/models/folio_page.dart';
import 'package:path/path.dart' as p;

List<FolioPage> _makePages(int count, String prefix) {
  return List.generate(
    count,
    (i) => FolioPage(
      id: '$prefix-page-$i',
      title: 'Página $prefix $i',
      blocks: [FolioBlock(id: '$prefix-block-$i', type: 'paragraph', text: 'x' * 200)],
    ),
  );
}

void main() {
  group('VaultLocalStorage per-vault lock', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('folio_local_storage_lock_test_');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test(
      'una lectura concurrente con una escritura sobre la misma libreta nunca ve el árbol a medio mover',
      () async {
        final vaultDir = Directory(p.join(tempDir.path, 'vaultA'))
          ..createSync(recursive: true);

        await VaultLocalStorage.decomposeAndStoreAt(
          vaultDir,
          VaultPayload(pages: _makePages(5, 'orig'), displayName: 'Orig'),
        );

        final results = await Future.wait([
          VaultLocalStorage.decomposeAndStoreAt(
            vaultDir,
            VaultPayload(pages: _makePages(10, 'nuevo'), displayName: 'Nuevo'),
          ).then((_) => -1),
          VaultLocalStorage.loadFromTreeAt(vaultDir).then((p) => p?.pages.length ?? -2),
        ]);

        final readResult = results[1];
        // El write no devuelve nada útil (mapeado a -1); solo nos importa
        // que la lectura concurrente haya visto un estado consistente:
        // o el árbol de antes (5) o el de después (10), nunca algo a medias.
        expect(readResult, anyOf(5, 10));
      },
    );

    test('libretas distintas no se serializan entre sí', () async {
      final dirBig = Directory(p.join(tempDir.path, 'vaultBig'))
        ..createSync(recursive: true);
      final dirSmall = Directory(p.join(tempDir.path, 'vaultSmall'))
        ..createSync(recursive: true);

      var bigDone = false;
      final bigFuture = VaultLocalStorage.decomposeAndStoreAt(
        dirBig,
        VaultPayload(pages: _makePages(300, 'big'), displayName: 'Big'),
      ).then((_) => bigDone = true);

      await VaultLocalStorage.decomposeAndStoreAt(
        dirSmall,
        VaultPayload(pages: _makePages(1, 'small'), displayName: 'Small'),
      );

      // Si compartieran candado, la escritura pequeña habría tenido que
      // esperar a que la libreta grande (300 páginas) terminase primero.
      expect(bigDone, isFalse);

      await bigFuture;
    });
  });
}
