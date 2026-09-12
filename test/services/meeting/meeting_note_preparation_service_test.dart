/// Fase 6 de la evolución de `meeting_note` — preparación de reunión.
///
/// `MeetingNotePreparationService` no implementa su propio proveedor de IA:
/// usa el `AiService` activo de `VaultSession` (mismo seam que
/// `vault_session_ai_tool_loop_test.dart`) y el grafo de páginas ya
/// existente. Este test verifica el contrato del servicio, no reimplementa
/// cobertura de `backlinkPagesFor`/`childrenOf`.
import 'package:flutter_test/flutter_test.dart';
import 'package:folio/models/block.dart';
import 'package:folio/services/ai/ai_service.dart';
import 'package:folio/services/ai/ai_tool.dart';
import 'package:folio/services/ai/ai_types.dart';
import 'package:folio/services/meeting_note_preparation_service.dart';
import 'package:folio/session/vault_session.dart';

class _ScriptedAiService implements AiService {
  _ScriptedAiService(this.result);

  final AiCompletionResult result;
  AiCompletionRequest? lastRequest;

  @override
  bool get supportsNativeToolCalling => true;

  @override
  String get providerName => 'scripted';

  @override
  Future<AiCompletionResult> complete(AiCompletionRequest request) async {
    lastRequest = request;
    return result;
  }

  @override
  Stream<AiCompletionChunk> completeStream(AiCompletionRequest request) async* {
    final r = await complete(request);
    yield AiCompletionChunk(textDelta: r.text, isFinal: true, toolCalls: r.toolCalls);
  }

  @override
  Future<void> ping() async {}

  @override
  Future<List<String>> listModels() async => const [];

  @override
  bool get supportsImageGeneration => false;

  @override
  Future<AiImageGenerationResult> generateImage({
    required String prompt,
    String? pageContextText,
  }) {
    throw AiImageGenerationUnsupportedException(providerName);
  }
}

VaultSession _readySession(AiService? ai) {
  final session = VaultSession();
  session.debugMarkUnlockedForTests();
  if (ai != null) session.setAiService(ai);
  return session;
}

