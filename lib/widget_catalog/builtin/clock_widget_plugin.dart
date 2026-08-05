import 'dart:async';

import 'package:intl/intl.dart';
import 'package:flutter/material.dart';

import '../../app/app_settings.dart';
import '../../config/models/widget_instance_config.dart';
import '../../l10n/generated/app_localizations.dart';
import '../folio_widget_plugin.dart';
import '../widget_plugin_context.dart';

/// Reloj en vivo — hasta hace poco era chrome fijo hardcodeado en la
/// cabecera de `WorkspaceHomeView` (imposible de quitar, bug real
/// reportado). Ahora es un widget del catálogo como cualquier otro,
/// seleccionable/editable desde el editor visual y removible/re-añadible
/// desde el editor de dashboard — e incluye deliberadamente el saludo,
/// fecha y titular ("Tu espacio") que antes eran chrome aparte: el usuario
/// los identifica como una sola pieza visual, así que ahora son un solo
/// widget en vez de un widget + texto fijo alrededor.
class ClockWidgetPlugin extends FolioWidgetPlugin {
  const ClockWidgetPlugin();

  @override
  String get id => 'clock';

  @override
  String displayName(BuildContext context) => 'Reloj';

  @override
  IconData get icon => Icons.access_time_rounded;

  @override
  bool get allowMultipleInstances => false;

  @override
  double get defaultHeight => 300;

  @override
  Widget build(
    BuildContext context,
    WidgetInstanceConfig instance,
    WidgetPluginContext ctx,
  ) {
    return _ClockHero(instance: instance, appSettings: ctx.appSettings);
  }

  /// Formato de hora (24h, segundos, zona horaria) — antes vivía en un
  /// botón aparte en la cabecera de inicio ("Formato de reloj y
  /// columnas"), fuera de lugar una vez el reloj se volvió un widget más.
  /// Ahora es la configuración propia de ESTE widget, por-instancia
  /// (`WidgetInstanceConfig.settings`) — `buildSettings` no recibe
  /// `WidgetPluginContext`, así que no hay forma de leer el valor previo
  /// de `AppSettings` aquí como default inicial; empieza en `false`
  /// (12h, sin segundos, sin zona) hasta que el usuario lo ajuste, igual
  /// que cualquier otro widget nuevo que se añade al dashboard.
  @override
  Widget? buildSettings(
    BuildContext context,
    WidgetInstanceConfig instance,
    ValueChanged<Map<String, dynamic>> onSettingsChanged,
  ) {
    final settings = instance.settings;
    bool readBool(String key) {
      final raw = settings[key];
      return raw is bool ? raw : false;
    }

    void set(String key, bool value) {
      onSettingsChanged({...settings, key: value});
    }

    return StatefulBuilder(
      builder: (context, setState) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwitchListTile(
              title: const Text('Formato 24 horas'),
              value: readBool('clock24Hour'),
              onChanged: (v) => setState(() => set('clock24Hour', v)),
            ),
            SwitchListTile(
              title: const Text('Mostrar segundos'),
              value: readBool('clockShowSeconds'),
              onChanged: (v) => setState(() => set('clockShowSeconds', v)),
            ),
            SwitchListTile(
              title: const Text('Mostrar zona horaria'),
              value: readBool('clockShowTimezone'),
              onChanged: (v) => setState(() => set('clockShowTimezone', v)),
            ),
          ],
        );
      },
    );
  }
}

class _ClockHero extends StatefulWidget {
  const _ClockHero({required this.instance, required this.appSettings});

  final WidgetInstanceConfig instance;
  final AppSettings appSettings;

  @override
  State<_ClockHero> createState() => _ClockHeroState();
}

class _ClockHeroState extends State<_ClockHero> {
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

  static String _formatUtcOffset(Duration d) {
    final sign = d.isNegative ? '-' : '+';
    final total = d.inMinutes.abs();
    final h = total ~/ 60;
    final m = total % 60;
    return 'UTC$sign${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  bool _boolSetting(String key, bool legacyDefault) {
    final raw = widget.instance.settings[key];
    return raw is bool ? raw : legacyDefault;
  }

  String _greeting(AppLocalizations l10n) {
    final h = DateTime.now().hour;
    if (h >= 5 && h < 12) return l10n.workspaceHomeGreetingMorning;
    if (h < 18) return l10n.workspaceHomeGreetingAfternoon;
    if (h < 22) return l10n.workspaceHomeGreetingEvening;
    return l10n.workspaceHomeGreetingNight;
  }

  String _timeString(String locale) {
    final sec = _boolSetting(
      'clockShowSeconds',
      widget.appSettings.workspaceHomeClockShowSeconds,
    );
    final h24 = _boolSetting(
      'clock24Hour',
      widget.appSettings.workspaceHomeClock24Hour,
    );
    if (h24) {
      return sec
          ? DateFormat('HH:mm:ss', locale).format(_now)
          : DateFormat('HH:mm', locale).format(_now);
    }
    return sec
        ? DateFormat.jms(locale).format(_now)
        : DateFormat.jm(locale).format(_now);
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final showTimezone = _boolSetting(
      'clockShowTimezone',
      widget.appSettings.workspaceHomeClockShowTimezone,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _greeting(l10n),
          style: theme.textTheme.titleMedium?.copyWith(
            color: scheme.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          DateFormat.yMMMMEEEEd(locale).format(_now),
          style: theme.textTheme.titleMedium?.copyWith(
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _timeString(locale),
          style: theme.textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: scheme.onSurface,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        if (showTimezone) ...[
          const SizedBox(height: 4),
          Text(
            '${_now.timeZoneName} · ${_formatUtcOffset(_now.timeZoneOffset)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        const SizedBox(height: 16),
        Text(
          l10n.workspaceHomeHeadline,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.workspaceHomeSubtitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
            height: 1.45,
          ),
        ),
      ],
    );
  }
}
