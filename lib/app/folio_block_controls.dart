import 'package:flutter/material.dart';

import 'ui_tokens.dart';

/// Compact block-editor control tokens (Notion-like, distinct from global pill theme).
abstract final class FolioBlockControls {
  static const double buttonRadius = FolioRadius.md;
  static const double iconSize = 18;
  static const double gutterButtonSize = 24;
  static const double toolbarSpacing = 6;
  static const EdgeInsets buttonPadding = EdgeInsets.symmetric(
    horizontal: 10,
    vertical: 6,
  );

  static RoundedRectangleBorder get buttonShape => RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(buttonRadius),
  );

  static ButtonStyle _compactBase(ButtonStyle style) => style.copyWith(
    visualDensity: VisualDensity.compact,
    padding: WidgetStateProperty.all(buttonPadding),
    shape: WidgetStateProperty.all(buttonShape),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  );

  static ButtonStyle primaryStyle(ColorScheme scheme) => _compactBase(
    FilledButton.styleFrom(
      backgroundColor: scheme.secondaryContainer,
      foregroundColor: scheme.onSecondaryContainer,
    ),
  );

  static ButtonStyle secondaryStyle(ColorScheme scheme) => _compactBase(
    OutlinedButton.styleFrom(
      side: BorderSide(
        color: scheme.outlineVariant.withValues(alpha: FolioAlpha.border),
      ),
    ),
  );

  static ButtonStyle tertiaryStyle(ColorScheme scheme) => _compactBase(
    TextButton.styleFrom(foregroundColor: scheme.primary),
  );

  static ButtonStyle destructiveStyle(ColorScheme scheme) => _compactBase(
    FilledButton.styleFrom(
      backgroundColor: scheme.errorContainer,
      foregroundColor: scheme.onErrorContainer,
    ),
  );
}

/// Compact block action buttons with consistent hierarchy.
abstract final class BlockButton {
  static Widget primary({
    required VoidCallback? onPressed,
    required Widget child,
    Key? key,
  }) {
    return Builder(
      key: key,
      builder: (context) {
        final scheme = Theme.of(context).colorScheme;
        return FilledButton(
          onPressed: onPressed,
          style: FolioBlockControls.primaryStyle(scheme),
          child: child,
        );
      },
    );
  }

  static Widget primaryIcon({
    required VoidCallback? onPressed,
    required IconData icon,
    required String label,
    Key? key,
  }) {
    return Builder(
      key: key,
      builder: (context) {
        final scheme = Theme.of(context).colorScheme;
        return FilledButton.icon(
          onPressed: onPressed,
          style: FolioBlockControls.primaryStyle(scheme),
          icon: Icon(icon, size: FolioBlockControls.iconSize),
          label: Text(label),
        );
      },
    );
  }

  static Widget secondary({
    required VoidCallback? onPressed,
    required Widget child,
    Key? key,
  }) {
    return Builder(
      key: key,
      builder: (context) {
        final scheme = Theme.of(context).colorScheme;
        return OutlinedButton(
          onPressed: onPressed,
          style: FolioBlockControls.secondaryStyle(scheme),
          child: child,
        );
      },
    );
  }

  static Widget secondaryIcon({
    required VoidCallback? onPressed,
    required IconData icon,
    required String label,
    Key? key,
  }) {
    return Builder(
      key: key,
      builder: (context) {
        final scheme = Theme.of(context).colorScheme;
        return OutlinedButton.icon(
          onPressed: onPressed,
          style: FolioBlockControls.secondaryStyle(scheme),
          icon: Icon(icon, size: FolioBlockControls.iconSize),
          label: Text(label),
        );
      },
    );
  }

  static Widget tertiaryIcon({
    required VoidCallback? onPressed,
    required IconData icon,
    required String label,
    Key? key,
  }) {
    return Builder(
      key: key,
      builder: (context) {
        final scheme = Theme.of(context).colorScheme;
        return TextButton.icon(
          onPressed: onPressed,
          style: FolioBlockControls.tertiaryStyle(scheme),
          icon: Icon(icon, size: FolioBlockControls.iconSize),
          label: Text(label),
        );
      },
    );
  }

  static Widget destructive({
    required VoidCallback? onPressed,
    required Widget child,
    Key? key,
  }) {
    return Builder(
      key: key,
      builder: (context) {
        final scheme = Theme.of(context).colorScheme;
        return FilledButton(
          onPressed: onPressed,
          style: FolioBlockControls.destructiveStyle(scheme),
          child: child,
        );
      },
    );
  }
}

