import 'package:flutter_test/flutter_test.dart';
import 'package:folio/models/folio_template_button_data.dart';

void main() {
  group('FolioTemplateButtonData', () {
    test('tryParse devuelve default cuando blocks viene vacio', () {
      final parsed = FolioTemplateButtonData.tryParse(
        '{"v":1,"label":"Mi plantilla","blocks":[]}',
      );

      expect(parsed, isNotNull);
      expect(parsed!.label, 'Plantilla');
      expect(parsed.blocks, isNotEmpty);
    });

    test('roundtrip encode/parse conserva label y bloques', () {
      final base = FolioTemplateButtonData.defaultNew();
      final parsed = FolioTemplateButtonData.tryParse(base.encode());

      expect(parsed, isNotNull);
      expect(parsed!.label, base.label);
      expect(parsed.blocks.length, base.blocks.length);
      expect(parsed.blocks.first.type, base.blocks.first.type);
    });

    test('raw vacio devuelve null', () {
      final parsed = FolioTemplateButtonData.tryParse('');

      expect(parsed, isNull);
    });
  });
}
