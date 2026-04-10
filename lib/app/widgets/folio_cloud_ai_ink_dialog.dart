import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';

Future<void> showFolioCloudAiInkExhaustedDialog(
  BuildContext context, {
  required VoidCallback onOpenSettings,
  required VoidCallback onOpenFolioCloudPitch,
}) {
  final l10n = AppLocalizations.of(context);
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.folioCloudAiNoInkTitle),
      content: Text(l10n.folioCloudAiNoInkBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(l10n.cancel),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(ctx);
            onOpenSettings();
          },
          child: Text(l10n.folioCloudAiNoInkActionLocal),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(ctx);
            onOpenFolioCloudPitch();
          },
          child: Text(l10n.folioCloudAiNoInkActionCloud),
        ),
      ],
    ),
  );
}
