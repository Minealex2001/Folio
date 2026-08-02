import 'package:flutter_test/flutter_test.dart';
import 'package:folio/services/folio_cloud/device_sync_trash_guard.dart';

void main() {
  group('shouldAutoTrashVaultOnRemoteTombstone', () {
    test('mueve a papelera en silencio si el dispositivo ya estaba al día', () {
      expect(
        shouldAutoTrashVaultOnRemoteTombstone(
          localAckedRev: 5,
          remoteTrashedRev: 5,
        ),
        isTrue,
      );
      expect(
        shouldAutoTrashVaultOnRemoteTombstone(
          localAckedRev: 7,
          remoteTrashedRev: 5,
        ),
        isTrue,
      );
    });

    test('no mueve a papelera si hay cambios locales sin sincronizar', () {
      expect(
        shouldAutoTrashVaultOnRemoteTombstone(
          localAckedRev: 3,
          remoteTrashedRev: 5,
        ),
        isFalse,
      );
    });

    test('sin ack previo (nunca sincronizada) se trata como no seguro', () {
      expect(
        shouldAutoTrashVaultOnRemoteTombstone(
          localAckedRev: 0,
          remoteTrashedRev: 1,
        ),
        isFalse,
      );
    });
  });
}
