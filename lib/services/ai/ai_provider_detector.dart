import 'dart:io';

import '../../app/app_settings.dart';
import 'lmstudio_ai_service.dart';
import 'ollama_ai_service.dart';

class AiProviderDetectionResult {
  const AiProviderDetectionResult({
    required this.provider,
    required this.baseUrl,
    required this.installed,
    required this.reachable,
    required this.hints,
  });

  final AiProvider provider;
  final Uri baseUrl;
  final bool installed;
  final bool reachable;
  final List<String> hints;
}

class AiProviderDetectionSummary {
  const AiProviderDetectionSummary({
    required this.ollama,
    required this.lmStudio,
    required this.recommendedProvider,
  });

  final AiProviderDetectionResult ollama;
  final AiProviderDetectionResult lmStudio;
  final AiProvider? recommendedProvider;

  bool get anyInstalled => ollama.installed || lmStudio.installed;
  bool get anyReachable => ollama.reachable || lmStudio.reachable;
}

class AiProviderDetector {
  const AiProviderDetector();

  Future<AiProviderDetectionSummary> detect({
    Duration timeout = const Duration(seconds: 2),
    AiProvider preferredProvider = AiProvider.none,
  }) async {
    final ollamaInstalled = await _detectInstalled(AiProvider.ollama);
    final lmStudioInstalled = await _detectInstalled(AiProvider.lmStudio);
    final ollamaReachable = await _detectReachable(AiProvider.ollama, timeout);
    final lmStudioReachable = await _detectReachable(AiProvider.lmStudio, timeout);

    final ollamaResult = AiProviderDetectionResult(
      provider: AiProvider.ollama,
      baseUrl: Uri.parse(AppSettings.defaultOllamaUrl),
      installed: ollamaInstalled.$1,
      reachable: ollamaReachable,
      hints: ollamaInstalled.$2,
    );
    final lmStudioResult = AiProviderDetectionResult(
      provider: AiProvider.lmStudio,
      baseUrl: Uri.parse(AppSettings.defaultLmStudioUrl),
      installed: lmStudioInstalled.$1,
      reachable: lmStudioReachable,
      hints: lmStudioInstalled.$2,
    );
    final recommended = _pickRecommendedProvider(
      ollama: ollamaResult,
      lmStudio: lmStudioResult,
      preferredProvider: preferredProvider,
    );
    return AiProviderDetectionSummary(
      ollama: ollamaResult,
      lmStudio: lmStudioResult,
      recommendedProvider: recommended,
    );
  }

  AiProvider? _pickRecommendedProvider({
    required AiProviderDetectionResult ollama,
    required AiProviderDetectionResult lmStudio,
    required AiProvider preferredProvider,
  }) {
    final reachable = <AiProvider>[
      if (ollama.reachable) AiProvider.ollama,
      if (lmStudio.reachable) AiProvider.lmStudio,
    ];
    if (reachable.isEmpty) return null;
    if (reachable.length == 1) return reachable.first;
    if (preferredProvider != AiProvider.none &&
        reachable.contains(preferredProvider)) {
      return preferredProvider;
    }
    return AiProvider.ollama;
  }

  Future<(bool, List<String>)> _detectInstalled(AiProvider provider) async {
    if (!Platform.isWindows) {
      return (false, const <String>[]);
    }
    final hints = <String>[];
    final executableNames = switch (provider) {
      AiProvider.ollama => const ['ollama.exe', 'ollama'],
      AiProvider.lmStudio => const ['LM Studio.exe', 'LMStudio.exe', 'lms.exe'],
      AiProvider.none => const <String>[],
      AiProvider.quillCloud => const <String>[],
    };

    for (final exe in executableNames) {
      try {
        final where = await Process.run('where', [exe]);
        if (where.exitCode == 0) {
          final out = (where.stdout ?? '').toString().trim();
          if (out.isNotEmpty) {
            hints.add(out.split(RegExp(r'[\r\n]+')).first);
            return (true, hints);
          }
        }
      } catch (_) {
        // Ignorar y seguir con otros métodos.
      }
    }

    for (final path in _commonInstallPaths(provider)) {
      if (File(path).existsSync()) {
        hints.add(path);
        return (true, hints);
      }
    }

    final processNames = switch (provider) {
      AiProvider.ollama => const ['ollama.exe'],
      AiProvider.lmStudio => const ['LM Studio.exe', 'LMStudio.exe', 'lms.exe'],
      AiProvider.none => const <String>[],
      AiProvider.quillCloud => const <String>[],
    };
    for (final processName in processNames) {
      try {
        final running = await Process.run('tasklist', [
          '/FI',
          'IMAGENAME eq $processName',
        ]);
        if (running.exitCode == 0) {
          final out = (running.stdout ?? '').toString();
          if (out.toLowerCase().contains(processName.toLowerCase())) {
            hints.add(processName);
            return (true, hints);
          }
        }
      } catch (_) {
        // Ignorar y seguir.
      }
    }
    return (false, hints);
  }

  List<String> _commonInstallPaths(AiProvider provider) {
    final localAppData = Platform.environment['LOCALAPPDATA'] ?? '';
    final programFiles = Platform.environment['ProgramFiles'] ?? '';
    final programFilesX86 = Platform.environment['ProgramFiles(x86)'] ?? '';
    return switch (provider) {
      AiProvider.ollama => [
          if (programFiles.isNotEmpty) '$programFiles\\Ollama\\ollama.exe',
          if (localAppData.isNotEmpty)
            '$localAppData\\Programs\\Ollama\\ollama.exe',
        ],
      AiProvider.lmStudio => [
          if (programFiles.isNotEmpty)
            '$programFiles\\LM Studio\\LM Studio.exe',
          if (programFilesX86.isNotEmpty)
            '$programFilesX86\\LM Studio\\LM Studio.exe',
          if (localAppData.isNotEmpty)
            '$localAppData\\Programs\\LM Studio\\LM Studio.exe',
          if (localAppData.isNotEmpty)
            '$localAppData\\LM-Studio\\LM Studio.exe',
        ],
      AiProvider.none => const [],
      AiProvider.quillCloud => const [],
    };
  }

  Future<bool> _detectReachable(AiProvider provider, Duration timeout) async {
    try {
      switch (provider) {
        case AiProvider.ollama:
          final s = OllamaAiService(
            baseUrl: Uri.parse(AppSettings.defaultOllamaUrl),
            timeout: timeout,
            defaultModel: AppSettings.defaultOllamaModel,
          );
          await s.ping();
          return true;
        case AiProvider.lmStudio:
          final s = LmStudioAiService(
            baseUrl: Uri.parse(AppSettings.defaultLmStudioUrl),
            timeout: timeout,
            defaultModel: AppSettings.defaultLmStudioModel,
          );
          await s.ping();
          return true;
        case AiProvider.none:
        case AiProvider.quillCloud:
          return false;
      }
    } catch (_) {
      return false;
    }
  }
}
