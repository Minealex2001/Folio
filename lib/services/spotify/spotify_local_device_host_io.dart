import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_windows/webview_windows.dart';

import 'spotify_local_device_service.dart';
import 'spotify_playback_sdk_html.dart';
import 'spotify_playback_sdk_local_server.dart';

/// Windows (WebView2/Edge Chromium) y Android/iOS/macOS (WKWebView / Chromium
/// del sistema) soportan el Web Playback SDK vía WebView embebido. Linux no
/// tiene un WebView Flutter con soporte EME/Widevine fiable, así que ahí el
/// dispositivo local se queda deshabilitado (fallback a control remoto).
bool get spotifyLocalDeviceSupported =>
    Platform.isWindows || Platform.isAndroid || Platform.isIOS || Platform.isMacOS;

/// Host invisible que arranca el Web Playback SDK cuando el usuario activa
/// el dispositivo local. No pinta nada visible: vive en el árbol solo para
/// mantener viva la instancia nativa de WebView.
class SpotifyLocalDeviceHost extends StatefulWidget {
  const SpotifyLocalDeviceHost({super.key});

  @override
  State<SpotifyLocalDeviceHost> createState() => _SpotifyLocalDeviceHostState();
}

class _SpotifyLocalDeviceHostState extends State<SpotifyLocalDeviceHost> {
  final _service = SpotifyLocalDeviceService.instance;

  WebViewController? _mobileController;
  WebviewController? _windowsController;
  StreamSubscription<dynamic>? _windowsMessageSub;
  SpotifyPlaybackSdkLocalServer? _localServer;
  Timer? _tokenTimer;
  bool _starting = false;
  bool _started = false;

  bool get _useWindows => Platform.isWindows;
  bool get _useMobile => Platform.isAndroid || Platform.isIOS || Platform.isMacOS;

  @override
  void initState() {
    super.initState();
    _service.addListener(_onServiceChanged);
    _onServiceChanged();
  }

  void _onServiceChanged() {
    if (_service.enabled && spotifyLocalDeviceSupported) {
      if (!_started && !_starting) unawaited(_start());
    } else {
      if (_started || _starting) unawaited(_stop());
    }
  }

  Future<void> _start() async {
    _starting = true;
    try {
      if (_useWindows) {
        await _startWindows();
      } else if (_useMobile) {
        await _startMobile();
      }
      _started = true;
    } catch (_) {
      // El servicio se queda en "connecting"; el usuario puede reintentar
      // apagando/encendiendo el toggle.
    } finally {
      _starting = false;
    }
  }

  Future<void> _startWindows() async {
    final server = await SpotifyPlaybackSdkLocalServer.start(spotifyPlaybackSdkHtml);
    _localServer = server;
    final controller = WebviewController();
    _windowsController = controller;
    await controller.initialize();
    _windowsMessageSub = controller.webMessage.listen((event) {
      if (event is String) _service.handleBridgeMessage(event);
    });
    await controller.setBackgroundColor(Colors.transparent);
    await controller.setPopupWindowPolicy(WebviewPopupWindowPolicy.deny);
    await controller.loadUrl(server.url.toString());
    await _pushTokenAndSchedule(
      run: (script) => controller.executeScript(script),
    );
  }

  Future<void> _startMobile() async {
    final server = await SpotifyPlaybackSdkLocalServer.start(spotifyPlaybackSdkHtml);
    _localServer = server;
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'FolioBridge',
        onMessageReceived: (message) =>
            _service.handleBridgeMessage(message.message),
      );
    await controller.setNavigationDelegate(
      NavigationDelegate(
        onPageFinished: (_) {
          unawaited(
            _pushTokenAndSchedule(
              run: (script) => controller.runJavaScript(script),
            ),
          );
        },
      ),
    );
    _mobileController = controller;
    await controller.loadRequest(server.url);
  }

  Future<void> _pushTokenAndSchedule({
    required Future<dynamic> Function(String script) run,
  }) async {
    Future<void> pushOnce() async {
      final provider = _service.tokenProvider;
      if (provider == null) return;
      final token = await provider();
      if (token == null || token.isEmpty) return;
      await run(spotifyPlaybackSdkSetTokenScript(token));
    }

    await pushOnce();
    _tokenTimer?.cancel();
    _tokenTimer = Timer.periodic(const Duration(minutes: 20), (_) {
      unawaited(pushOnce());
    });
  }

  Future<void> _stop() async {
    _starting = false;
    _started = false;
    _tokenTimer?.cancel();
    _tokenTimer = null;
    await _windowsMessageSub?.cancel();
    _windowsMessageSub = null;
    final win = _windowsController;
    _windowsController = null;
    if (win != null) unawaited(win.dispose());
    _mobileController = null;
    final server = _localServer;
    _localServer = null;
    if (server != null) unawaited(server.stop());
  }

  @override
  void dispose() {
    _service.removeListener(_onServiceChanged);
    unawaited(_stop());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Nunca se muestra: el padre (SpotifyLocalDeviceMount) lo mantiene fuera
    // de pantalla con Offstage. Solo necesitamos que el plugin de WebView
    // esté montado para que el SDK JS siga vivo en segundo plano.
    if (_useWindows && _windowsController != null) {
      return Webview(_windowsController!);
    }
    if (_useMobile && _mobileController != null) {
      return WebViewWidget(controller: _mobileController!);
    }
    return const SizedBox.shrink();
  }
}
