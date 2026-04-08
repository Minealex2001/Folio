import 'package:flutter/material.dart';

import '../../../app/ui_tokens.dart';
import '../../../l10n/generated/app_localizations.dart';

class WorkspaceTopAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const WorkspaceTopAppBar({
    super.key,
    required this.title,
    required this.compact,
    required this.actions,
    required this.onOpenDrawer,
  });

  final String title;
  final bool compact;
  final List<Widget> actions;
  final VoidCallback onOpenDrawer;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      centerTitle: compact,
      toolbarHeight: compact ? 60 : 64,
      title: Semantics(
        header: true,
        child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      leading: compact
          ? IconButton(
              tooltip: MaterialLocalizations.of(context).openAppDrawerTooltip,
              icon: const Icon(Icons.menu_rounded),
              onPressed: onOpenDrawer,
            )
          : null,
      actions: actions,
    );
  }
}

class WorkspaceBodyShell extends StatelessWidget {
  const WorkspaceBodyShell({
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ...?betaBanner == null ? null : [betaBanner!],
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!compact)
                    AnimatedContainer(
                      duration: FolioMotion.medium1,
                      curve: FolioMotion.emphasized,
                      width: sidePanelWidth,
                      child: sidePanel,
                    ),
                  if (!compact && showSidebarResizeHandle)
                    Semantics(
                      label: l10n.resizeSidebarHandle,
                      hint: l10n.resizeSidebarHandleHint,
                      child: MouseRegion(
                        cursor: SystemMouseCursors.resizeColumn,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onHorizontalDragUpdate: (details) {
                            onResizeSidebarDelta?.call(details.delta.dx);
                          },
                          child: Container(
                            width: 6,
                            color: scheme.outlineVariant.withValues(
                              alpha: FolioAlpha.track,
                            ),
                          ),
                        ),
                      ),
                    ),
                  Expanded(child: editorContent),
                ],
              ),
            ),
          ],
        ),
        if (sidebarLeftEdgeHover && !compact)
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 14,
            child: MouseRegion(
              opaque: true,
              onEnter: (_) => onSidebarEdgeEnter?.call(),
              child: const ColoredBox(color: Color(0x00000000)),
            ),
          ),
        if (aiFloatingPanel != null)
          Positioned(
            right: FolioSpace.md,
            bottom: FolioSpace.md,
            width: aiFloatingWidth,
            height: aiFloatingHeight,
            child: aiFloatingShowResizeHandles
                ? Material(
                    elevation: FolioElevation.menu,
                    shadowColor: scheme.shadow.withValues(alpha: FolioAlpha.soft),
                    borderRadius: BorderRadius.circular(FolioRadius.xl),
                    clipBehavior: Clip.antiAlias,
                    color: scheme.surface,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Semantics(
                          label: l10n.resizeAiPanelHeightHandle,
                          hint: l10n.resizeAiPanelHeightHandleHint,
                          child: MouseRegion(
                            cursor: SystemMouseCursors.resizeUpDown,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onVerticalDragUpdate: (details) {
                                onResizeAiPanelHeight?.call(-details.delta.dy);
                              },
                              child: Container(
                                height: 7,
                                color: scheme.outlineVariant.withValues(
                                  alpha: FolioAlpha.track,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Semantics(
                                label: l10n.aiPanelResizeHandle,
                                hint: l10n.aiPanelResizeHandleHint,
                                child: MouseRegion(
                                  cursor: SystemMouseCursors.resizeColumn,
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onHorizontalDragUpdate: (details) {
                                      onResizeAiPanelWidth?.call(
                                        details.delta.dx,
                                      );
                                    },
                                    child: Container(
                                      width: 7,
                                      color: scheme.outlineVariant.withValues(
                                        alpha: FolioAlpha.track,
                                      ),
                                    ),
                                  ),
                                ),
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
                    shadowColor: scheme.shadow.withValues(alpha: FolioAlpha.soft),
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
  }
}
