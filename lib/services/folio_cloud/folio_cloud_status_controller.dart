import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'folio_cloud_status.dart';

/// Poll + cache del estado p├║blico Folio Cloud (Minealex).
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
    final fp = _bannerFingerprint(snap);
    return fp != _dismissedFingerprint;
  }

  /// Arranque no bloqueante + polling.
  void start() {
    if (_started || _disposed) return;
    _started = true;
    unawaited(_loadDismissed());
    unawaited(refresh());
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
      // Si cambi├│ el fingerprint, el dismiss anterior ya no aplica.
      final fp = _bannerFingerprint(next);
      if (_dismissedFingerprint != null && _dismissedFingerprint != fp) {
        // Mantener dismiss solo si el fingerprint coincide; si empeora/cambia, se limpia abajo al comparar en bannerVisible.
      }
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
    _dismissedFingerprint = fp;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsDismissKey, fp);
    } catch (_) {
      // ignore prefs errors
    }
  }

  String _bannerFingerprint(FolioCloudStatusSnapshot snap) {
    final ids = snap.activeIncidents.map((i) => i.id).where((id) => id.isNotEmpty).join(',');
    return '${snap.status}|$ids';
  }

  Future<void> _loadDismissed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _dismissedFingerprint = prefs.getString(_prefsDismissKey);
      if (!_disposed) notifyListeners();
    } catch (_) {
      // ignore
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
