import 'package:flutter/material.dart';

import '../../app/folio_theme.dart';
import '../../config/folio_web_urls.dart';
import 'public_vault_share_page.dart';
import 'reset_password_page.dart';
import 'verify_email_page.dart';

/// MaterialApp mínimo para rutas públicas de Flutter web (sin vault / onboarding).
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
