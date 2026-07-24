/// Regresión: el push automático de device-sync (activo y headless) no debe
/// subir un payload sin páginas cuando ya había evidencia de contenido previo
/// (fingerprint propio ya confirmado, blobs cacheados, o remoto ya poblado).
/// Antes de este fix, `_pushIfNeeded`/`_syncVaultHeadlessBody` solo comprobaban
/// que los *bytes* exportados no fueran nulos/vacíos, pero un payload con
/// `pages: []` serializa a JSON no vacío, así que ese check nunca protegía
/// nada — ver folio_cloud_device_sync.dart.
import 'package:flutter_test/flutter_test.dart';
import 'package:folio/services/folio_cloud/device_sync_push_guard.dart';

void main() {
  group('shouldSkipEmptyDeviceSyncPush', () {
    test('bloquea un payload vacío cuando ya había contenido previo', () {
      expect(
        shouldSkipEmptyDeviceSyncPush(
          payloadHasPages: false,
          hadPriorContent: true,
        ),
        isTrue,
      );
    });

    test('permite el primer push de una libreta nueva y vacía', () {
      expect(
        shouldSkipEmptyDeviceSyncPush(
          payloadHasPages: false,
          hadPriorContent: false,
        ),
        isFalse,
      );
    });

    test('permite un push normal con páginas, haya o no historial previo', () {
      expect(
        shouldSkipEmptyDeviceSyncPush(
          payloadHasPages: true,
          hadPriorContent: true,
        ),
        isFalse,
      );
      expect(
        shouldSkipEmptyDeviceSyncPush(
          payloadHasPages: true,
          hadPriorContent: false,
        ),
        isFalse,
      );
    });
  });
}
