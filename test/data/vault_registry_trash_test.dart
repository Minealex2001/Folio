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

  group('VaultRegistry adopt / rebind account', () {
    test('filtra por accountUid y adopta a la cuenta activa', () async {
      final registry = VaultRegistry.instance;
      await registry.bindContext(accountUid: 'personal-uid');
      await registry.add(
        const VaultEntry(
          id: 'v1',
          displayName: 'Empresa',
          createdAtMs: 1,
          accountUid: 'personal-uid',
        ),
      );
      expect(registry.vaults, hasLength(1));

      await registry.bindContext(accountUid: 'company-uid');
      expect(registry.vaults, isEmpty);
      expect(registry.adoptablePersonalVaultsFor('company-uid'), hasLength(1));

      final n = await registry.adoptPersonalVaultsToAccount('company-uid');
      expect(n, 1);
      expect(registry.vaults.single.id, 'v1');
      expect(registry.entryFor('v1')?.accountUid, 'company-uid');
    });

    test('rebind limpia organizationId de workspace de equipo', () async {
      final registry = VaultRegistry.instance;
      await registry.bindContext(accountUid: 'old');
      await registry.add(
        const VaultEntry(
          id: 'team-v',
          displayName: 'Team',
          createdAtMs: 1,
          accountUid: 'old',
          organizationId: 'org-1',
          workspaceId: 'ws-1',
        ),
      );

      await registry.rebindAccountUid(
        vaultId: 'team-v',
        newAccountUid: 'new',
      );
      final e = registry.entryFor('team-v')!;
      expect(e.accountUid, 'new');
      expect(e.organizationId, isNull);
      expect(e.workspaceId, isNull);
    });
  });
}
