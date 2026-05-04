import 'package:uuid/uuid.dart';

import '../../models/block.dart';
import '../../models/folio_task_data.dart';
import '../../session/vault_session.dart';

/// Nombre estable de herramienta local ejecutable sin alucinar `blockId`.
enum QuillToolKind {
  insertTodosFromLines,
  insertTasksFromEncodedLines,
}

/// Llamada a herramienta (fase 2 del agente Quill).
class QuillToolCall {
  const QuillToolCall({
    required this.kind,
    required this.pageId,
    this.lines,
    this.taskPayloads,
  });

  final QuillToolKind kind;
  final String pageId;

  /// Líneas de texto para bloques `todo`.
  final List<String>? lines;

  /// Cada elemento: JSON [FolioTaskData] válido o título plano para una tarea.
  final List<String>? taskPayloads;
}

/// Ejecuta herramientas deterministas sobre la libreta.
class QuillToolExecutor {
  QuillToolExecutor._();

  static const _uuid = Uuid();

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
    }
  }
}
