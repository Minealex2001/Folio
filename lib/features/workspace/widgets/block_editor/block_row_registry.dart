/// Tipos de bloque que comparten el editor con menú `/`, menciones `@` y barra de formato.
const Set<String> kBlockEditorSlashStyleTypes = {
  'paragraph',
  'h1',
  'h2',
  'h3',
  'bullet',
  'numbered',
  'todo',
  'toggle',
  'quote',
  'callout',
};

bool blockEditorTypeUsesSlashMenu(String type) =>
    kBlockEditorSlashStyleTypes.contains(type);
