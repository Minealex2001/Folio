import 'package:flutter/material.dart';

import '../../../app/widgets/folio_skeletons.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../services/admin/admin_diagnostics_api.dart';
import '../../../services/admin/admin_users_api.dart';

/// Landing section: a handful of cheap counts so an admin sees "how's it going" before drilling
/// into any one resource.
class AdminDashboardSection extends StatefulWidget {
  const AdminDashboardSection({super.key, required this.role});

  final String role;

  @override
  State<AdminDashboardSection> createState() => _AdminDashboardSectionState();
}

class _AdminDashboardSectionState extends State<AdminDashboardSection> {
  static const _usersApi = AdminUsersApi();
  static const _diagnosticsApi = AdminDiagnosticsApi();

  bool _loading = true;
  int? _totalUsers;
  int? _openDiagnostics;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        _usersApi.listUsers(limit: 1),
        _diagnosticsApi.list(limit: 1, status: 'open'),
      ]);
      if (!mounted) return;
      setState(() {
        _totalUsers = results[0].total;
        _openDiagnostics = results[1].total;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(l10n.adminWelcomeTitle, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(l10n.adminCurrentRole(widget.role), style: TextStyle(color: scheme.onSurfaceVariant)),
        const SizedBox(height: 24),
        if (_loading)
          const Center(child: FolioLoadingIndicator())
        else
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _StatCard(
                icon: Icons.people_alt_outlined,
                label: l10n.adminTotalUsersLabel,
                value: '${_totalUsers ?? '—'}',
              ),
              _StatCard(
                icon: Icons.bug_report_outlined,
                label: l10n.adminOpenDiagnosticsLabel,
                value: '${_openDiagnostics ?? '—'}',
                highlight: (_openDiagnostics ?? 0) > 0,
              ),
            ],
          ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: highlight ? scheme.errorContainer : null,
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: highlight ? scheme.onErrorContainer : scheme.primary),
            const SizedBox(height: 12),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: highlight ? scheme.onErrorContainer : null,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            Text(label, style: TextStyle(color: highlight ? scheme.onErrorContainer : scheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}
