import 'dart:async';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/gestures.dart'
    show kBackMouseButton, kForwardMouseButton;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:system_theme/system_theme.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/config_bootstrap.dart';
import '../config/config_store.dart';
import '../core/bootstrap/app_bootstrap.dart';
import '../core/bootstrap/bootstrap_phase.dart';
import '../layout_engine/layout_engine_controller.dart';
import '../theme_engine/theme_resolver.dart';
import 'widgets/folio_dialog.dart';
import 'widgets/folio_skeletons.dart';
import '../data/vault_backup.dart';
import '../desktop/desktop_integration.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/block.dart';
import '../services/ai/ai_provider_launcher.dart';
import '../services/ai/ai_safety_policy.dart';
import '../services/ai/folio_tool_registry.dart';
import '../services/ai/gemini_nano_ai_service.dart';
import '../services/ai/lmstudio_ai_service.dart';
import '../services/ai/ollama_ai_service.dart';
import '../services/ai/on_device_ai_bridge.dart';
import '../services/ai/openai_compatible_ai_service.dart';
import '../services/mcp/folio_mcp_server.dart';
import '../services/mcp/folio_mcp_server_status.dart';
import '../services/platform/launch_arguments.dart';
import '../services/cloud_account/cloud_account_controller.dart';
import '../services/cloud_account/organization_context_controller.dart';
import '../services/ai/folio_cloud_ai_service.dart';
import '../services/folio_cloud/folio_cloud_entitlements.dart';
import '../services/folio_cloud/folio_cloud_device_sync.dart';
import '../services/folio_cloud/folio_cloud_settings_sync.dart';
import '../services/folio_cloud/folio_cloud_status_controller.dart';
import '../services/app_logger.dart';
import '../services/folio_diagnostic_reporter.dart';
import '../services/folio_telemetry.dart';
import '../services/folio_telemetry_navigator_observer.dart';
import '../services/vault_scheduled_local_export.dart';
import '../services/tasks/task_reminder_service.dart';
import '../services/tasks/platform_notification_service.dart';
import '../features/settings/vault_identity_verify_dialog.dart';
import '../services/device_sync/device_sync_controller.dart';
import '../services/device_sync/device_sync_models.dart';
import '../services/integrations/integration_command_processor.dart';
import '../services/spotify/spotify_playback_controller.dart';
import '../services/spotify/spotify_local_device_mount.dart';
import '../services/ytmusic/ytmusic_playback_controller.dart';
import '../services/media/media_playback_router.dart';
import '../services/media/music_provider_gate.dart';
import '../services/meeting_note_posthoc_transcription_manager.dart';
import '../services/meeting_note_session_controller.dart';
import '../services/integrations/integrations_bridge.dart';
import '../services/integrations/integrations_markdown_codec.dart';
import '../services/updater/github_release_updater.dart';
import '../features/release_notes/release_notes_page.dart';
import '../features/release_notes/update_available_dialog_content.dart';
import '../features/lock/lock_screen.dart';
import '../features/onboarding/onboarding_flow.dart';
import '../features/vault/recovery_screen.dart';
import '../features/workspace/workspace.dart';
import '../session/vault_session.dart';
import 'app_settings.dart';
import 'ui_tokens.dart';

import '../services/folio_cloud/folio_cloud_identity.dart';
class FolioApp extends StatefulWidget {
  const FolioApp({
    super.key,
    required this.session,
    required this.appSettings,
    required this.cloudAccountController,
    required this.configStore,
    required this.layoutEngineController,
    this.folioCloudEntitlements,
    this.organizationContext,
    this.initialLaunchArgs = const <String>[],
  });

  final VaultSession session;
  final AppSettings appSettings;
  final CloudAccountController cloudAccountController;

  /// Sistema de personalización de UI (Fase 1 del plan): persistencia de
  /// LayoutConfig/ThemeConfig/DashboardConfig. Todavía no conectado al
  /// render del tema — eso llega en la Fase 3.
  final ConfigStore configStore;

  /// Motor de layout (Fase 2). `AppSettings.onWorkspaceSidebarWidthChanged`
  /// ya lo mantiene sincronizado con el ancho real del sidebar; el shell
  /// (`workspace_page.dart`) todavía renderiza desde `AppSettings` como
  /// antes — este controller es la fuente de verdad para futuras fases
  /// (editor visual, presets, responsive) sin haber tocado ese archivo.
  final LayoutEngineController layoutEngineController;

  /// Si es null, el estado crea uno la primera vez que hace falta (también tras hot reload).
  final FolioCloudEntitlementsController? folioCloudEntitlements;

  /// Fase 12 del roadmap de Organizations. Si es null, el estado crea uno
  /// (mismo patrón que [folioCloudEntitlements]) — sin UI todavía que lo
  /// consuma (llega en las fases 13-14).
  final OrganizationContextController? organizationContext;
  final List<String> initialLaunchArgs;

  @override
  State<FolioApp> createState() => _FolioAppState();
}

class _FolioAppState extends State<FolioApp> with WidgetsBindingObserver {
  StreamSubscription<SystemAccentColor>? _accentSub;
  StreamSubscription<List<String>>? _launchArgsSub;
  final GlobalKey<NavigatorState> _navKey = GlobalKey<NavigatorState>();
  FolioCloudEntitlementsController? _folioCloudEntitlementsInstance;
  OrganizationContextController? _organizationContextInstance;
  FolioMcpServer? _mcpServer;
  Future<void>? _mcpServerApplyInFlight;

  /// Inicialización perezosa: tras hot reload [initState] no se vuelve a llamar y un `late final` fallaría.
  FolioCloudEntitlementsController get _folioCloudEntitlements {
    _folioCloudEntitlementsInstance ??=
        widget.folioCloudEntitlements ?? FolioCloudEntitlementsController();
    return _folioCloudEntitlementsInstance!;
  }

  /// Fase 12 del roadmap de Organizations — mismo patrón perezoso que [_folioCloudEntitlements].
  OrganizationContextController get _organizationContext {
    _organizationContextInstance ??= widget.organizationContext ??
        OrganizationContextController(account: widget.cloudAccountController);
    return _organizationContextInstance!;
  }

