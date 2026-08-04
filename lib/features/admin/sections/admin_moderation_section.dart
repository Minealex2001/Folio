import 'package:flutter/material.dart';

import '../../../app/widgets/folio_dialog.dart';
import '../../../app/widgets/folio_skeletons.dart';
import '../../../services/admin/folio_admin_api.dart';

/// Moderación community (reports, ban, suspend) — migrada desde Settings → Admin.
class AdminModerationSection extends StatefulWidget {
  const AdminModerationSection({super.key});

  @override
  State<AdminModerationSection> createState() => _AdminModerationSectionState();
}

class _AdminModerationSectionState extends State<AdminModerationSection> {
  final _api = FolioAdminApi();
  final _userQuery = TextEditingController();
  final _templateId = TextEditingController();

  var _reportsBusy = false;
  String? _reportsError;
  List<Map<String, dynamic>> _reports = const [];

  var _lookupBusy = false;
  String? _lookupError;
  Map<String, dynamic>? _lookup;

  @override
  void dispose() {
    _userQuery.dispose();
    _templateId.dispose();
    super.dispose();
  }

  Future<void> _loadReports() async {
    setState(() {
      _reportsBusy = true;
      _reportsError = null;
    });
    try {
      final items = await _api.listOpenReports();
      if (!mounted) return;
      setState(() {
        _reports = items;
        _reportsBusy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _reportsBusy = false;
        _reportsError = '$e';
      });
    }
  }

  Future<void> _lookupUser() async {
    final raw = _userQuery.text.trim();
    if (raw.isEmpty) return;
    setState(() {
      _lookupBusy = true;
      _lookupError = null;
      _lookup = null;
    });
    try {
      final isEmail = raw.contains('@');
      final snap = await _api.lookupUser(
        email: isEmail ? raw : null,
        uid: isEmail ? null : raw,
      );
      if (!mounted) return;
      setState(() {
        _lookup = snap;
        _lookupBusy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _lookupBusy = false;
        _lookupError = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Reportes de templates', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.flag_outlined),
          title: const Text('Actualizar reportes abiertos'),
          trailing: _reportsBusy
              ? const FolioLoadingIndicator(size: FolioLoadingSize.small)
              : const Icon(Icons.refresh_rounded),
          onTap: _reportsBusy ? null : _loadReports,
        ),
        if (_reportsError != null)
          Text(_reportsError!, style: TextStyle(color: scheme.error)),
        if (_reports.isEmpty && !_reportsBusy)
          Text('Sin reportes abiertos.', style: TextStyle(color: scheme.onSurfaceVariant)),
        for (final report in _reports) ...[
          const Divider(),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              (report['templateName']?.toString().trim().isNotEmpty == true)
                  ? report['templateName'].toString()
                  : (report['templateId']?.toString() ?? ''),
            ),
            subtitle: Text(
              [
                if ((report['reason']?.toString() ?? '').trim().isNotEmpty)
                  report['reason'].toString(),
                'owner: ${report['ownerUid'] ?? '—'}',
                'reporter: ${report['reporterUid'] ?? '—'}',
              ].join('\n'),
            ),
            isThreeLine: true,
          ),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton(
                onPressed: () async {
                  final id = report['templateId']?.toString();
                  if (id == null || id.isEmpty) return;
                  await _api.deleteCommunityTemplate(id);
                  final reportId = report['id']?.toString();
                  if (reportId != null) await _api.resolveReport(reportId);
                  await _loadReports();
                },
                child: const Text('Borrar template'),
              ),
              FilledButton.tonal(
                onPressed: () async {
                  final reportId = report['id']?.toString();
                  if (reportId == null) return;
                  await _api.resolveReport(reportId);
                  await _loadReports();
                },
                child: const Text('Resolver'),
              ),
            ],
          ),
        ],
        const SizedBox(height: 24),
        Text('Usuario (lookup)', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        TextField(
          controller: _userQuery,
          decoration: const InputDecoration(
            labelText: 'Email o uid',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          onSubmitted: (_) => _lookupUser(),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.search),
          title: const Text('Buscar'),
          trailing: _lookupBusy
              ? const FolioLoadingIndicator(size: FolioLoadingSize.small)
              : null,
          onTap: _lookupBusy ? null : _lookupUser,
        ),
        if (_lookupError != null)
          Text(_lookupError!, style: TextStyle(color: scheme.error)),
        if (_lookup != null) ...[
          Text(
            _lookup!['email']?.toString() ?? _lookup!['uid']?.toString() ?? '',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          Text(
            'uid: ${_lookup!['uid']}\n'
            'status: ${_lookup!['status'] ?? 'active'}\n'
            'uploadBanned: ${_lookup!['communityTemplateUploadBanned'] == true}',
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: () async {
                  final banned =
                      _lookup!['communityTemplateUploadBanned'] == true;
                  final uid = _lookup!['uid']?.toString();
                  if (uid == null) return;
                  final next =
                      await _api.setUploadBan(uid: uid, banned: !banned);
                  setState(() => _lookup = next);
                },
                child: Text(
                  _lookup!['communityTemplateUploadBanned'] == true
                      ? 'Permitir uploads'
                      : 'Ban uploads',
                ),
              ),
              OutlinedButton(
                onPressed: () async {
                  final suspended =
                      (_lookup!['status']?.toString() ?? '') == 'suspended';
                  final uid = _lookup!['uid']?.toString();
                  if (uid == null) return;
                  final next = await _api.setUserStatus(
                    uid: uid,
                    status: suspended ? 'active' : 'suspended',
                  );
                  setState(() => _lookup = next);
                },
                child: Text(
                  (_lookup!['status']?.toString() ?? '') == 'suspended'
                      ? 'Reactivar'
                      : 'Suspender',
                ),
              ),
              OutlinedButton(
                onPressed: () async {
                  final uid = _lookup!['uid']?.toString();
                  if (uid == null) return;
                  final go = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => FolioDialog(
                      title: const Text('Purgar templates'),
                      content: const Text(
                        '¿Borrar todos los community templates de este usuario?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancelar'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Purgar'),
                        ),
                      ],
                    ),
                  );
                  if (go != true) return;
                  await _api.purgeCommunityTemplatesByOwner(uid: uid);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Templates purgados')),
                    );
                  }
                },
                child: const Text('Purgar templates'),
              ),
            ],
          ),
        ],
        const SizedBox(height: 24),
        Text('Borrar template por ID', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        TextField(
          controller: _templateId,
          decoration: const InputDecoration(
            labelText: 'templateId',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.delete_outline),
          title: const Text('Borrar'),
          onTap: () async {
            final id = _templateId.text.trim();
            if (id.isEmpty) return;
            await _api.deleteCommunityTemplate(id);
            _templateId.clear();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Template borrado')),
              );
            }
          },
        ),
      ],
    );
  }
}
