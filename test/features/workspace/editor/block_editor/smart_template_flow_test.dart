import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:folio/app/app_settings.dart';
import 'package:folio/features/workspace/editor/block_editor.dart';
import 'package:folio/features/workspace/editor/smart_templates/smart_template_definitions.dart';
import 'package:folio/features/workspace/editor/smart_templates/smart_template_flow_overlay.dart';
import 'package:folio/l10n/generated/app_localizations.dart';
import 'package:folio/session/vault_session.dart';

/// Fase G2 del rediseño UX del editor — mini-flujo de variables antes de
/// generar una smart template multi-bloque, y el caso sin variables
/// (`/roadmap`) que inserta directamente sin overlay. Mismo harness que
/// `ai_selection_popover_test.dart` (Fase D1): se invoca el método público
/// `showSmartTemplateFlow` directamente en vez de tipear `/meeting` en el
/// editor real, para aislar el mecanismo del flujo del catálogo de slash
/// (ya cubierto en `block_type_catalog_slash_registry_test.dart`).
Future<BlockEditorState> _pumpEditor(WidgetTester tester, VaultSession session) async {
  tester.view.physicalSize = const Size(1400, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: BlockEditor(
          session: session,
          appSettings: AppSettings(),
          onAiSlashCommand: (_) async {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return tester.state<BlockEditorState>(find.byType(BlockEditor));
}

void main() {
  testWidgets(
    '/roadmap (sin variables) inserta los bloques directamente, sin overlay',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final session = VaultSession();
      session.addPage();
      final pageId = session.selectedPageId!;
      final blockId = session.selectedPage!.blocks.first.id;

      final state = await _pumpEditor(tester, session);
      state.showSmartTemplateFlow(
        template: kSmartTemplateRoadmap,
        pageId: pageId,
        blockId: blockId,
      );
      await tester.pump();

      expect(state.isSmartTemplateFlowOpen, isFalse);
      expect(find.byType(SmartTemplateFlowOverlay), findsNothing);
      // El último bloque de la plantilla es un `bullet` vacío, así que
      // `_ensureTrailingSentinel` añade un `paragraph` vacío extra al final
      // para que el usuario pueda seguir escribiendo — comportamiento
      // establecido del editor, no de esta plantilla.
      final blocks = session.selectedPage!.blocks;
      expect(blocks.map((b) => b.type), [
        'h1',
        'h2',
        'bullet',
        'h2',
        'bullet',
        'h2',
        'bullet',
        'paragraph',
      ]);
      expect(blocks.any((b) => b.id == blockId), isFalse);
    },
  );

  testWidgets(
    '/meeting abre el mini-flujo y, tras responder ambas preguntas, genera '
    'los bloques interpolados y elimina el bloque disparador',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final session = VaultSession();
      session.addPage();
      final pageId = session.selectedPageId!;
      final blockId = session.selectedPage!.blocks.first.id;

      final state = await _pumpEditor(tester, session);
      state.showSmartTemplateFlow(
        template: kSmartTemplateMeeting,
        pageId: pageId,
        blockId: blockId,
      );
      await tester.pump();

      expect(state.isSmartTemplateFlowOpen, isTrue);
      expect(find.byType(SmartTemplateFlowOverlay), findsOneWidget);

      final l10n = AppLocalizations.of(tester.element(find.byType(BlockEditor)));

      await tester.enterText(find.byType(TextField), 'Ana');
      await tester.tap(find.text(l10n.smartTemplateFlowNext));
      await tester.pump();

      await tester.enterText(find.byType(TextField), '2026-08-10');
      await tester.tap(find.text(l10n.smartTemplateFlowGenerate));
      await tester.pumpAndSettle();

      expect(state.isSmartTemplateFlowOpen, isFalse);
      // Igual que en el caso de /roadmap: el último bloque de la plantilla
      // (`todo` vacío) no es un `paragraph`, así que `_ensureTrailingSentinel`
      // añade uno extra al final.
      final blocks = session.selectedPage!.blocks;
      expect(blocks.map((b) => b.type), [
        'h1',
        'callout',
        'meeting_note',
        'toggle',
        'h2',
        'todo',
        'paragraph',
      ]);
      expect(blocks.first.text, l10n.smartTemplateMeetingTitleWith('Ana'));
      expect(blocks[1].text, l10n.smartTemplateMeetingDateLine('2026-08-10'));
      expect(blocks.any((b) => b.id == blockId), isFalse);
    },
  );

  testWidgets('Escape cancela el mini-flujo sin insertar bloques', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final session = VaultSession();
    session.addPage();
    final pageId = session.selectedPageId!;
    final blockId = session.selectedPage!.blocks.first.id;
    final originalBlockCount = session.selectedPage!.blocks.length;

    final state = await _pumpEditor(tester, session);
    state.showSmartTemplateFlow(
      template: kSmartTemplateMeeting,
      pageId: pageId,
      blockId: blockId,
    );
    await tester.pump();
    expect(state.isSmartTemplateFlowOpen, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    expect(state.isSmartTemplateFlowOpen, isFalse);
    expect(session.selectedPage!.blocks.length, originalBlockCount);
    expect(session.selectedPage!.blocks.any((b) => b.id == blockId), isTrue);
  });

  testWidgets(
    '/sprint (una sola variable) muestra "Generar" ya en el primer paso',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final session = VaultSession();
      session.addPage();
      final pageId = session.selectedPageId!;
      final blockId = session.selectedPage!.blocks.first.id;

      final state = await _pumpEditor(tester, session);
      state.showSmartTemplateFlow(
        template: kSmartTemplateSprint,
        pageId: pageId,
        blockId: blockId,
      );
      await tester.pump();

      final l10n = AppLocalizations.of(tester.element(find.byType(BlockEditor)));
      expect(find.text(l10n.smartTemplateFlowGenerate), findsOneWidget);
      expect(find.text(l10n.smartTemplateFlowNext), findsNothing);

      await tester.enterText(find.byType(TextField), 'Sprint 42');
      await tester.tap(find.text(l10n.smartTemplateFlowGenerate));
      await tester.pumpAndSettle();

      final blocks = session.selectedPage!.blocks;
      expect(blocks.first.text, l10n.smartTemplateSprintTitleWithName('Sprint 42'));
    },
  );
}
