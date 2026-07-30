import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/ui_tokens.dart';
import '../../config/folio_status_urls.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../services/folio_cloud/folio_cloud_status.dart';
import '../../services/folio_cloud/folio_cloud_status_colors.dart';
import '../../services/folio_cloud/folio_cloud_status_controller.dart';

/// Aviso de estado Folio Cloud pensado para el sidebar (no ocupa el workspace).
class FolioCloudStatusBanner extends StatelessWidget {
  const FolioCloudStatusBanner({
    super.key,
    required this.controller,
    required this.onOpenDetails,
  });

  final FolioCloudStatusController controller;
  final VoidCallback onOpenDetails;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (!controller.bannerVisible) return const SizedBox.shrink();
        final snap = controller.snapshot;
        if (snap == null) return const SizedBox.shrink();
        return _SidebarBannerBody(
          snapshot: snap,
          onOpenDetails: onOpenDetails,
          onDismiss: () => controller.dismissBanner(),
        );
      },
    );
  }
}

class _SidebarBannerBody extends StatelessWidget {
  const _SidebarBannerBody({
    required this.snapshot,
    required this.onOpenDetails,
    required this.onDismiss,
  });

  final FolioCloudStatusSnapshot snapshot;
  final VoidCallback onOpenDetails;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final brightness = Theme.of(context).brightness;
    final incident = snapshot.primaryIncident;
    final affectedIds = snapshot.bannerAffectedServiceIds;
    final severity = snapshot.bannerSeverity;
    final bg = FolioCloudStatusColors.container(severity, brightness: brightness);
    final fg = FolioCloudStatusColors.onContainer(severity, brightness: brightness);

    final title = incident != null && incident.title.isNotEmpty
        ? incident.title
        : switch (severity) {
            'down' => l10n.folioCloudStatusBannerDown,
            'partial' => l10n.folioCloudStatusBannerPartial,
            _ => l10n.folioCloudStatusBannerDegraded,
          };

    final hint = incident != null
        ? l10n.folioCloudStatusBannerIncidentHint(
            incident.type == 'maintenance'
                ? l10n.folioCloudStatusTypeMaintenance
                : l10n.folioCloudStatusTypeIncident,
          )
        : l10n.folioCloudStatusBannerGenericHint;
    final affected = affectedIds.isEmpty
        ? null
        : l10n.folioCloudStatusAffectedServices(
            affectedIds.map((id) => _serviceLabel(l10n, id)).join(', '),
          );

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(FolioRadius.md),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 4, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(
                    switch (severity) {
                      'down' => Icons.cloud_off_outlined,
                      'partial' => Icons.cloud_queue_outlined,
                      _ => Icons.warning_amber_outlined,
                    },
                    size: 16,
                    color: fg,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: fg,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hint,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: fg.withValues(alpha: 0.9),
                            ),
                      ),
                      if (affected != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          affected,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: fg,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  tooltip: l10n.folioCloudStatusBannerDismiss,
                  onPressed: onDismiss,
                  icon: Icon(Icons.close, size: 16, color: fg),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 0,
                children: [
                  TextButton(
                    onPressed: onOpenDetails,
                    style: TextButton.styleFrom(
                      foregroundColor: fg,
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      minimumSize: const Size(0, 28),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(l10n.folioCloudStatusBannerDetails),
                  ),
                  TextButton(
                    onPressed: () async {
                      final lang = Localizations.localeOf(context).languageCode;
                      final uri =
                          FolioStatusUrls.statusPageUri(languageCode: lang);
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: fg,
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      minimumSize: const Size(0, 28),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(l10n.folioCloudStatusBannerMoreInfo),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _serviceLabel(AppLocalizations l10n, String id) {
    return switch (id) {
      'api' => l10n.folioCloudStatusServiceApi,
      'database' => l10n.folioCloudStatusServiceDatabase,
      'bucket' => l10n.folioCloudStatusServiceBucket,
      'quill' => l10n.folioCloudStatusServiceQuill,
      'stripe' => l10n.folioCloudStatusServiceStripe,
      'resend' => l10n.folioCloudStatusServiceResend,
      'jira' => l10n.folioCloudStatusServiceJira,
      'slack' => l10n.folioCloudStatusServiceSlack,
      'teams' => l10n.folioCloudStatusServiceTeams,
      'spotify' => l10n.folioCloudStatusServiceSpotify,
      'microsoft_store' => l10n.folioCloudStatusServiceMicrosoftStore,
      _ => id,
    };
  }
}
