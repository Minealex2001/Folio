import 'package:flutter/material.dart';

import '../../../models/folio_page.dart';
import '../../../models/folio_page_revision.dart';
import '../../../session/vault_session.dart';
import 'page_revision_diff_view.dart';

/// Abre el historial de versiones a pantalla completa.
void openPageHistoryScreen({
  required BuildContext context,
  required VaultSession session,
  required FolioPage page,
}) {
  Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (ctx) => PageHistoryScreen(session: session, page: page),
    ),
  );
}

class PageHistoryScreen extends StatelessWidget {
  const PageHistoryScreen({
    super.key,
    required this.session,
    required this.page,
  });

  final VaultSession session;
  final FolioPage page;

  static String _formatRevisionTimestamp(int savedAtMs) {
    final d = DateTime.fromMillisecondsSinceEpoch(savedAtMs);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year} · ${two(d.hour)}:${two(d.minute)}';
  }

  Future<void> _confirmRestore(
    BuildContext screenContext,
    FolioPageRevision rev,
  ) async {
    final ok = await showDialog<bool>(
      context: screenContext,
      builder: (ctx) => AlertDialog(
        icon: Icon(
          Icons.restore_rounded,
          color: Theme.of(ctx).colorScheme.primary,
        ),
        title: const Text('Restaurar versión'),
        content: const Text(
          'Se sustituirá el título y el contenido de la página por esta '
          'versión. El estado actual se guardará antes en el historial.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restaurar'),
          ),
        ],
      ),
    );
    if (ok != true || !screenContext.mounted) return;
    session.restorePageRevision(page.id, rev.revisionId);
    if (screenContext.mounted) Navigator.pop(screenContext);
  }

  Future<void> _confirmDelete(
    BuildContext screenContext,
    FolioPageRevision rev,
  ) async {
    final scheme = Theme.of(screenContext).colorScheme;
    final ok = await showDialog<bool>(
      context: screenContext,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.delete_outline_rounded, color: scheme.error),
        title: const Text('Borrar versión'),
        content: const Text(
          'Esta entrada desaparecerá del historial. El texto actual de la '
          'página no cambia.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: scheme.error,
              foregroundColor: scheme.onError,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
    if (ok != true || !screenContext.mounted) return;
    session.deletePageRevision(page.id, rev.revisionId);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        toolbarHeight: 72,
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Historial de versiones'),
            Text(
              page.title.isEmpty ? 'Sin título' : page.title,
              style: textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
      body: AnimatedBuilder(
        animation: session,
        builder: (context, _) {
          final items = session.revisionsForPage(page.id);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: _HistoryHeaderCard(
                  scheme: scheme,
                  textTheme: textTheme,
                  versionCount: items.length,
                ),
              ),
              Expanded(
                child: items.isEmpty
                    ? Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 400),
                          child: Padding(
                            padding: const EdgeInsets.all(36),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(22),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: scheme.surfaceContainerHighest
                                        .withValues(alpha: 0.65),
                                  ),
                                  child: Icon(
                                    Icons.layers_outlined,
                                    size: 40,
                                    color: scheme.onSurfaceVariant.withValues(
                                      alpha: 0.7,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  'Sin versiones todavía',
                                  style: textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Cuando dejes de escribir unos segundos, '
                                  'aquí aparecerá el historial de cambios.',
                                  textAlign: TextAlign.center,
                                  style: textTheme.bodyMedium?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    : Align(
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 720),
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                            itemCount: items.length,
                            separatorBuilder: (context, _) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, i) {
                              final rev = items[i];
                              final older = i + 1 < items.length
                                  ? items[i + 1]
                                  : null;
                              final indexLabel = items.length - i;
                              return _RevisionCard(
                                rev: rev,
                                older: older,
                                indexLabel: indexLabel,
                                timestamp: _formatRevisionTimestamp(
                                  rev.savedAtMs,
                                ),
                                scheme: scheme,
                                textTheme: textTheme,
                                onRestore: () => _confirmRestore(context, rev),
                                onDelete: () => _confirmDelete(context, rev),
                              );
                            },
                          ),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _HistoryHeaderCard extends StatelessWidget {
  const _HistoryHeaderCard({
    required this.scheme,
    required this.textTheme,
    required this.versionCount,
  });

  final ColorScheme scheme;
  final TextTheme textTheme;
  final int versionCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: [
            scheme.primaryContainer.withValues(alpha: 0.4),
            scheme.surfaceContainerLow.withValues(alpha: 0.55),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.history_edu_rounded,
              size: 26,
              color: scheme.primary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Control de versiones',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'El cofre se guarda en seguida; el historial añade una '
                  'entrada cuando dejas de editar y el contenido cambió.',
                  style: textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _InfoChip(
                      icon: Icons.bookmarks_outlined,
                      label: versionCount == 0
                          ? '0 versiones'
                          : '$versionCount ${versionCount == 1 ? 'versión' : 'versiones'}',
                      scheme: scheme,
                      textTheme: textTheme,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    required this.scheme,
    required this.textTheme,
  });

  final IconData icon;
  final String label;
  final ColorScheme scheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: scheme.primary),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RevisionCard extends StatelessWidget {
  const _RevisionCard({
    required this.rev,
    required this.older,
    required this.indexLabel,
    required this.timestamp,
    required this.scheme,
    required this.textTheme,
    required this.onRestore,
    required this.onDelete,
  });

  final FolioPageRevision rev;
  final FolioPageRevision? older;
  final int indexLabel;
  final String timestamp;
  final ColorScheme scheme;
  final TextTheme textTheme;
  final VoidCallback onRestore;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: scheme.surfaceContainerLow.withValues(alpha: 0.65),
      elevation: 0,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.65)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: ValueKey(rev.revisionId),
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          leading: SizedBox(
            width: 44,
            height: 44,
            child: Stack(
              alignment: Alignment.center,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: scheme.primary.withValues(alpha: 0.35),
                      width: 2,
                    ),
                  ),
                  child: const SizedBox(width: 40, height: 40),
                ),
                Text(
                  '$indexLabel',
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: scheme.primary,
                  ),
                ),
              ],
            ),
          ),
          title: Text(
            rev.title.isEmpty ? 'Sin título' : rev.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                Icon(
                  Icons.event_rounded,
                  size: 14,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  timestamp,
                  style: textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              decoration: BoxDecoration(
                color: scheme.surface.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.compare_arrows_rounded,
                        size: 18,
                        color: scheme.tertiary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          older == null
                              ? 'Cambios desde el inicio vacío'
                              : 'Comparado con la versión anterior',
                          style: textTheme.labelLarge?.copyWith(
                            color: scheme.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  PageRevisionDiffView(newer: rev, older: older),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline_rounded, size: 20),
                    label: const Text('Borrar'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: scheme.error,
                      side: BorderSide(
                        color: scheme.error.withValues(alpha: 0.5),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: onRestore,
                    icon: const Icon(Icons.restore_rounded, size: 20),
                    label: const Text('Restaurar'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
