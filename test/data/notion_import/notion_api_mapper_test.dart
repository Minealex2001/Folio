import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:folio/data/notion_import/notion_api_mapper.dart';
import 'package:folio/models/folio_columns_data.dart';
import 'package:folio/models/folio_database_data.dart';
import 'package:folio/models/folio_table_data.dart';
import 'package:folio/models/folio_toggle_data.dart';
import 'package:folio/services/notion/notion_api_client.dart';

/// Construye un [NotionApiClient] cuyo transporte HTTP está interceptado:
/// las llamadas al proxy (`{method,path,accessToken,body}`) se enrutan por
/// `path` a [routes]; cualquier otra URL (descargas de adjuntos) se resuelve
/// con [onDownload].
NotionApiClient _fakeClient(
  Map<String, dynamic Function(Map<String, dynamic> body)> routes, {
  http.Response Function(Uri uri)? onDownload,
}) {
  final mock = MockClient((request) async {
    if (!request.url.path.endsWith('/api-proxy')) {
      if (onDownload != null) return onDownload(request.url);
      return http.Response('not found', 404);
    }
    final decoded = jsonDecode(utf8.decode(request.bodyBytes)) as Map<String, dynamic>;
    final path = decoded['path'] as String;
    // Las rutas paginadas del cliente incluyen query params en el GET (p.ej.
    // .../children?page_size=100&start_cursor=...) — el router matchea solo
    // el prefijo antes del '?'.
    final basePath = path.split('?').first;
    final handler = routes[basePath];
    // Sin `content-type: application/json`, el paquete http decodifica la
    // respuesta con latin1 por defecto (rompe con emoji/acentos en los
    // fixtures) — de ahí el header explícito en ambas respuestas de abajo.
    const jsonHeaders = {'content-type': 'application/json'};
    if (handler == null) {
      return http.Response.bytes(
        utf8.encode(jsonEncode({'status': 404, 'body': {'message': 'no route for $basePath'}})),
        200,
        headers: jsonHeaders,
      );
    }
    final result = handler(decoded);
    return http.Response.bytes(utf8.encode(jsonEncode({'status': 200, 'body': result})), 200, headers: jsonHeaders);
  });
  return NotionApiClient(accessToken: 'test-token', httpClient: mock);
}

Map<String, dynamic> _richText(String text) => {
  'rich_text': [
    {'plain_text': text},
  ],
};

Map<String, dynamic> _block(String type, Map<String, dynamic> props, {String id = 'blk', bool hasChildren = false}) => {
  'id': id,
  'type': type,
  'has_children': hasChildren,
  type: props,
};

Map<String, dynamic> _childrenPage(List<Map<String, dynamic>> blocks) => {
  'results': blocks,
  'has_more': false,
  'next_cursor': null,
};

