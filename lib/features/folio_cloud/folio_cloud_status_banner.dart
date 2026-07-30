import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/folio_status_urls.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../services/folio_cloud/folio_cloud_status.dart';
import '../../services/folio_cloud/folio_cloud_status_controller.dart';

/// Banner de alerta cuando Folio Cloud est├í degradado o hay incidencias.
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
        return _BannerBody(
          snapshot: snap,
          onOpenDetails: onOpenDetails,
          onDismiss: () => controller.dismissBanner(),
        );
      },
    );
  }
}

class _BannerBody extends StatelessWidget {
  const _BannerBody({
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
    final scheme = Theme.of(context).colorScheme;
    final incident = snapshot.primaryIncident;
    final isDown = snapshot.status == 'down';
    final bg = isDown ? scheme.errorContainer : scheme.tertiaryContainer;
    final fg = isDown ? scheme.onErrorContainer : scheme.onTertiaryContainer;
    final icon = incident?.type == 'maintenance'
        ? Icons.build_circle_outlined
        : (isDown ? Icons.cloud_off_outlined : Icons.cloud_queue_outlined);

    final title = incident != null && incident.title.isNotEmpty
        ? incident.title
        : (isDown
            ? l10n.folioCloudStatusBannerDown
            : l10n.folioCloudStatusBannerDegraded);

    final subtitle = incident != null
        ? l10n.folioCloudStatusBannerIncidentHint(
            incident.type == 'maintenance'
                ? l10n.folioCloudStatusTypeMaintenance
                : l10n.folioCloudStatusTypeIncident,
          )
        : l10n.folioCloudStatusBannerGenericHint;

    return Material(
      color: bg,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: fg),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: fg,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: fg.withValues(alpha: 0.9),
                        ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      TextButton(
                        onPressed: onOpenDetails,
                        style: TextButton.styleFrom(
                          foregroundColor: fg,
                          visualDensity: VisualDensity.compact,
                        ),
                        child: Text(l10n.folioCloudStatusBannerDetails),
                      ),
                      TextButton(
                        onPressed: () async {
                          final lang =
                              Localizations.localeOf(context).languageCode;
                          final uri = FolioStatusUrls.statusPageUri(
                            languageCode: lang,
                          );
                          await launchUrl(
                            uri,
                            mode: LaunchMode.externalApplication,
                          );
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: fg,
                          visualDensity: VisualDensity.compact,
                        ),
                        child: Text(l10n.folioCloudStatusBannerMoreInfo),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: l10n.folioCloudStatusBannerDismiss,
              onPressed: onDismiss,
              icon: Icon(Icons.close, size: 18, color: fg),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }
}
