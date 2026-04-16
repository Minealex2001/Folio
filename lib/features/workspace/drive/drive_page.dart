import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:super_clipboard/super_clipboard.dart';
import 'package:uuid/uuid.dart';

import '../../../app/app_settings.dart';
import '../../../app/ui_tokens.dart';
import '../../../app/widgets/folio_dialog.dart';
import '../../../data/vault_paths.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../models/block.dart';
import '../../../models/folio_drive_data.dart';
import '../../../models/folio_page.dart';
import '../../../session/vault_session.dart';

const _uuid = Uuid();

class DrivePage extends StatefulWidget {
  const DrivePage({
    super.key,
    required this.pageId,
    required this.session,
    required this.appSettings,
    required this.onOpenClassicEditor,
  });

  final String pageId;
  final VaultSession session;
  final AppSettings appSettings;
  final VoidCallback onOpenClassicEditor;

  @override
  State<DrivePage> createState() => _DrivePageState();
}

class _DrivePageState extends State<DrivePage> {
  FolioFileDriveData _data = FolioFileDriveData.defaults();
  String? _selectedFolderId; // null = root
  bool _uploading = false;
  Object? _selectedItem; // FolioDriveEntry | FolioDriveFolder | null
  bool _isDragHovering = false;
  final Set<String> _selectedEntryIds = {}; // multi-selection

  FolioPage? get _page =>
      widget.session.pages.where((p) => p.id == widget.pageId).firstOrNull;

  FolioBlock? get _driveBlock =>
      _page?.blocks.where((b) => b.type == 'drive').firstOrNull;

  @override
  void initState() {
    super.initState();
    widget.session.addListener(_onSession);
    _refresh();
  }

  @override
  void dispose() {
    widget.session.removeListener(_onSession);
    super.dispose();
  }

  void _onSession() => _refresh();

  void _refresh() {
    final block = _driveBlock;
    if (block == null) return;
    final parsed =
        FolioFileDriveData.tryParse(block.text) ??
        FolioFileDriveData.defaults();
    // If selected folder was deleted, reset to root.
    final folderStillExists =
        _selectedFolderId == null ||
        parsed.folders.any((f) => f.id == _selectedFolderId);
    // Reset selected item if it no longer exists.
    Object? newSelectedItem = _selectedItem;
    if (_selectedItem is FolioDriveEntry) {
      final id = (_selectedItem as FolioDriveEntry).id;
      if (!parsed.entries.any((e) => e.id == id)) newSelectedItem = null;
    } else if (_selectedItem is FolioDriveFolder) {
      final id = (_selectedItem as FolioDriveFolder).id;
      if (!parsed.folders.any((f) => f.id == id)) newSelectedItem = null;
    }
    setState(() {
      _data = parsed;
      if (!folderStillExists) _selectedFolderId = null;
      _selectedItem = newSelectedItem;
    });
  }

  void _persist(FolioFileDriveData data) {
    final block = _driveBlock;
    if (block == null) return;
    widget.session.setPageDriveData(widget.pageId, block.id, data);
  }

  // ── Acciones ──────────────────────────────────────────────────────────────

