import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../models/folio_canvas_data.dart';

/// Panel lateral de capas: orden Z, visibilidad, bloqueo.
class CanvasLayersPanel extends StatelessWidget {
  const CanvasLayersPanel({
    super.key,
    required this.data,
    required this.selectedIds,
    required this.onReorder,
    required this.onToggleVisible,
    required this.onToggleLock,
    required this.onSelect,
  });

  final FolioCanvasData data;
  final Set<String> selectedIds;
  /// Índices en la lista mostrada (arriba = más al frente).
  final void Function(int displayOldIndex, int displayNewIndex) onReorder;
  final void Function(String nodeId) onToggleVisible;
  final void Function(String nodeId) onToggleLock;
  final void Function(String nodeId) onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    // Orden de capas: el último de la lista se pinta encima.
    final ordered = List<FolioCanvasNode>.from(data.nodes.reversed);

    return Material(
      elevation: 8,
      child: Container(
        width: 260,
        color: scheme.surfaceContainerLow,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                l10n.canvasLayersTitle,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            Expanded(
              child: ReorderableListView.builder(
                buildDefaultDragHandles: false,
                itemCount: ordered.length,
                onReorder: onReorder,
                itemBuilder: (context, index) {
                  final node = ordered[index];
                  final selected = selectedIds.contains(node.id);
                  final title = _layerTitle(node, l10n);
                  return Material(
                    key: ValueKey(node.id),
                    color: selected ? scheme.primaryContainer.withValues(alpha: 0.35) : Colors.transparent,
                    child: ListTile(
                      dense: true,
                      leading: ReorderableDragStartListener(
                        index: index,
                        child: Icon(Icons.drag_handle_rounded, color: scheme.outline),
                      ),
                      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(
                              node.visible ? Icons.visibility_rounded : Icons.visibility_off_outlined,
                              size: 20,
                            ),
                            onPressed: () => onToggleVisible(node.id),
                            visualDensity: VisualDensity.compact,
                          ),
                          IconButton(
                            icon: Icon(
                              node.locked ? Icons.lock_rounded : Icons.lock_open_rounded,
                              size: 20,
                            ),
                            onPressed: () => onToggleLock(node.id),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                      onTap: () => onSelect(node.id),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _layerTitle(FolioCanvasNode node, AppLocalizations l10n) {
    switch (node.type) {
      case CanvasNodeType.text:
        final t = node.text.trim();
        return t.isEmpty ? l10n.canvasToolbarAddNode : t;
      case CanvasNodeType.shape:
        return node.text.trim().isEmpty ? l10n.canvasToolbarAddShape : node.text;
      case CanvasNodeType.image:
        return l10n.canvasLayerImageBrief;
      case CanvasNodeType.folioBlock:
        return node.folioBlockText ?? node.folioBlockType ?? 'Block';
      case CanvasNodeType.frame:
        return l10n.canvasFrameLabel;
    }
  }
}
