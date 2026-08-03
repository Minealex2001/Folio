import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../models/spotify_integration_state.dart';
import '../../session/vault_session.dart';
import 'spotify_api_client.dart';
import 'spotify_auth_config.dart';
import 'spotify_local_device_host.dart' show spotifyLocalDeviceSupported;
import 'spotify_local_device_service.dart';

/// Controlador global de reproducción Spotify (now playing + controles).
class SpotifyPlaybackController extends ChangeNotifier {
  SpotifyPlaybackController._();
  static final SpotifyPlaybackController instance = SpotifyPlaybackController._();

  VaultSession? _session;
  SpotifyApiClient? _client;
  Timer? _pollTimer;
  int _listeners = 0;

  SpotifyPlaybackSnapshot _snapshot = SpotifyPlaybackSnapshot.empty;
  String? _lastError;

  SpotifyPlaybackSnapshot get snapshot => _snapshot;
  String? get lastError => _lastError;
  bool get hasConnection => _client != null;
  SpotifyConnection? get activeConnection =>
      _session?.spotifyConnections.isNotEmpty == true
          ? _session!.spotifyConnections.first
          : null;

  void attachSession(VaultSession session) {
    if (identical(_session, session)) return;
    _session?.removeListener(_onSessionChanged);
    _session = session;
    session.addListener(_onSessionChanged);
    _rebuildClient();
  }

  void detachSession() {
    _session?.removeListener(_onSessionChanged);
    _session = null;
    _client = null;
    _stopPolling();
    _snapshot = SpotifyPlaybackSnapshot.empty;
    _lastError = null;
    _syncLocalDevice();
    notifyListeners();
  }

  void _onSessionChanged() {
    _rebuildClient();
  }

  void _rebuildClient() {
    final session = _session;
    if (session == null || session.state != VaultFlowState.unlocked) {
      _client = null;
      _stopPolling();
      return;
    }
    final conns = session.spotifyConnections;
    if (conns.isEmpty) {
      _client = null;
      _stopPolling();
      _snapshot = SpotifyPlaybackSnapshot.empty;
      _syncLocalDevice();
      notifyListeners();
      return;
    }
    final conn = conns.first;
    // Si el cliente ya existe y es para la misma cuenta, solo actualizamos el
    // token sin recrear el cliente (evita un bucle: refresh token →
    // upsertSpotifyConnection → notifyListeners → _rebuildClient → nuevo cliente).
    if (_client != null && _client!.connection.id == conn.id) {
      _client!.updateConnection(conn);
      _syncLocalDevice();
      return;
    }
    _client = SpotifyApiClient(
      connection: conn,
      onConnectionUpdated: (updated) async {
        session.upsertSpotifyConnection(updated);
        return updated;
      },
    );
    if (_listeners > 0) {
      unawaited(refresh());
      _startPolling();
    }
    _syncLocalDevice();
  }

  /// Sincroniza el servicio del dispositivo local con la conexión activa:
  /// solo se activa si el usuario lo pidió (`localDeviceEnabled`) y la
  /// cuenta ya concedió el scope `streaming` (si no, hace falta reconectar).
  void _syncLocalDevice() {
    final conn = activeConnection;
    final client = _client;
    final wantsLocalDevice = conn?.localDeviceEnabled ?? false;
    final hasStreamingScope =
        conn != null && conn.missingScopesFor(const ['streaming']).isEmpty;
    SpotifyLocalDeviceService.instance.configure(
      enabled: wantsLocalDevice && hasStreamingScope && client != null,
      platformSupported: spotifyLocalDeviceSupported,
      tokenProvider: client?.freshAccessToken,
    );
  }

  /// Si el dispositivo local es compatible con esta plataforma.
  bool get isLocalDeviceSupported => spotifyLocalDeviceSupported;

  /// Scopes que faltan (p.ej. `streaming`) para poder usar el dispositivo
  /// local con la conexión activa. Vacío si ya están todos concedidos.
  List<String> get missingLocalDeviceScopes {
    final conn = activeConnection;
    if (conn == null) return const ['streaming'];
    return conn.missingScopesFor(const ['streaming']);
  }

  SpotifyLocalDeviceStatus get localDeviceStatus =>
      SpotifyLocalDeviceService.instance.status;
  String? get localDeviceId => SpotifyLocalDeviceService.instance.deviceId;
  String? get localDeviceLastError =>
      SpotifyLocalDeviceService.instance.lastError;

