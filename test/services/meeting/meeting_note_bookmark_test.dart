/// Fase 4 de la evolución de `meeting_note` — bookmarks.
///
/// Cubre: el modelo `MeetingNoteBookmark` (round-trip JSON), los mutators
/// `addBlockMeetingNoteBookmark`/`removeBlockMeetingNoteBookmark` de
/// `VaultSession`, y la tool MCP `meeting_create_bookmark` de
/// `FolioToolRegistry` — la vía por la que el auto-trigger (Fase 11, más
/// adelante) podrá marcar momentos sin pasar por la UI.
import 'package:flutter_test/flutter_test.dart';
import 'package:folio/models/block.dart';
import 'package:folio/models/meeting_note_bookmark.dart';
import 'package:folio/services/ai/ai_tool.dart';
import 'package:folio/services/ai/folio_tool_registry.dart';
import 'package:folio/session/vault_session.dart';

void main() {
  group('MeetingNoteBookmark — modelo', () {
    test('round-trip JSON conserva todos los campos', () {
      final bookmark = MeetingNoteBookmark(
        id: 'bm1',
        timestampMs: 12345,
        type: MeetingNoteBookmarkType.decision,
        label: 'Usar S3 para adjuntos',
        createdAtMs: 1000,
      );
      final roundTripped = MeetingNoteBookmark.fromJson(bookmark.toJson());
      expect(roundTripped.id, 'bm1');
      expect(roundTripped.timestampMs, 12345);
      expect(roundTripped.type, MeetingNoteBookmarkType.decision);
      expect(roundTripped.label, 'Usar S3 para adjuntos');
      expect(roundTripped.createdAtMs, 1000);
    });

    test('tipo desconocido/ausente cae a "important"', () {
      final bookmark = MeetingNoteBookmark.fromJson({
        'id': 'bm2',
        'timestampMs': 0,
      });
      expect(bookmark.type, MeetingNoteBookmarkType.important);
    });

    test('listToJson devuelve null para lista vacía o null (no infla el bloque)', () {
      expect(MeetingNoteBookmark.listToJson(null), isNull);
      expect(MeetingNoteBookmark.listToJson(const []), isNull);
    });
  });

  group('VaultSession — mutators de bookmarks', () {
    late VaultSession session;
    late String pageId;
    late String blockId;

    setUp(() {
      session = VaultSession();
      session.addPage();
      final page = session.selectedPage!;
      pageId = page.id;
      blockId = page.blocks.first.id;
      session.changeBlockType(pageId, blockId, 'meeting_note');
    });

    test('addBlockMeetingNoteBookmark añade y persiste en el bloque', () {
      session.addBlockMeetingNoteBookmark(
        pageId,
        blockId,
        MeetingNoteBookmark(
          id: 'bm1',
          timestampMs: 5000,
          type: MeetingNoteBookmarkType.question,
        ),
      );
      final block = session.selectedPage!.blocks.first;
      expect(block.meetingNoteBookmarks, hasLength(1));
      expect(block.meetingNoteBookmarks!.first.id, 'bm1');

      // Sobrevive a un round-trip JSON completo del bloque.
      final roundTripped = FolioBlock.fromJson(block.toJson());
      expect(roundTripped.meetingNoteBookmarks, hasLength(1));
      expect(
        roundTripped.meetingNoteBookmarks!.first.type,
        MeetingNoteBookmarkType.question,
      );
    });

    test('removeBlockMeetingNoteBookmark elimina solo el bookmark indicado', () {
      session.addBlockMeetingNoteBookmark(
        pageId,
        blockId,
        MeetingNoteBookmark(
          id: 'bm1',
          timestampMs: 0,
          type: MeetingNoteBookmarkType.note,
        ),
      );
      session.addBlockMeetingNoteBookmark(
        pageId,
        blockId,
        MeetingNoteBookmark(
          id: 'bm2',
          timestampMs: 1000,
          type: MeetingNoteBookmarkType.note,
        ),
      );

      session.removeBlockMeetingNoteBookmark(pageId, blockId, 'bm1');

      final bookmarks = session.selectedPage!.blocks.first.meetingNoteBookmarks;
      expect(bookmarks, hasLength(1));
      expect(bookmarks!.first.id, 'bm2');
    });

    test('removeBlockMeetingNoteBookmark con id inexistente no lanza y no cambia nada', () {
      session.addBlockMeetingNoteBookmark(
        pageId,
        blockId,
        MeetingNoteBookmark(
          id: 'bm1',
          timestampMs: 0,
          type: MeetingNoteBookmarkType.note,
        ),
      );
      session.removeBlockMeetingNoteBookmark(pageId, blockId, 'no-existe');
      expect(session.selectedPage!.blocks.first.meetingNoteBookmarks, hasLength(1));
    });
  });

  group('FolioToolRegistry — meeting_create_bookmark', () {
    late VaultSession session;
    late FolioToolRegistry registry;
    late String pageId;
    late String blockId;

    setUp(() {
      session = VaultSession();
      session.addPage();
      final page = session.selectedPage!;
      pageId = page.id;
      blockId = page.blocks.first.id;
      session.changeBlockType(pageId, blockId, 'meeting_note');
      registry = FolioToolRegistry(session, scopePageId: pageId);
    });

    test('está presente en las definiciones', () {
      expect(registry.definitionByName('meeting_create_bookmark'), isNotNull);
    });

    test('crea un bookmark en el bloque y devuelve su id', () async {
      final result = await registry.execute(
        AiToolCall(
          id: 'call1',
          name: 'meeting_create_bookmark',
          arguments: {
            'pageId': pageId,
            'blockId': blockId,
            'timestampMs': 42000,
            'type': 'actionItem',
            'label': 'Asignar owner de deployment',
          },
        ),
      );
      expect(result.isError, isFalse);
      expect(result.content, contains(pageId));

      final bookmarks = session.selectedPage!.blocks.first.meetingNoteBookmarks;
      expect(bookmarks, hasLength(1));
      expect(bookmarks!.first.timestampMs, 42000);
      expect(bookmarks.first.type, MeetingNoteBookmarkType.actionItem);
      expect(bookmarks.first.label, 'Asignar owner de deployment');
    });

    test('devuelve error si el bloque no es meeting_note', () async {
      session.changeBlockType(pageId, blockId, 'paragraph');
      final result = await registry.execute(
        AiToolCall(
          id: 'call2',
          name: 'meeting_create_bookmark',
          arguments: {
            'pageId': pageId,
            'blockId': blockId,
            'timestampMs': 0,
          },
        ),
      );
      expect(result.isError, isTrue);
    });

    test('devuelve error si la página no existe', () async {
      final result = await registry.execute(
        AiToolCall(
          id: 'call3',
          name: 'meeting_create_bookmark',
          arguments: {
            'pageId': 'no-existe',
            'blockId': blockId,
            'timestampMs': 0,
          },
        ),
      );
      expect(result.isError, isTrue);
    });
  });
}
