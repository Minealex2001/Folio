import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:folio/features/settings/capability_explorer_page.dart';
import 'package:folio/l10n/generated/app_localizations.dart';
import 'package:folio/session/vault_session.dart';

/// Fase B4 del plan Quill/MCP — el Capability Explorer es interactivo (tipo
/// Swagger): lista de tools agrupadas por categoría, formulario de
/// parámetros, Preview/Execute/Exportar. Este test cubre el flujo mínimo:
/// las tools aparecen, tocar una la expande con sus parámetros, y
/// Preview/Execute funcionan sin necesitar credenciales de un cliente MCP
/// real (se ejecuta sobre el `FolioToolRegistry` real de la app).
///
/// Cada test filtra por búsqueda antes de tocar una tool: el catálogo tiene
/// ~27 entradas y `ListView` no construye las que están fuera de pantalla,
/// así que buscar por nombre es lo que garantiza que el `ExpansionTile`
/// exista en el árbol sin depender de scroll manual.
Future<void> _pumpExplorer(WidgetTester tester, VaultSession session) async {
  tester.view.physicalSize = const Size(1200, 2000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: CapabilityExplorerPage(session: session),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _searchAndExpand(WidgetTester tester, String toolName) async {
  await tester.enterText(find.byType(TextField).first, toolName);
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(ExpansionTile, toolName));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('la búsqueda encuentra tools de distintas categorías', (tester) async {
    final session = VaultSession();
    await _pumpExplorer(tester, session);

    await tester.enterText(find.byType(TextField).first, 'create_page');
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ExpansionTile, 'create_page'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'permanently_delete_page');
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ExpansionTile, 'permanently_delete_page'), findsOneWidget);
  });

  testWidgets(
    'filtrar por búsqueda reduce la lista a las tools que coinciden',
    (tester) async {
      final session = VaultSession();
      await _pumpExplorer(tester, session);

      await tester.enterText(find.byType(TextField).first, 'search_pages');
      await tester.pumpAndSettle();

      expect(find.widgetWithText(ExpansionTile, 'search_pages'), findsOneWidget);
      expect(find.widgetWithText(ExpansionTile, 'create_page'), findsNothing);
    },
  );

  testWidgets(
    'Preview de permanently_delete_page muestra el resumen sin ejecutar',
    (tester) async {
      final session = VaultSession();
      session.addPage(parentId: null);
      session.addPage(parentId: null);
      final pageId = session.pages.last.id;
      session.movePageToTrash(pageId);

      await _pumpExplorer(tester, session);
      await _searchAndExpand(tester, 'permanently_delete_page');

      final pageIdField = find.widgetWithText(TextField, 'pageId *');
      expect(pageIdField, findsOneWidget);
      await tester.enterText(pageIdField, pageId);
      await tester.pumpAndSettle();

      final l10n = AppLocalizations.of(tester.element(find.byType(CapabilityExplorerPage)));
      await tester.tap(find.text(l10n.capabilityExplorerPreview));
      await tester.pumpAndSettle();

      expect(find.text(l10n.capabilityExplorerPreviewResultTitle), findsOneWidget);
      expect(session.pages.any((p) => p.id == pageId), isTrue);
    },
  );

  testWidgets(
    'Execute de una tool no destructiva muta el vault sin diálogo de confirmación',
    (tester) async {
      final session = VaultSession();
      await _pumpExplorer(tester, session);
      await _searchAndExpand(tester, 'create_folder');

      final titleField = find.widgetWithText(TextField, 'title *');
      await tester.enterText(titleField, 'Carpeta de prueba');
      await tester.pumpAndSettle();

      final l10n = AppLocalizations.of(tester.element(find.byType(CapabilityExplorerPage)));
      await tester.ensureVisible(find.text(l10n.capabilityExplorerExecute));
      await tester.tap(find.text(l10n.capabilityExplorerExecute));
      await tester.pumpAndSettle();

      expect(
        session.pages.any((p) => p.isFolder && p.title == 'Carpeta de prueba'),
        isTrue,
      );
      expect(find.textContaining('"title"'), findsWidgets);
    },
  );

  testWidgets(
    'Execute de una tool destructiva pide confirmación antes de mutar',
    (tester) async {
      final session = VaultSession();
      session.addPage(parentId: null);
      session.addPage(parentId: null);
      final pageId = session.pages.last.id;
      session.movePageToTrash(pageId);

      await _pumpExplorer(tester, session);
      await _searchAndExpand(tester, 'permanently_delete_page');

      final pageIdField = find.widgetWithText(TextField, 'pageId *');
      await tester.enterText(pageIdField, pageId);
      await tester.pumpAndSettle();

      // `pumpAndSettle` no sirve desde aquí: en cuanto se toca "Ejecutar",
      // `_busy` pasa a `true` y el botón muestra un `CircularProgressIndicator`
      // indeterminado (nunca "se asienta") mientras se espera la confirmación
      // del diálogo — se usa `pump()` acotado en su lugar.
      final l10n = AppLocalizations.of(tester.element(find.byType(CapabilityExplorerPage)));
      await tester.ensureVisible(find.text(l10n.capabilityExplorerExecute));
      await tester.tap(find.text(l10n.capabilityExplorerExecute));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text(l10n.capabilityExplorerConfirmTitle), findsOneWidget);
      expect(session.pages.any((p) => p.id == pageId), isTrue);

      // `pumpAndSettle` puede colgarse aquí: el botón "Ejecutar" muestra un
      // `CircularProgressIndicator` indeterminado mientras `_busy` es `true`,
      // cuya animación no se "asienta" nunca por diseño — se usa `pump()`
      // acotado en su lugar.
      await tester.tap(find.text(l10n.capabilityExplorerExecute).last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(session.pages.any((p) => p.id == pageId), isFalse);
    },
  );
}
