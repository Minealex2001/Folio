import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Puntos animados tipo «escribiendo…» mientras la IA genera respuesta.
class FolioAiTypingIndicator extends StatefulWidget {
  const FolioAiTypingIndicator({super.key, this.color});

  final Color? color;

  @override
  State<FolioAiTypingIndicator> createState() => _FolioAiTypingIndicatorState();
}

class _FolioAiTypingIndicatorState extends State<FolioAiTypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseColor =
        widget.color ?? Theme.of(context).colorScheme.onSurfaceVariant;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final phase = (t + i * 0.22) % 1.0;
            final wave = (math.sin(phase * math.pi * 2) + 1) / 2;
            final opacity = 0.28 + 0.62 * wave;
            return Padding(
              padding: EdgeInsets.only(right: i < 2 ? 5 : 0),
              child: Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: baseColor.withValues(alpha: opacity),
                  shape: BoxShape.circle,
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
