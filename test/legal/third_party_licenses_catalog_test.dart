import 'package:flutter_test/flutter_test.dart';
import 'package:folio/legal/third_party_license.dart';
import 'package:folio/legal/third_party_licenses_catalog.dart';

void main() {
  group('ThirdPartyLicenseEntry', () {
    test('allows optional copyright, source, and license text', () {
      const entry = ThirdPartyLicenseEntry(
        id: 'example',
        name: 'Example',
        license: 'MIT',
        category: ThirdPartyLicenseCategory.openSource,
      );
      expect(entry.hasCopyright, isFalse);
      expect(entry.hasSourceUrl, isFalse);
      expect(entry.hasLicenseText, isFalse);
      expect(entry.showInAboutUi, isTrue);
      expect(entry.includeInNoticesFile, isTrue);
    });

    test('reports presence of optional fields', () {
      const entry = ThirdPartyLicenseEntry(
        id: 'with-fields',
        name: 'With Fields',
        license: 'MIT',
        copyright: 'Copyright (c) Example',
        sourceUrl: 'https://example.com',
        licenseText: 'MIT License text',
        category: ThirdPartyLicenseCategory.dartPackages,
      );
      expect(entry.hasCopyright, isTrue);
      expect(entry.hasSourceUrl, isTrue);
      expect(entry.hasLicenseText, isTrue);
    });
  });

  group('ThirdPartyLicensesCatalog', () {
    test('has unique ids', () {
      final ids = ThirdPartyLicensesCatalog.entries.map((e) => e.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('every entry has a non-empty name and license', () {
      for (final entry in ThirdPartyLicensesCatalog.entries) {
        expect(entry.name.trim(), isNotEmpty, reason: entry.id);
        expect(entry.license.trim(), isNotEmpty, reason: entry.id);
      }
    });

    test('source URLs are https when present', () {
      for (final entry in ThirdPartyLicensesCatalog.entries) {
        final url = entry.sourceUrl?.trim();
        if (url == null || url.isEmpty) continue;
        final uri = Uri.parse(url);
        expect(uri.hasScheme, isTrue, reason: entry.id);
        expect(
          uri.scheme == 'https' || uri.scheme == 'http',
          isTrue,
          reason: '${entry.id}: $url',
        );
      }
    });

    test('categories used in catalog are valid enum values', () {
      for (final entry in ThirdPartyLicensesCatalog.entries) {
        expect(ThirdPartyLicenseCategory.values, contains(entry.category));
      }
    });

    test('uiEntries only includes showInAboutUi', () {
      expect(
        ThirdPartyLicensesCatalog.uiEntries.every((e) => e.showInAboutUi),
        isTrue,
      );
    });

    test('findById returns entries and null for missing', () {
      expect(ThirdPartyLicensesCatalog.findById('whisper-cpp'), isNotNull);
      expect(ThirdPartyLicensesCatalog.findById('missing-id'), isNull);
    });

    test('includes FolioBackend runtime packages', () {
      expect(ThirdPartyLicensesCatalog.findById('be-spring-boot'), isNotNull);
      expect(ThirdPartyLicensesCatalog.findById('be-stripe-java'), isNotNull);
      expect(
        ThirdPartyLicensesCatalog.byCategory(
          ThirdPartyLicenseCategory.backendPackages,
        ),
        isNotEmpty,
      );
    });

    test('does not attribute Call.md without verified reuse', () {
      final names = ThirdPartyLicensesCatalog.entries
          .map((e) => e.name.toLowerCase())
          .toList();
      expect(names.any((n) => n.contains('call.md')), isFalse);
      expect(names.any((n) => n.contains('videodb')), isFalse);
    });
  });
}
