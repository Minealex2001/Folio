part of 'package:folio/features/workspace/editor/block_editor.dart';

/// Cabecera de una [Section] real (Fase E0C del rediseño UX del editor) —
/// icono/color/título + badges de estado/prioridad + chevron de
/// colapsar/expandir. Reutiliza el patrón de padding de
/// `_specialRowChrome` en vez de inventar un widget de chrome aparte.
/// Deliberadamente minimal en v1: el editor de metadata inline (icon/color/
/// state/priority/tags/assignee) llega en la Fase E3, cuando exista una
/// superficie real (quick action "Agrupar en Sección") para crearlas.
Widget _sectionHeaderRow({
  required BlockEditorState st,
  required Section section,
  required ColorScheme scheme,
  required TextTheme textTheme,
  required AppLocalizations l10n,
}) {
  final metadata = section.metadata;
  final collapsed = metadata.collapsed;
  final accentColor = metadata.color != null
      ? Color(metadata.color!)
      : scheme.primary;

  void toggleCollapsed() {
    final page = st._s.selectedPage;
    if (page == null) return;
    st._s.updateSectionMetadata(
      page.id,
      section.id,
      metadata.copyWith(collapsed: !collapsed),
    );
  }

  // "Desagrupar" pedido junto con "Agrupar" (Fases E1-E3) — deshace la
  // sección sin tocar los bloques (mismo `VaultSession.deleteSection` que
  // ya usaba cualquier otra vía de borrado de sección).
  void ungroupSection() {
    final page = st._s.selectedPage;
    if (page == null) return;
    st._s.deleteSection(page.id, section.id);
  }

  return Padding(
    padding: const EdgeInsets.fromLTRB(4, 16, 4, 4),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: toggleCollapsed,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Row(
            children: [
              AnimatedRotation(
                turns: collapsed ? -0.25 : 0,
                duration: FolioMotion.short2,
                child: Icon(
                  Icons.expand_more_rounded,
                  size: 20,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 4),
              if (metadata.icon != null) ...[
                Text(metadata.icon!, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 6),
              ] else ...[
                Icon(Icons.segment_rounded, size: 16, color: accentColor),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  section.title,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (metadata.state != null) ...[
                _sectionMetadataBadge(
                  label: metadata.state!,
                  scheme: scheme,
                ),
                const SizedBox(width: 6),
              ],
              if (metadata.priority != null) ...[
                _sectionMetadataBadge(
                  label: metadata.priority!,
                  scheme: scheme,
                ),
                const SizedBox(width: 4),
              ],
              PopupMenuButton<VoidCallback>(
                tooltip: l10n.blockOptions,
                icon: Icon(
                  Icons.more_horiz_rounded,
                  size: 18,
                  color: scheme.onSurfaceVariant,
                ),
                onSelected: (action) => action(),
                itemBuilder: (menuContext) => [
                  PopupMenuItem<VoidCallback>(
                    value: ungroupSection,
                    child: Row(
                      children: [
                        Icon(
                          Icons.layers_clear_outlined,
                          size: 18,
                          color: Theme.of(menuContext).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 10),
                        Text(l10n.blockEditorUngroupSection),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Widget _sectionMetadataBadge({
  required String label,
  required ColorScheme scheme,
}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      label,
      style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
    ),
  );
}
