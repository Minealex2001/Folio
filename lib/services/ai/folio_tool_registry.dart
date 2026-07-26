import 'package:uuid/uuid.dart';

import '../../models/block.dart';
import '../../models/folio_page.dart';
import '../../models/folio_task_data.dart';
import '../../session/vault_session.dart';
import 'ai_tool.dart';
import 'quill_tools.dart';

/// Resultado del diálogo de permiso de lectura MCP.
enum McpReadAccessDecision {
  /// El usuario deniega; no se filtra contenido.
  deny,

  /// Lectura permitida solo esta vez; no se guarda en la allowlist.
  allowOnce,

  /// Lectura permitida y la página se añade a la allowlist.
  allowAndRemember,
}

/// Puente entre el bucle de tool-calling genérico ([ai_tool_loop.dart]) y las
/// mutaciones reales del vault. Cada tool envuelve un método ya existente de
/// [VaultSession]/[QuillToolExecutor] — esta clase no reimplementa lógica de
/// dominio, solo traduce `AiToolCall.arguments` a esas llamadas y su
/// resultado a un [AiToolResult] serializable que el modelo pueda leer.
class FolioToolRegistry {
  FolioToolRegistry(
    this._session, {
    this.scopePageId,
    this.onRequestMcpReadAccess,
    this.onConfirmIrreversibleTool,
  });

  final VaultSession _session;

  /// Página "actual" del chat, usada cuando una tool recibe `pageId: 'current'`
  /// o no se especifica `pageId` y la operación lo requiere.
  final String? scopePageId;

  /// Si no es null, se aplica la allowlist MCP: lectura solo de páginas
  /// autorizadas; si falta permiso, se pide confirmación vía este callback.
  /// Quill interno deja este campo null (lectura libre).
  final Future<McpReadAccessDecision> Function(String pageId, String pageTitle)?
      onRequestMcpReadAccess;

  /// Si no es null, se pide confirmación antes de ejecutar tools irreversibles
  /// (`permanently_delete_page`, `empty_trash`). Solo lo pasa el modo Plan al
  /// ejecutar un plan aprobado; la ruta normal y MCP dejan null.
  final Future<bool> Function(String toolName, Map<String, dynamic> arguments)?
      onConfirmIrreversibleTool;

  static const _uuid = Uuid();

  static const _localMediaBlockTypes = {'image', 'file', 'video', 'audio'};

  bool get _enforceMcpReadGate => onRequestMcpReadAccess != null;

  List<AiToolDefinition> get definitions => [
    // --- Fase 1: contenido (envuelven el comportamiento ya existente) ---
    _createPageDef,
    _appendBlocksDef,
    _replacePageBlocksDef,
    _editPageBlocksDef,
    _insertTodosDef,
    _insertTasksDef,
    _translateBilingualDef,
    _getPageContentDef,
    // --- Fase 2: gestión de libretas/páginas ---
    _createFolderDef,
    _renamePageDef,
    _movePageDef,
    _reorderPageDef,
    _duplicatePageDef,
    _setPageEmojiDef,
    _addPageTagDef,
    _removePageTagDef,
    _trashPageDef,
    _restorePageDef,
    _permanentlyDeletePageDef,
    _emptyTrashDef,
    _deleteFolderFlattenChildrenDef,
    _searchPagesDef,
    _listChildrenDef,
    _insertBlocksAtPositionDef,
    _listTasksDef,
    _updateTaskDef,
  ];

  Future<AiToolResult> execute(AiToolCall call) async {
    try {
      switch (call.name) {
        case 'create_page':
          return _createPage(call);
        case 'append_blocks_to_page':
          return _appendBlocksToPage(call);
        case 'replace_page_blocks':
          return _replacePageBlocks(call);
        case 'edit_page_blocks':
          return _editPageBlocks(call);
        case 'insert_todos':
          return _insertTodos(call);
        case 'insert_tasks':
          return _insertTasks(call);
        case 'translate_page_bilingual':
          return _translateBilingual(call);
        case 'get_page_content':
          return _getPageContent(call);
        case 'create_folder':
          return _createFolder(call);
        case 'rename_page':
          return _renamePage(call);
        case 'move_page':
          return _movePage(call);
        case 'reorder_page':
          return _reorderPage(call);
        case 'duplicate_page':
          return _duplicatePage(call);
        case 'set_page_emoji':
          return _setPageEmoji(call);
        case 'add_page_tag':
          return _addPageTag(call);
        case 'remove_page_tag':
          return _removePageTag(call);
        case 'trash_page':
          return _trashPage(call);
        case 'restore_page':
          return _restorePage(call);
        case 'permanently_delete_page':
          return _permanentlyDeletePage(call);
        case 'empty_trash':
          return _emptyTrash(call);
        case 'delete_folder_flatten_children':
          return _deleteFolderFlattenChildren(call);
        case 'search_pages':
          return _searchPages(call);
        case 'list_children':
          return _listChildren(call);
        case 'insert_blocks_at_position':
          return _insertBlocksAtPosition(call);
        case 'list_tasks':
          return _listTasks(call);
        case 'update_task':
          return _updateTask(call);
        default:
          return AiToolResult.error(call.id, 'Tool desconocido: ${call.name}');
      }
    } catch (e) {
      return AiToolResult.error(call.id, 'Error ejecutando ${call.name}: $e');
    }
  }

  // ---------------------------------------------------------------------
  // Helpers de argumentos y de resolución de página
  // ---------------------------------------------------------------------

  String _resolvePageId(Map<String, dynamic> args) {
    final raw = (args['pageId'] as String?)?.trim();
    if (raw == null || raw.isEmpty || raw == 'current') {
      return scopePageId ?? '';
    }
    return raw;
  }

  FolioPage? _pageById(String id) {
    for (final p in _session.pages) {
      if (p.id == id) return p;
    }
    return null;
  }

