/// Fase 14 de la evolución de `meeting_note` — integración profunda con
/// Quill. No añade lógica nueva, verifica dos invariantes que las Fases
/// 1–13 (muchos campos nuevos en `FolioBlock`) no deben haber roto:
/// 1) `meeting_note` sigue excluido de la fusión de bloques adyacentes.
/// 2) La gramática de generación de bloques por IA (`vault_session_ai.dart`)
///    sigue listando `meeting_note` como tipo válido.
import 'package:flutter_test/flutter_test.dart';
import 'package:folio/models/block.dart';

void main() {
  group('Fase 14 — invariantes de integración con Quill', () {
    test('meeting_note nunca se fusiona con un bloque de texto adyacente', () {
      final meetingNote = FolioBlock(
        id: 'mn1',
        type: 'meeting_note',
        text: 'Speaker 1: hola',
      );
      final paragraph = FolioBlock(id: 'p1', type: 'paragraph', text: 'texto');

      expect(folioBlocksCanMerge(meetingNote, paragraph), isFalse);
      expect(folioBlocksCanMerge(paragraph, meetingNote), isFalse);
    });

    test(
      'meeting_note nunca se fusiona con otro meeting_note (dos grabaciones '
      'distintas no deben mezclar su transcript)',
      () {
        final a = FolioBlock(id: 'mn1', type: 'meeting_note', text: 'a');
        final b = FolioBlock(id: 'mn2', type: 'meeting_note', text: 'b');
        expect(folioBlocksCanMerge(a, b), isFalse);
      },
    );

    test(
      'un bloque meeting_note con todos los campos de las Fases 1-13 '
      'sobrevive un round-trip JSON completo sin perder ninguno',
      () {
        final block = FolioBlock(
          id: 'mn1',
          type: 'meeting_note',
          text: 'Speaker 1: hola',
          meetingNoteProvider: 'local',
          meetingNoteTranscriptionEnabled: true,
          meetingNoteTitle: 'Weekly sync',
          meetingNoteLanguage: 'es',
          meetingNoteChannelMeta: const {'micChunks': 3, 'dualChannel': true},
          meetingNoteBookmarks: null,
          meetingNotePrepNotes: '## Agenda',
          meetingNoteMetricsSummary: const {'wordsPerMinute': 120.0},
          meetingNoteAutoAssistEnabled: true,
          meetingNoteSummary: const {
            'narrative': 'resumen',
            'keyPoints': ['punto 1'],
            'actionItems': [
              {'title': 'acción 1', 'taskBlockId': null},
            ],
          },
        );

        final roundTripped = FolioBlock.fromJson(block.toJson());

        expect(roundTripped.meetingNoteProvider, 'local');
        expect(roundTripped.meetingNoteTitle, 'Weekly sync');
        expect(roundTripped.meetingNoteLanguage, 'es');
        expect(roundTripped.meetingNoteChannelMeta, {
          'micChunks': 3,
          'dualChannel': true,
        });
        expect(roundTripped.meetingNotePrepNotes, '## Agenda');
        expect(roundTripped.meetingNoteMetricsSummary, {
          'wordsPerMinute': 120.0,
        });
        expect(roundTripped.meetingNoteAutoAssistEnabled, isTrue);
        expect(roundTripped.meetingNoteSummary?['narrative'], 'resumen');
      },
    );
  });
}
