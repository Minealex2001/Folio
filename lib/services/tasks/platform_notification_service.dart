import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:local_notifier/local_notifier.dart';

/// Wrapper sobre [LocalNotifier] para notificaciones nativas de escritorio.
/// Actualmente solo activo en Windows; en otras plataformas todas las llamadas
/// son no-op para evitar complejidad de permisos / setup adicional.
class PlatformNotificationService {
  PlatformNotificationService._();

  static bool _initialized = false;

  /// true si la plataforma actual puede mostrar notificaciones nativas.
  static bool get supported => !kIsWeb && Platform.isWindows;

  /// Inicializa el plugin. Debe llamarse una sola vez desde [FolioApp].
  static Future<void> init() async {
    if (!supported || _initialized) return;
    await localNotifier.setup(appName: 'Folio');
    _initialized = true;
  }

  /// Muestra una notificación nativa con [title] y [body].
  ///
  /// [id] identifica la notificación; se convierte en un String único.
  /// Si el servicio no está inicializado o la plataforma no es Windows, no hace nada.
  static Future<void> show({
    required int id,
    required String title,
    required String body,
  }) async {
    if (!supported || !_initialized) return;
    final notification = LocalNotification(
      identifier: 'folio_task_$id',
      title: title,
      body: body,
    );
    await notification.show();
  }
}