  List<FolioBlock> _blocksFromArgs(String pageId, Map<String, dynamic> args) {
    final raw = args['blocks'];
    if (raw is! List) return const [];
    final out = <FolioBlock>[];
    for (final entry in raw) {
      if (entry is! Map) continue;
      final type = (entry['type'] as String?)?.trim();
      final text = (entry['text'] as String?) ?? '';
      if (type == null || type.isEmpty) continue;
      out.add(
        FolioBlock(
          id: '${pageId}_${_uuid.v4()}',
          type: type,
          text: text,
          checked: entry['checked'] as bool?,
          codeLanguage: (entry['codeLanguage'] as String?)?.trim(),
          depth: (entry['depth'] as num?)?.toInt() ?? 0,
        ),
      );
    }
    return out;
  }

  Map<String, dynamic> _pageSummary(FolioPage p) => {
    'pageId': p.id,
    'title': p.title,
    'emoji': p.emoji,
    'parentId': p.parentId,
    'isFolder': p.isFolder,
    'tags': p.tags,
    'blockCount': p.blocks.length,
    'trashed': p.isTrashed,
  };

  // ---------------------------------------------------------------------
  // Fase 1 — contenido
  // ---------------------------------------------------------------------

  static const _createPageDef = AiToolDefinition(
    name: 'create_page',
    description:
        'Crea una página nueva en la libreta con un título y una lista de '
        'bloques de contenido ya redactados por el modelo. '
        'Obligatorio: "blocks" con contenido sustancial (varios bloques con texto); '
        'nunca crear una página vacía. Si piden diagramas, incluye type=mermaid.',
    parameters: [
      AiToolParam(
        name: 'title',
        type: 'string',
        description: 'Título de la nueva página.',
        required: true,
      ),
      AiToolParam(
        name: 'parentId',
        type: 'string',
        description:
            'Id de la carpeta/página padre. Omitir para crearla en la raíz.',
      ),
      AiToolParam(
        name: 'blocks',
        type: 'array',
        itemsType: 'object',
        description:
            'Bloques de contenido: [{type, text, checked?}]. type es uno de '
            'paragraph|h1|h2|h3|bullet|numbered|todo|task|quote|code|callout|'
            'toggle|divider|table|mermaid|equation. Requerido y no vacío.',
        required: true,
      ),
    ],
  );

  AiToolResult _createPage(AiToolCall call) {
    final args = call.arguments;
    final title = (args['title'] as String?)?.trim();
    if (title == null || title.isEmpty) {
      return AiToolResult.error(call.id, 'Falta "title" para crear la página.');
    }
    final parentId = (args['parentId'] as String?)?.trim();
    final id = _uuid.v4();
    final blocks = _blocksFromArgs(id, args);
    if (blocks.isEmpty) {
      return AiToolResult.error(
        call.id,
        'Falta contenido: "blocks" no puede estar vacío. '
        'Vuelve a llamar create_page con título y varios bloques con texto '
        '(h2, párrafos, listas; mermaid si piden diagramas).',
      );
    }
    _session.createPageWithId(
      id: id,
      title: title,
      parentId: (parentId == null || parentId.isEmpty) ? null : parentId,
      blocks: blocks,
    );
    return AiToolResult.ok(
      call.id,
      '{"pageId":"$id","title":${_jsonStr(title)},"blockCount":${blocks.length}}',
    );
  }

  static const _appendBlocksDef = AiToolDefinition(
    name: 'append_blocks_to_page',
    description: 'Añade bloques de contenido al final de una página existente.',
    parameters: [
      AiToolParam(
        name: 'pageId',
        type: 'string',
        description: 'Id de la página, o "current" para la página abierta.',
        required: true,
      ),
      AiToolParam(
        name: 'blocks',
        type: 'array',
        itemsType: 'object',
        description: 'Bloques a añadir: [{type, text, checked?}].',
        required: true,
      ),
    ],
  );

  AiToolResult _appendBlocksToPage(AiToolCall call) {
    final pageId = _resolvePageId(call.arguments);
    final page = _pageById(pageId);
    if (page == null) return AiToolResult.error(call.id, 'Página no encontrada: $pageId');
    final blocks = _blocksFromArgs(pageId, call.arguments);
    for (final b in blocks) {
      _session.appendBlock(pageId: pageId, block: b);
    }
    return AiToolResult.ok(call.id, '{"pageId":"$pageId","insertedBlockCount":${blocks.length}}');
  }

  static const _replacePageBlocksDef = AiToolDefinition(
    name: 'replace_page_blocks',
    description:
        'Reemplaza todo el contenido de una página (todos sus bloques) por '
        'una nueva lista de bloques. Útil para resumir o reescribir la página.',
    parameters: [
      AiToolParam(
        name: 'pageId',
        type: 'string',
        description: 'Id de la página, o "current" para la página abierta.',
        required: true,
      ),
      AiToolParam(
        name: 'blocks',
        type: 'array',
        itemsType: 'object',
        description: 'Nuevos bloques: [{type, text, checked?}].',
        required: true,
      ),
    ],
  );

  AiToolResult _replacePageBlocks(AiToolCall call) {
    final pageId = _resolvePageId(call.arguments);
    final page = _pageById(pageId);
    if (page == null) return AiToolResult.error(call.id, 'Página no encontrada: $pageId');
    final blocks = _blocksFromArgs(pageId, call.arguments);
    if (blocks.isEmpty) {
      return AiToolResult.error(call.id, 'No se especificaron bloques de reemplazo.');
    }
    _session.mutatePageBlocks(pageId, (list) {
      list
        ..clear()
        ..addAll(blocks);
    });
    return AiToolResult.ok(call.id, '{"pageId":"$pageId","blockCount":${blocks.length}}');
  }

