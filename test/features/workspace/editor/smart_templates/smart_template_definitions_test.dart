import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:folio/features/workspace/editor/smart_templates/smart_template_definitions.dart';
import 'package:folio/l10n/generated/app_localizations.dart';

/// Fase G2 del rediseño UX del editor — composición pura de bloques por
/// plantilla, con y sin variables resueltas. Sin widget, sin VaultSession:
/// solo `buildBlocks` como función pura.
void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  int counter = 0;
  String newBlockId() => 'blk_${counter++}';

  setUp(() {
    counter = 0;
  });

  group('kSmartTemplateMeeting', () {
    test('con variables vacías usa títulos por defecto y omite el callout de fecha', () {
      final blocks = kSmartTemplateMeeting.buildBlocks({}, newBlockId, l10n);

      expect(blocks.map((b) => b.type), [
        'h1',
        'meeting_note',
        'toggle',
        'h2',
        'todo',
      ]);
      expect(blocks.first.text, l10n.smartTemplateMeetingDefaultTitle);
    });

    test('con attendee y date interpola el título y añade el callout de fecha', () {
      final blocks = kSmartTemplateMeeting.buildBlocks(
        {'attendee': 'Ana', 'date': '2026-08-10'},
        newBlockId,
        l10n,
      );

      expect(blocks.map((b) => b.type), [
        'h1',
        'callout',
        'meeting_note',
        'toggle',
        'h2',
        'todo',
      ]);
      expect(blocks.first.text, l10n.smartTemplateMeetingTitleWith('Ana'));
      expect(blocks[1].text, l10n.smartTemplateMeetingDateLine('2026-08-10'));
    });

    test('genera ids únicos vía newBlockId para cada bloque', () {
      final blocks = kSmartTemplateMeeting.buildBlocks(
        {'attendee': 'Ana', 'date': '2026-08-10'},
        newBlockId,
        l10n,
      );
      expect(blocks.map((b) => b.id).toSet().length, blocks.length);
    });
  });

  group('kSmartTemplateSprint', () {
    test('con name vacío usa el título por defecto', () {
      final blocks = kSmartTemplateSprint.buildBlocks({}, newBlockId, l10n);
      expect(blocks.map((b) => b.type), ['h1', 'h2', 'bullet', 'h2', 'todo']);
      expect(blocks.first.text, l10n.smartTemplateSprintDefaultTitle);
    });

    test('con name interpola el título', () {
      final blocks = kSmartTemplateSprint.buildBlocks(
        {'name': 'Sprint 42'},
        newBlockId,
        l10n,
      );
      expect(blocks.first.text, l10n.smartTemplateSprintTitleWithName('Sprint 42'));
    });
  });

  group('kSmartTemplateRoadmap', () {
    test('no tiene variables y genera una estructura fija de 3 horizontes', () {
      expect(kSmartTemplateRoadmap.variables, isEmpty);
      final blocks = kSmartTemplateRoadmap.buildBlocks({}, newBlockId, l10n);
      expect(blocks.map((b) => b.type), [
        'h1',
        'h2',
        'bullet',
        'h2',
        'bullet',
        'h2',
        'bullet',
      ]);
    });
  });

  group('smartTemplateForCmdKey', () {
    test('resuelve cada clave cmd_smart_* a su definición', () {
      expect(smartTemplateForCmdKey('cmd_smart_meeting'), kSmartTemplateMeeting);
      expect(smartTemplateForCmdKey('cmd_smart_sprint'), kSmartTemplateSprint);
      expect(smartTemplateForCmdKey('cmd_smart_roadmap'), kSmartTemplateRoadmap);
    });

    test('clave desconocida devuelve null', () {
      expect(smartTemplateForCmdKey('cmd_smart_unknown'), isNull);
    });
  });
}
