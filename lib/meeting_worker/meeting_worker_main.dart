import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';

import 'meeting_worker_host.dart';
import 'meeting_worker_protocol.dart';

/// Entrypoint del proceso aparte de reunión (mismo binario + `--meeting-worker`).
Future<void> runMeetingWorker(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  final port = MeetingWorkerProtocol.parseIpcPort(args);
  if (port == null || port <= 0 || port > 65535) {
    stderr.writeln('folio meeting worker: missing or invalid --ipc-port');
    exit(2);
  }

  // runApp mantiene vivo el engine/plugins (record, system_audio). Sin esto,
  // el embedder de Windows puede tumbar el proceso al forzar el primer frame.
  runApp(_MeetingWorkerApp(port: port));
}

class _MeetingWorkerApp extends StatefulWidget {
  const _MeetingWorkerApp({required this.port});

  final int port;

  @override
  State<_MeetingWorkerApp> createState() => _MeetingWorkerAppState();
}

class _MeetingWorkerAppState extends State<_MeetingWorkerApp> {
  @override
  void initState() {
    super.initState();
    unawaited(_run());
  }

  Future<void> _run() async {
    Socket? socket;
    try {
      socket = await Socket.connect(
        InternetAddress.loopbackIPv4,
        widget.port,
        timeout: const Duration(seconds: 30),
      );
      final host = MeetingWorkerHost(socket: socket);
      await host.run();
      exit(0);
    } catch (e, st) {
      stderr.writeln('folio meeting worker failed: $e');
      stderr.writeln('$st');
      try {
        await socket?.close();
      } catch (_) {}
      exit(3);
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Directionality(
      textDirection: TextDirection.ltr,
      child: SizedBox.shrink(),
    );
  }
}
