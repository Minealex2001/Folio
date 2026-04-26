import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../models/folio_page_template.dart';
import '../../../session/vault_session.dart';

class TemplateGalleryResult {
  const TemplateGalleryResult({this.template});

  final FolioPageTemplate? template;
}

Future<TemplateGalleryResult?> showTemplateGalleryDialog({
  required BuildContext context,
  required VaultSession session,
}) {
  return showDialog<TemplateGalleryResult>(
    context: context,
    builder: (_) => _TemplateGalleryDialog(session: session),
  );
}

enum _TemplateSortMode { recent, name }

class _TemplateGalleryDialog extends StatefulWidget {
  const _TemplateGalleryDialog({required this.session});

  final VaultSession session;

  @override
  State<_TemplateGalleryDialog> createState() => _TemplateGalleryDialogState();
}

class _TemplateGalleryDialogState extends State<_TemplateGalleryDialog> {
  String _filter = '';
  String _category = '';
  String? _selectedId;
  _TemplateSortMode _sortMode = _TemplateSortMode.recent;

  List<FolioPageTemplate> get _allTemplates => widget.session.pageTemplates;

  List<String> get _categories {
    final values =
        _allTemplates
            .map((template) => template.category.trim())
            .where((category) => category.isNotEmpty)
            .toSet()
            .toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return values;
  }

  List<FolioPageTemplate> get _templates {
    final query = _filter.trim().toLowerCase();
    final filtered = _allTemplates.where((template) {
      if (_category.isNotEmpty && template.category.trim() != _category) {
        return false;
      }
      if (query.isEmpty) return true;
      return template.name.toLowerCase().contains(query) ||
          template.description.toLowerCase().contains(query) ||
          template.category.toLowerCase().contains(query) ||
          _previewTextFor(template).toLowerCase().contains(query);
    }).toList();

    filtered.sort((a, b) {
      switch (_sortMode) {
        case _TemplateSortMode.recent:
          return b.createdAtMs.compareTo(a.createdAtMs);
        case _TemplateSortMode.name:
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      }
    });
    return filtered;
  }

