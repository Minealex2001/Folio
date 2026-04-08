import 'package:flutter/material.dart';

import '../../../app/ui_tokens.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../models/folio_page.dart';
import 'block_type_catalog.dart';

/// Panel flotante alineado con menús slash, menciones y la barra de formato.
class BlockEditorFloatingPanel extends StatelessWidget {
  const BlockEditorFloatingPanel({
    super.key,
    required this.scheme,
    required this.child,
    this.clipBehavior = Clip.antiAlias,
  });

  final ColorScheme scheme;
  final Widget child;
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.canvas,
      elevation: FolioElevation.menu,
      shadowColor: scheme.shadow.withValues(alpha: FolioAlpha.scrim),
      color: scheme.surfaceContainerHigh,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(FolioRadius.md),
        side: BorderSide(
          color: scheme.outlineVariant.withValues(alpha: FolioAlpha.border),
        ),
      ),
      clipBehavior: clipBehavior,
      child: child,
    );
  }
}

class BlockEditorDragHandle extends StatefulWidget {
  const BlockEditorDragHandle({super.key, required this.iconColor});

  final Color iconColor;

  @override
  State<BlockEditorDragHandle> createState() => _BlockEditorDragHandleState();
}

class _BlockEditorDragHandleState extends State<BlockEditorDragHandle> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.grab,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 22,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _hovered
              ? Theme.of(
                  context,
                ).colorScheme.onSurfaceVariant.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(FolioRadius.sm),
        ),
        child: Icon(
          Icons.drag_indicator,
          size: 18,
          color: widget.iconColor.withValues(alpha: _hovered ? 1.0 : 0.6),
        ),
      ),
    );
  }
}

class BlockEditorInlineSlashList extends StatelessWidget {
  const BlockEditorInlineSlashList({
    super.key,
    required this.scrollController,
    required this.theme,
    required this.scheme,
    required this.items,
    required this.selectedIndex,
    required this.showSections,
    required this.onPick,
  });

  final ScrollController scrollController;
  final ThemeData theme;
  final ColorScheme scheme;
  final List<BlockTypeDef> items;
  final int selectedIndex;
  final bool showSections;
  final void Function(String typeKey) onPick;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    BlockTypeSection? previousSection;
    for (var i = 0; i < items.length; i++) {
      final definition = items[i];
      final selected = i == selectedIndex;
      if (showSections && previousSection != definition.section) {
        previousSection = definition.section;
        children.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(
              FolioSpace.sm,
              FolioSpace.sm,
              FolioSpace.sm,
              FolioSpace.xxs,
            ),
            child: Text(
              blockSectionTitle(definition.section),
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.primary,
                fontWeight: FontWeight.w700,
                fontSize: 11,
                letterSpacing: 0.8,
              ),
            ),
          ),
        );
      }
      children.add(
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: FolioSpace.xxs,
            vertical: 2,
          ),
          child: Material(
            color: selected
                ? scheme.primaryContainer.withValues(alpha: 0.45)
                : Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(FolioRadius.sm),
              onTap: () => onPick(definition.key),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: FolioSpace.xs + 2,
                  vertical: FolioSpace.xxs + 4,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(FolioRadius.sm),
                      ),
                      child: Icon(
                        definition.icon,
                        size: 16,
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: FolioSpace.xs),
                    Expanded(
                      child: showSections
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  definition.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    height: 1.15,
                                  ),
                                ),
                                Text(
                                  definition.hint,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                    fontSize: 11,
                                    height: 1.15,
                                  ),
                                ),
                              ],
                            )
                          : Text(
                              definition.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                height: 1.2,
                              ),
                            ),
                    ),
                    const SizedBox(width: FolioSpace.xs),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest.withValues(
                          alpha: selected ? 0.95 : 0.7,
                        ),
                        borderRadius: BorderRadius.circular(FolioRadius.xs),
                        border: Border.all(
                          color: scheme.outlineVariant.withValues(alpha: 0.45),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        child: Text(
                          '/${definition.key}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Theme(
      data: theme.copyWith(visualDensity: VisualDensity.compact),
      child: ListView(
        controller: scrollController,
        padding: const EdgeInsets.symmetric(vertical: FolioSpace.xxs),
        primary: false,
        physics: const ClampingScrollPhysics(),
        children: children,
      ),
    );
  }
}

class BlockEditorInlineMentionList extends StatelessWidget {
  const BlockEditorInlineMentionList({
    super.key,
    required this.scrollController,
    required this.theme,
    required this.scheme,
    required this.items,
    required this.selectedIndex,
    required this.onPick,
  });

