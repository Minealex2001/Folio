import 'dart:async';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:system_theme/system_theme.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/vault_backup.dart';
import '../desktop/desktop_integration.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/block.dart';
import '../services/ai/ai_provider_launcher.dart';
import '../services/ai/ai_safety_policy.dart';
import '../services/ai/lmstudio_ai_service.dart';
import '../services/ai/ollama_ai_service.dart';
import '../services/platform/launch_arguments.dart';
import '../services/cloud_account/cloud_account_controller.dart';
import '../services/ai/folio_cloud_ai_service.dart';
import '../services/folio_cloud/folio_cloud_entitlements.dart';
import '../services/folio_diagnostic_reporter.dart';
import '../services/folio_telemetry.dart';
import '../services/folio_telemetry_navigator_observer.dart';
import '../services/vault_scheduled_local_export.dart';
import '../services/tasks/task_reminder_service.dart';
import '../services/tasks/platform_notification_service.dart';
import '../features/settings/vault_identity_verify_dialog.dart';
import '../services/device_sync/device_sync_controller.dart';
import '../services/device_sync/device_sync_models.dart';
import '../services/integrations/integrations_bridge.dart';
import '../services/integrations/integrations_markdown_codec.dart';
import '../services/app_store/app_store_service.dart';
import '../services/app_store/app_extension_registry.dart';
import '../services/app_store/integration_auth_service.dart';
import '../services/updater/github_release_updater.dart';
import '../features/release_notes/release_notes_page.dart';
import '../features/lock/lock_screen.dart';
import '../features/onboarding/onboarding_flow.dart';
import '../features/workspace/workspace.dart';
import '../session/vault_session.dart';
import 'app_settings.dart';
import 'folio_theme.dart';
import 'ui_tokens.dart';

class FolioApp extends StatefulWidget {
  const FolioApp({
    super.key,
    required this.session,
    required this.appSettings,
    required this.cloudAccountController,
    this.folioCloudEntitlements,
    this.initialLaunchArgs = const <String>[],
  });

  final VaultSession session;
  final AppSettings appSettings;
  final CloudAccountController cloudAccountController;

  /// Si es null, el estado crea uno la primera vez que hace falta (también tras hot reload).
  final FolioCloudEntitlementsController? folioCloudEntitlements;
  final List<String> initialLaunchArgs;

  @override
  State<FolioApp> createState() => _FolioAppState();
}

class _FolioAppState extends State<FolioApp> with WidgetsBindingObserver {
  StreamSubscription<SystemAccentColor>? _accentSub;
  StreamSubscription<List<String>>? _launchArgsSub;
  final GlobalKey<NavigatorState> _navKey = GlobalKey<NavigatorState>();
  FolioCloudEntitlementsController? _folioCloudEntitlementsInstance;

  /// Inicialización perezosa: tras hot reload [initState] no se vuelve a llamar y un `late final` fallaría.
  FolioCloudEntitlementsController get _folioCloudEntitlements {
    _folioCloudEntitlementsInstance ??=
        widget.folioCloudEntitlements ?? FolioCloudEntitlementsController();
    return _folioCloudEntitlementsInstance!;
  }

  DesktopIntegration? _desktop;
  late final IntegrationsBridgeController _integrationsBridge;
  late final DeviceSyncController _deviceSyncController;
  String? _installedVersionLabel;
  var _openingByHotkey = false;
  String _desktopSettingsSignature = '';
  bool _updateDialogShown = false;
  bool _releaseNotesCheckInProgress = false;
  bool _releaseNotesShownThisRun = false;
  bool _handledInitialLaunchArgs = false;
  Timer? _scheduledVaultBackupTimer;
  TaskReminderService? _taskReminderService;
  StreamSubscription<List<TaskReminderEvent>>? _reminderSub;

  late final FolioTelemetryNavigatorObserver _telemetryNavObserver;
  VaultFlowState? _lastVaultFlowForTelemetry;

