import 'dart:async';

import '../../models/system_media_integration_state.dart';
import '../../session/vault_session.dart';
import 'now_playing_snapshot.dart';
import 'now_playing_source.dart';
import 'system_media_service.dart';

/// Controlador de media del sistema como [NowPlayingSource].
class SystemMediaController extends NowPlayingSource {
  SystemMediaController._();
  static final SystemMediaController instance = SystemMediaController._();

  final SystemMediaService _service = SystemMediaService.instance;
  VaultSession? _session;
  StreamSubscription<SystemMediaRawSnapshot>? _sub;
  SystemMediaRawSnapshot _raw = SystemMediaRawSnapshot.empty;
  int _listeners = 0;
  bool _supported = false;
  bool _hasPermission = true;

  bool get platformSupported => _supported;
  bool get hasPermission => _hasPermission;
  SystemMediaRawSnapshot get rawSnapshot => _raw;

  SystemMediaIntegrationState get state =>
      _session?.systemMediaIntegrationState ??
      SystemMediaIntegrationState.empty;

  @override
  NowPlayingSourceId get id => NowPlayingSourceId.system;

  @override
  bool get isAvailable =>
      state.enabled && _supported && _hasPermission;

  @override
  bool get hasActiveContent {
    if (!isAvailable) return false;
    if (_raw.looksLikeSpotify) return false;
    return _raw.hasSession &&
        ((_raw.title != null && _raw.title!.trim().isNotEmpty) ||
            _raw.isPlaying);
  }

  @override
  NowPlayingSnapshot get snapshot {
    if (!_raw.hasSession || _raw.looksLikeSpotify) {
      return NowPlayingSnapshot.emptySystem.copyWith(
        sourceLabel: _raw.appName,
        appId: _raw.appId,
        canSkip: _raw.canSkipNext || _raw.canSkipPrevious,
        canSeek: _raw.canSeek,
        canInsertBlock: true,
      );
    }
    return NowPlayingSnapshot(
      title: _raw.title,
      artist: _raw.artist,
      albumArtBytes: _raw.albumArtBytes,
      isPlaying: _raw.isPlaying,
      progressMs: _raw.progressMs,
      durationMs: _raw.durationMs,
      sourceId: NowPlayingSourceId.system,
      sourceLabel: _raw.appName,
      appId: _raw.appId,
      canSeek: _raw.canSeek,
      canSkip: _raw.canSkipNext || _raw.canSkipPrevious,
      canSetVolume: false,
      canOpenExternal: false,
      canInsertBlock: true,
      noContent: !_raw.hasSession,
    );
  }

  void attachSession(VaultSession session) {
    if (identical(_session, session)) return;
    _session?.removeListener(_onSessionChanged);
    _session = session;
    session.addListener(_onSessionChanged);
    unawaited(_syncFromSession());
  }

  void detachSession() {
    _session?.removeListener(_onSessionChanged);
    _session = null;
    unawaited(_service.stopListening());
    _raw = SystemMediaRawSnapshot.empty;
    notifyListeners();
  }

  void _onSessionChanged() {
    unawaited(_syncFromSession());
  }

  Future<void> _syncFromSession() async {
    _supported = await _service.isSupported();
    if (_supported) {
      _hasPermission = await _service.hasPermission();
    }
    if (state.enabled && _supported && _hasPermission && _listeners > 0) {
      await _ensureListening();
    } else if (!state.enabled) {
      await _service.stopListening();
      await _sub?.cancel();
      _sub = null;
      _raw = SystemMediaRawSnapshot.empty;
    }
    notifyListeners();
  }

  Future<void> refreshCapability() async {
    _supported = await _service.isSupported();
    _hasPermission = await _service.hasPermission();
    notifyListeners();
  }

  Future<void> openPermissionSettings() =>
      _service.openPermissionSettings();

  Future<void> _ensureListening() async {
    await _service.startListening();
    _sub ??= _service.snapshots.listen((snap) {
      _raw = snap;
      notifyListeners();
    });
    _raw = _service.latest;
    if (!_raw.hasSession) {
      _raw = await _service.getCurrent();
    }
  }

  @override
  void addListenerRef() {
    _listeners++;
    if (_listeners == 1 && state.enabled) {
      unawaited(_ensureListening().then((_) => notifyListeners()));
    }
  }

  @override
  void removeListenerRef() {
    if (_listeners > 0) _listeners--;
    if (_listeners == 0) {
      unawaited(_service.stopListening());
      unawaited(_sub?.cancel());
      _sub = null;
    }
  }

  @override
  Future<void> togglePlayPause() async {
    if (_raw.isPlaying) {
      await _service.pause();
    } else {
      await _service.play();
    }
    await Future<void>.delayed(const Duration(milliseconds: 300));
    _raw = await _service.getCurrent();
    notifyListeners();
  }

  @override
  Future<void> skipNext() async {
    await _service.skipNext();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    _raw = await _service.getCurrent();
    notifyListeners();
  }

  @override
  Future<void> skipPrevious() async {
    await _service.skipPrevious();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    _raw = await _service.getCurrent();
    notifyListeners();
  }

  @override
  Future<void> seek(int positionMs) async {
    await _service.seek(positionMs);
    _raw = SystemMediaRawSnapshot(
      title: _raw.title,
      artist: _raw.artist,
      appId: _raw.appId,
      appName: _raw.appName,
      albumArtBytes: _raw.albumArtBytes,
      isPlaying: _raw.isPlaying,
      progressMs: positionMs,
      durationMs: _raw.durationMs,
      canPlay: _raw.canPlay,
      canPause: _raw.canPause,
      canSkipNext: _raw.canSkipNext,
      canSkipPrevious: _raw.canSkipPrevious,
      canSeek: _raw.canSeek,
    );
    notifyListeners();
  }

  @override
  Future<void> setVolume(int volumePercent) async {
    // El SO no expone volumen unificado de forma fiable.
  }

  @override
  Future<void> openExternal() async {}

  @override
  Future<void> pause() async {
    await _service.pause();
    _raw = await _service.getCurrent();
    notifyListeners();
  }
}
