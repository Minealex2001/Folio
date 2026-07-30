import 'dart:async' show unawaited;
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';

import '../../app/app_settings.dart';
import '../../app/ui_tokens.dart';
import '../../app/widgets/folio_dialog.dart';
import '../../app/widgets/folio_password_field.dart';
import '../../app/widgets/folio_skeletons.dart';
import '../../app/widgets/web_desktop_only_notice.dart';
import '../../crypto/vault_crypto.dart';
import '../../data/notion_import/notion_importer.dart';
import '../../data/vault_backup.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../models/folio_usage_intent.dart';
import '../../session/vault_session.dart';
import '../../services/cloud_account/cloud_account_controller.dart';
import '../../services/folio_cloud/folio_cloud_entitlements.dart';
import '../../services/folio_cloud/folio_cloud_pack_sync.dart';
import '../../services/folio_cloud/folio_cloud_reachability.dart';
import '../../services/folio_telemetry.dart';
import '../../services/app_logger.dart';
import '../settings/folio_cloud_import_all_dialog.dart';
import '../settings/folio_cloud_reauth_dialog.dart';
import 'cloud_sign_in_dialog.dart';
import 'onboarding_cloud_pitch_step.dart';

import '../../services/folio_cloud/folio_cloud_exception.dart';
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
  bool? _onboardingCloudPackIsPlain;
  String? _error;
  var _busy = false;
  var _obscurePassword = true;
  var _obscureConfirm = true;
  var _obscureBackupPassword = true;
  var _obscureNotionPassword = true;
  var _obscureNotionConfirm = true;
  var _createWithoutEncryption = false;
  var _createStarterPages = true;
  List<FolioUsageIntent> _selectedUsageIntents = const [FolioUsageIntent.notes];
  String? _usageProfileError;

  /// ElecciÃ³n en onboarding (se persiste al salir del paso).
  /// Default: true (telemetrÃ­a habilitada, puede desactivarse en Settings)
  var _onboardingTelemetryEnabled = true;

  static const _minLen = 10;

  _PasswordStrength get _passwordStrength =>
      _passwordStrengthFor(_password.text);

  bool get _shouldShowQuillIntro => !widget.appSettings.hasSeenQuillIntro;

  bool get _isFirstOnboarding => !widget.session.canCancelNewVaultOnboarding;

  /// Borradores de pasos de configuraciÃ³n (solo se persisten al pulsar Continuar).
  late FolioThemeMode _draftThemeMode;
  late FolioAccentColorMode _draftAccentMode;
  late int _draftCustomAccentArgb;
  late int _draftIdleLockMinutes;
  late bool _draftLockOnMinimize;
  late bool _draftScheduledBackupEnabled;
  late int _draftScheduledBackupIntervalMinutes;
  late String _draftScheduledBackupDirectory;
  late bool _draftScheduledBackupAlsoUploadCloud;
  late bool _draftMinimizeToTray;
  late bool _draftCloseToTray;
  late bool _draftWindowsNotificationsEnabled;

  @override
  void initState() {
    super.initState();
    _selectedUsageIntents = List<FolioUsageIntent>.from(
      widget.appSettings.usageIntents,
    );
    _syncDraftsFromAppSettings();
  }

  void _syncDraftsFromAppSettings() {
    final s = widget.appSettings;
    _draftThemeMode = s.themeMode;
    _draftAccentMode = s.accentColorMode;
    _draftCustomAccentArgb = s.customAccentArgb;
    _draftIdleLockMinutes = _coerceIdleLockMinutes(s.vaultIdleLockMinutes);
    _draftLockOnMinimize = s.vaultLockOnMinimize;
    _draftScheduledBackupEnabled = s.scheduledVaultBackupEnabled;
    _draftScheduledBackupIntervalMinutes = s.scheduledVaultBackupIntervalMinutes;
    _draftScheduledBackupDirectory = s.scheduledVaultBackupDirectory;
    _draftScheduledBackupAlsoUploadCloud = s.scheduledVaultBackupAlsoUploadCloud;
    _draftMinimizeToTray = s.minimizeToTray;
    _draftCloseToTray = s.closeToTray;
    _draftWindowsNotificationsEnabled = s.windowsNotificationsEnabled;
  }

  List<_OnboardingStepId> _buildFlowSteps() {
    switch (_mode) {
      case _OnboardingMode.importChooser:
        return const [
          _OnboardingStepId.welcome,
          _OnboardingStepId.importChooser,
        ];
      case _OnboardingMode.backupImport:
        return const [
          _OnboardingStepId.welcome,
          _OnboardingStepId.importChooser,
          _OnboardingStepId.importBackupForm,
        ];
      case _OnboardingMode.notionImport:
        return const [
          _OnboardingStepId.welcome,
          _OnboardingStepId.importChooser,
          _OnboardingStepId.importNotionForm,
        ];
      case _OnboardingMode.create:
        final steps = <_OnboardingStepId>[
          _OnboardingStepId.welcome,
          _OnboardingStepId.vaultSetup,
        ];
        if (_isFirstOnboarding) {
          steps.add(_OnboardingStepId.usageProfile);
          steps.addAll([
            _OnboardingStepId.personalize,
            _OnboardingStepId.reliability,
            _OnboardingStepId.privacyTrust,
            if (_folio.isAvailable) _OnboardingStepId.folioCloud,
            if (_shouldShowQuillIntro) _OnboardingStepId.quillIntro,
          ]);
        } else {
          steps.add(_OnboardingStepId.usageProfile);
        }
        steps.add(_OnboardingStepId.ready);
        return steps;
    }
  }

  List<_OnboardingStepId> get _flowSteps => _buildFlowSteps();

  _OnboardingStepId get _currentStepId {
    final steps = _flowSteps;
    if (_page < 0 || _page >= steps.length) {
      return steps.isNotEmpty ? steps.first : _OnboardingStepId.welcome;
    }
    return steps[_page];
  }

  void _goNext() {
    final steps = _flowSteps;
    if (_page < steps.length - 1) {
      setState(() => _page++);
      AppLogger.debug(
        'onboarding next',
        tag: 'onboarding',
        context: {
          'mode': _mode.name,
          'page': _page,
          'step': _currentStepId.name,
        },
      );
    }
  }

  void _goBack() {
    if (_page <= 0) return;
    setState(() {
      _page--;
      _syncDraftsFromAppSettings();
    });
    AppLogger.debug(
      'onboarding back',
      tag: 'onboarding',
      context: {
        'mode': _mode.name,
        'page': _page,
        'step': _currentStepId.name,
      },
    );
  }

  ButtonStyle get _onboardingPrimaryButtonStyle => FilledButton.styleFrom(
        minimumSize: const Size(120, 48),
        padding: const EdgeInsets.symmetric(horizontal: FolioSpace.md),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FolioRadius.md),
        ),
      );

  /// Barra inferior unificada: [AtrÃ¡s] Â· espacio Â· [widgets opcionales] Â· [principal].
  Widget _onboardingBottomActions({
    required VoidCallback? onBack,
    VoidCallback? onPrimary,
    String? primaryLabel,
    Widget? primaryChild,
    bool primaryBusy = false,
    List<Widget>? beforePrimary,
  }) {
    final l10n = AppLocalizations.of(context);
    final children = <Widget>[
      TextButton(onPressed: onBack, child: Text(l10n.back)),
      const Spacer(),
    ];
    if (beforePrimary != null) {
      for (final w in beforePrimary) {
        children.add(w);
      }
    }
    if (onPrimary != null) {
      children.add(
        FilledButton(
          style: _onboardingPrimaryButtonStyle,
          onPressed: primaryBusy ? null : onPrimary,
          child: primaryBusy
              ? const FolioLoadingIndicator(size: FolioLoadingSize.small)
              : (primaryChild ?? Text(primaryLabel ?? l10n.continueAction)),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: FolioSpace.xl),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: children,
      ),
    );
  }

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

  void _chooseCreateNew() {
    AppLogger.info('choose create new vault', tag: 'onboarding');
    setState(() {
      _error = null;
      _mode = _OnboardingMode.create;
      _createStarterPages = true;
      _selectedUsageIntents = List<FolioUsageIntent>.from(
        widget.appSettings.usageIntents,
      );
      _usageProfileError = null;
      _onboardingTelemetryEnabled = widget.appSettings.telemetryEnabled;
      _page = 1;
    });
  }

  void _chooseImportSource() {
    AppLogger.info('choose import source', tag: 'onboarding');
    setState(() {
      _error = null;
      _mode = _OnboardingMode.importChooser;
      _page = 1;
    });
  }

  void _chooseImportBackup() {
    setState(() {
      _error = null;
      _mode = _OnboardingMode.backupImport;
      _backupZipPath = null;
      _onboardingCloudPackVaultId = null;
      _onboardingCloudPackIsPlain = null;
      _page = 2;
    });
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
      case 'password-reset-required':
        return l10n.cloudAuthErrorPasswordResetRequired;
      case 'invalid-token':
        return l10n.cloudAuthErrorInvalidToken;
      case 'token-expired':
        return l10n.cloudAuthErrorTokenExpired;
      case 'token-used':
        return l10n.cloudAuthErrorTokenUsed;
      case 'already-verified':
        return l10n.cloudAccountVerificationNowVerified;
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

    String? accountPassword;

    // 1) Sign in if needed (captures account password for restore).
    if (!_cloud.isSignedIn) {
      accountPassword = await showDialog<String>(
        context: context,
        barrierDismissible: true,
        builder: (ctx) => CloudSignInDialog(
          l10n: l10n,
          cloud: _cloud,
          onAuthError: (c) => _cloudAuthErrorMessage(l10n, c),
        ),
      );
      if (!mounted || accountPassword == null || accountPassword.isEmpty) {
        return;
      }
    } else {
      // 2) Reauth captures account password for restore unwrap.
      final userEmail = _cloud.email?.trim();
      if (userEmail == null || userEmail.isEmpty) {
        setState(() => _error = l10n.cloudAuthErrorGeneric);
        return;
      }
      if (!mounted) return;
      accountPassword = await showDialog<String>(
        context: context,
        barrierDismissible: true,
        builder: (ctx) => FolioCloudReauthDialog(
          l10n: l10n,
          cloud: _cloud,
          initialEmail: userEmail,
          onAuthError: (c) => _cloudAuthErrorMessage(l10n, c),
        ),
      );
      if (!mounted || accountPassword == null || accountPassword.isEmpty) {
        return;
      }
    }

    setState(() => _busy = true);
    try {
      final result = await showFolioCloudImportAllVaultsFlow(
        context: context,
        session: widget.session,
        entitlements: _folio,
        accountPassword: accountPassword,
        telemetrySettings: widget.appSettings,
        skipWarning: true,
      );
      if (!mounted) return;
      if (result == null || !result.hasImports) {
        setState(() {
          _busy = false;
          if (result != null && result.imported == 0 && result.failed == 0) {
            _error = l10n.folioCloudImportAllNone;
          }
        });
        return;
      }

      final firstId = result.firstImportedVaultId;
      if (firstId != null) {
        await widget.session.switchVault(firstId);
        final unlockPwd =
            result.firstRestorePassword ?? accountPassword;
        try {
          await widget.session.unlockWithPassword(unlockPwd);
        } catch (_) {
          // La libreta queda bloqueada; el usuario desbloquea con su master.
        }
      }
      if (!mounted) return;
      setState(() => _busy = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = '$e';
      });
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  void _chooseImportNotion() {
    setState(() {
      _error = null;
      _mode = _OnboardingMode.notionImport;
      _notionZipPath = null;
      _notionPassword.clear();
      _notionConfirm.clear();
      _page = 2;
    });
  }

  void _nextCreatePassword() {
    setState(() {
      _error = null;
      if (_currentStepId != _OnboardingStepId.vaultSetup) return;
      if (_createWithoutEncryption) {
        _page++;
        return;
      }
      final p = _password.text;
      final c = _confirm.text;
      if (p.length < _minLen) {
        _error = AppLocalizations.of(context).minCharactersError(_minLen);
        return;
      }
      if (!_meetsVaultMasterPasswordPolicy(_passwordStrength)) {
        _error = AppLocalizations.of(context).passwordMustBeStrongError;
        return;
      }
      if (p != c) {
        _error = AppLocalizations.of(context).passwordMismatchError;
        return;
      }
      _page++;
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
        _onboardingCloudPackIsPlain = null;
      });
      try {
        final plain = await isPlainBackupZip(File(path));
        if (!mounted) return;
        setState(() => _backupZipIsPlain = plain);
      } catch (_) {
        // Si no se puede inspeccionar, mantenemos el comportamiento anterior (pedir contraseÃ±a).
        if (mounted) setState(() => _backupZipIsPlain = null);
      }
    }
  }

  Future<void> _finishImport() async {
    final l10n = AppLocalizations.of(context);
    if (_onboardingCloudPackVaultId != null) {
      final vid = _onboardingCloudPackVaultId!;
      final pwd = _backupPassword.text.trim();
      setState(() {
        _busy = true;
        _error = null;
      });
      try {
        final backup = await downloadCloudPackToMemoryForRestore(
          vaultId: vid,
          restorePassword: pwd,
          entitlementSnapshot: _folio.snapshot,
          telemetrySettings: widget.appSettings,
        );
        final isPlain = await isPlainExtractedBackup(backup);
        final vaultPwd = isPlain ? '' : pwd;
        await widget.session.completeOnboardingFromMemory(backup, vaultPwd);
      } on VaultCryptoException catch (e) {
        if (mounted) {
          setState(() {
            _error = '$e';
          });
        }
      } on FolioCloudException catch (e) {
        if (mounted) {
          final isWrap = e.code.toLowerCase() == 'failed-precondition';
          setState(() {
            _error = isWrap
                ? l10n.onboardingCloudBackupNeedRestoreWrap
                : l10n.importFailedError(e.message ?? '$e');
          });
        }
      } on VaultBackupException catch (e) {
        if (mounted) {
          setState(() {
            _error = '$e';
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _error = l10n.importFailedError('$e');
          });
        }
      } finally {
        if (mounted) {
          setState(() => _busy = false);
        }
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
      setState(() => _error = l10n.enterBackupPasswordError);
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
          _error = '$e';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = l10n.importFailedError('$e');
        });
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
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
    if (!_meetsVaultMasterPasswordPolicy(_passwordStrengthFor(pwd))) {
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
      builder: (ctx) => FolioDialog(
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
    AppLogger.info(
      'finishCreate start',
      tag: 'onboarding',
      context: {
        'encrypted': !_createWithoutEncryption,
        'starterPages': _createStarterPages,
      },
    );
    try {
      await widget.session.completeOnboarding(
        password: _createWithoutEncryption ? null : _password.text,
        encrypted: !_createWithoutEncryption,
        createStarterPages: _createStarterPages,
        usageIntents: _selectedUsageIntents,
        includeQuillStarterPage: _flowSteps.contains(
          _OnboardingStepId.quillIntro,
        ),
      );
      await widget.appSettings.setHasSeenQuillIntro(true);
      AppLogger.info('finishCreate ok', tag: 'onboarding');
    } catch (e) {
      AppLogger.error(
        'finishCreate failed',
        tag: 'onboarding',
        error: e,
      );
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
                      l10n.appTitle,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: scheme.primary,
                          ),
                    ),
                  ),
                  const SizedBox(height: FolioSpace.xs),
                  Semantics(
                    label: l10n.onboardingProgressSemantics(
                      _page + 1,
                      _flowSteps.length,
                    ),
                    child: _StepSegments(
                      current: _page + 1,
                      total: _flowSteps.length,
                    ),
                  ),
                  const SizedBox(height: FolioSpace.lg),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: KeyedSubtree(
                      key: ValueKey(
                        'step_${_mode}_${_page}_${_currentStepId.name}',
                      ),
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
                              _leftPanelIcon(),
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
                          Semantics(
                            label: l10n.onboardingProgressSemantics(
                              _page + 1,
                              _flowSteps.length,
                            ),
                            child: _StepSegments(
                              current: _page + 1,
                              total: _flowSteps.length,
                            ),
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
    switch (_currentStepId) {
      case _OnboardingStepId.welcome:
        return _stepWelcome(context);
      case _OnboardingStepId.importChooser:
        return _stepImportSource(context);
      case _OnboardingStepId.importBackupForm:
        return _stepImportBackup(context);
      case _OnboardingStepId.importNotionForm:
        return _stepImportNotion(context);
      case _OnboardingStepId.vaultSetup:
        return _stepPassword(context);
      case _OnboardingStepId.ready:
        return _stepReady(context);
      case _OnboardingStepId.personalize:
        return _stepPersonalize(context);
      case _OnboardingStepId.reliability:
        return _stepReliability(context);
      case _OnboardingStepId.privacyTrust:
        return _stepPrivacyTrust(context);
      case _OnboardingStepId.folioCloud:
        return _stepFolioCloud(context);
      case _OnboardingStepId.quillIntro:
        return _stepQuillIntro(context);
      case _OnboardingStepId.usageProfile:
        return _stepUsageProfile(context);
    }
  }

  IconData _leftPanelIcon() {
    switch (_currentStepId) {
      case _OnboardingStepId.importChooser:
      case _OnboardingStepId.importBackupForm:
      case _OnboardingStepId.importNotionForm:
        return Icons.archive_outlined;
      case _OnboardingStepId.personalize:
        return Icons.palette_outlined;
      case _OnboardingStepId.reliability:
        return Icons.backup_outlined;
      case _OnboardingStepId.privacyTrust:
        return Icons.verified_user_outlined;
      case _OnboardingStepId.folioCloud:
        return Icons.cloud_outlined;
      case _OnboardingStepId.quillIntro:
        return FolioIcons.quill;
      case _OnboardingStepId.usageProfile:
        return Icons.tune_rounded;
      case _OnboardingStepId.ready:
        return Icons.celebration_outlined;
      default:
        return Icons.shield_outlined;
    }
  }

  String _leftPanelTitle(AppLocalizations l10n) {
    if (!_isFirstOnboarding &&
        (_currentStepId == _OnboardingStepId.welcome ||
            _currentStepId == _OnboardingStepId.vaultSetup ||
            _currentStepId == _OnboardingStepId.usageProfile ||
            _currentStepId == _OnboardingStepId.ready)) {
      return l10n.newVaultLeftPanelTitle;
    }
    switch (_currentStepId) {
      case _OnboardingStepId.importChooser:
        return l10n.importSourceTitle;
      case _OnboardingStepId.importBackupForm:
        return l10n.importBackupTitle;
      case _OnboardingStepId.importNotionForm:
        return l10n.importNotionTitle;
      case _OnboardingStepId.personalize:
        return l10n.onboardingPersonalizeTitle;
      case _OnboardingStepId.reliability:
        return l10n.onboardingReliabilityTitle;
      case _OnboardingStepId.privacyTrust:
        return l10n.onboardingPrivacyTrustTitle;
      case _OnboardingStepId.folioCloud:
        return l10n.onboardingFolioCloudTitle;
      case _OnboardingStepId.quillIntro:
        return l10n.quillIntroTitle;
      case _OnboardingStepId.usageProfile:
        return l10n.onboardingUsageProfileTitle;
      case _OnboardingStepId.ready:
        return l10n.readyTitle;
      default:
        return l10n.welcomeTitle;
    }
  }

  String _leftPanelBody(AppLocalizations l10n) {
    if (!_isFirstOnboarding &&
        (_currentStepId == _OnboardingStepId.welcome ||
            _currentStepId == _OnboardingStepId.vaultSetup ||
            _currentStepId == _OnboardingStepId.usageProfile ||
            _currentStepId == _OnboardingStepId.ready)) {
      return l10n.newVaultLeftPanelBody;
    }
    switch (_currentStepId) {
      case _OnboardingStepId.importChooser:
        return l10n.importSourceBody;
      case _OnboardingStepId.importBackupForm:
        return l10n.importBackupBody;
      case _OnboardingStepId.importNotionForm:
        return l10n.importNotionDialogBody;
      case _OnboardingStepId.personalize:
        return l10n.onboardingPersonalizeBody;
      case _OnboardingStepId.reliability:
        return l10n.onboardingReliabilityBody;
      case _OnboardingStepId.privacyTrust:
        return l10n.onboardingPrivacyTrustBody;
      case _OnboardingStepId.folioCloud:
        return l10n.onboardingFolioCloudBody;
      case _OnboardingStepId.quillIntro:
        return l10n.quillIntroBody;
      case _OnboardingStepId.usageProfile:
        return l10n.onboardingUsageProfileBody;
      case _OnboardingStepId.ready:
        return _createWithoutEncryption
            ? l10n.readyBodyPlainVault
            : l10n.readyBody;
      default:
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
        _onboardingBottomActions(
          onBack: () {
            setState(() {
              _createWithoutEncryption = false;
              _page = 0;
              _syncDraftsFromAppSettings();
            });
          },
          onPrimary: _nextCreatePassword,
          primaryLabel: l10n.continueAction,
        ),
      ],
    );
  }

  Widget _welcomeCreateCard(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(FolioSpace.md),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: FolioAlpha.soft),
        borderRadius: BorderRadius.circular(FolioRadius.xl),
        border: Border.all(
          color: scheme.primary.withValues(alpha: 0.55),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(FolioRadius.md),
            ),
            child: Icon(
              Icons.add_circle_outline_rounded,
              color: scheme.primary,
              size: 26,
            ),
          ),
          const SizedBox(height: FolioSpace.sm),
          Text(
            l10n.welcomeOptionCreateTitle,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: FolioSpace.xs),
          Text(
            l10n.welcomeOptionCreateBody,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
          const SizedBox(height: FolioSpace.sm),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.createVaultWithoutEncryption),
            subtitle: Text(
              l10n.plainVaultSecurityNotice,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            value: _createWithoutEncryption,
            onChanged: (v) {
              setState(() => _createWithoutEncryption = v);
            },
          ),
          const SizedBox(height: FolioSpace.sm),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: _onboardingPrimaryButtonStyle,
              onPressed: _chooseCreateNew,
              child: Text(l10n.continueAction),
            ),
          ),
        ],
      ),
    );
  }

  Widget _welcomeChoiceCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required bool primary,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(FolioRadius.xl),
        child: Container(
          padding: const EdgeInsets.all(FolioSpace.md),
          decoration: BoxDecoration(
            color: primary
                ? scheme.primaryContainer.withValues(alpha: FolioAlpha.soft)
                : scheme.surface,
            borderRadius: BorderRadius.circular(FolioRadius.xl),
            border: Border.all(
              color: primary
                  ? scheme.primary.withValues(alpha: 0.55)
                  : scheme.outlineVariant.withValues(alpha: FolioAlpha.border),
              width: primary ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(FolioRadius.md),
                ),
                child: Icon(icon, color: scheme.primary, size: 26),
              ),
              const SizedBox(height: FolioSpace.sm),
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: FolioSpace.xs),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stepWelcome(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final first = _isFirstOnboarding;
    final title = first ? l10n.welcomeTitle : l10n.welcomeNewVaultTitle;
    final body = first ? l10n.welcomeBody : l10n.welcomeNewVaultBody;
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 520;
        final cards = wide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _welcomeCreateCard(context)),
                  const SizedBox(width: FolioSpace.md),
                  Expanded(
                    child: _welcomeChoiceCard(
                      context: context,
                      icon: Icons.download_outlined,
                      title: l10n.welcomeOptionImportTitle,
                      subtitle: l10n.welcomeOptionImportBody,
                      primary: false,
                      onTap: _chooseImportSource,
                    ),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _welcomeCreateCard(context),
                  const SizedBox(height: FolioSpace.md),
                  _welcomeChoiceCard(
                    context: context,
                    icon: Icons.download_outlined,
                    title: l10n.welcomeOptionImportTitle,
                    subtitle: l10n.welcomeOptionImportBody,
                    primary: false,
                    onTap: _chooseImportSource,
                  ),
                ],
              );
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
              title,
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: FolioSpace.md),
            Text(
              body,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(height: 1.45),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: FolioSpace.xl),
            cards,
          ],
        );
      },
    );
  }

  Widget _stepImportSource(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    Widget tile({
      required IconData icon,
      required String title,
      required String subtitle,
      required VoidCallback onTap,
    }) {
      return Padding(
        padding: const EdgeInsets.only(bottom: FolioSpace.sm),
        child: Material(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(FolioRadius.lg),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(FolioRadius.lg),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(FolioRadius.lg),
                border: Border.all(
                  color: scheme.outlineVariant.withValues(
                    alpha: FolioAlpha.border,
                  ),
                ),
              ),
              child: ListTile(
                leading: Icon(icon, color: scheme.primary),
                title: Text(title),
                subtitle: Text(subtitle),
                trailing: const Icon(Icons.chevron_right_rounded),
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: FolioSpace.lg),
        Text(
          l10n.importSourceTitle,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: FolioSpace.sm),
        Text(
          l10n.importSourceBody,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: scheme.onSurfaceVariant,
            height: 1.45,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: FolioSpace.lg),
        if (kIsWeb) ...[
          WebDesktopOnlyNotice(
            icon: Icons.archive_outlined,
            title: l10n.importBackupZip,
            subtitle: l10n.importSourceBackupSubtitle,
          ),
          const SizedBox(height: FolioSpace.sm),
        ] else
          tile(
            icon: Icons.archive_outlined,
            title: l10n.importBackupZip,
            subtitle: l10n.importSourceBackupSubtitle,
            onTap: _chooseImportBackup,
          ),
        tile(
          icon: Icons.cloud_download_outlined,
          title: l10n.onboardingCloudBackupCta,
          subtitle: l10n.importSourceCloudSubtitle,
          onTap: () => unawaited(_signInAndPickCloudBackup()),
        ),
        if (kIsWeb) ...[
          const SizedBox(height: FolioSpace.sm),
          WebDesktopOnlyNotice(
            icon: Icons.note_alt_outlined,
            title: l10n.importNotionTitle,
            subtitle: l10n.importSourceNotionSubtitle,
          ),
        ] else
          tile(
            icon: Icons.note_alt_outlined,
            title: l10n.importNotionTitle,
            subtitle: l10n.importSourceNotionSubtitle,
            onTap: _chooseImportNotion,
          ),
        const SizedBox(height: FolioSpace.md),
        _onboardingBottomActions(
          onBack: () {
            setState(() {
              _mode = _OnboardingMode.create;
              _page = 0;
            });
          },
          onPrimary: null,
        ),
      ],
    );
  }

  static const List<int> _idleLockPresets = [1, 5, 10, 15, 30, 60];

  int _coerceIdleLockMinutes(int minutes) {
    if (_idleLockPresets.contains(minutes)) return minutes;
    return AppSettings.defaultVaultIdleLockMinutes;
  }

  Widget _configStepActions({
    required VoidCallback onBack,
    required VoidCallback onSkip,
    required VoidCallback onContinue,
    String? continueLabel,
    bool continueBusy = false,
  }) {
    final l10n = AppLocalizations.of(context);
    return _onboardingBottomActions(
      onBack: onBack,
      onPrimary: onContinue,
      primaryLabel: continueLabel,
      primaryBusy: continueBusy,
      beforePrimary: [
        TextButton(onPressed: onSkip, child: Text(l10n.skip)),
        const SizedBox(width: FolioSpace.xs),
      ],
    );
  }

  void _skipConfigDraftStep() {
    AppLogger.info(
      'skip config draft step',
      tag: 'onboarding',
      context: {'step': _currentStepId.name},
    );
    setState(() {
      _syncDraftsFromAppSettings();
      if (_page < _flowSteps.length - 1) {
        _page++;
      }
    });
  }

  Future<void> _pickDraftAccentPresets() async {
    final l10n = AppLocalizations.of(context);
    const presets = <int>[
      0xFF00F3FF,
      0xFF1565C0,
      0xFF0277BD,
      0xFF6A1B9A,
      0xFFAD1457,
      0xFF2E7D32,
      0xFF558B2F,
      0xFFBF360C,
      0xFF00695C,
      0xFF283593,
      0xFF4E342E,
      0xFF37474F,
    ];
    final picked = await showDialog<int>(
      context: context,
      builder: (ctx) => FolioDialog(
        title: Text(l10n.settingsAccentPickColor),
        content: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final a in presets)
              Material(
                color: Color(a),
                elevation: 2,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => Navigator.pop(ctx, a),
                  child: const SizedBox(width: 44, height: 44),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
        ],
      ),
    );
    if (picked != null && mounted) {
      setState(() {
        _draftCustomAccentArgb = picked;
        _draftAccentMode = FolioAccentColorMode.custom;
      });
    }
  }

  Future<void> _applyPersonalizeAndContinue() async {
    await widget.appSettings.setThemeMode(_draftThemeMode);
    await widget.appSettings.setAccentColorMode(_draftAccentMode);
    if (_draftAccentMode == FolioAccentColorMode.custom) {
      await widget.appSettings.setCustomAccentArgb(_draftCustomAccentArgb);
    }
    if (!_createWithoutEncryption) {
      await widget.appSettings.setVaultIdleLockMinutes(_draftIdleLockMinutes);
      await widget.appSettings.setVaultLockOnMinimize(_draftLockOnMinimize);
    }
    if (!mounted) return;
    _goNext();
  }

  Future<void> _applyReliabilityAndContinue() async {
    await widget.appSettings.setScheduledVaultBackupEnabled(
      _draftScheduledBackupEnabled,
    );
    await widget.appSettings.setScheduledVaultBackupIntervalMinutes(
      _draftScheduledBackupIntervalMinutes,
    );
    await widget.appSettings.setScheduledVaultBackupDirectory(
      _draftScheduledBackupDirectory,
    );
    await widget.appSettings.setScheduledVaultBackupAlsoUploadCloud(
      _draftScheduledBackupAlsoUploadCloud,
    );
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      await widget.appSettings.setMinimizeToTray(_draftMinimizeToTray);
      await widget.appSettings.setCloseToTray(_draftCloseToTray);
      await widget.appSettings.setWindowsNotificationsEnabled(
        _draftWindowsNotificationsEnabled,
      );
    }
    if (!mounted) return;
    _goNext();
  }

  Future<void> _applyPrivacyTrustAndContinue() async {
    await widget.appSettings.setTelemetryEnabled(_onboardingTelemetryEnabled);
    await FolioTelemetry.onSettingsChanged(widget.appSettings);
    if (!mounted) return;
    _goNext();
  }

  void _onFolioCloudStepContinue() {
    AppLogger.info('folio cloud step continue', tag: 'onboarding');
    _goNext();
  }

  Future<void> _pickDraftBackupFolder() async {
    final dir = await FilePicker.getDirectoryPath();
    if (!mounted || dir == null) return;
    setState(() => _draftScheduledBackupDirectory = dir);
  }

  String _scheduledBackupIntervalSummary(AppLocalizations l10n, int minutes) {
    if (AppSettings.isContinuousVaultBackupInterval(minutes)) {
      return l10n.scheduledVaultBackupEveryChange;
    }
    if (minutes < 60) {
      return l10n.scheduledVaultBackupEveryNMinutes(minutes);
    }
    return l10n.scheduledVaultBackupEveryNHours(minutes ~/ 60);
  }

  Widget _stepPersonalize(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: FolioSpace.lg),
        Icon(Icons.palette_outlined, size: 64, color: scheme.primary),
        const SizedBox(height: FolioSpace.lg),
        Text(
          l10n.onboardingPersonalizeTitle,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: FolioSpace.md),
        Text(
          l10n.onboardingPersonalizeBody,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: scheme.onSurfaceVariant,
            height: 1.45,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: FolioSpace.lg),
        Text(
          l10n.settingsAppearanceChipTheme,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: FolioSpace.sm),
        SegmentedButton<FolioThemeMode>(
          segments: [
            ButtonSegment<FolioThemeMode>(
              value: FolioThemeMode.system,
              label: Text(l10n.systemTheme),
              icon: const Icon(Icons.brightness_auto, size: 18),
            ),
            ButtonSegment<FolioThemeMode>(
              value: FolioThemeMode.light,
              label: Text(l10n.lightTheme),
              icon: const Icon(Icons.light_mode_outlined, size: 18),
            ),
            ButtonSegment<FolioThemeMode>(
              value: FolioThemeMode.dark,
              label: Text(l10n.darkTheme),
              icon: const Icon(Icons.dark_mode_outlined, size: 18),
            ),
            ButtonSegment<FolioThemeMode>(
              value: FolioThemeMode.oled,
              label: Text(l10n.oledTheme),
              icon: const Icon(Icons.contrast, size: 18),
            ),
          ],
          selected: {_draftThemeMode},
          onSelectionChanged: (s) {
            setState(() => _draftThemeMode = s.first);
          },
        ),
        const SizedBox(height: FolioSpace.lg),
        Text(
          l10n.settingsAccentColorTitle,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: FolioSpace.sm),
        SegmentedButton<FolioAccentColorMode>(
          segments: [
            ButtonSegment<FolioAccentColorMode>(
              value: FolioAccentColorMode.followSystem,
              label: Text(FolioAdaptive.currentPlatformName()),
              icon: const Icon(Icons.palette_outlined, size: 18),
            ),
            ButtonSegment<FolioAccentColorMode>(
              value: FolioAccentColorMode.folioDefault,
              label: Text(l10n.settingsAccentFolioDefault),
              icon: const Icon(Icons.brush_outlined, size: 18),
            ),
            ButtonSegment<FolioAccentColorMode>(
              value: FolioAccentColorMode.custom,
              label: Text(l10n.settingsAccentCustom),
              icon: const Icon(Icons.color_lens_outlined, size: 18),
            ),
          ],
          selected: {_draftAccentMode},
          onSelectionChanged: (s) {
            setState(() => _draftAccentMode = s.first);
          },
        ),
        if (_draftAccentMode == FolioAccentColorMode.custom) ...[
          const SizedBox(height: FolioSpace.sm),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.color_lens, color: Color(_draftCustomAccentArgb)),
            title: Text(l10n.settingsAccentPickColor),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => unawaited(_pickDraftAccentPresets()),
          ),
        ],
        if (!_createWithoutEncryption) ...[
          const SizedBox(height: FolioSpace.lg),
          Divider(color: scheme.outlineVariant.withValues(alpha: FolioAlpha.border)),
          const SizedBox(height: FolioSpace.md),
          Text(
            l10n.onboardingSecurityTitle,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: FolioSpace.sm),
          Text(
            l10n.lockAutoByInactivity,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: FolioSpace.sm),
          InputDecorator(
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(FolioRadius.md),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                isExpanded: true,
                value: _coerceIdleLockMinutes(_draftIdleLockMinutes),
                items: _idleLockPresets
                    .map(
                      (m) => DropdownMenuItem<int>(
                        value: m,
                        child: Text(l10n.minutesShort(m)),
                      ),
                    )
                    .toList(),
                onChanged: _busy
                    ? null
                    : (v) {
                        if (v == null) return;
                        setState(() => _draftIdleLockMinutes = v);
                      },
              ),
            ),
          ),
          const SizedBox(height: FolioSpace.md),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.minimize_rounded),
            title: Text(l10n.lockOnMinimize),
            value: _draftLockOnMinimize,
            onChanged: _busy
                ? null
                : (v) {
                    setState(() => _draftLockOnMinimize = v);
                  },
          ),
        ],
        const SizedBox(height: FolioSpace.xl),
        _configStepActions(
          onBack: _goBack,
          onSkip: _skipConfigDraftStep,
          onContinue: () => unawaited(_applyPersonalizeAndContinue()),
        ),
      ],
    );
  }

  Widget _stepReliability(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final choices = AppSettings.scheduledVaultBackupIntervalChoicesMinutes;
    final isWindows =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: FolioSpace.lg),
        Icon(Icons.backup_outlined, size: 64, color: scheme.primary),
        const SizedBox(height: FolioSpace.lg),
        Text(
          l10n.onboardingReliabilityTitle,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: FolioSpace.md),
        Text(
          l10n.onboardingReliabilityBody,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: scheme.onSurfaceVariant,
            height: 1.45,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: FolioSpace.lg),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          secondary: const Icon(Icons.schedule_rounded),
          title: Text(l10n.scheduledVaultBackupTitle),
          subtitle: Text(l10n.scheduledVaultBackupSubtitle),
          value: _draftScheduledBackupEnabled,
          onChanged: _busy
              ? null
              : (v) {
                  setState(() => _draftScheduledBackupEnabled = v);
                },
        ),
        if (_draftScheduledBackupEnabled) ...[
          const SizedBox(height: FolioSpace.sm),
          Text(
            l10n.scheduledVaultBackupIntervalLabel,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: FolioSpace.sm),
          InputDecorator(
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(FolioRadius.md),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                isExpanded: true,
                value: choices.contains(_draftScheduledBackupIntervalMinutes)
                    ? _draftScheduledBackupIntervalMinutes
                    : choices.first,
                items: choices
                    .map(
                      (m) => DropdownMenuItem<int>(
                        value: m,
                        child: Text(_scheduledBackupIntervalSummary(l10n, m)),
                      ),
                    )
                    .toList(),
                onChanged: _busy
                    ? null
                    : (v) {
                        if (v == null) return;
                        setState(
                          () => _draftScheduledBackupIntervalMinutes = v,
                        );
                      },
              ),
            ),
          ),
          const SizedBox(height: FolioSpace.sm),
          OutlinedButton.icon(
            onPressed: _busy ? null : () => unawaited(_pickDraftBackupFolder()),
            icon: const Icon(Icons.folder_open_outlined),
            label: Text(l10n.scheduledVaultBackupChooseFolder),
          ),
          if (_draftScheduledBackupDirectory.isNotEmpty) ...[
            const SizedBox(height: FolioSpace.xs),
            Text(
              _draftScheduledBackupDirectory,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          ],
          if (_folio.isAvailable) ...[
            const SizedBox(height: FolioSpace.md),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.cloud_upload_outlined),
              title: Text(l10n.scheduledVaultBackupCloudSyncTitle),
              subtitle: Text(l10n.scheduledVaultBackupCloudSyncSubtitle),
              value: _draftScheduledBackupAlsoUploadCloud,
              onChanged: _busy
                  ? null
                  : (v) {
                      setState(() => _draftScheduledBackupAlsoUploadCloud = v);
                    },
            ),
          ],
        ],
        if (isWindows) ...[
          const SizedBox(height: FolioSpace.lg),
          Divider(color: scheme.outlineVariant.withValues(alpha: FolioAlpha.border)),
          const SizedBox(height: FolioSpace.md),
          Text(
            l10n.onboardingSystemTitle,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: FolioSpace.sm),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.minimize_outlined),
            title: Text(l10n.minimizeToTray),
            value: _draftMinimizeToTray,
            onChanged: _busy
                ? null
                : (v) {
                    setState(() => _draftMinimizeToTray = v);
                  },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.close_fullscreen_outlined),
            title: Text(l10n.closeToTray),
            value: _draftCloseToTray,
            onChanged: _busy
                ? null
                : (v) {
                    setState(() => _draftCloseToTray = v);
                  },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.notifications_outlined),
            title: Text(l10n.settingsWindowsNotifications),
            subtitle: Text(l10n.settingsWindowsNotificationsSubtitle),
            value: _draftWindowsNotificationsEnabled,
            onChanged: _busy
                ? null
                : (v) {
                    setState(() => _draftWindowsNotificationsEnabled = v);
                  },
          ),
        ],
        const SizedBox(height: FolioSpace.xl),
        _configStepActions(
          onBack: _goBack,
          onSkip: _skipConfigDraftStep,
          onContinue: () => unawaited(_applyReliabilityAndContinue()),
        ),
      ],
    );
  }

  Widget _stepPrivacyTrust(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: FolioSpace.lg),
        Icon(Icons.verified_user_outlined, size: 64, color: scheme.primary),
        const SizedBox(height: FolioSpace.lg),
        Text(
          l10n.onboardingPrivacyTrustTitle,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: FolioSpace.md),
        Text(
          l10n.onboardingPrivacyTrustBody,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: scheme.onSurfaceVariant,
            height: 1.45,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: FolioSpace.md),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: scheme.primaryContainer.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(FolioRadius.lg),
            border: Border.all(
              color: scheme.primary.withValues(alpha: 0.25),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.shield_outlined, color: scheme.primary, size: 22),
              const SizedBox(width: FolioSpace.sm),
              Expanded(
                child: Text(
                  l10n.onboardingPrivacyTrustLocalFirstBadge,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
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
        _configStepActions(
          onBack: _goBack,
          onSkip: _skipConfigDraftStep,
          onContinue: () => unawaited(_applyPrivacyTrustAndContinue()),
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
              ? AppLocalizations.of(
                  context,
                ).onboardingCloudBackupIncrementalRestoreBody
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
        if ((_onboardingCloudPackVaultId == null &&
                _backupZipPath != null &&
                _backupZipIsPlain == true) ||
            (_onboardingCloudPackVaultId != null &&
                _onboardingCloudPackIsPlain == true))
          Text(
            AppLocalizations.of(context).backupPlainNoPasswordHint,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.35,
            ),
            textAlign: TextAlign.center,
          )
        else if (_onboardingCloudPackVaultId != null || _backupZipPath != null)
          FolioPasswordField(
            controller: _backupPassword,
            obscureText: _obscureBackupPassword,
            enabled: !_busy,
            labelText: AppLocalizations.of(context).backupPasswordLabel,
            helperText: _onboardingCloudPackVaultId != null
                ? AppLocalizations.of(context).cloudPackRestorePasswordHelper
                : null,
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
        _onboardingBottomActions(
          onBack: _busy
              ? null
              : () {
                  setState(() {
                    _mode = _OnboardingMode.importChooser;
                    _page = 1;
                    _onboardingCloudPackVaultId = null;
                    _onboardingCloudPackIsPlain = null;
                  });
                },
          onPrimary: _busy ? null : _finishImport,
          primaryLabel: AppLocalizations.of(context).importVault,
          primaryBusy: _busy,
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
        _onboardingBottomActions(
          onBack: _goBack,
          onPrimary: _nextCreatePassword,
          primaryLabel: AppLocalizations.of(context).next,
        ),
      ],
    );
  }

  Widget _stepReady(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final body = _createWithoutEncryption ? l10n.readyBodyPlainVault : l10n.readyBody;
    final showCloudSummary = _isFirstOnboarding && _folio.isAvailable;
    final cloudSummary = showCloudSummary
        ? (_folio.snapshot.active
            ? l10n.onboardingReadySummaryCloudActive
            : l10n.onboardingReadySummaryCloudSkipped)
        : null;
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
          l10n.readyTitle,
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: FolioSpace.md),
        Text(
          body,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.45),
          textAlign: TextAlign.center,
        ),
        if (cloudSummary != null) ...[
          const SizedBox(height: FolioSpace.md),
          Text(
            cloudSummary,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: FolioSpace.xl),
        _onboardingBottomActions(
          onBack: _busy ? null : _goBack,
          onPrimary: _busy ? null : () => unawaited(_finishCreate()),
          primaryLabel: l10n.createVault,
          primaryBusy: _busy,
        ),
      ],
    );
  }

  Widget _stepUsageProfile(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final intents = FolioUsageIntent.values;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: FolioSpace.xl),
        Icon(Icons.tune_rounded, size: 64, color: scheme.primary),
        const SizedBox(height: FolioSpace.lg),
        Text(
          l10n.onboardingUsageProfileTitle,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: FolioSpace.md),
        Text(
          l10n.onboardingUsageProfileBody,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: scheme.onSurfaceVariant,
            height: 1.45,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: FolioSpace.sm),
        Text(
          l10n.onboardingUsageProfileHint,
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
            height: 1.35,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: FolioSpace.lg),
        Wrap(
          spacing: FolioSpace.sm,
          runSpacing: FolioSpace.sm,
          children: [
            for (final intent in intents)
              FilterChip(
                label: Text(_usageIntentTitle(l10n, intent)),
                selected: _selectedUsageIntents.contains(intent),
                onSelected: _busy
                    ? null
                    : (selected) {
                        setState(() {
                          _usageProfileError = null;
                          if (selected) {
                            if (_selectedUsageIntents.length >=
                                FolioUsageIntent.maxSelection) {
                              return;
                            }
                            _selectedUsageIntents = [
                              ..._selectedUsageIntents,
                              intent,
                            ];
                          } else {
                            _selectedUsageIntents = _selectedUsageIntents
                                .where((e) => e != intent)
                                .toList();
                          }
                        });
                      },
              ),
          ],
        ),
        if (_usageProfileError != null) ...[
          const SizedBox(height: FolioSpace.sm),
          Text(
            _usageProfileError!,
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.error),
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: FolioSpace.xl),
        _onboardingBottomActions(
          onBack: _busy ? null : _goBack,
          onPrimary: _busy ? null : () => unawaited(_persistUsageProfileAndGoNext()),
          primaryLabel: l10n.continueAction,
        ),
      ],
    );
  }

  Future<void> _persistUsageProfileAndGoNext() async {
    final safe = FolioUsageIntent.sanitizeSelection(_selectedUsageIntents);
    if (safe.isEmpty) {
      setState(() {
        _usageProfileError = AppLocalizations.of(
          context,
        ).onboardingUsageProfileMinSelectionError;
      });
      return;
    }
    setState(() {
      _selectedUsageIntents = List<FolioUsageIntent>.from(safe);
      _usageProfileError = null;
    });
    await widget.appSettings.setUsageIntents(safe);
    if (!mounted) return;
    _goNext();
  }

  String _usageIntentTitle(AppLocalizations l10n, FolioUsageIntent intent) {
    switch (intent) {
      case FolioUsageIntent.notes:
        return l10n.onboardingUsageIntentNotesTitle;
      case FolioUsageIntent.tasks:
        return l10n.onboardingUsageIntentTasksTitle;
      case FolioUsageIntent.projects:
        return l10n.onboardingUsageIntentProjectsTitle;
      case FolioUsageIntent.knowledge:
        return l10n.onboardingUsageIntentKnowledgeTitle;
      case FolioUsageIntent.journal:
        return l10n.onboardingUsageIntentJournalTitle;
      case FolioUsageIntent.study:
        return l10n.onboardingUsageIntentStudyTitle;
    }
  }


  Widget _stepFolioCloud(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return OnboardingCloudPitchStep(
      cloud: _cloud,
      folio: _folio,
      usageIntents: _selectedUsageIntents,
      onAuthError: (c) => _cloudAuthErrorMessage(l10n, c),
      onContinue: _onFolioCloudStepContinue,
      onBack: _goBack,
      busy: _busy,
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
        Icon(FolioIcons.quill, size: 64, color: scheme.primary),
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
        _onboardingBottomActions(
          onBack: _busy ? null : _goBack,
          onPrimary: _busy ? null : _goNext,
          primaryLabel: l10n.continueAction,
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
        _onboardingBottomActions(
          onBack: _busy
              ? null
              : () {
                  setState(() {
                    _mode = _OnboardingMode.importChooser;
                    _page = 1;
                  });
                },
          onPrimary: _busy ? null : () => unawaited(_finishNotionImport()),
          primaryLabel: l10n.importAction,
          primaryBusy: _busy,
        ),
      ],
    );
  }
}

