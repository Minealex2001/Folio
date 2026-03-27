import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../models/folio_page_template.dart';
import '../../../session/vault_session.dart';

/// Resultado que devuelve [showTemplateGalleryDialog]:
/// - [template] no nulo → crear página desde ese template.
/// - ambos nulos → "página en blanco" o cancelación.
class TemplateGalleryResult {
  const TemplateGalleryResult({this.template});
  final FolioPageTemplate? template;
}

/// Muestra la galería de templates del vault y devuelve la elección del usuario.
Future<TemplateGalleryResult?> showTemplateGalleryDialog({
  required BuildContext context,
  required VaultSession session,
}) {
  return showDialog<TemplateGalleryResult>(
    context: context,
    builder: (ctx) => _TemplateGalleryDialog(session: session),
  );
}

// ─────────────────────────────────────────────────────────────────────────────

class _TemplateGalleryDialog extends StatefulWidget {
  const _TemplateGalleryDialog({required this.session});
  final VaultSession session;

  @override
  State<_TemplateGalleryDialog> createState() => _TemplateGalleryDialogState();
}

class _TemplateGalleryDialogState extends State<_TemplateGalleryDialog> {
  String _filter = '';
  String? _selectedId;

  List<FolioPageTemplate> get _templates {
    final q = _filter.trim().toLowerCase();
    final all = widget.session.pageTemplates;
    if (q.isEmpty) return all;
    return all
        .where(
          (t) =>
              t.name.toLowerCase().contains(q) ||
              t.description.toLowerCase().contains(q) ||
              t.category.toLowerCase().contains(q),
        )
        .toList();
  }

