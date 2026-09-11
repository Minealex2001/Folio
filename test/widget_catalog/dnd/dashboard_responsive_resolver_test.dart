import 'package:flutter_test/flutter_test.dart';
import 'package:folio/config/models/dashboard_config.dart';
import 'package:folio/config/models/widget_instance_config.dart';
import 'package:folio/widget_catalog/dnd/dashboard_responsive_resolver.dart';

void main() {
  DashboardConfig baseWith(List<WidgetInstanceConfig> widgets, {
    Map<String, DashboardConfig>? overrides,
  }) {
    return DashboardConfig(
      id: 'test',
      name: 'Test',
      widgets: widgets,
      responsiveOverrides: overrides,
    );
  }

  group('DashboardResponsiveResolver.resolveForWidth', () {
    test('with no responsiveOverrides, returns the base config unchanged '
        'at any width', () {
      final base = baseWith([
        WidgetInstanceConfig(instanceId: 'a', pluginId: 'clock', regionId: 'left', order: 0),
      ]);
      expect(DashboardResponsiveResolver.resolveForWidth(base, 400), same(base));
      expect(DashboardResponsiveResolver.resolveForWidth(base, 1200), same(base));
    });

    test('a mobile override hiding one widget only affects that widget, '
        'at mobile width', () {
      final visible = WidgetInstanceConfig(
        instanceId: 'a',
        pluginId: 'clock',
        regionId: 'left',
        order: 0,
      );
      final other = WidgetInstanceConfig(
        instanceId: 'b',
        pluginId: 'tasks',
        regionId: 'left',
        order: 1,
      );
      final base = baseWith(
        [visible, other],
        overrides: {
          'mobile': DashboardConfig(
            id: 'test-mobile',
            name: 'mobile',
            widgets: [visible.copyWith(visible: false)],
          ),
        },
      );

      final atMobile = DashboardResponsiveResolver.resolveForWidth(base, 400);
      expect(atMobile.widgets.firstWhere((w) => w.instanceId == 'a').visible, isFalse);
      expect(atMobile.widgets.firstWhere((w) => w.instanceId == 'b').visible, isTrue);

      // A desktop width, sin override aplicable, ambos siguen visibles.
      final atDesktop = DashboardResponsiveResolver.resolveForWidth(base, 1200);
      expect(atDesktop.widgets.every((w) => w.visible), isTrue);
    });

    test('preserves base widget order after merging an override', () {
      final a = WidgetInstanceConfig(instanceId: 'a', pluginId: 'clock', regionId: 'left', order: 0);
      final b = WidgetInstanceConfig(instanceId: 'b', pluginId: 'tasks', regionId: 'left', order: 1);
      final c = WidgetInstanceConfig(instanceId: 'c', pluginId: 'weather', regionId: 'left', order: 2);
      final base = baseWith(
        [a, b, c],
        overrides: {
          'tablet': DashboardConfig(
            id: 'test-tablet',
            name: 'tablet',
            widgets: [b.copyWith(visible: false)],
          ),
        },
      );

      final result = DashboardResponsiveResolver.resolveForWidth(base, 700);
      expect(result.widgets.map((w) => w.instanceId), ['a', 'b', 'c']);
      expect(result.widgets[1].visible, isFalse);
    });

    test('an empty override widgets list is treated as no override', () {
      final base = baseWith(
        [WidgetInstanceConfig(instanceId: 'a', pluginId: 'clock', regionId: 'left', order: 0)],
        overrides: {'mobile': DashboardConfig(id: 'empty', name: 'empty', widgets: const [])},
      );
      expect(DashboardResponsiveResolver.resolveForWidth(base, 400), same(base));
    });
  });
}