  static const _editPageBlocksDef = AiToolDefinition(
    name: 'edit_page_blocks',
    description:
        'Aplica una lista de operaciones puntuales sobre los bloques de una '
        'página existente: update_block_text, delete_block, insert_after, '
        'insert_before.',
    parameters: [
      AiToolParam(
        name: 'pageId',
        type: 'string',
        description: 'Id de la página, o "current" para la página abierta.',
        required: true,
      ),
      AiToolParam(
        name: 'operations',
        type: 'array',
        itemsType: 'object',
        description:
            'Operaciones: [{kind, blockId, text?, type?, afterBlockId?, '
            'beforeBlockId?}]. kind es uno de update_block_text|delete_block|'
            'insert_after|insert_before.',
        required: true,
      ),
    ],
  );

  AiToolResult _editPageBlocks(AiToolCall call) {
    final pageId = _resolvePageId(call.arguments);
    final page = _pageById(pageId);
    if (page == null) return AiToolResult.error(call.id, 'Página no encontrada: $pageId');
    final rawOps = call.arguments['operations'];
    if (rawOps is! List || rawOps.isEmpty) {
      return AiToolResult.error(call.id, 'No se especificaron operaciones.');
    }
    var applied = 0;
    for (final rawOp in rawOps) {
      if (rawOp is! Map) continue;
      final op = Map<String, dynamic>.from(rawOp);
      final kind = (op['kind'] as String?)?.trim();
      switch (kind) {
        case 'update_block_text':
          final blockId = op['blockId'] as String?;
          final text = op['text'] as String?;
          if (blockId != null && text != null) {
            _session.updateBlockTextFull(pageId, blockId, text, null);
            applied++;
          }
        case 'delete_block':
          final blockId = op['blockId'] as String?;
          if (blockId != null) {
            _session.mutatePageBlocks(pageId, (blocks) {
              blocks.removeWhere((b) => b.id == blockId);
            });
            applied++;
          }
        case 'insert_after':
        case 'insert_before':
          final anchorId = (op['afterBlockId'] ?? op['beforeBlockId']) as String?;
          final type = (op['type'] as String?)?.trim();
          final text = (op['text'] as String?) ?? '';
          if (anchorId != null && type != null && type.isNotEmpty) {
            final block = FolioBlock(id: '${pageId}_${_uuid.v4()}', type: type, text: text);
            if (kind == 'insert_after') {
              _session.insertBlockAfter(pageId: pageId, afterBlockId: anchorId, block: block);
            } else {
              _session.insertBlockBefore(pageId: pageId, beforeBlockId: anchorId, block: block);
            }
            applied++;
          }
      }
    }
    if (applied == 0) {
      return AiToolResult.error(call.id, 'Ninguna operación pudo aplicarse.');
    }
    return AiToolResult.ok(call.id, '{"pageId":"$pageId","operationsApplied":$applied}');
  }

  static const _insertTodosDef = AiToolDefinition(
    name: 'insert_todos',
    description: 'Inserta bloques todo (una tarea simple por línea) al final de la página.',
    parameters: [
      AiToolParam(
        name: 'pageId',
        type: 'string',
        description: 'Id de la página, o "current".',
        required: true,
      ),
      AiToolParam(
        name: 'lines',
        type: 'array',
        itemsType: 'string',
        description: 'Una línea de texto por cada todo a crear.',
        required: true,
      ),
    ],
  );

  AiToolResult _insertTodos(AiToolCall call) {
    final pageId = _resolvePageId(call.arguments);
    if (_pageById(pageId) == null) return AiToolResult.error(call.id, 'Página no encontrada: $pageId');
    final lines = (call.arguments['lines'] as List?)?.map((e) => '$e').toList() ?? const [];
    QuillToolExecutor.insertTodosFromLines(_session, pageId: pageId, lines: lines);
    return AiToolResult.ok(call.id, '{"pageId":"$pageId","insertedCount":${lines.length}}');
  }

  static const _insertTasksDef = AiToolDefinition(
    name: 'insert_tasks',
    description: 'Inserta bloques task (tareas enriquecidas) al final de la página.',
    parameters: [
      AiToolParam(
        name: 'pageId',
        type: 'string',
        description: 'Id de la página, o "current".',
        required: true,
      ),
      AiToolParam(
        name: 'tasks',
        type: 'array',
        itemsType: 'string',
        description: 'Un título de tarea (o payload FolioTaskData) por elemento.',
        required: true,
      ),
    ],
  );

  AiToolResult _insertTasks(AiToolCall call) {
    final pageId = _resolvePageId(call.arguments);
    if (_pageById(pageId) == null) return AiToolResult.error(call.id, 'Página no encontrada: $pageId');
    final tasks = (call.arguments['tasks'] as List?)?.map((e) => '$e').toList() ?? const [];
    QuillToolExecutor.insertTasksFromEncodedLines(_session, pageId: pageId, payloads: tasks);
    return AiToolResult.ok(call.id, '{"pageId":"$pageId","insertedCount":${tasks.length}}');
  }

  static const _translateBilingualDef = AiToolDefinition(
    name: 'translate_page_bilingual',
    description:
        'Inserta, justo después de cada bloque original indicado, un bloque '
        'con su traducción ya generada por el modelo (traducción bilingüe en línea).',
    parameters: [
      AiToolParam(
        name: 'pageId',
        type: 'string',
        description: 'Id de la página, o "current".',
        required: true,
      ),
      AiToolParam(
        name: 'translations',
        type: 'array',
        itemsType: 'object',
        description: 'Traducciones: [{blockId, text}].',
        required: true,
      ),
    ],
  );

  AiToolResult _translateBilingual(AiToolCall call) {
    final pageId = _resolvePageId(call.arguments);
    if (_pageById(pageId) == null) return AiToolResult.error(call.id, 'Página no encontrada: $pageId');
    final raw = call.arguments['translations'];
    final translations = <BilingualBlockTranslation>[];
    if (raw is List) {
      for (final entry in raw) {
        if (entry is! Map) continue;
        final blockId = entry['blockId'] as String?;
        final text = entry['text'] as String?;
        if (blockId != null && text != null) {
          translations.add(BilingualBlockTranslation(blockId: blockId, text: text));
        }
      }
    }
    final inserted = QuillToolExecutor.insertBilingualTranslations(
      _session,
      pageId: pageId,
      translations: translations,
    );
    return AiToolResult.ok(call.id, '{"pageId":"$pageId","insertedCount":$inserted}');
  }

