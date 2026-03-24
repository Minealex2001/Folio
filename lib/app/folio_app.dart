import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:system_theme/system_theme.dart';

import '../desktop/desktop_integration.dart';
import '../l10n/generated/app_localizations.dart';
import '../services/ai/ai_safety_policy.dart';
import '../services/ai/lmstudio_ai_service.dart';
import '../services/ai/ollama_ai_service.dart';
import '../features/lock/lock_screen.dart';
import '../features/onboarding/onboarding_flow.dart';
import '../features/workspace/workspace_page.dart';
import '../features/workspace/widgets/global_search_popup.dart';
import '../session/vault_session.dart';
import 'app_settings.dart';
import 'folio_theme.dart';

class FolioApp extends StatefulWidget {
  const FolioApp({super.key, required this.session, required this.appSettings});

  final VaultSession session;
  final AppSettings appSettings;

  @override
  State<FolioApp> createState() => _FolioAppState();
}

class _FolioAppState extends State<FolioApp> with WidgetsBindingObserver {
  StreamSubscription<SystemAccentColor>? _accentSub;
  final GlobalKey<NavigatorState> _navKey = GlobalKey<NavigatorState>();
  DesktopIntegration? _desktop;
  var _openingByHotkey = false;
  String _desktopSettingsSignature = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.session.addListener(_onSession);
    widget.appSettings.addListener(_onSettings);
    _applySessionSecurityPolicy();
    _applyAiSettings();
    widget.session.bootstrap();
    _initDesktopIntegration();
    _accentSub = SystemTheme.onChange.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _accentSub?.cancel();
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
      exit: l10n.exit,
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
        return OnboardingFlow(session: session);
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
