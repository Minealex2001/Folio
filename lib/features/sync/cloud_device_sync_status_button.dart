import 'dart:async';

import 'package:flutter/material.dart';

import '../../application/vault_persistence_controller.dart';
import '../../data/vault_registry.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../services/folio_cloud/device_sync_vault_status.dart';
import '../../services/folio_cloud/folio_cloud_device_sync.dart';

/// Un solo indicador en la barra: guardado local + sync Folio Cloud.
class CloudDeviceSyncStatusButton extends StatelessWidget {
  const CloudDeviceSyncStatusButton({
    super.key,
    required this.saveStatus,
    required this.saveListenable,
    this.controller,
    this.pendingConflicts = 0,
    this.onOpenConflicts,
    this.onOpenVault,
  });

  final SaveStatus saveStatus;
  final Listenable saveListenable;
  final FolioCloudDeviceSyncController? controller;
  final int pendingConflicts;
  final VoidCallback? onOpenConflicts;
  final Future<void> Function(VaultEntry vault)? onOpenVault;

  bool get _cloudEnabled => controller != null && controller!.isEnabled;

  @override
  Widget build(BuildContext context) {
    final listenables = <Listenable>[saveListenable];
    final ctrl = controller;
    if (ctrl != null) listenables.add(ctrl);

    return ListenableBuilder(
      listenable: Listenable.merge(listenables),
      builder: (context, _) {
        final l10n = AppLocalizations.of(context);
        final scheme = Theme.of(context).colorScheme;
        final visual = _resolveVisual(
          l10n: l10n,
          scheme: scheme,
          save: saveStatus,
          cloud: ctrl,
          pendingConflicts: pendingConflicts,
          cloudEnabled: _cloudEnabled,
        );

        return IconButton(
          tooltip: visual.tooltip,
          onPressed: () => _showSheet(context),
          icon: Badge(
            isLabelVisible: visual.badge,
            smallSize: 8,
            child: visual.showSpinner
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: visual.color,
                    ),
                  )
                : Icon(visual.icon, color: visual.color),
          ),
        );
      },
    );
  }

  Future<void> _showSheet(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final ctrl = controller;
    if (_cloudEnabled && ctrl != null) {
      unawaited(ctrl.refreshAllVaultStatuses());
    }
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        final listenables = <Listenable>[saveListenable];
        if (ctrl != null) listenables.add(ctrl);
        return ListenableBuilder(
          listenable: Listenable.merge(listenables),
          builder: (context, _) {
            final scheme = Theme.of(context).colorScheme;
            final saveLabel = _saveStatusLabel(l10n, saveStatus);
            final cloudOn = ctrl != null && ctrl.isEnabled;

            String? syncSummary;
            if (cloudOn) {
              syncSummary = _syncSummaryLine(l10n, ctrl);
            }

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * 0.7,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          l10n.folioCloudUnifiedSheetTitle,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          l10n.folioCloudUnifiedLocalSaveSection,
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          saveLabel,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                        ),
                        if (cloudOn && syncSummary != null) ...[
                          const SizedBox(height: 16),
                          Text(
                            l10n.folioCloudDeviceSyncTitle,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            syncSummary,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                          ),
                          if (ctrl.transferProgress != null) ...[
                            const SizedBox(height: 12),
                            LinearProgressIndicator(
                              value: ctrl.transferProgress,
                            ),
                          ],
                          if (ctrl.lastError != null &&
                              ctrl.lastError!.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text(
                              ctrl.lastError!,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: scheme.error),
                              maxLines: 4,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          if (ctrl.vaultStatuses.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Text(
                              l10n.folioCloudDeviceSyncVaultsSection,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 8),
                            for (final v in ctrl.vaultStatuses)
                              _VaultSyncTile(
                                status: v,
                                l10n: l10n,
                                onOpen: (!v.wantsOpenAction ||
                                        onOpenVault == null)
                                    ? null
                                    : () async {
                                        Navigator.of(ctx).pop();
                                        await onOpenVault!(
                                          VaultEntry(
                                            id: v.vaultId,
                                            displayName: v.displayName,
                                            createdAtMs: 0,
                                          ),
                                        );
                                      },
                              ),
                          ],
                          if (pendingConflicts > 0) ...[
                            const SizedBox(height: 12),
                            Text(
                              l10n.folioCloudDeviceSyncConflictHint,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: ctrl.isSyncing
                                ? null
                                : () async {
                                    final nav = Navigator.of(ctx);
                                    final messenger =
                                        ScaffoldMessenger.maybeOf(context);
                                    nav.pop();
                                    final ok = await ctrl.syncNow();
                                    final msg = !ctrl.isEnabled
                                        ? l10n.folioCloudDeviceSyncNowDisabled
                                        : (ok
                                            ? l10n.folioCloudDeviceSyncNowOk
                                            : l10n.folioCloudDeviceSyncNowFail);
                                    messenger?.showSnackBar(
                                      SnackBar(content: Text(msg)),
                                    );
                                  },
                            icon: const Icon(Icons.sync),
                            label: Text(l10n.folioCloudDeviceSyncNow),
                          ),
                          if (pendingConflicts > 0 &&
                              onOpenConflicts != null) ...[
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              onPressed: () {
                                Navigator.of(ctx).pop();
                                onOpenConflicts!();
                              },
                              icon: const Icon(Icons.warning_amber_rounded),
                              label: Text(
                                l10n.folioCloudDeviceSyncOpenConflicts(
                                  pendingConflicts,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  static String _saveStatusLabel(AppLocalizations l10n, SaveStatus status) {
    return switch (status) {
      SaveStatus.pending => l10n.saveStatusPending,
      SaveStatus.saving => l10n.saveStatusSaving,
      SaveStatus.saved => l10n.saveStatusSaved,
      SaveStatus.error => l10n.saveStatusError,
      SaveStatus.idle => l10n.saveStatusIdle,
    };
  }

  static String _syncSummaryLine(
    AppLocalizations l10n,
    FolioCloudDeviceSyncController ctrl,
  ) {
    final status = ctrl.statusMessage;
    final allOk = ctrl.allVaultsSynced;
    if (status == 'pushing' || status == 'pulling' || ctrl.isSyncing) {
      var line = l10n.folioCloudDeviceSyncStatusSyncing;
      if (ctrl.blobsTotal > 0) {
        line = '$line (${ctrl.blobsCompleted}/${ctrl.blobsTotal})';
      }
      return line;
    }
    if (status == 'error') return l10n.folioCloudDeviceSyncStatusError;
    if (allOk) return l10n.folioCloudDeviceSyncAllVaultsOk;
    if (ctrl.vaultsNeedingAttention > 0) {
      return l10n.folioCloudDeviceSyncVaultsNeedAttention(
        ctrl.vaultsNeedingAttention,
      );
    }
    if (ctrl.lastSyncSuccessMs > 0) {
      return l10n.folioCloudDeviceSyncStatusSynced(
        _formatAgo(
          DateTime.now().millisecondsSinceEpoch - ctrl.lastSyncSuccessMs,
          l10n,
        ),
      );
    }
    return l10n.folioCloudDeviceSyncStatusPending;
  }

  static _UnifiedVisual _resolveVisual({
    required AppLocalizations l10n,
    required ColorScheme scheme,
    required SaveStatus save,
    required FolioCloudDeviceSyncController? cloud,
    required int pendingConflicts,
    required bool cloudEnabled,
  }) {
    final saveLabel = _saveStatusLabel(l10n, save);
    final syncing = cloudEnabled &&
        cloud != null &&
        (cloud.isSyncing ||
            cloud.statusMessage == 'pushing' ||
            cloud.statusMessage == 'pulling');
    final syncError =
        cloudEnabled && cloud != null && cloud.statusMessage == 'error';
    final needing =
        cloudEnabled && cloud != null ? cloud.vaultsNeedingAttention : 0;
    final allOk = cloudEnabled &&
        cloud != null &&
        cloud.allVaultsSynced &&
        pendingConflicts <= 0;

    String syncLabel = '';
    if (cloudEnabled && cloud != null) {
      syncLabel = _syncSummaryLine(l10n, cloud);
      if (pendingConflicts > 0) {
        syncLabel = l10n.folioCloudDeviceSyncConflictsTooltip(pendingConflicts);
      }
    }

    String tooltipFor(String primary, [String? secondary]) {
      if (secondary == null || secondary.isEmpty) return primary;
      if (primary == secondary) return primary;
      return l10n.folioCloudUnifiedTooltip(primary, secondary);
    }

    // Prioridad: errores → actividad → atención → ok.
    if (save == SaveStatus.error) {
      return _UnifiedVisual(
        icon: Icons.cloud_off_outlined,
        color: scheme.error,
        tooltip: tooltipFor(saveLabel, syncLabel),
        badge: true,
      );
    }
    if (syncError) {
      return _UnifiedVisual(
        icon: Icons.sync_problem_rounded,
        color: scheme.error,
        tooltip: tooltipFor(syncLabel, saveLabel),
        badge: true,
      );
    }
    if (save == SaveStatus.saving || syncing) {
      return _UnifiedVisual(
        icon: Icons.sync,
        color: scheme.primary,
        tooltip: tooltipFor(
          save == SaveStatus.saving ? saveLabel : syncLabel,
          save == SaveStatus.saving ? syncLabel : saveLabel,
        ),
        showSpinner: true,
      );
    }
    if (save == SaveStatus.pending) {
      return _UnifiedVisual(
        icon: Icons.cloud_upload_outlined,
        color: scheme.onSurfaceVariant,
        tooltip: tooltipFor(saveLabel, syncLabel),
      );
    }
    if (pendingConflicts > 0) {
      return _UnifiedVisual(
        icon: Icons.warning_amber_rounded,
        color: scheme.tertiary,
        tooltip: tooltipFor(syncLabel, saveLabel),
        badge: true,
      );
    }
    if (needing > 0) {
      return _UnifiedVisual(
        icon: Icons.cloud_sync_outlined,
        color: scheme.tertiary,
        tooltip: tooltipFor(syncLabel, saveLabel),
        badge: true,
      );
    }
    if (!cloudEnabled) {
      return _UnifiedVisual(
        icon: Icons.cloud_done_outlined,
        color: (save == SaveStatus.saved || save == SaveStatus.idle)
            ? scheme.primary
            : scheme.onSurfaceVariant,
        tooltip: saveLabel,
      );
    }
    if (allOk) {
      return _UnifiedVisual(
        icon: Icons.cloud_done_outlined,
        color: scheme.primary,
        tooltip: tooltipFor(l10n.folioCloudDeviceSyncAllVaultsOk, saveLabel),
      );
    }
    if (cloud!.lastSyncSuccessMs > 0) {
      return _UnifiedVisual(
        icon: Icons.cloud_done_outlined,
        color: scheme.onSurfaceVariant,
        tooltip: tooltipFor(syncLabel, saveLabel),
      );
    }
    return _UnifiedVisual(
      icon: Icons.cloud_queue_outlined,
      color: scheme.onSurfaceVariant,
      tooltip: tooltipFor(syncLabel, saveLabel),
    );
  }

  static String _formatAgo(int millisAgo, AppLocalizations l10n) {
    final seconds = (millisAgo / 1000).floor();
    if (seconds < 60) return l10n.folioCloudDeviceSyncAgoSeconds(seconds);
    final minutes = (seconds / 60).floor();
    if (minutes < 60) return l10n.folioCloudDeviceSyncAgoMinutes(minutes);
    final hours = (minutes / 60).floor();
    return l10n.folioCloudDeviceSyncAgoHours(hours);
  }
}

class _UnifiedVisual {
  const _UnifiedVisual({
    required this.icon,
    required this.color,
    required this.tooltip,
    this.badge = false,
    this.showSpinner = false,
  });

  final IconData icon;
  final Color color;
  final String tooltip;
  final bool badge;
  final bool showSpinner;
}

class _VaultSyncTile extends StatelessWidget {
  const _VaultSyncTile({
    required this.status,
    required this.l10n,
    this.onOpen,
  });

  final DeviceSyncVaultStatus status;
  final AppLocalizations l10n;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    late final IconData icon;
    late final Color color;
    late final String subtitle;
    switch (status.phase) {
      case DeviceSyncVaultPhase.syncing:
        icon = Icons.sync;
        color = scheme.primary;
        subtitle = l10n.folioCloudDeviceSyncStatusSyncing;
      case DeviceSyncVaultPhase.synced:
        icon = Icons.check_circle_outline;
        color = scheme.primary;
        subtitle = status.lastSuccessMs > 0
            ? l10n.folioCloudDeviceSyncStatusSynced(
                CloudDeviceSyncStatusButton._formatAgo(
                  DateTime.now().millisecondsSinceEpoch - status.lastSuccessMs,
                  l10n,
                ),
              )
            : l10n.folioCloudDeviceSyncVaultPhaseSynced;
      case DeviceSyncVaultPhase.needsUnlock:
        // Legado: ya no pedimos desbloqueo; tratamos como pendiente de sync.
        icon = Icons.hourglass_empty;
        color = scheme.onSurfaceVariant;
        subtitle = l10n.folioCloudDeviceSyncStatusPending;
      case DeviceSyncVaultPhase.emptyCloud:
        icon = Icons.cloud_off_outlined;
        color = scheme.onSurfaceVariant;
        subtitle = l10n.folioCloudDeviceSyncVaultPhaseEmpty;
      case DeviceSyncVaultPhase.error:
        icon = Icons.error_outline;
        color = scheme.error;
        subtitle = status.detail?.trim().isNotEmpty == true
            ? status.detail!.trim()
            : l10n.folioCloudDeviceSyncStatusError;
      case DeviceSyncVaultPhase.pending:
        icon = Icons.hourglass_empty;
        color = scheme.onSurfaceVariant;
        subtitle = l10n.folioCloudDeviceSyncStatusPending;
    }

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: color),
      title: Text(
        status.isActive
            ? '${status.displayName} (${l10n.folioCloudDeviceSyncVaultActive})'
            : status.displayName,
      ),
      subtitle: Text(subtitle),
      trailing: onOpen == null
          ? null
          : TextButton(
              onPressed: onOpen,
              child: Text(l10n.folioCloudDeviceSyncOpenVault),
            ),
    );
  }
}

/// Banner compacto cuando la página abierta tiene revisiones `sync_remote_*`
/// o conflictos de sync pendientes de esa página.
class SyncRemoteRevisionBanner extends StatelessWidget {
  const SyncRemoteRevisionBanner({
    super.key,
    required this.remoteRevisionCount,
    required this.onOpenHistory,
    required this.onDismiss,
    this.pageConflictCount = 0,
    this.onReviewConflicts,
  });

  final int remoteRevisionCount;
  final int pageConflictCount;
  final VoidCallback onOpenHistory;
  final VoidCallback? onReviewConflicts;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    if (remoteRevisionCount <= 0 && pageConflictCount <= 0) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Icon(Icons.merge_type_rounded, color: scheme.onSecondaryContainer),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                pageConflictCount > 0
                    ? l10n.folioCloudDeviceSyncConflictsTooltip(
                        pageConflictCount,
                      )
                    : l10n.folioCloudDeviceSyncRemoteRevisionBanner(
                        remoteRevisionCount,
                      ),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSecondaryContainer,
                    ),
              ),
            ),
            if (onReviewConflicts != null)
              TextButton(
                onPressed: onReviewConflicts,
                child: Text(l10n.syncConflictMergeReviewConflicts),
              ),
            if (remoteRevisionCount > 0)
              TextButton(
                onPressed: onOpenHistory,
                child: Text(l10n.folioCloudDeviceSyncViewHistory),
              ),
            IconButton(
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              onPressed: onDismiss,
              icon: const Icon(Icons.close, size: 18),
            ),
          ],
        ),
      ),
    );
  }
}

