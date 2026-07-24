/// Round-trip de las funciones que parten un VaultPayload en "resto de
/// libreta" + un slice por página (usadas por el manifiesto v3 de device-sync
/// para subir cada página como su propio blob, en vez de todo el payload en
/// un único JSON). Esta es la parte del cambio que no depende de Firebase y
/// donde más fácil sería perder un campo por descuido (p. ej. comentarios
/// huérfanos, displayName, tombstones) — justo lo que causó el bug original.
import 'package:flutter_test/flutter_test.dart';
import 'package:folio/data/vault_payload.dart';
import 'package:folio/models/block.dart';
import 'package:folio/models/folio_page.dart';
import 'package:folio/models/local_collab.dart';

void main() {
  group('VaultPayload page slice / rest round-trip', () {
    test('reconstruye un payload con varias páginas y comentarios sin pérdidas', () {
      final pageA = FolioPage(
        id: 'pA',
        title: 'Página A',
        blocks: [FolioBlock(id: 'bA1', type: 'paragraph', text: 'hola')],
      );
      final pageB = FolioPage(
        id: 'pB',
        title: 'Página B',
        parentId: 'pA',
        blocks: [FolioBlock(id: 'bB1', type: 'paragraph', text: 'mundo')],
      );
      final commentOnA = LocalPageComment(
        id: 'c1',
        pageId: 'pA',
        authorProfileId: 'me',
        text: 'comentario en A',
        createdAtMs: 1000,
      );
      // Comentario huérfano: su página ya no existe en `pages`.
      final orphanComment = LocalPageComment(
        id: 'c2',
        pageId: 'pDeleted',
        authorProfileId: 'me',
        text: 'comentario huérfano',
        createdAtMs: 2000,
      );

      final original = VaultPayload(
        pages: [pageA, pageB],
        displayName: 'Mi libreta',
        pageOrderByParent: {
          '': ['pA'],
          'pA': ['pB'],
        },
        pageTombstones: {'pOldDeleted': 12345},
        comments: [commentOnA, orphanComment],
        syncClock: 7,
      );

      final restJson = original.restJsonExcludingPages();
      expect(restJson.containsKey('pages'), isFalse);

      final pageSlices = original.pages
          .map((p) => VaultPayload.pageSliceJson(p, original.comments))
          .toList();

      // Cada slice trae solo los comentarios de su propia página.
      expect((pageSlices[0]['comments'] as List), hasLength(1));
      expect((pageSlices[1]['comments'] as List), isEmpty);

      final mergedJson = VaultPayload.mergeRestAndPageSlices(
        restJson,
        pageSlices,
      );
      final reconstructed = VaultPayload.fromJson(mergedJson);

      expect(reconstructed.pages.map((p) => p.id).toSet(), {'pA', 'pB'});
      expect(
        reconstructed.pages.firstWhere((p) => p.id == 'pB').parentId,
        'pA',
      );
      expect(reconstructed.displayName, 'Mi libreta');
      expect(reconstructed.pageOrderByParent, original.pageOrderByParent);
      expect(reconstructed.pageTombstones, original.pageTombstones);
      expect(reconstructed.syncClock, 7);
      // El comentario huérfano no se pierde: vuelve por el blob "resto".
      expect(
        reconstructed.comments.map((c) => c.id).toSet(),
        {'c1', 'c2'},
      );
    });

    test('payload vacío hace round-trip sin páginas ni comentarios', () {
      final original = VaultPayload(pages: const []);
      final restJson = original.restJsonExcludingPages();
      final mergedJson = VaultPayload.mergeRestAndPageSlices(restJson, const []);
      final reconstructed = VaultPayload.fromJson(mergedJson);
      expect(reconstructed.pages, isEmpty);
      expect(reconstructed.comments, isEmpty);
    });
  });
}
