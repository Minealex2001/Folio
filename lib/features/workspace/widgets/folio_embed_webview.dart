import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_windows/webview_windows.dart';

import '../../../l10n/generated/app_localizations.dart';

/// Vista web embebida cuando la plataforma lo permite (Windows WebView2, Android, iOS, macOS).
class FolioEmbedWebView extends StatefulWidget {
  const FolioEmbedWebView({super.key, required this.url, required this.scheme});

  final String url;
  final ColorScheme scheme;

  @override
  State<FolioEmbedWebView> createState() => _FolioEmbedWebViewState();
}

class _FolioEmbedWebViewState extends State<FolioEmbedWebView> {
  WebViewController? _mobile;
  WebviewController? _windows;
  String? _error;
  var _winReady = false;

  bool get _useWindows => !kIsWeb && Platform.isWindows;

  bool get _useMobileWebView =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS);

  @override
  void initState() {
    super.initState();
    final uri = Uri.tryParse(widget.url.trim());
    if (uri == null ||
        (!uri.hasScheme || (uri.scheme != 'http' && uri.scheme != 'https'))) {
      _error = 'bad';
      return;
    }
    if (_useWindows) {
      _windows = WebviewController();
      unawaited(_initWindows(uri.toString()));
    } else if (_useMobileWebView) {
      _mobile = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.transparent)
        ..loadRequest(uri);
    }
  }

  Future<void> _initWindows(String url) async {
    final c = _windows;
    if (c == null) return;
    try {
      await c.initialize();
      await c.setBackgroundColor(Colors.transparent);
      await c.setPopupWindowPolicy(WebviewPopupWindowPolicy.deny);
      await c.loadUrl(url);
      if (mounted) setState(() => _winReady = true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
        });
      }
    }
  }

  @override
  void dispose() {
    final w = _windows;
    if (w != null) {
      unawaited(w.dispose());
    }
    super.dispose();
  }

  Future<void> _openExternal() async {
    final u = Uri.tryParse(widget.url.trim());
    if (u != null && await canLaunchUrl(u)) {
      await launchUrl(u, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (_error != null) {
      return _Fallback(
        scheme: widget.scheme,
        message: l10n.embedUnavailable,
        url: widget.url,
        onOpen: _openExternal,
      );
    }
    if (kIsWeb || (!kIsWeb && Platform.isLinux)) {
      return _Fallback(
        scheme: widget.scheme,
        message: l10n.embedUnavailable,
        url: widget.url,
        onOpen: _openExternal,
      );
    }
    if (_useWindows) {
      final c = _windows;
      if (c == null || !_winReady) {
        return const Center(child: CircularProgressIndicator());
      }
      return Webview(
        c,
        permissionRequested: (controller, url, kind) async =>
            WebviewPermissionDecision.allow,
      );
    }
    if (_useMobileWebView && _mobile != null) {
      return WebViewWidget(controller: _mobile!);
    }
    return _Fallback(
      scheme: widget.scheme,
      message: l10n.embedUnavailable,
      url: widget.url,
      onOpen: _openExternal,
    );
  }
}

class _Fallback extends StatelessWidget {
  const _Fallback({
    required this.scheme,
    required this.message,
    required this.url,
    required this.onOpen,
  });

  final ColorScheme scheme;
  final String message;
  final String url;
  final Future<void> Function() onOpen;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.web_asset_off_outlined, size: 40, color: scheme.outline),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            SelectableText(
              url,
              style: TextStyle(color: scheme.primary, fontSize: 12),
            ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: () => unawaited(onOpen()),
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: Text(AppLocalizations.of(context).bookmarkOpenLink),
            ),
          ],
        ),
      ),
    );
  }
}