  static const _getPageContentDef = AiToolDefinition(
    name: 'get_page_content',
    description:
        'Lee el contenido completo de una página (metadatos + bloques con id). '
        'Vía MCP solo páginas en la allowlist; si no está autorizada, Folio '
        'pedirá permiso al usuario una vez.',
    parameters: [
      AiToolParam(
        name: 'pageId',
        type: 'string',
        description: 'Id de la página, o "current" para la página abierta.',
        required: true,
      ),
    ],
  );

  Future<AiToolResult> _getPageContent(AiToolCall call) async {
    final pageId = _resolvePageId(call.arguments);
    final page = _pageById(pageId);
    if (page == null) {
      return AiToolResult.error(call.id, 'Página no encontrada: $pageId');
    }
    final allowed = await _ensureMcpReadAccess(page);
    if (!allowed) {
      return AiToolResult.error(
        call.id,
        'Lectura denegada: la página no está en la allowlist MCP.',
      );
    }
    final blocksJson = page.blocks.map(_blockForMcpRead).map(_jsonMap).join(',');
    final propsJson = page.properties
        .map(
          (p) => _jsonMap({
            'name': p.name,
            'type': p.type.name,
            'value': p.value?.toString() ?? '',
          }),
        )
        .join(',');
    return AiToolResult.ok(
      call.id,
      '{'
      '"pageId":${_jsonStr(page.id)},'
      '"title":${_jsonStr(page.title)},'
      '"emoji":${_jsonStrOrNull(page.emoji)},'
      '"parentId":${_jsonStrOrNull(page.parentId)},'
      '"isFolder":${page.isFolder},'
      '"tags":[${page.tags.map(_jsonStr).join(',')}],'
      '"properties":[$propsJson],'
      '"blocks":[$blocksJson]'
      '}',
    );
  }

  Future<bool> _ensureMcpReadAccess(FolioPage page) async {
    if (!_enforceMcpReadGate) return true;
    if (_session.isMcpPageReadable(page.id)) return true;
    final gate = onRequestMcpReadAccess;
    if (gate == null) return false;
    final decision = await gate(page.id, page.title);
    switch (decision) {
      case McpReadAccessDecision.deny:
        return false;
      case McpReadAccessDecision.allowOnce:
        return true;
      case McpReadAccessDecision.allowAndRemember:
        _session.grantMcpPageReadable(page.id);
        return true;
    }
  }

  Map<String, dynamic> _blockForMcpRead(FolioBlock b) {
    final map = <String, dynamic>{
      'id': b.id,
      'type': b.type,
      'text': b.text,
      'depth': b.depth,
    };
    if (b.checked != null) map['checked'] = b.checked;
    if (b.codeLanguage != null && b.codeLanguage!.trim().isNotEmpty) {
      map['codeLanguage'] = b.codeLanguage!.trim();
    }
    if (b.icon != null && b.icon!.trim().isNotEmpty) {
      map['icon'] = b.icon!.trim();
    }
    final url = b.url?.trim() ?? '';
    if (url.isNotEmpty) {
      if (_localMediaBlockTypes.contains(b.type) && !_isRemoteUrl(url)) {
        map['url'] = '[local-attachment]';
      } else {
        map['url'] = url;
      }
    }
    return map;
  }

  bool _isRemoteUrl(String url) =>
      url.startsWith('http://') || url.startsWith('https://');

  // ---------------------------------------------------------------------
  // Fase 2 — gestión de libretas/páginas
  // ---------------------------------------------------------------------

  static const _createFolderDef = AiToolDefinition(
    name: 'create_folder',
    description:
        'Crea una libreta/carpeta nueva en el árbol. Pasa siempre un "title" '
        'descriptivo (nunca dejes el título por defecto genérico).',
    parameters: [
      AiToolParam(
        name: 'title',
        type: 'string',
        description: 'Título de la carpeta (obligatorio en la práctica; p. ej. "Física").',
        required: true,
      ),
      AiToolParam(
        name: 'parentId',
        type: 'string',
        description: 'Id de la carpeta padre. Omitir para crearla en la raíz.',
      ),
    ],
  );

  AiToolResult _createFolder(AiToolCall call) {
    final parentId = (call.arguments['parentId'] as String?)?.trim();
    final title = (call.arguments['title'] as String?)?.trim() ?? '';
    if (title.isEmpty) {
      return AiToolResult.error(
        call.id,
        'Falta "title" para create_folder. Elige un nombre concreto '
        '(p. ej. "Física"); no uses títulos genéricos.',
      );
    }
    final createdId = _session.addFolder(
      parentId: (parentId == null || parentId.isEmpty) ? null : parentId,
      title: title,
    );
    return AiToolResult.ok(
      call.id,
      '{"pageId":"$createdId","title":${_jsonStr(title)}}',
    );
  }

  static const _renamePageDef = AiToolDefinition(
    name: 'rename_page',
    description: 'Cambia el título de una página o libreta.',
    parameters: [
      AiToolParam(name: 'pageId', type: 'string', description: 'Id de la página.', required: true),
      AiToolParam(name: 'title', type: 'string', description: 'Nuevo título.', required: true),
    ],
  );

  AiToolResult _renamePage(AiToolCall call) {
    final pageId = (call.arguments['pageId'] as String?)?.trim() ?? '';
    final title = (call.arguments['title'] as String?)?.trim() ?? '';
    if (pageId.isEmpty || title.isEmpty) {
      return AiToolResult.error(call.id, 'Faltan "pageId" o "title".');
    }
    if (_pageById(pageId) == null) return AiToolResult.error(call.id, 'Página no encontrada: $pageId');
    _session.renamePage(pageId, title);
    return AiToolResult.ok(call.id, '{"pageId":"$pageId","title":${_jsonStr(title)}}');
  }

