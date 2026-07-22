import 'package:flutter/foundation.dart';

import 'now_playing_snapshot.dart';

/// Fuente de reproducción que puede alimentar [MediaPlaybackRouter] / la barra.
abstract class NowPlayingSource extends ChangeNotifier {
  NowPlayingSourceId get id;

  /// La fuente está habilitada / conectada y puede mostrarse en la barra.
  bool get isAvailable;

  /// Hay contenido usable (pista o reproducción activa), no solo idle.
  bool get hasActiveContent;

  NowPlayingSnapshot get snapshot;

  Future<void> togglePlayPause();

  Future<void> skipNext();

  Future<void> skipPrevious();

  Future<void> seek(int positionMs);

  Future<void> setVolume(int volumePercent);

  Future<void> openExternal();

  Future<void> pause();

  /// Contadores de UI: la fuente puede arrancar/parar polling según listeners.
  void addListenerRef();

  void removeListenerRef();
}
