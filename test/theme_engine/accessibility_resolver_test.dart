import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folio/config/models/theme_motion_tokens.dart';
import 'package:folio/theme_engine/accessibility_resolver.dart';

void main() {
  group('applyContrast', () {
    final scheme = ColorScheme.fromSeed(seedColor: Colors.blue);

    test('contrast = normal (default) returns the scheme unchanged', () {
      expect(applyContrast(scheme, 'normal'), scheme);
    });

    test('contrast = high changes onSurfaceVariant/outline/outlineVariant '
        'without touching primary/secondary/tertiary', () {
      final result = applyContrast(scheme, 'high');
      expect(result.onSurfaceVariant, isNot(scheme.onSurfaceVariant));
      expect(result.outline, isNot(scheme.outline));
      expect(result.outlineVariant, isNot(scheme.outlineVariant));
      expect(result.primary, scheme.primary);
      expect(result.secondary, scheme.secondary);
    });
  });

  group('applyReduceMotion', () {
    test('reduceMotion = false returns the tokens unchanged', () {
      final motion = ThemeMotionTokens();
      expect(applyReduceMotion(motion, false), same(motion));
    });

    test('reduceMotion = true forces motion.enabled = false, keeping '
        'every other field', () {
      final motion = ThemeMotionTokens(shortMs: 999, curveName: 'linear');
      final result = applyReduceMotion(motion, true);
      expect(result.enabled, isFalse);
      expect(result.shortMs, 999);
      expect(result.curveName, 'linear');
    });
  });

  group('minTapTarget', () {
    test('false (default) returns 40, matching today\'s literal (parity)', () {
      expect(minTapTarget(false), 40);
    });

    test('true returns the larger WCAG-friendly target', () {
      expect(minTapTarget(true), 56);
    });
  });
}
