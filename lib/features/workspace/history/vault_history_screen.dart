import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;

import '../../../app/widgets/folio_dialog.dart';
import '../../../git/vault_snapshot.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../session/vault_session.dart';

/// Abre el historial de TODA la libreta (estilo `git log`) a pantalla completa.
void openVaultHistoryScreen({
  required BuildContext context,
  required VaultSession session,
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
          width: 640,
          height: 720,
          child: VaultHistoryScreen(session: session, embedded: true),
        ),
      ),
    );
    return;
  }

  Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (ctx) => VaultHistoryScreen(session: session),
    ),
  );
}

class VaultHistoryScreen extends StatefulWidget {
  const VaultHistoryScreen({
    super.key,
    required this.session,
    this.embedded = false,
  });

  final VaultSession session;
  final bool embedded;

  @override
  State<VaultHistoryScreen> createState() => _VaultHistoryScreenState();
}

class _VaultHistoryScreenState extends State<VaultHistoryScreen> {
  List<VaultSnapshot> _snapshots = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_reload());
  }

  Future<void> _reload() async {
    final snapshots = await widget.session.listVaultSnapshots();
    if (!mounted) return;
    setState(() {
      _snapshots = snapshots;
      _loading = false;
    });
  }

  static String _formatTimestamp(int createdAtMs) {
    final d = DateTime.fromMillisecondsSinceEpoch(createdAtMs);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year} · ${two(d.hour)}:${two(d.minute)}';
  }

  String _originLabel(AppLocalizations l10n, String? label) {
    switch (label) {
      case 'autosave':
        return l10n.vaultHistoryOriginAutosave;
      case 'cloud-sync':
        return l10n.vaultHistoryOriginCloudSync;
      case 'pre-restore':
        return l10n.vaultHistoryOriginPreRestore;
      case 'post-restore':
        return l10n.vaultHistoryOriginPostRestore;
      default:
        return l10n.vaultHistoryOriginManual;
    }
  }

  Future<void> _confirmRestore(
    BuildContext screenContext,
    VaultSnapshot snapshot,
  ) async {
    final l10n = AppLocalizations.of(screenContext);
    final ok = await FolioDialog.confirm(
      screenContext,
      icon: Icon(
        Icons.restore_rounded,
        color: Theme.of(screenContext).colorScheme.primary,
      ),
      title: Text(l10n.vaultHistoryRestoreTitle),
      content: Text(l10n.vaultHistoryRestoreBody),
      confirmLabel: l10n.restore,
      destructive: true,
    );
    if (ok != true || !screenContext.mounted) return;
    final success = await widget.session.restoreVaultSnapshot(
      snapshot.snapshotId,
    );
    if (!screenContext.mounted) return;
    if (success) {
      await _reload();
      if (screenContext.mounted) Navigator.pop(screenContext);
    } else {
      ScaffoldMessenger.of(screenContext).showSnackBar(
        SnackBar(content: Text(l10n.restoreVersionFailed)),
      );
    }
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
    } else if (_snapshots.isEmpty) {
      body = Center(
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
                    color: scheme.surfaceContainerHighest.withValues(
                      alpha: 0.65,
                    ),
                  ),
                  child: Icon(
                    Icons.history_rounded,
                    size: 40,
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  l10n.vaultHistoryEmptyHint,
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
      );
    } else {
      body = Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            itemCount: _snapshots.length,
            separatorBuilder: (context, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final snapshot = _snapshots[i];
              final indexLabel = _snapshots.length - i;
              return _SnapshotCard(
                indexLabel: indexLabel,
                snapshot: snapshot,
                originLabel: _originLabel(l10n, snapshot.label),
                timestamp: _formatTimestamp(snapshot.createdAtMs),
                pageCount: snapshot.fileManifest
                    .where(
                      (e) => e.path.replaceAll('\\', '/').startsWith('pages/') &&
                          e.path.endsWith('meta.json'),
                    )
                    .length,
                scheme: scheme,
                textTheme: textTheme,
                onRestore: () => _confirmRestore(context, snapshot),
              );
            },
          ),
        ),
      );
    }

    if (widget.embedded) {
      return Material(
        color: scheme.surface,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 12, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.vaultHistoryTitle,
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
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
      appBar: AppBar(title: Text(l10n.vaultHistoryTitle)),
      body: body,
    );
  }
}

class _SnapshotCard extends StatelessWidget {
  const _SnapshotCard({
    required this.indexLabel,
    required this.snapshot,
    required this.originLabel,
    required this.timestamp,
    required this.pageCount,
    required this.scheme,
    required this.textTheme,
    required this.onRestore,
  });

  final int indexLabel;
  final VaultSnapshot snapshot;
  final String originLabel;
  final String timestamp;
  final int pageCount;
  final ColorScheme scheme;
  final TextTheme textTheme;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Material(
      color: scheme.surfaceContainerLow.withValues(alpha: 0.65),
      elevation: 0,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.65)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 36,
              height: 36,
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
                    child: const SizedBox(width: 32, height: 32),
                  ),
                  Text(
                    '$indexLabel',
                    style: textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: scheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          originLabel,
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        l10n.vaultHistoryPageCount(pageCount),
                        style: textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
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
                      const SizedBox(width: 8),
                      Icon(
                        Icons.devices_other_rounded,
                        size: 14,
                        color: scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          snapshot.deviceId,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: l10n.restore,
              onPressed: onRestore,
              icon: const Icon(Icons.restore_rounded),
            ),
          ],
        ),
      ),
    );
  }
}
