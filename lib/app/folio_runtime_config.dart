import 'dart:io';

class FolioRuntimeConfig {
  const FolioRuntimeConfig({required this.integrationSecret});

  final String integrationSecret;

  static Future<FolioRuntimeConfig> load() async {
    final defineSecret = const String.fromEnvironment(
      'FOLIO_INTEGRATION_SECRET',
    ).trim();
    if (defineSecret.isNotEmpty) {
      return FolioRuntimeConfig(integrationSecret: defineSecret);
    }

    final envSecret =
        Platform.environment['FOLIO_INTEGRATION_SECRET']?.trim() ?? '';
    if (envSecret.isNotEmpty) {
      return FolioRuntimeConfig(integrationSecret: envSecret);
    }
    for (final fileName in const ['.env.local', '.env']) {
      final env = await _tryReadEnvFile(fileName);
      final secret = env['FOLIO_INTEGRATION_SECRET']?.trim() ?? '';
      if (secret.isNotEmpty) {
        return FolioRuntimeConfig(integrationSecret: secret);
      }
    }

    return const FolioRuntimeConfig(integrationSecret: '');
  }

  static Future<Map<String, String>> _tryReadEnvFile(String fileName) async {
    final file = File(fileName);
    if (!await file.exists()) return const <String, String>{};
    final content = await file.readAsString();
    return _parseEnv(content);
  }

  static Map<String, String> _parseEnv(String content) {
    final values = <String, String>{};
    for (final rawLine in content.split(RegExp(r'\r?\n'))) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      final separator = line.indexOf('=');
      if (separator <= 0) continue;
      final key = line.substring(0, separator).trim();
      if (key.isEmpty) continue;
      var value = line.substring(separator + 1).trim();
      if ((value.startsWith('"') && value.endsWith('"')) ||
          (value.startsWith("'") && value.endsWith("'"))) {
        value = value.substring(1, value.length - 1);
      }
      values[key] = value;
    }
    return values;
  }
}
