/// Regresión: applyImportToVaultRoot (restaurar backup ZIP) debía invalidar
/// el árbol v1 existente y escribir de forma atómica. Antes del fix, si la
/// libreta destino ya estaba migrada a v1 (`repo/` + `vault.format=1`),
/// restaurar un backup escribía un `vault.bin` nuevo que el siguiente
/// `bootstrap()` ignoraba en silencio — el marker seguía diciendo v1 y el
/// árbol viejo (sin tocar) seguía siendo lo que se cargaba. El restore
/// parecía funcionar (no había error) pero no tenía ningún efecto visible.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:folio/data/vault_backup.dart';
import 'package:folio/data/vault_local_storage.dart';
import 'package:folio/data/vault_payload.dart';
import 'package:folio/git/vault_payload_converters.dart';
import 'package:folio/models/block.dart';
import 'package:folio/models/folio_page.dart';
import 'package:path/path.dart' as p;

void main() {
  group('applyImportToVaultRoot', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('folio_import_test_');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test(
      'imported vault.bin actually takes effect on a vault already migrated to v1',
      () async {
        final vaultRoot = Directory(p.join(tempDir.path, 'vault'));
        await vaultRoot.create(recursive: true);

        // Libreta destino: ya migrada a v1, con contenido "viejo".
        final oldTreeDir = Directory(p.join(vaultRoot.path, 'repo'));
        await VaultPayloadToTree.decompose(
          VaultPayload(
            pages: [
              FolioPage(
                id: 'old-page',
                title: 'Viejo',
                blocks: [
                  FolioBlock(id: 'b1', type: 'paragraph', text: 'old'),
                ],
              ),
            ],
          ),
          oldTreeDir,
        );
        await File(
          p.join(vaultRoot.path, 'vault.format'),
        ).writeAsString('1', flush: true);

        // Copia a importar: libreta distinta, en claro.
        final extractedDir = Directory(p.join(tempDir.path, 'extracted'));
        await extractedDir.create(recursive: true);
        final importedPayload = VaultPayload(
          pages: [
            FolioPage(
              id: 'imported-page',
              title: 'Restaurada',
              blocks: [
                FolioBlock(id: 'b2', type: 'paragraph', text: 'restored'),
              ],
            ),
          ],
        );
        await File(
          p.join(extractedDir.path, 'vault.bin'),
        ).writeAsBytes(importedPayload.encodeUtf8(), flush: true);
        await File(
          p.join(extractedDir.path, 'vault.mode'),
        ).writeAsString('plain', flush: true);

        await applyImportToVaultRoot(extractedDir, vaultRoot);

        // vault.bin ahora contiene el contenido importado.
        final binBytes = await File(
          p.join(vaultRoot.path, 'vault.bin'),
        ).readAsBytes();
        final decoded = VaultPayload.decodeUtf8(binBytes);
        expect(decoded.pages.single.id, 'imported-page');

        // El marker v1 y el árbol viejo ya no están vigentes: el próximo
        // bootstrap debe tratar esto como v0 y migrar desde el vault.bin
        // recién importado, no seguir usando el árbol de antes.
        expect(File(p.join(vaultRoot.path, 'vault.format')).existsSync(), isFalse);
        expect(oldTreeDir.existsSync(), isFalse);
        expect(
          Directory(p.join(vaultRoot.path, 'repo.pre-import')).existsSync(),
          isTrue,
        );

        // El árbol viejo se conservó (renombrado), no se borró.
        final preservedTree = await VaultLocalStorage.loadFromTreeDir(
          Directory(p.join(vaultRoot.path, 'repo.pre-import')),
        );
        expect(preservedTree!.pages.single.id, 'old-page');
      },
    );
  });
}
