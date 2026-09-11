import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app/ui_tokens.dart';
import '../../../../app/widgets/folio_dialog.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../services/cloud_account/cloud_account_controller.dart';

/// Switcher de cuentas Folio Cloud (multi-cuenta en dispositivo).
/// Distinto del switcher de equipos ([SidebarOrganizationSwitcher]).
class SidebarCloudAccountSwitcher extends StatelessWidget {
  const SidebarCloudAccountSwitcher({
    super.key,
    required this.account,
    this.onAddAccount,
    this.onAfterSwitch,
  });

  final CloudAccountController account;
  final VoidCallback? onAddAccount;
  final VoidCallback? onAfterSwitch;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: account,
      builder: (context, _) {
        if (!account.isSignedIn) return const SizedBox.shrink();
        final accounts = account.accounts;
        final active = account.activeUid;
        final label = account.email?.trim().isNotEmpty == true
            ? account.email!.trim()
            : (account.displayName ?? l10n.cloudAccountSwitcherFallback);

        return PopupMenuButton<String>(
          tooltip: l10n.cloudAccountSwitcherTooltip,
          onSelected: (value) {
            if (value == '_add') {
              onAddAccount?.call();
              return;
            }
            if (value == '_remove') {
              unawaited(_confirmRemoveActive(context));
              return;
            }
            if (value != active) {
              unawaited(() async {
                await account.switchAccount(value);
                onAfterSwitch?.call();
              }());
            }
          },
          itemBuilder: (context) => [
            for (final a in accounts)
              PopupMenuItem(
                value: a.uid,
                child: Row(
                  children: [
                    Icon(
                      a.uid == active
                          ? Icons.check_circle
                          : Icons.account_circle_outlined,
                      size: 18,
                    ),
                    const SizedBox(width: FolioSpace.sm),
                    Expanded(
                      child: Text(
                        a.email.isNotEmpty ? a.email : a.uid,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            const PopupMenuDivider(),
            PopupMenuItem(
              value: '_add',
              child: Row(
                children: [
                  const Icon(Icons.person_add_alt_1_outlined, size: 18),
                  const SizedBox(width: FolioSpace.sm),
                  Text(l10n.cloudAccountSwitcherAdd),
                ],
              ),
            ),
            PopupMenuItem(
              value: '_remove',
              child: Row(
                children: [
                  const Icon(Icons.logout, size: 18),
                  const SizedBox(width: FolioSpace.sm),
                  Text(l10n.cloudAccountSwitcherRemove),
                ],
              ),
            ),
          ],
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: FolioSpace.sm,
              vertical: FolioSpace.xs,
            ),
            child: Row(
              children: [
                const Icon(Icons.manage_accounts_outlined, size: 18),
                const SizedBox(width: FolioSpace.xs),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
                if (accounts.length > 1)
                  Padding(
                    padding: const EdgeInsets.only(left: FolioSpace.xs),
                    child: Text(
                      '${accounts.length}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                    ),
                  ),
                const Icon(Icons.expand_more, size: 18),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmRemoveActive(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => FolioDialog(
        title: Text(l10n.cloudAccountSwitcherRemoveTitle),
        content: Text(l10n.cloudAccountSwitcherRemoveBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.cloudAccountSwitcherRemove),
          ),
        ],
      ),
    );
    if (go == true && context.mounted) {
      final uid = account.activeUid;
      if (uid != null) await account.removeAccount(uid);
      onAfterSwitch?.call();
    }
  }
}

/// Diálogo simple para añadir otra cuenta Folio Cloud.
Future<void> showAddFolioCloudAccountDialog({
  required BuildContext context,
  required CloudAccountController account,
}) async {
  final l10n = AppLocalizations.of(context);
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  var busy = false;
  String? error;

  await showDialog<void>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setLocal) {
          return FolioDialog(
            title: Text(l10n.cloudAccountSwitcherAdd),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: FolioSpace.sm),
                    child: Text(
                      error!,
                      style: TextStyle(color: Theme.of(ctx).colorScheme.error),
                    ),
                  ),
                TextField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: l10n.orgPanelEmailLabel,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: FolioSpace.sm),
                TextField(
                  controller: passCtrl,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: l10n.cloudAccountPasswordLabel,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: busy ? null : () => Navigator.pop(ctx),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: busy
                    ? null
                    : () async {
                        setLocal(() {
                          busy = true;
                          error = null;
                        });
                        try {
                          await account.addAccountWithEmailAndPassword(
                            email: emailCtrl.text.trim(),
                            password: passCtrl.text,
                          );
                          if (ctx.mounted) Navigator.pop(ctx);
                        } catch (e) {
                          setLocal(() {
                            error = '$e';
                            busy = false;
                          });
                        }
                      },
                child: Text(l10n.cloudAccountSwitcherAdd),
              ),
            ],
          );
        },
      );
    },
  );
}