  Future<void> _uploadFile() async {
    final result = await FilePicker.pickFiles(
      allowMultiple: true,
      type: FileType.any,
    );
    if (result == null || result.files.isEmpty) return;
    if (!mounted) return;

    setState(() => _uploading = true);
    final importedPaths = <String>[];
    try {
      final newEntries = <FolioDriveEntry>[];
      for (final pf in result.files) {
        final srcPath = pf.path;
        if (srcPath == null) continue;
        final src = File(srcPath);
        final rel = await VaultPaths.importAttachmentFile(
          src,
          preserveExtension: true,
          preserveFileName: false,
        );
        final ft = folioDriveFileTypeFromExtension(p.basename(srcPath));
        newEntries.add(
          FolioDriveEntry(
            id: _uuid.v4(),
            name: p.basename(srcPath),
            url: rel,
            fileType: ft,
            folderId: _selectedFolderId,
            sizeBytes: src.existsSync() ? src.lengthSync() : null,
            addedAtMs: DateTime.now().millisecondsSinceEpoch,
          ),
        );
        importedPaths.add(srcPath);
      }
      if (newEntries.isNotEmpty) {
        _persist(_data.copyWith(entries: [..._data.entries, ...newEntries]));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
    if (importedPaths.isNotEmpty &&
        widget.appSettings.driveDeleteOriginalsOnUpload) {
      for (final path in importedPaths) {
        try {
          final f = File(path);
          if (f.existsSync()) f.deleteSync();
        } catch (_) {}
      }
    }
  }

  void _createFolder() {
    final l10n = AppLocalizations.of(context);
    var text = '';
    showDialog<String?>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setSt) => FolioDialog(
          title: Text(l10n.driveNewFolder),
          content: SizedBox(
            width: 400,
            child: TextFormField(
              initialValue: text,
              autofocus: true,
              decoration: InputDecoration(
                labelText: l10n.driveNewFolder,
                border: const OutlineInputBorder(),
              ),
              onChanged: (v) => text = v,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx2).pop<String?>(null),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx2).pop<String?>(text),
              child: const Text('OK'),
            ),
          ],
        ),
      ),
    ).then((name) {
      if (name == null) return;
      final trimmed = name.trim();
      if (trimmed.isEmpty) return;
      final folder = FolioDriveFolder(
        id: _uuid.v4(),
        name: trimmed,
        parentId: _selectedFolderId,
      );
      _persist(_data.copyWith(folders: [..._data.folders, folder]));
    });
  }

  void _renameFolder(FolioDriveFolder folder) {
    final l10n = AppLocalizations.of(context);
    var text = folder.name;
    showDialog<String?>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setSt) => FolioDialog(
          title: Text(l10n.driveNewFolder),
          content: SizedBox(
            width: 400,
            child: TextFormField(
              initialValue: text,
              autofocus: true,
              decoration: InputDecoration(
                labelText: l10n.driveNewFolder,
                border: const OutlineInputBorder(),
              ),
              onChanged: (v) => text = v,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx2).pop<String?>(null),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx2).pop<String?>(text),
              child: const Text('OK'),
            ),
          ],
        ),
      ),
    ).then((name) {
      if (name == null) return;
      final trimmed = name.trim();
      if (trimmed.isEmpty) return;
      _persist(
        _data.copyWith(
          folders: [
            for (final f in _data.folders)
              f.id == folder.id ? f.copyWith(name: trimmed) : f,
          ],
        ),
      );
    });
  }

  void _deleteFolder(FolioDriveFolder folder) {
    // Collect all descendant folder IDs (BFS).
    final toDelete = <String>{folder.id};
    bool changed = true;
    while (changed) {
      changed = false;
      for (final f in _data.folders) {
        if (f.parentId != null &&
            toDelete.contains(f.parentId) &&
            !toDelete.contains(f.id)) {
          toDelete.add(f.id);
          changed = true;
        }
      }
    }
    // Move files from deleted folders to root (don't delete the actual files).
    final updatedEntries = _data.entries
        .map(
          (e) => toDelete.contains(e.folderId) ? e.copyWith(folderId: null) : e,
        )
        .toList();
    _persist(
      _data.copyWith(
        folders: _data.folders.where((f) => !toDelete.contains(f.id)).toList(),
        entries: updatedEntries,
      ),
    );
    if (_selectedFolderId != null && toDelete.contains(_selectedFolderId)) {
      setState(() => _selectedFolderId = null);
    }
  }

  void _renameEntry(FolioDriveEntry entry) {
    final l10n = AppLocalizations.of(context);
    var text = entry.name;
    showDialog<String?>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setSt) => FolioDialog(
          title: Text(l10n.driveOpenFile),
          content: SizedBox(
            width: 400,
            child: TextFormField(
              initialValue: text,
              autofocus: true,
              decoration: InputDecoration(
                labelText: entry.name,
                border: const OutlineInputBorder(),
              ),
              onChanged: (v) => text = v,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx2).pop<String?>(null),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx2).pop<String?>(text),
              child: const Text('OK'),
            ),
          ],
        ),
      ),
    ).then((name) {
      if (name == null) return;
      final trimmed = name.trim();
      if (trimmed.isEmpty) return;
      _persist(
        _data.copyWith(
          entries: [
            for (final e in _data.entries)
              e.id == entry.id ? e.copyWith(name: trimmed) : e,
          ],
        ),
      );
    });
  }

  void _deleteEntry(FolioDriveEntry entry) {
    final l10n = AppLocalizations.of(context);
    showDialog<bool?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.driveDeleteConfirm),
        content: Text(entry.name),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop<bool?>(null),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop<bool?>(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    ).then((confirmed) {
      if (confirmed != true) return;
      _persist(
        _data.copyWith(
          entries: _data.entries.where((e) => e.id != entry.id).toList(),
        ),
      );
    });
  }

  void _moveEntryToFolder(FolioDriveEntry entry, String? folderId) {
    // If the dragged entry is part of a multi-selection, move all selected.
    if (_selectedEntryIds.contains(entry.id) && _selectedEntryIds.length > 1) {
      _moveSelectedEntriesToFolder(folderId);
      return;
    }
    _persist(
      _data.copyWith(
        entries: [
          for (final e in _data.entries)
            e.id == entry.id ? e.copyWith(folderId: folderId) : e,
        ],
      ),
    );
  }

  void _moveFolderToFolder(FolioDriveFolder folder, String? newParentId) {
    if (_data.wouldCreateCycle(folder.id, newParentId)) return;
    _persist(
      _data.copyWith(
        folders: [
          for (final f in _data.folders)
            f.id == folder.id ? f.copyWith(parentId: newParentId) : f,
        ],
      ),
    );
  }

  void _toggleEntrySelection(FolioDriveEntry entry) {
    setState(() {
      if (_selectedEntryIds.contains(entry.id)) {
        _selectedEntryIds.remove(entry.id);
      } else {
        _selectedEntryIds.add(entry.id);
      }
      _selectedItem = null;
    });
  }

  void _clearEntrySelection() {
    if (_selectedEntryIds.isNotEmpty) setState(() => _selectedEntryIds.clear());
  }

  void _setMultiSelection(Set<String> ids) {
    setState(() {
      _selectedEntryIds
        ..clear()
        ..addAll(ids);
      if (ids.isNotEmpty) _selectedItem = null;
    });
  }

  void _moveSelectedEntriesToFolder(String? folderId) {
    final ids = Set<String>.from(_selectedEntryIds);
    _persist(
      _data.copyWith(
        entries: [
          for (final e in _data.entries)
            ids.contains(e.id) ? e.copyWith(folderId: folderId) : e,
        ],
      ),
    );
    setState(() => _selectedEntryIds.clear());
  }

  Future<void> _exportEntry(FolioDriveEntry entry) async {
    final vault = await VaultPaths.vaultDirectory();
    final url = entry.url;
    final File srcFile;
    if (url.startsWith('attachments/')) {
      final full = p.join(vault.path, url.replaceAll('/', p.separator));
      srcFile = File(full);
    } else {
      srcFile = File(url);
    }
    if (!srcFile.existsSync()) return;
    final destDir = await FilePicker.getDirectoryPath(
      dialogTitle: 'Export "${entry.name}" to…',
    );
    if (destDir == null || !mounted) return;
    final destPath = p.join(destDir, entry.name);
    await srcFile.copy(destPath);
    _persist(
      _data.copyWith(
        entries: _data.entries.where((e) => e.id != entry.id).toList(),
      ),
    );
    if (mounted) {
      setState(() {
        if (_selectedItem == entry) _selectedItem = null;
        _selectedEntryIds.remove(entry.id);
      });
    }
  }

  Future<void> _openEntry(FolioDriveEntry entry) async {
    final vault = await VaultPaths.vaultDirectory();
    final url = entry.url;
    File? resolved;
    if (url.startsWith('attachments/')) {
      final full = p.join(vault.path, url.replaceAll('/', p.separator));
      final f = File(full);
      if (f.existsSync()) resolved = f;
    } else {
      final f = File(url);
      if (f.existsSync()) resolved = f;
    }

    if (!mounted) return;
    if (entry.fileType == FolioDriveFileType.image && resolved != null) {
      _showImageViewer(resolved, entry.name);
    } else if (resolved != null) {
      _openWithSystem(resolved.path);
    }
  }

  void _showImageViewer(File file, String name) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black87,
        insetPadding: const EdgeInsets.all(FolioSpace.sm),
        child: Stack(
          children: [
            InteractiveViewer(child: Image.file(file, fit: BoxFit.contain)),
            Positioned(
              top: FolioSpace.xs,
              right: FolioSpace.xs,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openWithSystem(String path) {
    // Open with the OS default application.
    final uri = Uri.file(path);
    // url_launcher equivalent without dependency — use Process.
    if (Platform.isWindows) {
      Process.run('explorer', [path]);
    } else if (Platform.isMacOS) {
      Process.run('open', [path]);
    } else if (Platform.isLinux) {
      Process.run('xdg-open', [path]);
    } else {
      // iOS/Android: show path (no direct file open from here).
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(uri.toString())));
    }
  }

  Future<void> _importFromVault() async {
    final l10n = AppLocalizations.of(context);
    const fileBlockTypes = {'file', 'image', 'video', 'audio'};
    final candidates = <_VaultFileCandidate>[];
    for (final page in widget.session.pages) {
      for (final block in page.blocks) {
        if (!fileBlockTypes.contains(block.type)) continue;
        // Images store their path/URL in block.text; other media types use block.url.
        final url = block.type == 'image'
            ? block.text.trim()
            : (block.url ?? '').trim();
        if (url.isEmpty) continue;
        // Skip if already imported.
        if (_data.entries.any(
          (e) => e.sourcePageId == page.id && e.sourceBlockId == block.id,
        )) {
          continue;
        }
        candidates.add(
          _VaultFileCandidate(
            pageName: page.title.isNotEmpty
                ? page.title
                : '(${l10n.driveImportFromVault})',
            block: block,
            pageId: page.id,
          ),
        );
      }
    }
    if (!mounted) return;
    if (candidates.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.driveFolderEmpty)));
      return;
    }
    final selected = await showDialog<List<_VaultFileCandidate>>(
      context: context,
      builder: (ctx) => _VaultImportDialog(candidates: candidates, l10n: l10n),
    );
    if (selected == null || selected.isEmpty) return;
    final newEntries = selected.map((c) {
      // Images store their path/URL in block.text; other media types use block.url.
      final url = c.block.type == 'image'
          ? c.block.text.trim()
          : (c.block.url ?? '').trim();
      final name = url.split('/').last;
      final ft = folioDriveFileTypeFromName(
        c.block.type == 'image'
            ? 'image'
            : c.block.type == 'video'
            ? 'video'
            : c.block.type == 'audio'
            ? 'audio'
            : null,
      );
      return FolioDriveEntry(
        id: _uuid.v4(),
        name: name.isNotEmpty ? name : url.split('/').last,
        url: url,
        fileType: ft,
        folderId: _selectedFolderId,
        addedAtMs: DateTime.now().millisecondsSinceEpoch,
        sourcePageId: c.pageId,
        sourceBlockId: c.block.id,
      );
    }).toList();
    _persist(_data.copyWith(entries: [..._data.entries, ...newEntries]));
  }

  void _changeFolderColor(FolioDriveFolder folder, int? colorValue) {
    _persist(
      _data.copyWith(
        folders: [
          for (final f in _data.folders)
            f.id == folder.id ? f.copyWith(colorValue: colorValue) : f,
        ],
      ),
    );
  }

  Future<void> _importExternalFiles(List<XFile> files) async {
    if (files.isEmpty) return;
    setState(() => _uploading = true);
    final importedPaths = <String>[];
    try {
      final newEntries = <FolioDriveEntry>[];
      for (final xf in files) {
        final src = File(xf.path);
        if (!src.existsSync()) continue;
        final rel = await VaultPaths.importAttachmentFile(
          src,
          preserveExtension: true,
          preserveFileName: false,
        );
        final ft = folioDriveFileTypeFromExtension(p.basename(xf.path));
        newEntries.add(
          FolioDriveEntry(
            id: _uuid.v4(),
            name: p.basename(xf.path),
            url: rel,
            fileType: ft,
            folderId: _selectedFolderId,
            sizeBytes: src.statSync().size,
            addedAtMs: DateTime.now().millisecondsSinceEpoch,
          ),
        );
        importedPaths.add(xf.path);
      }
      if (newEntries.isNotEmpty) {
        _persist(_data.copyWith(entries: [..._data.entries, ...newEntries]));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
    if (importedPaths.isNotEmpty &&
        widget.appSettings.driveDeleteOriginalsOnUpload) {
      for (final path in importedPaths) {
        try {
          final f = File(path);
          if (f.existsSync()) f.deleteSync();
        } catch (_) {}
      }
    }
  }

  Future<void> _pasteFromClipboard() async {
    if (!Platform.isWindows && !Platform.isMacOS && !Platform.isLinux) return;
    final clipboard = SystemClipboard.instance;
    if (clipboard == null) return;
    final reader = await clipboard.read();
    final uris = <Uri>[];
    if (reader.canProvide(Formats.fileUri)) {
      final completer = <Uri>[];
      reader.getValue<Uri>(Formats.fileUri, (uri) {
        if (uri != null) completer.add(uri);
      });
      await Future<void>.delayed(const Duration(milliseconds: 80));
      uris.addAll(completer);
    }
    if (uris.isNotEmpty && mounted) {
      final xfiles = uris.map((u) => XFile(u.toFilePath())).toList();
      await _importExternalFiles(xfiles);
    }
  }

  void _toggleViewType() {
    final newType = _data.viewType == FolioDriveViewType.grid
        ? FolioDriveViewType.list
        : FolioDriveViewType.grid;
    _persist(_data.copyWith(viewType: newType));
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final page = _page;
    if (page == null) return const SizedBox.shrink();
    // Warn if multiple drive blocks.
    final driveBlockCount = page.blocks.where((b) => b.type == 'drive').length;
    final isDesktop =
        Platform.isWindows || Platform.isMacOS || Platform.isLinux;

    Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (driveBlockCount > 1)
          MaterialBanner(
            content: Text(l10n.driveMultipleBlocksSnack),
            actions: [
              TextButton(
                onPressed: widget.onOpenClassicEditor,
                child: Text(l10n.driveEditBlock),
              ),
            ],
          ),
        _DriveToolbar(
          data: _data,
          uploading: _uploading,
          onUpload: _uploadFile,
          onNewFolder: _createFolder,
          onImport: _importFromVault,
          onToggleView: _toggleViewType,
          onOpenEditor: widget.onOpenClassicEditor,
          l10n: l10n,
          scheme: scheme,
          theme: theme,
        ),
        const Divider(height: 1),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Folder tree sidebar.
              SizedBox(
                width: 220,
                child: _FolderTree(
                  data: _data,
                  selectedFolderId: _selectedFolderId,
                  onSelectFolder: (id) => setState(() {
                    _selectedFolderId = id;
                    _selectedItem = null;
                  }),
                  onCreateFolder: _createFolder,
                  onRenameFolder: _renameFolder,
                  onDeleteFolder: _deleteFolder,
                  onMoveFolder: _moveFolderToFolder,
                  onMoveEntryToFolder: _moveEntryToFolder,
                  onChangeColor: _changeFolderColor,
                  l10n: l10n,
                  scheme: scheme,
                  theme: theme,
                ),
              ),
              const VerticalDivider(width: 1),
              // Main area: breadcrumb + file area.
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _BreadcrumbBar(
                      data: _data,
                      selectedFolderId: _selectedFolderId,
                      onNavigate: (id) => setState(() {
                        _selectedFolderId = id;
                        _selectedItem = null;
                      }),
                      scheme: scheme,
                      theme: theme,
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: Stack(
                        children: [
                          _FileArea(
                            data: _data,
                            selectedFolderId: _selectedFolderId,
                            selectedItem: _selectedItem,
                            selectedEntryIds: _selectedEntryIds,
                            onSelectFolder: (id) => setState(() {
                              _selectedFolderId = id;
                              _selectedItem = null;
                              _selectedEntryIds.clear();
                            }),
                            onSelectItem: (item) =>
                                setState(() => _selectedItem = item),
                            onToggleSelectEntry: _toggleEntrySelection,
                            onClearMultiSelect: _clearEntrySelection,
                            onSetMultiSelection: _setMultiSelection,
                            onMoveSelectedEntries: _moveSelectedEntriesToFolder,
                            onRenameFolder: _renameFolder,
                            onDeleteFolder: _deleteFolder,
                            onChangeColor: _changeFolderColor,
                            onOpen: _openEntry,
                            onRename: _renameEntry,
                            onDelete: _deleteEntry,
                            onMoveEntry: _moveEntryToFolder,
                            onExportEntry: _exportEntry,
                            l10n: l10n,
                            scheme: scheme,
                            theme: theme,
                          ),
                          if (_isDragHovering) const _DragOverlay(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Details panel.
              AnimatedSize(
                duration: FolioMotion.medium1,
                curve: Curves.easeInOut,
                child: _selectedItem != null
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const VerticalDivider(width: 1),
                          SizedBox(
                            width: 280,
                            child: _DriveDetailsPanel(
                              selectedItem: _selectedItem!,
                              data: _data,
                              onClose: () =>
                                  setState(() => _selectedItem = null),
                              onOpen: _openEntry,
                              onRename: (item) {
                                if (item is FolioDriveEntry) {
                                  _renameEntry(item);
                                }
                                if (item is FolioDriveFolder) {
                                  _renameFolder(item);
                                }
                              },
                              onDelete: (item) {
                                if (item is FolioDriveEntry) {
                                  _deleteEntry(item);
                                }
                                if (item is FolioDriveFolder) {
                                  _deleteFolder(item);
                                }
                              },
                              onMoveEntry: _moveEntryToFolder,
                              onExportEntry: _exportEntry,
                              onChangeColor: _changeFolderColor,
                              scheme: scheme,
                              theme: theme,
                              l10n: l10n,
                            ),
                          ),
                        ],
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ],
    );

    // Wrap with keyboard shortcut for paste.
    if (isDesktop) {
      content = Focus(
        autofocus: true,
        child: CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.keyV, control: true):
                _pasteFromClipboard,
          },
          child: content,
        ),
      );
    }

    // Wrap with OS drop target.
    if (isDesktop) {
      content = DropTarget(
        onDragEntered: (_) => setState(() => _isDragHovering = true),
        onDragExited: (_) => setState(() => _isDragHovering = false),
        onDragDone: (details) {
          setState(() => _isDragHovering = false);
          _importExternalFiles(details.files);
        },
        child: content,
      );
    }

    return content;
  }
}

