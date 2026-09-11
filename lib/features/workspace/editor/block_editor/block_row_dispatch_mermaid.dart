part of 'package:folio/features/workspace/editor/block_editor.dart';
// ignore_for_file: unused_local_variable


Widget? _specialRowMermaid(_BlockRowScope s) {
  if (s.block.type != 'mermaid') return null;
  final st = s.st;
  final block = s.block;
  final page = s.page;
  final scheme = s.scheme;
  final theme = s.theme;
  final context = s.context;
  final ctrl = s.ctrl;
  final focus = s.focus;
  final marker = s.marker;
  final dragHandle = s.dragHandle;
  final menu = s.menu;
  final showActions = s.showActions;
  final showInlineEditControls = s.showInlineEditControls;
  final index = s.index;
  final readOnlyMode = s.readOnlyMode;
  final codeCtrl = ctrl as CodeController;
  final showSourceEditor =
      block.text.trim().isEmpty ||
      st._mermaidEditingSourceIds.contains(block.id);
  // Fase F1 del rediseño UX del editor: la etiqueta plana "Mermaid" pasa a
  // ser la cabecera de acento compartida (icono + chip), consistente con
  // code/database/meeting_note en vez de un texto suelto solo aquí.
  final accentTone = _blockAccentToneFor('mermaid')!;
  return Padding(
    padding: EdgeInsetsDirectional.fromSTEB(block.depth * 28.0, 2, 4, 2),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        st._blockMenuSlot(showActions: showActions, menu: menu),
        dragHandle,
        marker,
        Expanded(
          child: _blockAccentStripe(
            scheme,
            st._calloutPreset,
            accentTone,
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              _blockAccentHeader(
                context,
                scheme,
                st._calloutPreset,
                tone: accentTone,
                icon: _blockAccentIconFor('mermaid'),
                label: 'Mermaid',
              ),
              if (showSourceEditor) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CodeTheme(
                    data: folioCodeThemeData(theme),
                    child: ColoredBox(
                      color: scheme.surfaceContainerHighest.withValues(
                        alpha: 0.55,
                      ),
                      child: CodeField(
                        key: ObjectKey(focus),
                        controller: codeCtrl,
                        focusNode: focus,
                        readOnly: readOnlyMode,
                        minLines: 3,
                        maxLines: null,
                        wrap: true,
                        textStyle: st._styleFor('code', theme.textTheme),
                        decoration: const BoxDecoration(),
                        padding: const EdgeInsets.all(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                FolioMermaidPreview(source: block.text),
              ] else
                Focus(
                  focusNode: focus,
                  child: GestureDetector(
                    onTap: () => focus.requestFocus(),
                    behavior: HitTestBehavior.opaque,
                    child: FolioMermaidPreview(source: block.text),
                  ),
                ),
            ],
            ),
          ),
        ),
      ],
    ),
  );
}
