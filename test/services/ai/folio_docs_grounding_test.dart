import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:folio/services/ai/folio_docs_grounding.dart';

const _sampleMarkdown = '''
# Folio features

## 1. Editor de bloques

El editor soporta párrafos, encabezados y listas.

### Atajos de teclado

Ctrl+B para negrita, Ctrl+I para cursiva.

## 22. Colaboración en tiempo real

Las salas de colaboración permiten editar una página entre varios usuarios
mediante un código de sala. La sincronización usa un servidor local.

## 23. Asistente IA Quill

Quill puede resumir, traducir y crear páginas. Se configura desde Ajustes.
''';

void main() {
  group('FolioDocsGrounding.parse', () {
    test('divide el markdown en secciones por encabezado', () {
      final grounding = FolioDocsGrounding.parse(_sampleMarkdown);
      expect(grounding.sectionCount, 4);
    });
  });

  group('FolioDocsGrounding.matchSections', () {
    late FolioDocsGrounding grounding;
    setUp(() => grounding = FolioDocsGrounding.parse(_sampleMarkdown));

    test('encuentra la sección de colaboración para una pregunta relacionada', () {
      final results = grounding.matchSections('cómo funciona la colaboración en tiempo real');
      expect(results, isNotEmpty);
      expect(results.first.heading, contains('Colaboración'));
    });

    test('encuentra la sección de Quill para una pregunta sobre el asistente', () {
      final results = grounding.matchSections('qué puede hacer el asistente Quill');
      expect(results, isNotEmpty);
      expect(results.first.heading, contains('Quill'));
    });

    test('no devuelve nada para una consulta sin términos relacionados', () {
      final results = grounding.matchSections('receta de tarta de manzana');
      expect(results, isEmpty);
    });

    test('respeta maxSections', () {
      final results = grounding.matchSections('editor bloques colaboración quill', maxSections: 1);
      expect(results.length, 1);
    });
  });

  group('FolioDocSection.toContextBlock', () {
    test('trunca el cuerpo a maxChars', () {
      final section = FolioDocSection(heading: 'X', body: 'a' * 100, level: 2);
      final block = section.toContextBlock(maxChars: 10);
      expect(block, contains('## X'));
      expect(block.length, lessThan(30));
    });
  });

  test('el docs/FEATURES.md real del repo parsea a varias secciones (sanity check anti-drift)', () {
    final file = File('docs/FEATURES.md');
    if (!file.existsSync()) {
      // Evita fallar en entornos donde el cwd del test runner no sea la raíz del repo.
      return;
    }
    final grounding = FolioDocsGrounding.parse(file.readAsStringSync());
    expect(grounding.sectionCount, greaterThan(10));
    final results = grounding.matchSections('cómo funciona el asistente Quill');
    expect(results, isNotEmpty);
  });
}
