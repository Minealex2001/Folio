import 'dart:convert';

import 'package:folio/services/folio_cloud/folio_web_portal_api.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizeFolioWebLinkCode', () {
    test('trims, removes inner spaces, uppercases', () {
      expect(
        normalizeFolioWebLinkCode('  ab cd  \n'),
        'ABCD',
      );
      expect(normalizeFolioWebLinkCode('x'), 'X');
    });
  });

  group('extractFolioPortalErrorMessage', () {
    test('reads message key', () {
      expect(
        extractFolioPortalErrorMessage(
          jsonEncode({'message': '  hello  '}),
        ),
        'hello',
      );
    });

    test('reads error key', () {
      expect(
        extractFolioPortalErrorMessage(
          jsonEncode({'error': 'bad'}),
        ),
        'bad',
      );
    });
  });

  group('FolioWebEntitlementSnapshot.tryParseJsonObject', () {
    test('parses typical payload', () {
      final snap = FolioWebEntitlementSnapshot.tryParseJsonObject(
        jsonDecode(
          '{"linked":true,"folioCloud":true,"folioCloudStatus":"active",'
          '"folioCloudPeriodEnd":"2026-01-01","folioInkCredits":42}',
        ),
      );
      expect(snap, isNotNull);
      expect(snap!.linked, true);
      expect(snap.folioCloud, true);
      expect(snap.folioCloudStatus, 'active');
      expect(snap.folioCloudPeriodEnd, '2026-01-01');
      expect(snap.folioInkCredits, 42);
    });

    test('returns null without linked bool', () {
      expect(
        FolioWebEntitlementSnapshot.tryParseJsonObject(<String, dynamic>{}),
        isNull,
      );
    });
  });
}
