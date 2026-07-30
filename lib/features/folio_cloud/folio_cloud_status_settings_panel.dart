import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/folio_status_urls.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../services/folio_cloud/folio_cloud_status.dart';
import '../../services/folio_cloud/folio_cloud_status_colors.dart';
import '../../services/folio_cloud/folio_cloud_status_controller.dart';

/// Panel de estado Folio Cloud en Ajustes (servicios, incidencias, historial).
class FolioCloudStatusSettingsPanel extends StatelessWidget {
  const FolioCloudStatusSettingsPanel({
    super.key,
    required this.controller,
    required this.scheme,
    required this.l10n,
    this.showSectionTitle = true,
  });

  final FolioCloudStatusController controller;
  final ColorScheme scheme;
  final AppLocalizations l10n;

  /// Si la pestaña ya se llama «Estado», ocultar el título duplicado.
  final bool showSectionTitle;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final snap = controller.snapshot;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(16, showSectionTitle ? 14 : 8, 8, 0),
              child: Row(
                children: [
                  if (showSectionTitle)
                    Expanded(
                      child: Text(
                        l10n.folioCloudStatusSubsectionTitle,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    )
                  else
                    const Spacer(),
                  if (controller.loading)
                    const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  IconButton(
                    tooltip: l10n.folioCloudStatusRefresh,
                    onPressed: controller.loading
                        ? null
                        : () => controller.refresh(),
                    icon: const Icon(Icons.refresh, size: 20),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
            if (controller.lastError != null && snap == null)
              ListTile(
                leading: Icon(Icons.cloud_off_outlined, color: scheme.error),
                title: Text(l10n.folioCloudStatusLoadError),
                subtitle: Text(l10n.folioCloudStatusLoadErrorHint),
                isThreeLine: true,
              )
            else if (snap != null) ...[
              ListTile(
                dense: true,
                leading: Icon(
                  _aggregateIcon(snap.uiSeverity),
                  color: FolioCloudStatusColors.foreground(snap.uiSeverity),
                ),
                title: Text(_aggregateLabel(l10n, snap.uiSeverity)),
                subtitle: snap.checkedAt != null
                    ? Text(
                        l10n.folioCloudStatusCheckedAt(
                          _formatCheckedAt(context, snap.checkedAt!),
                        ),
                      )
                    : null,
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: _serviceSquaresGrid(context, snap),
              ),
              if (snap.incidents.isNotEmpty) ...[
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text(
                    l10n.folioCloudStatusIncidentsTitle,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
                ...snap.incidents.take(8).map(
                      (i) => _IncidentTile(
                        incident: i,
                        l10n: l10n,
                        scheme: scheme,
                      ),
                    ),
              ],
              if (snap.history.isNotEmpty) ...[
                const Divider(height: 1),
                Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    initiallyExpanded: false,
                    title: Text(l10n.folioCloudStatusHistoryCollapsed),
                    children: [
                      ..._historyTiles(context, snap, limit: 4),
                      ListTile(
                        dense: true,
                        leading: const Icon(Icons.open_in_new, size: 20),
                        title: Text(l10n.folioCloudStatusOpenWebMore),
                        onTap: () async {
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
                      ),
                    ],
                  ),
                ),
              ],
            ] else if (controller.loading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              ListTile(
                leading: const Icon(Icons.cloud_outlined),
                title: Text(l10n.folioCloudStatusEmpty),
                subtitle: Text(l10n.folioCloudStatusEmptyHint),
              ),
            ListTile(
              leading: const Icon(Icons.open_in_new),
              title: Text(l10n.folioCloudStatusOpenWeb),
              onTap: () async {
                final lang = Localizations.localeOf(context).languageCode;
                final uri = FolioStatusUrls.statusPageUri(languageCode: lang);
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              },
            ),
          ],
        );
      },
    );
  }

  Widget _serviceSquaresGrid(
    BuildContext context,
    FolioCloudStatusSnapshot snap,
  ) {
    final ids = folioCloudStatusVisibleServiceIds(snap);
    if (ids.isEmpty) return const SizedBox.shrink();
    const gap = 8.0;
    const tileSize = 104.0;
    return Wrap(
      spacing: gap,
      runSpacing: gap,
      children: [
        for (final id in ids)
          SizedBox(
            width: tileSize,
            height: tileSize,
            child: _ServiceStatusSquare(
              icon: _serviceIcon(id),
              logoAsset: _serviceLogoAsset(id),
              label: _serviceLabel(l10n, id),
              status: snap.displayStatusFor(id),
              statusLabel: _serviceStatusLabel(
                l10n,
                snap.displayStatusFor(id),
              ),
              latencyMs: snap.services[id]?.latencyMs,
              tooltip: _serviceSubtitle(l10n, snap, id),
              l10n: l10n,
              scheme: scheme,
            ),
          ),
      ],
    );
  }

