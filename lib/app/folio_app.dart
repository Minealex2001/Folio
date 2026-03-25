import 'dart:async';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:system_theme/system_theme.dart';

import '../desktop/desktop_integration.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/block.dart';
import '../services/ai/ai_provider_launcher.dart';
import '../services/ai/ai_safety_policy.dart';
import '../services/ai/lmstudio_ai_service.dart';
import '../services/ai/ollama_ai_service.dart';
import '../services/run2doc/run2doc_bridge.dart';
import '../services/run2doc/run2doc_markdown_codec.dart';
import '../services/updater/github_release_updater.dart';
import '../features/lock/lock_screen.dart';
import '../features/onboarding/onboarding_flow.dart';
import '../features/workspace/workspace_page.dart';
import '../features/workspace/widgets/global_search_popup.dart';
import '../session/vault_session.dart';
import 'app_settings.dart';
import 'folio_theme.dart';

class FolioApp extends StatefulWidget {
  const FolioApp({
    super.key,
    required this.session,
    required this.appSettings,
    this.initialLaunchArgs = const <String>[],
  });

  final VaultSession session;
  final AppSettings appSettings;
  final List<String> initialLaunchArgs;

  @override
  State<FolioApp> createState() => _FolioAppState();
}

class _FolioAppState extends State<FolioApp> with WidgetsBindingObserver {
  StreamSubscription<SystemAccentColor>? _accentSub;
  final GlobalKey<NavigatorState> _navKey = GlobalKey<NavigatorState>();
  DesktopIntegration? _desktop;
  late final Run2DocBridgeController _run2DocBridge;
  String? _installedVersionLabel;
  var _openingByHotkey = false;
  String _desktopSettingsSignature = '';
  bool _updateDialogShown = false;
  bool _handledInitialLaunchArgs = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.session.addListener(_onSession);
    widget.appSettings.addListener(_onSettings);
    _run2DocBridge = Run2DocBridgeController(
      onImport: _importRun2DocMarkdown,
      onUpdate: _updateRun2DocPage,
      onListPages: _listRun2DocPages,
      onImportJson: _importRun2DocJson,
      onApproveClient: _approveRun2DocClient,
      onClientObserved: _syncObservedRun2DocClient,
      isClientApproved: (client) => widget.appSettings.isIntegrationAppApproved(
        client.appId,
        integrationVersion: client.integrationVersion,
      ),
      secretProvider: () => widget.appSettings.integrationSecret,
      appInfoProvider: _run2DocAppInfo,
      onEvent: _showSnack,
    );
    _applySessionSecurityPolicy();
    _applyAiSettings();
    _maybeLaunchAiProvider();
    widget.session.bootstrap();
    unawaited(_loadInstalledVersionInfo());
    unawaited(_startRun2DocBridge());
    _initDesktopIntegration();
    unawaited(_handleInitialLaunchArgs());
    _checkForUpdatesOnStartup();
    _accentSub = SystemTheme.onChange.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _accentSub?.cancel();
    unawaited(_run2DocBridge.dispose());
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_desktop?.dispose());
    widget.appSettings.removeListener(_onSettings);
    widget.session.removeListener(_onSession);
    super.dispose();
  }

  void _onSession() {
    if (widget.session.state == VaultFlowState.locked) {
      final nav = _navKey.currentState;
      if (nav != null) {
        nav.popUntil((route) => route.isFirst);
      }
    }
    if (mounted) setState(() {});
  }

  void _showSnack(String message) {
    final ctx = _navKey.currentContext;
    if (ctx == null || message.trim().isEmpty) return;
    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(message)));
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

  Future<void> _startRun2DocBridge() async {
    try {
      await _run2DocBridge.start();
    } catch (e) {
      _showSnack('No se pudo iniciar el bridge Run2Doc: $e');
    }
  }

  void _onSettings() {
    _applySessionSecurityPolicy();
    _applyAiSettings();
    _applyDesktopSettingsIfNeeded();
    if (mounted) setState(() {});
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
    final endpointError = AiSafetyPolicy.validateEndpoint(
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

  Future<void> _handleSearchRequested() async {
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
      await showDialog<bool>(
        context: _navKey.currentContext ?? context,
        barrierDismissible: true,
        builder: (ctx) => GlobalSearchPopup(session: widget.session),
      );
    } finally {
      _openingByHotkey = false;
    }
  }

  Future<void> _handleLockRequested() async {
    widget.session.lock();
  }

  Future<void> _handleExitRequested() async {
    await SystemNavigator.pop();
  }

  Future<FolioMarkdownImportResult> _importRun2DocMarkdown(
    Run2DocMarkdownImportRequest request,
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

  Future<FolioMarkdownImportResult> _updateRun2DocPage(
    Run2DocPageUpdateRequest request,
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

  Future<List<Map<String, Object?>>> _listRun2DocPages(
    String clientAppId,
  ) async {
    return widget.session.listPagesByApp(clientAppId);
  }

  Future<FolioMarkdownImportResult> _importRun2DocJson(
    Run2DocJsonImportRequest request,
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

  Future<bool> _approveRun2DocClient(Run2DocClientIdentity client) async {
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

  Future<void> _syncObservedRun2DocClient(Run2DocClientIdentity client) {
    return widget.appSettings.syncApprovedIntegrationAppObservation(
      appId: client.appId,
      appName: client.appName,
      appVersion: client.appVersion,
      integrationVersion: client.integrationVersion,
    );
  }

  Map<String, Object?> _run2DocAppInfo() {
    final page = widget.session.selectedPage;
    final activeSession = _run2DocBridge.activeSession;
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
      'bridgePort': Run2DocLaunchSession.fixedPort,
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
    Uri? launchUri;
    for (final arg in widget.initialLaunchArgs) {
      final uri = Uri.tryParse(arg);
      if (uri != null && uri.scheme == 'folio') {
        launchUri = uri;
        break;
      }
    }
    if (launchUri == null) return;
    try {
      await _run2DocBridge.activateFromUri(launchUri);
      await _desktop?.showAndFocus();
    } catch (e) {
      _showSnack('No se pudo activar la integración Run2Doc: $e');
    }
  }

  Future<void> _checkForUpdatesOnStartup() async {
    if (!widget.appSettings.checkUpdatesOnStartup) return;
    final updater = GitHubReleaseUpdater(
      owner: widget.appSettings.updaterGithubOwner,
      repo: widget.appSettings.updaterGithubRepo,
    );
    try {
      final result = await updater.checkForUpdate(
        channel: widget.appSettings.updateReleaseChannel,
      );
      if (!mounted || !result.hasUpdate || _updateDialogShown) return;
      _updateDialogShown = true;
      final betaNote = result.isPrerelease
          ? '\n\nVersión beta (pre-release).'
          : '';
      final shouldInstall = await showDialog<bool>(
        context: _navKey.currentContext ?? context,
        builder: (ctx) {
          return AlertDialog(
            title: Text(
              result.isPrerelease
                  ? 'Beta disponible'
                  : 'Actualización disponible',
            ),
            content: Text(
              'Hay una nueva versión (${result.releaseVersion}) disponible.$betaNote\n\n'
              '¿Quieres descargar e instalar ahora?',
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
          );
        },
      );
      if (shouldInstall == true) {
        final installer = await updater.downloadInstaller(result);
        await updater.launchInstallerAndExit(installer);
      }
    } catch (_) {
      // No interrumpir el arranque si falla el chequeo.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
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
    final seed = SystemTheme.accentColor.accent;
    return MaterialApp(
      navigatorKey: _navKey,
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
        return Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (_) => _onGlobalUserActivity(),
          onPointerSignal: (_) => _onGlobalUserActivity(),
          onPointerPanZoomStart: (_) => _onGlobalUserActivity(),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: _HomeByState(
        session: widget.session,
        appSettings: widget.appSettings,
        onOpenSearch: _handleSearchRequested,
      ),
    );
  }
}

class _IntegrationApprovalDialog extends StatelessWidget {
  const _IntegrationApprovalDialog({
    required this.client,
    required this.previousApproval,
  });

  final Run2DocClientIdentity client;
  final IntegrationAppApproval? previousApproval;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final isUpdate =
        previousApproval != null &&
        (previousApproval?.integrationVersion.trim() ?? '') !=
            client.integrationVersion;

    Widget capabilityRow(IconData icon, String text, {Color? color}) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: color ?? scheme.primary),
            const SizedBox(width: 10),
            Expanded(child: Text(text)),
          ],
        ),
      );
    }

    return AlertDialog(
      title: Text(
        isUpdate
            ? l10n.integrationApprovalUpdateTitle
            : l10n.integrationApprovalTitle,
      ),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isUpdate
                    ? l10n.integrationApprovalUpdateBody(
                        client.appName,
                        (previousApproval?.integrationVersion.trim() ?? '')
                                .isEmpty
                            ? l10n.integrationApprovalUnknownVersion
                            : previousApproval!.integrationVersion.trim(),
                        client.integrationVersion,
                      )
                    : l10n.integrationApprovalBody(
                        client.appName,
                        client.appVersion,
                        client.integrationVersion,
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
                    Text(
                      client.appName,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text('${l10n.integrationApprovalAppId}: ${client.appId}'),
                    Text(
                      '${l10n.integrationApprovalAppVersion}: ${client.appVersion}',
                    ),
                    Text(
                      '${l10n.integrationApprovalProtocolVersion}: ${client.integrationVersion}',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.integrationApprovalCanDoTitle,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 10),
              capabilityRow(
                Icons.playlist_add_check_circle_outlined,
                l10n.integrationApprovalCanDoSessions,
              ),
              capabilityRow(
                Icons.description_outlined,
                l10n.integrationApprovalCanDoImport,
              ),
              capabilityRow(
                Icons.history_toggle_off_rounded,
                l10n.integrationApprovalCanDoMetadata,
              ),
              capabilityRow(
                Icons.lock_open_outlined,
                l10n.integrationApprovalCanDoUnlockedVault,
              ),
              const SizedBox(height: 12),
              Text(
                l10n.integrationApprovalCannotDoTitle,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 10),
              capabilityRow(
                Icons.visibility_off_outlined,
                l10n.integrationApprovalCannotDoRead,
                color: scheme.error,
              ),
              capabilityRow(
                Icons.shield_outlined,
                l10n.integrationApprovalCannotDoBypassLock,
                color: scheme.error,
              ),
              capabilityRow(
                Icons.key_off_outlined,
                l10n.integrationApprovalCannotDoWithoutSecret,
                color: scheme.error,
              ),
              capabilityRow(
                Icons.public_off_outlined,
                l10n.integrationApprovalCannotDoRemoteAccess,
                color: scheme.error,
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

class _HomeByState extends StatelessWidget {
  const _HomeByState({
    required this.session,
    required this.appSettings,
    required this.onOpenSearch,
  });

  final VaultSession session;
  final AppSettings appSettings;
  final VoidCallback onOpenSearch;

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
        return LockScreen(session: session);
      case VaultFlowState.unlocked:
        return WorkspacePage(
          session: session,
          appSettings: appSettings,
          onOpenSearch: onOpenSearch,
        );
    }
  }
}
