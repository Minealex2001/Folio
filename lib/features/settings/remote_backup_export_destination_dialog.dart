import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';

enum RemoteBackupExportChoice { localFile, configuredFolder, webdav }

/// Selector de destino para exportación manual de copia.
class RemoteBackupExportDestinationDialog extends StatelessWidget {
  const RemoteBackupExportDestinationDialog({
    super.key,
    required this.l10n,
    required this.canFolder,
    required this.canWebdav,
  });

  final AppLocalizations l10n;
  final bool canFolder;
  final bool canWebdav;

  static Future<RemoteBackupExportChoice?> show(
    BuildContext context, {
    required AppLocalizations l10n,
    required bool canFolder,
    required bool canWebdav,
  }) {
    return showDialog<RemoteBackupExportChoice>(
      context: context,
      builder: (ctx) => RemoteBackupExportDestinationDialog(
        l10n: l10n,
        canFolder: canFolder,
        canWebdav: canWebdav,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(l10n.remoteBackupExportDestinationTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            leading: const Icon(Icons.save_alt_outlined),
            title: Text(l10n.remoteBackupExportToLocalFile),
            onTap: () =>
                Navigator.pop(context, RemoteBackupExportChoice.localFile),
          ),
          if (canFolder)
            ListTile(
              leading: const Icon(Icons.folder_open_outlined),
              title: Text(l10n.remoteBackupExportToFolder),
              onTap: () => Navigator.pop(
                context,
                RemoteBackupExportChoice.configuredFolder,
              ),
            ),
          if (canWebdav)
            ListTile(
              leading: const Icon(Icons.cloud_upload_outlined),
              title: Text(l10n.remoteBackupExportToWebdav),
              onTap: () =>
                  Navigator.pop(context, RemoteBackupExportChoice.webdav),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
      ],
    );
  }
}
