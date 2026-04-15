import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:folio/features/workspace/editor/folio_text_format.dart';

void main() {
  group('folioToggleWrap', () {
    test('wraps expanded selection and keeps selection on inner text', () {
      final c = TextEditingController(text: 'hola mundo');
      c.selection = const TextSelection(baseOffset: 5, extentOffset: 10); // mundo

      final ok = folioToggleWrap(c, '**', '**');

      expect(ok, true);
      expect(c.text, 'hola **mundo**');
      expect(c.selection.baseOffset, 7);
      expect(c.selection.extentOffset, 12);
      expect(c.text.substring(c.selection.start, c.selection.end), 'mundo');
    });

    test('unwraps when selection is already wrapped', () {
      final c = TextEditingController(text: 'hola **mundo**');
      c.selection = const TextSelection(baseOffset: 7, extentOffset: 12); // mundo

      final ok = folioToggleWrap(c, '**', '**');

      expect(ok, true);
      expect(c.text, 'hola mundo');
      expect(c.selection.baseOffset, 5);
      expect(c.selection.extentOffset, 10);
    });

    test('unwraps when selection includes the wrap markers', () {
      final c = TextEditingController(text: 'hola **mundo**');
      c.selection = const TextSelection(baseOffset: 5, extentOffset: 14); // **mundo**

      final ok = folioToggleWrap(c, '**', '**');

      expect(ok, true);
      expect(c.text, 'hola mundo');
      expect(c.selection.baseOffset, 5);
      expect(c.selection.extentOffset, 10);
    });

    test('wraps collapsed selection by inserting pair and placing caret inside', () {
      final c = TextEditingController(text: 'hola');
      c.selection = const TextSelection.collapsed(offset: 2);

      final ok = folioToggleWrap(c, '_', '_');

      expect(ok, true);
      expect(c.text, 'ho__la');
      expect(c.selection.isCollapsed, true);
      expect(c.selection.baseOffset, 3);
    });

    test('does not apply inline code when selection contains backticks', () {
      final c = TextEditingController(text: 'a `b` c');
      c.selection = const TextSelection(baseOffset: 2, extentOffset: 5); // `b`

      final ok = folioToggleWrap(c, '`', '`');

      expect(ok, false);
      expect(c.text, 'a `b` c');
      expect(c.selection.baseOffset, 2);
      expect(c.selection.extentOffset, 5);
    });
  });
}

