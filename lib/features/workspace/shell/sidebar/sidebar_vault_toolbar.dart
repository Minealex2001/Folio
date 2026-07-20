import 'package:flutter/material.dart';

import '../../../../app/ui_tokens.dart';
import '../../../../data/vault_registry.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../app/widgets/folio_interactions.dart';

class SidebarVaultToolbar extends StatelessWidget {
  const SidebarVaultToolbar({
    super.key,
    required this.vaults,
    required this.loading,
    required this.activeVaultId,
    required this.onSwitchVault,
    required this.onAddVault,
    required this.onRenameVault,
  });

  final List<VaultEntry> vaults;
  final bool loading;
  final String? activeVaultId;
  final ValueChanged<String> onSwitchVault;
  final VoidCallback onAddVault;
  final VoidCallback onRenameVault;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    if (loading) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(
          FolioSpace.sm,
          FolioSpace.sm,
          FolioSpace.sm,
          FolioSpace.xs,
        ),
        child: Semantics(
          label: l10n.sidebarVaultsLoading,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(FolioRadius.sm),
                child: LinearProgressIndicator(
                  minHeight: 3,
                  backgroundColor: scheme.surfaceContainerHighest.withValues(
                    alpha: FolioAlpha.track,
                  ),
                  color: scheme.primary.withValues(alpha: 0.85),
                ),
              ),
              const SizedBox(height: FolioSpace.sm),
              Text(
                l10n.sidebarVaultsLoading,
                style: textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (vaults.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(
          FolioSpace.sm,
          FolioSpace.sm,
          FolioSpace.sm,
          FolioSpace.xs,
        ),
        child: Semantics(
          label: l10n.sidebarVaultsEmpty,
          child: FadingEmptyState(
            child: Container(
              padding: const EdgeInsets.all(FolioSpace.sm),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(FolioRadius.md),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.folder_off_outlined,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: FolioSpace.sm),
                  Expanded(
                    child: Text(
                      l10n.sidebarVaultsEmpty,
                      style: textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    VaultEntry? current;
    for (final e in vaults) {
      if (e.id == activeVaultId) {
        current = e;
        break;
      }
    }
    current ??= vaults.first;

    return Padding(
      padding: const EdgeInsets.all(FolioSpace.sm),
      child: PopupMenuButton<String>(
        tooltip: l10n.switchVaultTooltip,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FolioRadius.md),
        ),
        offset: const Offset(0, 64),
        onSelected: (value) {
          if (value == 'add') {
            onAddVault();
          } else if (value == 'rename') {
            onRenameVault();
          } else {
            onSwitchVault(value);
          }
        },
        itemBuilder: (ctx) => [
          for (final e in vaults)
            PopupMenuItem(
              value: e.id,
              child: ListTile(
                leading: const Icon(Icons.lock_outline),
                title: Text(e.displayName),
                trailing: e.id == activeVaultId ? const Icon(Icons.check) : null,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          const PopupMenuDivider(),
          PopupMenuItem(
            value: 'add',
            child: ListTile(
              leading: Icon(Icons.add_circle_outline),
              title: Text(l10n.addVault),
              contentPadding: EdgeInsets.zero,
            ),
          ),
          PopupMenuItem(
            value: 'rename',
            child: ListTile(
              leading: Icon(Icons.edit_outlined),
              title: Text(l10n.renameActiveVault),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
        child: Container(
          padding: const EdgeInsets.all(FolioSpace.sm),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(FolioRadius.md),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.lock,
                  size: 20,
                  color: scheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: FolioSpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.activeVaultLabel,
                      style: textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      current.displayName,
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: scheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(Icons.unfold_more, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
