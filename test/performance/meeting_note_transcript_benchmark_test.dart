// Fase de investigación de freezes (0.8.5) — mide el coste de UI de una nota
// de reunión EN GRABACIÓN según crece el transcript.
//
// Reproduce el bucle real: el worker (`meeting_worker_host.dart`) emite un
// evento cada 1 s → `MeetingNoteSessionController.notifyListeners()` →
// `_MeetingNoteBlockWidgetState._onSessionChanged()` → `setState(() {})` →
// rebuild completo → `_buildRecording` → `_buildColoredTranscript` (N líneas
// `Speaker N:` en un `SingleChildScrollView`, sin virtualización).
//
// Aquí se fuerza el estado `recording` con transcripts de tamaño creciente
// (`debugForceRecordingStateForTest`) y se cronometra el frame resultante
// (`tester.pump()` = build + layout + paint, incluye el coste diferido de
// construir cada `Builder`/`SelectableText` por línea).
//
//   flutter test --dart-define=FOLIO_PERF_TRACE=true \
//     test/performance/meeting_note_transcript_benchmark_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:folio/app/app_settings.dart';
import 'package:folio/features/workspace/editor/block_editor.dart';
import 'package:folio/l10n/generated/app_localizations.dart';
import 'package:folio/services/meeting_note_session_controller.dart';
import 'package:folio/session/vault_session.dart';

String _transcript(int lines) {
  final b = StringBuffer();
  for (var i = 0; i < lines; i++) {
    b.write('Speaker ${i % 3 + 1}: ');
    b.write(
      'Esto es la línea $i del acta, con contenido suficiente para que el '
      'render por línea (SelectableText + PopupMenuButton) tenga trabajo real.',
    );
    b.write('\n');
  }
  return b.toString();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final results = <String>[];

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    MeetingNoteSessionController.instance.debugResetForTest();
  });
  tearDown(() {
    MeetingNoteSessionController.instance.debugResetForTest();
  });
  tearDownAll(() {
    // ignore: avoid_print
    print('\n===== MEETING NOTE — coste de frame en grabación vs transcript =====');
    for (final l in results) {
      // ignore: avoid_print
      print(l);
    }
    // ignore: avoid_print
    print('  frame_ms = tester.pump() tras forzar recording (build+layout+paint).');
    // ignore: avoid_print
    print('  El worker real dispara esto ~1 vez/segundo durante toda la reunión.\n');
  });

  testWidgets('coste de rebuild en recording según nº de líneas del transcript',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final session = VaultSession();
    session.addPage();
    final pageId = session.selectedPageId!;
    final blockId = session.selectedPage!.blocks.first.id;
    session.changeBlockType(pageId, blockId, 'meeting_note');

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: BlockEditor(
            session: session,
            appSettings: AppSettings(),
            onAiSlashCommand: (_) async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final ctrl = MeetingNoteSessionController.instance;

    Future<double> forceAndTime(int lines, {required String tag}) async {
      final t = _transcript(lines);
      ctrl.debugForceRecordingStateForTest(
        pageId: pageId,
        blockId: blockId,
        transcript: t,
        elapsed: Duration(seconds: lines),
      );
      final sw = Stopwatch()..start();
      await tester.pump(); // 1 frame: build + layout + paint
      sw.stop();
      final ms = sw.elapsedMicroseconds / 1000.0;
      // segundo pump idéntico = "tick de elapsed sin cambio de transcript"
      ctrl.debugForceRecordingStateForTest(
        pageId: pageId,
        blockId: blockId,
        transcript: t,
        elapsed: Duration(seconds: lines + 1),
      );
      final sw2 = Stopwatch()..start();
      await tester.pump();
      sw2.stop();
      final msNoGrow = sw2.elapsedMicroseconds / 1000.0;
      results.add(
        '  $tag: ${lines.toString().padLeft(5)} líneas  '
        'frame_ms(delta)=${ms.toStringAsFixed(1).padLeft(7)}  '
        'frame_ms(tick sin crecer)=${msNoGrow.toStringAsFixed(1).padLeft(7)}',
      );
      return ms;
    }

    // Calentamiento (primer render del bloque en recording).
    await forceAndTime(10, tag: 'warmup');
    results.clear();

    for (final n in const [50, 200, 600, 1500, 3000]) {
      await forceAndTime(n, tag: 'recording');
    }

    expect(tester.takeException(), isNull);
  }, timeout: const Timeout(Duration(minutes: 3)));
}
