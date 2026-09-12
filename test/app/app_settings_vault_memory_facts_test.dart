import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:folio/app/app_settings.dart';
import 'package:folio/models/vault_memory_fact.dart';

/// Fase A4 del plan Quill/MCP — hechos duraderos que Quill incluye
/// automáticamente como contexto, pero que solo el usuario puede escribir.
/// Persistencia por-dispositivo, reutilizando exactamente el mismo
/// mecanismo que ya usan los presets de `QuillSystemPrompt` en `AppSettings`.
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

  group('AppSettings.vaultMemoryFacts', () {
    test('empieza vacío', () async {
      final settings = AppSettings();
      await settings.load();
      expect(settings.vaultMemoryFacts, isEmpty);
    });

    test('addVaultMemoryFact añade y persiste', () async {
      final settings = AppSettings();
      await settings.load();
      await settings.addVaultMemoryFact(
        VaultMemoryFact(
          id: 'f1',
          text: 'Usa Maven',
          createdAt: DateTime.now(),
          scope: MemoryFactScope.permanent,
        ),
      );
      expect(settings.vaultMemoryFacts, hasLength(1));

      final reloaded = AppSettings();
      await reloaded.load();
      expect(reloaded.vaultMemoryFacts, hasLength(1));
      expect(reloaded.vaultMemoryFacts.single.text, 'Usa Maven');
    });

    test('deleteVaultMemoryFact borra solo el id indicado', () async {
      final settings = AppSettings();
      await settings.load();
      await settings.addVaultMemoryFact(
        VaultMemoryFact(id: 'f1', text: 'a', createdAt: DateTime.now(), scope: MemoryFactScope.permanent),
      );
      await settings.addVaultMemoryFact(
        VaultMemoryFact(id: 'f2', text: 'b', createdAt: DateTime.now(), scope: MemoryFactScope.temporary),
      );

      await settings.deleteVaultMemoryFact('f1');

      expect(settings.vaultMemoryFacts.map((f) => f.id), ['f2']);
    });

    test('clearTemporaryVaultMemoryFacts borra solo los temporales', () async {
      final settings = AppSettings();
      await settings.load();
      await settings.addVaultMemoryFact(
        VaultMemoryFact(id: 'temp1', text: 'a', createdAt: DateTime.now(), scope: MemoryFactScope.temporary),
      );
      await settings.addVaultMemoryFact(
        VaultMemoryFact(id: 'perm1', text: 'b', createdAt: DateTime.now(), scope: MemoryFactScope.permanent),
      );
      await settings.addVaultMemoryFact(
        VaultMemoryFact(id: 'temp2', text: 'c', createdAt: DateTime.now(), scope: MemoryFactScope.temporary),
      );

      await settings.clearTemporaryVaultMemoryFacts();

      expect(settings.vaultMemoryFacts.map((f) => f.id), ['perm1']);
    });
  });
}
