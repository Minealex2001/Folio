import 'dart:io';

import '../../app/app_settings.dart';

/// Intenta abrir Ollama o LM Studio en Windows cuando el usuario lo solicita al iniciar Folio.
class AiProviderLauncher {
  AiProviderLauncher._();

  static Future<void> tryLaunchProvider(AiProvider provider) async {
    if (!Platform.isWindows || provider == AiProvider.none) return;
    final path = switch (provider) {
      AiProvider.ollama => _firstExistingPath(_ollamaExePaths),
      AiProvider.lmStudio => _firstExistingPath(_lmStudioExePaths),
      AiProvider.folioCloud => null,
      AiProvider.none => null,
    };
    if (path == null) return;
    try {
      await Process.start(path, [], mode: ProcessStartMode.detached);
    } catch (_) {}
  }

  static String? _firstExistingPath(List<String> paths) {
    for (final p in paths) {
      if (p.trim().isEmpty) continue;
      try {
        if (File(p).existsSync()) return p;
      } catch (_) {}
    }
    return null;
  }

  static List<String> get _ollamaExePaths {
    final localAppData = Platform.environment['LOCALAPPDATA'] ?? '';
    final programFiles = Platform.environment['ProgramFiles'] ?? '';
    return [
      if (programFiles.isNotEmpty) '$programFiles\\Ollama\\ollama.exe',
      if (localAppData.isNotEmpty)
        '$localAppData\\Programs\\Ollama\\ollama.exe',
    ];
  }

  static List<String> get _lmStudioExePaths {
    final localAppData = Platform.environment['LOCALAPPDATA'] ?? '';
    final programFiles = Platform.environment['ProgramFiles'] ?? '';
    final programFilesX86 = Platform.environment['ProgramFiles(x86)'] ?? '';
    return [
      if (programFiles.isNotEmpty)
        '$programFiles\\LM Studio\\LM Studio.exe',
      if (programFilesX86.isNotEmpty)
        '$programFilesX86\\LM Studio\\LM Studio.exe',
      if (localAppData.isNotEmpty)
        '$localAppData\\Programs\\LM Studio\\LM Studio.exe',
      if (localAppData.isNotEmpty)
        '$localAppData\\LM-Studio\\LM Studio.exe',
    ];
  }
}
