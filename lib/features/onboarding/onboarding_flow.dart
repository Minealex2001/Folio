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
  final _pageController = PageController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _backupPassword = TextEditingController();

  var _page = 0;
  var _importMode = false;
  String? _backupZipPath;
  String? _error;
  var _busy = false;

  static const _minLen = 10;

  @override
  void dispose() {
    _pageController.dispose();
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
    _pageController.animateToPage(
      i,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  void _chooseCreateNew() {
    setState(() {
      _error = null;
      _importMode = false;
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
        final p = _password.text;
        final c = _confirm.text;
        if (p.length < _minLen) {
          _error = AppLocalizations.of(context).minCharactersError(_minLen);
          return;
        }
        if (p != c) {
          _error = AppLocalizations.of(context).passwordMismatchError;
          return;
        }
      }
      _page = 2;
      _pageController.animateToPage(
        2,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
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
      await widget.session.completeOnboarding(_password.text);
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
          obscureText: true,
          enabled: !_busy,
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context).backupPasswordLabel,
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
                        _pageController.jumpToPage(0);
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
          obscureText: true,
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context).passwordLabel,
          ),
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: FolioSpace.md),
        TextField(
          controller: _confirm,
          obscureText: true,
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context).confirmPasswordLabel,
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
                  _pageController.jumpToPage(0);
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
                  _pageController.jumpToPage(1);
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
