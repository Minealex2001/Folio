import 'package:flutter/material.dart';
import '../../l10n/generated/app_localizations.dart';

import '../../config/models/widget_instance_config.dart';
import '../../services/weather/weather_client.dart';
import '../folio_widget_plugin.dart';
import '../widget_plugin_context.dart';
import 'builtin_widget_card.dart';

/// Clima actual vía Open-Meteo (ciudad en settings de instancia).
class WeatherWidgetPlugin extends FolioWidgetPlugin {
  const WeatherWidgetPlugin();

  static final WeatherClient _client = WeatherClient();

  @override
  String get id => 'weather';

  @override
  String displayName(BuildContext context) => AppLocalizations.of(context).widgetWeather;

  @override
  IconData get icon => Icons.wb_sunny_outlined;

  @override
  bool get allowMultipleInstances => false;

  @override
  double get defaultHeight => 140;

  static String _cityOf(WidgetInstanceConfig instance) {
    final raw = instance.settings['weatherCity'];
    return raw is String ? raw.trim() : '';
  }

  static bool _celsiusOf(WidgetInstanceConfig instance) {
    final raw = instance.settings['weatherCelsius'];
    return raw is bool ? raw : true;
  }

  @override
  Widget build(
    BuildContext context,
    WidgetInstanceConfig instance,
    WidgetPluginContext ctx,
  ) {
    return BuiltinWidgetCard(
      icon: icon,
      title: displayName(context),
      child: _WeatherBody(
        city: _cityOf(instance),
        celsius: _celsiusOf(instance),
        client: _client,
      ),
    );
  }

  @override
  Widget? buildSettings(
    BuildContext context,
    WidgetInstanceConfig instance,
    ValueChanged<Map<String, dynamic>> onSettingsChanged,
  ) {
    final settings = Map<String, dynamic>.from(instance.settings);
    final cityController = TextEditingController(text: _cityOf(instance));
    var celsius = _celsiusOf(instance);

    return StatefulBuilder(
      builder: (context, setState) {
        final l10n = AppLocalizations.of(context);
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: cityController,
              decoration: InputDecoration(
                labelText: l10n.widgetWeatherCityLabel,
                hintText: l10n.widgetWeatherCityHint,
              ),
              onChanged: (v) {
                onSettingsChanged({...settings, 'weatherCity': v.trim()});
                settings['weatherCity'] = v.trim();
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.widgetWeatherUseCelsius),
              subtitle: Text(
                celsius ? l10n.widgetWeatherCelsiusUnit : l10n.widgetWeatherFahrenheitUnit,
              ),
              value: celsius,
              onChanged: (v) {
                setState(() => celsius = v);
                settings['weatherCelsius'] = v;
                onSettingsChanged({...settings});
              },
            ),
          ],
        );
      },
    );
  }
}

class _WeatherBody extends StatefulWidget {
  const _WeatherBody({
    required this.city,
    required this.celsius,
    required this.client,
  });

  final String city;
  final bool celsius;
  final WeatherClient client;

  @override
  State<_WeatherBody> createState() => _WeatherBodyState();
}

class _WeatherBodyState extends State<_WeatherBody> {
  Future<WeatherSnapshot>? _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void didUpdateWidget(covariant _WeatherBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.city != widget.city || oldWidget.celsius != widget.celsius) {
      _reload();
    }
  }

  void _reload() {
    if (widget.city.isEmpty) {
      _future = null;
      return;
    }
    _future = widget.client.fetchCurrent(
      city: widget.city,
      celsius: widget.celsius,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.city.isEmpty) {
      return BuiltinWidgetEmpty(
        message: AppLocalizations.of(context).widgetWeatherConfigureCity,
      );
    }

    return FutureBuilder<WeatherSnapshot>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
        if (snap.hasError) {
          return BuiltinWidgetEmpty(
            message: snap.error?.toString() ??
                AppLocalizations.of(context).widgetWeatherLoadError,
          );
        }
        final data = snap.data!;
        final scheme = Theme.of(context).colorScheme;
        return Row(
          children: [
            Icon(data.conditionIcon, size: 36, color: scheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    data.temperatureLabel,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  Text(
                    data.conditionLabel,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  Text(
                    data.cityLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
