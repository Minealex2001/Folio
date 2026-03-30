import 'package:flutter/material.dart';

import '../../../app/ui_tokens.dart';

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
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
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
    required this.showAiPanel,
    required this.aiPanelWidth,
    required this.onResizeAiPanel,
    required this.scheme,
    this.betaBanner,
    this.aiPanel,
    this.overlay,
  });

  final bool compact;
  final double sidePanelWidth;
  final Widget sidePanel;
  final Widget editorContent;
  final bool showAiPanel;
  final double aiPanelWidth;
  final ValueChanged<double> onResizeAiPanel;
  final ColorScheme scheme;
  final Widget? betaBanner;
  final Widget? aiPanel;
  final Widget? overlay;

  @override
  Widget build(BuildContext context) {
    return Stack(
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
                  Expanded(child: editorContent),
                  if (showAiPanel)
                    MouseRegion(
                      cursor: SystemMouseCursors.resizeColumn,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onHorizontalDragUpdate: (details) =>
                            onResizeAiPanel(details.delta.dx),
                        child: Container(
                          width: 6,
                          color: scheme.outlineVariant.withValues(
                            alpha: FolioAlpha.track,
                          ),
                        ),
                      ),
                    ),
                  AnimatedSwitcher(
                    duration: FolioMotion.medium1,
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: SizeTransition(
                        sizeFactor: animation,
                        axis: Axis.horizontal,
                        axisAlignment: -1,
                        child: child,
                      ),
                    ),
                    child: showAiPanel
                        ? SizedBox(
                            key: const ValueKey('ai_panel'),
                            width: aiPanelWidth,
                            child: aiPanel ?? const SizedBox.shrink(),
                          )
                        : const SizedBox.shrink(
                            key: ValueKey('ai_panel_hidden'),
                          ),
                  ),
                ],
              ),
            ),
          ],
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
