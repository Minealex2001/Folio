import 'package:flutter/material.dart';

class FolioPasswordField extends StatelessWidget {
  const FolioPasswordField({
    super.key,
    required this.controller,
    required this.labelText,
    required this.obscureText,
    required this.onToggleObscure,
    required this.showPasswordTooltip,
    required this.hidePasswordTooltip,
    this.enabled = true,
    this.onSubmitted,
    this.onChanged,
    this.textInputAction,
    this.autofocus = false,
    this.helperText,
    this.validator,
    this.errorText,
    this.focusNode,
  });

  final TextEditingController controller;
  final String labelText;
  final bool obscureText;
  final VoidCallback onToggleObscure;
  final String showPasswordTooltip;
  final String hidePasswordTooltip;
  final bool enabled;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final TextInputAction? textInputAction;
  final bool autofocus;
  final String? helperText;
  final String? Function(String?)? validator;
  final String? errorText;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      enabled: enabled,
      autofocus: autofocus,
      textInputAction: textInputAction,
      onFieldSubmitted: onSubmitted,
      onChanged: onChanged,
      validator: validator,
      focusNode: focusNode,
      decoration: InputDecoration(
        labelText: labelText,
        helperText: helperText,
        errorText: errorText,
        border: const OutlineInputBorder(),
        suffixIcon: IconButton(
          onPressed: enabled ? onToggleObscure : null,
          icon: Icon(obscureText ? Icons.visibility : Icons.visibility_off),
          tooltip: obscureText ? showPasswordTooltip : hidePasswordTooltip,
        ),
      ),
    );
  }
}
