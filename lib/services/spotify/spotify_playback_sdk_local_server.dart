import 'dart:async';
import 'dart:io';

/// Servidor loopback mínimo que sirve la página del Web Playback SDK sobre
/// `http://127.0.0.1`.
///
/// Necesario porque el SDK exige un "secure context" (usa EME/Widevine para
/// desencriptar audio); cargar el HTML directamente como string
/// (`loadHtmlString`/`loadStringContent`) le da a la página un origen opaco
/// que NO cuenta como secure context y hace fallar la inicialización
/// (`initialization_error: Failed to initialize player`). `http://127.0.0.1`
/// sí se trata como secure context en todos los motores Chromium/WebKit
/// modernos (excepción explícita para loopback).
class SpotifyPlaybackSdkLocalServer {
  SpotifyPlaybackSdkLocalServer._(this._server);

  final HttpServer _server;

  /// Puerto loopback fijo, distinto de los usados por los flujos OAuth
  /// (Jira `45747`, Spotify `45748`).
  static const int port = 45749;

  Uri get url => Uri.parse('http://127.0.0.1:$port/index.html');

  static Future<SpotifyPlaybackSdkLocalServer> start(String html) async {
    final server = await HttpServer.bind(
      InternetAddress.loopbackIPv4,
      port,
      shared: true,
    );
    final instance = SpotifyPlaybackSdkLocalServer._(server);
    unawaited(instance._serve(html));
    return instance;
  }

  Future<void> _serve(String html) async {
    await for (final request in _server) {
      try {
        request.response.statusCode = HttpStatus.ok;
        request.response.headers.contentType = ContentType.html;
        request.response.write(html);
        await request.response.close();
      } catch (_) {
        // Conexión cerrada a mitad de respuesta; sin acción.
      }
    }
  }

  Future<void> stop() async {
    try {
      await _server.close(force: true);
    } catch (_) {}
  }
}