  List<Widget> _historyTiles(
    BuildContext context,
    FolioCloudStatusSnapshot snap, {
    int limit = 8,
  }) {
    final rows = snap.history.reversed.take(limit).toList();
    return [
      for (final h in rows)
        ListTile(
          dense: true,
          title: Text(
            '${_serviceLabel(l10n, h.serviceId)} · ${h.logDate}',
          ),
          subtitle: Text(
            l10n.folioCloudStatusHistoryLine(
              h.uptimePercentage.toStringAsFixed(2),
              h.successfulChecks,
              h.totalChecks,
            ),
          ),
          trailing: h.avgLatencyMs != null
              ? Text(
                  l10n.folioCloudStatusLatencyMs(h.avgLatencyMs!.round()),
                  style: Theme.of(context).textTheme.bodySmall,
                )
              : null,
        ),
    ];
  }

  static String _serviceSubtitle(
    AppLocalizations l10n,
    FolioCloudStatusSnapshot snap,
    String id,
  ) {
    final statusLabel = _serviceStatusLabel(l10n, snap.displayStatusFor(id));
    final incident = snap.activeIncidentFor(id);
    final parts = <String>[statusLabel];
    final reason = snap.statusReasonFor(id);
    if (reason == 'incident') {
      parts.add(l10n.folioCloudStatusTypeIncident);
    } else if (reason == 'maintenance') {
      parts.add(l10n.folioCloudStatusTypeMaintenance);
    } else if (reason != null &&
        reason.isNotEmpty &&
        reason != 'normal' &&
        reason != 'high_latency') {
      parts.add(reason);
    } else if (reason == 'high_latency') {
      parts.add(statusLabel);
    }
    final title = incident?.title.trim();
    if (title != null && title.isNotEmpty) {
      parts.add(title);
    }
    return parts.join(' · ');
  }

  static IconData _aggregateIcon(String status) {
    return switch (status) {
      'ok' => Icons.check_circle_outline,
      'degraded' => Icons.warning_amber_outlined,
      'partial' => Icons.cloud_queue_outlined,
      _ => Icons.error_outline,
    };
  }

  static String _aggregateLabel(AppLocalizations l10n, String status) {
    return switch (status) {
      'ok' => l10n.folioCloudStatusAggregateOk,
      'degraded' => l10n.folioCloudStatusAggregateDegraded,
      'partial' => l10n.folioCloudStatusAggregatePartial,
      'down' => l10n.folioCloudStatusAggregateDown,
      _ => status,
    };
  }

  static String? _serviceLogoAsset(String id) {
    return switch (id) {
      'jira' => 'appLogos/jira.png',
      'slack' => 'appLogos/slack.png',
      'teams' => 'appLogos/microsoftTeams.png',
      'spotify' => 'appLogos/spotify.png',
      _ => null,
    };
  }

  static IconData _serviceIcon(String id) {
    return switch (id) {
      'api' => Icons.dns_outlined,
      'database' => Icons.storage_outlined,
      'bucket' => Icons.cloud_outlined,
      'quill' => Icons.auto_awesome_outlined,
      'stripe' => Icons.payments_outlined,
      'resend' => Icons.mail_outline,
      'jira' => Icons.bug_report_outlined,
      'slack' => Icons.tag_outlined,
      'teams' => Icons.groups_outlined,
      'spotify' => Icons.music_note_outlined,
      'microsoft_store' => Icons.shop_outlined,
      'community_templates' => Icons.style_outlined,
      'collab' => Icons.groups_2_outlined,
      'vault_share' => Icons.share_outlined,
      'device_sync' => Icons.sync_outlined,
      'integrations' => Icons.extension_outlined,
      _ => Icons.circle_outlined,
    };
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
      'community_templates' => l10n.folioCloudStatusServiceCommunityTemplates,
      'collab' => l10n.folioCloudStatusServiceCollab,
      'vault_share' => l10n.folioCloudStatusServiceVaultShare,
      'device_sync' => l10n.folioCloudStatusServiceDeviceSync,
      'integrations' => l10n.folioCloudStatusServiceIntegrations,
      _ => id,
    };
  }

  static String _serviceStatusLabel(AppLocalizations l10n, String status) {
    return switch (status) {
      'ok' => l10n.folioCloudStatusServiceOk,
      'degraded' => l10n.folioCloudStatusServiceDegraded,
      'partial' => l10n.folioCloudStatusServicePartial,
      'down' => l10n.folioCloudStatusServiceDown,
      'unconfigured' => l10n.folioCloudStatusServiceUnconfigured,
      _ => status,
    };
  }

  static String _formatCheckedAt(BuildContext context, DateTime utc) {
    final local = utc.toLocal();
    final loc = MaterialLocalizations.of(context);
    final date = loc.formatShortDate(local);
    final time = loc.formatTimeOfDay(TimeOfDay.fromDateTime(local));
    return '$date $time';
  }
}

