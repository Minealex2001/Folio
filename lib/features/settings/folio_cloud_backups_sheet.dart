import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../app/app_settings.dart';
import '../../app/ui_tokens.dart';
import '../../app/widgets/folio_dialog.dart';
import '../../app/widgets/folio_password_field.dart';
import '../../app/widgets/folio_skeletons.dart';
import '../../data/vault_backup.dart';
import '../../data/vault_paths.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../services/folio_cloud/folio_cloud_backup.dart';
import '../../services/folio_cloud/folio_cloud_entitlements.dart';
import '../../services/folio_cloud/folio_cloud_pack_sync.dart';
import '../../services/platform/browser_file_download.dart';
import '../../session/vault_session.dart';

/// Gestión de copias Folio Cloud (listar / importar / descargar / borrar),
/// con UI tipo papelera.
Future<void> showFolioCloudBackupsSheet({
  required BuildContext context,
  required FolioCloudSnapshot entitlementSnapshot,
  required VaultSession session,
  required AppSettings telemetrySettings,
  required List<FolioCloudBackupVaultEntry> vaults,
  required String initialVaultId,
  required List<FolioCloudBackupEntry> initialEntries,
  required String Function(int bytes) formatByteSize,
  required Future<bool> Function() verifyAccount,
  required void Function(String message) onSnack,
  required Future<void> Function() onQuotaChanged,
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
          return _FolioCloudBackupsSheetBody(
            entitlementSnapshot: entitlementSnapshot,
            session: session,
            telemetrySettings: telemetrySettings,
            vaults: vaults,
            initialVaultId: initialVaultId,
            initialEntries: initialEntries,
            formatByteSize: formatByteSize,
            verifyAccount: verifyAccount,
            onSnack: onSnack,
            onQuotaChanged: onQuotaChanged,
            scrollController: scrollController,
          );
        },
      );
    },
  );
}

class _FolioCloudBackupsSheetBody extends StatefulWidget {
  const _FolioCloudBackupsSheetBody({
    required this.entitlementSnapshot,
    required this.session,
    required this.telemetrySettings,
    required this.vaults,
    required this.initialVaultId,
    required this.initialEntries,
    required this.formatByteSize,
    required this.verifyAccount,
    required this.onSnack,
    required this.onQuotaChanged,
    required this.scrollController,
  });

  final FolioCloudSnapshot entitlementSnapshot;
  final VaultSession session;
  final AppSettings telemetrySettings;
  final List<FolioCloudBackupVaultEntry> vaults;
  final String initialVaultId;
  final List<FolioCloudBackupEntry> initialEntries;
  final String Function(int bytes) formatByteSize;
  final Future<bool> Function() verifyAccount;
  final void Function(String message) onSnack;
  final Future<void> Function() onQuotaChanged;
  final ScrollController scrollController;

  @override
  State<_FolioCloudBackupsSheetBody> createState() =>
      _FolioCloudBackupsSheetBodyState();
}

