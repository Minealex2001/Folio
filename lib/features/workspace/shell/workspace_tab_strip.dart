import 'package:flutter/material.dart';

import '../../../session/workspace_state_controller.dart';

/// Tira de pestañas horizontal (Fase 29, v1 acotado) — navegación/atajos
/// sobre el modelo existente de un-solo-documento-activo (`VaultSession`),
/// NO múltiples editores renderizados simultáneamente ni paneles divididos.
/// Se monta como `titleWidget` de `WorkspaceTopAppBar` (`workspace_shell.dart`)
/// cuando `controller.config.openTabs` no esté vacío — vive en la misma
/// barra que las acciones del editor, como en un navegador, no en una tira
/// aparte debajo.
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
        // Estilo pestaña-de-navegador: esquinas redondeadas solo arriba y el
        // color de fondo de la pestaña activa es el mismo que el contenido
        // debajo (`Scaffold.backgroundColor`, ver `workspace_page.dart`), así
        // se lee como "conectada" al documento que muestra — más que un
        // botón activo cualquiera, es la pestaña que ahora mismo es la página.
        const tabRadius = BorderRadius.vertical(top: Radius.circular(10));
        return SizedBox(
          height: 44,
          child: ListView.separated(
            padding: const EdgeInsets.only(left: 4),
            scrollDirection: Axis.horizontal,
            itemCount: tabs.length,
            separatorBuilder: (context, _) => const SizedBox(width: 2),
            itemBuilder: (context, index) {
              final tab = tabs[index];
              final active = tab.pageId == controller.config.activeTabId;
              return Padding(
                padding: const EdgeInsets.only(top: 6, bottom: 2),
                child: Material(
                  color: active ? scheme.surfaceContainerLow : Colors.transparent,
                  borderRadius: tabRadius,
                  child: InkWell(
                    borderRadius: tabRadius,
                    onTap: () {
                      controller.activateTab(tab.pageId);
                      onSelectPage(tab.pageId);
                    },
                    child: Container(
                      decoration: active
                          ? BoxDecoration(
                              borderRadius: tabRadius,
                              border: Border(
                                top: BorderSide(color: scheme.primary, width: 2),
                              ),
                            )
                          : null,
                      padding: const EdgeInsets.fromLTRB(10, 4, 8, 4),
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
                                color: active ? scheme.onSurface : scheme.onSurfaceVariant,
                                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                              ),
                            ),
                          ),
                          if (!tab.pinned) ...[
                            const SizedBox(width: 6),
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
