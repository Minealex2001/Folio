import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class PlatformLaunchArguments {
  PlatformLaunchArguments._();

  static const _channel = MethodChannel('folio/windows_launch_args');

  static Future<List<String>> initialArguments() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.windows) {
      return const <String>[];
    }
    try {
      final raw = await _channel.invokeMethod<List<dynamic>>(
        'getInitialLaunchArguments',
      );
      return raw?.map((entry) => entry.toString()).toList() ?? const <String>[];
    } on MissingPluginException {
      // Puede ocurrir durante hot restart antes de reiniciar el runner nativo.
      return const <String>[];
    }
  }

  static Uri? firstUriWithScheme(List<String> args, String scheme) {
    for (final arg in args) {
      final uri = Uri.tryParse(arg);
      if (uri != null && uri.scheme == scheme) {
        return uri;
      }
    }
    return null;
  }
}
