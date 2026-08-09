import 'package:flutter_test/flutter_test.dart';
import 'package:folio/models/block.dart';
import 'package:folio/models/folio_page.dart';
import 'package:folio/models/meeting_note_bookmark.dart';
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

    test(
      'Fase 19 evolución meeting_note: exporta transcript + summary + '
      'bookmarks + metrics cuando están presentes',
      () {
        final page = FolioPage(
          id: 'page_3',
          title: 'Weekly sync',
          blocks: [
            FolioBlock(
              id: 'mn1',
              type: 'meeting_note',
              text: 'Speaker 1: hablamos de la migración a S3',
              meetingNoteTitle: 'Weekly sync',
              meetingNoteSummary: const {
                'narrative': 'Se decidió migrar a S3.',
                'keyPoints': ['Migración a S3 aprobada'],
                'actionItems': [
                  {'title': 'Implementar sync', 'taskBlockId': 'task1'},
                  {'title': 'Confirmar plazo', 'taskBlockId': null},
                ],
              },
              meetingNoteBookmarks: [
                MeetingNoteBookmark(
                  id: 'bm1',
                  timestampMs: 42000,
                  type: MeetingNoteBookmarkType.decision,
                  label: 'Usar S3',
                ),
              ],
              meetingNoteMetricsSummary: const {
                'wordsPerMinute': 118.0,
                'questionCount': 2,
              },
            ),
          ],
        );

        final markdown = FolioMarkdownCodec.exportPage(page);

        expect(markdown, contains('## Weekly sync'));
        expect(markdown, contains('hablamos de la migración a S3'));
        expect(markdown, contains('### Summary'));
        expect(markdown, contains('Se decidió migrar a S3.'));
        expect(markdown, contains('### Key Points'));
        expect(markdown, contains('- Migración a S3 aprobada'));
        expect(markdown, contains('### Action Items'));
        expect(markdown, contains('- [x] Implementar sync'));
        expect(markdown, contains('- [ ] Confirmar plazo'));
        expect(markdown, contains('### Bookmarks'));
        expect(markdown, contains('00:42 [decision] — Usar S3'));
        expect(markdown, contains('### Metrics'));
        expect(markdown, contains('118 wpm'));
        expect(markdown, contains('2 question(s)'));
      },
    );

    test(
      'meeting_note sin summary/bookmarks/metrics exporta solo el título y transcript',
      () {
        final page = FolioPage(
          id: 'page_4',
          title: 'Quick call',
          blocks: [
            FolioBlock(
              id: 'mn1',
              type: 'meeting_note',
              text: 'Speaker 1: hola',
            ),
          ],
        );

        final markdown = FolioMarkdownCodec.exportPage(page);

        expect(markdown, contains('## Meeting'));
        expect(markdown, contains('Speaker 1: hola'));
        expect(markdown, isNot(contains('### Summary')));
        expect(markdown, isNot(contains('### Bookmarks')));
        expect(markdown, isNot(contains('### Metrics')));
      },
    );
  });
}
