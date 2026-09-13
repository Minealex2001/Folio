import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:folio/app/app_settings.dart';
import 'package:folio/models/quill_workflow.dart';

/// Fase 6 de Quill 2.0 — desde esta fase, `AppSettings.load()` siempre
/// reinserta 4 presets por defecto (`isSystemDefault: true`), mismo
/// mecanismo que ya usa `QuillSystemPrompt`. Los tests de workflows de
/// usuario filtran esos defaults para no acoplarse a su número exacto.
const _kDefaultWorkflowIds = {
  'quill_wf_prep_meeting',
  'quill_wf_weekly_review',
  'quill_wf_pending_tasks',
  'quill_wf_analyze_project',
};

Iterable<QuillWorkflow> _userWorkflows(AppSettings settings) =>
    settings.quillWorkflows.where((w) => !w.isSystemDefault);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('addQuillWorkflow añade y persiste entre instancias', () async {
    final settings = AppSettings();
    await settings.load();
    await settings.addQuillWorkflow(
      const QuillWorkflow(id: 'w1', name: 'X', currentVersion: 1, promptTemplate: 'A'),
    );

    expect(_userWorkflows(settings), hasLength(1));

    final reloaded = AppSettings();
    await reloaded.load();
    expect(_userWorkflows(reloaded).single.name, 'X');
  });

  test('updateQuillWorkflow reemplaza y persiste la versión editada', () async {
    final settings = AppSettings();
    await settings.load();
    const original = QuillWorkflow(id: 'w1', name: 'X', currentVersion: 1, promptTemplate: 'A');
    await settings.addQuillWorkflow(original);

    await settings.updateQuillWorkflow(original.edited(newPromptTemplate: 'B'));

    final userWorkflow = _userWorkflows(settings).single;
    expect(userWorkflow.currentVersion, 2);
    expect(userWorkflow.history, hasLength(1));
  });

  test('deleteQuillWorkflow borra por id', () async {
    final settings = AppSettings();
    await settings.load();
    await settings.addQuillWorkflow(
      const QuillWorkflow(id: 'w1', name: 'X', currentVersion: 1, promptTemplate: 'A'),
    );

    await settings.deleteQuillWorkflow('w1');

    expect(_userWorkflows(settings), isEmpty);
  });

  group('Presets por defecto (Fase 6)', () {
    test('load() inserta los 4 presets por defecto', () async {
      final settings = AppSettings();
      await settings.load();

      final defaultIds = settings.quillWorkflows
          .where((w) => w.isSystemDefault)
          .map((w) => w.id)
          .toSet();
      expect(defaultIds, _kDefaultWorkflowIds);
    });

    test('load() repetido no duplica los presets por defecto', () async {
      final settings = AppSettings();
      await settings.load();
      await settings.load();

      final defaults = settings.quillWorkflows.where((w) => w.isSystemDefault);
      expect(defaults, hasLength(_kDefaultWorkflowIds.length));
    });

    test('los workflows del usuario no se tocan ni se pierden al recargar', () async {
      final settings = AppSettings();
      await settings.load();
      await settings.addQuillWorkflow(
        const QuillWorkflow(id: 'w1', name: 'Mío', currentVersion: 1, promptTemplate: 'A'),
      );

      await settings.load();

      expect(_userWorkflows(settings).map((w) => w.id), ['w1']);
      expect(
        settings.quillWorkflows.where((w) => w.isSystemDefault),
        hasLength(_kDefaultWorkflowIds.length),
        reason: 'los defaults se reinsertan sin duplicarse junto al workflow del usuario',
      );
    });

    test('un preset por defecto tiene contenido no vacío y nombre no vacío', () async {
      final settings = AppSettings();
      await settings.load();

      for (final w in settings.quillWorkflows.where((w) => w.isSystemDefault)) {
        expect(w.name.trim(), isNotEmpty, reason: '${w.id} debe tener nombre');
        expect(w.promptTemplate.trim(), isNotEmpty, reason: '${w.id} debe tener prompt');
      }
    });
  });
}
