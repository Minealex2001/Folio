import 'package:flutter/material.dart';

import '../app/ui_tokens.dart';
import 'drag_resize/resize_handle.dart';
import 'layout_engine_controller.dart';
import 'panel_frame.dart';
import 'panel_region_ids.dart';
import 'responsive/responsive_layout_resolver.dart';

/// Compone un [LayoutConfig] en un árbol de widgets real: regiones ancladas
/// (`sidebarLeft`, `sidebarRight`, `main`) en un `Row`, regiones flotantes
/// (`floatingAi`, `floatingCollab`, `floatingInspector`, ...) como hijos
/// `Positioned` de un `Stack` por encima.
///
/// [regionBuilders] solo se invoca para regiones `visible` — build perezoso,
/// nada se monta para paneles ocultos (Fase 9, rendimiento).
class PanelHost extends StatelessWidget {
  const PanelHost({
    super.key,
    required this.controller,
    required this.regionBuilders,
    this.dockedOrder = const [
      PanelRegionIds.sidebarLeft,
      PanelRegionIds.main,
      PanelRegionIds.sidebarRight,
    ],
    this.floatingOrder = const [
      PanelRegionIds.floatingCollab,
      PanelRegionIds.floatingAi,
      PanelRegionIds.floatingInspector,
    ],
  });

  final LayoutEngineController controller;
  final Map<String, WidgetBuilder> regionBuilders;

  /// Orden de composición horizontal de las regiones ancladas.
  final List<String> dockedOrder;

  /// Orden de apilado (z-order) de las regiones flotantes; las últimas
  /// quedan por encima.
  final List<String> floatingOrder;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            // Fase 7: fusiona los overrides responsive del breakpoint actual
            // sobre el LayoutConfig base antes de renderizar. El drag/resize
            // sigue mutando siempre el config base vía [controller] — los
            // overrides por breakpoint son solo una vista alternativa para
            // renderizar, no algo que un gesto de resize reescriba.
            final effectiveConfig = ResponsiveLayoutResolver.resolveForWidth(
              controller.config,
              constraints.maxWidth,
            );

            final dockedChildren = <Widget>[];
            for (final regionId in dockedOrder) {
              final panel = effectiveConfig.panels[regionId];
              final builder = regionBuilders[regionId];
              if (panel == null || builder == null || !panel.visible) {
                continue;
              }

              final isMain = regionId == PanelRegionIds.main;
              final isLeft = regionId == PanelRegionIds.sidebarLeft;
              final isRight = regionId == PanelRegionIds.sidebarRight;

              Widget region = PanelFrame(
                regionId: regionId,
                controller: controller,
                effectivePanel: panel,
                resizableEdges: isLeft
                    ? const {PanelResizeEdge.right}
                    : isRight
                    ? const {PanelResizeEdge.left}
                    : const {},
                child: Builder(builder: builder),
              );

              if (isMain) {
                dockedChildren.add(Expanded(child: region));
              } else {
                region = AnimatedContainer(
                  duration: FolioMotion.medium1,
                  curve: FolioMotion.emphasized,
                  width: panel.width,
                  child: region,
                );
                dockedChildren.add(region);
              }
            }

            final floatingChildren = <Widget>[];
            for (final regionId in floatingOrder) {
              final panel = effectiveConfig.panels[regionId];
              final builder = regionBuilders[regionId];
              if (panel == null || builder == null || !panel.visible) {
                continue;
              }

              floatingChildren.add(
                Positioned(
                  left: panel.floatingX,
                  top: panel.floatingY,
                  width: panel.width,
                  height: panel.height,
                  child: PanelFrame(
                    regionId: regionId,
                    controller: controller,
                    effectivePanel: panel,
                    draggable: true,
                    resizableEdges: const {
                      PanelResizeEdge.left,
                      PanelResizeEdge.bottom,
                    },
                    child: Material(
                      elevation: FolioElevation.menu,
                      borderRadius: BorderRadius.circular(FolioRadius.xl),
                      clipBehavior: Clip.antiAlias,
                      color: Theme.of(context).colorScheme.surface,
                      child: Builder(builder: builder),
                    ),
                  ),
                ),
              );
            }

            return Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: dockedChildren,
                ),
                ...floatingChildren,
              ],
            );
          },
        );
      },
    );
  }
}