void main() {
  group('mapNotionSelectionToParsedExport — bloques simples', () {
    test('mapea texto, encabezados, listas, todo, cita y divisor 1:1', () async {
      final tempDir = await Directory.systemTemp.createTemp('notion_mapper_test_');
      addTearDown(() => tempDir.delete(recursive: true));

      final client = _fakeClient({
        '/v1/blocks/page1/children': (_) => _childrenPage([
          _block('paragraph', _richText('Hola mundo'), id: 'b1'),
          _block('heading_1', _richText('Título 1'), id: 'b2'),
          _block('heading_2', _richText('Título 2'), id: 'b3'),
          _block('heading_3', _richText('Título 3'), id: 'b4'),
          _block('bulleted_list_item', _richText('Item bullet'), id: 'b5'),
          _block('numbered_list_item', _richText('Item numerado'), id: 'b6'),
          _block('to_do', {...(_richText('Tarea')), 'checked': true}, id: 'b7'),
          _block('quote', _richText('Una cita'), id: 'b8'),
          _block('divider', {}, id: 'b9'),
        ]),
      });

      final export = await mapNotionSelectionToParsedExport(
        client: client,
        selected: [NotionSearchResultItem(id: 'page1', object: 'page', title: 'Página 1')],
        attachmentsDir: tempDir,
      );

      expect(export.pages, hasLength(1));
      final blocks = export.pages.single.blocks;
      expect(blocks.map((b) => b.type).toList(), [
        'paragraph',
        'h1',
        'h2',
        'h3',
        'bullet',
        'numbered',
        'todo',
        'quote',
        'divider',
      ]);
      expect(blocks[0].text, 'Hola mundo');
      expect(blocks[6].checked, true);
      expect(export.warnings, isEmpty);
    });

    test('callout con icono emoji y code con lenguaje mapeado', () async {
      final tempDir = await Directory.systemTemp.createTemp('notion_mapper_test_');
      addTearDown(() => tempDir.delete(recursive: true));

      final client = _fakeClient({
        '/v1/blocks/page1/children': (_) => _childrenPage([
          _block('callout', {...(_richText('Ojo con esto')), 'icon': {'type': 'emoji', 'emoji': '⚠️'}}, id: 'b1'),
          _block('code', {...(_richText('print(1)')), 'language': 'python'}, id: 'b2'),
          _block('equation', {'expression': r'E=mc^2'}, id: 'b3'),
        ]),
      });

      final export = await mapNotionSelectionToParsedExport(
        client: client,
        selected: [NotionSearchResultItem(id: 'page1', object: 'page', title: 'Página 1')],
        attachmentsDir: tempDir,
      );

      final blocks = export.pages.single.blocks;
      expect(blocks[0].type, 'callout');
      expect(blocks[0].icon, '⚠️');
      expect(blocks[1].type, 'code');
      expect(blocks[1].codeLanguage, 'python');
      expect(blocks[2].type, 'equation');
      expect(blocks[2].text, r'E=mc^2');
    });
  });

  group('mapNotionSelectionToParsedExport — media y adjuntos', () {
    test('imagen externa se mantiene como URL sin descargar', () async {
      final tempDir = await Directory.systemTemp.createTemp('notion_mapper_test_');
      addTearDown(() => tempDir.delete(recursive: true));

      final client = _fakeClient({
        '/v1/blocks/page1/children': (_) => _childrenPage([
          _block('image', {
            'type': 'external',
            'external': {'url': 'https://example.com/pic.png'},
          }, id: 'b1'),
        ]),
      });

      final export = await mapNotionSelectionToParsedExport(
        client: client,
        selected: [NotionSearchResultItem(id: 'page1', object: 'page', title: 'Página 1')],
        attachmentsDir: tempDir,
      );

      expect(export.pages.single.blocks.single.text, 'https://example.com/pic.png');
      expect(tempDir.listSync(), isEmpty);
    });

    test('imagen alojada en Notion se descarga a un archivo local', () async {
      final tempDir = await Directory.systemTemp.createTemp('notion_mapper_test_');
      addTearDown(() => tempDir.delete(recursive: true));

      final client = _fakeClient(
        {
          '/v1/blocks/page1/children': (_) => _childrenPage([
            _block('image', {
              'type': 'file',
              'file': {'url': 'https://prod-files-secure.example.com/signed/pic.jpg?X-Amz-Signature=abc'},
            }, id: 'b1'),
          ]),
        },
        onDownload: (uri) => http.Response.bytes([1, 2, 3, 4], 200),
      );

      final export = await mapNotionSelectionToParsedExport(
        client: client,
        selected: [NotionSearchResultItem(id: 'page1', object: 'page', title: 'Página 1')],
        attachmentsDir: tempDir,
      );

      final imageText = export.pages.single.blocks.single.text;
      expect(imageText.startsWith('http'), isFalse);
      expect(File('${tempDir.path}/$imageText').existsSync(), isTrue);
      expect(export.warnings, isEmpty);
    });
  });

  group('mapNotionSelectionToParsedExport — bookmark/embed/toc/breadcrumb', () {
    test('bookmark, embed, toc y breadcrumb se mapean 1:1', () async {
      final tempDir = await Directory.systemTemp.createTemp('notion_mapper_test_');
      addTearDown(() => tempDir.delete(recursive: true));

      final client = _fakeClient({
        '/v1/blocks/page1/children': (_) => _childrenPage([
          _block('bookmark', {'url': 'https://example.com', ...(_richText('Un marcador'))}, id: 'b1'),
          _block('embed', {'url': 'https://example.com/embed'}, id: 'b2'),
          _block('table_of_contents', {}, id: 'b3'),
          _block('breadcrumb', {}, id: 'b4'),
        ]),
      });

      final export = await mapNotionSelectionToParsedExport(
        client: client,
        selected: [NotionSearchResultItem(id: 'page1', object: 'page', title: 'Página 1')],
        attachmentsDir: tempDir,
      );

      final blocks = export.pages.single.blocks;
      expect(blocks[0].type, 'bookmark');
      expect(blocks[0].url, 'https://example.com');
      expect(blocks[1].type, 'embed');
      expect(blocks[1].url, 'https://example.com/embed');
      expect(blocks[2].type, 'toc');
      expect(blocks[3].type, 'breadcrumb');
    });
  });

  group('mapNotionSelectionToParsedExport — table', () {
    test('table + table_row se convierte en FolioTableData en orden fila-mayor', () async {
      final tempDir = await Directory.systemTemp.createTemp('notion_mapper_test_');
      addTearDown(() => tempDir.delete(recursive: true));

      final client = _fakeClient({
        '/v1/blocks/page1/children': (_) => _childrenPage([
          _block('table', {'table_width': 2, 'has_row_header': false}, id: 'tbl1', hasChildren: true),
        ]),
        // El cliente real recursa de verdad en /v1/blocks/{id}/children para
        // cualquier bloque con has_children:true — hay que registrar esa
        // ruta, no basta con inyectar `_children` a mano en el fixture.
        '/v1/blocks/tbl1/children': (_) => _childrenPage([
          {
            'id': 'row1',
            'type': 'table_row',
            'has_children': false,
            'table_row': {
              'cells': [
                [
                  {'plain_text': 'A1'},
                ],
                [
                  {'plain_text': 'B1'},
                ],
              ],
            },
          },
          {
            'id': 'row2',
            'type': 'table_row',
            'has_children': false,
            'table_row': {
              'cells': [
                [
                  {'plain_text': 'A2'},
                ],
                [
                  {'plain_text': 'B2'},
                ],
              ],
            },
          },
        ]),
      });

      final export = await mapNotionSelectionToParsedExport(
        client: client,
        selected: [NotionSearchResultItem(id: 'page1', object: 'page', title: 'Página 1')],
        attachmentsDir: tempDir,
      );

      final block = export.pages.single.blocks.single;
      expect(block.type, 'table');
      final data = FolioTableData.tryParse(block.text)!;
      expect(data.cols, 2);
      expect(data.cellAt(0, 0), 'A1');
      expect(data.cellAt(0, 1), 'B1');
      expect(data.cellAt(1, 0), 'A2');
      expect(data.cellAt(1, 1), 'B2');
    });
  });

  group('mapNotionSelectionToParsedExport — column_list', () {
    test('2 columnas se mapean 1:1 sin warning', () async {
      final tempDir = await Directory.systemTemp.createTemp('notion_mapper_test_');
      addTearDown(() => tempDir.delete(recursive: true));

      Map<String, dynamic> column(String id) => {'id': id, 'type': 'column', 'has_children': true, 'column': {}};

      final client = _fakeClient({
        '/v1/blocks/page1/children': (_) => _childrenPage([
          _block('column_list', {}, id: 'cl1', hasChildren: true),
        ]),
        '/v1/blocks/cl1/children': (_) => _childrenPage([column('col_a'), column('col_b')]),
        '/v1/blocks/col_a/children': (_) => _childrenPage([_block('paragraph', _richText('col-a'), id: 'p_a')]),
        '/v1/blocks/col_b/children': (_) => _childrenPage([_block('paragraph', _richText('col-b'), id: 'p_b')]),
      });

      final export = await mapNotionSelectionToParsedExport(
        client: client,
        selected: [NotionSearchResultItem(id: 'page1', object: 'page', title: 'Página 1')],
        attachmentsDir: tempDir,
      );

      final block = export.pages.single.blocks.single;
      expect(block.type, 'column_list');
      final data = FolioColumnsData.tryParse(block.text)!;
      expect(data.columns, hasLength(2));
      expect(data.columns[0].blocks.single.text, 'col-a');
      expect(data.columns[1].blocks.single.text, 'col-b');
      expect(export.warnings, isEmpty);
    });

    test('4 columnas se fusionan en 3 con warning explícito', () async {
      final tempDir = await Directory.systemTemp.createTemp('notion_mapper_test_');
      addTearDown(() => tempDir.delete(recursive: true));

      Map<String, dynamic> column(String id) => {'id': id, 'type': 'column', 'has_children': true, 'column': {}};

      final client = _fakeClient({
        '/v1/blocks/page1/children': (_) => _childrenPage([
          _block('column_list', {}, id: 'cl1', hasChildren: true),
        ]),
        '/v1/blocks/cl1/children': (_) => _childrenPage([column('col_a'), column('col_b'), column('col_c'), column('col_d')]),
        '/v1/blocks/col_a/children': (_) => _childrenPage([_block('paragraph', _richText('a'), id: 'p_a')]),
        '/v1/blocks/col_b/children': (_) => _childrenPage([_block('paragraph', _richText('b'), id: 'p_b')]),
        '/v1/blocks/col_c/children': (_) => _childrenPage([_block('paragraph', _richText('c'), id: 'p_c')]),
        '/v1/blocks/col_d/children': (_) => _childrenPage([_block('paragraph', _richText('d'), id: 'p_d')]),
      });

      final export = await mapNotionSelectionToParsedExport(
        client: client,
        selected: [NotionSearchResultItem(id: 'page1', object: 'page', title: 'Página 1')],
        attachmentsDir: tempDir,
      );

      final data = FolioColumnsData.tryParse(export.pages.single.blocks.single.text)!;
      expect(data.columns, hasLength(3));
      // La 3ª columna Folio contiene el contenido de las columnas Notion c y d.
      expect(data.columns[2].blocks.map((b) => b.text), containsAll(['c', 'd']));
      expect(export.warnings, hasLength(1));
    });
  });

  group('mapNotionSelectionToParsedExport — toggle', () {
    test('toggle con hijos de solo texto usa FolioToggleData sin warning', () async {
      final tempDir = await Directory.systemTemp.createTemp('notion_mapper_test_');
      addTearDown(() => tempDir.delete(recursive: true));

      final client = _fakeClient({
        '/v1/blocks/page1/children': (_) => _childrenPage([
          _block('toggle', _richText('Detalles'), id: 'tg1', hasChildren: true),
        ]),
        '/v1/blocks/tg1/children': (_) => _childrenPage([
          _block('paragraph', _richText('línea 1'), id: 'p1'),
          _block('paragraph', _richText('línea 2'), id: 'p2'),
        ]),
      });

      final export = await mapNotionSelectionToParsedExport(
        client: client,
        selected: [NotionSearchResultItem(id: 'page1', object: 'page', title: 'Página 1')],
        attachmentsDir: tempDir,
      );

      final blocks = export.pages.single.blocks;
      expect(blocks, hasLength(1));
      expect(blocks[0].type, 'toggle');
      final data = FolioToggleData.tryParse(blocks[0].text)!;
      expect(data.title, 'Detalles');
      expect(data.body, 'línea 1\nlínea 2');
      expect(export.warnings, isEmpty);
    });

    test('toggle con hijos estructurados promociona a hermanos y avisa', () async {
      final tempDir = await Directory.systemTemp.createTemp('notion_mapper_test_');
      addTearDown(() => tempDir.delete(recursive: true));

      final client = _fakeClient({
        '/v1/blocks/page1/children': (_) => _childrenPage([
          _block('toggle', _richText('Detalles'), id: 'tg1', hasChildren: true),
        ]),
        '/v1/blocks/tg1/children': (_) => _childrenPage([
          _block('image', {
            'type': 'external',
            'external': {'url': 'https://example.com/x.png'},
          }, id: 'img1'),
        ]),
      });

      final export = await mapNotionSelectionToParsedExport(
        client: client,
        selected: [NotionSearchResultItem(id: 'page1', object: 'page', title: 'Página 1')],
        attachmentsDir: tempDir,
      );

      final blocks = export.pages.single.blocks;
      expect(blocks, hasLength(2));
      expect(blocks[0].type, 'toggle');
      expect(blocks[1].type, 'image');
      expect(blocks[1].depth, 1);
      expect(export.warnings, hasLength(1));
    });
  });

  group('mapNotionSelectionToParsedExport — synced_block', () {
    test('resuelve el contenido del bloque original y avisa de la pérdida de sync', () async {
      final tempDir = await Directory.systemTemp.createTemp('notion_mapper_test_');
      addTearDown(() => tempDir.delete(recursive: true));

      final client = _fakeClient({
        '/v1/blocks/page1/children': (_) => _childrenPage([
          _block('synced_block', {
            'synced_from': {'block_id': 'original1'},
          }, id: 'sb1'),
        ]),
        '/v1/blocks/original1/children': (_) => _childrenPage([
          _block('paragraph', _richText('contenido original'), id: 'op1'),
        ]),
      });

      final export = await mapNotionSelectionToParsedExport(
        client: client,
        selected: [NotionSearchResultItem(id: 'page1', object: 'page', title: 'Página 1')],
        attachmentsDir: tempDir,
      );

      final blocks = export.pages.single.blocks;
      expect(blocks.single.type, 'paragraph');
      expect(blocks.single.text, 'contenido original');
      expect(export.warnings, hasLength(1));
    });
  });

  group('mapNotionSelectionToParsedExport — child_page / child_database', () {
    test('child_page se importa como página anidada y resuelve su árbol', () async {
      final tempDir = await Directory.systemTemp.createTemp('notion_mapper_test_');
      addTearDown(() => tempDir.delete(recursive: true));

      final client = _fakeClient({
        '/v1/blocks/parent1/children': (_) => _childrenPage([
          _block('child_page', {'title': 'Subpágina'}, id: 'child1'),
        ]),
        '/v1/blocks/child1/children': (_) => _childrenPage([
          _block('paragraph', _richText('contenido de la subpágina'), id: 'cp1'),
        ]),
      });

      final export = await mapNotionSelectionToParsedExport(
        client: client,
        selected: [NotionSearchResultItem(id: 'parent1', object: 'page', title: 'Padre')],
        attachmentsDir: tempDir,
      );

      expect(export.pages, hasLength(2));
      final parent = export.pages.firstWhere((p) => p.sourcePath == 'parent1');
      final child = export.pages.firstWhere((p) => p.sourcePath == 'child1');
      expect(parent.blocks.single.type, 'child_page');
      expect(parent.blocks.single.text, 'child1');
      expect(child.parentSourcePath, 'parent1');
      expect(child.title, 'Subpágina');
      expect(child.blocks.single.text, 'contenido de la subpágina');
    });

    test('child_database se incrusta inline como bloque database', () async {
      final tempDir = await Directory.systemTemp.createTemp('notion_mapper_test_');
      addTearDown(() => tempDir.delete(recursive: true));

      final client = _fakeClient({
        '/v1/blocks/page1/children': (_) => _childrenPage([
          _block('child_database', {'title': 'Mi DB'}, id: 'db1'),
        ]),
        '/v1/databases/db1': (_) => {
          'properties': {
            'Nombre': {'type': 'title'},
            'Hecho': {'type': 'checkbox'},
          },
        },
        '/v1/databases/db1/query': (_) => _childrenPage([
          {
            'properties': {
              'Nombre': {
                'type': 'title',
                'title': [
                  {'plain_text': 'Fila 1'},
                ],
              },
              'Hecho': {'type': 'checkbox', 'checkbox': true},
            },
          },
        ]),
      });

      final export = await mapNotionSelectionToParsedExport(
        client: client,
        selected: [NotionSearchResultItem(id: 'page1', object: 'page', title: 'Página 1')],
        attachmentsDir: tempDir,
      );

      final block = export.pages.single.blocks.single;
      expect(block.type, 'database');
      final data = FolioDatabaseData.tryParse(block.text)!;
      expect(data.properties.map((p) => p.name), containsAll(['Nombre', 'Hecho']));
      expect(data.rows, hasLength(1));
    });
  });

  group('mapNotionSelectionToParsedExport — link_to_page y tipos no soportados', () {
    test('link_to_page se aproxima a bookmark con warning', () async {
      final tempDir = await Directory.systemTemp.createTemp('notion_mapper_test_');
      addTearDown(() => tempDir.delete(recursive: true));

      final client = _fakeClient({
        '/v1/blocks/page1/children': (_) => _childrenPage([
          _block('link_to_page', {'type': 'page_id', 'page_id': 'other-page'}, id: 'l1'),
        ]),
      });

      final export = await mapNotionSelectionToParsedExport(
        client: client,
        selected: [NotionSearchResultItem(id: 'page1', object: 'page', title: 'Página 1')],
        attachmentsDir: tempDir,
      );

      expect(export.pages.single.blocks.single.type, 'bookmark');
      expect(export.warnings, hasLength(1));
    });

    test('un tipo de bloque desconocido se omite con warning, sin romper el import', () async {
      final tempDir = await Directory.systemTemp.createTemp('notion_mapper_test_');
      addTearDown(() => tempDir.delete(recursive: true));

      final client = _fakeClient({
        '/v1/blocks/page1/children': (_) => _childrenPage([
          _block('some_future_notion_block_type', {}, id: 'u1'),
          _block('paragraph', _richText('sigue funcionando'), id: 'p1'),
        ]),
      });

      final export = await mapNotionSelectionToParsedExport(
        client: client,
        selected: [NotionSearchResultItem(id: 'page1', object: 'page', title: 'Página 1')],
        attachmentsDir: tempDir,
      );

      expect(export.pages.single.blocks, hasLength(1));
      expect(export.pages.single.blocks.single.text, 'sigue funcionando');
      expect(export.warnings, hasLength(1));
    });
  });

  group('mapNotionSelectionToParsedExport — base de datos seleccionada como top-level', () {
    test('propiedades relation/rollup degradan a texto con warning', () async {
      final tempDir = await Directory.systemTemp.createTemp('notion_mapper_test_');
      addTearDown(() => tempDir.delete(recursive: true));

      final client = _fakeClient({
        '/v1/databases/topdb': (_) => {
          'properties': {
            'Nombre': {'type': 'title'},
            'Relacionado': {'type': 'relation'},
          },
        },
        '/v1/databases/topdb/query': (_) => _childrenPage([]),
      });

      final export = await mapNotionSelectionToParsedExport(
        client: client,
        selected: [NotionSearchResultItem(id: 'topdb', object: 'database', title: 'DB top-level')],
        attachmentsDir: tempDir,
      );

      expect(export.pages, isEmpty);
      expect(export.databases, hasLength(1));
      final data = export.databases.single.data;
      expect(data.properties.map((p) => p.name), containsAll(['Nombre', 'Relacionado']));
      expect(export.warnings, hasLength(1));
    });
  });
}
