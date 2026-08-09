import 'package:flutter_test/flutter_test.dart';

import 'package:folio/features/workspace/shell/workspace_page.dart';
import 'package:folio/services/meeting_note_session_controller.dart';

/// Fase A3 del plan Quill/MCP — lógica de decisión pura de
/// `meetingCompletionSuggestionDecision`, aislada de `WorkspacePage` y del
/// `MeetingNoteSessionController` real (que en el momento de esta fase
/// estaba bajo reescritura activa — de ahí que la señal se consuma
/// puramente desde fuera, sin ningún hook de test añadido a ese archivo).
void main() {
  group('meetingCompletionSuggestionDecision', () {
    test('transición a completed con transcript no vacío → shouldShow', () {
      final decision = meetingCompletionSuggestionDecision(
        previousState: MeetingNoteSessionState.cloudProcessing,
        currentState: MeetingNoteSessionState.completed,
        pageId: 'page_1',
        blockId: 'block_1',
        transcript: 'Hola, esta es la transcripción.',
        alreadyShownKeys: {},
        enabled: true,
      );

      expect(decision.shouldShow, isTrue);
      expect(decision.pageId, 'page_1');
      expect(decision.blockId, 'block_1');
      expect(decision.key, 'page_1#block_1');
    });

    test('deshabilitado en ajustes → nunca muestra', () {
      final decision = meetingCompletionSuggestionDecision(
        previousState: MeetingNoteSessionState.recording,
        currentState: MeetingNoteSessionState.completed,
        pageId: 'page_1',
        blockId: 'block_1',
        transcript: 'x',
        alreadyShownKeys: {},
        enabled: false,
      );
      expect(decision.shouldShow, isFalse);
    });

    test('sin transición real (previous == current) no muestra de nuevo', () {
      final decision = meetingCompletionSuggestionDecision(
        previousState: MeetingNoteSessionState.completed,
        currentState: MeetingNoteSessionState.completed,
        pageId: 'page_1',
        blockId: 'block_1',
        transcript: 'x',
        alreadyShownKeys: {},
        enabled: true,
      );
      expect(decision.shouldShow, isFalse);
    });

    test('estado distinto de completed no muestra', () {
      for (final state in [
        MeetingNoteSessionState.idle,
        MeetingNoteSessionState.setup,
        MeetingNoteSessionState.recording,
        MeetingNoteSessionState.cloudProcessing,
      ]) {
        final decision = meetingCompletionSuggestionDecision(
          previousState: MeetingNoteSessionState.idle,
          currentState: state,
          pageId: 'page_1',
          blockId: 'block_1',
          transcript: 'x',
          alreadyShownKeys: {},
          enabled: true,
        );
        expect(decision.shouldShow, isFalse, reason: state.name);
      }
    });

    test('pageId o blockId null no muestra', () {
      expect(
        meetingCompletionSuggestionDecision(
          previousState: MeetingNoteSessionState.recording,
          currentState: MeetingNoteSessionState.completed,
          pageId: null,
          blockId: 'block_1',
          transcript: 'x',
          alreadyShownKeys: {},
          enabled: true,
        ).shouldShow,
        isFalse,
      );
      expect(
        meetingCompletionSuggestionDecision(
          previousState: MeetingNoteSessionState.recording,
          currentState: MeetingNoteSessionState.completed,
          pageId: 'page_1',
          blockId: null,
          transcript: 'x',
          alreadyShownKeys: {},
          enabled: true,
        ).shouldShow,
        isFalse,
      );
    });

    test('transcript vacío (o solo espacios) no muestra', () {
      final decision = meetingCompletionSuggestionDecision(
        previousState: MeetingNoteSessionState.recording,
        currentState: MeetingNoteSessionState.completed,
        pageId: 'page_1',
        blockId: 'block_1',
        transcript: '   ',
        alreadyShownKeys: {},
        enabled: true,
      );
      expect(decision.shouldShow, isFalse);
    });

    test('ya mostrada para esta clave (pageId#blockId) no se repite', () {
      final decision = meetingCompletionSuggestionDecision(
        previousState: MeetingNoteSessionState.recording,
        currentState: MeetingNoteSessionState.completed,
        pageId: 'page_1',
        blockId: 'block_1',
        transcript: 'x',
        alreadyShownKeys: {'page_1#block_1'},
        enabled: true,
      );
      expect(decision.shouldShow, isFalse);
    });

    test('la misma reunión en otro bloque (clave distinta) sí muestra', () {
      final decision = meetingCompletionSuggestionDecision(
        previousState: MeetingNoteSessionState.recording,
        currentState: MeetingNoteSessionState.completed,
        pageId: 'page_1',
        blockId: 'block_2',
        transcript: 'x',
        alreadyShownKeys: {'page_1#block_1'},
        enabled: true,
      );
      expect(decision.shouldShow, isTrue);
      expect(decision.key, 'page_1#block_2');
    });
  });
}
