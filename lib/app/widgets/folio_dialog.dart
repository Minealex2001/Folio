import 'package:flutter/material.dart';

class FolioDialog extends StatelessWidget {
  const FolioDialog({
    super.key,
    required this.title,
    required this.content,
    required this.actions,
    this.contentWidth,
  });

  final Widget title;
  final Widget content;
  final List<Widget> actions;
  final double? contentWidth;

  @override
  Widget build(BuildContext context) {
    final body = contentWidth == null
        ? content
        : SizedBox(width: contentWidth, child: content);
    return AlertDialog(title: title, content: body, actions: actions);
  }

  // ---------------------------------------------------------------------------
  // Helpers estáticos para los patrones más frecuentes
  // ---------------------------------------------------------------------------

  /// Muestra un diálogo de confirmación con botones Cancel + acción.
  ///
  /// Devuelve `true` si el usuario confirma, `false`/`null` si cancela.
  static Future<bool?> confirm(
    BuildContext context, {
    required Widget title,
    required Widget content,
    required String confirmLabel,
    String? cancelLabel,

    /// Si es `true`, el botón de confirmación usa [FilledButton.tonal]
    /// con color de error (para acciones destructivas).
    bool destructive = false,
    bool barrierDismissible = true,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (ctx) {
        final l10n = cancelLabel;
        return AlertDialog(
          title: title,
          content: content,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                l10n ?? MaterialLocalizations.of(ctx).cancelButtonLabel,
              ),
            ),
            if (destructive)
              FilledButton.tonal(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(ctx).colorScheme.errorContainer,
                  foregroundColor: Theme.of(ctx).colorScheme.onErrorContainer,
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(confirmLabel),
              )
            else
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(confirmLabel),
              ),
          ],
        );
      },
    );
  }

  /// Muestra un diálogo informativo con un único botón OK.
  static Future<void> info(
    BuildContext context, {
    required Widget title,
    required Widget content,
    String? okLabel,
  }) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: title,
        content: content,
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(okLabel ?? MaterialLocalizations.of(ctx).okButtonLabel),
          ),
        ],
      ),
    );
  }

  /// Muestra un diálogo con un único campo de texto.
  ///
  /// Devuelve el texto introducido, o `null` si se cancela.
  static Future<String?> input(
    BuildContext context, {
    required Widget title,
    String? hint,
    String? initialValue,
    String? confirmLabel,
    String? cancelLabel,
    int maxLines = 1,
    int? maxLength,
    bool autofocus = true,
  }) {
    String draft = initialValue ?? '';
    return showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: title,
          content: TextFormField(
            initialValue: draft,
            autofocus: autofocus,
            maxLines: maxLines,
            maxLength: maxLength,
            decoration: InputDecoration(hintText: hint),
            onChanged: (v) => draft = v,
            onFieldSubmitted: (_) => Navigator.pop(ctx, draft.trim()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                cancelLabel ?? MaterialLocalizations.of(ctx).cancelButtonLabel,
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, draft.trim()),
              child: Text(
                confirmLabel ?? MaterialLocalizations.of(ctx).okButtonLabel,
              ),
            ),
          ],
        );
      },
    );
  }
}
