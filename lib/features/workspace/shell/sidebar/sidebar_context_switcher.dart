import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app/ui_tokens.dart';
import '../../../../app/widgets/folio_dialog.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../services/cloud_account/cloud_account_controller.dart';
import '../../../../services/cloud_account/organization_context_controller.dart';
import 'sidebar_cloud_account_switcher.dart';

/// Un solo chip de contexto en el sidebar: cuenta Folio Cloud + equipo.
///
/// Oculto si solo hay una cuenta y (como mucho) la org personal — evita el
/// doble selector que sobrecargaba el footer.
class SidebarContextSwitcher extends StatelessWidget {
  const SidebarContextSwitcher({
    super.key,
    required this.account,
    this.organizationContext,
    this.onManageTeams,
  });

  final CloudAccountController account;
  final OrganizationContextController? organizationContext;
  final VoidCallback? onManageTeams;

  @override
  Widget build(BuildContext context) {
    final lists = <Listenable>[account];
    if (organizationContext != null) lists.add(organizationContext!);

    return ListenableBuilder(
      listenable: Listenable.merge(lists),
      builder: (context, _) {
        if (!account.isSignedIn) return const SizedBox.shrink();

        final l10n = AppLocalizations.of(context);
        final scheme = Theme.of(context).colorScheme;
        final accounts = account.accounts;
        final orgs = organizationContext?.organizations ?? const [];
        final multiAccount = accounts.length > 1;
        final multiOrg = orgs.length > 1;

        // Nada que cambiar → no ocupar espacio.
        if (!multiAccount && !multiOrg) return const SizedBox.shrink();

        final activeOrg = organizationContext?.activeOrganization;
        final String label;
        final IconData icon;
        if (multiOrg && activeOrg != null) {
          label = activeOrg.isPersonal
              ? l10n.orgPanelPersonalOrgLabel(activeOrg.name)
              : activeOrg.name;
          icon = activeOrg.isPersonal
              ? Icons.person_outline
              : Icons.groups_outlined;
        } else if (multiAccount) {
          label = account.email?.trim().isNotEmpty == true
              ? account.email!.trim()
              : (account.displayName ?? l10n.cloudAccountSwitcherFallback);
          icon = Icons.manage_accounts_outlined;
        } else {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(
            FolioSpace.sm,
            0,
            FolioSpace.sm,
            FolioSpace.xs,
          ),
          child: PopupMenuButton<String>(
          tooltip: multiOrg
              ? l10n.orgSwitcherTooltip
              : l10n.cloudAccountSwitcherTooltip,
          padding: EdgeInsets.zero,
          onSelected: (value) {
            if (value == '_manage_teams') {
              onManageTeams?.call();
              return;
            }
            if (value == '_add_account') {
              unawaited(
                showAddFolioCloudAccountDialog(
                  context: context,
                  account: account,
                ),
              );
              return;
            }
            if (value == '_remove_account') {
              unawaited(_confirmRemoveActive(context));
              return;
            }
            if (value.startsWith('acc:')) {
              final uid = value.substring(4);
              if (uid != account.activeUid) {
                unawaited(account.switchAccount(uid));
              }
              return;
            }
            if (value.startsWith('org:')) {
              final id = value.substring(4);
              unawaited(
                organizationContext?.setActiveOrganizationId(id),
              );
            }
          },
          itemBuilder: (context) {
            final items = <PopupMenuEntry<String>>[];

            if (multiAccount) {
              items.add(
                PopupMenuItem(
                  enabled: false,
                  height: 32,
                  child: Text(
                    l10n.cloudAccountSwitcherFallback,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              );
              for (final a in accounts) {
                items.add(
                  PopupMenuItem(
                    value: 'acc:${a.uid}',
                    child: Row(
                      children: [
                        SizedBox(
                          width: 22,
                          child: a.uid == account.activeUid
                              ? Icon(Icons.check, size: 16, color: scheme.primary)
                              : null,
                        ),
                        Expanded(
                          child: Text(
                            a.email.isNotEmpty ? a.email : a.uid,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
              items.add(
                PopupMenuItem(
                  value: '_add_account',
                  child: Row(
                    children: [
                      const Icon(Icons.person_add_alt_1_outlined, size: 18),
                      const SizedBox(width: FolioSpace.sm),
                      Text(l10n.cloudAccountSwitcherAdd),
                    ],
                  ),
                ),
              );
              items.add(
                PopupMenuItem(
                  value: '_remove_account',
                  child: Row(
                    children: [
                      const Icon(Icons.logout, size: 18),
                      const SizedBox(width: FolioSpace.sm),
                      Text(l10n.cloudAccountSwitcherRemove),
                    ],
                  ),
                ),
              );
            }

            if (multiAccount && multiOrg) {
              items.add(const PopupMenuDivider());
            }

            if (multiOrg && organizationContext != null) {
              items.add(
                PopupMenuItem(
                  enabled: false,
                  height: 32,
                  child: Text(
                    l10n.settingsSectionOrganization,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              );
              for (final org in orgs) {
                items.add(
                  PopupMenuItem(
                    value: 'org:${org.id}',
                    child: Row(
                      children: [
                        SizedBox(
                          width: 22,
                          child: org.id ==
                                  organizationContext!.activeOrganizationId
                              ? Icon(Icons.check, size: 16, color: scheme.primary)
                              : null,
                        ),
                        Expanded(
                          child: Text(
                            org.isPersonal
                                ? l10n.orgPanelPersonalOrgLabel(org.name)
                                : org.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
              items.add(
                PopupMenuItem(
                  value: '_manage_teams',
                  child: Row(
                    children: [
                      const Icon(Icons.settings_outlined, size: 18),
                      const SizedBox(width: FolioSpace.sm),
                      Text(l10n.orgSwitcherManageTeams),
                    ],
                  ),
                ),
              );
            }

            return items;
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(FolioRadius.sm),
            ),
            child: Row(
              children: [
                Icon(icon, size: 15, color: scheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                Icon(
                  Icons.expand_more,
                  size: 16,
                  color: scheme.onSurfaceVariant,
                ),
              ],
            ),
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
    }
  }
}
