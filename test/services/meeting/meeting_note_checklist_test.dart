/// Fase 7 de la evolución de `meeting_note` — checklist dinámico.
///
/// Verifica que tanto la tool MCP `meeting_generate_checklist` como
/// `MeetingNotePreparationService.generateChecklist` reutilizan la
/// infraestructura de tareas ya existente (`FolioTaskData` + bloques
/// `task` normales), no un tipo de bloque paralelo — cada item creado debe
/// llevar `createdFromBlockId` apuntando al meeting_note origen.
import 'package:flutter_test/flutter_test.dart';
import 'package:folio/models/folio_task_data.dart';
import 'package:folio/services/ai/ai_service.dart';
import 'package:folio/services/ai/ai_tool.dart';
import 'package:folio/services/ai/ai_types.dart';
import 'package:folio/services/ai/folio_tool_registry.dart';
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

void main() {
  group('FolioToolRegistry — meeting_generate_checklist', () {
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
      expect(registry.definitionByName('meeting_generate_checklist'), isNotNull);
    });

    test('crea bloques task normales vinculados via createdFromBlockId', () async {
      final result = await registry.execute(
        AiToolCall(
          id: 'c1',
          name: 'meeting_generate_checklist',
          arguments: {
            'pageId': pageId,
            'blockId': blockId,
            'items': ['Revisar arquitectura', 'Confirmar deployment'],
          },
        ),
      );

      expect(result.isError, isFalse);
      final taskBlocks = session.selectedPage!.blocks
          .where((b) => b.type == 'task')
          .toList();
      expect(taskBlocks, hasLength(2));

      final data0 = FolioTaskData.tryParse(taskBlocks[0].text)!;
      expect(data0.title, 'Revisar arquitectura');
      expect(data0.createdFromBlockId, blockId);
      expect(data0.aiContextPageId, pageId);

      final data1 = FolioTaskData.tryParse(taskBlocks[1].text)!;
      expect(data1.title, 'Confirmar deployment');
    });

    test('devuelve error si items está vacío', () async {
      final result = await registry.execute(
        AiToolCall(
          id: 'c2',
          name: 'meeting_generate_checklist',
          arguments: {'pageId': pageId, 'blockId': blockId, 'items': []},
        ),
      );
      expect(result.isError, isTrue);
    });

    test('devuelve error si el bloque no es meeting_note', () async {
      session.changeBlockType(pageId, blockId, 'paragraph');
      final result = await registry.execute(
        AiToolCall(
          id: 'c3',
          name: 'meeting_generate_checklist',
          arguments: {
            'pageId': pageId,
            'blockId': blockId,
            'items': ['x'],
          },
        ),
      );
      expect(result.isError, isTrue);
    });
  });

  group('MeetingNotePreparationService.generateChecklist', () {
    test('sin AiService devuelve 0 y no crea bloques', () async {
      final session = VaultSession();
      session.addPage();
      final pageId = session.selectedPageId!;
      final blockId = session.selectedPage!.blocks.first.id;
      session.changeBlockType(pageId, blockId, 'meeting_note');

      final count = await MeetingNotePreparationService.instance.generateChecklist(
        session: session,
        pageId: pageId,
        blockId: blockId,
      );

      expect(count, 0);
      expect(session.selectedPage!.blocks.where((b) => b.type == 'task'), isEmpty);
    });

    test('parsea la respuesta de la IA línea a línea y crea un task por línea', () async {
      final session = VaultSession();
      session.setAiService(
        _ScriptedAiService('Revisar arquitectura\nConfirmar deployment\n'),
      );
      session.addPage();
      final pageId = session.selectedPageId!;
      final blockId = session.selectedPage!.blocks.first.id;
      session.changeBlockType(pageId, blockId, 'meeting_note');

      final count = await MeetingNotePreparationService.instance.generateChecklist(
        session: session,
        pageId: pageId,
        blockId: blockId,
      );

      expect(count, 2);
      final taskBlocks =
          session.selectedPage!.blocks.where((b) => b.type == 'task').toList();
      expect(taskBlocks, hasLength(2));
      expect(
        FolioTaskData.tryParse(taskBlocks.first.text)!.createdFromBlockId,
        blockId,
      );
    });
  });
}
