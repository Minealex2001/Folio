import 'dart:async';
import 'dart:html' as html;
import 'dart:js' as js;

import 'package:flutter/widgets.dart';

import 'spotify_local_device_service.dart';
import 'spotify_playback_sdk_html.dart';

/// En Flutter Web la app ya corre dentro de un navegador real, así que el
/// Web Playback SDK se inyecta directamente en el DOM (sin WebView).
bool get spotifyLocalDeviceSupported => true;

const _scriptElementId = 'folio-spotify-sdk-bootstrap';
const _sdkScriptElementId = 'folio-spotify-sdk-script';

/// Host invisible que inyecta/retira el script del SDK en el `<head>` del
/// documento según el estado del toggle de dispositivo local.
class SpotifyLocalDeviceHost extends StatefulWidget {
  const SpotifyLocalDeviceHost({super.key});

  @override
  State<SpotifyLocalDeviceHost> createState() => _SpotifyLocalDeviceHostState();
}

class _SpotifyLocalDeviceHostState extends State<SpotifyLocalDeviceHost> {
  final _service = SpotifyLocalDeviceService.instance;
  Timer? _tokenTimer;
  bool _injected = false;

  @override
  void initState() {
    super.initState();
    _service.addListener(_onServiceChanged);
    _onServiceChanged();
  }

  void _onServiceChanged() {
    if (_service.enabled) {
      if (!_injected) _inject();
    } else {
      if (_injected) _remove();
    }
  }

  void _inject() {
    _injected = true;
    js.context['__folioDartBridge'] = (String msg) {
      _service.handleBridgeMessage(msg);
    };

    if (html.document.getElementById(_scriptElementId) == null) {
      final bootstrap = html.ScriptElement()
        ..id = _scriptElementId
        ..type = 'text/javascript'
        ..text = _extractInlineScript(spotifyPlaybackSdkHtml);
      html.document.head?.append(bootstrap);
    }
    if (html.document.getElementById(_sdkScriptElementId) == null) {
      final sdk = html.ScriptElement()
        ..id = _sdkScriptElementId
        ..src = 'https://sdk.scdn.co/spotify-player.js';
      html.document.head?.append(sdk);
    }

    unawaited(_pushTokenAndSchedule());
  }

  Future<void> _pushTokenAndSchedule() async {
    Future<void> pushOnce() async {
      final provider = _service.tokenProvider;
      if (provider == null) return;
      final token = await provider();
      if (token == null || token.isEmpty) return;
      js.context['__folioToken'] = token;
    }

    await pushOnce();
    _tokenTimer?.cancel();
    _tokenTimer = Timer.periodic(const Duration(minutes: 20), (_) {
      unawaited(pushOnce());
    });
  }

  void _remove() {
    _injected = false;
    _tokenTimer?.cancel();
    _tokenTimer = null;
    try {
      (js.context['__folioPlayer'] as js.JsObject?)?.callMethod('disconnect');
    } catch (_) {}
    html.document.getElementById(_scriptElementId)?.remove();
    html.document.getElementById(_sdkScriptElementId)?.remove();
  }

  @override
  void dispose() {
    _service.removeListener(_onServiceChanged);
    _remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// Extrae el contenido del primer `<script>` inline de la plantilla HTML
/// compartida (el que define `onSpotifyWebPlaybackSDKReady`), descartando el
/// `<script src="...">` del SDK (ese se inyecta aparte para poder quitarlo
/// al desactivar el dispositivo local).
String _extractInlineScript(String source) {
  final start = source.indexOf('<script>');
  final end = source.indexOf('</script>', start);
  if (start == -1 || end == -1) return '';
  return source.substring(start + '<script>'.length, end);
}
