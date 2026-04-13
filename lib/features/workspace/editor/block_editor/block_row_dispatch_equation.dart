part of 'package:folio/features/workspace/editor/block_editor.dart';
// ignore_for_file: unused_local_variable


Widget? _specialRowEquation(_BlockRowScope s) {
  if (s.block.type != 'equation') return null;
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
  return Padding(
    padding: EdgeInsetsDirectional.fromSTEB(block.depth * 28.0, 2, 4, 2),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        st._blockMenuSlot(showActions: showActions, menu: menu),
        dragHandle,
        marker,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  'LaTeX',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: scheme.primary,
                  ),
                ),
              ),
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
                      minLines: 2,
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
              FolioEquationPreview(
                latex: block.text,
                textStyle: theme.textTheme.bodyLarge,
                scheme: scheme,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
