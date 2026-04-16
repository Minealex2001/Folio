part of 'package:folio/features/workspace/editor/block_editor.dart';
// ignore_for_file: unused_local_variable

Widget? _specialRowDrive(_BlockRowScope s) {
  if (s.block.type != 'drive') return null;
  final st = s.st;
  final block = s.block;
  final menu = s.menu;
  final dragHandle = s.dragHandle;
  final marker = s.marker;
  final showActions = s.showActions;
  final context = s.context;
  final l10n = AppLocalizations.of(context);
  final data =
      FolioFileDriveData.tryParse(block.text) ?? FolioFileDriveData.defaults();
  final fileCount = data.entries.length;
  final folderCount = data.folders.length;
  return _specialRowChrome(
    st: st,
    block: block,
    menu: menu,
    dragHandle: dragHandle,
    marker: marker,
    showActions: showActions,
    child: Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: s.scheme.surfaceContainerHighest.withValues(alpha: 0.35),
      child: ListTile(
        leading: Icon(
          Icons.drive_folder_upload_rounded,
          color: s.scheme.primary,
        ),
        title: Text(l10n.driveBlockRowTitle),
        subtitle: Text(
          l10n.driveBlockRowSubtitle(fileCount, folderCount),
          style: s.theme.textTheme.bodySmall?.copyWith(
            color: s.scheme.onSurfaceVariant,
          ),
        ),
      ),
    ),
  );
}
