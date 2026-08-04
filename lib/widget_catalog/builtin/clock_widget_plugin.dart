import 'dart:async';

import 'package:flutter/material.dart';

import '../../config/models/widget_instance_config.dart';
import '../folio_widget_plugin.dart';
import '../widget_plugin_context.dart';
import 'builtin_widget_card.dart';

/// Reloj en vivo — ejemplo simple del catálogo nuevo pedido en el brief:
/// dato real (la hora del sistema), sin integración externa.
class ClockWidgetPlugin extends FolioWidgetPlugin {
  const ClockWidgetPlugin();

  @override
  String get id => 'clock';

  @override
  String displayName(BuildContext context) => 'Reloj';

  @override
  IconData get icon => Icons.access_time_rounded;

  @override
  Widget build(
    BuildContext context,
    WidgetInstanceConfig instance,
    WidgetPluginContext ctx,
  ) {
    return BuiltinWidgetCard(
      icon: icon,
      title: displayName(context),
      child: const _LiveClock(),
    );
  }
}

class _LiveClock extends StatefulWidget {
  const _LiveClock();

  @override
  State<_LiveClock> createState() => _LiveClockState();
}

class _LiveClockState extends State<_LiveClock> {
  late DateTime _now = DateTime.now();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hh = _now.hour.toString().padLeft(2, '0');
    final mm = _now.minute.toString().padLeft(2, '0');
    final ss = _now.second.toString().padLeft(2, '0');
    return Center(
      child: Text(
        '$hh:$mm:$ss',
        style: Theme.of(
          context,
        ).textTheme.headlineMedium?.copyWith(fontFeatures: const [
          FontFeature.tabularFigures(),
        ]),
      ),
    );
  }
}
