import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../services/folio_cloud/folio_cloud_entitlements.dart';

/// Dashboard de telemetría staff — deshabilitado tras cutover Spring (Fase 28/30).
/// Ya no hay pipeline Firestore `telemetryGlobalStats` / `analytics_events`.
class TelemetryDashboardPage extends StatelessWidget {
  const TelemetryDashboardPage({super.key, required this.folioCloudSnapshot});

  final FolioCloudSnapshot folioCloudSnapshot;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.telemetryDashboardTitle)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            l10n.telemetryDashboardUnavailableSpring,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