  @override
  void initState() {
    super.initState();
    _telemetryNavObserver =
        FolioTelemetryNavigatorObserver(() => widget.appSettings);
    _lastVaultFlowForTelemetry = widget.session.state;
    FolioDiagnosticReporter.bindAppSettings(widget.appSettings);
    WidgetsBinding.instance.addObserver(this);
    widget.session.titleLocale = widget.appSettings.locale;
    widget.session.addListener(_onSession);
    widget.appSettings.addListener(_onSettings);
    _integrationsBridge = IntegrationsBridgeController(
      onImport: _importIntegrationsMarkdown,
      onUpdate: _updateIntegrationsPage,
      onListPages: _listIntegrationsPages,
      onListCustomEmojis: _listIntegrationsCustomEmojis,
      onImportJson: _importIntegrationsJson,
      onReplaceCustomEmojis: _replaceIntegrationsCustomEmojis,
      onUpsertCustomEmoji: _upsertIntegrationsCustomEmoji,
      onDeleteCustomEmoji: _deleteIntegrationsCustomEmoji,
      onApproveClient: _approveIntegrationsClient,
      onClientObserved: _syncObservedIntegrationsClient,
      isClientApproved: (client) => widget.appSettings.isIntegrationAppApproved(
        client.appId,
        integrationVersion: client.integrationVersion,
      ),
      appInfoProvider: _integrationsAppInfo,
      resolveLocale: () => widget.appSettings.locale ?? const Locale('es'),
      onEvent: _showSnack,
      allowedOrigins: const ['*'],
    );
    _deviceSyncController = DeviceSyncController(
      appSettings: widget.appSettings,
      onEvent: _showSnack,
      onIncomingPairRequest: _showIncomingPairRequestDialog,
      onExportSnapshot: _exportSyncSnapshot,
      onImportSnapshot: _importSyncSnapshot,
    );
    widget.session.onSyncConflictCountChanged = (count) {
      unawaited(widget.appSettings.setSyncPendingConflicts(count));
    };
    widget.session.onPersisted = _deviceSyncController.onLocalSnapshotPersisted;
    unawaited(_deviceSyncController.load());
    _applySessionSecurityPolicy();
    _folioCloudEntitlements.addListener(_onFolioCloudEntitlements);
    _folioCloudEntitlements.setWebPortalBaseUrlResolver(
      () => AppSettings.folioWebPortalLinkEnabled
          ? widget.appSettings.folioWebPortalBaseUrlEffective
          : '',
    );
    unawaited(_folioCloudEntitlements.refreshWebPortalEntitlement());
    _applyAiSettings();
    _applyDeviceSyncSettings();
    _maybeLaunchAiProvider();
    unawaited(IntegrationAuthService.instance.load());
    unawaited(
      AppStoreService.instance.init().then((_) {
        AppExtensionRegistry.instance.loadFromInstalledApps(
          AppStoreService.instance.installedApps,
        );
        AppStoreService.instance.addListener(() {
          AppExtensionRegistry.instance.loadFromInstalledApps(
            AppStoreService.instance.installedApps,
          );
        });
      }),
    );
    widget.session.bootstrap();
    unawaited(_loadInstalledVersionInfo());
    unawaited(_startIntegrationsBridge());
    _initDesktopIntegration();
    _launchArgsSub = PlatformLaunchArguments.launchArguments().listen((args) {
      unawaited(_handleLaunchArguments(args, focusWindow: false));
    });
    unawaited(_handleInitialLaunchArgs());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_checkForUpdatesOnStartup());
    });
    unawaited(_maybeOpenReleaseNotesPage());
    _scheduledVaultBackupTimer = Timer.periodic(
      const Duration(minutes: 15),
      (_) => unawaited(_maybeRunScheduledVaultBackup()),
    );
    unawaited(_maybeRunScheduledVaultBackup());
    unawaited(_initPlatformNotifications());
    _accentSub = SystemTheme.onChange.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    FolioDiagnosticReporter.bindAppSettings(null);
    _reminderSub?.cancel();
    _taskReminderService?.dispose();
    _scheduledVaultBackupTimer?.cancel();
    _launchArgsSub?.cancel();
    _accentSub?.cancel();
    unawaited(_integrationsBridge.dispose());
    widget.session.onSyncConflictCountChanged = null;
    widget.session.onPersisted = null;
    _deviceSyncController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_desktop?.dispose());
    widget.cloudAccountController.dispose();
    _folioCloudEntitlements.removeListener(_onFolioCloudEntitlements);
    _folioCloudEntitlementsInstance?.dispose();
    widget.appSettings.removeListener(_onSettings);
    widget.session.removeListener(_onSession);
    super.dispose();
  }

  void _onSession() {
    final nextVault = widget.session.state;
    if (_lastVaultFlowForTelemetry != nextVault) {
      if (_lastVaultFlowForTelemetry != null) {
        unawaited(
          FolioTelemetry.logNavigation(
            widget.appSettings,
            _vaultTelemetryScreen(_lastVaultFlowForTelemetry!),
            _vaultTelemetryScreen(nextVault),
          ),
        );
      }
      _lastVaultFlowForTelemetry = nextVault;
    }
    if (widget.session.state == VaultFlowState.locked) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final nav = _navKey.currentState;
        if (nav == null || !nav.mounted) return;
        while (nav.canPop()) {
          nav.pop();
        }
      });
    }
    unawaited(_maybeOpenReleaseNotesPage());
    if (mounted) setState(() {});
  }

  Future<void> _openReleaseNotesForUser(BuildContext context) async {
    try {
      final info = await PackageInfo.fromPlatform();
      final appVersion = info.version.trim();
      final buildNumber = info.buildNumber.trim();
      if (appVersion.isEmpty) return;
      final versionLabel = buildNumber.isEmpty
          ? appVersion
          : '$appVersion+$buildNumber';
      final updater = GitHubReleaseUpdater(
        owner: widget.appSettings.updaterGithubOwner,
        repo: widget.appSettings.updaterGithubRepo,
      );
      ReleaseNotesResult? release;
      try {
        release = await updater.fetchReleaseNotesForVersion(
          appVersion: appVersion,
          buildNumber: buildNumber,
        );
      } catch (_) {
        release = null;
      }
      if (!context.mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (ctx) => ReleaseNotesPage(
            versionLabel: versionLabel,
            releaseTitle: release?.releaseName,
            releaseNotes: release?.releaseNotes ?? '',
            publishedAt: release?.publishedAt,
            tagName: release?.tagName,
          ),
          settings: const RouteSettings(name: 'release_notes'),
        ),
      );
      await widget.appSettings.setLastSeenReleaseNotesVersion(versionLabel);
    } catch (_) {}
  }

  Future<void> _maybeOpenReleaseNotesPage() async {
    if (_releaseNotesCheckInProgress || _releaseNotesShownThisRun) return;
    _releaseNotesCheckInProgress = true;
    try {
      if (!mounted) return;
      if (_updateDialogShown) return;
      if (widget.session.state != VaultFlowState.unlocked) return;
      final nav = _navKey.currentState;
      final ctx = _navKey.currentContext;
      if (nav == null || !nav.mounted || ctx == null || !ctx.mounted) return;
      if (nav.canPop()) return;

      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      final appVersion = info.version.trim();
      final buildNumber = info.buildNumber.trim();
      if (appVersion.isEmpty) return;
      final versionLabel = buildNumber.isEmpty
          ? appVersion
          : '$appVersion+$buildNumber';
      final lastSeen = widget.appSettings.lastSeenReleaseNotesVersion.trim();

      // Inicializa el marcador en instalaciones nuevas para no abrir en el primer arranque.
      if (lastSeen.isEmpty) {
        await widget.appSettings.setLastSeenReleaseNotesVersion(versionLabel);
        return;
      }
      if (lastSeen == versionLabel) return;

      final updater = GitHubReleaseUpdater(
        owner: widget.appSettings.updaterGithubOwner,
        repo: widget.appSettings.updaterGithubRepo,
      );
      ReleaseNotesResult? release;
      try {
        release = await updater.fetchReleaseNotesForVersion(
          appVersion: appVersion,
          buildNumber: buildNumber,
        );
      } catch (_) {
        release = null;
      }
      if (!mounted) return;
      if (_updateDialogShown) return;
      if (widget.session.state != VaultFlowState.unlocked) return;
      final safeNav = _navKey.currentState;
      if (safeNav == null || !safeNav.mounted || safeNav.canPop()) return;

      _releaseNotesShownThisRun = true;
      await safeNav.push(
        MaterialPageRoute<void>(
          builder: (context) {
            return ReleaseNotesPage(
              versionLabel: versionLabel,
              releaseTitle: release?.releaseName,
              releaseNotes: release?.releaseNotes ?? '',
              publishedAt: release?.publishedAt,
              tagName: release?.tagName,
            );
          },
          settings: const RouteSettings(name: 'release_notes'),
        ),
      );
      await widget.appSettings.setLastSeenReleaseNotesVersion(versionLabel);
    } finally {
      _releaseNotesCheckInProgress = false;
    }
  }

  void _showSnack(String message) {
    final ctx = _navKey.currentContext;
    if (ctx == null || message.trim().isEmpty) return;
    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _initPlatformNotifications() async {
    await PlatformNotificationService.init();
    _taskReminderService = TaskReminderService(session: widget.session);
    _reminderSub = _taskReminderService!.stream.listen(_onReminderEvents);
    _taskReminderService!.start();
  }

  void _onReminderEvents(List<TaskReminderEvent> events) {
    if (!widget.appSettings.windowsNotificationsEnabled) return;
    if (!PlatformNotificationService.supported) return;
    final lang = widget.appSettings.locale?.languageCode ?? 'es';
    for (final event in events) {
      final id = event.blockId.hashCode.abs() % 65535;
      final title = switch (lang) {
        'en' => event.isOverdue ? 'Overdue task' : 'Task due today',
        'ca' => event.isOverdue ? 'Tasca vençuda' : 'Tasca per avui',
        'pt' => event.isOverdue ? 'Tarefa vencida' : 'Tarefa para hoje',
        'gl' => event.isOverdue ? 'Tarefa vencida' : 'Tarefa para hoxe',
        'eu' =>
          event.isOverdue ? 'Epemuga igarotako zeregina' : 'Gaurko zeregina',
        _ => event.isOverdue ? 'Tarea vencida' : 'Tarea para hoy',
      };
      final body = '${event.pageTitle}: ${event.taskTitle}';
      unawaited(
        PlatformNotificationService.show(id: id, title: title, body: body),
      );
    }
  }

  Future<void> _maybeRunScheduledVaultBackup() async {
    if (!mounted) return;
    if (widget.session.state != VaultFlowState.unlocked) return;
    final vaultId = widget.session.activeVaultId ?? '';
    final prefs = await widget.appSettings.getVaultBackupPrefs(
      vaultId.isEmpty ? null : vaultId,
    );
    if (!prefs.enabled) return;
    final canCloud =
        Firebase.apps.isNotEmpty &&
        FirebaseAuth.instance.currentUser != null &&
        _folioCloudEntitlements.snapshot.canUseCloudBackup;
    final willDoFolder = prefs.folderEnabled && prefs.directory.isNotEmpty;
    final willDoCloud = prefs.alsoCloud && canCloud;
    if (!willDoFolder && !willDoCloud) return;
    final intervalMs = prefs.intervalMinutes * 60 * 1000;
    final now = DateTime.now().millisecondsSinceEpoch;
    final last = prefs.lastMs;
    if (last > 0 && now - last < intervalMs) return;
    try {
      await runScheduledFolderVaultExport(
        session: widget.session,
        appSettings: widget.appSettings,
        vaultId: vaultId.isEmpty ? null : vaultId,
        folioEntitlements: _folioCloudEntitlements,
      );
      final okCtx = _navKey.currentContext;
      if (okCtx == null || !okCtx.mounted) return;
      _showSnack(AppLocalizations.of(okCtx).scheduledVaultBackupSnackOk);
    } on VaultBackupException catch (e) {
      final errCtx = _navKey.currentContext;
      if (errCtx == null || !errCtx.mounted) return;
      _showSnack(
        AppLocalizations.of(errCtx).scheduledVaultBackupSnackFail('$e'),
      );
    } catch (e) {
      final errCtx = _navKey.currentContext;
      if (errCtx == null || !errCtx.mounted) return;
      _showSnack(
        AppLocalizations.of(errCtx).scheduledVaultBackupSnackFail('$e'),
      );
    }
  }

  Future<List<int>?> _exportSyncSnapshot() {
    return widget.session.exportSyncSnapshotBytes();
  }

  String _vaultTelemetryScreen(VaultFlowState s) {
    switch (s) {
      case VaultFlowState.initializing:
        return 'vault_initializing';
      case VaultFlowState.needsOnboarding:
        return 'vault_onboarding';
      case VaultFlowState.locked:
        return 'vault_locked';
      case VaultFlowState.unlocked:
        return 'workspace';
    }
  }

  Future<bool> _importSyncSnapshot(List<int> snapshot, String _) async {
    final sw = Stopwatch()..start();
    try {
      final ok = await widget.session.applySyncSnapshotBytes(snapshot);
      unawaited(
        FolioTelemetry.logSyncEvent(
          widget.appSettings,
          'device_lan_import',
          ok,
          durationMs: sw.elapsedMilliseconds,
        ),
      );
      return ok;
    } catch (e) {
      unawaited(
        FolioTelemetry.logSyncEvent(
          widget.appSettings,
          'device_lan_import',
          false,
          errorMessage: '$e',
          durationMs: sw.elapsedMilliseconds,
        ),
      );
      rethrow;
    }
  }

  void _showIncomingPairRequestDialog(IncomingPairRequest request) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctx = _navKey.currentContext;
      if (ctx == null) return;
      final isEs = widget.appSettings.locale?.languageCode == 'es';
      final who = request.trimmedRequesterName.isEmpty
          ? (isEs ? 'Otro dispositivo' : 'Another device')
          : request.trimmedRequesterName;
      final emojis = request.sharedEmojis.join(' ');
      showDialog<void>(
        context: ctx,
        barrierDismissible: false,
        builder: (dialogCtx) {
          return AlertDialog(
            title: Text(isEs ? 'Solicitud de vinculacion' : 'Link request'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEs
                      ? '$who quiere enlazar este dispositivo.'
                      : '$who wants to link this device.',
                ),
                if (emojis.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  SelectableText(
                    emojis,
                    style: Theme.of(dialogCtx).textTheme.headlineMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isEs
                        ? '¿Aparecen estos mismos 3 emojis en el otro dispositivo? Si coinciden, pulsa Vincular.'
                        : 'Do these same 3 emojis appear on the other device? If they match, press Link.',
                  ),
                ] else ...[
                  const SizedBox(height: 12),
                  Text(
                    isEs
                        ? 'No se pudo calcular la coincidencia visual. Activa el modo vinculacion en ambos dispositivos y vuelve a intentarlo.'
                        : 'Could not calculate the visual match. Enable pairing mode on both devices and try again.',
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(dialogCtx).pop();
                  unawaited(_deviceSyncController.respondIncomingPair(false));
                },
                child: Text(isEs ? 'No coinciden' : 'No match'),
              ),
              FilledButton(
                onPressed: () async {
                  Navigator.of(dialogCtx).pop();
                  final verifyCtx = _navKey.currentContext;
                  if (verifyCtx == null || !mounted) {
                    unawaited(_deviceSyncController.respondIncomingPair(false));
                    return;
                  }
                  final ok = await showDialog<bool>(
                    context: verifyCtx,
                    barrierDismissible: false,
                    builder: (vctx) => VaultIdentityVerifyDialog(
                      session: widget.session,
                      quickEnabled: false,
                      passkeyRegistered: false,
                      title: Text(
                        isEs ? 'Confirmar identidad' : 'Confirm identity',
                      ),
                      body: Text(
                        isEs
                            ? 'Introduce la contraseña de la libreta para aceptar la vinculación con otro dispositivo.'
                            : 'Enter your vault password to accept linking with another device.',
                      ),
                      passwordButtonLabel: isEs ? 'Verificar' : 'Verify',
                    ),
                  );
                  if (!mounted) return;
                  unawaited(
                    _deviceSyncController.respondIncomingPair(ok == true),
                  );
                },
                child: Text(isEs ? 'Vincular' : 'Link'),
              ),
            ],
          );
        },
      );
    });
  }

  Future<void> _loadInstalledVersionInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() {
        _installedVersionLabel = '${info.version}+${info.buildNumber}';
      });
    } catch (_) {
      _installedVersionLabel ??= 'unknown';
    }
  }

  Future<void> _startIntegrationsBridge() async {
    if (defaultTargetPlatform == TargetPlatform.android) return;
    try {
      await _integrationsBridge.start();
    } catch (e) {
      _showSnack('No se pudo iniciar el bridge de integraciones: $e');
    }
  }

  void _onFolioCloudEntitlements() {
    _applyAiSettings();
    if (mounted) setState(() {});
  }

  void _onSettings() {
    widget.session.titleLocale = widget.appSettings.locale;
    _applySessionSecurityPolicy();
    _applyAiSettings();
    _applyDeviceSyncSettings();
    _applyDesktopSettingsIfNeeded();
    FolioDiagnosticReporter.bindAppSettings(widget.appSettings);
    unawaited(FolioTelemetry.onSettingsChanged(widget.appSettings));
    if (mounted) setState(() {});
  }

  void _applyDeviceSyncSettings() {
    _deviceSyncController.refreshSettingsSnapshot();
  }

  void _applySessionSecurityPolicy() {
    widget.session.applySecurityPolicy(
      idleLockMinutes: widget.appSettings.vaultIdleLockMinutes,
      lockOnAppBackground: widget.appSettings.vaultLockOnMinimize,
    );
  }

  void _onGlobalUserActivity() {
    widget.session.touchActivity();
  }

  bool _hasEditableTextFocus() {
    final ctx = FocusManager.instance.primaryFocus?.context;
    if (ctx == null) return false;
    return ctx.widget is EditableText ||
        ctx.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  Future<void> _adjustUiScaleBy(double delta) async {
    if (_hasEditableTextFocus()) return;
    if (widget.appSettings.uiScaleMode != UiScaleMode.manual) {
      await widget.appSettings.setUiScaleMode(UiScaleMode.manual);
    }
    await widget.appSettings.setUiScale(widget.appSettings.uiScale + delta);
  }

  Future<void> _resetUiScale() async {
    if (_hasEditableTextFocus()) return;
    if (widget.appSettings.uiScaleMode != UiScaleMode.manual) {
      await widget.appSettings.setUiScaleMode(UiScaleMode.manual);
    }
    await widget.appSettings.setUiScale(AppSettings.defaultUiScale);
  }

  String _buildDesktopSettingsSignature() {
    final s = widget.appSettings;
    return [
      s.enableGlobalSearchHotkey ? '1' : '0',
      s.globalSearchHotkey,
      s.minimizeToTray ? '1' : '0',
      s.closeToTray ? '1' : '0',
    ].join('|');
  }

  void _applyDesktopSettingsIfNeeded() {
    final next = _buildDesktopSettingsSignature();
    if (next == _desktopSettingsSignature) return;
    _desktopSettingsSignature = next;
    unawaited(_desktop?.applySettings());
  }

  void _maybeLaunchAiProvider() {
    if (!aiLocalProvidersSupported) return;
    final s = widget.appSettings;
    if (!s.aiLaunchProviderWithApp) return;
    if (!s.isAiRuntimeEnabled) return;
    if (s.aiProvider == AiProvider.none) return;
    final uri = AiSafetyPolicy.parseAndNormalizeUrl(s.aiBaseUrl);
    if (uri == null || !AiSafetyPolicy.isLocalhostHost(uri.host)) return;
    unawaited(AiProviderLauncher.tryLaunchProvider(s.aiProvider));
  }

  void _applyAiSettings() {
    if (!aiLocalProvidersSupported) {
      if (!widget.appSettings.isAiRuntimeEnabled) {
        widget.session.setAiService(null);
        return;
      }
      if (widget.appSettings.aiProvider == AiProvider.quillCloud) {
        if (_folioCloudEntitlements.snapshot.canUseCloudAi) {
          widget.session.setAiService(
            FolioCloudAiService(entitlements: _folioCloudEntitlements),
          );
        } else {
          widget.session.setAiService(null);
        }
        return;
      }
      widget.session.setAiService(null);
      return;
    }
    if (!widget.appSettings.isAiRuntimeEnabled) {
      widget.session.setAiService(null);
      return;
    }
    switch (widget.appSettings.aiProvider) {
      case AiProvider.none:
        widget.session.setAiService(null);
        return;
      case AiProvider.quillCloud:
        if (!_folioCloudEntitlements.snapshot.canUseCloudAi) {
          widget.session.setAiService(null);
          return;
        }
        widget.session.setAiService(
          FolioCloudAiService(entitlements: _folioCloudEntitlements),
        );
        return;
      case AiProvider.ollama:
      case AiProvider.lmStudio:
        break;
    }
    final endpointError = AiSafetyPolicy.validateEndpointIssue(
      rawUrl: widget.appSettings.aiBaseUrl,
      mode: widget.appSettings.aiEndpointMode,
      remoteConfirmed: widget.appSettings.aiRemoteEndpointConfirmed,
    );
    if (endpointError != null) {
      widget.session.setAiService(null);
      return;
    }
    final uri = AiSafetyPolicy.parseAndNormalizeUrl(
      widget.appSettings.aiBaseUrl,
    );
    if (uri == null) {
      widget.session.setAiService(null);
      return;
    }
    final timeout = Duration(milliseconds: widget.appSettings.aiTimeoutMs);
    switch (widget.appSettings.aiProvider) {
      case AiProvider.ollama:
        widget.session.setAiService(
          OllamaAiService(
            baseUrl: uri,
            timeout: timeout,
            defaultModel: widget.appSettings.aiModel,
          ),
        );
        break;
      case AiProvider.lmStudio:
        widget.session.setAiService(
          LmStudioAiService(
            baseUrl: uri,
            timeout: timeout,
            defaultModel: widget.appSettings.aiModel,
          ),
        );
        break;
      case AiProvider.none:
      case AiProvider.quillCloud:
        break;
    }
  }

  Future<void> _initDesktopIntegration() async {
    final desktop = DesktopIntegration(
      settings: widget.appSettings,
      onOpenRequested: _handleOpenRequested,
      onSearchRequested: _handleSearchRequested,
      onLockRequested: _handleLockRequested,
      onExitRequested: _handleExitRequested,
      labelsBuilder: _desktopLabels,
    );
    _desktop = desktop;
    await desktop.initialize();
    _desktopSettingsSignature = _buildDesktopSettingsSignature();
  }

  Future<void> _handleOpenRequested() async {
    await _desktop?.showAndFocus();
  }

  DesktopTrayLabels _desktopLabels() {
    final ctx = _navKey.currentContext;
    if (ctx == null) {
      return const DesktopTrayLabels(
        open: 'Open',
        search: 'Search',
        lock: 'Lock',
        exit: 'Exit',
      );
    }
    final l10n = AppLocalizations.of(ctx);
    return DesktopTrayLabels(
      open: l10n.open,
      search: l10n.search,
      lock: l10n.lockNow,
      exit: l10n.trayMenuCloseApplication,
    );
  }

  Future<void> _handleSearchRequested([String? initialQuery]) async {
    if (_openingByHotkey) return;
    _openingByHotkey = true;
    try {
      await _desktop?.showAndFocus();
      if (!mounted) return;
      if (widget.session.state == VaultFlowState.locked) {
        final unlocked = await showDialog<bool>(
          context: _navKey.currentContext ?? context,
          barrierDismissible: true,
          builder: (ctx) => MiniUnlockDialog(session: widget.session),
        );
        if (unlocked != true) return;
      }
      if (!mounted || widget.session.state != VaultFlowState.unlocked) return;
      unawaited(
        FolioTelemetry.logFeatureUsed(widget.appSettings, 'global_search'),
      );
      final q = initialQuery?.trim();
      await showDialog<bool>(
        context: _navKey.currentContext ?? context,
        barrierDismissible: true,
        builder: (ctx) => GlobalSearchPopup(
          session: widget.session,
          appSettings: widget.appSettings,
          initialQuery: (q == null || q.isEmpty) ? null : q,
        ),
      );
    } finally {
      _openingByHotkey = false;
    }
  }

  Future<void> _handleLockRequested() async {
    await widget.session.lock();
  }

  Future<void> _handleExitRequested() async {
    await SystemNavigator.pop();
  }

  Future<FolioMarkdownImportResult> _importIntegrationsMarkdown(
    IntegrationsMarkdownImportRequest request,
  ) async {
    return widget.session.importMarkdownDocument(
      request.markdown,
      title: request.title,
      parentId: request.parentPageId,
      sourceApp: request.sourceApp,
      sourceUrl: request.sourceUrl,
      clientAppId: request.clientAppId,
      clientAppName: request.clientAppName,
      sessionId: request.sessionId,
      metadata: request.metadata,
      mode: request.importMode,
    );
  }

  Future<FolioMarkdownImportResult> _updateIntegrationsPage(
    IntegrationsPageUpdateRequest request,
  ) async {
    if (request.isJsonMode) {
      final blocks = request.blocks!
          .map((b) => FolioBlock.fromJson(b))
          .toList();
      return widget.session.updatePageBlocks(
        request.pageId,
        blocks,
        title: request.title,
        sourceApp: request.sourceApp,
        sourceUrl: request.sourceUrl,
        clientAppId: request.clientAppId,
        clientAppName: request.clientAppName,
        sessionId: request.sessionId,
        metadata: request.metadata,
        mode: request.importMode,
      );
    }
    return widget.session.updatePageContent(
      request.pageId,
      request.markdown,
      title: request.title,
      sourceApp: request.sourceApp,
      sourceUrl: request.sourceUrl,
      clientAppId: request.clientAppId,
      clientAppName: request.clientAppName,
      sessionId: request.sessionId,
      metadata: request.metadata,
      mode: request.importMode,
    );
  }

  Future<List<Map<String, Object?>>> _listIntegrationsPages(
    String clientAppId,
  ) async {
    return widget.session.listPagesByApp(clientAppId);
  }

  Future<FolioMarkdownImportResult> _importIntegrationsJson(
    IntegrationsJsonImportRequest request,
  ) async {
    final blocks = request.blocks.map((b) => FolioBlock.fromJson(b)).toList();
    return widget.session.importBlocksDocument(
      request.title,
      blocks,
      parentId: request.parentPageId,
      sourceApp: request.sourceApp,
      sourceUrl: request.sourceUrl,
      clientAppId: request.clientAppId,
      clientAppName: request.clientAppName,
      sessionId: request.sessionId,
      metadata: request.metadata,
    );
  }

  Future<List<Map<String, Object?>>> _listIntegrationsCustomEmojis(
    String clientAppId,
  ) async {
    return widget.appSettings
        .integrationCustomIconsForApp(clientAppId)
        .map((entry) => entry.toJson())
        .toList(growable: false);
  }

  Future<void> _replaceIntegrationsCustomEmojis(
    String clientAppId,
    List<Map<String, Object?>> items,
  ) async {
    final entries = items
        .map((item) => CustomIconEntry.fromJson(item))
        .toList(growable: false);
    await widget.appSettings.replaceIntegrationCustomIconsForApp(
      clientAppId,
      entries,
    );
  }

  Future<Map<String, Object?>> _upsertIntegrationsCustomEmoji(
    IntegrationsCustomEmojiUpsertRequest request,
  ) async {
    final createdAtMs = request.createdAtMs > 0
        ? request.createdAtMs
        : DateTime.now().millisecondsSinceEpoch;
    final entry = CustomIconEntry(
      id: request.emojiId,
      label: request.label,
      source: request.source,
      filePath: request.filePath,
      mimeType: request.mimeType,
      createdAtMs: createdAtMs,
    );
    await widget.appSettings.addOrUpdateIntegrationCustomIconForApp(
      request.clientAppId,
      entry,
    );
    return entry.toJson();
  }

  Future<void> _deleteIntegrationsCustomEmoji(
    IntegrationsCustomEmojiDeleteRequest request,
  ) {
    return widget.appSettings.removeIntegrationCustomIconForApp(
      request.clientAppId,
      request.emojiId,
    );
  }

  Future<bool> _approveIntegrationsClient(
    IntegrationsClientIdentity client,
  ) async {
    if (widget.appSettings.isIntegrationAppApproved(
      client.appId,
      integrationVersion: client.integrationVersion,
    )) {
      return true;
    }
    final ctx = _navKey.currentContext ?? context;
    final previousApproval = widget.appSettings.integrationAppApproval(
      client.appId,
    );
    final approved = await showDialog<bool>(
      context: ctx,
      barrierDismissible: false,
      builder: (dialogContext) => _IntegrationApprovalDialog(
        client: client,
        previousApproval: previousApproval,
      ),
    );
    if (approved == true) {
      await widget.appSettings.approveIntegrationApp(
        appId: client.appId,
        appName: client.appName,
        appVersion: client.appVersion,
        integrationVersion: client.integrationVersion,
      );
      return true;
    }
    return false;
  }

  Future<void> _syncObservedIntegrationsClient(
    IntegrationsClientIdentity client,
  ) {
    return widget.appSettings.syncApprovedIntegrationAppObservation(
      appId: client.appId,
      appName: client.appName,
      appVersion: client.appVersion,
      integrationVersion: client.integrationVersion,
    );
  }

  Map<String, Object?> _integrationsAppInfo() {
    final page = widget.session.selectedPage;
    final activeSession = _integrationsBridge.activeSession;
    return <String, Object?>{
      'name': 'Folio',
      'version': _installedVersionLabel ?? 'unknown',
      'platform': 'windows',
      'state': widget.session.state.name,
      'isUnlocked': widget.session.isUnlocked,
      'vaultUsesEncryption': widget.session.vaultUsesEncryption,
      'activeVaultId': widget.session.activeVaultId,
      'selectedPage': page == null
          ? null
          : <String, Object?>{
              'id': page.id,
              'title': page.title,
              'blockCount': page.blocks.length,
              'lastImportInfo': page.lastImportInfo?.toJson(),
            },
      'aiEnabled': widget.session.aiEnabled,
      'bridgePort': IntegrationsLaunchSession.fixedPort,
      'approvedClients': widget.appSettings.approvedIntegrationAppApprovals
          .map(
            (entry) => <String, Object?>{
              'appId': entry.appId,
              'appName': entry.appName,
              'appVersion': entry.appVersion,
              'integrationVersion': entry.integrationVersion,
              'approvedAtMs': entry.approvedAtMs,
            },
          )
          .toList(),
      'importSession': activeSession == null
          ? null
          : <String, Object?>{
              'sessionId': activeSession.sessionId,
              'port': activeSession.port,
              'clientAppId': activeSession.client.appId,
              'clientAppName': activeSession.client.appName,
              'clientAppVersion': activeSession.client.appVersion,
              'integrationVersion': activeSession.client.integrationVersion,
            },
      'timestampUtc': DateTime.now().toUtc().toIso8601String(),
    };
  }

  Future<void> _handleInitialLaunchArgs() async {
    if (_handledInitialLaunchArgs) return;
    _handledInitialLaunchArgs = true;
    if (kIsWeb ||
        defaultTargetPlatform != TargetPlatform.windows ||
        widget.initialLaunchArgs.isEmpty) {
      return;
    }
    await _handleLaunchArguments(widget.initialLaunchArgs, focusWindow: true);
  }

  Future<void> _handleLaunchArguments(
    List<String> args, {
    required bool focusWindow,
  }) async {
    final launchUri = PlatformLaunchArguments.firstUriWithScheme(args, 'folio');
    if (launchUri == null) return;
    try {
      await _integrationsBridge.activateFromUri(launchUri);
      if (focusWindow) {
        await _desktop?.showAndFocus();
      }
    } catch (e) {
      _showSnack('No se pudo activar la integración: $e');
    }
  }

  Future<void> _checkForUpdatesOnStartup() async {
    if (!widget.appSettings.checkUpdatesOnStartup) return;
    final navCtx = _navKey.currentContext;
    if (navCtx == null || !navCtx.mounted) return;
    final l10n = AppLocalizations.of(navCtx);
    final updater = GitHubReleaseUpdater(
      owner: widget.appSettings.updaterGithubOwner,
      repo: widget.appSettings.updaterGithubRepo,
    );
    try {
      final result = await updater.checkForUpdate(
        channel: widget.appSettings.updateReleaseChannel,
      );
      if (!mounted || !result.hasUpdate || _updateDialogShown) return;
      final dialogCtx = _navKey.currentContext;
      if (dialogCtx == null || !dialogCtx.mounted) return;
      _updateDialogShown = true;
      final betaNote = result.isPrerelease
          ? '\n\n${l10n.updaterStartupDialogBetaNote}'
          : '';
      final shouldInstall = await showDialog<bool>(
        context: dialogCtx,
        builder: (ctx) {
          return AlertDialog(
            title: Text(
              result.isPrerelease
                  ? l10n.updaterStartupDialogTitleBeta
                  : l10n.updaterStartupDialogTitleStable,
            ),
            content: Text(
              '${l10n.updaterStartupDialogBody(result.releaseVersion.toString())}$betaNote\n\n'
              '${defaultTargetPlatform == TargetPlatform.android ? l10n.updaterOpenApkDownloadQuestion : l10n.updaterStartupDialogQuestion}',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(l10n.updaterStartupDialogLater),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(l10n.updaterStartupDialogUpdateNow),
              ),
            ],
          );
        },
      );
      if (shouldInstall == true) {
        if (defaultTargetPlatform == TargetPlatform.android) {
          final raw = result.installerUrl ?? '';
          final uri = Uri.tryParse(raw);
          if (uri == null) return;
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          return;
        }
        final installer = await updater.downloadInstaller(result);
        await updater.launchInstallerAndExit(installer);
      }
    } catch (_) {
      // No interrumpir el arranque si falla el chequeo.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_maybeRunScheduledVaultBackup());
      unawaited(_folioCloudEntitlements.handleAppResumed());
    }
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      widget.session.onAppBackgrounded();
      if (widget.appSettings.minimizeToTray) {
        unawaited(_desktop?.hideToTray());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final seed = widget.appSettings.resolveAccentSeedColor();
    return MaterialApp(
      navigatorKey: _navKey,
      navigatorObservers: [_telemetryNavObserver],
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      theme: folioLightTheme(seed),
      darkTheme: folioDarkTheme(seed),
      themeMode: widget.appSettings.themeMode,
      locale: widget.appSettings.locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        final media = MediaQuery.of(context);
        final uiScale = widget.appSettings.resolveEffectiveUiScale(
          isWindows: !kIsWeb && defaultTargetPlatform == TargetPlatform.windows,
          devicePixelRatio: media.devicePixelRatio,
        );
        Widget content = child ?? const SizedBox.shrink();
        if ((uiScale - 1.0).abs() > 0.001) {
          content = ClipRect(
            child: OverflowBox(
              alignment: Alignment.topLeft,
              minWidth: 0,
              minHeight: 0,
              maxWidth: double.infinity,
              maxHeight: double.infinity,
              child: Transform.scale(
                alignment: Alignment.topLeft,
                scale: uiScale,
                child: SizedBox(
                  width: media.size.width / uiScale,
                  height: media.size.height / uiScale,
                  child: content,
                ),
              ),
            ),
          );
        }
        return Shortcuts(
          shortcuts: const <ShortcutActivator, Intent>{
            SingleActivator(LogicalKeyboardKey.equal, control: true):
                _ZoomInIntent(),
            SingleActivator(LogicalKeyboardKey.numpadAdd, control: true):
                _ZoomInIntent(),
            SingleActivator(LogicalKeyboardKey.minus, control: true):
                _ZoomOutIntent(),
            SingleActivator(LogicalKeyboardKey.numpadSubtract, control: true):
                _ZoomOutIntent(),
            SingleActivator(LogicalKeyboardKey.digit0, control: true):
                _ZoomResetIntent(),
            SingleActivator(LogicalKeyboardKey.numpad0, control: true):
                _ZoomResetIntent(),
          },
          child: Actions(
            actions: <Type, Action<Intent>>{
              _ZoomInIntent: CallbackAction<_ZoomInIntent>(
                onInvoke: (_) {
                  unawaited(_adjustUiScaleBy(0.05));
                  return null;
                },
              ),
              _ZoomOutIntent: CallbackAction<_ZoomOutIntent>(
                onInvoke: (_) {
                  unawaited(_adjustUiScaleBy(-0.05));
                  return null;
                },
              ),
              _ZoomResetIntent: CallbackAction<_ZoomResetIntent>(
                onInvoke: (_) {
                  unawaited(_resetUiScale());
                  return null;
                },
              ),
            },
            child: Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (_) => _onGlobalUserActivity(),
              onPointerSignal: (_) => _onGlobalUserActivity(),
              onPointerPanZoomStart: (_) => _onGlobalUserActivity(),
              child: content,
            ),
          ),
        );
      },
      home: _HomeByState(
        session: widget.session,
        appSettings: widget.appSettings,
        deviceSyncController: _deviceSyncController,
        cloudAccountController: widget.cloudAccountController,
        folioCloudEntitlements: _folioCloudEntitlements,
        onOpenSearch: _handleSearchRequested,
        onOpenReleaseNotes: _openReleaseNotesForUser,
      ),
    );
  }
}

