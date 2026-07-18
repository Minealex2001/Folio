import 'package:flutter/foundation.dart';

/// Estado de instalación PWA (solo relevante en web).
class PwaInstallController extends ChangeNotifier {
  PwaInstallController._();
  static final PwaInstallController instance = PwaInstallController._();

  /// En plataformas no web no hay instalación PWA.
  bool get canInstall => false;

  bool get isStandalone => false;

  /// No-op fuera de web.
  Future<PwaInstallOutcome> promptInstall() async => PwaInstallOutcome.unavailable;

  void disposeListeners() {}
}

enum PwaInstallOutcome { accepted, dismissed, unavailable }
