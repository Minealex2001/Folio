import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';

import '../app_settings.dart';
import '../ui_tokens.dart';
import 'folio_dialog.dart';
import 'folio_icon_token_view.dart';

enum _FolioIconPickerTab { quick, imported, all }

Future<String?> showFolioIconPicker({
  required BuildContext context,
  required AppSettings appSettings,
  required String title,
  required String helperText,
  required String fallbackText,
  required List<String> quickIcons,
  required String customInputLabel,
  required String cancelLabel,
  required String saveLabel,
  required String removeLabel,
  required String quickTabLabel,
  required String importedTabLabel,
  required String allEmojiTabLabel,
  required String emptyImportedLabel,
  String? initialToken,
}) {
  return showGeneralDialog<String>(
    context: context,
    barrierDismissible: true,
    barrierLabel: title,
    barrierColor: Colors.black.withValues(alpha: 0.14),
    transitionDuration: FolioMotion.short2,
    pageBuilder: (ctx, _, _) => SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(FolioSpace.lg),
          child: _FolioIconPickerDialog(
            appSettings: appSettings,
            title: title,
            helperText: helperText,
            fallbackText: fallbackText,
            quickIcons: quickIcons,
            customInputLabel: customInputLabel,
            cancelLabel: cancelLabel,
            saveLabel: saveLabel,
            removeLabel: removeLabel,
            quickTabLabel: quickTabLabel,
            importedTabLabel: importedTabLabel,
            allEmojiTabLabel: allEmojiTabLabel,
            emptyImportedLabel: emptyImportedLabel,
            initialToken: initialToken,
          ),
        ),
      ),
    ),
    transitionBuilder: (ctx, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class _FolioIconPickerDialog extends StatefulWidget {
  const _FolioIconPickerDialog({
    required this.appSettings,
    required this.title,
    required this.helperText,
    required this.fallbackText,
    required this.quickIcons,
    required this.customInputLabel,
    required this.cancelLabel,
    required this.saveLabel,
    required this.removeLabel,
    required this.quickTabLabel,
    required this.importedTabLabel,
    required this.allEmojiTabLabel,
    required this.emptyImportedLabel,
    this.initialToken,
  });

  final AppSettings appSettings;
  final String title;
  final String helperText;
  final String fallbackText;
  final List<String> quickIcons;
  final String customInputLabel;
  final String cancelLabel;
  final String saveLabel;
  final String removeLabel;
  final String quickTabLabel;
  final String importedTabLabel;
  final String allEmojiTabLabel;
  final String emptyImportedLabel;
  final String? initialToken;

  @override
  State<_FolioIconPickerDialog> createState() => _FolioIconPickerDialogState();
}

class _FolioIconPickerDialogState extends State<_FolioIconPickerDialog> {
  late String _selected;
  late String _manualValue;
  late _FolioIconPickerTab _activeTab;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialToken?.trim() ?? '';
    _manualValue = widget.appSettings.isCustomIconToken(_selected)
        ? ''
        : _selected;
    if (widget.appSettings.isCustomIconToken(_selected) &&
        widget.appSettings.customIcons.isNotEmpty) {
      _activeTab = _FolioIconPickerTab.imported;
    } else {
      _activeTab = _FolioIconPickerTab.quick;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final hasImported = widget.appSettings.customIcons.isNotEmpty;
    final tabs = <ButtonSegment<_FolioIconPickerTab>>[
      ButtonSegment<_FolioIconPickerTab>(
        value: _FolioIconPickerTab.quick,
        label: Text(widget.quickTabLabel),
        icon: const Icon(Icons.auto_awesome_outlined, size: 16),
      ),
      if (hasImported)
        ButtonSegment<_FolioIconPickerTab>(
          value: _FolioIconPickerTab.imported,
          label: Text(widget.importedTabLabel),
          icon: const Icon(Icons.collections_bookmark_outlined, size: 16),
        ),
      ButtonSegment<_FolioIconPickerTab>(
        value: _FolioIconPickerTab.all,
        label: Text(widget.allEmojiTabLabel),
        icon: const Icon(Icons.sentiment_satisfied_alt_outlined, size: 16),
      ),
    ];
    return Material(
      color: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(FolioRadius.xl),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.45),
            ),
            boxShadow: FolioShadows.card(scheme),
          ),
          child: Padding(
            padding: const EdgeInsets.all(FolioSpace.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(FolioRadius.md),
                      ),
                      child: Center(
                        child: FolioIconTokenView(
                          appSettings: widget.appSettings,
                          token: _selected,
                          fallbackText: widget.fallbackText,
                          size: 22,
                        ),
                      ),
                    ),
                    const SizedBox(width: FolioSpace.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.helperText,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: widget.cancelLabel,
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded, size: 18),
                    ),
                  ],
                ),
                const SizedBox(height: FolioSpace.md),
                Row(
                  children: [
                    Expanded(
                      child: SegmentedButton<_FolioIconPickerTab>(
                        segments: tabs,
                        selected: {_activeTab},
                        showSelectedIcon: false,
                        onSelectionChanged: (selection) {
                          setState(() {
                            _activeTab = selection.first;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: FolioSpace.xs),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(''),
                      child: Text(widget.removeLabel),
                    ),
                  ],
                ),
                const SizedBox(height: FolioSpace.md),
                AnimatedSwitcher(
                  duration: FolioMotion.short2,
                  child: KeyedSubtree(
                    key: ValueKey(_activeTab),
                    child: switch (_activeTab) {
                      _FolioIconPickerTab.quick => _buildQuickTab(context),
                      _FolioIconPickerTab.imported => _buildImportedTab(
                        context,
                      ),
                      _FolioIconPickerTab.all => _buildAllEmojiTab(context),
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickTab(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _IconGrid(
          appSettings: widget.appSettings,
          items: widget.quickIcons,
          selected: _selected,
          fallbackText: widget.fallbackText,
          onSelect: (value) {
            Navigator.of(context).pop(value);
          },
        ),
        const SizedBox(height: FolioSpace.md),
        TextFormField(
          initialValue: _manualValue,
          decoration: InputDecoration(
            labelText: widget.customInputLabel,
            hintText: widget.fallbackText,
          ),
          onChanged: (value) {
            setState(() {
              _manualValue = value.trim();
              _selected = value.trim();
            });
          },
          onFieldSubmitted: (value) {
            Navigator.of(context).pop(value.trim());
          },
        ),
      ],
    );
  }

  Widget _buildImportedTab(BuildContext context) {
    if (widget.appSettings.customIcons.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: FolioSpace.sm),
        child: Text(
          widget.emptyImportedLabel,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    return _IconGrid(
      appSettings: widget.appSettings,
      items: widget.appSettings.customIcons.map((icon) => icon.token).toList(),
      selected: _selected,
      fallbackText: widget.fallbackText,
      onSelect: (value) {
        Navigator.of(context).pop(value);
      },
    );
  }

  Widget _buildAllEmojiTab(BuildContext context) {
    return Container(
      height: 240,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(FolioRadius.lg),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: EmojiPicker(
        onEmojiSelected: (_, emoji) {
          Navigator.of(context).pop(emoji.emoji);
        },
      ),
    );
  }
}

class _IconGrid extends StatelessWidget {
  const _IconGrid({
    required this.appSettings,
    required this.items,
    required this.selected,
    required this.fallbackText,
    required this.onSelect,
  });

  final AppSettings appSettings;
  final List<String> items;
  final String selected;
  final String fallbackText;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: FolioSpace.xs,
      runSpacing: FolioSpace.xs,
      children: items.map((item) {
        final active = selected == item;
        return InkWell(
          borderRadius: BorderRadius.circular(FolioRadius.md),
          onTap: () => onSelect(item),
          child: AnimatedContainer(
            duration: FolioMotion.short2,
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: active ? scheme.primaryContainer : scheme.surfaceContainer,
              borderRadius: BorderRadius.circular(FolioRadius.md),
              border: Border.all(
                color: active ? scheme.primary : scheme.outlineVariant,
                width: active ? 1.5 : 1,
              ),
              boxShadow: active ? FolioShadows.card(scheme) : const [],
            ),
            child: Center(
              child: FolioIconTokenView(
                appSettings: appSettings,
                token: item,
                fallbackText: fallbackText,
                size: 24,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
