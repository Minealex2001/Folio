/// Fase 13 (Post-Meeting Intelligence) y Fase 14 (materialización de
/// action items como tareas) de la evolución de `meeting_note`.
///
/// `generateSummary` extrae texto — nunca crea tareas por sí sola.
/// `materializeActionItem` es la única vía que crea un bloque `task` real,
/// y reutiliza `FolioTaskData.createdFromBlockId` (mismo patrón que
/// `meeting_note_checklist_test.dart`), no un path nuevo.
import 'package:flutter_test/flutter_test.dart';
import 'package:folio/models/folio_task_data.dart';
import 'package:folio/services/ai/ai_service.dart';
import 'package:folio/services/ai/ai_types.dart';
import 'package:folio/services/meeting_note_preparation_service.dart';
import 'package:folio/session/vault_session.dart';

class _ScriptedAiService implements AiService {
  _ScriptedAiService(this.text);
  final String text;

  @override
  bool get supportsNativeToolCalling => true;

  @override
  String get providerName => 'scripted';

  @override
  Future<AiCompletionResult> complete(AiCompletionRequest request) async =>
      AiCompletionResult(text: text);

  @override
  Stream<AiCompletionChunk> completeStream(AiCompletionRequest request) async* {
    yield AiCompletionChunk(textDelta: text, isFinal: true);
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

const _sampleAiResponse = '''
## Summary
El equipo revisó la arquitectura de sincronización y acordó usar S3.

## Key Points
- Se decidió usar S3 para adjuntos
- El plazo sigue sin confirmar

## Action Items
- Implementar sync con S3
- Confirmar plazo con el cliente
''';

void main() {
  group('generateSummary', () {
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

    test('sin AiService devuelve null y no persiste nada', () async {
      session.updateBlockText(pageId, blockId, 'Speaker 1: hola');
      final result = await MeetingNotePreparationService.instance.generateSummary(
        session: session,
        pageId: pageId,
        blockId: blockId,
      );
      expect(result, isNull);
      expect(session.selectedPage!.blocks.first.meetingNoteSummary, isNull);
    });

    test('transcript vacío devuelve null sin llamar a la IA', () async {
      session.setAiService(_ScriptedAiService(_sampleAiResponse));
      final result = await MeetingNotePreparationService.instance.generateSummary(
        session: session,
        pageId: pageId,
        blockId: blockId,
      );
      expect(result, isNull);
    });

    test(
      'parsea narrative/keyPoints/actionItems y los persiste, sin crear tareas',
      () async {
        session.setAiService(_ScriptedAiService(_sampleAiResponse));
        session.updateBlockText(
          pageId,
          blockId,
          'Speaker 1: usemos S3 para los adjuntos',
        );

        final result = await MeetingNotePreparationService.instance.generateSummary(
          session: session,
          pageId: pageId,
          blockId: blockId,
        );

        expect(result, isNotNull);
        expect(result!['narrative'], contains('S3'));
        expect(result['keyPoints'], hasLength(2));
        final actionItems = result['actionItems'] as List;
        expect(actionItems, hasLength(2));
        expect((actionItems[0] as Map)['title'], 'Implementar sync con S3');
        expect((actionItems[0] as Map)['taskBlockId'], isNull);

        // Persistido en el bloque.
        final persisted = session.selectedPage!.blocks.first.meetingNoteSummary;
        expect(persisted, isNotNull);
        expect(persisted!['narrative'], result['narrative']);

        // No se creó ningún bloque task todavía.
        expect(
          session.selectedPage!.blocks.where((b) => b.type == 'task'),
          isEmpty,
        );
      },
    );

    test('respuesta sin las tres secciones devuelve null', () async {
      session.setAiService(_ScriptedAiService('texto libre sin encabezados'));
      session.updateBlockText(pageId, blockId, 'Speaker 1: hola');

      final result = await MeetingNotePreparationService.instance.generateSummary(
        session: session,
        pageId: pageId,
        blockId: blockId,
      );

      expect(result, isNull);
    });
  });

  group('materializeActionItem', () {
    late VaultSession session;
    late String pageId;
    late String blockId;

    setUp(() async {
      session = VaultSession();
      session.setAiService(_ScriptedAiService(_sampleAiResponse));
      session.addPage();
      final page = session.selectedPage!;
      pageId = page.id;
      blockId = page.blocks.first.id;
      session.changeBlockType(pageId, blockId, 'meeting_note');
      session.updateBlockText(pageId, blockId, 'Speaker 1: usemos S3');
      await MeetingNotePreparationService.instance.generateSummary(
        session: session,
        pageId: pageId,
        blockId: blockId,
      );
    });

    test('crea un bloque task vinculado via createdFromBlockId', () {
      final taskBlockId = MeetingNotePreparationService.instance
          .materializeActionItem(
            session: session,
            pageId: pageId,
            blockId: blockId,
            index: 0,
          );

      expect(taskBlockId, isNotNull);
      final taskBlocks =
          session.selectedPage!.blocks.where((b) => b.type == 'task').toList();
      expect(taskBlocks, hasLength(1));
      expect(taskBlocks.first.id, taskBlockId);

      final data = FolioTaskData.tryParse(taskBlocks.first.text)!;
      expect(data.title, 'Implementar sync con S3');
      expect(data.createdFromBlockId, blockId);
      expect(data.aiContextPageId, pageId);

      // El summary refleja el taskBlockId del item materializado.
      final summary = session.selectedPage!.blocks.first.meetingNoteSummary!;
      final actionItems = summary['actionItems'] as List;
      expect((actionItems[0] as Map)['taskBlockId'], taskBlockId);
      // El segundo item sigue sin materializar.
      expect((actionItems[1] as Map)['taskBlockId'], isNull);
    });

    test('materializar el mismo item dos veces no crea un segundo task', () {
      final first = MeetingNotePreparationService.instance.materializeActionItem(
        session: session,
        pageId: pageId,
        blockId: blockId,
        index: 0,
      );
      final second = MeetingNotePreparationService.instance.materializeActionItem(
        session: session,
        pageId: pageId,
        blockId: blockId,
        index: 0,
      );

      expect(first, isNotNull);
      expect(second, isNull);
      expect(
        session.selectedPage!.blocks.where((b) => b.type == 'task'),
        hasLength(1),
      );
    });

    test('índice fuera de rango devuelve null sin lanzar', () {
      final result = MeetingNotePreparationService.instance.materializeActionItem(
        session: session,
        pageId: pageId,
        blockId: blockId,
        index: 99,
      );
      expect(result, isNull);
    });
  });
}
