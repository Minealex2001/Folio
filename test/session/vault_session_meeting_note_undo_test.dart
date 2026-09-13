import 'package:flutter_test/flutter_test.dart';
import 'package:folio/models/meeting_note_bookmark.dart';
import 'package:folio/session/vault_session.dart';

/// Fase 3 de Quill 2.0 — auditoría de undo: `addBlockMeetingNoteBookmark`,
/// `updateBlockMeetingNotePrepNotes` y `updateBlockMeetingNoteSummary`
/// mutaban campos que SÍ están en el snapshot de undo (`_snapshotOfPage`)
/// pero nunca llamaban a `_rememberUndoBeforePageMutation` — a diferencia de
/// todo el resto de métodos de mutación de bloques. Efecto: las tools
/// `meeting_create_bookmark`/`meeting_generate_prep`/`meeting_generate_summary`
/// estaban marcadas `isReversible: true`, así que un turno que solo las usara
/// ofrecía el botón "Deshacer este turno", pero pulsarlo no revertía nada.
/// Estos tests fallaban antes del fix y pasan ahora que las 3 llamadas
/// existen.
void main() {
  VaultSession readySession() {
    final session = VaultSession();
    session.debugMarkUnlockedForTests();
    session.addPage(parentId: null);
    return session;
  }

  test('addBlockMeetingNoteBookmark es deshacible con undoPageEdits', () {
    final session = readySession();
    final page = session.pages.first;
    final blockId = page.blocks.first.id;

    session.addBlockMeetingNoteBookmark(
      page.id,
      blockId,
      MeetingNoteBookmark(
        id: 'bm1',
        timestampMs: 1000,
        type: MeetingNoteBookmarkType.important,
      ),
    );
    expect(
      session.pages.first.blocks.first.meetingNoteBookmarks,
      hasLength(1),
    );

    session.undoPageEdits(pageId: page.id);

    expect(
      session.pages.first.blocks.first.meetingNoteBookmarks ?? const [],
      isEmpty,
    );
  });

  test('updateBlockMeetingNotePrepNotes es deshacible con undoPageEdits', () {
    final session = readySession();
    final page = session.pages.first;
    final blockId = page.blocks.first.id;

    session.updateBlockMeetingNotePrepNotes(page.id, blockId, 'Notas de prep');
    expect(session.pages.first.blocks.first.meetingNotePrepNotes, 'Notas de prep');

    session.undoPageEdits(pageId: page.id);

    expect(session.pages.first.blocks.first.meetingNotePrepNotes, isNull);
  });

  test('updateBlockMeetingNoteSummary es deshacible con undoPageEdits', () {
    final session = readySession();
    final page = session.pages.first;
    final blockId = page.blocks.first.id;

    session.updateBlockMeetingNoteSummary(page.id, blockId, {'resumen': 'x'});
    expect(session.pages.first.blocks.first.meetingNoteSummary, isNotNull);

    session.undoPageEdits(pageId: page.id);

    expect(session.pages.first.blocks.first.meetingNoteSummary, isNull);
  });

  test(
    'un turno de IA que solo use meeting_create_bookmark ofrece deshacer real, no aparente',
    () {
      final session = readySession();
      final page = session.pages.first;
      final blockId = page.blocks.first.id;

      final turnId = session.beginAiTurnUndoGroup();
      session.addBlockMeetingNoteBookmark(
        page.id,
        blockId,
        MeetingNoteBookmark(
          id: 'bm1',
          timestampMs: 500,
          type: MeetingNoteBookmarkType.decision,
        ),
      );
      session.endAiTurnUndoGroup(turnId);

      expect(session.aiTurnHasUndoableChanges(turnId), isTrue);
      session.undoAiTurn(turnId);

      expect(
        session.pages.first.blocks.first.meetingNoteBookmarks ?? const [],
        isEmpty,
        reason: 'undoAiTurn debe revertir el bookmark, no solo aparentarlo',
      );
    },
  );
}