  static const _movePageDef = AiToolDefinition(
    name: 'move_page',
    description:
        'Mueve una página a otra carpeta (o a la raíz) y a una posición dentro '
        'de ese nuevo padre. Rechaza mover una página dentro de su propio descendiente.',
    parameters: [
      AiToolParam(name: 'pageId', type: 'string', description: 'Id de la página a mover.', required: true),
      AiToolParam(
        name: 'newParentId',
        type: 'string',
        description: 'Id del nuevo padre. Omitir o vacío para mover a la raíz.',
      ),
      AiToolParam(
        name: 'newIndex',
        type: 'integer',
        description: 'Posición dentro del nuevo padre (0 = primero).',
      ),
    ],
  );

  AiToolResult _movePage(AiToolCall call) {
    final pageId = (call.arguments['pageId'] as String?)?.trim() ?? '';
    if (pageId.isEmpty || _pageById(pageId) == null) {
      return AiToolResult.error(call.id, 'Página no encontrada: $pageId');
    }
    final newParentId = (call.arguments['newParentId'] as String?)?.trim();
    final newIndex = (call.arguments['newIndex'] as num?)?.toInt() ?? 0;
    if (newParentId != null &&
        newParentId.isNotEmpty &&
        _session.isUnderAncestor(ancestorId: pageId, nodeId: newParentId)) {
      return AiToolResult.error(call.id, 'No se puede mover una página dentro de su propio descendiente.');
    }
    _session.movePage(
      pageId: pageId,
      newParentId: (newParentId == null || newParentId.isEmpty) ? null : newParentId,
      newIndex: newIndex,
    );
    return AiToolResult.ok(call.id, '{"pageId":"$pageId","newParentId":${_jsonStrOrNull(newParentId)}}');
  }

  static const _reorderPageDef = AiToolDefinition(
    name: 'reorder_page',
    description: 'Cambia la posición de una página dentro de su padre actual, sin moverla de padre.',
    parameters: [
      AiToolParam(name: 'pageId', type: 'string', description: 'Id de la página.', required: true),
      AiToolParam(name: 'newIndex', type: 'integer', description: 'Nueva posición (0 = primero).', required: true),
    ],
  );

  AiToolResult _reorderPage(AiToolCall call) {
    final pageId = (call.arguments['pageId'] as String?)?.trim() ?? '';
    final page = _pageById(pageId);
    if (page == null) return AiToolResult.error(call.id, 'Página no encontrada: $pageId');
    final newIndex = (call.arguments['newIndex'] as num?)?.toInt() ?? 0;
    _session.reorderPageWithinParent(parentId: page.parentId, pageId: pageId, newIndex: newIndex);
    return AiToolResult.ok(call.id, '{"pageId":"$pageId","newIndex":$newIndex}');
  }

  static const _duplicatePageDef = AiToolDefinition(
    name: 'duplicate_page',
    description: 'Duplica una página existente (título y bloques) bajo el padre indicado.',
    parameters: [
      AiToolParam(name: 'pageId', type: 'string', description: 'Id de la página a duplicar.', required: true),
      AiToolParam(
        name: 'parentId',
        type: 'string',
        description: 'Padre para la copia. Omitir para usar el mismo padre que el original.',
      ),
    ],
  );

  AiToolResult _duplicatePage(AiToolCall call) {
    final pageId = (call.arguments['pageId'] as String?)?.trim() ?? '';
    final source = _pageById(pageId);
    if (source == null) return AiToolResult.error(call.id, 'Página no encontrada: $pageId');
    final parentId = (call.arguments['parentId'] as String?)?.trim();
    final createdId = _session.createPageFromTemplate(
      pageId,
      parentId: (parentId == null || parentId.isEmpty) ? source.parentId : parentId,
    );
    if (createdId == null) return AiToolResult.error(call.id, 'No se pudo duplicar la página.');
    return AiToolResult.ok(call.id, '{"pageId":"$createdId"}');
  }

  static const _setPageEmojiDef = AiToolDefinition(
    name: 'set_page_emoji',
    description: 'Cambia (o quita) el emoji/icono de una página.',
    parameters: [
      AiToolParam(name: 'pageId', type: 'string', description: 'Id de la página.', required: true),
      AiToolParam(name: 'emoji', type: 'string', description: 'Emoji nuevo, o vacío para quitarlo.'),
    ],
  );

  AiToolResult _setPageEmoji(AiToolCall call) {
    final pageId = (call.arguments['pageId'] as String?)?.trim() ?? '';
    if (_pageById(pageId) == null) return AiToolResult.error(call.id, 'Página no encontrada: $pageId');
    final emoji = (call.arguments['emoji'] as String?)?.trim();
    _session.setPageEmoji(pageId, (emoji == null || emoji.isEmpty) ? null : emoji);
    return AiToolResult.ok(call.id, '{"pageId":"$pageId"}');
  }

  static const _addPageTagDef = AiToolDefinition(
    name: 'add_page_tag',
    description: 'Añade una etiqueta a una página.',
    parameters: [
      AiToolParam(name: 'pageId', type: 'string', description: 'Id de la página.', required: true),
      AiToolParam(name: 'tag', type: 'string', description: 'Etiqueta a añadir.', required: true),
    ],
  );

  AiToolResult _addPageTag(AiToolCall call) {
    final pageId = (call.arguments['pageId'] as String?)?.trim() ?? '';
    final tag = (call.arguments['tag'] as String?)?.trim() ?? '';
    if (pageId.isEmpty || tag.isEmpty) return AiToolResult.error(call.id, 'Faltan "pageId" o "tag".');
    if (_pageById(pageId) == null) return AiToolResult.error(call.id, 'Página no encontrada: $pageId');
    _session.addPageTag(pageId, tag);
    return AiToolResult.ok(call.id, '{"pageId":"$pageId","tag":${_jsonStr(tag)}}');
  }

  static const _removePageTagDef = AiToolDefinition(
    name: 'remove_page_tag',
    description: 'Quita una etiqueta de una página.',
    parameters: [
      AiToolParam(name: 'pageId', type: 'string', description: 'Id de la página.', required: true),
      AiToolParam(name: 'tag', type: 'string', description: 'Etiqueta a quitar.', required: true),
    ],
  );