  FolioPageTemplate? get _selected {
    final selectedId = _selectedId;
    if (selectedId == null) return null;
    for (final template in _allTemplates) {
      if (template.id == selectedId) return template;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _syncSelection();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final templates = _templates;
    final selected = _selected;
    final totalTemplates = _allTemplates.length;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 980, maxHeight: 680),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.templateGalleryTitle,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          totalTemplates == templates.length
                              ? l10n.templateCount(totalTemplates)
                              : l10n.templateFilteredCount(
                                  templates.length,
                                  totalTemplates,
                                ),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: _importTemplate,
                    icon: const Icon(Icons.upload_rounded, size: 18),
                    label: Text(l10n.templateImport),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                    tooltip: l10n.cancel,
                  ),
                ],
              ),
            ),
            const Divider(height: 20),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 8, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  decoration: InputDecoration(
                                    hintText: l10n.templateSearchHint,
                                    prefixIcon: const Icon(
                                      Icons.search_rounded,
                                    ),
                                    isDense: true,
                                  ),
                                  onChanged: (value) {
                                    setState(() {
                                      _filter = value;
                                      _syncSelection();
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              DropdownButton<_TemplateSortMode>(
                                value: _sortMode,
                                onChanged: (value) {
                                  if (value == null) return;
                                  setState(() {
                                    _sortMode = value;
                                    _syncSelection();
                                  });
                                },
                                items: [
                                  DropdownMenuItem(
                                    value: _TemplateSortMode.recent,
                                    child: Text(l10n.templateSortRecent),
                                  ),
                                  DropdownMenuItem(
                                    value: _TemplateSortMode.name,
                                    child: Text(l10n.templateSortName),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          if (_categories.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            SizedBox(
                              height: 34,
                              child: ListView(
                                scrollDirection: Axis.horizontal,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: ChoiceChip(
                                      label: Text(l10n.searchFilterAll),
                                      selected: _category.isEmpty,
                                      onSelected: (_) {
                                        setState(() {
                                          _category = '';
                                          _syncSelection();
                                        });
                                      },
                                    ),
                                  ),
                                  for (final category in _categories)
                                    Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: ChoiceChip(
                                        label: Text(category),
                                        selected: _category == category,
                                        onSelected: (_) {
                                          setState(() {
                                            _category = _category == category
                                                ? ''
                                                : category;
                                            _syncSelection();
                                          });
                                        },
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          Expanded(
                            child: templates.isEmpty
                                ? _TemplateEmptyState(
                                    isFiltering:
                                        _filter.trim().isNotEmpty ||
                                        _category.isNotEmpty,
                                    onImport: _importTemplate,
                                  )
                                : GridView.builder(
                                    gridDelegate:
                                        const SliverGridDelegateWithMaxCrossAxisExtent(
                                          maxCrossAxisExtent: 220,
                                          mainAxisExtent: 164,
                                          crossAxisSpacing: 10,
                                          mainAxisSpacing: 10,
                                        ),
                                    itemCount: templates.length,
                                    itemBuilder: (_, index) {
                                      final template = templates[index];
                                      return _TemplateCard(
                                        template: template,
                                        previewText: _previewTextFor(template),
                                        selected: template.id == _selectedId,
                                        onTap: () => setState(
                                          () => _selectedId = template.id,
                                        ),
                                        onDoubleTap: () => _use(template),
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: selected == null
                        ? const SizedBox(
                            key: ValueKey('empty_detail'),
                            width: 292,
                            child: _TemplateNoSelectionPanel(),
                          )
                        : SizedBox(
                            key: ValueKey(selected.id),
                            width: 292,
                            child: _TemplateDetailPanel(
                              template: selected,
                              previewText: _previewTextFor(selected),
                              onUse: () => _use(selected),
                              onEdit: () => _editTemplate(selected),
                              onDelete: () => _confirmDelete(selected),
                              onExport: () => _exportTemplate(selected),
                            ),
                          ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  TextButton.icon(
                    onPressed: _clearFilters,
                    icon: const Icon(Icons.filter_alt_off_rounded, size: 16),
                    label: Text(l10n.clear),
                  ),
                  const Spacer(),
                  OutlinedButton(
                    onPressed: () =>
                        Navigator.pop(context, const TemplateGalleryResult()),
                    child: Text(l10n.templateBlankPage),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: selected == null ? null : () => _use(selected),
                    child: Text(l10n.templateUse),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _clearFilters() {
    setState(() {
      _filter = '';
      _category = '';
      _sortMode = _TemplateSortMode.recent;
      _syncSelection();
    });
  }

  void _syncSelection() {
    final visibleTemplates = _templates;
    if (visibleTemplates.isEmpty) {
      _selectedId = null;
      return;
    }
    if (!visibleTemplates.any((template) => template.id == _selectedId)) {
      _selectedId = visibleTemplates.first.id;
    }
  }

  void _use(FolioPageTemplate template) {
    Navigator.pop(context, TemplateGalleryResult(template: template));
  }

  Future<void> _editTemplate(FolioPageTemplate template) async {
    final l10n = AppLocalizations.of(context);
    String emoji = template.emoji ?? '';
    String name = template.name;
    String description = template.description;
    String category = template.category;

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(l10n.templateEdit),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  initialValue: emoji,
                  decoration: const InputDecoration(labelText: 'Emoji'),
                  onChanged: (value) => setDialogState(() => emoji = value),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  initialValue: name,
                  autofocus: true,
                  decoration: InputDecoration(labelText: l10n.templateNameHint),
                  onChanged: (value) => setDialogState(() => name = value),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  initialValue: description,
                  minLines: 2,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: l10n.templateDescriptionHint,
                  ),
                  onChanged: (value) =>
                      setDialogState(() => description = value),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  initialValue: category,
                  decoration: InputDecoration(
                    labelText: l10n.templateCategoryHint,
                  ),
                  onChanged: (value) => setDialogState(() => category = value),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: name.trim().isEmpty
                  ? null
                  : () => Navigator.pop(dialogContext, true),
              child: Text(l10n.save),
            ),
          ],
        ),
      ),
    );

    if (shouldSave != true || !mounted) return;

    widget.session.updateTemplate(
      FolioPageTemplate(
        id: template.id,
        name: name.trim(),
        description: description.trim(),
        emoji: emoji.trim().isEmpty ? null : emoji.trim(),
        category: category.trim(),
        createdAtMs: template.createdAtMs,
        blocks: template.blocks,
      ),
    );

    setState(_syncSelection);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.templateUpdated)));
  }

  Future<void> _confirmDelete(FolioPageTemplate template) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.templateDeleteConfirmTitle),
        content: Text(l10n.templateDeleteConfirmBody(template.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    widget.session.deleteTemplate(template.id);
    setState(_syncSelection);
  }

  Future<void> _importTemplate() async {
    final l10n = AppLocalizations.of(context);
    final pick = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['folio-template', 'json'],
      allowMultiple: false,
      dialogTitle: l10n.templateImportPickTitle,
    );
    if (pick == null || pick.files.isEmpty || !mounted) return;

    final path = pick.files.single.path;
    if (path == null) return;

    try {
      final template = widget.session.importTemplateFromFile(path);
      if (!mounted) return;
      setState(() {
        _selectedId = template.id;
        _syncSelection();
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.templateImportSuccess)));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.templateImportError('$error'))),
      );
    }
  }

  Future<void> _exportTemplate(FolioPageTemplate template) async {
    final l10n = AppLocalizations.of(context);
    final safeName = template.name
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '_');
    final destination = await FilePicker.saveFile(
      dialogTitle: l10n.templateExportPickTitle,
      fileName: '$safeName.folio-template',
    );
    if (destination == null || !mounted) return;

    try {
      widget.session.exportTemplateToFile(template, destination);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.templateExportSuccess)));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.templateExportError('$error'))),
      );
    }
  }

  String _previewTextFor(FolioPageTemplate template) {
    for (final block in template.blocks) {
      final text = block.text.trim();
      if (text.isNotEmpty) return text.replaceAll('\n', ' ');
    }
    return '';
  }
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({
    required this.template,
    required this.previewText,
    required this.selected,
    required this.onTap,
    required this.onDoubleTap,
  });

  final FolioPageTemplate template;
  final String previewText;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onDoubleTap: onDoubleTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected
                ? scheme.secondaryContainer
                : scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? scheme.secondary : scheme.outlineVariant,
              width: selected ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: scheme.shadow.withAlpha(selected ? 28 : 12),
                blurRadius: selected ? 14 : 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    template.emoji ?? '📄',
                    style: const TextStyle(fontSize: 26),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? scheme.onSecondaryContainer.withAlpha(26)
                          : scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${template.blocks.length}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                template.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: selected
                      ? scheme.onSecondaryContainer
                      : scheme.onSurface,
                ),
              ),
              if (template.category.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  template.category,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: selected
                        ? scheme.onSecondaryContainer.withAlpha(185)
                        : scheme.primary,
                  ),
                ),
              ],
              const Spacer(),
              Text(
                previewText.isEmpty
                    ? AppLocalizations.of(context).templatePreviewEmpty
                    : previewText,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: selected
                      ? scheme.onSecondaryContainer.withAlpha(210)
                      : scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TemplateDetailPanel extends StatelessWidget {
  const _TemplateDetailPanel({
    required this.template,
    required this.previewText,
    required this.onUse,
    required this.onEdit,
    required this.onDelete,
    required this.onExport,
  });

  final FolioPageTemplate template;
  final String previewText;
  final VoidCallback onUse;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.fromLTRB(0, 0, 12, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                template.emoji ?? '📄',
                style: const TextStyle(fontSize: 36),
              ),
              const Spacer(),
              IconButton(
                onPressed: onEdit,
                tooltip: l10n.templateEdit,
                icon: const Icon(Icons.edit_outlined),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            template.name,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          if (template.description.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              template.description,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MetaChip(
                icon: Icons.view_agenda_outlined,
                label: l10n.templateBlockCount(template.blocks.length),
              ),
              if (template.category.trim().isNotEmpty)
                _MetaChip(icon: Icons.sell_outlined, label: template.category),
              _MetaChip(
                icon: Icons.schedule_rounded,
                label: l10n.templateCreatedOn(
                  _formatDate(template.createdAtMs),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            l10n.contentLabel,
            style: theme.textTheme.labelMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              previewText.isEmpty ? l10n.templatePreviewEmpty : previewText,
              maxLines: 8,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
          ),
          const Spacer(),
          FilledButton.icon(
            onPressed: onUse,
            icon: const Icon(Icons.note_add_outlined, size: 18),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(40),
            ),
            label: Text(l10n.templateUse),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined, size: 18),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(40),
            ),
            label: Text(l10n.templateEdit),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: onExport,
            icon: const Icon(Icons.ios_share_rounded, size: 18),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(40),
            ),
            label: Text(l10n.templateExport),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: onDelete,
            icon: Icon(Icons.delete_outline_rounded, color: scheme.error),
            style: TextButton.styleFrom(minimumSize: const Size.fromHeight(40)),
            label: Text(l10n.delete, style: TextStyle(color: scheme.error)),
          ),
        ],
      ),
    );
  }

  static String _formatDate(int createdAtMs) {
    final date = DateTime.fromMillisecondsSinceEpoch(createdAtMs).toLocal();
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}

class _TemplateEmptyState extends StatelessWidget {
  const _TemplateEmptyState({
    required this.isFiltering,
    required this.onImport,
  });

  final bool isFiltering;
  final Future<void> Function() onImport;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isFiltering ? Icons.search_off_rounded : Icons.layers_outlined,
                size: 34,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              isFiltering ? l10n.noSearchResults : l10n.templateEmptyHint,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: onImport,
              icon: const Icon(Icons.upload_rounded, size: 18),
              label: Text(l10n.templateImport),
            ),
          ],
        ),
      ),
    );
  }
}

class _TemplateNoSelectionPanel extends StatelessWidget {
  const _TemplateNoSelectionPanel();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.fromLTRB(0, 0, 12, 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Center(
        child: Text(
          AppLocalizations.of(context).templateSelectHint,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: scheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(label, style: theme.textTheme.labelMedium),
        ],
      ),
    );
  }
}
