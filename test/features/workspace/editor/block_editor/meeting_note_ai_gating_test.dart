/// Fase 16 de la evolución de `meeting_note` — auditoría de gating
/// local-first/cloud. Antes de esta fase, los botones Prepare/Generate
/// checklist/Generate summary llamaban al `AiService` activo sin pedir
/// opt-in cuando el proveedor era cloud — inconsistente con Live Assist,
/// que sí lo pedía. Este test cubre la corrección: con proveedor cloud,
/// ninguno de los tres dispara una llamada real a la IA sin que el usuario
/// confirme el diálogo de opt-in primero; con proveedor local, no hay
/// diálogo y la llamada procede directo.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:folio/app/app_settings.dart';
import 'package:folio/features/workspace/editor/meeting_note_block_widget.dart';
import 'package:folio/l10n/generated/app_localizations.dart';
import 'package:folio/models/block.dart';
import 'package:folio/services/ai/ai_service.dart';
import 'package:folio/services/ai/ai_types.dart';
import 'package:folio/session/vault_session.dart';

class _CountingAiService implements AiService {
  int callCount = 0;

  @override
  bool get supportsNativeToolCalling => true;

  @override
  String get providerName => 'scripted';

  @override
  Future<AiCompletionResult> complete(AiCompletionRequest request) async {
    callCount++;
    return const AiCompletionResult(
      text: '## Agenda sugerida\n- punto\n## Preguntas a hacer\n## Temas a cubrir',
    );
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

Future<(VaultSession, AppSettings, FolioBlock)> _setupIdleMeetingNote({
  required bool cloudProvider,
}) async {
  final session = VaultSession();
  final ai = _CountingAiService();
  session.setAiService(ai);
  session.addPage();
  final page = session.selectedPage!;
  session.changeBlockType(page.id, page.blocks.first.id, 'meeting_note');
  final block = session.selectedPage!.blocks.first;

  final appSettings = AppSettings();
  await appSettings.setAiEnabled(true);
  if (cloudProvider) {
    await appSettings.setAiProvider(AiProvider.quillCloud);
  }
  return (session, appSettings, block);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'proveedor cloud: "Prepare meeting" pide opt-in antes de llamar a la IA',
    (tester) async {
      final (session, appSettings, block) = await _setupIdleMeetingNote(
        cloudProvider: true,
      );
      final ai = session.aiService as _CountingAiService;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => MeetingNoteBlockWidget(
                block: block,
                page: session.selectedPage!,
                session: session,
                appSettings: appSettings,
                scheme: Theme.of(context).colorScheme,
                resolvedFile: null,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final l10n = AppLocalizations.of(
        tester.element(find.byType(MeetingNoteBlockWidget)),
      );

      await tester.tap(find.text(l10n.meetingNotePrepareMeeting));
      await tester.pump();

      // El diálogo de opt-in aparece; la IA todavía NO se llamó.
      expect(find.text(l10n.meetingNoteLiveAssistCloudOptInTitle), findsOneWidget);
      expect(ai.callCount, 0);

      await tester.tap(find.text(l10n.meetingNoteLiveAssistCloudOptInConfirm));
      await tester.pumpAndSettle();

      // Confirmado: ahora sí se llamó a la IA.
      expect(ai.callCount, 1);
    },
  );

  testWidgets(
    'proveedor cloud: cancelar el opt-in no llama a la IA',
    (tester) async {
      final (session, appSettings, block) = await _setupIdleMeetingNote(
        cloudProvider: true,
      );
      final ai = session.aiService as _CountingAiService;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => MeetingNoteBlockWidget(
                block: block,
                page: session.selectedPage!,
                session: session,
                appSettings: appSettings,
                scheme: Theme.of(context).colorScheme,
                resolvedFile: null,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final l10n = AppLocalizations.of(
        tester.element(find.byType(MeetingNoteBlockWidget)),
      );

      await tester.tap(find.text(l10n.meetingNotePrepareMeeting));
      await tester.pump();
      await tester.tap(find.text(l10n.meetingNoteCancelUpload));
      await tester.pumpAndSettle();

      expect(ai.callCount, 0);
    },
  );

  testWidgets(
    'proveedor local: no hay diálogo de opt-in, la llamada procede directo',
    (tester) async {
      final (session, appSettings, block) = await _setupIdleMeetingNote(
        cloudProvider: false,
      );
      final ai = session.aiService as _CountingAiService;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => MeetingNoteBlockWidget(
                block: block,
                page: session.selectedPage!,
                session: session,
                appSettings: appSettings,
                scheme: Theme.of(context).colorScheme,
                resolvedFile: null,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final l10n = AppLocalizations.of(
        tester.element(find.byType(MeetingNoteBlockWidget)),
      );

      await tester.tap(find.text(l10n.meetingNotePrepareMeeting));
      await tester.pumpAndSettle();

      expect(find.text(l10n.meetingNoteLiveAssistCloudOptInTitle), findsNothing);
      expect(ai.callCount, 1);
    },
  );
}