// ── Toolbar ───────────────────────────────────────────────────────────────────

class _DriveToolbar extends StatelessWidget {
  const _DriveToolbar({
    required this.data,
    required this.uploading,
    required this.onUpload,
    required this.onNewFolder,
    required this.onImport,
    required this.onToggleView,
    required this.onOpenEditor,
    required this.l10n,
    required this.scheme,
    required this.theme,
  });

  final FolioFileDriveData data;
  final bool uploading;
  final VoidCallback onUpload;
  final VoidCallback onNewFolder;
  final VoidCallback onImport;
  final VoidCallback onToggleView;
  final VoidCallback onOpenEditor;
  final AppLocalizations l10n;
  final ColorScheme scheme;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: FolioSpace.sm,
        vertical: FolioSpace.xxs,
      ),
      child: Row(
        children: [
          if (uploading)
            const Padding(
              padding: EdgeInsets.only(right: FolioSpace.xs),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          FilledButton.tonalIcon(
            onPressed: uploading ? null : onUpload,
            icon: const Icon(Icons.upload_rounded, size: 18),
            label: Text(l10n.driveUploadFile),
            style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
          ),
          const SizedBox(width: FolioSpace.xxs),
          TextButton.icon(
            onPressed: onNewFolder,
            icon: const Icon(Icons.create_new_folder_outlined, size: 18),
            label: Text(l10n.driveNewFolder),
            style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
          ),
          const SizedBox(width: FolioSpace.xxs),
          TextButton.icon(
            onPressed: onImport,
            icon: const Icon(Icons.link_rounded, size: 18),
            label: Text(l10n.driveImportFromVault),
            style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
          ),
          const Spacer(),
          IconButton(
            icon: Icon(
              data.viewType == FolioDriveViewType.grid
                  ? Icons.view_list_rounded
                  : Icons.grid_view_rounded,
              size: 20,
            ),
            tooltip: data.viewType == FolioDriveViewType.grid
                ? l10n.driveViewList
                : l10n.driveViewGrid,
            onPressed: onToggleView,
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            icon: const Icon(Icons.edit_note_rounded, size: 20),
            tooltip: l10n.driveEditBlock,
            onPressed: onOpenEditor,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

// ── Folder tree ───────────────────────────────────────────────────────────────

class _FolderTree extends StatelessWidget {
  const _FolderTree({
    required this.data,
    required this.selectedFolderId,
    required this.onSelectFolder,
    required this.onCreateFolder,
    required this.onRenameFolder,
    required this.onDeleteFolder,
    required this.onMoveFolder,
    required this.onMoveEntryToFolder,
    required this.onChangeColor,
    required this.l10n,
    required this.scheme,
    required this.theme,
  });

  final FolioFileDriveData data;
  final String? selectedFolderId;
  final ValueChanged<String?> onSelectFolder;
  final VoidCallback onCreateFolder;
  final ValueChanged<FolioDriveFolder> onRenameFolder;
  final ValueChanged<FolioDriveFolder> onDeleteFolder;
  final void Function(FolioDriveFolder folder, String? newParentId)
  onMoveFolder;
  final void Function(FolioDriveEntry entry, String? folderId)
  onMoveEntryToFolder;
  final void Function(FolioDriveFolder, int?) onChangeColor;
  final AppLocalizations l10n;
  final ColorScheme scheme;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final rootFolders = data.folders.where((f) => f.parentId == null).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // "All files" root item.
        _FolderTreeItem(
          label: 'All files',
          labelOverride: null,
          icon: Icons.drive_folder_upload_rounded,
          isSelected: selectedFolderId == null,
          folderId: null,
          onTap: () => onSelectFolder(null),
          onMoveEntry: onMoveEntryToFolder,
          onMoveFolder: onMoveFolder,
          canAcceptCycle: (_) => true,
          l10n: l10n,
          scheme: scheme,
          theme: theme,
        ),
        const Divider(height: 1, indent: FolioSpace.xs),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: FolioSpace.md),
            children: [
              for (final folder in rootFolders)
                _FolderTreeItemRecursive(
                  folder: folder,
                  allFolders: data.folders,
                  selectedFolderId: selectedFolderId,
                  depth: 0,
                  onSelectFolder: onSelectFolder,
                  onRenameFolder: onRenameFolder,
                  onDeleteFolder: onDeleteFolder,
                  onMoveFolder: onMoveFolder,
                  onMoveEntry: onMoveEntryToFolder,
                  onChangeColor: onChangeColor,
                  data: data,
                  l10n: l10n,
                  scheme: scheme,
                  theme: theme,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// (removed unused constant)

class _FolderTreeItemRecursive extends StatelessWidget {
  const _FolderTreeItemRecursive({
    required this.folder,
    required this.allFolders,
    required this.selectedFolderId,
    required this.depth,
    required this.onSelectFolder,
    required this.onRenameFolder,
    required this.onDeleteFolder,
    required this.onMoveFolder,
    required this.onMoveEntry,
    required this.onChangeColor,
    required this.data,
    required this.l10n,
    required this.scheme,
    required this.theme,
  });

  final FolioDriveFolder folder;
  final List<FolioDriveFolder> allFolders;
  final String? selectedFolderId;
  final int depth;
  final ValueChanged<String?> onSelectFolder;
  final ValueChanged<FolioDriveFolder> onRenameFolder;
  final ValueChanged<FolioDriveFolder> onDeleteFolder;
  final void Function(FolioDriveFolder, String?) onMoveFolder;
  final void Function(FolioDriveEntry, String?) onMoveEntry;
  final void Function(FolioDriveFolder, int?) onChangeColor;
  final FolioFileDriveData data;
  final AppLocalizations l10n;
  final ColorScheme scheme;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final children = allFolders.where((f) => f.parentId == folder.id).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.only(left: depth * 12.0),
          child: Row(
            children: [
              Expanded(
                child: _FolderTreeItem(
                  label: folder.name,
                  icon: Icons.folder_rounded,
                  iconColor: folder.colorValue != null
                      ? Color(folder.colorValue!)
                      : null,
                  isSelected: selectedFolderId == folder.id,
                  folderId: folder.id,
                  onTap: () => onSelectFolder(folder.id),
                  onMoveEntry: onMoveEntry,
                  onMoveFolder: onMoveFolder,
                  canAcceptCycle: (f) =>
                      !data.wouldCreateCycle(f.id, folder.id),
                  l10n: l10n,
                  scheme: scheme,
                  theme: theme,
                ),
              ),
              _FolderContextMenuButton(
                folder: folder,
                onRename: onRenameFolder,
                onDelete: onDeleteFolder,
                onChangeColor: onChangeColor,
                l10n: l10n,
                scheme: scheme,
              ),
            ],
          ),
        ),
        for (final child in children)
          _FolderTreeItemRecursive(
            folder: child,
            allFolders: allFolders,
            selectedFolderId: selectedFolderId,
            depth: depth + 1,
            onSelectFolder: onSelectFolder,
            onRenameFolder: onRenameFolder,
            onDeleteFolder: onDeleteFolder,
            onMoveFolder: onMoveFolder,
            onMoveEntry: onMoveEntry,
            onChangeColor: onChangeColor,
            data: data,
            l10n: l10n,
            scheme: scheme,
            theme: theme,
          ),
      ],
    );
  }
}

class _FolderTreeItem extends StatelessWidget {
  const _FolderTreeItem({
    required this.label,
    this.labelOverride,
    required this.icon,
    this.iconColor,
    required this.isSelected,
    required this.folderId,
    required this.onTap,
    required this.onMoveEntry,
    required this.onMoveFolder,
    required this.canAcceptCycle,
    required this.l10n,
    required this.scheme,
    required this.theme,
  });

  final String label;
  final String? labelOverride;
  final IconData icon;
  final Color? iconColor;
  final bool isSelected;
  final String? folderId;
  final VoidCallback onTap;
  final void Function(FolioDriveEntry, String?) onMoveEntry;
  final void Function(FolioDriveFolder, String?) onMoveFolder;
  final bool Function(FolioDriveFolder) canAcceptCycle;
  final AppLocalizations l10n;
  final ColorScheme scheme;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return DragTarget<Object>(
      onWillAcceptWithDetails: (details) {
        if (details.data is FolioDriveEntry) return true;
        if (details.data is FolioDriveFolder) {
          return canAcceptCycle(details.data as FolioDriveFolder);
        }
        return false;
      },
      onAcceptWithDetails: (details) {
        if (details.data is FolioDriveEntry) {
          onMoveEntry(details.data as FolioDriveEntry, folderId);
        } else if (details.data is FolioDriveFolder) {
          onMoveFolder(details.data as FolioDriveFolder, folderId);
        }
      },
      builder: (ctx, candidates, rejected) {
        final highlight = candidates.isNotEmpty;
        return InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(FolioRadius.sm),
          child: AnimatedContainer(
            duration: FolioMotion.short1,
            decoration: BoxDecoration(
              color: highlight
                  ? scheme.primary.withValues(alpha: FolioAlpha.soft)
                  : isSelected
                  ? scheme.primary.withValues(alpha: FolioAlpha.faint)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(FolioRadius.sm),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: FolioSpace.xs,
              vertical: FolioSpace.xxs,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 16,
                  color:
                      iconColor ??
                      (isSelected ? scheme.primary : scheme.onSurfaceVariant),
                ),
                const SizedBox(width: FolioSpace.xxs),
                Expanded(
                  child: Text(
                    labelOverride ?? label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isSelected ? scheme.primary : scheme.onSurface,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _FolderContextMenuButton extends StatelessWidget {
  const _FolderContextMenuButton({
    required this.folder,
    required this.onRename,
    required this.onDelete,
    required this.onChangeColor,
    required this.l10n,
    required this.scheme,
  });

  final FolioDriveFolder folder;
  final ValueChanged<FolioDriveFolder> onRename;
  final ValueChanged<FolioDriveFolder> onDelete;
  final void Function(FolioDriveFolder, int?) onChangeColor;
  final AppLocalizations l10n;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, size: 16),
      iconSize: 16,
      itemBuilder: (_) => [
        PopupMenuItem(value: 'rename', child: const Text('Rename')),
        PopupMenuItem(value: 'color', child: const Text('Change color')),
        PopupMenuItem(value: 'delete', child: Text(l10n.driveDeleteConfirm)),
      ],
      onSelected: (v) {
        if (v == 'rename') onRename(folder);
        if (v == 'delete') onDelete(folder);
        if (v == 'color') {
          showDialog<void>(
            context: context,
            builder: (ctx) => _FolderColorPicker(
              folder: folder,
              onChangeColor: onChangeColor,
              scheme: scheme,
            ),
          );
        }
      },
    );
  }
}

// ── File area ─────────────────────────────────────────────────────────────────

class _FileArea extends StatefulWidget {
  const _FileArea({
    required this.data,
    required this.selectedFolderId,
    required this.selectedItem,
    required this.selectedEntryIds,
    required this.onSelectFolder,
    required this.onSelectItem,
    required this.onToggleSelectEntry,
    required this.onClearMultiSelect,
    required this.onSetMultiSelection,
    required this.onMoveSelectedEntries,
    required this.onRenameFolder,
    required this.onDeleteFolder,
    required this.onChangeColor,
    required this.onOpen,
    required this.onRename,
    required this.onDelete,
    required this.onMoveEntry,
    required this.onExportEntry,
    required this.l10n,
    required this.scheme,
    required this.theme,
  });

  final FolioFileDriveData data;
  final String? selectedFolderId;
  final Object? selectedItem;
  final Set<String> selectedEntryIds;
  final ValueChanged<String?> onSelectFolder;
  final ValueChanged<Object?> onSelectItem;
  final ValueChanged<FolioDriveEntry> onToggleSelectEntry;
  final VoidCallback onClearMultiSelect;
  final void Function(Set<String>) onSetMultiSelection;
  final void Function(String?) onMoveSelectedEntries;
  final ValueChanged<FolioDriveFolder> onRenameFolder;
  final ValueChanged<FolioDriveFolder> onDeleteFolder;
  final void Function(FolioDriveFolder, int?) onChangeColor;
  final ValueChanged<FolioDriveEntry> onOpen;
  final ValueChanged<FolioDriveEntry> onRename;
  final ValueChanged<FolioDriveEntry> onDelete;
  final void Function(FolioDriveEntry, String?) onMoveEntry;
  final ValueChanged<FolioDriveEntry> onExportEntry;
  final AppLocalizations l10n;
  final ColorScheme scheme;
  final ThemeData theme;

  @override
  State<_FileArea> createState() => _FileAreaState();
}

class _FileAreaState extends State<_FileArea> {
  // ── Rubber-band selection ──────────────────────────────────────────────────
  final Map<String, GlobalKey> _cardKeys = {};
  Offset? _rubberStartGlobal;
  Offset? _rubberCurrentGlobal;
  Offset? _rubberStartLocal;
  Offset? _rubberCurrentLocal;
  bool _rubberActive = false;

  GlobalKey _keyFor(String id) => _cardKeys.putIfAbsent(id, () => GlobalKey());

  @override
  void didUpdateWidget(_FileArea oldWidget) {
    super.didUpdateWidget(oldWidget);
    final entryIds = widget.data.entries.map((e) => e.id).toSet();
    _cardKeys.removeWhere((id, _) => !entryIds.contains(id));
  }

  bool _hitTestAnyCard(Offset globalPos) {
    for (final key in _cardKeys.values) {
      final box = key.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.attached) continue;
      if ((box.localToGlobal(Offset.zero) & box.size).contains(globalPos)) {
        return true;
      }
    }
    return false;
  }

  void _updateRubberSelection() {
    if (_rubberStartGlobal == null || _rubberCurrentGlobal == null) return;
    final globalRect = Rect.fromPoints(
      _rubberStartGlobal!,
      _rubberCurrentGlobal!,
    );
    final entries = widget.data.entries
        .where((e) => e.folderId == widget.selectedFolderId)
        .toList();
    final selected = <String>{};
    for (final entry in entries) {
      final key = _cardKeys[entry.id];
      if (key == null) continue;
      final box = key.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.attached) continue;
      final cardRect = box.localToGlobal(Offset.zero) & box.size;
      if (globalRect.overlaps(cardRect)) selected.add(entry.id);
    }
    widget.onSetMultiSelection(selected);
  }

  void _onPointerDown(PointerDownEvent e) {
    if (e.buttons != kPrimaryMouseButton) return;
    if (_hitTestAnyCard(e.position)) {
      return;
    }
    widget.onClearMultiSelect();
    setState(() {
      _rubberStartGlobal = e.position;
      _rubberCurrentGlobal = e.position;
      _rubberStartLocal = e.localPosition;
      _rubberCurrentLocal = e.localPosition;
      _rubberActive = false;
    });
  }

  void _onPointerMove(PointerMoveEvent e) {
    if (_rubberStartGlobal == null) return;
    final dist = (e.position - _rubberStartGlobal!).distance;
    setState(() {
      _rubberCurrentGlobal = e.position;
      _rubberCurrentLocal = e.localPosition;
      if (dist > 4) _rubberActive = true;
    });
    if (_rubberActive) _updateRubberSelection();
  }

  void _onPointerUp(PointerUpEvent e) {
    if (_rubberStartGlobal == null) return;
    setState(() {
      _rubberStartGlobal = null;
      _rubberCurrentGlobal = null;
      _rubberStartLocal = null;
      _rubberCurrentLocal = null;
      _rubberActive = false;
    });
  }

  Rect? get _rubberRectLocal {
    if (!_rubberActive ||
        _rubberStartLocal == null ||
        _rubberCurrentLocal == null) {
      return null;
    }
    return Rect.fromPoints(_rubberStartLocal!, _rubberCurrentLocal!);
  }

  @override
  Widget build(BuildContext context) {
    final subFolders = widget.data.folders
        .where((f) => f.parentId == widget.selectedFolderId)
        .toList();
    final entries = widget.data.entries
        .where((e) => e.folderId == widget.selectedFolderId)
        .toList();

    if (subFolders.isEmpty && entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.folder_open_rounded,
              size: 72,
              color: widget.scheme.onSurfaceVariant.withValues(
                alpha: FolioAlpha.soft,
              ),
            ),
            const SizedBox(height: FolioSpace.xs),
            Text(
              widget.l10n.driveFolderEmpty,
              style: widget.theme.textTheme.bodyMedium?.copyWith(
                color: widget.scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: FolioSpace.xxs),
            Text(
              'Drag files here or press Ctrl+V',
              style: widget.theme.textTheme.labelSmall?.copyWith(
                color: widget.scheme.onSurfaceVariant.withValues(
                  alpha: FolioAlpha.emphasis,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // ── Multi-select action bar ───────────────────────────────────────────────
    Widget? multiSelectBar;
    if (widget.selectedEntryIds.isNotEmpty) {
      multiSelectBar = Material(
        color: widget.scheme.primaryContainer,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: FolioSpace.sm,
            vertical: FolioSpace.xxs,
          ),
          child: Row(
            children: [
              Icon(
                Icons.check_circle_rounded,
                size: 18,
                color: widget.scheme.onPrimaryContainer,
              ),
              const SizedBox(width: FolioSpace.xxs),
              Text(
                '${widget.selectedEntryIds.length} selected',
                style: widget.theme.textTheme.labelMedium?.copyWith(
                  color: widget.scheme.onPrimaryContainer,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: widget.scheme.onPrimaryContainer,
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.drive_file_move_rounded, size: 16),
                label: const Text('Mover a…'),
                onPressed: () =>
                    _showMultiMoveDialog(context, widget.data.folders),
              ),
              const SizedBox(width: FolioSpace.xxs),
              TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: widget.scheme.onPrimaryContainer,
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.close_rounded, size: 16),
                label: const Text('Cancelar'),
                onPressed: widget.onClearMultiSelect,
              ),
            ],
          ),
        ),
      );
    }

    Widget content;

    if (widget.data.viewType == FolioDriveViewType.list) {
      // ── List view ─────────────────────────────────────────────────────────
      content = ListView.separated(
        padding: const EdgeInsets.all(FolioSpace.sm),
        itemCount:
            subFolders.length +
            entries.length +
            (subFolders.isNotEmpty && entries.isNotEmpty ? 1 : 0),
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (ctx, i) {
          if (i < subFolders.length) {
            final folder = subFolders[i];
            return _FolderListRow(
              folder: folder,
              data: widget.data,
              isSelected: widget.selectedItem == folder,
              onTap: () {
                widget.onClearMultiSelect();
                widget.onSelectItem(folder);
              },
              onDoubleTap: () => widget.onSelectFolder(folder.id),
              onRename: widget.onRenameFolder,
              onDelete: widget.onDeleteFolder,
              onChangeColor: widget.onChangeColor,
              onMoveEntry: widget.onMoveEntry,
              l10n: widget.l10n,
              scheme: widget.scheme,
              theme: widget.theme,
            );
          }
          // Spacer row between folders and files in list view.
          if (subFolders.isNotEmpty && i == subFolders.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: FolioSpace.sm,
                vertical: FolioSpace.xxs,
              ),
              child: Text(
                'Archivos',
                style: widget.theme.textTheme.labelSmall?.copyWith(
                  color: widget.scheme.onSurfaceVariant,
                  letterSpacing: 0.8,
                ),
              ),
            );
          }
          final entryIndex = subFolders.isNotEmpty
              ? i - subFolders.length - 1
              : i - subFolders.length;
          final entry = entries[entryIndex];
          final isMultiSelected = widget.selectedEntryIds.contains(entry.id);
          return _FileListRow(
            entry: entry,
            isSelected: widget.selectedItem == entry,
            isMultiSelected: isMultiSelected,
            multiSelectedCount: widget.selectedEntryIds.length,
            onTap: () {
              if (HardwareKeyboard.instance.isControlPressed) {
                widget.onToggleSelectEntry(entry);
              } else {
                widget.onClearMultiSelect();
                widget.onSelectItem(entry);
              }
            },
            onOpen: widget.onOpen,
            onRename: widget.onRename,
            onDelete: widget.onDelete,
            onMoveEntry: widget.onMoveEntry,
            onExportEntry: widget.onExportEntry,
            folders: widget.data.folders,
            l10n: widget.l10n,
            scheme: widget.scheme,
            theme: widget.theme,
          );
        },
      );
    } else {
      // ── Grid view: folders compact at top, files grid + rubber-band ────────
      final rubberRect = _rubberRectLocal;
      final scrollView = CustomScrollView(
        slivers: [
          if (subFolders.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  FolioSpace.sm,
                  FolioSpace.sm,
                  FolioSpace.sm,
                  FolioSpace.xxs,
                ),
                child: Text(
                  'Carpetas',
                  style: widget.theme.textTheme.labelSmall?.copyWith(
                    color: widget.scheme.onSurfaceVariant,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ),
            SliverList.builder(
              itemCount: subFolders.length,
              itemBuilder: (ctx, i) {
                final folder = subFolders[i];
                return _FolderListRow(
                  folder: folder,
                  data: widget.data,
                  isSelected: widget.selectedItem == folder,
                  onTap: () {
                    widget.onClearMultiSelect();
                    widget.onSelectItem(folder);
                  },
                  onDoubleTap: () => widget.onSelectFolder(folder.id),
                  onRename: widget.onRenameFolder,
                  onDelete: widget.onDeleteFolder,
                  onChangeColor: widget.onChangeColor,
                  onMoveEntry: widget.onMoveEntry,
                  l10n: widget.l10n,
                  scheme: widget.scheme,
                  theme: widget.theme,
                );
              },
            ),
            const SliverToBoxAdapter(child: Divider(height: 1)),
          ],
          if (entries.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  FolioSpace.sm,
                  FolioSpace.sm,
                  FolioSpace.sm,
                  FolioSpace.xxs,
                ),
                child: Text(
                  'Archivos',
                  style: widget.theme.textTheme.labelSmall?.copyWith(
                    color: widget.scheme.onSurfaceVariant,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                FolioSpace.sm,
                0,
                FolioSpace.sm,
                FolioSpace.sm,
              ),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 180,
                  mainAxisExtent: 200,
                  crossAxisSpacing: FolioSpace.xs,
                  mainAxisSpacing: FolioSpace.xs,
                ),
                delegate: SliverChildBuilderDelegate((ctx, i) {
                  final entry = entries[i];
                  final isMultiSelected = widget.selectedEntryIds.contains(
                    entry.id,
                  );
                  return _FileGridCard(
                    key: _keyFor(entry.id),
                    entry: entry,
                    isSelected: widget.selectedItem == entry,
                    isMultiSelected: isMultiSelected,
                    multiSelectedCount: widget.selectedEntryIds.length,
                    onTap: () {
                      if (HardwareKeyboard.instance.isControlPressed) {
                        widget.onToggleSelectEntry(entry);
                      } else {
                        widget.onClearMultiSelect();
                        widget.onSelectItem(entry);
                      }
                    },
                    onOpen: widget.onOpen,
                    onRename: widget.onRename,
                    onDelete: widget.onDelete,
                    onMoveEntry: widget.onMoveEntry,
                    onExportEntry: widget.onExportEntry,
                    folders: widget.data.folders,
                    l10n: widget.l10n,
                    scheme: widget.scheme,
                    theme: widget.theme,
                  );
                }, childCount: entries.length),
              ),
            ),
          ],
        ],
      );
      content = Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: _onPointerDown,
        onPointerMove: _onPointerMove,
        onPointerUp: _onPointerUp,
        child: Stack(
          children: [
            scrollView,
            if (rubberRect != null)
              IgnorePointer(
                child: CustomPaint(
                  painter: _RubberBandPainter(
                    rubberRect,
                    widget.scheme.primary,
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ?multiSelectBar,
        Expanded(child: content),
      ],
    );
  }

  void _showMultiMoveDialog(
    BuildContext context,
    List<FolioDriveFolder> folders,
  ) {
    showDialog<String?>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Mover a carpeta'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, ''),
            child: const Text('/ (raíz)'),
          ),
          for (final f in folders)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, f.id),
              child: Text(f.name),
            ),
        ],
      ),
    ).then((result) {
      if (result != null) {
        widget.onMoveSelectedEntries(result.isEmpty ? null : result);
      }
    });
  }
}

