import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:folio/app/app_settings.dart';
import 'package:folio/features/workspace/editor/block_editor.dart';
import 'package:folio/features/workspace/editor/block_editor_support_widgets.dart';
import 'package:folio/l10n/generated/app_localizations.dart';
import 'package:folio/models/block.dart';
import 'package:folio/session/vault_session.dart';

/// Fase F2 del rediseño UX del editor — microinteracciones + feedback
/// visual: fade+slide-in al crear un bloque, crossfade al convertir su
/// tipo, y "lift" (elevación creciente) al arrastrar para reordenar.
/// Estos tests afirman estado inicial/final tras `pumpAndSettle()`, no
/// curvas frame-a-frame (frágil, ver guía de la Fase F2 del plan).
Future<BlockEditorState> _pumpEditor(WidgetTester tester, VaultSession session) async {
  tester.view.physicalSize = const Size(1400, 1200);
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
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'un bloque recién creado hace fade-in y termina en opacidad completa '
    'tras pumpAndSettle, sin excepciones a mitad de la animación',
    (tester) async {
      final session = VaultSession();
      session.addPage();
      final pageId = session.selectedPageId!;
      final firstId = session.selectedPage!.blocks.first.id;

      await _pumpEditor(tester, session);

      // Inserta un segundo bloque real (no el sentinela inicial) — la fila
      // que lo renderiza es una `_BlockListRow` nueva (Key por block.id),
      // así que dispara la animación de entrada.
      session.insertBlockAfter(
        pageId: pageId,
        afterBlockId: firstId,
        block: FolioBlockForTest(),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);

      // `pumpAndSettle` solo termina si todas las animaciones activas
      // llegan a reposo — la controller de entrada dura 180ms (finita), así
      // que si esto no lanza (ni hace timeout) la animación de fade-in de
      // la fila nueva ya se completó.
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(FadeTransition), findsWidgets);
    },
  );

  testWidgets(
    'convertir el tipo de un bloque no lanza excepciones (crossfade vía '
    'AnimatedSwitcher en vez de un salto instantáneo)',
    (tester) async {
      final session = VaultSession();
      session.addPage();
      final pageId = session.selectedPageId!;
      final blockId = session.selectedPage!.blocks.first.id;
      session.updateBlockText(pageId, blockId, 'hola');

      await _pumpEditor(tester, session);

      session.changeBlockType(pageId, blockId, 'h1');
      await tester.pump();
      expect(tester.takeException(), isNull);

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(AnimatedSwitcher), findsWidgets);
    },
  );

  testWidgets(
    'arrastrar el manejador de un bloque para reordenar no lanza '
    'excepciones (ejercita el proxyDecorator de "lift")',
    (tester) async {
      final session = VaultSession();
      session.addPage();
      final pageId = session.selectedPageId!;
      final firstId = session.selectedPage!.blocks.first.id;
      session.updateBlockText(pageId, firstId, 'primero');
      session.insertBlockAfter(
        pageId: pageId,
        afterBlockId: firstId,
        block: FolioBlockForTest(text: 'segundo'),
      );

      final state = await _pumpEditor(tester, session);
      // El manejador de arrastre solo es interactivo cuando `showActions`
      // es verdadero (hover/foco/selección) — se selecciona el primer
      // bloque para revelarlo, igual que ya hace el usuario al pasar el
      // ratón por encima.
      state.debugSelectBlocksForTest({firstId});
      await tester.pump();

      final handle = find.byType(BlockEditorDragHandle).first;
      expect(handle, findsOneWidget);

      final gesture = await tester.startGesture(tester.getCenter(handle));
      await tester.pump(const Duration(milliseconds: 50));
      await gesture.moveBy(const Offset(0, 80));
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}

/// Bloque de párrafo mínimo para pruebas — evita repetir el constructor
/// completo de `FolioBlock` en cada test de este archivo.
// ignore: non_constant_identifier_names
FolioBlock FolioBlockForTest({String text = ''}) =>
    FolioBlock(id: 'test_block_${text.hashCode}_${text.length}', type: 'paragraph', text: text);
