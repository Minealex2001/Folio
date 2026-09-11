import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folio/features/workspace/editor/block_editor/block_editor_callout.dart';
import 'package:folio/theme_engine/callout_style_presets.dart';

void main() {
  final scheme = ColorScheme.fromSeed(seedColor: Colors.blue);

  group('calloutToneForIcon', () {
    test('maps known icons to their tone', () {
      expect(calloutToneForIcon('💡'), BlockCalloutTone.info);
      expect(calloutToneForIcon('✅'), BlockCalloutTone.success);
      expect(calloutToneForIcon('⚠️'), BlockCalloutTone.warning);
      expect(calloutToneForIcon('🚨'), BlockCalloutTone.danger);
    });

    test('an unknown icon falls back to neutral', () {
      expect(calloutToneForIcon('🦄'), BlockCalloutTone.neutral);
      expect(calloutToneForIcon(null), BlockCalloutTone.neutral);
    });
  });

  group('callout color functions — default preset parity (Fase 27)', () {
    test('omitting preset reproduces the exact literal alpha values', () {
      final bg = calloutBackgroundForTone(scheme, BlockCalloutTone.info);
      expect(bg.a, closeTo(0.26, 0.001));
      final border = calloutBorderForTone(scheme, BlockCalloutTone.info);
      expect(border.a, closeTo(0.45, 0.001));
      final chip = calloutChipForTone(scheme, BlockCalloutTone.info);
      expect(chip.a, closeTo(0.75, 0.001));
    });

    test('explicitly passing kCalloutStyleNotion matches the default '
        '(identity preset)', () {
      final withDefault = calloutBackgroundForTone(scheme, BlockCalloutTone.warning);
      final withNotion = calloutBackgroundForTone(
        scheme,
        BlockCalloutTone.warning,
        preset: kCalloutStyleNotion,
      );
      expect(withNotion.a, closeTo(withDefault.a, 0.0001));
    });
  });

  group('callout color functions — preset variation', () {
    test('obsidian scales the background/border/chip alpha up', () {
      final notionBg = calloutBackgroundForTone(scheme, BlockCalloutTone.success);
      final obsidianBg = calloutBackgroundForTone(
        scheme,
        BlockCalloutTone.success,
        preset: kCalloutStyleObsidian,
      );
      expect(obsidianBg.a, greaterThan(notionBg.a));
    });

    test('minimal disables the border entirely (fully transparent)', () {
      final border = calloutBorderForTone(
        scheme,
        BlockCalloutTone.danger,
        preset: kCalloutStyleMinimal,
      );
      expect(border, Colors.transparent);
    });

    test('minimal reduces the background alpha relative to notion', () {
      final notionBg = calloutBackgroundForTone(scheme, BlockCalloutTone.neutral);
      final minimalBg = calloutBackgroundForTone(
        scheme,
        BlockCalloutTone.neutral,
        preset: kCalloutStyleMinimal,
      );
      expect(minimalBg.a, lessThan(notionBg.a));
    });
  });
}
