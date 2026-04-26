import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_windows/webview_windows.dart';

import '../../../models/block.dart';
import '../../../services/app_store/app_extension_registry.dart';

/// Widget que renderiza un bloque de tipo personalizado (proveniente de una app instalada)
/// usando WebView.  El tipo del bloque sigue el formato de reverse-domain (p.ej. `com.acme.chart`).
///
/// Comunicación JS→Flutter: `Folio.updateBlock(json)` actualiza los datos del bloque.
/// Comunicación Flutter→JS: se inyecta `window.__folioBlock = <json>` antes de cargar.
class CustomAppBlockWidget extends StatefulWidget {
  const CustomAppBlockWidget({
    super.key,
    required this.block,
    required this.scheme,
    required this.appRegistry,
    this.onBlockUpdated,
  });

  final FolioBlock block;
  final ColorScheme scheme;
  final AppExtensionRegistry appRegistry;

  /// Callback cuando el bloque pide actualizar sus datos vía JS bridge.
  final ValueChanged<Map<String, dynamic>>? onBlockUpdated;

  @override
  State<CustomAppBlockWidget> createState() => _CustomAppBlockWidgetState();
}

class _CustomAppBlockWidgetState extends State<CustomAppBlockWidget> {
  WebViewController? _mobile;
  WebviewController? _windows;
  bool _winReady = false;
  String? _error;

  bool get _useWindows => !kIsWeb && Platform.isWindows;
  bool get _useMobileWebView =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS);

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  Future<void> _initWebView() async {
    final html = _buildHtml();
    if (html == null) {
      if (mounted) setState(() => _error = 'Bloque no disponible.');
      return;
    }

    if (_useWindows) {
      final c = WebviewController();
      _windows = c;
      try {
        await c.initialize();
        await c.setBackgroundColor(Colors.transparent);
        await c.setPopupWindowPolicy(WebviewPopupWindowPolicy.deny);

        // JS bridge: Folio.updateBlock(json) → onBlockUpdated callback
        await c.executeScript('''
window.Folio = {
  updateBlock: function(data) {
    window.chrome.webview.postMessage(JSON.stringify(data));
  }
};
''');

        c.webMessage.listen(_onWindowsMessage);

        // Inyectar datos del bloque antes del HTML
        // Carga HTML como data URI
        final dataUri =
            'data:text/html;charset=utf-8,${Uri.encodeComponent(html)}';
        await c.loadUrl(dataUri);

        if (mounted) setState(() => _winReady = true);
      } catch (e) {
        if (mounted) setState(() => _error = 'Error al cargar bloque: $e');
      }
    } else if (_useMobileWebView) {
      final c = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.transparent)
        ..addJavaScriptChannel(
          'FolioNative',
          onMessageReceived: _onMobileMessage,
        )
        ..loadHtmlString(html);
      if (mounted) setState(() => _mobile = c);
    }
  }

  void _onWindowsMessage(dynamic message) {
    if (message is String) {
      try {
        final data = jsonDecode(message) as Map<String, dynamic>;
        widget.onBlockUpdated?.call(data);
      } catch (_) {}
    }
  }

  void _onMobileMessage(JavaScriptMessage message) {
    try {
      final data = jsonDecode(message.message) as Map<String, dynamic>;
      widget.onBlockUpdated?.call(data);
    } catch (_) {}
  }

  /// Construye el HTML que se cargará, inyectando los datos del bloque y
  /// el bridge de Folio como variables globales.
  String? _buildHtml() {
    final blockType = widget.appRegistry.blockTypeForKey(widget.block.type);
    if (blockType == null) return null;

    // Buscar la app propietaria del bloque
    final parts = widget.block.type.split('.');
    if (parts.length < 2) return null;
    final appId = parts.sublist(0, parts.length - 1).join('.');

    // Buscar app instalada
    String? localPath;
    for (final def in widget.appRegistry.registeredBlockTypes) {
      if (def.key == widget.block.type) {
        // Encontramos el registro; necesitamos el localPath de la app instalada
        // AppExtensionRegistry expone el path via installedLocalPaths map
        localPath = widget.appRegistry.installedLocalPaths[appId];
        break;
      }
    }

    if (localPath == null) return null;

    final blockJson = const JsonEncoder.withIndent(
      '  ',
    ).convert(widget.block.toJson());

    // Inyectar bridge mobile-compatible (envía a FolioNative si existe, sino a chrome.webview)
    const bridge = '''
<script>
  window.__folioBlock = null;
  window.Folio = {
    updateBlock: function(data) {
      var json = typeof data === 'string' ? data : JSON.stringify(data);
      if (window.FolioNative) {
        window.FolioNative.postMessage(json);
      } else if (window.chrome && window.chrome.webview) {
        window.chrome.webview.postMessage(json);
      }
    }
  };
</script>
''';

    final inject =
        '''
<script>
  window.__folioBlock = $blockJson;
</script>
''';

    // Intentar construir HTML estándar si no existe un archivo físico.
    // En una implementación completa, se leerían los assets del .folioapp extraído.
    return '''<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>
  body { margin: 0; padding: 8px; font-family: sans-serif; }
  #app { width: 100%; }
</style>
$bridge
$inject
</head>
<body>
<div id="app"></div>
<script src="renderer.js"></script>
</body>
</html>''';
  }

  @override
  void dispose() {
    final w = _windows;
    if (w != null) unawaited(w.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return _ErrorView(
        blockType: widget.block.type,
        error: _error!,
        scheme: widget.scheme,
      );
    }

    if (_useWindows) {
      final c = _windows;
      if (c == null || !_winReady) {
        return const SizedBox(
          height: 80,
          child: Center(child: CircularProgressIndicator.adaptive()),
        );
      }
      return Webview(
        c,
        permissionRequested: (controller, url, kind) async =>
            WebviewPermissionDecision.allow,
      );
    }

    if (_useMobileWebView) {
      final c = _mobile;
      if (c == null) {
        return const SizedBox(
          height: 80,
          child: Center(child: CircularProgressIndicator.adaptive()),
        );
      }
      return SizedBox(height: 200, child: WebViewWidget(controller: c));
    }

    return _ErrorView(
      blockType: widget.block.type,
      error: 'Bloques personalizados no disponibles en esta plataforma.',
      scheme: widget.scheme,
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.blockType,
    required this.error,
    required this.scheme,
  });

  final String blockType;
  final String error;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.errorContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: scheme.error, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$blockType: $error',
              style: TextStyle(fontSize: 12, color: scheme.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}
