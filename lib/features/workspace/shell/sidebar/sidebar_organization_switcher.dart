import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../../../services/cloud_account/organization_context_controller.dart';

/// Selector de organización activa (personal/equipo) en el shell principal.
///
/// Complementa el selector que ya existía dentro de Settings → Equipos
/// (`OrganizationManagementPanel`), que sigue siendo la única vía para
/// crear/gestionar equipos — este widget solo cambia la preferencia local de
/// "organización activa" y nunca se usa como fuente de autorización (ver
/// doc de [OrganizationContextController]). Oculto por completo cuando el
/// usuario solo tiene su organización personal, para no añadir ruido visual
/// a la mayoría de cuentas.
class SidebarOrganizationSwitcher extends StatelessWidget {
  const SidebarOrganizationSwitcher({
    super.key,
    required this.controller,
    this.onManageTeams,
  });

  final OrganizationContextController controller;
  final VoidCallback? onManageTeams;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final orgs = controller.organizations;
        if (orgs.length < 2) return const SizedBox.shrink();

        final l10n = AppLocalizations.of(context);
        final scheme = Theme.of(context).colorScheme;
        final active = controller.activeOrganization;
        final label = active == null
            ? l10n.settingsSectionOrganization
            : (active.isPersonal ? l10n.orgPanelPersonalOrgLabel(active.name) : active.name);

        return PopupMenuButton<String>(
          tooltip: l10n.orgSwitcherTooltip,
          onSelected: (id) {
            if (id == '_manage') {
              onManageTeams?.call();
              return;
            }
            unawaited(controller.setActiveOrganizationId(id));
          },
          itemBuilder: (context) => [
            for (final org in orgs)
              PopupMenuItem(
                value: org.id,
                child: Row(
                  children: [
                    SizedBox(
                      width: 26,
                      child: org.id == controller.activeOrganizationId
                          ? const Icon(Icons.check, size: 18)
                          : null,
                    ),
                    Expanded(
                      child: Text(
                        org.isPersonal ? l10n.orgPanelPersonalOrgLabel(org.name) : org.name,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            const PopupMenuDivider(),
            PopupMenuItem(
              value: '_manage',
              child: Row(
                children: [
                  const Icon(Icons.settings_outlined, size: 18),
                  const SizedBox(width: 8),
                  Text(l10n.orgSwitcherManageTeams),
                ],
              ),
            ),
          ],
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.groups_outlined, size: 16, color: scheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                Icon(Icons.unfold_more_rounded, size: 16, color: scheme.onSurfaceVariant),
              ],
            ),
          ),
        );
      },
    );
  }
}
