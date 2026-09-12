import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/ui_tokens.dart';
import '../../app/widgets/folio_dialog.dart';
import '../../data/vault_entry.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../session/vault_session.dart';

/// Papelera de libretas: restaurar o eliminar definitivamente, incluidas las
/// borradas en otro dispositivo que este nunca llegó a materializar.
Future<void> showVaultTrashSheet({
  required BuildContext context,
  required VaultSession session,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) {
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.55,
        minChildSize: 0.35,
        maxChildSize: 0.9,
        builder: (context, scrollController) {
          return _VaultTrashSheetBody(
            session: session,
            scrollController: scrollController,
          );
        },
      );
    },
  );
}

class _VaultTrashSheetBody extends StatefulWidget {
  const _VaultTrashSheetBody({
    required this.session,
    required this.scrollController,
  });

  final VaultSession session;
  final ScrollController scrollController;

  @override
  State<_VaultTrashSheetBody> createState() => _VaultTrashSheetBodyState();
}

class _VaultTrashSheetBodyState extends State<_VaultTrashSheetBody> {
  List<VaultTrashEntry>? _entries;
  bool _loading = true;
  String? _busyVaultId;

  @override
  void initState() {
    super.initState();
    widget.session.addListener(_onSessionChanged);
    unawaited(_load());
  }

  @override
  void dispose() {
    widget.session.removeListener(_onSessionChanged);
    super.dispose();
  }

  void _onSessionChanged() {
    if (!mounted) return;
    unawaited(_load());
  }

  Future<void> _load() async {
    final entries = await widget.session.loadTrashedVaultEntries();
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _loading = false;
    });
  }

  int _daysLeft(VaultTrashEntry e) {
    final expires = e.trashedAt.toUtc().add(VaultSession.vaultTrashRetention);
    final left = expires.difference(DateTime.now().toUtc()).inDays;
    return left < 0 ? 0 : left;
  }

  Future<void> _restore(VaultTrashEntry e) async {
    setState(() => _busyVaultId = e.vaultId);
    try {
      await widget.session.restoreVault(e.vaultId);
    } catch (_) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.vaultTrashRestoreFailed)));
      }
    } finally {
      if (mounted) setState(() => _busyVaultId = null);
    }
    await _load();
  }

  Future<void> _confirmEmpty(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => FolioDialog(
        title: Text(l10n.vaultTrashEmptyAction),
        content: Text(l10n.vaultTrashEmptyConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: scheme.error,
              foregroundColor: scheme.onError,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.vaultTrashEmptyAction),
          ),
        ],
      ),
    );
    if (ok == true) {
      await widget.session.emptyVaultTrash();
      await _load();
    }
  }

  Future<void> _confirmDeleteForever(
    BuildContext context,
    VaultTrashEntry e,
  ) async {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final title = e.displayName.trim().isEmpty
        ? l10n.untitledFallback
        : e.displayName.trim();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => FolioDialog(
        title: Text(l10n.vaultTrashDeleteForever),
        content: Text(l10n.vaultTrashDeleteForeverConfirm(title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: scheme.error,
              foregroundColor: scheme.onError,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.vaultTrashDeleteForever),
          ),
        ],
      ),
    );
    if (ok == true) {
      await widget.session.permanentlyDeleteVault(e.vaultId);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final entries = _entries ?? const [];

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              FolioSpace.lg,
              FolioSpace.sm,
              FolioSpace.sm,
              FolioSpace.xs,
            ),
            child: Row(
              children: [
                Icon(Icons.delete_outline_rounded, color: scheme.onSurface),
                const SizedBox(width: FolioSpace.sm),
                Expanded(
                  child: Text(
                    l10n.vaultTrashTitle,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (entries.isNotEmpty)
                  TextButton(
                    onPressed: () => _confirmEmpty(context),
                    child: Text(l10n.vaultTrashEmptyAction),
                  ),
                IconButton(
                  tooltip: l10n.sidebarTrashClose,
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              FolioSpace.lg,
              0,
              FolioSpace.lg,
              FolioSpace.sm,
            ),
            child: Text(
              l10n.vaultTrashRetentionHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : entries.isEmpty
                ? Center(
                    child: Text(
                      l10n.vaultTrashEmpty,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: widget.scrollController,
                    padding: const EdgeInsets.fromLTRB(
                      FolioSpace.sm,
                      0,
                      FolioSpace.sm,
                      FolioSpace.lg,
                    ),
                    itemCount: entries.length,
                    itemBuilder: (context, index) {
                      final e = entries[index];
                      final title = e.displayName.trim().isEmpty
                          ? l10n.untitledFallback
                          : e.displayName.trim();
                      final days = _daysLeft(e);
                      final busy = _busyVaultId == e.vaultId;
                      final subtitle = e.hasLocalCopy
                          ? l10n.vaultTrashDaysLeft(days)
                          : '${l10n.vaultTrashDaysLeft(days)} · '
                                '${l10n.vaultTrashNotOnThisDevice}';
                      return ListTile(
                        leading: Icon(
                          Icons.folder_delete_outlined,
                          color: scheme.onSurfaceVariant,
                        ),
                        title: Text(title),
                        subtitle: Text(subtitle),
                        trailing: busy
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  TextButton(
                                    onPressed: () => _restore(e),
                                    child: Text(l10n.vaultTrashRestore),
                                  ),
                                  IconButton(
                                    tooltip: l10n.vaultTrashDeleteForever,
                                    onPressed: () =>
                                        _confirmDeleteForever(context, e),
                                    icon: Icon(
                                      Icons.delete_forever_outlined,
                                      color: scheme.error,
                                    ),
                                  ),
                                ],
                              ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
