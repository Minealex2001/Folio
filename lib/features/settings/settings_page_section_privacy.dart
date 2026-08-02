part of 'settings_page.dart';

extension _SettingsPagePrivacySection on _SettingsPageState {
  List<Widget> _buildPrivacyDiagnosticsChildren({
    required AppLocalizations l10n,
    required ColorScheme scheme,
  }) {
    return [
      _SettingsSubsectionTitle(
        title: l10n.settingsPrivacySectionTitle,
        scheme: scheme,
        topPadding: 8,
      ),
      const Divider(height: 1),
      SwitchListTile(
        secondary: const Icon(Icons.analytics_outlined),
        title: Text(l10n.settingsTelemetryTitle),
        subtitle: Text(l10n.settingsTelemetrySubtitle),
        value: _app.telemetryEnabled,
        onChanged: (v) => _app.setTelemetryEnabled(v),
      ),
      const Divider(height: 1),
      SwitchListTile(
        secondary: const Icon(Icons.bug_report_outlined),
        title: Text(l10n.settingsAutoCrashReportsTitle),
        subtitle: Text(l10n.settingsAutoCrashReportsSubtitle),
        value: _app.autoCrashReports,
        onChanged: (v) => _app.setAutoCrashReports(v),
      ),
      const Divider(height: 1),
      ListTile(
        leading: const Icon(Icons.mail_outline),
        title: Text(l10n.settingsReportBugButton),
        subtitle: Text(l10n.settingsPrivacyFootnote),
        onTap: _reportBugFlow,
      ),
      if (_cloud.isSignedIn) ...[
        if (_openDiagnosticReportsLoading)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: LinearProgressIndicator(minHeight: 2),
          ),
        for (final report in _openDiagnosticReports) ...[
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.pending_actions_outlined),
            title: Text(
              report.idReadable?.isNotEmpty == true
                  ? l10n.settingsReportBugOpenTitle(report.idReadable!)
                  : l10n.settingsReportBugOpenTitleGeneric,
            ),
            subtitle: Text(
              report.errorSummary.isNotEmpty
                  ? report.errorSummary
                  : l10n.settingsReportBugOpenSubtitle,
            ),
            trailing: TextButton(
              onPressed: () => _appendOpenDiagnosticReport(report),
              child: Text(l10n.settingsReportBugAppendAction),
            ),
            isThreeLine: true,
          ),
        ],
      ],
    ];
  }
}
