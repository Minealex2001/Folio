import 'package:diff_match_patch/diff_match_patch.dart';
import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../models/folio_page_revision.dart';
import '../../../models/folio_page.dart';

/// Vista estilo diff entre una revisión y la anterior (o vacío).
class PageRevisionDiffView extends StatelessWidget {
  const PageRevisionDiffView({super.key, required this.newer, this.older});

  final FolioPageRevision newer;
  final FolioPageRevision? older;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final oldTitle = older?.title ?? '';
    final newTitle = newer.title;
    final oldBody = older != null
        ? folioPlainTextFromBlocksJson(older!.blocksJson)
        : '';
    final newBody = folioPlainTextFromBlocksJson(newer.blocksJson);

    final dmp = DiffMatchPatch()..diffTimeout = 0;
    final bodyDiffs = dmp.diff(oldBody, newBody, true);
    dmp.diffCleanupSemantic(bodyDiffs);

    final mono = theme.textTheme.bodySmall?.copyWith(
      fontFamily: 'monospace',
      fontSize: 12,
      height: 1.35,
    );

    final titleChanged = oldTitle != newTitle;
    final bodyUnchanged = oldBody == newBody;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (titleChanged) ...[
          Text(
            l10n.titleLabelSimple,
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: scheme.errorContainer.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    oldTitle.isEmpty ? l10n.emptyValue : oldTitle,
                    style: mono?.copyWith(
                      color: scheme.onErrorContainer,
                      decoration: TextDecoration.lineThrough,
                      decorationColor: scheme.onErrorContainer,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  size: 18,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    newTitle.isEmpty ? l10n.emptyValue : newTitle,
                    style: mono?.copyWith(
                      color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        Text(
          l10n.contentLabel,
          style: theme.textTheme.labelSmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        if (!bodyUnchanged) ..._diffWidgets(bodyDiffs, scheme, mono),
        if (bodyUnchanged)
          Text(
            l10n.noTextChanges,
            style: mono?.copyWith(color: scheme.onSurfaceVariant),
          ),
      ],
    );
  }

  List<Widget> _diffWidgets(
    List<Diff> diffs,
    ColorScheme scheme,
    TextStyle? mono,
  ) {
    final out = <Widget>[];
    for (final d in diffs) {
      if (d.text.isEmpty) continue;
      final lines = d.text.split('\n');
      var i = 0;
      for (final line in lines) {
        final isLastLine = i == lines.length - 1;
        i++;
        if (line.isEmpty && isLastLine && d.text.endsWith('\n')) {
          out.add(const SizedBox(height: 4));
          continue;
        }
        Color bg;
        Color fg;
        String prefix;
        switch (d.operation) {
          case DIFF_DELETE:
            bg = scheme.error.withValues(alpha: 0.12);
            fg = scheme.error;
            prefix = '− ';
            break;
          case DIFF_INSERT:
            bg = scheme.primaryContainer.withValues(alpha: 0.5);
            fg = scheme.onPrimaryContainer;
            prefix = '+ ';
            break;
          default:
            bg = scheme.surfaceContainerHighest.withValues(alpha: 0.5);
            fg = scheme.onSurfaceVariant.withValues(alpha: 0.85);
            prefix = '  ';
        }
        out.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: SelectableText(
                  '$prefix${line.isEmpty ? ' ' : line}',
                  style: mono?.copyWith(color: fg),
                ),
              ),
            ),
          ),
        );
      }
    }
    return out;
  }
}
