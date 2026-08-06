import 'package:flutter_test/flutter_test.dart';
import 'package:folio/config/models/widget_theme_tokens.dart';
import 'package:folio/theme_engine/widget_theme_resolver.dart';

void main() {
  group('themeFor', () {
    test('null tokens returns the plugin default unchanged', () {
      final result = themeFor(null, 'calendar', const {'weekendColor': 1});
      expect(result, {'weekendColor': 1});
    });

    test('a plugin with no configured theme returns its default unchanged', () {
      const tokens = WidgetThemeTokens(widgets: {'tasks': {'completedOpacity': 0.5}});
      final result = themeFor(tokens, 'calendar', const {'weekendColor': 1});
      expect(result, {'weekendColor': 1});
    });

    test('configured keys override matching default keys, others pass '
        'through untouched', () {
      const tokens = WidgetThemeTokens(
        widgets: {
          'calendar': {'weekendColor': 0xFFFF0000},
        },
      );
      final result = themeFor(
        tokens,
        'calendar',
        const {'weekendColor': 0x00000000, 'todayStyle': 'filled'},
      );
      expect(result['weekendColor'], 0xFFFF0000);
      expect(result['todayStyle'], 'filled');
    });

    test('an empty configured map for a plugin is treated as unconfigured', () {
      const tokens = WidgetThemeTokens(widgets: {'calendar': {}});
      final result = themeFor(tokens, 'calendar', const {'weekendColor': 1});
      expect(result, {'weekendColor': 1});
    });
  });
}
