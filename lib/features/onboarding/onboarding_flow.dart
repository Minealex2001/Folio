import 'dart:async' show unawaited;
import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../app/app_settings.dart';
import '../../app/ui_tokens.dart';
import '../../app/widgets/folio_password_field.dart';
import '../../crypto/vault_crypto.dart';
import '../../data/notion_import/notion_importer.dart';
import '../../data/vault_backup.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../session/vault_session.dart';
import '../../services/cloud_account/cloud_account_controller.dart';
import '../../services/folio_cloud/folio_cloud_backup.dart';
import '../../services/folio_cloud/folio_cloud_entitlements.dart';
import '../../services/folio_cloud/folio_cloud_pack_sync.dart';
import '../../services/folio_cloud/folio_cloud_reachability.dart';
import '../../services/folio_telemetry.dart';
import '../settings/folio_cloud_reauth_dialog.dart';
import 'cloud_sign_in_dialog.dart';

class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({
    super.key,
    required this.session,
    required this.appSettings,
  });

  final VaultSession session;
  final AppSettings appSettings;

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _backupPassword = TextEditingController();
  final _notionPassword = TextEditingController();
  final _notionConfirm = TextEditingController();

  late final CloudAccountController _cloud = CloudAccountController();
  late final FolioCloudEntitlementsController _folio =
      FolioCloudEntitlementsController();

  var _page = 0;
  var _mode = _OnboardingMode.create;
  String? _backupZipPath;
  String? _notionZipPath;
  bool? _backupZipIsPlain;
  String? _onboardingCloudPackVaultId;
  String? _error;
  var _busy = false;
  var _obscurePassword = true;
  var _obscureConfirm = true;
  var _obscureBackupPassword = true;
  var _obscureNotionPassword = true;
  var _obscureNotionConfirm = true;
  var _createWithoutEncryption = false;
  var _createStarterPages = true;
  /// Elección en onboarding (se persiste al salir del paso).
  var _onboardingTelemetryEnabled = false;

  static const _minLen = 10;

  _PasswordStrength get _passwordStrength =>
      _passwordStrengthFor(_password.text);

  bool get _shouldShowQuillIntro => !widget.appSettings.hasSeenQuillIntro;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    _backupPassword.dispose();
    _notionPassword.dispose();
    _notionConfirm.dispose();
    _cloud.dispose();
    _folio.dispose();
    super.dispose();
  }

  String get _stepLabel {
    final l10n = AppLocalizations.of(context);
    if (_mode == _OnboardingMode.backupImport ||
        _mode == _OnboardingMode.notionImport) {
      return l10n.stepOfTotal(_page + 1, 2);
    }
    // Create flow:
    // 0 welcome, 1 password, 2 ready, 3 telemetry, 4 folio cloud, 5 quill intro (optional)
    return l10n.stepOfTotal(_page + 1, _shouldShowQuillIntro ? 6 : 5);
  }

  void _goPage(int i) {
    setState(() => _page = i);
  }

  void _chooseCreateNew() {
    setState(() {
      _error = null;
      _mode = _OnboardingMode.create;
      _createWithoutEncryption = false;
      _createStarterPages = true;
      _onboardingTelemetryEnabled = widget.appSettings.telemetryEnabled;
    });
    _goPage(1);
  }

  void _chooseImportBackup() {
    setState(() {
      _error = null;
      _mode = _OnboardingMode.backupImport;
      _backupZipPath = null;
      _onboardingCloudPackVaultId = null;
    });
    _goPage(1);
  }

  String _cloudAuthErrorMessage(AppLocalizations l10n, String code) {
    switch (code.trim().toLowerCase()) {
      case 'invalid-email':
        return l10n.cloudAuthErrorInvalidEmail;
      case 'wrong-password':
        return l10n.cloudAuthErrorWrongPassword;
      case 'user-not-found':
        return l10n.cloudAuthErrorUserNotFound;
      case 'user-disabled':
        return l10n.cloudAuthErrorUserDisabled;
      case 'invalid-credential':
        return l10n.cloudAuthErrorInvalidCredential;
      case 'network-request-failed':
        return l10n.cloudAuthErrorNetwork;
      case 'too-many-requests':
        return l10n.cloudAuthErrorTooManyRequests;
      case 'operation-not-allowed':
        return l10n.cloudAuthErrorOperationNotAllowed;
      default:
        return l10n.cloudAuthErrorGeneric;
    }
  }

  Future<void> _signInAndPickCloudBackup() async {
    if (_busy) return;
    final l10n = AppLocalizations.of(context);

    if (!_cloud.isAvailable || !_folio.isAvailable) {
      setState(() => _error = l10n.cloudAccountUnavailable);
      return;
    }

    setState(() => _error = null);

    if (defaultTargetPlatform == TargetPlatform.windows) {
      final ok = await folioGoogleApisReachable();
      if (!ok) {
        if (!mounted) return;
        setState(() => _error = l10n.cloudAuthErrorNetwork);
        return;
      }
    }

    if (!mounted) return;

    // 1) Sign in if needed.
    if (!_cloud.isSignedIn) {
      final ok = await showDialog<bool>(
        context: context,
        barrierDismissible: true,
        builder: (ctx) => CloudSignInDialog(
          l10n: l10n,
          cloud: _cloud,
          onAuthError: (c) => _cloudAuthErrorMessage(l10n, c),
        ),
      );
      if (!mounted || ok != true) return;
    }

    // 2) Verify password for sensitive cloud action (required for listing/downloading backups).
    final userEmail = _cloud.user?.email?.trim();
    if (userEmail == null || userEmail.isEmpty) {
      setState(() => _error = l10n.cloudAuthErrorGeneric);
      return;
    }
    if (!mounted) return;
    final verified = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => FolioCloudReauthDialog(
        l10n: l10n,
        cloud: _cloud,
        initialEmail: userEmail,
        onAuthError: (c) => _cloudAuthErrorMessage(l10n, c),
      ),
    );
    if (!mounted || verified != true) return;

    // 3) Load latest entitlements (ink/plan/features).
    setState(() => _busy = true);
    try {
      await _folio.refreshUserDocFromServer();
      final snap = _folio.snapshot;
      final vaults = await listFolioCloudBackupVaults(
        entitlementSnapshot: snap,
      );
      if (!mounted) return;
      if (vaults.isEmpty) {
        setState(() {
          _busy = false;
          _error = '${l10n.folioCloudCloudBackupsList}: ${l10n.noPages}';
        });
        return;
      }
      final chosenVaultId = await showDialog<String>(
        context: context,
        builder: (ctx) => _CloudVaultPickerDialog(l10n: l10n, vaults: vaults),
      );
      if (!mounted || chosenVaultId == null) {
        setState(() => _busy = false);
        return;
      }

      final backups = await listFolioCloudBackups(
        vaultId: chosenVaultId,
        entitlementSnapshot: snap,
      );
      if (!mounted) return;

      final chosen = await showDialog<FolioCloudBackupEntry>(
        context: context,
        builder: (ctx) =>
            _CloudBackupPickerDialog(l10n: l10n, items: backups),
      );
      if (!mounted || chosen == null) {
        setState(() => _busy = false);
        return;
      }

      if (chosen.isCloudPack) {
        setState(() {
          _busy = false;
          _error = null;
          _mode = _OnboardingMode.backupImport;
          _backupZipPath = null;
          _backupZipIsPlain = null;
          _onboardingCloudPackVaultId = chosenVaultId;
          _page = 1;
        });
        return;
      }

      final tmpDir = await Directory.systemTemp.createTemp('folio_cloud_dl_');
      final destPath = p.join(tmpDir.path, chosen.fileName);
      final dest = File(destPath);
      await downloadFolioCloudBackup(
        entry: chosen,
        destinationFile: dest,
        entitlementSnapshot: snap,
      );
      if (!mounted) return;
      bool? isPlain;
      try {
        isPlain = await isPlainBackupArchive(dest);
      } catch (_) {
        isPlain = null;
      }
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = null;
        _mode = _OnboardingMode.backupImport;
        _backupZipPath = dest.path;
        _backupZipIsPlain = isPlain;
        _onboardingCloudPackVaultId = null;
        _page = 1;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = '$e';
      });
    }
  }

  void _chooseImportNotion() {
    setState(() {
      _error = null;
      _mode = _OnboardingMode.notionImport;
      _notionZipPath = null;
      _notionPassword.clear();
      _notionConfirm.clear();
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
    final pick = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['zip'],
      allowMultiple: false,
    );
    if (!mounted) return;
    final path = pick?.files.single.path;
    if (path != null) {
      setState(() {
        _backupZipPath = path;
        _backupZipIsPlain = null;
        _onboardingCloudPackVaultId = null;
      });
      try {
        final plain = await isPlainBackupZip(File(path));
        if (!mounted) return;
        setState(() => _backupZipIsPlain = plain);
      } catch (_) {
        // Si no se puede inspeccionar, mantenemos el comportamiento anterior (pedir contraseña).
        if (mounted) setState(() => _backupZipIsPlain = null);
      }
    }
  }

  Future<void> _finishImport() async {
    final l10n = AppLocalizations.of(context);
    if (_onboardingCloudPackVaultId != null) {
      final vid = _onboardingCloudPackVaultId!;
      final pwd = _backupPassword.text.trim();
      if (pwd.isEmpty) {
        setState(() => _error = l10n.enterBackupPasswordError);
        return;
      }
      setState(() {
        _busy = true;
        _error = null;
      });
      final tmp = await Directory.systemTemp.createTemp('folio_ob_cloud_pack_');
      try {
        await downloadCloudPackToDirectoryForRestore(
          vaultId: vid,
          restorePassword: pwd,
          extractDir: tmp,
          entitlementSnapshot: _folio.snapshot,
        );
        final isPlain = await isPlainExtractedBackupDirectory(tmp);
        final vaultPwd = isPlain ? '' : pwd;
        await widget.session.completeOnboardingFromExtractedDirectory(
          tmp,
          vaultPwd,
        );
        if (mounted) setState(() => _busy = false);
      } on VaultCryptoException catch (e) {
        if (mounted) {
          setState(() {
            _busy = false;
            _error = '$e';
          });
        }
      } on FirebaseFunctionsException catch (e) {
        if (mounted) {
          final isWrap = e.code.toLowerCase() == 'failed-precondition';
          setState(() {
            _busy = false;
            _error = isWrap
                ? l10n.onboardingCloudBackupNeedRestoreWrap
                : l10n.importFailedError(e.message ?? '$e');
          });
        }
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
            _error = l10n.importFailedError('$e');
          });
        }
      } finally {
        try {
          if (tmp.existsSync()) {
            await tmp.delete(recursive: true);
          }
        } catch (_) {}
      }
      return;
    }

    if (_backupZipPath == null) {
      setState(() => _error = l10n.chooseZipError);
      return;
    }
    final pwd = _backupPassword.text;
    final isPlain = _backupZipIsPlain == true;
    if (!isPlain && pwd.isEmpty) {
      setState(
        () => _error = l10n.enterBackupPasswordError,
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.session.completeOnboardingFromBackup(
        _backupZipPath!,
        isPlain ? '' : pwd,
      );
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
          _error = l10n.importFailedError('$e');
        });
      }
    }
  }

  Future<void> _pickNotionFile() async {
    setState(() => _error = null);
    final pick = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['zip'],
      allowMultiple: false,
    );
    if (!mounted) return;
    final path = pick?.files.single.path;
    if (path != null) {
      setState(() => _notionZipPath = path);
    }
  }

  Future<void> _finishNotionImport() async {
    final l10n = AppLocalizations.of(context);
    if (_notionZipPath == null) {
      setState(() => _error = l10n.chooseZipError);
      return;
    }
    final pwd = _notionPassword.text;
    final confirm = _notionConfirm.text;
    if (pwd.length < _minLen) {
      setState(() => _error = l10n.minCharactersError(_minLen));
      return;
    }
    if (_passwordStrengthFor(pwd) != _PasswordStrength.strong) {
      setState(() => _error = l10n.passwordMustBeStrongError);
      return;
    }
    if (pwd != confirm) {
      setState(() => _error = l10n.passwordMismatchError);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.session.importNotionAsNewVault(
        _notionZipPath!,
        masterPassword: pwd,
        displayName: l10n.importNotionDefaultVaultName,
      );
      await widget.session.unlockWithPassword(pwd);
      await widget.appSettings.setHasSeenQuillIntro(true);
      final warnings = widget.session.lastImportWarnings;
      if (mounted && warnings.isNotEmpty) {
        await _showImportWarningsDialog(warnings);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = l10n.importNotionError('$e');
      });
    }
  }

  Future<void> _showImportWarningsDialog(
    List<NotionImportWarning> warnings,
  ) async {
    final l10n = AppLocalizations.of(context);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: Theme.of(ctx).colorScheme.tertiary,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(l10n.importNotionWarningsTitle)),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l10n.importNotionWarningsBody),
                const SizedBox(height: 12),
                ...warnings.map(
                  (w) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('\u2022 '),
                        Expanded(child: Text(w.message)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.ok),
          ),
        ],
      ),
    );
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
        createStarterPages: _createStarterPages,
      );
      await widget.appSettings.setHasSeenQuillIntro(true);
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
    final flowCard = SingleChildScrollView(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: FolioSpace.lg,
            vertical: FolioSpace.md,
          ),
          child: Card.filled(
            margin: EdgeInsets.zero,
            color: scheme.surface,
            elevation: FolioElevation.none,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(FolioRadius.xxl),
            ),
            child: Padding(
              padding: const EdgeInsets.all(FolioSpace.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Text(
                      'Folio',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
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
                      key: ValueKey('step_$_mode$_page'),
                      child: _buildCurrentStep(context),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: FolioSpace.md),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _error!,
                            style: TextStyle(color: scheme.error),
                          ),
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
    );
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
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 1100;
            if (!wide) {
              return Center(child: flowCard);
            }
            return Padding(
              padding: const EdgeInsets.all(FolioSpace.xl),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.only(right: FolioSpace.xl),
                      padding: const EdgeInsets.all(36),
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer.withValues(
                          alpha: FolioAlpha.panel,
                        ),
                        borderRadius: BorderRadius.circular(FolioRadius.xxl),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: scheme.surface,
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Icon(
                              _mode == _OnboardingMode.backupImport ||
                                      _mode == _OnboardingMode.notionImport
                                  ? Icons.archive_outlined
                                  : Icons.shield_outlined,
                              size: 34,
                              color: scheme.primary,
                            ),
                          ),
                          const SizedBox(height: FolioSpace.xl),
                          Text(
                            _leftPanelTitle(l10n),
                            style: Theme.of(context).textTheme.displaySmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: scheme.onSurface,
                                ),
                          ),
                          const SizedBox(height: FolioSpace.md),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 560),
                            child: Text(
                              _leftPanelBody(l10n),
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                    height: 1.35,
                                  ),
                            ),
                          ),
                          const SizedBox(height: FolioSpace.lg),
                          Chip(
                            avatar: const Icon(Icons.flag_outlined, size: 18),
                            label: Text(_stepLabel),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Center(child: flowCard),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCurrentStep(BuildContext context) {
    if (_page == 0) {
      return _stepWelcome(context);
    }
    if (_mode == _OnboardingMode.backupImport) {
      return _stepImportBackup(context);
    }
    if (_mode == _OnboardingMode.notionImport) {
      return _stepImportNotion(context);
    }
    if (_page == 1) {
      return _stepPassword(context);
    }
    if (_page == 2) {
      return _stepReady(context);
    }
    if (_page == 3) {
      return _stepTelemetry(context);
    }
    if (_page == 4) {
      return _stepFolioCloudIntro(context);
    }
    if (_shouldShowQuillIntro && _page == 5) {
      return _stepQuillIntro(context);
    }
    return _stepFolioCloudIntro(context);
  }

  String _leftPanelTitle(AppLocalizations l10n) {
    switch (_mode) {
      case _OnboardingMode.backupImport:
        return l10n.importBackupTitle;
      case _OnboardingMode.notionImport:
        return l10n.importNotionTitle;
      case _OnboardingMode.create:
        return l10n.welcomeTitle;
    }
  }

  String _leftPanelBody(AppLocalizations l10n) {
    switch (_mode) {
      case _OnboardingMode.backupImport:
        return l10n.importBackupBody;
      case _OnboardingMode.notionImport:
        return l10n.importNotionDialogBody;
      case _OnboardingMode.create:
        return l10n.welcomeBody;
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
          l10n.noEncryptionConfirmTitle,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: FolioSpace.md),
        Text(
          l10n.noEncryptionConfirmBody,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: scheme.onSurfaceVariant,
            height: 1.45,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: FolioSpace.xl),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          secondary: const Icon(Icons.auto_awesome_motion_rounded),
          title: Text(AppLocalizations.of(context).createStarterPagesTitle),
          subtitle: Text(AppLocalizations.of(context).createStarterPagesBody),
          value: _createStarterPages,
          onChanged: _busy
              ? null
              : (value) {
                  setState(() => _createStarterPages = value);
                },
        ),
        const SizedBox(height: FolioSpace.lg),
        Row(
          children: [
            TextButton(
              onPressed: () {
                setState(() {
                  _createWithoutEncryption = false;
                  _page = 0;
                });
              },
              child: Text(l10n.back),
            ),
            const SizedBox(width: FolioSpace.md),
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size(120, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(FolioRadius.md),
                ),
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
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(FolioRadius.md),
            ),
          ),
          onPressed: _chooseCreateNew,
          child: Text(AppLocalizations.of(context).createNewVault),
        ),
        const SizedBox(height: FolioSpace.md),
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(FolioRadius.md),
            ),
          ),
          onPressed: () {
            setState(() {
              _error = null;
              _mode = _OnboardingMode.create;
              _createWithoutEncryption = true;
              _createStarterPages = true;
              _onboardingTelemetryEnabled = widget.appSettings.telemetryEnabled;
            });
            _goPage(1);
          },
          child: Text(
            AppLocalizations.of(context).createVaultWithoutEncryption,
          ),
        ),
        const SizedBox(height: FolioSpace.md),
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(FolioRadius.md),
            ),
          ),
          onPressed: _chooseImportBackup,
          child: Text(AppLocalizations.of(context).importBackupZip),
        ),
        const SizedBox(height: FolioSpace.md),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(FolioRadius.md),
            ),
          ),
          onPressed: _busy ? null : _signInAndPickCloudBackup,
          icon: const Icon(Icons.cloud_download_outlined),
          label: Text(AppLocalizations.of(context).onboardingCloudBackupCta),
        ),
        const SizedBox(height: FolioSpace.md),
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(FolioRadius.md),
            ),
          ),
          onPressed: _chooseImportNotion,
          child: Text(AppLocalizations.of(context).importNotionTitle),
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
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: FolioSpace.md),
        Text(
          _onboardingCloudPackVaultId != null
              ? AppLocalizations.of(context).onboardingCloudBackupIncrementalRestoreBody
              : AppLocalizations.of(context).importBackupBody,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            height: 1.45,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: FolioSpace.xl),
        if (_onboardingCloudPackVaultId == null) ...[
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
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
        ] else ...[
          Icon(
            Icons.cloud_sync_outlined,
            size: 48,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: FolioSpace.md),
        ],
        const SizedBox(height: FolioSpace.lg),
        if (_onboardingCloudPackVaultId == null &&
            _backupZipPath != null &&
            _backupZipIsPlain == true)
          Text(
            AppLocalizations.of(context).backupPlainNoPasswordHint,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.35,
            ),
            textAlign: TextAlign.center,
          )
        else if (_onboardingCloudPackVaultId != null ||
            _backupZipPath != null)
          FolioPasswordField(
            controller: _backupPassword,
            obscureText: _obscureBackupPassword,
            enabled: !_busy,
            labelText: AppLocalizations.of(context).backupPasswordLabel,
            showPasswordTooltip: AppLocalizations.of(context).showPassword,
            hidePasswordTooltip: AppLocalizations.of(context).hidePassword,
            onToggleObscure: () {
              setState(() => _obscureBackupPassword = !_obscureBackupPassword);
            },
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
                        _onboardingCloudPackVaultId = null;
                      });
                    },
              child: Text(AppLocalizations.of(context).back),
            ),
            const SizedBox(width: FolioSpace.md),
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size(120, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(FolioRadius.md),
                ),
              ),
              onPressed: _busy ? null : _finishImport,
              child: _busy
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: ScaleTransition(
                        scale: AlwaysStoppedAnimation(1.0),
                        child: const CircularProgressIndicator(strokeWidth: 2),
                      ),
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
      _PasswordStrength.veryWeak => AppLocalizations.of(
        context,
      ).passwordStrengthVeryWeak,
      _PasswordStrength.weak => AppLocalizations.of(
        context,
      ).passwordStrengthWeak,
      _PasswordStrength.fair => AppLocalizations.of(
        context,
      ).passwordStrengthFair,
      _PasswordStrength.strong => AppLocalizations.of(
        context,
      ).passwordStrengthStrong,
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
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
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
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          secondary: const Icon(Icons.auto_awesome_motion_rounded),
          title: Text(AppLocalizations.of(context).createStarterPagesTitle),
          subtitle: Text(AppLocalizations.of(context).createStarterPagesBody),
          value: _createStarterPages,
          onChanged: _busy
              ? null
              : (value) {
                  setState(() => _createStarterPages = value);
                },
        ),
        const SizedBox(height: FolioSpace.md),
        FolioPasswordField(
          controller: _password,
          obscureText: _obscurePassword,
          labelText: AppLocalizations.of(context).passwordLabel,
          showPasswordTooltip: AppLocalizations.of(context).showPassword,
          hidePasswordTooltip: AppLocalizations.of(context).hidePassword,
          onToggleObscure: () {
            setState(() => _obscurePassword = !_obscurePassword);
          },
          onChanged: (_) => setState(() {}),
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
        FolioPasswordField(
          controller: _confirm,
          obscureText: _obscureConfirm,
          labelText: AppLocalizations.of(context).confirmPasswordLabel,
          showPasswordTooltip: AppLocalizations.of(context).showPassword,
          hidePasswordTooltip: AppLocalizations.of(context).hidePassword,
          onToggleObscure: () {
            setState(() => _obscureConfirm = !_obscureConfirm);
          },
          onSubmitted: (_) => _nextCreatePassword(),
        ),
        const SizedBox(height: FolioSpace.xl),
        Row(
          children: [
            TextButton(
              onPressed: () {
                setState(() {
                  _page = 0;
                  _mode = _OnboardingMode.create;
                });
              },
              child: Text(AppLocalizations.of(context).back),
            ),
            const SizedBox(width: FolioSpace.md),
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size(120, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(FolioRadius.md),
                ),
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
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
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
                  _mode = _OnboardingMode.create;
                });
              },
              child: Text(AppLocalizations.of(context).back),
            ),
            const SizedBox(width: FolioSpace.md),
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size(120, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(FolioRadius.md),
                ),
              ),
              onPressed: _busy
                  ? null
                  : () {
                      _goPage(3);
                    },
              child: _busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(AppLocalizations.of(context).continueAction),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _persistTelemetryAndGoToCloud() async {
    await widget.appSettings.setTelemetryEnabled(_onboardingTelemetryEnabled);
    await FolioTelemetry.onSettingsChanged(widget.appSettings);
    if (!mounted) return;
    _goPage(4);
  }

  Widget _stepTelemetry(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: FolioSpace.xl),
        Icon(Icons.analytics_outlined, size: 64, color: scheme.primary),
        const SizedBox(height: FolioSpace.lg),
        Text(
          l10n.onboardingTelemetryTitle,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: FolioSpace.md),
        Text(
          l10n.onboardingTelemetryBody,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: scheme.onSurfaceVariant,
            height: 1.45,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: FolioSpace.lg),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          secondary: const Icon(Icons.insights_outlined),
          title: Text(l10n.onboardingTelemetrySwitchTitle),
          subtitle: Text(l10n.onboardingTelemetrySwitchSubtitle),
          value: _onboardingTelemetryEnabled,
          onChanged: _busy
              ? null
              : (v) {
                  setState(() => _onboardingTelemetryEnabled = v);
                },
        ),
        const SizedBox(height: FolioSpace.sm),
        Text(
          l10n.onboardingTelemetryFootnote,
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
            height: 1.35,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: FolioSpace.xl),
        Row(
          children: [
            TextButton(
              onPressed: _busy ? null : () => _goPage(2),
              child: Text(l10n.back),
            ),
            const SizedBox(width: FolioSpace.md),
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size(120, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(FolioRadius.md),
                ),
              ),
              onPressed: _busy ? null : () => unawaited(_persistTelemetryAndGoToCloud()),
              child: Text(l10n.continueAction),
            ),
          ],
        ),
      ],
    );
  }

  Widget _stepFolioCloudIntro(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    Widget feature({
      required IconData icon,
      required String title,
      required String body,
    }) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(FolioRadius.lg),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: FolioAlpha.border),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: scheme.primary, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    body,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: FolioSpace.lg),
        Icon(Icons.cloud_outlined, size: 64, color: scheme.primary),
        const SizedBox(height: FolioSpace.lg),
        Text(
          l10n.onboardingFolioCloudTitle,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: FolioSpace.md),
        Text(
          l10n.onboardingFolioCloudBody,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: scheme.onSurfaceVariant,
            height: 1.45,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: FolioSpace.lg),
        feature(
          icon: Icons.backup_outlined,
          title: l10n.onboardingFolioCloudFeatureBackupTitle,
          body: l10n.onboardingFolioCloudFeatureBackupBody,
        ),
        const SizedBox(height: FolioSpace.sm),
        feature(
          icon: Icons.auto_awesome_outlined,
          title: l10n.onboardingFolioCloudFeatureAiTitle,
          body: l10n.onboardingFolioCloudFeatureAiBody,
        ),
        const SizedBox(height: FolioSpace.sm),
        feature(
          icon: Icons.public_outlined,
          title: l10n.onboardingFolioCloudFeatureWebTitle,
          body: l10n.onboardingFolioCloudFeatureWebBody,
        ),
        const SizedBox(height: FolioSpace.xl),
        Row(
          children: [
            TextButton(
              onPressed: _busy ? null : () => _goPage(3),
              child: Text(l10n.back),
            ),
            const SizedBox(width: FolioSpace.md),
            TextButton(
              onPressed: _busy
                  ? null
                  : () {
                      if (_shouldShowQuillIntro) {
                        _goPage(5);
                      } else {
                        _finishCreate();
                      }
                    },
              child: Text(l10n.onboardingFolioCloudLaterInSettings),
            ),
            const SizedBox(width: FolioSpace.md),
            FilledButton(
              onPressed: _busy
                  ? null
                  : () {
                      if (_shouldShowQuillIntro) {
                        _goPage(5);
                      } else {
                        _finishCreate();
                      }
                    },
              child: Text(l10n.continueAction),
            ),
          ],
        ),
      ],
    );
  }

  Widget _stepQuillIntro(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    Widget capability(IconData icon, String text) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(FolioRadius.lg),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: FolioAlpha.border),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: scheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.35),
              ),
            ),
          ],
        ),
      );
    }

    Widget exampleChip(String text) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: scheme.primaryContainer.withValues(alpha: FolioAlpha.emphasis),
          borderRadius: BorderRadius.circular(FolioRadius.xl),
        ),
        child: Text(
          text,
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onPrimaryContainer,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: FolioSpace.lg),
        Icon(Icons.auto_awesome_rounded, size: 64, color: scheme.primary),
        const SizedBox(height: FolioSpace.lg),
        Text(
          l10n.quillIntroTitle,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: FolioSpace.md),
        Text(
          l10n.quillIntroBody,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: scheme.onSurfaceVariant,
            height: 1.45,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: FolioSpace.lg),
        capability(Icons.edit_note_rounded, l10n.quillIntroCapabilityWrite),
        const SizedBox(height: FolioSpace.sm),
        capability(
          Icons.text_snippet_outlined,
          l10n.quillIntroCapabilityExplain,
        ),
        const SizedBox(height: FolioSpace.sm),
        capability(Icons.menu_book_outlined, l10n.quillIntroCapabilityContext),
        const SizedBox(height: FolioSpace.sm),
        capability(
          Icons.lightbulb_outline_rounded,
          l10n.quillIntroCapabilityExamples,
        ),
        const SizedBox(height: FolioSpace.lg),
        Text(
          l10n.quillIntroExamplesTitle,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: FolioSpace.sm),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            exampleChip(l10n.quillIntroExampleOne),
            exampleChip(l10n.quillIntroExampleTwo),
            exampleChip(l10n.quillIntroExampleThree),
          ],
        ),
        const SizedBox(height: FolioSpace.md),
        Text(
          l10n.quillIntroFootnote,
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
            height: 1.35,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: FolioSpace.xl),
        Row(
          children: [
            TextButton(
              onPressed: _busy ? null : () => _goPage(4),
              child: Text(l10n.back),
            ),
            const SizedBox(width: FolioSpace.md),
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size(120, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(FolioRadius.md),
                ),
              ),
              onPressed: _busy ? null : _finishCreate,
              child: _busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.createVault),
            ),
          ],
        ),
      ],
    );
  }

  Widget _stepImportNotion(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: FolioSpace.xl),
        Icon(
          Icons.note_alt_outlined,
          size: 64,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(height: FolioSpace.lg),
        Text(
          l10n.importNotionDialogTitle,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: FolioSpace.md),
        Text(
          l10n.importNotionDialogBody,
          style: theme.textTheme.bodyLarge?.copyWith(
            height: 1.45,
            color: scheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: FolioSpace.md),
        Container(
          padding: const EdgeInsets.all(FolioSpace.md),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(FolioRadius.lg),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: FolioAlpha.border),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.notionExportGuideTitle,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: FolioSpace.xs),
              Text(
                l10n.notionExportGuideBody,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: FolioSpace.lg),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(FolioRadius.md),
            ),
          ),
          onPressed: _busy ? null : _pickNotionFile,
          icon: const Icon(Icons.folder_open_outlined),
          label: Text(
            _notionZipPath == null ? l10n.chooseZipFile : l10n.changeFile,
          ),
        ),
        if (_notionZipPath != null) ...[
          const SizedBox(height: FolioSpace.sm),
          Text(
            _notionZipPath!,
            style: theme.textTheme.bodySmall,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: FolioSpace.md),
        FolioPasswordField(
          controller: _notionPassword,
          obscureText: _obscureNotionPassword,
          enabled: !_busy,
          labelText: l10n.passwordLabel,
          showPasswordTooltip: l10n.showPassword,
          hidePasswordTooltip: l10n.hidePassword,
          onToggleObscure: () {
            setState(() => _obscureNotionPassword = !_obscureNotionPassword);
          },
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: FolioSpace.sm),
        FolioPasswordField(
          controller: _notionConfirm,
          obscureText: _obscureNotionConfirm,
          enabled: !_busy,
          labelText: l10n.confirmPasswordLabel,
          showPasswordTooltip: l10n.showPassword,
          hidePasswordTooltip: l10n.hidePassword,
          onToggleObscure: () {
            setState(() => _obscureNotionConfirm = !_obscureNotionConfirm);
          },
          onSubmitted: (_) {
            if (!_busy) _finishNotionImport();
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
                        _mode = _OnboardingMode.create;
                      });
                    },
              child: Text(l10n.back),
            ),
            const SizedBox(width: FolioSpace.md),
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size(120, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(FolioRadius.md),
                ),
              ),
              onPressed: _busy ? null : _finishNotionImport,
              child: _busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.importAction),
            ),
          ],
        ),
      ],
    );
  }
}

