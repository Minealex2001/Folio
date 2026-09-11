import 'package:flutter/material.dart';

import '../../config/models/widget_instance_config.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../services/folio_cloud/folio_cloud_identity.dart';
import '../folio_widget_plugin.dart';
import '../widget_plugin_context.dart';
import 'builtin_widget_card.dart';

/// Folio Cloud — tinta, plan y almacenamiento de backup (mismos controllers
/// que la tarjeta rápida del home legacy).
class FolioCloudWidgetPlugin extends FolioWidgetPlugin {
  const FolioCloudWidgetPlugin();

  @override
  String get id => 'folio_cloud';

  @override
  String displayName(BuildContext context) => 'Folio Cloud';

  @override
  IconData get icon => Icons.cloud_outlined;

  @override
  bool get allowMultipleInstances => false;

  @override
  double get defaultHeight => 180;

  @override
  Widget build(
    BuildContext context,
    WidgetInstanceConfig instance,
    WidgetPluginContext ctx,
  ) {
    return BuiltinWidgetCard(
      icon: icon,
      title: displayName(context),
      trailing: ctx.onOpenSettings == null
          ? null
          : TextButton(
              onPressed: ctx.onOpenSettings,
              child: Text(AppLocalizations.of(context).workspaceHomeCloudOpenSettings),
            ),
      child: _FolioCloudBody(ctx: ctx),
    );
  }
}

class _FolioCloudBody extends StatelessWidget {
  const _FolioCloudBody({required this.ctx});

  final WidgetPluginContext ctx;

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(kb >= 100 ? 0 : 1)} KB';
    final mb = kb / 1024;
    if (mb < 1024) return '${mb.toStringAsFixed(mb >= 100 ? 0 : 1)} MB';
    final gb = mb / 1024;
    return '${gb.toStringAsFixed(gb >= 100 ? 1 : 2)} GB';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final account = ctx.cloudAccount;
    final entitlements = ctx.folioCloudEntitlements;

    if (account == null || entitlements == null) {
      return BuiltinWidgetEmpty(
        message: l10n.widgetFolioCloudUnavailable,
      );
    }

    return ListenableBuilder(
      listenable: Listenable.merge([account, entitlements]),
      builder: (context, _) {
        final signedIn = folioCloudHasSession() && account.isSignedIn;
        if (!signedIn) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                l10n.folioCloudPitchGuestTeaserBody,
                style: textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              if (ctx.onOpenFolioCloudPitch != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.tonalIcon(
                    onPressed: ctx.onOpenFolioCloudPitch,
                    icon: const Icon(Icons.cloud_outlined, size: 18),
                    label: Text(l10n.workspaceHomeCloudGuestTeaserCta),
                  ),
                )
              else if (ctx.onOpenSettings != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.tonalIcon(
                    onPressed: ctx.onOpenSettings,
                    icon: const Icon(Icons.settings_outlined, size: 18),
                    label: Text(l10n.workspaceHomeCloudOpenSettings),
                  ),
                ),
            ],
          );
        }

        final snap = entitlements.snapshot;
        final ink = snap.ink;
        final unlimited = snap.folioStaff;
        final quota = snap.backupQuotaBytes;
        final usedBytes = snap.backupUsedBytes;
        final showBackupBar =
            snap.canUseCloudBackup && (unlimited || quota > 0);
        final remainingBytes = !unlimited && showBackupBar
            ? (quota - usedBytes).clamp(0, quota)
            : 0;
        final pct = !unlimited && showBackupBar
            ? ((usedBytes / quota) * 100).round().clamp(0, 100)
            : null;
        final identity = (account.displayName ?? account.email ?? '').trim();
        final planLabel = unlimited
            ? l10n.workspaceHomeCloudStaffShort
            : (snap.plan?.trim().isNotEmpty == true
                ? snap.plan!
                : (snap.active ? 'Cloud' : l10n.planFree));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (identity.isNotEmpty)
              Text(
                identity,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            Text(
              planLabel,
              style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.water_drop_outlined, color: scheme.tertiary, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    unlimited
                        ? '∞'
                        : l10n.folioCloudInkCount(ink.totalInk),
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  l10n.folioCloudInkTotal,
                  style: textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            if (showBackupBar) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: unlimited ? 0 : usedBytes / quota,
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                unlimited
                    ? '∞'
                    : l10n.folioCloudBackupStorageBarDetail(
                        _formatBytes(usedBytes),
                        _formatBytes(quota),
                        _formatBytes(remainingBytes),
                      ),
                style: textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (pct != null)
                Text(
                  l10n.folioCloudBackupStorageBarPercent(pct),
                  style: textTheme.labelSmall?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ],
        );
      },
    );
  }
}
