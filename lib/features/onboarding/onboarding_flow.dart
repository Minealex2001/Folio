import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../app/ui_tokens.dart';
import '../../data/vault_backup.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../session/vault_session.dart';

class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({super.key, required this.session});

  final VaultSession session;

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _backupPassword = TextEditingController();

  var _page = 0;
  var _importMode = false;
  String? _backupZipPath;
  String? _error;
  var _busy = false;
  var _obscurePassword = true;
  var _obscureConfirm = true;
  var _obscureBackupPassword = true;
  var _createWithoutEncryption = false;

  static const _minLen = 10;

  _PasswordStrength get _passwordStrength => _passwordStrengthFor(_password.text);

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    _backupPassword.dispose();
    super.dispose();
  }

  String get _stepLabel {
    final l10n = AppLocalizations.of(context);
    if (_importMode) {
      return l10n.stepOfTotal(_page + 1, 2);
    }
    return l10n.stepOfTotal(_page + 1, 3);
  }

  void _goPage(int i) {
    setState(() => _page = i);
  }

  void _chooseCreateNew() {
    setState(() {
      _error = null;
      _importMode = false;
      _createWithoutEncryption = false;
    });
    _goPage(1);
  }

  void _chooseImport() {
    setState(() {
      _error = null;
      _importMode = true;
      _backupZipPath = null;
    });
    _goPage(1);
  }

  void _nextCreatePassword() {
    setState(() {
      _error = null;
      if (_page == 1) {
        if (_createWithoutEncryption) {
          _page = 2;
          return;
        }
        final p = _password.text;
        final c = _confirm.text;
        if (p.length < _minLen) {
          _error = AppLocalizations.of(context).minCharactersError(_minLen);
          return;
        }
        if (_passwordStrength != _PasswordStrength.strong) {
          _error = AppLocalizations.of(context).passwordMustBeStrongError;
          return;
        }
        if (p != c) {
          _error = AppLocalizations.of(context).passwordMismatchError;
          return;
        }
      }
      _page = 2;
    });
  }

  Future<void> _pickBackupFile() async {
    setState(() => _error = null);
    final pick = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['zip'],
      allowMultiple: false,
    );
    if (!mounted) return;
    final path = pick?.files.single.path;
    if (path != null) {
      setState(() => _backupZipPath = path);
    }
  }

  Future<void> _finishImport() async {
    if (_backupZipPath == null) {
      setState(() => _error = AppLocalizations.of(context).chooseZipError);
      return;
    }
    final pwd = _backupPassword.text;
    if (pwd.isEmpty) {
      setState(
        () => _error = AppLocalizations.of(context).enterBackupPasswordError,
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.session.completeOnboardingFromBackup(_backupZipPath!, pwd);
    } on VaultBackupException catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = '$e';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = AppLocalizations.of(context).importFailedError('$e');
        });
      }
    }
  }

  Future<void> _finishCreate() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.session.completeOnboarding(
        password: _createWithoutEncryption ? null : _password.text,
        encrypted: !_createWithoutEncryption,
      );
    } catch (e) {
      setState(() {
        _busy = false;
        _error = AppLocalizations.of(context).createVaultFailedError('$e');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      appBar: widget.session.canCancelNewVaultOnboarding
          ? AppBar(
              backgroundColor: Colors.transparent,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () async {
                  await widget.session.cancelPrepareNewVault();
                },
              ),
              title: Text(l10n.newVault),
            )
          : null,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: FolioSpace.lg,
                  vertical: FolioSpace.md,
                ),
                child: Material(
                  color: scheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(FolioRadius.lg),
                  child: Padding(
                    padding: const EdgeInsets.all(FolioSpace.xl),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Text(
                            'Folio',
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: scheme.primary,
                                ),
                          ),
                        ),
                        const SizedBox(height: FolioSpace.xs),
                        Center(
                          child: Text(
                            _stepLabel,
                            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                          ),
                        ),
                        const SizedBox(height: FolioSpace.lg),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: KeyedSubtree(
                            key: ValueKey('step_$_importMode$_page'),
                            child: _buildCurrentStep(context),
                          ),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: FolioSpace.md),
                          Row(
                            children: [
                              Expanded(
                                child: Text(_error!, style: TextStyle(color: scheme.error)),
                              ),
                              const SizedBox(width: FolioSpace.xs),
                              TextButton.icon(
                                onPressed: _busy
                                    ? null
                                    : () {
                                        setState(() => _error = null);
                                      },
                                icon: const Icon(Icons.close_rounded),
                                label: Text(l10n.retry),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentStep(BuildContext context) {
    if (_importMode) {
      if (_page == 0) return _stepWelcome(context);
      return _stepImportBackup(context);
    } else {
      if (_page == 0) return _stepWelcome(context);
      if (_page == 1) return _stepPassword(context);
      return _stepReady(context);
    }
  }

  Widget _stepNoEncryptionConfirm(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: FolioSpace.xl),
        Icon(Icons.warning_amber_rounded, size: 64, color: scheme.error),
        const SizedBox(height: FolioSpace.lg),
        Text(
          'Crear cofre sin cifrado',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: FolioSpace.md),
        Text(
          'Tus datos quedaran guardados sin contraseña y sin cifrado. '
          'Cualquier persona con acceso al dispositivo podra leerlos.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.45,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: FolioSpace.xl),
        Row(
          children: [
            TextButton(
              onPressed: () {
                setState(() => _createWithoutEncryption = false);
              },
              child: Text(l10n.back),
            ),
            const SizedBox(width: FolioSpace.md),
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size(120, 48),
                shape: const StadiumBorder(),
              ),
              onPressed: _nextCreatePassword,
              child: Text(l10n.continueAction),
            ),
          ],
        ),
      ],
    );
  }

  Widget _stepWelcome(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: FolioSpace.xl),
        Icon(
          Icons.shield_outlined,
          size: 80,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: FolioSpace.lg),
        Text(
          AppLocalizations.of(context).welcomeTitle,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: FolioSpace.md),
        Text(
          AppLocalizations.of(context).welcomeBody,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.45),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: FolioSpace.xl),
        FilledButton(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
            shape: const StadiumBorder(),
          ),
          onPressed: _chooseCreateNew,
          child: Text(AppLocalizations.of(context).createNewVault),
        ),
        const SizedBox(height: FolioSpace.md),
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
            shape: const StadiumBorder(),
          ),
          onPressed: () {
            setState(() {
              _error = null;
              _importMode = false;
              _createWithoutEncryption = true;
            });
            _goPage(1);
          },
          child: const Text('Crear sin cifrado'),
        ),
        const SizedBox(height: FolioSpace.md),
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
            shape: const StadiumBorder(),
          ),
          onPressed: _chooseImport,
          child: Text(AppLocalizations.of(context).importBackupZip),
        ),
      ],
    );
  }

  Widget _stepImportBackup(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: FolioSpace.xl),
        Icon(
          Icons.settings_backup_restore_rounded,
          size: 64,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: FolioSpace.lg),
        Text(
          AppLocalizations.of(context).importBackupTitle,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: FolioSpace.md),
        Text(
          AppLocalizations.of(context).importBackupBody,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                height: 1.45,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: FolioSpace.xl),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
            shape: const StadiumBorder(),
          ),
          onPressed: _busy ? null : _pickBackupFile,
          icon: const Icon(Icons.folder_open_outlined),
          label: Text(
            _backupZipPath == null
                ? AppLocalizations.of(context).chooseZipFile
                : AppLocalizations.of(context).changeFile,
          ),
        ),
        if (_backupZipPath != null) ...[
          const SizedBox(height: FolioSpace.sm),
          Text(
            _backupZipPath!,
            style: Theme.of(context).textTheme.bodySmall,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: FolioSpace.lg),
        TextField(
          controller: _backupPassword,
          obscureText: _obscureBackupPassword,
          enabled: !_busy,
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context).backupPasswordLabel,
            suffixIcon: IconButton(
              onPressed: _busy
                  ? null
                  : () => setState(
                      () => _obscureBackupPassword = !_obscureBackupPassword,
                    ),
              icon: Icon(
                _obscureBackupPassword ? Icons.visibility : Icons.visibility_off,
              ),
              tooltip: _obscureBackupPassword
                  ? AppLocalizations.of(context).showPassword
                  : AppLocalizations.of(context).hidePassword,
            ),
          ),
          onSubmitted: (_) {
            if (!_busy) _finishImport();
          },
        ),
        const SizedBox(height: FolioSpace.xl),
        Row(
          children: [
            TextButton(
              onPressed: _busy
                  ? null
                  : () {
                      setState(() {
                        _page = 0;
                      });
                    },
              child: Text(AppLocalizations.of(context).back),
            ),
            const SizedBox(width: FolioSpace.md),
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size(120, 48),
                shape: const StadiumBorder(),
              ),
              onPressed: _busy ? null : _finishImport,
              child: _busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(AppLocalizations.of(context).importVault),
            ),
          ],
        ),
      ],
    );
  }

  Widget _stepPassword(BuildContext context) {
    if (_createWithoutEncryption) {
      return _stepNoEncryptionConfirm(context);
    }
    final strength = _passwordStrength;
    final strengthValue = switch (strength) {
      _PasswordStrength.veryWeak => 0.25,
      _PasswordStrength.weak => 0.5,
      _PasswordStrength.fair => 0.75,
      _PasswordStrength.strong => 1.0,
    };
    final strengthLabel = switch (strength) {
      _PasswordStrength.veryWeak =>
        AppLocalizations.of(context).passwordStrengthVeryWeak,
      _PasswordStrength.weak => AppLocalizations.of(context).passwordStrengthWeak,
      _PasswordStrength.fair => AppLocalizations.of(context).passwordStrengthFair,
      _PasswordStrength.strong => AppLocalizations.of(context).passwordStrengthStrong,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: FolioSpace.xl),
        Icon(
          Icons.password_outlined,
          size: 64,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: FolioSpace.lg),
        Text(
          AppLocalizations.of(context).masterPasswordTitle,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: FolioSpace.md),
        Text(
          AppLocalizations.of(context).masterPasswordHint(_minLen),
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.45,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: FolioSpace.xl),
        TextField(
          controller: _password,
          obscureText: _obscurePassword,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context).passwordLabel,
            suffixIcon: IconButton(
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
              icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
              tooltip: _obscurePassword
                  ? AppLocalizations.of(context).showPassword
                  : AppLocalizations.of(context).hidePassword,
            ),
          ),
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: FolioSpace.sm),
        LinearProgressIndicator(value: strengthValue),
        const SizedBox(height: FolioSpace.xs),
        Text(
          '${AppLocalizations.of(context).passwordStrengthLabel}: $strengthLabel',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: FolioSpace.md),
        TextField(
          controller: _confirm,
          obscureText: _obscureConfirm,
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context).confirmPasswordLabel,
            suffixIcon: IconButton(
              onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
              icon: Icon(_obscureConfirm ? Icons.visibility : Icons.visibility_off),
              tooltip: _obscureConfirm
                  ? AppLocalizations.of(context).showPassword
                  : AppLocalizations.of(context).hidePassword,
            ),
          ),
          onSubmitted: (_) => _nextCreatePassword(),
        ),
        const SizedBox(height: FolioSpace.xl),
        Row(
          children: [
            TextButton(
              onPressed: () {
                setState(() {
                  _page = 0;
                });
              },
              child: Text(AppLocalizations.of(context).back),
            ),
            const SizedBox(width: FolioSpace.md),
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size(120, 48),
                shape: const StadiumBorder(),
              ),
              onPressed: _nextCreatePassword,
              child: Text(AppLocalizations.of(context).next),
            ),
          ],
        ),
      ],
    );
  }

  Widget _stepReady(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: FolioSpace.xl),
        Icon(
          Icons.celebration_outlined,
          size: 64,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: FolioSpace.lg),
        Text(
          AppLocalizations.of(context).readyTitle,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: FolioSpace.md),
        Text(
          AppLocalizations.of(context).readyBody,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.45),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: FolioSpace.xl),
        Row(
          children: [
            TextButton(
              onPressed: () {
                setState(() {
                  _page = 1;
                });
              },
              child: Text(AppLocalizations.of(context).back),
            ),
            const SizedBox(width: FolioSpace.md),
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size(120, 48),
                shape: const StadiumBorder(),
              ),
              onPressed: _busy ? null : _finishCreate,
              child: _busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(AppLocalizations.of(context).createVault),
            ),
          ],
        ),
      ],
    );
  }
}

enum _PasswordStrength { veryWeak, weak, fair, strong }

_PasswordStrength _passwordStrengthFor(String text) {
  var score = 0;
  if (text.length >= 10) score++;
  if (text.length >= 14) score++;
  if (RegExp(r'[a-z]').hasMatch(text) && RegExp(r'[A-Z]').hasMatch(text)) {
    score++;
  }
  if (RegExp(r'\d').hasMatch(text)) score++;
  if (RegExp(r'[^A-Za-z0-9]').hasMatch(text)) score++;
  if (score <= 1) return _PasswordStrength.veryWeak;
  if (score == 2) return _PasswordStrength.weak;
  if (score == 3 || score == 4) return _PasswordStrength.fair;
  return _PasswordStrength.strong;
}
