/// Fase 18 de la evolución de `meeting_note` — historial de reuniones.
/// Sin base de datos nueva: la pantalla recorre `session.pages` filtrando
/// por bloques `meeting_note`, reutilizando el mismo dato que el resto de
/// Folio (grafo, árbol de páginas).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:folio/features/workspace/history/meeting_notes_history_screen.dart';
import 'package:folio/l10n/generated/app_localizations.dart';
import 'package:folio/session/vault_session.dart';

Future<void> _pump(
  WidgetTester tester,
  VaultSession session, {
  required void Function(String) onOpenPage,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MeetingNotesHistoryScreen(session: session, onOpenPage: onOpenPage),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('sin páginas con meeting_note, muestra el estado vacío', (
    tester,
  ) async {
    final session = VaultSession();
    session.addPage(); // página normal, sin meeting_note

    await _pump(tester, session, onOpenPage: (_) {});

    final l10n = AppLocalizations.of(
      tester.element(find.byType(MeetingNotesHistoryScreen)),
    );
    expect(find.text(l10n.meetingNotesHistoryEmpty), findsOneWidget);
  });

  testWidgets(
    'lista páginas con al menos un bloque meeting_note, no las que no tienen',
    (tester) async {
      final session = VaultSession();

      session.addPage();
      final normalPageId = session.selectedPageId!;
      session.renamePage(normalPageId, 'Página normal');

      session.addPage();
      final meetingPageId = session.selectedPageId!;
      session.renamePage(meetingPageId, 'Weekly sync');
      session.changeBlockType(
        meetingPageId,
        session.selectedPage!.blocks.first.id,
        'meeting_note',
      );
      session.updateBlockText(
        meetingPageId,
        session.selectedPage!.blocks.first.id,
        'Speaker 1: hablamos de la migración',
      );

      await _pump(tester, session, onOpenPage: (_) {});

      expect(find.text('Weekly sync'), findsOneWidget);
      expect(find.text('Página normal'), findsNothing);
      expect(find.textContaining('migración'), findsOneWidget);
    },
  );

  testWidgets('el buscador filtra por título', (tester) async {
    final session = VaultSession();

    session.addPage();
    final page1 = session.selectedPageId!;
    session.renamePage(page1, 'Weekly sync');
    session.changeBlockType(
      page1,
      session.selectedPage!.blocks.first.id,
      'meeting_note',
    );

    session.addPage();
    final page2 = session.selectedPageId!;
    session.renamePage(page2, 'Retro trimestral');
    session.changeBlockType(
      page2,
      session.selectedPage!.blocks.first.id,
      'meeting_note',
    );

    await _pump(tester, session, onOpenPage: (_) {});

    expect(find.text('Weekly sync'), findsOneWidget);
    expect(find.text('Retro trimestral'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'retro');
    await tester.pumpAndSettle();

    expect(find.text('Weekly sync'), findsNothing);
    expect(find.text('Retro trimestral'), findsOneWidget);
  });

  testWidgets('tocar una entrada llama a onOpenPage con el id correcto', (
    tester,
  ) async {
    final session = VaultSession();
    session.addPage();
    final pageId = session.selectedPageId!;
    session.renamePage(pageId, 'Weekly sync');
    session.changeBlockType(
      pageId,
      session.selectedPage!.blocks.first.id,
      'meeting_note',
    );

    String? openedPageId;
    await _pump(tester, session, onOpenPage: (id) => openedPageId = id);

    await tester.tap(find.text('Weekly sync'));
    await tester.pumpAndSettle();

    expect(openedPageId, pageId);
  });

  testWidgets('páginas en papelera no aparecen en el historial', (
    tester,
  ) async {
    final session = VaultSession();
    // movePageToTrash no permite vaciar el vault por completo — se necesita
    // al menos otra página activa para que la papelera sea posible.
    session.addPage();
    session.addPage();
    final pageId = session.selectedPageId!;
    session.renamePage(pageId, 'Reunión borrada');
    session.changeBlockType(
      pageId,
      session.selectedPage!.blocks.first.id,
      'meeting_note',
    );
    session.movePageToTrash(pageId);

    await _pump(tester, session, onOpenPage: (_) {});

    expect(find.text('Reunión borrada'), findsNothing);
  });
}