class _ZoomInIntent extends Intent {
  const _ZoomInIntent();
}

class _ZoomOutIntent extends Intent {
  const _ZoomOutIntent();
}

class _ZoomResetIntent extends Intent {
  const _ZoomResetIntent();
}

class _IntegrationApprovalDialog extends StatelessWidget {
  const _IntegrationApprovalDialog({
    required this.client,
    required this.previousApproval,
  });

  final IntegrationsClientIdentity client;
  final IntegrationAppApproval? previousApproval;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = Theme.of(context).colorScheme;
    final isUpdate =
        previousApproval != null &&
        (previousApproval?.integrationVersion.trim() ?? '') !=
            client.integrationVersion;
    final previousVersion =
        (previousApproval?.integrationVersion.trim() ?? '').isEmpty
        ? l10n.integrationApprovalUnknownVersion
        : previousApproval!.integrationVersion.trim();
    final isEncryptedContent =
        client.integrationVersion.trim() ==
        IntegrationsBridgeController.supportedIntegrationVersion;
    final appVersion = client.appVersion.trim().isEmpty
        ? l10n.integrationApprovalUnknownVersion
        : client.appVersion.trim();

    Widget capabilityRow(
      IconData icon,
      String title,
      String description, {
      required Color accent,
      bool danger = false,
    }) {
      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: danger
              ? scheme.errorContainer.withValues(alpha: 0.24)
              : scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(FolioRadius.lg),
          border: Border.all(
            color: danger
                ? scheme.error.withValues(alpha: 0.18)
                : scheme.outlineVariant.withValues(alpha: 0.45),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(FolioRadius.md),
              ),
              child: Icon(icon, size: 18, color: accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
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

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      content: SizedBox(
        width: 640,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      scheme.secondaryContainer.withValues(alpha: 0.7),
                      scheme.surfaceContainerHigh,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(FolioRadius.xl),
                  border: Border.all(
                    color: scheme.outlineVariant.withValues(alpha: 0.45),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: scheme.surface,
                            borderRadius: BorderRadius.circular(FolioRadius.lg),
                          ),
                          child: Icon(
                            isUpdate
                                ? Icons.system_update_alt_rounded
                                : Icons.hub_rounded,
                            color: scheme.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isUpdate
                                    ? l10n.integrationDialogTitleUpdatePermission
                                    : l10n.integrationDialogTitleAllowConnect,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                isUpdate
                                    ? l10n.integrationDialogBodyUpdate(
                                        previousVersion,
                                        client.integrationVersion,
                                      )
                                    : l10n.integrationDialogBodyNew(
                                        client.appName,
                                        appVersion,
                                        client.integrationVersion,
                                      ),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _IntegrationApprovalChip(
                          icon: Icons.laptop_windows_rounded,
                          label: l10n.integrationChipLocalhostOnly,
                        ),
                        _IntegrationApprovalChip(
                          icon: Icons.verified_user_outlined,
                          label: l10n.integrationChipRevocableApproval,
                        ),
                        _IntegrationApprovalChip(
                          icon: Icons.key_off_outlined,
                          label: l10n.integrationChipNoSharedSecret,
                        ),
                        _IntegrationApprovalChip(
                          icon: isEncryptedContent
                              ? Icons.lock_rounded
                              : Icons.lock_open_rounded,
                          label: isEncryptedContent
                              ? l10n.integrationApprovalEncryptedChip
                              : l10n.integrationApprovalUnencryptedChip,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: scheme.outlineVariant.withValues(alpha: 0.6),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            client.appName,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: scheme.primary.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            l10n.integrationChipScopedByAppId,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: scheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _IntegrationApprovalMetaRow(
                      label: l10n.integrationApprovalAppId,
                      value: client.appId,
                    ),
                    _IntegrationApprovalMetaRow(
                      label: l10n.integrationApprovalAppVersion,
                      value: appVersion,
                    ),
                    _IntegrationApprovalMetaRow(
                      label: l10n.integrationApprovalProtocolVersion,
                      value: client.integrationVersion,
                    ),
                    if (isUpdate)
                      _IntegrationApprovalMetaRow(
                        label: l10n.integrationMetaPreviouslyApprovedVersion,
                        value: previousVersion,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.integrationSectionWhatAppCanDo,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              capabilityRow(
                Icons.playlist_add_check_circle_outlined,
                l10n.integrationCapEphemeralSessionsTitle,
                l10n.integrationCapEphemeralSessionsBody,
                accent: scheme.primary,
              ),
              capabilityRow(
                Icons.description_outlined,
                l10n.integrationCapImportPagesTitle,
                l10n.integrationCapImportPagesBody,
                accent: scheme.primary,
              ),
              capabilityRow(
                Icons.emoji_emotions_outlined,
                l10n.integrationCapCustomEmojisTitle,
                l10n.integrationCapCustomEmojisBody,
                accent: scheme.primary,
              ),
              capabilityRow(
                Icons.lock_open_outlined,
                l10n.integrationCapUnlockedVaultTitle,
                l10n.integrationCapUnlockedVaultBody,
                accent: scheme.primary,
              ),
              capabilityRow(
                isEncryptedContent
                    ? Icons.enhanced_encryption_outlined
                    : Icons.gpp_maybe_outlined,
                isEncryptedContent
                    ? l10n.integrationApprovalEncryptedTitle
                    : l10n.integrationApprovalUnencryptedTitle,
                isEncryptedContent
                    ? l10n.integrationApprovalEncryptedDescription
                    : l10n.integrationApprovalUnencryptedDescription,
                accent: isEncryptedContent ? scheme.primary : scheme.error,
                danger: !isEncryptedContent,
              ),
              const SizedBox(height: 12),
              Text(
                l10n.integrationSectionWhatStaysBlocked,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              capabilityRow(
                Icons.visibility_off_outlined,
                l10n.integrationBlockNoSeeAllTitle,
                l10n.integrationBlockNoSeeAllBody,
                accent: scheme.error,
                danger: true,
              ),
              capabilityRow(
                Icons.shield_outlined,
                l10n.integrationBlockNoBypassTitle,
                l10n.integrationBlockNoBypassBody,
                accent: scheme.error,
                danger: true,
              ),
              capabilityRow(
                Icons.apps_outage_outlined,
                l10n.integrationBlockNoOtherAppsTitle,
                l10n.integrationBlockNoOtherAppsBody,
                accent: scheme.error,
                danger: true,
              ),
              capabilityRow(
                Icons.public_off_outlined,
                l10n.integrationBlockNoRemoteTitle,
                l10n.integrationBlockNoRemoteBody,
                accent: scheme.error,
                danger: true,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l10n.integrationApprovalDeny),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(
            isUpdate
                ? l10n.integrationApprovalApproveUpdate
                : l10n.integrationApprovalApprove,
          ),
        ),
      ],
    );
  }
}

class _IntegrationApprovalChip extends StatelessWidget {
  const _IntegrationApprovalChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: scheme.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _IntegrationApprovalMetaRow extends StatelessWidget {
  const _IntegrationApprovalMetaRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 170,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurface,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeByState extends StatelessWidget {
  const _HomeByState({
    required this.session,
    required this.appSettings,
    required this.deviceSyncController,
    required this.cloudAccountController,
    required this.folioCloudEntitlements,
    required this.onOpenSearch,
    required this.onOpenReleaseNotes,
  });

  final VaultSession session;
  final AppSettings appSettings;
  final DeviceSyncController deviceSyncController;
  final CloudAccountController cloudAccountController;
  final FolioCloudEntitlementsController folioCloudEntitlements;
  final void Function([String? initialQuery]) onOpenSearch;
  final Future<void> Function(BuildContext context) onOpenReleaseNotes;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    switch (session.state) {
      case VaultFlowState.initializing:
        return Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: scheme.primary),
                const SizedBox(height: 16),
                Text(
                  l10n.loading,
                  style: textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        );
      case VaultFlowState.needsOnboarding:
        return OnboardingFlow(session: session, appSettings: appSettings);
      case VaultFlowState.locked:
        return LockScreen(session: session, appSettings: appSettings);
      case VaultFlowState.unlocked:
        return WorkspacePage(
          session: session,
          appSettings: appSettings,
          deviceSyncController: deviceSyncController,
          cloudAccountController: cloudAccountController,
          folioCloudEntitlements: folioCloudEntitlements,
          onOpenSearch: onOpenSearch,
          onOpenReleaseNotes: onOpenReleaseNotes,
        );
    }
  }
}