  AiToolResult _removePageTag(AiToolCall call) {
    final pageId = (call.arguments['pageId'] as String?)?.trim() ?? '';
    final tag = (call.arguments['tag'] as String?)?.trim() ?? '';
    if (pageId.isEmpty || tag.isEmpty) return AiToolResult.error(call.id, 'Faltan "pageId" o "tag".');
    if (_pageById(pageId) == null) return AiToolResult.error(call.id, 'Página no encontrada: $pageId');
    _session.removePageTag(pageId, tag);
    return AiToolResult.ok(call.id, '{"pageId":"$pageId","tag":${_jsonStr(tag)}}');
  }

  static const _trashPageDef = AiToolDefinition(
    name: 'trash_page',
    description: 'Mueve una página (y su subárbol) a la papelera.',
    parameters: [
      AiToolParam(name: 'pageId', type: 'string', description: 'Id de la página.', required: true),
    ],
  );

  AiToolResult _trashPage(AiToolCall call) {
    final pageId = (call.arguments['pageId'] as String?)?.trim() ?? '';
    if (_pageById(pageId) == null) return AiToolResult.error(call.id, 'Página no encontrada: $pageId');
    if (!_session.canMovePageToTrash(pageId)) {
      return AiToolResult.error(call.id, 'No se puede enviar a la papelera (dejaría el vault vacío).');
    }
    _session.movePageToTrash(pageId);
    return AiToolResult.ok(call.id, '{"pageId":"$pageId"}');
  }

  static const _restorePageDef = AiToolDefinition(
    name: 'restore_page',
    description: 'Restaura una página de la papelera.',
    parameters: [
      AiToolParam(name: 'pageId', type: 'string', description: 'Id de la página en papelera.', required: true),
    ],
  );

  AiToolResult _restorePage(AiToolCall call) {
    final pageId = (call.arguments['pageId'] as String?)?.trim() ?? '';
    final page = _pageById(pageId);
    if (page == null || !page.isTrashed) return AiToolResult.error(call.id, 'Página no está en la papelera: $pageId');
    _session.restoreFromTrash(pageId);
    return AiToolResult.ok(call.id, '{"pageId":"$pageId"}');
  }

  static const _permanentlyDeletePageDef = AiToolDefinition(
    name: 'permanently_delete_page',
    description: 'Borra permanentemente una página que ya está en la papelera. Irreversible.',
    parameters: [
      AiToolParam(name: 'pageId', type: 'string', description: 'Id de la página en papelera.', required: true),
    ],
  );

  Future<AiToolResult> _permanentlyDeletePage(AiToolCall call) async {
    final pageId = (call.arguments['pageId'] as String?)?.trim() ?? '';
    final page = _pageById(pageId);
    if (page == null || !page.isTrashed) return AiToolResult.error(call.id, 'Página no está en la papelera: $pageId');
    final confirm = onConfirmIrreversibleTool;
    if (confirm != null) {
      final ok = await confirm(call.name, call.arguments);
      if (!ok) {
        return AiToolResult.error(
          call.id,
          'Acción cancelada por el usuario: permanently_delete_page',
        );
      }
    }
    _session.permanentlyDeleteFromTrash(pageId);
    return AiToolResult.ok(call.id, '{"pageId":"$pageId"}');
  }

  static const _emptyTrashDef = AiToolDefinition(
    name: 'empty_trash',
    description: 'Vacía la papelera por completo. Irreversible.',
  );

  Future<AiToolResult> _emptyTrash(AiToolCall call) async {
    final confirm = onConfirmIrreversibleTool;
    if (confirm != null) {
      final ok = await confirm(call.name, call.arguments);
      if (!ok) {
        return AiToolResult.error(
          call.id,
          'Acción cancelada por el usuario: empty_trash',
        );
      }
    }
    _session.emptyTrash();
    return AiToolResult.ok(call.id, '{"emptied":true}');
  }

  static const _deleteFolderFlattenChildrenDef = AiToolDefinition(
    name: 'delete_folder_flatten_children',
    description:
        'Borra una carpeta pero mueve sus páginas hijas directas a la raíz en '
        'vez de borrarlas también.',
    parameters: [
      AiToolParam(name: 'folderId', type: 'string', description: 'Id de la carpeta.', required: true),
    ],
  );

  AiToolResult _deleteFolderFlattenChildren(AiToolCall call) {
    final folderId = (call.arguments['folderId'] as String?)?.trim() ?? '';
    final folder = _pageById(folderId);
    if (folder == null || !folder.isFolder) return AiToolResult.error(call.id, 'Carpeta no encontrada: $folderId');
    _session.deleteFolderMoveChildrenToRoot(folderId);
    return AiToolResult.ok(call.id, '{"folderId":"$folderId"}');
  }

  static const _searchPagesDef = AiToolDefinition(
    name: 'search_pages',
    description: 'Busca páginas por título o contenido y devuelve coincidencias con snippet.',
    parameters: [
      AiToolParam(name: 'query', type: 'string', description: 'Texto a buscar.', required: true),
      AiToolParam(name: 'limit', type: 'integer', description: 'Máximo de resultados (por defecto 10).'),
    ],
  );

  AiToolResult _searchPages(AiToolCall call) {
    final query = (call.arguments['query'] as String?)?.trim() ?? '';
    if (query.isEmpty) return AiToolResult.error(call.id, 'Falta "query".');
    final limit = (call.arguments['limit'] as num?)?.toInt() ?? 10;
    final results = _session.searchIndex.search(query, limit: limit);
    final encoded = results
        .map((r) {
          final readable =
              !_enforceMcpReadGate || _session.isMcpPageReadable(r.pageId);
          final snippet = readable ? r.snippet : '';
          final blockIdPart = r.blockId == null || r.blockId!.isEmpty
              ? '"blockId":null'
              : '"blockId":${_jsonStr(r.blockId!)}';
          return '{"pageId":${_jsonStr(r.pageId)},"pageTitle":${_jsonStr(r.pageTitle)},'
              '"snippet":${_jsonStr(snippet)},"matchKind":${_jsonStr(r.matchKind.name)},'
              '$blockIdPart,"contentReadable":$readable}';
        })
        .join(',');
    return AiToolResult.ok(call.id, '{"results":[$encoded]}');
  }

