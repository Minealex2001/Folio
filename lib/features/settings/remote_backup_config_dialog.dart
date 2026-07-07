import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_settings.dart';
import '../../app/widgets/folio_dialog.dart';
import '../../app/widgets/folio_password_field.dart';
import '../../data/vault_backup.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../services/backup_destinations/local_folder_destination.dart';
import '../../services/backup_destinations/smb_network_auth.dart';
import '../../services/backup_destinations/webdav_destination.dart';
import '../../services/secure_credential_storage.dart';

/// Diálogo unificado para configurar carpeta de red (SMB/UNC) y WebDAV.
class RemoteBackupConfigDialog extends StatefulWidget {
  const RemoteBackupConfigDialog({
    super.key,
    required this.l10n,
    required this.initialPrefs,
    required this.vaultId,
    required this.credentials,
    this.initialTab = 0,
  });

  final AppLocalizations l10n;
  final VaultBackupPrefs initialPrefs;
  final String vaultId;
  final SecureCredentialStorage credentials;
  final int initialTab;

  static Future<VaultBackupPrefs?> show(
    BuildContext context, {
    required AppLocalizations l10n,
    required VaultBackupPrefs initialPrefs,
    required String vaultId,
    required SecureCredentialStorage credentials,
    int initialTab = 0,
  }) {
    return showDialog<VaultBackupPrefs>(
      context: context,
      builder: (ctx) => RemoteBackupConfigDialog(
        l10n: l10n,
        initialPrefs: initialPrefs,
        vaultId: vaultId,
        credentials: credentials,
        initialTab: initialTab,
      ),
    );
  }

  @override
  State<RemoteBackupConfigDialog> createState() =>
      _RemoteBackupConfigDialogState();
}

