// Selección de implementación del host del dispositivo local Spotify según
// plataforma: WebView nativo (Windows/Android/iOS/macOS) en el resto,
// inyección directa en el DOM en Web. Linux queda sin soporte (ver
// `spotify_local_device_host_io.dart`).
export 'spotify_local_device_host_io.dart'
    if (dart.library.html) 'spotify_local_device_host_web.dart';