enum _OnboardingStepId {
  welcome,
  importChooser,
  vaultSetup,
  ready,
  personalize,
  reliability,
  privacyTrust,
  folioCloud,
  quillIntro,
  usageProfile,
  importBackupForm,
  importNotionForm,
}

enum _OnboardingMode { create, importChooser, backupImport, notionImport }

class _StepSegments extends StatelessWidget {
  const _StepSegments({required this.current, required this.total});

  /// Paso actual (1-indexed).
  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (total <= 0) return const SizedBox.shrink();
    final safeTotal = total;
    final safeCurrent = current.clamp(1, safeTotal);
    return Row(
      children: List.generate(safeTotal, (i) {
        final done = i < safeCurrent - 1;
        final active = i == safeCurrent - 1;
        final color = done
            ? scheme.primary
            : active
                ? scheme.primary.withValues(alpha: 0.45)
                : scheme.surfaceContainerHighest;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(left: i == 0 ? 0 : 4),
            child: AnimatedContainer(
              duration: FolioMotion.short2,
              curve: FolioMotion.emphasized,
              height: 6,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        );
      }),
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

bool _meetsVaultMasterPasswordPolicy(_PasswordStrength strength) =>
    strength == _PasswordStrength.fair || strength == _PasswordStrength.strong;
