import 'package:flutter/material.dart';

import '../../../app/ui_tokens.dart';

/// Burbuja esqueleto con shimmer mientras el asistente genera respuesta.
class FolioAiChatReplySkeleton extends StatefulWidget {
  const FolioAiChatReplySkeleton({
    super.key,
    required this.colorScheme,
  });

  final ColorScheme colorScheme;

  @override
  State<FolioAiChatReplySkeleton> createState() => _FolioAiChatReplySkeletonState();
}

class _FolioAiChatReplySkeletonState extends State<FolioAiChatReplySkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _shimmer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
    _shimmer = Tween<double>(begin: -1, end: 2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.linear),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = widget.colorScheme;
    final base = scheme.surfaceContainerHighest.withValues(alpha: 0.55);
    final hi = scheme.surfaceContainerHighest.withValues(alpha: 0.95);

    final track = scheme.surfaceContainer;

    Widget bar(double widthFactor, double height) {
      return LayoutBuilder(
        builder: (context, c) {
          final w = (c.maxWidth * widthFactor).clamp(0.0, c.maxWidth);
          return Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: w,
              height: height,
              child: AnimatedBuilder(
                animation: _shimmer,
                builder: (context, _) {
                  return ShaderMask(
                    blendMode: BlendMode.srcOver,
                    shaderCallback: (bounds) {
                      return LinearGradient(
                        begin: Alignment(-1 - _shimmer.value, 0),
                        end: Alignment(1 - _shimmer.value, 0),
                        colors: [
                          base.withValues(alpha: 0.35),
                          hi.withValues(alpha: 0.55),
                          base.withValues(alpha: 0.35),
                        ],
                      ).createShader(bounds);
                    },
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: track,
                        borderRadius: BorderRadius.circular(FolioRadius.sm),
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        },
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        bar(1.0, 12),
        const SizedBox(height: 8),
        bar(0.88, 10),
        const SizedBox(height: 8),
        bar(0.62, 10),
        const SizedBox(height: 8),
        bar(0.45, 8),
      ],
    );
  }
}