class _RemoteBackupConfigDialogState extends State<RemoteBackupConfigDialog>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  late final TextEditingController _folderPathCtrl;
  late final TextEditingController _folderUserCtrl;
  late final TextEditingController _folderDomainCtrl;
  late final TextEditingController _folderPasswordCtrl;
  late final TextEditingController _webdavUrlCtrl;
  late final TextEditingController _webdavPathCtrl;
  late final TextEditingController _webdavUserCtrl;
  late final TextEditingController _webdavPasswordCtrl;
  late final TextEditingController _retentionCtrl;

  bool _folderRequiresAuth = false;
  bool _folderPasswordObscure = true;
  bool _webdavPasswordObscure = true;
  bool _testing = false;
  String? _statusMessage;
  bool _statusOk = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 1),
    );
    final p = widget.initialPrefs;
    _folderPathCtrl = TextEditingController(text: p.directory);
    _folderUserCtrl = TextEditingController(text: p.folderUsername);
    _folderDomainCtrl = TextEditingController(text: p.folderDomain);
    _folderPasswordCtrl = TextEditingController();
    _webdavUrlCtrl = TextEditingController(text: p.webdavBaseUrl);
    _webdavPathCtrl = TextEditingController(text: p.webdavRemotePath);
    _webdavUserCtrl = TextEditingController(text: p.webdavUsername);
    _webdavPasswordCtrl = TextEditingController();
    _retentionCtrl = TextEditingController(text: '${p.retentionCount}');
    _folderRequiresAuth = p.folderRequiresAuth;
    unawaited(_loadStoredPasswords());
  }

  Future<void> _loadStoredPasswords() async {
    final folderPw = await widget.credentials.readPassword(
      widget.vaultId,
      BackupCredentialScope.folder,
    );
    final webdavPw = await widget.credentials.readPassword(
      widget.vaultId,
      BackupCredentialScope.webdav,
    );
    if (!mounted) return;
    if (folderPw != null) _folderPasswordCtrl.text = folderPw;
    if (webdavPw != null) _webdavPasswordCtrl.text = webdavPw;
  }

  @override
  void dispose() {
    _tabs.dispose();
    _folderPathCtrl.dispose();
    _folderUserCtrl.dispose();
    _folderDomainCtrl.dispose();
    _folderPasswordCtrl.dispose();
    _webdavUrlCtrl.dispose();
    _webdavPathCtrl.dispose();
    _webdavUserCtrl.dispose();
    _webdavPasswordCtrl.dispose();
    _retentionCtrl.dispose();
    super.dispose();
  }

  int _parseRetention() {
    final n = int.tryParse(_retentionCtrl.text.trim()) ?? 10;
    return n.clamp(0, 999);
  }

  bool get _folderCredentialsNeeded {
    final isUnc = SmbNetworkAuth.isUncPath(_folderPathCtrl.text);
    return isUnc || _folderRequiresAuth;
  }

  VaultBackupPrefs _buildPrefs() {
    final folderCreds = _folderCredentialsNeeded;
    return widget.initialPrefs.copyWith(
      directory: _folderPathCtrl.text.trim(),
      folderRequiresAuth: folderCreds && _folderRequiresAuth,
      folderUsername: folderCreds ? _folderUserCtrl.text.trim() : '',
      folderDomain: folderCreds ? _folderDomainCtrl.text.trim() : '',
      webdavBaseUrl: _webdavUrlCtrl.text.trim(),
      webdavRemotePath: _webdavPathCtrl.text.trim().isEmpty
          ? '/folio-backups'
          : _webdavPathCtrl.text.trim(),
      webdavUsername: _webdavUserCtrl.text.trim(),
      retentionCount: _parseRetention(),
    );
  }

  Future<void> _testFolder() async {
    setState(() {
      _testing = true;
      _statusMessage = null;
    });
    try {
      final dest = LocalFolderDestination(
        directoryPath: _folderPathCtrl.text.trim(),
        folderRequiresAuth: _folderRequiresAuth,
        username: _folderUserCtrl.text.trim(),
        password: _folderPasswordCtrl.text,
        domain: _folderDomainCtrl.text.trim(),
      );
      await dest.ping();
      if (!mounted) return;
      setState(() {
        _statusOk = true;
        _statusMessage = widget.l10n.remoteBackupTestConnectionOk;
      });
    } on VaultBackupException catch (e) {
      if (!mounted) return;
      setState(() {
        _statusOk = false;
        _statusMessage = widget.l10n.remoteBackupTestConnectionFail('$e');
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusOk = false;
        _statusMessage = widget.l10n.remoteBackupTestConnectionFail('$e');
      });
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _testWebdav() async {
    setState(() {
      _testing = true;
      _statusMessage = null;
    });
    try {
      final dest = WebDavDestination(
        baseUrl: _webdavUrlCtrl.text.trim(),
        remotePath: _webdavPathCtrl.text.trim().isEmpty
            ? '/folio-backups'
            : _webdavPathCtrl.text.trim(),
        username: _webdavUserCtrl.text.trim(),
        password: _webdavPasswordCtrl.text,
      );
      await dest.ping();
      if (!mounted) return;
      setState(() {
        _statusOk = true;
        _statusMessage = widget.l10n.remoteBackupTestConnectionOk;
      });
    } on VaultBackupException catch (e) {
      if (!mounted) return;
      setState(() {
        _statusOk = false;
        _statusMessage = widget.l10n.remoteBackupTestConnectionFail('$e');
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusOk = false;
        _statusMessage = widget.l10n.remoteBackupTestConnectionFail('$e');
      });
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _save() async {
    final prefs = _buildPrefs();
    // Si la carpeta no necesita credenciales, no guardamos contraseña obsoleta.
    await widget.credentials.writePassword(
      widget.vaultId,
      BackupCredentialScope.folder,
      _folderCredentialsNeeded ? _folderPasswordCtrl.text : '',
    );
    await widget.credentials.writePassword(
      widget.vaultId,
      BackupCredentialScope.webdav,
      _webdavPasswordCtrl.text,
    );
    if (!mounted) return;
    Navigator.pop(context, prefs);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    final scheme = Theme.of(context).colorScheme;
    return FolioDialog(
      title: Text(l10n.remoteBackupConfigTitle),
      contentWidth: 520,
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            TabBar(
              controller: _tabs,
              tabs: [
                Tab(text: l10n.remoteBackupTabFolder),
                Tab(text: l10n.remoteBackupTabWebdav),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 360,
              child: TabBarView(
                controller: _tabs,
                children: [
                  _folderTab(l10n, scheme),
                  _webdavTab(l10n, scheme),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _retentionCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: l10n.remoteBackupRetentionLabel,
                helperText: l10n.remoteBackupRetentionSubtitle,
              ),
            ),
            if (_statusMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _statusMessage!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: _statusOk ? scheme.primary : scheme.error,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _testing ? null : () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _testing ? null : _save,
          child: Text(l10n.remoteBackupSave),
        ),
      ],
    );
  }

  Widget _folderTab(AppLocalizations l10n, ColorScheme scheme) {
    final isUnc = SmbNetworkAuth.isUncPath(_folderPathCtrl.text);
    // Las credenciales solo tienen sentido en rutas de red (UNC) o si el
    // usuario indica explícitamente que el servidor las requiere.
    final showCredentials = isUnc || _folderRequiresAuth;
    return ListView(
      children: [
        TextField(
          controller: _folderPathCtrl,
          decoration: InputDecoration(
            labelText: l10n.remoteBackupNetworkPathLabel,
            hintText: l10n.remoteBackupNetworkPathHint,
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.remoteBackupMountedDriveHint,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        // El interruptor de autenticación solo es útil cuando la ruta no es
        // UNC (en UNC las credenciales se muestran siempre).
        if (!isUnc) ...[
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.remoteBackupRequiresAuth),
            subtitle: Text(l10n.remoteBackupRequiresAuthSubtitle),
            value: _folderRequiresAuth,
            onChanged: (v) => setState(() => _folderRequiresAuth = v),
          ),
        ],
        if (showCredentials) ...[
          const SizedBox(height: 12),
          Text(
            l10n.remoteBackupCredentialsTitle,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _folderUserCtrl,
            decoration: InputDecoration(
              labelText: l10n.remoteBackupUsernameLabel,
            ),
          ),
          const SizedBox(height: 8),
          FolioPasswordField(
            controller: _folderPasswordCtrl,
            labelText: l10n.remoteBackupPasswordLabel,
            obscureText: _folderPasswordObscure,
            onToggleObscure: () => setState(
              () => _folderPasswordObscure = !_folderPasswordObscure,
            ),
            showPasswordTooltip: l10n.showPassword,
            hidePasswordTooltip: l10n.hidePassword,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _folderDomainCtrl,
            decoration: InputDecoration(
              labelText: l10n.remoteBackupDomainLabel,
              helperText: l10n.remoteBackupDomainOptional,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.remoteBackupUgreenHelp,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _testing ? null : _testFolder,
          icon: _testing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.lan_outlined),
          label: Text(l10n.remoteBackupTestConnection),
        ),
      ],
    );
  }

  Widget _webdavTab(AppLocalizations l10n, ColorScheme scheme) {
    return ListView(
      children: [
        Text(
          l10n.remoteBackupWebdavSubtitle,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _webdavUrlCtrl,
          decoration: InputDecoration(
            labelText: l10n.remoteBackupWebdavUrlLabel,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _webdavPathCtrl,
          decoration: InputDecoration(
            labelText: l10n.remoteBackupWebdavPathLabel,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _webdavUserCtrl,
          decoration: InputDecoration(labelText: l10n.remoteBackupUsernameLabel),
        ),
        const SizedBox(height: 8),
        FolioPasswordField(
          controller: _webdavPasswordCtrl,
          labelText: l10n.remoteBackupPasswordLabel,
          obscureText: _webdavPasswordObscure,
          onToggleObscure: () =>
              setState(() => _webdavPasswordObscure = !_webdavPasswordObscure),
          showPasswordTooltip: l10n.showPassword,
          hidePasswordTooltip: l10n.hidePassword,
        ),
        const SizedBox(height: 12),
        Text(
          l10n.remoteBackupUgreenHelp,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _testing ? null : _testWebdav,
          icon: _testing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.cloud_outlined),
          label: Text(l10n.remoteBackupTestConnection),
        ),
      ],
    );
  }
}