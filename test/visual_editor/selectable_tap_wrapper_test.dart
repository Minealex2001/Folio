import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folio/visual_editor/selectable.dart';
import 'package:folio/visual_editor/selectable_tap_wrapper.dart';
import 'package:folio/visual_editor/visual_editor_controller.dart';

class _FakeSelectable implements Selectable {
  _FakeSelectable(this.id);

  @override
  final String id;
  @override
  SelectableKind get kind => SelectableKind.panel;
  @override
  double? width;
  @override
  double? height;
  @override
  double? x;
  @override
  double? y;
  @override
  bool locked = false;
  @override
  int? colorArgb;
  @override
  double? opacity;
  @override
  double? cornerRadius;
  @override
  void setSize({double? width, double? height}) {}
  @override
  void setPosition({double? x, double? y}) {}
  @override
  void setColorArgb(int? argb) {}
  @override
  void setOpacity(double? opacity) {}
  @override
  void setCornerRadius(double? radius) {}
}

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('is a pure passthrough (no GestureDetector) when edit mode '
      'is inactive', (tester) async {
    final controller = VisualEditorController();
    await tester.pumpWidget(
      wrap(
        SelectableTapWrapper(
          controller: controller,
          selectable: _FakeSelectable('a'),
          child: const Text('content'),
        ),
      ),
    );

    expect(find.text('content'), findsOneWidget);
    expect(find.byType(GestureDetector), findsNothing);
  });

  testWidgets('tapping selects the element when edit mode is active', (
    tester,
  ) async {
    final controller = VisualEditorController()..editModeActive = true;
    final selectable = _FakeSelectable('a');

    await tester.pumpWidget(
      wrap(
        SelectableTapWrapper(
          controller: controller,
          selectable: selectable,
          child: const Text('content'),
        ),
      ),
    );

    expect(controller.selected, isNull);
    await tester.tap(find.text('content'));
    await tester.pump();

    expect(controller.selected, selectable);
  });

  testWidgets('selected element renders with a visible border', (
    tester,
  ) async {
    final controller = VisualEditorController()..editModeActive = true;
    final selectable = _FakeSelectable('a');
    controller.select(selectable);

    await tester.pumpWidget(
      wrap(
        SelectableTapWrapper(
          controller: controller,
          selectable: selectable,
          child: const Text('content'),
        ),
      ),
    );

    final container = tester.widget<Container>(find.byType(Container));
    final decoration = container.decoration as BoxDecoration;
    expect(decoration.border, isNotNull);
    expect(
      (decoration.border as Border).top.color,
      isNot(Colors.transparent),
    );
  });

  testWidgets('unselected element renders with a transparent border', (
    tester,
  ) async {
    final controller = VisualEditorController()..editModeActive = true;

    await tester.pumpWidget(
      wrap(
        SelectableTapWrapper(
          controller: controller,
          selectable: _FakeSelectable('a'),
          child: const Text('content'),
        ),
      ),
    );

    final container = tester.widget<Container>(find.byType(Container));
    final decoration = container.decoration as BoxDecoration;
    expect((decoration.border as Border).top.color, Colors.transparent);
  });
}