void main() {
  group('MeetingNotePreparationService', () {
    test('sin AiService activo devuelve null y no persiste nada', () async {
      final session = _readySession(null);
      session.addPage();
      final pageId = session.selectedPageId!;
      final blockId = session.selectedPage!.blocks.first.id;
      session.changeBlockType(pageId, blockId, 'meeting_note');

      final result = await MeetingNotePreparationService.instance.generate(
        session: session,
        pageId: pageId,
        blockId: blockId,
      );

      expect(result, isNull);
      expect(
        session.selectedPage!.blocks.first.meetingNotePrepNotes,
        isNull,
      );
    });

    test('genera y persiste meetingNotePrepNotes con AiService activo', () async {
      final ai = _ScriptedAiService(
        const AiCompletionResult(
          text: '## Agenda sugerida\n- Revisar arquitectura\n',
        ),
      );
      final session = _readySession(ai);
      session.addPage();
      final pageId = session.selectedPageId!;
      session.renamePage(pageId, 'Weekly sync');
      final blockId = session.selectedPage!.blocks.first.id;
      session.changeBlockType(pageId, blockId, 'meeting_note');

      final result = await MeetingNotePreparationService.instance.generate(
        session: session,
        pageId: pageId,
        blockId: blockId,
      );

      expect(result, contains('Agenda sugerida'));
      expect(
        session.selectedPage!.blocks.first.meetingNotePrepNotes,
        contains('Agenda sugerida'),
      );
      expect(ai.lastRequest?.prompt, contains('Weekly sync'));
      expect(ai.lastRequest?.cloudInkOperation, 'meeting_note_prep');
    });

    test('respuesta vacía de la IA devuelve null y no persiste', () async {
      final ai = _ScriptedAiService(const AiCompletionResult(text: '   '));
      final session = _readySession(ai);
      session.addPage();
      final pageId = session.selectedPageId!;
      final blockId = session.selectedPage!.blocks.first.id;
      session.changeBlockType(pageId, blockId, 'meeting_note');

      final result = await MeetingNotePreparationService.instance.generate(
        session: session,
        pageId: pageId,
        blockId: blockId,
      );

      expect(result, isNull);
      expect(
        session.selectedPage!.blocks.first.meetingNotePrepNotes,
        isNull,
      );
    });

    test('página/bloque inexistentes devuelven null sin lanzar', () async {
      final ai = _ScriptedAiService(const AiCompletionResult(text: 'x'));
      final session = _readySession(ai);

      final result = await MeetingNotePreparationService.instance.generate(
        session: session,
        pageId: 'no-existe',
        blockId: 'no-existe',
      );

      expect(result, isNull);
    });

    test('incluye contexto (tags, hijos, relacionadas) en el prompt', () async {
      final ai = _ScriptedAiService(const AiCompletionResult(text: 'ok'));
      final session = _readySession(ai);

      session.addPage();
      final pageId = session.selectedPageId!;
      session.renamePage(pageId, 'Weekly sync');
      session.addPageTag(pageId, 'importante');
      final blockId = session.selectedPage!.blocks.first.id;
      session.changeBlockType(pageId, blockId, 'meeting_note');

      session.addPage(parentId: pageId);
      session.renamePage(session.selectedPageId!, 'Subpágina hija');

      await MeetingNotePreparationService.instance.generate(
        session: session,
        pageId: pageId,
        blockId: blockId,
      );

      expect(ai.lastRequest?.prompt, contains('importante'));
      expect(ai.lastRequest?.prompt, contains('Subpágina hija'));
    });

    test('incluye contenido de bloques existentes y participantes en el prompt', () async {
      final ai = _ScriptedAiService(const AiCompletionResult(text: 'ok'));
      final session = _readySession(ai);

      session.addPage();
      final pageId = session.selectedPageId!;
      final blockId = session.selectedPage!.blocks.first.id;
      session.changeBlockType(pageId, blockId, 'meeting_note');

      session.appendBlock(
        pageId: pageId,
        block: FolioBlock(
          id: 'p_sprint',
          type: 'paragraph',
          text: 'Objetivo crítico del sprint',
        ),
      );

      await MeetingNotePreparationService.instance.generate(
        session: session,
        pageId: pageId,
        blockId: blockId,
        type: MeetingNoteType.oneOnOne,
        participants: 'Carlos, Ana',
      );

      expect(ai.lastRequest?.prompt, contains('Objetivo crítico del sprint'));
      expect(ai.lastRequest?.prompt, contains('Carlos, Ana'));
      expect(ai.lastRequest?.prompt, contains('1 a 1'));
    });

    test('insertPrepAsBlocks convierte el markdown en bloques h2, bullet y paragraph en la página', () {
      final session = _readySession(null);
      session.addPage();
      final pageId = session.selectedPageId!;
      final blockId = session.selectedPage!.blocks.first.id;
      session.changeBlockType(pageId, blockId, 'meeting_note');

      session.updateBlockMeetingNotePrepNotes(
        pageId,
        blockId,
        '## Agenda sugerida\n- Punto uno\n- Punto dos\nPárrafo de cierre',
      );

      final count = MeetingNotePreparationService.instance.insertPrepAsBlocks(
        session: session,
        pageId: pageId,
        blockId: blockId,
      );

      expect(count, 4);
      final blocks = session.selectedPage!.blocks;
      expect(blocks.length, 5); // 1 meeting_note + 4 creados
      expect(blocks[1].type, 'h2');
      expect(blocks[1].text, 'Agenda sugerida');
      expect(blocks[2].type, 'bullet');
      expect(blocks[2].text, 'Punto uno');
      expect(blocks[3].type, 'bullet');
      expect(blocks[3].text, 'Punto dos');
      expect(blocks[4].type, 'paragraph');
      expect(blocks[4].text, 'Párrafo de cierre');
    });

    test('suggestChecklistItems devuelve lista de items y insertSelectedChecklistItems inserta los elegidos', () async {
      final ai = _ScriptedAiService(
        const AiCompletionResult(text: '- Preparar métricas\n- Enviar invite\n- Revisar backlog'),
      );
      final session = _readySession(ai);
      session.addPage();
      final pageId = session.selectedPageId!;
      final blockId = session.selectedPage!.blocks.first.id;
      session.changeBlockType(pageId, blockId, 'meeting_note');

      final suggestions = await MeetingNotePreparationService.instance.suggestChecklistItems(
        session: session,
        pageId: pageId,
        blockId: blockId,
      );

      expect(suggestions.length, 3);
      expect(suggestions, contains('Preparar métricas'));
      expect(suggestions, contains('Enviar invite'));

      final inserted = MeetingNotePreparationService.instance.insertSelectedChecklistItems(
        session: session,
        pageId: pageId,
        blockId: blockId,
        items: [suggestions[0], suggestions[2]], // Solo 2 elegidos
      );

      expect(inserted, 2);
    });
  });
}
