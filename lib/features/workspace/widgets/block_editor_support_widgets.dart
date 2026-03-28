import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import 'block_type_catalog.dart';

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
          borderRadius: BorderRadius.circular(6),
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
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
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
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Material(
            color: selected
                ? scheme.primaryContainer.withValues(alpha: 0.45)
                : Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => onPick(definition.key),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
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
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        definition.icon,
                        size: 16,
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: 12),
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
                    const SizedBox(width: 8),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest.withValues(
                          alpha: selected ? 0.95 : 0.7,
                        ),
                        borderRadius: BorderRadius.circular(6),
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

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(vertical: 4),
      primary: false,
      physics: const ClampingScrollPhysics(),
      children: children,
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
                        'Tipos de bloque',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Elige cómo se verá este bloque',
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
                              'Nada coincide con tu búsqueda',
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
                                'BETA',
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
