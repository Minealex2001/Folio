import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:folio/app/app_settings.dart';
import 'package:folio/models/vault_memory_fact.dart';

/// Fase A4 del plan Quill/MCP — hechos duraderos que Quill incluye
/// automáticamente como contexto, pero que solo el usuario puede escribir.
///
/// Fase 5 de Quill 2.0 — antes se guardaban en una única clave global de
/// `SharedPreferences` compartida por todos los vaults del dispositivo (fuga
/// real: los hechos de una libreta se filtraban al contexto de Quill en
/// todas las demás). Ahora están aislados por `vaultId`, con migración
/// best-effort desde la clave legacy: la primera libreta que los consulte
/// tras la actualización los adopta, y la clave legacy se borra de inmediato
/// (el formato legacy nunca guardó `vaultId`, así que no hay forma de saber
/// a qué libreta pertenecía cada hecho — no se reparte ni se infiere).
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('VaultMemoryFact', () {
    test('round-trip de serialización preserva todos los campos', () {
      final fact = VaultMemoryFact(
        id: 'f1',
        text: 'Este proyecto usa Spring Boot',
        createdAt: DateTime.utc(2026, 8, 9, 12),
        scope: MemoryFactScope.permanent,
      );
      final restored = VaultMemoryFact.fromJson(fact.toJson());
      expect(restored.id, fact.id);
      expect(restored.text, fact.text);
      expect(restored.createdAt, fact.createdAt);
      expect(restored.scope, MemoryFactScope.permanent);
    });

    test('fromJson con scope desconocido cae a permanent', () {
      final restored = VaultMemoryFact.fromJson({
        'id': 'f1',
        'text': 'x',
        'createdAt': DateTime.now().toIso8601String(),
        'scope': 'nonsense',
      });
      expect(restored.scope, MemoryFactScope.permanent);
    });
  });

  group('AppSettings.getVaultMemoryFacts — aislado por libreta', () {
    test('empieza vacío para cualquier vaultId', () async {
      final settings = AppSettings();
      await settings.load();
      expect(await settings.getVaultMemoryFacts('vault-A'), isEmpty);
    });

    test('vaultId vacío o null siempre devuelve vacío, sin tocar el storage', () async {
      final settings = AppSettings();
      await settings.load();
      expect(await settings.getVaultMemoryFacts(null), isEmpty);
      expect(await settings.getVaultMemoryFacts(''), isEmpty);
      expect(await settings.getVaultMemoryFacts('  '), isEmpty);
    });

    test('addVaultMemoryFact añade y persiste, aislado por vaultId', () async {
      final settings = AppSettings();
      await settings.load();
      await settings.addVaultMemoryFact(
        'vault-A',
        VaultMemoryFact(
          id: 'f1',
          text: 'Usa Maven',
          createdAt: DateTime.now(),
          scope: MemoryFactScope.permanent,
        ),
      );
      expect(await settings.getVaultMemoryFacts('vault-A'), hasLength(1));

      final reloaded = AppSettings();
      await reloaded.load();
      final reloadedFacts = await reloaded.getVaultMemoryFacts('vault-A');
      expect(reloadedFacts, hasLength(1));
      expect(reloadedFacts.single.text, 'Usa Maven');
    });

    test('dos vaultId distintos nunca ven los hechos del otro', () async {
      final settings = AppSettings();
      await settings.load();
      await settings.addVaultMemoryFact(
        'vault-A',
        VaultMemoryFact(id: 'a1', text: 'solo de A', createdAt: DateTime.now(), scope: MemoryFactScope.permanent),
      );
      await settings.addVaultMemoryFact(
        'vault-B',
        VaultMemoryFact(id: 'b1', text: 'solo de B', createdAt: DateTime.now(), scope: MemoryFactScope.permanent),
      );

      final factsA = await settings.getVaultMemoryFacts('vault-A');
      final factsB = await settings.getVaultMemoryFacts('vault-B');

      expect(factsA.map((f) => f.id), ['a1']);
      expect(factsB.map((f) => f.id), ['b1']);
    });

    test('deleteVaultMemoryFact borra solo el id indicado, dentro de esa libreta', () async {
      final settings = AppSettings();
      await settings.load();
      await settings.addVaultMemoryFact(
        'vault-A',
        VaultMemoryFact(id: 'f1', text: 'a', createdAt: DateTime.now(), scope: MemoryFactScope.permanent),
      );
      await settings.addVaultMemoryFact(
        'vault-A',
        VaultMemoryFact(id: 'f2', text: 'b', createdAt: DateTime.now(), scope: MemoryFactScope.temporary),
      );

      await settings.deleteVaultMemoryFact('vault-A', 'f1');

      final facts = await settings.getVaultMemoryFacts('vault-A');
      expect(facts.map((f) => f.id), ['f2']);
    });

    test('clearTemporaryVaultMemoryFacts borra solo los temporales de esa libreta', () async {
      final settings = AppSettings();
      await settings.load();
      await settings.addVaultMemoryFact(
        'vault-A',
        VaultMemoryFact(id: 'temp1', text: 'a', createdAt: DateTime.now(), scope: MemoryFactScope.temporary),
      );
      await settings.addVaultMemoryFact(
        'vault-A',
        VaultMemoryFact(id: 'perm1', text: 'b', createdAt: DateTime.now(), scope: MemoryFactScope.permanent),
      );
      await settings.addVaultMemoryFact(
        'vault-A',
        VaultMemoryFact(id: 'temp2', text: 'c', createdAt: DateTime.now(), scope: MemoryFactScope.temporary),
      );

      await settings.clearTemporaryVaultMemoryFacts('vault-A');

      final facts = await settings.getVaultMemoryFacts('vault-A');
      expect(facts.map((f) => f.id), ['perm1']);
    });
  });

  group('Migración best-effort desde la clave legacy global', () {
    Future<void> writeLegacyGlobalFacts(List<VaultMemoryFact> facts) async {
      final p = await SharedPreferences.getInstance();
      await p.setString(
        'folio_vault_memory_facts_json',
        jsonEncode(facts.map((f) => f.toJson()).toList()),
      );
    }

    test('la primera libreta que consulta memoria adopta los hechos legacy, y la clave legacy se borra', () async {
      await writeLegacyGlobalFacts([
        VaultMemoryFact(id: 'legacy1', text: 'hecho antiguo', createdAt: DateTime.now(), scope: MemoryFactScope.permanent),
      ]);

      final settings = AppSettings();
      await settings.load();

      final factsA = await settings.getVaultMemoryFacts('vault-A');
      expect(factsA.map((f) => f.id), ['legacy1']);

      final p = await SharedPreferences.getInstance();
      expect(
        p.getString('folio_vault_memory_facts_json'),
        isNull,
        reason: 'la clave legacy debe borrarse de inmediato tras la migración',
      );
    });

    test(
      'tras migrar a vault-A, una lectura posterior de vault-B sigue devolviendo vacío '
      '(repetida varias veces, no solo la primera)',
      () async {
        await writeLegacyGlobalFacts([
          VaultMemoryFact(id: 'legacy1', text: 'hecho antiguo', createdAt: DateTime.now(), scope: MemoryFactScope.permanent),
        ]);

        final settings = AppSettings();
        await settings.load();

        await settings.getVaultMemoryFacts('vault-A'); // dispara la migración a vault-A

        expect(await settings.getVaultMemoryFacts('vault-B'), isEmpty);
        expect(await settings.getVaultMemoryFacts('vault-B'), isEmpty);
        expect(await settings.getVaultMemoryFacts('vault-B'), isEmpty);
      },
    );

    test(
      'una escritura posterior en vault-B no reactiva ni reutiliza los hechos ya migrados a vault-A',
      () async {
        await writeLegacyGlobalFacts([
          VaultMemoryFact(id: 'legacy1', text: 'hecho antiguo', createdAt: DateTime.now(), scope: MemoryFactScope.permanent),
        ]);

        final settings = AppSettings();
        await settings.load();
        await settings.getVaultMemoryFacts('vault-A'); // migra a vault-A y borra la clave legacy

        await settings.addVaultMemoryFact(
          'vault-B',
          VaultMemoryFact(id: 'nuevoB', text: 'hecho propio de B', createdAt: DateTime.now(), scope: MemoryFactScope.permanent),
        );

        final factsB = await settings.getVaultMemoryFacts('vault-B');
        expect(factsB.map((f) => f.id), ['nuevoB']);

        // vault-A conserva los suyos, sin interferencia de la escritura en B.
        final factsA = await settings.getVaultMemoryFacts('vault-A');
        expect(factsA.map((f) => f.id), ['legacy1']);
      },
    );

    test('sin datos legacy, una libreta nueva simplemente empieza vacía', () async {
      final settings = AppSettings();
      await settings.load();
      expect(await settings.getVaultMemoryFacts('vault-nueva'), isEmpty);
    });
  });
}
