import 'package:flutter/material.dart';

import '../../config/models/widget_instance_config.dart';
import '../../features/workspace/widgets/spotify_now_playing_bar.dart';
import '../../services/media/media_playback_router.dart';
import '../../session/vault_session.dart';
import '../folio_widget_plugin.dart';
import '../widget_plugin_context.dart';
import 'builtin_widget_card.dart';

/// Reproducción actual — reutiliza [NowPlayingBar] sobre
/// [MediaPlaybackRouter] (mismo stack que el sidebar / workspace).
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
  double get defaultHeight => 120;

  @override
  Widget build(
    BuildContext context,
    WidgetInstanceConfig instance,
    WidgetPluginContext ctx,
  ) {
    final height = instance.height ?? defaultHeight;
    final density = height >= 180
        ? NowPlayingBarDensity.expanded
        : NowPlayingBarDensity.mini;

    return BuiltinWidgetCard(
      icon: icon,
      title: displayName(context),
      child: _MusicNowPlayingBody(
        session: ctx.session,
        density: density,
      ),
    );
  }
}

class _MusicNowPlayingBody extends StatefulWidget {
  const _MusicNowPlayingBody({
    required this.session,
    required this.density,
  });

  final VaultSession session;
  final NowPlayingBarDensity density;

  @override
  State<_MusicNowPlayingBody> createState() => _MusicNowPlayingBodyState();
}

class _MusicNowPlayingBodyState extends State<_MusicNowPlayingBody> {
  @override
  void initState() {
    super.initState();
    // Mantener polling aunque la barra no se monte (idle).
    MediaPlaybackRouter.instance.addListenerRef();
    MediaPlaybackRouter.instance.addListener(_onPlayback);
  }

  @override
  void dispose() {
    MediaPlaybackRouter.instance.removeListener(_onPlayback);
    MediaPlaybackRouter.instance.removeListenerRef();
    super.dispose();
  }

  void _onPlayback() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final router = MediaPlaybackRouter.instance;
    if (!router.shouldShowBar) {
      return const BuiltinWidgetEmpty(
        message: 'No hay nada sonando ahora mismo.',
      );
    }
    // NowPlayingBar también hace addListenerRef; ref-count lo tolera.
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: NowPlayingBar(
        session: widget.session,
        density: widget.density,
      ),
    );
  }
}
