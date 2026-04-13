import 'package:flutter_test/flutter_test.dart';
import 'package:folio/models/block.dart';
import 'package:folio/models/folio_page.dart';
import 'package:folio/services/integrations/integrations_markdown_codec.dart';

void main() {
  group('Integrations markdown codec', () {
    test('parsea bloques markdown enriquecidos', () {
      const markdown = '''
---
title: "Petstore API"
---

> [!WARNING]
> Requiere token.

1. Login
  1. Refresh
- [x] Checklist

| Name | Value |
| --- | ---: |
| foo | bar |

```diff
- old
+ new
```

```mermaid
graph TD
  A --> B
```
''';

      final doc = FolioMarkdownCodec.parseDocument(markdown, pageId: 'page_1');

      expect(doc.title, 'Petstore API');
      expect(doc.blocks.any((b) => b.type == 'callout'), isTrue);
      expect(doc.blocks.any((b) => b.type == 'numbered'), isTrue);
      expect(doc.blocks.any((b) => b.type == 'todo'), isTrue);
      expect(doc.blocks.any((b) => b.type == 'table'), isTrue);
      expect(doc.blocks.any((b) => b.type == 'mermaid'), isTrue);

      final diffBlock = doc.blocks.firstWhere((b) => b.type == 'code');
      expect(diffBlock.codeLanguage, 'diff');
    });

    test('exporta callouts y bloques de codigo a markdown', () {
      final page = FolioPage(
        id: 'page_2',
        title: 'Guide',
        blocks: [
          FolioBlock(id: 'b1', type: 'callout', text: 'Texto', icon: '💡'),
          FolioBlock(
            id: 'b2',
            type: 'code',
            text: 'print(1);',
            codeLanguage: 'dart',
          ),
        ],
      );

      final markdown = FolioMarkdownCodec.exportPage(page);

      expect(markdown, contains('> [!TIP]'));
      expect(markdown, contains('```dart'));
      expect(markdown, contains('print(1);'));
    });
  });
}
