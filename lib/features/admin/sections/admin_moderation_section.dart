import 'package:flutter/material.dart';

import '../../../app/widgets/folio_dialog.dart';
import '../../../app/widgets/folio_skeletons.dart';
import '../../../l10n/generated/app_localizations.dart';
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
    final l10n = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(l10n.adminModerationReportsTitle, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.flag_outlined),
          title: Text(l10n.adminRefreshOpenReportsTitle),
          trailing: _reportsBusy
              ? const FolioLoadingIndicator(size: FolioLoadingSize.small)
              : const Icon(Icons.refresh_rounded),
          onTap: _reportsBusy ? null : _loadReports,
        ),
        if (_reportsError != null)
          Text(_reportsError!, style: TextStyle(color: scheme.error)),
        if (_reports.isEmpty && !_reportsBusy)
          Text(l10n.adminNoOpenReports, style: TextStyle(color: scheme.onSurfaceVariant)),
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
                child: Text(l10n.adminDeleteTemplateButton),
              ),
              FilledButton.tonal(
                onPressed: () async {
                  final reportId = report['id']?.toString();
                  if (reportId == null) return;
                  await _api.resolveReport(reportId);
                  await _loadReports();
                },
                child: Text(l10n.adminResolveButton),
              ),
            ],
          ),
        ],
        const SizedBox(height: 24),
        Text(l10n.adminUserLookupTitle, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        TextField(
          controller: _userQuery,
          decoration: InputDecoration(
            labelText: l10n.adminEmailOrUidLabel,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
          onSubmitted: (_) => _lookupUser(),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.search),
          title: Text(l10n.search),
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
                      ? l10n.adminAllowUploads
                      : l10n.adminBanUploads,
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
                      ? l10n.adminReactivateUser
                      : l10n.adminSuspendUser,
                ),
              ),
              OutlinedButton(
                onPressed: () async {
                  final uid = _lookup!['uid']?.toString();
                  if (uid == null) return;
                  final go = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => FolioDialog(
                      title: Text(l10n.adminPurgeTemplatesButton),
                      content: Text(l10n.adminPurgeTemplatesConfirm),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: Text(l10n.cancel),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: Text(l10n.adminActionPurge),
                        ),
                      ],
                    ),
                  );
                  if (go != true) return;
                  await _api.purgeCommunityTemplatesByOwner(uid: uid);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.adminTemplatesPurged)),
                    );
                  }
                },
                child: Text(l10n.adminPurgeTemplatesButton),
              ),
            ],
          ),
        ],
        const SizedBox(height: 24),
        Text(l10n.adminDeleteTemplateByIdTitle, style: Theme.of(context).textTheme.titleMedium),
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
          title: Text(l10n.adminActionDelete),
          onTap: () async {
            final id = _templateId.text.trim();
            if (id.isEmpty) return;
            await _api.deleteCommunityTemplate(id);
            _templateId.clear();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.adminTemplateDeleted)),
              );
            }
          },
        ),
      ],
    );
  }
}
