import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../app/folio_in_app_shortcuts.dart';

/// Diálogo modal: captura una pulsación y devuelve [SingleActivator].
class InAppShortcutCaptureDialog extends StatefulWidget {
  const InAppShortcutCaptureDialog({super.key});

  @override
  State<InAppShortcutCaptureDialog> createState() =>
      _InAppShortcutCaptureDialogState();
}

class _InAppShortcutCaptureDialogState
    extends State<InAppShortcutCaptureDialog> {
  SingleActivator? _captured;

  static bool _isModifierOnly(LogicalKeyboardKey k) {
    return k == LogicalKeyboardKey.control ||
        k == LogicalKeyboardKey.controlLeft ||
        k == LogicalKeyboardKey.controlRight ||
        k == LogicalKeyboardKey.shift ||
        k == LogicalKeyboardKey.shiftLeft ||
        k == LogicalKeyboardKey.shiftRight ||
        k == LogicalKeyboardKey.alt ||
        k == LogicalKeyboardKey.altLeft ||
        k == LogicalKeyboardKey.altRight ||
        k == LogicalKeyboardKey.meta ||
        k == LogicalKeyboardKey.metaLeft ||
        k == LogicalKeyboardKey.metaRight;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.shortcutsCaptureTitle),
      content: SizedBox(
        width: 320,
        child: Focus(
          autofocus: true,
          onKeyEvent: (node, event) {
            if (event is! KeyDownEvent) return KeyEventResult.ignored;
            if (event.logicalKey == LogicalKeyboardKey.escape) {
              Navigator.of(context).pop();
              return KeyEventResult.handled;
            }
            if (_isModifierOnly(event.logicalKey)) {
              return KeyEventResult.ignored;
            }
            final hw = HardwareKeyboard.instance;
            final a = SingleActivator(
              event.logicalKey,
              control: hw.isControlPressed,
              meta: hw.isMetaPressed,
              alt: hw.isAltPressed,
              shift: hw.isShiftPressed,
            );
            setState(() => _captured = a);
            return KeyEventResult.handled;
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _captured == null
                    ? l10n.shortcutsCaptureHint
                    : describeActivator(_captured!),
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _captured == null
              ? null
              : () => Navigator.of(context).pop(_captured),
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
