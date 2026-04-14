part of 'package:folio/features/workspace/editor/block_editor.dart';

/// Fila de la lista de bloques con hover local: evita [setState] en todo el
/// [BlockEditor] al mover el ratón (véase plan de rendimiento del editor).
class _BlockListRow extends StatefulWidget {
  const _BlockListRow({
    required this.editor,
    required this.readOnlyMode,
    required this.androidPhoneLayout,
    required this.scheme,
    required this.page,
    required this.block,
    required this.index,
    required this.ctrl,
    required this.focus,
    required this.style,
    required this.selected,
    required this.showActionsBaseline,
  });

  final BlockEditorState editor;
  final bool readOnlyMode;
  final bool androidPhoneLayout;
  final ColorScheme scheme;
  final FolioPage page;
  final FolioBlock block;
  final int index;
  final TextEditingController ctrl;
  final FocusNode focus;
  final TextStyle style;
  final bool selected;

  /// Sin contar hover: selección, foco, menú abierto, multiselección en escritorio.
  final bool showActionsBaseline;

  @override
  State<_BlockListRow> createState() => _BlockListRowState();
}

class _BlockListRowState extends State<_BlockListRow> {
  bool _hovered = false;
  bool _shouldFocusOnPointerUp = false;

  bool _hitTestHasInteractiveChild(Offset globalPosition) {
    final result = HitTestResult();
    // Flutter 3.11+: usar hitTestInView y especificar la vista.
    final viewId = View.of(context).viewId;
    WidgetsBinding.instance.hitTestInView(result, globalPosition, viewId);
    for (final entry in result.path) {
      final target = entry.target;
      if (target is RenderMetaData) {
        final tag = target.metaData;
        if (tag == folioLinkMetaDataTag || tag == folioInteractiveMetaDataTag) {
          return true;
        }
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final showActions =
        !widget.readOnlyMode && (_hovered || widget.showActionsBaseline);
    final showInlineEditControls =
        !widget.readOnlyMode &&
        (showActions || widget.selected || widget.focus.hasFocus);

    return MouseRegion(
      onEnter: (_) {
        if (!_hovered) setState(() => _hovered = true);
      },
      onExit: (_) {
        if (_hovered) setState(() => _hovered = false);
      },
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerUp: widget.readOnlyMode
            ? null
            : (_) {
                if (_shouldFocusOnPointerUp) {
                  _shouldFocusOnPointerUp = false;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    widget.focus.requestFocus();
                  });
                }
              },
        onPointerCancel: widget.readOnlyMode
            ? null
            : (_) {
                _shouldFocusOnPointerUp = false;
              },
        onPointerDown: widget.readOnlyMode
            ? null
            : (event) {
                _shouldFocusOnPointerUp = false;
                if (event.kind == PointerDeviceKind.mouse &&
                    event.buttons == kSecondaryMouseButton) {
                  unawaited(
                    widget.editor._showBlockContextMenuAtGlobal(
                      event.position,
                      context,
                      widget.page,
                      widget.block,
                      widget.index,
                    ),
                  );
                  return;
                }
                // En touch/stylus `buttons` puede venir como 0. Solo filtramos
                // explícitamente por "no-primary" cuando es ratón.
                if (event.kind == PointerDeviceKind.mouse &&
                    (event.buttons & kPrimaryButton) == 0) {
                  return;
                }
                final onInteractive =
                    _hitTestHasInteractiveChild(event.position);
                if (onInteractive) {
                  return;
                }
                if (HardwareKeyboard.instance.isShiftPressed ||
                    widget.editor._isAdditiveSelectionPressed) {
                  widget.editor._handleBlockSelection(
                    widget.page,
                    widget.block.id,
                    focusNode: widget.focus,
                  );
                  return;
                }
                widget.editor._handleBlockSelection(
                  widget.page,
                  widget.block.id,
                  focusNode: widget.focus,
                  requestFocus: true,
                );
              },
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onPanStart: widget.readOnlyMode
              ? null
              : (_) => widget.editor._beginDragSelection(
                  widget.page,
                  widget.block.id,
                  focusNode: widget.focus,
                ),
          onPanUpdate: widget.readOnlyMode
              ? null
              : (_) => widget.editor._updateDragSelection(
                    widget.page,
                    widget.block.id,
                  ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            margin: EdgeInsets.only(bottom: widget.androidPhoneLayout ? 6 : 1),
            decoration: BoxDecoration(
              color: widget.editor._blockRowFill(
                widget.scheme,
                widget.focus,
                widget.selected,
                _hovered,
              ),
              borderRadius: BorderRadius.circular(
                widget.androidPhoneLayout ? 14 : 6,
              ),
            ),
            child: widget.editor._buildBlockRow(
              context: context,
              scheme: widget.scheme,
              page: widget.page,
              block: widget.block,
              index: widget.index,
              ctrl: widget.ctrl,
              focus: widget.focus,
              style: widget.style,
              showActions: showActions,
              showInlineEditControls: showInlineEditControls,
            ),
          ),
        ),
      ),
    );
  }
}

