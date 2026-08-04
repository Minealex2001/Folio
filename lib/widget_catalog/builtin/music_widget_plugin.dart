import 'package:flutter/material.dart';

import '../../config/models/widget_instance_config.dart';
import '../../services/media/media_playback_router.dart';
import '../folio_widget_plugin.dart';
import '../widget_plugin_context.dart';
import 'builtin_widget_card.dart';

/// Reproducción actual — lee `MediaPlaybackRouter.instance` (fuente real
/// compartida con Spotify/YT Music/reproducción del sistema, ya usada por
/// `lib/features/workspace/spotify/`), en vez de reincrustar el panel
/// completo `SpotifyRightNowPlaying` (diseñado como overlay a pantalla
/// completa, no como celda de dashboard).
class MusicWidgetPlugin extends FolioWidgetPlugin {
  const MusicWidgetPlugin();

  @override
  String get id => 'music';

  @override
  String displayName(BuildContext context) => 'Música';

  @override
  IconData get icon => Icons.music_note_rounded;

  @override
  bool get allowMultipleInstances => false;

  @override
  Widget build(
    BuildContext context,
    WidgetInstanceConfig instance,
    WidgetPluginContext ctx,
  ) {
    return BuiltinWidgetCard(
      icon: icon,
      title: displayName(context),
      child: ListenableBuilder(
        listenable: MediaPlaybackRouter.instance,
        builder: (context, _) {
          final snapshot = MediaPlaybackRouter.instance.snapshot;
          if (!snapshot.hasTrack) {
            return const BuiltinWidgetComingSoon(
              message: 'No hay nada sonando ahora mismo.',
            );
          }
          return Row(
            children: [
              Icon(
                snapshot.isPlaying
                    ? Icons.pause_circle_filled_rounded
                    : Icons.play_circle_filled_rounded,
                size: 28,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      snapshot.title ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    if (snapshot.artist != null)
                      Text(
                        snapshot.artist!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
