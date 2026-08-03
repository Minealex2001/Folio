import 'package:flutter/widgets.dart';

import 'spotify_local_device_host.dart';

/// Widget de tamaño cero, invisible y no interactivo que mantiene viva la
/// instancia de WebView/JS del Web Playback SDK en segundo plano mientras la
/// app está abierta. Debe montarse una única vez, cerca de la raíz del árbol
/// de widgets (ver `FolioApp`), para que sobreviva a la navegación interna.
class SpotifyLocalDeviceMount extends StatelessWidget {
  const SpotifyLocalDeviceMount({super.key});

  @override
  Widget build(BuildContext context) {
    return const Offstage(
      offstage: true,
      child: SizedBox(
        width: 1,
        height: 1,
        child: SpotifyLocalDeviceHost(),
      ),
    );
  }
}
