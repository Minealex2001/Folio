import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../l10n/generated/app_localizations.dart';
import 'smart_template_definitions.dart';

/// Fase G2 del rediseño UX del editor — mini-flujo inline secuencial de
/// variables antes de generar una smart template. Mismo patrón visual de
/// overlay-anclado-y-centrado ya establecido por `CommandPaletteOverlay`
/// (Fase C2) en vez de un `Dialog` modal separado — una pregunta a la vez,
/// Enter avanza, Esc cancela.
class SmartTemplateFlowOverlay extends StatefulWidget {
  const SmartTemplateFlowOverlay({
    super.key,
    required this.template,
    required this.onComplete,
    required this.onCancel,
  });

  final SmartTemplateDefinition template;
  final ValueChanged<Map<String, String>> onComplete;
  final VoidCallback onCancel;

  @override
  State<SmartTemplateFlowOverlay> createState() =>
      _SmartTemplateFlowOverlayState();
}

class _SmartTemplateFlowOverlayState extends State<SmartTemplateFlowOverlay> {
  int _stepIndex = 0;
  final Map<String, String> _answers = {};
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  bool get _isLastStep => _stepIndex >= widget.template.variables.length - 1;

  void _advance() {
    final variable = widget.template.variables[_stepIndex];
    _answers[variable.id] = _controller.text.trim();
    if (_isLastStep) {
      widget.onComplete(_answers);
      return;
    }
    setState(() {
      _stepIndex += 1;
      _controller.clear();
    });
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      widget.onCancel();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter) {
      _advance();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final variables = widget.template.variables;
    final variable = variables[_stepIndex];

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onCancel,
            child: const SizedBox.shrink(),
          ),
        ),
        Align(
          alignment: const Alignment(0, -0.55),
          child: Material(
            elevation: 12,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Focus(
                onKeyEvent: _onKeyEvent,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(widget.template.icon, size: 18, color: scheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            widget.template.labelOf(l10n),
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const Spacer(),
                          Text(
                            '${_stepIndex + 1}/${variables.length}',
                            style: TextStyle(
                              color: scheme.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(variable.promptOf(l10n)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        autofocus: true,
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: l10n.smartTemplateFlowSkipHint,
                          border: const OutlineInputBorder(),
                        ),
                        onSubmitted: (_) => _advance(),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: widget.onCancel,
                            child: Text(l10n.smartTemplateFlowCancel),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed: _advance,
                            child: Text(
                              _isLastStep
                                  ? l10n.smartTemplateFlowGenerate
                                  : l10n.smartTemplateFlowNext,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
