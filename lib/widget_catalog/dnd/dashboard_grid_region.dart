import 'package:flutter/material.dart';

import '../../config/models/dashboard_config.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../config/models/widget_instance_config.dart';
import '../../visual_editor/visual_editor_controller.dart';
import '../folio_widget_plugin.dart';
import '../widget_catalog_registry.dart';
import '../widget_plugin_context.dart';
import 'dashboard_grid_controller.dart';
import 'dashboard_responsive_resolver.dart';
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
    this.visualEditor,
  });

  final DashboardGridController controller;
  final WidgetPluginContext pluginContext;

  /// Inyectable para tests; por defecto usa el registro global.
  final WidgetCatalogRegistry? registry;

  /// Editor visual (Fase 6/9) — pasado a cada [WidgetInstanceFrame]. Null =
  /// las instancias no son seleccionables (comportamiento anterior).
  final VisualEditorController? visualEditor;

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
        final effectiveRegistry = registry ?? WidgetCatalogRegistry.instance;
        return LayoutBuilder(
          builder: (context, constraints) {
            // Fase 26: solo afecta qué se renderiza (visibilidad efectiva
            // por instancia) — drag/drop sigue mutando siempre `config`
            // base vía `controller`, nunca este valor resuelto.
            final effectiveConfig = DashboardResponsiveResolver.resolveForWidth(
              config,
              constraints.maxWidth,
            );
            final effectiveVisibility = <String, bool>{
              for (final w in effectiveConfig.widgets) w.instanceId: w.visible,
            };
            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Align(
                      // centerLeft, no centerRight: el inspector del editor
                      // visual (Fase 6/9) flota anclado arriba-a-la-derecha
                      // de la pantalla (ver WorkspaceBodyShell.overlay) —
                      // bug real reportado: con "Añadir widget" también a
                      // la derecha, el inspector lo tapaba por completo en
                      // cuanto se activaba el editor.
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: () => _showAddWidgetPicker(
                          context,
                          controller,
                          effectiveRegistry,
                          columns,
                        ),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: Text(AppLocalizations.of(context).dashboardAddWidget),
                      ),
                    ),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final regionId in columns) ...[
                        Expanded(
                          child: _DashboardColumn(
                            regionId: regionId,
                            controller: controller,
                            pluginContext: pluginContext,
                            registry: effectiveRegistry,
                            visualEditor: visualEditor,
                            effectiveVisibility: effectiveVisibility,
                          ),
                        ),
                        if (regionId != columns.last)
                          SizedBox(width: config.gap),
                      ],
                    ],
                  ),
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

/// Muestra un diálogo con los plugins del catálogo disponibles y añade el
/// elegido a la primera columna — bug real reportado: el editor de
/// dashboard permitía arrastrar/redimensionar/eliminar instancias pero
/// nunca añadir una nueva, así que el catálogo entero (calendario, reloj,
/// clima...) era invisible en la práctica salvo que ya viniera de un pack.
Future<void> _showAddWidgetPicker(
  BuildContext context,
  DashboardGridController controller,
  WidgetCatalogRegistry registry,
  List<String> columns,
) async {
  final existingPluginIds = controller.config.widgets
      .map((w) => w.pluginId)
      .toSet();
  final available =
      registry.all
          .where(
            (p) => p.allowMultipleInstances || !existingPluginIds.contains(p.id),
          )
          .toList()
        ..sort(
          (a, b) => a.displayName(context).compareTo(b.displayName(context)),
        );

  final l10n = AppLocalizations.of(context);
  if (available.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.dashboardNoMoreWidgets)),
    );
    return;
  }

  final selected = await showDialog<FolioWidgetPlugin>(
    context: context,
    builder: (dialogContext) => SimpleDialog(
      title: Text(l10n.dashboardAddWidget),
      children: [
        for (final plugin in available)
          SimpleDialogOption(
            onPressed: () => Navigator.of(dialogContext).pop(plugin),
            child: Row(
              children: [
                Icon(plugin.icon, size: 18),
                const SizedBox(width: 12),
                Expanded(child: Text(plugin.displayName(dialogContext))),
              ],
            ),
          ),
      ],
    ),
  );
  if (selected == null) return;
  final targetRegion = columns.isNotEmpty
      ? columns.first
      : DashboardRegionIds.left;
  controller.addInstance(selected.id, targetRegion);
}

