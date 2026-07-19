import 'package:flutter_test/flutter_test.dart';
import 'package:folio/data/vault_payload.dart';
import 'package:folio/models/folio_page.dart';

void main() {
  test('VaultPayload v11 round-trip de mcpReadablePageIds', () {
    final payload = VaultPayload(
      version: kVaultPayloadVersion,
      pages: [
        FolioPage(id: 'p1', title: 'A'),
        FolioPage(id: 'p2', title: 'B', isFolder: true),
      ],
      mcpReadablePageIds: {'p1', 'p2'},
    );

    final decoded = VaultPayload.decodeUtf8(payload.encodeUtf8());

    expect(decoded.version, kVaultPayloadVersion);
    expect(kVaultPayloadVersion, 11);
    expect(decoded.mcpReadablePageIds, {'p1', 'p2'});
  });

  test('VaultPayload sin mcpReadablePageIds tolera libretas antiguas', () {
    final json = {
      'version': 10,
      'pages': [
        {'id': 'x', 'title': 'Old', 'blocks': []},
      ],
      'pageRevisions': <String, dynamic>{},
      'pageAcl': <String, dynamic>{},
      'localProfiles': <dynamic>[],
      'comments': <dynamic>[],
      'aiChatThreads': <dynamic>[],
      'aiActiveChatIndex': 0,
    };

    final decoded = VaultPayload.fromJson(json);
    expect(decoded.mcpReadablePageIds, isEmpty);
  });
}
