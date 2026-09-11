import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folio/features/workspace/editor/block_type_catalog.dart';
import 'package:folio/l10n/generated/app_localizations.dart';

/// Fase G1 del rediseño UX del editor: `resolveInlineSlashActionCatalog`
/// (comandos `cmd_*`) se movió de una función privada en `block_editor.dart`
/// a `block_type_catalog.dart`, junto a `blockTypeTemplates` — este archivo
/// pasa a ser la única fuente de verdad de "todo lo que puede aparecer en
/// el catálogo `/`". Estos tests prueban la completitud del registro
/// fusionado: ningún comando/tipo se perdió en el traslado, y no hay
/// colisiones de `key` entre las dos listas (lo que rompería el
/// `catalogIndex` combinado en `_catalogFilteredForSlash`).
void main() {
  test(
    'resolveInlineSlashActionCatalog conserva los 13 comandos cmd_* '
    'originales, sin duplicados ni pérdidas',
    () async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      final inline = resolveInlineSlashActionCatalog(l10n);

      const expectedKeys = {
        'cmd_ai_summarize',
        'cmd_ai_continue',
        'cmd_ai_explain',
        'cmd_ai_action_items',
        'cmd_ai_todo',
        'cmd_ai_mindmap',
        'cmd_ai_table',
        'cmd_ai_improve',
        'cmd_ai_translate',
        'cmd_duplicate_prev',
        'cmd_insert_date',
        'cmd_mention_page',
        'cmd_turn_into',
      };

      expect(inline.map((e) => e.key).toSet(), expectedKeys);
      expect(inline.length, expectedKeys.length);
      for (final entry in inline) {
        expect(entry.label, isNotEmpty, reason: '${entry.key} sin label');
      }
    },
  );

  test(
    'blockTypeTemplates y resolveInlineSlashActionCatalog no colisionan en '
    'key — el catalogIndex combinado de _catalogFilteredForSlash depende de '
    'que ambas listas sean disjuntas',
    () async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      final blockKeys = blockTypeTemplates.map((t) => t.key).toSet();
      final inlineKeys = resolveInlineSlashActionCatalog(
        l10n,
      ).map((e) => e.key).toSet();

      expect(blockKeys.intersection(inlineKeys), isEmpty);
    },
  );

  test(
    'resolveBlockTypeCatalog + resolveInlineSlashActionCatalog cubren, entre '
    'las dos, todo lo que _catalogFilteredForSlash concatena en producción '
    '(mismo conteo que blockTypeTemplates.length + 13 comandos)',
    () async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      final combined = [
        ...resolveBlockTypeCatalog(l10n),
        ...resolveInlineSlashActionCatalog(l10n),
      ];
      expect(combined.length, blockTypeTemplates.length + 13);
    },
  );
}
