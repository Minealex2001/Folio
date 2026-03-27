import 'package:flutter_test/flutter_test.dart';
import 'package:folio/models/block.dart';

void main() {
  group('FolioBlock appearance', () {
    test('serializa y deserializa la apariencia del bloque', () {
      final block = FolioBlock(
        id: 'b1',
        type: 'paragraph',
        text: 'Hola',
        appearance: const FolioBlockAppearance(
          textColorRole: 'primary',
          backgroundRole: 'surface',
          fontScale: 1.15,
        ),
      );

      final encoded = block.toJson();
      final decoded = FolioBlock.fromJson(encoded);

      expect(decoded.appearance, isNotNull);
      expect(decoded.appearance!.textColorRole, 'primary');
      expect(decoded.appearance!.backgroundRole, 'surface');
      expect(decoded.appearance!.fontScale, 1.15);
    });

    test('omite apariencia por defecto al serializar', () {
      final block = FolioBlock(
        id: 'b1',
        type: 'paragraph',
        text: 'Hola',
        appearance: const FolioBlockAppearance(),
      );

      final encoded = block.toJson();

      expect(encoded.containsKey('appearance'), isFalse);
    });
  });
}
