import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:folio/data/notion_import/notion_importer.dart';

void main() {
  group('notion importer', () {
    test('detecta markdown y convierte bloques basicos', () async {
      final temp = await Directory.systemTemp.createTemp(
        'folio_notion_test_md_',
      );
      addTearDown(() async {
        if (temp.existsSync()) await temp.delete(recursive: true);
      });
      final page = File('${temp.path}${Platform.pathSeparator}Home.md');
      await page.writeAsString('''
# Titulo

Parrafo inicial.

- [x] Tarea hecha
- Item simple

```dart
print("hola");
```
''');

      final parsed = parseNotionExportDirectory(temp);
      expect(parsed.format, NotionExportFormat.markdown);
      expect(parsed.pages, hasLength(1));
      final blocks = parsed.pages.first.blocks;
      expect(blocks.any((b) => b.type == 'h1'), isTrue);
      expect(blocks.any((b) => b.type == 'todo' && b.checked == true), isTrue);
      expect(blocks.any((b) => b.type == 'bullet'), isTrue);
      expect(blocks.any((b) => b.type == 'code'), isTrue);
    });

    test('detecta html y convierte encabezados/parrafos', () async {
      final temp = await Directory.systemTemp.createTemp(
        'folio_notion_test_html_',
      );
      addTearDown(() async {
        if (temp.existsSync()) await temp.delete(recursive: true);
      });
      final page = File('${temp.path}${Platform.pathSeparator}Page.html');
      await page.writeAsString('''
<html><body>
<h1>Mi Pagina</h1>
<p>Contenido <strong>simple</strong>.</p>
<li>[x] checkbox</li>
</body></html>
''');

      final parsed = parseNotionExportDirectory(temp);
      expect(parsed.format, NotionExportFormat.html);
      expect(parsed.pages, hasLength(1));
      final blocks = parsed.pages.first.blocks;
      expect(
        blocks.any((b) => b.type == 'h1' && b.text.contains('Mi Pagina')),
        isTrue,
      );
      expect(blocks.any((b) => b.type == 'paragraph'), isTrue);
      expect(blocks.any((b) => b.type == 'todo' && b.checked == true), isTrue);
    });

    test('detecta csv y lo convierte a database data', () async {
      final temp = await Directory.systemTemp.createTemp(
        'folio_notion_test_csv_',
      );
      addTearDown(() async {
        if (temp.existsSync()) await temp.delete(recursive: true);
      });
      final csv = File('${temp.path}${Platform.pathSeparator}Tasks.csv');
      await csv.writeAsString('''
Name,Status,Points
Task A,Todo,3
Task B,Done,5
''');

      final parsed = parseNotionExportDirectory(temp);
      expect(parsed.databases, hasLength(1));
      final db = parsed.databases.first.data;
      expect(db.properties.length, 3);
      expect(db.rows.length, 2);
      expect(db.rows.first.values['p_title'], 'Task A');
    });
  });
}