// ── Rubber-band selection painter ─────────────────────────────────────────────

class _RubberBandPainter extends CustomPainter {
  const _RubberBandPainter(this.rect, this.color);

  final Rect rect;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      rect,
      Paint()
        ..color = color.withValues(alpha: 0.12)
        ..style = PaintingStyle.fill,
    );
    canvas.drawRect(
      rect,
      Paint()
        ..color = color.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
  }

  @override
  bool shouldRepaint(_RubberBandPainter old) =>
      old.rect != rect || old.color != color;
}

// ── Folder list row ───────────────────────────────────────────────────────────

class _FolderListRow extends StatelessWidget {
  const _FolderListRow({
    required this.folder,
    required this.data,
    required this.isSelected,
    required this.onTap,
    required this.onDoubleTap,
    required this.onRename,
    required this.onDelete,
    required this.onChangeColor,
    required this.onMoveEntry,
    required this.l10n,
    required this.scheme,
    required this.theme,
  });

  final FolioDriveFolder folder;
  final FolioFileDriveData data;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;
  final ValueChanged<FolioDriveFolder> onRename;
  final ValueChanged<FolioDriveFolder> onDelete;
  final void Function(FolioDriveFolder, int?) onChangeColor;
  final void Function(FolioDriveEntry, String?) onMoveEntry;
  final AppLocalizations l10n;
  final ColorScheme scheme;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final folderColor = folder.colorValue != null
        ? Color(folder.colorValue!)
        : scheme.primary;
    final childFolderCount = data.folders
        .where((f) => f.parentId == folder.id)
        .length;
    final childFileCount = data.entries
        .where((e) => e.folderId == folder.id)
        .length;
    return DragTarget<FolioDriveEntry>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (details) => onMoveEntry(details.data, folder.id),
      builder: (ctx, candidates, rejected) {
        final highlight = candidates.isNotEmpty;
        return GestureDetector(
          onDoubleTap: onDoubleTap,
          child: ListTile(
            selected: isSelected || highlight,
            selectedTileColor: highlight
                ? scheme.primary.withValues(alpha: FolioAlpha.soft)
                : scheme.primary.withValues(alpha: FolioAlpha.faint),
            leading: Icon(
              Icons.folder_rounded,
              color: folderColor.withValues(alpha: 0.85),
              size: 28,
            ),
            title: Text(folder.name, style: theme.textTheme.bodyMedium),
            subtitle: Text(
              '$childFolderCount folders · $childFileCount files',
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            trailing: _FolderContextMenuButton(
              folder: folder,
              onRename: onRename,
              onDelete: onDelete,
              onChangeColor: onChangeColor,
              l10n: l10n,
              scheme: scheme,
            ),
            onTap: onTap,
          ),
        );
      },
    );
  }
}

