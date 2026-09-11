import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Campo numérico compacto reutilizado por los editores del inspector
/// (tamaño, posición, radio de esquina). Confirma el valor en
/// `onSubmitted`/`onEditingComplete`, no en cada tecla — evita escribir un
/// valor a medio teclear.
class InspectorNumberField extends StatefulWidget {
  const InspectorNumberField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final double? value;
  final ValueChanged<double> onChanged;

  @override
  State<InspectorNumberField> createState() => _InspectorNumberFieldState();
}

class _InspectorNumberFieldState extends State<InspectorNumberField> {
  late final TextEditingController _controller;

  String _format(double? value) =>
      value == null ? '' : value.toStringAsFixed(value == value.roundToDouble() ? 0 : 1);

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _format(widget.value));
  }

  @override
  void didUpdateWidget(covariant InspectorNumberField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && !_controller.selection.isValid) {
      _controller.text = _format(widget.value);
    }
  }

  void _commit(String text) {
    final parsed = double.tryParse(text.trim());
    if (parsed != null) widget.onChanged(parsed);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-]'))],
      decoration: InputDecoration(labelText: widget.label, isDense: true),
      onSubmitted: _commit,
      onEditingComplete: () => _commit(_controller.text),
    );
  }
}