enum _OnboardingMode { create, backupImport, notionImport }

class _CloudBackupPickerDialog extends StatelessWidget {
  const _CloudBackupPickerDialog({required this.l10n, required this.items});

  final AppLocalizations l10n;
  final List<FolioCloudBackupEntry> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return AlertDialog(
      title: Text(
        l10n.folioCloudCloudBackupsList,
        style: theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w800,
        ),
      ),
      content: SizedBox(
        width: 520,
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: items.length,
          separatorBuilder: (context, index) => Divider(
            height: 1,
            color: scheme.outlineVariant.withValues(alpha: 0.45),
          ),
          itemBuilder: (context, i) {
            final e = items[i];
            return ListTile(
              leading: Icon(
                e.isCloudPack ? Icons.cloud_sync_outlined : Icons.archive_outlined,
              ),
              title: Text(
                e.fileName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                l10n.importBackupBody,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              onTap: () => Navigator.of(context).pop(e),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
      ],
    );
  }
}

class _CloudVaultPickerDialog extends StatelessWidget {
  const _CloudVaultPickerDialog({required this.l10n, required this.vaults});

  final AppLocalizations l10n;
  final List<FolioCloudBackupVaultEntry> vaults;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return AlertDialog(
      title: Text(
        l10n.folioCloudCloudBackupsList,
        style: theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w800,
        ),
      ),
      content: SizedBox(
        width: 520,
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: vaults.length,
          separatorBuilder: (context, index) => Divider(
            height: 1,
            color: scheme.outlineVariant.withValues(alpha: 0.45),
          ),
          itemBuilder: (context, i) {
            final v = vaults[i];
            return ListTile(
              leading: const Icon(Icons.folder_outlined),
              title: Text(
                v.displayName.isNotEmpty ? v.displayName : v.vaultId,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              subtitle: Text(
                l10n.onboardingCloudBackupPickVaultSubtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              onTap: () => Navigator.of(context).pop(v.vaultId),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
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
