import 'package:flutter_test/flutter_test.dart';
import 'package:folio/models/folio_toggle_data.dart';

void main() {
  group('FolioToggleData', () {
    test('raw vacio devuelve objeto vacio', () {
      final parsed = FolioToggleData.tryParse('   ');

      expect(parsed, isNotNull);
      expect(parsed!.title, '');
      expect(parsed.body, '');
    });

    test('roundtrip encode/parse mantiene campos', () {
      final data = FolioToggleData(title: 'Titulo', body: 'Contenido');
      final parsed = FolioToggleData.tryParse(data.encode());

      expect(parsed, isNotNull);
      expect(parsed!.title, 'Titulo');
      expect(parsed.body, 'Contenido');
    });

    test('json invalido devuelve null', () {
      final parsed = FolioToggleData.tryParse('{bad json');

      expect(parsed, isNull);
    });
  });
}
