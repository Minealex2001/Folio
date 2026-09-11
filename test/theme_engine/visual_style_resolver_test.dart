import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folio/config/models/visual_style.dart';
import 'package:folio/theme_engine/visual_style_resolver.dart';

void main() {
  group('resolveCursor', () {
    test('maps known cursor names to their SystemMouseCursors', () {
      const style = VisualStyle(
        cursorHover: 'grab',
        cursorResize: 'resizeRow',
        cursorText: 'text',
      );
      expect(resolveCursor(style, 'hover'), SystemMouseCursors.grab);
      expect(resolveCursor(style, 'resize'), SystemMouseCursors.resizeRow);
      expect(resolveCursor(style, 'text'), SystemMouseCursors.text);
    });

    test('an unknown cursor name falls back to basic', () {
      const style = VisualStyle(cursorHover: 'not-a-real-cursor');
      expect(resolveCursor(style, 'hover'), SystemMouseCursors.basic);
    });

    test('null VisualStyle uses the documented defaults', () {
      expect(resolveCursor(null, 'hover'), SystemMouseCursors.basic);
      expect(resolveCursor(null, 'resize'), SystemMouseCursors.resizeColumn);
      expect(resolveCursor(null, 'text'), SystemMouseCursors.text);
    });
  });

  group('resolveGlobalBorder', () {
    final scheme = ColorScheme.fromSeed(seedColor: Colors.blue);

    test('borderEnabled = false (default) returns null', () {
      expect(resolveGlobalBorder(null, scheme), isNull);
      expect(resolveGlobalBorder(const VisualStyle(), scheme), isNull);
    });

    test('borderEnabled = true returns a BorderSide', () {
      const style = VisualStyle(borderEnabled: true);
      expect(resolveGlobalBorder(style, scheme), isNotNull);
    });
  });
}
