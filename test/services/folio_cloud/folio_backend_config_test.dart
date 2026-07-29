import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:folio/config/folio_backend_config.dart';
import 'package:folio/services/cloud_account/folio_spring_auth_session.dart';
import 'package:folio/services/folio_cloud/folio_cloud_callable.dart';
import 'package:folio/services/folio_cloud/folio_spring_account_me.dart';
import 'package:folio/services/folio_cloud/folio_spring_callable_routes.dart';

void main() {
  group('FolioBackendConfig (default via FolioLocalSecrets)', () {
    test('useSpring follows FolioLocalSecrets when defines are empty', () {
      // En este checkout: secrets apuntan a Railway Spring.
      expect(FolioBackendConfig.useSpring, isTrue);
      expect(FolioBackendConfig.modeLabel, 'spring');
      expect(
        FolioBackendConfig.baseUrl,
        'https://backendfolio.minealexgames.com',
      );
    });

    test('folioHttpsCallableUsesHttp is platform-gated without Spring', () {
      // Con Spring activo el cliente fuerza HTTP en todas las plataformas.
      expect(FolioBackendConfig.useSpring, isTrue);
    });
  });

  group('decodeJwtPayload', () {
    test('decodes sub and email claims', () {
      // header.payload.sig — payload: {"sub":"uid1","email":"a@b.c"}
      final payload = base64Url
          .encode(utf8.encode('{"sub":"uid1","email":"a@b.c"}'))
          .replaceAll('=', '');
      final token = 'eyJhbGciOiJIUzI1NiJ9.$payload.sig';
      final claims = decodeJwtPayload(token);
      expect(claims?['sub'], 'uid1');
      expect(claims?['email'], 'a@b.c');
    });
  });

  group('Spring callable routes', () {
    test('maps core callables', () {
      expect(
        resolveFolioSpringApiRoute('ensureUserDocExists')?.pathBuilder({}),
        'account/ensure',
      );
      expect(
        resolveFolioSpringApiRoute('folioGetBackupStorageUsage')?.pathBuilder({}),
        'vault/backups/usage',
      );
      expect(
        resolveFolioSpringApiRoute('createCollabRoom')?.pathBuilder({}),
        'collab/rooms',
      );
      expect(
        resolveFolioSpringApiRoute('closeCollabRoom')
            ?.pathBuilder({'roomId': 'r1'}),
        'collab/rooms/r1/close',
      );
      expect(
        resolveFolioSpringApiRoute('folioCloudAiComplete')?.method,
        'POST',
      );
      expect(
        resolveFolioSpringApiRoute('folioCloudAiPricing')?.method,
        'GET',
      );
      expect(
        resolveFolioSpringApiRoute('updateAccountDisplayName')?.method,
        'PATCH',
      );
    });

    test('catalog prices has public Spring route', () {
      expect(kFolioSpringPendingCallables, isEmpty);
      final route = resolveFolioSpringApiRoute('folioCloudCatalogPrices');
      expect(route?.pathBuilder(const {}), 'billing/catalog-prices');
      expect(route?.requiresAuth, isFalse);
    });
  });

  group('folioSpringAccountMeToUserDoc', () {
    test('parses features JSON string and aliases', () {
      final doc = folioSpringAccountMeToUserDoc({
        'uid': 'u1',
        'email': 'a@b.c',
        'displayName': 'Ada',
        'folioCloud': {
          'active': true,
          'subscriptionStatus': 'active',
          'family': true,
          'student': false,
          'studentVerified': false,
          'familyOwnerUid': null,
          'familySeats': 3,
          'features':
              '{"backup":true,"cloudAi":true,"publishWeb":false,"realtimeCollab":true}',
        },
        'ink': {
          'monthlyBalance': 10,
          'purchasedBalance': 2,
          'monthlyPeriodKey': '2026-07',
        },
      });
      final fc = doc['folioCloud'] as Map<String, dynamic>;
      expect(fc['isFamily'], isTrue);
      expect(fc['isStudent'], isFalse);
      final features = fc['features'] as Map<String, dynamic>;
      expect(features['backup'], isTrue);
      expect(features['cloudAi'], isTrue);
      expect(features['publishWeb'], isFalse);
    });
  });
}
