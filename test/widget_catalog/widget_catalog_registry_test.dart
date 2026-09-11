import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folio/config/models/widget_instance_config.dart';
import 'package:folio/widget_catalog/widget_catalog.dart';

class _FakePlugin extends FolioWidgetPlugin {
  const _FakePlugin(this.id);

  @override
  final String id;

  @override
  String displayName(BuildContext context) => id;

  @override
  IconData get icon => Icons.widgets;

  @override
  Widget build(
    BuildContext context,
    WidgetInstanceConfig instance,
    WidgetPluginContext ctx,
  ) => Text(id);
}

void main() {
  setUp(() => WidgetCatalogRegistry.instance.debugClear());
  tearDown(() => WidgetCatalogRegistry.instance.debugClear());

  test('register + lookup by id', () {
    final registry = WidgetCatalogRegistry.instance;
    registry.register(const _FakePlugin('clock'));

    expect(registry['clock']?.id, 'clock');
    expect(registry['missing'], isNull);
  });

  test('all returns every registered plugin', () {
    final registry = WidgetCatalogRegistry.instance;
    registry.register(const _FakePlugin('clock'));
    registry.register(const _FakePlugin('weather'));

    expect(registry.all.map((p) => p.id), containsAll(['clock', 'weather']));
    expect(registry.all, hasLength(2));
  });

  test('registering a duplicate id asserts in debug mode', () {
    final registry = WidgetCatalogRegistry.instance;
    registry.register(const _FakePlugin('clock'));

    expect(
      () => registry.register(const _FakePlugin('clock')),
      throwsA(isA<AssertionError>()),
    );
  });

  test('default sizeConstraints/allowMultipleInstances', () {
    const plugin = _FakePlugin('clock');
    expect(plugin.sizeConstraints.minWidth, 1);
    expect(plugin.sizeConstraints.minHeight, 1);
    expect(plugin.sizeConstraints.maxWidth, isNull);
    expect(plugin.allowMultipleInstances, isTrue);
  });

  testWidgets('default buildSettings returns null', (tester) async {
    const plugin = _FakePlugin('clock');
    await tester.pumpWidget(
      Builder(
        builder: (context) {
          final settings = plugin.buildSettings(
            context,
            WidgetInstanceConfig(
              instanceId: 'i1',
              pluginId: 'clock',
              regionId: 'left',
            ),
            (_) {},
          );
          expect(settings, isNull);
          return const SizedBox.shrink();
        },
      ),
    );
  });
}
