import 'package:flutter_test/flutter_test.dart';
import 'package:folio/models/block.dart';
import 'package:folio/services/ai/quill_tools.dart';
import 'package:folio/session/vault_session.dart';

void main() {
  test('insertBilingualTranslations inserta de abajo a arriba', () {
    final session = VaultSession();
    session.addPage(parentId: null);
    final pageId = session.selectedPage!.id;
    final b0 = session.selectedPage!.blocks.first.id;
    session.updateBlockText(pageId, b0, 'Primero');

    session.insertBlockAfter(
      pageId: pageId,
      afterBlockId: b0,
      block: FolioBlock(id: '${pageId}_mid', type: 'paragraph', text: 'Segundo'),
    );
    session.insertBlockAfter(
      pageId: pageId,
      afterBlockId: '${pageId}_mid',
      block: FolioBlock(id: '${pageId}_last', type: 'h1', text: 'Titulo'),
    );

    final inserted = QuillToolExecutor.insertBilingualTranslations(
      session,
      pageId: pageId,
      translations: [
        BilingualBlockTranslation(blockId: '${pageId}_mid', text: 'Second'),
        BilingualBlockTranslation(blockId: '${pageId}_last', text: 'Title'),
      ],
    );
    expect(inserted, 2);

    final page = session.pages.firstWhere((p) => p.id == pageId);
    expect(page.blocks.length, greaterThanOrEqualTo(4));
    final midIdx = page.blocks.indexWhere((b) => b.id == '${pageId}_mid');
    expect(midIdx, greaterThanOrEqualTo(0));
    expect(page.blocks[midIdx + 1].text, 'Second');
    expect(page.blocks[midIdx + 1].type, 'paragraph');
    final lastIdx = page.blocks.indexWhere((b) => b.id == '${pageId}_last');
    expect(lastIdx, greaterThan(midIdx));
    expect(page.blocks[lastIdx + 1].text, 'Title');
    expect(page.blocks[lastIdx + 1].type, 'h1');
  });

  test('QuillToolCall execute dispatches translatePageBilingual', () {
    final session = VaultSession();
    session.addPage(parentId: null);
    final pageId = session.selectedPage!.id;
    final blockId = session.selectedPage!.blocks.first.id;
    session.updateBlockText(pageId, blockId, 'Hola');

    QuillToolExecutor.execute(
      session,
      QuillToolCall(
        kind: QuillToolKind.translatePageBilingual,
        pageId: pageId,
        bilingualTranslations: const [
          BilingualBlockTranslation(blockId: 'missing', text: 'X'),
        ],
      ),
    );
    final page = session.pages.firstWhere((p) => p.id == pageId);
    expect(page.blocks.length, 1);

    QuillToolExecutor.execute(
      session,
      QuillToolCall(
        kind: QuillToolKind.translatePageBilingual,
        pageId: pageId,
        bilingualTranslations: [
          BilingualBlockTranslation(blockId: blockId, text: 'Hello'),
        ],
      ),
    );
    final page2 = session.pages.firstWhere((p) => p.id == pageId);
    expect(page2.blocks.length, 2);
    expect(page2.blocks[1].text, 'Hello');
    expect(page2.blocks[1].type, 'paragraph');
  });
}
