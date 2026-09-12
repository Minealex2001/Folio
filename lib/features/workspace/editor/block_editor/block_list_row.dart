part of 'package:folio/features/workspace/editor/block_editor.dart';

/// Fila de la lista de bloques con hover local: evita [setState] en todo el
/// [BlockEditor] al mover el ratón (véase plan de rendimiento del editor).
///
/// Fase F2 del rediseño UX del editor — microinteracciones cubiertas aquí:
/// fade+slide-in al crear (ver `_entranceController` en el State) y
/// crossfade al convertir el tipo (`AnimatedSwitcher` en `build`). El
/// fade+collapse-out al eliminar queda **fuera de alcance de v1**: esta
/// fila vive dentro de un `ReorderableListView.builder` cuyo `itemCount`
/// sigue `page.blocks.length` 1:1 — animar la salida requeriría retrasar la
/// mutación real (mantener el bloque "fantasma" en la lista mientras se
/// desvanece, en todos los call sites de borrado: menú "⋮", backspace al
/// fusionar, multi-selección, ungroup...) o migrar a un `AnimatedList`
/// manual. Deliberadamente pospuesto: el desplazamiento suave de las filas
/// vecinas (ya animado vía el `AnimatedContainer` de 120ms existente) da
/// suficiente continuidad visual sin ese rediseño.
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

class _BlockListRowState extends State<_BlockListRow>
    with SingleTickerProviderStateMixin {
  bool _hovered = false;
  bool _shouldFocusOnPointerUp = false;

  // Fase F2 del rediseño UX del editor — microinteracción de "crear": esta
  // fila hace fade+slide-in una única vez, al montar (initState solo corre
  // una vez por identidad de `State`, y cada bloque tiene una `Key` propia
  // vía `ValueKey('block_row_${b.id}')` en el `itemBuilder` — así que esto
  // dispara para bloques recién creados, no en cada rebuild por tecleo).
  late final AnimationController _entranceController;
  late final Animation<double> _entranceOpacity;
  late final Animation<Offset> _entranceOffset;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    final curved = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOut,
    );
    _entranceOpacity = curved;
    _entranceOffset = Tween<Offset>(
      begin: const Offset(0, -0.08),
      end: Offset.zero,
    ).animate(curved);
    _entranceController.forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

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

    final rowContent = MouseRegion(
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
            // Fase F2: crossfade al convertir el tipo del bloque (ej. "/"
            // párrafo -> heading) — misma curva/duración que el resto del
            // chrome (120ms, easeOut) en vez de un salto instantáneo. La
            // `ValueKey` es por tipo, no por bloque (la fila ya tiene su
            // propia identidad vía `KeyedSubtree` en el `itemBuilder`), así
            // que solo dispara cuando `block.type` cambia, nunca al teclear.
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 120),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              child: KeyedSubtree(
                key: ValueKey(widget.block.type),
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
        ),
      ),
    );
    return FadeTransition(
      opacity: _entranceOpacity,
      child: SlideTransition(position: _entranceOffset, child: rowContent),
    );
  }
}

