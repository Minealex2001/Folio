import 'package:flutter/material.dart';

import '../../../app/ui_tokens.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../models/block.dart';
import 'block_editor.dart';
import 'page_outline.dart';

/// Panel lateral con índice automático de encabezados (estilo Notion).
class PageOutlinePanel extends StatelessWidget {
  const PageOutlinePanel({
    super.key,
    required this.blocks,
    required this.scheme,
    required this.blockEditorKey,
  });

  final List<FolioBlock> blocks;
  final ColorScheme scheme;
  final GlobalKey<BlockEditorState> blockEditorKey;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final entries = pageOutlineEntriesFromBlocks(blocks);
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
              child: entries.isEmpty
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
                      itemCount: entries.length,
                      itemBuilder: (context, i) {
                        final e = entries[i];
                        final pad = 10.0 * (e.level - 1);
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
