import 'package:flutter_test/flutter_test.dart';
import 'package:folio/config/models/layout_config.dart';
import 'package:folio/config/models/panel_config.dart';
import 'package:folio/layout_engine/responsive/responsive_layout_resolver.dart';

void main() {
  final base = LayoutConfig(
    id: 'test',
    name: 'Test',
    panels: {
      'sidebarLeft': PanelConfig(
        regionId: 'sidebarLeft',
        visible: true,
        width: 280,
      ),
      'main': PanelConfig(regionId: 'main', visible: true),
    },
    responsiveOverrides: {
      'mobile': LayoutConfig(
        id: 'test-mobile-override',
        name: 'mobile',
        panels: {
          'sidebarLeft': PanelConfig(regionId: 'sidebarLeft', visible: false),
        },
      ),
    },
  );

  test('returns the base config unchanged when there is no override for '
      'the resolved breakpoint', () {
    final resolved = ResponsiveLayoutResolver.resolveForWidth(base, 1200);
    expect(resolved.panels['sidebarLeft']!.visible, isTrue);
    expect(resolved.panels['sidebarLeft']!.width, 280);
  });

  test('merges the override for the resolved breakpoint over the base '
      'panels', () {
    final resolved = ResponsiveLayoutResolver.resolveForWidth(base, 400);
    expect(resolved.panels['sidebarLeft']!.visible, isFalse);
  });

  test('only overrides the panels present in the override, leaving others '
      'from the base untouched', () {
    final resolved = ResponsiveLayoutResolver.resolveForWidth(base, 400);
    expect(resolved.panels['main']!.visible, isTrue);
  });

  test('returns the base config unchanged when responsiveOverrides is '
      'null', () {
    final noOverrides = LayoutConfig.defaultConfig(id: 'plain');
    final resolved = ResponsiveLayoutResolver.resolveForWidth(
      noOverrides,
      400,
    );
    expect(resolved, same(noOverrides));
  });
}
