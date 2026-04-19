import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../../../app/ui_tokens.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../models/folio_page.dart';
import '../../../models/page_property.dart';
import '../../../session/vault_session.dart';

const _uuid = Uuid();

// ---------------------------------------------------------------------------
// Colors for status chips (index-based cycling palette)
// ---------------------------------------------------------------------------
Color _statusBgColor(BuildContext context, String value, List<String> options) {
  final idx = options.indexOf(value);
  final scheme = Theme.of(context).colorScheme;
  final palette = [
    scheme.surfaceContainerHighest, // 0 – not started (neutral)
    scheme.primaryContainer, // 1 – in progress (accent)
    const Color(0xFFD4EDDA), // 2 – done (green)
    const Color(0xFFFFE0B2), // 3 – custom (orange)
    const Color(0xFFE1BEE7), // 4 – custom (purple)
    const Color(0xFFB2EBF2), // 5 – custom (cyan)
  ];
  if (idx < 0) return palette[0];
  return palette[idx % palette.length];
}

Color _statusFgColor(BuildContext context, String value, List<String> options) {
  final idx = options.indexOf(value);
  final scheme = Theme.of(context).colorScheme;
  final palette = [
    scheme.onSurfaceVariant, // 0
    scheme.onPrimaryContainer, // 1
    const Color(0xFF1B5E20), // 2 – dark green
    const Color(0xFFE65100), // 3 – dark orange
    const Color(0xFF4A148C), // 4 – dark purple
    const Color(0xFF006064), // 5 – dark cyan
  ];
  if (idx < 0) return palette[0];
  return palette[idx % palette.length];
}

// ---------------------------------------------------------------------------
// Icon for each property type
// ---------------------------------------------------------------------------
IconData _iconForType(PagePropertyType type) {
  switch (type) {
    case PagePropertyType.text:
      return Icons.short_text_rounded;
    case PagePropertyType.number:
      return Icons.tag_rounded;
    case PagePropertyType.date:
      return Icons.calendar_today_rounded;
    case PagePropertyType.select:
      return Icons.radio_button_checked_rounded;
    case PagePropertyType.status:
      return Icons.circle_rounded;
    case PagePropertyType.url:
      return Icons.link_rounded;
    case PagePropertyType.checkbox:
      return Icons.check_box_outlined;
  }
}

// ---------------------------------------------------------------------------
// Main widget
// ---------------------------------------------------------------------------

/// Inline frontmatter properties shown between the page title and the editor.
class PagePropertiesWidget extends StatelessWidget {
  const PagePropertiesWidget({
    super.key,
    required this.page,
    required this.session,
    required this.readOnly,
  });

  final FolioPage page;
  final VaultSession session;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final props = page.properties;
    final hasTags = page.tags.isNotEmpty;
    if (props.isEmpty && !hasTags && readOnly) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Tags row
        _TagsRow(page: page, session: session, readOnly: readOnly),
        for (final prop in props)
          _PropertyRow(
            key: ValueKey(prop.id),
            prop: prop,
            pageId: page.id,
            session: session,
            readOnly: readOnly,
          ),
        if (!readOnly)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _showAddPropertySheet(context),
              icon: const Icon(Icons.add_rounded, size: 15),
              label: Text(l10n.propAdd),
              style: TextButton.styleFrom(
                foregroundColor: scheme.onSurfaceVariant,
                textStyle: Theme.of(context).textTheme.bodySmall,
                padding: const EdgeInsets.symmetric(
                  horizontal: FolioSpace.xxs,
                  vertical: 2,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        const SizedBox(height: FolioSpace.xs),
        Divider(height: 1, color: scheme.outlineVariant.withValues(alpha: 0.5)),
        const SizedBox(height: FolioSpace.xs),
      ],
    );
  }

  void _showAddPropertySheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (ctx) => _AddPropertySheet(pageId: page.id, session: session),
    );
  }
}

// ---------------------------------------------------------------------------
// Tags row — same 32 px height as other property rows, tap → bottom sheet
// ---------------------------------------------------------------------------

