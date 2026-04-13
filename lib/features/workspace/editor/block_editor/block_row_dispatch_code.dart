part of 'package:folio/features/workspace/editor/block_editor.dart';
// ignore_for_file: unused_local_variable


Widget? _specialRowCode(_BlockRowScope s) {
  if (s.block.type != 'code') return null;
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
                padding: const EdgeInsets.only(bottom: 8),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: MenuAnchor(
                    style: MenuStyle(
                      backgroundColor: WidgetStatePropertyAll(
                        scheme.surfaceContainerHigh,
                      ),
                      surfaceTintColor: const WidgetStatePropertyAll(
                        Colors.transparent,
                      ),
                      shadowColor: WidgetStatePropertyAll(
                        scheme.shadow.withValues(alpha: 0.14),
                      ),
                      elevation: const WidgetStatePropertyAll(8),
                      padding: const WidgetStatePropertyAll(
                        EdgeInsets.symmetric(vertical: 8),
                      ),
                      shape: WidgetStatePropertyAll(
                        RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                    menuChildren: [
                      for (final o in st._codeLanguageOptionsForBlock(block))
                        MenuItemButton(
                          leadingIcon: Icon(
                            iconForCodeLanguageOption(o),
                            size: 20,
                          ),
                          trailingIcon:
                              o.id == st._codeLangDropdownValue(block)
                              ? Icon(
                                  Icons.check_rounded,
                                  size: 20,
                                  color: scheme.primary,
                                )
                              : null,
                          onPressed: () {
                            st._onCodeLanguagePicked(
                              page.id,
                              block.id,
                              index,
                              o.id,
                            );
                          },
                          child: Text(o.label),
                        ),
                    ],
                    builder: (context, menuController, child) {
                      final id = st._codeLangDropdownValue(block);
                      final label = st._codeLangLabelForId(id);
                      final langIcon = codeLanguageIcon(id);
                      return Material(
                        color: scheme.surfaceContainerHighest.withValues(
                          alpha: 0.8,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () {
                            if (menuController.isOpen) {
                              menuController.close();
                            } else {
                              menuController.open();
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  langIcon,
                                  size: 20,
                                  color: scheme.primary,
                                ),
                                const SizedBox(width: 10),
                                Flexible(
                                  child: Text(
                                    label,
                                    style: theme.textTheme.labelLarge
                                        ?.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  size: 22,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
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
                      // flutter_code_editor no actualiza el FocusNode interno en didUpdateWidget;
                      // sin esta clave, al resincronizar controladores se reutiliza el State con un nodo ya disposed.
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
            ],
          ),
        ),
      ],
    ),
  );
}
