import 'package:flutter_test/flutter_test.dart';
import 'package:folio/models/folio_page_import_info.dart';

void main() {
  group('FolioPageImportInfo', () {
    test('fromJson aplica defaults cuando faltan campos', () {
      final info = FolioPageImportInfo.fromJson({});

      expect(info.clientAppId, 'unknown-client');
      expect(info.clientAppName, 'Unknown client');
      expect(info.importedAtMs, 0);
      expect(info.importMode, 'newPage');
      expect(info.metadata, isEmpty);
    });

    test('roundtrip toJson/fromJson conserva data y metadata', () {
      final base = FolioPageImportInfo(
        clientAppId: 'folio-desktop',
        clientAppName: 'Folio',
        importedAtMs: 123456789,
        importMode: 'merge',
        sessionId: 's1',
        sourceApp: 'notion',
        sourceUrl: 'https://example.test',
        metadata: {'key': 'value'},
      );

      final parsed = FolioPageImportInfo.fromJson(base.toJson());

      expect(parsed.clientAppId, 'folio-desktop');
      expect(parsed.clientAppName, 'Folio');
      expect(parsed.importedAtMs, 123456789);
      expect(parsed.importMode, 'merge');
      expect(parsed.sessionId, 's1');
      expect(parsed.sourceApp, 'notion');
      expect(parsed.sourceUrl, 'https://example.test');
      expect(parsed.metadata['key'], 'value');
    });
  });
}
