import 'dart:typed_data';

/// Identificador de la fuente que alimenta la barra now playing.
enum NowPlayingSourceId {
  spotify,
  system,
}

/// Snapshot unificado de reproducción (Spotify API o media del sistema).
class NowPlayingSnapshot {
  const NowPlayingSnapshot({
    this.title,
    this.artist,
    this.albumArtUrl,
    this.albumArtBytes,
    this.isPlaying = false,
    this.progressMs = 0,
    this.durationMs = 0,
    this.volumePercent,
    required this.sourceId,
    this.sourceLabel,
    this.appId,
    this.externalUrl,
    this.canSeek = true,
    this.canSkip = true,
    this.canSetVolume = false,
    this.canOpenExternal = false,
    this.canInsertBlock = false,
    this.premiumRequired = false,
    this.noActiveDevice = false,
    this.noContent = false,
    this.idleTitle,
  });

  final String? title;
  final String? artist;
  final String? albumArtUrl;
  final Uint8List? albumArtBytes;
  final bool isPlaying;
  final int progressMs;
  final int durationMs;
  final int? volumePercent;
  final NowPlayingSourceId sourceId;
  /// Etiqueta de origen (p. ej. «YouTube Music», «Spotify»).
  final String? sourceLabel;
  /// AUMID / package name de la app del sistema.
  final String? appId;
  final String? externalUrl;
  final bool canSeek;
  final bool canSkip;
  final bool canSetVolume;
  final bool canOpenExternal;
  final bool canInsertBlock;
  final bool premiumRequired;
  final bool noActiveDevice;
  final bool noContent;
  /// Título cuando no hay pista (p. ej. nombre de playlist de enfoque).
  final String? idleTitle;

  bool get hasTrack => title != null && title!.trim().isNotEmpty;

  bool get isIdle => !hasTrack && !isPlaying;

  static const emptySpotify = NowPlayingSnapshot(
    sourceId: NowPlayingSourceId.spotify,
    sourceLabel: 'Spotify',
    noContent: true,
    canSetVolume: true,
    canOpenExternal: true,
  );

  static const emptySystem = NowPlayingSnapshot(
    sourceId: NowPlayingSourceId.system,
    noContent: true,
    canInsertBlock: true,
  );

  NowPlayingSnapshot copyWith({
    String? title,
    String? artist,
    String? albumArtUrl,
    Uint8List? albumArtBytes,
    bool? isPlaying,
    int? progressMs,
    int? durationMs,
    int? volumePercent,
    NowPlayingSourceId? sourceId,
    String? sourceLabel,
    String? appId,
    String? externalUrl,
    bool? canSeek,
    bool? canSkip,
    bool? canSetVolume,
    bool? canOpenExternal,
    bool? canInsertBlock,
    bool? premiumRequired,
    bool? noActiveDevice,
    bool? noContent,
    String? idleTitle,
    bool clearAlbumArtBytes = false,
  }) {
    return NowPlayingSnapshot(
      title: title ?? this.title,
      artist: artist ?? this.artist,
      albumArtUrl: albumArtUrl ?? this.albumArtUrl,
      albumArtBytes:
          clearAlbumArtBytes ? null : (albumArtBytes ?? this.albumArtBytes),
      isPlaying: isPlaying ?? this.isPlaying,
      progressMs: progressMs ?? this.progressMs,
      durationMs: durationMs ?? this.durationMs,
      volumePercent: volumePercent ?? this.volumePercent,
      sourceId: sourceId ?? this.sourceId,
      sourceLabel: sourceLabel ?? this.sourceLabel,
      appId: appId ?? this.appId,
      externalUrl: externalUrl ?? this.externalUrl,
      canSeek: canSeek ?? this.canSeek,
      canSkip: canSkip ?? this.canSkip,
      canSetVolume: canSetVolume ?? this.canSetVolume,
      canOpenExternal: canOpenExternal ?? this.canOpenExternal,
      canInsertBlock: canInsertBlock ?? this.canInsertBlock,
      premiumRequired: premiumRequired ?? this.premiumRequired,
      noActiveDevice: noActiveDevice ?? this.noActiveDevice,
      noContent: noContent ?? this.noContent,
      idleTitle: idleTitle ?? this.idleTitle,
    );
  }
}
