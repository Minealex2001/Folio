import 'dart:io';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/widgets.dart';
import 'package:window_manager/window_manager.dart';

import 'meeting_worker_host.dart';
import 'meeting_worker_protocol.dart';

/// Entrypoint del proceso aparte de reunión (mismo binario + `--meeting-worker`).
Future<void> runMeetingWorker(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.macOS)) {
    try {
      await windowManager.ensureInitialized();
      await windowManager.setPreventClose(false);
      await windowManager.setSkipTaskbar(true);
      await windowManager.setTitle('Folio Meeting Worker');
      // Ocultar lo antes posible para no mostrar una segunda ventana.
      await windowManager.hide();
    } catch (_) {
      // Sin window_manager (p.ej. tests) seguimos con el host IPC.
    }
  }

  final port = MeetingWorkerProtocol.parseIpcPort(args);
  if (port == null || port <= 0 || port > 65535) {
    stderr.writeln('folio meeting worker: missing or invalid --ipc-port');
    exitCode = 2;
    return;
  }

  Socket? socket;
  try {
    socket = await Socket.connect(
      InternetAddress.loopbackIPv4,
      port,
      timeout: const Duration(seconds: 15),
    );
  } catch (e) {
    stderr.writeln('folio meeting worker: failed to connect IPC: $e');
    exitCode = 3;
    return;
  }

  final host = MeetingWorkerHost(socket: socket);
  await host.run();
  exit(0);
}
