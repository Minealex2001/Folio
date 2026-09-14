import 'package:flutter_test/flutter_test.dart';
import 'package:folio/services/ai/ai_service.dart';
import 'package:folio/services/ai/ai_types.dart';
import 'package:folio/services/meeting_note_reconciliation_service.dart';
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
  bool get supportsVision => false;

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
  group('MeetingNoteReconciliationService', () {
    test('sin AiService activo devuelve null y no persiste nada', () async {
      final session = _readySession(null);
      session.addPage();
      final pageId = session.selectedPageId!;
      final blockId = session.selectedPage!.blocks.first.id;
      session.changeBlockType(pageId, blockId, 'meeting_note');
      session.updateBlockText(pageId, blockId, 'Speaker 1: Hola');

      final result = await MeetingNoteReconciliationService.instance
          .reconcileTranscript(
            session: session,
            pageId: pageId,
            blockId: blockId,
          );

      expect(result, isNull);
    });

    test('reconcileTranscript actualiza y limpia la transcripción con la IA', () async {
      final ai = _ScriptedAiService(
        const AiCompletionResult(
          text: 'Alejandro: Hola a todos, empezamos la reunión.\nCarlos: Perfecto, adelante.',
        ),
      );
      final session = _readySession(ai);
      session.addPage();
      final pageId = session.selectedPageId!;
      final blockId = session.selectedPage!.blocks.first.id;
      session.changeBlockType(pageId, blockId, 'meeting_note');
      session.updateBlockText(
        pageId,
        blockId,
        'Speaker 1: Hola a todos,\nSpeaker 2: empezamos la reunión.\nSpeaker 1: Perfecto, adelante.',
      );

      final result = await MeetingNoteReconciliationService.instance
          .reconcileTranscript(
            session: session,
            pageId: pageId,
            blockId: blockId,
          );

      expect(result, contains('Alejandro: Hola a todos, empezamos la reunión.'));
      expect(result, contains('Carlos: Perfecto, adelante.'));
      expect(session.selectedPage!.blocks.first.text, result);
      expect(ai.lastRequest?.cloudInkOperation, 'meeting_note_reconcile');
    });

    test('renameSpeaker sustituye todas las menciones del hablante indicado', () {
      final session = _readySession(null);
      session.addPage();
      final pageId = session.selectedPageId!;
      final blockId = session.selectedPage!.blocks.first.id;
      session.changeBlockType(pageId, blockId, 'meeting_note');
      session.updateBlockText(
        pageId,
        blockId,
        'Speaker 1: Primer punto.\nSpeaker 2: De acuerdo.\nSpeaker 1: Segundo punto.',
      );

      final updated = MeetingNoteReconciliationService.instance.renameSpeaker(
        session: session,
        pageId: pageId,
        blockId: blockId,
        oldSpeaker: 'Speaker 1',
        newSpeaker: 'Alejandro',
      );

      expect(updated, contains('Alejandro: Primer punto.'));
      expect(updated, contains('Speaker 2: De acuerdo.'));
      expect(updated, contains('Alejandro: Segundo punto.'));
      expect(session.selectedPage!.blocks.first.text, updated);
    });

    test('mergeSpeakers unifica turnos asignándolos al hablante de destino', () {
      final session = _readySession(null);
      session.addPage();
      final pageId = session.selectedPageId!;
      final blockId = session.selectedPage!.blocks.first.id;
      session.changeBlockType(pageId, blockId, 'meeting_note');
      session.updateBlockText(
        pageId,
        blockId,
        'Speaker 1: Texto 1.\nSpeaker 2: Texto 2.',
      );

      final updated = MeetingNoteReconciliationService.instance.mergeSpeakers(
        session: session,
        pageId: pageId,
        blockId: blockId,
        sourceSpeaker: 'Speaker 2',
        targetSpeaker: 'Speaker 1',
      );

      expect(updated, 'Speaker 1: Texto 1.\nSpeaker 1: Texto 2.');
    });
  });
}
