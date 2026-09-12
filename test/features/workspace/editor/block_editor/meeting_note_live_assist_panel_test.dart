/// Fase 9 (Live Assist), Fase 10 (nudges) y Fase 11/12 (auto-assist toggle
/// + resultados MCP) de la evolución de `meeting_note` — cobertura de
/// widget para `MeetingNoteLiveAssistPanel` embebido en la vista de
/// grabación de `MeetingNoteBlockWidget`.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:folio/app/app_settings.dart';
import 'package:folio/features/workspace/editor/meeting_note_block_widget.dart';
import 'package:folio/l10n/generated/app_localizations.dart';
import 'package:folio/models/block.dart';
import 'package:folio/services/ai/ai_service.dart';
import 'package:folio/services/ai/ai_types.dart';
import 'package:folio/services/meeting_note_session_controller.dart';
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

Future<AppSettings> _aiEnabledSettings() async {
  final settings = AppSettings();
  await settings.setAiEnabled(true);
  return settings;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    MeetingNoteSessionController.instance.debugResetForTest();
  });

  tearDown(() {
    MeetingNoteSessionController.instance.debugResetForTest();
  });

  testWidgets(
    'panel no aparece si isAiRuntimeEnabled es false, aunque esté grabando',
    (tester) async {
      final session = VaultSession();
      session.addPage();
      final page = session.selectedPage!;
      final block = FolioBlock(id: 'mn1', type: 'meeting_note', text: '');
      MeetingNoteSessionController.instance.debugForceRecordingStateForTest(
        pageId: page.id,
        blockId: block.id,
      );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => MeetingNoteBlockWidget(
                block: block,
                page: page,
                session: session,
                appSettings: AppSettings(),
                scheme: Theme.of(context).colorScheme,
                resolvedFile: null,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Live Assist'), findsNothing);
    },
  );

  testWidgets(
    'panel aparece grabando con IA activa; "Sugerir" muestra sugerencias',
    (tester) async {
      final session = VaultSession();
      session.setAiService(
        _ScriptedAiService('¿Cuál es el plazo?\nFalta el propietario'),
      );
      session.addPage();
      final page = session.selectedPage!;
      final block = FolioBlock(id: 'mn1', type: 'meeting_note', text: '');
      final appSettings = await _aiEnabledSettings();

      MeetingNoteSessionController.instance.debugForceRecordingStateForTest(
        pageId: page.id,
        blockId: block.id,
        transcript: 'Speaker 1: no sabemos el plazo final',
        elapsed: const Duration(seconds: 30),
      );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => MeetingNoteBlockWidget(
                block: block,
                page: page,
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
      expect(tester.takeException(), isNull);

      final l10n = AppLocalizations.of(
        tester.element(find.byType(MeetingNoteBlockWidget)),
      );

      // El panel está colapsado por defecto — expandir.
      await tester.tap(find.text(l10n.meetingNoteLiveAssistTitle));
      await tester.pumpAndSettle();

      await tester.tap(find.text(l10n.meetingNoteLiveAssistSuggest));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.textContaining('plazo'), findsWidgets);
    },
  );

  testWidgets(
    'nudge de monólogo largo aparece como banner descartable',
    (tester) async {
      final session = VaultSession();
      session.addPage();
      final page = session.selectedPage!;
      final block = FolioBlock(id: 'mn1', type: 'meeting_note', text: '');
      final appSettings = await _aiEnabledSettings();

      // Un único turno ininterrumpido de Speaker 1 que cubre toda la
      // grabación: la duración estimada del monólogo (palabras del turno /
      // wpm de la sesión) siempre converge al tiempo transcurrido en ese
      // caso — con 4 minutos transcurridos supera el umbral de 3 minutos.
      final longTurn = List.filled(300, 'palabra').join(' ');
      MeetingNoteSessionController.instance.debugForceRecordingStateForTest(
        pageId: page.id,
        blockId: block.id,
        transcript: 'Speaker 1: $longTurn',
        elapsed: const Duration(minutes: 4),
      );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => MeetingNoteBlockWidget(
                block: block,
                page: page,
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
      expect(tester.takeException(), isNull);

      final l10n = AppLocalizations.of(
        tester.element(find.byType(MeetingNoteBlockWidget)),
      );
      expect(find.text(l10n.meetingNoteNudgeMonologueLong), findsOneWidget);

      // Descartable: tras cerrarlo, desaparece.
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
      expect(find.text(l10n.meetingNoteNudgeMonologueLong), findsNothing);
    },
  );

  testWidgets(
    'toggle de auto-assist (Fase 11) persiste meetingNoteAutoAssistEnabled en el bloque',
    (tester) async {
      final session = VaultSession();
      session.setAiService(_ScriptedAiService('sin sugerencias'));
      session.addPage();
      final page = session.selectedPage!;
      // El bloque debe pertenecer de verdad a la página: el mutator de
      // persistencia busca por id dentro de `page.blocks`, no acepta un
      // FolioBlock "flotante" pasado solo como parámetro del widget.
      session.changeBlockType(page.id, page.blocks.first.id, 'meeting_note');
      final block = session.selectedPage!.blocks.first;
      final appSettings = await _aiEnabledSettings();

      MeetingNoteSessionController.instance.debugForceRecordingStateForTest(
        pageId: page.id,
        blockId: block.id,
      );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => MeetingNoteBlockWidget(
                block: block,
                page: page,
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

      // Expandir el panel y activar el switch de auto-assist.
      await tester.tap(find.text(l10n.meetingNoteLiveAssistTitle));
      await tester.pumpAndSettle();
      expect(
        session.selectedPage!.blocks.first.meetingNoteAutoAssistEnabled,
        isNot(true),
      );

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        session.selectedPage!.blocks.first.meetingNoteAutoAssistEnabled,
        isTrue,
      );

      // Con auto-assist activo, "Sugerir" también dispara una pasada de
      // auto-trigger — con el AiService scripted (sin tool calls) no debe
      // lanzar ninguna excepción ni bloquear la UI.
      await tester.tap(find.text(l10n.meetingNoteLiveAssistSuggest));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
