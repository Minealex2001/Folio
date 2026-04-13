part of 'package:folio/features/workspace/editor/block_editor.dart';

/// Contexto compartido para construir una fila de bloque (menú, asa, marcador, cuerpo).
class _BlockRowScope {
  const _BlockRowScope({
    required this.st,
    required this.context,
    required this.scheme,
    required this.theme,
    required this.page,
    required this.block,
    required this.index,
    required this.ctrl,
    required this.focus,
    required this.style,
    required this.showActions,
    required this.showInlineEditControls,
    required this.menu,
    required this.dragHandle,
    required this.marker,
    required this.androidPhoneLayout,
    required this.compactReadOnlyMobile,
  });

  final BlockEditorState st;
  final BuildContext context;
  final ColorScheme scheme;
  final ThemeData theme;
  final FolioPage page;
  final FolioBlock block;
  final int index;
  final TextEditingController ctrl;
  final FocusNode focus;
  final TextStyle style;
  final bool showActions;
  final bool showInlineEditControls;
  final PopupMenuButton<String> menu;
  final Widget dragHandle;
  final Widget marker;
  final bool androidPhoneLayout;
  final bool compactReadOnlyMobile;

  bool get readOnlyMode => st.widget.readOnlyMode;
  AppSettings get appSettings => st.widget.appSettings;
  FolioCloudEntitlementsController? get folioCloudEntitlements =>
      st.widget.folioCloudEntitlements;
}
