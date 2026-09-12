import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:folio/config/config_store.dart';
import 'package:folio/config/config_store_backend_io.dart';
import 'package:folio/config/models/design_variables.dart';
import 'package:folio/theme_engine/design_tokens_defaults.dart';
import 'package:folio/theme_engine/design_variables_controller.dart';

void main() {
  late Directory tempDir;
  late ConfigStore store;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('folio_design_vars_test');
    ConfigStoreBackend.debugRootOverride = tempDir;
    store = await ConfigStore.open();
  });

  tearDown(() async {
    ConfigStoreBackend.debugRootOverride = null;
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  test('load() falls back to kFolioDefaultDesignVariables when nothing is '
      'persisted yet', () async {
    final controller = await DesignVariablesController.load(store);
    expect(controller.config.entries, kFolioDefaultDesignVariables.entries);
  });

  test('load() returns the persisted document when one exists', () async {
    await store.saveVariables(
      DesignVariables(id: 'default', entries: const {'foo': '@space.md'}),
    );
    final controller = await DesignVariablesController.load(store);
    expect(controller.config.entries, {'foo': '@space.md'});
  });

  test('setVariable adds or overwrites a single entry without touching '
      'the rest', () {
    final controller = DesignVariablesController(
      store,
      initialConfig: DesignVariables(entries: const {'a': '@space.md'}),
      persistDebounce: const Duration(minutes: 10),
    );
    controller.setVariable('b', '@radius.lg');
    expect(controller.config.entries, {'a': '@space.md', 'b': '@radius.lg'});

    controller.setVariable('a', '@space.lg');
    expect(controller.config.entries, {'a': '@space.lg', 'b': '@radius.lg'});
  });

  test('removeVariable deletes only the named entry', () {
    final controller = DesignVariablesController(
      store,
      initialConfig: DesignVariables(
        entries: const {'a': '@space.md', 'b': '@radius.lg'},
      ),
      persistDebounce: const Duration(minutes: 10),
    );
    controller.removeVariable('a');
    expect(controller.config.entries, {'b': '@radius.lg'});
  });

  test('mutations notify listeners and schedule persistence', () async {
    final controller = DesignVariablesController(
      store,
      initialConfig: DesignVariables(),
      persistDebounce: const Duration(milliseconds: 10),
    );
    var notified = false;
    controller.addListener(() => notified = true);

    controller.setVariable('a', '@space.md');
    expect(notified, isTrue);

    await Future<void>.delayed(const Duration(milliseconds: 50));
    final loaded = await store.loadVariables(controller.config.id);
    expect(loaded?.entries['a'], '@space.md');
  });
}
