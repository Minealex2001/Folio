import 'package:uuid/uuid.dart';

import '../models/block.dart';
import '../models/folio_page.dart';
import '../models/folio_task_data.dart';
import '../services/ai/ai_types.dart';
import '../session/vault_session.dart';
import 'ai/quill_tools.dart';

enum MeetingNoteType {
  general,
  oneOnOne,
  standup,
  kickoff,
  clientSync,
}

/// Genera notas de preparación (agenda sugerida, preguntas, temas) para un
/// `meeting_note` antes de empezar a grabar (Fase 6 de la evolución del
/// bloque, inspirada en el "Meeting Setup Wizard" de Call.md).
///
/// No implementa su propio proveedor de IA ni su propio contexto: reutiliza
/// el `AiService` activo de la sesión (`VaultSession.aiService`, ya resuelto
/// según `AppSettings.aiProvider` — local u opt-in cloud) y el bundle de
/// contexto de `VaultSession.backlinkPagesFor`/`childrenOf` (el mismo dato
/// que expone la tool MCP `meeting_get_context`).
class MeetingNotePreparationService {
  MeetingNotePreparationService._();
  static final MeetingNotePreparationService instance =
      MeetingNotePreparationService._();

  static const _uuid = Uuid();

  /// Genera y persiste `meetingNotePrepNotes` para el bloque. Devuelve el
  /// texto generado, o `null` si no hay `AiService` activo (sin IA
  /// configurada) o si el bloque/página no existen.
  Future<String?> generate({
    required VaultSession session,
    required String pageId,
    required String blockId,
    MeetingNoteType type = MeetingNoteType.general,
    String? participants,
  }) async {
    final ai = session.aiService;
    if (ai == null) return null;

    final page = _pageById(session, pageId);
    if (page == null) return null;
    final block = _blockById(page, blockId);
    if (block == null) return null;

    final parent = page.parentId != null ? _pageById(session, page.parentId!) : null;
    final children = session.childrenOf(pageId);
    final related = session.backlinkPagesFor(pageId);

    final contextLines = StringBuffer();
    if (parent != null) {
      contextLines.writeln('Página padre: ${parent.title}');
    }
    if (children.isNotEmpty) {
      contextLines.writeln(
        'Subpáginas: ${children.map((p) => p.title).join(', ')}',
      );
    }
    if (related.isNotEmpty) {
      contextLines.writeln(
        'Páginas relacionadas: ${related.map((p) => p.title).join(', ')}',
      );
    }
    if (page.tags.isNotEmpty) {
      contextLines.writeln('Tags: ${page.tags.join(', ')}');
    }
    if (participants != null && participants.trim().isNotEmpty) {
      contextLines.writeln('Participantes / Asistentes: ${participants.trim()}');
    }

    // Contexto profundo: bloques ya redactados en la página actual.
    final pageBlocksContent = StringBuffer();
    for (final b in page.blocks) {
      if (b.id == blockId) continue;
      final t = b.text.trim();
      if (t.isNotEmpty && b.type != 'meeting_note') {
        pageBlocksContent.writeln('- $t');
      }
      if (pageBlocksContent.length > 1500) break;
    }
    if (pageBlocksContent.isNotEmpty) {
      contextLines.writeln('Contenido existente en la página:\n$pageBlocksContent');
    }

    // Continuidad: acuerdos o tareas de reuniones previas en la misma página.
    final priorNotes = StringBuffer();
    for (final b in page.blocks) {
      if (b.id == blockId || b.type != 'meeting_note') continue;
      final summary = b.meetingNoteSummary;
      if (summary != null) {
        final keyPoints = summary['keyPoints'];
        final actionItems = summary['actionItems'];
        if (keyPoints is List && keyPoints.isNotEmpty) {
          priorNotes.writeln('Acuerdos de reunión previa: ${keyPoints.take(3).join('; ')}');
        }
        if (actionItems is List && actionItems.isNotEmpty) {
          final titles = actionItems
              .map((a) => a is Map ? a['title'] : null)
              .whereType<String>()
              .take(3);
          if (titles.isNotEmpty) {
            priorNotes.writeln('Tareas abiertas previas: ${titles.join('; ')}');
          }
        }
      }
    }
    if (priorNotes.isNotEmpty) {
      contextLines.writeln('Historial de reuniones previas:\n$priorNotes');
    }

    final title = block.meetingNoteTitle?.trim().isNotEmpty == true
        ? block.meetingNoteTitle!.trim()
        : page.title;

    final typeInstruction = switch (type) {
      MeetingNoteType.oneOnOne =>
        'Esta reunión es un 1 a 1 (1:1 / feedback / desarrollo personal).\n'
        'Estructura el Markdown con exactamente estas tres secciones:\n'
        '## Agenda sugerida\n## Preguntas a hacer\n## Temas a cubrir\n'
        'Focalízate en objetivos personales, bienestar, bloqueos y feedback mutuo.',
      MeetingNoteType.standup =>
        'Esta reunión es un seguimiento ágil (Daily / Standup / Status).\n'
        'Estructura el Markdown con exactamente estas tres secciones:\n'
        '## Agenda sugerida\n## Preguntas a hacer\n## Temas a cubrir\n'
        'Focalízate en avances inmediatos, bloqueos y dependencias.',
      MeetingNoteType.kickoff =>
        'Esta reunión es el arranque o planificación de un proyecto (Kickoff / Planning).\n'
        'Estructura el Markdown con exactamente estas tres secciones:\n'
        '## Agenda sugerida\n## Preguntas a hacer\n## Temas a cubrir\n'
        'Focalízate en visión, alcance, roles, dependencias técnicas y riesgos.',
      MeetingNoteType.clientSync =>
        'Esta reunión es con un cliente o reunión comercial (Client / Sales Sync).\n'
        'Estructura el Markdown con exactamente estas tres secciones:\n'
        '## Agenda sugerida\n## Preguntas a hacer\n## Temas a cubrir\n'
        'Focalízate en necesidades del cliente, plazos, propuesta y siguientes pasos.',
      MeetingNoteType.general =>
        'Genera notas de preparación breves y accionables en el idioma del título, '
        'en formato Markdown con exactamente estas tres secciones:\n'
        '## Agenda sugerida\n## Preguntas a hacer\n## Temas a cubrir',
    };

    final prompt =
        'Vas a preparar una reunión titulada "$title". Con el contexto '
        'disponible (puede estar incompleto), $typeInstruction\n\n'
        'Cada sección: 3-5 puntos como máximo, concretos, sin relleno. No '
        'inventes datos que no estén en el contexto — si falta información, '
        'formula la pregunta en vez de asumir una respuesta.\n\n'
        'Contexto disponible:\n${contextLines.isEmpty ? '(sin contexto adicional)' : contextLines.toString()}';

    final result = await ai.complete(
      AiCompletionRequest(
        prompt: prompt,
        model: 'auto',
        cloudInkOperation: 'meeting_note_prep',
        maxTokens: 750,
      ),
    );

    final text = result.text.trim();
    if (text.isEmpty) return null;

    session.updateBlockMeetingNotePrepNotes(pageId, blockId, text);
    return text;
  }

