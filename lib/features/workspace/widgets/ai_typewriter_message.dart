import 'dart:async';

import 'package:flutter/material.dart';

/// Muestra un texto revelándose progresivamente (efecto "typewriter").
///
/// Diseñado para respuestas de IA que llegan completas (no streaming) y donde
/// renderizar Markdown parcial podría romper el layout.
class FolioAiTypewriterMessage extends StatefulWidget {
  const FolioAiTypewriterMessage({
    super.key,
    required this.fullText,
    required this.style,
    this.tick = const Duration(milliseconds: 35),
    this.charsPerTick = 3,
    this.maxDuration = const Duration(seconds: 6),
    this.onCompleted,
    this.selectable = true,
  });

  final String fullText;
  final TextStyle style;

  /// Intervalo de actualización del reveal.
  final Duration tick;

  /// Número base de "caracteres" (grapheme clusters) por tick.
  final int charsPerTick;

  /// Duración máxima antes de forzar finalización (para textos largos).
  final Duration maxDuration;

  final VoidCallback? onCompleted;

  /// Si true, usa `SelectableText` durante la animación.
  final bool selectable;

  @override
  State<FolioAiTypewriterMessage> createState() =>
      _FolioAiTypewriterMessageState();
}

class _FolioAiTypewriterMessageState extends State<FolioAiTypewriterMessage> {
  Timer? _timer;
  int _visible = 0;
  late int _total;
  late DateTime _startedAt;

  @override
  void initState() {
    super.initState();
    _resetAndStart();
  }

  @override
  void didUpdateWidget(covariant FolioAiTypewriterMessage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fullText != widget.fullText) {
      _resetAndStart();
    }
  }

  void _resetAndStart() {
    _timer?.cancel();
    _startedAt = DateTime.now();
    _total = widget.fullText.characters.length;
    _visible = 0;
    if (_total == 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onCompleted?.call();
      });
      return;
    }
    _timer = Timer.periodic(widget.tick, (_) => _step());
  }

  int _effectiveCharsPerTick() {
    final base = widget.charsPerTick <= 0 ? 1 : widget.charsPerTick;
    final t = _total;
    if (t <= 400) return base;
    if (t <= 1200) return base + 2;
    return base + 6;
  }

  void _step() {
    if (!mounted) return;

    final elapsed = DateTime.now().difference(_startedAt);
    if (elapsed >= widget.maxDuration) {
      _finish();
      return;
    }

    final next = (_visible + _effectiveCharsPerTick()).clamp(0, _total);
    if (next == _visible) return;

    setState(() {
      _visible = next;
    });

    if (_visible >= _total) {
      _finish();
    }
  }

  void _finish() {
    _timer?.cancel();
    _timer = null;
    if (!mounted) return;
    if (_visible != _total) {
      setState(() {
        _visible = _total;
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onCompleted?.call();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visibleText =
        widget.fullText.characters.take(_visible).toString().trimRight();
    if (widget.selectable) {
      return SelectableText(
        visibleText,
        style: widget.style,
      );
    }
    return Text(
      visibleText,
      style: widget.style,
    );
  }
}

