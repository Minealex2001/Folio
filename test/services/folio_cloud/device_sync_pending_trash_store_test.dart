import 'package:flutter_test/flutter_test.dart';
import 'package:folio/services/folio_cloud/device_sync_pending_trash_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('DeviceSyncPendingTrashStore', () {
    test('marca, consulta y limpia un vaultId pendiente', () async {
      final store = DeviceSyncPendingTrashStore();
      expect(await store.isPending('v1'), isFalse);

      await store.markPending('v1');
      expect(await store.isPending('v1'), isTrue);
      expect(await store.pendingVaultIds(), contains('v1'));

      await store.clear('v1');
      expect(await store.isPending('v1'), isFalse);
    });

    test('persiste entre instancias (misma SharedPreferences)', () async {
      final store1 = DeviceSyncPendingTrashStore();
      await store1.markPending('v2');

      final store2 = DeviceSyncPendingTrashStore();
      expect(await store2.isPending('v2'), isTrue);
    });
  });
}
