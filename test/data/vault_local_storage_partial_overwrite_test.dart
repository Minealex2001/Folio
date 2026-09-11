/// Regresión: la sincronización con Folio Cloud podía sustituir una libreta
/// completa por un manifiesto parcial (p. ej. 59 páginas -> 1), sin que
/// ningún guard de disco lo detectara — el único guard existente
/// (`allowEmptyOverwrite`) solo cubría el caso de payload totalmente vacío.
/// Este test cubre el nuevo guard `guardAgainstPartialOverwrite`, la última
/// red de seguridad antes de escribir en disco. Ver vault_local_storage.dart.
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
      blocks: [FolioBlock(id: '$prefix-block-$i', type: 'paragraph', text: 'x')],
    ),
  );
}

void main() {
  group('VaultLocalStorage.decomposeAndStoreAt guardAgainstPartialOverwrite', () {
    late Directory tempDir;
    late Directory vaultDir;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('folio_partial_overwrite_test_');
      vaultDir = Directory(p.join(tempDir.path, 'vault'))..createSync(recursive: true);
      await VaultLocalStorage.decomposeAndStoreAt(
        vaultDir,
        VaultPayload(pages: _makePages(59, 'orig'), displayName: 'Orig'),
      );
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('rechaza un payload que colapsó de 59 a 1 página cuando el guard está activo', () async {
      expect(
        () => VaultLocalStorage.decomposeAndStoreAt(
          vaultDir,
          VaultPayload(pages: _makePages(1, 'partial'), displayName: 'Orig'),
          guardAgainstPartialOverwrite: true,
        ),
        throwsA(isA<VaultEmptyOverwriteException>()),
      );

      // El árbol en disco no debe haberse tocado: las 59 páginas siguen ahí.
      final onDisk = await VaultLocalStorage.loadFromTreeAt(vaultDir);
      expect(onDisk!.pages.length, 59);
    });

    test('permite el mismo payload parcial cuando el guard está desactivado (comportamiento previo)', () async {
      await VaultLocalStorage.decomposeAndStoreAt(
        vaultDir,
        VaultPayload(pages: _makePages(1, 'partial'), displayName: 'Orig'),
      );

      final onDisk = await VaultLocalStorage.loadFromTreeAt(vaultDir);
      expect(onDisk!.pages.length, 1);
    });

    test('permite una caída gradual legítima (borrado real) aunque el guard esté activo', () async {
      await VaultLocalStorage.decomposeAndStoreAt(
        vaultDir,
        VaultPayload(pages: _makePages(40, 'partial'), displayName: 'Orig'),
        guardAgainstPartialOverwrite: true,
      );

      final onDisk = await VaultLocalStorage.loadFromTreeAt(vaultDir);
      expect(onDisk!.pages.length, 40);
    });

    test('no aplica la heurística de % en libretas pequeñas', () async {
      final smallDir = Directory(p.join(tempDir.path, 'vaultSmall'))
        ..createSync(recursive: true);
      await VaultLocalStorage.decomposeAndStoreAt(
        smallDir,
        VaultPayload(pages: _makePages(3, 'orig'), displayName: 'Small'),
      );

      // De 3 a 1 página cruzaría el 40%, pero el mínimo de 4 páginas
      // existentes no se alcanza: no debe bloquear.
      await VaultLocalStorage.decomposeAndStoreAt(
        smallDir,
        VaultPayload(pages: _makePages(1, 'small'), displayName: 'Small'),
        guardAgainstPartialOverwrite: true,
      );

      final onDisk = await VaultLocalStorage.loadFromTreeAt(smallDir);
      expect(onDisk!.pages.length, 1);
    });
  });
}
