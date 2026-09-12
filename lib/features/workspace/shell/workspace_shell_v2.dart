import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/ui_tokens.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../layout_engine/drag_resize/resize_handle.dart';

class _ResizeByDeltaIntent extends Intent {
  const _ResizeByDeltaIntent(this.delta);
  final double delta;
}

/// V2 del shell del workspace (Fase 24) — mismo contrato público que
/// [WorkspaceBodyShell] (`workspace_shell.dart`, v1) byte a byte, así que es
/// un drop-in: `workspace_page.dart` no necesita cambiar cómo calcula
/// `sidePanelWidth`/`effectiveSidebarW`/los callbacks de resize, solo qué
/// clase construye.
///
/// La diferencia real es interna: los tres handles de resize hechos a mano
/// (sidebar/IA/colaboración — cada uno su propio `MouseRegion` +
/// `GestureDetector` + `Container` casi idéntico) se sustituyen por
/// [PanelResizeHandle], el mismo widget compartido que ya usa `PanelHost`/
/// `PanelFrame` en el motor de layout (Fase 2) — un único sitio con la
/// lógica de resize en vez de tres copias divergentes.
///
/// Deliberadamente NO se migra a través de [PanelFrame]/[PanelHost]
/// directamente: esos componen su decisión de visibilidad/ancho desde
/// `LayoutEngineController.panelFor(regionId)`, pero `sidePanelWidth`/
/// `compact`/zen-mode aquí son un valor ya resuelto por el caller que
/// mezcla el layout persistido con estado efímero (modo zen, "peek" al
/// pasar el ratón sobre un sidebar colapsado) — forzar esa mezcla a través
/// de `PanelConfig.visible` escribiría estado transitorio en el documento
/// persistido. `PanelResizeHandle` es la pieza reutilizable correcta aquí;
/// `PanelFrame`/`PanelHost` completos son para cuando el estado SÍ vive
/// enteramente en el `LayoutConfig` (ver `PanelHost` en el dashboard/
/// sidebar de ajustes).
///
/// Añade, respecto a v1, dos slots opcionales `topBand`/`bottomBand` (Fase
/// 24/25) — una banda horizontal de ancho completo por encima/debajo del
/// cuerpo principal, para la futura toolbar acoplada (Fase 25) o tira de
/// pestañas (Fase 29). `null` (default) = sin banda, árbol idéntico a v1.
class WorkspaceBodyShellV2 extends StatelessWidget {
  const WorkspaceBodyShellV2({
    super.key,
    required this.compact,
    required this.sidePanelWidth,
    required this.sidePanel,
    required this.editorContent,
    required this.scheme,
    this.betaBanner,
    this.overlay,
    this.showSidebarResizeHandle = false,
    this.onResizeSidebarDelta,
    this.sidebarLeftEdgeHover = false,
    this.onSidebarEdgeEnter,
    this.aiFloatingPanel,
    this.aiFloatingWidth = 380,
    this.aiFloatingHeight = 480,
    this.onResizeAiPanelWidth,
    this.onResizeAiPanelHeight,
    this.aiFloatingShowResizeHandles = true,
    this.collabFloatingPanel,
    this.collabFloatingWidth = 360,
    this.collabFloatingHeight = 480,
    this.onResizeCollabPanelWidth,
    this.onResizeCollabPanelHeight,
    this.collabFloatingShowResizeHandles = true,
    this.topBand,
    this.bottomBand,
    this.sidebarPosition = 'left',
    this.sidebarShowDivider = true,
  });

  final bool compact;
  final double sidePanelWidth;
  final Widget sidePanel;
  final Widget editorContent;
  final ColorScheme scheme;
  final Widget? betaBanner;
  final Widget? overlay;
  final bool showSidebarResizeHandle;
  final ValueChanged<double>? onResizeSidebarDelta;
  final bool sidebarLeftEdgeHover;
  final VoidCallback? onSidebarEdgeEnter;

  /// Panel de IA flotante (esquina inferior derecha); null si no hay IA visible.
  final Widget? aiFloatingPanel;
  final double aiFloatingWidth;
  final double aiFloatingHeight;
  final ValueChanged<double>? onResizeAiPanelWidth;
  final ValueChanged<double>? onResizeAiPanelHeight;
  final bool aiFloatingShowResizeHandles;

