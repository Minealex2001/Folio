import 'package:flutter/material.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:highlight/highlight_core.dart';
import 'package:highlight/languages/all.dart';

import '../../../l10n/generated/app_localizations.dart';

/// Opción del selector de lenguaje (id = clave en [builtinLanguages]).
class CodeLanguageOption {
  const CodeLanguageOption({required this.id, required this.label, this.icon});

  final String id;
  final String label;

  /// Si es null, se usa [codeLanguageIcon].
  final IconData? icon;
}

List<CodeLanguageOption> buildCodeLanguagePickerOptions(AppLocalizations l10n) =>
    <CodeLanguageOption>[
      CodeLanguageOption(
        id: 'dart',
        label: l10n.codeLangDart,
        icon: Icons.flutter_dash,
      ),
      CodeLanguageOption(
        id: 'typescript',
        label: l10n.codeLangTypeScript,
        icon: Icons.javascript_outlined,
      ),
      CodeLanguageOption(
        id: 'javascript',
        label: l10n.codeLangJavaScript,
        icon: Icons.javascript_outlined,
      ),
      CodeLanguageOption(
        id: 'python',
        label: l10n.codeLangPython,
        icon: Icons.terminal_rounded,
      ),
      CodeLanguageOption(
        id: 'json',
        label: l10n.codeLangJson,
        icon: Icons.data_object_rounded,
      ),
      CodeLanguageOption(
        id: 'yaml',
        label: l10n.codeLangYaml,
        icon: Icons.account_tree_outlined,
      ),
      CodeLanguageOption(
        id: 'markdown',
        label: l10n.codeLangMarkdown,
        icon: Icons.article_outlined,
      ),
      CodeLanguageOption(
        id: 'diff',
        label: l10n.codeLangDiff,
        icon: Icons.compare_arrows_rounded,
      ),
      CodeLanguageOption(
        id: 'sql',
        label: l10n.codeLangSql,
        icon: Icons.table_chart_outlined,
      ),
      CodeLanguageOption(
        id: 'bash',
        label: l10n.codeLangBash,
        icon: Icons.terminal_rounded,
      ),
      CodeLanguageOption(
        id: 'cpp',
        label: l10n.codeLangCpp,
        icon: Icons.memory_rounded,
      ),
      CodeLanguageOption(
        id: 'java',
        label: l10n.codeLangJava,
        icon: Icons.coffee_outlined,
      ),
      CodeLanguageOption(
        id: 'kotlin',
        label: l10n.codeLangKotlin,
        icon: Icons.code_rounded,
      ),
      CodeLanguageOption(
        id: 'rust',
        label: l10n.codeLangRust,
        icon: Icons.settings_suggest_outlined,
      ),
      CodeLanguageOption(
        id: 'go',
        label: l10n.codeLangGo,
        icon: Icons.speed_rounded,
      ),
      CodeLanguageOption(
        id: 'xml',
        label: l10n.codeLangHtmlXml,
        icon: Icons.html_outlined,
      ),
      CodeLanguageOption(
        id: 'css',
        label: l10n.codeLangCss,
        icon: Icons.style_outlined,
      ),
      // Idiomas extra: el motor de resaltado (highlight) soporta muchos ids;
      // el picker solo necesita exponerlos. Si algún id no existe, el fallback
      // seguirá siendo plaintext (ver modeForLanguageId).
      const CodeLanguageOption(
        id: 'csharp',
        label: 'C#',
        icon: Icons.tag_rounded,
      ),
      const CodeLanguageOption(
        id: 'php',
        label: 'PHP',
        icon: Icons.web_rounded,
      ),
      const CodeLanguageOption(
        id: 'ruby',
        label: 'Ruby',
        icon: Icons.diamond_outlined,
      ),
      const CodeLanguageOption(
        id: 'swift',
        label: 'Swift',
        icon: Icons.bolt_rounded,
      ),
      const CodeLanguageOption(
        id: 'r',
        label: 'R',
        icon: Icons.query_stats_rounded,
      ),
      const CodeLanguageOption(
        id: 'scala',
        label: 'Scala',
        icon: Icons.stacked_line_chart_rounded,
      ),
      const CodeLanguageOption(
        id: 'perl',
        label: 'Perl',
        icon: Icons.code_rounded,
      ),
      const CodeLanguageOption(
        id: 'objectivec',
        label: 'Objective-C',
        icon: Icons.phone_iphone_rounded,
      ),
      const CodeLanguageOption(
        id: 'powershell',
        label: 'PowerShell',
        icon: Icons.terminal_rounded,
      ),
      const CodeLanguageOption(
        id: 'dockerfile',
        label: 'Dockerfile',
        icon: Icons.inventory_2_outlined,
      ),
      const CodeLanguageOption(
        id: 'toml',
        label: 'TOML',
        icon: Icons.tune_rounded,
      ),
      const CodeLanguageOption(
        id: 'ini',
        label: 'INI',
        icon: Icons.settings_rounded,
      ),
      const CodeLanguageOption(
        id: 'graphql',
        label: 'GraphQL',
        icon: Icons.hub_rounded,
      ),
      const CodeLanguageOption(
        id: 'protobuf',
        label: 'Protocol Buffers',
        icon: Icons.schema_rounded,
      ),
      CodeLanguageOption(
        id: 'plaintext',
        label: l10n.codeLangPlainText,
        icon: Icons.notes_rounded,
      ),
    ];

String labelForCodeLanguageId(String id, AppLocalizations l10n) {
  for (final o in buildCodeLanguagePickerOptions(l10n)) {
    if (o.id == id) return o.label;
  }
  return id;
}

IconData iconForCodeLanguageOption(CodeLanguageOption o) =>
    o.icon ?? codeLanguageIcon(o.id);

/// Icono por id (p. ej. lenguaje personalizado guardado en el bloque).
IconData codeLanguageIcon(String id) {
  for (final o in buildCodeLanguagePickerOptions(_iconLookupL10n)) {
    if (o.id == id) return o.icon ?? Icons.code_rounded;
  }
  return Icons.code_rounded;
}

/// Solo para resolver iconos cuando no hay contexto (etiquetas no se usan).
final AppLocalizations _iconLookupL10n =
    lookupAppLocalizations(const Locale('en'));

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