class _FolioCloudBackupsSheetBodyState
    extends State<_FolioCloudBackupsSheetBody> {
  late String _selectedVaultId;
  late List<FolioCloudBackupEntry> _entries;
  late List<FolioCloudBackupVaultEntry> _vaults;
  var _loading = false;
  String? _busyKey;

  FolioCloudSnapshot get _snap => widget.entitlementSnapshot;

  @override
  void initState() {
    super.initState();
    _selectedVaultId = widget.initialVaultId;
    _entries = List<FolioCloudBackupEntry>.from(widget.initialEntries);
    _vaults = List<FolioCloudBackupVaultEntry>.from(widget.vaults);
  }

  Future<void> _switchVault(String vaultId) async {
    setState(() {
      _selectedVaultId = vaultId;
      _loading = true;
    });
    try {
      final newEntries = vaultId.isEmpty
          ? const <FolioCloudBackupEntry>[]
          : await listFolioCloudBackups(
              vaultId: vaultId,
              entitlementSnapshot: _snap,
            );
      if (!mounted) return;
      setState(() {
        _entries = newEntries;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _refreshVaultList({String? preferVaultId}) async {
    final vaults = await listFolioCloudBackupVaults(
      entitlementSnapshot: _snap,
    );
    if (!mounted) return;
    final prefer = preferVaultId?.trim() ?? '';
    final nextId = vaults.any((v) => v.vaultId == prefer)
        ? prefer
        : (vaults.isNotEmpty ? vaults.first.vaultId : '');
    setState(() => _vaults = vaults);
    await _switchVault(nextId);
  }

  Future<void> _confirmDelete(FolioCloudBackupEntry entry) async {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => FolioDialog(
        title: Text(l10n.delete),
        content: Text(
          entry.isCloudPack
              ? l10n.settingsCloudBackupDeleteCloudPackWarning
              : l10n.settingsCloudBackupDeleteWarning,
        ),
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
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final key = entry.storagePath;
    final deletedVaultId = _selectedVaultId;
    setState(() => _busyKey = key);
    try {
      final vaultRemoved = await deleteFolioCloudBackup(
        entry: entry,
        vaultId: deletedVaultId,
        entitlementSnapshot: _snap,
      );
      if (!mounted) return;
      if (vaultRemoved) {
        await _refreshVaultList();
        widget.onSnack(l10n.settingsCloudBackupVaultRemovedSnack);
      } else {
        await _switchVault(deletedVaultId);
        widget.onSnack(l10n.settingsCloudBackupDeletedSnack);
      }
      await widget.onQuotaChanged();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busyKey = null);
    }
  }

  Future<void> _download(FolioCloudBackupEntry entry) async {
    final l10n = AppLocalizations.of(context);
    if (entry.isCloudPack) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.folioCloudBackupPackNoDownload)),
      );
      return;
    }
    final verified = await widget.verifyAccount();
    if (!verified || !mounted) return;

    final key = entry.storagePath;
    setState(() => _busyKey = key);
    try {
      if (kIsWeb) {
        final bytes = await downloadFolioCloudBackupBytes(
          entry: entry,
          entitlementSnapshot: _snap,
        );
        if (!mounted) return;
        folioTriggerBrowserDownload(entry.fileName, bytes);
      } else {
        final path = await FilePicker.saveFile(
          dialogTitle: l10n.settingsCloudBackupSaveDialogTitle,
          fileName: entry.fileName,
        );
        if (path == null || !mounted) return;
        await downloadFolioCloudBackup(
          entry: entry,
          destinationFile: File(path),
          entitlementSnapshot: _snap,
        );
      }
      if (!mounted) return;
      widget.onSnack(l10n.settingsCloudBackupDownloadedSnack);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busyKey = null);
    }
  }

  Future<void> _importOverwrite(FolioCloudBackupEntry entry) async {
    final l10n = AppLocalizations.of(context);
    if (!widget.session.isUnlocked) {
      widget.onSnack(l10n.settingsCloudBackupVaultMustBeUnlocked);
      return;
    }
    final verified = await widget.verifyAccount();
    if (!verified || !mounted) return;

    final sure = await FolioDialog.confirm(
      context,
      title: Text(l10n.settingsCloudBackupImportOverwriteTitle),
      content: Text(l10n.settingsCloudBackupImportOverwriteBody),
      confirmLabel: l10n.settingsCloudBackupActionImportOverwrite,
    );
    if (sure != true || !mounted) return;

    final key = entry.storagePath;
    setState(() => _busyKey = key);

    final tmpDir = await Directory.systemTemp.createTemp(
      'folio_cloud_import_',
    );
    final localPath = p.join(tmpDir.path, entry.fileName);
    final localFile = File(localPath);
    try {
      var password = '';
      if (entry.isCloudPack) {
        final extract = Directory(p.join(tmpDir.path, 'vault_extract'));
        await extract.create(recursive: true);
        final activeId = widget.session.activeVaultId?.trim() ?? '';
        final sameCloudVault = _selectedVaultId == activeId;
        if (!sameCloudVault) {
          if (!mounted) return;
          final ctrl = TextEditingController();
          var obscure = true;
          final ok = await showDialog<bool>(
            context: context,
            builder: (dCtx) => StatefulBuilder(
              builder: (dCtx, setSt2) => FolioDialog(
                title: Text(l10n.backupPasswordDialogTitle),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(l10n.settingsCloudBackupImportRemoteCloudPackIntro),
                      const SizedBox(height: 12),
                      FolioPasswordField(
                        controller: ctrl,
                        labelText: l10n.passwordLabel,
                        obscureText: obscure,
                        onToggleObscure: () =>
                            setSt2(() => obscure = !obscure),
                        showPasswordTooltip: l10n.showPassword,
                        hidePasswordTooltip: l10n.hidePassword,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.cloudPackRestorePasswordHelper,
                        style: Theme.of(dCtx).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dCtx, false),
                    child: Text(l10n.cancel),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(dCtx, true),
                    child: Text(l10n.settingsCloudBackupActionImportOverwrite),
                  ),
                ],
              ),
            ),
          );
          password = ctrl.text;
          ctrl.dispose();
          if (ok != true) return;
          await downloadCloudPackToDirectoryForRestore(
            vaultId: _selectedVaultId,
            restorePassword: password,
            extractDir: extract,
            entitlementSnapshot: _snap,
            telemetrySettings: widget.telemetrySettings,
          );
        } else {
          await downloadLatestCloudPackToDirectory(
            session: widget.session,
            vaultId: _selectedVaultId,
            extractDir: extract,
            entitlementSnapshot: _snap,
            telemetrySettings: widget.telemetrySettings,
          );
          final modeFile = File(
            p.join(extract.path, VaultPaths.vaultModeFile),
          );
          final isPlain =
              modeFile.existsSync() &&
              modeFile.readAsStringSync().trim().toLowerCase() == 'plain';
          if (!isPlain) {
            if (!mounted) return;
            final ctrl = TextEditingController();
            var obscure = true;
            final ok = await showDialog<bool>(
              context: context,
              builder: (dCtx) => StatefulBuilder(
                builder: (dCtx, setSt2) => FolioDialog(
                  title: Text(l10n.backupPasswordDialogTitle),
                  content: FolioPasswordField(
                    controller: ctrl,
                    labelText: l10n.passwordLabel,
                    obscureText: obscure,
                    onToggleObscure: () => setSt2(() => obscure = !obscure),
                    showPasswordTooltip: l10n.showPassword,
                    hidePasswordTooltip: l10n.hidePassword,
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dCtx, false),
                      child: Text(l10n.cancel),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(dCtx, true),
                      child: Text(
                        l10n.settingsCloudBackupActionImportOverwrite,
                      ),
                    ),
                  ],
                ),
              ),
            );
            password = ctrl.text;
            ctrl.dispose();
            if (ok != true || password.trim().isEmpty) return;
          }
        }
        await widget.session.importVaultBackupOverwriteActiveFromExtractedDir(
          extract,
          password,
        );
      } else {
        await downloadFolioCloudBackup(
          entry: entry,
          destinationFile: localFile,
          entitlementSnapshot: _snap,
        );
        final isPlain = await isPlainBackupArchive(localFile);
        if (!isPlain) {
          if (!mounted) return;
          final ctrl = TextEditingController();
          var obscure = true;
          final ok = await showDialog<bool>(
            context: context,
            builder: (dCtx) => StatefulBuilder(
              builder: (dCtx, setSt2) => FolioDialog(
                title: Text(l10n.backupPasswordDialogTitle),
                content: FolioPasswordField(
                  controller: ctrl,
                  labelText: l10n.passwordLabel,
                  obscureText: obscure,
                  onToggleObscure: () => setSt2(() => obscure = !obscure),
                  showPasswordTooltip: l10n.showPassword,
                  hidePasswordTooltip: l10n.hidePassword,
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dCtx, false),
                    child: Text(l10n.cancel),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(dCtx, true),
                    child: Text(l10n.settingsCloudBackupActionImportOverwrite),
                  ),
                ],
              ),
            ),
          );
          password = ctrl.text;
          ctrl.dispose();
          if (ok != true || password.trim().isEmpty) return;
        }
        await widget.session.importVaultBackupOverwriteActive(
          localFile.path,
          password,
        );
      }
      if (!mounted) return;
      Navigator.pop(context);
      widget.onSnack(l10n.settingsCloudBackupImportedSnack);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      try {
        if (tmpDir.existsSync()) {
          await tmpDir.delete(recursive: true);
        }
      } catch (_) {}
      if (mounted) setState(() => _busyKey = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final totalBytes = _entries.fold<int>(
      0,
      (a, e) => a + (e.sizeBytes > 0 ? e.sizeBytes : 0),
    );

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
                Icon(Icons.cloud_outlined, color: scheme.onSurface),
                const SizedBox(width: FolioSpace.sm),
                Expanded(
                  child: Text(
                    l10n.settingsCloudBackupsSheetTitle,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.settingsCloudBackupsManageHint,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                if (_entries.isNotEmpty) ...[
                  const SizedBox(height: FolioSpace.xs),
                  Text(
                    l10n.settingsCloudBackupsTotalLabel(
                      widget.formatByteSize(totalBytes),
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (_vaults.length > 1) ...[
                  const SizedBox(height: FolioSpace.sm),
                  DropdownButtonFormField<String>(
                    key: ValueKey('cloud_backups_vault_$_selectedVaultId'),
                    initialValue: _selectedVaultId.isNotEmpty &&
                            _vaults.any((v) => v.vaultId == _selectedVaultId)
                        ? _selectedVaultId
                        : null,
                    decoration: InputDecoration(
                      labelText: l10n.settingsCloudBackupsVaultLabel,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      border: const OutlineInputBorder(),
                    ),
                    isExpanded: true,
                    items: _vaults.map((v) {
                      final name = v.displayName.isNotEmpty
                          ? v.displayName
                          : v.vaultId;
                      return DropdownMenuItem(
                        value: v.vaultId,
                        child: Text(name, overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: _loading
                        ? null
                        : (v) {
                            if (v != null && v != _selectedVaultId) {
                              unawaited(_switchVault(v));
                            }
                          },
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const FolioLoadingIndicator(centered: true)
                : _entries.isEmpty
                    ? Center(
                        child: Text(
                          l10n.settingsCloudBackupsEmpty,
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
                        itemCount: _entries.length,
                        itemBuilder: (context, index) {
                          final e = _entries[index];
                          final sizeLabel = e.sizeBytes > 0
                              ? widget.formatByteSize(e.sizeBytes)
                              : '—';
                          final whenRaw = e.createdAt.trim();
                          final when = whenRaw.isNotEmpty ? whenRaw : '—';
                          final busy = _busyKey == e.storagePath;
                          return ListTile(
                            leading: Icon(
                              e.isCloudPack
                                  ? Icons.cloud_sync_outlined
                                  : Icons.inventory_2_outlined,
                              color: scheme.onSurfaceVariant,
                            ),
                            title: Text(
                              e.isCloudPack
                                  ? l10n.folioCloudBackupTypeIncremental
                                  : e.fileName,
                              style: TextStyle(
                                fontFamily: e.isCloudPack ? null : 'monospace',
                                fontWeight: e.isCloudPack
                                    ? FontWeight.w700
                                    : null,
                              ),
                            ),
                            subtitle: Text(
                              e.isCloudPack
                                  ? '${e.fileName} · $sizeLabel · $when'
                                  : '$sizeLabel · $when',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
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
                                      if (!e.isCloudPack)
                                        IconButton(
                                          tooltip: l10n
                                              .settingsCloudBackupDownloadTooltip,
                                          onPressed: () =>
                                              unawaited(_download(e)),
                                          icon: const Icon(
                                            Icons.download_outlined,
                                          ),
                                        ),
                                      TextButton(
                                        onPressed: () =>
                                            unawaited(_importOverwrite(e)),
                                        child: Text(
                                          l10n
                                              .settingsCloudBackupActionImportOverwrite,
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: l10n
                                            .settingsCloudBackupDeleteTooltip,
                                        onPressed: () =>
                                            unawaited(_confirmDelete(e)),
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