  /// Panel de colaboración (esquina inferior izquierda).
  final Widget? collabFloatingPanel;
  final double collabFloatingWidth;
  final double collabFloatingHeight;
  final ValueChanged<double>? onResizeCollabPanelWidth;
  final ValueChanged<double>? onResizeCollabPanelHeight;
  final bool collabFloatingShowResizeHandles;

  /// Banda horizontal opcional encima del cuerpo (Fase 24/25) — ej. una
  /// toolbar acoplada. `null` = sin banda.
  final Widget? topBand;

  /// Igual que [topBand] pero debajo del cuerpo.
  final Widget? bottomBand;

  /// 'left' (default, comportamiento de siempre) | 'right' (Fase 25) —
  /// qué lado del editor ocupa [sidePanel]. El handle de resize se orienta
  /// automáticamente al borde correcto.
  final String sidebarPosition;

  /// `false` (Fase 26, `PanelConfig.showDivider`) pinta el handle de resize
  /// transparente en vez de con el color de `outlineVariant` — sigue
  /// funcionando como target de arrastre, solo deja de dibujar la línea
  /// divisoria. `true` (default) reproduce el color de hoy.
  final bool sidebarShowDivider;

  bool get _sidebarOnRight => sidebarPosition == 'right';

  Widget _sidePanelContainer() {
    return AnimatedContainer(
      duration: FolioMotion.medium1,
      curve: FolioMotion.emphasized,
      width: sidePanelWidth,
      child: sidePanel,
    );
  }

