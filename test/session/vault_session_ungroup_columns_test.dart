import 'package:flutter_test/flutter_test.dart';
import 'package:folio/models/block.dart';
import 'package:folio/models/folio_columns_data.dart';
import 'package:folio/session/vault_session.dart';

/// "Desagrupar" — pedido explícitamente por el usuario junto con "Agrupar"
/// (Fases E1-E3). `ungroupColumnsBlock` deshace un bloque `column_list`
/// sustituyéndolo por los bloques planos de sus columnas, en orden.
void main() {
  test('sustituye el column_list por los bloques de sus columnas, en orden', () {
    final session = VaultSession();
    session.addPage();
    final pageId = session.selectedPageId!;
    final b0 = session.selectedPage!.blocks.first.id;

    final columnsData = FolioColumnsData(
      columns: [
        FolioColumnData(
          blocks: [FolioBlock(id: 'c1', type: 'paragraph', text: 'uno')],
        ),
        FolioColumnData(
          blocks: [FolioBlock(id: 'c2', type: 'paragraph', text: 'dos')],
        ),
      ],
    );
    session.insertBlockAfter(
      pageId: pageId,
      afterBlockId: b0,
      block: FolioBlock(
        id: 'cols',
        type: 'column_list',
        text: columnsData.encode(),
      ),
    );

    final ok = session.ungroupColumnsBlock(pageId, 'cols');

    expect(ok, isTrue);
    final blocks = session.selectedPage!.blocks;
    expect(blocks.any((b) => b.id == 'cols'), isFalse);
    final ids = blocks.map((b) => b.id).toList();
    expect(ids.indexOf('c1'), lessThan(ids.indexOf('c2')));
    expect(blocks.firstWhere((b) => b.id == 'c1').text, 'uno');
    expect(blocks.firstWhere((b) => b.id == 'c2').text, 'dos');
  });

  test('no-op sobre un bloque que no es column_list', () {
    final session = VaultSession();
    session.addPage();
    final pageId = session.selectedPageId!;
    final b0 = session.selectedPage!.blocks.first.id;

    final ok = session.ungroupColumnsBlock(pageId, b0);

    expect(ok, isFalse);
    expect(session.selectedPage!.blocks.length, 1);
  });

  test('no-op sobre un id inexistente', () {
    final session = VaultSession();
    session.addPage();
    final pageId = session.selectedPageId!;

    final ok = session.ungroupColumnsBlock(pageId, 'missing');

    expect(ok, isFalse);
  });
}
