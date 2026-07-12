import 'package:uuid/uuid.dart';

import '../../models/block.dart';
import '../../models/folio_page.dart';
import '../../models/folio_task_data.dart';
import '../../session/vault_session.dart';

/// Traducción bilingüe: texto traducido para un bloque existente.
class BilingualBlockTranslation {
  const BilingualBlockTranslation({
    required this.blockId,
    required this.text,
  });

  final String blockId;
  final String text;
}

/// Nombre estable de herramienta local ejecutable sin alucinar `blockId`.
enum QuillToolKind {
  insertTodosFromLines,
  insertTasksFromEncodedLines,
  translatePageBilingual,
}

/// Llamada a herramienta (fase 2 del agente Quill).
class QuillToolCall {
  const QuillToolCall({
    required this.kind,
    required this.pageId,
    this.lines,
    this.taskPayloads,
    this.bilingualTranslations,
  });

  final QuillToolKind kind;
  final String pageId;

  /// Líneas de texto para bloques `todo`.
  final List<String>? lines;

  /// Cada elemento: JSON [FolioTaskData] válido o título plano para una tarea.
  final List<String>? taskPayloads;

  /// Traducciones bilingües a insertar tras cada bloque original.
  final List<BilingualBlockTranslation>? bilingualTranslations;
}

/// Ejecuta herramientas deterministas sobre la libreta.
class QuillToolExecutor {
  QuillToolExecutor._();

  static const _uuid = Uuid();

  /// Tipos de bloque con texto traducible en modo bilingüe.
  static const translatableBlockTypes = {
    'paragraph',
    'h1',
    'h2',
    'h3',
    'bullet',
    'numbered',
    'todo',
    'task',
    'quote',
    'code',
    'callout',
    'toggle',
  };

  /// Inserta bloques `todo` al final de la página [pageId].
  static void insertTodosFromLines(
    VaultSession session, {
    required String pageId,
    required List<String> lines,
  }) {
    for (final raw in lines) {
      final t = raw.trim();
      if (t.isEmpty) continue;
      session.appendBlock(
        pageId: pageId,
        block: FolioBlock(
          id: '${pageId}_${_uuid.v4()}',
          type: 'todo',
          text: t,
          checked: false,
        ),
      );
    }
  }

  /// Inserta bloques `task` al final de la página [pageId].
  static void insertTasksFromEncodedLines(
    VaultSession session, {
    required String pageId,
    required List<String> payloads,
  }) {
    for (final raw in payloads) {
      final t = raw.trim();
      if (t.isEmpty) continue;
      final encoded = FolioTaskData.tryParse(t)?.encode() ??
          FolioTaskData(title: t, status: 'todo').encode();
      session.appendBlock(
        pageId: pageId,
        block: FolioBlock(
          id: '${pageId}_${_uuid.v4()}',
          type: 'task',
          text: encoded,
        ),
      );
    }
  }

  /// Inserta cada traducción justo después del bloque original (de abajo a
  /// arriba para no desplazar índices de inserción pendientes).
  static int insertBilingualTranslations(
    VaultSession session, {
    required String pageId,
    required List<BilingualBlockTranslation> translations,
  }) {
    if (translations.isEmpty) return 0;
    FolioPage? page;
    for (final p in session.pages) {
      if (p.id == pageId) {
        page = p;
        break;
      }
    }
    if (page == null) return 0;

    final ordered = <({int index, BilingualBlockTranslation item})>[];
    for (final t in translations) {
      final text = t.text.trim();
      if (text.isEmpty) continue;
      final idx = page.blocks.indexWhere((b) => b.id == t.blockId);
      if (idx < 0) continue;
      ordered.add((index: idx, item: t));
    }
    ordered.sort((a, b) => b.index.compareTo(a.index));

    var inserted = 0;
    for (final entry in ordered) {
      final original = page.blocks[entry.index];
      if (!translatableBlockTypes.contains(original.type)) continue;
      if (original.text.trim().isEmpty) continue;

      final translatedText = entry.item.text.trim();
      final block = FolioBlock(
        id: '${pageId}_${_uuid.v4()}',
        type: original.type,
        text: translatedText,
        checked: original.checked,
        expanded: original.expanded,
        codeLanguage: original.codeLanguage,
        depth: original.depth,
        icon: original.icon,
      );
      session.insertBlockAfter(
        pageId: pageId,
        afterBlockId: original.id,
        block: block,
      );
      inserted++;
    }
    return inserted;
  }

  static void execute(VaultSession session, QuillToolCall call) {
    switch (call.kind) {
      case QuillToolKind.insertTodosFromLines:
        insertTodosFromLines(
          session,
          pageId: call.pageId,
          lines: call.lines ?? const [],
        );
      case QuillToolKind.insertTasksFromEncodedLines:
        insertTasksFromEncodedLines(
          session,
          pageId: call.pageId,
          payloads: call.taskPayloads ?? const [],
        );
      case QuillToolKind.translatePageBilingual:
        insertBilingualTranslations(
          session,
          pageId: call.pageId,
          translations: call.bilingualTranslations ?? const [],
        );
    }
  }
}
