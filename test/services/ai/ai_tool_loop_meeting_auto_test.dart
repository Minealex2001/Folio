/// Fase 11 de la evolución de `meeting_note` — MCP Auto-Triggering.
///
/// `MeetingNoteAutoTriggerService` no reimplementa el bucle de tool-calling
/// (usa `runToolLoop`, el mismo que chat/plan) — este test verifica que
/// solo declara/ejecuta el subconjunto curado de tools
/// (`FolioToolRegistry.meetingAutoTriggerToolNames`) y que un intento de
/// invocar una tool fuera de ese conjunto se rechaza antes de tocar el
/// vault (defensa en profundidad si el modelo no respeta la lista
/// declarada).
import 'package:flutter_test/flutter_test.dart';
import 'package:folio/models/meeting_note_bookmark.dart';
import 'package:folio/services/ai/ai_service.dart';
import 'package:folio/services/ai/ai_types.dart';
import 'package:folio/services/ai/folio_tool_registry.dart';
import 'package:folio/services/meeting_note_auto_trigger_service.dart';
import 'package:folio/session/vault_session.dart';

class _ScriptedAiService implements AiService {
  _ScriptedAiService(this._responses);

  final List<AiCompletionResult> _responses;
  int _callCount = 0;
  final List<AiCompletionRequest> requests = [];

  @override
  bool get supportsNativeToolCalling => true;

  @override
  String get providerName => 'scripted';

  @override
  Future<AiCompletionResult> complete(AiCompletionRequest request) async {
    requests.add(request);
    final r = _responses[_callCount.clamp(0, _responses.length - 1)];
    _callCount++;
    return r;
  }

  @override
  Stream<AiCompletionChunk> completeStream(AiCompletionRequest request) async* {
    final r = await complete(request);
    yield AiCompletionChunk(
      textDelta: r.text,
      isFinal: true,
      toolCalls: r.toolCalls,
    );
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
  group('MeetingNoteAutoTriggerService.run', () {
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

    test('sin AiService devuelve null sin lanzar', () async {
      final result = await MeetingNoteAutoTriggerService.instance.run(
        session: session,
        pageId: pageId,
        blockId: blockId,
        recentTranscript: 'Speaker 1: decidimos usar S3',
      );
      expect(result, isNull);
    });

    test('transcript vacío devuelve null sin llamar a la IA', () async {
      final ai = _ScriptedAiService([const AiCompletionResult(text: '')]);
      session.setAiService(ai);

      final result = await MeetingNoteAutoTriggerService.instance.run(
        session: session,
        pageId: pageId,
        blockId: blockId,
        recentTranscript: '   ',
      );

      expect(result, isNull);
      expect(ai.requests, isEmpty);
    });

    test('solo declara el subconjunto curado de tools al modelo', () async {
      final ai = _ScriptedAiService([const AiCompletionResult(text: '')]);
      session.setAiService(ai);

      await MeetingNoteAutoTriggerService.instance.run(
        session: session,
        pageId: pageId,
        blockId: blockId,
        recentTranscript: 'Speaker 1: hola',
      );

      final declaredNames = ai.requests.first.tools.map((t) => t.name).toSet();
      expect(
        declaredNames,
        FolioToolRegistry.meetingAutoTriggerToolNames.toSet(),
      );
      // Nunca una tool destructiva o de gestión de páginas.
      expect(declaredNames.contains('permanently_delete_page'), isFalse);
      expect(declaredNames.contains('trash_page'), isFalse);
      expect(declaredNames.contains('create_page'), isFalse);
    });

    test('ejecuta meeting_create_bookmark cuando el modelo lo invoca', () async {
      final ai = _ScriptedAiService([
        AiCompletionResult(
          text: '',
          toolCalls: [
            AiToolCall(
              id: 'call1',
              name: 'meeting_create_bookmark',
              arguments: {
                'pageId': pageId,
                'blockId': blockId,
                'timestampMs': 5000,
                'type': 'decision',
              },
            ),
          ],
        ),
        const AiCompletionResult(text: ''),
      ]);
      session.setAiService(ai);

      final outcome = await MeetingNoteAutoTriggerService.instance.run(
        session: session,
        pageId: pageId,
        blockId: blockId,
        recentTranscript: 'Speaker 1: decidimos usar S3 para adjuntos',
      );

      expect(outcome, isNotNull);
      expect(outcome!.steps, hasLength(1));
      expect(outcome.steps.first.result.isError, isFalse);

      final bookmarks = session.selectedPage!.blocks.first.meetingNoteBookmarks;
      expect(bookmarks, hasLength(1));
      expect(bookmarks!.first.type, MeetingNoteBookmarkType.decision);
    });

    test(
      'rechaza (defensa en profundidad) una tool fuera del allowlist sin tocar el vault',
      () async {
        final ai = _ScriptedAiService([
          AiCompletionResult(
            text: '',
            toolCalls: [
              AiToolCall(
                id: 'call1',
                name: 'permanently_delete_page',
                arguments: {'pageId': pageId},
              ),
            ],
          ),
          const AiCompletionResult(text: ''),
        ]);
        session.setAiService(ai);

        final outcome = await MeetingNoteAutoTriggerService.instance.run(
          session: session,
          pageId: pageId,
          blockId: blockId,
          recentTranscript: 'Speaker 1: hola',
        );

        expect(outcome, isNotNull);
        expect(outcome!.steps, hasLength(1));
        expect(outcome.steps.first.result.isError, isTrue);
        // La página sigue existiendo — el intento de borrado nunca llegó
        // a ejecutarse contra el vault.
        expect(
          session.pages.any((p) => p.id == pageId && !p.isTrashed),
          isTrue,
        );
      },
    );
  });
}
