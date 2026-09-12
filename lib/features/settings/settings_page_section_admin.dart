part of 'settings_page.dart';

extension _SettingsPageAdminSection on _SettingsPageState {
  Widget _buildAdminSection({
    required AppLocalizations l10n,
    required ColorScheme scheme,
    required _SettingsSectionId? activeSection,
  }) {
    return Visibility(
      visible: activeSection == _SettingsSectionId.admin,
      maintainState: false,
      child: KeyedSubtree(
        key: const ValueKey(_SettingsSectionId.admin),
        child: _SettingsPanel(
          margin: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SettingsPanelHeroCard(
                icon: Icons.admin_panel_settings_outlined,
                title: l10n.settingsAdminSectionTitle,
                description: l10n.settingsAdminHeroDescription,
              ),
              const Divider(height: 1),
              _SettingsSubsectionTitle(
                title: l10n.settingsAdminReportsTitle,
                scheme: scheme,
              ),
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: Text(l10n.settingsAdminRefreshReports),
                trailing: _adminReportsBusy
                    ? const FolioLoadingIndicator(size: FolioLoadingSize.small)
                    : const Icon(Icons.refresh_rounded),
                onTap: _adminReportsBusy ? null : _adminLoadReports,
              ),
              if (_adminReportsError != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Text(
                    _adminReportsError!,
                    style: TextStyle(color: scheme.error),
                  ),
                ),
              if (_adminReports.isEmpty && !_adminReportsBusy)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Text(
                    l10n.settingsAdminReportsEmpty,
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ),
              for (final report in _adminReports) ...[
                const Divider(height: 1),
                ListTile(
                  title: Text(
                    (report['templateName']?.toString().trim().isNotEmpty ==
                            true)
                        ? report['templateName'].toString()
                        : (report['templateId']?.toString() ?? ''),
                  ),
                  subtitle: Text(
                    [
                      if ((report['reason']?.toString() ?? '')
                          .trim()
                          .isNotEmpty)
                        report['reason'].toString(),
                      'owner: ${report['ownerUid'] ?? '—'}',
                      'reporter: ${report['reporterUid'] ?? '—'}',
                    ].join('\n'),
                  ),
                  isThreeLine: true,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: () async {
                          final id = report['templateId']?.toString() ?? '';
                          if (id.isEmpty) return;
                          await Clipboard.setData(ClipboardData(text: id));
                          if (!mounted) return;
                          _snack(l10n.settingsAdminCopiedId);
                        },
                        child: Text(l10n.settingsAdminCopyTemplateId),
                      ),
                      FilledButton.tonal(
                        onPressed: () => _adminDeleteTemplateFromReport(report),
                        child: Text(l10n.settingsAdminDeleteTemplate),
                      ),
                      TextButton(
                        onPressed: () => _adminResolveReport(report),
                        child: Text(l10n.settingsAdminResolveReport),
                      ),
                    ],
                  ),
                ),
              ],
              const Divider(height: 1),
              _SettingsSubsectionTitle(
                title: l10n.settingsAdminUserTitle,
                scheme: scheme,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: TextField(
                  controller: _adminUserQueryController,
                  decoration: InputDecoration(
                    labelText: l10n.settingsAdminUserLookupHint,
                    border: const OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _adminLookupUser(),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.search_rounded),
                title: Text(l10n.settingsAdminLookupUser),
                trailing: _adminLookupBusy
                    ? const FolioLoadingIndicator(size: FolioLoadingSize.small)
                    : null,
                onTap: _adminLookupBusy ? null : _adminLookupUser,
              ),
              if (_adminLookupError != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Text(
                    _adminLookupError!,
                    style: TextStyle(color: scheme.error),
                  ),
                ),
              if (_adminLookupSnapshot != null) ...[
                ListTile(
                  title: Text(
                    _adminLookupSnapshot!['email']?.toString() ??
                        _adminLookupSnapshot!['uid']?.toString() ??
                        '',
                  ),
                  subtitle: Text(
                    'uid: ${_adminLookupSnapshot!['uid']}\n'
                    'status: ${_adminLookupSnapshot!['status'] ?? 'active'}\n'
                    'uploadBanned: ${_adminLookupSnapshot!['communityTemplateUploadBanned'] == true}',
                  ),
                  isThreeLine: true,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: () => _adminToggleUploadBan(
                          banned:
                              _adminLookupSnapshot![
                                      'communityTemplateUploadBanned'] !=
                                  true,
                        ),
                        child: Text(
                          _adminLookupSnapshot![
                                      'communityTemplateUploadBanned'] ==
                                  true
                              ? l10n.settingsAdminAllowUploads
                              : l10n.settingsAdminBanUploads,
                        ),
                      ),
                      OutlinedButton(
                        onPressed: () => _adminToggleSuspend(
                          suspend:
                              (_adminLookupSnapshot!['status']?.toString() ??
                                      'active') !=
                                  'suspended',
                        ),
                        child: Text(
                          (_adminLookupSnapshot!['status']?.toString() ??
                                      'active') ==
                                  'suspended'
                              ? l10n.settingsAdminReactivateUser
                              : l10n.settingsAdminSuspendUser,
                        ),
                      ),
                      FilledButton.tonal(
                        style: FilledButton.styleFrom(
                          foregroundColor: scheme.error,
                        ),
                        onPressed: _adminPurgeOwnerTemplates,
                        child: Text(l10n.settingsAdminPurgeTemplates),
                      ),
                    ],
                  ),
                ),
              ],
              const Divider(height: 1),
              _SettingsSubsectionTitle(
                title: l10n.settingsAdminTemplateByIdTitle,
                scheme: scheme,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: TextField(
                  controller: _adminTemplateIdController,
                  decoration: InputDecoration(
                    labelText: l10n.settingsAdminTemplateIdHint,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              ListTile(
                leading: Icon(Icons.delete_outline_rounded, color: scheme.error),
                title: Text(l10n.settingsAdminDeleteTemplate),
                onTap: _adminDeleteTemplateById,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _adminLoadReports() async {
    setState(() {
      _adminReportsBusy = true;
      _adminReportsError = null;
    });
    try {
      final items = await _adminApi.listOpenReports();
      if (!mounted) return;
      setState(() {
        _adminReports = items;
        _adminReportsBusy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _adminReportsBusy = false;
        _adminReportsError = '$e';
      });
    }
  }

  Future<void> _adminResolveReport(Map<String, dynamic> report) async {
    final id = report['id']?.toString() ?? '';
    if (id.isEmpty) return;
    try {
      await _adminApi.resolveReport(id);
      if (!mounted) return;
      _snack(AppLocalizations.of(context).settingsAdminResolveSuccess);
      await _adminLoadReports();
    } catch (e) {
      if (!mounted) return;
      _snack('${AppLocalizations.of(context).settingsAdminActionError}: $e');
    }
  }

  Future<void> _adminDeleteTemplateFromReport(
    Map<String, dynamic> report,
  ) async {
    final l10n = AppLocalizations.of(context);
    final templateId = report['templateId']?.toString() ?? '';
    if (templateId.isEmpty) return;
    final ok = await FolioDialog.confirm(
      context,
      title: Text(l10n.settingsAdminDeleteTemplate),
      content: Text(l10n.settingsAdminDeleteTemplateConfirm(templateId)),
      confirmLabel: l10n.settingsAdminDeleteTemplate,
    );
    if (ok != true || !mounted) return;
    try {
      await _adminApi.deleteCommunityTemplate(templateId);
      final reportId = report['id']?.toString();
      if (reportId != null && reportId.isNotEmpty) {
        await _adminApi.resolveReport(reportId);
      }
      if (!mounted) return;
      _snack(l10n.settingsAdminDeleteTemplateSuccess);
      await _adminLoadReports();
    } catch (e) {
      if (!mounted) return;
      _snack('${l10n.settingsAdminActionError}: $e');
    }
  }

  Future<void> _adminLookupUser() async {
    final raw = _adminUserQueryController.text.trim();
    if (raw.isEmpty) return;
    setState(() {
      _adminLookupBusy = true;
      _adminLookupError = null;
      _adminLookupSnapshot = null;
    });
    try {
      final isEmail = raw.contains('@');
      final snap = await _adminApi.lookupUser(
        email: isEmail ? raw : null,
        uid: isEmail ? null : raw,
      );
      if (!mounted) return;
      setState(() {
        _adminLookupSnapshot = snap;
        _adminLookupBusy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _adminLookupBusy = false;
        _adminLookupError = '$e';
      });
    }
  }

  Future<void> _adminToggleUploadBan({required bool banned}) async {
    final snap = _adminLookupSnapshot;
    if (snap == null) return;
    final l10n = AppLocalizations.of(context);
    final uid = snap['uid']?.toString();
    try {
      final next = await _adminApi.setUploadBan(uid: uid, banned: banned);
      if (!mounted) return;
      setState(() => _adminLookupSnapshot = next);
      _snack(
        banned
            ? l10n.settingsAdminBanUploadsSuccess
            : l10n.settingsAdminAllowUploadsSuccess,
      );
    } catch (e) {
      if (!mounted) return;
      _snack('${l10n.settingsAdminActionError}: $e');
    }
  }

  Future<void> _adminToggleSuspend({required bool suspend}) async {
    final snap = _adminLookupSnapshot;
    if (snap == null) return;
    final l10n = AppLocalizations.of(context);
    final uid = snap['uid']?.toString();
    final ok = await FolioDialog.confirm(
      context,
      title: Text(
        suspend
            ? l10n.settingsAdminSuspendUser
            : l10n.settingsAdminReactivateUser,
      ),
      content: Text(
        suspend
            ? l10n.settingsAdminSuspendConfirm
            : l10n.settingsAdminReactivateConfirm,
      ),
      confirmLabel: suspend
          ? l10n.settingsAdminSuspendUser
          : l10n.settingsAdminReactivateUser,
    );
    if (ok != true || !mounted) return;
    try {
      final next = await _adminApi.setUserStatus(
        uid: uid,
        status: suspend ? 'suspended' : 'active',
      );
      if (!mounted) return;
      setState(() => _adminLookupSnapshot = next);
      _snack(
        suspend
            ? l10n.settingsAdminSuspendSuccess
            : l10n.settingsAdminReactivateSuccess,
      );
    } catch (e) {
      if (!mounted) return;
      _snack('${l10n.settingsAdminActionError}: $e');
    }
  }

  Future<void> _adminPurgeOwnerTemplates() async {
    final snap = _adminLookupSnapshot;
    if (snap == null) return;
    final l10n = AppLocalizations.of(context);
    final uid = snap['uid']?.toString() ?? '';
    final ok = await FolioDialog.confirm(
      context,
      title: Text(l10n.settingsAdminPurgeTemplates),
      content: Text(l10n.settingsAdminPurgeConfirm(uid)),
      confirmLabel: l10n.settingsAdminPurgeTemplates,
    );
    if (ok != true || !mounted) return;
    try {
      final result = await _adminApi.purgeCommunityTemplatesByOwner(uid: uid);
      if (!mounted) return;
      final deleted = result['deleted'];
      _snack(l10n.settingsAdminPurgeSuccess('$deleted'));
    } catch (e) {
      if (!mounted) return;
      _snack('${l10n.settingsAdminActionError}: $e');
    }
  }

  Future<void> _adminDeleteTemplateById() async {
    final l10n = AppLocalizations.of(context);
    final id = _adminTemplateIdController.text.trim();
    if (id.isEmpty) return;
    final ok = await FolioDialog.confirm(
      context,
      title: Text(l10n.settingsAdminDeleteTemplate),
      content: Text(l10n.settingsAdminDeleteTemplateConfirm(id)),
      confirmLabel: l10n.settingsAdminDeleteTemplate,
    );
    if (ok != true || !mounted) return;
    try {
      await _adminApi.deleteCommunityTemplate(id);
      if (!mounted) return;
      _adminTemplateIdController.clear();
      _snack(l10n.settingsAdminDeleteTemplateSuccess);
    } catch (e) {
      if (!mounted) return;
      _snack('${l10n.settingsAdminActionError}: $e');
    }
  }
}
