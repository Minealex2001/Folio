import 'dart:async';
import 'dart:html' as html;

import 'package:flutter/foundation.dart';

/// Estado de instalación PWA en el navegador.
class PwaInstallController extends ChangeNotifier {
  PwaInstallController._() {
    _syncFromDom();
    html.window.addEventListener('folio-pwa-can-install', _onCanInstall);
    html.window.addEventListener('folio-pwa-installed', _onInstalled);
  }

  static final PwaInstallController instance = PwaInstallController._();

  var _canInstall = false;
  var _isStandalone = false;

  bool get canInstall => _canInstall && !_isStandalone;

  bool get isStandalone => _isStandalone;

  void _syncFromDom() {
    final root = html.document.documentElement;
    _canInstall = root?.getAttribute('data-folio-pwa-can-install') == '1';
    _isStandalone = root?.getAttribute('data-folio-pwa-standalone') == '1' ||
        _matchStandalone();
  }

  bool _matchStandalone() {
    try {
      return html.window.matchMedia('(display-mode: standalone)').matches;
    } catch (_) {
      return false;
    }
  }

  void _onCanInstall(html.Event _) {
    _syncFromDom();
    _canInstall = true;
    notifyListeners();
  }

  void _onInstalled(html.Event _) {
    _canInstall = false;
    _isStandalone = true;
    notifyListeners();
  }

  /// Muestra el diálogo nativo «Instalar aplicación» si el navegador lo permite.
  Future<PwaInstallOutcome> promptInstall() async {
    if (_isStandalone) return PwaInstallOutcome.unavailable;

    final completer = Completer<PwaInstallOutcome>();
    void onResult(html.Event e) {
      html.window.removeEventListener('folio-pwa-prompt-result', onResult);
      final detail = (e as html.CustomEvent).detail?.toString() ?? 'dismissed';
      switch (detail) {
        case 'accepted':
          _isStandalone = true;
          _canInstall = false;
          notifyListeners();
          completer.complete(PwaInstallOutcome.accepted);
        case 'unavailable':
          completer.complete(PwaInstallOutcome.unavailable);
        default:
          _syncFromDom();
          notifyListeners();
          completer.complete(PwaInstallOutcome.dismissed);
      }
    }

    html.window.addEventListener('folio-pwa-prompt-result', onResult);
    html.window.dispatchEvent(html.CustomEvent('folio-pwa-request-install'));
    return completer.future.timeout(
      const Duration(minutes: 2),
      onTimeout: () {
        html.window.removeEventListener('folio-pwa-prompt-result', onResult);
        return PwaInstallOutcome.dismissed;
      },
    );
  }

  void disposeListeners() {
    html.window.removeEventListener('folio-pwa-can-install', _onCanInstall);
    html.window.removeEventListener('folio-pwa-installed', _onInstalled);
  }
}

enum PwaInstallOutcome { accepted, dismissed, unavailable }