  /// Activa/desactiva el opt-in "Usar Folio como dispositivo de Spotify" y
  /// lo persiste en la conexión (vault cifrado).
  Future<void> setLocalDeviceEnabled(bool enabled) async {
    final session = _session;
    final conn = activeConnection;
    if (session == null || conn == null) return;
    final updated = conn.copyWith(localDeviceEnabled: enabled);
    session.upsertSpotifyConnection(updated);
    // upsertSpotifyConnection dispara _onSessionChanged → _rebuildClient →
    // _syncLocalDevice, pero lo forzamos aquí también por si el listener
    // tarda un ciclo en propagarse.
    _syncLocalDevice();
  }

  /// Lista los dispositivos Spotify Connect disponibles (incluye "Folio"
  /// cuando el dispositivo local está listo).
  Future<List<SpotifyDevice>> listDevices() async {
    final client = _client;
    if (client == null) return const [];
    return client.listDevices();
  }

  /// Transfiere la reproducción al dispositivo [deviceId].
  Future<void> activateDevice(String deviceId, {bool play = true}) async {
    final client = _client;
    if (client == null) return;
    await client.transferPlayback(deviceId, play: play);
    await Future<void>.delayed(const Duration(milliseconds: 500));
    await refresh();
  }

  /// Transfiere la reproducción al dispositivo local de Folio, si está listo.
  Future<void> activateLocalDevice({bool play = true}) async {
    final deviceId = localDeviceId;
    if (deviceId == null) {
      throw StateError('spotify_local_device_not_ready');
    }
    await activateDevice(deviceId, play: play);
  }

  void addListenerRef() {
    _listeners++;
    if (_listeners == 1 && _client != null) {
      unawaited(refresh());
      _startPolling();
    }
  }

  void removeListenerRef() {
    if (_listeners > 0) _listeners--;
    if (_listeners == 0) {
      _stopPolling();
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      unawaited(refresh());
    });
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> refresh() async {
    final client = _client;
    if (client == null) return;
    try {
      // /me/player incluye volume_percent del dispositivo; better que currently-playing.
      final snap = await client.getPlaybackState();
      _snapshot = snap;
      _lastError = null;
      notifyListeners();
    } catch (e) {
      _lastError = '$e';
      notifyListeners();
    }
  }

  /// Activa Folio como dispositivo Spotify Connect (si la plataforma lo
  /// soporta) y espera a que el Web Playback SDK esté listo.
  ///
  /// Devuelve el `device_id` para pasarlo a `/me/player/play`, o `null` si
  /// no se pudo (sin Premium / sin scope / plataforma no soportada / timeout).
  Future<String?> _ensureFolioPlaybackDevice() async {
    if (!isLocalDeviceSupported) return null;
    final conn = activeConnection;
    if (conn == null) return null;
    if (conn.grantedScopes.isNotEmpty &&
        conn.missingScopesFor(const ['streaming']).isNotEmpty) {
      return null;
    }

    if (!conn.localDeviceEnabled) {
      await setLocalDeviceEnabled(true);
    }

    final local = SpotifyLocalDeviceService.instance;
    if (local.isReady) return local.deviceId;

    final completer = Completer<String?>();
    void onChange() {
      if (completer.isCompleted) return;
      if (local.isReady) {
        completer.complete(local.deviceId);
        return;
      }
      if (local.status == SpotifyLocalDeviceStatus.error ||
          local.status == SpotifyLocalDeviceStatus.unsupported ||
          local.status == SpotifyLocalDeviceStatus.disabled) {
        completer.complete(null);
      }
    }

    local.addListener(onChange);
    onChange();
    final timeout = Timer(const Duration(seconds: 12), () {
      if (!completer.isCompleted) {
        completer.complete(local.isReady ? local.deviceId : null);
      }
    });
    try {
      return await completer.future;
    } finally {
      timeout.cancel();
      local.removeListener(onChange);
    }
  }

  /// Reproduce en Folio (device_id local) cuando sea posible.
  Future<void> _playEnsuringFolioDevice({
    String? contextUri,
    List<String>? uris,
    String? offsetUri,
  }) async {
    if (_client == null) _rebuildClient();
    final client = _client;
    if (client == null) {
      throw StateError('No Spotify connection');
    }
    if (_pollTimer == null) _startPolling();

    final deviceId = await _ensureFolioPlaybackDevice();
    await client.play(
      contextUri: contextUri,
      uris: uris,
      offsetUri: offsetUri,
      deviceId: deviceId,
    );
    await Future<void>.delayed(const Duration(milliseconds: 500));
    await refresh();
  }

