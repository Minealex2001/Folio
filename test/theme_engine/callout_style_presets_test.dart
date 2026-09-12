import 'package:flutter_test/flutter_test.dart';
import 'package:folio/theme_engine/callout_style_presets.dart';

void main() {
  group('kBuiltinCalloutStylePresets', () {
    test('has exactly the 3 documented presets with unique ids', () {
      final ids = kBuiltinCalloutStylePresets.map((p) => p.id).toSet();
      expect(ids, {'notion', 'obsidian', 'minimal'});
    });

    test('notion is the identity preset (scale 1.0, border+icon shown)', () {
      expect(kCalloutStyleNotion.backgroundAlphaScale, 1.0);
      expect(kCalloutStyleNotion.borderAlphaScale, 1.0);
      expect(kCalloutStyleNotion.chipAlphaScale, 1.0);
      expect(kCalloutStyleNotion.showBorder, isTrue);
      expect(kCalloutStyleNotion.showIcon, isTrue);
    });

    test('minimal has no border and a reduced background', () {
      expect(kCalloutStyleMinimal.showBorder, isFalse);
      expect(kCalloutStyleMinimal.showIcon, isFalse);
      expect(kCalloutStyleMinimal.backgroundAlphaScale, lessThan(1.0));
    });
  });

  group('calloutStylePresetFor', () {
    test('resolves each builtin id to the matching preset', () {
      expect(calloutStylePresetFor('notion'), kCalloutStyleNotion);
      expect(calloutStylePresetFor('obsidian'), kCalloutStyleObsidian);
      expect(calloutStylePresetFor('minimal'), kCalloutStyleMinimal);
    });

    test('an unknown id falls back to notion', () {
      expect(calloutStylePresetFor('does-not-exist'), kCalloutStyleNotion);
    });
  });
}