  FolioPageTemplate? get _selected => _selectedId == null
      ? null
      : widget.session.pageTemplates
            .where((t) => t.id == _selectedId)
            .firstOrNull;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final templates = _templates;
    final selected = _selected;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820, maxHeight: 580),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
              child: Row(
                children: [
                  Text(
                    l10n.templateGalleryTitle,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  // Import button
                  TextButton.icon(
                    onPressed: _importTemplate,
                    icon: const Icon(Icons.upload_rounded, size: 18),
                    label: Text(l10n.templateImport),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                    tooltip: l10n.cancel,
                  ),
                ],
              ),
            ),
            const Divider(height: 16),
            // ── Body ────────────────────────────────────────────────────────
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left: grid
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            decoration: InputDecoration(
                              hintText: l10n.templateSearchHint,
                              prefixIcon: const Icon(Icons.search_rounded),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 10,
                              ),
                            ),
                            onChanged: (v) => setState(() => _filter = v),
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: templates.isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.layers_outlined,
                                          size: 48,
                                          color: scheme.onSurfaceVariant
                                              .withAlpha(100),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          _filter.isNotEmpty
                                              ? l10n.noSearchResults
                                              : l10n.templateEmptyHint,
                                          style: TextStyle(
                                            color: scheme.onSurfaceVariant,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  )
                                : GridView.builder(
                                    gridDelegate:
                                        const SliverGridDelegateWithMaxCrossAxisExtent(
                                          maxCrossAxisExtent: 160,
                                          mainAxisExtent: 130,
                                          crossAxisSpacing: 8,
                                          mainAxisSpacing: 8,
                                        ),
                                    itemCount: templates.length,
                                    itemBuilder: (_, i) => _TemplateCard(
                                      template: templates[i],
                                      selected: templates[i].id == _selectedId,
                                      onTap: () => setState(
                                        () => _selectedId = templates[i].id,
                                      ),
                                      onDoubleTap: () => _use(templates[i]),
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Right: detail panel
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: selected == null
                        ? const SizedBox(key: ValueKey('none'), width: 220)
                        : SizedBox(
                            key: ValueKey(selected.id),
                            width: 220,
                            child: _TemplateDetailPanel(
                              template: selected,
                              session: widget.session,
                              onUse: () => _use(selected),
                              onDelete: () {
                                setState(() => _selectedId = null);
                                widget.session.deleteTemplate(selected.id);
                              },
                              onExport: () => _exportTemplate(selected),
                            ),
                          ),
                  ),
                ],
              ),
            ),
            // ── Footer ──────────────────────────────────────────────────────
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () =>
                        Navigator.pop(context, const TemplateGalleryResult()),
                    child: Text(l10n.templateBlankPage),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: selected != null ? () => _use(selected) : null,
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

  void _use(FolioPageTemplate template) {
    Navigator.pop(context, TemplateGalleryResult(template: template));
  }

  Future<void> _importTemplate() async {
    final l10n = AppLocalizations.of(context);
    final pick = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['folio-template', 'json'],
      allowMultiple: false,
      dialogTitle: l10n.templateImportPickTitle,
    );
    if (pick == null || pick.files.isEmpty || !mounted) return;
    final path = pick.files.single.path;
    if (path == null) return;
    try {
      widget.session.importTemplateFromFile(path);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.templateImportSuccess)));
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.templateImportError('$e'))));
    }
  }

  Future<void> _exportTemplate(FolioPageTemplate template) async {
    final l10n = AppLocalizations.of(context);
    final safeName = template.name
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '_');
    final dest = await FilePicker.platform.saveFile(
      dialogTitle: l10n.templateExportPickTitle,
      fileName: '$safeName.folio-template',
    );
    if (dest == null || !mounted) return;
    try {
      widget.session.exportTemplateToFile(template, dest);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.templateExportSuccess)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.templateExportError('$e'))));
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({
    required this.template,
    required this.selected,
    required this.onTap,
    required this.onDoubleTap,
  });

  final FolioPageTemplate template;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          color: selected
              ? scheme.secondaryContainer
              : scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? scheme.secondary : scheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(template.emoji ?? '📄', style: const TextStyle(fontSize: 28)),
            const Spacer(),
            Text(
              template.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: selected
                    ? scheme.onSecondaryContainer
                    : scheme.onSurface,
              ),
            ),
            if (template.category.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                template.category,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: selected
                      ? scheme.onSecondaryContainer.withAlpha(180)
                      : scheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _TemplateDetailPanel extends StatelessWidget {
  const _TemplateDetailPanel({
    required this.template,
    required this.session,
    required this.onUse,
    required this.onDelete,
    required this.onExport,
  });

  final FolioPageTemplate template;
  final VaultSession session;
  final VoidCallback onUse;
  final VoidCallback onDelete;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final blockCount = template.blocks.length;

    return Container(
      margin: const EdgeInsets.fromLTRB(0, 0, 12, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(template.emoji ?? '📄', style: const TextStyle(fontSize: 36)),
          const SizedBox(height: 8),
          Text(
            template.name,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          if (template.description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              template.description,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
          if (template.category.isNotEmpty) ...[
            const SizedBox(height: 6),
            Chip(
              label: Text(template.category),
              labelStyle: Theme.of(context).textTheme.labelSmall,
              padding: EdgeInsets.zero,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
          const SizedBox(height: 8),
          Text(
            l10n.templateBlockCount(blockCount),
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const Spacer(),
          FilledButton.tonal(
            onPressed: onUse,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(36),
            ),
            child: Text(l10n.templateUse),
          ),
          const SizedBox(height: 6),
          OutlinedButton.icon(
            onPressed: onExport,
            icon: const Icon(Icons.ios_share_rounded, size: 16),
            label: Text(l10n.templateExport),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(36),
            ),
          ),
          const SizedBox(height: 6),
          TextButton.icon(
            onPressed: onDelete,
            icon: Icon(
              Icons.delete_outline_rounded,
              size: 16,
              color: scheme.error,
            ),
            label: Text(l10n.delete, style: TextStyle(color: scheme.error)),
            style: TextButton.styleFrom(minimumSize: const Size.fromHeight(36)),
          ),
        ],
      ),
    );
  }
}
