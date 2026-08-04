import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/ui_tokens.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../services/cloud_account/organization_context_controller.dart';
import '../../services/folio_cloud/folio_cloud_organizations.dart';

/// Fase 13 del roadmap de Organizations — UI de gestión de equipo, estilo
/// `vault_share_sheet.dart` (patrón `_loading`/`_busy`/`_error` + `_run`).
///
/// Widget autocontenido a propósito: no añade campos de estado nuevos a
/// `_SettingsPageState` (una clase muy grande y compartida por muchas
/// secciones) — la sección de Settings solo lo embebe.
class OrganizationManagementPanel extends StatefulWidget {
  const OrganizationManagementPanel({super.key, required this.controller});

  final OrganizationContextController controller;

  @override
  State<OrganizationManagementPanel> createState() => _OrganizationManagementPanelState();
}

class _OrganizationManagementPanelState extends State<OrganizationManagementPanel> {
  bool _busy = false;
  String? _error;

  List<OrganizationMember> _members = const [];
  List<OrganizationInvitation> _invitations = const [];
  List<OrganizationActivityLogEntry> _activity = const [];
  OrganizationInkBalance? _ink;
  bool _detailLoading = false;

  final _createNameCtrl = TextEditingController();
  final _inviteEmailCtrl = TextEditingController();
  String _inviteRole = 'MEMBER';

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
    _createNameCtrl.dispose();
    _inviteEmailCtrl.dispose();
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
    setState(() => _detailLoading = true);
    try {
      final members = await fetchOrganizationMembers(orgId);
      List<OrganizationInvitation> invitations = const [];
      List<OrganizationActivityLogEntry> activity = const [];
      OrganizationInkBalance? ink;
      try {
        invitations = await fetchOrganizationInvitations(orgId);
      } catch (_) {}
      try {
        activity = await fetchOrganizationActivity(orgId);
      } catch (_) {}
      try {
        ink = await fetchOrganizationInk(orgId);
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _members = members;
        _invitations = invitations;
        _activity = activity;
        _ink = ink;
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

  Future<void> _createTeam() async {
    final l10n = AppLocalizations.of(context);
    await _run(() async {
      final name = _createNameCtrl.text.trim();
      if (name.isEmpty) throw StateError(l10n.orgPanelNameRequiredError);
      final org = await createOrganization(name: name);
      _createNameCtrl.clear();
      await widget.controller.refresh();
      await _selectOrganization(org.id);
    });
  }

  Future<void> _invite() async {
    final orgId = widget.controller.activeOrganizationId;
    if (orgId == null) return;
    final l10n = AppLocalizations.of(context);
    await _run(() async {
      final email = _inviteEmailCtrl.text.trim();
      if (email.isEmpty || !email.contains('@')) {
        throw StateError(l10n.orgPanelInvalidEmailError);
      }
      await inviteOrganizationMember(orgId: orgId, email: email, role: _inviteRole);
      _inviteEmailCtrl.clear();
      await _loadSelectedOrganizationDetail();
    });
  }

  Future<void> _revokeInvitation(String invitationId) async {
    final orgId = widget.controller.activeOrganizationId;
    if (orgId == null) return;
    await _run(() async {
      await revokeOrganizationInvitation(orgId: orgId, invitationId: invitationId);
      await _loadSelectedOrganizationDetail();
    });
  }

  Future<void> _changeRole(String memberId, String role) async {
    final orgId = widget.controller.activeOrganizationId;
    if (orgId == null) return;
    await _run(() async {
      await changeOrganizationMemberRole(orgId: orgId, memberId: memberId, role: role);
      await _loadSelectedOrganizationDetail();
    });
  }

  Future<void> _removeMember(String memberId) async {
    final orgId = widget.controller.activeOrganizationId;
    if (orgId == null) return;
    await _run(() async {
      await removeOrganizationMember(orgId: orgId, memberId: memberId);
      await _loadSelectedOrganizationDetail();
    });
  }

  /// Fase 13 (billing de equipo) — reutiliza el patrón "abrir URL de Stripe
  /// en el navegador externo" de `settings_page_state_folio_cloud.dart`, sin
  /// el diálogo de checkout embebido (fuera de alcance de esta fase).
  Future<void> _openCheckout() async {
    final orgId = widget.controller.activeOrganizationId;
    if (orgId == null) return;
    final l10n = AppLocalizations.of(context);
    await _run(() async {
      final result = await createOrganizationCheckoutSession(orgId);
      final url = result['url'];
      if (url == null || url.isEmpty) throw StateError(l10n.orgPanelStripeNoUrlError);
      final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (!ok) throw StateError(l10n.orgPanelCheckoutLaunchError);
    });
  }

  Future<void> _openBillingPortal() async {
    final orgId = widget.controller.activeOrganizationId;
    if (orgId == null) return;
    final l10n = AppLocalizations.of(context);
    await _run(() async {
      final result = await createOrganizationPortalSession(orgId);
      final url = result['url'];
      if (url == null || url.isEmpty) throw StateError(l10n.orgPanelStripeNoUrlError);
      final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (!ok) throw StateError(l10n.orgPanelPortalLaunchError);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final controller = widget.controller;
    final orgs = controller.organizations;
    final active = controller.activeOrganization;
    final isTeam = active != null && !active.isPersonal;
    final isOwnerOrAdmin = active != null && (active.role == 'OWNER' || active.role == 'ADMIN');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.settingsSectionOrganization, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: FolioSpace.xs),
        Text(
          l10n.orgPanelIntro,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
        if (_error != null) ...[
          const SizedBox(height: FolioSpace.sm),
          Text(_error!, style: TextStyle(color: scheme.error)),
        ],
        const SizedBox(height: FolioSpace.md),
        if (controller.loading && orgs.isEmpty)
          const Padding(
            padding: EdgeInsets.all(FolioSpace.lg),
            child: Center(child: CircularProgressIndicator()),
          )
        else ...[
          if (orgs.isNotEmpty)
            DropdownButtonFormField<String>(
              initialValue: controller.activeOrganizationId,
              decoration: InputDecoration(
                labelText: l10n.orgPanelActiveOrgLabel,
                border: const OutlineInputBorder(),
              ),
              items: [
                for (final org in orgs)
                  DropdownMenuItem(
                    value: org.id,
                    child: Text(org.isPersonal ? l10n.orgPanelPersonalOrgLabel(org.name) : org.name),
                  ),
              ],
              onChanged: _busy ? null : _selectOrganization,
            ),
          const SizedBox(height: FolioSpace.md),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _createNameCtrl,
                  decoration: InputDecoration(
                    labelText: l10n.orgPanelNewTeamNameLabel,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: FolioSpace.sm),
              FilledButton(
                onPressed: _busy ? null : _createTeam,
                child: Text(l10n.orgPanelCreateTeamButton),
              ),
            ],
          ),
          if (active != null) ...[
            const SizedBox(height: FolioSpace.xl),
            const Divider(height: 1),
            const SizedBox(height: FolioSpace.md),
            if (_detailLoading)
              const Center(child: CircularProgressIndicator())
            else if (isTeam) ...[
              if (_ink != null) ...[
                _OrganizationInkBalanceCard(ink: _ink!, scheme: scheme),
                const SizedBox(height: FolioSpace.md),
              ],
              if (isOwnerOrAdmin) ...[
                Text(l10n.orgPanelBillingTitle, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: FolioSpace.sm),
                Wrap(
                  spacing: FolioSpace.sm,
                  runSpacing: FolioSpace.sm,
                  children: [
                    FilledButton.tonal(
                      onPressed: _busy ? null : _openCheckout,
                      child: Text(l10n.orgPanelSubscribeButton),
                    ),
                    OutlinedButton(
                      onPressed: _busy ? null : _openBillingPortal,
                      child: Text(l10n.orgPanelManageBillingButton),
                    ),
                  ],
                ),
                const SizedBox(height: FolioSpace.lg),
              ],
              Text(l10n.orgPanelMembersTitle, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: FolioSpace.sm),
              for (final m in _members)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(m.displayName?.isNotEmpty == true ? m.displayName! : (m.email ?? m.userId)),
                  subtitle: Text('${m.role} · ${m.status}'),
                  trailing: isOwnerOrAdmin
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            DropdownButton<String>(
                              value: _roleOptions.contains(m.role) ? m.role : null,
                              hint: Text(m.role),
                              items: [
                                for (final r in _roleOptions)
                                  DropdownMenuItem(value: r, child: Text(r)),
                              ],
                              onChanged: _busy ? null : (r) => r == null ? null : _changeRole(m.id, r),
                            ),
                            IconButton(
                              tooltip: l10n.orgPanelRemoveMemberTooltip,
                              onPressed: _busy ? null : () => _removeMember(m.id),
                              icon: const Icon(Icons.person_remove_outlined),
                            ),
                          ],
                        )
                      : null,
                ),
              if (isOwnerOrAdmin) ...[
                const SizedBox(height: FolioSpace.md),
                Text(l10n.orgPanelInviteTitle, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: FolioSpace.sm),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _inviteEmailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: l10n.orgPanelEmailLabel,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: FolioSpace.sm),
                    DropdownButton<String>(
                      value: _inviteRole,
                      items: [
                        for (final r in _roleOptions) DropdownMenuItem(value: r, child: Text(r)),
                      ],
                      onChanged: _busy ? null : (r) => setState(() => _inviteRole = r ?? 'MEMBER'),
                    ),
                    const SizedBox(width: FolioSpace.sm),
                    FilledButton.tonal(
                      onPressed: _busy ? null : _invite,
                      child: Text(l10n.orgPanelInviteButton),
                    ),
                  ],
                ),
                if (_invitations.isNotEmpty) ...[
                  const SizedBox(height: FolioSpace.md),
                  Text(l10n.orgPanelPendingInvitationsTitle, style: Theme.of(context).textTheme.titleSmall),
                  for (final inv in _invitations)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(inv.email),
                      subtitle: Text('${inv.role} · ${inv.status}'),
                      trailing: inv.status == 'PENDING'
                          ? IconButton(
                              tooltip: l10n.orgPanelRevokeTooltip,
                              onPressed: _busy ? null : () => _revokeInvitation(inv.id),
                              icon: const Icon(Icons.cancel_outlined),
                            )
                          : null,
                    ),
                ],
              ],
              if (_activity.isNotEmpty) ...[
                const SizedBox(height: FolioSpace.md),
                Text(l10n.orgPanelActivityTitle, style: Theme.of(context).textTheme.titleSmall),
                for (final a in _activity.take(20))
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(a.eventType),
                    subtitle: a.createdAt == null ? null : Text('${a.createdAt}'),
                  ),
              ],
            ] else
              Text(
                l10n.orgPanelPersonalOrgHint,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
              ),
          ],
        ],
      ],
    );
  }
}

/// Saldo de tinta IA compartida por todos los miembros de la organización
/// (Fase 13 del roadmap de Organizations — `org_ink`, no `user_ink`).
class _OrganizationInkBalanceCard extends StatelessWidget {
  const _OrganizationInkBalanceCard({required this.ink, required this.scheme});

  final OrganizationInkBalance ink;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(FolioSpace.md),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.water_drop_outlined, color: scheme.primary),
          const SizedBox(width: FolioSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.orgPanelInkCardTitle, style: Theme.of(context).textTheme.titleSmall),
                Text(
                  l10n.orgPanelInkCardDetail(ink.total, ink.monthlyBalance, ink.purchasedBalance),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
