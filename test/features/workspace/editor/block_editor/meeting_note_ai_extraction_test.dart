import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:folio/app/app_settings.dart';
import 'package:folio/app/ui_tokens.dart';
import 'package:folio/features/workspace/ai/ai_slash_intent.dart';
import 'package:folio/features/workspace/editor/block_editor.dart';
import 'package:folio/features/workspace/editor/command_palette/command_palette_overlay.dart';
import 'package:folio/l10n/generated/app_localizations.dart';
import 'package:folio/models/block.dart';
import 'package:folio/session/vault_session.dart';

/// Fase D3 del rediseño UX del editor — extracción de estructura de
/// reunión asistida por IA, deliberadamente NO automática/silenciosa
/// (violaría el "nunca invasivo" del brief): una acción explícita en la
/// cabecera del bloque `meeting_note` que abre el mismo popover de IA
/// anclado a selección de la Fase D1 — mismo pipeline, un disparador más.
Future<void> _pumpEditor(
  WidgetTester tester,
  VaultSession session, {
  Future<void> Function(FolioAiSlashParams)? onAiSlashCommand,
}) async {
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
          onAiSlashCommand: onAiSlashCommand,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'un bloque meeting_note con transcripción muestra el botón de IA en su '
    'cabecera',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final session = VaultSession();
      session.addPage();
      final pageId = session.selectedPageId!;
      final blockId = session.selectedPage!.blocks.first.id;
      session.changeBlockType(pageId, blockId, 'meeting_note');
      session.updateBlockText(pageId, blockId, 'Transcripción de la reunión');

      await _pumpEditor(tester, session, onAiSlashCommand: (_) async {});

      expect(find.byIcon(FolioIcons.quillOutlined), findsOneWidget);
    },
  );

  testWidgets(
    'sin onAiSlashCommand configurado, el botón no aparece (nunca un '
    'affordance que no puede hacer nada)',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final session = VaultSession();
      session.addPage();
      final pageId = session.selectedPageId!;
      final blockId = session.selectedPage!.blocks.first.id;
      session.changeBlockType(pageId, blockId, 'meeting_note');
      session.updateBlockText(pageId, blockId, 'Transcripción');

      await _pumpEditor(tester, session, onAiSlashCommand: null);

      expect(find.byIcon(FolioIcons.quillOutlined), findsNothing);
    },
  );

  testWidgets(
    'un meeting_note sin transcripción (aún vacío) no muestra el botón '
    '— nada que extraer todavía. Esto también reproduce el bug reportado '
    'aparte: sin foco, cae en la rama no compacta que renderiza '
    'MeetingNoteBlockWidget completo (un SwitchListTile dentro de un '
    'DecoratedBox con color) — ya no debe lanzar la excepción fatal de '
    '"ListTile background color or ink splashes may be invisible"',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final session = VaultSession();
      session.addPage();
      final pageId = session.selectedPageId!;
      final blockId = session.selectedPage!.blocks.first.id;
      session.changeBlockType(pageId, blockId, 'meeting_note');

      await _pumpEditor(tester, session, onAiSlashCommand: (_) async {});

      expect(tester.takeException(), isNull);
      expect(find.byIcon(FolioIcons.quillOutlined), findsNothing);
    },
  );

  testWidgets(
    'tocar el botón abre el mismo popover de IA (Fase D1), anclado a este '
    'bloque de reunión',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final session = VaultSession();
      session.addPage();
      final pageId = session.selectedPageId!;
      final blockId = session.selectedPage!.blocks.first.id;
      session.changeBlockType(pageId, blockId, 'meeting_note');
      session.updateBlockText(pageId, blockId, 'Transcripción de la reunión');

      await _pumpEditor(tester, session, onAiSlashCommand: (_) async {});
      final state = tester.state<BlockEditorState>(find.byType(BlockEditor));
      expect(state.isAiSelectionPopoverOpen, isFalse);

      await tester.tap(find.byIcon(FolioIcons.quillOutlined));
      await tester.pump();

      expect(state.isAiSelectionPopoverOpen, isTrue);
      expect(find.byType(CommandPaletteOverlay), findsOneWidget);
    },
  );
}
