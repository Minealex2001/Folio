import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:passkeys/exceptions.dart';

import '../../app/app_settings.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../data/vault_backup.dart';
import '../../session/vault_session.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.session,
    required this.appSettings,
  });

  final VaultSession session;
  final AppSettings appSettings;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  VaultSession get _s => widget.session;
  AppSettings get _app => widget.appSettings;

  var _quickEnabled = false;
  var _passkeyRegistered = false;

  @override
  void initState() {
    super.initState();
    _refreshSecurityFlags();
  }

  Future<void> _refreshSecurityFlags() async {
    final q = await _s.quickUnlockEnabled;
    final p = await _s.hasPasskey;
    if (mounted) {
      setState(() {
        _quickEnabled = q;
        _passkeyRegistered = p;
      });
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _suggestedBackupFileName() {
    final d = DateTime.now();
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return 'folio-cofre-$y-$m-$day.folio.zip';
  }

  Future<void> _openExportBackupFlow() async {
    if (_s.state != VaultFlowState.unlocked) return;
    final verified = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _VaultIdentityVerifyDialog(
        session: _s,
        quickEnabled: _quickEnabled,
        passkeyRegistered: _passkeyRegistered,
        title: const Text('Exportar copia del cofre'),
        body: const Text(
          'Para crear un archivo de copia, confirma tu identidad con el cofre actual desbloqueado.',
        ),
        passwordButtonLabel: 'Verificar y exportar',
      ),
    );
    if (verified != true || !mounted) return;

    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Guardar copia del cofre',
      fileName: _suggestedBackupFileName(),
      type: FileType.custom,
      allowedExtensions: const ['zip'],
    );
    if (path == null || !mounted) return;

    try {
      await _s.exportVaultBackup(path);
      if (mounted) {
        _snack('Copia guardada correctamente.');
      }
    } on VaultBackupException catch (e) {
      if (mounted) _snack('No se pudo exportar: $e');
    } catch (e) {
      if (mounted) {
        _snack('No se pudo exportar: $e');
      }
    }
  }

  Future<void> _openImportBackupFlow() async {
    if (_s.state != VaultFlowState.unlocked) return;
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Importar copia del cofre'),
        content: const SingleChildScrollView(
          child: Text(
            'Se añadirá un cofre nuevo desde el archivo. El cofre que tienes abierto ahora no se borra ni se modifica.\n\n'
            'La contraseña del archivo será la del cofre importado (para abrirlo al cambiar de cofre).\n\n'
            'La passkey y el desbloqueo rápido (Hello / biometría) no van en la copia y no son transferibles; '
            'podrás configurarlos en ese cofre después.\n\n'
            '¿Continuar?',
            style: TextStyle(height: 1.45),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
    if (go != true || !mounted) return;

    final verified = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _VaultIdentityVerifyDialog(
        session: _s,
        quickEnabled: _quickEnabled,
        passkeyRegistered: _passkeyRegistered,
        title: const Text('Confirma identidad'),
        body: const Text(
          'Demuestra que eres tú con el cofre actual desbloqueado antes de importar.',
        ),
        passwordButtonLabel: 'Verificar y continuar',
      ),
    );
    if (verified != true || !mounted) return;

    final pick = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['zip'],
      allowMultiple: false,
    );
    if (pick == null || pick.files.isEmpty || !mounted) return;
    final fp = pick.files.single.path;
    if (fp == null) {
      _snack('No se pudo leer la ruta del archivo.');
      return;
    }

    final password = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const _BackupPasswordDialog(),
    );
    if (password == null || password.isEmpty || !mounted) return;

    try {
      await _s.importVaultBackupAsNew(fp, password);
      await _refreshSecurityFlags();
      if (!mounted) return;
      _snack(
        'Cofre importado. Aparece en el selector del panel lateral; el actual sigue igual.',
      );
      Navigator.of(context).pop();
    } on VaultBackupException catch (e) {
      if (mounted) _snack('No se pudo importar: $e');
    } catch (e) {
      if (mounted) _snack('No se pudo importar: $e');
    }
  }

  Future<void> _openWipeFlow() async {
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Borrar cofre'),
        content: const Text(
          'Se eliminarán todas las páginas y la contraseña maestra dejará de ser válida. '
          'Esta acción no se puede deshacer.\n\n'
          '¿Seguro que quieres continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
    if (go != true || !mounted) return;

    final verified = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _VaultIdentityVerifyDialog(
        session: _s,
        quickEnabled: _quickEnabled,
        passkeyRegistered: _passkeyRegistered,
        title: const Text('Confirma identidad'),
        body: const Text('Para borrar el cofre, demuestra que eres tú.'),
        passwordButtonLabel: 'Verificar con contraseña y borrar',
      ),
    );

    if (verified != true || !context.mounted) return;

    try {
      await _s.wipeVaultAndReset();
      if (!context.mounted) return;
      if (_s.state == VaultFlowState.needsOnboarding) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          Navigator.of(context, rootNavigator: true).popUntil((r) => r.isFirst);
        });
      } else {
        if (!mounted) return;
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (!context.mounted) return;
      _snack('No se pudo borrar el cofre: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _app,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: Text(l10n.settings)),
          body: ListenableBuilder(
            listenable: _s,
            builder: (context, _) {
              return ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _SectionHeader(title: l10n.appearance, scheme: scheme),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Text(
                      'El color principal sigue al acento de Windows cuando está disponible.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: SegmentedButton<ThemeMode>(
                      segments: [
                        ButtonSegment<ThemeMode>(
                          value: ThemeMode.system,
                          label: Text(l10n.systemTheme),
                          icon: Icon(Icons.brightness_auto, size: 18),
                        ),
                        ButtonSegment<ThemeMode>(
                          value: ThemeMode.light,
                          label: Text(l10n.lightTheme),
                          icon: Icon(Icons.light_mode_outlined, size: 18),
                        ),
                        ButtonSegment<ThemeMode>(
                          value: ThemeMode.dark,
                          label: Text(l10n.darkTheme),
                          icon: Icon(Icons.dark_mode_outlined, size: 18),
                        ),
                      ],
                      selected: {_app.themeMode},
                      onSelectionChanged: (s) {
                        _app.setThemeMode(s.first);
                      },
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.translate_rounded),
                    title: Text(l10n.language),
                    subtitle: Text(
                      _app.locale == null
                          ? l10n.useSystemLanguage
                          : (_app.locale!.languageCode == 'es'
                                ? l10n.spanishLanguage
                                : l10n.englishLanguage),
                    ),
                    trailing: DropdownButton<String?>(
                      value: _app.locale?.languageCode,
                      onChanged: (code) {
                        _app.setLocale(code == null ? null : Locale(code));
                      },
                      items: [
                        DropdownMenuItem<String?>(
                          value: null,
                          child: Text(l10n.useSystemLanguage),
                        ),
                        DropdownMenuItem<String?>(
                          value: 'es',
                          child: Text(l10n.spanishLanguage),
                        ),
                        DropdownMenuItem<String?>(
                          value: 'en',
                          child: Text(l10n.englishLanguage),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _SectionHeader(title: l10n.security, scheme: scheme),
                  ListTile(
                    leading: const Icon(Icons.fingerprint),
                    title: const Text('Desbloqueo rápido (Hello / biometría)'),
                    subtitle: Text(_quickEnabled ? 'Activado' : 'Desactivado'),
                    trailing: _quickEnabled
                        ? TextButton(
                            onPressed: () async {
                              await _s.disableQuickUnlock();
                              await _refreshSecurityFlags();
                              _snack('Desbloqueo rápido desactivado');
                            },
                            child: const Text('Quitar'),
                          )
                        : FilledButton.tonal(
                            onPressed: () async {
                              try {
                                await _s.enableDeviceQuickUnlock();
                                await _refreshSecurityFlags();
                                _snack('Desbloqueo rápido activado');
                              } catch (e) {
                                _snack('$e');
                              }
                            },
                            child: const Text('Activar'),
                          ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.key_rounded),
                    title: const Text('Passkey'),
                    subtitle: const Text('WebAuthn en este dispositivo'),
                    trailing: _passkeyRegistered
                        ? TextButton(
                            onPressed: () async {
                              await _s.revokePasskey();
                              await _refreshSecurityFlags();
                              _snack('Passkey revocada');
                            },
                            child: const Text('Revocar'),
                          )
                        : FilledButton.tonal(
                            onPressed: () async {
                              try {
                                await _s.registerPasskey();
                                await _refreshSecurityFlags();
                                _snack('Passkey registrada');
                              } on PasskeyAuthCancelledException {
                                // ignorar
                              } catch (e) {
                                _snack('Passkey: $e');
                              }
                            },
                            child: const Text('Registrar'),
                          ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.lock_outline),
                    title: const Text('Bloquear ahora'),
                    onTap: () {
                      _s.lock();
                      Navigator.pop(context);
                    },
                  ),
                  const SizedBox(height: 16),
                  _SectionHeader(title: l10n.vaultBackup, scheme: scheme),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Text(
                      'El archivo contiene los mismos datos cifrados que en disco (vault.keys y vault.bin), '
                      'sin exponer el contenido en claro. Las imágenes en adjuntos van tal cual.\n\n'
                      'La passkey y el desbloqueo rápido no se incluyen en la copia y no son transferibles entre dispositivos; '
                      'en cada cofre importado podrás configurarlos de nuevo.\n\n'
                      'Importar añade un cofre nuevo; no sustituye el que tienes abierto.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.file_download_outlined),
                    title: const Text('Exportar copia (.zip)'),
                    subtitle: const Text(
                      'Contraseña, Hello o passkey del cofre actual',
                    ),
                    onTap: _s.state == VaultFlowState.unlocked
                        ? _openExportBackupFlow
                        : null,
                  ),
                  ListTile(
                    leading: const Icon(Icons.file_upload_outlined),
                    title: const Text('Importar copia (.zip)'),
                    subtitle: const Text(
                      'Añade cofre nuevo · identidad actual + contraseña del archivo',
                    ),
                    onTap: _s.state == VaultFlowState.unlocked
                        ? _openImportBackupFlow
                        : null,
                  ),
                  const SizedBox(height: 16),
                  _SectionHeader(title: l10n.data, scheme: scheme),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Card(
                      child: ListTile(
                        leading: Icon(
                          Icons.delete_forever_outlined,
                          color: scheme.error,
                        ),
                        title: Text(
                          'Borrar cofre y empezar de cero',
                          style: TextStyle(color: scheme.error),
                        ),
                        subtitle: Text(
                          'Requiere contraseña, Hello o passkey.',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                        onTap: _openWipeFlow,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _BackupPasswordDialog extends StatefulWidget {
  const _BackupPasswordDialog();

  @override
  State<_BackupPasswordDialog> createState() => _BackupPasswordDialogState();
}

class _BackupPasswordDialogState extends State<_BackupPasswordDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final t = _controller.text;
    if (t.isEmpty) return;
    Navigator.pop(context, t);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Contraseña de la copia'),
      content: TextField(
        controller: _controller,
        obscureText: true,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'Contraseña del archivo de copia',
          helperText:
              'Es la contraseña maestra con la que se creó la copia, no la de otro dispositivo.',
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Importar')),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.scheme});

  final String title;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: scheme.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _VaultIdentityVerifyDialog extends StatefulWidget {
  const _VaultIdentityVerifyDialog({
    required this.session,
    required this.quickEnabled,
    required this.passkeyRegistered,
    required this.title,
    required this.body,
    required this.passwordButtonLabel,
  });

  final VaultSession session;
  final bool quickEnabled;
  final bool passkeyRegistered;
  final Widget title;
  final Widget body;
  final String passwordButtonLabel;

  @override
  State<_VaultIdentityVerifyDialog> createState() =>
      _VaultIdentityVerifyDialogState();
}

class _VaultIdentityVerifyDialogState
    extends State<_VaultIdentityVerifyDialog> {
  final _password = TextEditingController();
  var _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _verifyPassword() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await widget.session.verifyPasswordMatchesUnlockedSession(
      _password.text,
    );
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context, true);
      return;
    }
    setState(() {
      _busy = false;
      _error = 'Contraseña incorrecta.';
    });
  }

  Future<void> _verifyHello() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.session.verifyQuickUnlockMatchesSession();
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = '$e';
        });
      }
    }
  }

  Future<void> _verifyPasskey() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.session.verifyPasskeyMatchesSession();
      if (mounted) Navigator.pop(context, true);
    } on PasskeyAuthCancelledException {
      if (mounted) setState(() => _busy = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = '$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: widget.title,
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DefaultTextStyle.merge(
              style: Theme.of(
                context,
              ).textTheme.bodyMedium!.copyWith(color: scheme.onSurfaceVariant),
              child: widget.body,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _password,
              obscureText: true,
              enabled: !_busy,
              decoration: const InputDecoration(
                labelText: 'Contraseña maestra',
              ),
              onSubmitted: (_) => _verifyPassword(),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _busy ? null : _verifyPassword,
              child: Text(widget.passwordButtonLabel),
            ),
            if (widget.quickEnabled) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _busy ? null : _verifyHello,
                icon: const Icon(Icons.fingerprint),
                label: const Text('Usar Hello / biometría'),
              ),
            ],
            if (widget.passkeyRegistered) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _busy ? null : _verifyPasskey,
                icon: const Icon(Icons.key_rounded),
                label: const Text('Usar passkey'),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: scheme.error)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
      ],
    );
  }
}
