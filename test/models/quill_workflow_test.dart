import 'package:flutter_test/flutter_test.dart';

import 'package:folio/models/quill_workflow.dart';

/// Fase A5 del plan Quill/MCP — Workflows son atajos nombrados y
/// versionados hacia el Plan-mode que ya existe, no un ejecutor nuevo. Este
/// archivo prueba la lógica pura: extracción de variables, resolución del
/// prompt final, y que editar nunca sobrescribe una versión anterior.
void main() {
  group('QuillWorkflow.variableIds', () {
    test('extrae variables únicas en orden de aparición', () {
      const workflow = QuillWorkflow(
        id: 'w1',
        name: 'Reunión',
        currentVersion: 1,
        promptTemplate:
            'Resume la reunión con {{persona}} del {{fecha}}, repite {{persona}}.',
      );
      expect(workflow.variableIds, ['persona', 'fecha']);
    });

    test('sin variables devuelve lista vacía', () {
      const workflow = QuillWorkflow(
        id: 'w1',
        name: 'Roadmap',
        currentVersion: 1,
        promptTemplate: 'Genera un roadmap trimestral.',
      );
      expect(workflow.variableIds, isEmpty);
    });
  });

  group('QuillWorkflow.resolve', () {
    test('sustituye cada variable por su respuesta', () {
      const workflow = QuillWorkflow(
        id: 'w1',
        name: 'Reunión',
        currentVersion: 1,
        promptTemplate: 'Reunión con {{persona}} el {{fecha}}.',
      );
      final resolved = workflow.resolve({'persona': 'Ana', 'fecha': '2026-08-10'});
      expect(resolved, 'Reunión con Ana el 2026-08-10.');
    });

    test('variable sin respuesta se sustituye por vacío', () {
      const workflow = QuillWorkflow(
        id: 'w1',
        name: 'Reunión',
        currentVersion: 1,
        promptTemplate: 'Reunión con {{persona}}.',
      );
      expect(workflow.resolve(const {}), 'Reunión con .');
    });
  });

  group('QuillWorkflow.edited', () {
    test('sube currentVersion y archiva la versión anterior en history', () {
      const workflow = QuillWorkflow(
        id: 'w1',
        name: 'Reunión',
        currentVersion: 1,
        promptTemplate: 'Prompt v1',
      );
      final edited = workflow.edited(newPromptTemplate: 'Prompt v2');

      expect(edited.currentVersion, 2);
      expect(edited.promptTemplate, 'Prompt v2');
      expect(edited.history, hasLength(1));
      expect(edited.history.single.version, 1);
      expect(edited.history.single.promptTemplate, 'Prompt v1');
    });

    test('varias ediciones acumulan historial sin perder versiones', () {
      const v1 = QuillWorkflow(id: 'w1', name: 'X', currentVersion: 1, promptTemplate: 'A');
      final v2 = v1.edited(newPromptTemplate: 'B');
      final v3 = v2.edited(newPromptTemplate: 'C');

      expect(v3.currentVersion, 3);
      expect(v3.promptTemplate, 'C');
      expect(v3.history.map((h) => h.promptTemplate), ['A', 'B']);
    });

    test('sin cambios reales devuelve el mismo workflow (no incrementa versión)', () {
      const workflow = QuillWorkflow(
        id: 'w1',
        name: 'X',
        currentVersion: 1,
        promptTemplate: 'Igual',
      );
      final result = workflow.edited(newPromptTemplate: 'Igual');
      expect(result.currentVersion, 1);
      expect(result.history, isEmpty);
    });
  });

  group('QuillWorkflow JSON', () {
    test('round-trip preserva historial completo', () {
      const v1 = QuillWorkflow(id: 'w1', name: 'X', currentVersion: 1, promptTemplate: 'A');
      final edited = v1.edited(newPromptTemplate: 'B');

      final restored = QuillWorkflow.fromJson(edited.toJson());

      expect(restored.currentVersion, 2);
      expect(restored.promptTemplate, 'B');
      expect(restored.history, hasLength(1));
      expect(restored.history.single.promptTemplate, 'A');
    });
  });
}
