import 'package:flutter_test/flutter_test.dart';
import 'package:folio/features/workspace/editor/paste_url_sheet.dart';

/// Fase D2 del rediseño UX del editor — clasificación pura de URLs pegadas
/// (GitHub/PDF), sin widget pump (mismo patrón que
/// `folio_slash_filter_test.dart`).
void main() {
  group('isGithubUrl', () {
    test('detecta github.com', () {
      expect(isGithubUrl('https://github.com/flutter/flutter'), isTrue);
    });

    test('detecta www.github.com', () {
      expect(isGithubUrl('https://www.github.com/flutter/flutter'), isTrue);
    });

    test('rechaza otros hosts', () {
      expect(isGithubUrl('https://gitlab.com/flutter/flutter'), isFalse);
      expect(isGithubUrl('https://example.com'), isFalse);
    });

    test('rechaza una URL malformada sin lanzar', () {
      expect(isGithubUrl('not a url'), isFalse);
    });
  });

  group('isPdfUrl', () {
    test('detecta una extensión .pdf', () {
      expect(isPdfUrl('https://example.com/doc.pdf'), isTrue);
    });

    test('detecta .pdf en mayúsculas', () {
      expect(isPdfUrl('https://example.com/DOC.PDF'), isTrue);
    });

    test('rechaza otras extensiones', () {
      expect(isPdfUrl('https://example.com/doc.docx'), isFalse);
      expect(isPdfUrl('https://example.com/'), isFalse);
    });

    test('rechaza una URL malformada sin lanzar', () {
      expect(isPdfUrl('not a url'), isFalse);
    });
  });
}
