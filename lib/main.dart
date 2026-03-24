import 'package:flutter/material.dart';
import 'package:system_theme/system_theme.dart';

import 'app/app_settings.dart';
import 'app/folio_app.dart';
import 'app/folio_runtime_config.dart';
import 'services/platform/launch_arguments.dart';
import 'session/vault_session.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemTheme.fallbackColor = const Color(0xFF455A64);
  await SystemTheme.accentColor.load();
  final runtimeConfig = await FolioRuntimeConfig.load();
  final appSettings = AppSettings(
    integrationSecret: runtimeConfig.integrationSecret,
  );
  await appSettings.load();
  final session = VaultSession();
  final initialLaunchArgs = await PlatformLaunchArguments.initialArguments();
  runApp(
    FolioApp(
      session: session,
      appSettings: appSettings,
      initialLaunchArgs: initialLaunchArgs,
    ),
  );
}
