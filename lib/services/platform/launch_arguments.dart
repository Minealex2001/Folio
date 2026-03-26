import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class PlatformLaunchArguments {
  PlatformLaunchArguments._();

  static const _channel = MethodChannel('folio/windows_launch_args');
  static StreamController<List<String>>? _launchArgumentsController;
  static final List<List<String>> _pendingLaunchArguments = <List<String>>[];
  static var _handlerRegistered = false;

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

  static Stream<List<String>> launchArguments() {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.windows) {
      return const Stream<List<String>>.empty();
    }
    _ensureHandlerRegistered();
    return _controller.stream;
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

  static StreamController<List<String>> get _controller {
    return _launchArgumentsController ??=
        StreamController<List<String>>.broadcast(onListen: _flushPending);
  }

  static void _ensureHandlerRegistered() {
    if (_handlerRegistered) return;
    _handlerRegistered = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'launchArguments') {
        throw MissingPluginException(
          'Unsupported launch argument method: ${call.method}',
        );
      }
      _emit(_asStringList(call.arguments));
      return null;
    });
  }

  static void _emit(List<String> args) {
    if (args.isEmpty) return;
    final controller = _controller;
    if (controller.hasListener) {
      controller.add(args);
      return;
    }
    _pendingLaunchArguments.add(args);
  }

  static void _flushPending() {
    if (_pendingLaunchArguments.isEmpty) return;
    final pending = List<List<String>>.from(_pendingLaunchArguments);
    _pendingLaunchArguments.clear();
    for (final args in pending) {
      _controller.add(args);
    }
  }

  static List<String> _asStringList(Object? raw) {
    if (raw is List) {
      return raw.map((entry) => entry.toString()).toList();
    }
    if (raw == null) {
      return const <String>[];
    }
    return <String>[raw.toString()];
  }
}
