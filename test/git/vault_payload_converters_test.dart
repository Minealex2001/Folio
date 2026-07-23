/// Tests para los convertidores VaultPayload ↔ árbol.
///
/// M0: Validar que la conversión es bidireccional sin pérdida de datos.

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:folio/data/vault_payload.dart';
import 'package:folio/models/folio_page.dart';
import 'package:folio/models/block.dart';
import 'package:folio/models/folio_page_import_info.dart';
import 'package:folio/models/page_property.dart';
import 'package:folio/git/vault_payload_converters.dart';
import 'package:path/path.dart' as p;

void main() {
  group('VaultPayloadConverters - M0', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('folio_converters_test_');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('decompose creates tree structure', () async {
      final payload = VaultPayload(
        pages: [
          FolioPage(
            id: 'page-001',
            title: 'Test Page',
            emoji: '📝',
            blocks: [
              FolioBlock(
                id: 'block-001',
                type: 'paragraph',
                text: 'Hello world',
              ),
            ],
          ),
        ],
        displayName: 'Test Vault',
      );

      final treeDir = Directory(p.join(tempDir.path, 'tree'));
      await VaultPayloadToTree.decompose(payload, treeDir);

      // Verify structure
      expect(File(p.join(treeDir.path, 'tree.json')).existsSync(), isTrue);
      expect(
        Directory(p.join(treeDir.path, 'pages')).existsSync(),
        isTrue,
      );
      expect(
        File(p.join(treeDir.path, 'vault', 'meta.json')).existsSync(),
        isTrue,
      );
    });

    test('round-trip: payload → tree → payload preserves content', () async {
      // Create original payload
      final originalPayload = VaultPayload(
        pages: [
          FolioPage(
            id: 'abc123',
            title: 'Main Page',
            emoji: '📄',
            isFolder: false,
            blocks: [
              FolioBlock(id: 'b1', type: 'paragraph', text: 'Paragraph text'),
              FolioBlock(id: 'b2', type: 'code', text: 'code here', codeLanguage: 'dart'),
            ],
            tags: ['important', 'work'],
          ),
          FolioPage(
            id: 'xyz789',
            title: 'Sub Page',
            parentId: 'abc123',
            isFolder: false,
            blocks: [],
          ),
        ],
        displayName: 'My Notebook',
        pageOrderByParent: {
          '': ['abc123', 'def456'],
          'abc123': ['xyz789'],
        },
      );

      // Decompose to tree
      final treeDir = Directory(p.join(tempDir.path, 'tree'));
      await VaultPayloadToTree.decompose(originalPayload, treeDir);

      // Recompose from tree
      final recomposed = await TreeToVaultPayload.compose(treeDir);

      // Verify key fields match
      expect(recomposed.displayName, equals(originalPayload.displayName));
      expect(recomposed.pages.length, equals(originalPayload.pages.length));

      // Verify first page
      final origPage = originalPayload.pages[0];
      final recPage = recomposed.pages.firstWhere((p) => p.id == origPage.id);
      expect(recPage.title, equals(origPage.title));
      expect(recPage.emoji, equals(origPage.emoji));
      expect(recPage.blocks.length, equals(origPage.blocks.length));
      expect(recPage.blocks[0].text, equals('Paragraph text'));
      expect(recPage.tags, equals(['important', 'work']));

      // Verify pageOrderByParent
      expect(
        recomposed.pageOrderByParent['abc123'],
        contains('xyz789'),
      );
    });

    test('decompose handles empty pages', () async {
      final payload = VaultPayload(
        pages: [],
        displayName: 'Empty Vault',
      );

      final treeDir = Directory(p.join(tempDir.path, 'tree'));
      await VaultPayloadToTree.decompose(payload, treeDir);

      // Should still create tree structure
      expect(File(p.join(treeDir.path, 'tree.json')).existsSync(), isTrue);
    });

    test('round-trip preserves properties, tombstones and syncClock', () async {
      final originalPayload = VaultPayload(
        pages: [
          FolioPage(
            id: 'prop1',
            title: 'With props',
            blocks: [
              FolioBlock(id: 'b1', type: 'paragraph', text: 'x'),
            ],
            properties: [
              FolioPageProperty(
                id: 'st',
                name: 'Status',
                type: PagePropertyType.status,
                value: 'Done',
              ),
            ],
            lastImportInfo: FolioPageImportInfo(
              clientAppId: 'c',
              clientAppName: 'Client',
              importedAtMs: 1,
              importMode: 'newPage',
            ),
          ),
        ],
        displayName: 'Props Vault',
        pageTombstones: {'deleted': 99},
        syncClock: 7,
      );

      final treeDir = Directory(p.join(tempDir.path, 'tree'));
      await VaultPayloadToTree.decompose(originalPayload, treeDir);
      final recomposed = await TreeToVaultPayload.compose(treeDir);

      expect(recomposed.syncClock, equals(7));
      expect(recomposed.pageTombstones['deleted'], equals(99));
      expect(recomposed.pages[0].properties.first.value, equals('Done'));
      expect(recomposed.pages[0].lastImportInfo?.clientAppId, equals('c'));
    });
  });
}
