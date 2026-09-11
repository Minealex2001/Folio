import 'package:flutter_test/flutter_test.dart';
import 'package:folio/dashboard_templates/builtin_dashboard_templates.dart';
import 'package:folio/widget_catalog/builtin/builtin_widget_plugins.dart';
import 'package:folio/widget_catalog/widget_catalog_registry.dart';

void main() {
  setUp(() {
    WidgetCatalogRegistry.instance.debugClear();
    registerBuiltinWidgetPlugins();
  });

  tearDown(() => WidgetCatalogRegistry.instance.debugClear());

  group('kBuiltinDashboardTemplates', () {
    test('has exactly the 6 documented templates with unique ids', () {
      final ids = kBuiltinDashboardTemplates.map((t) => t.id).toSet();
      expect(ids, {
        'template-developer',
        'template-writer',
        'template-research',
        'template-student',
        'template-planning',
        'template-gaming',
      });
    });

    test('every widget referenced by every template is a plugin actually '
        'registered in the catalog — no dangling pluginId', () {
      final registry = WidgetCatalogRegistry.instance;
      for (final entry in kBuiltinDashboardTemplates) {
        final config = entry.build();
        for (final widget in config.widgets) {
          expect(
            registry[widget.pluginId],
            isNotNull,
            reason:
                '${entry.id} references pluginId "${widget.pluginId}", '
                'which is not registered',
          );
        }
      }
    });

    test('every template has unique instanceIds within itself', () {
      for (final entry in kBuiltinDashboardTemplates) {
        final config = entry.build();
        final ids = config.widgets.map((w) => w.instanceId).toList();
        expect(ids.toSet().length, ids.length, reason: '${entry.id} has duplicate instanceIds');
      }
    });

    test('each template\'s DashboardConfig.id matches its registry entry id', () {
      for (final entry in kBuiltinDashboardTemplates) {
        expect(entry.build().id, entry.id);
      }
    });
  });

  group('dashboardTemplateById', () {
    test('resolves a known id to the matching entry', () {
      expect(dashboardTemplateById('template-gaming')?.displayName, 'Gaming');
    });

    test('an unknown id returns null', () {
      expect(dashboardTemplateById('does-not-exist'), isNull);
    });
  });
}