  static const _listChildrenDef = AiToolDefinition(
    name: 'list_children',
    description: 'Lista las páginas hijas directas de una carpeta/página (metadatos, no contenido).',
    parameters: [
      AiToolParam(
        name: 'pageId',
        type: 'string',
        description: 'Id de la página padre. Omitir o vacío para listar la raíz.',
      ),
    ],
  );

  AiToolResult _listChildren(AiToolCall call) {
    final pageId = (call.arguments['pageId'] as String?)?.trim();
    final children = (pageId == null || pageId.isEmpty)
        ? _session.pages.where((p) => p.parentId == null).toList()
        : _session.childrenOf(pageId);
    final encoded = children.map((p) => _jsonMap(_pageSummary(p))).join(',');
    return AiToolResult.ok(call.id, '{"children":[$encoded]}');
  }

  static const _insertBlocksAtPositionDef = AiToolDefinition(
    name: 'insert_blocks_at_position',
    description:
        'Inserta bloques en una posición concreta de la página: al inicio, al '
        'final, o justo antes/después de un bloque existente.',
    parameters: [
      AiToolParam(name: 'pageId', type: 'string', description: 'Id de la página, o "current".', required: true),
      AiToolParam(
        name: 'position',
        type: 'string',
        description: 'start | end | afterBlockId:<id> | beforeBlockId:<id>.',
        required: true,
      ),
      AiToolParam(
        name: 'blocks',
        type: 'array',
        itemsType: 'object',
        description: 'Bloques a insertar: [{type, text, checked?}].',
        required: true,
      ),
    ],
  );

  AiToolResult _insertBlocksAtPosition(AiToolCall call) {
    final pageId = _resolvePageId(call.arguments);
    if (_pageById(pageId) == null) return AiToolResult.error(call.id, 'Página no encontrada: $pageId');
    final blocks = _blocksFromArgs(pageId, call.arguments);
    if (blocks.isEmpty) return AiToolResult.error(call.id, 'No se especificaron bloques.');
    final position = (call.arguments['position'] as String?)?.trim() ?? 'end';
    if (position == 'start') {
      _session.mutatePageBlocks(pageId, (list) => list.insertAll(0, blocks));
    } else if (position.startsWith('afterBlockId:')) {
      final anchor = position.substring('afterBlockId:'.length);
      var cursor = anchor;
      for (final b in blocks) {
        _session.insertBlockAfter(pageId: pageId, afterBlockId: cursor, block: b);
        cursor = b.id;
      }
    } else if (position.startsWith('beforeBlockId:')) {
      final anchor = position.substring('beforeBlockId:'.length);
      for (final b in blocks) {
        _session.insertBlockBefore(pageId: pageId, beforeBlockId: anchor, block: b);
      }
    } else {
      for (final b in blocks) {
        _session.appendBlock(pageId: pageId, block: b);
      }
    }
    return AiToolResult.ok(call.id, '{"pageId":"$pageId","insertedBlockCount":${blocks.length}}');
  }

  static const _listTasksDef = AiToolDefinition(
    name: 'list_tasks',
    description:
        'Lista tareas enriquecidas del vault (bloques task). Filtros opcionales '
        'por estado, página, fechas y texto en el título.',
    parameters: [
      AiToolParam(
        name: 'status',
        type: 'string',
        description: 'Filtrar por status: todo | in_progress | done.',
      ),
      AiToolParam(
        name: 'pageId',
        type: 'string',
        description: 'Solo tareas de esta página.',
      ),
      AiToolParam(
        name: 'dueBefore',
        type: 'string',
        description: 'ISO date YYYY-MM-DD inclusive upper bound on dueDate.',
      ),
      AiToolParam(
        name: 'dueAfter',
        type: 'string',
        description: 'ISO date YYYY-MM-DD inclusive lower bound on dueDate.',
      ),
      AiToolParam(
        name: 'query',
        type: 'string',
        description: 'Subcadena en el título (case-insensitive).',
      ),
      AiToolParam(
        name: 'limit',
        type: 'number',
        description: 'Máximo de resultados (default 50).',
      ),
    ],
  );

  Future<AiToolResult> _listTasks(AiToolCall call) async {
    final status = (call.arguments['status'] as String?)?.trim().toLowerCase();
    final pageId = (call.arguments['pageId'] as String?)?.trim();
    final dueBefore = (call.arguments['dueBefore'] as String?)?.trim();
    final dueAfter = (call.arguments['dueAfter'] as String?)?.trim();
    final query = (call.arguments['query'] as String?)?.trim().toLowerCase();
    final limitRaw = call.arguments['limit'];
    final limit = limitRaw is num ? limitRaw.toInt().clamp(1, 200) : 50;

    var entries = _session.collectTaskBlocks(includeSimpleTodos: false);
    if (pageId != null && pageId.isNotEmpty) {
      entries = entries.where((e) => e.pageId == pageId).toList();
    }
    if (status != null && status.isNotEmpty) {
      entries = entries
          .where((e) => (e.task?.status ?? '').trim().toLowerCase() == status)
          .toList();
    }
    if (dueBefore != null && dueBefore.isNotEmpty) {
      entries = entries.where((e) {
        final d = (e.dueDate ?? '').trim();
        return d.isNotEmpty && d.compareTo(dueBefore) <= 0;
      }).toList();
    }
    if (dueAfter != null && dueAfter.isNotEmpty) {
      entries = entries.where((e) {
        final d = (e.dueDate ?? '').trim();
        return d.isNotEmpty && d.compareTo(dueAfter) >= 0;
      }).toList();
    }
    if (query != null && query.isNotEmpty) {
      entries = entries
          .where((e) => e.displayTitle.toLowerCase().contains(query))
          .toList();
    }

    final out = <Map<String, dynamic>>[];
    for (final e in entries.take(limit)) {
      final page = _pageById(e.pageId);
      if (page == null) continue;
      if (!(await _ensureMcpReadAccess(page))) continue;
      out.add({
        'pageId': e.pageId,
        'pageTitle': e.pageTitle,
        'blockId': e.blockId,
        'title': e.displayTitle,
        'status': e.task?.status ?? '',
        'dueDate': e.dueDate,
        'startDate': e.startDate,
        'priority': e.priority,
        'blocked': e.isBlocked,
      });
    }
    final encoded = out.map(_jsonMap).join(',');
    return AiToolResult.ok(call.id, '{"tasks":[$encoded],"count":${out.length}}');
  }

