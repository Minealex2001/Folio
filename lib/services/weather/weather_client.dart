import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// Cliente mínimo Open-Meteo (sin API key): geocode + clima actual.
class WeatherClient {
  WeatherClient({http.Client? httpClient}) : _http = httpClient ?? http.Client();

  final http.Client _http;

  static const _geocodeHost = 'geocoding-api.open-meteo.com';
  static const _forecastHost = 'api.open-meteo.com';

  final Map<String, ({DateTime at, WeatherSnapshot snap})> _cache = {};
  static const _cacheTtl = Duration(minutes: 15);

  Future<WeatherSnapshot> fetchCurrent({
    required String city,
    required bool celsius,
  }) async {
    final key = '${city.trim().toLowerCase()}|${celsius ? 'c' : 'f'}';
    final cached = _cache[key];
    if (cached != null && DateTime.now().difference(cached.at) < _cacheTtl) {
      return cached.snap;
    }

    final place = await _geocode(city.trim());
    if (place == null) {
      throw WeatherException('No se encontró la ciudad "$city".');
    }

    final unit = celsius ? 'celsius' : 'fahrenheit';
    final uri = Uri.https(_forecastHost, '/v1/forecast', {
      'latitude': place.lat.toString(),
      'longitude': place.lon.toString(),
      'current': 'temperature_2m,weather_code,wind_speed_10m',
      'temperature_unit': unit,
      'timezone': 'auto',
    });
    final res = await _http.get(uri).timeout(const Duration(seconds: 12));
    if (res.statusCode != 200) {
      throw WeatherException('Error de clima (${res.statusCode}).');
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final current = json['current'] as Map<String, dynamic>?;
    if (current == null) {
      throw WeatherException('Respuesta de clima incompleta.');
    }

    final snap = WeatherSnapshot(
      cityLabel: place.name,
      temperature: (current['temperature_2m'] as num).toDouble(),
      weatherCode: (current['weather_code'] as num?)?.toInt() ?? 0,
      windSpeed: (current['wind_speed_10m'] as num?)?.toDouble(),
      celsius: celsius,
    );
    _cache[key] = (at: DateTime.now(), snap: snap);
    return snap;
  }

  Future<_GeoPlace?> _geocode(String city) async {
    if (city.isEmpty) return null;
    final uri = Uri.https(_geocodeHost, '/v1/search', {
      'name': city,
      'count': '1',
      'language': 'es',
      'format': 'json',
    });
    final res = await _http.get(uri).timeout(const Duration(seconds: 12));
    if (res.statusCode != 200) return null;
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final results = json['results'] as List<dynamic>?;
    if (results == null || results.isEmpty) return null;
    final first = results.first as Map<String, dynamic>;
    final name = first['name'] as String? ?? city;
    final admin = first['admin1'] as String?;
    final country = first['country'] as String?;
    final label = [
      name,
      if (admin != null && admin.isNotEmpty) admin,
      if (country != null && country.isNotEmpty) country,
    ].join(', ');
    return _GeoPlace(
      name: label,
      lat: (first['latitude'] as num).toDouble(),
      lon: (first['longitude'] as num).toDouble(),
    );
  }
}

class WeatherSnapshot {
  const WeatherSnapshot({
    required this.cityLabel,
    required this.temperature,
    required this.weatherCode,
    required this.celsius,
    this.windSpeed,
  });

  final String cityLabel;
  final double temperature;
  final int weatherCode;
  final bool celsius;
  final double? windSpeed;

  String get temperatureLabel {
    final unit = celsius ? '°C' : '°F';
    return '${temperature.round()}$unit';
  }

  String get conditionLabel => weatherCodeLabel(weatherCode);

  IconData get conditionIcon => weatherCodeIcon(weatherCode);
}

class WeatherException implements Exception {
  WeatherException(this.message);
  final String message;

  @override
  String toString() => message;
}

class _GeoPlace {
  const _GeoPlace({
    required this.name,
    required this.lat,
    required this.lon,
  });
  final String name;
  final double lat;
  final double lon;
}

String weatherCodeLabel(int code) {
  if (code == 0) return 'Despejado';
  if (code <= 3) return 'Parcialmente nublado';
  if (code <= 48) return 'Niebla';
  if (code <= 57) return 'Llovizna';
  if (code <= 67) return 'Lluvia';
  if (code <= 77) return 'Nieve';
  if (code <= 82) return 'Chubascos';
  if (code <= 86) return 'Chubascos de nieve';
  if (code <= 99) return 'Tormenta';
  return 'Desconocido';
}

IconData weatherCodeIcon(int code) {
  if (code == 0) return Icons.wb_sunny_rounded;
  if (code <= 3) return Icons.wb_cloudy_rounded;
  if (code <= 48) return Icons.cloud_rounded;
  if (code <= 67) return Icons.umbrella_rounded;
  if (code <= 77) return Icons.ac_unit_rounded;
  if (code <= 82) return Icons.grain_rounded;
  if (code <= 99) return Icons.thunderstorm_rounded;
  return Icons.wb_cloudy_outlined;
}
