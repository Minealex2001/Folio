import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../services/cloud_account/organization_context_controller.dart';
import '../../services/folio_cloud/folio_cloud_organizations.dart';

/// Fase 6 del roadmap de producto (idea #15, "Team Home") — la superficie
/// que el propio roadmap identificó como la pieza que faltaba: roles,
/// invitaciones y billing ya tenían UI completa en
/// `OrganizationManagementPanel`, pero un equipo no tenía ningún "hogar"
/// propio, solo un panel de gestión. Reutiliza exactamente las mismas
/// llamadas de API que ya usa ese panel (`fetchOrganizationMembers`,
/// `fetchOrganizationActivity`) más una que YA existía en el cliente pero
/// nunca se había conectado a ninguna UI — `fetchOrganizationWorkspaces`/
/// `createOrganizationWorkspace` (agrupación de proyectos, el hueco real).
/// No incluye "próximas reuniones" del mockup original del roadmap: Folio
/// no tiene un modelo de reuniones programadas (solo `meeting_note`, que
/// registra reuniones ya ocurridas) — inventar ese dato sería el "relleno"
/// que este catálogo evita en todos los demás sitios.
class TeamHomeScreen extends StatefulWidget {
  const TeamHomeScreen({super.key, required this.controller});

  final OrganizationContextController controller;

  @override
  State<TeamHomeScreen> createState() => _TeamHomeScreenState();
}

class _TeamHomeScreenState extends State<TeamHomeScreen> {
  bool _loading = true;
  String? _error;
  List<OrganizationWorkspace> _workspaces = const [];
  List<OrganizationActivityLogEntry> _activity = const [];
  List<OrganizationMember> _members = const [];
  bool _busy = false;

  String? get _orgId => widget.controller.activeOrganizationId;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final orgId = _orgId;
    if (orgId == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        fetchOrganizationWorkspaces(orgId),
        fetchOrganizationActivity(orgId, limit: 20),
        fetchOrganizationMembers(orgId),
      ]);
      if (!mounted) return;
      setState(() {
        _workspaces = results[0] as List<OrganizationWorkspace>;
        _activity = results[1] as List<OrganizationActivityLogEntry>;
        _members = results[2] as List<OrganizationMember>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _createWorkspace() async {
    final l10n = AppLocalizations.of(context);
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.teamHomeCreateWorkspaceTitle),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
            labelText: l10n.teamHomeWorkspaceNameLabel,
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
            child: Text(l10n.teamHomeCreateWorkspaceButton),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    final orgId = _orgId;
    if (orgId == null) return;
    setState(() => _busy = true);
    try {
      await createOrganizationWorkspace(orgId: orgId, name: name);
      await _load();
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final active = widget.controller.activeOrganization;

    return Scaffold(
      appBar: AppBar(title: Text(active?.name ?? l10n.teamHomeTitle)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    children: [
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            _error!,
                            style: TextStyle(color: scheme.error),
                          ),
                        ),
                      Row(
                        children: [
                          Expanded(
                            child: _TeamHomeSectionCard(
                              icon: Icons.dashboard_customize_outlined,
                              title: l10n.teamHomeWorkspacesTitle,
                              trailing: IconButton(
                                icon: const Icon(Icons.add_rounded),
                                tooltip: l10n.teamHomeCreateWorkspaceButton,
                                onPressed: _busy ? null : _createWorkspace,
                              ),
                              child: _workspaces.isEmpty
                                  ? _EmptyHint(text: l10n.teamHomeWorkspacesEmpty)
                                  : Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        for (final ws in _workspaces)
                                          ListTile(
                                            contentPadding: EdgeInsets.zero,
                                            leading: const Icon(
                                              Icons.folder_shared_outlined,
                                            ),
                                            title: Text(ws.name),
                                            subtitle: ws.createdAt == null
                                                ? null
                                                : Text(
                                                    DateFormat.yMMMd()
                                                        .format(ws.createdAt!.toLocal()),
                                                  ),
                                          ),
                                      ],
                                    ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _TeamHomeSectionCard(
                        icon: Icons.groups_outlined,
                        title: l10n.teamHomeMembersTitle(_members.length),
                        child: _members.isEmpty
                            ? _EmptyHint(text: l10n.teamHomeMembersEmpty)
                            : Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  for (final m in _members)
                                    Chip(
                                      avatar: CircleAvatar(
                                        child: Text(
                                          (m.displayName?.isNotEmpty == true
                                                  ? m.displayName!
                                                  : (m.email ?? '?'))
                                              .substring(0, 1)
                                              .toUpperCase(),
                                        ),
                                      ),
                                      label: Text(
                                        m.displayName?.isNotEmpty == true
                                            ? m.displayName!
                                            : (m.email ?? m.userId),
                                      ),
                                    ),
                                ],
                              ),
                      ),
                      const SizedBox(height: 16),
                      _TeamHomeSectionCard(
                        icon: Icons.timeline_rounded,
                        title: l10n.teamHomeActivityTitle,
                        child: _activity.isEmpty
                            ? _EmptyHint(text: l10n.teamHomeActivityEmpty)
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  for (final a in _activity)
                                    ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      dense: true,
                                      leading: const Icon(
                                        Icons.circle,
                                        size: 8,
                                      ),
                                      title: Text(_activityLabel(l10n, a.eventType)),
                                      subtitle: a.createdAt == null
                                          ? null
                                          : Text(
                                              DateFormat.yMMMd()
                                                  .add_Hm()
                                                  .format(a.createdAt!.toLocal()),
                                            ),
                                    ),
                                ],
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Text(
      text,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: scheme.onSurfaceVariant,
      ),
    );
  }
}

class _TeamHomeSectionCard extends StatelessWidget {
  const _TeamHomeSectionCard({
    required this.icon,
    required this.title,
    required this.child,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: scheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title, style: Theme.of(context).textTheme.titleSmall),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
