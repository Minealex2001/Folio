import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:folio/app/app_settings.dart';
import 'package:folio/features/workspace/editor/block_editor.dart';
import 'package:folio/l10n/generated/app_localizations.dart';
import 'package:folio/session/vault_session.dart';

/// Fase F1 del rediseño UX del editor — identidad visual de bloques
/// especiales (code/mermaid/database/meeting_note). Smoke test: cada tipo
/// debe renderizar sin excepciones con su acento aplicado (antes de esta
/// fase, `meeting_note` habría lanzado la excepción de Flutter
/// "borderRadius can only be given on borders with uniform colors" si el
/// acento se hubiese implementado con colores no uniformes por lado — este
/// test es justamente la regresión que habría cogido ese error).
Future<void> _pumpEditorWithBlockType(
  WidgetTester tester,
  VaultSession session,
  String blockType,
) async {
  session.addPage();
  final pageId = session.selectedPageId!;
  final blockId = session.selectedPage!.blocks.first.id;
  session.changeBlockType(pageId, blockId, blockType);

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
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('bloque code renderiza con su franja de acento sin excepciones', (
    tester,
  ) async {
    final session = VaultSession();
    await _pumpEditorWithBlockType(tester, session, 'code');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'bloque mermaid muestra la cabecera de acento (icono + etiqueta) en vez '
    'del texto plano suelto de antes de esta fase',
    (tester) async {
      final session = VaultSession();
      await _pumpEditorWithBlockType(tester, session, 'mermaid');
      expect(tester.takeException(), isNull);
      expect(find.text('Mermaid'), findsOneWidget);
      expect(find.byIcon(Icons.schema_outlined), findsOneWidget);
    },
  );

  testWidgets('bloque database renderiza con su franja de acento sin excepciones', (
    tester,
  ) async {
    final session = VaultSession();
    await _pumpEditorWithBlockType(tester, session, 'database');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'bloque meeting_note (vacío, sin foco — la rama que reportó la '
    'excepción del borderRadius no uniforme) renderiza sin excepciones',
    (tester) async {
      final session = VaultSession();
      await _pumpEditorWithBlockType(tester, session, 'meeting_note');
      expect(tester.takeException(), isNull);
    },
  );
}