// ── Grid card ─────────────────────────────────────────────────────────────────

class _FileGridCard extends StatelessWidget {
  const _FileGridCard({
    super.key,
    required this.entry,
    required this.isSelected,
    required this.isMultiSelected,
    required this.multiSelectedCount,
    required this.onTap,
    required this.onOpen,
    required this.onRename,
    required this.onDelete,
    required this.onMoveEntry,
    required this.onExportEntry,
    required this.folders,
    required this.l10n,
    required this.scheme,
    required this.theme,
  });

  final FolioDriveEntry entry;
  final bool isSelected;
  final bool isMultiSelected;
  final int multiSelectedCount;
  final VoidCallback onTap;
  final ValueChanged<FolioDriveEntry> onOpen;
  final ValueChanged<FolioDriveEntry> onRename;
  final ValueChanged<FolioDriveEntry> onDelete;
  final void Function(FolioDriveEntry, String?) onMoveEntry;
  final ValueChanged<FolioDriveEntry> onExportEntry;
  final List<FolioDriveFolder> folders;
  final AppLocalizations l10n;
  final ColorScheme scheme;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final isDraggingMultiple = isMultiSelected && multiSelectedCount > 1;
    return Draggable<FolioDriveEntry>(
      data: entry,
      dragAnchorStrategy: (_, __, ___) => const Offset(40, 40),
      feedback: Material(
        color: Colors.transparent,
        child: Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: scheme.primaryContainer.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(FolioRadius.md),
          ),
          child: isDraggingMultiple
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.copy_all_rounded,
                      color: scheme.onPrimaryContainer,
                      size: 28,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$multiSelectedCount archivos',
                      style: TextStyle(
                        color: scheme.onPrimaryContainer,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                )
              : Icon(
                  _fileIcon(entry.fileType, entry.name),
                  color: scheme.onPrimaryContainer,
                  size: 36,
                ),
        ),
      ),
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FolioRadius.md),
          side: (isSelected || isMultiSelected)
              ? BorderSide(color: scheme.primary, width: 2)
              : BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
        ),
        child: GestureDetector(
          onDoubleTap: () => onOpen(entry),
          child: InkWell(
            borderRadius: BorderRadius.circular(FolioRadius.md),
            onTap: onTap,
            child: Stack(
              children: [
                if (isMultiSelected)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(FolioRadius.md),
                      ),
                    ),
                  ),
                if (isMultiSelected)
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Icon(
                      Icons.check_circle_rounded,
                      size: 20,
                      color: scheme.primary,
                    ),
                  ),
                Positioned.fill(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Preview area (65%).
                      Expanded(
                        flex: 65,
                        child: Container(
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerLowest,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(FolioRadius.md),
                            ),
                          ),
                          child: Center(
                            child: _FilePreviewWidget(
                              entry: entry,
                              scheme: scheme,
                            ),
                          ),
                        ),
                      ),
                      // Name strip (35%).
                      Expanded(
                        flex: 35,
                        child: Container(
                          color: scheme.surfaceContainerHigh,
                          padding: const EdgeInsets.symmetric(
                            horizontal: FolioSpace.xs,
                            vertical: FolioSpace.xxs,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                entry.name,
                                style: theme.textTheme.labelMedium,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (entry.sizeBytes != null)
                                Text(
                                  _formatSize(entry.sizeBytes!),
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                  maxLines: 1,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: 2,
                  right: 2,
                  child: _FileContextMenu(
                    entry: entry,
                    onOpen: onOpen,
                    onRename: onRename,
                    onDelete: onDelete,
                    onMoveEntry: onMoveEntry,
                    onExportEntry: onExportEntry,
                    folders: folders,
                    l10n: l10n,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── List row ──────────────────────────────────────────────────────────────────

class _FileListRow extends StatelessWidget {
  const _FileListRow({
    required this.entry,
    required this.isSelected,
    required this.isMultiSelected,
    required this.multiSelectedCount,
    required this.onTap,
    required this.onOpen,
    required this.onRename,
    required this.onDelete,
    required this.onMoveEntry,
    required this.onExportEntry,
    required this.folders,
    required this.l10n,
    required this.scheme,
    required this.theme,
  });

  final FolioDriveEntry entry;
  final bool isSelected;
  final bool isMultiSelected;
  final int multiSelectedCount;
  final VoidCallback onTap;
  final ValueChanged<FolioDriveEntry> onOpen;
  final ValueChanged<FolioDriveEntry> onRename;
  final ValueChanged<FolioDriveEntry> onDelete;
  final void Function(FolioDriveEntry, String?) onMoveEntry;
  final ValueChanged<FolioDriveEntry> onExportEntry;
  final List<FolioDriveFolder> folders;
  final AppLocalizations l10n;
  final ColorScheme scheme;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final dateStr = entry.addedAtMs != null
        ? DateFormat(
            'MMM d',
          ).format(DateTime.fromMillisecondsSinceEpoch(entry.addedAtMs!))
        : null;
    final isDraggingMultiple = isMultiSelected && multiSelectedCount > 1;
    return Draggable<FolioDriveEntry>(
      data: entry,
      dragAnchorStrategy: (_, __, ___) => const Offset(20, 16),
      feedback: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(FolioSpace.xs),
          decoration: BoxDecoration(
            color: scheme.primaryContainer.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(FolioRadius.sm),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isDraggingMultiple
                    ? Icons.copy_all_rounded
                    : _fileIcon(entry.fileType, entry.name),
                color: scheme.onPrimaryContainer,
                size: 20,
              ),
              const SizedBox(width: FolioSpace.xxs),
              Text(
                isDraggingMultiple
                    ? '$multiSelectedCount archivos'
                    : entry.name,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onPrimaryContainer,
                ),
              ),
            ],
          ),
        ),
      ),
      child: ListTile(
        selected: isSelected || isMultiSelected,
        selectedTileColor: isMultiSelected
            ? scheme.primary.withValues(alpha: FolioAlpha.faint)
            : scheme.primary.withValues(alpha: FolioAlpha.faint),
        leading: isMultiSelected
            ? Icon(Icons.check_circle_rounded, color: scheme.primary, size: 22)
            : Icon(
                _fileIcon(entry.fileType, entry.name),
                color: _fileIconColor(entry.fileType, entry.name),
                size: 22,
              ),
        title: Text(entry.name, style: theme.textTheme.bodySmall, maxLines: 1),
        subtitle: entry.sizeBytes != null
            ? Text(
                _formatSize(entry.sizeBytes!),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              )
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (dateStr != null)
              Padding(
                padding: const EdgeInsets.only(right: FolioSpace.xs),
                child: Text(
                  dateStr,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            _FileContextMenu(
              entry: entry,
              onOpen: onOpen,
              onRename: onRename,
              onDelete: onDelete,
              onMoveEntry: onMoveEntry,
              onExportEntry: onExportEntry,
              folders: folders,
              l10n: l10n,
            ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}

// ── File context menu ─────────────────────────────────────────────────────────

class _FileContextMenu extends StatefulWidget {
  const _FileContextMenu({
    required this.entry,
    required this.onOpen,
    required this.onRename,
    required this.onDelete,
    required this.onMoveEntry,
    required this.onExportEntry,
    required this.folders,
    required this.l10n,
  });

  final FolioDriveEntry entry;
  final ValueChanged<FolioDriveEntry> onOpen;
  final ValueChanged<FolioDriveEntry> onRename;
  final ValueChanged<FolioDriveEntry> onDelete;
  final void Function(FolioDriveEntry, String?) onMoveEntry;
  final ValueChanged<FolioDriveEntry> onExportEntry;
  final List<FolioDriveFolder> folders;
  final AppLocalizations l10n;

  @override
  State<_FileContextMenu> createState() => _FileContextMenuState();
}

class _FileContextMenuState extends State<_FileContextMenu> {
  final _menuKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: _menuKey,
      child: PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert, size: 16),
        iconSize: 16,
        padding: EdgeInsets.zero,
        itemBuilder: (_) => [
          PopupMenuItem(value: 'open', child: Text(widget.l10n.driveOpenFile)),
          PopupMenuItem(value: 'rename', child: const Text('Rename')),
          if (widget.folders.isNotEmpty)
            PopupMenuItem(value: 'move', child: Text(widget.l10n.driveMoveTo)),
          const PopupMenuDivider(),
          const PopupMenuItem(
            value: 'export',
            child: Text('Exportar al disco…'),
          ),
          const PopupMenuDivider(),
          PopupMenuItem(
            value: 'delete',
            child: Text(
              widget.l10n.driveDeleteConfirm,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
        onSelected: (v) {
          if (v == 'open') widget.onOpen(widget.entry);
          if (v == 'rename') widget.onRename(widget.entry);
          if (v == 'export') widget.onExportEntry(widget.entry);
          if (v == 'move') _showMovePicker();
          if (v == 'delete') _showDeleteConfirm();
        },
      ),
    );
  }

  void _showDeleteConfirm() {
    final ctx = _menuKey.currentContext;
    if (ctx == null || !ctx.mounted) return;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null) return;
    final topLeft = box.localToGlobal(Offset.zero);
    final scheme = Theme.of(ctx).colorScheme;
    final textTheme = Theme.of(ctx).textTheme;
    showMenu<bool>(
      context: ctx,
      position: RelativeRect.fromLTRB(
        topLeft.dx,
        topLeft.dy + box.size.height,
        topLeft.dx + box.size.width,
        0,
      ),
      items: [
        PopupMenuItem<bool>(
          enabled: false,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(
            '¿Eliminar "${widget.entry.name}"?',
            style: textTheme.bodySmall,
          ),
        ),
        PopupMenuItem<bool>(
          value: true,
          child: Text(
            'Eliminar',
            style: TextStyle(color: scheme.error, fontWeight: FontWeight.w600),
          ),
        ),
        PopupMenuItem<bool>(value: false, child: const Text('Cancelar')),
      ],
    ).then((ok) {
      if (ok == true) widget.onDelete(widget.entry);
    });
  }

  void _showMovePicker() {
    final ctx = _menuKey.currentContext;
    if (ctx == null || !ctx.mounted) return;
    showDialog<String?>(
      context: ctx,
      builder: (dialogCtx) => SimpleDialog(
        title: Text(widget.l10n.driveMoveTo),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(dialogCtx, ''),
            child: const Text('/ (root)'),
          ),
          for (final f in widget.folders)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogCtx, f.id),
              child: Text(f.name),
            ),
        ],
      ),
    ).then((result) {
      if (result != null) {
        widget.onMoveEntry(widget.entry, result.isEmpty ? null : result);
      }
    });
  }
}

