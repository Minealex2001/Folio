import 'package:flutter/material.dart';

import '../../../../app/ui_tokens.dart';
import '../../../../l10n/generated/app_localizations.dart';

/// Fase 5 del roadmap de producto — primera pieza visible de la jerarquía de
/// 5 pilares (Write/Think/Organize/Connect/Customize) que el brief original
/// pedía como reestructuración de navegación, no solo categorización
/// interna. Deliberadamente acotada a un v1 de bajo riesgo: en vez de
/// reagrupar todo el árbol de páginas (código de drag&drop delicado, ver
/// resto de `sidebar.dart`) o inventar destinos nuevos sin verificar, cada
/// botón despacha a un callback que YA existe y ya está enganchado en algún
/// otro punto de esta misma barra lateral — esta fila es un atajo visible a
/// esos destinos reales, no un segundo sistema de navegación paralelo.
/// Reagrupar el resto del sidebar por pilar queda como ampliación futura de
/// esta misma pieza, no una reescritura distinta.
class SidebarPillarRail extends StatelessWidget {
  const SidebarPillarRail({
    super.key,
    required this.onWrite,
    this.onThink,
    this.onOrganize,
    this.onConnect,
    this.onCustomize,
  });

  /// ✍️ Write — crear página nueva. Mismo callback que el botón "nueva
  /// página" de la cabecera de "Páginas" (`session.addPage`).
  final VoidCallback onWrite;

  /// 🧠 Think — búsqueda global (incluye memoria de reuniones/Quill desde
  /// la Fase 1 de este roadmap). No hay hoy un "abrir panel de Quill"
  /// separado y verificado — la búsqueda es el destino real más cercano.
  final VoidCallback? onThink;

  /// ✅ Organize — el Task Hub ya existente (`onOpenVaultTaskHub`).
  final VoidCallback? onOrganize;

  /// ☁️ Connect — estado de Folio Cloud / equipo (`onOpenCloudStatus`).
  final VoidCallback? onConnect;

  /// 🎨 Customize — Ajustes (`onOpenSettings`); personalización/Visual
  /// Packs viven dentro, no hay todavía un deep-link directo a esa sección
  /// desde el sidebar.
  final VoidCallback? onCustomize;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    Widget pillarButton({
      required IconData icon,
      required String tooltip,
      required VoidCallback? onPressed,
    }) {
      return Expanded(
        child: Tooltip(
          message: tooltip,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(FolioRadius.md),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Icon(
                icon,
                size: 20,
                color: onPressed == null
                    ? scheme.onSurfaceVariant.withValues(alpha: 0.35)
                    : scheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        FolioSpace.sm,
        0,
        FolioSpace.sm,
        FolioSpace.sm,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(FolioRadius.lg),
        ),
        child: Row(
          children: [
            pillarButton(
              icon: Icons.edit_note_rounded,
              tooltip: l10n.sidebarPillarWrite,
              onPressed: onWrite,
            ),
            pillarButton(
              icon: Icons.psychology_outlined,
              tooltip: l10n.sidebarPillarThink,
              onPressed: onThink,
            ),
            pillarButton(
              icon: Icons.check_circle_outline_rounded,
              tooltip: l10n.sidebarPillarOrganize,
              onPressed: onOrganize,
            ),
            pillarButton(
              icon: Icons.cloud_outlined,
              tooltip: l10n.sidebarPillarConnect,
              onPressed: onConnect,
            ),
            pillarButton(
              icon: Icons.palette_outlined,
              tooltip: l10n.sidebarPillarCustomize,
              onPressed: onCustomize,
            ),
          ],
        ),
      ),
    );
  }
}
