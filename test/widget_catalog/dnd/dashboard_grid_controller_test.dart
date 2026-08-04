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