// ── File preview ──────────────────────────────────────────────────────────────

class _FilePreviewWidget extends StatelessWidget {
  const _FilePreviewWidget({required this.entry, required this.scheme});

  final FolioDriveEntry entry;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    if (entry.fileType == FolioDriveFileType.image &&
        entry.url.startsWith('attachments/')) {
      return FutureBuilder<File?>(
        future: _resolveFile(),
        builder: (ctx, snap) {
          if (snap.hasData && snap.data != null) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(FolioRadius.sm),
              child: Image.file(
                snap.data!,
                width: 80,
                height: 80,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _iconWidget(),
              ),
            );
          }
          return _iconWidget();
        },
      );
    }
    return _iconWidget();
  }

  Widget _iconWidget() {
    final color = _fileIconColor(entry.fileType, entry.name);
    final icon = _fileIcon(entry.fileType, entry.name);
    // For video: dark background with centered play icon
    if (entry.fileType == FolioDriveFileType.video) {
      return Container(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(FolioRadius.sm),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              Icons.movie_rounded,
              size: 40,
              color: color.withValues(alpha: 0.3),
            ),
            Icon(icon, size: 36, color: color),
          ],
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(FolioRadius.sm),
      ),
      child: Center(child: Icon(icon, size: 48, color: color)),
    );
  }

  Future<File?> _resolveFile() async {
    final vault = await VaultPaths.vaultDirectory();
    final full = p.join(vault.path, entry.url.replaceAll('/', p.separator));
    final f = File(full);
    return f.existsSync() ? f : null;
  }
}

