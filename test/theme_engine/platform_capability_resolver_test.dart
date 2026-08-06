import 'package:flutter/foundation.dart' show TargetPlatform;
import 'package:flutter_test/flutter_test.dart';
import 'package:folio/theme_engine/platform_capability_resolver.dart';

void main() {
  group('isEffectAllowed', () {
    test('window backdrop blur is not allowed on mobile platforms', () {
      expect(
        isEffectAllowed(kEffectWindowBackdropBlur, TargetPlatform.android),
        isFalse,
      );
      expect(
        isEffectAllowed(kEffectWindowBackdropBlur, TargetPlatform.iOS),
        isFalse,
      );
    });

    test('window backdrop blur is allowed on desktop platforms', () {
      expect(
        isEffectAllowed(kEffectWindowBackdropBlur, TargetPlatform.windows),
        isTrue,
      );
      expect(
        isEffectAllowed(kEffectWindowBackdropBlur, TargetPlatform.macOS),
        isTrue,
      );
      expect(
        isEffectAllowed(kEffectWindowBackdropBlur, TargetPlatform.linux),
        isTrue,
      );
    });

    test('glass opacity is gated the same way as window backdrop blur', () {
      expect(isEffectAllowed(kEffectGlassOpacity, TargetPlatform.android), isFalse);
      expect(isEffectAllowed(kEffectGlassOpacity, TargetPlatform.windows), isTrue);
    });

    test('an unknown effect id is allowed everywhere (exception list, not '
        'an allowlist)', () {
      expect(isEffectAllowed('some-future-effect', TargetPlatform.android), isTrue);
      expect(isEffectAllowed('some-future-effect', TargetPlatform.windows), isTrue);
    });
  });
}
