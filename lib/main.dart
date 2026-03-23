import 'package:flutter/material.dart';
import 'package:system_theme/system_theme.dart';

import 'app/app_settings.dart';
import 'app/folio_app.dart';
import 'session/vault_session.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemTheme.fallbackColor = const Color(0xFF455A64);
  await SystemTheme.accentColor.load();
  final appSettings = AppSettings();
  await appSettings.load();
  final session = VaultSession();
  runApp(FolioApp(session: session, appSettings: appSettings));
}
