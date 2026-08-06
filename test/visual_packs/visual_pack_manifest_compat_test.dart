import 'package:flutter_test/flutter_test.dart';
import 'package:folio/visual_packs/visual_pack_manifest.dart';

void main() {
  group('VisualPackManifest.isCompatible', () {
    VisualPackManifest manifestWith({String? min, String? max}) {
      return VisualPackManifest(
        id: 'x',
        name: 'X',
        description: '',
        minAppVersion: min,
        maxAppVersion: max,
      );
    }

    test('both bounds null (default, all builtin packs) is always compatible', () {
      final manifest = manifestWith();
      expect(manifest.isCompatible('0.1.0'), isTrue);
      expect(manifest.isCompatible('99.0.0'), isTrue);
    });

    test('below minAppVersion is incompatible', () {
      final manifest = manifestWith(min: '1.0.0');
      expect(manifest.isCompatible('0.9.0'), isFalse);
      expect(manifest.isCompatible('1.0.0'), isTrue); // límite inclusivo
      expect(manifest.isCompatible('1.0.1'), isTrue);
    });

    test('above maxAppVersion is incompatible', () {
      final manifest = manifestWith(max: '2.0.0');
      expect(manifest.isCompatible('2.0.1'), isFalse);
      expect(manifest.isCompatible('2.0.0'), isTrue); // límite inclusivo
      expect(manifest.isCompatible('1.9.0'), isTrue);
    });

    test('within [min, max] is compatible', () {
      final manifest = manifestWith(min: '1.0.0', max: '2.0.0');
      expect(manifest.isCompatible('1.5.0'), isTrue);
    });

    test('an unparseable current app version degrades to compatible '
        '(never blocks on a bad version string)', () {
      final manifest = manifestWith(min: '1.0.0');
      expect(manifest.isCompatible('not-a-version'), isTrue);
    });

    test('handles the build-metadata suffix used by pubspec.yaml (e.g. '
        '0.8.1+18)', () {
      final manifest = manifestWith(min: '0.8.0', max: '0.9.0');
      expect(manifest.isCompatible('0.8.1+18'), isTrue);
    });
  });

  group('PlatformSupport JSON round-trip', () {
    test('defaults to all platforms supported', () {
      const support = PlatformSupport();
      expect(support.supportsDesktop, isTrue);
      expect(support.supportsMobile, isTrue);
      expect(support.supportsWeb, isTrue);
    });

    test('round-trips through toJson/fromJson', () {
      const support = PlatformSupport(supportsMobile: false);
      final decoded = PlatformSupport.fromJson(support.toJson());
      expect(decoded.supportsMobile, isFalse);
      expect(decoded.supportsDesktop, isTrue);
    });
  });

  group('VisualPackManifest JSON round-trip with the new Fase 32 fields', () {
    test('minAppVersion/maxAppVersion/platformSupport survive toJson/fromJson', () {
      const manifest = VisualPackManifest(
        id: 'x',
        name: 'X',
        description: 'desc',
        minAppVersion: '1.0.0',
        maxAppVersion: '2.0.0',
        platformSupport: PlatformSupport(supportsMobile: false),
      );
      final decoded = VisualPackManifest.fromJson(manifest.toJson());
      expect(decoded.minAppVersion, '1.0.0');
      expect(decoded.maxAppVersion, '2.0.0');
      expect(decoded.platformSupport?.supportsMobile, isFalse);
    });

    test('omitted fields (builtin packs) round-trip as null', () {
      const manifest = VisualPackManifest(id: 'x', name: 'X', description: '');
      final decoded = VisualPackManifest.fromJson(manifest.toJson());
      expect(decoded.minAppVersion, isNull);
      expect(decoded.maxAppVersion, isNull);
      expect(decoded.platformSupport, isNull);
    });
  });
}
