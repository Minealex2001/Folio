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
    final originalSpan = super.buildTextSpan(
      context: context,
      style: style,
      withComposing: withComposing,
    );
    if (_suggestion.isEmpty) {
      return originalSpan;
    }

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return TextSpan(
      style: style,
      children: [
        originalSpan,
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
