import 'package:flutter_test/flutter_test.dart';
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

    test('hace fallback a markdown cuando no hay JSON válido', () {
      final session = VaultSession();
      final output = '''
# Titulo
- punto A
- [ ] tarea
> cita
''';
      final blocks = session.parseAiOutputForTesting(output);
      expect(blocks.length, 4);
      expect(blocks[0].type, 'h1');
      expect(blocks[1].type, 'bullet');
      expect(blocks[2].type, 'todo');
      expect(blocks[3].type, 'quote');
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
  });
}
