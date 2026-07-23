import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;

import '../../../app/widgets/folio_dialog.dart';
import '../../../git/version_info.dart';
import '../../../l10n/generated/app_localizations.dart';
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
  final isHandheldPlatform =
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
  if (!isHandheldPlatform) {
    showDialog<void>(
      context: context,
      barrierColor:
          Theme.of(context).colorScheme.scrim.withValues(alpha: 0.55),
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: 760,
          height: 720,
          child: PageHistoryScreen(
            session: session,
            page: page,
            embedded: true,
          ),
        ),
      ),
    );
    return;
  }

  Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (ctx) => PageHistoryScreen(session: session, page: page),
    ),
  );
}

class PageHistoryScreen extends StatefulWidget {
  const PageHistoryScreen({
    super.key,
    required this.session,
    required this.page,
    this.embedded = false,
  });

  final VaultSession session;
  final FolioPage page;
  final bool embedded;

  @override
  State<PageHistoryScreen> createState() => _PageHistoryScreenState();
}

class _PageHistoryScreenState extends State<PageHistoryScreen> {
  List<VersionInfo> _versions = const [];
  Map<String, FolioPageRevision> _legacyById = const {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    widget.session.addListener(_onSessionChanged);
    unawaited(_reload());
  }

  @override
  void dispose() {
    widget.session.removeListener(_onSessionChanged);
    super.dispose();
  }

  void _onSessionChanged() {
    if (!mounted) return;
    unawaited(_reload());
  }

  Future<void> _reload() async {
    final versions = await widget.session.versionsForPage(widget.page.id);
    // Contenido por versión para diffs (v0 memoria o v1 extract de snapshot).
    final byId = <String, FolioPageRevision>{};
    if (widget.session.vaultFormatVersion == 0) {
      for (final r in widget.session.revisionsForPage(widget.page.id)) {
        byId[r.revisionId] = r;
      }
    } else {
      for (final v in versions) {
        final rev = await widget.session.pageContentAtVersion(
          widget.page.id,
          v.versionId,
        );
        if (rev != null) byId[v.versionId] = rev;
      }
    }
    if (!mounted) return;
    setState(() {
      _versions = versions;
      _legacyById = byId;
      _loading = false;
    });
  }

  static String _formatTimestamp(int savedAtMs) {
    final d = DateTime.fromMillisecondsSinceEpoch(savedAtMs);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year} · ${two(d.hour)}:${two(d.minute)}';
  }

  Future<void> _confirmRestore(
    BuildContext screenContext,
    VersionInfo version,
  ) async {
    final l10n = AppLocalizations.of(screenContext);
    final ok = await FolioDialog.confirm(
      screenContext,
      icon: Icon(
        Icons.restore_rounded,
        color: Theme.of(screenContext).colorScheme.primary,
      ),
      title: Text(l10n.restoreVersionTitle),
      content: Text(l10n.restoreVersionBody),
      confirmLabel: l10n.restore,
    );
    if (ok != true || !screenContext.mounted) return;
    final success = await widget.session.restoreVersion(
      widget.page.id,
      version.versionId,
    );
    if (!screenContext.mounted) return;
    if (success) {
      Navigator.pop(screenContext);
    } else {
      ScaffoldMessenger.of(screenContext).showSnackBar(
        SnackBar(content: Text(l10n.restoreVersionFailed)),
      );
    }
  }

  Future<void> _confirmDelete(
    BuildContext screenContext,
    VersionInfo version,
  ) async {
    final l10n = AppLocalizations.of(screenContext);
    final scheme = Theme.of(screenContext).colorScheme;
    final ok = await FolioDialog.confirm(
      screenContext,
      icon: Icon(Icons.delete_outline_rounded, color: scheme.error),
      title: Text(l10n.deleteVersionTitle),
      content: Text(l10n.deleteVersionBody),
      confirmLabel: l10n.delete,
      destructive: true,
    );
    if (ok != true || !screenContext.mounted) return;
    await widget.session.deleteVersion(widget.page.id, version.versionId);
    if (mounted) await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final Widget body;
    if (_loading) {
      body = const Center(child: CircularProgressIndicator());
    } else {
      final items = _versions;
      body = Column(
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
                              l10n.noVersionsYet,
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              l10n.historyAppearsHint,
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
                          final version = items[i];
                          final olderRevision = i + 1 < items.length
                              ? _legacyById[items[i + 1].versionId]
                              : null;
                          final indexLabel = items.length - i;
                          return _VersionCard(
                            version: version,
                            legacyRevision: _legacyById[version.versionId],
                            olderLegacyRevision: olderRevision,
                            indexLabel: indexLabel,
                            timestamp: _formatTimestamp(version.timestamp),
                            scheme: scheme,
                            textTheme: textTheme,
                            onRestore: () => _confirmRestore(context, version),
                            onDelete: () => _confirmDelete(context, version),
                          );
                        },
                      ),
                    ),
                  ),
          ),
        ],
      );
    }

    if (widget.embedded) {
      return Material(
        color: scheme.surface,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.pageHistoryTitle,
                          style: textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.page.title.isEmpty
                              ? l10n.untitledFallback
                              : widget.page.title,
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
                  IconButton(
                    tooltip:
                        MaterialLocalizations.of(context).closeButtonTooltip,
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(child: body),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        toolbarHeight: 72,
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.pageHistoryTitle),
            Text(
              widget.page.title.isEmpty ? l10n.untitledFallback : widget.page.title,
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
      body: body,
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
                  AppLocalizations.of(context).versionControl,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  AppLocalizations.of(context).historyHeaderBody,
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
                      label: AppLocalizations.of(
                        context,
                      ).versionsCount(versionCount),
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

class _VersionCard extends StatelessWidget {
  const _VersionCard({
    required this.version,
    required this.legacyRevision,
    required this.olderLegacyRevision,
    required this.indexLabel,
    required this.timestamp,
    required this.scheme,
    required this.textTheme,
    required this.onRestore,
    required this.onDelete,
  });

  final VersionInfo version;
  final FolioPageRevision? legacyRevision;
  final FolioPageRevision? olderLegacyRevision;
  final int indexLabel;
  final String timestamp;
  final ColorScheme scheme;
  final TextTheme textTheme;
  final VoidCallback onRestore;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final title = legacyRevision != null && legacyRevision!.title.isNotEmpty
        ? legacyRevision!.title
        : version.label;

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
          key: ValueKey(version.versionId),
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
            title.isEmpty ? l10n.untitledFallback : title,
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
                if (version.isSnapshot) ...[
                  const SizedBox(width: 8),
                  Icon(
                    Icons.cloud_outlined,
                    size: 14,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 3),
                  Flexible(
                    child: Text(
                      version.deviceId ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
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
                          legacyRevision == null
                              ? l10n.versionSnapshotNoDiffHint
                              : olderLegacyRevision == null
                                  ? l10n.changesFromEmptyStart
                                  : l10n.comparedWithPrevious,
                          style: textTheme.labelLarge?.copyWith(
                            color: scheme.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (legacyRevision != null) ...[
                    const SizedBox(height: 12),
                    PageRevisionDiffView(
                      newer: legacyRevision!,
                      older: olderLegacyRevision,
                    ),
                  ],
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
                    label: Text(l10n.delete),
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
                    label: Text(l10n.restore),
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
