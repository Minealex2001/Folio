import 'package:flutter/material.dart';

import '../../../app/ui_tokens.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../models/folio_page.dart';
import '../../../models/folio_section.dart';
import '../../../session/vault_session.dart';
import '../editor/block_editor.dart';
import 'page_outline.dart';

/// Fase E4 del rediseño UX del editor — ítem de render del outline: o bien
/// la cabecera de una sección real, o bien un heading (h1/h2/h3), con
/// `nested = true` cuando el heading vive dentro de una sección (indent
/// extra). Ver `_buildOutlineItems` para el algoritmo de construcción.
sealed class _OutlineItem {}

class _OutlineSectionHeader extends _OutlineItem {
  _OutlineSectionHeader(this.section);
  final Section section;
}

class _OutlineHeading extends _OutlineItem {
  _OutlineHeading(this.entry, {required this.nested});
  final PageOutlineEntry entry;
  final bool nested;
}

/// Jerarquía mixta Sección→Heading (Fase E4): si `page.sections` tiene
/// entradas reales, se muestran como nivel superior, con los headings
/// dentro de cada rango anidados debajo; los bloques no cubiertos por
/// ninguna sección real (el caso común, ya que las secciones son opt-in)
/// siguen apareciendo como headings de nivel superior, igual que el
/// bloque `toc` manual ya hace hoy — un documento sin secciones se
/// comporta exactamente igual que antes de esta fase.
List<_OutlineItem> _buildOutlineItems(FolioPage page) {
  final sections = page.sections;
  if (sections == null || sections.isEmpty) {
    return pageOutlineEntriesFromBlocks(page.blocks)
        .map((e) => _OutlineHeading(e, nested: false))
        .toList();
  }

  final headerAtBlockId = <String, Section>{};
  for (final section in sections) {
    final covered = blocksInRange(page, section.range);
    if (covered.isEmpty) continue;
    headerAtBlockId[covered.first.id] = section;
  }

  final items = <_OutlineItem>[];
  var i = 0;
  while (i < page.blocks.length) {
    final block = page.blocks[i];
    final header = headerAtBlockId[block.id];
    if (header != null) {
      items.add(_OutlineSectionHeader(header));
      final covered = blocksInRange(page, header.range);
      if (!header.metadata.collapsed) {
        items.addAll(
          pageOutlineEntriesFromBlocks(
            covered,
          ).map((e) => _OutlineHeading(e, nested: true)),
        );
      }
      i += covered.length;
      continue;
    }
    final level = switch (block.type) {
      'h1' => 1,
      'h2' => 2,
      'h3' => 3,
      _ => 0,
    };
    final text = block.text.trim();
    if (level != 0 && text.isNotEmpty) {
      items.add(
        _OutlineHeading((id: block.id, text: text, level: level), nested: false),
      );
    }
    i++;
  }
  return items;
}

/// Panel lateral con índice automático de secciones/encabezados (estilo
/// Notion). Antes de la Fase E4 solo mostraba headings en una lista plana
/// (`pageOutlineEntriesFromBlocks`, sin conocer `Section`) — ahora también
/// muestra la jerarquía real de secciones cuando existen, colapsables desde
/// aquí mismo (reutiliza `VaultSession.updateSectionMetadata`, la misma
/// mutación que ya usa la cabecera de sección dentro del editor).
class PageOutlinePanel extends StatelessWidget {
  const PageOutlinePanel({
    super.key,
    required this.page,
    required this.session,
    required this.scheme,
    required this.blockEditorKey,
  });

  final FolioPage page;
  final VaultSession session;
  final ColorScheme scheme;
  final GlobalKey<BlockEditorState> blockEditorKey;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final items = _buildOutlineItems(page);
    return Material(
      color: scheme.surfaceContainerLow,
      child: SizedBox(
        width: 248,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                FolioSpace.sm,
                FolioSpace.md,
                FolioSpace.sm,
                FolioSpace.xs,
              ),
              child: Text(
                l10n.pageOutlineTitle,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
              ),
            ),
            Expanded(
              child: items.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(FolioSpace.md),
                      child: Text(
                        l10n.pageOutlineEmpty,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(
                        FolioSpace.sm,
                        0,
                        FolioSpace.sm,
                        FolioSpace.md,
                      ),
                      itemCount: items.length,
                      itemBuilder: (context, i) {
                        final item = items[i];
                        if (item is _OutlineSectionHeader) {
                          final section = item.section;
                          final collapsed = section.metadata.collapsed;
                          return InkWell(
                            borderRadius: BorderRadius.circular(FolioRadius.sm),
                            onTap: () => blockEditorKey.currentState
                                ?.scrollToBlock(section.range.firstBlockId),
                            child: Padding(
                              padding: const EdgeInsets.only(top: 8, bottom: 4),
                              child: Row(
                                children: [
                                  InkWell(
                                    borderRadius: BorderRadius.circular(4),
                                    onTap: () => session.updateSectionMetadata(
                                      page.id,
                                      section.id,
                                      section.metadata.copyWith(
                                        collapsed: !collapsed,
                                      ),
                                    ),
                                    child: Icon(
                                      collapsed
                                          ? Icons.chevron_right_rounded
                                          : Icons.expand_more_rounded,
                                      size: 16,
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      section.title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: scheme.onSurface,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }
                        final heading = (item as _OutlineHeading);
                        final e = heading.entry;
                        final pad =
                            10.0 * (e.level - 1) + (heading.nested ? 16.0 : 0.0);
                        return InkWell(
                          borderRadius: BorderRadius.circular(FolioRadius.sm),
                          onTap: () {
                            blockEditorKey.currentState?.scrollToBlock(e.id);
                          },
                          child: Padding(
                            padding: EdgeInsetsDirectional.only(
                              start: pad,
                              top: 4,
                              bottom: 4,
                            ),
                            child: Text(
                              e.text,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.primary,
                                height: 1.25,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
