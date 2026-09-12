import 'package:flutter_test/flutter_test.dart';
import 'package:folio/services/folio_cloud/device_sync_vault_bootstrap.dart';

void main() {
  group('isDeviceSyncWireMacFailure', () {
    test('detecta mensajes MAC típicos', () {
      expect(
        isDeviceSyncWireMacFailure(
          StateError('Wrong message authentication code'),
        ),
        isTrue,
      );
      expect(
        isDeviceSyncWireMacFailure(
          Exception('SecretBoxAuthenticationError'),
        ),
        isTrue,
      );
    });

    test('no enmascara blob missing ni errores genéricos', () {
      expect(
        isDeviceSyncWireMacFailure(
          StateError('Missing device-sync blob: abc'),
        ),
        isFalse,
      );
      expect(
        isDeviceSyncWireMacFailure(StateError('Empty sync pack')),
        isFalse,
      );
      expect(isDeviceSyncWireMacFailure(Exception('timeout')), isFalse);
    });
  });
}