class _DashboardColumn extends StatefulWidget {
  const _DashboardColumn({
    required this.regionId,
    required this.controller,
    required this.pluginContext,
    required this.registry,
    this.visualEditor,
    this.effectiveVisibility = const {},
  });

  final String regionId;
  final DashboardGridController controller;
  final WidgetPluginContext pluginContext;
  final WidgetCatalogRegistry registry;
  final VisualEditorController? visualEditor;

  /// instanceId -> visibilidad efectiva tras aplicar
  /// `DashboardConfig.responsiveOverrides` para el ancho actual (Fase 26).
  /// Una instancia ausente de este mapa cae a `instance.visible` — la
  /// mutación de drag/drop sigue operando siempre sobre el config base vía
  /// [controller], este mapa solo afecta qué se renderiza.
  final Map<String, bool> effectiveVisibility;

  @override
  State<_DashboardColumn> createState() => _DashboardColumnState();
}

class _DashboardColumnState extends State<_DashboardColumn> {
  final _columnKey = GlobalKey();

  /// Convierte la posición global de la caída en el índice de la instancia
  /// más cercana — bug real reportado: antes, soltar en cualquier punto de
  /// la columna siempre movía el widget al final; ahora la posición
  /// vertical de la caída decide dónde se inserta (aproximado por altura
  /// acumulada de cada instancia, no un slot exacto por-pixel).
  int _targetOrderForDrop(Offset globalOffset, List<WidgetInstanceConfig> instances) {
    final renderBox = _columnKey.currentContext?.findRenderObject();
    if (renderBox is! RenderBox || !renderBox.attached) return instances.length;
    final local = renderBox.globalToLocal(globalOffset);
    var cumulative = 0.0;
    for (var i = 0; i < instances.length; i++) {
      final itemHeight = (instances[i].height ?? 160) + 8;
      if (local.dy < cumulative + itemHeight / 2) return i;
      cumulative += itemHeight;
    }
    return instances.length;
  }

  void _moveTo(String draggedId, int targetOrder) {
    final current = widget.controller.instanceFor(draggedId);
    if (current == null) return;
    if (current.regionId == widget.regionId) {
      if (current.order == targetOrder) return;
      widget.controller.reorderWithinColumn(
        widget.regionId,
        current.order,
        targetOrder,
      );
    } else {
      widget.controller.moveToColumn(
        draggedId,
        widget.regionId,
        insertAtOrder: targetOrder,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final instances = widget.controller.widgetsInRegion(widget.regionId);
    return DragTarget<String>(
      onWillAcceptWithDetails: (details) => details.data.isNotEmpty,
      onAcceptWithDetails: (details) {
        final targetOrder = _targetOrderForDrop(details.offset, instances);
        _moveTo(details.data, targetOrder);
      },
      builder: (context, candidateData, rejectedData) {
        final highlighted = candidateData.isNotEmpty;
        return Container(
          key: _columnKey,
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
                Builder(
                  builder: (context) {
                    final plugin = widget.registry[instance.pluginId];
                    final visible =
                        widget.effectiveVisibility[instance.instanceId] ??
                        instance.visible;
                    if (plugin == null || !visible) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: SizedBox(
                        height: instance.height ?? plugin.defaultHeight,
                        child: WidgetInstanceFrame(
                          instance: instance,
                          controller: widget.controller,
                          visualEditor: widget.visualEditor,
                          plugin: plugin,
                          child: plugin.build(
                            context,
                            instance,
                            widget.pluginContext,
                          ),
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}
