import 'dart:async' show unawaited;

import 'package:flutter/material.dart';

import '../../app/app_settings.dart';
import '../../app/widgets/folio_dialog.dart';
import '../../app/widgets/folio_password_field.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../session/vault_session.dart';
import '../../services/folio_cloud/folio_cloud_entitlements.dart';
import '../../services/folio_cloud/folio_cloud_import_all_vaults.dart';

/// Aviso + importación masiva de libretas tras login (onboarding o ajustes).
Future<FolioCloudImportAllResult?> showFolioCloudImportAllVaultsFlow({
  required BuildContext context,
  required VaultSession session,
  required FolioCloudEntitlementsController entitlements,
  required String accountPassword,
  AppSettings? telemetrySettings,
  bool skipWarning = false,
}) async {
  final l10n = AppLocalizations.of(context);
  await entitlements.refreshUserDocFromServer();
  if (!context.mounted) return null;

  final snap = entitlements.snapshot;
  if (!snap.canUseCloudBackup) {
    return const FolioCloudImportAllResult(
      imported: 0,
      skipped: 0,
      failed: 0,
      errors: [],
    );
  }

  final localEmpty = await session.isLocalVaultEmptyForCloudImport();
  if (!context.mounted) return null;

  if (!skipWarning) {
    final proceed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => FolioDialog(
        title: Text(l10n.folioCloudImportAllWarningTitle),
        content: Text(
          localEmpty
              ? l10n.folioCloudImportAllWarningBodyEmpty
              : l10n.folioCloudImportAllWarningBodyKeepLocal,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.folioCloudImportAllConfirm),
          ),
        ],
      ),
    );
    if (proceed != true || !context.mounted) return null;
  }

  final progress = ValueNotifier<String>(
    l10n.folioCloudImportAllProgress(0, 0, '…'),
  );
  unawaited(
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: FolioDialog(
          title: Text(l10n.folioCloudImportAllWarningTitle),
          content: ValueListenableBuilder<String>(
            valueListenable: progress,
            builder: (_, text, child) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const LinearProgressIndicator(),
                const SizedBox(height: 16),
                Text(text),
              ],
            ),
          ),
          actions: const [],
        ),
      ),
    ),
  );

  FolioCloudImportAllResult result;
  try {
    result = await importAllFolioCloudVaults(
      session: session,
      accountPassword: accountPassword,
      entitlements: snap,
      telemetrySettings: telemetrySettings,
      onProgress: (current, total, name) {
        progress.value = l10n.folioCloudImportAllProgress(current, total, name);
      },
      onNeedVaultPassword: ({required vaultId, required displayName}) async {
        if (!context.mounted) return null;
        return _promptVaultMasterPassword(
          context: context,
          l10n: l10n,
          displayName: displayName,
        );
      },
    );
  } finally {
    progress.dispose();
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  if (!context.mounted) return result;

  if (result.imported == 0 && result.failed == 0) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.folioCloudImportAllNone)),
    );
  } else {
    final msg = StringBuffer(
      l10n.folioCloudImportAllDone(result.imported),
    );
    if (result.failed > 0) {
      msg.write(' ');
      msg.write(l10n.folioCloudImportAllPartialFail(result.failed));
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg.toString())),
    );
  }

  return result;
}

Future<String?> _promptVaultMasterPassword({
  required BuildContext context,
  required AppLocalizations l10n,
  required String displayName,
}) async {
  final ctrl = TextEditingController();
  var obscure = true;
  try {
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => FolioDialog(
          title: Text(l10n.folioCloudImportAllVaultPasswordTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.folioCloudImportAllVaultPasswordBody(displayName)),
              const SizedBox(height: 12),
              FolioPasswordField(
                controller: ctrl,
                labelText: l10n.passwordLabel,
                obscureText: obscure,
                onToggleObscure: () => setSt(() => obscure = !obscure),
                showPasswordTooltip: l10n.showPassword,
                hidePasswordTooltip: l10n.hidePassword,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.folioCloudImportAllConfirm),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return null;
    return ctrl.text;
  } finally {
    ctrl.dispose();
  }
}
