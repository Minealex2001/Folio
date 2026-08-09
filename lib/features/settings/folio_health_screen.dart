import 'package:flutter/material.dart';

import '../../app/app_settings.dart';
import '../../data/vault_paths.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../services/folio_cloud/folio_cloud_device_sync.dart';
import '../../services/folio_cloud/folio_cloud_entitlements.dart';
import '../../session/vault_session.dart';

String _fmtHealthBytes(int b) {
  if (b < 1024) return '$b B';
  final kb = b / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(kb >= 100 ? 0 : 1)} KB';
  final mb = kb / 1024;
  if (mb < 1024) return '${mb.toStringAsFixed(mb >= 100 ? 0 : 1)} MB';
  final gb = mb / 1024;
  return '${gb.toStringAsFixed(gb >= 100 ? 1 : 2)} GB';
}

/// Fase 3 del roadmap de producto (idea #6, "Folio Health") — pantalla que
/// agrega en un solo sitio señales de salud que hoy viven dispersas en
/// varias sub-pantallas de Settings: estado de sincronización de
/// dispositivo (`FolioCloudDeviceSyncController`, ya usado en
/// `settings_page_folio_cloud.dart`), cuota de backup/almacenamiento
/// (`FolioCloudEntitlementsController.snapshot`, idem), y uso de disco +
/// cifrado de la libreta activa (`VaultPaths`, ya usado en
/// `settings_page_state_backup_security.dart`). No introduce ninguna fuente
/// de datos nueva — es una vista de solo lectura sobre controllers/servicios
/// que ya existen y ya se observan en otro sitio, con las mismas acciones
/// (sincronizar ahora, resolver conflictos) reenviadas por callback en vez
/// de reimplementadas.
class FolioHealthScreen extends StatefulWidget {
  const FolioHealthScreen({
    super.key,
    required this.session,
    required this.appSettings,
    required this.folioCloudEntitlements,
    this.cloudDeviceSyncController,
    this.onResolveSyncConflicts,
  });

  final VaultSession session;
  final AppSettings appSettings;
  final FolioCloudEntitlementsController folioCloudEntitlements;
  final FolioCloudDeviceSyncController? cloudDeviceSyncController;
  final VoidCallback? onResolveSyncConflicts;

  @override
  State<FolioHealthScreen> createState() => _FolioHealthScreenState();
}

class _FolioHealthScreenState extends State<FolioHealthScreen> {
  late Future<int> _vaultDiskUsageFuture;

  @override
  void initState() {
    super.initState();
    _vaultDiskUsageFuture = _loadVaultDiskUsageBytes();
  }

  Future<int> _loadVaultDiskUsageBytes() async {
    final dir = await VaultPaths.vaultDirectory();
    return VaultPaths.directoryTotalFileBytes(dir);
  }