  DesktopIntegration? _desktop;
  late final IntegrationsBridgeController _integrationsBridge;
  late final DeviceSyncController _deviceSyncController;
  FolioCloudDeviceSyncController? _cloudDeviceSyncController;
  FolioCloudStatusController? _cloudStatusController;
  FolioCloudSettingsSyncController? _cloudSettingsSyncController;
  bool? _lastCloudDeviceSyncShouldRun;
  bool? _lastSettingsSyncShouldRun;
  bool _appProfileRestoreDialogShown = false;
  String? _installedVersionLabel;
  var _openingByHotkey = false;
  String _desktopSettingsSignature = '';
  bool _updateDialogShown = false;
  bool _releaseNotesCheckInProgress = false;
  /// Lifecycle Flutter: resumed vs paused/hidden/…
  bool _lifecycleActive = true;
  /// Foco de ventana OS (desktop). En móvil/web se mantiene true.
  bool _windowFocused = true;
  bool _releaseNotesShownThisRun = false;
  bool _handledInitialLaunchArgs = false;
  Timer? _scheduledVaultBackupTimer;
  Timer? _continuousVaultBackupDebounce;
  bool _continuousVaultBackupRunning = false;
  bool _continuousVaultBackupDirty = false;
  static const Duration _continuousVaultBackupDebounceDuration =
      Duration(seconds: 45);
  TaskReminderService? _taskReminderService;
  StreamSubscription<List<TaskReminderEvent>>? _reminderSub;
  late final IntegrationCommandProcessor _integrationCommandProcessor;

  late final FolioTelemetryNavigatorObserver _telemetryNavObserver;
  late final AppBootstrap _appBootstrap;
  VaultFlowState? _lastVaultFlowForTelemetry;

