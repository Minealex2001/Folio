import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';

import '../../config/models/widget_instance_config.dart';
import '../../visual_editor/selectable_tap_wrapper.dart';
import '../../visual_editor/visual_editor_controller.dart';
import '../../visual_editor/widget_instance_selectable.dart';
import '../folio_widget_plugin.dart';
import '../widget_capabilities.dart';
import 'dashboard_grid_controller.dart';
import 'dashboard_grid_math.dart';

/// Capacidades efectivas para [instance]: `plugin.capabilities` como base,
/// con cada campo no-null de `instance.capabilityOverrides` ganando (Fase
/// 13) — mismo patrón de fallback de dos niveles que el resto del sistema.
WidgetCapabilities resolveWidgetCapabilities(
  FolioWidgetPlugin? plugin,
  WidgetInstanceConfig instance,
) {
  final base = plugin?.capabilities ?? const WidgetCapabilities();
  final overrides = instance.capabilityOverrides;
  if (overrides == null) return base;
  return WidgetCapabilities(
    movable: overrides.movable ?? base.movable,
    resizable: overrides.resizable ?? base.resizable,
    duplicable: overrides.duplicable ?? base.duplicable,
    closable: overrides.closable ?? base.closable,
    detachable: overrides.detachable ?? base.detachable,
  );
}

/// Chrome de una instancia de widget dentro del grid del dashboard —
/// equivalente de `PanelFrame` (Fase 2) para widgets en vez de paneles:
/// arrastrable (`Draggable` en desktop/mouse — arranca al instante;
/// `LongPressDraggable` solo en Android/iOS, donde un drag inmediato
/// choca con el scroll táctil), resize desde la esquina inferior
/// derecha, y botones de duplicar/eliminar.
class WidgetInstanceFrame extends StatefulWidget {
  const WidgetInstanceFrame({
    super.key,
    required this.instance,
    required this.controller,
    required this.child,
    this.resizable = true,
    this.rowUnit = 32,
    this.visualEditor,
    this.plugin,
  });

  final WidgetInstanceConfig instance;
  final DashboardGridController controller;
  final Widget child;
  final bool resizable;

  /// Plugin resuelto para [instance] — usado solo para exponer
  /// `plugin.buildSettings(...)` (si no es null) como un botón de ajustes
  /// junto a duplicar/eliminar. Bug real reportado: `buildSettings` ya
  /// existía en `FolioWidgetPlugin` desde la Fase 4 pero ningún sitio lo
  /// llamaba — era una capacidad muerta.
  final FolioWidgetPlugin? plugin;

  /// Editor visual (Fase 6/9): cuando no es null, envuelve el contenido con
  /// [SelectableTapWrapper] usando [WidgetInstanceSelectable] — mismo
  /// mecanismo ya usado para el sidebar (`PanelSelectable`). Null =
  /// passthrough puro, sin coste ni cambio de comportamiento.
  final VisualEditorController? visualEditor;

  /// Unidad de fila para el snap de alto/ancho al soltar el resize.
  final double rowUnit;

  @override
  State<WidgetInstanceFrame> createState() => _WidgetInstanceFrameState();
}

class _WidgetInstanceFrameState extends State<WidgetInstanceFrame> {
  Offset _resizeAccumulator = Offset.zero;
  bool _hovering = false;

