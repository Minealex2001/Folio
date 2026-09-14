import 'package:flutter_test/flutter_test.dart';
import 'package:folio/features/workspace/shell/workspace_page.dart';

void main() {
  group('humanizeWorkflowVariableId (Fase 8 de Quill 2.0)', () {
    test('capitaliza un id de una sola palabra', () {
      expect(humanizeWorkflowVariableId('tema'), 'Tema');
      expect(humanizeWorkflowVariableId('topic'), 'Topic');
    });

    test('convierte guiones bajos/guiones en espacios', () {
      expect(humanizeWorkflowVariableId('project_name'), 'Project name');
      expect(humanizeWorkflowVariableId('due-date'), 'Due date');
    });

    test('un id vacío se devuelve tal cual', () {
      expect(humanizeWorkflowVariableId(''), '');
    });
  });
}