// ── Vault import dialog ───────────────────────────────────────────────────────

class _VaultFileCandidate {
  const _VaultFileCandidate({
    required this.pageName,
    required this.block,
    required this.pageId,
  });

  final String pageName;
  final FolioBlock block;
  final String pageId;
}

class _VaultImportDialog extends StatefulWidget {
  const _VaultImportDialog({required this.candidates, required this.l10n});

  final List<_VaultFileCandidate> candidates;
  final AppLocalizations l10n;

  @override
  State<_VaultImportDialog> createState() => _VaultImportDialogState();
}

class _VaultImportDialogState extends State<_VaultImportDialog> {
  final Set<int> _selected = {};

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    return AlertDialog(
      title: Text(l10n.driveImportFromVault),
      content: SizedBox(
        width: 420,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: widget.candidates.length,
          itemBuilder: (ctx, i) {
            final c = widget.candidates[i];
            final rawUrl = c.block.type == 'image'
                ? c.block.text.trim()
                : (c.block.url ?? '').trim();
            final label = rawUrl.split('/').last;
            return CheckboxListTile(
              dense: true,
              value: _selected.contains(i),
              onChanged: (v) =>
                  setState(() => v! ? _selected.add(i) : _selected.remove(i)),
              title: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(
                c.pageName,
                style: const TextStyle(fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              secondary: Icon(
                _fileIcon(
                  folioDriveFileTypeFromName(
                    c.block.type == 'image'
                        ? 'image'
                        : c.block.type == 'video'
                        ? 'video'
                        : c.block.type == 'audio'
                        ? 'audio'
                        : null,
                  ),
                ),
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _selected.isEmpty
              ? null
              : () => Navigator.pop(context, [
                  for (final i in _selected) widget.candidates[i],
                ]),
          child: Text(l10n.driveImportFromVault),
        ),
      ],
    );
  }
}

// ── Breadcrumb bar ────────────────────────────────────────────────────────────

class _BreadcrumbBar extends StatelessWidget {
  const _BreadcrumbBar({
    required this.data,
    required this.selectedFolderId,
    required this.onNavigate,
    required this.scheme,
    required this.theme,
  });

  final FolioFileDriveData data;
  final String? selectedFolderId;
  final ValueChanged<String?> onNavigate;
  final ColorScheme scheme;
  final ThemeData theme;

  List<FolioDriveFolder> _buildChain() {
    final chain = <FolioDriveFolder>[];
    String? current = selectedFolderId;
    while (current != null) {
      final folder = data.folders.where((f) => f.id == current).firstOrNull;
      if (folder == null) break;
      chain.insert(0, folder);
      current = folder.parentId;
    }
    return chain;
  }

  @override
  Widget build(BuildContext context) {
    final chain = _buildChain();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: FolioSpace.sm,
        vertical: FolioSpace.xxs,
      ),
      child: Row(
        children: [
          if (selectedFolderId != null)
            TextButton(
              onPressed: () => onNavigate(null),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: FolioSpace.xxs),
              ),
              child: Text(
                'All files',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: scheme.primary,
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: FolioSpace.xxs),
              child: Text(
                'All files',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          for (int i = 0; i < chain.length; i++) ...[
            Icon(
              Icons.chevron_right_rounded,
              size: 16,
              color: scheme.onSurfaceVariant,
            ),
            if (i < chain.length - 1)
              TextButton(
                onPressed: () => onNavigate(chain[i].id),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(
                    horizontal: FolioSpace.xxs,
                  ),
                ),
                child: Text(
                  chain[i].name,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.primary,
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: FolioSpace.xxs),
                child: Text(
                  chain[i].name,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

// ── Details panel ─────────────────────────────────────────────────────────────

class _DriveDetailsPanel extends StatelessWidget {
  const _DriveDetailsPanel({
    required this.selectedItem,
    required this.data,
    required this.onClose,
    required this.onOpen,
    required this.onRename,
    required this.onDelete,
    required this.onMoveEntry,
    required this.onExportEntry,
    required this.onChangeColor,
    required this.scheme,
    required this.theme,
    required this.l10n,
  });

  final Object selectedItem;
  final FolioFileDriveData data;
  final VoidCallback onClose;
  final ValueChanged<FolioDriveEntry> onOpen;
  final ValueChanged<Object> onRename;
  final ValueChanged<Object> onDelete;
  final void Function(FolioDriveEntry, String?) onMoveEntry;
  final ValueChanged<FolioDriveEntry> onExportEntry;
  final void Function(FolioDriveFolder, int?) onChangeColor;
  final ColorScheme scheme;
  final ThemeData theme;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final isEntry = selectedItem is FolioDriveEntry;
    final isFolder = selectedItem is FolioDriveFolder;
    final entry = isEntry ? selectedItem as FolioDriveEntry : null;
    final folder = isFolder ? selectedItem as FolioDriveFolder : null;
    final folderColor = folder?.colorValue != null
        ? Color(folder!.colorValue!)
        : scheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header.
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: FolioSpace.sm,
            vertical: FolioSpace.xxs,
          ),
          child: Row(
            children: [
              Text('Details', style: theme.textTheme.titleSmall),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 18),
                onPressed: onClose,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: FolioSpace.sm),
            children: [
              // Thumbnail.
              Center(
                child: SizedBox(
                  width: 120,
                  height: 120,
                  child: isEntry && entry!.fileType == FolioDriveFileType.image
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(FolioRadius.md),
                          child: _FilePreviewWidget(
                            entry: entry,
                            scheme: scheme,
                          ),
                        )
                      : isFolder
                      ? Icon(
                          Icons.folder_rounded,
                          size: 80,
                          color: folderColor.withValues(alpha: 0.85),
                        )
                      : Icon(
                          _fileIcon(entry!.fileType, entry.name),
                          size: 72,
                          color: _fileIconColor(entry.fileType, entry.name),
                        ),
                ),
              ),
              const SizedBox(height: FolioSpace.xs),
              // Name.
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: FolioSpace.sm),
                child: Text(
                  entry?.name ?? folder?.name ?? '',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: FolioSpace.xs),
              const Divider(),
              // Details rows.
              _DetailRow(
                label: 'Type',
                value: isFolder ? 'Folder' : _fileTypeName(entry!.fileType),
                scheme: scheme,
                theme: theme,
              ),
              if (entry != null) ...[
                _DetailRow(
                  label: 'Size',
                  value: entry.sizeBytes != null
                      ? _formatSize(entry.sizeBytes!)
                      : '—',
                  scheme: scheme,
                  theme: theme,
                ),
                _DetailRow(
                  label: 'Added',
                  value: entry.addedAtMs != null
                      ? DateFormat('MMM d, yyyy').format(
                          DateTime.fromMillisecondsSinceEpoch(entry.addedAtMs!),
                        )
                      : '—',
                  scheme: scheme,
                  theme: theme,
                ),
                _DetailRow(
                  label: 'Source',
                  value: entry.sourcePageId != null
                      ? 'Imported from vault'
                      : 'Uploaded',
                  scheme: scheme,
                  theme: theme,
                ),
              ],
              if (isFolder) ...[
                _DetailRow(
                  label: 'Folders',
                  value: data.folders
                      .where((f) => f.parentId == folder!.id)
                      .length
                      .toString(),
                  scheme: scheme,
                  theme: theme,
                ),
                _DetailRow(
                  label: 'Files',
                  value: data.entries
                      .where((e) => e.folderId == folder!.id)
                      .length
                      .toString(),
                  scheme: scheme,
                  theme: theme,
                ),
              ],
              // Action buttons (files only).
              if (entry != null) ...[
                const Divider(),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: FolioSpace.sm,
                    vertical: FolioSpace.xxs,
                  ),
                  child: FilledButton.icon(
                    onPressed: () => onOpen(entry),
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: Text(l10n.driveOpenFile),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: FolioSpace.sm,
                    vertical: FolioSpace.xxs,
                  ),
                  child: OutlinedButton.icon(
                    onPressed: () => onRename(entry),
                    icon: const Icon(
                      Icons.drive_file_rename_outline_rounded,
                      size: 18,
                    ),
                    label: const Text('Rename'),
                  ),
                ),
                if (data.folders.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: FolioSpace.sm,
                      vertical: FolioSpace.xxs,
                    ),
                    child: OutlinedButton.icon(
                      onPressed: () => _showMovePicker(context, entry),
                      icon: const Icon(Icons.drive_file_move_rounded, size: 18),
                      label: Text(l10n.driveMoveTo),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: FolioSpace.sm,
                    vertical: FolioSpace.xxs,
                  ),
                  child: OutlinedButton.icon(
                    onPressed: () => onExportEntry(entry),
                    icon: const Icon(Icons.download_rounded, size: 18),
                    label: const Text('Exportar al disco…'),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: FolioSpace.sm,
                    vertical: FolioSpace.xxs,
                  ),
                  child: _DeleteConfirmAnchor(
                    label: entry.name,
                    onConfirm: () => onDelete(entry),
                    child: TextButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      label: const Text('Delete'),
                      style: TextButton.styleFrom(
                        foregroundColor: scheme.error,
                      ),
                    ),
                  ),
                ),
              ],
              // Action buttons (folders).
              if (folder != null) ...[
                const Divider(),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: FolioSpace.sm,
                    vertical: FolioSpace.xxs,
                  ),
                  child: OutlinedButton.icon(
                    onPressed: () => onRename(folder),
                    icon: const Icon(
                      Icons.drive_file_rename_outline_rounded,
                      size: 18,
                    ),
                    label: const Text('Rename'),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: FolioSpace.sm,
                    vertical: FolioSpace.xxs,
                  ),
                  child: TextButton.icon(
                    onPressed: () {
                      showDialog<void>(
                        context: context,
                        builder: (ctx) => _FolderColorPicker(
                          folder: folder,
                          onChangeColor: onChangeColor,
                          scheme: scheme,
                        ),
                      );
                    },
                    icon: const Icon(Icons.color_lens_outlined, size: 18),
                    label: const Text('Change color'),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: FolioSpace.sm,
                    vertical: FolioSpace.xxs,
                  ),
                  child: _DeleteConfirmAnchor(
                    label: folder.name,
                    onConfirm: () => onDelete(folder),
                    child: TextButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      label: const Text('Delete'),
                      style: TextButton.styleFrom(
                        foregroundColor: scheme.error,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  String _fileTypeName(FolioDriveFileType type) {
    switch (type) {
      case FolioDriveFileType.image:
        return 'Image';
      case FolioDriveFileType.video:
        return 'Video';
      case FolioDriveFileType.audio:
        return 'Audio';
      case FolioDriveFileType.file:
        return 'File';
    }
  }

  void _showMovePicker(BuildContext context, FolioDriveEntry entry) {
    showDialog<String?>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l10n.driveMoveTo),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, ''),
            child: const Text('/ (root)'),
          ),
          for (final f in data.folders)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, f.id),
              child: Text(f.name),
            ),
        ],
      ),
    ).then((result) {
      if (result != null) {
        onMoveEntry(entry, result.isEmpty ? null : result);
      }
    });
  }
}

