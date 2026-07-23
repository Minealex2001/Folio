/// Regresión: applySyncSnapshotBytes no debe vaciar la libreta en memoria
/// cuando el pack remoto llega con 0 páginas (mismo riesgo de wipe por sync
/// que ya se había corregido en el camino headless, pero por la ruta de
/// sesión desbloqueada / P2P, que no tenía este guard).
import 'package:flutter_test/flutter_test.dart';
import 'package:folio/data/vault_payload.dart';
import 'package:folio/services/sync/vault_sync_pack.dart';
import 'package:folio/session/vault_session.dart';

void main() {
  group('VaultSession.applySyncSnapshotBytes anti-wipe guard', () {
    test('refuses an empty remote pack when local has pages', () async {
      final session = VaultSession();
      session.debugMarkUnlockedForTests();
      session.addPage(parentId: null);
      final pageId = session.selectedPage!.id;
      session.updateBlockText(
        pageId,
        session.selectedPage!.blocks.first.id,
        'Contenido local importante',
      );

      expect(session.pages, hasLength(1));

      final emptyPack = VaultSyncPack(
        payload: VaultPayload(pages: const []),
        attachments: const [],
      );
      final result = await session.applySyncSnapshotBytes(
        emptyPack.encodeUtf8(),
      );

      expect(result.ok, isTrue);
      expect(result.changed, isFalse);
      expect(session.pages, hasLength(1));
      expect(
        session.pages.first.blocks.first.text,
        'Contenido local importante',
      );
    });
  });
}
