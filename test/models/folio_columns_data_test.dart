import 'package:flutter_test/flutter_test.dart';
import 'package:folio/models/folio_columns_data.dart';

void main() {
  group('FolioColumnsData', () {
    test('tryParse devuelve estructura vacia si columns esta vacio', () {
      final parsed = FolioColumnsData.tryParse('{"v":2,"columns":[]}');

      expect(parsed, isNotNull);
      expect(parsed!.columns.length, 2);
      expect(parsed.columns.first.blocks, isNotEmpty);
      expect(parsed.columns.last.blocks, isNotEmpty);
    });

    test('tryParse completa columna faltante cuando viene una sola', () {
      final parsed = FolioColumnsData.tryParse(
        '{"v":2,"columns":[{"blocks":[{"id":"b1","type":"paragraph","text":"uno"}]}]}',
      );

      expect(parsed, isNotNull);
      expect(parsed!.columns.length, 2);
      expect(parsed.columns.first.blocks.first.text, 'uno');
    });

    test('tryParse recorta a maximo 3 columnas', () {
      final parsed = FolioColumnsData.tryParse(
        '{"v":2,"columns":[{"blocks":[]},{"blocks":[]},{"blocks":[]},{"blocks":[]}]}',
      );

      expect(parsed, isNotNull);
      expect(parsed!.columns.length, 3);
    });

    test('roundtrip encode/parse conserva columnas', () {
      final base = FolioColumnsData.empty();
      final parsed = FolioColumnsData.tryParse(base.encode());

      expect(parsed, isNotNull);
      expect(parsed!.columns.length, 2);
    });
  });
}
