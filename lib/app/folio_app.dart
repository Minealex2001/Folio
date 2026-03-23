import 'package:flutter/material.dart';

import '../features/lock/lock_screen.dart';
import '../features/onboarding/onboarding_flow.dart';
import '../features/workspace/workspace_page.dart';
import '../session/vault_session.dart';

class FolioApp extends StatefulWidget {
  const FolioApp({super.key, required this.session});

  final VaultSession session;

  @override
  State<FolioApp> createState() => _FolioAppState();
}

class _FolioAppState extends State<FolioApp> {
  @override
  void initState() {
    super.initState();
    widget.session.addListener(_onSession);
    widget.session.bootstrap();
  }

  @override
  void dispose() {
    widget.session.removeListener(_onSession);
    super.dispose();
  }

  void _onSession() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF455A64),
      brightness: Brightness.light,
    );
    return MaterialApp(
      title: 'Folio',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: colorScheme.surface,
        appBarTheme: AppBarTheme(
          centerTitle: false,
          elevation: 0,
          scrolledUnderElevation: 1,
          backgroundColor: colorScheme.surfaceContainerLow,
          foregroundColor: colorScheme.onSurface,
          surfaceTintColor: colorScheme.surfaceTint,
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: colorScheme.surfaceContainerLowest,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: colorScheme.outlineVariant),
          ),
        ),
        dividerTheme: DividerThemeData(
          color: colorScheme.outlineVariant,
          thickness: 1,
        ),
        listTileTheme: ListTileThemeData(
          iconColor: colorScheme.onSurfaceVariant,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          horizontalTitleGap: 12,
          minLeadingWidth: 40,
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        dialogTheme: DialogThemeData(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: colorScheme.outlineVariant),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: colorScheme.outlineVariant),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: colorScheme.primary, width: 2),
          ),
        ),
      ),
      home: _HomeByState(session: widget.session),
    );
  }
}

class _HomeByState extends StatelessWidget {
  const _HomeByState({required this.session});

  final VaultSession session;

  @override
  Widget build(BuildContext context) {
    switch (session.state) {
      case VaultFlowState.initializing:
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      case VaultFlowState.needsOnboarding:
        return OnboardingFlow(session: session);
      case VaultFlowState.locked:
        return LockScreen(session: session);
      case VaultFlowState.unlocked:
        return WorkspacePage(session: session);
    }
  }
}
