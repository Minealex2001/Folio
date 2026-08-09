/// Fase 21 de la evolución de `meeting_note` — test de integración de
/// ciclo de vida completo, para detectar regresiones cruzadas entre fases
/// en la serialización de `vault_session.dart` y en el guardado
/// best-effort antes de un lock de la bóveda.
///
/// Recorre: grabación simulada (vía el seam de test del controller, no hay
/// worker real en `flutter test`) → bookmark → live assist → "stop"
/// (persistencia de transcript + métricas) → resumen post-reunión →
/// materializar un action item como tarea → exportar a Markdown → lock()
/// de la bóveda. Cada paso reutiliza los mismos mutators/servicios que las
/// Fases 1–19 ya prueban por separado — este test verifica que encadenados
/// no se pisan ni se pierde nada.
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folio/data/vault_paths.dart';
import 'package:folio/models/block.dart';
import 'package:folio/models/folio_task_data.dart';
import 'package:folio/models/meeting_note_bookmark.dart';
import 'package:folio/services/ai/ai_service.dart';
import 'package:folio/services/ai/ai_types.dart';
import 'package:folio/services/integrations/integrations_markdown_codec.dart';
import 'package:folio/services/meeting_note_live_assist_service.dart';
import 'package:folio/services/meeting_note_metrics_service.dart';
import 'package:folio/services/meeting_note_preparation_service.dart';
import 'package:folio/services/meeting_note_session_controller.dart';
import 'package:folio/session/vault_session.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _ScriptedAiService implements AiService {
  int callCount = 0;

  @override
  bool get supportsNativeToolCalling => true;

  @override
  String get providerName => 'scripted';

  @override
  Future<AiCompletionResult> complete(AiCompletionRequest request) async {
    callCount++;
    if (request.cloudInkOperation == 'meeting_note_summary') {
      return const AiCompletionResult(
        text: '## Summary\nSe decidió migrar a S3.\n'
            '## Key Points\n- Migración a S3 aprobada\n'
            '## Action Items\n- Implementar sync con S3\n- Confirmar plazo',
      );
    }
    // Live assist: una sugerencia corta.
    return const AiCompletionResult(text: '¿Confirmamos el plazo final?');
  }

  @override
  Stream<AiCompletionChunk> completeStream(AiCompletionRequest request) async* {
    final r = await complete(request);
    yield AiCompletionChunk(textDelta: r.text, isFinal: true);
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
  TestWidgetsFlutterBinding.ensureInitialized();
  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

  group('meeting_note — ciclo de vida completo (Fase 21)', () {
    late Directory mockedSupportDir;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      mockedSupportDir = await Directory.systemTemp.createTemp(
        'folio_meeting_lifecycle_',
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(pathProviderChannel, (call) async {
            return mockedSupportDir.path;
          });
      MeetingNoteSessionController.instance.debugResetForTest();
    });

    tearDown(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(pathProviderChannel, null);
      MeetingNoteSessionController.instance.debugResetForTest();
      VaultPaths.clearActiveVaultId();
      if (mockedSupportDir.existsSync()) {
        await mockedSupportDir.delete(recursive: true);
      }
    });

    test(
      'start (simulado) -> bookmark -> live assist -> stop -> summary -> '
      'materializar action item -> export -> lock, sin perder nada',
      () async {
        const vaultId = 'meeting-lifecycle-vault';
        VaultPaths.setActiveVaultId(vaultId);
        await VaultPaths.initVaultStorage(vaultId);

        final ai = _ScriptedAiService();
        final session = VaultSession();
        session.debugMarkUnlockedForTests(formatVersion: 1, encrypted: true);
        session.setAiService(ai);
        session.addPage(parentId: null);
        final page = session.selectedPage!;
        final pageId = page.id;
        final blockId = page.blocks.first.id;
        session.changeBlockType(pageId, blockId, 'meeting_note');
        session.renamePage(pageId, 'Weekly sync');

        // --- start (simulado): sin worker real disponible en flutter test,
        // se usa el mismo seam que ya usan los tests de UI de Fase 9/10.
        const liveTranscript = 'Speaker 1: hablemos de la migración a S3';
        MeetingNoteSessionController.instance.debugForceRecordingStateForTest(
          pageId: pageId,
          blockId: blockId,
          transcript: liveTranscript,
          elapsed: const Duration(minutes: 2),
        );
        expect(
          MeetingNoteSessionController.instance.state,
          MeetingNoteSessionState.recording,
        );

        // --- bookmark (Fase 4), durante la grabación.
        session.addBlockMeetingNoteBookmark(
          pageId,
          blockId,
          MeetingNoteBookmark(
            id: 'bm1',
            timestampMs: 60000,
            type: MeetingNoteBookmarkType.decision,
            label: 'Usar S3',
          ),
        );
        expect(
          session.selectedPage!.blocks.first.meetingNoteBookmarks,
          hasLength(1),
        );

        // --- live assist (Fase 9), sobre el transcript en vivo.
        final suggestions = await MeetingNoteLiveAssistService.instance.suggest(
          session: session,
          pageId: pageId,
          recentTranscript: MeetingNoteSessionController.instance.transcript,
        );
        expect(suggestions, isNotEmpty);

        // --- stop (simulado): persistir transcript final + snapshot de
        // métricas, igual que hace `_stopImpl` en el controller real.
        session.updateBlockText(pageId, blockId, liveTranscript);
        final metricsSnapshot = MeetingMetricsService.instance.computeSnapshot(
          transcript: liveTranscript,
          elapsed: const Duration(minutes: 2),
        );
        session.updateBlockMeetingNoteMetricsSummary(
          pageId,
          blockId,
          metricsSnapshot.toJson(),
        );
        MeetingNoteSessionController.instance.debugResetForTest();
        expect(
          MeetingNoteSessionController.instance.state,
          MeetingNoteSessionState.idle,
        );

        // --- post-meeting summary (Fase 13).
        final summary = await MeetingNotePreparationService.instance
            .generateSummary(session: session, pageId: pageId, blockId: blockId);
        expect(summary, isNotNull);
        expect(
          session.selectedPage!.blocks.first.meetingNoteSummary,
          isNotNull,
        );

        // --- materializar un action item como tarea real (Fase 14).
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
        expect(
          FolioTaskData.tryParse(taskBlocks.first.text)!.createdFromBlockId,
          blockId,
        );

        // --- export (Fase 19): todo lo acumulado debe aparecer.
        final markdown = FolioMarkdownCodec.exportPage(session.selectedPage!);
        expect(markdown, contains('hablemos de la migración a S3'));
        expect(markdown, contains('### Summary'));
        expect(markdown, contains('### Bookmarks'));
        expect(markdown, contains('01:00 [decision] — Usar S3'));
        expect(markdown, contains('### Metrics'));

        // --- round-trip JSON completo del bloque meeting_note antes de
        // lockear — ninguno de los campos de las Fases 1-13 debe perderse.
        final blockBeforeLock = session.selectedPage!.blocks.first;
        final roundTripped = FolioBlock.fromJson(blockBeforeLock.toJson());
        expect(roundTripped.meetingNoteBookmarks, hasLength(1));
        expect(roundTripped.meetingNoteMetricsSummary, isNotNull);
        expect(roundTripped.meetingNoteSummary, isNotNull);
        expect(roundTripped.text, liveTranscript);

        // --- lock() de la bóveda: no debe colgarse ni perder el estado ya
        // persistido (regresión histórica cubierta también por
        // vault_session_lock_meeting_note_test.dart, aquí con datos reales
        // acumulados en vez de un vault vacío).
        await session.lock().timeout(const Duration(seconds: 5));
        expect(
          MeetingNoteSessionController.instance.state,
          MeetingNoteSessionState.idle,
        );
      },
    );
  });
}