  Future<void> togglePlayPause() async {
    if (_client == null) _rebuildClient();
    final client = _client;
    if (client == null) return;
    try {
      if (_snapshot.isPlaying) {
        await client.pause();
      } else if (_snapshot.trackName == null || _snapshot.noContent) {
        final focusUri = activeConnection?.focusPlaylistUri?.trim() ?? '';
        if (focusUri.isNotEmpty) {
          await _playEnsuringFolioDevice(contextUri: focusUri);
          return;
        }
        await _playEnsuringFolioDevice();
        return;
      } else {
        await _playEnsuringFolioDevice();
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 400));
      await refresh();
    } catch (e) {
      _lastError = '$e';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> skipNext() async {
    final client = _client;
    if (client == null) return;
    await client.skipNext();
    await Future<void>.delayed(const Duration(milliseconds: 400));
    await refresh();
  }

  Future<void> skipPrevious() async {
    final client = _client;
    if (client == null) return;
    await client.skipPrevious();
    await Future<void>.delayed(const Duration(milliseconds: 400));
    await refresh();
  }

  Future<void> setVolume(int volumePercent) async {
    if (_client == null) _rebuildClient();
    final client = _client;
    if (client == null) return;
    final percent = volumePercent.clamp(0, 100);
    // Actualización optimista para que el slider no salte.
    _snapshot = _snapshot.copyWith(volumePercent: percent);
    notifyListeners();
    try {
      await client.setVolume(percent);
      _lastError = null;
    } catch (e) {
      _lastError = '$e';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> seek(int positionMs) async {
    if (_client == null) _rebuildClient();
    final client = _client;
    if (client == null) return;
    final duration = _snapshot.durationMs;
    final pos = positionMs.clamp(0, duration > 0 ? duration : positionMs);
    _snapshot = _snapshot.copyWith(progressMs: pos);
    notifyListeners();
    try {
      await client.seek(pos);
      _lastError = null;
    } catch (e) {
      _lastError = '$e';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> startFocusPlaylist() async {
    final conn = activeConnection;
    final uri = conn?.focusPlaylistUri?.trim() ?? '';
    if (uri.isEmpty) return;
    await _playEnsuringFolioDevice(contextUri: uri);
  }

  /// Reproduce un recurso Spotify (`track`/`episode` como uris; resto como context).
  Future<void> playSpotifyRef({
    required String type,
    required String id,
  }) async {
    final spotifyUri = 'spotify:$type:$id';
    if (type == 'track' || type == 'episode') {
      await _playEnsuringFolioDevice(uris: [spotifyUri]);
    } else {
      await _playEnsuringFolioDevice(contextUri: spotifyUri);
    }
  }

  /// Reproduce un contexto (playlist/álbum) opcionalmente desde un track concreto.
  Future<void> playContext({
    required String contextUri,
    String? offsetUri,
  }) async {
    await _playEnsuringFolioDevice(
      contextUri: contextUri,
      offsetUri: offsetUri,
    );
  }

  /// Reproduce una lista de URIs de track.
  Future<void> playUris(List<String> uris) async {
    if (uris.isEmpty) return;
    await _playEnsuringFolioDevice(uris: uris);
  }

  Future<SpotifyQueueSnapshot> getQueue() async {
    if (_client == null) _rebuildClient();
    final client = _client;
    if (client == null) return const SpotifyQueueSnapshot();
    return client.getQueue();
  }

  Future<void> addToQueue(String uri) async {
    if (_client == null) _rebuildClient();
    final client = _client;
    if (client == null) return;
    await client.addToQueue(uri);
  }

  Future<void> setShuffle(bool enabled) async {
    if (_client == null) _rebuildClient();
    final client = _client;
    if (client == null) return;
    await client.setShuffle(enabled);
    await refresh();
  }

  Future<void> setRepeat(String state) async {
    if (_client == null) _rebuildClient();
    final client = _client;
    if (client == null) return;
    await client.setRepeat(state);
    await refresh();
  }

  /// Cicla repeat: off → context → track → off.
  Future<void> cycleRepeat() async {
    final current = _snapshot.repeatState;
    final next = switch (current) {
      'off' => 'context',
      'context' => 'track',
      _ => 'off',
    };
    await setRepeat(next);
  }

  /// Scopes de biblioteca que faltan (recently played / liked / etc.).
  List<String> get missingLibraryScopes {
    final conn = activeConnection;
    if (conn == null) return SpotifyAuthConfig.libraryScopes;
    // Si aún no tenemos grantedScopes persistidos, no forzar reconexión.
    if (conn.grantedScopes.isEmpty) return const [];
    return conn.missingScopesFor(SpotifyAuthConfig.libraryScopes);
  }

  Future<void> pause() async {
    final client = _client;
    if (client == null) return;
    await client.pause();
    await refresh();
  }

  SpotifyApiClient? apiClientForSettings() {
    if (_client == null) _rebuildClient();
    return _client;
  }

  @override
  void dispose() {
    _stopPolling();
    detachSession();
    super.dispose();
  }
}
