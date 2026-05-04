import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:folio/models/folio_task_data.dart';
import 'package:folio/session/vault_session.dart';

void main() {
  group('AI hybrid parser', () {
    test('parsea JSON estructurado con tipos de bloque', () {
      final session = VaultSession();
      final output = '''
{
  "title": "Demo",
  "blocks": [
    {"type":"h1","text":"Plan semanal"},
    {"type":"bullet","text":"Primero"},
    {"type":"todo","text":"Terminar tarea","checked":true},
    {"type":"code","text":"print(1);","codeLanguage":"dart"}
  ]
}
''';
      final blocks = session.parseAiOutputForTesting(output);
      expect(blocks.length, 4);
      expect(blocks[0].type, 'h1');
      expect(blocks[1].type, 'bullet');
      expect(blocks[2].type, 'todo');
      expect(blocks[2].checked, isTrue);
      expect(blocks[3].type, 'code');
      expect(blocks[3].codeLanguage, 'dart');
    });

    test('acepta JSON con markdown fences y lo limpia', () {
      final session = VaultSession();
      const output = '''
```json
{
  "title": "Fences",
  "blocks": [{"type":"paragraph","text":"ok"}]
}
```
''';
      final blocks = session.parseAiOutputForTesting(output);
      expect(blocks.length, 1);
      expect(blocks.first.type, 'paragraph');
      expect(blocks.first.text, 'ok');
    });

    test('hace fallback a markdown cuando no hay JSON válido', () {
      final session = VaultSession();
      final output = '''
# Titulo
1. paso uno
- punto A
- [ ] tarea
> cita
''';
      final blocks = session.parseAiOutputForTesting(output);
      expect(blocks.length, 5);
      expect(blocks[0].type, 'h1');
      expect(blocks[1].type, 'numbered');
      expect(blocks[2].type, 'bullet');
      expect(blocks[3].type, 'todo');
      expect(blocks[4].type, 'quote');
    });

    test('recupera bloques desde JSON malformado y normaliza type con pipes', () {
      final session = VaultSession();
      const output =
          '{"blocks":[{"type":"paragraph|h1|h2|h3|bullet|todo|quote|code|divider","text":"Hola mundo"}';
      final blocks = session.parseAiOutputForTesting(output);
      expect(blocks, isNotEmpty);
      expect(blocks.first.type, 'paragraph');
      expect(blocks.first.text, contains('Hola mundo'));
    });

    test('parsea bloque table con filas y columnas', () {
      final session = VaultSession();
      const output = '''
{
  "title": "Tabla",
  "blocks": [
    {
      "type": "table",
      "cols": 2,
      "rows": [
        ["Nombre", "Edad"],
        ["Ana", "30"]
      ]
    }
  ]
}
''';
      final blocks = session.parseAiOutputForTesting(output);
      expect(blocks.length, 1);
      expect(blocks.first.type, 'table');
      expect(blocks.first.text, contains('"cols":2'));
      expect(blocks.first.text, contains('Nombre'));
      expect(blocks.first.text, contains('Ana'));
    });

    test('parsea bloque task con título o JSON en text', () {
      final session = VaultSession();
      final taskJson = FolioTaskData(
        title: 'Con JSON',
        status: 'in_progress',
        priority: 'high',
      ).encode();
      final output = jsonEncode({
        'title': 'Tareas',
        'blocks': [
          {'type': 'task', 'title': 'Solo título'},
          {'type': 'task', 'text': taskJson},
        ],
      });
      final blocks = session.parseAiOutputForTesting(output);
      expect(blocks.length, 2);
      expect(blocks.every((b) => b.type == 'task'), isTrue);
      final a = FolioTaskData.tryParse(blocks[0].text);
      expect(a?.title, 'Solo título');
      final b = FolioTaskData.tryParse(blocks[1].text);
      expect(b?.title, 'Con JSON');
      expect(b?.status, 'in_progress');
      expect(b?.priority, 'high');
    });

    test('acepta bloque image con url aunque text venga vacío', () {
      final session = VaultSession();
      const output = '''
{
  "title": "Imagen",
  "blocks": [
    {
      "type": "image",
      "text": "",
      "url": "https://example.com/a.png"
    }
  ]
}
''';
      final blocks = session.parseAiOutputForTesting(output);
      expect(blocks.length, 1);
      expect(blocks.first.type, 'image');
      expect(blocks.first.url, 'https://example.com/a.png');
    });
  });
}
