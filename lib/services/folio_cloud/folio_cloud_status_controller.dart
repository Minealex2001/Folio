import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'folio_cloud_status.dart';

/// Poll + cache del estado público Folio Cloud (Minealex).
class FolioCloudStatusController extends ChangeNotifier {
  FolioCloudStatusController({
    this.pollInterval = const Duration(minutes: 5),
    Future<FolioCloudStatusSnapshot> Function()? fetch,
  }) : _fetch = fetch ?? fetchFolioCloudStatus;

  final Duration pollInterval;
  final Future<FolioCloudStatusSnapshot> Function() _fetch;

  static const _prefsDismissKey = 'folio_cloud_status_banner_dismissed';

  FolioCloudStatusSnapshot? _snapshot;
  Object? _lastError;
  bool _loading = false;
  bool _appInForeground = true;
  String? _dismissedFingerprint;
  bool _dismissLoaded = false;
  Timer? _pollTimer;
  bool _started = false;
  bool _disposed = false;

  FolioCloudStatusSnapshot? get snapshot => _snapshot;
  Object? get lastError => _lastError;
  bool get loading => _loading;
  bool get appInForeground => _appInForeground;

  bool get bannerVisible {
    final snap = _snapshot;
    if (snap == null || !snap.shouldShowBanner) return false;
    // Evitar flash antes de cargar el dismiss persistido.
    if (!_dismissLoaded) return false;
    final fp = _bannerFingerprint(snap);
    if (fp.isEmpty) return false;
    return fp != _dismissedFingerprint;
  }

  /// Arranque no bloqueante + polling.
  void start() {
    if (_started || _disposed) return;
    _started = true;
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    await _loadDismissed();
    if (_disposed) return;
    await refresh();
    if (_disposed) return;
    _restartPollTimer();
  }

  void setAppInForeground(bool foreground) {
    if (_appInForeground == foreground) return;
    _appInForeground = foreground;
    if (foreground) {
      unawaited(refresh());
      _restartPollTimer();
    } else {
      _pollTimer?.cancel();
      _pollTimer = null;
    }
  }

  Future<void> refresh() async {
    if (_disposed) return;
    _loading = true;
    notifyListeners();
    try {
      final next = await _fetch();
      if (_disposed) return;
      _snapshot = next;
      _lastError = null;
    } catch (e) {
      if (_disposed) return;
      _lastError = e;
    } finally {
      if (!_disposed) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> dismissBanner() async {
    final snap = _snapshot;
    if (snap == null) return;
    final fp = _bannerFingerprint(snap);
    if (fp.isEmpty) return;
    _dismissedFingerprint = fp;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsDismissKey, fp);
    } catch (_) {
      // ignore prefs errors
    }
  }

  /// Fingerprint estable: incidencia (prio 1) o set de servicios unhealthy (prio 2).
  /// No incluye latencias para que el dismiss no se pierda en cada poll.
  String _bannerFingerprint(FolioCloudStatusSnapshot snap) {
    final incident = snap.primaryIncident;
    if (incident != null) {
      final id = incident.id.trim().isNotEmpty
          ? incident.id.trim()
          : '${incident.title}|${incident.type}|${incident.createdAt?.toIso8601String() ?? ''}';
      return 'incident|$id|${incident.impact}|${incident.status}';
    }
    final services = snap.unhealthyServiceIds
        .map((id) {
          final reason = snap.services[id]?.statusReason ?? '';
          return '$id:${snap.displayStatusFor(id)}:$reason';
        })
        .join(',');
    if (services.isEmpty && !snap.isUnhealthy) return '';
    return 'status|${snap.bannerSeverity}|$services';
  }

  Future<void> _loadDismissed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_prefsDismissKey);
      // No pisar un dismiss hecho en memoria mientras cargábamos prefs.
      _dismissedFingerprint ??= stored;
    } catch (_) {
      // ignore
    } finally {
      _dismissLoaded = true;
      if (!_disposed) notifyListeners();
    }
  }

  void _restartPollTimer() {
    _pollTimer?.cancel();
    if (!_appInForeground || _disposed) return;
    _pollTimer = Timer.periodic(pollInterval, (_) {
      if (_appInForeground && !_disposed) {
        unawaited(refresh());
      }
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _pollTimer?.cancel();
    _pollTimer = null;
    super.dispose();
  }
}
