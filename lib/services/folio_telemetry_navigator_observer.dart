import 'dart:async';

import 'package:flutter/material.dart';

import '../app/app_settings.dart';
import 'folio_telemetry.dart';

/// Registra navegación de alto nivel para [FolioTelemetry] (sin listeners de Firestore).
///
/// Usa [RouteSettings.name] cuando exista; si no, un etiqueta genérica por tipo de ruta.
class FolioTelemetryNavigatorObserver extends NavigatorObserver {
  FolioTelemetryNavigatorObserver(this._settings);

  final AppSettings Function() _settings;

  final Map<String, DateTime> _lastNavAt = {};
  static const _throttle = Duration(seconds: 2);

  String _routeLabel(Route<dynamic>? route) {
    if (route == null) return '';
    final name = route.settings.name;
    if (name != null && name.trim().isNotEmpty) return name.trim();
    return 'route_${route.runtimeType}';
  }

  void _maybeLog(Route<dynamic>? fromRoute, Route<dynamic>? toRoute) {
    final settings = _settings();
    if (!settings.telemetryEnabled) return;

    final from = _routeLabel(fromRoute);
    final to = _routeLabel(toRoute);
    if (to.isEmpty) return;

    final key = '$from|$to';
    final now = DateTime.now();
    final last = _lastNavAt[key];
    if (last != null && now.difference(last) < _throttle) return;
    _lastNavAt[key] = now;

    unawaited(FolioTelemetry.logNavigation(settings, from, to));
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _maybeLog(previousRoute, route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute != null) {
      _maybeLog(oldRoute, newRoute);
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _maybeLog(route, previousRoute);
  }
}
