import 'package:flutter_test/flutter_test.dart';
import 'package:folio/visual_editor/selectable.dart';
import 'package:folio/visual_editor/visual_editor_controller.dart';

class _FakeSelectable implements Selectable {
  _FakeSelectable(this.id, {this.kind = SelectableKind.panel});

  @override
  final String id;
  @override
  final SelectableKind kind;

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
  test('editModeActive defaults to false, no selection', () {
    final controller = VisualEditorController();
    expect(controller.editModeActive, isFalse);
    expect(controller.selected, isNull);
  });

  test('toggling editModeActive on/off notifies listeners', () {
    final controller = VisualEditorController();
    var notifications = 0;
    controller.addListener(() => notifications++);

    controller.editModeActive = true;
    expect(controller.editModeActive, isTrue);
    expect(notifications, 1);

    controller.editModeActive = true; // sin cambio -> no notifica de nuevo
    expect(notifications, 1);
  });

  test('turning edit mode off clears the current selection', () {
    final controller = VisualEditorController();
    controller.editModeActive = true;
    controller.select(_FakeSelectable('a'));
    expect(controller.selected, isNotNull);

    controller.editModeActive = false;
    expect(controller.selected, isNull);
  });

  test('select/clearSelection update selected and notify', () {
    final controller = VisualEditorController();
    var notifications = 0;
    controller.addListener(() => notifications++);

    final selectable = _FakeSelectable('panel-a');
    controller.select(selectable);
    expect(controller.selected, selectable);
    expect(notifications, 1);

    controller.clearSelection();
    expect(controller.selected, isNull);
    expect(notifications, 2);
  });

  test('clearSelection is a no-op (no notify) when nothing is selected', () {
    final controller = VisualEditorController();
    var notifications = 0;
    controller.addListener(() => notifications++);

    controller.clearSelection();
    expect(notifications, 0);
  });

  test('isSelected matches by kind + id, not instance identity', () {
    final controller = VisualEditorController();
    controller.select(
      _FakeSelectable('a', kind: SelectableKind.widgetInstance),
    );

    expect(controller.isSelected(SelectableKind.widgetInstance, 'a'), isTrue);
    expect(controller.isSelected(SelectableKind.panel, 'a'), isFalse);
    expect(controller.isSelected(SelectableKind.widgetInstance, 'b'), isFalse);
  });
}
