import 'package:flutter/material.dart';

void showFolioSnack(
  BuildContext context,
  String message, {
  bool error = false,
}) {
  final trimmed = message.trim();
  if (trimmed.isEmpty) return;
  final scheme = Theme.of(context).colorScheme;
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Text(trimmed),
      backgroundColor: error ? scheme.errorContainer : null,
      behavior: SnackBarBehavior.floating,
    ),
  );
}