  Future<void> _runVaultBootstrap() async {
    final result = await _appBootstrap.runVaultPhase();
    if (!mounted) return;
    if (result.failedPhases.contains(BootstrapPhase.vaultOpen)) {
      AppLogger.warn(
        'Vault bootstrap degraded',
        tag: 'bootstrap',
        context: {'state': '${widget.session.state}'},
      );
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_runSecondaryBootstrap());
    });
  }

  Future<void> _runSecondaryBootstrap() async {
    if (!mounted) return;
    final bootstrap = _appBootstrap;
    await bootstrap.runSecondaryPhase(
      BootstrapPhase.deviceSync,
      () => _deviceSyncController.load(),
    );
    if (!mounted) return;
    _applySessionSecurityPolicy();
    // Fase 12 del roadmap de Organizations: carga best-effort, no bloquea el
    // arranque — sin UI todavía que dependa de esto.
    unawaited(_organizationContext.refresh());
    _folioCloudEntitlements.addListener(_onFolioCloudEntitlements);
    _folioCloudEntitlements.setWebPortalBaseUrlResolver(
      () => AppSettings.folioWebPortalLinkEnabled
          ? widget.appSettings.folioWebPortalBaseUrlEffective
          : '',
    );
    await bootstrap.runSecondaryPhase(
      BootstrapPhase.firebase,
      () => _folioCloudEntitlements.refreshWebPortalEntitlement(),
    );
    if (!mounted) return;
    _applyAiSettings();
    _applyDeviceSyncSettings();
    unawaited(_applyMcpServerSettings());
    _maybeLaunchAiProvider();
    await bootstrap.runSecondaryPhase(
      BootstrapPhase.desktop,
      _initDesktopIntegration,
    );
    if (!mounted) return;
    await bootstrap.runSecondaryPhase(
      BootstrapPhase.integrations,
      _startIntegrationsBridge,
    );
    if (!mounted) return;
    unawaited(_loadInstalledVersionInfo());
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
    await bootstrap.runSecondaryPhase(
      BootstrapPhase.background,
      _initPlatformNotifications,
    );
  }

  @override
  void initState() {
    super.initState();
    _appBootstrap = AppBootstrap(
      session: widget.session,
      appSettings: widget.appSettings,
    );
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
      // Sin allowedOrigins: el bridge sirve a apps nativas/CLI locales, no a
      // páginas web. Con '*' cualquier sitio abierto en el navegador del
      // usuario podía hacer fetch() al puerto fijo del bridge y disparar el
      // diálogo de aprobación con un nombre de app falsificado.
    );
    _deviceSyncController = DeviceSyncController(
      appSettings: widget.appSettings,
      onEvent: _showSnack,
      onIncomingPairRequest: _showIncomingPairRequestDialog,
      onExportSnapshot: _exportSyncSnapshot,
      onImportSnapshot: _importSyncSnapshot,
    );
    _cloudDeviceSyncController = FolioCloudDeviceSyncController(
      appSettings: widget.appSettings,
      session: widget.session,
      entitlements: _folioCloudEntitlements,
      onEvent: _showSnack,
    );
    _cloudStatusController = FolioCloudStatusController();
    _cloudStatusController!.start();
    _cloudSettingsSyncController = FolioCloudSettingsSyncController(
      appSettings: widget.appSettings,
      entitlements: _folioCloudEntitlements,
      onEvent: _showSnack,
    );
    _cloudSettingsSyncController!.addListener(_onCloudSettingsSync);
    _integrationCommandProcessor = IntegrationCommandProcessor(
      session: widget.session,
      appSettings: widget.appSettings,
    );
    _integrationCommandProcessor.bind();
    widget.session.onSyncConflictCountChanged = (count) {
      unawaited(widget.appSettings.setSyncPendingConflicts(count));
    };
    widget.session.onPersisted = _onVaultPersisted;
    widget.session.onBeforeLeaveVault = () async {
      await _cloudDeviceSyncController?.flushPushNow();
    };
    widget.session.onBeforeLeavePage = () async {
      await _cloudDeviceSyncController?.flushPushIfPending();
    };
    widget.session.onVaultDeletedLocally = (vaultId, displayName) =>
        _cloudDeviceSyncController?.notifyVaultDeletedLocally(
              vaultId,
              displayName,
            ) ??
        Future.value();
    widget.session.onVaultRestoredLocally = (vaultId) =>
        _cloudDeviceSyncController?.notifyVaultRestoredLocally(vaultId) ??
        Future.value();
    widget.session.onVaultPurgedLocally = (vaultId) =>
        _cloudDeviceSyncController?.notifyVaultPurgedLocally(vaultId) ??
        Future.value();
    widget.session.onFetchRemoteOnlyTrash = () =>
        _cloudDeviceSyncController?.listRemoteOnlyTrash() ??
        Future.value(const []);
    widget.session.onMaterializeGhostVault = (vaultId) =>
        _cloudDeviceSyncController?.materializeGhostVault(vaultId) ??
        Future.value(false);
    _launchArgsSub = PlatformLaunchArguments.launchArguments().listen((args) {
      unawaited(_handleLaunchArguments(args, focusWindow: false));
    });
    unawaited(_runVaultBootstrap());
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
    _continuousVaultBackupDebounce?.cancel();
    _launchArgsSub?.cancel();
    _accentSub?.cancel();
    unawaited(_integrationsBridge.dispose());
    _integrationCommandProcessor.dispose();
    widget.session.onSyncConflictCountChanged = null;
    widget.session.onPersisted = null;
    widget.session.onBeforeLeaveVault = null;
    widget.session.onBeforeLeavePage = null;
    widget.session.onVaultDeletedLocally = null;
    widget.session.onVaultRestoredLocally = null;
    widget.session.onVaultPurgedLocally = null;
    widget.session.onFetchRemoteOnlyTrash = null;
    widget.session.onMaterializeGhostVault = null;
    _deviceSyncController.dispose();
    unawaited(_cloudDeviceSyncController?.disposeController());
    _cloudDeviceSyncController?.dispose();
    _cloudStatusController?.dispose();
    _cloudStatusController = null;
    _cloudSettingsSyncController?.removeListener(_onCloudSettingsSync);
    unawaited(_cloudSettingsSyncController?.disposeController());
    _cloudSettingsSyncController?.dispose();
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_desktop?.dispose());
    widget.cloudAccountController.dispose();
    _folioCloudEntitlements.removeListener(_onFolioCloudEntitlements);
    _folioCloudEntitlementsInstance?.dispose();
    _organizationContextInstance?.dispose();
    unawaited(_mcpServer?.stop());
    folioMcpServerStatus.value = null;
    widget.appSettings.onWorkspaceSidebarWidthChanged = null;
    widget.appSettings.onWorkspaceHomeDashboardChanged = null;
    widget.layoutEngineController.dispose();
    widget.appSettings.removeListener(_onSettings);
    widget.session.removeListener(_onSession);
    super.dispose();
  }

  void _onSession() {
    final nextVault = widget.session.state;
    final vaultFlowChanged = _lastVaultFlowForTelemetry != nextVault;
    if (vaultFlowChanged) {
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
      MusicProviderGate.instance.unbind();
      YtMusicPlaybackController.instance.detachSession();
      SpotifyPlaybackController.instance.detachSession();
      MediaPlaybackRouter.instance.detachSession();
      // Device-sync sigue en segundo plano (headless) aunque la libreta esté
      // bloqueada; settings sync no — requiere vault unlocked (no reiniciar
      // solo por sesión cloud).
      unawaited(_syncCloudSettingsSyncLifecycle());
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final nav = _navKey.currentState;
        if (nav == null || !nav.mounted) return;
        while (nav.canPop()) {
          nav.pop();
        }
      });
      // Relanzar sync headless si estaba parado; luego rebind si cambió la activa.
      unawaited(() async {
        await _syncCloudDeviceSyncLifecycle(force: true);
        await _cloudDeviceSyncController?.onActiveVaultMaybeChanged();
      }());
    } else if (widget.session.state == VaultFlowState.unlocked) {
      SpotifyPlaybackController.instance.attachSession(widget.session);
      YtMusicPlaybackController.instance.attachSession(widget.session);
      MediaPlaybackRouter.instance.attachSession(widget.session);
      MusicProviderGate.instance.bind(
        settings: widget.appSettings,
        session: widget.session,
      );
      // `_onSession` se dispara en CADA notificación de la sesión (cada
      // edición, no solo al desbloquear). `_syncCloudDeviceSyncLifecycle` ya
      // cachea el último `isEnabled` aplicado y no hace nada si no cambió;
      // llamar a `ctrl.start()` a pelo aquí (como antes) reiniciaba todo el
      // pipeline de cloud sync — incl. una subida/descarga completa — en
      // cada tecla. `cacheKeyForActiveVault` solo debe correr una vez por
      // desbloqueo real, no en cada notificación.
      unawaited(() async {
        await _syncCloudDeviceSyncLifecycle();
        await _cloudDeviceSyncController?.onActiveVaultMaybeChanged();
      }());
      unawaited(_syncCloudSettingsSyncLifecycle());
      if (vaultFlowChanged) {
        unawaited(_cloudDeviceSyncController?.cacheKeyForActiveVault());
      }
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

      // Primera instalación: marcar como visto sin abrir.
      if (lastSeen.isEmpty) {
        await widget.appSettings.setLastSeenReleaseNotesVersion(versionLabel);
        return;
      }
      // Tras actualizar: no abrir el modal automáticamente.
      // La tarjeta «Novedades» del home sigue indicando unread
      // (lastSeen != versionLabel) hasta que el usuario la abra o descarte.
      if (lastSeen != versionLabel) return;
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

  void _onVaultPersisted() {
    _deviceSyncController.onLocalSnapshotPersisted();
    _cloudDeviceSyncController?.onLocalSnapshotPersisted();
    unawaited(_scheduleContinuousVaultBackupAfterPersist());
  }

  Future<void> _scheduleContinuousVaultBackupAfterPersist() async {
    if (!mounted) return;
    if (widget.session.state != VaultFlowState.unlocked) return;
    final vaultId = widget.session.activeVaultId ?? '';
    final prefs = await widget.appSettings.getVaultBackupPrefs(
      vaultId.isEmpty ? null : vaultId,
    );
    if (!prefs.enabled || !prefs.isContinuous) return;
    final canCloud =
        folioCloudHasSession() &&
        folioCloudHasSession() &&
        _folioCloudEntitlements.snapshot.canUseCloudBackup;
    if (!scheduledVaultBackupHasDestination(prefs, canCloud: canCloud)) {
      return;
    }
    _continuousVaultBackupDirty = true;
    _continuousVaultBackupDebounce?.cancel();
    _continuousVaultBackupDebounce = Timer(
      _continuousVaultBackupDebounceDuration,
      () => unawaited(_runContinuousVaultBackupIfNeeded()),
    );
  }

  Future<void> _runContinuousVaultBackupIfNeeded() async {
    if (!mounted) return;
    if (_continuousVaultBackupRunning) {
      _continuousVaultBackupDirty = true;
      return;
    }
    if (!_continuousVaultBackupDirty) return;
    _continuousVaultBackupDirty = false;
    _continuousVaultBackupRunning = true;
    try {
      await _executeScheduledVaultBackup(showSuccessSnack: false);
      if (_continuousVaultBackupDirty && mounted) {
        _continuousVaultBackupDebounce?.cancel();
        _continuousVaultBackupDebounce = Timer(
          _continuousVaultBackupDebounceDuration,
          () => unawaited(_runContinuousVaultBackupIfNeeded()),
        );
      }
    } finally {
      _continuousVaultBackupRunning = false;
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
    // El modo continuo se dispara tras persist; el timer solo cubre intervalos fijos.
    if (prefs.isContinuous) return;
    final canCloud =
        folioCloudHasSession() &&
        folioCloudHasSession() &&
        _folioCloudEntitlements.snapshot.canUseCloudBackup;
    final willDoFolder = prefs.hasNetworkDestination;
    final willDoCloud = prefs.alsoCloud && canCloud;
    if (!willDoFolder && !willDoCloud) return;
    final intervalMs = prefs.intervalMinutes * 60 * 1000;
    final now = DateTime.now().millisecondsSinceEpoch;
    final last = prefs.lastMs;
    if (last > 0 && now - last < intervalMs) return;
    await _executeScheduledVaultBackup(showSuccessSnack: true);
  }

  Future<void> _executeScheduledVaultBackup({
    required bool showSuccessSnack,
  }) async {
    final vaultId = widget.session.activeVaultId ?? '';
    try {
      await runScheduledFolderVaultExport(
        session: widget.session,
        appSettings: widget.appSettings,
        vaultId: vaultId.isEmpty ? null : vaultId,
        folioEntitlements: _folioCloudEntitlements,
      );
      if (!showSuccessSnack) return;
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
      case VaultFlowState.recovery:
        return 'vault_recovery';
    }
  }

  Future<bool> _importSyncSnapshot(List<int> snapshot, String _) async {
    final sw = Stopwatch()..start();
    try {
      final applied = await widget.session.applySyncSnapshotBytes(snapshot);
      unawaited(
        FolioTelemetry.logSyncEvent(
          widget.appSettings,
          'device_lan_import',
          applied.ok,
          durationMs: sw.elapsedMilliseconds,
        ),
      );
      return applied.ok;
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
          return FolioDialog(
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
    unawaited(_syncCloudDeviceSyncLifecycle());
    unawaited(_syncCloudSettingsSyncLifecycle());
    if (mounted) setState(() {});
  }

  void _onCloudSettingsSync() {
    if (_cloudSettingsSyncController?.hasRemoteProfilePromptPending == true) {
      unawaited(_maybeShowAppProfileRestoreDialog());
    }
  }

  void _onSettings() {
    widget.session.titleLocale = widget.appSettings.locale;
    _applySessionSecurityPolicy();
    _applyAiSettings();
    _applyDeviceSyncSettings();
    // Settings-cloud sync: lifecycle propio (cachea shouldRun), no acoplado
    // a cada refresh de LAN device-sync.
    unawaited(_syncCloudSettingsSyncLifecycle());
    _applyDesktopSettingsIfNeeded();
    unawaited(_applyMcpServerSettings());
    FolioDiagnosticReporter.bindAppSettings(widget.appSettings);
    unawaited(FolioTelemetry.onSettingsChanged(widget.appSettings));
    if (mounted) setState(() {});
  }

  /// Fase 5: arranca/para el servidor MCP local según
  /// `AppSettings.mcpServerEnabled` — nunca corre sin que el usuario lo pida
  /// explícitamente, y nunca fuera de desktop (`mcpServerSupported`).
  ///
  /// Si llega otra petición mientras hay una en vuelo, se encola un reintento
  /// al terminar (para no perder un toggle ON que coincida con un arranque).
  bool _mcpServerApplyQueued = false;

  Future<void> _applyMcpServerSettings() {
    final inFlight = _mcpServerApplyInFlight;
    if (inFlight != null) {
      _mcpServerApplyQueued = true;
      return inFlight;
    }
    final run = _applyMcpServerSettingsBody();
    late final Future<void> tracked;
    tracked = run.whenComplete(() {
      if (identical(_mcpServerApplyInFlight, tracked)) {
        _mcpServerApplyInFlight = null;
      }
      if (_mcpServerApplyQueued) {
        _mcpServerApplyQueued = false;
        unawaited(_applyMcpServerSettings());
      }
    });
    _mcpServerApplyInFlight = tracked;
    return tracked;
  }

  /// El servidor MCP ya no bindea su propio puerto (45833): se enruta a
  /// través del bridge de Integraciones (45831, siempre activo) vía
  /// `_integrationsBridge.setMcpServer(...)`. `prepareToken()` solo genera/
  /// fija el token Bearer, no hace I/O, así que ya no puede "fallar" un bind
  /// como antes -- se quita el manejo de error asociado.
  Future<void> _applyMcpServerSettingsBody() async {
    final wantsEnabled = widget.appSettings.mcpServerEnabled && mcpServerSupported;
    final server = _mcpServer;
    if (!wantsEnabled) {
      if (server != null) {
        await server.stop();
      }
      _mcpServer = null;
      _integrationsBridge.setMcpServer(null);
      folioMcpServerStatus.value = null;
      return;
    }
    // Sin notify: si generamos token aquí, notifyListeners reentraría en
    // `_onSettings` → otro `_applyMcpServerSettings`.
    final token = await widget.appSettings.ensureMcpServerAuthToken(notify: false);
    if (server != null && server.authToken == token) {
      folioMcpServerStatus.value = FolioMcpServerInfo(
        port: _integrationsBridge.port,
        authToken: server.authToken!,
        isRunning: true,
      );
      return;
    }
    final active = FolioMcpServer(
      FolioToolRegistry(
        widget.session,
        onRequestMcpReadAccess: _requestMcpReadAccess,
      ),
      onApproveClient: _approveMcpClient,
      isClientApproved: _isMcpClientApproved,
      onClientObserved: _syncObservedMcpClient,
    );
    active.prepareToken(authToken: token);
    _mcpServer = active;
    _integrationsBridge.setMcpServer(active);
    folioMcpServerStatus.value = FolioMcpServerInfo(
      port: _integrationsBridge.port,
      authToken: active.authToken!,
      isRunning: true,
    );
    AppLogger.info(
      'Servidor MCP local en ${FolioMcpServer.endpointUrl(port: _integrationsBridge.port)}',
      tag: 'mcp',
    );
    if (mounted) setState(() {});
  }

  void _applyDeviceSyncSettings() {
    _deviceSyncController.refreshSettingsSnapshot();
    unawaited(_syncCloudDeviceSyncLifecycle());
  }

  /// Solo relanza/para el controlador cuando el estado efectivo
  /// (habilitado) realmente cambia, para no reiniciar el listener de
  /// Firestore en cada `AppSettings.notifyListeners()` ajeno (tema,
  /// preferencias, etc.). `force` ignora la cache. El pull al volver a
  /// primer plano lo gestiona `setAppInForeground(true)`, no este método.
  Future<void> _syncCloudDeviceSyncLifecycle({bool force = false}) async {
    final ctrl = _cloudDeviceSyncController;
    if (ctrl == null) return;
    // Sync multi-dispositivo no exige libreta desbloqueada (headless + cache DEK).
    final shouldRun = ctrl.isEnabled;
    if (!force && shouldRun == _lastCloudDeviceSyncShouldRun) return;
    AppLogger.info(
      'device sync lifecycle',
      tag: 'cloud_sync',
      context: {
        'shouldRun': shouldRun,
        'force': force,
        'prev': _lastCloudDeviceSyncShouldRun,
      },
    );
    _lastCloudDeviceSyncShouldRun = shouldRun;
    if (shouldRun) {
      await ctrl.start();
    } else {
      await ctrl.stopWatching();
    }
  }

  /// Arranca/para settings sync solo cuando el estado efectivo cambia
  /// (misma idea que device sync). Exige vault unlocked: con locked no se
  /// relanza solo por `folioCloudHasSession()` (evita storm de meta tras
  /// `stopWatching` en lock + `_onSettings`).
  Future<void> _syncCloudSettingsSyncLifecycle({bool force = false}) async {
    final ctrl = _cloudSettingsSyncController;
    if (ctrl == null) return;
    // isEnabled ya exige sesión cloud; no OR-ear hasSession con locked.
    final shouldRun = ctrl.isEnabled &&
        widget.session.state == VaultFlowState.unlocked;
    if (!force && shouldRun == _lastSettingsSyncShouldRun) return;
    AppLogger.debug(
      'settings sync lifecycle',
      tag: 'settings_sync',
      context: {
        'shouldRun': shouldRun,
        'force': force,
        'prev': _lastSettingsSyncShouldRun,
        'enabled': ctrl.isEnabled,
        'vaultState': widget.session.state.name,
      },
    );
    if (shouldRun) {
      try {
        await ctrl.start();
        _lastSettingsSyncShouldRun = true;
      } catch (e) {
        // No cachear éxito: un fallo de meta/start debe permitir reintento
        // en el próximo notify (p. ej. tras corte HTTP).
        _lastSettingsSyncShouldRun = null;
        rethrow;
      }
    } else {
      await ctrl.stopWatching();
      _lastSettingsSyncShouldRun = false;
    }
  }

  Future<void> _maybeShowAppProfileRestoreDialog() async {
    final ctrl = _cloudSettingsSyncController;
    if (ctrl == null || !ctrl.hasRemoteProfilePromptPending) return;
    if (_appProfileRestoreDialogShown) return;
    final navCtx = _navKey.currentContext;
    if (navCtx == null || !navCtx.mounted) return;
    _appProfileRestoreDialogShown = true;
    final l10n = AppLocalizations.of(navCtx);
    final choice = await showDialog<String>(
      context: navCtx,
      barrierDismissible: false,
      builder: (ctx) => FolioDialog(
        title: Text(l10n.folioCloudAppProfileRestoreDialogTitle),
        content: Text(l10n.folioCloudAppProfileRestoreDialogBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('fresh'),
            child: Text(l10n.folioCloudAppProfileStartFreshAction),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop('restore'),
            child: Text(l10n.folioCloudAppProfileRestoreAction),
          ),
        ],
      ),
    );
    if (choice == 'restore') {
      final ok = await ctrl.restoreAppProfileFromCloud();
      if (mounted) {
        _showSnack(
          ok
              ? l10n.folioCloudAppProfileRestoreOk
              : l10n.folioCloudAppProfileRestoreFail,
        );
      }
    } else {
      await ctrl.keepLocalAndPush();
    }
    _appProfileRestoreDialogShown = false;
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

  void _onMouseNavigationButtons(PointerDownEvent event) {
    final back = (event.buttons & kBackMouseButton) != 0;
    final forward = (event.buttons & kForwardMouseButton) != 0;
    if (!back && !forward) return;
    if (!widget.session.isUnlocked) return;

    if (back) {
      final nav = _navKey.currentState;
      if (nav != null && nav.canPop()) {
        nav.maybePop();
        return;
      }
      widget.session.navigateHistoryBack();
      return;
    }

    widget.session.navigateHistoryForward();
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
    if (!widget.appSettings.isAiRuntimeEnabled) {
      widget.session.setAiService(null);
      return;
    }

    final provider = widget.appSettings.aiProvider;
    if (provider == AiProvider.none) {
      widget.session.setAiService(null);
      return;
    }

    // Quill Cloud
    if (provider == AiProvider.quillCloud) {
      if (_folioCloudEntitlements.snapshot.canUseCloudAi) {
        widget.session.setAiService(
          FolioCloudAiService(entitlements: _folioCloudEntitlements),
        );
      } else {
        widget.session.setAiService(null);
      }
      return;
    }

    // Gemini Nano / Galaxy AI on-device (solo Android).
    if (provider == AiProvider.geminiNano) {
      if (aiOnDeviceProviderSupported) {
        unawaited(OnDeviceAiBridge.getDeviceBrand());
        widget.session.setAiService(
          GeminiNanoAiService(
            timeout: Duration(milliseconds: widget.appSettings.aiTimeoutMs),
          ),
        );
      } else {
        widget.session.setAiService(null);
      }
      return;
    }

    // Local providers (Ollama / LM Studio) solo en escritorio.
    final isLocalProvider = provider == AiProvider.ollama || provider == AiProvider.lmStudio;
    if (isLocalProvider && !aiLocalProvidersSupported) {
      widget.session.setAiService(null);
      return;
    }

    // Validate endpoint only for local providers
    if (isLocalProvider) {
      final endpointError = AiSafetyPolicy.validateEndpointIssue(
        rawUrl: widget.appSettings.aiBaseUrl,
        mode: widget.appSettings.aiEndpointMode,
        remoteConfirmed: widget.appSettings.aiRemoteEndpointConfirmed,
      );
      if (endpointError != null) {
        widget.session.setAiService(null);
        return;
      }
    }

    final uri = AiSafetyPolicy.parseAndNormalizeUrl(
      widget.appSettings.aiBaseUrl,
    );
    if (uri == null) {
      widget.session.setAiService(null);
      return;
    }

    final timeout = Duration(milliseconds: widget.appSettings.aiTimeoutMs);
    switch (provider) {
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
      case AiProvider.openAi:
      case AiProvider.gemini:
        widget.session.setAiService(
          OpenAiCompatibleAiService(
            baseUrl: uri,
            timeout: timeout,
            defaultModel: widget.appSettings.aiModel,
            apiKey: widget.appSettings.aiApiKey,
            provider: provider.name,
          ),
        );
        break;
      case AiProvider.none:
      case AiProvider.quillCloud:
      case AiProvider.geminiNano:
        widget.session.setAiService(null);
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
      onWindowFocusChanged: _onDesktopWindowFocusChanged,
    );
    _desktop = desktop;
    try {
      await desktop.initialize();
      _windowFocused = await desktop.isWindowFocused();
      _syncCloudDeviceSyncForeground();
    } catch (e, st) {
      AppLogger.error(
        'Desktop integration init failed',
        tag: 'desktop',
        error: e,
        stackTrace: st,
      );
    }
    _desktopSettingsSignature = _buildDesktopSettingsSignature();
  }

  void _onDesktopWindowFocusChanged(bool focused) {
    if (_windowFocused == focused) return;
    _windowFocused = focused;
    _syncCloudDeviceSyncForeground();
  }

  /// Pull activo solo con lifecycle resumed y ventana con foco (en desktop).
  void _syncCloudDeviceSyncForeground() {
    final foreground = _lifecycleActive && _windowFocused;
    _cloudDeviceSyncController?.setAppInForeground(foreground);
    _cloudStatusController?.setAppInForeground(foreground);
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
    // Guarda de forma acotada una nota de reunión activa antes de cerrar —
    // dispose() de VaultSession es síncrono y no puede esperar esto, así que
    // este interceptor de cierre de ventana (async, corre antes de destruir
    // la ventana) es el punto correcto para hacerlo sin perder la grabación.
    await MeetingNoteSessionController.instance
        .saveActiveRecordingBeforeTeardown();
    await PostHocTranscriptionJobManager.instance.cancelAllAndAwait();
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

  /// Igual que `_approveIntegrationsClient`/Run2Doc, pero para clientes MCP
  /// (Fase 5): la primera vez que un cliente MCP se conecta (`initialize`),
  /// se pide permiso explícito y la aprobación se guarda en el mismo sistema
  /// que el resto de integraciones — así aparece y se puede revocar desde
  /// Ajustes → Integraciones sin código nuevo en esa pantalla.
  Future<bool> _approveMcpClient(McpClientIdentity client) async {
    if (widget.appSettings.isIntegrationAppApproved(
      client.appId,
      integrationVersion: FolioMcpServer.capabilitiesVersion,
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
      builder: (dialogContext) => _McpApprovalDialog(
        client: client,
        previousApproval: previousApproval,
      ),
    );
    if (approved == true) {
      await widget.appSettings.approveIntegrationApp(
        appId: client.appId,
        appName: client.appName,
        appVersion: client.appVersion,
        integrationVersion: FolioMcpServer.capabilitiesVersion,
      );
      return true;
    }
    return false;
  }

  /// Lectura MCP de una página fuera de la allowlist: el usuario puede denegar,
  /// permitir solo esta vez, o permitir y añadir a la allowlist.
  Future<McpReadAccessDecision> _requestMcpReadAccess(
    String pageId,
    String pageTitle,
  ) async {
    final ctx = _navKey.currentContext ?? context;
    if (!ctx.mounted) return McpReadAccessDecision.deny;
    final clientName =
        _mcpServer?.connectedClient?.appName.trim().isNotEmpty == true
        ? _mcpServer!.connectedClient!.appName.trim()
        : 'MCP';
    final title = pageTitle.trim().isEmpty ? pageId : pageTitle.trim();
    final decision = await showDialog<McpReadAccessDecision>(
      context: ctx,
      barrierDismissible: false,
      builder: (dialogContext) => _McpReadAccessDialog(
        pageTitle: title,
        clientName: clientName,
      ),
    );
    return decision ?? McpReadAccessDecision.deny;
  }

  bool _isMcpClientApproved(McpClientIdentity client) {
    return widget.appSettings.isIntegrationAppApproved(
      client.appId,
      integrationVersion: FolioMcpServer.capabilitiesVersion,
    );
  }

  Future<void> _syncObservedMcpClient(McpClientIdentity client) {
    return widget.appSettings.syncApprovedIntegrationAppObservation(
      appId: client.appId,
      appName: client.appName,
      appVersion: client.appVersion,
      integrationVersion: FolioMcpServer.capabilitiesVersion,
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
      final shouldInstall = await UpdateAvailableDialogContent.confirm(
        context: dialogCtx,
        title: Text(
          result.isPrerelease
              ? l10n.updaterStartupDialogTitleBeta
              : l10n.updaterStartupDialogTitleStable,
        ),
        intro:
            '${l10n.updaterStartupDialogBody(result.releaseVersion.toString())}$betaNote',
        releaseNotes: result.releaseNotes,
        question: defaultTargetPlatform == TargetPlatform.android
            ? l10n.updaterOpenApkDownloadQuestion
            : l10n.updaterStartupDialogQuestion,
        cancelLabel: l10n.updaterStartupDialogLater,
        confirmLabel: l10n.updaterStartupDialogUpdateNow,
      );
      if (shouldInstall == true) {
        if (defaultTargetPlatform == TargetPlatform.android) {
          final raw = result.installerUrl ?? '';
          final uri = Uri.tryParse(raw);
          if (uri == null) return;
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          return;
        }
        _showSnack(l10n.updaterDownloadProgressTitle);
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
      _lifecycleActive = true;
      // Primero foreground efectivo (lifecycle + foco ventana); luego lifecycle
      // sin force (no reinicia push/bootstrap si ya corría).
      _syncCloudDeviceSyncForeground();
      unawaited(_syncCloudDeviceSyncLifecycle());
    }
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _lifecycleActive = false;
      _syncCloudDeviceSyncForeground();
      widget.session.onAppBackgrounded();
      if (widget.appSettings.minimizeToTray) {
        unawaited(_desktop?.hideToTray());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) => _buildApp(context, lightDynamic),
    );
  }

  Widget _buildApp(BuildContext context, ColorScheme? androidLightDynamic) {
    final androidAccent = androidLightDynamic?.primary;
    // Motor de tema (Fase 3): AppSettings sigue siendo la única fuente de
    // verdad (igual que antes) — solo se traduce a un ThemeConfig efímero
    // en cada build para que la construcción del ThemeData sea data-driven
    // (resolveThemeData) en vez de las funciones hardcodeadas de
    // folio_theme.dart. Ver ThemeResolverTest para la verificación de
    // equivalencia estructural con el ThemeData legacy.
    final themeConfig = ConfigBootstrap.themeConfigFromAppSettings(
      widget.appSettings,
    );
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: _navKey,
      navigatorObservers: [_telemetryNavObserver],
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      theme: resolveThemeData(
        themeConfig,
        Brightness.light,
        androidDynamicAccent: androidAccent,
      ),
      darkTheme: resolveThemeData(
        themeConfig,
        Brightness.dark,
        androidDynamicAccent: androidAccent,
      ),
      themeMode: widget.appSettings.materialThemeMode,
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
        // La estructura del árbol se mantiene SIEMPRE igual (aunque la escala
        // sea 1.0) para no re-parentar el subárbol que contiene el Navigator y
        // sus FocusScope. Cambiar la profundidad del árbol al cruzar el límite
        // de 1.0 provocaba la aserción '_elements.contains(element)' del
        // framework al mover elementos con GlobalKey.
        final double effectiveScale = (uiScale - 1.0).abs() > 0.001
            ? uiScale
            : 1.0;
        final Widget content = Stack(
          children: [
            ClipRect(
              child: OverflowBox(
                alignment: Alignment.topLeft,
                minWidth: 0,
                minHeight: 0,
                maxWidth: double.infinity,
                maxHeight: double.infinity,
                child: Transform.scale(
                  alignment: Alignment.topLeft,
                  scale: effectiveScale,
                  child: SizedBox(
                    width: media.size.width / effectiveScale,
                    height: media.size.height / effectiveScale,
                    child: child ?? const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
            // Host invisible del dispositivo Spotify Connect local (Web
            // Playback SDK). Montado aquí, cerca de la raíz, para que
            // sobreviva a toda la navegación interna de la app.
            const SpotifyLocalDeviceMount(),
          ],
        );
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
              onPointerDown: (event) {
                _onGlobalUserActivity();
                _onMouseNavigationButtons(event);
              },
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
        cloudSettingsSyncController: _cloudSettingsSyncController,
        cloudDeviceSyncController: _cloudDeviceSyncController,
        cloudStatusController: _cloudStatusController,
        cloudAccountController: widget.cloudAccountController,
        folioCloudEntitlements: _folioCloudEntitlements,
        organizationContext: _organizationContext,
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

    return FolioDialog(
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

/// Diálogo de permiso para un cliente MCP conectando por primera vez (Fase 5)
/// Diálogo de aprobación del cliente MCP (misma idea que el bridge de
/// Integraciones/Run2Doc), describiendo el catálogo de tools — incluida la
/// lectura restringida a la allowlist.
class _McpApprovalDialog extends StatelessWidget {
  const _McpApprovalDialog({
    required this.client,
    this.previousApproval,
  });

  final McpClientIdentity client;
  final IntegrationAppApproval? previousApproval;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final isUpdate = previousApproval != null &&
        !previousApproval!.matches(
          integrationVersion: FolioMcpServer.capabilitiesVersion,
        );
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

    return FolioDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      content: SizedBox(
        width: 620,
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
                child: Row(
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
                            : Icons.dns_rounded,
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
                                ? l10n.mcpApprovalUpdateTitle(client.appName)
                                : l10n.mcpApprovalTitle(client.appName),
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            isUpdate
                                ? l10n.mcpApprovalUpdateBody
                                : l10n.mcpApprovalBody(appVersion),
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
              ),
              if (isUpdate) ...[
                const SizedBox(height: 12),
                capabilityRow(
                  Icons.menu_book_outlined,
                  l10n.mcpApprovalUpdateHighlightTitle,
                  l10n.mcpApprovalUpdateHighlightDesc,
                  accent: scheme.tertiary,
                ),
              ],
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _IntegrationApprovalChip(
                    icon: Icons.laptop_windows_rounded,
                    label: l10n.mcpApprovalChipLocalOnly,
                  ),
                  _IntegrationApprovalChip(
                    icon: Icons.verified_user_outlined,
                    label: l10n.mcpApprovalChipRevocable,
                  ),
                  _IntegrationApprovalChip(
                    icon: Icons.key_outlined,
                    label: l10n.mcpApprovalChipToken,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                l10n.mcpApprovalCanDoTitle,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              capabilityRow(
                Icons.edit_note_rounded,
                l10n.mcpApprovalCanDoEdit,
                l10n.mcpApprovalCanDoEditDesc,
                accent: scheme.primary,
              ),
              capabilityRow(
                Icons.account_tree_outlined,
                l10n.mcpApprovalCanDoManage,
                l10n.mcpApprovalCanDoManageDesc,
                accent: scheme.primary,
              ),
              capabilityRow(
                Icons.search_rounded,
                l10n.mcpApprovalCanDoSearch,
                l10n.mcpApprovalCanDoSearchDesc,
                accent: scheme.primary,
              ),
              capabilityRow(
                Icons.menu_book_outlined,
                l10n.mcpApprovalCanDoRead,
                l10n.mcpApprovalCanDoReadDesc,
                accent: scheme.primary,
              ),
              const SizedBox(height: 8),
              capabilityRow(
                Icons.public_off_outlined,
                l10n.mcpApprovalCannotLeaveMachine,
                l10n.mcpApprovalCannotLeaveMachineDesc,
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
          child: Text(l10n.mcpApprovalDeny),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(
            isUpdate ? l10n.mcpApprovalApproveUpdate : l10n.mcpApprovalAllow,
          ),
        ),
      ],
    );
  }
}

class _McpReadAccessDialog extends StatelessWidget {
  const _McpReadAccessDialog({
    required this.pageTitle,
    required this.clientName,
  });

  final String pageTitle;
  final String clientName;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final displayTitle = pageTitle.trim().isEmpty ? '—' : pageTitle.trim();

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

    return FolioDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      content: SizedBox(
        width: 620,
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
                child: Row(
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
                        Icons.menu_book_rounded,
                        color: scheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.mcpReadAccessTitle,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            l10n.mcpReadAccessBody(clientName),
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
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(FolioRadius.lg),
                  border: Border.all(
                    color: scheme.outlineVariant.withValues(alpha: 0.45),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.description_outlined,
                      size: 20,
                      color: scheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.mcpReadAccessPageLabel,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            displayTitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _IntegrationApprovalChip(
                    icon: Icons.laptop_windows_rounded,
                    label: l10n.mcpApprovalChipLocalOnly,
                  ),
                  _IntegrationApprovalChip(
                    icon: Icons.playlist_add_check_rounded,
                    label: l10n.mcpReadAccessChipAllowlist,
                  ),
                  _IntegrationApprovalChip(
                    icon: Icons.visibility_off_outlined,
                    label: l10n.mcpReadAccessChipNoPreview,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                l10n.mcpReadAccessCanDoTitle,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              capabilityRow(
                Icons.menu_book_outlined,
                l10n.mcpReadAccessCanDoRead,
                l10n.mcpReadAccessCanDoReadDesc,
                accent: scheme.primary,
              ),
              capabilityRow(
                Icons.playlist_add_outlined,
                l10n.mcpReadAccessCanDoAllowlist,
                l10n.mcpReadAccessCanDoAllowlistDesc,
                accent: scheme.primary,
              ),
              capabilityRow(
                Icons.looks_one_outlined,
                l10n.mcpReadAccessCanDoOnce,
                l10n.mcpReadAccessCanDoOnceDesc,
                accent: scheme.primary,
              ),
              const SizedBox(height: 8),
              capabilityRow(
                Icons.public_off_outlined,
                l10n.mcpApprovalCannotLeaveMachine,
                l10n.mcpApprovalCannotLeaveMachineDesc,
                accent: scheme.error,
                danger: true,
              ),
              capabilityRow(
                Icons.hide_source_outlined,
                l10n.mcpReadAccessCannotPreview,
                l10n.mcpReadAccessCannotPreviewDesc,
                accent: scheme.error,
                danger: true,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, McpReadAccessDecision.deny),
          child: Text(l10n.mcpReadAccessDeny),
        ),
        OutlinedButton(
          onPressed: () =>
              Navigator.pop(context, McpReadAccessDecision.allowOnce),
          child: Text(l10n.mcpReadAccessAllowOnce),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.pop(context, McpReadAccessDecision.allowAndRemember),
          child: Text(l10n.mcpReadAccessAllow),
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
    this.cloudSettingsSyncController,
    this.cloudDeviceSyncController,
    this.cloudStatusController,
    required this.cloudAccountController,
    required this.folioCloudEntitlements,
    this.organizationContext,
    required this.onOpenSearch,
    required this.onOpenReleaseNotes,
  });

  final VaultSession session;
  final AppSettings appSettings;
  final DeviceSyncController deviceSyncController;
  final FolioCloudSettingsSyncController? cloudSettingsSyncController;
  final FolioCloudDeviceSyncController? cloudDeviceSyncController;
  final FolioCloudStatusController? cloudStatusController;
  final CloudAccountController cloudAccountController;
  final FolioCloudEntitlementsController folioCloudEntitlements;
  final OrganizationContextController? organizationContext;
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
                FolioLoadingIndicator(color: scheme.primary),
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
      case VaultFlowState.recovery:
        return RecoveryScreen(session: session, appSettings: appSettings);
      case VaultFlowState.unlocked:
        return WorkspacePage(
          session: session,
          appSettings: appSettings,
          deviceSyncController: deviceSyncController,
          cloudSettingsSyncController: cloudSettingsSyncController,
          cloudDeviceSyncController: cloudDeviceSyncController,
          cloudStatusController: cloudStatusController,
          cloudAccountController: cloudAccountController,
          folioCloudEntitlements: folioCloudEntitlements,
          organizationContext: organizationContext,
          onOpenSearch: onOpenSearch,
          onOpenReleaseNotes: onOpenReleaseNotes,
        );
    }
  }
}
