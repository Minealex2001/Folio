import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/ui_tokens.dart';
import '../../app/widgets/folio_dialog.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../services/cloud_account/organization_context_controller.dart';
import '../../services/folio_cloud/folio_cloud_organizations.dart';

/// Gestión de equipos en Ajustes — mismo lenguaje visual que Folio Cloud
/// (subsecciones + ListTile + diálogos), no un formulario admin.
class OrganizationManagementPanel extends StatefulWidget {
  const OrganizationManagementPanel({super.key, required this.controller});

  final OrganizationContextController controller;

  @override
  State<OrganizationManagementPanel> createState() =>
      _OrganizationManagementPanelState();
}

class _OrganizationManagementPanelState
    extends State<OrganizationManagementPanel> {
  bool _busy = false;
  String? _error;
  String? _invitesError;
  String? _activityError;
  String? _inkError;
  String? _billingError;

  List<OrganizationMember> _members = const [];
  List<OrganizationInvitation> _invitations = const [];
  List<OrganizationActivityLogEntry> _activity = const [];
  OrganizationInkBalance? _ink;
  Map<String, dynamic>? _billing;
  bool _detailLoading = false;
  bool _activityExpanded = false;

  static const _roleOptions = ['ADMIN', 'MEMBER', 'GUEST'];

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    _loadSelectedOrganizationDetail();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _run(Future<void> Function() fn) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await fn();
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _loadSelectedOrganizationDetail() async {
    final orgId = widget.controller.activeOrganizationId;
    if (orgId == null) return;
    final active = widget.controller.activeOrganization;
    setState(() {
      _detailLoading = true;
      _invitesError = null;
      _activityError = null;
      _inkError = null;
      _billingError = null;
    });
    try {
      final members = await fetchOrganizationMembers(orgId);
      List<OrganizationInvitation> invitations = const [];
      List<OrganizationActivityLogEntry> activity = const [];
      OrganizationInkBalance? ink;
      Map<String, dynamic>? billing;

      if (active != null && !active.isPersonal) {
        try {
          invitations = await fetchOrganizationInvitations(orgId);
        } catch (e) {
          _invitesError = '$e';
        }
        try {
          activity = await fetchOrganizationActivity(orgId);
        } catch (e) {
          _activityError = '$e';
        }
        try {
          ink = await fetchOrganizationInk(orgId);
        } catch (e) {
          _inkError = '$e';
        }
        if (active.role == 'OWNER') {
          try {
            billing = await fetchOrganizationBillingStatus(orgId);
          } catch (e) {
            _billingError = '$e';
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _members = members;
        _invitations = invitations;
        _activity = activity;
        _ink = ink;
        _billing = billing;
        _detailLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _detailLoading = false;
      });
    }
  }

  Future<void> _selectOrganization(String? orgId) async {
    await widget.controller.setActiveOrganizationId(orgId);
    await _loadSelectedOrganizationDetail();
  }

  Future<void> _createTeamDialog() async {
    final l10n = AppLocalizations.of(context);
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => FolioDialog(
        title: Text(l10n.orgPanelCreateTeamButton),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: l10n.orgPanelNewTeamNameLabel,
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (v) {
            final t = v.trim();
            if (t.isNotEmpty) Navigator.pop(ctx, t);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: Text(l10n.orgPanelCreateTeamButton),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    await _run(() async {
      final org = await createOrganization(name: name);
      await widget.controller.refresh();
      await widget.controller.setActiveOrganizationId(org.id);
      await _loadSelectedOrganizationDetail();
    });
  }

  Future<void> _inviteDialog() async {
    final l10n = AppLocalizations.of(context);
    final emailCtrl = TextEditingController();
    var role = 'MEMBER';
    final result = await showDialog<({String email, String role})>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return FolioDialog(
              title: Text(l10n.orgPanelInviteTitle),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: emailCtrl,
                    autofocus: true,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: l10n.orgPanelEmailLabel,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: FolioSpace.sm),
                  DropdownButtonFormField<String>(
                    initialValue: role,
                    decoration: InputDecoration(
                      labelText: l10n.orgPanelRoleMember,
                      border: const OutlineInputBorder(),
                    ),
                    items: [
                      for (final r in _roleOptions)
                        DropdownMenuItem(
                          value: r,
                          child: Text(_roleLabel(l10n, r)),
                        ),
                    ],
                    onChanged: (r) => setLocal(() => role = r ?? 'MEMBER'),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(l10n.cancel),
                ),
                FilledButton(
                  onPressed: () {
                    final email = emailCtrl.text.trim();
                    if (email.isEmpty || !email.contains('@')) return;
                    Navigator.pop(ctx, (email: email, role: role));
                  },
                  child: Text(l10n.orgPanelInviteButton),
                ),
              ],
            );
          },
        );
      },
    );
    if (result == null) return;
    await _run(() async {
      final orgId = widget.controller.activeOrganizationId;
      if (orgId == null) return;
      await inviteOrganizationMember(
        orgId: orgId,
        email: result.email,
        role: result.role,
      );
      await _loadSelectedOrganizationDetail();
    });
  }

  Future<void> _acceptInviteDialog() async {
    final l10n = AppLocalizations.of(context);
    final tokenCtrl = TextEditingController();
    final token = await showDialog<String>(
      context: context,
      builder: (ctx) => FolioDialog(
        title: Text(l10n.orgInviteAcceptTitle),
        content: TextField(
          controller: tokenCtrl,
          autofocus: true,
          decoration: InputDecoration(
            labelText: l10n.orgInviteTokenLabel,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, tokenCtrl.text.trim()),
            child: Text(l10n.orgInviteAcceptButton),
          ),
        ],
      ),
    );
    if (token == null || token.isEmpty) return;
    await _run(() async {
      final preview = await previewOrganizationInvitation(token);
      if (!mounted) return;
      final roleLabel = _roleLabel(l10n, preview.role);
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => FolioDialog(
          title: Text(l10n.orgInviteAcceptTitle),
          content: Text(
            l10n.orgInviteAcceptBody(
              preview.inviterDisplayName ?? '—',
              preview.organizationName,
              roleLabel,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.orgInviteAcceptButton),
            ),
          ],
        ),
      );
      if (go != true) return;
      await acceptOrganizationInvitation(token);
      await widget.controller.refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.orgInviteAcceptSuccess)),
        );
      }
      await _loadSelectedOrganizationDetail();
    });
  }

  Future<void> _changeRole(String memberId, String role) async {
    await _run(() async {
      final orgId = widget.controller.activeOrganizationId;
      if (orgId == null) return;
      await changeOrganizationMemberRole(
        orgId: orgId,
        memberId: memberId,
        role: role,
      );
      await _loadSelectedOrganizationDetail();
    });
  }

  Future<void> _removeMember(String memberId) async {
    final l10n = AppLocalizations.of(context);
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => FolioDialog(
        title: Text(l10n.orgPanelRemoveMemberTooltip),
        content: Text(l10n.orgPanelRemoveMemberConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.orgPanelRemoveMemberTooltip),
          ),
        ],
      ),
    );
    if (go != true) return;
    await _run(() async {
      final orgId = widget.controller.activeOrganizationId;
      if (orgId == null) return;
      await removeOrganizationMember(orgId: orgId, memberId: memberId);
      await _loadSelectedOrganizationDetail();
    });
  }

  Future<void> _revokeInvitation(String invitationId) async {
    await _run(() async {
      final orgId = widget.controller.activeOrganizationId;
      if (orgId == null) return;
      await revokeOrganizationInvitation(
        orgId: orgId,
        invitationId: invitationId,
      );
      await _loadSelectedOrganizationDetail();
    });
  }

  Future<void> _openCheckout() async {
    final l10n = AppLocalizations.of(context);
    await _run(() async {
      final orgId = widget.controller.activeOrganizationId;
      if (orgId == null) return;
      final session = await createOrganizationCheckoutSession(orgId);
      final url = session['url'] ?? session['checkoutUrl'];
      if (url == null || url.isEmpty) {
        throw StateError(l10n.orgPanelStripeNoUrlError);
      }
      final ok = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!ok) throw StateError(l10n.orgPanelCheckoutLaunchError);
    });
  }

  Future<void> _openBillingPortal() async {
    final l10n = AppLocalizations.of(context);
    await _run(() async {
      final orgId = widget.controller.activeOrganizationId;
      if (orgId == null) return;
      final session = await createOrganizationPortalSession(orgId);
      final url = session['url'] ?? session['portalUrl'];
      if (url == null || url.isEmpty) {
        throw StateError(l10n.orgPanelStripeNoUrlError);
      }
      final ok = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!ok) throw StateError(l10n.orgPanelPortalLaunchError);
    });
  }

  Future<void> _renameTeam() async {
    final l10n = AppLocalizations.of(context);
    final active = widget.controller.activeOrganization;
    if (active == null || active.isPersonal) return;
    final ctrl = TextEditingController(text: active.name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => FolioDialog(
        title: Text(l10n.orgPanelRenameTeam),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
            labelText: l10n.orgPanelNewTeamNameLabel,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: Text(l10n.save),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    await _run(() async {
      await renameOrganization(orgId: active.id, name: name);
      await widget.controller.refresh();
      await _loadSelectedOrganizationDetail();
    });
  }

  Future<void> _leaveTeam() async {
    final l10n = AppLocalizations.of(context);
    final active = widget.controller.activeOrganization;
    if (active == null || active.isPersonal) return;
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => FolioDialog(
        title: Text(l10n.orgPanelLeaveTeam),
        content: Text(l10n.orgPanelLeaveTeamConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.orgPanelLeaveTeam),
          ),
        ],
      ),
    );
    if (go != true) return;
    await _run(() async {
      await leaveOrganization(active.id);
      await widget.controller.refresh();
      await _loadSelectedOrganizationDetail();
    });
  }

  String _roleLabel(AppLocalizations l10n, String role) {
    return switch (role) {
      'OWNER' => l10n.orgPanelRoleOwner,
      'ADMIN' => l10n.orgPanelRoleAdmin,
      'MEMBER' => l10n.orgPanelRoleMember,
      'GUEST' => l10n.orgPanelRoleGuest,
      _ => role,
    };
  }

  String _statusLabel(AppLocalizations l10n, String status) {
    return switch (status) {
      'ACTIVE' => l10n.orgPanelStatusActive,
      'PENDING' => l10n.orgPanelStatusPending,
      'REMOVED' => l10n.orgPanelStatusRemoved,
      'ACCEPTED' => l10n.orgPanelStatusAccepted,
      'EXPIRED' => l10n.orgPanelStatusExpired,
      'REVOKED' => l10n.orgPanelStatusRevoked,
      _ => status,
    };
  }

  String _activityLabel(AppLocalizations l10n, String eventType) {
    return switch (eventType) {
      'organization.created' => l10n.orgPanelActivityOrganizationCreated,
      'organization.renamed' => l10n.orgPanelActivityOrganizationRenamed,
      'organization.settings_updated' => l10n.orgPanelActivitySettingsUpdated,
      'member.invited' => l10n.orgPanelActivityMemberInvited,
      'member.invite_revoked' => l10n.orgPanelActivityInviteRevoked,
      'member.joined' => l10n.orgPanelActivityMemberJoined,
      'member.role_changed' => l10n.orgPanelActivityRoleChanged,
      'member.removed' => l10n.orgPanelActivityMemberRemoved,
      'member.left' => l10n.orgPanelActivityMemberLeft,
      'workspace.created' => l10n.orgPanelActivityWorkspaceCreated,
      'workspace.renamed' => l10n.orgPanelActivityWorkspaceRenamed,
      'workspace.archived' => l10n.orgPanelActivityWorkspaceArchived,
      _ => l10n.orgPanelActivityUnknown(eventType),
    };
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '';
    return DateFormat.yMMMd().add_Hm().format(dt.toLocal());
  }

  String _initial(String value) {
    final t = value.trim();
    if (t.isEmpty) return '?';
    return t.substring(0, 1).toUpperCase();
  }

  Widget _subsection(String title, ColorScheme scheme, {double top = 16}) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, top, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final controller = widget.controller;
    final orgs = controller.organizations;
    final teams = orgs.where((o) => !o.isPersonal).toList();
    final active = controller.activeOrganization;
    final isTeam = active != null && !active.isPersonal;
    final isOwnerOrAdmin =
        active != null && (active.role == 'OWNER' || active.role == 'ADMIN');
    final isOwner = active?.role == 'OWNER';

    if (controller.loading && orgs.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(FolioSpace.xl),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text(_error!, style: TextStyle(color: scheme.error)),
          ),

        // —— Tus equipos ——
        _subsection(l10n.settingsSectionOrganization, scheme, top: 14),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          child: Text(
            l10n.orgPanelIntro,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.35,
                ),
          ),
        ),
        // Personal account as context row
        for (final org in orgs.where((o) => o.isPersonal))
          ListTile(
            leading: Icon(
              Icons.person_outline,
              color: org.id == controller.activeOrganizationId
                  ? scheme.primary
                  : scheme.onSurfaceVariant,
            ),
            title: Text(l10n.orgPanelPersonalAccountLabel(org.name)),
            trailing: org.id == controller.activeOrganizationId
                ? Icon(Icons.check_circle, color: scheme.primary, size: 20)
                : null,
            selected: org.id == controller.activeOrganizationId,
            onTap: _busy ? null : () => _selectOrganization(org.id),
          ),
        if (teams.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(
              l10n.orgPanelPersonalOrgHint,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.35,
                  ),
            ),
          ),
        for (final org in teams)
          ListTile(
            leading: Icon(
              Icons.groups_outlined,
              color: org.id == controller.activeOrganizationId
                  ? scheme.primary
                  : null,
            ),
            title: Text(org.name),
            subtitle: Text(_roleLabel(l10n, org.role)),
            trailing: org.id == controller.activeOrganizationId
                ? Icon(Icons.check_circle, color: scheme.primary, size: 20)
                : null,
            selected: org.id == controller.activeOrganizationId,
            onTap: _busy ? null : () => _selectOrganization(org.id),
          ),
        ListTile(
          leading: Icon(Icons.add_circle_outline, color: scheme.primary),
          title: Text(l10n.orgPanelCreateTeamButton),
          enabled: !_busy,
          onTap: _busy ? null : _createTeamDialog,
        ),
        ListTile(
          leading: const Icon(Icons.mail_outline),
          title: Text(l10n.orgInviteAcceptTitle),
          subtitle: Text(l10n.orgInviteTokenLabel),
          enabled: !_busy,
          onTap: _busy ? null : _acceptInviteDialog,
        ),

        // —— Detalle del equipo seleccionado ——
        if (isTeam) ...[
          if (_detailLoading)
            const Padding(
              padding: EdgeInsets.all(FolioSpace.lg),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            _subsection(active.name, scheme),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.badge_outlined),
              title: Text(l10n.orgPanelYourRole(_roleLabel(l10n, active.role))),
            ),
            if (isOwnerOrAdmin)
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: Text(l10n.orgPanelRenameTeam),
                enabled: !_busy,
                onTap: _busy ? null : _renameTeam,
              ),
            if (!isOwner)
              ListTile(
                leading: Icon(Icons.logout, color: scheme.error),
                title: Text(l10n.orgPanelLeaveTeam),
                enabled: !_busy,
                onTap: _busy ? null : _leaveTeam,
              ),

            // Tinta
            _subsection(l10n.orgPanelInkCardTitle, scheme),
            const Divider(height: 1),
            if (_ink != null)
              ListTile(
                leading: Icon(Icons.water_drop_outlined, color: scheme.primary),
                title: Text(
                  l10n.orgPanelInkCardDetail(
                    _ink!.total,
                    _ink!.monthlyBalance,
                    _ink!.purchasedBalance,
                  ),
                ),
              )
            else if (_inkError != null)
              ListTile(
                leading: Icon(Icons.error_outline, color: scheme.error),
                title: Text(_inkError!, style: TextStyle(color: scheme.error)),
              ),

            // Facturación (OWNER)
            if (isOwner) ...[
              _subsection(l10n.orgPanelBillingTitle, scheme),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.receipt_long_outlined),
                title: Text(
                  _billing != null
                      ? l10n.orgPanelBillingStatusLine(
                          '${_billing!['plan'] ?? 'FREE'}',
                          '${_billing!['subscriptionStatus'] ?? '—'}',
                          (_billing!['seats'] as num?)?.toInt() ?? 0,
                        )
                      : (_billingError ?? l10n.orgPanelBillingUnknown),
                ),
              ),
              ListTile(
                leading: Icon(Icons.workspace_premium_outlined,
                    color: scheme.primary),
                title: Text(l10n.orgPanelSubscribeButton),
                enabled: !_busy,
                onTap: _busy ? null : _openCheckout,
              ),
              ListTile(
                leading: const Icon(Icons.manage_accounts_outlined),
                title: Text(l10n.orgPanelManageBillingButton),
                enabled: !_busy,
                onTap: _busy ? null : _openBillingPortal,
              ),
            ],

            // Miembros
            _subsection(l10n.orgPanelMembersTitle, scheme),
            const Divider(height: 1),
            for (final m in _members)
              ListTile(
                leading: CircleAvatar(
                  radius: 16,
                  backgroundColor: scheme.surfaceContainerHighest,
                  child: Text(
                    _initial(m.displayName ?? m.email ?? '?'),
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
                title: Text(
                  m.displayName?.isNotEmpty == true
                      ? m.displayName!
                      : (m.email ?? m.userId),
                ),
                subtitle: Text(
                  '${_roleLabel(l10n, m.role)} · ${_statusLabel(l10n, m.status)}',
                ),
                trailing: isOwnerOrAdmin && m.role != 'OWNER'
                    ? PopupMenuButton<String>(
                        enabled: !_busy,
                        onSelected: (v) {
                          if (v == '_remove') {
                            _removeMember(m.id);
                          } else {
                            _changeRole(m.id, v);
                          }
                        },
                        itemBuilder: (ctx) => [
                          for (final r in _roleOptions)
                            PopupMenuItem(
                              value: r,
                              child: Text(_roleLabel(l10n, r)),
                            ),
                          const PopupMenuDivider(),
                          PopupMenuItem(
                            value: '_remove',
                            child: Text(l10n.orgPanelRemoveMemberTooltip),
                          ),
                        ],
                      )
                    : null,
              ),
            if (isOwnerOrAdmin)
              ListTile(
                leading: Icon(Icons.person_add_alt_1_outlined,
                    color: scheme.primary),
                title: Text(l10n.orgPanelInviteButton),
                enabled: !_busy,
                onTap: _busy ? null : _inviteDialog,
              ),
            if (_invitesError != null)
              ListTile(
                title: Text(
                  _invitesError!,
                  style: TextStyle(color: scheme.error),
                ),
              ),
            if (_invitations.isNotEmpty) ...[
              _subsection(l10n.orgPanelPendingInvitationsTitle, scheme),
              const Divider(height: 1),
              for (final inv in _invitations.where((i) => i.status == 'PENDING'))
                ListTile(
                  leading: const Icon(Icons.hourglass_empty_outlined),
                  title: Text(inv.email),
                  subtitle: Text(_roleLabel(l10n, inv.role)),
                  trailing: isOwnerOrAdmin
                      ? IconButton(
                          tooltip: l10n.orgPanelRevokeTooltip,
                          onPressed:
                              _busy ? null : () => _revokeInvitation(inv.id),
                          icon: const Icon(Icons.cancel_outlined),
                        )
                      : null,
                ),
            ],

            // Actividad (colapsable)
            if (_activity.isNotEmpty || _activityError != null) ...[
              const Divider(height: 1),
              ExpansionTile(
                initiallyExpanded: _activityExpanded,
                onExpansionChanged: (v) =>
                    setState(() => _activityExpanded = v),
                leading: const Icon(Icons.history),
                title: Text(l10n.orgPanelActivityTitle),
                children: [
                  if (_activityError != null)
                    ListTile(
                      title: Text(
                        _activityError!,
                        style: TextStyle(color: scheme.error),
                      ),
                    ),
                  for (final a in _activity.take(15))
                    ListTile(
                      dense: true,
                      title: Text(_activityLabel(l10n, a.eventType)),
                      subtitle: a.createdAt == null
                          ? null
                          : Text(_formatDate(a.createdAt)),
                    ),
                ],
              ),
            ],
          ],
        ],
      ],
    );
  }
}
