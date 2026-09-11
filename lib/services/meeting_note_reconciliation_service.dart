import '../models/block.dart';
import '../models/folio_page.dart';
import '../session/vault_session.dart';
import 'ai/ai_types.dart';

/// Servicio de refinamiento semántico de transcripciones de reunión
/// (Smart Diarization Pass).
///
/// Corrige mediante IA las deficiencias de la diarización acústica local:
/// 1. Une frases cortadas arbitrariamente en mitad de una intervención.
/// 2. Reatribuye turnos según coherencia conversacional y pares pregunta/respuesta.
/// 3. Infiere nombres reales de participantes cuando se mencionan en la llamada
///    ("Hola Carlos", "como comentaba María").
class MeetingNoteReconciliationService {
  MeetingNoteReconciliationService._();
  static final MeetingNoteReconciliationService instance =
      MeetingNoteReconciliationService._();

  /// Refina y persiste el texto de la transcripción del bloque de reunión.
  /// Devuelve el texto refinado, o `null` si no hay `AiService` activo o
  /// la transcripción está vacía.
  Future<String?> reconcileTranscript({
    required VaultSession session,
    required String pageId,
    required String blockId,
  }) async {
    final ai = session.aiService;
    if (ai == null) return null;

    final page = _pageById(session, pageId);
    if (page == null) return null;
    final block = _blockById(page, blockId);
    if (block == null) return null;

    final rawTranscript = block.text.trim();
    if (rawTranscript.isEmpty) return null;

    final title = block.meetingNoteTitle?.trim().isNotEmpty == true
        ? block.meetingNoteTitle!.trim()
        : page.title;

    final prompt =
        'Eres un asistente experto en transcripción y diarización de reuniones. '
        'A continuación tienes una transcripción bruta de la reunión titulada "$title". '
        'La transcripción actual puede contener errores de detección de hablantes, como '
        'oraciones cortadas por error a mitad de frase y asignadas a otra persona, '
        'falsos cambios de turno o etiquetas genéricas ("Speaker 1", "Speaker 2").\n\n'
        'Tu tarea es corregir la transcripción y devolverla limpia siguiendo estrictamente estas reglas:\n'
        '1. Une las oraciones interrumpidas que claramente correspondan al mismo hablante.\n'
        '2. Si en la conversación se menciona explícitamente el nombre de un participante '
        '(ejemplo: "Hola Carlos", "gracias Ana", "como decía Pedro"), reemplaza "Speaker N" '
        'por el nombre correspondiente con certeza contextual.\n'
        '3. Cada intervención debe seguir el formato: "[Hablante o Nombre]: [Texto de la intervención]".\n'
        '4. Mantén fielmente el contenido hablado en el idioma original, sin inventar ni omitir ideas.\n'
        '5. Devuelve EXCLUSIVAMENTE las líneas de la transcripción, sin introducciones, '
        'sin comentarios ni bloques de código markdown ```.\n\n'
        'Transcripción bruta:\n$rawTranscript';

    final result = await ai.complete(
      AiCompletionRequest(
        prompt: prompt,
        model: 'auto',
        cloudInkOperation: 'meeting_note_reconcile',
        maxTokens: 2500,
      ),
    );

    var text = result.text.trim();
    if (text.isEmpty) return null;

    // Quitar delimitadores de código si el modelo los incluyó
    if (text.startsWith('```')) {
      final firstNewline = text.indexOf('\n');
      if (firstNewline != -1) {
        text = text.substring(firstNewline + 1);
      }
      if (text.endsWith('```')) {
        text = text.substring(0, text.length - 3).trim();
      }
    }

    if (text.isNotEmpty) {
      session.updateBlockText(pageId, blockId, text);
      return text;
    }
    return null;
  }

  /// Renombra todas las ocurrencias de un hablante en la transcripción.
  /// (Ejemplo: de "Speaker 1" a "Alejandro").
  String renameSpeaker({
    required VaultSession session,
    required String pageId,
    required String blockId,
    required String oldSpeaker,
    required String newSpeaker,
  }) {
    final page = _pageById(session, pageId);
    if (page == null) return '';
    final block = _blockById(page, blockId);
    if (block == null) return '';

    final safeOld = oldSpeaker.trim();
    final safeNew = newSpeaker.trim();
    if (safeOld.isEmpty || safeNew.isEmpty || safeOld == safeNew) {
      return block.text;
    }

    final pattern = RegExp(
      r'^(Speaker\s+\d+|[A-ZÁ-Úa-zá-ú0-9 _\-]+)(:)',
      multiLine: true,
    );

    final lines = block.text.split('\n');
    final updatedLines = <String>[];

    for (final line in lines) {
      final match = pattern.firstMatch(line);
      if (match != null) {
        final currentName = match.group(1)?.trim();
        if (currentName != null &&
            currentName.toLowerCase() == safeOld.toLowerCase()) {
          updatedLines.add('$safeNew:${line.substring(match.end)}');
          continue;
        }
      }
      updatedLines.add(line);
    }

    final newText = updatedLines.join('\n');
    session.updateBlockText(pageId, blockId, newText);
    return newText;
  }

  /// Fusiona dos hablantes en la transcripción (todas las intervenciones de
  /// [sourceSpeaker] pasan a pertenecer a [targetSpeaker]).
  String mergeSpeakers({
    required VaultSession session,
    required String pageId,
    required String blockId,
    required String sourceSpeaker,
    required String targetSpeaker,
  }) {
    return renameSpeaker(
      session: session,
      pageId: pageId,
      blockId: blockId,
      oldSpeaker: sourceSpeaker,
      newSpeaker: targetSpeaker,
    );
  }

  FolioPage? _pageById(VaultSession session, String id) {
    for (final p in session.pages) {
      if (p.id == id) return p;
    }
    return null;
  }

  FolioBlock? _blockById(FolioPage page, String blockId) {
    for (final b in page.blocks) {
      if (b.id == blockId) return b;
    }
    return null;
  }
}
