import 'package:flutter/material.dart';

import '../../app/widgets/folio_dialog.dart';
import '../../app/widgets/folio_skeletons.dart';
<<<<<<< HEAD
=======
import '../../l10n/generated/app_localizations.dart';
>>>>>>> 6a0aa5e40f4e97ec3a7dc4005e3d074cd104d623
import '../../services/admin/admin_storage_api.dart';

/// SUPER_ADMIN-only bucket explorer: folder-style browsing over S3/MinIO via
/// `AdminStorageApi.listObjects` (delimited paging, not a full-bucket dump).
class AdminObjectExplorerPage extends StatefulWidget {
  const AdminObjectExplorerPage({super.key});

  @override
  State<AdminObjectExplorerPage> createState() => _AdminObjectExplorerPageState();
}

class _AdminObjectExplorerPageState extends State<AdminObjectExplorerPage> {
  final _api = const AdminStorageApi();
  final _prefixStack = <String>[''];

  bool _loading = true;
  String? _error;
  List<String> _prefixes = const [];
  List<Map<String, dynamic>> _objects = const [];
  String? _nextToken;

  String get _currentPrefix => _prefixStack.last;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({String? continuationToken}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await _api.listObjects(
        prefix: _currentPrefix,
        continuationToken: continuationToken,
      );
      if (!mounted) return;
      setState(() {
        _prefixes = page.commonPrefixes;
        _objects = continuationToken == null
            ? page.objects
            : [..._objects, ...page.objects];
        _nextToken = page.nextContinuationToken;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  void _openPrefix(String prefix) {
    setState(() => _prefixStack.add(prefix));
    _load();
  }

  void _goBack() {
    if (_prefixStack.length <= 1) return;
    setState(() => _prefixStack.removeLast());
    _load();
  }

  void _goToUserPrefix() async {
<<<<<<< HEAD
=======
    final l10n = AppLocalizations.of(context);
>>>>>>> 6a0aa5e40f4e97ec3a7dc4005e3d074cd104d623
    final controller = TextEditingController();
    final uid = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
<<<<<<< HEAD
        title: const Text('Ir a users/{uid}/'),
        content: TextField(controller: controller, decoration: const InputDecoration(labelText: 'uid')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Ir'),
=======
        title: Text(l10n.adminGoToUserTitle),
        content: TextField(controller: controller, decoration: const InputDecoration(labelText: 'uid')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(l10n.adminActionGoTo),
>>>>>>> 6a0aa5e40f4e97ec3a7dc4005e3d074cd104d623
          ),
        ],
      ),
    );
    if (uid == null || uid.isEmpty) return;
    setState(() {
      _prefixStack
        ..clear()
        ..add('users/$uid/');
    });
    _load();
  }

  Future<void> _deleteObject(String key) async {
<<<<<<< HEAD
    final ok = await FolioDialog.confirm(
      context,
      title: const Text('Borrar objeto'),
      content: Text('Esto borra "$key" directamente del bucket. No se puede deshacer.'),
      confirmLabel: 'Borrar',
=======
    final l10n = AppLocalizations.of(context);
    final ok = await FolioDialog.confirm(
      context,
      title: Text(l10n.adminDeleteObjectTitle),
      content: Text(l10n.adminDeleteObjectBody(key)),
      confirmLabel: l10n.adminActionDelete,
>>>>>>> 6a0aa5e40f4e97ec3a7dc4005e3d074cd104d623
      destructive: true,
    );
    if (ok != true) return;
    try {
      await _api.deleteObject(key);
      if (!mounted) return;
      await _load();
    } catch (e) {
      if (!mounted) return;
<<<<<<< HEAD
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
=======
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.adminErrorWithDetails('$e'))));
>>>>>>> 6a0aa5e40f4e97ec3a7dc4005e3d074cd104d623
    }
  }

  @override
  Widget build(BuildContext context) {
<<<<<<< HEAD
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentPrefix.isEmpty ? 'Explorador de objetos' : _currentPrefix),
=======
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentPrefix.isEmpty ? l10n.adminObjectExplorerTitle : _currentPrefix),
>>>>>>> 6a0aa5e40f4e97ec3a7dc4005e3d074cd104d623
        leading: _prefixStack.length > 1
            ? IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: _goBack)
            : null,
        actions: [
          IconButton(
<<<<<<< HEAD
            tooltip: 'Ir a un usuario',
=======
            tooltip: l10n.adminGoToUserTooltip,
>>>>>>> 6a0aa5e40f4e97ec3a7dc4005e3d074cd104d623
            icon: const Icon(Icons.person_search_outlined),
            onPressed: _goToUserPrefix,
          ),
        ],
      ),
      body: _loading && _objects.isEmpty && _prefixes.isEmpty
          ? const Center(child: FolioLoadingIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: TextStyle(color: scheme.error)))
              : ListView(
                  children: [
                    for (final prefix in _prefixes)
                      ListTile(
                        leading: const Icon(Icons.folder_outlined),
                        title: Text(prefix),
                        onTap: () => _openPrefix(prefix),
                      ),
                    for (final obj in _objects)
                      ListTile(
                        leading: const Icon(Icons.insert_drive_file_outlined),
                        title: Text(obj['key']?.toString() ?? ''),
                        subtitle: Text(_formatBytes((obj['size'] as num?)?.toInt() ?? 0)),
                        trailing: IconButton(
                          icon: Icon(Icons.delete_outline_rounded, color: scheme.error),
                          onPressed: () => _deleteObject(obj['key']?.toString() ?? ''),
                        ),
                      ),
                    if (_nextToken != null)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Center(
                          child: _loading
                              ? const FolioLoadingIndicator(size: FolioLoadingSize.small)
                              : OutlinedButton(
                                  onPressed: () => _load(continuationToken: _nextToken),
<<<<<<< HEAD
                                  child: const Text('Cargar más'),
=======
                                  child: Text(l10n.adminLoadMore),
>>>>>>> 6a0aa5e40f4e97ec3a7dc4005e3d074cd104d623
                                ),
                        ),
                      ),
                  ],
                ),
    );
  }
}

String _formatBytes(int bytes) {
  if (bytes <= 0) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var value = bytes.toDouble();
  var unitIndex = 0;
  while (value >= 1024 && unitIndex < units.length - 1) {
    value /= 1024;
    unitIndex++;
  }
  return '${value.toStringAsFixed(value < 10 && unitIndex > 0 ? 1 : 0)} ${units[unitIndex]}';
}
