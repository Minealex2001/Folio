import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:dart_quill_delta/dart_quill_delta.dart';

import 'package:folio/features/workspace/editor/richtext/markdown_quill_codec.dart';

void main() {
  test('markdownToDocument preserves visible text', () {
    final doc = FolioMarkdownQuillCodec.markdownToDocument(
      '**hola** _mundo_ ~~x~~ `c` <u>u</u> [l](https://e.com)',
    );
    final plain = doc.toPlainText();
    expect(plain.contains('hola'), true);
    expect(plain.contains('mundo'), true);
    expect(plain.contains('x'), true);
    expect(plain.contains('c'), true);
    expect(plain.contains('u'), true);
    expect(plain.contains('l'), true);
  });

  test('documentToMarkdown emits basic wrappers', () {
    final doc = quill.Document();
    final c = quill.QuillController(
      document: doc,
      selection: const TextSelection.collapsed(offset: 0),
    );
    c.replaceText(0, 0, 'hola', null);
    c.formatText(0, 4, quill.Attribute.bold);
    final md = FolioMarkdownQuillCodec.documentToMarkdown(c.document);
    expect(md.contains('**hola**'), true);
  });

  test('delta json roundtrip: doc -> deltaJson -> doc', () {
    final doc = FolioMarkdownQuillCodec.markdownToDocument('**hola**');
    final deltaJson = doc.toDelta().toJson();
    final restored = quill.Document.fromDelta(Delta.fromJson(deltaJson));
    expect(restored.toPlainText().contains('hola'), true);
  });
}

