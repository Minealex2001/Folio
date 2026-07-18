import 'package:flutter/material.dart';

class CopilotTextEditingController extends TextEditingController {
  CopilotTextEditingController({super.text});

  String _suggestion = '';

  String get suggestion => _suggestion;

  set suggestion(String value) {
    if (_suggestion != value) {
      _suggestion = value;
      notifyListeners();
    }
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    if (_suggestion.isEmpty) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    // El texto del bloque puede traer un salto de línea final (p. ej. al
    // reflejar un documento Quill). Si lo dejamos, el span de la sugerencia
    // queda empujado a una línea nueva y no se ve.
    var displayText = text;
    if (displayText.endsWith('\n')) {
      displayText = displayText.substring(0, displayText.length - 1);
    }

    return TextSpan(
      style: style,
      children: [
        TextSpan(text: displayText, style: style),
        TextSpan(
          text: _suggestion,
          style: style?.copyWith(
            color: scheme.onSurfaceVariant.withOpacity(0.4),
          ) ??
          TextStyle(
            color: Colors.grey.withOpacity(0.4),
          ),
        ),
      ],
    );
  }
}
