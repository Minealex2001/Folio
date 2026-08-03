import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/ytmusic_integration_state.dart';
import '../../session/vault_session.dart';
import 'ytmusic_api_client.dart';

class YtMusicPlaybackSnapshot {
  const YtMusicPlaybackSnapshot({
    this.track,
    this.isPlaying = false,
    this.progressMs = 0,
    this.queue = const [],
    this.noContent = false,
  });

  final YtMusicTrack? track;
  final bool isPlaying;
  final int progressMs;
  final List<YtMusicTrack> queue;
  final bool noContent;

  static const empty = YtMusicPlaybackSnapshot(noContent: true);

  int get durationMs => track?.durationMs ?? 0;
}

/// Reproducción local Folio (progreso + cola) y apertura en YT Music.
/// Sin Cast/Connect; el audio se abre en el navegador/app de YT Music.
class YtMusicPlaybackController extends ChangeNotifier {
  YtMusicPlaybackController._();
  static final YtMusicPlaybackController instance = YtMusicPlaybackController._();

  VaultSession? _session;
  YtMusicPlaybackSnapshot _snapshot = YtMusicPlaybackSnapshot.empty;
  Timer? _ticker;
  DateTime? _progressAnchor;
  int _progressBase = 0;
  final List<YtMusicTrack> _queue = [];
  bool _active = false;

  YtMusicPlaybackSnapshot get snapshot => _snapshot;
  bool get hasConnection =>
      _active && (_session?.ytMusicConnections.isNotEmpty ?? false);

  YtMusicConnection? get activeConnection {
    final list = _session?.ytMusicConnections ?? const [];
    return list.isEmpty ? null : list.first;
  }

  void attachSession(VaultSession session) {
    if (identical(_session, session)) return;
    _session = session;
    session.addListener(_onSession);
    _onSession();
  }

  void detachSession() {
    _session?.removeListener(_onSession);
    _session = null;
    _stopTicker();
    _snapshot = YtMusicPlaybackSnapshot.empty;
    _queue.clear();
    notifyListeners();
  }

  void setActive(bool active) {
    if (_active == active) return;
    _active = active;
    if (!active) {
      pause();
      _snapshot = YtMusicPlaybackSnapshot.empty;
      _queue.clear();
    }
    notifyListeners();
  }

  void _onSession() {
    if (!hasConnection) {
      _snapshot = YtMusicPlaybackSnapshot.empty;
    }
    notifyListeners();
  }

  YtMusicApiClient? _client() {
    final conn = activeConnection;
    final session = _session;
    if (conn == null || session == null) return null;
    return YtMusicApiClient(
      connection: conn,
      onConnectionUpdated: session.upsertYtMusicConnection,
    );
  }

  Future<void> playTrack(YtMusicTrack track, {List<YtMusicTrack>? queue}) async {
    if (!_active) return;
    if (queue != null) {
      _queue
        ..clear()
        ..addAll(queue.where((t) => t.videoId != track.videoId));
    }
    final client = _client();
    var resolved = track;
    if ((track.durationMs <= 0 || (track.albumArtUrl ?? '').isEmpty) &&
        client != null) {
      try {
        final meta = await client.playerMeta(track.videoId);
        if (meta != null) resolved = meta;
      } catch (_) {}
    }
    _progressBase = 0;
    _progressAnchor = DateTime.now();
    _snapshot = YtMusicPlaybackSnapshot(
      track: resolved,
      isPlaying: true,
      progressMs: 0,
      queue: List.unmodifiable(_queue),
    );
    _startTicker();
    notifyListeners();
    await _openWatch(resolved.videoId);
  }

  Future<void> playPlaylist(String browseId) async {
    final client = _client();
    if (client == null) return;
    final tracks = await client.browseTracks(browseId);
    if (tracks.isEmpty) return;
    await playTrack(tracks.first, queue: tracks.skip(1).toList());
  }

  Future<void> togglePlayPause() async {
    if (_snapshot.track == null) return;
    if (_snapshot.isPlaying) {
      await pause();
    } else {
      _progressAnchor = DateTime.now();
      _progressBase = _snapshot.progressMs;
      _snapshot = YtMusicPlaybackSnapshot(
        track: _snapshot.track,
        isPlaying: true,
        progressMs: _snapshot.progressMs,
        queue: _snapshot.queue,
      );
      _startTicker();
      notifyListeners();
    }
  }

  Future<void> pause() async {
    _syncProgress();
    _stopTicker();
    _snapshot = YtMusicPlaybackSnapshot(
      track: _snapshot.track,
      isPlaying: false,
      progressMs: _snapshot.progressMs,
      queue: _snapshot.queue,
      noContent: _snapshot.track == null,
    );
    notifyListeners();
  }

  Future<void> skipNext() async {
    if (_queue.isEmpty) return;
    final next = _queue.removeAt(0);
    await playTrack(next);
  }

  Future<void> skipPrevious() async {
    await seek(0);
  }

  Future<void> seek(int positionMs) async {
    final dur = _snapshot.durationMs;
    final clamped = positionMs.clamp(0, dur > 0 ? dur : positionMs);
    _progressBase = clamped;
    _progressAnchor = DateTime.now();
    _snapshot = YtMusicPlaybackSnapshot(
      track: _snapshot.track,
      isPlaying: _snapshot.isPlaying,
      progressMs: clamped,
      queue: _snapshot.queue,
    );
    notifyListeners();
  }

  List<YtMusicTrack> getQueue() =>
      [if (_snapshot.track != null) _snapshot.track!, ..._queue];

  Future<void> openExternal() async {
    final id = _snapshot.track?.videoId;
    if (id == null) {
      await launchUrl(
        Uri.https('music.youtube.com', '/'),
        mode: LaunchMode.externalApplication,
      );
      return;
    }
    await _openWatch(id);
  }

  Future<void> _openWatch(String videoId) async {
    final uri = Uri.https('music.youtube.com', '/watch', {'v': videoId});
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (ok) return;
    } catch (_) {}
    await launchUrl(uri, mode: LaunchMode.platformDefault);
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (!_snapshot.isPlaying) return;
      _syncProgress();
      final dur = _snapshot.durationMs;
      if (dur > 0 && _snapshot.progressMs >= dur - 400) {
        unawaited(skipNext());
      } else {
        notifyListeners();
      }
    });
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  void _syncProgress() {
    if (_progressAnchor == null) return;
    final elapsed =
        DateTime.now().difference(_progressAnchor!).inMilliseconds;
    final next = _progressBase + elapsed;
    final dur = _snapshot.durationMs;
    _snapshot = YtMusicPlaybackSnapshot(
      track: _snapshot.track,
      isPlaying: _snapshot.isPlaying,
      progressMs: dur > 0 ? next.clamp(0, dur) : next,
      queue: _snapshot.queue,
    );
  }
}
