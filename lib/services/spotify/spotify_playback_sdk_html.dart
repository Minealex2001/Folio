import 'dart:convert';

/// Página mínima que arranca el Spotify Web Playback SDK y reenvía sus
/// eventos de vuelta a Dart. El puente de salida (`__folioPost`) soporta tres
/// mecanismos según la plataforma que la aloje:
/// - `window.__folioDartBridge` (función expuesta vía `dart:js` en Flutter Web).
/// - `window.FolioBridge.postMessage` (canal JS de `webview_flutter`).
/// - `window.chrome.webview.postMessage` (bridge nativo de `webview_windows`).
const String spotifyPlaybackSdkHtml = '''
<!DOCTYPE html>
<html>
<head><meta charset="utf-8"></head>
<body>
<script>
  window.__folioToken = "";

  function __folioPost(type, payload) {
    var msg = JSON.stringify({ type: type, payload: payload || {} });
    try {
      if (window.__folioDartBridge) { window.__folioDartBridge(msg); return; }
    } catch (e) {}
    try {
      if (window.FolioBridge) { window.FolioBridge.postMessage(msg); return; }
    } catch (e) {}
    try {
      if (window.chrome && window.chrome.webview) {
        window.chrome.webview.postMessage(msg);
        return;
      }
    } catch (e) {}
  }

  window.onSpotifyWebPlaybackSDKReady = function () {
    var player = new Spotify.Player({
      name: 'Folio',
      getOAuthToken: function (cb) { cb(window.__folioToken || ''); },
      volume: 0.5
    });
    window.__folioPlayer = player;

    player.addListener('ready', function (e) {
      __folioPost('ready', { device_id: e.device_id });
    });
    player.addListener('not_ready', function (e) {
      __folioPost('not_ready', { device_id: e.device_id });
    });
    player.addListener('initialization_error', function (e) {
      __folioPost('initialization_error', { message: e.message });
    });
    player.addListener('authentication_error', function (e) {
      __folioPost('authentication_error', { message: e.message });
    });
    player.addListener('account_error', function (e) {
      __folioPost('account_error', { message: e.message });
    });
    player.addListener('playback_error', function (e) {
      __folioPost('playback_error', { message: e.message });
    });

    player.connect();
  };
</script>
<script src="https://sdk.scdn.co/spotify-player.js"></script>
</body>
</html>
''';

/// Script que actualiza el token OAuth cacheado por la página del SDK.
/// Debe reenviarse cada vez que Folio refresca el access token.
String spotifyPlaybackSdkSetTokenScript(String accessToken) =>
    'window.__folioToken = ${jsonEncode(accessToken)};';