  static const _updateTaskDef = AiToolDefinition(
    name: 'update_task',
    description:
        'Actualiza campos de un bloque task existente (título, estado, fechas, '
        'prioridad, descripción, bloqueo).',
    parameters: [
      AiToolParam(
        name: 'pageId',
        type: 'string',
        description: 'Id de la página que contiene la tarea.',
        required: true,
      ),
      AiToolParam(
        name: 'blockId',
        type: 'string',
        description: 'Id del bloque task a actualizar.',
        required: true,
      ),
      AiToolParam(
        name: 'title',
        type: 'string',
        description: 'Nuevo título de la tarea.',
      ),
      AiToolParam(
        name: 'status',
        type: 'string',
        description: 'Nuevo estado (p. ej. todo, doing, done).',
      ),
      AiToolParam(
        name: 'dueDate',
        type: 'string',
        description: 'Fecha de vencimiento ISO (YYYY-MM-DD) o vacío para quitarla.',
      ),
      AiToolParam(
        name: 'priority',
        type: 'string',
        description: 'Prioridad de la tarea.',
      ),
      AiToolParam(
        name: 'description',
        type: 'string',
        description: 'Descripción o notas de la tarea.',
      ),
      AiToolParam(
        name: 'blocked',
        type: 'boolean',
        description: 'Si la tarea está bloqueada.',
      ),
      AiToolParam(
        name: 'blockedReason',
        type: 'string',
        description: 'Motivo del bloqueo.',
      ),
      AiToolParam(
        name: 'columnId',
        type: 'string',
        description: 'Id de columna del tablero (si aplica).',
      ),
    ],
  );

  Future<AiToolResult> _updateTask(AiToolCall call) async {
    final pageId = (call.arguments['pageId'] as String?)?.trim() ?? '';
    final blockId = (call.arguments['blockId'] as String?)?.trim() ?? '';
    if (pageId.isEmpty || blockId.isEmpty) {
      return AiToolResult.error(call.id, 'pageId y blockId son obligatorios.');
    }
    final page = _pageById(pageId);
    if (page == null) {
      return AiToolResult.error(call.id, 'Página no encontrada: $pageId');
    }
    FolioBlock? block;
    for (final b in page.blocks) {
      if (b.id == blockId) {
        block = b;
        break;
      }
    }
    if (block == null || block.type != 'task') {
      return AiToolResult.error(call.id, 'Bloque task no encontrado: $blockId');
    }
    final current = FolioTaskData.tryParse(block.text);
    if (current == null) {
      return AiToolResult.error(call.id, 'No se pudo parsear la tarea.');
    }
    var next = current;
    if (call.arguments.containsKey('title')) {
      next = next.copyWith(title: '${call.arguments['title'] ?? ''}'.trim());
    }
    if (call.arguments.containsKey('status')) {
      next = next.copyWith(status: '${call.arguments['status'] ?? ''}'.trim());
    }
    if (call.arguments.containsKey('dueDate')) {
      final v = '${call.arguments['dueDate'] ?? ''}'.trim();
      next = next.copyWith(dueDate: v.isEmpty ? null : v);
    }
    if (call.arguments.containsKey('priority')) {
      next = next.copyWith(priority: '${call.arguments['priority'] ?? ''}'.trim());
    }
    if (call.arguments.containsKey('description')) {
      next = next.copyWith(description: '${call.arguments['description'] ?? ''}');
    }
    if (call.arguments.containsKey('blocked')) {
      next = next.copyWith(blocked: call.arguments['blocked'] == true);
    }
    if (call.arguments.containsKey('blockedReason')) {
      next = next.copyWith(
        blockedReason: '${call.arguments['blockedReason'] ?? ''}'.trim(),
      );
    }
    if (call.arguments.containsKey('columnId')) {
      next = next.copyWith(columnId: '${call.arguments['columnId'] ?? ''}'.trim());
    }
    _session.updateBlockText(pageId, blockId, next.encode());
    return AiToolResult.ok(
      call.id,
      '{"pageId":"$pageId","blockId":"$blockId","updated":true}',
    );
  }

  // ---------------------------------------------------------------------
  // Encoding utils (evita tirar de dart:convert solo para mapas pequeños ya
  // controlados; sigue el mismo estilo que el resto del bridge)
  // ---------------------------------------------------------------------

  String _jsonStr(String s) => '"${s.replaceAll('\\', '\\\\').replaceAll('"', '\\"')}"';

  String _jsonStrOrNull(String? s) => s == null || s.isEmpty ? 'null' : _jsonStr(s);

  String _jsonMap(Map<String, dynamic> map) {
    final entries = map.entries.map((e) {
      final v = e.value;
      final encodedValue = switch (v) {
        null => 'null',
        String s => _jsonStr(s),
        bool b => b.toString(),
        num n => n.toString(),
        List l => '[${l.map((e) => e is String ? _jsonStr(e) : e).join(',')}]',
        _ => _jsonStr(v.toString()),
      };
      return '${_jsonStr(e.key)}:$encodedValue';
    }).join(',');
    return '{$entries}';
  }
}
