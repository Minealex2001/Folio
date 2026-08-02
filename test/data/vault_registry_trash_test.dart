import 'package:flutter_test/flutter_test.dart';
import 'package:folio/data/vault_entry.dart';
import 'package:folio/data/vault_registry.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('VaultRegistry trash/restore', () {
    test('trash oculta de vaults pero conserva en allVaults', () async {
      final registry = VaultRegistry.instance;
      await registry.load();
      await registry.add(
        const VaultEntry(id: 'a', displayName: 'A', createdAtMs: 1),
      );

      await registry.trash('a');

      expect(registry.vaults.any((e) => e.id == 'a'), isFalse);
      expect(registry.allVaults.any((e) => e.id == 'a'), isTrue);
      expect(registry.trashedVaults.single.id, 'a');
      expect(registry.entryFor('a')?.isTrashed, isTrue);
    });

    test('trash de la libreta activa limpia activeVaultId', () async {
      final registry = VaultRegistry.instance;
      await registry.load();
      await registry.add(
        const VaultEntry(id: 'b', displayName: 'B', createdAtMs: 1),
      );
      await registry.setActiveVaultId('b');

      await registry.trash('b');

      expect(registry.activeVaultId, isNull);
    });

    test('restoreFromTrash deshace el trash', () async {
      final registry = VaultRegistry.instance;
      await registry.load();
      await registry.add(
        const VaultEntry(id: 'c', displayName: 'C', createdAtMs: 1),
      );
      await registry.trash('c');
      await registry.restoreFromTrash('c');

      expect(registry.vaults.any((e) => e.id == 'c'), isTrue);
      expect(registry.trashedVaults, isEmpty);
    });
  });
}