  /// Inserta las notas de preparación como bloques nativos Folio en la página
  /// directamente debajo del bloque de la reunión.
  int insertPrepAsBlocks({
    required VaultSession session,
    required String pageId,
    required String blockId,
  }) {
    final page = _pageById(session, pageId);
    if (page == null) return 0;
    final block = _blockById(page, blockId);
    if (block == null) return 0;
    final text = block.meetingNotePrepNotes?.trim();
    if (text == null || text.isEmpty) return 0;

    final lines = text.split('\n');
    var currentAnchorId = blockId;
    var insertedCount = 0;

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      FolioBlock newBlock;
      final newId = '${pageId}_${_uuid.v4()}';

      if (line.startsWith('## ')) {
        newBlock = FolioBlock(
          id: newId,
          type: 'h2',
          text: line.substring(3).trim(),
        );
      } else if (line.startsWith('### ')) {
        newBlock = FolioBlock(
          id: newId,
          type: 'h3',
          text: line.substring(4).trim(),
        );
      } else if (line.startsWith('- ') || line.startsWith('* ')) {
        newBlock = FolioBlock(
          id: newId,
          type: 'bullet',
          text: line.substring(2).trim(),
        );
      } else {
        newBlock = FolioBlock(
          id: newId,
          type: 'paragraph',
          text: line,
        );
      }

      session.insertBlockAfter(
        pageId: pageId,
        afterBlockId: currentAnchorId,
        block: newBlock,
      );
      currentAnchorId = newId;
      insertedCount++;
    }