  final ScrollController scrollController;
  final ThemeData theme;
  final ColorScheme scheme;
  final List<FolioPage> items;
  final int selectedIndex;
  final void Function(String pageId) onPick;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Theme(
      data: theme.copyWith(visualDensity: VisualDensity.compact),
      child: ListView.builder(
        controller: scrollController,
        padding: const EdgeInsets.symmetric(vertical: FolioSpace.xxs),
        primary: false,
        physics: const ClampingScrollPhysics(),
        itemCount: items.length,
        itemBuilder: (context, i) {
          final page = items[i];
          final selected = i == selectedIndex;
          final title =
              page.title.trim().isEmpty ? l10n.untitled : page.title;
          return Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: FolioSpace.xxs,
              vertical: 2,
            ),
            child: Material(
              color: selected
                  ? scheme.primaryContainer.withValues(alpha: 0.45)
                  : Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(FolioRadius.sm),
                onTap: () => onPick(page.id),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: FolioSpace.xs + 2,
                    vertical: FolioSpace.xxs + 4,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: scheme.primaryContainer.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(FolioRadius.sm),
                        ),
                        child: Icon(
                          Icons.description_outlined,
                          size: 16,
                          color: scheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(width: FolioSpace.xs),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '@$title',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                height: 1.15,
                              ),
                            ),
                            Text(
                              l10n.blockMentionPageSubtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                                fontSize: 11,
                                height: 1.15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class BlockTypePickerSheet extends StatefulWidget {
  const BlockTypePickerSheet({super.key, required this.catalog});

  final List<BlockTypeDef> catalog;

  @override
  State<BlockTypePickerSheet> createState() => BlockTypePickerSheetState();
}

class BlockTypePickerSheetState extends State<BlockTypePickerSheet> {
  final _filter = TextEditingController();
  var _query = '';

  @override
  void initState() {
    super.initState();
    _filter.addListener(() => setState(() => _query = _filter.text));
  }

  @override
  void dispose() {
    _filter.dispose();
    super.dispose();
  }

  List<BlockTypeDef> _filtered() {
    return filterBlockTypeCatalog(
      _query,
    ).where((definition) => widget.catalog.contains(definition)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final filtered = _filtered();
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return DraggableScrollableSheet(
      initialChildSize: 0.58,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return Material(
          color: scheme.surface,
          elevation: 2,
          shadowColor: scheme.shadow.withValues(alpha: 0.2),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: EdgeInsets.only(bottom: bottomInset),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 10),
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: scheme.outlineVariant,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.blockTypesSheetTitle,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.blockTypesSheetSubtitle,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: _filter,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: AppLocalizations.of(
                        context,
                      ).searchByNameOrShortcut,
                      filled: true,
                      fillColor: scheme.surfaceContainerHighest.withValues(
                        alpha: 0.42,
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: scheme.onSurfaceVariant,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Text(
                              l10n.blockTypeFilterEmpty,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        )
                      : ListView(
                          controller: scrollController,
                          padding: const EdgeInsets.fromLTRB(8, 4, 8, 28),
                          children: _sectionedTiles(
                            context,
                            theme,
                            scheme,
                            filtered,
                          ),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _sectionedTiles(
    BuildContext context,
    ThemeData theme,
    ColorScheme scheme,
    List<BlockTypeDef> items,
  ) {
    final children = <Widget>[];
    BlockTypeSection? previousSection;
    for (final definition in items) {
      if (previousSection != definition.section) {
        previousSection = definition.section;
        children.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 6),
            child: Text(
              blockSectionTitle(definition.section),
              style: theme.textTheme.labelLarge?.copyWith(
                color: scheme.primary,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ),
        );
      }
      children.add(
        _BlockTypeTile(definition: definition, scheme: scheme, theme: theme),
      );
    }
    return children;
  }
}

class _BlockTypeTile extends StatelessWidget {
  const _BlockTypeTile({
    required this.definition,
    required this.scheme,
    required this.theme,
  });

  final BlockTypeDef definition;
  final ColorScheme scheme;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: scheme.surfaceContainerLow.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.pop(context, definition.key),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    definition.icon,
                    color: scheme.onPrimaryContainer,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              definition.label,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.1,
                              ),
                            ),
                          ),
                          if (definition.beta) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: scheme.tertiaryContainer.withValues(
                                  alpha: 0.9,
                                ),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                l10n.aiBetaBadge,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: scheme.onTertiaryContainer,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        definition.hint,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          height: 1.25,
                        ),
                      ),
                    ],
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
