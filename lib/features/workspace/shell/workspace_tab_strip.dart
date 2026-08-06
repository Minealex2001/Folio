import 'package:flutter/material.dart';

import '../../../session/workspace_state_controller.dart';

/// Tira de pestañas horizontal (Fase 29, v1 acotado) — navegación/atajos
/// sobre el modelo existente de un-solo-documento-activo (`VaultSession`),
/// NO múltiples editores renderizados simultáneamente ni paneles divididos.
/// Pensada para montarse en la banda `toolbarTop` de `WorkspaceBodyShellV2`
/// (Fase 24) cuando `controller.config.openTabs` no esté vacío.
class WorkspaceTabStrip extends StatelessWidget {
  const WorkspaceTabStrip({
    super.key,
    required this.controller,
    required this.pageTitleFor,
    required this.onSelectPage,
  });

  final WorkspaceStateController controller;

  /// Resuelve el título a mostrar para un `pageId` — el controller solo
  /// conoce ids, no títulos de página (eso vive en `VaultSession`).
  final String Function(String pageId) pageTitleFor;

  /// Navega a la página seleccionada — el strip solo decide QUÉ pestaña
  /// está activa en el modelo de sesión, la navegación real (mover el
  /// documento visible del editor) es responsabilidad del caller.
  final ValueChanged<String> onSelectPage;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final tabs = [...controller.config.openTabs]
          ..sort((a, b) => a.order.compareTo(b.order));
        if (tabs.isEmpty) return const SizedBox.shrink();

        final scheme = Theme.of(context).colorScheme;
        return SizedBox(
          height: 40,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: tabs.length,
            itemBuilder: (context, index) {
              final tab = tabs[index];
              final active = tab.pageId == controller.config.activeTabId;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                child: Material(
                  color: active ? scheme.surfaceContainerHighest : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () {
                      controller.activateTab(tab.pageId);
                      onSelectPage(tab.pageId);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (tab.pinned)
                            Icon(Icons.push_pin_rounded, size: 12, color: scheme.onSurfaceVariant),
                          if (tab.pinned) const SizedBox(width: 4),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 160),
                            child: Text(
                              pageTitleFor(tab.pageId),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                              ),
                            ),
                          ),
                          if (!tab.pinned) ...[
                            const SizedBox(width: 4),
                            InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => controller.closeTab(tab.pageId),
                              child: Icon(
                                Icons.close_rounded,
                                size: 14,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
