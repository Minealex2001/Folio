/// Fase 2 de la evolución de `meeting_note` — live transcript UX.
///
/// Cubre dos mejoras concretas de esta fase, ambas en la preview colapsada
/// de `block_row_dispatch_meeting_note.dart` y en el transcript coloreado
/// por speaker de `meeting_note_block_widget.dart`:
/// 1) La preview colapsada muestra un indicador "grabando…" en vivo solo
///    cuando `MeetingNoteSessionController` está grabando ESE bloque
///    concreto (no otro), y desaparece si no lo está.
/// 2) El transcript expandido con líneas `Speaker N: ...` se colorea por
///    speaker sin lanzar excepciones; texto sin ese formato sigue
///    renderizando en texto plano.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:folio/app/app_settings.dart';
import 'package:folio/features/workspace/editor/block_editor.dart';
import 'package:folio/features/workspace/editor/meeting_note_block_widget.dart';
import 'package:folio/l10n/generated/app_localizations.dart';
import 'package:folio/models/block.dart';
import 'package:folio/services/meeting_note_session_controller.dart';
import 'package:folio/session/vault_session.dart';

Future<(String pageId, String blockId)> _pumpMeetingNoteEditor(
  WidgetTester tester,
  VaultSession session, {
  String transcriptText = '',
}) async {
  session.addPage();
  final pageId = session.selectedPageId!;
  final blockId = session.selectedPage!.blocks.first.id;
  session.changeBlockType(pageId, blockId, 'meeting_note');
  if (transcriptText.isNotEmpty) {
    session.updateBlockText(pageId, blockId, transcriptText);
  }

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
  return (pageId, blockId);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    MeetingNoteSessionController.instance.debugResetForTest();
  });

  tearDown(() {
    MeetingNoteSessionController.instance.debugResetForTest();
  });

  testWidgets(
    'preview colapsada NO muestra indicador de grabación cuando no hay sesión activa',
    (tester) async {
      final session = VaultSession();
      await _pumpMeetingNoteEditor(
        tester,
        session,
        transcriptText: 'Speaker 1: hola',
      );
      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.circle), findsNothing);
    },
  );

  testWidgets(
    'preview colapsada muestra "grabando…" cuando MeetingNoteSessionController '
    'está grabando ESE bloque',
    (tester) async {
      final session = VaultSession();
      final (pageId, blockId) = await _pumpMeetingNoteEditor(
        tester,
        session,
        transcriptText: 'Speaker 1: hola',
      );

      MeetingNoteSessionController.instance.debugForceRecordingStateForTest(
        pageId: pageId,
        blockId: blockId,
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      final l10n = AppLocalizations.of(tester.element(find.byType(BlockEditor)));
      expect(find.text(l10n.meetingNoteRecordingLiveBadge), findsOneWidget);
    },
  );

  testWidgets(
    'preview colapsada NO muestra el indicador si la sesión activa es de OTRO bloque',
    (tester) async {
      final session = VaultSession();
      final (pageId, blockId) = await _pumpMeetingNoteEditor(
        tester,
        session,
        transcriptText: 'Speaker 1: hola',
      );

      MeetingNoteSessionController.instance.debugForceRecordingStateForTest(
        pageId: pageId,
        blockId: 'otro-bloque-distinto',
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      final l10n = AppLocalizations.of(tester.element(find.byType(BlockEditor)));
      expect(find.text(l10n.meetingNoteRecordingLiveBadge), findsNothing);
    },
  );

  testWidgets(
    'MeetingNoteBlockWidget: transcript con líneas "Speaker N:" renderiza '
    'coloreado sin excepciones (estado completed)',
    (tester) async {
      final session = VaultSession();
      session.addPage();
      final page = session.selectedPage!;
      final block = FolioBlock(
        id: 'mn1',
        type: 'meeting_note',
        text: 'Speaker 1: hola a todos\nSpeaker 2: buenas',
      );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => MeetingNoteBlockWidget(
                block: block,
                page: page,
                session: session,
                appSettings: AppSettings(),
                scheme: Theme.of(context).colorScheme,
                resolvedFile: null,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // El transcript se renderiza vía SelectableText.rich (coloreado por
      // speaker); el texto plano sigue siendo localizable en el árbol.
      expect(find.textContaining('hola a todos'), findsOneWidget);
      final richTextFinder = find.byWidgetPredicate(
        (w) =>
            w is SelectableText &&
            w.textSpan?.toPlainText().contains('hola a todos') == true,
      );
      expect(richTextFinder, findsOneWidget);
    },
  );
}
