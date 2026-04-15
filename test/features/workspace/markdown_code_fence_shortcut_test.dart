import 'package:flutter_test/flutter_test.dart';

import 'package:folio/features/workspace/editor/block_editor.dart';

void main() {
  group('folioParseMarkdownCodeFenceShortcut', () {
    test('returns empty string for plain fence', () {
      expect(folioParseMarkdownCodeFenceShortcut('``` '), '');
      expect(folioParseMarkdownCodeFenceShortcut('```'), '');
      expect(folioParseMarkdownCodeFenceShortcut('```   '), '');
    });

    test('parses language id (case-insensitive)', () {
      expect(folioParseMarkdownCodeFenceShortcut('```dart '), 'dart');
      expect(folioParseMarkdownCodeFenceShortcut('```DART'), 'dart');
    });

    test('normalizes common aliases', () {
      expect(folioParseMarkdownCodeFenceShortcut('```js '), 'javascript');
      expect(folioParseMarkdownCodeFenceShortcut('```ts'), 'typescript');
      expect(folioParseMarkdownCodeFenceShortcut('```sh'), 'bash');
      expect(folioParseMarkdownCodeFenceShortcut('```yml'), 'yaml');
      expect(folioParseMarkdownCodeFenceShortcut('```text'), 'plaintext');
    });

    test('returns null when not a full-line fence shortcut', () {
      expect(folioParseMarkdownCodeFenceShortcut('````dart'), isNull);
      expect(folioParseMarkdownCodeFenceShortcut('hello ```dart'), isNull);
      expect(folioParseMarkdownCodeFenceShortcut(' ```dart'), isNull);
    });
  });
}

