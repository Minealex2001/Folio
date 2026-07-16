import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../app/app_settings.dart';
import '../../app/widgets/folio_dialog.dart';
import '../../app/widgets/folio_password_field.dart';
import '../../data/vault_backup.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../services/backup_destinations/backup_destination.dart';
import '../../services/backup_destinations/backup_export_runner.dart';
import '../../services/secure_credential_storage.dart';
import '../../services/vault_pack/vault_pack_destinations.dart';
import '../../services/vault_pack/vault_pack_sync.dart';
import '../../services/vault_pack/vault_pack_transport.dart';
import '../../session/vault_session.dart';
import '../../app/widgets/folio_skeletons.dart';
import '../../app/widgets/folio_error_card.dart';

enum _RemoteBackupRestoreSource { folder, webdav }

/// Lista copias en NAS/carpeta/WebDAV y permite descargar o importar.
class RemoteBackupRestoreDialog extends StatefulWidget {
  const RemoteBackupRestoreDialog({
    super.key,
    required this.l10n,
    required this.session,
    required this.prefs,
    required this.vaultId,
    required this.credentials,
  });

  final AppLocalizations l10n;
  final VaultSession session;
  final VaultBackupPrefs prefs;
  final String vaultId;
  final SecureCredentialStorage credentials;

  static Future<void> show(
    BuildContext context, {
    required AppLocalizations l10n,
    required VaultSession session,
    required VaultBackupPrefs prefs,
    required String vaultId,
    required SecureCredentialStorage credentials,
  }) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => RemoteBackupRestoreDialog(
        l10n: l10n,
        session: session,
        prefs: prefs,
        vaultId: vaultId,
        credentials: credentials,
      ),
    );
  }

  @override
  State<RemoteBackupRestoreDialog> createState() =>
      _RemoteBackupRestoreDialogState();
}

class _RemoteBackupRestoreDialogState extends State<RemoteBackupRestoreDialog> {
  _RemoteBackupRestoreSource _source = _RemoteBackupRestoreSource.folder;
  bool _loading = true;
  String? _error;
  List<RemoteBackupEntry> _entries = const [];
  String? _busyName;

  @override
  void initState() {
    super.initState();
    if (widget.prefs.hasConfiguredWebDav && !widget.prefs.hasConfiguredFolder) {
      _source = _RemoteBackupRestoreSource.webdav;
    }
    unawaited(_reload());
  }

  Future<BackupDestination?> _destinationForSource() async {
    if (_source == _RemoteBackupRestoreSource.folder) {
      return VaultBackupDestinations.configuredFolder(
        prefs: widget.prefs,
        vaultId: widget.vaultId,
        credentials: widget.credentials,
      );
    }
    return VaultBackupDestinations.configuredWebDav(
      prefs: widget.prefs,
      vaultId: widget.vaultId,
      credentials: widget.credentials,
    );
  }

  Future<VaultPackTransport?> _packTransportForEntry(
    RemoteBackupEntry entry,
  ) async {
    final packVaultId =
        (entry.packVaultId ?? vaultIdFromPackListEntryName(entry.name) ?? '')
            .trim();
    if (packVaultId.isEmpty) return null;
    if (_source == _RemoteBackupRestoreSource.folder) {
      return VaultPackDestinations.folderTransport(
        prefs: widget.prefs,
        vaultId: packVaultId,
        credentials: widget.credentials,
      );
    }
    return VaultPackDestinations.webdavTransport(
      prefs: widget.prefs,
      vaultId: packVaultId,
      credentials: widget.credentials,
    );
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final hasDest = _source == _RemoteBackupRestoreSource.folder
          ? widget.prefs.hasConfiguredFolder
          : widget.prefs.hasConfiguredWebDav;
      if (!hasDest) {
        setState(() {
          _entries = const [];
          _loading = false;
        });
        return;
      }

      final zips = <RemoteBackupEntry>[];
      final dest = await _destinationForSource();
      if (dest != null) {
        zips.addAll(await dest.listZipBackups());
      }

      final packs = _source == _RemoteBackupRestoreSource.folder
          ? await listFolderPackBackupEntries(
              prefs: widget.prefs,
              vaultId: widget.vaultId,
              credentials: widget.credentials,
            )
          : await listWebDavPackBackupEntries(
              prefs: widget.prefs,
              vaultId: widget.vaultId,
              credentials: widget.credentials,
            );

      final merged = <RemoteBackupEntry>[...packs, ...zips];
      merged.sort((a, b) {
        final am = a.modifiedAt?.millisecondsSinceEpoch ?? 0;
        final bm = b.modifiedAt?.millisecondsSinceEpoch ?? 0;
        return bm.compareTo(am);
      });

      if (!mounted) return;
      setState(() {
        _entries = merged;
        _loading = false;
      });
    } on VaultBackupException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<File> _downloadZipToTemp(RemoteBackupEntry entry) async {
    final dest = await _destinationForSource();
    if (dest == null) {
      throw VaultBackupException('No hay destino configurado.');
    }
    final tmp = await Directory.systemTemp.createTemp('folio_remote_restore_');
    final local = File(p.join(tmp.path, entry.name));
    await dest.download(entry.name, local);
    return local;
  }

