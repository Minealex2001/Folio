import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:folio/app/app_settings.dart';
import 'package:folio/features/settings/vault_memory_facts_page.dart';
import 'package:folio/l10n/generated/app_localizations.dart';
import 'package:folio/models/vault_memory_fact.dart';

/// Fase A4 del plan Quill/MCP — pantalla de gestión de hechos, probada en
/// aislamiento (no vía `SettingsPage`, que hoy arrastra una dependencia
/// rota de otro trabajo en curso en el repo — ver `lib/legal/`).
Future<void> _pump(WidgetTester tester, AppSettings settings) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: VaultMemoryFactsPage(appSettings: settings),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('sin hechos muestra el estado vacío', (tester) async {
    final settings = AppSettings();
    await settings.load();
    await _pump(tester, settings);

    final l10n = AppLocalizations.of(tester.element(find.byType(VaultMemoryFactsPage)));
    expect(find.text(l10n.vaultMemoryFactsEmpty), findsOneWidget);
  });

  testWidgets('lista los hechos agrupados en temporal/permanente', (tester) async {
    final settings = AppSettings();
    await settings.load();
    await settings.addVaultMemoryFact(
      VaultMemoryFact(id: 't1', text: 'Sprint actual: v2', createdAt: DateTime.now(), scope: MemoryFactScope.temporary),
    );
    await settings.addVaultMemoryFact(
      VaultMemoryFact(id: 'p1', text: 'Usa Spring Boot', createdAt: DateTime.now(), scope: MemoryFactScope.permanent),
    );

    await _pump(tester, settings);

    expect(find.text('Sprint actual: v2'), findsOneWidget);
    expect(find.text('Usa Spring Boot'), findsOneWidget);
  });

  testWidgets('borrar un hecho lo quita de la lista', (tester) async {
    final settings = AppSettings();
    await settings.load();
    await settings.addVaultMemoryFact(
      VaultMemoryFact(id: 'p1', text: 'Usa Spring Boot', createdAt: DateTime.now(), scope: MemoryFactScope.permanent),
    );

    await _pump(tester, settings);
    await tester.tap(find.byIcon(Icons.delete_outline_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Usa Spring Boot'), findsNothing);
    expect(settings.vaultMemoryFacts, isEmpty);
  });

  testWidgets('"Vaciar temporales" borra solo los temporales', (tester) async {
    final settings = AppSettings();
    await settings.load();
    await settings.addVaultMemoryFact(
      VaultMemoryFact(id: 't1', text: 'Temporal', createdAt: DateTime.now(), scope: MemoryFactScope.temporary),
    );
    await settings.addVaultMemoryFact(
      VaultMemoryFact(id: 'p1', text: 'Permanente', createdAt: DateTime.now(), scope: MemoryFactScope.permanent),
    );

    await _pump(tester, settings);
    final l10n = AppLocalizations.of(tester.element(find.byType(VaultMemoryFactsPage)));
    await tester.tap(find.text(l10n.vaultMemoryFactsClearTemporary));
    await tester.pumpAndSettle();

    expect(find.text('Temporal'), findsNothing);
    expect(find.text('Permanente'), findsOneWidget);
  });
}
