import 'package:flutter_test/flutter_test.dart';
import 'package:folio/models/folio_page.dart';
import 'package:folio/data/vault_repository.dart';

void main() {
  group('VaultRepository starter content', () {
    List<FolioPage> buildStarterPages(VaultStarterContent starterContent) {
      return buildVaultStarterPages(starterContent);
    }

    test('crea páginas iniciales por defecto', () {
      final pages = buildStarterPages(VaultStarterContent.enabled);

      expect(pages, isNotEmpty);
      expect(pages.first.title, 'Empieza aquí');
      expect(pages.any((page) => page.title == 'Qué puede hacer Folio'), isTrue);
      expect(pages.any((page) => page.title == 'Quill y privacidad'), isTrue);
    });

    test('permite desactivar las páginas iniciales', () {
      final pages = buildStarterPages(VaultStarterContent.disabled);

      expect(pages, isEmpty);
    });
  });
}
