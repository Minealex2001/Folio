import 'package:flutter/material.dart';

import '../../config/models/dashboard_config.dart';
import '../widget_catalog_registry.dart';
import '../widget_plugin_context.dart';
import 'dashboard_grid_controller.dart';
import 'widget_instance_frame.dart';

/// Renderiza un [DashboardConfig] como un grid de columnas — content
/// builder de una región del motor de layout (Fase 2: se registra como
/// `regionBuilders[PanelRegionIds.main]` en modo dashboard, no es un
/// sistema paralelo a `PanelHost`).
///
/// Cada columna es un `DragTarget<String>` (Flutter nativo) que acepta la
/// id de una instancia soltada y la mueve al final de esa columna — v1
/// deliberadamente grueso (columna completa, no slot exacto de drop);
/// reordenar dentro de una columna se hace vía [DashboardGridController.
/// reorderWithinColumn], expuesto para que un futuro refinamiento de drop
/// más preciso lo use sin cambiar el modelo.
class DashboardGridRegion extends StatelessWidget {
  const DashboardGridRegion({
    super.key,
    required this.controller,
    required this.pluginContext,
    this.registry,
    this.columnRegionIds,
  });

  final DashboardGridController controller;
  final WidgetPluginContext pluginContext;

  /// Inyectable para tests; por defecto usa el registro global.
  final WidgetCatalogRegistry? registry;

  /// Ids de región (columna) en orden de izquierda a derecha. Si es null,
  /// se derivan de las regiones que ya aparecen en `DashboardConfig.widgets`
  /// (orden de primera aparición), con tantas columnas como
  /// `DashboardConfig.columns` como mínimo.
  final List<String>? columnRegionIds;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final config = controller.config;
        final columns = _resolveColumnIds(config);
        return LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final regionId in columns) ...[
                    Expanded(
                      child: _DashboardColumn(
                        regionId: regionId,
                        controller: controller,
                        pluginContext: pluginContext,
                        registry: registry ?? WidgetCatalogRegistry.instance,
                      ),
                    ),
                    if (regionId != columns.last) SizedBox(width: config.gap),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  List<String> _resolveColumnIds(DashboardConfig config) {
    if (columnRegionIds != null) return columnRegionIds!;
    final seen = <String>[];
    for (final widget in config.widgets) {
      if (!seen.contains(widget.regionId)) seen.add(widget.regionId);
    }
    return seen;
  }
}

class _DashboardColumn extends StatelessWidget {
  const _DashboardColumn({
    required this.regionId,
    required this.controller,
    required this.pluginContext,
    required this.registry,
  });

  final String regionId;
  final DashboardGridController controller;
  final WidgetPluginContext pluginContext;
  final WidgetCatalogRegistry registry;

  @override
  Widget build(BuildContext context) {
    final instances = controller.widgetsInRegion(regionId);
    return DragTarget<String>(
      onWillAcceptWithDetails: (details) => details.data.isNotEmpty,
      onAcceptWithDetails: (details) {
        final draggedId = details.data;
        final current = controller.instanceFor(draggedId);
        if (current == null) return;
        if (current.regionId == regionId) return;
        controller.moveToColumn(draggedId, regionId);
      },
      builder: (context, candidateData, rejectedData) {
        final highlighted = candidateData.isNotEmpty;
        return Container(
          decoration: highlighted
              ? BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  ),
                )
              : null,
          constraints: const BoxConstraints(minHeight: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final instance in instances)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: SizedBox(
                    height: instance.height ?? 160,
                    child: Builder(
                      builder: (context) {
                        final plugin = registry[instance.pluginId];
                        if (plugin == null || !instance.visible) {
                          return const SizedBox.shrink();
                        }
                        return WidgetInstanceFrame(
                          instance: instance,
                          controller: controller,
                          child: plugin.build(context, instance, pluginContext),
                        );
                      },
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
