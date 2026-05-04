import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folio/features/workspace/editor/block_editor/block_editor_text_helpers.dart';

void main() {
  group('slashAiTailIsValid', () {
    test('allows /ai and one-word subcommand with space', () {
      expect(slashAiTailIsValid('ai'), isTrue);
      expect(slashAiTailIsValid('ai summarize'), isTrue);
      expect(slashAiTailIsValid('aisummarize'), isTrue);
      expect(slashAiTailIsValid('ai sum'), isTrue);
    });

    test('rejects multiple tokens after ai', () {
      expect(slashAiTailIsValid('ai summarize more'), isFalse);
    });

    test('allows partial typing', () {
      expect(slashAiTailIsValid('a'), isTrue);
      expect(slashAiTailIsValid(''), isTrue);
    });

    test('rejects non-ai tails with spaces', () {
      expect(slashAiTailIsValid('foo bar'), isFalse);
    });
  });

  group('slashFilterFromBlockText', () {
    test('returns filter for ai summarize', () {
      expect(slashFilterFromBlockText('/ai summarize'), 'ai summarize');
    });

    test('returns null for ambiguous multi-word non-ai', () {
      expect(slashFilterFromBlockText('/foo bar'), isNull);
    });
  });

  group('slashFilterFromPlainTextAndSelection', () {
    test('caret after /ai summarize yields filter', () {
      const plain = 'intro\n/ai summarize';
      const sel = TextSelection.collapsed(offset: plain.length);
      expect(slashFilterFromPlainTextAndSelection(plain, sel), 'ai summarize');
    });
  });
}
