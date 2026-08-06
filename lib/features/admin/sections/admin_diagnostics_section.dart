import 'package:flutter/material.dart';

import '../../../app/widgets/folio_skeletons.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../services/admin/admin_diagnostics_api.dart';
import '../widgets/admin_paginated_list.dart';

class AdminDiagnosticsSection extends StatefulWidget {
  const AdminDiagnosticsSection({super.key, required this.canResolve});

  final bool canResolve;

  @override
  State<AdminDiagnosticsSection> createState() => _AdminDiagnosticsSectionState();
}

class _AdminDiagnosticsSectionState extends State<AdminDiagnosticsSection> {
  final _api = const AdminDiagnosticsApi();
  AdminPaginatedListController? _listController;
  String _statusFilter = 'open';

  Future<void> _openDetail(Map<String, dynamic> row) async {
    final id = row['id']?.toString() ?? '';
    if (id.isEmpty) return;
    final detail = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => _DiagnosticDetailDialog(id: id, api: _api, canResolve: widget.canResolve),
    );
    if (detail != null) _listController?.reload();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return AdminPaginatedList(
      searchable: false,
      searchHint: l10n.search,
      emptyLabel: l10n.adminNoDiagnosticReports,
      controllerBuilder: (c) => _listController = c,
      extraActions: [
        DropdownButton<String>(
          value: _statusFilter,
          items: [
            DropdownMenuItem(value: 'open', child: Text(l10n.adminFilterOpen)),
            DropdownMenuItem(value: 'resolved', child: Text(l10n.adminFilterResolved)),
            DropdownMenuItem(value: '', child: Text(l10n.adminFilterAll)),
          ],
          onChanged: (v) {
            if (v == null) return;
            setState(() => _statusFilter = v);
            _listController?.reload();
          },
        ),
      ],
      fetch: (page, limit, query) =>
          _api.list(page: page, limit: limit, status: _statusFilter.isEmpty ? null : _statusFilter),
      itemBuilder: (context, item) => ListTile(
        leading: Icon(
          item['status'] == 'resolved' ? Icons.check_circle_outline_rounded : Icons.bug_report_outlined,
          color: item['status'] == 'resolved' ? null : scheme.error,
        ),
        title: Text(item['kind']?.toString() ?? l10n.adminDiagnosticFallbackTitle),
        subtitle: Text(
          'user: ${item['userId'] ?? '—'} · ${item['platform'] ?? ''} ${item['appVersion'] ?? ''} · ${item['createdAt'] ?? ''}',
        ),
        onTap: () => _openDetail(item),
      ),
    );
  }
}

class _DiagnosticDetailDialog extends StatefulWidget {
  const _DiagnosticDetailDialog({required this.id, required this.api, required this.canResolve});

  final String id;
  final AdminDiagnosticsApi api;
  final bool canResolve;

  @override
  State<_DiagnosticDetailDialog> createState() => _DiagnosticDetailDialogState();
}

class _DiagnosticDetailDialogState extends State<_DiagnosticDetailDialog> {
  Map<String, dynamic>? _detail;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    widget.api.detail(widget.id).then((d) {
      if (mounted) setState(() => _detail = d);
    });
  }

  Future<void> _setStatus(String status) async {
    setState(() => _busy = true);
    try {
      final updated = await widget.api.setStatus(widget.id, status);
      if (!mounted) return;
      Navigator.pop(context, updated);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).adminErrorWithDetails('$e'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final d = _detail;
    return AlertDialog(
      title: Text(d?['kind']?.toString() ?? l10n.adminDiagnosticDialogFallbackTitle),
      content: SizedBox(
        width: 480,
        child: d == null
            ? const SizedBox(height: 80, child: Center(child: FolioLoadingIndicator()))
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('status: ${d['status'] ?? '—'}'),
                    Text('user: ${d['userId'] ?? '—'}'),
                    Text('installId: ${d['installId'] ?? '—'}'),
                    Text('platform: ${d['platform'] ?? '—'} · ${d['appVersion'] ?? '—'} · ${d['channel'] ?? '—'}'),
                    if ((d['userNote']?.toString() ?? '').isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(l10n.adminUserNoteLabel, style: Theme.of(context).textTheme.titleSmall),
                      Text(d['userNote'].toString()),
                    ],
                    if ((d['logExcerpt']?.toString() ?? '').isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(l10n.adminLogLabel, style: Theme.of(context).textTheme.titleSmall),
                      Text(d['logExcerpt'].toString(), style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                    ],
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.close)),
        if (widget.canResolve && d != null)
          FilledButton.tonal(
            onPressed: _busy ? null : () => _setStatus(d['status'] == 'resolved' ? 'open' : 'resolved'),
            child: Text(d['status'] == 'resolved' ? l10n.adminReopenButton : l10n.adminMarkResolvedButton),
          ),
      ],
    );
  }
}
