import 'package:flutter_test/flutter_test.dart';

import 'package:folio/models/execution_profile.dart';
import 'package:folio/services/ai/ai_tool.dart';
import 'package:folio/services/ai/folio_tool_registry.dart';
import 'package:folio/session/vault_session.dart';

/// Fase C1 del plan Quill/MCP — investigado primero (backend ignora el
/// modelo enviado por el cliente, ver doc de `ExecutionProfile`); esta fase
/// se acota a lo que sí es decisión real de cliente: temperatura, alcance
/// de contexto, categorías de tools, timeout.
void main() {
  group('ExecutionProfile.filterTools', () {
    test('allowedToolCategories null no filtra nada', () {
      final session = VaultSession();
      final definitions = FolioToolRegistry(session).definitions;

      final filtered = kExecutionProfileDeepResearch.filterTools(definitions);

      expect(filtered.length, definitions.length);
    });

    test('quickAnswer (categorías vacías) filtra todas las tools', () {
      final session = VaultSession();
      final definitions = FolioToolRegistry(session).definitions;

      final filtered = kExecutionProfileQuickAnswer.filterTools(definitions);

      expect(filtered, isEmpty);
    });

    test('codeTask solo deja tools de content y task', () {
      final session = VaultSession();
      final definitions = FolioToolRegistry(session).definitions;

      final filtered = kExecutionProfileCodeTask.filterTools(definitions);

      expect(filtered, isNotEmpty);
      expect(
        filtered.every(
          (d) => d.category == AiToolCategory.content || d.category == AiToolCategory.task,
        ),
        isTrue,
      );
      expect(filtered.any((d) => d.category == AiToolCategory.destructive), isFalse);
    });
  });

  group('resolveExecutionProfileForPrompt', () {
    test('prompt vacío cae a deepResearch', () {
      expect(resolveExecutionProfileForPrompt(''), kExecutionProfileDeepResearch);
    });

    test('menciones de código eligen codeTask', () {
      expect(
        resolveExecutionProfileForPrompt('Arregla este bug en la función de login'),
        kExecutionProfileCodeTask,
      );
      expect(
        resolveExecutionProfileForPrompt('Refactor this class please'),
        kExecutionProfileCodeTask,
      );
    });

    test('peticiones cortas de resumen/traducción eligen quickAnswer', () {
      expect(
        resolveExecutionProfileForPrompt('Resume esto en una frase'),
        kExecutionProfileQuickAnswer,
      );
      expect(
        resolveExecutionProfileForPrompt('Translate: hola mundo'),
        kExecutionProfileQuickAnswer,
      );
    });

    test('un pedido de resumen MUY largo no cae en quickAnswer (ya no es "rápido")', () {
      final longPrompt = 'resume ${'palabra ' * 30}';
      expect(
        resolveExecutionProfileForPrompt(longPrompt),
        isNot(kExecutionProfileQuickAnswer),
      );
    });

    test('petición genérica sin palabras clave cae a deepResearch', () {
      expect(
        resolveExecutionProfileForPrompt('Ayúdame a organizar mis notas de este trimestre'),
        kExecutionProfileDeepResearch,
      );
    });
  });
}
