import 'dart:async';

import 'package:flutter/material.dart';
import 'package:system_theme/system_theme.dart';

import '../features/lock/lock_screen.dart';
import '../features/onboarding/onboarding_flow.dart';
import '../features/workspace/workspace_page.dart';
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

class _FolioAppState extends State<FolioApp> {
  StreamSubscription<SystemAccentColor>? _accentSub;

  @override
  void initState() {
    super.initState();
    widget.session.addListener(_onSession);
    widget.appSettings.addListener(_onSettings);
    widget.session.bootstrap();
    _accentSub = SystemTheme.onChange.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _accentSub?.cancel();
    widget.appSettings.removeListener(_onSettings);
    widget.session.removeListener(_onSession);
    super.dispose();
  }

  void _onSession() {
    if (mounted) setState(() {});
  }

  void _onSettings() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final seed = SystemTheme.accentColor.accent;
    return MaterialApp(
      title: 'Folio',
      theme: folioLightTheme(seed),
      darkTheme: folioDarkTheme(seed),
      themeMode: widget.appSettings.themeMode,
      home: _HomeByState(
        session: widget.session,
        appSettings: widget.appSettings,
      ),
    );
  }
}

class _HomeByState extends StatelessWidget {
  const _HomeByState({required this.session, required this.appSettings});

  final VaultSession session;
  final AppSettings appSettings;

  @override
  Widget build(BuildContext context) {
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
                  'Cargando…',
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
        return WorkspacePage(session: session, appSettings: appSettings);
    }
  }
}
