import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:folio/app/app_settings.dart';
import 'package:folio/models/quill_workflow.dart';

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

    expect(settings.quillWorkflows, hasLength(1));

    final reloaded = AppSettings();
    await reloaded.load();
    expect(reloaded.quillWorkflows.single.name, 'X');
  });

  test('updateQuillWorkflow reemplaza y persiste la versión editada', () async {
    final settings = AppSettings();
    await settings.load();
    const original = QuillWorkflow(id: 'w1', name: 'X', currentVersion: 1, promptTemplate: 'A');
    await settings.addQuillWorkflow(original);

    await settings.updateQuillWorkflow(original.edited(newPromptTemplate: 'B'));

    expect(settings.quillWorkflows.single.currentVersion, 2);
    expect(settings.quillWorkflows.single.history, hasLength(1));
  });

  test('deleteQuillWorkflow borra por id', () async {
    final settings = AppSettings();
    await settings.load();
    await settings.addQuillWorkflow(
      const QuillWorkflow(id: 'w1', name: 'X', currentVersion: 1, promptTemplate: 'A'),
    );

    await settings.deleteQuillWorkflow('w1');

    expect(settings.quillWorkflows, isEmpty);
  });
}
