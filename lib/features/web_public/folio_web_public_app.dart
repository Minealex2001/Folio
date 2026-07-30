import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../../app/folio_theme.dart';
import '../../config/folio_web_urls.dart';
import '../../l10n/generated/app_localizations.dart';
import 'public_vault_share_page.dart';
import 'reset_password_page.dart';
import 'verify_email_page.dart';

/// MaterialApp mínimo para rutas públicas de Flutter web (sin vault / onboarding).
/// El share `/s/{token}` reutiliza [BlockEditor] en solo lectura (misma app).
class FolioWebPublicApp extends StatelessWidget {
  const FolioWebPublicApp({super.key, required this.route});

  final FolioWebPublicRoute route;

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF00F3FF);
    final light = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.light,
    );
    final dark = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.dark,
    );
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Folio',
      theme: folioLightTheme(light),
      darkTheme: folioDarkTheme(dark),
      themeMode: ThemeMode.system,
      locale: const Locale('es'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: switch (route) {
        FolioWebPublicShareRoute(:final token) =>
          PublicVaultSharePage(token: token),
        FolioWebResetPasswordRoute(:final token) =>
          ResetPasswordPage(token: token),
        FolioWebVerifyEmailRoute(:final token) =>
          VerifyEmailPage(token: token),
      },
    );
  }
}