  /// Aplica los overrides visuales por instancia que escribe el inspector
  /// del editor visual (`WidgetInstanceSelectable.setColorArgb`/
  /// `setOpacity`/`setCornerRadius`) — bug real reportado: el inspector
  /// guardaba estos valores pero ningún sitio los leía de vuelta, así que
  /// editar color/opacidad/radio no cambiaba nada visible. Se aplican aquí,
  /// en el único wrapper común a cualquier plugin, en vez de en cada plugin
  /// por separado.
  ///
  /// Fase 31: `WidgetInstanceConfig.appearance` (tipado) es la fuente
  /// primaria; si es null para un campo concreto, cae a las 3 claves
  /// legacy en `settings` (`colorOverrideArgb`/`opacityOverride`/
  /// `cornerRadiusOverride`) para que instancias guardadas antes de esta
  /// fase sigan renderizando su override sin migración.
  Widget _applyOverrides(Widget child) {
    final appearance = widget.instance.appearance;
    final settings = widget.instance.settings;
    var result = child;

    final colorRaw = appearance?.backgroundColorArgb ?? settings['colorOverrideArgb'];
    if (colorRaw is int) {
      result = Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Color(colorRaw),
          borderRadius: BorderRadius.circular(8),
        ),
        child: result,
      );
    }

    final cornerRaw = appearance?.cornerRadius ?? settings['cornerRadiusOverride'];
    if (cornerRaw is num) {
      result = ClipRRect(
        borderRadius: BorderRadius.circular(cornerRaw.toDouble()),
        child: result,
      );
    }

    final opacityRaw = appearance?.opacity ?? settings['opacityOverride'];
    if (opacityRaw is num) {
      result = Opacity(opacity: opacityRaw.toDouble().clamp(0.0, 1.0), child: result);
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final capabilities = resolveWidgetCapabilities(widget.plugin, widget.instance);
    final content = RepaintBoundary(
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: Stack(
          children: [
            Positioned.fill(child: _applyOverrides(widget.child)),
            if (_hovering)
              Positioned(
                top: 4,
                right: 4,
                child: _InstanceActionsRow(
                  instance: widget.instance,
                  controller: widget.controller,
                  plugin: widget.plugin,
                  capabilities: capabilities,
                ),
              ),
            if (widget.resizable && capabilities.resizable && _hovering)
              Positioned(
                right: 0,
                bottom: 0,
                child: MouseRegion(
                  cursor: SystemMouseCursors.resizeDownRight,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanStart: (_) => _resizeAccumulator = Offset.zero,
                    onPanUpdate: (details) {
                      _resizeAccumulator += details.delta;
                    },
                    onPanEnd: (_) => _commitResize(),
                    child: const SizedBox(
                      width: 16,
                      height: 16,
                      child: Icon(Icons.south_east_rounded, size: 14),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    final visualEditor = widget.visualEditor;
    final selectableContent = visualEditor == null
        ? content
        : SelectableTapWrapper(
            controller: visualEditor,
            selectable: WidgetInstanceSelectable(
              widget.controller,
              widget.instance.instanceId,
            ),
            child: content,
          );

    final feedback = Material(
      elevation: 6,
      color: Colors.transparent,
      child: Opacity(
        opacity: 0.85,
        child: SizedBox(
          width: widget.instance.width ?? 240,
          height: widget.instance.height ?? 160,
          child: widget.child,
        ),
      ),
    );
    final childWhenDragging = Opacity(opacity: 0.3, child: selectableContent);

    // Bug real reportado: en desktop/mouse, LongPressDraggable exige
    // mantener pulsado ~500ms antes de que el drag arranque — un
    // click-and-drag normal de ratón no llega a activarlo y el arrastre
    // parece simplemente no funcionar. Long-press solo tiene sentido en
    // táctil (decisión original de la Fase 5); en el resto de plataformas
    // el drag debe iniciar de inmediato, como cualquier `Draggable` nativo.
    final isTouchPrimary =
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;

    if (!capabilities.movable) {
      return selectableContent;
    }
    if (isTouchPrimary) {
      return LongPressDraggable<String>(
        data: widget.instance.instanceId,
        feedback: feedback,
        childWhenDragging: childWhenDragging,
        child: selectableContent,
      );
    }
    return Draggable<String>(
      data: widget.instance.instanceId,
      feedback: feedback,
      childWhenDragging: childWhenDragging,
      child: selectableContent,
    );
  }

  void _commitResize() {
    final baseWidth = widget.instance.width ?? 240;
    final baseHeight = widget.instance.height ?? 160;
    final nextWidth = DashboardGridMath.snapToRowUnit(
      (baseWidth + _resizeAccumulator.dx).clamp(80, double.infinity),
      widget.rowUnit,
    );
    final nextHeight = DashboardGridMath.snapToRowUnit(
      (baseHeight + _resizeAccumulator.dy).clamp(80, double.infinity),
      widget.rowUnit,
    );
    widget.controller.resizeInstance(
      widget.instance.instanceId,
      width: nextWidth,
      height: nextHeight,
    );
    _resizeAccumulator = Offset.zero;
  }
}

class _InstanceActionsRow extends StatelessWidget {
  const _InstanceActionsRow({
    required this.instance,
    required this.controller,
    required this.capabilities,
    this.plugin,
  });

  final WidgetInstanceConfig instance;
  final DashboardGridController controller;
  final FolioWidgetPlugin? plugin;
  final WidgetCapabilities capabilities;

  void _openSettings(BuildContext context) {
    final settingsWidget = plugin?.buildSettings(
      context,
      instance,
      (next) => controller.setInstanceSettings(instance.instanceId, next),
    );
    if (settingsWidget == null) return;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(child: settingsWidget),
    );
  }

  @override
  Widget build(BuildContext context) {
    // buildSettings necesita `instance` actual para leer valores previos —
    // se resuelve al construir el botón (no en cada rebuild de este Row)
    // solo para decidir si el botón se muestra; el sheet en sí llama a
    // buildSettings de nuevo al abrirse, con el instance más reciente.
    final hasSettings =
        plugin?.buildSettings(context, instance, (_) {}) != null;
    return Material(
      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
      shape: const StadiumBorder(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasSettings)
            IconButton(
              iconSize: 16,
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.tune_rounded),
              onPressed: () => _openSettings(context),
            ),
          if (capabilities.duplicable)
            IconButton(
              iconSize: 16,
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.copy_rounded),
              onPressed: () => controller.duplicateInstance(instance.instanceId),
            ),
          if (capabilities.closable)
            IconButton(
              iconSize: 16,
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.close_rounded),
              onPressed: () => controller.removeInstance(instance.instanceId),
            ),
        ],
      ),
    );
  }
}