    return insertedCount;
  }

  /// Genera una lista de sugerencias de checklist para previsualizar antes de insertar.
  Future<List<String>> suggestChecklistItems({
    required VaultSession session,
    required String pageId,
    required String blockId,
    MeetingNoteType type = MeetingNoteType.general,
  }) async {
    final ai = session.aiService;
    if (ai == null) return const [];

    final page = _pageById(session, pageId);
    if (page == null) return const [];
    final block = _blockById(page, blockId);
    if (block == null) return const [];

    final title = block.meetingNoteTitle?.trim().isNotEmpty == true
        ? block.meetingNoteTitle!.trim()
        : page.title;
    final prepNotes = block.meetingNotePrepNotes?.trim() ?? '';

    final typeHint = switch (type) {
      MeetingNoteType.oneOnOne => 'para una reunión 1 a 1 (alineación, feedback y seguimiento)',
      MeetingNoteType.standup => 'para una reunión de estado o daily (avances, blockers y tareas de hoy)',
      MeetingNoteType.kickoff => 'para un kickoff de proyecto (alcance, arquitectura y primeros pasos)',
      MeetingNoteType.clientSync => 'para una reunión con cliente (validación de acuerdos, plazos y propuesta)',
      MeetingNoteType.general => 'para la reunión "$title"',
    };

    final prompt =
        'Vas a generar un checklist de acciones concretas y accionables $typeHint. '
        'Devuelve exclusivamente una lista de items (verbo + objeto), uno por '
        'línea, sin viñetas, sin números, sin markdown ni explicaciones, máximo 7 items, '
        'en el idioma del título.\n\n'
        '${prepNotes.isEmpty ? '' : 'Notas de preparación ya generadas:\n$prepNotes\n\n'}'
        'Página: $title';

    final result = await ai.complete(
      AiCompletionRequest(
        prompt: prompt,
        model: 'auto',
        cloudInkOperation: 'meeting_note_checklist',
        maxTokens: 350,
      ),
    );

    final items = result.text
        .split('\n')
        .map((l) => l.replaceAll(RegExp(r'^\s*[-*•\d\.\)]\s*'), '').trim())
        .where((l) => l.isNotEmpty)
        .toList();

    return items;
  }

  /// Inserta una lista seleccionada de items de checklist como tareas reales de Folio.
  int insertSelectedChecklistItems({
    required VaultSession session,
    required String pageId,
    required String blockId,
    required List<String> items,
  }) {
    if (items.isEmpty) return 0;
    final payloads = items
        .map(
          (t) => FolioTaskData(
            title: t,
            status: 'todo',
            createdFromBlockId: blockId,
            aiContextPageId: pageId,
          ).encode(),
        )
        .toList();
    QuillToolExecutor.insertTasksFromEncodedLines(
      session,
      pageId: pageId,
      payloads: payloads,
    );
    return items.length;
  }

  /// Genera un checklist corto (Fase 7) a partir del contexto de la reunión
  /// (y de `meetingNotePrepNotes` si ya se generó) e inserta cada item como
  /// un bloque `task` normal, vinculado al meeting_note vía
  /// `createdFromBlockId` — reutiliza `QuillToolExecutor.insertTasksFromEncodedLines`,
  /// el mismo camino que usa la tool MCP `meeting_generate_checklist` y
  /// `insert_tasks`. Devuelve el número de items insertados (`0` si no hay
  /// `AiService` activo o el bloque/página no existen).
  Future<int> generateChecklist({
    required VaultSession session,
    required String pageId,
    required String blockId,
    MeetingNoteType type = MeetingNoteType.general,
  }) async {
    final items = await suggestChecklistItems(
      session: session,
      pageId: pageId,
      blockId: blockId,
      type: type,
    );
    if (items.isEmpty) return 0;
    return insertSelectedChecklistItems(
      session: session,
      pageId: pageId,
      blockId: blockId,
      items: items,
    );
  }

  /// Post-Meeting Intelligence (Fase 13): extrae resumen narrativo, key
  /// points y action items del transcript ya grabado. Extiende el mismo
  /// popover/servicio de extracción IA existente para meeting_note en vez
  /// de crear uno nuevo. Los action items se devuelven como texto — NO se
  /// crean tareas automáticamente aquí (eso es Fase 14, materialización
  /// explícita por el usuario item a item vía
  /// `VaultSession.setMeetingNoteSummaryActionItemTaskBlockId`).
  ///
  /// Devuelve el mapa persistido en `meetingNoteSummary`, o `null` si no
  /// hay `AiService` activo, el bloque/página no existen, o el transcript
  /// está vacío.
  Future<Map<String, Object?>?> generateSummary({
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
    final transcript = block.text.trim();
    if (transcript.isEmpty) return null;

    final title = block.meetingNoteTitle?.trim().isNotEmpty == true
        ? block.meetingNoteTitle!.trim()
        : page.title;

    final prompt =
        'Analiza esta transcripción de la reunión "$title" y genera un '
        'resumen estructurado en el idioma de la transcripción, en '
        'formato Markdown, con EXACTAMENTE estas tres secciones y nada '
        'más:\n'
        '## Summary\n(un párrafo breve, sin viñetas)\n'
        '## Key Points\n(viñetas "- ", agrupadas por tema si aplica, '
        'máximo 8)\n'
        '## Action Items\n(viñetas "- ", cada una una acción concreta '
        'verbo+objeto, máximo 8; vacío si no hay ninguna)\n\n'
        'No inventes decisiones ni acciones que no estén respaldadas por '
        'el texto.\n\n'
        'Transcripción:\n$transcript';

    final result = await ai.complete(
      AiCompletionRequest(
        prompt: prompt,
        model: 'auto',
        cloudInkOperation: 'meeting_note_summary',
        maxTokens: 900,
      ),
    );

    final text = result.text;
    final narrative = _extractSection(text, 'Summary');
    final keyPoints = _extractBullets(text, 'Key Points');
    final actionItemTitles = _extractBullets(text, 'Action Items');

    if (narrative.isEmpty && keyPoints.isEmpty && actionItemTitles.isEmpty) {
      return null;
    }

    final summary = <String, Object?>{
      'narrative': narrative,
      'keyPoints': keyPoints,
      'actionItems': [
        for (final t in actionItemTitles) {'title': t, 'taskBlockId': null},
      ],
    };
    session.updateBlockMeetingNoteSummary(pageId, blockId, summary);
    return summary;
  }

  /// Fase 14: materializa UN action item del resumen (Fase 13) como tarea
  /// real de Folio — reutiliza `QuillToolExecutor`, no un path de creación
  /// de tareas nuevo. Actualización explícita, item a item: la extracción
  /// nunca crea tareas por sí sola (ver `generateSummary`). Devuelve el id
  /// del bloque `task` creado, o `null` si el índice/summary no existen o
  /// el item ya estaba materializado.
  String? materializeActionItem({
    required VaultSession session,
    required String pageId,
    required String blockId,
    required int index,
  }) {
    final page = _pageById(session, pageId);
    if (page == null) return null;
    final block = _blockById(page, blockId);
    if (block == null) return null;
    final actionItems = block.meetingNoteSummary?['actionItems'];
    if (actionItems is! List || index < 0 || index >= actionItems.length) {
      return null;
    }
    final item = actionItems[index];
    if (item is! Map) return null;
    if (item['taskBlockId'] != null) return null;
    final title = (item['title'] as String?)?.trim() ?? '';
    if (title.isEmpty) return null;

    final taskBlock = FolioBlock(
      id: '${pageId}_${_uuid.v4()}',
      type: 'task',
      text: FolioTaskData(
        title: title,
        status: 'todo',
        createdFromBlockId: blockId,
        aiContextPageId: pageId,
      ).encode(),
    );
    session.appendBlock(pageId: pageId, block: taskBlock);
    session.setMeetingNoteSummaryActionItemTaskBlockId(
      pageId,
      blockId,
      index,
      taskBlock.id,
    );
    return taskBlock.id;
  }

  /// Extrae el texto entre un encabezado `## [heading]` y el siguiente `##`
  /// (o el final), como párrafo plano.
  String _extractSection(String text, String heading) {
    final headerRe = RegExp(
      r'^##\s*' + RegExp.escape(heading) + r'\s*$',
      multiLine: true,
      caseSensitive: false,
    );
    final match = headerRe.firstMatch(text);
    if (match == null) return '';
    final rest = text.substring(match.end);
    final nextHeader = RegExp(r'^##\s', multiLine: true).firstMatch(rest);
    final body = nextHeader != null ? rest.substring(0, nextHeader.start) : rest;
    return body.trim();
  }

  /// Extrae líneas con viñeta (`- `/`* `) dentro de una sección `## [heading]`.
  List<String> _extractBullets(String text, String heading) {
    final section = _extractSection(text, heading);
    if (section.isEmpty) return const [];
    return section
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.startsWith('- ') || l.startsWith('* '))
        .map((l) => l.substring(2).trim())
        .where((l) => l.isNotEmpty)
        .toList();
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
