import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:folio/data/vault_payload.dart';
import 'package:folio/models/block.dart';
import 'package:folio/models/folio_page.dart';
import 'package:folio/services/sync/vault_sync_pack.dart';

void main() {
  FolioPage page(String id) => FolioPage(
        id: id,
        title: 'Page $id',
        blocks: [
          FolioBlock(id: '${id}_b0', type: 'paragraph', text: 'hello $id'),
        ],
      );

  VaultPayload payload(List<FolioPage> pages) => VaultPayload(pages: pages);

  test('encodeUtf8Async/decodeFlexibleAsync round-trip below isolate threshold '
      '(inline path)', () async {
    final pack = VaultSyncPack(
      payload: payload([page('a'), page('b')]),
      attachments: [
        VaultSyncPackAttachment(
          path: 'attachments/small.bin',
          sha256Hex: '',
          bytes: Uint8List.fromList(List.filled(128, 7)),
        ),
      ],
    );

    final encoded = await pack.encodeUtf8Async();
    expect(encoded, pack.encodeUtf8());

    final decoded = await VaultSyncPack.decodeFlexibleAsync(encoded);
    expect(decoded.payload.pages.map((p) => p.id).toSet(), {'a', 'b'});
    expect(decoded.attachments, hasLength(1));
    expect(decoded.attachments.single.bytes, pack.attachments.single.bytes);
  });

  test('encodeUtf8Async/decodeFlexibleAsync round-trip above isolate '
      'threshold (offloaded to compute())', () async {
    // Un solo adjunto de 300 KiB fuerza la rama que manda el trabajo a un
    // isolate aparte (umbral interno: 256 KiB de bytes de adjuntos).
    final bigBytes = Uint8List.fromList(
      List.generate(300 * 1024, (i) => i % 256),
    );
    final pack = VaultSyncPack(
      payload: payload([page('a'), page('b'), page('c')]),
      attachments: [
        VaultSyncPackAttachment(
          path: 'attachments/big.bin',
          sha256Hex: 'deadbeef',
          bytes: bigBytes,
        ),
      ],
    );

    final encoded = await pack.encodeUtf8Async();
    // El resultado debe ser byte-a-byte idéntico a la versión síncrona: el
    // isolate solo debe cambiar DÓNDE corre el trabajo, no el formato wire.
    expect(encoded, pack.encodeUtf8());

    final decoded = await VaultSyncPack.decodeFlexibleAsync(encoded);
    expect(decoded.payload.pages.map((p) => p.id).toSet(), {'a', 'b', 'c'});
    expect(decoded.attachments, hasLength(1));
    expect(decoded.attachments.single.path, 'attachments/big.bin');
    expect(decoded.attachments.single.sha256Hex, 'deadbeef');
    expect(decoded.attachments.single.bytes, bigBytes);
  });

  test('decodeFlexibleAsync handles legacy plain-VaultPayload snapshots '
      '(no format/attachments)', () async {
    final legacy = payload([page('a')]);
    final bytes = legacy.encodeUtf8();

    final decoded = await VaultSyncPack.decodeFlexibleAsync(bytes);
    expect(decoded.payload.pages.map((p) => p.id).toSet(), {'a'});
    expect(decoded.attachments, isEmpty);
  });
}
