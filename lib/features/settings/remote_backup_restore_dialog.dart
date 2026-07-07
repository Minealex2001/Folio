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
import '../../session/vault_session.dart';

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

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final dest = await _destinationForSource();
      if (dest == null) {
        setState(() {
          _entries = const [];
          _loading = false;
        });
        return;
      }
      final list = await dest.listZipBackups();
      if (!mounted) return;
      setState(() {
        _entries = list;
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

  Future<File> _downloadToTemp(RemoteBackupEntry entry) async {
    final dest = await _destinationForSource();
    if (dest == null) {
      throw VaultBackupException('No hay destino configurado.');
    }
    final tmp = await Directory.systemTemp.createTemp('folio_remote_restore_');
    final local = File(p.join(tmp.path, entry.name));
    await dest.download(entry.name, local);
    return local;
  }

  Future<void> _downloadEntry(RemoteBackupEntry entry) async {
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
    final password = await _askBackupPassword();
    if (password == null || !mounted) return;
    setState(() => _busyName = entry.name);
    try {
      final local = await _downloadToTemp(entry);
      await widget.session.importVaultBackupAsNew(local.path, password);
      if (mounted) Navigator.pop(context);
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

  Future<void> _importOverwrite(RemoteBackupEntry entry) async {
    final sure = await FolioDialog.confirm(
      context,
      title: Text(widget.l10n.settingsCloudBackupImportOverwriteTitle),
      content: Text(widget.l10n.settingsCloudBackupImportOverwriteBody),
      confirmLabel: widget.l10n.settingsCloudBackupActionImportOverwrite,
    );
    if (sure != true || !mounted) return;
    final password = await _askBackupPassword();
    if (password == null || !mounted) return;
    setState(() => _busyName = entry.name);
    try {
      final local = await _downloadToTemp(entry);
      await widget.session.importVaultBackupOverwriteActive(
        local.path,
        password,
      );
      if (mounted) Navigator.pop(context);
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
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text(_error!));
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
        final subtitle = [
          if (e.modifiedAt != null) e.modifiedAt!.toLocal().toString(),
          if (e.sizeBytes != null) '${e.sizeBytes} B',
        ].join(' · ');
        return ListTile(
          title: Text(e.name),
          subtitle: subtitle.isEmpty ? null : Text(subtitle),
          trailing: busy
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
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