// ── Delete confirm anchor ──────────────────────────────────────────────────────

/// Wraps a delete button and shows a small confirmation popover anchored to it
/// when tapped, instead of a full-screen dialog.
class _DeleteConfirmAnchor extends StatefulWidget {
  const _DeleteConfirmAnchor({
    required this.label,
    required this.onConfirm,
    required this.child,
  });

  final String label;
  final VoidCallback onConfirm;
  final Widget child;

  @override
  State<_DeleteConfirmAnchor> createState() => _DeleteConfirmAnchorState();
}

class _DeleteConfirmAnchorState extends State<_DeleteConfirmAnchor> {
  final MenuController _menuController = MenuController();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    return MenuAnchor(
      controller: _menuController,
      alignmentOffset: const Offset(0, 4),
      menuChildren: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 240),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '¿Eliminar "${widget.label}"?',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => _menuController.close(),
                      child: const Text('Cancelar'),
                    ),
                    const SizedBox(width: 6),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: scheme.error,
                        foregroundColor: scheme.onError,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () {
                        _menuController.close();
                        widget.onConfirm();
                      },
                      child: const Text('Eliminar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
      child: GestureDetector(
        onTap: () => _menuController.isOpen
            ? _menuController.close()
            : _menuController.open(),
        child: widget.child,
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    required this.scheme,
    required this.theme,
  });

  final String label;
  final String value;
  final ColorScheme scheme;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: FolioSpace.xxs,
        horizontal: FolioSpace.sm,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodySmall)),
        ],
      ),
    );
  }
}

// ── Folder color picker ───────────────────────────────────────────────────────

class _FolderColorPicker extends StatelessWidget {
  const _FolderColorPicker({
    required this.folder,
    required this.onChangeColor,
    required this.scheme,
  });

  final FolioDriveFolder folder;
  final void Function(FolioDriveFolder, int?) onChangeColor;
  final ColorScheme scheme;

  static const _colors = <Color?>[
    null, // use primary
    Colors.red,
    Colors.orange,
    Colors.amber,
    Colors.green,
    Colors.teal,
    Colors.blue,
    Colors.indigo,
    Colors.purple,
    Colors.pink,
    Colors.brown,
  ];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Folder color'),
      content: SizedBox(
        width: 280,
        child: Wrap(
          spacing: FolioSpace.xs,
          runSpacing: FolioSpace.xs,
          children: [
            for (final color in _colors)
              _ColorSwatch(
                color: color ?? scheme.primary,
                isSelected: color == null
                    ? folder.colorValue == null
                    : folder.colorValue == color.toARGB32(),
                onTap: () {
                  onChangeColor(folder, color?.toARGB32());
                  Navigator.of(context).pop();
                },
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: isSelected ? Border.all(color: Colors.white, width: 3) : null,
          boxShadow: isSelected
              ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 4)]
              : null,
        ),
        child: isSelected
            ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
            : null,
      ),
    );
  }
}

// ── Drag overlay ──────────────────────────────────────────────────────────────

class _DragOverlay extends StatelessWidget {
  const _DragOverlay();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IgnorePointer(
      child: Container(
        decoration: BoxDecoration(
          color: scheme.primary.withValues(alpha: 0.12),
          border: Border.all(color: scheme.primary, width: 2),
          borderRadius: BorderRadius.circular(FolioRadius.md),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.upload_file_rounded, size: 56, color: scheme.primary),
              const SizedBox(height: FolioSpace.xs),
              Text(
                'Drop files to upload',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(color: scheme.primary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

IconData _fileIcon(FolioDriveFileType type, [String? name]) {
  switch (type) {
    case FolioDriveFileType.image:
      return Icons.image_rounded;
    case FolioDriveFileType.video:
      return Icons.play_circle_filled_rounded;
    case FolioDriveFileType.audio:
      return Icons.music_note_rounded;
    case FolioDriveFileType.file:
      final ext = name != null ? p.extension(name).toLowerCase() : '';
      switch (ext) {
        case '.pdf':
          return Icons.picture_as_pdf_rounded;
        case '.doc':
        case '.docx':
        case '.odt':
          return Icons.article_rounded;
        case '.xls':
        case '.xlsx':
        case '.csv':
        case '.ods':
          return Icons.table_chart_rounded;
        case '.ppt':
        case '.pptx':
        case '.odp':
          return Icons.slideshow_rounded;
        case '.zip':
        case '.rar':
        case '.7z':
        case '.tar':
        case '.gz':
          return Icons.folder_zip_rounded;
        case '.js':
        case '.ts':
        case '.dart':
        case '.py':
        case '.java':
        case '.cpp':
        case '.c':
        case '.html':
        case '.css':
        case '.json':
        case '.xml':
        case '.yaml':
        case '.yml':
        case '.sh':
          return Icons.code_rounded;
        case '.txt':
        case '.md':
        case '.rtf':
          return Icons.text_snippet_rounded;
        case '.ttf':
        case '.otf':
        case '.woff':
          return Icons.font_download_rounded;
        default:
          return Icons.insert_drive_file_rounded;
      }
  }
}

Color _fileIconColor(FolioDriveFileType type, String? name) {
  switch (type) {
    case FolioDriveFileType.image:
      return Colors.pink.shade400;
    case FolioDriveFileType.video:
      return Colors.deepPurple.shade400;
    case FolioDriveFileType.audio:
      return Colors.teal.shade500;
    case FolioDriveFileType.file:
      final ext = name != null ? p.extension(name).toLowerCase() : '';
      switch (ext) {
        case '.pdf':
          return Colors.red.shade600;
        case '.doc':
        case '.docx':
        case '.odt':
          return Colors.blue.shade600;
        case '.xls':
        case '.xlsx':
        case '.csv':
        case '.ods':
          return Colors.green.shade600;
        case '.ppt':
        case '.pptx':
        case '.odp':
          return Colors.orange.shade600;
        case '.zip':
        case '.rar':
        case '.7z':
        case '.tar':
        case '.gz':
          return Colors.brown.shade400;
        case '.js':
        case '.ts':
        case '.dart':
        case '.py':
        case '.java':
        case '.cpp':
        case '.c':
        case '.html':
        case '.css':
        case '.json':
        case '.xml':
        case '.yaml':
        case '.yml':
        case '.sh':
          return Colors.indigo.shade400;
        case '.txt':
        case '.md':
        case '.rtf':
          return Colors.blueGrey.shade400;
        default:
          return Colors.blueGrey.shade300;
      }
  }
}

String _formatSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}