/// External block toolbar — always placed below block content.
class FolioBlockToolbar extends StatelessWidget {
  const FolioBlockToolbar({
    super.key,
    required this.children,
    this.alignment = WrapAlignment.start,
  });

  final List<Widget> children;
  final WrapAlignment alignment;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: FolioSpace.xs),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: FolioSpace.xs,
          vertical: FolioSpace.xxs,
        ),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(FolioBlockControls.buttonRadius),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: FolioAlpha.faint),
          ),
        ),
        child: Wrap(
          spacing: FolioBlockControls.toolbarSpacing,
          runSpacing: FolioBlockControls.toolbarSpacing,
          alignment: alignment,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: children,
        ),
      ),
    );
  }
}

/// Inline + button for Notion-style table gutters.
class FolioTableGutterButton extends StatelessWidget {
  const FolioTableGutterButton({
    super.key,
    required this.tooltip,
    required this.onPressed,
    this.icon = Icons.add_rounded,
    this.visible = true,
  });

  final String tooltip;
  final VoidCallback? onPressed;
  final IconData icon;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: scheme.surfaceContainerHigh.withValues(alpha: 0.85),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FolioRadius.sm),
          side: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: FolioAlpha.border),
          ),
        ),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(FolioRadius.sm),
          child: SizedBox(
            width: FolioBlockControls.gutterButtonSize,
            height: FolioBlockControls.gutterButtonSize,
            child: Icon(
              icon,
              size: 16,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

/// Horizontal resize handle for media blocks using [imageWidth].
class FolioBlockResizeHandle extends StatefulWidget {
  const FolioBlockResizeHandle({
    super.key,
    required this.child,
    required this.widthFactor,
    required this.onWidthChanged,
    required this.enabled,
    required this.maxAvailableWidth,
    this.minFactor = 0.2,
    this.maxFactor = 1.0,
  });

  final Widget child;
  final double widthFactor;
  final ValueChanged<double> onWidthChanged;
  final bool enabled;
  /// Full row width used to compute drag deltas (not the current scaled width).
  final double maxAvailableWidth;
  final double minFactor;
  final double maxFactor;

  @override
  State<FolioBlockResizeHandle> createState() => _FolioBlockResizeHandleState();
}

class _FolioBlockResizeHandleState extends State<FolioBlockResizeHandle> {
  bool _hovering = false;
  bool _dragging = false;
  double? _dragStartX;
  double? _dragStartFactor;

  void _onDragStart(DragStartDetails details) {
    if (!widget.enabled) return;
    setState(() {
      _dragging = true;
      _dragStartX = details.globalPosition.dx;
      _dragStartFactor = widget.widthFactor;
    });
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (!widget.enabled || _dragStartX == null || _dragStartFactor == null) {
      return;
    }
    final maxW = widget.maxAvailableWidth;
    if (maxW <= 0) return;
    final delta = details.globalPosition.dx - _dragStartX!;
    final next = (_dragStartFactor! + delta / maxW).clamp(
      widget.minFactor,
      widget.maxFactor,
    );
    if ((next - widget.widthFactor).abs() > 0.005) {
      widget.onWidthChanged(next);
    }
  }

  void _onDragEnd(DragEndDetails details) {
    setState(() {
      _dragging = false;
      _dragStartX = null;
      _dragStartFactor = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final showHandle = widget.enabled && (_hovering || _dragging);

    return MouseRegion(
          onEnter: (_) => setState(() => _hovering = true),
          onExit: (_) => setState(() => _hovering = false),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              widget.child,
              if (_dragging)
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: scheme.primary.withValues(alpha: 0.45),
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(FolioRadius.sm),
                      ),
                    ),
                  ),
                ),
              if (showHandle)
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.resizeLeftRight,
                    child: GestureDetector(
                      onHorizontalDragStart: _onDragStart,
                      onHorizontalDragUpdate: _onDragUpdate,
                      onHorizontalDragEnd: _onDragEnd,
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(FolioRadius.sm),
                            bottomRight: Radius.circular(FolioRadius.sm),
                          ),
                          border: Border.all(
                            color: scheme.outlineVariant,
                          ),
                        ),
                        child: Icon(
                          Icons.open_in_full_rounded,
                          size: 11,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
  }
}
