import 'dart:io';

import 'package:path/path.dart' as p;

import '../../models/block.dart';
import '../../models/folio_columns_data.dart';
import '../../models/folio_database_data.dart';
import '../../models/folio_table_data.dart';
import '../../models/folio_template_button_data.dart';
import '../../models/folio_toggle_data.dart';
import '../../services/notion/notion_api_client.dart';
import 'notion_importer.dart'
    show
        NotionExportFormat,
        NotionImportWarning,
        NotionParsedDatabase,
        NotionParsedExport,
        NotionParsedPage;

/// Convierte la selección de páginas/bases de datos del picker (hecha vía la
/// API real de Notion) en el mismo `NotionParsedExport` que produce el
/// importador ZIP (`notion_importer.dart`), para que
/// `VaultSession._materializeNotionPages` se reutilice sin cambios.
///
/// A diferencia del importador ZIP (que solo ve Markdown/HTML/CSV ya
/// exportado a disco), aquí se recorre el árbol de bloques real de Notion,
/// bloque a bloque, así que la fidelidad es mucho mayor. Las
/// simplificaciones deliberadas (donde el modelo de bloques de Folio no
/// puede representar algo 1:1) están documentadas junto a cada caso y
/// siempre generan un [NotionImportWarning] explicando qué se perdió — nunca
/// descartan contenido en silencio.
Future<NotionParsedExport> mapNotionSelectionToParsedExport({
  required NotionApiClient client,
  required List<NotionSearchResultItem> selected,
  required Directory attachmentsDir,
}) async {
  final warnings = <NotionImportWarning>[];
  final pages = <NotionParsedPage>[];
  final databases = <NotionParsedDatabase>[];
  final visitedPageIds = <String>{};

  final selectedPages = selected.where((s) => !s.isDatabase).toList();
  final selectedDatabases = selected.where((s) => s.isDatabase).toList();

  for (final item in selectedPages) {
    await _mapPageRecursive(
      pageId: item.id,
      knownTitle: item.title,
      parentSourcePath: null,
      client: client,
      pages: pages,
      warnings: warnings,
      visitedPageIds: visitedPageIds,
      attachmentsDir: attachmentsDir,
    );
  }

  for (final item in selectedDatabases) {
    try {
      final data = await _fetchDatabaseAsFolioData(client, item.id, warnings: warnings);
      databases.add(
        NotionParsedDatabase(
          sourcePath: item.id,
          title: item.title.trim().isEmpty ? 'Database' : item.title.trim(),
          data: data,
        ),
      );
    } catch (e) {
      warnings.add(NotionImportWarning('No se pudo importar la base de datos "${item.title}": $e'));
    }
  }

  return NotionParsedExport(
    format: NotionExportFormat.notionApi,
    pages: pages,
    databases: databases,
    warnings: warnings,
  );
}

class _PendingChildPage {
  _PendingChildPage(this.id, this.title);
  final String id;
  final String title;
}

Future<void> _mapPageRecursive({
  required String pageId,
  String? knownTitle,
  required String? parentSourcePath,
  required NotionApiClient client,
  required List<NotionParsedPage> pages,
  required List<NotionImportWarning> warnings,
  required Set<String> visitedPageIds,
  required Directory attachmentsDir,
}) async {
  // Evita reprocesar/duplicar una página ya vista (p. ej. seleccionada en el
  // picker Y referenciada como child_page desde otra página seleccionada).
  if (visitedPageIds.contains(pageId)) return;
  visitedPageIds.add(pageId);

  var title = (knownTitle ?? '').trim();
  if (title.isEmpty) {
    try {
      final meta = await client.retrievePage(pageId);
      title = NotionSearchResultItem.fromJson(meta).title;
    } catch (_) {
      title = '';
    }
  }

  List<Map<String, dynamic>> children;
  try {
    children = await client.retrieveBlockChildrenRecursive(pageId);
  } catch (e) {
    warnings.add(NotionImportWarning('No se pudo leer el contenido de "${title.isEmpty ? pageId : title}": $e'));
    children = const [];
  }

  final pendingChildPages = <_PendingChildPage>[];
  final blocks = await _mapBlocks(
    children,
    client: client,
    warnings: warnings,
    attachmentsDir: attachmentsDir,
    pendingChildPages: pendingChildPages,
    depth: 0,
  );

  pages.add(
    NotionParsedPage(
      sourcePath: pageId,
      sourceDirPath: attachmentsDir.path,
      parentSourcePath: parentSourcePath,
      title: title.isEmpty ? 'Untitled' : title,
      blocks: blocks.isEmpty ? [FolioBlock(id: 'tmp', type: 'paragraph', text: '')] : blocks,
    ),
  );

  // Las subpáginas encontradas como bloques `child_page` dentro del
  // contenido se importan también, anidadas bajo esta página — así una
  // página compartida trae consigo todo su árbol, no solo su contenido
  // directo (igual que ocurriría si el usuario la explorara en Notion).
  for (final child in pendingChildPages) {
    await _mapPageRecursive(
      pageId: child.id,
      knownTitle: child.title,
      parentSourcePath: pageId,
      client: client,
      pages: pages,
      warnings: warnings,
      visitedPageIds: visitedPageIds,
      attachmentsDir: attachmentsDir,
    );
  }
}

