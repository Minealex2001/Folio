import 'package:folio/models/block.dart';
import 'package:folio/models/folio_page.dart';
import 'package:folio/services/folio_cloud/folio_cloud_vault_share.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('view pack incluye rich text y se hidrata a FolioPage', () {
    final page = FolioPage(
      id: 'p1',
      title: 'Hola',
      emoji: '📘',
      blocks: [
        FolioBlock(
          id: 'b1',
          type: 'paragraph',
          text: 'mundo',
          richTextDeltaJson: '[{"insert":"mundo\\n"}]',
        ),
      ],
    );
    final pack = buildVaultPublicViewPack(
      vaultId: 'v1',
      displayName: 'Demo',
      pages: [page],
    );
    final blocks = (pack['pages'] as List).first as Map;
    final b0 = (blocks['blocks'] as List).first as Map;
    expect(b0['richTextDeltaJson'], isNotNull);

    final hydrated = hydrateVaultPublicViewPages(pack);
    expect(hydrated, hasLength(1));
    expect(hydrated.first.blocks.first.richTextDeltaJson, isNotNull);
  });

  test('view pack omite urls locales de adjuntos', () {
    final page = FolioPage(
      id: 'p1',
      title: 'Img',
      blocks: [
        FolioBlock(
          id: 'b1',
          type: 'image',
          text: '',
          url: 'attachments/foo.png',
        ),
        FolioBlock(
          id: 'b2',
          type: 'image',
          text: '',
          url: 'https://cdn.example/a.png',
        ),
      ],
    );
    final pack = buildVaultPublicViewPack(
      vaultId: 'v1',
      displayName: 'Demo',
      pages: [page],
    );
    final blocks = ((pack['pages'] as List).first as Map)['blocks'] as List;
    expect((blocks[0] as Map).containsKey('url'), isFalse);
    expect((blocks[1] as Map)['url'], 'https://cdn.example/a.png');
  });
}
