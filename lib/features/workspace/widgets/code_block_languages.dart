import 'package:flutter/material.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:highlight/highlight_core.dart';
import 'package:highlight/languages/all.dart';

/// Opción del selector de lenguaje (id = clave en [builtinLanguages]).
class CodeLanguageOption {
  const CodeLanguageOption({required this.id, required this.label, this.icon});

  final String id;
  final String label;

  /// Si es null, se usa [codeLanguageIcon].
  final IconData? icon;
}

/// Lenguajes mostrados en el desplegable / hoja modal.
const kCodeLanguagePickerOptions = <CodeLanguageOption>[
  CodeLanguageOption(id: 'dart', label: 'Dart', icon: Icons.flutter_dash),
  CodeLanguageOption(
    id: 'typescript',
    label: 'TypeScript',
    icon: Icons.javascript_outlined,
  ),
  CodeLanguageOption(
    id: 'javascript',
    label: 'JavaScript',
    icon: Icons.javascript_outlined,
  ),
  CodeLanguageOption(
    id: 'python',
    label: 'Python',
    icon: Icons.terminal_rounded,
  ),
  CodeLanguageOption(
    id: 'json',
    label: 'JSON',
    icon: Icons.data_object_rounded,
  ),
  CodeLanguageOption(
    id: 'yaml',
    label: 'YAML',
    icon: Icons.account_tree_outlined,
  ),
  CodeLanguageOption(
    id: 'markdown',
    label: 'Markdown',
    icon: Icons.article_outlined,
  ),
  CodeLanguageOption(
    id: 'diff',
    label: 'Diff',
    icon: Icons.compare_arrows_rounded,
  ),
  CodeLanguageOption(id: 'sql', label: 'SQL', icon: Icons.table_chart_outlined),
  CodeLanguageOption(id: 'bash', label: 'Bash', icon: Icons.terminal_rounded),
  CodeLanguageOption(id: 'cpp', label: 'C / C++', icon: Icons.memory_rounded),
  CodeLanguageOption(id: 'java', label: 'Java', icon: Icons.coffee_outlined),
  CodeLanguageOption(id: 'kotlin', label: 'Kotlin', icon: Icons.code_rounded),
  CodeLanguageOption(
    id: 'rust',
    label: 'Rust',
    icon: Icons.settings_suggest_outlined,
  ),
  CodeLanguageOption(id: 'go', label: 'Go', icon: Icons.speed_rounded),
  CodeLanguageOption(id: 'xml', label: 'HTML / XML', icon: Icons.html_outlined),
  CodeLanguageOption(id: 'css', label: 'CSS', icon: Icons.style_outlined),
  CodeLanguageOption(
    id: 'plaintext',
    label: 'Texto plano',
    icon: Icons.notes_rounded,
  ),
];

IconData iconForCodeLanguageOption(CodeLanguageOption o) =>
    o.icon ?? codeLanguageIcon(o.id);

/// Icono por id (p. ej. lenguaje personalizado guardado en el bloque).
IconData codeLanguageIcon(String id) {
  for (final o in kCodeLanguagePickerOptions) {
    if (o.id == id) return o.icon ?? Icons.code_rounded;
  }
  return Icons.code_rounded;
}

Mode? modeForLanguageId(String? id) {
  final key = id?.trim();
  if (key == null || key.isEmpty) {
    return builtinLanguages['dart'];
  }
  return builtinLanguages[key] ?? builtinLanguages['plaintext'];
}

/// Tema de resaltado alineado con Material 3 (claro / oscuro).
CodeThemeData folioCodeThemeData(ThemeData theme) {
  final scheme = theme.colorScheme;
  final base =
      theme.textTheme.bodyMedium?.copyWith(
        fontFamily: 'monospace',
        fontSize: 13.5,
        height: 1.4,
      ) ??
      const TextStyle(fontFamily: 'monospace', fontSize: 13.5, height: 1.4);

  return CodeThemeData(
    classStyle: base.copyWith(
      color: scheme.primary,
      fontWeight: FontWeight.w600,
    ),
    commentStyle: base.copyWith(
      color: scheme.onSurfaceVariant,
      fontStyle: FontStyle.italic,
    ),
    functionStyle: base.copyWith(color: scheme.secondary),
    keywordStyle: base.copyWith(
      color: scheme.tertiary,
      fontWeight: FontWeight.w600,
    ),
    paramsStyle: base.copyWith(color: scheme.onSurface),
    quoteStyle: base.copyWith(color: scheme.primary),
    titleStyle: base.copyWith(
      color: scheme.onSurface,
      fontWeight: FontWeight.w600,
    ),
    variableStyle: base.copyWith(color: scheme.onSurface),
  );
}
