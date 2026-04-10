import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:passkeys/exceptions.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/app_settings.dart';
import '../../app/folio_in_app_shortcuts.dart';
import '../../app/ui_tokens.dart';
import '../../app/widgets/folio_dialog.dart';
import '../../app/widgets/folio_icon_token_view.dart';
import '../../app/widgets/folio_password_field.dart';
import 'in_app_shortcut_capture_dialog.dart';
import '../../crypto/vault_crypto.dart';
import '../../data/notion_import/notion_importer.dart';
import '../../data/vault_registry.dart';
import '../../data/vault_paths.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../data/vault_backup.dart';
import '../../services/ai/ai_service.dart';
import '../../services/ai/ai_provider_detector.dart';
import '../../services/ai/ai_safety_policy.dart';
import '../../services/ai/folio_cloud_ai_service.dart';
import '../../services/ai/lmstudio_ai_service.dart';
import '../../services/ai/ollama_ai_service.dart';
import '../../services/custom_icon_import_service.dart';
import '../../services/cloud_account/cloud_account_controller.dart';
import '../../services/folio_cloud/folio_cloud_backup.dart';
import '../../services/folio_cloud/folio_cloud_billing.dart';
import '../../services/folio_cloud/folio_cloud_checkout.dart';
import '../../services/folio_cloud/folio_cloud_entitlements.dart';
import '../../services/folio_cloud/folio_cloud_publish.dart';
import '../../services/folio_cloud/folio_web_portal_api.dart';
import '../../services/folio_cloud/folio_page_html_export.dart';
import '../../services/device_sync/device_sync_controller.dart';
import '../../services/device_sync/device_sync_models.dart';
import '../../services/updater/github_release_updater.dart';
import '../../services/updater/update_release_channel.dart';
import '../../session/vault_session.dart';
import 'release_readiness.dart';
import 'folio_cloud_reauth_dialog.dart';
import 'folio_cloud_subscription_pitch_page.dart';
import 'vault_identity_verify_dialog.dart';
import '../../services/vault_scheduled_local_export.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.session,
    required this.appSettings,
    required this.deviceSyncController,
    required this.cloudAccountController,
    required this.folioCloudEntitlements,
  });

  final VaultSession session;
  final AppSettings appSettings;
  final DeviceSyncController deviceSyncController;
  final CloudAccountController cloudAccountController;
  final FolioCloudEntitlementsController folioCloudEntitlements;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  static const _idleOptions = <int>[1, 5, 10, 15, 30, 60];
  VaultSession get _s => widget.session;
  AppSettings get _app => widget.appSettings;
  DeviceSyncController get _sync => widget.deviceSyncController;
  CloudAccountController get _cloud => widget.cloudAccountController;
  FolioCloudEntitlementsController get _folio => widget.folioCloudEntitlements;
  final ScrollController _settingsScrollController = ScrollController();
  final TextEditingController _settingsSectionFilterController =
      TextEditingController();
  final List<GlobalKey> _sectionKeys = List.generate(11, (_) => GlobalKey());
  int _selectedDesktopSection = 0;
  bool _programmaticSectionScroll = false;

  var _quickEnabled = false;
  var _passkeyRegistered = false;
  late final TextEditingController _aiBaseUrlController;
  late final TextEditingController _aiTimeoutController;
  late final TextEditingController _aiContextWindowController;
  late final TextEditingController _customIconSourceController;
  late final TextEditingController _customIconLabelController;
  late final TextEditingController _webLinkCodeController;
  List<String> _availableModels = const [];
  bool _loadingModels = false;
  bool _checkingUpdates = false;
  bool _detectingAiProvider = false;
  bool _importingCustomIcon = false;
  String _installedVersionLabel = '...';
  bool _releaseStatusBusy = false;
  bool _folioCloudActionBusy = false;
  bool _webLinkBusy = false;
  int? _cloudBackupCount;
  bool _cloudBackupCountBusy = false;
  ReleaseReadinessSnapshot _releaseSnapshot = const ReleaseReadinessSnapshot(
    installedVersionLabel: '... ',
    isSemverValid: false,
    updateReleaseChannel: UpdateReleaseChannel.stable,
    activeVaultId: '-',
    activeVaultPath: '-',
    isVaultUnlocked: false,
    isVaultEncrypted: false,
    isAiEnabled: false,
    isAiEndpointPolicyValid: true,
    aiSummary: 'IA desactivada',
    checks: const <ReleaseCheckItem>[],
  );
  final CustomIconImportService _customIconImportService =
      CustomIconImportService();

  @override
  void initState() {
    super.initState();
    _aiBaseUrlController = TextEditingController(text: _app.aiBaseUrl);
    _aiTimeoutController = TextEditingController(
      text: _app.aiTimeoutMs.toString(),
    );
    _aiContextWindowController = TextEditingController(
      text: _app.aiContextWindowTokens.toString(),
    );
    _customIconSourceController = TextEditingController();
    _customIconLabelController = TextEditingController();
    _webLinkCodeController = TextEditingController();
    _availableModels = _app.cachedAiModelsFor(_app.aiProvider);
    _settingsScrollController.addListener(_handleSettingsScroll);
    _settingsSectionFilterController.addListener(() {
      if (mounted) setState(() {});
    });
    _refreshSecurityFlags();
    _loadInstalledVersionInfo();
    _refreshReleaseReadiness();
  }

  @override
  void dispose() {
    _settingsScrollController.removeListener(_handleSettingsScroll);
    _settingsScrollController.dispose();
    _settingsSectionFilterController.dispose();
    _aiBaseUrlController.dispose();
    _aiTimeoutController.dispose();
    _aiContextWindowController.dispose();
    _customIconSourceController.dispose();
    _customIconLabelController.dispose();
    _webLinkCodeController.dispose();
    super.dispose();
  }

  Future<bool> _ensureSectionVisible(int index) async {
    if (!_settingsScrollController.hasClients) return false;
    final targetContext = _sectionKeys[index].currentContext;
    if (targetContext == null) return false;
    await Scrollable.ensureVisible(
      targetContext,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      alignment: 0.03,
    );
    return true;
  }

  List<_SettingsSectionNavItem> _filterDesktopSections(
    List<_SettingsSectionNavItem> all,
  ) {
    final q = _settingsSectionFilterController.text.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all
        .where((s) => s.label.toLowerCase().contains(q))
        .toList(growable: false);
  }

  String _formatScheduledBackupTime(int ms) {
    if (ms <= 0) return '—';
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    final y = d.year.toString().padLeft(4, '0');
    final mo = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    final h = d.hour.toString().padLeft(2, '0');
    final mi = d.minute.toString().padLeft(2, '0');
    return '$y-$mo-$day $h:$mi';
  }

  Future<void> _pickScheduledVaultBackupFolder() async {
    final path = await FilePicker.platform.getDirectoryPath();
    if (path == null || !mounted) return;
    await _app.setScheduledVaultBackupDirectory(path);
    if (mounted) setState(() {});
  }

  Future<void> _scrollToSection(int index) async {
    if (index < 0 || index >= _sectionKeys.length) return;
    if (mounted) {
      setState(() => _selectedDesktopSection = index);
    }
    _programmaticSectionScroll = true;
    if (await _ensureSectionVisible(index)) {
      _programmaticSectionScroll = false;
      return;
    }

    // En algunos frames el target puede no tener context aun; reintenta una vez.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        if (!mounted) return;
        if (await _ensureSectionVisible(index)) return;
        if (!_settingsScrollController.hasClients) return;

        final max = _settingsScrollController.position.maxScrollExtent;
        if (max <= 0) return;
        final denom = (_sectionKeys.length - 1).clamp(1, _sectionKeys.length);
        final target = (index / denom) * max;
        await _settingsScrollController.animateTo(
          target.clamp(0.0, max),
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
        );
      } finally {
        _programmaticSectionScroll = false;
      }
    });
  }

  void _handleSettingsScroll() {
    if (!mounted || _programmaticSectionScroll) return;
    final active = _activeSectionFromViewport();
    if (active == null || active == _selectedDesktopSection) return;
    setState(() => _selectedDesktopSection = active);
  }

  int? _activeSectionFromViewport() {
    const thresholdTop = 156.0;
    final visible = <MapEntry<int, double>>[];
    for (var i = 0; i < _sectionKeys.length; i++) {
      final ctx = _sectionKeys[i].currentContext;
      if (ctx == null) continue;
      final render = ctx.findRenderObject();
      if (render is! RenderBox || !render.hasSize) continue;
      final dy = render.localToGlobal(Offset.zero).dy;
      visible.add(MapEntry(i, dy));
    }
    if (visible.isEmpty) return null;
    visible.sort((a, b) => a.value.compareTo(b.value));
    final passed = visible.where((s) => s.value <= thresholdTop).toList();
    if (passed.isNotEmpty) {
      return passed.last.key;
    }
    return visible.first.key;
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

  Future<void> _loadInstalledVersionInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() {
        _installedVersionLabel = '${info.version}+${info.buildNumber}';
      });
      await _refreshReleaseReadiness();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _installedVersionLabel = 'desconocida';
      });
      await _refreshReleaseReadiness();
    }
  }

  Future<void> _refreshReleaseReadiness() async {
    if (mounted) setState(() => _releaseStatusBusy = true);

    final vaultId = _s.activeVaultId;
    var vaultPath = '-';
    try {
      final dir = await VaultPaths.vaultDirectory();
      vaultPath = dir.path;
    } catch (_) {
      vaultPath = '-';
    }

    final snapshot = evaluateReleaseReadiness(
      installedVersionLabel: _installedVersionLabel,
      updateReleaseChannel: _app.updateReleaseChannel,
      activeVaultId: vaultId,
      activeVaultPath: vaultPath,
      isVaultUnlocked: _s.state == VaultFlowState.unlocked,
      isVaultEncrypted: _s.vaultUsesEncryption,
      isAiEnabled: _app.aiEnabled,
      aiProvider: _app.aiProvider,
      aiBaseUrl: _app.aiBaseUrl,
      aiEndpointMode: _app.aiEndpointMode,
      aiRemoteEndpointConfirmed: _app.aiRemoteEndpointConfirmed,
    );

    if (!mounted) return;
    setState(() {
      _releaseSnapshot = snapshot;
      _releaseStatusBusy = false;
    });
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<bool> _verifyVaultIdentity({
    required Widget title,
    required Widget body,
    String? passwordButtonLabel,
  }) async {
    if (_s.state != VaultFlowState.unlocked) return false;
    final l10n = AppLocalizations.of(context);
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => VaultIdentityVerifyDialog(
        session: _s,
        quickEnabled: _quickEnabled,
        passkeyRegistered: _passkeyRegistered,
        title: title,
        body: body,
        passwordButtonLabel: passwordButtonLabel ?? l10n.verifyAndContinue,
      ),
    );
    return result == true;
  }

  /// Lista/descarga de copias en Storage: reautenticación con **cuenta Folio Cloud**, no libreta local.
  Future<bool> _verifyFolioCloudAccountForBackups() async {
    if (!_cloud.isAvailable || !_cloud.isSignedIn) {
      _snack(
        _t(
          'Inicia sesión en Folio Cloud.',
          'Sign in to Folio Cloud.',
        ),
      );
      return false;
    }
    if (!_cloud.canReauthenticateWithPassword) {
      _snack(
        AppLocalizations.of(context).folioCloudReauthRequiresPasswordProvider,
      );
      return false;
    }
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => FolioCloudReauthDialog(
        l10n: l10n,
        cloud: _cloud,
        onAuthError: (code) => _cloudAuthErrorMessage(l10n, code),
        initialEmail: _cloud.user?.email,
      ),
    );
    return ok == true;
  }

  Future<void> _runBackupNowToScheduledFolder() async {
    if (_s.state != VaultFlowState.unlocked) return;
    final l10n = AppLocalizations.of(context);
    final dirEmpty = _app.scheduledVaultBackupDirectory.trim().isEmpty;
    final canCloud = _folio.isAvailable &&
        _cloud.isSignedIn &&
        _folio.snapshot.canUseCloudBackup;
    final cloudOnly =
        dirEmpty && _app.scheduledVaultBackupAlsoUploadCloud && canCloud;
    if (dirEmpty && !cloudOnly) {
      _snack(l10n.vaultBackupRunNowNeedFolder);
      return;
    }
    try {
      await runScheduledFolderVaultExport(
        session: _s,
        appSettings: _app,
        folioEntitlements: _folio,
      );
      if (mounted) {
        _snack(
          cloudOnly && dirEmpty
              ? l10n.folioCloudUploadSnackOk
              : l10n.scheduledVaultBackupSnackOk,
        );
      }
    } on VaultBackupException catch (e) {
      if (mounted) _snack('$e');
    } catch (e) {
      if (mounted) _snack(l10n.scheduledVaultBackupSnackFail('$e'));
    }
  }

  String _t(String es, String en) {
    final isEs = Localizations.localeOf(
      context,
    ).languageCode.toLowerCase().startsWith('es');
    return isEs ? es : en;
  }

  Future<void> _exportReleaseReadinessReport() async {
    final destination = await FilePicker.platform.saveFile(
      dialogTitle: 'Guardar reporte de release readiness',
      fileName: buildReleaseReadinessFileName(DateTime.now()),
      type: FileType.custom,
      allowedExtensions: const ['txt'],
    );
    if (destination == null || destination.trim().isEmpty) return;
    try {
      await File(destination).writeAsString(_releaseSnapshot.toReportText());
      if (!mounted) return;
      _snack('Reporte guardado correctamente.');
    } catch (e) {
      if (!mounted) return;
      _snack('No se pudo guardar el reporte: $e');
    }
  }

  Future<void> _revokeIntegrationApp(String appId) async {
    await _app.revokeIntegrationApp(appId);
    _snack('App revocada: $appId');
  }

  String _formatLastSyncLabel() {
    final ms = _app.syncLastSuccessMs;
    if (ms <= 0) {
      return _t('Aun sin sincronizar', 'Not synced yet');
    }
    final at = DateTime.fromMillisecondsSinceEpoch(ms).toLocal();
    final two = (int value) => value.toString().padLeft(2, '0');
    return '${two(at.day)}/${two(at.month)}/${at.year} ${two(at.hour)}:${two(at.minute)}';
  }

  String _shortCloudUid(String uid) {
    if (uid.length <= 12) return uid;
    return '${uid.substring(0, 8)}…${uid.substring(uid.length - 4)}';
  }

  String _cloudAuthErrorMessage(AppLocalizations l10n, String code) {
    switch (code) {
      case 'invalid-email':
        return l10n.cloudAuthErrorInvalidEmail;
      case 'wrong-password':
        return l10n.cloudAuthErrorWrongPassword;
      case 'user-not-found':
        return l10n.cloudAuthErrorUserNotFound;
      case 'user-disabled':
        return l10n.cloudAuthErrorUserDisabled;
      case 'email-already-in-use':
        return l10n.cloudAuthErrorEmailAlreadyInUse;
      case 'weak-password':
        return l10n.cloudAuthErrorWeakPassword;
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

  Future<void> _showCloudAuthDialog({required bool register}) async {
    final l10n = AppLocalizations.of(context);
    await showDialog<void>(
      context: context,
      builder: (ctx) => _CloudAuthDialog(
        initialRegister: register,
        l10n: l10n,
        cloudAuthController: _cloud,
        onAuthError: (code) => _cloudAuthErrorMessage(l10n, code),
        onForgotPassword: () {
          Navigator.of(ctx).pop();
          Future.microtask(() {
            unawaited(_showCloudPasswordResetDialog());
          });
        },
      ),
    );
  }

  Future<void> _showCloudPasswordResetDialog({String? fixedEmail}) async {
    if (!_cloud.isAvailable) return;
    final l10n = AppLocalizations.of(context);
    final email = await showDialog<String?>(
      context: context,
      builder: (ctx) => _CloudPasswordResetDialog(
        l10n: l10n,
        fixedEmail: fixedEmail,
      ),
    );
    if (email == null || email.isEmpty) return;
    try {
      await _cloud.sendPasswordResetEmail(email);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.cloudPasswordResetSent)));
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_cloudAuthErrorMessage(l10n, e.code))),
      );
    }
  }

  Future<void> _sendCloudEmailVerification() async {
    if (!_cloud.isAvailable || !_cloud.isSignedIn) return;
    final l10n = AppLocalizations.of(context);
    try {
      await _cloud.sendEmailVerification();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.cloudAccountVerificationSent)),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_cloudAuthErrorMessage(l10n, e.code))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _reloadCloudUserVerificationStatus() async {
    if (!_cloud.isAvailable || !_cloud.isSignedIn) return;
    final l10n = AppLocalizations.of(context);
    try {
      await _cloud.reloadCurrentUser();
      if (!mounted) return;
      final verified = _cloud.user?.emailVerified ?? false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            verified
                ? l10n.cloudAccountVerificationNowVerified
                : l10n.cloudAccountVerificationStillPending,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _editSyncDeviceName() async {
    var draft = _app.syncDeviceName;
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(_t('Nombre del dispositivo', 'Device name')),
          content: TextFormField(
            initialValue: draft,
            autofocus: true,
            maxLength: 40,
            decoration: InputDecoration(
              hintText: _t(
                'Ejemplo: Pixel de Alejandra',
                'Example: Alejandra Pixel',
              ),
            ),
            onChanged: (v) => draft = v,
            onFieldSubmitted: (_) => Navigator.of(ctx).pop(draft.trim()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(AppLocalizations.of(context).cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(draft.trim()),
              child: Text(AppLocalizations.of(context).save),
            ),
          ],
        );
      },
    );
    if (result == null) return;
    await _app.setSyncDeviceName(result);
  }

  void _activateEmojiPairingMode() {
    if (!_app.syncEnabled) return;
    _sync.generatePairingCode();
    _snack(
      _t(
        'Modo vinculacion activado durante 2 minutos.',
        'Pairing mode enabled for 2 minutes.',
      ),
    );
  }

  Future<void> _submitPairingCodeDialog({SyncPeer? peer}) async {
    final targetPeer = peer;
    if (targetPeer == null) {
      _snack(
        _t(
          'Primero activa el modo vinculacion y luego elige un dispositivo detectado.',
          'First enable pairing mode and then choose a discovered device.',
        ),
      );
      return;
    }
    final l10nLink = AppLocalizations.of(context);
    final idOk = await _verifyVaultIdentity(
      title: Text(l10nLink.vaultIdentitySyncTitle),
      body: Text(l10nLink.vaultIdentitySyncBody),
    );
    if (!idOk || !mounted) return;
    if (!_sync.isPairingModeActive) {
      _sync.generatePairingCode();
    }
    final sharedEmojis = _sync.sharedPairingEmojisForPeer(targetPeer);
    if (sharedEmojis.isEmpty) {
      _snack(
        _t(
          'Activa el modo vinculacion en ambos dispositivos y espera a que aparezcan los mismos 3 emojis.',
          'Enable pairing mode on both devices and wait until the same 3 emojis appear.',
        ),
      );
      return;
    }
    final started = await _sync.submitEmojiPairingRequest(targetPeer);
    if (!started) {
      if (!mounted) return;
      _snack(
        _t(
          'No se pudo iniciar la vinculacion. Activa el modo vinculacion en ambos dispositivos y espera a ver los mismos 3 emojis.',
          'Could not start pairing. Enable pairing mode on both devices and wait until the same 3 emojis appear.',
        ),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(_t('Confirmar vinculacion', 'Confirm pairing')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _t(
                  'Comprueba que en el otro dispositivo aparecen estos mismos 3 emojis:',
                  'Check that the other device shows these same 3 emojis:',
                ),
              ),
              const SizedBox(height: 12),
              SelectableText(
                sharedEmojis.join(' '),
                style: Theme.of(ctx).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _t(
                  'Este popup tambien aparecera en el otro dispositivo. Para completar el enlace, pulsa Vincular aqui y luego Vincular en el otro.',
                  'This popup will also appear on the other device. To complete linking, press Link here and then Link on the other one.',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                _sync.cancelOutgoingPair(targetPeer.peerId);
                Navigator.of(ctx).pop(false);
              },
              child: Text(AppLocalizations.of(context).cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(_t('Vincular', 'Link')),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;
    await _sync.confirmOutgoingPair(targetPeer.peerId);
    if (!mounted) return;
    _snack(
      _t(
        'Confirmacion enviada. Falta que el otro dispositivo pulse Vincular en su popup.',
        'Confirmation sent. The other device still needs to press Link in its popup.',
      ),
    );
  }

  Future<void> _revokeSyncPeer(SyncPeer peer) async {
    final l10nRev = AppLocalizations.of(context);
    final ok = await _verifyVaultIdentity(
      title: Text(l10nRev.vaultIdentitySyncTitle),
      body: Text(l10nRev.vaultIdentitySyncBody),
    );
    if (!ok || !mounted) return;
    await _sync.revokePeer(peer.peerId);
    if (!mounted) return;
    _snack(_t('Dispositivo revocado.', 'Device revoked.'));
  }

  String _formatSyncConflictTimestamp(int ms) {
    final at = DateTime.fromMillisecondsSinceEpoch(ms).toLocal();
    final two = (int value) => value.toString().padLeft(2, '0');
    return '${two(at.day)}/${two(at.month)} ${two(at.hour)}:${two(at.minute)}';
  }

  Future<void> _showSyncConflictsDialog() async {
    final l10nConf = AppLocalizations.of(context);
    final ok = await _verifyVaultIdentity(
      title: Text(l10nConf.vaultIdentitySyncTitle),
      body: Text(l10nConf.vaultIdentitySyncBody),
    );
    if (!ok || !mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(_t('Resolver conflictos', 'Resolve conflicts')),
          content: SizedBox(
            width: 560,
            child: ListenableBuilder(
              listenable: _s,
              builder: (context, _) {
                final conflicts = _s.syncConflicts;
                if (conflicts.isEmpty) {
                  return Text(
                    _t(
                      'No hay conflictos pendientes.',
                      'There are no pending conflicts.',
                    ),
                  );
                }
                return SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: conflicts.map((conflict) {
                      final subtitle = _t(
                        'Origen: ${conflict.fromPeerId}\nPaginas remotas: ${conflict.remotePageCount}\nDetectado: ${_formatSyncConflictTimestamp(conflict.createdAtMs)}',
                        'Source: ${conflict.fromPeerId}\nRemote pages: ${conflict.remotePageCount}\nDetected: ${_formatSyncConflictTimestamp(conflict.createdAtMs)}',
                      );
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Theme.of(
                              context,
                            ).colorScheme.outlineVariant.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _t(
                                'Conflicto de sincronizacion',
                                'Sync conflict',
                              ),
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 8),
                            Text(subtitle),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                  onPressed: () async {
                                    await _s.resolveSyncConflictKeepLocal(
                                      conflict.id,
                                    );
                                    if (!mounted) return;
                                    _snack(
                                      _t(
                                        'Se conservo la version local.',
                                        'Local version kept.',
                                      ),
                                    );
                                  },
                                  child: Text(
                                    _t('Mantener local', 'Keep local'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                FilledButton.tonal(
                                  onPressed: () async {
                                    final ok = await _s
                                        .resolveSyncConflictAcceptRemote(
                                          conflict.id,
                                        );
                                    if (!mounted) return;
                                    _snack(
                                      ok
                                          ? _t(
                                              'Se aplico la version remota.',
                                              'Remote version applied.',
                                            )
                                          : _t(
                                              'No se pudo aplicar la version remota.',
                                              'Could not apply the remote version.',
                                            ),
                                    );
                                  },
                                  child: Text(
                                    _t('Aceptar remota', 'Accept remote'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(_t('Cerrar', 'Close')),
            ),
          ],
        );
      },
    );
  }

  Future<void> _importCustomIconFromSource(String source) async {
    final raw = source.trim();
    if (raw.isEmpty || _importingCustomIcon) return;
    setState(() => _importingCustomIcon = true);
    try {
      final entry = await _customIconImportService.importFromSource(
        source: raw,
        label: _customIconLabelController.text,
      );
      await _app.addOrUpdateCustomIcon(entry);
      if (!mounted) return;
      _customIconSourceController.clear();
      _customIconLabelController.clear();
      _snack(
        _t('Icono importado correctamente.', 'Icon imported successfully.'),
      );
    } catch (e) {
      if (!mounted) return;
      _snack('$e');
    } finally {
      if (mounted) setState(() => _importingCustomIcon = false);
    }
  }

  Future<void> _importCustomIconFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (text.isEmpty) {
      _snack(_t('El portapapeles está vacío.', 'Clipboard is empty.'));
      return;
    }
    _customIconSourceController.text = text;
    await _importCustomIconFromSource(text);
  }

  Future<void> _removeCustomIcon(CustomIconEntry entry) async {
    await _app.removeCustomIcon(entry.id);
    try {
      final file = File(entry.filePath);
      if (file.existsSync()) {
        await file.delete();
      }
    } catch (_) {
      // Ignorar: la referencia ya se eliminó de ajustes.
    }
    if (!mounted) return;
    _snack(_t('Icono eliminado.', 'Icon removed.'));
  }

  Future<bool> _vaultRequiresPassword(String vaultId) async {
    final dir = await VaultPaths.vaultDirectoryForId(vaultId);
    final modePath = File(
      '${dir.path}${Platform.pathSeparator}${VaultPaths.vaultModeFile}',
    );
    if (!modePath.existsSync()) return true;
    final raw = await modePath.readAsString();
    return raw.trim().toLowerCase() != 'plain';
  }

  Future<bool> _verifyVaultPasswordForDelete(String vaultId) async {
    final l10n = AppLocalizations.of(context);
    final dir = await VaultPaths.vaultDirectoryForId(vaultId);
    final keysPath = File(
      '${dir.path}${Platform.pathSeparator}${VaultPaths.wrappedDekFile}',
    );
    if (!keysPath.existsSync()) return true;

    final controller = TextEditingController();
    var obscure = true;
    String? password;
    while (mounted) {
      password = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDialogState) => FolioDialog(
            title: Text(l10n.confirmIdentity),
            content: FolioPasswordField(
              controller: controller,
              obscureText: obscure,
              autofocus: true,
              labelText: l10n.currentPasswordLabel,
              showPasswordTooltip: l10n.showPassword,
              hidePasswordTooltip: l10n.hidePassword,
              onToggleObscure: () {
                setDialogState(() => obscure = !obscure);
              },
              onSubmitted: (_) => Navigator.pop(ctx, controller.text.trim()),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, controller.text.trim()),
                child: Text(l10n.verifyAndDelete),
              ),
            ],
          ),
        ),
      );
      if (password == null) {
        controller.dispose();
        return false;
      }
      if (password.trim().isEmpty) {
        _snack(l10n.incorrectPasswordError);
        continue;
      }
      try {
        final wrapped = await keysPath.readAsBytes();
        await VaultCrypto.unwrapDek(
          wrapped: wrapped,
          password: password.trim(),
        );
        controller.dispose();
        return true;
      } catch (_) {
        _snack(l10n.incorrectPasswordError);
      }
    }
    controller.dispose();
    return false;
  }

  Future<void> _deleteOtherVault() async {
    final l10n = AppLocalizations.of(context);
    final active = _s.activeVaultId;
    final vaults = await _s.listVaultEntries();
    final others = vaults.where((e) => e.id != active).toList(growable: false);
    if (others.isEmpty) {
      _snack(l10n.noOtherVaultsSnack);
      return;
    }

    VaultEntry? picked;
    await showDialog<void>(
      context: context,
      builder: (ctx) => FolioDialog(
        title: Text(l10n.deleteOtherVaultTitle),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: others
                .map(
                  (e) => ListTile(
                    title: Text(e.displayName),
                    subtitle: Text(
                      e.id,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () {
                      picked = e;
                      Navigator.pop(ctx);
                    },
                  ),
                )
                .toList(growable: false),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
        ],
      ),
    );
    if (picked == null || !mounted) return;

    final target = picked!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => FolioDialog(
        title: Text(l10n.deleteVaultConfirmTitle),
        content: Text(l10n.deleteVaultConfirmBody(target.displayName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    final requiresPassword = await _vaultRequiresPassword(target.id);
    if (!mounted) return;
    if (requiresPassword) {
      final verified = await _verifyVaultPasswordForDelete(target.id);
      if (!verified || !mounted) return;
    }

    try {
      await _s.deleteVaultById(target.id);
      if (!mounted) return;
      _snack(l10n.vaultDeletedSnack);
    } catch (e) {
      if (!mounted) return;
      _snack('$e');
    }
  }

  Future<void> _openEncryptPlainVaultDialog() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => _EncryptPlainVaultDialog(session: _s),
    );
    if (ok != true || !mounted) return;
    await _refreshSecurityFlags();
    if (!mounted) return;
    _snack(AppLocalizations.of(context).encryptPlainVaultSuccessSnack);
  }

  Future<void> _confirmRemoteEndpointIfNeeded() async {
    final uri = AiSafetyPolicy.parseAndNormalizeUrl(_app.aiBaseUrl);
    if (uri == null) return;
    final isRemote = !AiSafetyPolicy.isLocalhostHost(uri.host);
    if (!isRemote || _app.aiEndpointMode != AiEndpointMode.allowRemote) return;
    if (_app.aiRemoteEndpointConfirmed) return;
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => FolioDialog(
        title: const Text('Confirmar endpoint remoto'),
        content: Text(
          'Vas a habilitar IA con un host remoto (${uri.host}). '
          'El contenido que envíes puede salir del equipo.\n\n¿Continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    if (go == true) {
      await _app.setAiRemoteEndpointConfirmed(true);
      return;
    }
    await _app.setAiEnabled(false);
  }

  Future<void> _saveAiFields() async {
    await _app.setAiBaseUrl(_aiBaseUrlController.text);
    final timeout = int.tryParse(_aiTimeoutController.text.trim());
    if (timeout != null) {
      await _app.setAiTimeoutMs(timeout);
    }
    final ctxWin = int.tryParse(_aiContextWindowController.text.trim());
    if (ctxWin != null) {
      await _app.setAiContextWindowTokens(ctxWin);
    }
    await _confirmRemoteEndpointIfNeeded();
    await _refreshReleaseReadiness();
  }

  Future<bool> _confirmAiBetaEnable() async {
    final l10n = AppLocalizations.of(context);
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => FolioDialog(
        title: Text(l10n.aiBetaEnableTitle),
        content: Text(l10n.aiBetaEnableBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.aiBetaEnableConfirm),
          ),
        ],
      ),
    );
    return go == true;
  }

  Future<bool> _confirmQuillGlobalScopeIfNeeded() async {
    if (_app.hasAcceptedQuillGlobalScope) return true;
    final l10n = AppLocalizations.of(context);
    final accepted = await showDialog<bool>(
      context: context,
      builder: (ctx) => FolioDialog(
        title: Text(l10n.quillGlobalScopeNoticeTitle),
        content: Text(l10n.quillGlobalScopeNoticeBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.quillGlobalScopeNoticeConfirm),
          ),
        ],
      ),
    );
    if (accepted == true) {
      await _app.setHasAcceptedQuillGlobalScope(true);
      return true;
    }
    return false;
  }

  String _providerLabel(AiProvider provider, AppLocalizations l10n) {
    switch (provider) {
      case AiProvider.ollama:
        return 'Ollama';
      case AiProvider.lmStudio:
        return 'LM Studio';
      case AiProvider.folioCloud:
        return 'Folio Cloud';
      case AiProvider.none:
        return l10n.aiProviderNone;
    }
  }

  Future<AiProvider?> _askUserProviderChoice() async {
    final l10n = AppLocalizations.of(context);
    return showDialog<AiProvider>(
      context: context,
      builder: (ctx) => FolioDialog(
        title: Text(l10n.aiSetupChooseProviderTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.aiSetupChooseProviderBody),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.hub_outlined),
              title: const Text('Ollama'),
              onTap: () => Navigator.pop(ctx, AiProvider.ollama),
            ),
            ListTile(
              leading: const Icon(Icons.hub_outlined),
              title: const Text('LM Studio'),
              onTap: () => Navigator.pop(ctx, AiProvider.lmStudio),
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
  }

  Future<bool> _autoDetectAndConfigureAiProvider() async {
    if (_detectingAiProvider) return false;
    setState(() => _detectingAiProvider = true);
    try {
      final detector = const AiProviderDetector();
      final summary = await detector.detect(preferredProvider: _app.aiProvider);
      final recommended = summary.recommendedProvider;
      if (recommended != null) {
        await _app.setAiProvider(recommended);
        final baseUrl = recommended == AiProvider.ollama
            ? AppSettings.defaultOllamaUrl
            : AppSettings.defaultLmStudioUrl;
        _aiBaseUrlController.text = baseUrl;
        await _app.setAiBaseUrl(baseUrl);
        await _saveAiFields();
        await _loadAiModels();
        if (mounted) {
          final l10n = AppLocalizations.of(context);
          _snack(
            l10n.aiProviderAutoConfigured(_providerLabel(recommended, l10n)),
          );
        }
        return true;
      }

      if (!mounted) return false;
      final l10n = AppLocalizations.of(context);
      final selectedProvider = await _askUserProviderChoice();
      if (!mounted || selectedProvider == null) return false;
      var retry = true;
      while (retry && mounted) {
        final action = await showDialog<_AiWizardAction>(
          context: context,
          builder: (ctx) => _AiSetupWizardDialog(
            summary: summary,
            selectedProvider: selectedProvider,
            title: l10n.aiSetupWizardTitle,
            noProviderTitle: l10n.aiSetupNoProviderTitle,
            noProviderBody: l10n.aiSetupNoProviderBody,
            ollamaInstallTitle: l10n.aiSetupOllamaTitle,
            ollamaInstallBody: l10n.aiSetupOllamaBody,
            lmStudioInstallTitle: l10n.aiSetupLmStudioTitle,
            lmStudioInstallBody: l10n.aiSetupLmStudioBody,
            openSettingsHint: l10n.aiSetupOpenSettingsHint,
            retryLabel: l10n.retry,
            closeLabel: l10n.cancel,
          ),
        );
        if (action == _AiWizardAction.retry) {
          final redetected = await detector.detect(
            preferredProvider: _app.aiProvider,
          );
          final selectedResult = selectedProvider == AiProvider.ollama
              ? redetected.ollama
              : redetected.lmStudio;
          if (selectedResult.reachable) {
            await _app.setAiProvider(selectedProvider);
            final baseUrl = selectedProvider == AiProvider.ollama
                ? AppSettings.defaultOllamaUrl
                : AppSettings.defaultLmStudioUrl;
            _aiBaseUrlController.text = baseUrl;
            await _app.setAiBaseUrl(baseUrl);
            await _saveAiFields();
            await _loadAiModels();
            if (mounted) {
              final l10n = AppLocalizations.of(context);
              _snack(
                l10n.aiProviderAutoConfigured(
                  _providerLabel(selectedProvider, l10n),
                ),
              );
            }
            return true;
          }
          retry = true;
          continue;
        }
        retry = false;
      }
      return false;
    } finally {
      if (mounted) setState(() => _detectingAiProvider = false);
    }
  }

  AiService _buildAiServiceFromInputs() {
    switch (_app.aiProvider) {
      case AiProvider.folioCloud:
        return FolioCloudAiService(entitlements: _folio);
      case AiProvider.none:
        throw StateError('Selecciona un proveedor IA primero.');
      case AiProvider.ollama:
      case AiProvider.lmStudio:
        break;
    }
    final uri = AiSafetyPolicy.parseAndNormalizeUrl(
      _aiBaseUrlController.text.trim(),
    );
    if (uri == null) {
      throw StateError('URL inválida. Usa http://localhost:1234');
    }
    final timeoutMs =
        int.tryParse(_aiTimeoutController.text.trim()) ?? _app.aiTimeoutMs;
    final timeout = Duration(milliseconds: timeoutMs.clamp(3000, 120000));
    switch (_app.aiProvider) {
      case AiProvider.ollama:
        return OllamaAiService(
          baseUrl: uri,
          timeout: timeout,
          defaultModel: _app.aiModel,
        );
      case AiProvider.lmStudio:
        return LmStudioAiService(
          baseUrl: uri,
          timeout: timeout,
          defaultModel: _app.aiModel,
        );
      case AiProvider.none:
      case AiProvider.folioCloud:
        throw StateError('Selecciona un proveedor IA primero.');
    }
  }

  Future<void> _testAiConnection() async {
    await _saveAiFields();
    if (_app.aiProvider != AiProvider.folioCloud) {
      final err = AiSafetyPolicy.validateEndpoint(
        rawUrl: _app.aiBaseUrl,
        mode: _app.aiEndpointMode,
        remoteConfirmed: _app.aiRemoteEndpointConfirmed,
      );
      if (err != null) {
        _snack(err);
        return;
      }
    }
    try {
      final service = _buildAiServiceFromInputs();
      await service.ping();
      await _loadAiModels();
      _snack('Conexión IA OK');
    } catch (e) {
      if (e is FolioCloudAiException) {
        _snack(e.message);
      } else {
        _snack('Error de conexión: $e');
      }
    }
  }

  Future<void> _loadAiModels() async {
    setState(() => _loadingModels = true);
    try {
      final service = _buildAiServiceFromInputs();
      final models = await service.listModels();
      if (!mounted) return;
      setState(() {
        _availableModels = models;
      });
      await _app.setCachedAiModelsFor(_app.aiProvider, models);
      if (models.isNotEmpty) {
        final selected = models.contains(_app.aiModel)
            ? _app.aiModel
            : models.first;
        await _app.setAiModel(selected);
      }
    } catch (e) {
      if (!mounted) return;
      _snack('No se pudieron listar modelos: $e');
    } finally {
      if (mounted) {
        setState(() => _loadingModels = false);
      }
    }
  }

  Future<void> _syncFolioStripeSubscription() async {
    if (_folioCloudActionBusy) return;
    setState(() => _folioCloudActionBusy = true);
    try {
      await _folio.refreshSubscriptionFromStripe();
      if (!mounted) return;
      _snack(
        _t(
          'Estado de suscripción actualizado.',
          'Subscription status refreshed.',
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _snack('$e');
    } finally {
      if (mounted) setState(() => _folioCloudActionBusy = false);
    }
  }

  Future<void> _openFolioBillingPortal() async {
    if (_folioCloudActionBusy) return;
    setState(() => _folioCloudActionBusy = true);
    try {
      final uri = await createBillingPortalUri();
      if (uri == null) {
        _snack(
          _t(
            'Portal de facturación no disponible.',
            'Billing portal unavailable.',
          ),
        );
        return;
      }
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) {
        _snack(_t('No se pudo abrir el enlace.', 'Could not open the link.'));
      }
    } catch (e) {
      _snack('$e');
    } finally {
      if (mounted) setState(() => _folioCloudActionBusy = false);
    }
  }

  String _l10nFolioWebPortalError(
    AppLocalizations l10n,
    FolioWebPortalException e,
  ) {
    final d = e.detail?.trim();
    switch (e.kind) {
      case FolioWebPortalErrorKind.network:
      case FolioWebPortalErrorKind.invalidBaseUrl:
        return l10n.folioWebPortalErrorNetwork;
      case FolioWebPortalErrorKind.timeout:
        return l10n.folioWebPortalErrorTimeout;
      case FolioWebPortalErrorKind.adminNotConfigured:
        return l10n.folioWebPortalErrorAdminNotConfigured;
      case FolioWebPortalErrorKind.unauthorized:
        return l10n.folioWebPortalErrorUnauthorized;
      case FolioWebPortalErrorKind.forbidden:
      case FolioWebPortalErrorKind.notFound:
      case FolioWebPortalErrorKind.conflict:
      case FolioWebPortalErrorKind.badRequest:
      case FolioWebPortalErrorKind.linkRejected:
      case FolioWebPortalErrorKind.serverError:
      case FolioWebPortalErrorKind.invalidJson:
      case FolioWebPortalErrorKind.entitlementParse:
        if (d != null && d.isNotEmpty) {
          return l10n.folioWebPortalServerMessage(d);
        }
        return l10n.folioWebPortalErrorGeneric;
    }
  }

  Future<void> _linkFolioWebPortalAccount() async {
    if (!AppSettings.folioWebPortalLinkEnabled) return;
    if (_webLinkBusy) return;
    final l10n = AppLocalizations.of(context);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _snack(l10n.folioWebPortalNeedSignIn);
      return;
    }
    final base = _app.folioWebPortalBaseUrlEffective;
    setState(() => _webLinkBusy = true);
    try {
      final token = await user.getIdToken(true);
      if (token == null || token.isEmpty) {
        if (mounted) _snack(l10n.folioWebPortalErrorUnauthorized);
        return;
      }
      await linkFolioWebAccount(
        portalBaseUrl: base,
        linkCode: _webLinkCodeController.text,
        idToken: token,
      );
      if (!mounted) return;
      _webLinkCodeController.clear();
      _snack(l10n.folioWebPortalLinkSuccess);
      await _folio.refreshWebPortalEntitlement();
    } on FolioWebPortalException catch (e) {
      if (mounted) {
        _snack(_l10nFolioWebPortalError(l10n, e));
      }
    } catch (e) {
      if (mounted) _snack('$e');
    } finally {
      if (mounted) setState(() => _webLinkBusy = false);
    }
  }

  Future<void> _refreshFolioWebPortalEntitlement() async {
    if (!AppSettings.folioWebPortalLinkEnabled) return;
    await _folio.refreshWebPortalEntitlement();
    if (!mounted) return;
    final err = _folio.webPortalRefreshError;
    if (err != null) {
      _snack(_l10nFolioWebPortalError(AppLocalizations.of(context), err));
    }
  }

  void _openFolioCloudSubscriptionPitch() {
    if (_folioCloudActionBusy) return;
    final l10n = AppLocalizations.of(context);
    final signedIn = _cloud.isSignedIn;
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (ctx) => FolioCloudSubscriptionPitchPage(
          busy: _folioCloudActionBusy,
          primaryCtaLabel: signedIn
              ? l10n.folioCloudSubscribeMonthly
              : l10n.folioCloudPitchCtaNeedAccount,
          primaryIcon: signedIn
              ? Icons.subscriptions_outlined
              : Icons.person_add_outlined,
          onPrimaryCta: () {
            Navigator.of(ctx).pop();
            if (!mounted) return;
            if (signedIn) {
              unawaited(_openFolioCheckout(FolioCheckoutKind.folioCloudMonthly));
            } else {
              unawaited(_showCloudAuthDialog(register: false));
            }
          },
        ),
      ),
    );
  }

  Future<void> _openFolioCheckout(FolioCheckoutKind kind) async {
    if (_folioCloudActionBusy) return;
    setState(() => _folioCloudActionBusy = true);
    try {
      final uri = await createFolioCheckoutUri(kind);
      if (uri == null) {
        _snack(
          _t(
            'Pago no disponible (configura Stripe en el servidor).',
            'Checkout unavailable (configure Stripe on server).',
          ),
        );
        return;
      }
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) {
        _snack(_t('No se pudo abrir el enlace.', 'Could not open the link.'));
      } else {
        _folio.scheduleStripeSyncOnNextResume();
      }
    } catch (e) {
      _snack('$e');
    } finally {
      if (mounted) setState(() => _folioCloudActionBusy = false);
    }
  }

  Future<void> _uploadFolioCloudBackup() async {
    if (_folioCloudActionBusy) return;
    if (_s.state != VaultFlowState.unlocked) return;
    final vaultId = _s.activeVaultId;
    if (vaultId == null || vaultId.trim().isEmpty) {
      _snack(_t('No hay libreta activa.', 'No active vault.'));
      return;
    }
    final snap = _folio.snapshot;
    if (!snap.canUseCloudBackup) {
      _snack(
        _t(
          'Activa Folio Cloud con la función de copia en la nube incluida en tu plan.',
          'Enable Folio Cloud with the cloud backup feature included in your plan.',
        ),
      );
      return;
    }
    setState(() => _folioCloudActionBusy = true);
    try {
      final label = await _s.getActiveVaultDisplayLabel();
      try {
        await upsertFolioCloudBackupVaultIndex(
          vaultId: vaultId,
          displayName: label,
          entitlementSnapshot: snap,
        );
      } catch (_) {}
      await uploadOpenVaultEncryptedToCloud(
        session: _s,
        vaultId: vaultId,
        entitlementSnapshot: snap,
      );
      // Best-effort: recorta a 10 copias por libreta.
      try {
        await trimFolioCloudBackups(
          vaultId: vaultId,
          maxCount: 10,
          entitlementSnapshot: snap,
        );
      } catch (e) {
        _snack(AppLocalizations.of(context).folioCloudBackupCleanupWarning);
      }
      if (mounted) {
        _snack(AppLocalizations.of(context).folioCloudUploadSnackOk);
      }
      await _refreshCloudBackupCount(requireVerify: false);
    } catch (e) {
      if (mounted) _snack('$e');
    } finally {
      if (mounted) setState(() => _folioCloudActionBusy = false);
    }
  }

  Future<void> _refreshCloudBackupCount({required bool requireVerify}) async {
    if (_cloudBackupCountBusy) return;
    final vaultId = _s.activeVaultId;
    if (vaultId == null || vaultId.trim().isEmpty) return;
    final snap = _folio.snapshot;
    if (!snap.canUseCloudBackup) return;
    if (requireVerify) {
      final verified = await _verifyFolioCloudAccountForBackups();
      if (!verified || !mounted) return;
    }
    setState(() => _cloudBackupCountBusy = true);
    try {
      final entries = await listFolioCloudBackups(
        vaultId: vaultId,
        entitlementSnapshot: snap,
      );
      if (!mounted) return;
      setState(() => _cloudBackupCount = entries.length);
    } catch (_) {
      // No interrumpimos la UI por el contador.
    } finally {
      if (mounted) setState(() => _cloudBackupCountBusy = false);
    }
  }

  Future<void> _folioPublishDemoPage() async {
    if (_folioCloudActionBusy) return;
    final snap = _folio.snapshot;
    if (!snap.canPublishToWeb) {
      _snack(
        _t(
          'Activa Folio Cloud con publicación web incluida en tu plan.',
          'Enable Folio Cloud with web publishing included in your plan.',
        ),
      );
      return;
    }
    setState(() => _folioCloudActionBusy = true);
    try {
      final slug = 'demo-${DateTime.now().millisecondsSinceEpoch}';
      String? appIconDataUri;
      try {
        final data = await rootBundle.load('assets/icons/folio.ico');
        appIconDataUri =
            'data:image/x-icon;base64,${base64Encode(data.buffer.asUint8List())}';
      } catch (_) {}
      final html = folioWebExportShellHtml(
        documentTitle: 'Folio',
        pageHeading: 'Folio',
        pageSubtitle: 'Página de prueba',
        bodyHtml: '<p>Página publicada desde Folio.</p>',
        appIconDataUri: appIconDataUri,
      );
      final res = await publishHtmlPage(
        slug: slug,
        html: html,
        entitlementSnapshot: snap,
      );
      _snack(_t('Publicado: ${res.publicUrl}', 'Published: ${res.publicUrl}'));
      await launchUrl(res.publicUrl, mode: LaunchMode.externalApplication);
    } catch (e) {
      _snack('$e');
    } finally {
      if (mounted) setState(() => _folioCloudActionBusy = false);
    }
  }

  Future<void> _openFolioCloudBackupsDialog() async {
    if (_folioCloudActionBusy) return;
    final vaultId = _s.activeVaultId;
    if (vaultId == null || vaultId.trim().isEmpty) {
      _snack(_t('No hay libreta activa.', 'No active vault.'));
      return;
    }
    final snap = _folio.snapshot;
    if (!snap.canUseCloudBackup) {
      _snack(
        _t(
          'Necesitas Folio Cloud activo con copia en la nube.',
          'You need an active Folio Cloud plan with cloud backup.',
        ),
      );
      return;
    }
    final verified = await _verifyFolioCloudAccountForBackups();
    if (!verified || !mounted) return;
    setState(() => _folioCloudActionBusy = true);
    late final List<FolioCloudBackupEntry> entries;
    try {
      entries = await listFolioCloudBackups(
        vaultId: vaultId,
        entitlementSnapshot: snap,
      );
    } catch (e) {
      if (mounted) {
        setState(() => _folioCloudActionBusy = false);
        _snack('$e');
      }
      return;
    }
    if (!mounted) return;
    setState(() => _folioCloudActionBusy = false);
    setState(() => _cloudBackupCount = entries.length);
    final l10n = AppLocalizations.of(context);
    await showDialog<void>(
      context: context,
      builder: (ctx) => FolioDialog(
        title: Text(
          _t(
            'Copias en la nube (${entries.length}/10)',
            'Cloud backups (${entries.length}/10)',
          ),
        ),
        content: SizedBox(
          width: 420,
          child: entries.isEmpty
              ? Text(
                  _t(
                    'Aún no hay copias en esta cuenta.',
                    'No backups in this account yet.',
                  ),
                )
              : ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 360),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: entries.length,
                    itemBuilder: (c, i) {
                      final e = entries[i];
                      return ListTile(
                        title: Text(
                          e.fileName,
                          style: const TextStyle(fontFamily: 'monospace'),
                        ),
                        trailing: IconButton(
                          tooltip: _t('Descargar', 'Download'),
                          icon: const Icon(Icons.download_outlined),
                          onPressed: () async {
                            final path = await FilePicker.platform.saveFile(
                              dialogTitle: _t(
                                'Guardar copia',
                                'Save backup',
                              ),
                              fileName: e.fileName,
                            );
                            if (path == null || !ctx.mounted) return;
                            try {
                              await downloadFolioCloudBackup(
                                entry: e,
                                destinationFile: File(path),
                                entitlementSnapshot: snap,
                              );
                              if (!ctx.mounted) return;
                              Navigator.pop(ctx);
                              if (mounted) {
                                _snack(
                                  _t('Copia descargada.', 'Backup downloaded.'),
                                );
                                setState(() => _cloudBackupCount = entries.length);
                              }
                            } catch (err) {
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(
                                  ctx,
                                ).showSnackBar(SnackBar(content: Text('$err')));
                              }
                            }
                          },
                        ),
                      );
                    },
                  ),
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
        ],
      ),
    );
  }

  Future<void> _openPublishedPagesDialog() async {
    if (_folioCloudActionBusy) return;
    final snap = _folio.snapshot;
    if (!snap.canPublishToWeb) {
      _snack(
        _t(
          'Necesitas Folio Cloud con publicación web activa.',
          'You need Folio Cloud with web publishing enabled.',
        ),
      );
      return;
    }
    setState(() => _folioCloudActionBusy = true);
    late final List<PublishedPageEntry> entries;
    try {
      entries = await listMyPublishedPages();
    } catch (e) {
      if (mounted) {
        setState(() => _folioCloudActionBusy = false);
        _snack('$e');
      }
      return;
    }
    if (!mounted) return;
    setState(() => _folioCloudActionBusy = false);
    await showDialog<void>(
      context: context,
      builder: (ctx) => FolioDialog(
        title: Text(_t('Páginas publicadas', 'Published pages')),
        content: SizedBox(
          width: 440,
          child: entries.isEmpty
              ? Text(
                  _t(
                    'Aún no hay páginas publicadas.',
                    'No published pages yet.',
                  ),
                )
              : ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 400),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: entries.length,
                    itemBuilder: (c, i) {
                      final e = entries[i];
                      final when = e.updatedAt != null
                          ? '${e.updatedAt!.toLocal()}'
                          : '—';
                      return ListTile(
                        title: Text(
                          e.slug,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          when,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: _t('Abrir', 'Open'),
                              icon: const Icon(Icons.open_in_new_outlined),
                              onPressed: () async {
                                final u = Uri.tryParse(e.publicUrl);
                                if (u != null) {
                                  await launchUrl(
                                    u,
                                    mode: LaunchMode.externalApplication,
                                  );
                                }
                              },
                            ),
                            IconButton(
                              tooltip: _t('Eliminar', 'Delete'),
                              icon: Icon(
                                Icons.delete_outline_rounded,
                                color: Theme.of(ctx).colorScheme.error,
                              ),
                              onPressed: () async {
                                final sure = await showDialog<bool>(
                                  context: ctx,
                                  builder: (dCtx) => AlertDialog(
                                    title: Text(
                                      _t(
                                        '¿Eliminar publicación?',
                                        'Remove publication?',
                                      ),
                                    ),
                                    content: Text(
                                      _t(
                                        'Se borrará el HTML público y el enlace dejará de funcionar.',
                                        'The public HTML will be removed and the link will stop working.',
                                      ),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(dCtx, false),
                                        child: Text(
                                          MaterialLocalizations.of(
                                            dCtx,
                                          ).cancelButtonLabel,
                                        ),
                                      ),
                                      FilledButton(
                                        onPressed: () =>
                                            Navigator.pop(dCtx, true),
                                        child: Text(_t('Eliminar', 'Delete')),
                                      ),
                                    ],
                                  ),
                                );
                                if (sure != true || !ctx.mounted) return;
                                try {
                                  await deletePublishedPage(
                                    e,
                                    entitlementSnapshot: snap,
                                  );
                                  if (!ctx.mounted) return;
                                  Navigator.pop(ctx);
                                  if (mounted) {
                                    _snack(
                                      _t('Publicación eliminada.', 'Removed.'),
                                    );
                                  }
                                } catch (err) {
                                  if (ctx.mounted) {
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                      SnackBar(content: Text('$err')),
                                    );
                                  }
                                }
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(_t('Cerrar', 'Close')),
          ),
        ],
      ),
    );
  }

  String _suggestedBackupFileName() {
    final d = DateTime.now();
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return 'folio-libreta-$y-$m-$day.folio.zip';
  }

  Future<void> _openExportBackupFlow() async {
    final l10n = AppLocalizations.of(context);
    if (_s.state != VaultFlowState.unlocked) return;
    final verified = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => VaultIdentityVerifyDialog(
        session: _s,
        quickEnabled: _quickEnabled,
        passkeyRegistered: _passkeyRegistered,
        title: Text(l10n.exportVaultDialogTitle),
        body: Text(l10n.exportVaultDialogBody),
        passwordButtonLabel: l10n.verifyAndExport,
      ),
    );
    if (verified != true || !mounted) return;

    final path = await FilePicker.platform.saveFile(
      dialogTitle: l10n.saveVaultBackupDialogTitle,
      fileName: _suggestedBackupFileName(),
      type: FileType.custom,
      allowedExtensions: const ['zip'],
    );
    if (path == null || !mounted) return;

    try {
      await _s.exportVaultBackup(path);
      if (mounted) {
        _snack(l10n.backupSavedSuccessSnack);
      }
    } on VaultBackupException catch (e) {
      if (mounted) _snack(l10n.exportFailedError('$e'));
    } catch (e) {
      if (mounted) {
        _snack(l10n.exportFailedError('$e'));
      }
    }
  }

  Future<void> _openImportBackupFlow() async {
    final l10n = AppLocalizations.of(context);
    if (_s.state != VaultFlowState.unlocked) return;
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => FolioDialog(
        title: Text(l10n.importVaultDialogTitle),
        content: SingleChildScrollView(
          child: Text(
            l10n.importVaultDialogBody,
            style: const TextStyle(height: 1.45),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.continueAction),
          ),
        ],
      ),
    );
    if (go != true || !mounted) return;

    final verified = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => VaultIdentityVerifyDialog(
        session: _s,
        quickEnabled: _quickEnabled,
        passkeyRegistered: _passkeyRegistered,
        title: Text(l10n.confirmIdentity),
        body: Text(l10n.importIdentityBody),
        passwordButtonLabel: l10n.verifyAndContinue,
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
      _snack(l10n.filePathReadError);
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
      _snack(l10n.importedVaultSuccessSnack);
      Navigator.of(context).pop();
    } on VaultBackupException catch (e) {
      if (mounted) _snack(l10n.importFailedGenericError('$e'));
    } catch (e) {
      if (mounted) _snack(l10n.importFailedGenericError('$e'));
    }
  }

  Future<void> _openImportNotionFlow() async {
    final l10n = AppLocalizations.of(context);
    if (_s.state != VaultFlowState.unlocked) return;

    final verified = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => VaultIdentityVerifyDialog(
        session: _s,
        quickEnabled: _quickEnabled,
        passkeyRegistered: _passkeyRegistered,
        title: Text(l10n.importNotionDialogTitle),
        body: Text(l10n.importNotionDialogBody),
        passwordButtonLabel: l10n.verifyAndContinue,
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
      _snack(l10n.filePathReadError);
      return;
    }

    final mode = await showDialog<_NotionImportMode>(
      context: context,
      builder: (ctx) => const _NotionImportModeDialog(),
    );
    if (mode == null || !mounted) return;

    try {
      if (mode == _NotionImportMode.currentVault) {
        await _s.importNotionIntoCurrentVault(fp);
        if (!mounted) return;
        _snack(l10n.importNotionSuccessCurrent);
      } else {
        final newPassword = await showDialog<String>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => const _NewVaultPasswordDialog(),
        );
        if (newPassword == null || newPassword.isEmpty || !mounted) return;
        await _s.importNotionAsNewVault(
          fp,
          masterPassword: newPassword,
          displayName: l10n.importNotionDefaultVaultName,
        );
        if (!mounted) return;
        _snack(l10n.importNotionSuccessNew);
      }
    } on NotionImportException catch (e) {
      if (mounted) _snack(l10n.importNotionError('$e'));
    } catch (e) {
      if (mounted) _snack(l10n.importNotionError('$e'));
    }
    if (!mounted) return;
    final warnings = _s.lastImportWarnings;
    if (warnings.isNotEmpty) {
      await _showImportWarningsDialog(warnings);
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
                        const Text('• '),
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

  Future<void> _openWipeFlow() async {
    final l10n = AppLocalizations.of(context);
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => FolioDialog(
        title: Text(l10n.wipeVaultDialogTitle),
        content: Text(l10n.wipeVaultDialogBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.continueAction),
          ),
        ],
      ),
    );
    if (go != true || !mounted) return;

    if (_s.vaultUsesEncryption) {
      final verified = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => VaultIdentityVerifyDialog(
          session: _s,
          quickEnabled: _quickEnabled,
          passkeyRegistered: _passkeyRegistered,
          title: Text(l10n.confirmIdentity),
          body: Text(l10n.wipeIdentityBody),
          passwordButtonLabel: l10n.verifyAndDelete,
        ),
      );

      if (verified != true || !context.mounted) return;
    }

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
      _snack(l10n.wipeFailedError('$e'));
    }
  }

  GitHubReleaseUpdater _buildUpdater() {
    return GitHubReleaseUpdater(
      owner: _app.updaterGithubOwner,
      repo: _app.updaterGithubRepo,
    );
  }

  Future<void> _checkUpdatesNow() async {
    if (_checkingUpdates) return;
    setState(() => _checkingUpdates = true);
    try {
      final updater = _buildUpdater();
      final result = await updater.checkForUpdate(
        channel: _app.updateReleaseChannel,
      );
      if (!mounted) return;
      if (!result.supportedPlatform) {
        _snack('El actualizador integrado solo está disponible en Windows.');
        return;
      }
      if (!result.hasUpdate) {
        final r = result.reason;
        _snack(
          r != null && r.isNotEmpty ? r : 'Ya tienes la versión más reciente.',
        );
        return;
      }
      final betaNote = result.isPrerelease
          ? '\n\nEsta es una versión beta (pre-release).'
          : '';
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => FolioDialog(
          title: Text(
            result.isPrerelease
                ? 'Beta disponible'
                : 'Actualización disponible',
          ),
          content: Text(
            'Versión actual: ${result.currentVersion}\n'
            'Nueva versión: ${result.releaseVersion}$betaNote\n\n'
            '¿Descargar e instalar ahora?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Más tarde'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Actualizar ahora'),
            ),
          ],
        ),
      );
      if (go != true) return;
      final installer = await updater.downloadInstaller(result);
      await updater.launchInstallerAndExit(installer);
    } catch (e) {
      if (!mounted) return;
      _snack('No se pudo actualizar: $e');
    } finally {
      if (mounted) setState(() => _checkingUpdates = false);
    }
  }

  Future<void> _openChangeMasterPasswordFlow() async {
    if (_s.state != VaultFlowState.unlocked) return;
    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _ChangeMasterPasswordDialog(session: _s),
    );
    if (changed == true && mounted) {
      _snack(AppLocalizations.of(context).masterPasswordUpdatedSnack);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final windowWidth = MediaQuery.sizeOf(context).width;
    final showDesktopOnlySections = FolioAdaptive.shouldUseDesktopSections(
      windowWidth,
    );
    final desktopSections = <_SettingsSectionNavItem>[
      _SettingsSectionNavItem(label: l10n.appearance, keyIndex: 0),
      _SettingsSectionNavItem(label: l10n.security, keyIndex: 1),
      if (showDesktopOnlySections) ...[
        _SettingsSectionNavItem(label: l10n.desktopSection, keyIndex: 2),
        _SettingsSectionNavItem(
          label: l10n.keyboardShortcutsSection,
          keyIndex: 3,
        ),
      ],
      if (_app.isAiAvailable)
        _SettingsSectionNavItem(label: l10n.ai, keyIndex: 4),
      _SettingsSectionNavItem(label: l10n.vaultBackup, keyIndex: 5),
      if (showDesktopOnlySections)
        _SettingsSectionNavItem(label: l10n.integrations, keyIndex: 6),
      _SettingsSectionNavItem(
        label: l10n.cloudAccountSectionTitle,
        keyIndex: 7,
      ),
      _SettingsSectionNavItem(
        label: _t('Sincronizacion', 'Device sync'),
        keyIndex: 8,
      ),
      _SettingsSectionNavItem(label: l10n.about, keyIndex: 9),
      _SettingsSectionNavItem(label: l10n.data, keyIndex: 10),
    ];
    return AnimatedBuilder(
      animation: _app,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: Text(l10n.settings)),
          body: LayoutBuilder(
            builder: (context, constraints) {
              final wide =
                  constraints.maxWidth >= FolioDesktop.mediumBreakpoint ||
                  FolioAdaptive.isAndroidDesktopLikeWidth(constraints.maxWidth);
              final settingsContent = ListenableBuilder(
                listenable: _s,
                builder: (context, _) {
                  return DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          scheme.surfaceContainer.withValues(alpha: 0.72),
                          scheme.surfaceContainerLow,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: scheme.outlineVariant.withValues(alpha: 0.35),
                      ),
                    ),
                    child: ListView(
                      controller: _settingsScrollController,
                      padding: const EdgeInsets.symmetric(
                        vertical: 24,
                        horizontal: 16,
                      ),
                      children: [
                        _SettingsOverviewBanner(appSettings: _app, session: _s),
                        const SizedBox(height: 8),
                        if (!wide) ...[
                          Semantics(
                            label: l10n.settingsSearchSections,
                            textField: true,
                            child: TextField(
                              controller: _settingsSectionFilterController,
                              decoration: InputDecoration(
                                prefixIcon: const Icon(Icons.search_rounded),
                                labelText: l10n.settingsSearchSections,
                                hintText: l10n.settingsSearchSectionsHint,
                                border: const OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        _SettingsPanel(
                          key: _sectionKeys[0],
                          margin: const EdgeInsets.only(bottom: 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _SettingsPanelHeroCard(
                                icon: Icons.palette_outlined,
                                title: l10n.appearance,
                                description: l10n.settingsAppearanceHint,
                                chips: [
                                  _SettingsInfoChip(
                                    icon: Icons.brightness_auto,
                                    label: _t('Tema', 'Theme'),
                                  ),
                                  _SettingsInfoChip(
                                    icon: Icons.translate_rounded,
                                    label: _t('Idioma', 'Language'),
                                  ),
                                  _SettingsInfoChip(
                                    icon: Icons.edit_outlined,
                                    label: _t(
                                      'Editor y espacio',
                                      'Editor & workspace',
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 1),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                child: SegmentedButton<ThemeMode>(
                                  segments: [
                                    ButtonSegment<ThemeMode>(
                                      value: ThemeMode.system,
                                      label: Text(l10n.systemTheme),
                                      icon: const Icon(
                                        Icons.brightness_auto,
                                        size: 18,
                                      ),
                                    ),
                                    ButtonSegment<ThemeMode>(
                                      value: ThemeMode.light,
                                      label: Text(l10n.lightTheme),
                                      icon: const Icon(
                                        Icons.light_mode_outlined,
                                        size: 18,
                                      ),
                                    ),
                                    ButtonSegment<ThemeMode>(
                                      value: ThemeMode.dark,
                                      label: Text(l10n.darkTheme),
                                      icon: const Icon(
                                        Icons.dark_mode_outlined,
                                        size: 18,
                                      ),
                                    ),
                                  ],
                                  selected: {_app.themeMode},
                                  onSelectionChanged: (s) {
                                    _app.setThemeMode(s.first);
                                  },
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Divider(height: 1),
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
                                  underline: const SizedBox.shrink(),
                                  onChanged: (code) {
                                    _app.setLocale(
                                      code == null ? null : Locale(code),
                                    );
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
                              _SettingsSubsectionTitle(
                                title: _t('Editor', 'Editor'),
                                scheme: scheme,
                              ),
                              const Divider(height: 1),
                              ListTile(
                                leading: const Icon(Icons.width_full_rounded),
                                title: Text(
                                  _t('Ancho del contenido', 'Content width'),
                                ),
                                subtitle: Text(
                                  _t(
                                    'Define cuánto ancho ocupan los bloques en el editor.',
                                    'Controls how wide blocks appear in the editor.',
                                  ),
                                ),
                                trailing: Text(
                                  '${_app.editorContentWidth.round()} px',
                                  style: Theme.of(context).textTheme.labelLarge
                                      ?.copyWith(
                                        color: scheme.onSurfaceVariant,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  0,
                                  16,
                                  8,
                                ),
                                child: Slider(
                                  value: _app.editorContentWidth,
                                  min: AppSettings.minEditorContentWidth,
                                  max: AppSettings.maxEditorContentWidth,
                                  divisions:
                                      ((AppSettings.maxEditorContentWidth -
                                                  AppSettings
                                                      .minEditorContentWidth) /
                                              20)
                                          .round(),
                                  label:
                                      '${_app.editorContentWidth.round()} px',
                                  onChanged: (value) {
                                    _app.setEditorContentWidth(value);
                                  },
                                ),
                              ),
                              const Divider(height: 1),
                              SwitchListTile(
                                secondary: const Icon(Icons.keyboard_return),
                                title: Text(
                                  _t(
                                    'Enter crea un bloque nuevo',
                                    'Enter creates a new block',
                                  ),
                                ),
                                subtitle: Text(
                                  _app.enterCreatesNewBlock
                                      ? _t(
                                          'Desactiva para que Enter inserte salto de línea.',
                                          'Disable to make Enter insert a line break.',
                                        )
                                      : _t(
                                          'Ahora Enter inserta salto de línea. Usa Shift+Enter igual.',
                                          'Enter now inserts a line break. Shift+Enter still works.',
                                        ),
                                ),
                                value: _app.enterCreatesNewBlock,
                                onChanged: _app.setEnterCreatesNewBlock,
                              ),
                              _SettingsSubsectionTitle(
                                title: _t('Espacio de trabajo', 'Workspace'),
                                scheme: scheme,
                              ),
                              const Divider(height: 1),
                              SwitchListTile(
                                secondary: const Icon(
                                  Icons.view_sidebar_rounded,
                                ),
                                title: Text(l10n.sidebarAutoRevealTitle),
                                subtitle: Text(l10n.sidebarAutoRevealSubtitle),
                                value: _app.workspaceSidebarAutoReveal,
                                onChanged: (v) =>
                                    _app.setWorkspaceSidebarAutoReveal(v),
                              ),
                            ],
                          ),
                        ),
                        _SettingsPanel(
                          margin: const EdgeInsets.only(bottom: 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _SettingsPanelHeroCard(
                                icon: Icons.emoji_symbols_rounded,
                                title: _t(
                                  'Iconos personalizados',
                                  'Custom icons',
                                ),
                                description: _t(
                                  'Importa una URL PNG, GIF o WebP, o un data:image compatible copiado desde páginas como notionicons.so. Después podrás usarlo como icono de página o de callout.',
                                  'Import a PNG, GIF, or WebP URL, or a compatible data:image copied from sites like notionicons.so. You can then use it as a page or callout icon.',
                                ),
                                trailingBadge: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: scheme.surface,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    _t(
                                      '${_app.customIcons.length} guardados',
                                      '${_app.customIcons.length} saved',
                                    ),
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelMedium
                                        ?.copyWith(
                                          color: scheme.primary,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                ),
                                chips: [
                                  _SettingsInfoChip(
                                    icon: Icons.link_rounded,
                                    label: _t(
                                      'URL PNG, GIF o WebP',
                                      'PNG, GIF, or WebP URL',
                                    ),
                                  ),
                                  _SettingsInfoChip(
                                    icon: Icons.code_rounded,
                                    label: 'data:image/*',
                                  ),
                                  _SettingsInfoChip(
                                    icon: Icons.content_paste_rounded,
                                    label: _t(
                                      'Pegar desde portapapeles',
                                      'Paste from clipboard',
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 1),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  0,
                                  16,
                                  16,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: scheme.surfaceContainerLow,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: scheme.outlineVariant.withValues(
                                        alpha: 0.45,
                                      ),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Text(
                                        _t(
                                          'Importar nuevo icono',
                                          'Import new icon',
                                        ),
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        _t(
                                          'Puedes ponerle nombre y pegar la fuente manualmente o traerla directamente desde el portapapeles.',
                                          'You can give it a name and paste the source manually or bring it directly from the clipboard.',
                                        ),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: scheme.onSurfaceVariant,
                                              height: 1.35,
                                            ),
                                      ),
                                      const SizedBox(height: 14),
                                      TextField(
                                        controller: _customIconLabelController,
                                        decoration: InputDecoration(
                                          labelText: _t('Nombre', 'Name'),
                                          hintText: _t('Opcional', 'Optional'),
                                          prefixIcon: const Icon(
                                            Icons.edit_outlined,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      TextField(
                                        controller: _customIconSourceController,
                                        minLines: 3,
                                        maxLines: 5,
                                        decoration: InputDecoration(
                                          labelText: _t(
                                            'URL o data:image',
                                            'URL or data:image',
                                          ),
                                          hintText:
                                              'https://...gif | ...webp | ...png o data:image/...',
                                          alignLabelWithHint: true,
                                          prefixIcon: const Padding(
                                            padding: EdgeInsets.only(
                                              bottom: 42,
                                            ),
                                            child: Icon(Icons.link_rounded),
                                          ),
                                        ),
                                        onSubmitted: (_) =>
                                            _importCustomIconFromSource(
                                              _customIconSourceController.text,
                                            ),
                                      ),
                                      const SizedBox(height: 14),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: FilledButton.icon(
                                              onPressed: _importingCustomIcon
                                                  ? null
                                                  : () => _importCustomIconFromSource(
                                                      _customIconSourceController
                                                          .text,
                                                    ),
                                              icon: _importingCustomIcon
                                                  ? const SizedBox(
                                                      width: 16,
                                                      height: 16,
                                                      child:
                                                          CircularProgressIndicator(
                                                            strokeWidth: 2,
                                                          ),
                                                    )
                                                  : const Icon(
                                                      Icons.download_rounded,
                                                    ),
                                              label: Text(
                                                _t(
                                                  'Importar icono',
                                                  'Import icon',
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: OutlinedButton.icon(
                                              onPressed: _importingCustomIcon
                                                  ? null
                                                  : _importCustomIconFromClipboard,
                                              icon: const Icon(
                                                Icons.content_paste_rounded,
                                              ),
                                              label: Text(
                                                _t(
                                                  'Desde portapapeles',
                                                  'From clipboard',
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  0,
                                  16,
                                  8,
                                ),
                                child: Row(
                                  children: [
                                    Text(
                                      _t('Biblioteca', 'Library'),
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _t(
                                        'Listos para usar en toda la app',
                                        'Ready to use across the app',
                                      ),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: scheme.onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              if (_app.customIcons.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    0,
                                    16,
                                    16,
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.all(18),
                                    decoration: BoxDecoration(
                                      color: scheme.surfaceContainerLow,
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(
                                        color: scheme.outlineVariant.withValues(
                                          alpha: 0.45,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 42,
                                          height: 42,
                                          decoration: BoxDecoration(
                                            color: scheme.surface,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Icon(
                                            Icons.inventory_2_outlined,
                                            color: scheme.onSurfaceVariant,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            _t(
                                              'Todavía no has importado iconos.',
                                              'No icons imported yet.',
                                            ),
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  color:
                                                      scheme.onSurfaceVariant,
                                                  height: 1.35,
                                                ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              else
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    0,
                                    16,
                                    16,
                                  ),
                                  child: Wrap(
                                    spacing: 12,
                                    runSpacing: 12,
                                    children: _app.customIcons.map((entry) {
                                      return Container(
                                        width: 182,
                                        padding: const EdgeInsets.all(14),
                                        decoration: BoxDecoration(
                                          color: scheme.surfaceContainerLow,
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          border: Border.all(
                                            color: scheme.outlineVariant,
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Row(
                                              children: [
                                                Container(
                                                  width: 44,
                                                  height: 44,
                                                  decoration: BoxDecoration(
                                                    color: scheme.surface,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          14,
                                                        ),
                                                  ),
                                                  child: Center(
                                                    child: FolioIconTokenView(
                                                      appSettings: _app,
                                                      token: entry.token,
                                                      fallbackText: '📄',
                                                      size: 26,
                                                    ),
                                                  ),
                                                ),
                                                const Spacer(),
                                                IconButton(
                                                  tooltip: _t(
                                                    'Eliminar icono',
                                                    'Delete icon',
                                                  ),
                                                  onPressed: () =>
                                                      _removeCustomIcon(entry),
                                                  icon: const Icon(
                                                    Icons
                                                        .delete_outline_rounded,
                                                    size: 20,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 10),
                                            Text(
                                              entry.label,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleSmall
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              entry.mimeType,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.copyWith(
                                                    color:
                                                        scheme.onSurfaceVariant,
                                                  ),
                                            ),
                                            const SizedBox(height: 10),
                                            SizedBox(
                                              width: double.infinity,
                                              child: OutlinedButton.icon(
                                                onPressed: () async {
                                                  await Clipboard.setData(
                                                    ClipboardData(
                                                      text: entry.token,
                                                    ),
                                                  );
                                                  if (!context.mounted) {
                                                    return;
                                                  }
                                                  _snack(
                                                    _t(
                                                      'Referencia copiada.',
                                                      'Reference copied.',
                                                    ),
                                                  );
                                                },
                                                icon: const Icon(
                                                  Icons.content_copy_rounded,
                                                  size: 18,
                                                ),
                                                label: Text(
                                                  _t(
                                                    'Copiar token',
                                                    'Copy token',
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                            ],
                          ),
                        ),

                        if (_s.vaultUsesEncryption)
                          _SettingsPanel(
                            key: _sectionKeys[1],
                            margin: const EdgeInsets.only(bottom: 24),
                            child: Column(
                              children: [
                                _SettingsPanelHeroCard(
                                  icon: Icons.shield_outlined,
                                  title: l10n.security,
                                  description: _t(
                                    'Desbloqueo rápido, passkey, bloqueo automático y contraseña maestra del vault cifrado.',
                                    'Quick unlock, passkey, auto-lock, and master password for your encrypted vault.',
                                  ),
                                  chips: [
                                    _SettingsInfoChip(
                                      icon: Icons.fingerprint,
                                      label: l10n.quickUnlockTitle,
                                    ),
                                    _SettingsInfoChip(
                                      icon: Icons.key_rounded,
                                      label: l10n.passkey,
                                    ),
                                    _SettingsInfoChip(
                                      icon: Icons.timer_outlined,
                                      label: l10n.lockAutoByInactivity,
                                    ),
                                  ],
                                ),
                                const Divider(height: 1),
                                ListTile(
                                  leading: const Icon(Icons.fingerprint),
                                  title: Text(l10n.quickUnlockTitle),
                                  subtitle: Text(
                                    _quickEnabled ? l10n.active : l10n.inactive,
                                  ),
                                  trailing: _quickEnabled
                                      ? TextButton(
                                          onPressed: () async {
                                            await _s.disableQuickUnlock();
                                            await _refreshSecurityFlags();
                                            _snack(
                                              l10n.quickUnlockDisabledSnack,
                                            );
                                          },
                                          child: Text(l10n.remove),
                                        )
                                      : FilledButton.tonal(
                                          onPressed: () async {
                                            try {
                                              await _s
                                                  .enableDeviceQuickUnlock();
                                              await _refreshSecurityFlags();
                                              _snack(
                                                l10n.quickUnlockEnabledSnack,
                                              );
                                            } catch (e) {
                                              _snack(
                                                '${l10n.quickUnlockEnableFailed} $e',
                                              );
                                            }
                                          },
                                          child: Text(l10n.enable),
                                        ),
                                ),
                                const Divider(height: 1),
                                ListTile(
                                  leading: const Icon(Icons.key_rounded),
                                  title: Text(l10n.passkey),
                                  subtitle: Text(l10n.passkeyThisDevice),
                                  trailing: _passkeyRegistered
                                      ? TextButton(
                                          onPressed: () async {
                                            final ok = await showDialog<bool>(
                                              context: context,
                                              builder: (ctx) => AlertDialog(
                                                title: Text(
                                                  l10n.passkeyRevokeConfirmTitle,
                                                ),
                                                content: Text(
                                                  l10n.passkeyRevokeConfirmBody,
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.of(
                                                          ctx,
                                                        ).pop(false),
                                                    child: Text(
                                                      AppLocalizations.of(
                                                        ctx,
                                                      ).cancel,
                                                    ),
                                                  ),
                                                  FilledButton(
                                                    onPressed: () =>
                                                        Navigator.of(
                                                          ctx,
                                                        ).pop(true),
                                                    child: Text(
                                                      l10n.revoke,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                            if (ok != true || !mounted) return;
                                            await _s.revokePasskey();
                                            await _refreshSecurityFlags();
                                            if (!mounted) return;
                                            _snack(l10n.passkeyRevokedSnack);
                                          },
                                          child: Text(l10n.revoke),
                                        )
                                      : FilledButton.tonal(
                                          onPressed: () async {
                                            try {
                                              await _s.registerPasskey();
                                              await _refreshSecurityFlags();
                                              _snack(
                                                l10n.passkeyRegisteredSnack,
                                              );
                                            } on PasskeyAuthCancelledException {
                                              // ignorar
                                            } catch (e) {
                                              _snack('$e');
                                            }
                                          },
                                          child: Text(l10n.register),
                                        ),
                                ),
                                const Divider(height: 1),
                                ListTile(
                                  leading: const Icon(Icons.lock_outline),
                                  title: Text(l10n.lockNow),
                                  onTap: () {
                                    _s.lock();
                                    Navigator.pop(context);
                                  },
                                ),
                                const Divider(height: 1),
                                ListTile(
                                  leading: const Icon(Icons.timer_outlined),
                                  title: Text(l10n.lockAutoByInactivity),
                                  subtitle: Text(
                                    l10n.minutesShort(
                                      _app.vaultIdleLockMinutes,
                                    ),
                                  ),
                                  trailing: DropdownButton<int>(
                                    value: _app.vaultIdleLockMinutes,
                                    underline: const SizedBox.shrink(),
                                    onChanged: (value) {
                                      if (value == null) return;
                                      _app.setVaultIdleLockMinutes(value);
                                    },
                                    items: _idleOptions
                                        .map(
                                          (m) => DropdownMenuItem<int>(
                                            value: m,
                                            child: Text(l10n.minutesShort(m)),
                                          ),
                                        )
                                        .toList(),
                                  ),
                                ),
                                const Divider(height: 1),
                                SwitchListTile(
                                  secondary: const Icon(Icons.minimize_rounded),
                                  title: Text(l10n.lockOnMinimize),
                                  value: _app.vaultLockOnMinimize,
                                  onChanged: _app.setVaultLockOnMinimize,
                                ),
                                const Divider(height: 1),
                                ListTile(
                                  leading: const Icon(Icons.password_rounded),
                                  title: Text(l10n.changeMasterPassword),
                                  subtitle: Text(l10n.requiresCurrentPassword),
                                  onTap: _openChangeMasterPasswordFlow,
                                ),
                              ],
                            ),
                          )
                        else
                          _SettingsPanel(
                            key: _sectionKeys[1],
                            margin: const EdgeInsets.only(bottom: 24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _SettingsPanelHeroCard(
                                  icon: Icons.lock_open_rounded,
                                  title: _t(
                                    'Vault sin cifrar',
                                    'Unencrypted vault',
                                  ),
                                  description: l10n.plainVaultSecurityNotice,
                                  chips: [
                                    _SettingsInfoChip(
                                      icon: Icons.folder_open_outlined,
                                      label: _t(
                                        'Datos en disco',
                                        'Data on disk',
                                      ),
                                    ),
                                    _SettingsInfoChip(
                                      icon: Icons.enhanced_encryption_outlined,
                                      label: _t(
                                        'Cifrado disponible',
                                        'Encryption available',
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(height: 1),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    20,
                                    0,
                                    20,
                                    20,
                                  ),
                                  child: FilledButton.icon(
                                    onPressed: () =>
                                        _openEncryptPlainVaultDialog(),
                                    icon: const Icon(
                                      Icons.lock_rounded,
                                      size: 20,
                                    ),
                                    label: Text(l10n.encryptPlainVaultConfirm),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        if (showDesktopOnlySections) ...[
                          _SettingsPanel(
                            key: _sectionKeys[2],
                            margin: const EdgeInsets.only(bottom: 24),
                            child: Column(
                              children: [
                                _SettingsPanelHeroCard(
                                  icon: Icons.desktop_windows_rounded,
                                  title: l10n.desktopSection,
                                  description: _t(
                                    'Atajos globales, bandeja del sistema y comportamiento de la ventana en el escritorio.',
                                    'Global shortcuts, system tray, and window behavior on desktop.',
                                  ),
                                  chips: [
                                    _SettingsInfoChip(
                                      icon: Icons.search_rounded,
                                      label: l10n.globalSearchHotkey,
                                    ),
                                    _SettingsInfoChip(
                                      icon: Icons.minimize_rounded,
                                      label: l10n.minimizeToTray,
                                    ),
                                    _SettingsInfoChip(
                                      icon: Icons.close_rounded,
                                      label: l10n.closeToTray,
                                    ),
                                  ],
                                ),
                                const Divider(height: 1),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    12,
                                    16,
                                    12,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Icon(
                                            Icons.keyboard_rounded,
                                            color: scheme.onSurfaceVariant,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  l10n.globalSearchHotkey,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .titleMedium
                                                      ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  _app.enableGlobalSearchHotkey
                                                      ? l10n.hotkeyCombination
                                                      : l10n.inactive,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(
                                                        color: scheme
                                                            .onSurfaceVariant,
                                                      ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Switch(
                                            value:
                                                _app.enableGlobalSearchHotkey,
                                            onChanged: _app
                                                .setEnableGlobalSearchHotkey,
                                          ),
                                        ],
                                      ),
                                      if (_app.enableGlobalSearchHotkey) ...[
                                        const SizedBox(height: 12),
                                        Text(
                                          l10n.hotkeyCombination,
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelLarge
                                              ?.copyWith(
                                                color: scheme.onSurfaceVariant,
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                        const SizedBox(height: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                          ),
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                              color: scheme.outlineVariant,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: DropdownButton<String>(
                                            isExpanded: true,
                                            value: _app.globalSearchHotkey,
                                            underline: const SizedBox.shrink(),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            items: [
                                              DropdownMenuItem(
                                                value: 'Alt+Space',
                                                child: Text(
                                                  l10n.hotkeyAltSpace,
                                                ),
                                              ),
                                              DropdownMenuItem(
                                                value: 'Ctrl+Shift+Space',
                                                child: Text(
                                                  l10n.hotkeyCtrlShiftSpace,
                                                ),
                                              ),
                                              DropdownMenuItem(
                                                value: 'Ctrl+Shift+K',
                                                child: Text(
                                                  l10n.hotkeyCtrlShiftK,
                                                ),
                                              ),
                                              const DropdownMenuItem(
                                                value: 'Ctrl+Shift+F',
                                                child: Text('Ctrl + Shift + F'),
                                              ),
                                              const DropdownMenuItem(
                                                value: 'Ctrl+Alt+Space',
                                                child: Text(
                                                  'Ctrl + Alt + Space',
                                                ),
                                              ),
                                            ],
                                            onChanged: (value) {
                                              if (value != null) {
                                                _app.setGlobalSearchHotkey(
                                                  value,
                                                );
                                              }
                                            },
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const Divider(height: 1),
                                SwitchListTile(
                                  secondary: const Icon(
                                    Icons.minimize_outlined,
                                  ),
                                  title: Text(l10n.minimizeToTray),
                                  value: _app.minimizeToTray,
                                  onChanged: _app.setMinimizeToTray,
                                ),
                                const Divider(height: 1),
                                SwitchListTile(
                                  secondary: const Icon(Icons.close_rounded),
                                  title: Text(l10n.closeToTray),
                                  value: _app.closeToTray,
                                  onChanged: _app.setCloseToTray,
                                ),
                              ],
                            ),
                          ),

                          _SettingsPanel(
                            key: _sectionKeys[3],
                            margin: const EdgeInsets.only(bottom: 24),
                            child: Column(
                              children: [
                                _SettingsPanelHeroCard(
                                  icon: Icons.keyboard_rounded,
                                  title: l10n.keyboardShortcutsSection,
                                  description: _t(
                                    'Combinaciones solo dentro de Folio. Prueba una tecla antes de guardarla.',
                                    'Shortcuts only inside Folio. Test a key before saving it.',
                                  ),
                                  chips: [
                                    _SettingsInfoChip(
                                      icon: Icons.ads_click_rounded,
                                      label: _t('Probar', 'Test'),
                                    ),
                                    _SettingsInfoChip(
                                      icon: Icons.restart_alt_rounded,
                                      label: l10n.shortcutResetAllTitle,
                                    ),
                                  ],
                                ),
                                const Divider(height: 1),
                                for (final id in FolioInAppShortcut.values) ...[
                                  if (id != FolioInAppShortcut.values.first)
                                    const Divider(height: 1),
                                  ListTile(
                                    leading: const Icon(Icons.keyboard_rounded),
                                    title: Text(id.settingsLabel),
                                    subtitle: Text(
                                      _app.describeInAppShortcut(id),
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        TextButton(
                                          onPressed: () {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  l10n.shortcutTestHint(
                                                    _app.describeInAppShortcut(
                                                      id,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                          child: Text(l10n.shortcutTestAction),
                                        ),
                                        TextButton(
                                          onPressed: () async {
                                            final next =
                                                await showDialog<
                                                  SingleActivator
                                                >(
                                                  context: context,
                                                  builder: (ctx) =>
                                                      const InAppShortcutCaptureDialog(),
                                                );
                                            if (next != null &&
                                                context.mounted) {
                                              await _app.setInAppShortcut(
                                                id,
                                                next,
                                              );
                                            }
                                          },
                                          child: Text(
                                            l10n.shortcutChangeAction,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                const Divider(height: 1),
                                ListTile(
                                  leading: const Icon(Icons.restore_rounded),
                                  title: Text(l10n.shortcutResetAllTitle),
                                  subtitle: Text(l10n.shortcutResetAllSubtitle),
                                  onTap: () async {
                                    await _app.resetInAppShortcutsToDefaults();
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            l10n.shortcutResetDoneSnack,
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],

                        if (_app.isAiAvailable) ...[
                          _SettingsPanel(
                            key: _sectionKeys[4],
                            margin: const EdgeInsets.only(bottom: 24),
                            child: Column(
                              children: [
                                _SettingsPanelHeroCard(
                                  icon: Icons.smart_toy_outlined,
                                  title: l10n.ai,
                                  description: _app.aiProvider ==
                                          AiProvider.folioCloud
                                      ? (aiLocalProvidersSupported
                                          ? _t(
                                              'La IA se ejecuta en Folio Cloud (suscripción con IA en la nube o tinta comprada). Elige otro proveedor abajo para Ollama o LM Studio en local.',
                                              'AI runs on Folio Cloud (subscription with cloud AI or purchased ink). Pick another provider below for local Ollama or LM Studio.',
                                            )
                                          : _t(
                                              'La IA se ejecuta en Folio Cloud (suscripción con IA en la nube o tinta comprada).',
                                              'AI runs on Folio Cloud (subscription with cloud AI or purchased ink).',
                                            ))
                                      : (aiLocalProvidersSupported
                                          ? _t(
                                              'Conecta Ollama o LM Studio en local; el asistente usa el modelo y el contexto que configures aquí.',
                                              'Connect Ollama or LM Studio locally; the assistant uses the model and context you set here.',
                                            )
                                          : _t(
                                              'En este dispositivo Quill solo puede usar Folio Cloud. Elige Folio Cloud como proveedor cuando quieras activar la IA.',
                                              'On this device Quill can only use Folio Cloud. Choose Folio Cloud as the provider when you want to enable AI.',
                                            )),
                                  chips: _app.aiProvider ==
                                          AiProvider.folioCloud
                                      ? [
                                          _SettingsInfoChip(
                                            icon: Icons.cloud_outlined,
                                            label: _t('En la nube', 'Hosted'),
                                          ),
                                          _SettingsInfoChip(
                                            icon: Icons.hub_outlined,
                                            label: l10n.aiProviderLabel,
                                          ),
                                        ]
                                      : [
                                          _SettingsInfoChip(
                                            icon: Icons.hub_outlined,
                                            label: l10n.aiProviderLabel,
                                          ),
                                          if (aiLocalProvidersSupported) ...[
                                            _SettingsInfoChip(
                                              icon: Icons.psychology_outlined,
                                              label: l10n.aiModel,
                                            ),
                                            _SettingsInfoChip(
                                              icon: Icons.assistant_navigation,
                                              label: l10n.aiSetupAssistantTitle,
                                            ),
                                          ],
                                        ],
                                ),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                                  child: Builder(
                                    builder: (context) {
                                      final theme = Theme.of(context);
                                      return Container(
                                        padding: const EdgeInsets.all(14),
                                        decoration: BoxDecoration(
                                          color: scheme.surfaceContainerHighest
                                              .withValues(alpha: 0.55),
                                          borderRadius:
                                              BorderRadius.circular(18),
                                          border: Border.all(
                                            color: scheme.outlineVariant
                                                .withValues(alpha: 0.45),
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.compare_arrows_rounded,
                                                  color: scheme.primary,
                                                ),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: Text(
                                                    l10n
                                                        .aiCompareCloudVsLocalTitle,
                                                    style: theme
                                                        .textTheme.titleSmall
                                                        ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.w800,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 10),
                                            LayoutBuilder(
                                              builder: (context, constraints) {
                                                final narrow =
                                                    constraints.maxWidth < 560;
                                                Widget card({
                                                  required IconData icon,
                                                  required String title,
                                                  required List<String> bullets,
                                                }) {
                                                  return Container(
                                                    padding:
                                                        const EdgeInsets.all(12),
                                                    decoration: BoxDecoration(
                                                      color: scheme.surface
                                                          .withValues(
                                                        alpha: 0.9,
                                                      ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                        16,
                                                      ),
                                                      border: Border.all(
                                                        color: scheme
                                                            .outlineVariant
                                                            .withValues(
                                                          alpha: 0.35,
                                                        ),
                                                      ),
                                                    ),
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .stretch,
                                                      children: [
                                                        Row(
                                                          children: [
                                                            Icon(
                                                              icon,
                                                              color:
                                                                  scheme.primary,
                                                            ),
                                                            const SizedBox(
                                                              width: 8,
                                                            ),
                                                            Expanded(
                                                              child: Text(
                                                                title,
                                                                style: theme
                                                                    .textTheme
                                                                    .labelLarge
                                                                    ?.copyWith(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w800,
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                        const SizedBox(
                                                          height: 8,
                                                        ),
                                                        ...bullets.map(
                                                          (b) => Padding(
                                                            padding:
                                                                const EdgeInsets
                                                                    .only(
                                                              bottom: 4,
                                                            ),
                                                            child: Text(
                                                              '• $b',
                                                              style: theme
                                                                  .textTheme
                                                                  .bodySmall
                                                                  ?.copyWith(
                                                                color: scheme
                                                                    .onSurfaceVariant,
                                                                height: 1.35,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                }

                                                final cloudCard = card(
                                                  icon: Icons.cloud_outlined,
                                                  title: l10n.aiCompareCloudTitle,
                                                  bullets: [
                                                    l10n
                                                        .aiCompareCloudBulletNoSetup,
                                                    l10n
                                                        .aiCompareCloudBulletNeedsSub,
                                                    l10n.aiCompareCloudBulletInk,
                                                  ],
                                                );
                                                final localCard = card(
                                                  icon: Icons.computer_outlined,
                                                  title: l10n.aiCompareLocalTitle,
                                                  bullets: [
                                                    l10n
                                                        .aiCompareLocalBulletPrivacy,
                                                    l10n.aiCompareLocalBulletNoInk,
                                                    l10n.aiCompareLocalBulletSetup,
                                                  ],
                                                );

                                                if (!aiLocalProvidersSupported) {
                                                  return cloudCard;
                                                }
                                                if (narrow) {
                                                  return Column(
                                                    children: [
                                                      cloudCard,
                                                      const SizedBox(height: 10),
                                                      localCard,
                                                    ],
                                                  );
                                                }
                                                return Row(
                                                  children: [
                                                    Expanded(child: cloudCard),
                                                    const SizedBox(width: 10),
                                                    Expanded(child: localCard),
                                                  ],
                                                );
                                              },
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                const Divider(height: 1),
                                SwitchListTile(
                                  secondary: const Icon(
                                    Icons.smart_toy_outlined,
                                  ),
                                  title: Text(l10n.aiEnableToggleTitle),
                                  subtitle: Text(
                                    _app.aiEnabled
                                        ? l10n.active
                                        : l10n.inactive,
                                  ),
                                  value: _app.aiEnabled,
                                  onChanged: _detectingAiProvider
                                      ? null
                                      : (v) async {
                                          if (v && !_app.aiEnabled) {
                                            final confirmed =
                                                await _confirmAiBetaEnable();
                                            if (!confirmed) return;
                                            final acceptedScope =
                                                await _confirmQuillGlobalScopeIfNeeded();
                                            if (!acceptedScope) return;
                                            if (!_app.hasCompletedQuillSetup) {
                                              if (aiLocalProvidersSupported) {
                                                final configured =
                                                    await _autoDetectAndConfigureAiProvider();
                                                if (!configured) return;
                                              }
                                              await _app
                                                  .setHasCompletedQuillSetup(
                                                    true,
                                                  );
                                            }
                                            await _saveAiFields();
                                            await _app.setAiEnabled(true);
                                            return;
                                          }
                                          await _saveAiFields();
                                          await _app.setAiEnabled(v);
                                        },
                                ),
                                if (_detectingAiProvider)
                                  const Padding(
                                    padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                                    child: LinearProgressIndicator(),
                                  ),
                                if (aiLocalProvidersSupported &&
                                    _app.aiProvider !=
                                        AiProvider.folioCloud) ...[
                                  const Divider(height: 1),
                                  ListTile(
                                    leading: const Icon(
                                      Icons.assistant_navigation,
                                    ),
                                    title: Text(l10n.aiSetupAssistantTitle),
                                    subtitle:
                                        Text(l10n.aiSetupAssistantSubtitle),
                                    trailing: const Icon(
                                      Icons.chevron_right_rounded,
                                    ),
                                    onTap: _detectingAiProvider
                                        ? null
                                        : _autoDetectAndConfigureAiProvider,
                                  ),
                                ],
                                const Divider(height: 1),
                                SwitchListTile(
                                  secondary: const Icon(
                                    Icons.psychology_outlined,
                                  ),
                                  title: Text(l10n.aiAlwaysShowThought),
                                  subtitle: Text(l10n.aiAlwaysShowThoughtHint),
                                  value: _app.aiAlwaysShowThought,
                                  onChanged: _app.aiEnabled
                                      ? _app.setAiAlwaysShowThought
                                      : null,
                                ),
                                if (aiLocalProvidersSupported &&
                                    _app.aiProvider !=
                                        AiProvider.folioCloud) ...[
                                  const Divider(height: 1),
                                  SwitchListTile(
                                    secondary: const Icon(
                                      Icons.rocket_launch_outlined,
                                    ),
                                    title: Text(l10n.aiLaunchProviderWithApp),
                                    subtitle: Text(
                                      l10n.aiLaunchProviderWithAppHint,
                                    ),
                                    value: _app.aiLaunchProviderWithApp,
                                    onChanged: _app.aiEnabled
                                        ? (v) async {
                                            await _app
                                                .setAiLaunchProviderWithApp(
                                                  v,
                                                );
                                          }
                                        : null,
                                  ),
                                  const Divider(height: 1),
                                  ListTile(
                                    leading: const Icon(Icons.memory_outlined),
                                    title: Text(l10n.aiContextWindowTokens),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          l10n.aiContextWindowTokensHint,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color:
                                                    scheme.onSurfaceVariant,
                                              ),
                                        ),
                                        TextField(
                                          controller:
                                              _aiContextWindowController,
                                          enabled: _app.aiEnabled,
                                          keyboardType: TextInputType.number,
                                          decoration: const InputDecoration(
                                            hintText: '131072',
                                            border: InputBorder.none,
                                            enabledBorder: InputBorder.none,
                                            focusedBorder: InputBorder.none,
                                            contentPadding: EdgeInsets.zero,
                                          ),
                                          onSubmitted: (_) => _saveAiFields(),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                const Divider(height: 1),
                                ListTile(
                                  leading: const Icon(Icons.hub_outlined),
                                  title: Text(l10n.aiProviderLabel),
                                  trailing: DropdownButton<AiProvider>(
                                    value: _app.aiProvider,
                                    underline: const SizedBox.shrink(),
                                    onChanged: (value) async {
                                      if (value == null) return;
                                      if (value == AiProvider.folioCloud) {
                                        if (!_folio.isAvailable) {
                                          _snack(
                                            _t(
                                              'Firebase no está disponible en esta compilación.',
                                              'Firebase is not available in this build.',
                                            ),
                                          );
                                          return;
                                        }
                                        if (!_cloud.isSignedIn) {
                                          _snack(
                                            _t(
                                              'Inicia sesión en la cuenta en la nube (Ajustes).',
                                              'Sign in to your cloud account (Settings).',
                                            ),
                                          );
                                          return;
                                        }
                                        if (!_folio.snapshot.canUseCloudAi) {
                                          _snack(l10n.aiProviderFolioCloudBlockedSnack);
                                          return;
                                        }
                                      }
                                      try {
                                        await _app.setAiProvider(value);
                                        if (!mounted) return;
                                        setState(() {
                                          _availableModels = _app
                                              .cachedAiModelsFor(value);
                                        });
                                        if (_availableModels.isNotEmpty &&
                                            !_availableModels.contains(
                                              _app.aiModel,
                                            )) {
                                          await _app.setAiModel(
                                            _availableModels.first,
                                          );
                                        }
                                        _aiBaseUrlController.text = _app
                                            .defaultUrlForProvider(value);
                                        await _saveAiFields();
                                        if (value == AiProvider.folioCloud) {
                                          await _loadAiModels();
                                        }
                                      } catch (e) {
                                        if (!mounted) return;
                                        _snack(
                                          'Error al cambiar proveedor: $e',
                                        );
                                      }
                                    },
                                    items: [
                                      DropdownMenuItem(
                                        value: AiProvider.none,
                                        child: Text(l10n.aiProviderNone),
                                      ),
                                      if (aiLocalProvidersSupported) ...[
                                        DropdownMenuItem(
                                          value: AiProvider.ollama,
                                          child: Text('Ollama'),
                                        ),
                                        DropdownMenuItem(
                                          value: AiProvider.lmStudio,
                                          child: Text('LM Studio'),
                                        ),
                                      ],
                                      DropdownMenuItem(
                                        value: AiProvider.folioCloud,
                                        child: const Text('Folio Cloud'),
                                      ),
                                    ],
                                  ),
                                ),
                                if (aiLocalProvidersSupported &&
                                    _app.aiProvider !=
                                        AiProvider.folioCloud) ...[
                                  const Divider(height: 1),
                                  ListTile(
                                    leading: const Icon(Icons.link_rounded),
                                    title: Text(l10n.aiEndpoint),
                                    subtitle: TextField(
                                      controller: _aiBaseUrlController,
                                      decoration: const InputDecoration(
                                        hintText: 'http://127.0.0.1:11434',
                                        border: InputBorder.none,
                                        enabledBorder: InputBorder.none,
                                        focusedBorder: InputBorder.none,
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                      onSubmitted: (_) => _saveAiFields(),
                                    ),
                                  ),
                                  const Divider(height: 1),
                                  ListTile(
                                    leading: const Icon(
                                      Icons.psychology_alt_outlined,
                                    ),
                                    title: Text(l10n.aiModel),
                                    subtitle: _loadingModels
                                        ? const Padding(
                                            padding: EdgeInsets.symmetric(
                                              vertical: 8,
                                            ),
                                            child: LinearProgressIndicator(),
                                          )
                                        : DropdownButton<String>(
                                            value:
                                                _availableModels.contains(
                                                  _app.aiModel,
                                                )
                                                ? _app.aiModel
                                                : null,
                                            hint: Text(
                                              l10n.aiConnectToListModels,
                                            ),
                                            isExpanded: true,
                                            underline:
                                                const SizedBox.shrink(),
                                            onChanged:
                                                _availableModels.isEmpty
                                                ? null
                                                : (value) {
                                                    if (value != null) {
                                                      _app.setAiModel(value);
                                                    }
                                                  },
                                            items: _availableModels
                                                .map(
                                                  (m) =>
                                                      DropdownMenuItem<String>(
                                                    value: m,
                                                    child: Text(m),
                                                  ),
                                                )
                                                .toList(),
                                          ),
                                  ),
                                  const Divider(height: 1),
                                  ListTile(
                                    leading: const Icon(Icons.timer_outlined),
                                    title: Text(l10n.aiTimeoutMs),
                                    subtitle: TextField(
                                      controller: _aiTimeoutController,
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(
                                        hintText: '30000',
                                        border: InputBorder.none,
                                        enabledBorder: InputBorder.none,
                                        focusedBorder: InputBorder.none,
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                      onSubmitted: (_) => _saveAiFields(),
                                    ),
                                  ),
                                  const Divider(height: 1),
                                  SwitchListTile(
                                    secondary:
                                        const Icon(Icons.public_outlined),
                                    title: Text(l10n.aiAllowRemoteEndpoint),
                                    subtitle: Text(
                                      _app.aiEndpointMode ==
                                              AiEndpointMode.allowRemote
                                          ? l10n.aiAllowRemoteEndpointAllowed
                                          : l10n
                                                .aiAllowRemoteEndpointLocalhostOnly,
                                    ),
                                    value:
                                        _app.aiEndpointMode ==
                                        AiEndpointMode.allowRemote,
                                    onChanged: (v) async {
                                      await _app.setAiEndpointMode(
                                        v
                                            ? AiEndpointMode.allowRemote
                                            : AiEndpointMode.localhostOnly,
                                      );
                                      if (v) {
                                        await _confirmRemoteEndpointIfNeeded();
                                      }
                                    },
                                  ),
                                  if (_app.aiEndpointMode ==
                                          AiEndpointMode.allowRemote &&
                                      !_app.aiRemoteEndpointConfirmed)
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        16,
                                        0,
                                        16,
                                        16,
                                      ),
                                      child: Text(
                                        l10n.aiAllowRemoteEndpointNotConfirmed,
                                        style: TextStyle(color: Colors.orange),
                                      ),
                                    ),
                                  const Divider(height: 1),
                                  ListTile(
                                    leading: const Icon(
                                      Icons.network_check_rounded,
                                    ),
                                    title: Text(l10n.aiConnectToListModels),
                                    onTap: _testAiConnection,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],

                        _SettingsPanel(
                          key: _sectionKeys[5],
                          margin: const EdgeInsets.only(bottom: 24),
                          child: Column(
                            children: [
                              _SettingsPanelHeroCard(
                                icon: Icons.backup_outlined,
                                title: l10n.vaultBackup,
                                description: l10n.backupInfoBody,
                                chips: [
                                  _SettingsInfoChip(
                                    icon: Icons.file_download_outlined,
                                    label: l10n.exportZipTitle,
                                  ),
                                  _SettingsInfoChip(
                                    icon: Icons.file_upload_outlined,
                                    label: l10n.importZipTitle,
                                  ),
                                  _SettingsInfoChip(
                                    icon: Icons.note_add_outlined,
                                    label: l10n.importNotionTitle,
                                  ),
                                ],
                              ),
                              const Divider(height: 1),
                              if (_s.state == VaultFlowState.unlocked)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    12,
                                    16,
                                    4,
                                  ),
                                  child: FutureBuilder<String>(
                                    key: ValueKey(_s.activeVaultId),
                                    future: _s.getActiveVaultDisplayLabel(),
                                    builder: (ctx, snap) {
                                      if (!snap.hasData) {
                                        return const SizedBox.shrink();
                                      }
                                      return Text(
                                        l10n.vaultBackupOpenVaultHint(
                                          snap.data!,
                                        ),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: scheme.onSurfaceVariant,
                                              height: 1.35,
                                            ),
                                      );
                                    },
                                  ),
                                ),
                              ListTile(
                                leading: const Icon(
                                  Icons.file_download_outlined,
                                ),
                                title: Text(l10n.exportZipTitle),
                                subtitle: Text(l10n.exportZipSubtitle),
                                onTap: _s.state == VaultFlowState.unlocked
                                    ? _openExportBackupFlow
                                    : null,
                              ),
                              const Divider(height: 1),
                              ListTile(
                                leading: const Icon(Icons.file_upload_outlined),
                                title: Text(l10n.importZipTitle),
                                subtitle: Text(l10n.importZipSubtitle),
                                onTap: _s.state == VaultFlowState.unlocked
                                    ? _openImportBackupFlow
                                    : null,
                              ),
                              const Divider(height: 1),
                              ListTile(
                                leading: const Icon(Icons.note_add_outlined),
                                title: Text(l10n.importNotionTitle),
                                subtitle: Text(l10n.importNotionSubtitle),
                                onTap: _s.state == VaultFlowState.unlocked
                                    ? _openImportNotionFlow
                                    : null,
                              ),
                              const Divider(height: 1),
                              SwitchListTile(
                                secondary: const Icon(Icons.schedule_rounded),
                                title: Text(l10n.scheduledVaultBackupTitle),
                                subtitle: Text(
                                  l10n.scheduledVaultBackupSubtitle,
                                ),
                                value: _app.scheduledVaultBackupEnabled,
                                onChanged: _s.state == VaultFlowState.unlocked
                                    ? (v) async {
                                        await _app
                                            .setScheduledVaultBackupEnabled(v);
                                        if (mounted) setState(() {});
                                      }
                                    : null,
                              ),
                              if (_app.scheduledVaultBackupEnabled) ...[
                                ListTile(
                                  leading: const Icon(Icons.timer_outlined),
                                  title: Text(
                                    l10n.scheduledVaultBackupIntervalLabel,
                                  ),
                                  trailing: DropdownButton<int>(
                                    value: _app
                                        .scheduledVaultBackupIntervalHours
                                        .clamp(1, 168),
                                    items: const [
                                      DropdownMenuItem(
                                        value: 6,
                                        child: Text('6 h'),
                                      ),
                                      DropdownMenuItem(
                                        value: 12,
                                        child: Text('12 h'),
                                      ),
                                      DropdownMenuItem(
                                        value: 24,
                                        child: Text('24 h'),
                                      ),
                                      DropdownMenuItem(
                                        value: 48,
                                        child: Text('48 h'),
                                      ),
                                      DropdownMenuItem(
                                        value: 168,
                                        child: Text('7 d'),
                                      ),
                                    ],
                                    onChanged:
                                        _s.state == VaultFlowState.unlocked
                                        ? (v) async {
                                            if (v == null) return;
                                            await _app
                                                .setScheduledVaultBackupIntervalHours(
                                                  v,
                                                );
                                            if (mounted) setState(() {});
                                          }
                                        : null,
                                  ),
                                ),
                                ListTile(
                                  leading: const Icon(
                                    Icons.folder_open_outlined,
                                  ),
                                  title: Text(
                                    l10n.scheduledVaultBackupChooseFolder,
                                  ),
                                  subtitle: Text(
                                    _app.scheduledVaultBackupDirectory.isEmpty
                                        ? '—'
                                        : _app.scheduledVaultBackupDirectory,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  onTap: _s.state == VaultFlowState.unlocked
                                      ? _pickScheduledVaultBackupFolder
                                      : null,
                                ),
                                ListTile(
                                  leading: const Icon(Icons.history_rounded),
                                  title: Text(
                                    l10n.scheduledVaultBackupLastRun(
                                      _formatScheduledBackupTime(
                                        _app.lastScheduledVaultBackupMs,
                                      ),
                                    ),
                                  ),
                                ),
                                if (_folio.isAvailable && _cloud.isSignedIn)
                                  SwitchListTile(
                                    secondary: const Icon(
                                      Icons.cloud_upload_outlined,
                                    ),
                                    title: Text(
                                      l10n.scheduledVaultBackupCloudSyncTitle,
                                    ),
                                    subtitle: Text(
                                      l10n.scheduledVaultBackupCloudSyncSubtitle,
                                    ),
                                    value: _app
                                        .scheduledVaultBackupAlsoUploadCloud,
                                    onChanged:
                                        _s.state == VaultFlowState.unlocked
                                        ? (v) async {
                                            await _app
                                                .setScheduledVaultBackupAlsoUploadCloud(
                                                  v,
                                                );
                                            if (mounted) setState(() {});
                                          }
                                        : null,
                                  ),
                              ],
                              ListTile(
                                leading: const Icon(Icons.save_alt_rounded),
                                title: Text(l10n.vaultBackupRunNowTile),
                                subtitle: Text(l10n.vaultBackupRunNowSubtitle),
                                onTap: _s.state == VaultFlowState.unlocked
                                    ? _runBackupNowToScheduledFolder
                                    : null,
                              ),
                              const Divider(height: 1),
                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      l10n.notionExportGuideTitle,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      l10n.notionExportGuideBody,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: scheme.onSurfaceVariant,
                                            height: 1.4,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        if (showDesktopOnlySections) ...[
                          _SettingsPanel(
                            key: _sectionKeys[6],
                            margin: const EdgeInsets.only(bottom: 24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _IntegrationsHero(
                                  approvedCount: _app
                                      .approvedIntegrationAppApprovals
                                      .length,
                                  hintText: l10n.integrationsAppsApprovedHint,
                                  title: l10n.integrations,
                                  featureChips: [
                                    _SettingsInfoChip(
                                      icon: Icons.verified_user_outlined,
                                      label: _t(
                                        'Permisos aprobados',
                                        'Approved permissions',
                                      ),
                                    ),
                                    _SettingsInfoChip(
                                      icon: Icons.lock_open_outlined,
                                      label: _t(
                                        'Acceso revocable',
                                        'Revocable access',
                                      ),
                                    ),
                                    _SettingsInfoChip(
                                      icon: Icons.devices_outlined,
                                      label: _t(
                                        'Apps externas',
                                        'External apps',
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(height: 1),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    0,
                                    16,
                                    16,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            _t(
                                              'Conexiones activas',
                                              'Active connections',
                                            ),
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleSmall
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            _t(
                                              'Apps que ya pueden interactuar con Folio',
                                              'Apps already allowed to interact with Folio',
                                            ),
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  color:
                                                      scheme.onSurfaceVariant,
                                                ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      if (_app
                                          .approvedIntegrationAppApprovals
                                          .isEmpty)
                                        Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.all(18),
                                          decoration: BoxDecoration(
                                            color: scheme.surfaceContainerLow,
                                            borderRadius: BorderRadius.circular(
                                              18,
                                            ),
                                            border: Border.all(
                                              color: scheme.outlineVariant
                                                  .withValues(alpha: 0.45),
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Container(
                                                width: 44,
                                                height: 44,
                                                decoration: BoxDecoration(
                                                  color: scheme.surface,
                                                  borderRadius:
                                                      BorderRadius.circular(14),
                                                ),
                                                child: Icon(
                                                  Icons.hub_outlined,
                                                  color:
                                                      scheme.onSurfaceVariant,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Text(
                                                  l10n.integrationsAppsApprovedNone,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(
                                                        color: scheme
                                                            .onSurfaceVariant,
                                                        height: 1.35,
                                                      ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        )
                                      else
                                        Wrap(
                                          spacing: 12,
                                          runSpacing: 12,
                                          children: _app
                                              .approvedIntegrationAppApprovals
                                              .map(
                                                (entry) => _IntegrationAppCard(
                                                  entry: entry,
                                                  detailsText: l10n.integrationsApprovedAppDetails(
                                                    entry.appId,
                                                    entry.appVersion.isEmpty
                                                        ? l10n.integrationApprovalUnknownVersion
                                                        : entry.appVersion,
                                                    entry
                                                            .integrationVersion
                                                            .isEmpty
                                                        ? l10n.integrationApprovalUnknownVersion
                                                        : entry
                                                              .integrationVersion,
                                                  ),
                                                  revokeLabel: l10n
                                                      .integrationsAppsApprovedRevoke,
                                                  onRevoke: () =>
                                                      _revokeIntegrationApp(
                                                        entry.appId,
                                                      ),
                                                ),
                                              )
                                              .toList(),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        _SettingsPanel(
                          key: _sectionKeys[7],
                          margin: const EdgeInsets.only(bottom: 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _SettingsPanelHeroCard(
                                icon: Icons.cloud_circle_outlined,
                                title: l10n.cloudAccountSectionTitle,
                                description:
                                    l10n.cloudAccountSectionDescription,
                                chips: [
                                  _SettingsInfoChip(
                                    icon: Icons.lock_outline_rounded,
                                    label: l10n.cloudAccountChipOptional,
                                  ),
                                  _SettingsInfoChip(
                                    icon: Icons.payments_outlined,
                                    label: l10n.cloudAccountChipPaidCloud,
                                  ),
                                ],
                              ),
                              const Divider(height: 1),
                              ListenableBuilder(
                                listenable: _cloud,
                                builder: (context, _) {
                                  if (!_cloud.isAvailable) {
                                    return Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        16,
                                        8,
                                        16,
                                        20,
                                      ),
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          color: scheme.errorContainer
                                              .withValues(alpha: 0.22),
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          border: Border.all(
                                            color: scheme.outlineVariant
                                                .withValues(alpha: 0.45),
                                          ),
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Icon(
                                                Icons.cloud_off_rounded,
                                                color: scheme.error,
                                                size: 26,
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Text(
                                                  l10n.cloudAccountUnavailable,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodyMedium
                                                      ?.copyWith(
                                                        height: 1.4,
                                                        color: scheme
                                                            .onSurfaceVariant,
                                                      ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  }
                                  if (_cloud.isSignedIn) {
                                    final u = _cloud.user!;
                                    final email =
                                        u.email?.trim().isNotEmpty == true
                                        ? u.email!.trim()
                                        : '—';
                                    final initial =
                                        email.isNotEmpty && email != '—'
                                        ? email[0].toUpperCase()
                                        : '?';
                                    return Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        16,
                                        4,
                                        16,
                                        20,
                                      ),
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [
                                              scheme.primaryContainer
                                                  .withValues(alpha: 0.35),
                                              scheme.surfaceContainerHighest,
                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            18,
                                          ),
                                          border: Border.all(
                                            color: scheme.outlineVariant
                                                .withValues(alpha: 0.4),
                                          ),
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.all(18),
                                          child: Semantics(
                                            container: true,
                                            label: l10n.cloudAccountSignedInAs(
                                              email,
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.stretch,
                                              children: [
                                                Row(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    CircleAvatar(
                                                      radius: 26,
                                                      backgroundColor: scheme
                                                          .primary
                                                          .withValues(
                                                            alpha: 0.18,
                                                          ),
                                                      child: Text(
                                                        initial,
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .titleLarge
                                                            ?.copyWith(
                                                              color: scheme
                                                                  .primary,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w700,
                                                            ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 14),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Row(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: [
                                                              Expanded(
                                                                child: Text(
                                                                  email,
                                                                  style: Theme.of(
                                                                    context,
                                                                  )
                                                                      .textTheme
                                                                      .titleSmall
                                                                      ?.copyWith(
                                                                        fontWeight:
                                                                            FontWeight
                                                                                .w700,
                                                                      ),
                                                                ),
                                                              ),
                                                              if (email != '—')
                                                                IconButton(
                                                                  tooltip: l10n
                                                                      .cloudAccountCopyEmail,
                                                                  onPressed:
                                                                      () async {
                                                                    await Clipboard.setData(
                                                                      ClipboardData(
                                                                        text:
                                                                            email,
                                                                      ),
                                                                    );
                                                                    if (!context
                                                                        .mounted) {
                                                                      return;
                                                                    }
                                                                    ScaffoldMessenger.of(
                                                                      context,
                                                                    ).showSnackBar(
                                                                      SnackBar(
                                                                        content:
                                                                            Text(
                                                                          l10n.cloudAccountEmailCopied,
                                                                        ),
                                                                      ),
                                                                    );
                                                                  },
                                                                  icon: const Icon(
                                                                    Icons
                                                                        .content_copy_rounded,
                                                                    size: 20,
                                                                  ),
                                                                ),
                                                            ],
                                                          ),
                                                          if (u.emailVerified)
                                                            Padding(
                                                              padding:
                                                                  const EdgeInsets.only(
                                                                    top: 6,
                                                                  ),
                                                              child: Row(
                                                                mainAxisSize:
                                                                    MainAxisSize
                                                                        .min,
                                                                children: [
                                                                  Icon(
                                                                    Icons
                                                                        .verified_rounded,
                                                                    size: 16,
                                                                    color: scheme
                                                                        .primary,
                                                                  ),
                                                                  const SizedBox(
                                                                    width: 4,
                                                                  ),
                                                                  Text(
                                                                    l10n.cloudAccountEmailVerified,
                                                                    style: Theme.of(context)
                                                                        .textTheme
                                                                        .labelSmall
                                                                        ?.copyWith(
                                                                          color:
                                                                              scheme.primary,
                                                                          fontWeight:
                                                                              FontWeight.w600,
                                                                        ),
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                          const SizedBox(
                                                            height: 6,
                                                          ),
                                                          SelectableText(
                                                            l10n.cloudAccountUid(
                                                              _shortCloudUid(
                                                                u.uid,
                                                              ),
                                                            ),
                                                            style: Theme.of(context)
                                                                .textTheme
                                                                .bodySmall
                                                                ?.copyWith(
                                                                  fontFamily:
                                                                      'monospace',
                                                                  color: scheme
                                                                      .onSurfaceVariant,
                                                                ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                if (u.email != null &&
                                                    u.email!
                                                        .trim()
                                                        .isNotEmpty &&
                                                    !u.emailVerified) ...[
                                                  const SizedBox(height: 12),
                                                  DecoratedBox(
                                                    decoration: BoxDecoration(
                                                      color: scheme
                                                          .errorContainer
                                                          .withValues(
                                                            alpha: 0.35,
                                                          ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            14,
                                                          ),
                                                      border: Border.all(
                                                        color: scheme
                                                            .outlineVariant
                                                            .withValues(
                                                              alpha: 0.45,
                                                            ),
                                                      ),
                                                    ),
                                                    child: Padding(
                                                      padding:
                                                          const EdgeInsets.all(
                                                            14,
                                                          ),
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .stretch,
                                                        children: [
                                                          Text(
                                                            l10n.cloudAccountEmailUnverifiedBanner,
                                                            style: Theme.of(
                                                              context,
                                                            )
                                                                .textTheme
                                                                .bodySmall
                                                                ?.copyWith(
                                                                  color: scheme
                                                                      .onSurfaceVariant,
                                                                  height: 1.35,
                                                                ),
                                                          ),
                                                          const SizedBox(
                                                            height: 10,
                                                          ),
                                                          Wrap(
                                                            spacing: 8,
                                                            runSpacing: 8,
                                                            children: [
                                                              OutlinedButton(
                                                                onPressed: () {
                                                                  unawaited(
                                                                    _sendCloudEmailVerification(),
                                                                  );
                                                                },
                                                                child: Text(
                                                                  l10n.cloudAccountResendVerification,
                                                                ),
                                                              ),
                                                              TextButton(
                                                                onPressed: () {
                                                                  unawaited(
                                                                    _reloadCloudUserVerificationStatus(),
                                                                  );
                                                                },
                                                                child: Text(
                                                                  l10n.cloudAccountReloadVerification,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                                const SizedBox(height: 14),
                                                Text(
                                                  l10n.cloudAccountSignOutHelp,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(
                                                        color: scheme
                                                            .onSurfaceVariant,
                                                        height: 1.35,
                                                      ),
                                                ),
                                                if (email != '—') ...[
                                                  const SizedBox(height: 10),
                                                  Align(
                                                    alignment:
                                                        Alignment.centerLeft,
                                                    child: TextButton.icon(
                                                      onPressed: () {
                                                        unawaited(
                                                          _showCloudPasswordResetDialog(
                                                            fixedEmail: email,
                                                          ),
                                                        );
                                                      },
                                                      icon: const Icon(
                                                        Icons
                                                            .lock_reset_rounded,
                                                        size: 20,
                                                      ),
                                                      label: Text(
                                                        l10n.cloudAccountResetPasswordEmail,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                                const SizedBox(height: 14),
                                                OutlinedButton.icon(
                                                  onPressed: () async {
                                                    try {
                                                      await _cloud.signOut();
                                                      if (!context.mounted) {
                                                        return;
                                                      }
                                                      ScaffoldMessenger.of(
                                                        context,
                                                      ).showSnackBar(
                                                        SnackBar(
                                                          content: Text(
                                                            _t(
                                                              'Sesión cerrada',
                                                              'Signed out',
                                                            ),
                                                          ),
                                                        ),
                                                      );
                                                    } catch (e) {
                                                      if (!context.mounted) {
                                                        return;
                                                      }
                                                      ScaffoldMessenger.of(
                                                        context,
                                                      ).showSnackBar(
                                                        SnackBar(
                                                          content: Text('$e'),
                                                        ),
                                                      );
                                                    }
                                                  },
                                                  icon: const Icon(
                                                    Icons.logout_rounded,
                                                    size: 20,
                                                  ),
                                                  label: Text(
                                                    l10n.cloudAccountSignOut,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  }
                                  return Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      4,
                                      16,
                                      20,
                                    ),
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        color: scheme.surfaceContainerLow,
                                        borderRadius: BorderRadius.circular(18),
                                        border: Border.all(
                                          color: scheme.outlineVariant
                                              .withValues(alpha: 0.4),
                                        ),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(18),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            Text(
                                              l10n.cloudAccountSignedOutPrompt,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodyMedium
                                                  ?.copyWith(
                                                    height: 1.4,
                                                    color:
                                                        scheme.onSurfaceVariant,
                                                  ),
                                            ),
                                            const SizedBox(height: 18),
                                            LayoutBuilder(
                                              builder: (context, constraints) {
                                                final narrow =
                                                    constraints.maxWidth < 420;
                                                final signInBtn = FilledButton(
                                                  onPressed: () =>
                                                      _showCloudAuthDialog(
                                                        register: false,
                                                      ),
                                                  child: Text(
                                                    l10n.cloudAccountSignIn,
                                                  ),
                                                );
                                                final registerBtn = OutlinedButton(
                                                  onPressed: () =>
                                                      _showCloudAuthDialog(
                                                        register: true,
                                                      ),
                                                  child: Text(
                                                    l10n.cloudAccountCreateAccount,
                                                  ),
                                                );
                                                if (narrow) {
                                                  return Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .stretch,
                                                    children: [
                                                      signInBtn,
                                                      const SizedBox(
                                                        height: 10,
                                                      ),
                                                      registerBtn,
                                                    ],
                                                  );
                                                }
                                                return Row(
                                                  children: [
                                                    Expanded(child: signInBtn),
                                                    const SizedBox(width: 12),
                                                    Expanded(
                                                      child: registerBtn,
                                                    ),
                                                  ],
                                                );
                                              },
                                            ),
                                            const SizedBox(height: 8),
                                            Center(
                                              child: TextButton.icon(
                                                onPressed:
                                                    _showCloudPasswordResetDialog,
                                                icon: const Icon(
                                                  Icons.mail_outline_rounded,
                                                  size: 20,
                                                ),
                                                label: Text(
                                                  l10n.cloudAccountForgotPassword,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                              ListenableBuilder(
                                listenable: Listenable.merge([
                                  _cloud,
                                  _folio,
                                ]),
                                builder: (context, _) {
                                  if (!AppSettings.folioWebPortalLinkEnabled) {
                                    return const SizedBox.shrink();
                                  }
                                  if (!_folio.isAvailable ||
                                      !_cloud.isSignedIn) {
                                    return const SizedBox.shrink();
                                  }
                                  final panelScheme =
                                      Theme.of(context).colorScheme;
                                  final panelL10n =
                                      AppLocalizations.of(context);
                                  final webSnap = _folio.webPortalEntitlement;
                                  return Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      8,
                                      16,
                                      8,
                                    ),
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        color:
                                            panelScheme.surfaceContainerLow,
                                        borderRadius: BorderRadius.circular(18),
                                        border: Border.all(
                                          color: panelScheme.outlineVariant
                                              .withValues(alpha: 0.4),
                                        ),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(18),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            Text(
                                              panelL10n
                                                  .folioWebPortalSubsectionTitle,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleSmall
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              panelL10n.folioWebMirrorNote,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.copyWith(
                                                    color: panelScheme
                                                        .onSurfaceVariant,
                                                    height: 1.35,
                                                  ),
                                            ),
                                            const SizedBox(height: 14),
                                            Text(
                                              panelL10n.folioWebPortalLinkHelp,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.copyWith(
                                                    color: panelScheme
                                                        .onSurfaceVariant,
                                                    height: 1.35,
                                                  ),
                                            ),
                                            const SizedBox(height: 10),
                                            TextField(
                                              controller: _webLinkCodeController,
                                              decoration: InputDecoration(
                                                labelText: panelL10n
                                                    .folioWebPortalLinkCodeLabel,
                                                border:
                                                    const OutlineInputBorder(),
                                              ),
                                              textCapitalization:
                                                  TextCapitalization.characters,
                                              autocorrect: false,
                                              enabled: !_webLinkBusy,
                                            ),
                                            const SizedBox(height: 12),
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: FilledButton(
                                                    onPressed: _webLinkBusy
                                                        ? null
                                                        : _linkFolioWebPortalAccount,
                                                    child: _webLinkBusy
                                                        ? const SizedBox(
                                                            height: 22,
                                                            width: 22,
                                                            child:
                                                                CircularProgressIndicator(
                                                              strokeWidth: 2,
                                                            ),
                                                          )
                                                        : Text(
                                                            panelL10n
                                                                .folioWebPortalLinkButton,
                                                          ),
                                                  ),
                                                ),
                                                IconButton(
                                                  tooltip: panelL10n
                                                      .folioWebPortalRefreshWeb,
                                                  onPressed:
                                                      _refreshFolioWebPortalEntitlement,
                                                  icon: const Icon(
                                                    Icons.refresh_rounded,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            if (_folio.webPortalRefreshError !=
                                                null) ...[
                                              const SizedBox(height: 10),
                                              Text(
                                                _l10nFolioWebPortalError(
                                                  panelL10n,
                                                  _folio.webPortalRefreshError!,
                                                ),
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodySmall
                                                    ?.copyWith(
                                                      color:
                                                          panelScheme.error,
                                                    ),
                                              ),
                                            ],
                                            if (webSnap != null) ...[
                                              const SizedBox(height: 14),
                                              Text(
                                                webSnap.linked
                                                    ? panelL10n
                                                        .folioWebEntitlementLinked
                                                    : panelL10n
                                                        .folioWebEntitlementNotLinked,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodyMedium
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                              ),
                                              if (webSnap.folioCloud !=
                                                  null) ...[
                                                const SizedBox(height: 6),
                                                Text(
                                                  panelL10n
                                                      .folioWebEntitlementWebPlan(
                                                    webSnap.folioCloud!
                                                        ? _t('Sí', 'Yes')
                                                        : _t('No', 'No'),
                                                  ),
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(
                                                        color: panelScheme
                                                            .onSurfaceVariant,
                                                      ),
                                                ),
                                              ],
                                              if (webSnap.folioCloudStatus !=
                                                      null &&
                                                  webSnap
                                                      .folioCloudStatus!
                                                      .isNotEmpty) ...[
                                                const SizedBox(height: 4),
                                                Text(
                                                  panelL10n
                                                      .folioWebEntitlementWebStatus(
                                                    webSnap.folioCloudStatus!,
                                                  ),
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(
                                                        color: panelScheme
                                                            .onSurfaceVariant,
                                                      ),
                                                ),
                                              ],
                                              if (webSnap.folioCloudPeriodEnd !=
                                                      null &&
                                                  webSnap
                                                      .folioCloudPeriodEnd!
                                                      .isNotEmpty) ...[
                                                const SizedBox(height: 4),
                                                Text(
                                                  panelL10n
                                                      .folioWebEntitlementWebPeriodEnd(
                                                    webSnap
                                                        .folioCloudPeriodEnd!,
                                                  ),
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(
                                                        color: panelScheme
                                                            .onSurfaceVariant,
                                                      ),
                                                ),
                                              ],
                                              if (webSnap.folioInkCredits !=
                                                  null) ...[
                                                const SizedBox(height: 4),
                                                Text(
                                                  panelL10n
                                                      .folioWebEntitlementWebInk(
                                                    webSnap.folioInkCredits!,
                                                  ),
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(
                                                        color: panelScheme
                                                            .onSurfaceVariant,
                                                      ),
                                                ),
                                              ],
                                            ],
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                              ListenableBuilder(
                                listenable: Listenable.merge([_cloud, _folio]),
                                builder: (context, _) {
                                  if (!_folio.isAvailable) {
                                    return const SizedBox.shrink();
                                  }
                                  if (!_cloud.isSignedIn) {
                                    return _FolioCloudGuestPitchTeaser(
                                      scheme: scheme,
                                      l10n: l10n,
                                      onOpenPitch: _openFolioCloudSubscriptionPitch,
                                    );
                                  }
                                  return _FolioCloudSubscriptionPanel(
                                    scheme: scheme,
                                    l10n: l10n,
                                    snap: _folio.snapshot,
                                    busy: _folioCloudActionBusy,
                                    backupCount: _cloudBackupCount,
                                    backupCountBusy: _cloudBackupCountBusy,
                                    onRefreshBackupCount: () =>
                                        _refreshCloudBackupCount(requireVerify: true),
                                    onSubscribeMonthly: () =>
                                        _openFolioCheckout(
                                          FolioCheckoutKind.folioCloudMonthly,
                                        ),
                                    onOpenPitch: _openFolioCloudSubscriptionPitch,
                                    onInkSmall: () => _openFolioCheckout(
                                      FolioCheckoutKind.inkSmall,
                                    ),
                                    onInkMedium: () => _openFolioCheckout(
                                      FolioCheckoutKind.inkMedium,
                                    ),
                                    onInkLarge: () => _openFolioCheckout(
                                      FolioCheckoutKind.inkLarge,
                                    ),
                                    onBillingPortal: _openFolioBillingPortal,
                                    onRefreshStripe:
                                        _syncFolioStripeSubscription,
                                    onUploadBackup: _uploadFolioCloudBackup,
                                    onOpenBackups: _openFolioCloudBackupsDialog,
                                    onPublishedPages: _openPublishedPagesDialog,
                                  );
                                },
                              ),
                            ],
                          ),
                        ),

                        AnimatedBuilder(
                          key: _sectionKeys[8],
                          animation: _sync,
                          builder: (context, _) => _SettingsPanel(
                            margin: const EdgeInsets.only(bottom: 24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _SettingsPanelHeroCard(
                                  icon: Icons.sync_rounded,
                                  title: _t(
                                    'Sincronización entre dispositivos',
                                    'Device synchronization',
                                  ),
                                  description: _t(
                                    'Empareja equipos en la red local; el relay solo ayuda a negociar la conexión, no envía el contenido del vault.',
                                    'Pair machines on the local network; the relay only helps negotiate the connection and does not send vault content.',
                                  ),
                                  chips: [
                                    _SettingsInfoChip(
                                      icon: Icons.shield_outlined,
                                      label: _t(
                                        'Código de enlace',
                                        'Pairing code',
                                      ),
                                    ),
                                    _SettingsInfoChip(
                                      icon: Icons.search_rounded,
                                      label: _t(
                                        'Detección automática',
                                        'Auto discovery',
                                      ),
                                    ),
                                    _SettingsInfoChip(
                                      icon: Icons.cloud_outlined,
                                      label: _t(
                                        'Relay opcional',
                                        'Optional relay',
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(height: 1),
                                SwitchListTile(
                                  secondary: const Icon(Icons.sync_rounded),
                                  title: Text(
                                    _t(
                                      'Activar sincronizacion entre dispositivos',
                                      'Enable device sync',
                                    ),
                                  ),
                                  subtitle: Text(
                                    _app.syncEnabled
                                        ? (_sync.discoveredPeers.isEmpty
                                              ? _t(
                                                  'Buscando dispositivos con Folio abierto en la red local...',
                                                  'Searching for nearby devices with Folio open on local network...',
                                                )
                                              : _t(
                                                  '${_sync.discoveredPeers.length} dispositivos detectados en LAN.',
                                                  '${_sync.discoveredPeers.length} devices discovered on LAN.',
                                                ))
                                        : _t(
                                            'La sincronizacion esta desactivada.',
                                            'Synchronization is currently disabled.',
                                          ),
                                  ),
                                  value: _app.syncEnabled,
                                  onChanged: (v) async {
                                    if (!v) {
                                      await _app.setSyncEnabled(false);
                                      if (mounted) setState(() {});
                                      return;
                                    }
                                    if (_s.state != VaultFlowState.unlocked) {
                                      return;
                                    }
                                    final l10nSync =
                                        AppLocalizations.of(context);
                                    final ok = await _verifyVaultIdentity(
                                      title: Text(
                                        l10nSync.vaultIdentitySyncTitle,
                                      ),
                                      body: Text(
                                        l10nSync.vaultIdentitySyncBody,
                                      ),
                                    );
                                    if (!ok || !mounted) return;
                                    await _app.setSyncEnabled(true);
                                    if (mounted) setState(() {});
                                  },
                                ),
                                const Divider(height: 1),
                                SwitchListTile(
                                  secondary: const Icon(Icons.hub_outlined),
                                  title: Text(
                                    _t(
                                      'Usar relay de senalizacion',
                                      'Use signaling relay',
                                    ),
                                  ),
                                  subtitle: Text(
                                    _t(
                                      'No envia contenido del vault, solo ayuda a negociar la conexion si la LAN falla.',
                                      'Does not send vault content, only helps negotiate connectivity when LAN fails.',
                                    ),
                                  ),
                                  value: _app.syncRelayEnabled,
                                  onChanged: _app.syncEnabled
                                      ? (v) async {
                                          if (v) {
                                            final l10nRelay =
                                                AppLocalizations.of(context);
                                            final ok =
                                                await _verifyVaultIdentity(
                                                  title: Text(
                                                    l10nRelay
                                                        .vaultIdentitySyncTitle,
                                                  ),
                                                  body: Text(
                                                    l10nRelay
                                                        .vaultIdentitySyncBody,
                                                  ),
                                                );
                                            if (!ok || !mounted) return;
                                          }
                                          await _app.setSyncRelayEnabled(v);
                                          if (mounted) setState(() {});
                                        }
                                      : null,
                                ),
                                const Divider(height: 1),
                                ListTile(
                                  leading: const Icon(Icons.devices_outlined),
                                  title: Text(
                                    _t('Nombre del dispositivo', 'Device name'),
                                  ),
                                  subtitle: Text(_app.syncDeviceName),
                                  trailing: TextButton(
                                    onPressed: _editSyncDeviceName,
                                    child: Text(_t('Editar', 'Edit')),
                                  ),
                                ),
                                const Divider(height: 1),
                                ListTile(
                                  leading: const Icon(Icons.pin_outlined),
                                  title: Text(
                                    _t(
                                      'Activar modo vinculacion por emojis',
                                      'Enable emoji pairing mode',
                                    ),
                                  ),
                                  subtitle: Text(
                                    _t(
                                      'Activalo en ambos dispositivos para iniciar el proceso de vinculacion sin escribir codigos.',
                                      'Enable it on both devices to start pairing without typing codes.',
                                    ),
                                  ),
                                  onTap: _app.syncEnabled
                                      ? _activateEmojiPairingMode
                                      : null,
                                ),
                                const Divider(height: 1),
                                ListTile(
                                  leading: const Icon(
                                    Icons.emoji_emotions_outlined,
                                  ),
                                  title: Text(
                                    _t(
                                      'Estado del modo vinculacion',
                                      'Pairing mode status',
                                    ),
                                  ),
                                  subtitle: Text(
                                    _sync.isPairingModeActive
                                        ? _t(
                                            'Activo durante 2 minutos. Ya puedes iniciar la vinculacion desde un dispositivo detectado.',
                                            'Active for 2 minutes. You can now start pairing from a detected device.',
                                          )
                                        : _t(
                                            'Inactivo. Activalo aqui y en el otro dispositivo para empezar a vincular.',
                                            'Inactive. Enable it here and on the other device to start pairing.',
                                          ),
                                  ),
                                ),
                                const Divider(height: 1),
                                ListTile(
                                  leading: const Icon(Icons.history_toggle_off),
                                  title: Text(
                                    _t(
                                      'Ultima sincronizacion',
                                      'Last synchronization',
                                    ),
                                  ),
                                  subtitle: Text(_formatLastSyncLabel()),
                                ),
                                const Divider(height: 1),
                                ListTile(
                                  leading: const Icon(
                                    Icons.warning_amber_rounded,
                                  ),
                                  title: Text(
                                    _t(
                                      'Conflictos pendientes',
                                      'Pending conflicts',
                                    ),
                                  ),
                                  subtitle: Text(
                                    _app.syncPendingConflicts <= 0
                                        ? _t(
                                            'Sin conflictos pendientes.',
                                            'No pending conflicts.',
                                          )
                                        : _t(
                                            '${_app.syncPendingConflicts} conflictos requieren revision manual.',
                                            '${_app.syncPendingConflicts} conflicts require manual review.',
                                          ),
                                  ),
                                  trailing: _app.syncPendingConflicts > 0
                                      ? TextButton(
                                          onPressed: _showSyncConflictsDialog,
                                          child: Text(
                                            _t('Resolver', 'Resolve'),
                                          ),
                                        )
                                      : null,
                                  onTap: _app.syncPendingConflicts > 0
                                      ? _showSyncConflictsDialog
                                      : null,
                                ),
                                const Divider(height: 1),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    12,
                                    16,
                                    6,
                                  ),
                                  child: Text(
                                    _t(
                                      'Dispositivos detectados',
                                      'Discovered devices',
                                    ),
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    0,
                                    16,
                                    10,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      if (_sync.discoveredPeers.isEmpty)
                                        Text(
                                          _t(
                                            'No se detectaron dispositivos todavia. Asegura que ambas apps esten abiertas en la misma red.',
                                            'No devices detected yet. Make sure both apps are open on the same network.',
                                          ),
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodySmall,
                                        )
                                      else
                                        ..._sync.discoveredPeers.map((peer) {
                                          final hasActiveCode =
                                              (peer.pairingCode ?? '')
                                                  .trim()
                                                  .isNotEmpty;
                                          final pairingReady =
                                              _sync.isPairingModeActive &&
                                              hasActiveCode;
                                          final subtitle = pairingReady
                                              ? _t(
                                                  'Listo para vincular.',
                                                  'Ready to link.',
                                                )
                                              : hasActiveCode
                                              ? _t(
                                                  'El otro dispositivo esta en modo vinculacion. Activalo aqui para iniciar el enlace.',
                                                  'The other device is in pairing mode. Enable it here to start linking.',
                                                )
                                              : _t(
                                                  'Detectado en la red local.',
                                                  'Detected on the local network.',
                                                );
                                          return Container(
                                            margin: const EdgeInsets.only(
                                              bottom: 8,
                                            ),
                                            decoration: BoxDecoration(
                                              color: scheme.surfaceContainerLow,
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                              border: Border.all(
                                                color: scheme.outlineVariant
                                                    .withValues(alpha: 0.5),
                                              ),
                                            ),
                                            child: ListTile(
                                              dense: true,
                                              leading: const Icon(
                                                Icons.wifi_tethering,
                                              ),
                                              title: Text(peer.deviceName),
                                              subtitle: Text(subtitle),
                                              trailing: FilledButton.tonal(
                                                onPressed:
                                                    _app.syncEnabled &&
                                                        pairingReady
                                                    ? () =>
                                                          _submitPairingCodeDialog(
                                                            peer: peer,
                                                          )
                                                    : null,
                                                child: Text(
                                                  _t('Vincular', 'Link'),
                                                ),
                                              ),
                                            ),
                                          );
                                        }),
                                    ],
                                  ),
                                ),
                                const Divider(height: 1),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    12,
                                    16,
                                    16,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _t(
                                          'Dispositivos vinculados',
                                          'Linked devices',
                                        ),
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                      const SizedBox(height: 10),
                                      if (_sync.peers.isEmpty)
                                        Text(
                                          _t(
                                            'Aun no hay dispositivos enlazados.',
                                            'No linked devices yet.',
                                          ),
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodySmall,
                                        )
                                      else
                                        ..._sync.peers.map((peer) {
                                          return Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 8,
                                            ),
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color:
                                                    scheme.surfaceContainerLow,
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                                border: Border.all(
                                                  color: scheme.outlineVariant
                                                      .withValues(alpha: 0.5),
                                                ),
                                              ),
                                              child: ListTile(
                                                dense: true,
                                                leading: const Icon(
                                                  Icons.devices,
                                                ),
                                                title: Text(peer.deviceName),
                                                subtitle: Text(
                                                  '${_t('ID', 'ID')}: ${peer.peerId}',
                                                ),
                                                trailing: TextButton(
                                                  onPressed: () =>
                                                      _revokeSyncPeer(peer),
                                                  child: Text(
                                                    _t('Revocar', 'Revoke'),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          );
                                        }),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        _SettingsPanel(
                          key: _sectionKeys[9],
                          margin: const EdgeInsets.only(bottom: 24),
                          child: Column(
                            children: [
                              _SettingsPanelHeroCard(
                                icon: Icons.info_outline_rounded,
                                title: l10n.about,
                                description: _t(
                                  'Versión instalada, origen de actualizaciones y comprobación manual de novedades.',
                                  'Installed version, update source, and manual checks for new releases.',
                                ),
                                chips: [
                                  _SettingsInfoChip(
                                    icon: Icons.tag_rounded,
                                    label: l10n.installedVersion,
                                  ),
                                  _SettingsInfoChip(
                                    icon: Icons.system_update_rounded,
                                    label: l10n.checkUpdates,
                                  ),
                                ],
                              ),
                              const Divider(height: 1),
                              ListTile(
                                leading: const Icon(Icons.info_outline_rounded),
                                title: Text(l10n.installedVersion),
                                subtitle: Text(_installedVersionLabel),
                              ),
                              if (showDesktopOnlySections) ...[
                                const Divider(height: 1),
                                ListTile(
                                  leading: const Icon(Icons.cloud_outlined),
                                  title: Text(l10n.updaterGithubRepository),
                                  subtitle: Text(
                                    '${_app.updaterGithubOwner}/${_app.updaterGithubRepo}',
                                  ),
                                ),
                                const Divider(height: 1),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    8,
                                    16,
                                    8,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Text(
                                        'Canal',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleSmall,
                                      ),
                                      const SizedBox(height: 8),
                                      SegmentedButton<UpdateReleaseChannel>(
                                        segments: const [
                                          ButtonSegment<UpdateReleaseChannel>(
                                            value: UpdateReleaseChannel.stable,
                                            label: Text('Release'),
                                            icon: Icon(
                                              Icons.verified_outlined,
                                              size: 18,
                                            ),
                                          ),
                                          ButtonSegment<UpdateReleaseChannel>(
                                            value: UpdateReleaseChannel.beta,
                                            label: Text('Beta'),
                                            icon: Icon(
                                              Icons.science_outlined,
                                              size: 18,
                                            ),
                                          ),
                                        ],
                                        selected: {_app.updateReleaseChannel},
                                        onSelectionChanged: (s) {
                                          _app.setUpdateReleaseChannel(s.first);
                                        },
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        _app.updateReleaseChannel ==
                                                UpdateReleaseChannel.beta
                                            ? l10n.updaterBetaDescription
                                            : l10n.updaterStableDescription,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: scheme.onSurfaceVariant,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Divider(height: 1),
                                ListTile(
                                  leading: const Icon(
                                    Icons.system_update_rounded,
                                  ),
                                  title: Text(l10n.checkUpdates),
                                  trailing: _checkingUpdates
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : null,
                                  onTap: _checkingUpdates
                                      ? null
                                      : _checkUpdatesNow,
                                ),
                              ],
                            ],
                          ),
                        ),

                        _SettingsPanel(
                          key: _sectionKeys[10],
                          margin: const EdgeInsets.only(bottom: 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _SettingsPanelHeroCard(
                                icon: Icons.storage_rounded,
                                title: l10n.data,
                                description: _t(
                                  'Acciones permanentes sobre archivos locales. Haz una copia de seguridad antes de borrar.',
                                  'Permanent actions on local files. Make a backup before deleting.',
                                ),
                                chips: [
                                  _SettingsInfoChip(
                                    icon: Icons.delete_forever_outlined,
                                    label: l10n.wipeCardTitle,
                                  ),
                                  _SettingsInfoChip(
                                    icon: Icons.delete_outline,
                                    label: l10n.deleteOtherVault,
                                  ),
                                ],
                              ),
                              const Divider(height: 1),
                              _SettingsSubsectionTitle(
                                title: _t('Zona de peligro', 'Danger zone'),
                                scheme: scheme,
                                topPadding: 8,
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  0,
                                  16,
                                  8,
                                ),
                                child: Card(
                                  color: scheme.errorContainer.withValues(
                                    alpha: 0.2,
                                  ),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    side: BorderSide(
                                      color: scheme.error.withValues(
                                        alpha: 0.5,
                                      ),
                                    ),
                                    borderRadius: const BorderRadius.all(
                                      Radius.circular(20),
                                    ),
                                  ),
                                  child: ListTile(
                                    leading: Icon(
                                      Icons.delete_forever_outlined,
                                      color: scheme.error,
                                    ),
                                    title: Text(
                                      l10n.wipeCardTitle,
                                      style: TextStyle(
                                        color: scheme.error,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    subtitle: Text(
                                      l10n.wipeCardSubtitle,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: scheme.error.withValues(
                                              alpha: 0.8,
                                            ),
                                          ),
                                    ),
                                    onTap: _openWipeFlow,
                                  ),
                                ),
                              ),
                              const Divider(height: 1),
                              ListTile(
                                leading: const Icon(Icons.delete_outline),
                                title: Text(l10n.deleteOtherVault),
                                subtitle: Text(l10n.deleteOtherVaultTitle),
                                onTap: _deleteOtherVault,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  );
                },
              );
              if (!wide) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: settingsContent,
                );
              }
              return Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1480),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          width: 280,
                          child: _SettingsDesktopRail(
                            title: l10n.settings,
                            subtitle: _t(
                              'Elige una categoría en la lista o desplázate por el contenido.',
                              'Pick a category from the list or scroll the content.',
                            ),
                            currentSection: _selectedDesktopSection,
                            onSelectSection: _scrollToSection,
                            sections: _filterDesktopSections(desktopSections),
                            sectionFilterController:
                                _settingsSectionFilterController,
                            sectionFilterHint: l10n.settingsSearchSectionsHint,
                            sectionFilterLabel: l10n.settingsSearchSections,
                          ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(child: settingsContent),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _CloudAuthDialog extends StatefulWidget {
  const _CloudAuthDialog({
    required this.initialRegister,
    required this.l10n,
    required this.cloudAuthController,
    required this.onAuthError,
    required this.onForgotPassword,
  });

  final bool initialRegister;
  final AppLocalizations l10n;
  final CloudAccountController cloudAuthController;
  final String Function(String code) onAuthError;
  final VoidCallback onForgotPassword;

  @override
  State<_CloudAuthDialog> createState() => _CloudAuthDialogState();
}

class _CloudAuthDialogState extends State<_CloudAuthDialog> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _emailFocus = FocusNode();
  late bool _modeRegister;
  var _obscurePassword = true;
  var _obscureConfirm = true;
  var _loading = false;

  @override
  void initState() {
    super.initState();
    _modeRegister = widget.initialRegister;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _emailFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    _emailFocus.dispose();
    super.dispose();
  }

  bool _isValidEmail(String s) {
    final t = s.trim();
    if (t.isEmpty) return false;
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t);
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final email = _email.text.trim();
    final pass = _password.text;
    setState(() => _loading = true);
    try {
      if (_modeRegister) {
        await widget.cloudAuthController.createUserWithEmailAndPassword(
          email: email,
          password: pass,
        );
      } else {
        await widget.cloudAuthController.signInWithEmailAndPassword(
          email: email,
          password: pass,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(widget.onAuthError(e.code)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(behavior: SnackBarBehavior.floating, content: Text('$e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    final scheme = Theme.of(context).colorScheme;
    final subtitle = _modeRegister
        ? l10n.cloudAuthSubtitleRegister
        : l10n.cloudAuthSubtitleSignIn;

    return FolioDialog(
      contentWidth: 420,
      title: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: scheme.primaryContainer.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.cloud_rounded, color: scheme.primary, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              l10n.cloudAuthDialogTitle,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            SegmentedButton<bool>(
              segments: [
                ButtonSegment<bool>(
                  value: false,
                  label: Text(l10n.cloudAuthModeSignIn),
                  icon: const Icon(Icons.login_rounded, size: 18),
                ),
                ButtonSegment<bool>(
                  value: true,
                  label: Text(l10n.cloudAuthModeRegister),
                  icon: const Icon(Icons.person_add_outlined, size: 18),
                ),
              ],
              selected: {_modeRegister},
              onSelectionChanged: (Set<bool> next) {
                if (_loading || next.isEmpty) return;
                setState(() {
                  _modeRegister = next.first;
                  _confirm.clear();
                });
              },
            ),
            const SizedBox(height: 18),
            AutofillGroup(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _email,
                      focusNode: _emailFocus,
                      enabled: !_loading,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      autofillHints: const [AutofillHints.email],
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: l10n.cloudAccountEmailLabel,
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.alternate_email_rounded),
                      ),
                      validator: (v) {
                        final s = v?.trim() ?? '';
                        if (s.isEmpty) return l10n.cloudAuthValidationRequired;
                        if (!_isValidEmail(s)) {
                          return l10n.cloudAuthErrorInvalidEmail;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _password,
                      enabled: !_loading,
                      obscureText: _obscurePassword,
                      autofillHints: [
                        _modeRegister
                            ? AutofillHints.newPassword
                            : AutofillHints.password,
                      ],
                      textInputAction: _modeRegister
                          ? TextInputAction.next
                          : TextInputAction.done,
                      onFieldSubmitted: (_) {
                        if (_modeRegister) {
                          FocusScope.of(context).nextFocus();
                        } else {
                          unawaited(_submit());
                        }
                      },
                      decoration: InputDecoration(
                        labelText: l10n.cloudAccountPasswordLabel,
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          tooltip: _obscurePassword
                              ? l10n.showPassword
                              : l10n.hidePassword,
                          onPressed: _loading
                              ? null
                              : () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                                ),
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_rounded
                                : Icons.visibility_off_rounded,
                          ),
                        ),
                      ),
                      validator: (v) {
                        final s = v ?? '';
                        if (s.isEmpty) return l10n.cloudAuthValidationRequired;
                        if (s.length < 6) {
                          return l10n.cloudAuthValidationPasswordShort;
                        }
                        return null;
                      },
                    ),
                    if (_modeRegister) ...[
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _confirm,
                        enabled: !_loading,
                        obscureText: _obscureConfirm,
                        autofillHints: const [AutofillHints.newPassword],
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => unawaited(_submit()),
                        decoration: InputDecoration(
                          labelText: l10n.cloudAuthConfirmPasswordLabel,
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.lock_person_outlined),
                          suffixIcon: IconButton(
                            tooltip: _obscureConfirm
                                ? l10n.showPassword
                                : l10n.hidePassword,
                            onPressed: _loading
                                ? null
                                : () => setState(
                                    () => _obscureConfirm = !_obscureConfirm,
                                  ),
                            icon: Icon(
                              _obscureConfirm
                                  ? Icons.visibility_rounded
                                  : Icons.visibility_off_rounded,
                            ),
                          ),
                        ),
                        validator: (v) {
                          final s = v ?? '';
                          if (s.isEmpty) {
                            return l10n.cloudAuthValidationRequired;
                          }
                          if (s != _password.text) {
                            return l10n.cloudAuthValidationConfirmMismatch;
                          }
                          return null;
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (!_modeRegister) ...[
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _loading ? null : widget.onForgotPassword,
                  icon: const Icon(Icons.mail_outline_rounded, size: 18),
                  label: Text(l10n.cloudAccountForgotPassword),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  _modeRegister
                      ? l10n.cloudAccountCreateAccount
                      : l10n.cloudAccountSignIn,
                ),
        ),
      ],
    );
  }
}

class _CloudPasswordResetDialog extends StatefulWidget {
  const _CloudPasswordResetDialog({
    required this.l10n,
    this.fixedEmail,
  });

  final AppLocalizations l10n;
  final String? fixedEmail;

  @override
  State<_CloudPasswordResetDialog> createState() =>
      _CloudPasswordResetDialogState();
}

class _CloudPasswordResetDialogState extends State<_CloudPasswordResetDialog> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _focus = FocusNode();

  bool get _emailLocked =>
      widget.fixedEmail != null && widget.fixedEmail!.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    final locked = widget.fixedEmail?.trim();
    if (locked != null && locked.isNotEmpty) {
      _email.text = locked;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_emailLocked) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _email.dispose();
    _focus.dispose();
    super.dispose();
  }

  bool _isValidEmail(String s) {
    final t = s.trim();
    if (t.isEmpty) return false;
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t);
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(_email.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    final scheme = Theme.of(context).colorScheme;
    return FolioDialog(
      contentWidth: 400,
      title: Row(
        children: [
          Icon(Icons.lock_reset_rounded, color: scheme.primary, size: 26),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              l10n.cloudAuthDialogTitleReset,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.cloudAuthResetHint,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _email,
              focusNode: _focus,
              readOnly: _emailLocked,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              autofillHints: const [AutofillHints.email],
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: l10n.cloudAccountEmailLabel,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.email_outlined),
              ),
              validator: (v) {
                final s = v?.trim() ?? '';
                if (s.isEmpty) return l10n.cloudAuthValidationRequired;
                if (!_isValidEmail(s)) return l10n.cloudAuthErrorInvalidEmail;
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.continueAction)),
      ],
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
  var _obscure = true;

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
    final l10n = AppLocalizations.of(context);
    return FolioDialog(
      title: Text(l10n.backupPasswordDialogTitle),
      content: FolioPasswordField(
        controller: _controller,
        obscureText: _obscure,
        autofocus: true,
        labelText: l10n.backupFilePasswordLabel,
        showPasswordTooltip: l10n.showPassword,
        hidePasswordTooltip: l10n.hidePassword,
        helperText: l10n.backupFilePasswordHelper,
        onToggleObscure: () => setState(() => _obscure = !_obscure),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.importAction)),
      ],
    );
  }
}

enum _NotionImportMode { currentVault, newVault }

class _NotionImportModeDialog extends StatelessWidget {
  const _NotionImportModeDialog();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return FolioDialog(
      title: Text(l10n.importNotionSelectTargetTitle),
      content: Text(l10n.importNotionSelectTargetBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        OutlinedButton(
          onPressed: () =>
              Navigator.pop(context, _NotionImportMode.currentVault),
          child: Text(l10n.importNotionTargetCurrent),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _NotionImportMode.newVault),
          child: Text(l10n.importNotionTargetNew),
        ),
      ],
    );
  }
}

class _NewVaultPasswordDialog extends StatefulWidget {
  const _NewVaultPasswordDialog();

  @override
  State<_NewVaultPasswordDialog> createState() =>
      _NewVaultPasswordDialogState();
}

class _NewVaultPasswordDialogState extends State<_NewVaultPasswordDialog> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  var _obscureA = true;
  var _obscureB = true;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _submit() {
    final l10n = AppLocalizations.of(context);
    final a = _password.text.trim();
    final b = _confirm.text.trim();
    if (a.length < 10) {
      setState(() => _error = l10n.minCharactersError(10));
      return;
    }
    if (a != b) {
      setState(() => _error = l10n.passwordMismatchError);
      return;
    }
    setState(() => _error = null);
    Navigator.pop(context, a);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return FolioDialog(
      title: Text(l10n.importNotionNewVaultPasswordTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FolioPasswordField(
            controller: _password,
            obscureText: _obscureA,
            labelText: l10n.passwordLabel,
            showPasswordTooltip: l10n.showPassword,
            hidePasswordTooltip: l10n.hidePassword,
            onToggleObscure: () => setState(() => _obscureA = !_obscureA),
          ),
          const SizedBox(height: 8),
          FolioPasswordField(
            controller: _confirm,
            obscureText: _obscureB,
            labelText: l10n.confirmPasswordLabel,
            showPasswordTooltip: l10n.showPassword,
            hidePasswordTooltip: l10n.hidePassword,
            onToggleObscure: () => setState(() => _obscureB = !_obscureB),
            onSubmitted: (_) => _submit(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.importAction)),
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

class _EncryptPlainVaultDialog extends StatefulWidget {
  const _EncryptPlainVaultDialog({required this.session});

  final VaultSession session;

  @override
  State<_EncryptPlainVaultDialog> createState() =>
      _EncryptPlainVaultDialogState();
}

class _EncryptPlainVaultDialogState extends State<_EncryptPlainVaultDialog> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  var _busy = false;
  var _obscurePw = true;
  var _obscureConfirm = true;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final pw = _password.text;
    final c = _confirm.text;
    final l10n = AppLocalizations.of(context);
    if (pw.isEmpty || c.isEmpty) {
      setState(() => _error = l10n.fillAllFieldsError);
      return;
    }
    if (pw != c) {
      setState(() => _error = l10n.passwordMismatchError);
      return;
    }
    if (_passwordStrengthFor(pw) != _PasswordStrength.strong) {
      setState(() => _error = l10n.passwordMustBeStrongError);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.session.enableVaultEncryption(pw);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final strength = _passwordStrengthFor(_password.text);
    final strengthValue = switch (strength) {
      _PasswordStrength.veryWeak => 0.25,
      _PasswordStrength.weak => 0.5,
      _PasswordStrength.fair => 0.75,
      _PasswordStrength.strong => 1.0,
    };
    final strengthLabel = switch (strength) {
      _PasswordStrength.veryWeak => l10n.passwordStrengthVeryWeak,
      _PasswordStrength.weak => l10n.passwordStrengthWeak,
      _PasswordStrength.fair => l10n.passwordStrengthFair,
      _PasswordStrength.strong => l10n.passwordStrengthStrong,
    };
    return FolioDialog(
      title: Text(l10n.encryptPlainVaultTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.encryptPlainVaultBody,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _password,
              obscureText: _obscurePw,
              enabled: !_busy,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: l10n.newPasswordLabel,
                suffixIcon: IconButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() => _obscurePw = !_obscurePw),
                  icon: Icon(
                    _obscurePw ? Icons.visibility : Icons.visibility_off,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: strengthValue),
            const SizedBox(height: 4),
            Text(l10n.passwordStrengthWithValue(strengthLabel)),
            const SizedBox(height: 12),
            TextField(
              controller: _confirm,
              obscureText: _obscureConfirm,
              enabled: !_busy,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: l10n.confirmNewPasswordLabel,
                suffixIcon: IconButton(
                  onPressed: _busy
                      ? null
                      : () =>
                            setState(() => _obscureConfirm = !_obscureConfirm),
                  icon: Icon(
                    _obscureConfirm ? Icons.visibility : Icons.visibility_off,
                  ),
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: Text(l10n.encryptPlainVaultConfirm),
        ),
      ],
    );
  }
}

class _ChangeMasterPasswordDialog extends StatefulWidget {
  const _ChangeMasterPasswordDialog({required this.session});

  final VaultSession session;

  @override
  State<_ChangeMasterPasswordDialog> createState() =>
      _ChangeMasterPasswordDialogState();
}

class _ChangeMasterPasswordDialogState
    extends State<_ChangeMasterPasswordDialog> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  var _busy = false;
  var _obscureCurrent = true;
  var _obscureNext = true;
  var _obscureConfirm = true;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final currentPassword = _current.text;
    final nextPassword = _next.text;
    final confirmPassword = _confirm.text;
    if (currentPassword.isEmpty ||
        nextPassword.isEmpty ||
        confirmPassword.isEmpty) {
      setState(() => _error = AppLocalizations.of(context).fillAllFieldsError);
      return;
    }
    if (nextPassword != confirmPassword) {
      setState(
        () => _error = AppLocalizations.of(context).newPasswordsMismatchError,
      );
      return;
    }
    if (_passwordStrengthFor(nextPassword) != _PasswordStrength.strong) {
      setState(
        () =>
            _error = AppLocalizations.of(context).newPasswordMustBeStrongError,
      );
      return;
    }
    if (currentPassword == nextPassword) {
      setState(
        () => _error = AppLocalizations.of(context).newPasswordMustDifferError,
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.session.changeMasterPassword(
        currentPassword: currentPassword,
        newPassword: nextPassword,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final strength = _passwordStrengthFor(_next.text);
    final strengthValue = switch (strength) {
      _PasswordStrength.veryWeak => 0.25,
      _PasswordStrength.weak => 0.5,
      _PasswordStrength.fair => 0.75,
      _PasswordStrength.strong => 1.0,
    };
    final strengthLabel = switch (strength) {
      _PasswordStrength.veryWeak => l10n.passwordStrengthVeryWeak,
      _PasswordStrength.weak => l10n.passwordStrengthWeak,
      _PasswordStrength.fair => l10n.passwordStrengthFair,
      _PasswordStrength.strong => l10n.passwordStrengthStrong,
    };
    return FolioDialog(
      title: Text(l10n.changeMasterPassword),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _current,
              obscureText: _obscureCurrent,
              enabled: !_busy,
              decoration: InputDecoration(
                labelText: l10n.currentPasswordLabel,
                suffixIcon: IconButton(
                  onPressed: _busy
                      ? null
                      : () =>
                            setState(() => _obscureCurrent = !_obscureCurrent),
                  icon: Icon(
                    _obscureCurrent ? Icons.visibility : Icons.visibility_off,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _next,
              obscureText: _obscureNext,
              enabled: !_busy,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: l10n.newPasswordLabel,
                suffixIcon: IconButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() => _obscureNext = !_obscureNext),
                  icon: Icon(
                    _obscureNext ? Icons.visibility : Icons.visibility_off,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: strengthValue),
            const SizedBox(height: 4),
            Text(l10n.passwordStrengthWithValue(strengthLabel)),
            const SizedBox(height: 12),
            TextField(
              controller: _confirm,
              obscureText: _obscureConfirm,
              enabled: !_busy,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: l10n.confirmNewPasswordLabel,
                suffixIcon: IconButton(
                  onPressed: _busy
                      ? null
                      : () =>
                            setState(() => _obscureConfirm = !_obscureConfirm),
                  icon: Icon(
                    _obscureConfirm ? Icons.visibility : Icons.visibility_off,
                  ),
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: Text(l10n.cancel),
        ),
        FilledButton(onPressed: _busy ? null : _submit, child: Text(l10n.save)),
      ],
    );
  }
}

enum _AiWizardAction { close, retry }

class _AiSetupWizardDialog extends StatefulWidget {
  const _AiSetupWizardDialog({
    required this.summary,
    required this.selectedProvider,
    required this.title,
    required this.noProviderTitle,
    required this.noProviderBody,
    required this.ollamaInstallTitle,
    required this.ollamaInstallBody,
    required this.lmStudioInstallTitle,
    required this.lmStudioInstallBody,
    required this.openSettingsHint,
    required this.retryLabel,
    required this.closeLabel,
  });

  final AiProviderDetectionSummary summary;
  final AiProvider selectedProvider;
  final String title;
  final String noProviderTitle;
  final String noProviderBody;
  final String ollamaInstallTitle;
  final String ollamaInstallBody;
  final String lmStudioInstallTitle;
  final String lmStudioInstallBody;
  final String openSettingsHint;
  final String retryLabel;
  final String closeLabel;

  @override
  State<_AiSetupWizardDialog> createState() => _AiSetupWizardDialogState();
}

class _AiSetupWizardDialogState extends State<_AiSetupWizardDialog> {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isOllama = widget.selectedProvider == AiProvider.ollama;
    final selectedStatus = isOllama
        ? widget.summary.ollama
        : widget.summary.lmStudio;
    return FolioDialog(
      title: Text(widget.title),
      contentWidth: 520,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.noProviderTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(widget.noProviderBody),
          const SizedBox(height: 12),
          _ProviderStatusLine(
            label: isOllama ? 'Ollama' : 'LM Studio',
            installed: selectedStatus.installed,
            reachable: selectedStatus.reachable,
          ),
          const SizedBox(height: 12),
          Text(
            isOllama ? widget.ollamaInstallTitle : widget.lmStudioInstallTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            isOllama ? widget.ollamaInstallBody : widget.lmStudioInstallBody,
          ),
          const SizedBox(height: 10),
          SelectableText(
            isOllama ? 'https://ollama.com/download' : 'https://lmstudio.ai/',
            style: TextStyle(color: scheme.primary),
          ),
          const SizedBox(height: 14),
          Text(
            widget.openSettingsHint,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, _AiWizardAction.close),
          child: Text(widget.closeLabel),
        ),
        FilledButton.tonal(
          onPressed: () => Navigator.pop(context, _AiWizardAction.retry),
          child: Text(widget.retryLabel),
        ),
      ],
    );
  }
}

class _ReleaseCheckRow extends StatelessWidget {
  const _ReleaseCheckRow({
    required this.label,
    required this.ok,
    required this.severity,
    this.details,
  });

  final String label;
  final bool ok;
  final ReleaseCheckSeverity severity;
  final String? details;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = ok
        ? Colors.green
        : (severity == ReleaseCheckSeverity.blocker
              ? scheme.error
              : Colors.orange);
    final tagText = severity == ReleaseCheckSeverity.blocker
        ? 'Bloqueador'
        : 'Advertencia';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              ok ? Icons.check_circle_rounded : Icons.error_outline_rounded,
              size: 18,
              color: color,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(label)),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        tagText,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                if (details != null && details!.trim().isNotEmpty)
                  Text(
                    details!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProviderStatusLine extends StatelessWidget {
  const _ProviderStatusLine({
    required this.label,
    required this.installed,
    required this.reachable,
  });

  final String label;
  final bool installed;
  final bool reachable;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(child: Text(label)),
        Icon(
          installed ? Icons.download_done_rounded : Icons.download_for_offline,
          size: 16,
          color: installed ? scheme.primary : scheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Icon(
          reachable ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
          size: 16,
          color: reachable ? Colors.green : scheme.onSurfaceVariant,
        ),
      ],
    );
  }
}

/// Tarjeta-resumen al inicio de un panel de ajustes (mismo lenguaje visual que
/// iconos personalizados e integraciones).
class _SettingsPanelHeroCard extends StatelessWidget {
  const _SettingsPanelHeroCard({
    required this.icon,
    required this.title,
    required this.description,
    this.trailingBadge,
    this.chips = const [],
  });

  final IconData icon;
  final String title;
  final String description;
  final Widget? trailingBadge;
  final List<Widget> chips;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primaryContainer.withValues(alpha: 0.55),
            scheme.surfaceContainerHigh,
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: scheme.primary, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        if (trailingBadge != null) ...[
                          const SizedBox(width: 8),
                          trailingBadge!,
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (chips.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(spacing: 8, runSpacing: 8, children: chips),
          ],
        ],
      ),
    );
  }
}

class _SettingsInfoChip extends StatelessWidget {
  const _SettingsInfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: scheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: scheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _IntegrationsHero extends StatelessWidget {
  const _IntegrationsHero({
    required this.approvedCount,
    required this.hintText,
    required this.title,
    required this.featureChips,
  });

  final int approvedCount;
  final String hintText;
  final String title;
  final List<Widget> featureChips;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _SettingsPanelHeroCard(
      icon: Icons.hub_rounded,
      title: title,
      description: hintText,
      trailingBadge: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          '$approvedCount',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: scheme.primary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      chips: featureChips,
    );
  }
}

class _IntegrationAppCard extends StatelessWidget {
  const _IntegrationAppCard({
    required this.entry,
    required this.detailsText,
    required this.revokeLabel,
    required this.onRevoke,
  });

  final IntegrationAppApproval entry;
  final String detailsText;
  final String revokeLabel;
  final VoidCallback onRevoke;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 260,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.verified_user_outlined,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  entry.appName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: scheme.primaryContainer.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              entry.appId,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: scheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            detailsText,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontFamily: 'monospace',
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onRevoke,
              icon: const Icon(Icons.delete_outline_rounded, size: 18),
              label: Text(revokeLabel),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsPanel extends StatelessWidget {
  const _SettingsPanel({super.key, required this.child, this.margin});

  final Widget child;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.surface, scheme.surfaceContainerLow],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
        boxShadow: FolioShadows.card(scheme),
      ),
      child: ClipRRect(borderRadius: BorderRadius.circular(24), child: child),
    );
  }
}

class _SettingsOverviewBanner extends StatelessWidget {
  const _SettingsOverviewBanner({
    required this.appSettings,
    required this.session,
  });

  final AppSettings appSettings;
  final VaultSession session;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final localeCode = appSettings.locale?.languageCode;
    final localeLabel = localeCode == null
        ? l10n.useSystemLanguage
        : (localeCode == 'es' ? l10n.spanishLanguage : l10n.englishLanguage);
    final aiLabel = appSettings.aiEnabled ? l10n.active : l10n.inactive;
    final vaultLabel = session.vaultUsesEncryption
        ? l10n.encryptedVault
        : (Localizations.localeOf(context).languageCode == 'es'
              ? 'Sin cifrar'
              : 'Unencrypted');
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primaryContainer.withValues(alpha: 0.72),
            scheme.tertiaryContainer.withValues(alpha: 0.36),
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: scheme.surface.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  Icons.tune_rounded,
                  color: scheme.primary,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.settings,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      Localizations.localeOf(context).languageCode == 'es'
                          ? 'Personaliza la app, gestiona seguridad, IA, copias e integraciones desde un único panel.'
                          : 'Customize the app, security, AI, backups, and integrations from one place.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _SettingsOverviewStat(
                icon: Icons.palette_outlined,
                label: l10n.language,
                value: localeLabel,
              ),
              _SettingsOverviewStat(
                icon: Icons.shield_outlined,
                label: Localizations.localeOf(context).languageCode == 'es'
                    ? 'Libreta'
                    : 'Vault',
                value: vaultLabel,
              ),
              _SettingsOverviewStat(
                icon: Icons.auto_awesome_outlined,
                label: Localizations.localeOf(context).languageCode == 'es'
                    ? 'IA'
                    : 'AI',
                value: aiLabel,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SettingsOverviewStat extends StatelessWidget {
  const _SettingsOverviewStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minWidth: 150),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: scheme.primary),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Agrupa opciones dentro de un panel (sin cambiar el índice de sección del rail).
class _SettingsSubsectionTitle extends StatelessWidget {
  const _SettingsSubsectionTitle({
    super.key,
    required this.title,
    required this.scheme,
    this.topPadding = 16,
  });

  final String title;
  final ColorScheme scheme;
  final double topPadding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, topPadding, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: scheme.onSurfaceVariant,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

/// Invitación a ver el pitch de Folio Cloud cuando aún no hay sesión (cuenta opcional).
class _FolioCloudGuestPitchTeaser extends StatelessWidget {
  const _FolioCloudGuestPitchTeaser({
    required this.scheme,
    required this.l10n,
    required this.onOpenPitch,
  });

  final ColorScheme scheme;
  final AppLocalizations l10n;
  final VoidCallback onOpenPitch;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SettingsSubsectionTitle(
          title: l10n.folioCloudSubsectionSubscription,
          scheme: scheme,
          topPadding: 14,
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: scheme.primaryContainer.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(FolioRadius.xl),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.4),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.cloud_outlined,
                      color: scheme.primary,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.folioCloudPitchGuestTeaserTitle,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            l10n.folioCloudPitchGuestTeaserBody,
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
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: onOpenPitch,
                    icon: const Icon(Icons.info_outline, size: 20),
                    label: Text(l10n.folioCloudPitchLearnMore),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Folio Cloud plan, ink, and billing UI inside Settings (signed-in only).
class _FolioCloudSubscriptionPanel extends StatelessWidget {
  const _FolioCloudSubscriptionPanel({
    required this.scheme,
    required this.l10n,
    required this.snap,
    required this.busy,
    required this.backupCount,
    required this.backupCountBusy,
    required this.onRefreshBackupCount,
    required this.onSubscribeMonthly,
    required this.onOpenPitch,
    required this.onInkSmall,
    required this.onInkMedium,
    required this.onInkLarge,
    required this.onBillingPortal,
    required this.onRefreshStripe,
    required this.onUploadBackup,
    required this.onOpenBackups,
    required this.onPublishedPages,
  });

  final ColorScheme scheme;
  final AppLocalizations l10n;
  final FolioCloudSnapshot snap;
  final bool busy;
  final int? backupCount;
  final bool backupCountBusy;
  final VoidCallback onRefreshBackupCount;
  final VoidCallback onSubscribeMonthly;
  final VoidCallback onOpenPitch;
  final VoidCallback onInkSmall;
  final VoidCallback onInkMedium;
  final VoidCallback onInkLarge;
  final VoidCallback onBillingPortal;
  final VoidCallback onRefreshStripe;
  final VoidCallback onUploadBackup;
  final VoidCallback onOpenBackups;
  final VoidCallback onPublishedPages;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: 1),
        if (busy)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: const LinearProgressIndicator(minHeight: 3),
            ),
          ),
        _SettingsSubsectionTitle(
          title: l10n.folioCloudSubsectionInk,
          scheme: scheme,
          topPadding: busy ? 10 : 14,
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final cardMin = ((constraints.maxWidth - 20) / 3).clamp(
                104.0,
                220.0,
              );
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _FolioCloudInkStatCard(
                    scheme: scheme,
                    icon: Icons.calendar_month_outlined,
                    label: l10n.folioCloudInkMonthly,
                    valueText: l10n.folioCloudInkCount(snap.ink.monthlyBalance),
                    minWidth: cardMin,
                  ),
                  _FolioCloudInkStatCard(
                    scheme: scheme,
                    icon: Icons.shopping_bag_outlined,
                    label: l10n.folioCloudInkPurchased,
                    valueText: l10n.folioCloudInkCount(
                      snap.ink.purchasedBalance,
                    ),
                    minWidth: cardMin,
                  ),
                  _FolioCloudInkStatCard(
                    scheme: scheme,
                    icon: Icons.water_drop_outlined,
                    label: l10n.folioCloudInkTotal,
                    valueText: l10n.folioCloudInkCount(snap.ink.totalInk),
                    minWidth: cardMin,
                  ),
                ],
              );
            },
          ),
        ),
        if (snap.ink.purchasedBalance > 0) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.secondaryContainer.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.check_circle_outline_rounded,
                    color: scheme.onSecondaryContainer,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l10n.folioCloudInkPurchaseAppliedHint(
                        l10n.folioCloudInkCount(snap.ink.purchasedBalance),
                      ),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSecondaryContainer,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        _SettingsSubsectionTitle(
          title: l10n.folioCloudSubsectionSubscription,
          scheme: scheme,
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Hero: subscription
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      scheme.primaryContainer.withValues(alpha: 0.55),
                      scheme.surfaceContainerHigh,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(FolioRadius.xl),
                  border: Border.all(
                    color: scheme.outlineVariant.withValues(alpha: 0.45),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: scheme.surface.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            Icons.cloud_outlined,
                            color: scheme.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                snap.active
                                    ? l10n.folioCloudPlanActiveHeadline
                                    : l10n.folioCloudSubscriptionNoneTitle,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                snap.active
                                    ? l10n.folioCloudSubscriptionActive
                                    : l10n.folioCloudSubscriptionNoneSubtitle,
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
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _SettingsInfoChip(
                          icon: Icons.backup_outlined,
                          label: l10n.folioCloudFeatureBackup,
                        ),
                        _SettingsInfoChip(
                          icon: Icons.auto_awesome_outlined,
                          label: l10n.folioCloudFeatureCloudAi,
                        ),
                        _SettingsInfoChip(
                          icon: Icons.public_outlined,
                          label: l10n.folioCloudFeaturePublishWeb,
                        ),
                      ],
                    ),
                    if (!snap.active) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: busy ? null : onOpenPitch,
                          icon: const Icon(Icons.info_outline, size: 20),
                          label: Text(l10n.folioCloudPitchLearnMore),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: busy
                                ? null
                                : (snap.active ? onBillingPortal : onSubscribeMonthly),
                            icon: Icon(
                              snap.active
                                  ? Icons.payments_outlined
                                  : Icons.subscriptions_outlined,
                              size: 20,
                            ),
                            label: Text(
                              snap.active
                                  ? l10n.folioCloudManageSubscription
                                  : l10n.folioCloudSubscribeMonthly,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        OutlinedButton.icon(
                          onPressed: busy ? null : onRefreshStripe,
                          icon: const Icon(Icons.sync, size: 20),
                          label: Text(l10n.folioCloudRefreshFromStripe),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Ink shop
              Text(
                l10n.folioCloudBuyInk,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              LayoutBuilder(
                builder: (context, constraints) {
                  final narrow = constraints.maxWidth < 520;
                  final cards = [
                    _FolioCloudInkPackCard(
                      scheme: scheme,
                      title: l10n.folioCloudInkSmall,
                      drops: 300,
                      onPressed: busy ? null : onInkSmall,
                    ),
                    _FolioCloudInkPackCard(
                      scheme: scheme,
                      title: l10n.folioCloudInkMedium,
                      drops: 1000,
                      onPressed: busy ? null : onInkMedium,
                    ),
                    _FolioCloudInkPackCard(
                      scheme: scheme,
                      title: l10n.folioCloudInkLarge,
                      drops: 2500,
                      onPressed: busy ? null : onInkLarge,
                    ),
                  ];
                  if (narrow) {
                    return Column(
                      children: [
                        for (var i = 0; i < cards.length; i++) ...[
                          if (i > 0) const SizedBox(height: 10),
                          cards[i],
                        ],
                      ],
                    );
                  }
                  return Row(
                    children: [
                      for (var i = 0; i < cards.length; i++) ...[
                        if (i > 0) const SizedBox(width: 10),
                        Expanded(child: cards[i]),
                      ],
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        _SettingsSubsectionTitle(
          title: l10n.folioCloudSubsectionBackupPublish,
          scheme: scheme,
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final cardMin = ((constraints.maxWidth - 20) / 3).clamp(
                104.0,
                220.0,
              );
              final used = backupCount;
              final remaining = used == null ? null : (10 - used).clamp(0, 10);
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _FolioCloudInkStatCard(
                    scheme: scheme,
                    icon: Icons.cloud_outlined,
                    label: l10n.folioCloudBackupsUsed,
                    valueText: used == null ? '—' : '$used',
                    minWidth: cardMin,
                  ),
                  _FolioCloudInkStatCard(
                    scheme: scheme,
                    icon: Icons.flag_outlined,
                    label: l10n.folioCloudBackupsLimit,
                    valueText: '10',
                    minWidth: cardMin,
                  ),
                  Stack(
                    children: [
                      _FolioCloudInkStatCard(
                        scheme: scheme,
                        icon: Icons.timer_outlined,
                        label: l10n.folioCloudBackupsRemaining,
                        valueText: remaining == null ? '—' : '$remaining',
                        minWidth: cardMin,
                      ),
                      Positioned(
                        top: 6,
                        right: 6,
                        child: IconButton(
                          tooltip: l10n.retry,
                          onPressed: backupCountBusy ? null : onRefreshBackupCount,
                          icon: backupCountBusy
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.refresh_rounded, size: 18),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
        ListTile(
          leading: const Icon(Icons.cloud_upload_outlined),
          title: Text(l10n.folioCloudUploadEncryptedBackup),
          subtitle: Text(l10n.folioCloudUploadEncryptedBackupSubtitle),
          enabled: !busy && snap.canUseCloudBackup,
          onTap: busy || !snap.canUseCloudBackup ? null : onUploadBackup,
        ),
        ListTile(
          leading: const Icon(Icons.cloud_download_outlined),
          title: Text(l10n.folioCloudCloudBackupsList),
          enabled: !busy && snap.canUseCloudBackup,
          onTap: busy || !snap.canUseCloudBackup ? null : onOpenBackups,
        ),
        ListTile(
          leading: const Icon(Icons.list_alt_outlined),
          title: Text(l10n.folioCloudPublishedPagesList),
          enabled: !busy && snap.canPublishToWeb,
          onTap: busy || !snap.canPublishToWeb ? null : onPublishedPages,
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _FolioCloudFeatureTile extends StatelessWidget {
  const _FolioCloudFeatureTile({
    required this.scheme,
    required this.icon,
    required this.title,
    required this.included,
    required this.includedLabel,
    required this.notIncludedLabel,
  });

  final ColorScheme scheme;
  final IconData icon;
  final String title;
  final bool included;
  final String includedLabel;
  final String notIncludedLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 22, color: scheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Icon(
            included ? Icons.check_circle_rounded : Icons.cancel_outlined,
            size: 22,
            color: included ? scheme.primary : scheme.outline,
          ),
          const SizedBox(width: 6),
          Text(
            included ? includedLabel : notIncludedLabel,
            style: theme.textTheme.labelMedium?.copyWith(
              color: included ? scheme.primary : scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _FolioCloudInkStatCard extends StatelessWidget {
  const _FolioCloudInkStatCard({
    required this.scheme,
    required this.icon,
    required this.label,
    required this.valueText,
    required this.minWidth,
  });

  final ColorScheme scheme;
  final IconData icon;
  final String label;
  final String valueText;
  final double minWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: BoxConstraints(minWidth: minWidth),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: scheme.surface.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: scheme.primary),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    valueText,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FolioCloudInkPackCard extends StatelessWidget {
  const _FolioCloudInkPackCard({
    required this.scheme,
    required this.title,
    required this.drops,
    required this.onPressed,
  });

  final ColorScheme scheme;
  final String title;
  final int drops;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.opacity_outlined, color: scheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '+$drops',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: -0.4,
              color: scheme.onSurface,
            ),
          ),
          Text(
            'ink',
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 10),
          FilledButton.tonal(
            onPressed: onPressed,
            child: Text(AppLocalizations.of(context).continueAction),
          ),
        ],
      ),
    );
  }
}

class _SettingsDesktopRail extends StatelessWidget {
  const _SettingsDesktopRail({
    required this.title,
    required this.subtitle,
    required this.sections,
    required this.currentSection,
    required this.onSelectSection,
    required this.sectionFilterController,
    required this.sectionFilterHint,
    required this.sectionFilterLabel,
  });

  final String title;
  final String subtitle;
  final List<_SettingsSectionNavItem> sections;
  final int currentSection;
  final ValueChanged<int> onSelectSection;
  final TextEditingController sectionFilterController;
  final String sectionFilterHint;
  final String sectionFilterLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [scheme.surface, scheme.surfaceContainerHigh],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - 48,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          scheme.primaryContainer,
                          scheme.tertiaryContainer,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(
                      Icons.tune_rounded,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    title,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Semantics(
                    label: sectionFilterLabel,
                    textField: true,
                    child: TextField(
                      controller: sectionFilterController,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search_rounded),
                        labelText: sectionFilterLabel,
                        hintText: sectionFilterHint,
                        isDense: true,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const SizedBox(height: 8),
                  ...sections.asMap().entries.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => onSelectSection(entry.value.keyIndex),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            curve: Curves.easeOutCubic,
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: currentSection == entry.value.keyIndex
                                  ? scheme.primaryContainer
                                  : scheme.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: currentSection == entry.value.keyIndex
                                    ? scheme.primary.withValues(alpha: 0.35)
                                    : Colors.transparent,
                              ),
                            ),
                            child: Text(
                              entry.value.label,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: currentSection == entry.value.keyIndex
                                    ? scheme.onPrimaryContainer
                                    : scheme.onSurface,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SettingsSectionNavItem {
  const _SettingsSectionNavItem({required this.label, required this.keyIndex});

  final String label;
  final int keyIndex;
}