  String _formatSyncAgo(int millisAgo, AppLocalizations l10n) {
    final seconds = (millisAgo / 1000).floor();
    if (seconds < 60) return l10n.folioCloudDeviceSyncAgoSeconds(seconds);
    final minutes = (seconds / 60).floor();
    if (minutes < 60) return l10n.folioCloudDeviceSyncAgoMinutes(minutes);
    final hours = (minutes / 60).floor();
    return l10n.folioCloudDeviceSyncAgoHours(hours);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.folioHealthTitle)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListenableBuilder(
            listenable: Listenable.merge([
              widget.appSettings,
              widget.folioCloudEntitlements,
              if (widget.cloudDeviceSyncController != null)
                widget.cloudDeviceSyncController!,
            ]),
            builder: (context, _) {
              final conflicts = widget.appSettings.syncPendingConflicts;
              final syncCtrl = widget.cloudDeviceSyncController;
              final syncError = syncCtrl?.statusMessage == 'error';
              final hasIssue = conflicts > 0 || syncError;

              return ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                children: [
                  _HealthSummaryBanner(healthy: !hasIssue, l10n: l10n),
                  const SizedBox(height: 20),
                  _HealthSectionCard(
                    icon: Icons.sync_rounded,
                    title: l10n.folioHealthSyncSectionTitle,
                    child: _buildSyncSection(context, l10n, scheme, conflicts),
                  ),
                  const SizedBox(height: 16),
                  _HealthSectionCard(
                    icon: Icons.cloud_outlined,
                    title: l10n.folioHealthBackupSectionTitle,
                    child: _buildBackupSection(context, l10n, scheme, textTheme),
                  ),
                  const SizedBox(height: 16),
                  _HealthSectionCard(
                    icon: Icons.folder_outlined,
                    title: l10n.folioHealthVaultSectionTitle,
                    child: _buildVaultSection(context, l10n, scheme),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSyncSection(
    BuildContext context,
    AppLocalizations l10n,
    ColorScheme scheme,
    int conflicts,
  ) {
    final ctrl = widget.cloudDeviceSyncController;
    if (ctrl == null) {
      return Text(
        l10n.folioHealthSyncDisabled,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      );
    }
    final status = ctrl.statusMessage;
    late final String text;
    late final IconData icon;
    Color? color;
    if (status == 'pushing' || status == 'pulling') {
      text = l10n.folioCloudDeviceSyncStatusSyncing;
      icon = Icons.sync;
    } else if (status == 'error') {
      text = l10n.folioCloudDeviceSyncStatusError;
      icon = Icons.error_outline;
      color = scheme.error;
    } else if (ctrl.lastSyncSuccessMs > 0) {
      final ago = DateTime.now().millisecondsSinceEpoch - ctrl.lastSyncSuccessMs;
      text = l10n.folioCloudDeviceSyncStatusSynced(_formatSyncAgo(ago, l10n));
      icon = Icons.check_circle_outline;
    } else {
      text = l10n.folioCloudDeviceSyncStatusPending;
      icon = Icons.hourglass_empty;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: color ?? scheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: color ?? scheme.onSurfaceVariant,
                ),
              ),
            ),
            TextButton(
              onPressed: ctrl.isSyncing ? null : () => ctrl.syncNow(),
              child: Text(l10n.folioCloudDeviceSyncNow),
            ),
          ],
        ),
        if (ctrl.transferProgress != null) ...[
          const SizedBox(height: 8),
          LinearProgressIndicator(value: ctrl.transferProgress),
        ],
        if (conflicts > 0) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, size: 18, color: scheme.error),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.folioHealthPendingConflicts(conflicts),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.error,
                  ),
                ),
              ),
              if (widget.onResolveSyncConflicts != null)
                TextButton(
                  onPressed: widget.onResolveSyncConflicts,
                  child: Text(l10n.folioHealthResolveConflicts),
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildBackupSection(
    BuildContext context,
    AppLocalizations l10n,
    ColorScheme scheme,
    TextTheme textTheme,
  ) {
    final snap = widget.folioCloudEntitlements.snapshot;
    final unlimited = snap.folioStaff;
    final quota = snap.backupQuotaBytes;
    final used = snap.backupUsedBytes;
    final determinate = !unlimited && quota > 0;
    final pct = determinate ? ((used / quota) * 100).round().clamp(0, 100) : null;

    if (!unlimited && quota <= 0 && used <= 0) {
      return Text(
        l10n.folioHealthBackupUnavailable,
        style: textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: unlimited ? 0 : (determinate ? (used / quota).clamp(0.0, 1.0) : null),
            minHeight: 10,
            backgroundColor: scheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(
              pct != null && pct >= 90 ? scheme.error : scheme.primary,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          unlimited
              ? l10n.folioHealthBackupUnlimited(_fmtHealthBytes(used))
              : l10n.folioHealthBackupUsage(
                  _fmtHealthBytes(used),
                  _fmtHealthBytes(quota),
                ),
          style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _buildVaultSection(
    BuildContext context,
    AppLocalizations l10n,
    ColorScheme scheme,
  ) {
    final encrypted = widget.session.vaultUsesEncryption;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(
              encrypted ? Icons.lock_outline_rounded : Icons.lock_open_rounded,
              size: 18,
              color: encrypted ? scheme.primary : scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Text(
              encrypted
                  ? l10n.folioHealthVaultEncrypted
                  : l10n.folioHealthVaultNotEncrypted,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
        const SizedBox(height: 12),
        FutureBuilder<int>(
          future: _vaultDiskUsageFuture,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              );
            }
            return Row(
              children: [
                Icon(Icons.storage_rounded, size: 18, color: scheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Text(
                  l10n.folioHealthVaultDiskUsage(_fmtHealthBytes(snapshot.data!)),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _HealthSummaryBanner extends StatelessWidget {
  const _HealthSummaryBanner({required this.healthy, required this.l10n});

  final bool healthy;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = healthy ? scheme.primary : scheme.error;
    final bg = healthy
        ? scheme.primaryContainer.withValues(alpha: 0.35)
        : scheme.errorContainer.withValues(alpha: 0.35);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(
            healthy ? Icons.check_circle_outline_rounded : Icons.error_outline_rounded,
            color: color,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              healthy ? l10n.folioHealthAllGood : l10n.folioHealthNeedsAttention,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _HealthSectionCard extends StatelessWidget {
  const _HealthSectionCard({
    required this.icon,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: scheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
