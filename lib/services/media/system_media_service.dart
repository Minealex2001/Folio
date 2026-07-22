import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

/// Snapshot crudo desde el plugin nativo de media del sistema.
class SystemMediaRawSnapshot {
  const SystemMediaRawSnapshot({
    this.title,
    this.artist,
    this.appId,
    this.appName,
    this.albumArtBytes,
    this.isPlaying = false,
    this.progressMs = 0,
    this.durationMs = 0,
    this.canPlay = true,
    this.canPause = true,
    this.canSkipNext = true,
    this.canSkipPrevious = true,
    this.canSeek = true,
  });

  final String? title;
  final String? artist;
  final String? appId;
  final String? appName;
  final Uint8List? albumArtBytes;
  final bool isPlaying;
  final int progressMs;
  final int durationMs;
  final bool canPlay;
  final bool canPause;
  final bool canSkipNext;
  final bool canSkipPrevious;
  final bool canSeek;

  static const empty = SystemMediaRawSnapshot();

  bool get hasSession =>
      (title != null && title!.trim().isNotEmpty) ||
      (appId != null && appId!.trim().isNotEmpty) ||
      isPlaying;

  /// True si la sesión parece ser Spotify (evitar duplicar con la integración).
  bool get looksLikeSpotify {
    final id = (appId ?? '').toLowerCase();
    final name = (appName ?? '').toLowerCase();
    return id.contains('spotify') || name.contains('spotify');
  }

  factory SystemMediaRawSnapshot.fromMap(Map<dynamic, dynamic> map) {
    Uint8List? art;
    final rawArt = map['albumArt'];
    if (rawArt is Uint8List) {
      art = rawArt;
    } else if (rawArt is List) {
      art = Uint8List.fromList(rawArt.cast<int>());
    }
    return SystemMediaRawSnapshot(
      title: _str(map['title']),
      artist: _str(map['artist']),
      appId: _str(map['appId']),
      appName: _str(map['appName']),
      albumArtBytes: art,
      isPlaying: map['isPlaying'] == true,
      progressMs: (map['progressMs'] as num?)?.toInt() ?? 0,
      durationMs: (map['durationMs'] as num?)?.toInt() ?? 0,
      canPlay: map['canPlay'] != false,
      canPause: map['canPause'] != false,
      canSkipNext: map['canSkipNext'] != false,
      canSkipPrevious: map['canSkipPrevious'] != false,
      canSeek: map['canSeek'] != false,
    );
  }

  static String? _str(Object? v) {
    final s = '$v'.trim();
    return s.isEmpty || s == 'null' ? null : s;
  }
}

/// Bridge Dart ↔ nativo para Now Playing del sistema.
class SystemMediaService {
  SystemMediaService._();
  static final SystemMediaService instance = SystemMediaService._();

  static const _method = MethodChannel('folio/system_media');
  static const _event = EventChannel('folio/system_media_events');

  StreamSubscription<dynamic>? _sub;
  final _controller = StreamController<SystemMediaRawSnapshot>.broadcast();
  SystemMediaRawSnapshot _latest = SystemMediaRawSnapshot.empty;
  bool _listening = false;
  bool? _supportedCache;

  SystemMediaRawSnapshot get latest => _latest;

  Stream<SystemMediaRawSnapshot> get snapshots => _controller.stream;

  /// Plataformas con lectura de media ajena implementada o prevista.
  static bool get isPlatformCandidate =>
      !kIsWeb &&
      (Platform.isWindows ||
          Platform.isAndroid ||
          Platform.isLinux ||
          Platform.isMacOS);

  Future<bool> isSupported() async {
    if (_supportedCache != null) return _supportedCache!;
    if (!isPlatformCandidate) {
      _supportedCache = false;
      return false;
    }
    try {
      final ok = await _method.invokeMethod<bool>('isSupported') ?? false;
      _supportedCache = ok;
      return ok;
    } on MissingPluginException {
      _supportedCache = false;
      return false;
    } on PlatformException {
      _supportedCache = false;
      return false;
    }
  }

  /// Android: permiso de Notification Listener.
  Future<bool> hasPermission() async {
    if (!isPlatformCandidate) return false;
    try {
      return await _method.invokeMethod<bool>('hasPermission') ?? true;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<void> openPermissionSettings() async {
    try {
      await _method.invokeMethod<void>('openPermissionSettings');
    } on MissingPluginException {
      // no-op
    } on PlatformException {
      // no-op
    }
  }

  Future<SystemMediaRawSnapshot> getCurrent() async {
    try {
      final raw = await _method.invokeMethod<dynamic>('getCurrent');
      if (raw is Map) {
        _latest = SystemMediaRawSnapshot.fromMap(raw);
        return _latest;
      }
    } on MissingPluginException {
      // ignore
    } on PlatformException {
      // ignore
    }
    return SystemMediaRawSnapshot.empty;
  }

  Future<void> startListening() async {
    if (_listening) return;
    final supported = await isSupported();
    if (!supported) return;
    try {
      // Adjuntar el EventSink antes de startListening para no perder el primer
      // snapshot nativo.
      _sub = _event.receiveBroadcastStream().listen((data) {
        if (data is Map) {
          _latest = SystemMediaRawSnapshot.fromMap(data);
          _controller.add(_latest);
        }
      });
      await _method.invokeMethod<void>('startListening');
      _listening = true;
      final current = await getCurrent();
      _controller.add(current);
    } on MissingPluginException {
      await _sub?.cancel();
      _sub = null;
    } on PlatformException {
      await _sub?.cancel();
      _sub = null;
    }
  }

  Future<void> stopListening() async {
    if (!_listening) return;
    await _sub?.cancel();
    _sub = null;
    try {
      await _method.invokeMethod<void>('stopListening');
    } on MissingPluginException {
      // ignore
    } on PlatformException {
      // ignore
    }
    _listening = false;
  }

  Future<void> play() async {
    try {
      await _method.invokeMethod<void>('play');
    } on MissingPluginException {
      // ignore
    } on PlatformException {
      // ignore
    }
  }

  Future<void> pause() async {
    try {
      await _method.invokeMethod<void>('pause');
    } on MissingPluginException {
      // ignore
    } on PlatformException {
      // ignore
    }
  }

  Future<void> skipNext() async {
    try {
      await _method.invokeMethod<void>('skipNext');
    } on MissingPluginException {
      // ignore
    } on PlatformException {
      // ignore
    }
  }

  Future<void> skipPrevious() async {
    try {
      await _method.invokeMethod<void>('skipPrevious');
    } on MissingPluginException {
      // ignore
    } on PlatformException {
      // ignore
    }
  }

  Future<void> seek(int positionMs) async {
    try {
      await _method.invokeMethod<void>('seek', {'positionMs': positionMs});
    } on MissingPluginException {
      // ignore
    } on PlatformException {
      // ignore
    }
  }
}
