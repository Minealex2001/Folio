import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:folio/config/config_store.dart';
import 'package:folio/config/config_store_backend_io.dart';
import 'package:folio/config/models/dashboard_config.dart';
import 'package:folio/config/models/widget_instance_config.dart';
import 'package:folio/widget_catalog/dnd/dashboard_grid_controller.dart';

void main() {
  late Directory tempDir;
  late ConfigStore store;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('folio_dashboard_grid_test');
    ConfigStoreBackend.debugRootOverride = tempDir;
    store = await ConfigStore.open();
  });

  tearDown(() async {
    ConfigStoreBackend.debugRootOverride = null;
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  DashboardGridController makeController({
    List<WidgetInstanceConfig> widgets = const [],
    Duration? debounce,
  }) {
    return DashboardGridController(
      store,
      initialConfig: DashboardConfig(
        id: 'test',
        name: 'Test',
        widgets: widgets,
      ),
      persistDebounce: debounce ?? const Duration(minutes: 10),
    );
  }

  WidgetInstanceConfig instance(String id, String region, int order) =>
      WidgetInstanceConfig(
        instanceId: id,
        pluginId: 'clock',
        regionId: region,
        order: order,
      );

  group('moveToColumn', () {
    test('moves an instance to another column, appending at the end by '
        'default', () {
      final controller = makeController(
        widgets: [
          instance('a', 'left', 0),
          instance('b', 'left', 1),
          instance('c', 'right', 0),
        ],
      );

      controller.moveToColumn('a', 'right');

      final left = controller.widgetsInRegion('left');
      final right = controller.widgetsInRegion('right');
      expect(left.map((w) => w.instanceId), ['b']);
      expect(left.first.order, 0); // renumerado tras el remove
      expect(right.map((w) => w.instanceId), ['c', 'a']);
      expect(controller.instanceFor('a')!.regionId, 'right');
    });

    test('inserts at a specific order within the destination column', () {
      final controller = makeController(
        widgets: [
          instance('a', 'left', 0),
          instance('b', 'right', 0),
          instance('c', 'right', 1),
        ],
      );

      controller.moveToColumn('a', 'right', insertAtOrder: 1);

      final right = controller.widgetsInRegion('right');
      expect(right.map((w) => w.instanceId), ['b', 'a', 'c']);
    });

    test('is a no-op for an unknown instance id', () {
      final controller = makeController(
        widgets: [instance('a', 'left', 0)],
      );
      controller.moveToColumn('missing', 'right');
      expect(controller.widgetsInRegion('left'), hasLength(1));
      expect(controller.widgetsInRegion('right'), isEmpty);
    });
  });

  group('reorderWithinColumn', () {
    test('reorders using ReorderableListView index conventions', () {
      final controller = makeController(
        widgets: [
          instance('a', 'left', 0),
          instance('b', 'left', 1),
          instance('c', 'left', 2),
        ],
      );

      // Mover 'a' (index 0) a después de 'b' (newIndex 2, convención RLV).
      controller.reorderWithinColumn('left', 0, 2);

      expect(
        controller.widgetsInRegion('left').map((w) => w.instanceId),
        ['b', 'a', 'c'],
      );
    });
  });

  group('resizeInstance', () {
    test('updates width/height for the target instance only', () {
      final controller = makeController(
        widgets: [instance('a', 'left', 0), instance('b', 'left', 1)],
      );
      controller.resizeInstance('a', width: 320, height: 200);

      expect(controller.instanceFor('a')!.width, 320);
      expect(controller.instanceFor('a')!.height, 200);
      expect(controller.instanceFor('b')!.width, isNull);
    });
  });

  group('duplicateInstance', () {
    test('creates a copy right after the original with the same plugin/'
        'settings', () {
      final controller = makeController(
        widgets: [
          WidgetInstanceConfig(
            instanceId: 'a',
            pluginId: 'weather',
            regionId: 'left',
            order: 0,
            settings: {'unit': 'celsius'},
          ),
          instance('b', 'left', 1),
        ],
      );

      final newId = controller.duplicateInstance('a');
      final left = controller.widgetsInRegion('left');

      expect(left.map((w) => w.instanceId), ['a', newId, 'b']);
      final copy = controller.instanceFor(newId)!;
      expect(copy.pluginId, 'weather');
      expect(copy.settings, {'unit': 'celsius'});
      expect(copy.instanceId, isNot('a'));
    });

    test('throws for an unknown instance id', () {
      final controller = makeController();
      expect(
        () => controller.duplicateInstance('missing'),
        throwsArgumentError,
      );
    });
  });

  group('removeInstance', () {
    test('removes the instance and renumbers the remaining column', () {
      final controller = makeController(
        widgets: [
          instance('a', 'left', 0),
          instance('b', 'left', 1),
          instance('c', 'left', 2),
        ],
      );
      controller.removeInstance('b');

      final left = controller.widgetsInRegion('left');
      expect(left.map((w) => w.instanceId), ['a', 'c']);
      expect(left.map((w) => w.order), [0, 1]);
    });
  });

  group('groups', () {
    test('createGroup assigns groupId to all members and registers '
        'metadata', () {
      final controller = makeController(
        widgets: [instance('a', 'left', 0), instance('b', 'left', 1)],
      );
      final groupId = controller.createGroup(['a', 'b'], label: 'My group');

      expect(controller.instanceFor('a')!.groupId, groupId);
      expect(controller.instanceFor('b')!.groupId, groupId);
      expect(controller.config.groups.single.id, groupId);
      expect(controller.config.groups.single.label, 'My group');
    });

    test('ungroup clears groupId and removes the group entry', () {
      final controller = makeController(
        widgets: [instance('a', 'left', 0), instance('b', 'left', 1)],
      );
      final groupId = controller.createGroup(['a', 'b']);
      controller.ungroup(groupId);

      expect(controller.instanceFor('a')!.groupId, isNull);
      expect(controller.instanceFor('b')!.groupId, isNull);
      expect(controller.config.groups, isEmpty);
    });

    test('removing the last member of a group prunes the empty group', () {
      final controller = makeController(
        widgets: [instance('a', 'left', 0), instance('b', 'left', 1)],
      );
      final groupId = controller.createGroup(['a', 'b']);
      controller.removeInstance('a');
      controller.removeInstance('b');

      expect(
        controller.config.groups.where((g) => g.id == groupId),
        isEmpty,
      );
    });
  });

  group('replaceConfig', () {
    test('adopts widgets/columns/gap/groups from the replacement but keeps '
        'the active dashboard id', () {
      final controller = makeController(widgets: [instance('a', 'left', 0)]);

      controller.replaceConfig(
        DashboardConfig(
          id: 'unrelated-id',
          name: 'Replaced',
          columns: 3,
          gap: 24,
          widgets: [instance('b', 'right', 0)],
        ),
      );

      expect(controller.config.id, 'test'); // conserva la id activa
      expect(controller.config.name, 'Replaced');
      expect(controller.config.columns, 3);
      expect(controller.config.gap, 24);
      expect(controller.widgetsInRegion('left'), isEmpty);
      expect(controller.widgetsInRegion('right').single.instanceId, 'b');
    });

    test('disposes notifiers for instances no longer present after the '
        'replacement', () {
      final controller = makeController(widgets: [instance('a', 'left', 0)]);
      final listenable = controller.listenable('a');
      var sawNull = false;
      listenable.addListener(() {
        if (listenable.value == null) sawNull = true;
      });

      controller.replaceConfig(
        DashboardConfig(id: 'x', name: 'x', widgets: const []),
      );

      expect(sawNull, isTrue);
      expect(controller.instanceFor('a'), isNull);
    });

    test('notifies listeners and schedules persistence', () async {
      final controller = makeController(debounce: const Duration(milliseconds: 30));
      var notified = false;
      controller.addListener(() => notified = true);

      controller.replaceConfig(
        DashboardConfig(id: 'x', name: 'Replaced', widgets: const []),
      );
      expect(notified, isTrue);

      await Future<void>.delayed(const Duration(milliseconds: 60));
      final saved = await store.loadDashboard('test');
      expect(saved!.name, 'Replaced');
    });

    test('preserves responsiveOverrides from the replacement (Fase 30 bug '
        'fix — it used to be silently dropped)', () {
      final controller = makeController();
      controller.replaceConfig(
        DashboardConfig(
          id: 'x',
          name: 'x',
          widgets: const [],
          responsiveOverrides: {
            'mobile': DashboardConfig(id: 'x-mobile', name: 'mobile'),
          },
        ),
      );
      expect(controller.config.responsiveOverrides, isNotNull);
      expect(controller.config.responsiveOverrides!.containsKey('mobile'), isTrue);
    });
  });

  group('switchToTemplate (Fase 30)', () {
    test('installs and persists the default template on first switch', () async {
      final controller = makeController(debounce: const Duration(minutes: 10));
      final template = DashboardConfig(
        id: 'template-x',
        name: 'Template X',
        widgets: [instance('t1', 'left', 0)],
      );

      await controller.switchToTemplate('template-x', template);

      expect(controller.config.id, 'template-x');
      expect(controller.widgetsInRegion('left').single.instanceId, 't1');
      final saved = await store.loadDashboard('template-x');
      expect(saved, isNotNull);
    });

    test('a second switch to the same template loads the persisted '
        '(possibly user-edited) version instead of resetting to default', () async {
      final controller = makeController(debounce: const Duration(minutes: 10));
      final template = DashboardConfig(
        id: 'template-x',
        name: 'Template X',
        widgets: [instance('t1', 'left', 0)],
      );
      await controller.switchToTemplate('template-x', template);

      // El usuario edita la plantilla ya instalada.
      controller.resizeInstance('t1', width: 500);
      await controller.persist();

      // Cambia a otro dashboard y vuelve — debe conservar la edición.
      await controller.switchToTemplate(
        'template-y',
        DashboardConfig(id: 'template-y', name: 'Y'),
      );
      await controller.switchToTemplate('template-x', template);

      expect(controller.instanceFor('t1')!.width, 500);
    });

    test('notifies listeners on switch', () async {
      final controller = makeController(debounce: const Duration(minutes: 10));
      var notified = false;
      controller.addListener(() => notified = true);

      await controller.switchToTemplate(
        'template-x',
        DashboardConfig(id: 'template-x', name: 'X'),
      );

      expect(notified, isTrue);
    });
  });

  group('persistence', () {
    test('persist() saves the current config to ConfigStore', () async {
      final controller = makeController(
        widgets: [instance('a', 'left', 0)],
      );
      controller.resizeInstance('a', width: 300);
      await controller.persist();

      final saved = await store.loadDashboard('test');
      expect(saved!.widgets.single.width, 300);
    });

    test('rapid mutations are debounced into a single write', () async {
      final controller = makeController(
        widgets: [instance('a', 'left', 0)],
        debounce: const Duration(milliseconds: 30),
      );

      controller.resizeInstance('a', width: 100);
      controller.resizeInstance('a', width: 200);
      controller.resizeInstance('a', width: 300);

      expect(await store.loadDashboard('test'), isNull);
      await Future<void>.delayed(const Duration(milliseconds: 60));

      final saved = await store.loadDashboard('test');
      expect(saved!.widgets.single.width, 300);
    });
  });

  group('listenable', () {
    test('only notifies for the targeted instance', () {
      final controller = makeController(
        widgets: [instance('a', 'left', 0), instance('b', 'left', 1)],
      );
      var aNotifications = 0;
      var bNotifications = 0;
      controller.listenable('a').addListener(() => aNotifications++);
      controller.listenable('b').addListener(() => bNotifications++);

      controller.resizeInstance('a', width: 300);

      expect(aNotifications, 1);
      expect(bNotifications, 0);
    });
  });
}