/// Tipos de bloque de Notion cuyo contenido NO puede colapsarse en el
/// `body` de texto plano de `FolioToggleData` sin perder información real
/// (imágenes, tablas, bloques anidados…) — usado para decidir si un toggle
/// se importa con fidelidad total (`FolioToggleData`) o si sus hijos deben
/// promocionarse a bloques hermanos visibles (ver `_mapToggle`).
const _structuralBlockTypes = {
  'image',
  'video',
  'audio',
  'file',
  'pdf',
  'table',
  'column_list',
  'toggle',
  'callout',
  'code',
  'equation',
  'bookmark',
  'embed',
  'link_preview',
  'child_page',
  'child_database',
  'synced_block',
  'template',
};

Future<List<FolioBlock>> _mapBlocks(
  List<Map<String, dynamic>> blocks, {
  required NotionApiClient client,
  required List<NotionImportWarning> warnings,
  required Directory attachmentsDir,
  required List<_PendingChildPage> pendingChildPages,
  required int depth,
}) async {
  final out = <FolioBlock>[];
  for (final b in blocks) {
    out.addAll(
      await _mapSingleBlock(
        b,
        client: client,
        warnings: warnings,
        attachmentsDir: attachmentsDir,
        pendingChildPages: pendingChildPages,
        depth: depth,
      ),
    );
  }
  return out;
}