  String? _lastAskedPassword;

  Future<Directory> _materializePackToTemp(RemoteBackupEntry entry) async {
    final transport = await _packTransportForEntry(entry);
    if (transport == null) {
      throw VaultBackupException('No hay pack incremental configurado.');
    }
    final password = await _askBackupPassword();
    if (password == null) {
      throw VaultBackupException('Restore cancelled');
    }
    _lastAskedPassword = password;
    final extract = await Directory.systemTemp.createTemp(
      'folio_pack_restore_',
    );
    await downloadVaultPackToDirectoryForRestore(
      transport: transport,
      restorePassword: password,
      extractDir: extract,
    );
    return extract;
  }

  Future<void> _downloadEntry(RemoteBackupEntry entry) async {
    if (entry.isIncrementalPack) return;
    setState(() => _busyName = entry.name);
    try {
      final savePath = await FilePicker.saveFile(
        dialogTitle: widget.l10n.remoteBackupRestoreDownload,
        fileName: entry.name,
        type: FileType.custom,
        allowedExtensions: const ['zip'],
      );
      if (savePath == null) return;
      final dest = await _destinationForSource();
      if (dest == null) return;
      await dest.download(entry.name, File(savePath));
    } on VaultBackupException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busyName = null);
    }
  }

  Future<String?> _askBackupPassword() async {
    final ctrl = TextEditingController();
    var obscure = true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => FolioDialog(
          title: Text(widget.l10n.backupPasswordDialogTitle),
          content: FolioPasswordField(
            controller: ctrl,
            labelText: widget.l10n.passwordLabel,
            obscureText: obscure,
            onToggleObscure: () => setSt(() => obscure = !obscure),
            showPasswordTooltip: widget.l10n.showPassword,
            hidePasswordTooltip: widget.l10n.hidePassword,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(widget.l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(widget.l10n.continueAction),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return null;
    return ctrl.text;
  }

  Future<void> _importAsNew(RemoteBackupEntry entry) async {
    setState(() => _busyName = entry.name);
    try {
      if (entry.isIncrementalPack) {
        _lastAskedPassword = null;
        final extract = await _materializePackToTemp(entry);
        try {
          final password = _lastAskedPassword;
          if (password == null || !mounted) return;
          await widget.session.importVaultBackupAsNewFromExtractedDir(
            extract,
            password,
          );
        } finally {
          try {
            if (extract.existsSync()) {
              await extract.delete(recursive: true);
            }
          } catch (_) {}
        }
      } else {
        final password = await _askBackupPassword();
        if (password == null || !mounted) return;
        final local = await _downloadZipToTemp(entry);
        await widget.session.importVaultBackupAsNew(local.path, password);
      }
      if (mounted) Navigator.pop(context);
    } on VaultBackupException catch (e) {
      if ('$e'.contains('Restore cancelled')) return;
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      _lastAskedPassword = null;
      if (mounted) setState(() => _busyName = null);
    }
  }

  Future<void> _importOverwrite(RemoteBackupEntry entry) async {
    final sure = await FolioDialog.confirm(
      context,
      title: Text(widget.l10n.settingsCloudBackupImportOverwriteTitle),
      content: Text(widget.l10n.settingsCloudBackupImportOverwriteBody),
      confirmLabel: widget.l10n.settingsCloudBackupActionImportOverwrite,
    );
    if (sure != true || !mounted) return;
    setState(() => _busyName = entry.name);
    try {
      if (entry.isIncrementalPack) {
        _lastAskedPassword = null;
        final extract = await _materializePackToTemp(entry);
        try {
          final password = _lastAskedPassword;
          if (password == null || !mounted) return;
          await widget.session.importVaultBackupOverwriteActiveFromExtractedDir(
            extract,
            password,
          );
        } finally {
          try {
            if (extract.existsSync()) {
              await extract.delete(recursive: true);
            }
          } catch (_) {}
        }
      } else {
        final password = await _askBackupPassword();
        if (password == null || !mounted) return;
        final local = await _downloadZipToTemp(entry);
        await widget.session.importVaultBackupOverwriteActive(
          local.path,
          password,
        );
      }
      if (mounted) Navigator.pop(context);
    } on VaultBackupException catch (e) {
      if ('$e'.contains('Restore cancelled')) return;
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      _lastAskedPassword = null;
      if (mounted) setState(() => _busyName = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    return FolioDialog(
      title: Text(l10n.remoteBackupRestoreTitle),
      contentWidth: 560,
      content: SizedBox(
        width: 520,
        height: 420,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.prefs.hasConfiguredFolder &&
                widget.prefs.hasConfiguredWebDav)
              SegmentedButton<_RemoteBackupRestoreSource>(
                segments: [
                  ButtonSegment(
                    value: _RemoteBackupRestoreSource.folder,
                    label: Text(l10n.remoteBackupRestoreFromFolder),
                  ),
                  ButtonSegment(
                    value: _RemoteBackupRestoreSource.webdav,
                    label: Text(l10n.remoteBackupRestoreFromWebdav),
                  ),
                ],
                selected: {_source},
                onSelectionChanged: (s) {
                  setState(() => _source = s.first);
                  unawaited(_reload());
                },
              ),
            const SizedBox(height: 8),
            Expanded(child: _buildBody(l10n)),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.remoteBackupDialogClose),
        ),
        TextButton(
          onPressed: _loading ? null : _reload,
          child: Text(l10n.remoteBackupDialogRefresh),
        ),
      ],
    );
  }

  Widget _buildBody(AppLocalizations l10n) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 8),
        child: FolioSkeletonList(),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: FolioErrorCard(
          title: l10n.remoteBackupRestoreTitle,
          message: _error!,
          icon: Icons.backup_outlined,
          onRetry: _reload,
        ),
      );
    }
    if (_entries.isEmpty) {
      return Center(child: Text(l10n.remoteBackupRestoreEmpty));
    }
    return ListView.separated(
      itemCount: _entries.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final e = _entries[index];
        final busy = _busyName == e.name;
        final title = e.isIncrementalPack
            ? l10n.remoteBackupRestoreIncrementalPackTitle(
                e.packVaultId ?? e.name,
              )
            : e.name;
        final subtitle = [
          if (e.isIncrementalPack) l10n.remoteBackupRestoreIncrementalPackSubtitle,
          if (e.modifiedAt != null) e.modifiedAt!.toLocal().toString(),
          if (e.sizeBytes != null) '${e.sizeBytes} B',
        ].join(' · ');
        return ListTile(
          title: Text(title),
          subtitle: subtitle.isEmpty ? null : Text(subtitle),
          trailing: busy
              ? const FolioLoadingIndicator(size: FolioLoadingSize.small)
              : PopupMenuButton<String>(
                  onSelected: (action) {
                    switch (action) {
                      case 'download':
                        unawaited(_downloadEntry(e));
                      case 'new':
                        unawaited(_importAsNew(e));
                      case 'overwrite':
                        unawaited(_importOverwrite(e));
                    }
                  },
                  itemBuilder: (ctx) => [
                    if (!e.isIncrementalPack)
                      PopupMenuItem(
                        value: 'download',
                        child: Text(l10n.remoteBackupRestoreDownload),
                      ),
                    PopupMenuItem(
                      value: 'new',
                      child: Text(l10n.remoteBackupRestoreImportNew),
                    ),
                    PopupMenuItem(
                      value: 'overwrite',
                      child: Text(l10n.remoteBackupRestoreImportOverwrite),
                    ),
                  ],
                ),
        );
      },
    );
  }
}