class _TagsRow extends StatelessWidget {
  const _TagsRow({
    required this.page,
    required this.session,
    required this.readOnly,
  });

  final FolioPage page;
  final VaultSession session;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final tags = page.tags;

    if (tags.isEmpty && readOnly) return const SizedBox.shrink();

    return SizedBox(
      height: 32,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: readOnly ? null : () => _openSheet(context),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              Icons.label_outline_rounded,
              size: 14,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(width: FolioSpace.xs),
            SizedBox(
              width: 108,
              child: Text(
                l10n.tagSectionTitle,
                style: textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: FolioSpace.xs),
            Expanded(
              child: tags.isEmpty
                  ? Text(
                      l10n.tagAdd,
                      style: textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
                      ),
                    )
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final tag in tags) ...[
                            _TagChip(label: tag),
                            const SizedBox(width: 4),
                          ],
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _openSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (ctx) => _TagsSheet(pageId: page.id, session: session),
    );
  }
}

// ---------------------------------------------------------------------------
// Tags management bottom sheet
// ---------------------------------------------------------------------------

class _TagsSheet extends StatefulWidget {
  const _TagsSheet({required this.pageId, required this.session});

  final String pageId;
  final VaultSession session;

  @override
  State<_TagsSheet> createState() => _TagsSheetState();
}

