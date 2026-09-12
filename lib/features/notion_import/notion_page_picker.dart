import 'package:flutter/material.dart';

import '../../app/widgets/folio_skeletons.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../services/notion/notion_api_client.dart';

/// Selector de páginas/bases de datos compartidas con la integración de
/// Notion tras el OAuth. Contenido puro (sin `Scaffold` propio) para poder
/// usarse tanto embebido como paso de onboarding como empujado en una ruta
/// propia desde Settings.
class NotionPagePicker extends StatefulWidget {
  const NotionPagePicker({
    super.key,
    required this.client,
    required this.onConfirm,
    this.onCancel,
  });

  final NotionApiClient client;
  final ValueChanged<List<NotionSearchResultItem>> onConfirm;
  final VoidCallback? onCancel;

  @override
  State<NotionPagePicker> createState() => _NotionPagePickerState();
}

class _NotionPagePickerState extends State<NotionPagePicker> {
  bool _loading = true;
  bool _truncated = false;
  String? _error;
  List<NotionSearchResultItem> _pages = [];
  List<NotionSearchResultItem> _databases = [];
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await widget.client.search();
      final pages = result.items.where((i) => !i.isDatabase).toList();
      final databases = result.items.where((i) => i.isDatabase).toList();
      if (!mounted) return;
      setState(() {
        _pages = pages;
        _databases = databases;
        _truncated = result.truncated;
        // Por defecto todo marcado — "importación directa" implica traer lo
        // compartido, el usuario desmarca lo que no quiera.
        _selectedIds
          ..clear()
          ..addAll(pages.map((p) => p.id))
          ..addAll(databases.map((d) => d.id));
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toggle(String id, bool? value) {
    setState(() {
      if (value ?? false) {
        _selectedIds.add(id);
      } else {
        _selectedIds.remove(id);
      }
    });
  }

  void _toggleAll(bool value) {
    setState(() {
      if (value) {
        _selectedIds
          ..addAll(_pages.map((p) => p.id))
          ..addAll(_databases.map((d) => d.id));
      } else {
        _selectedIds.clear();
      }
    });
  }

  List<NotionSearchResultItem> get _selectedItems => [
    ..._pages.where((p) => _selectedIds.contains(p.id)),
    ..._databases.where((d) => _selectedIds.contains(d.id)),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: FolioLoadingIndicator(centered: true),
      );
    }

    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.notionPagePickerLoadError(_error!), style: TextStyle(color: scheme.error)),
            const SizedBox(height: 12),
            FilledButton(onPressed: _load, child: Text(l10n.retry)),
          ],
        ),
      );
    }

    final total = _pages.length + _databases.length;
    if (total == 0) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.notionPagePickerEmptyState, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: _load, child: Text(l10n.retry)),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(l10n.notionPagePickerBody, style: Theme.of(context).textTheme.bodyMedium),
        ),
        if (_truncated)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              l10n.notionPagePickerTruncatedNotice(NotionApiClient.searchResultCap),
              style: TextStyle(color: scheme.error, fontSize: 12),
            ),
          ),
        CheckboxListTile(
          value: _selectedIds.length == total,
          tristate: _selectedIds.isNotEmpty && _selectedIds.length != total,
          onChanged: (v) => _toggleAll(v ?? false),
          title: Text(l10n.notionPagePickerSelectAll),
          controlAffinity: ListTileControlAffinity.leading,
        ),
        const Divider(height: 1),
        // `shrinkWrap: true` (no `Flexible`/`Expanded`): este widget se usa
        // tanto en el onboarding (dentro de un `SingleChildScrollView` de
        // altura no acotada, donde un `Flexible` rompería el layout) como en
        // una ruta propia de Settings — sizearse al contenido funciona en
        // ambos sin duplicar el widget.
        ListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            if (_pages.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(
                  l10n.notionPagePickerSectionPages,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              for (final item in _pages) _NotionPickerTile(item: item, selectedIds: _selectedIds, onChanged: _toggle),
            ],
            if (_databases.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(
                  l10n.notionPagePickerSectionDatabases,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              for (final item in _databases)
                _NotionPickerTile(item: item, selectedIds: _selectedIds, onChanged: _toggle),
            ],
          ],
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(l10n.notionPagePickerSelectedCount(_selectedIds.length)),
              const Spacer(),
              if (widget.onCancel != null) ...[
                TextButton(onPressed: widget.onCancel, child: Text(l10n.cancel)),
                const SizedBox(width: 8),
              ],
              FilledButton(
                onPressed: _selectedIds.isEmpty ? null : () => widget.onConfirm(_selectedItems),
                child: Text(l10n.continueAction),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NotionPickerTile extends StatelessWidget {
  const _NotionPickerTile({required this.item, required this.selectedIds, required this.onChanged});

  final NotionSearchResultItem item;
  final Set<String> selectedIds;
  final void Function(String id, bool? value) onChanged;

  @override
  Widget build(BuildContext context) {
    final title = item.title.trim().isEmpty ? 'Untitled' : item.title.trim();
    return CheckboxListTile(
      value: selectedIds.contains(item.id),
      onChanged: (v) => onChanged(item.id, v),
      controlAffinity: ListTileControlAffinity.leading,
      secondary: item.iconEmoji != null
          ? Text(item.iconEmoji!, style: const TextStyle(fontSize: 18))
          : Icon(item.isDatabase ? Icons.table_chart_outlined : Icons.description_outlined),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }
}