  /// Sidebar a la izquierda: handle en su borde derecho, delta crudo (dx),
  /// el caller hace `width + d`. Sidebar a la derecha: handle en su borde
  /// izquierdo — `PanelResizeHandle` ya orienta ese borde como `-dx`, que
  /// produce el mismo signo "arrastrar hacia el panel = crecer" sin
  /// necesitar una negación adicional aquí.
  Widget _sidebarResizeHandle(AppLocalizations l10n) {
    return PanelResizeHandle(
      edge: _sidebarOnRight ? PanelResizeEdge.left : PanelResizeEdge.right,
      thickness: 6,
      color: sidebarShowDivider ? null : Colors.transparent,
      semanticLabel: l10n.resizeSidebarHandle,
      semanticHint: l10n.resizeSidebarHandleHint,
      onDelta: (d) => onResizeSidebarDelta?.call(d),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final shortcuts = <ShortcutActivator, Intent>{
      if (!compact && showSidebarResizeHandle && onResizeSidebarDelta != null)
        const SingleActivator(
          LogicalKeyboardKey.arrowLeft,
          control: true,
          alt: true,
        ): const _ResizeByDeltaIntent(
          -24,
        ),
      if (!compact && showSidebarResizeHandle && onResizeSidebarDelta != null)
        const SingleActivator(
          LogicalKeyboardKey.arrowRight,
          control: true,
          alt: true,
        ): const _ResizeByDeltaIntent(
          24,
        ),
      if (aiFloatingPanel != null &&
          aiFloatingShowResizeHandles &&
          onResizeAiPanelWidth != null)
        const SingleActivator(
          LogicalKeyboardKey.arrowLeft,
          control: true,
          alt: true,
          shift: true,
        ): const _ResizeByDeltaIntent(
          -24,
        ),
      if (aiFloatingPanel != null &&
          aiFloatingShowResizeHandles &&
          onResizeAiPanelWidth != null)
        const SingleActivator(
          LogicalKeyboardKey.arrowRight,
          control: true,
          alt: true,
          shift: true,
        ): const _ResizeByDeltaIntent(
          24,
        ),
      if (aiFloatingPanel != null &&
          aiFloatingShowResizeHandles &&
          onResizeAiPanelHeight != null)
        const SingleActivator(
          LogicalKeyboardKey.arrowUp,
          control: true,
          alt: true,
          shift: true,
        ): const _ResizeByDeltaIntent(
          24,
        ),
      if (aiFloatingPanel != null &&
          aiFloatingShowResizeHandles &&
          onResizeAiPanelHeight != null)
        const SingleActivator(
          LogicalKeyboardKey.arrowDown,
          control: true,
          alt: true,
          shift: true,
        ): const _ResizeByDeltaIntent(
          -24,
        ),
    };

    final actions = <Type, Action<Intent>>{
      _ResizeByDeltaIntent: CallbackAction<_ResizeByDeltaIntent>(
        onInvoke: (intent) {
          // Sidebar y AI comparten intent; priorizamos según modificadores.
          // - Ctrl+Alt: Sidebar
          // - Ctrl+Alt+Shift: AI
          final pressed = HardwareKeyboard.instance.logicalKeysPressed;
          final shift =
              pressed.contains(LogicalKeyboardKey.shiftLeft) ||
              pressed.contains(LogicalKeyboardKey.shiftRight);

          if (shift) {
            // AI panel
            final upDown =
                pressed.contains(LogicalKeyboardKey.arrowUp) ||
                pressed.contains(LogicalKeyboardKey.arrowDown);
            if (upDown) {
              onResizeAiPanelHeight?.call(intent.delta);
            } else {
              onResizeAiPanelWidth?.call(intent.delta);
            }
          } else {
            onResizeSidebarDelta?.call(intent.delta);
          }
          return null;
        },
      ),
    };

    return Actions(
      actions: actions,
      child: Shortcuts(
        shortcuts: shortcuts,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bodyH = constraints.maxHeight;
            final bodyW = constraints.maxWidth;
            final dockMode = QuillChatLayout.resolve(
              viewportWidth: bodyW,
              splitView: false,
            );
            final clampedAiW = aiFloatingPanel == null
                ? aiFloatingWidth
                : QuillChatLayout.clampDockWidth(
                    desired: aiFloatingWidth,
                    availableBodyWidth: bodyW,
                    mode: dockMode,
                  );
            final clampedAiH = aiFloatingPanel == null
                ? aiFloatingHeight
                : QuillChatLayout.clampDockHeight(
                    desired: aiFloatingHeight,
                    availableBodyHeight: bodyH,
                    mode: dockMode,
                  );
            final clampedCollabW = collabFloatingPanel == null
                ? collabFloatingWidth
                : QuillChatLayout.clampDockWidth(
                    desired: collabFloatingWidth,
                    availableBodyWidth: bodyW,
                    mode: dockMode,
                  );
            final clampedCollabH = collabFloatingPanel == null
                ? collabFloatingHeight
                : QuillChatLayout.clampDockHeight(
                    desired: collabFloatingHeight,
                    availableBodyHeight: bodyH,
                    mode: dockMode,
                  );

            final body = Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ...?betaBanner == null ? null : [betaBanner!],
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: _sidebarOnRight
                            ? [
                                Expanded(child: editorContent),
                                if (!compact && showSidebarResizeHandle)
                                  _sidebarResizeHandle(l10n),
                                if (!compact) _sidePanelContainer(),
                              ]
                            : [
                                if (!compact) _sidePanelContainer(),
                                if (!compact && showSidebarResizeHandle)
                                  _sidebarResizeHandle(l10n),
                                Expanded(child: editorContent),
                              ],
                      ),
                    ),
                  ],
                ),
                if (sidebarLeftEdgeHover && !compact)
                  Positioned(
                    left: _sidebarOnRight ? null : 0,
                    right: _sidebarOnRight ? 0 : null,
                    top: 0,
                    bottom: 0,
                    width: 14,
                    child: MouseRegion(
                      opaque: true,
                      onEnter: (_) => onSidebarEdgeEnter?.call(),
                      child: const ColoredBox(color: Color(0x00000000)),
                    ),
                  ),
                if (collabFloatingPanel != null)
                  Positioned(
                    right: aiFloatingPanel != null
                        ? (FolioSpace.md + clampedAiW + FolioSpace.sm)
                        : FolioSpace.md,
                    bottom: FolioSpace.md,
                    width: clampedCollabW,
                    height: clampedCollabH,
                    child: collabFloatingShowResizeHandles
                        ? Material(
                            elevation: FolioElevation.menu,
                            shadowColor: scheme.shadow.withValues(
                              alpha: FolioAlpha.soft,
                            ),
                            borderRadius: BorderRadius.circular(FolioRadius.xl),
                            clipBehavior: Clip.antiAlias,
                            color: scheme.surface,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                PanelResizeHandle(
                                  edge: PanelResizeEdge.top,
                                  thickness: 7,
                                  semanticLabel: l10n.resizeAiPanelHeightHandle,
                                  semanticHint: l10n.resizeAiPanelHeightHandleHint,
                                  // edge=top ya orienta el delta como -dy
                                  // (PanelResizeHandle), idéntico al -dy que
                                  // v1 pasaba a mano — sin negación extra.
                                  onDelta: (d) =>
                                      onResizeCollabPanelHeight?.call(d),
                                ),
                                Expanded(
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      Expanded(child: collabFloatingPanel!),
                                      PanelResizeHandle(
                                        edge: PanelResizeEdge.right,
                                        thickness: 7,
                                        semanticLabel: l10n.aiPanelResizeHandle,
                                        semanticHint: l10n.aiPanelResizeHandleHint,
                                        onDelta: (d) =>
                                            onResizeCollabPanelWidth?.call(d),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Material(
                            elevation: FolioElevation.menu,
                            shadowColor: scheme.shadow.withValues(
                              alpha: FolioAlpha.soft,
                            ),
                            borderRadius: BorderRadius.circular(FolioRadius.lg),
                            clipBehavior: Clip.antiAlias,
                            color: scheme.surface,
                            child: collabFloatingPanel!,
                          ),
                  ),
                if (aiFloatingPanel != null)
                  Positioned(
                    right: FolioSpace.md,
                    bottom: FolioSpace.md,
                    width: clampedAiW,
                    height: clampedAiH,
                    child: aiFloatingShowResizeHandles
                        ? Material(
                            elevation: FolioElevation.menu,
                            shadowColor: scheme.shadow.withValues(
                              alpha: FolioAlpha.soft,
                            ),
                            borderRadius: BorderRadius.circular(FolioRadius.xl),
                            clipBehavior: Clip.antiAlias,
                            color: scheme.surface,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                PanelResizeHandle(
                                  edge: PanelResizeEdge.top,
                                  thickness: 7,
                                  semanticLabel: l10n.resizeAiPanelHeightHandle,
                                  semanticHint: l10n.resizeAiPanelHeightHandleHint,
                                  // edge=top ya orienta el delta como -dy,
                                  // idéntico al -dy que v1 pasaba a mano.
                                  onDelta: (d) => onResizeAiPanelHeight?.call(d),
                                ),
                                Expanded(
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      PanelResizeHandle(
                                        edge: PanelResizeEdge.left,
                                        thickness: 7,
                                        semanticLabel: l10n.aiPanelResizeHandle,
                                        semanticHint: l10n.aiPanelResizeHandleHint,
                                        // edge=left orienta el delta como
                                        // -dx; v1 pasaba dx crudo (su
                                        // callback hace `width - d`) — se
                                        // deshace el flip para preservar
                                        // exactamente el mismo signo.
                                        onDelta: (d) =>
                                            onResizeAiPanelWidth?.call(-d),
                                      ),
                                      Expanded(child: aiFloatingPanel!),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Material(
                            elevation: FolioElevation.menu,
                            shadowColor: scheme.shadow.withValues(
                              alpha: FolioAlpha.soft,
                            ),
                            borderRadius: BorderRadius.circular(FolioRadius.lg),
                            clipBehavior: Clip.antiAlias,
                            color: scheme.surface,
                            child: aiFloatingPanel!,
                          ),
                  ),
                AnimatedSwitcher(
                  duration: FolioMotion.short2,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, -0.04),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  child: overlay == null
                      ? const SizedBox.shrink(key: ValueKey('overlay_hidden'))
                      : SafeArea(
                          key: const ValueKey('overlay_visible'),
                          child: Align(
                            alignment: compact
                                ? Alignment.topCenter
                                : Alignment.topRight,
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(
                                FolioSpace.sm,
                                FolioSpace.sm,
                                compact ? FolioSpace.sm : FolioSpace.md,
                                0,
                              ),
                              child: overlay!,
                            ),
                          ),
                        ),
                ),
              ],
            );

            if (topBand == null && bottomBand == null) {
              return body;
            }
            return Column(
              children: [
                ?topBand,
                Expanded(child: body),
                ?bottomBand,
              ],
            );
          },
        ),
      ),
    );
  }
}