class _ServiceStatusSquare extends StatelessWidget {
  const _ServiceStatusSquare({
    required this.icon,
    required this.label,
    required this.status,
    required this.statusLabel,
    required this.l10n,
    required this.scheme,
    this.logoAsset,
    this.latencyMs,
    this.tooltip,
  });

  final IconData icon;
  final String? logoAsset;
  final String label;
  final String status;
  final String statusLabel;
  final AppLocalizations l10n;
  final ColorScheme scheme;
  final int? latencyMs;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final color = FolioCloudStatusColors.foreground(status);
    final tile = Material(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: logoAsset != null
                    ? SizedBox(
                        width: 22,
                        height: 22,
                        child: Image.asset(
                          logoAsset!,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.medium,
                        ),
                      )
                    : Icon(icon, size: 20, color: color),
              ),
              const Spacer(),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                      fontSize: 11.5,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                statusLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              if (latencyMs != null)
                Text(
                  l10n.folioCloudStatusLatencyMs(latencyMs!),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontSize: 10,
                      ),
                ),
            ],
          ),
        ),
      ),
    );
    if (tooltip == null || tooltip!.isEmpty) return tile;
    return Tooltip(message: tooltip!, child: tile);
  }
}

class _IncidentTile extends StatelessWidget {
  const _IncidentTile({
    required this.incident,
    required this.l10n,
    required this.scheme,
  });

  final FolioCloudIncident incident;
  final AppLocalizations l10n;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final typeLabel = incident.type == 'maintenance'
        ? l10n.folioCloudStatusTypeMaintenance
        : l10n.folioCloudStatusTypeIncident;
    final latest = incident.updates.isNotEmpty ? incident.updates.last : null;
    return ExpansionTile(
      leading: Icon(
        incident.type == 'maintenance'
            ? Icons.build_outlined
            : Icons.report_problem_outlined,
        color: incident.isActive
            ? FolioCloudStatusColors.foreground(
                statusFromIncidentImpact(incident.impact) ?? 'degraded',
              )
            : scheme.outline,
      ),
      title: Text(incident.title.isEmpty ? typeLabel : incident.title),
      subtitle: Text(
        [
          typeLabel,
          _incidentStatusLabel(l10n, incident.status),
          if (incident.impact.isNotEmpty)
            _impactLabel(l10n, incident.impact),
        ].join(' · '),
      ),
      children: [
        if (latest != null && latest.message.isNotEmpty)
          ListTile(
            dense: true,
            title: Text(latest.message),
            subtitle: Text(_incidentStatusLabel(l10n, latest.status)),
          ),
        if (incident.affectedServices.isNotEmpty)
          ListTile(
            dense: true,
            title: Text(
              l10n.folioCloudStatusAffectedServices(
                incident.affectedServices.join(', '),
              ),
            ),
          ),
      ],
    );
  }

  static String _impactLabel(AppLocalizations l10n, String impact) {
    return switch (impact.trim().toLowerCase()) {
      'major_outage' || 'down' || 'outage' || 'full_outage' =>
        l10n.folioCloudStatusImpactMajorOutage,
      'partial_outage' || 'minor_outage' =>
        l10n.folioCloudStatusImpactPartialOutage,
      'degraded' => l10n.folioCloudStatusImpactDegraded,
      _ => l10n.folioCloudStatusImpactDegraded,
    };
  }

  static String _incidentStatusLabel(AppLocalizations l10n, String status) {
    return switch (status) {
      'investigating' => l10n.folioCloudStatusIncidentInvestigating,
      'identified' => l10n.folioCloudStatusIncidentIdentified,
      'monitoring' => l10n.folioCloudStatusIncidentMonitoring,
      'resolved' => l10n.folioCloudStatusIncidentResolved,
      'scheduled' => l10n.folioCloudStatusIncidentScheduled,
      'in_progress' => l10n.folioCloudStatusIncidentInProgress,
      _ => status,
    };
  }
}
