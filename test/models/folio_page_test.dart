import 'package:flutter_test/flutter_test.dart';
import 'package:folio/models/block.dart';
import 'package:folio/models/folio_page.dart';

void main() {
  group('FolioPage', () {
    test('serializa y deserializa bloques y metadatos de colaboracion', () {
      final page = FolioPage(
        id: 'p1',
        title: 'Notas',
        emoji: '📝',
        collabRoomId: ' room-123 ',
        collabJoinCode: ' 123456 ',
        blocks: [
          FolioBlock(id: 'b1', type: 'paragraph', text: 'Hola mundo'),
          FolioBlock(id: 'b2', type: 'todo', text: 'Pendiente', checked: false),
        ],
      );

      final encoded = page.toJson();
      final decoded = FolioPage.fromJson(encoded);

      expect(decoded.id, 'p1');
      expect(decoded.title, 'Notas');
      expect(decoded.emoji, '📝');
      expect(decoded.collabRoomId, 'room-123');
      expect(decoded.collabJoinCode, '123456');
      expect(decoded.blocks.length, 2);
      expect(decoded.blocks.first.text, 'Hola mundo');
      expect(decoded.blocks.last.type, 'todo');
    });

    test('crea bloque por defecto cuando blocks no existe en json', () {
      final decoded = FolioPage.fromJson({'id': 'p2', 'title': 'Sin bloques'});

      expect(decoded.blocks, isNotEmpty);
      expect(decoded.blocks.first.type, 'paragraph');
      expect(decoded.blocks.first.id, 'p2_b0');
    });

    test('normaliza collabRoomId y collabJoinCode vacios a null', () {
      final decoded = FolioPage.fromJson({
        'id': 'p3',
        'title': 'Colaboracion',
        'collabRoomId': '   ',
        'collabJoinCode': '',
      });

      expect(decoded.collabRoomId, isNull);
      expect(decoded.collabJoinCode, isNull);
    });

    test('plainTextContent agrega representaciones especiales', () {
      final page = FolioPage(
        id: 'p4',
        title: 'Contenido',
        blocks: [
          FolioBlock(id: 'b1', type: 'paragraph', text: 'Linea 1'),
          FolioBlock(
            id: 'b2',
            type: 'bookmark',
            text: 'Sitio',
            url: 'https://a.test',
          ),
          FolioBlock(id: 'b3', type: 'audio', text: '', url: 'song.mp3'),
        ],
      );

      expect(page.plainTextContent, contains('Linea 1'));
      expect(
        page.plainTextContent,
        contains('[bookmark] Sitio https://a.test'),
      );
      expect(page.plainTextContent, contains('[audio] song.mp3'));
    });

    test('syncPlainFallback actualiza bloque unico de parrafo', () {
      final page = FolioPage(
        id: 'p5',
        title: 'Fallback',
        blocks: [FolioBlock(id: 'b1', type: 'paragraph', text: 'Antes')],
      );

      page.syncPlainFallback('Despues');

      expect(page.blocks.length, 1);
      expect(page.blocks.first.type, 'paragraph');
      expect(page.blocks.first.text, 'Despues');
    });

    test('syncPlainFallback crea bloque cuando lista vacia', () {
      final page = FolioPage(id: 'p6', title: 'Nueva', blocks: []);

      page.syncPlainFallback('Texto inicial');

      expect(page.blocks, isNotEmpty);
      expect(page.blocks.first.id, 'p6_b0');
      expect(page.blocks.first.text, 'Texto inicial');
    });
  });
}
