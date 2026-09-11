import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';

/// Muestra un diálogo interactivo para previsualizar, desmarcar, editar o
/// añadir items al checklist generado por la IA antes de insertarlos como
/// tareas en la página.
Future<List<String>?> showMeetingChecklistDialog({
  required BuildContext context,
  required List<String> suggestions,
  required ColorScheme scheme,
}) {
  return showDialog<List<String>>(
    context: context,
    builder: (ctx) => _MeetingChecklistDialog(
      suggestions: suggestions,
      scheme: scheme,
    ),
  );
}

class _ChecklistItemEntry {
  _ChecklistItemEntry({
    required String text,
  })  : controller = TextEditingController(text: text),
        selected = true;

  final TextEditingController controller;
  bool selected;

  void dispose() => controller.dispose();
}

class _MeetingChecklistDialog extends StatefulWidget {
  const _MeetingChecklistDialog({
    required this.suggestions,
    required this.scheme,
  });

  final List<String> suggestions;
  final ColorScheme scheme;

  @override
  State<_MeetingChecklistDialog> createState() =>
      _MeetingChecklistDialogState();
}

class _MeetingChecklistDialogState extends State<_MeetingChecklistDialog> {
  final List<_ChecklistItemEntry> _entries = [];
  final TextEditingController _customController = TextEditingController();

  @override
  void initState() {
    super.initState();
    for (final s in widget.suggestions) {
      final t = s.trim();
      if (t.isNotEmpty) {
        _entries.add(_ChecklistItemEntry(text: t));
      }
    }
  }

  @override
  void dispose() {
    for (final e in _entries) {
      e.dispose();
    }
    _customController.dispose();
    super.dispose();
  }

  int get _selectedCount => _entries.where((e) => e.selected).length;

  void _addCustomItem() {
    final text = _customController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _entries.add(_ChecklistItemEntry(text: text));
      _customController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.checklist_rounded, color: widget.scheme.primary, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n.meetingNoteChecklistDialogTitle,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.meetingNoteChecklistDialogSubtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: widget.scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              if (_entries.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Text(
                      l10n.meetingNotePrepFailed,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: widget.scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                )
              else
                ..._entries.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Checkbox(
                          value: item.selected,
                          activeColor: widget.scheme.primary,
                          onChanged: (val) {
                            setState(() => item.selected = val ?? false);
                          },
                        ),
                        Expanded(
                          child: TextField(
                            controller: item.controller,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: item.selected
                                  ? widget.scheme.onSurface
                                  : widget.scheme.onSurfaceVariant
                                      .withValues(alpha: 0.6),
                              decoration: item.selected
                                  ? null
                                  : TextDecoration.lineThrough,
                            ),
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 8,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                                borderSide: BorderSide(
                                  color: widget.scheme.outlineVariant
                                      .withValues(alpha: 0.5),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 16),
                          visualDensity: VisualDensity.compact,
                          color: widget.scheme.onSurfaceVariant,
                          onPressed: () {
                            setState(() {
                              final removed = _entries.removeAt(index);
                              removed.dispose();
                            });
                          },
                        ),
                      ],
                    ),
                  );
                }),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _customController,
                      style: theme.textTheme.bodySmall,
                      decoration: InputDecoration(
                        hintText: l10n.meetingNoteChecklistAddCustom,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      onSubmitted: (_) => _addCustomItem(),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton.filledTonal(
                    onPressed: _addCustomItem,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          onPressed: _selectedCount == 0
              ? null
              : () {
                  final result = _entries
                      .where((e) => e.selected)
                      .map((e) => e.controller.text.trim())
                      .where((t) => t.isNotEmpty)
                      .toList();
                  Navigator.of(context).pop(result);
                },
          child: Text(l10n.meetingNoteChecklistConfirm(_selectedCount)),
        ),
      ],
    );
  }
}