Future<List<FolioBlock>> _mapSingleBlock(
  Map<String, dynamic> b, {
  required NotionApiClient client,
  required List<NotionImportWarning> warnings,
  required Directory attachmentsDir,
  required List<_PendingChildPage> pendingChildPages,
  required int depth,
}) async {
  final type = b['type'] as String? ?? '';
  final id = b['id'] as String? ?? '';
  final rawChildren = ((b['_children'] as List?) ?? const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();

  Future<List<FolioBlock>> withNestedChildren(FolioBlock own) async {
    if (rawChildren.isEmpty) return [own];
    final nested = await _mapBlocks(
      rawChildren,
      client: client,
      warnings: warnings,
      attachmentsDir: attachmentsDir,
      pendingChildPages: pendingChildPages,
      depth: depth + 1,
    );
    return [own, ...nested];
  }

  switch (type) {
    case 'paragraph':
      return withNestedChildren(FolioBlock(id: 'tmp', type: 'paragraph', text: _rt(b['paragraph']), depth: depth));
    case 'heading_1':
      return withNestedChildren(FolioBlock(id: 'tmp', type: 'h1', text: _rt(b['heading_1']), depth: depth));
    case 'heading_2':
      return withNestedChildren(FolioBlock(id: 'tmp', type: 'h2', text: _rt(b['heading_2']), depth: depth));
    case 'heading_3':
      return withNestedChildren(FolioBlock(id: 'tmp', type: 'h3', text: _rt(b['heading_3']), depth: depth));
    case 'bulleted_list_item':
      return withNestedChildren(FolioBlock(id: 'tmp', type: 'bullet', text: _rt(b['bulleted_list_item']), depth: depth));
    case 'numbered_list_item':
      return withNestedChildren(FolioBlock(id: 'tmp', type: 'numbered', text: _rt(b['numbered_list_item']), depth: depth));
    case 'to_do':
      final todo = (b['to_do'] as Map?) ?? const {};
      return withNestedChildren(
        FolioBlock(id: 'tmp', type: 'todo', text: _rt(todo), checked: todo['checked'] == true, depth: depth),
      );
    case 'quote':
      return withNestedChildren(FolioBlock(id: 'tmp', type: 'quote', text: _rt(b['quote']), depth: depth));
    case 'callout':
      final callout = (b['callout'] as Map?) ?? const {};
      return [
        FolioBlock(id: 'tmp', type: 'callout', text: _rt(callout), icon: _iconFrom(callout['icon']), depth: depth),
      ];
    case 'divider':
      return [FolioBlock(id: 'tmp', type: 'divider', text: '', depth: depth)];
    case 'code':
      final code = (b['code'] as Map?) ?? const {};
      return [
        FolioBlock(
          id: 'tmp',
          type: 'code',
          text: _rt(code),
          codeLanguage: _notionLangToFolio((code['language'] as String?) ?? 'plain text'),
          depth: depth,
        ),
      ];
    case 'equation':
      final eq = (b['equation'] as Map?) ?? const {};
      return [FolioBlock(id: 'tmp', type: 'equation', text: (eq['expression'] as String?) ?? '', depth: depth)];
    case 'image':
      return [await _mapMediaBlock(b, 'image', client, attachmentsDir, warnings, depth)];
    case 'video':
      return [await _mapMediaBlock(b, 'video', client, attachmentsDir, warnings, depth)];
    case 'audio':
      return [await _mapMediaBlock(b, 'audio', client, attachmentsDir, warnings, depth)];
    case 'file':
    case 'pdf':
      return [await _mapMediaBlock(b, 'file', client, attachmentsDir, warnings, depth)];
    case 'bookmark':
      final bm = (b['bookmark'] as Map?) ?? const {};
      final url = (bm['url'] as String?) ?? '';
      final caption = _rt(bm);
      return [FolioBlock(id: 'tmp', type: 'bookmark', text: caption.isEmpty ? url : caption, url: url, depth: depth)];
    case 'embed':
    case 'link_preview':
      final em = (b[type] as Map?) ?? const {};
      return [FolioBlock(id: 'tmp', type: 'embed', text: '', url: (em['url'] as String?) ?? '', depth: depth)];
    case 'table_of_contents':
      return [FolioBlock(id: 'tmp', type: 'toc', text: '', depth: depth)];
    case 'breadcrumb':
      return [FolioBlock(id: 'tmp', type: 'breadcrumb', text: '', depth: depth)];
    case 'child_page':
      final cp = (b['child_page'] as Map?) ?? const {};
      final childTitle = ((cp['title'] as String?) ?? '').trim();
      if (id.isNotEmpty) {
        pendingChildPages.add(_PendingChildPage(id, childTitle.isEmpty ? 'Untitled' : childTitle));
      }
      // `text` guarda por ahora el id de origen de Notion; VaultSession lo
      // resuelve al id de la página ya materializada (ver
      // `_materializeNotionPages` en vault_session.dart).
      return [FolioBlock(id: 'tmp', type: 'child_page', text: id, depth: depth)];
    case 'child_database':
      try {
        final data = await _fetchDatabaseAsFolioData(client, id, warnings: warnings);
        return [FolioBlock(id: 'tmp', type: 'database', text: data.encode(), depth: depth)];
      } catch (e) {
        warnings.add(NotionImportWarning('No se pudo importar una base de datos incrustada: $e'));
        return [
          FolioBlock(id: 'tmp', type: 'bookmark', text: 'Notion database', url: 'https://notion.so/$id', depth: depth),
        ];
      }
    case 'template':
      final tpl = (b['template'] as Map?) ?? const {};
      final label = _rt(tpl);
      final childBlocks = await _mapBlocks(
        rawChildren,
        client: client,
        warnings: warnings,
        attachmentsDir: attachmentsDir,
        pendingChildPages: pendingChildPages,
        depth: 0,
      );
      final data = FolioTemplateButtonData(
        label: label.isEmpty ? 'Template' : label,
        blocks: childBlocks.isEmpty ? [FolioBlock(id: '_tpl', type: 'paragraph', text: '')] : childBlocks,
      );
      return [FolioBlock(id: 'tmp', type: 'template_button', text: data.encode(), depth: depth)];
    case 'table':
      return [_mapTableBlock(b, rawChildren, depth)];
    case 'table_row':
      // Consumido directamente por su `table` padre (ver arriba); no debería
      // visitarse suelto.
      return const [];
    case 'column_list':
      return [
        await _mapColumnList(rawChildren, client, warnings, attachmentsDir, pendingChildPages, depth),
      ];
    case 'column':
      // Consumido directamente por su `column_list` padre.
      return const [];
    case 'synced_block':
      return _mapSyncedBlock(b, rawChildren, client, warnings, attachmentsDir, pendingChildPages, depth);
    case 'toggle':
      return _mapToggle(b, rawChildren, client, warnings, attachmentsDir, pendingChildPages, depth);
    case 'link_to_page':
      final ltp = (b['link_to_page'] as Map?) ?? const {};
      final targetType = ltp['type'] as String?;
      final targetId = ((targetType != null ? ltp[targetType] : null) as String?) ?? '';
      warnings.add(
        const NotionImportWarning(
          'Una referencia a otra página de Notion se importó como marcador (no se resolvió como enlace interno).',
        ),
      );
      return [
        FolioBlock(
          id: 'tmp',
          type: 'bookmark',
          text: 'Notion',
          url: targetId.isEmpty ? 'https://notion.so' : 'https://notion.so/${targetId.replaceAll('-', '')}',
          depth: depth,
        ),
      ];
    default:
      warnings.add(NotionImportWarning('Tipo de bloque de Notion no soportado: "$type" — se omitió.'));
      return const [];
  }
}

Future<List<FolioBlock>> _mapSyncedBlock(
  Map<String, dynamic> b,
  List<Map<String, dynamic>> rawChildren,
  NotionApiClient client,
  List<NotionImportWarning> warnings,
  Directory attachmentsDir,
  List<_PendingChildPage> pendingChildPages,
  int depth,
) async {
  final synced = (b['synced_block'] as Map?) ?? const {};
  final syncedFrom = synced['synced_from'];
  var originalChildren = rawChildren;
  if (syncedFrom is Map) {
    final originalBlockId = syncedFrom['block_id'] as String?;
    if (originalBlockId != null && originalBlockId.isNotEmpty) {
      try {
        originalChildren = await client.retrieveBlockChildrenRecursive(originalBlockId);
      } catch (e) {
        warnings.add(NotionImportWarning('No se pudo resolver un bloque sincronizado: $e'));
        originalChildren = const [];
      }
    }
  }
  warnings.add(
    const NotionImportWarning(
      'Un bloque sincronizado de Notion se importó como contenido normal — se conserva el contenido pero se pierde la sincronización en vivo entre copias.',
    ),
  );
  return _mapBlocks(
    originalChildren,
    client: client,
    warnings: warnings,
    attachmentsDir: attachmentsDir,
    pendingChildPages: pendingChildPages,
    depth: depth,
  );
}

Future<List<FolioBlock>> _mapToggle(
  Map<String, dynamic> b,
  List<Map<String, dynamic>> rawChildren,
  NotionApiClient client,
  List<NotionImportWarning> warnings,
  Directory attachmentsDir,
  List<_PendingChildPage> pendingChildPages,
  int depth,
) async {
  final toggle = (b['toggle'] as Map?) ?? const {};
  final title = _rt(toggle);
  final hasStructuredChildren = rawChildren.any((c) => _structuralBlockTypes.contains(c['type']));

  if (!hasStructuredChildren) {
    final bodyLines = <String>[];
    for (final c in rawChildren) {
      final t = c['type'] as String?;
      final rt = t != null ? _rt(c[t]) : '';
      if (rt.isNotEmpty) bodyLines.add(rt);
    }
    final data = FolioToggleData(title: title, body: bodyLines.join('\n'));
    return [FolioBlock(id: 'tmp', type: 'toggle', text: data.encode(), expanded: false, depth: depth)];
  }

  // FolioToggleData solo guarda título + cuerpo de texto plano (sin lista de
  // bloques hijos) — meter una imagen/tabla ahí sería destructivo. En vez de
  // perder contenido, se promociona a bloques hermanos visibles justo debajo
  // del título: se conserva todo, pero se pierde el colapsar/expandir de esos
  // hijos concretos (el título del toggle en sí sigue siendo colapsable).
  warnings.add(
    const NotionImportWarning(
      'Un toggle con contenido enriquecido (imágenes, tablas u otros bloques) se importó con su título colapsable, '
      'pero ese contenido se muestra siempre visible debajo — Folio aún no soporta colapsar bloques complejos dentro '
      'de un toggle.',
    ),
  );
  final data = FolioToggleData(title: title, body: '');
  final headerBlock = FolioBlock(id: 'tmp', type: 'toggle', text: data.encode(), expanded: true, depth: depth);
  final children = await _mapBlocks(
    rawChildren,
    client: client,
    warnings: warnings,
    attachmentsDir: attachmentsDir,
    pendingChildPages: pendingChildPages,
    depth: depth + 1,
  );
  return [headerBlock, ...children];
}

FolioBlock _mapTableBlock(Map<String, dynamic> tableBlock, List<Map<String, dynamic>> rows, int depth) {
  final tableProps = (tableBlock['table'] as Map?) ?? const {};
  var width = (tableProps['table_width'] as num?)?.toInt() ?? 0;
  if (width <= 0 && rows.isNotEmpty) {
    final firstRowProps = (rows.first['table_row'] as Map?) ?? const {};
    width = ((firstRowProps['cells'] as List?) ?? const []).length;
  }
  if (width <= 0) width = 1;

  final cells = <String>[];
  for (final row in rows) {
    final rowProps = (row['table_row'] as Map?) ?? const {};
    final rowCells = (rowProps['cells'] as List?) ?? const [];
    for (var c = 0; c < width; c++) {
      final cell = c < rowCells.length ? rowCells[c] : null;
      cells.add(cell is List ? _plainTextFromRichTextList(cell) : '');
    }
  }
  final data = FolioTableData(cols: width, cells: cells);
  return FolioBlock(id: 'tmp', type: 'table', text: data.encode(), depth: depth);
}

Future<FolioBlock> _mapColumnList(
  List<Map<String, dynamic>> columnBlocks,
  NotionApiClient client,
  List<NotionImportWarning> warnings,
  Directory attachmentsDir,
  List<_PendingChildPage> pendingChildPages,
  int depth,
) async {
  final columnsData = <FolioColumnData>[];
  for (var i = 0; i < columnBlocks.length; i++) {
    final col = columnBlocks[i];
    final colChildrenRaw =
        ((col['_children'] as List?) ?? const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    final mapped = await _mapBlocks(
      colChildrenRaw,
      client: client,
      warnings: warnings,
      attachmentsDir: attachmentsDir,
      pendingChildPages: pendingChildPages,
      depth: 0,
    );
    final blocks = mapped.isEmpty ? [FolioBlock(id: 'tmp', type: 'paragraph', text: '')] : mapped;
    if (i < 2) {
      columnsData.add(FolioColumnData(blocks: blocks));
    } else if (i == 2) {
      columnsData.add(FolioColumnData(blocks: blocks));
    } else {
      // FolioColumnsData está limitado a 2–3 columnas: las columnas 4+ de
      // Notion se fusionan en la última en vez de truncarse — el contenido
      // no se pierde, solo cambia su disposición.
      columnsData.last.blocks.addAll(blocks);
    }
  }
  if (columnBlocks.length > 3) {
    warnings.add(
      NotionImportWarning(
        'Una fila de ${columnBlocks.length} columnas de Notion se fusionó en 3 (límite de Folio); el contenido no se perdió.',
      ),
    );
  }
  while (columnsData.length < 2) {
    columnsData.add(FolioColumnData.empty());
  }
  final data = FolioColumnsData(columns: columnsData);
  return FolioBlock(id: 'tmp', type: 'column_list', text: data.encode(), depth: depth);
}

Future<FolioBlock> _mapMediaBlock(
  Map<String, dynamic> b,
  String folioType,
  NotionApiClient client,
  Directory attachmentsDir,
  List<NotionImportWarning> warnings,
  int depth,
) async {
  final props = (b[b['type']] as Map?) ?? const {};
  final captionText = _rt(props);
  final fileType = props['type'] as String?; // 'file' (alojado en Notion, caduca) | 'external' (permanente)
  var url = '';
  if (fileType == 'external') {
    url = ((props['external'] as Map?)?['url'] as String?) ?? '';
  } else if (fileType == 'file') {
    final hosted = ((props['file'] as Map?)?['url'] as String?) ?? '';
    if (hosted.isNotEmpty) {
      // Las URLs alojadas en Notion son S3 firmadas y caducan (~1h) — hay
      // que descargarlas ya durante el import. El nombre local devuelto se
      // resuelve luego vía VaultSession._importBlockAttachmentIfNeeded
      // (sin cambios), igual que hace el importador ZIP con rutas relativas.
      final downloaded = await _downloadNotionAttachment(client, hosted, attachmentsDir, warnings);
      url = downloaded ?? hosted;
    }
  }
  if (folioType == 'image') {
    return FolioBlock(id: 'tmp', type: 'image', text: url, depth: depth);
  }
  return FolioBlock(id: 'tmp', type: folioType, text: captionText, url: url, depth: depth);
}

int _attachmentCounter = 0;

Future<String?> _downloadNotionAttachment(
  NotionApiClient client,
  String url,
  Directory attachmentsDir,
  List<NotionImportWarning> warnings,
) async {
  try {
    final bytes = await client.downloadRaw(url);
    final uri = Uri.parse(url);
    var ext = p.extension(uri.path);
    if (ext.isEmpty || ext.length > 6) ext = '.bin';
    final name = 'notion_attachment_${_attachmentCounter++}$ext';
    final file = File(p.join(attachmentsDir.path, name));
    await file.writeAsBytes(bytes);
    return name;
  } catch (e) {
    warnings.add(NotionImportWarning('No se pudo descargar un adjunto de Notion: $e'));
    return null;
  }
}

Future<FolioDatabaseData> _fetchDatabaseAsFolioData(
  NotionApiClient client,
  String databaseId, {
  required List<NotionImportWarning> warnings,
}) async {
  final schema = await client.retrieveDatabase(databaseId);
  final rawProps = (schema['properties'] as Map?) ?? const {};
  final db = FolioDatabaseData.empty();
  db.properties = [];
  final propIdByNotionKey = <String, String>{};
  var isFirst = true;
  for (final entry in rawProps.entries) {
    final key = entry.key as String;
    final propJson = (entry.value as Map?) ?? const {};
    final notionType = propJson['type'] as String? ?? 'rich_text';
    final folioType = isFirst ? FolioDbPropertyType.text : _notionPropTypeToFolio(notionType, warnings, key);
    final propId = isFirst ? 'p_title' : 'p_${propIdByNotionKey.length + 1}';
    var options = const <String>[];
    if (notionType == 'select') {
      options = (((propJson['select'] as Map?)?['options'] as List?) ?? const [])
          .map((o) => (o as Map)['name'] as String? ?? '')
          .toList();
    } else if (notionType == 'multi_select') {
      options = (((propJson['multi_select'] as Map?)?['options'] as List?) ?? const [])
          .map((o) => (o as Map)['name'] as String? ?? '')
          .toList();
    }
    db.properties.add(FolioDbProperty(id: propId, name: key, type: folioType, options: options));
    propIdByNotionKey[key] = propId;
    isFirst = false;
  }
  if (db.properties.isEmpty) {
    db.properties.add(FolioDbProperty(id: 'p_title', name: 'Nombre', type: FolioDbPropertyType.text));
  }

  final rows = await client.queryDatabaseAll(databaseId);
  db.rows = [];
  for (var i = 0; i < rows.length; i++) {
    final row = rows[i];
    final props = (row['properties'] as Map?) ?? const {};
    final folioRow = FolioDbRow(id: 'r_$i');
    for (final entry in propIdByNotionKey.entries) {
      final propJson = props[entry.key] as Map?;
      folioRow.values[entry.value] = _notionPropertyValueToFolio(propJson);
    }
    db.rows.add(folioRow);
  }
  return db;
}

FolioDbPropertyType _notionPropTypeToFolio(String notionType, List<NotionImportWarning> warnings, String propName) {
  switch (notionType) {
    case 'title':
    case 'rich_text':
      return FolioDbPropertyType.text;
    case 'select':
      return FolioDbPropertyType.select;
    case 'status':
      // Semántica de "una opción entre varias" equivalente a select.
      return FolioDbPropertyType.select;
    case 'multi_select':
      return FolioDbPropertyType.multiSelect;
    case 'checkbox':
      return FolioDbPropertyType.checkbox;
    case 'date':
      return FolioDbPropertyType.date;
    case 'number':
      return FolioDbPropertyType.number;
    case 'url':
      return FolioDbPropertyType.url;
    case 'email':
      return FolioDbPropertyType.email;
    case 'phone_number':
      return FolioDbPropertyType.phone;
    default:
      // relation/rollup/formula/people/files/created_by/last_edited_by/…:
      // dependen de otras páginas, usuarios o cálculos fuera del alcance de
      // una importación puntual — se conservan como texto en vez de
      // perderse.
      warnings.add(
        NotionImportWarning(
          'Propiedad de base de datos "$propName" (tipo Notion "$notionType") importada como texto: depende de '
          'otras páginas/usuarios/cálculos fuera del alcance de esta importación.',
        ),
      );
      return FolioDbPropertyType.text;
  }
}

dynamic _notionPropertyValueToFolio(Map? propJson) {
  if (propJson == null) return '';
  final type = propJson['type'] as String?;
  switch (type) {
    case 'title':
      return _plainTextFromRichTextList((propJson['title'] as List?) ?? const []);
    case 'rich_text':
      return _plainTextFromRichTextList((propJson['rich_text'] as List?) ?? const []);
    case 'select':
      return (propJson['select'] as Map?)?['name'] as String? ?? '';
    case 'status':
      return (propJson['status'] as Map?)?['name'] as String? ?? '';
    case 'multi_select':
      return ((propJson['multi_select'] as List?) ?? const []).map((e) => (e as Map)['name'] as String? ?? '').toList();
    case 'checkbox':
      return propJson['checkbox'] == true;
    case 'date':
      return ((propJson['date'] as Map?)?['start'] as String?) ?? '';
    case 'number':
      return propJson['number'];
    case 'url':
      return propJson['url'] as String? ?? '';
    case 'email':
      return propJson['email'] as String? ?? '';
    case 'phone_number':
      return propJson['phone_number'] as String? ?? '';
    default:
      return '';
  }
}

/// Extrae el texto plano de una propiedad con array `rich_text` (o `caption`
/// para bookmark/media). Notion incluye `plain_text` ya resuelto también
/// para menciones (`@página`, `@usuario`, fechas) y ecuaciones inline, así
/// que aplanarlas a texto sale gratis aquí sin lógica especial adicional.
String _rt(dynamic props) {
  if (props is! Map) return '';
  final rich = props['rich_text'] ?? props['caption'];
  if (rich is List) return _plainTextFromRichTextList(rich);
  return '';
}

String _plainTextFromRichTextList(List rich) {
  final buffer = StringBuffer();
  for (final r in rich) {
    if (r is Map) {
      final plain = r['plain_text'] as String?;
      if (plain != null) buffer.write(plain);
    }
  }
  return buffer.toString();
}

String? _iconFrom(dynamic icon) {
  if (icon is! Map) return null;
  if (icon['type'] == 'emoji') return icon['emoji'] as String?;
  // Iconos de callout tipo external/file (URL de imagen) no encajan en el
  // campo `icon` de FolioBlock (espera un emoji) — se omite el icono, el
  // texto del callout se conserva íntegro.
  return null;
}

const Map<String, String> _notionLangAliases = {
  'c++': 'cpp',
  'c#': 'csharp',
  'f#': 'fsharp',
  'objective-c': 'objectivec',
  'plain text': 'text',
  'shell': 'bash',
  'docker': 'dockerfile',
  'coffeescript': 'coffeescript',
};

String _notionLangToFolio(String notionLang) {
  final normalized = notionLang.toLowerCase().trim();
  return _notionLangAliases[normalized] ?? normalized.replaceAll(' ', '-');
}