class _TagsSheetState extends State<_TagsSheet> {
  final TextEditingController _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final t = _ctrl.text.trim();
    if (t.isNotEmpty) {
      widget.session.addPageTag(widget.pageId, t);
      _ctrl.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.only(
        left: FolioSpace.md,
        right: FolioSpace.md,
        top: FolioSpace.xs,
        bottom: MediaQuery.viewInsetsOf(context).bottom + FolioSpace.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.tagSectionTitle, style: textTheme.titleSmall),
          const SizedBox(height: FolioSpace.sm),
          ListenableBuilder(
            listenable: widget.session,
            builder: (context, _) {
              final idx = widget.session.pages.indexWhere(
                (p) => p.id == widget.pageId,
              );
              final tags = idx >= 0
                  ? widget.session.pages[idx].tags
                  : const <String>[];
              if (tags.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(bottom: FolioSpace.sm),
                child: Wrap(
                  spacing: FolioSpace.xs,
                  runSpacing: FolioSpace.xs,
                  children: [
                    for (final tag in tags)
                      InputChip(
                        label: Text(tag, style: textTheme.labelMedium),
                        deleteIcon: const Icon(Icons.close_rounded, size: 14),
                        onDeleted: () =>
                            widget.session.removePageTag(widget.pageId, tag),
                      ),
                  ],
                ),
              );
            },
          ),
          TextField(
            controller: _ctrl,
            autofocus: true,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              hintText: l10n.tagInputHint,
              prefixIcon: const Icon(Icons.add_rounded),
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tag chip (display only — removal handled inside _TagsSheet)
// ---------------------------------------------------------------------------

class _TagChip extends StatelessWidget {
  const _TagChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(FolioRadius.xs),
      ),
      child: Text(
        label,
        style: textTheme.labelSmall?.copyWith(
          color: scheme.onSecondaryContainer,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Property row
// ---------------------------------------------------------------------------

class _PropertyRow extends StatelessWidget {
  const _PropertyRow({
    super.key,
    required this.prop,
    required this.pageId,
    required this.session,
    required this.readOnly,
  });

  final FolioPageProperty prop;
  final String pageId;
  final VaultSession session;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return GestureDetector(
      onLongPress: readOnly ? null : () => _showPropertyOptions(context),
      child: SizedBox(
        height: 32,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Type icon
            Icon(
              _iconForType(prop.type),
              size: 14,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(width: FolioSpace.xs),
            // Property name (fixed width)
            SizedBox(
              width: 108,
              child: Text(
                prop.name,
                style: textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: FolioSpace.xs),
            // Value (tap to edit)
            Expanded(
              child: _ValueDisplay(
                prop: prop,
                pageId: pageId,
                session: session,
                readOnly: readOnly,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPropertyOptions(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.drive_file_rename_outline_rounded),
              title: Text(l10n.propRename),
              onTap: () {
                Navigator.pop(ctx);
                _showRenameDialog(context);
              },
            ),
            ListTile(
              leading: Icon(
                Icons.delete_outline_rounded,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(
                l10n.propRemove,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              onTap: () {
                Navigator.pop(ctx);
                session.removePageProperty(pageId, prop.id);
              },
            ),
            const SizedBox(height: FolioSpace.sm),
          ],
        ),
      ),
    );
  }

  void _showRenameDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController(text: prop.name);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.propRename),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: prop.name),
          onSubmitted: (_) {
            session.renamePageProperty(pageId, prop.id, controller.text);
            Navigator.pop(ctx);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () {
              session.renamePageProperty(pageId, prop.id, controller.text);
              Navigator.pop(ctx);
            },
            child: Text(MaterialLocalizations.of(ctx).okButtonLabel),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Value display (tap to edit)
// ---------------------------------------------------------------------------

class _ValueDisplay extends StatelessWidget {
  const _ValueDisplay({
    required this.prop,
    required this.pageId,
    required this.session,
    required this.readOnly,
  });

  final FolioPageProperty prop;
  final String pageId;
  final VaultSession session;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    switch (prop.type) {
      // --- Checkbox --- tap directly toggles
      case PagePropertyType.checkbox:
        final checked = prop.value == true;
        return Align(
          alignment: Alignment.centerLeft,
          child: GestureDetector(
            onTap: readOnly
                ? null
                : () => session.updatePagePropertyValue(
                    pageId,
                    prop.id,
                    !checked,
                  ),
            child: Icon(
              checked
                  ? Icons.check_box_rounded
                  : Icons.check_box_outline_blank_rounded,
              size: 18,
              color: checked ? scheme.primary : scheme.onSurfaceVariant,
            ),
          ),
        );

      // --- Status chip ---
      case PagePropertyType.status:
        final value = prop.value as String?;
        final options = prop.options.isNotEmpty
            ? prop.options
            : FolioPageProperty.defaultStatusOptions;
        final label = value ?? l10n.propNotSet;
        final bg = value != null
            ? _statusBgColor(context, value, options)
            : null;
        final fg = value != null
            ? _statusFgColor(context, value, options)
            : null;

        return Align(
          alignment: Alignment.centerLeft,
          child: GestureDetector(
            onTap: readOnly
                ? null
                : () => _showSelectSheet(context, options, isStatus: true),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: bg ?? scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(FolioRadius.xs),
              ),
              child: Text(
                label,
                style: textTheme.bodySmall?.copyWith(
                  color: fg ?? scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        );

      // --- Select chip ---
      case PagePropertyType.select:
        final value = prop.value as String?;
        return Align(
          alignment: Alignment.centerLeft,
          child: GestureDetector(
            onTap: readOnly
                ? null
                : () => _showSelectSheet(context, prop.options),
            child: value != null
                ? Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(FolioRadius.xs),
                    ),
                    child: Text(
                      value,
                      style: textTheme.bodySmall?.copyWith(
                        color: scheme.onSecondaryContainer,
                      ),
                    ),
                  )
                : Text(
                    l10n.propNotSet,
                    style: textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                  ),
          ),
        );

      // --- Date ---
      case PagePropertyType.date:
        final ms = prop.value as int?;
        final date = ms != null
            ? DateTime.fromMillisecondsSinceEpoch(ms)
            : null;
        return GestureDetector(
          onTap: readOnly ? null : () => _pickDate(context, date),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              date != null
                  ? '${date.day.toString().padLeft(2, '0')}/'
                        '${date.month.toString().padLeft(2, '0')}/'
                        '${date.year}'
                  : l10n.propNotSet,
              style: textTheme.bodySmall?.copyWith(
                color: date != null
                    ? scheme.onSurface
                    : scheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ),
          ),
        );

      // --- URL ---
      case PagePropertyType.url:
        final url = prop.value as String?;
        return GestureDetector(
          onTap: readOnly
              ? (url != null ? () => _launchUrl(url) : null)
              : () => _editTextValue(context, keyboard: TextInputType.url),
          child: Align(
            alignment: Alignment.centerLeft,
            child: url != null && url.isNotEmpty
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          url,
                          style: textTheme.bodySmall?.copyWith(
                            color: scheme.primary,
                            decoration: TextDecoration.underline,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!readOnly)
                        Padding(
                          padding: const EdgeInsets.only(left: 2),
                          child: Icon(
                            Icons.open_in_new_rounded,
                            size: 12,
                            color: scheme.primary,
                          ),
                        ),
                    ],
                  )
                : Text(
                    l10n.propNotSet,
                    style: textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                  ),
          ),
        );

      // --- Number ---
      case PagePropertyType.number:
        final num = prop.value;
        return GestureDetector(
          onTap: readOnly ? null : () => _editNumberValue(context),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              num != null ? '$num' : l10n.propNotSet,
              style: textTheme.bodySmall?.copyWith(
                color: num != null
                    ? scheme.onSurface
                    : scheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ),
          ),
        );

      // --- Text (default) ---
      case PagePropertyType.text:
        final text = prop.value as String?;
        return GestureDetector(
          onTap: readOnly ? null : () => _editTextValue(context),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              text != null && text.isNotEmpty ? text : l10n.propNotSet,
              style: textTheme.bodySmall?.copyWith(
                color: text != null && text.isNotEmpty
                    ? scheme.onSurface
                    : scheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
    }
  }

  // --- Helpers ---

  Future<void> _editTextValue(
    BuildContext context, {
    TextInputType keyboard = TextInputType.text,
  }) async {
    final ctrl = TextEditingController(text: prop.value as String? ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(prop.name),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: keyboard,
          decoration: InputDecoration(hintText: prop.name),
          onSubmitted: (_) => Navigator.pop(ctx, ctrl.text),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: Text(MaterialLocalizations.of(ctx).okButtonLabel),
          ),
        ],
      ),
    );
    if (result != null) {
      session.updatePagePropertyValue(pageId, prop.id, result.trim());
    }
  }

  Future<void> _editNumberValue(BuildContext context) async {
    final ctrl = TextEditingController(
      text: prop.value != null ? '${prop.value}' : '',
    );
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(prop.name),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-]')),
          ],
          onSubmitted: (_) => Navigator.pop(ctx, ctrl.text),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: Text(MaterialLocalizations.of(ctx).okButtonLabel),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      final parsed = double.tryParse(result);
      session.updatePagePropertyValue(pageId, prop.id, parsed ?? result);
    }
  }

  Future<void> _pickDate(BuildContext context, DateTime? current) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      session.updatePagePropertyValue(
        pageId,
        prop.id,
        picked.millisecondsSinceEpoch,
      );
    }
  }

  void _showSelectSheet(
    BuildContext context,
    List<String> options, {
    bool isStatus = false,
  }) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (ctx) => _SelectSheet(
        prop: prop,
        pageId: pageId,
        session: session,
        isStatus: isStatus,
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

// ---------------------------------------------------------------------------
// Select / Status sheet
// ---------------------------------------------------------------------------

class _SelectSheet extends StatefulWidget {
  const _SelectSheet({
    required this.prop,
    required this.pageId,
    required this.session,
    required this.isStatus,
  });

  final FolioPageProperty prop;
  final String pageId;
  final VaultSession session;
  final bool isStatus;

  @override
  State<_SelectSheet> createState() => _SelectSheetState();
}

class _SelectSheetState extends State<_SelectSheet> {
  late List<String> _options;
  final TextEditingController _newOptionCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _options = List<String>.from(
      widget.prop.options.isNotEmpty
          ? widget.prop.options
          : (widget.isStatus ? FolioPageProperty.defaultStatusOptions : []),
    );
  }

  @override
  void dispose() {
    _newOptionCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final selected = widget.prop.value as String?;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                FolioSpace.md,
                0,
                FolioSpace.md,
                FolioSpace.xs,
              ),
              child: Text(
                widget.prop.name,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            if (_options.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: FolioSpace.md,
                  vertical: FolioSpace.sm,
                ),
                child: Text(
                  l10n.propNotSet,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _options.length,
                  itemBuilder: (_, i) {
                    final opt = _options[i];
                    final isSelected = opt == selected;
                    final bg = widget.isStatus
                        ? _statusBgColor(context, opt, _options)
                        : scheme.secondaryContainer;
                    final fg = widget.isStatus
                        ? _statusFgColor(context, opt, _options)
                        : scheme.onSecondaryContainer;
                    return ListTile(
                      dense: true,
                      leading: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: bg,
                          shape: BoxShape.circle,
                        ),
                      ),
                      title: Text(
                        opt,
                        style: TextStyle(
                          color: isSelected ? scheme.primary : fg,
                          fontWeight: isSelected ? FontWeight.w600 : null,
                        ),
                      ),
                      trailing: isSelected
                          ? Icon(
                              Icons.check_rounded,
                              size: 16,
                              color: scheme.primary,
                            )
                          : null,
                      onTap: () {
                        widget.session.updatePagePropertyValue(
                          widget.pageId,
                          widget.prop.id,
                          opt,
                        );
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            // Clear selection
            if (selected != null)
              ListTile(
                dense: true,
                leading: Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: scheme.onSurfaceVariant,
                ),
                title: Text(
                  l10n.propNotSet,
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
                onTap: () {
                  widget.session.updatePagePropertyValue(
                    widget.pageId,
                    widget.prop.id,
                    null,
                  );
                  Navigator.pop(context);
                },
              ),
            const Divider(height: 1),
            // Add new option
            Padding(
              padding: const EdgeInsets.fromLTRB(
                FolioSpace.md,
                FolioSpace.xs,
                FolioSpace.md,
                FolioSpace.md,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _newOptionCtrl,
                      decoration: InputDecoration(
                        hintText: l10n.propAddOption,
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(FolioRadius.sm),
                        ),
                      ),
                      onSubmitted: (_) => _addOption(),
                    ),
                  ),
                  const SizedBox(width: FolioSpace.xs),
                  FilledButton.tonal(
                    onPressed: _addOption,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: FolioSpace.sm,
                        vertical: FolioSpace.xs,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Icon(Icons.add_rounded, size: 18),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _addOption() {
    final o = _newOptionCtrl.text.trim();
    if (o.isEmpty || _options.contains(o)) return;
    widget.session.addPagePropertyOption(widget.pageId, widget.prop.id, o);
    setState(() {
      _options.add(o);
      _newOptionCtrl.clear();
    });
  }
}

// ---------------------------------------------------------------------------
// Add property sheet (type picker)
// ---------------------------------------------------------------------------

class _AddPropertySheet extends StatelessWidget {
  const _AddPropertySheet({required this.pageId, required this.session});

  final String pageId;
  final VaultSession session;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final types = <PagePropertyType, String>{
      PagePropertyType.text: l10n.propTypeText,
      PagePropertyType.number: l10n.propTypeNumber,
      PagePropertyType.date: l10n.propTypeDate,
      PagePropertyType.select: l10n.propTypeSelect,
      PagePropertyType.status: l10n.propTypeStatus,
      PagePropertyType.url: l10n.propTypeUrl,
      PagePropertyType.checkbox: l10n.propTypeCheckbox,
    };

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              FolioSpace.md,
              0,
              FolioSpace.md,
              FolioSpace.xs,
            ),
            child: Text(
              l10n.propAdd,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          for (final entry in types.entries)
            ListTile(
              dense: true,
              leading: Icon(_iconForType(entry.key), size: 18),
              title: Text(entry.value),
              onTap: () {
                Navigator.pop(context);
                final prop = FolioPageProperty(
                  id: _uuid.v4(),
                  name: entry.value,
                  type: entry.key,
                );
                session.addPageProperty(pageId, prop);
              },
            ),
          const SizedBox(height: FolioSpace.sm),
        ],
      ),
    );
  }
}
