part of 'package:folio/features/workspace/editor/block_editor.dart';

/// Fase F3 del rediseño UX del editor — reducción de chrome más allá de
/// Zen mode (ítem 13 del brief): esta pista de atajos ("Enter: nueva
/// línea, /: comandos...") vivía siempre visible en la cabecera de cada
/// página, sin importar si el usuario ya la conocía o estaba enfocado
/// escribiendo. Extiende la misma convención "oculto hasta hover/focus" ya
/// usada a nivel de fila (`showActionsBaseline`/`_hovered` en
/// `block_list_row.dart`, `_blockMenuSlot`): permanece visible mientras
/// ningún bloque tiene foco (orientación útil antes de empezar a escribir)
/// y se atenúa en cuanto el usuario enfoca un bloque y se pone a escribir
/// — reaparece con un simple hover sobre su propia franja, para poder
/// consultarla sin perder el foco de escritura.
///
/// Estado de hover local (igual que `_BlockListRowState`): evita un
/// `setState` en todo `BlockEditorState` al mover el ratón.
class _EditorShortcutsHint extends StatefulWidget {
  const _EditorShortcutsHint({
    required this.text,
    required this.style,
    required this.hasFocusedBlock,
    required this.padding,
  });

  final String text;
  final TextStyle? style;
  final bool hasFocusedBlock;
  final EdgeInsetsGeometry padding;

  @override
  State<_EditorShortcutsHint> createState() => _EditorShortcutsHintState();
}

class _EditorShortcutsHintState extends State<_EditorShortcutsHint> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final visible = _hovered || !widget.hasFocusedBlock;
    return MouseRegion(
      onEnter: (_) {
        if (!_hovered) setState(() => _hovered = true);
      },
      onExit: (_) {
        if (_hovered) setState(() => _hovered = false);
      },
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: FolioMotion.short2,
        child: Padding(
          padding: widget.padding,
          child: Text(
            widget.text,
            textAlign: TextAlign.center,
            style: widget.style,
          ),
        ),
      ),
    );
  }
}
