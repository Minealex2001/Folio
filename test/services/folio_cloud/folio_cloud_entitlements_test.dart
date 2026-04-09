import 'package:flutter_test/flutter_test.dart';
import 'package:folio/services/folio_cloud/folio_cloud_entitlements.dart';

void main() {
  group('FolioCloudSnapshot.fromUserDoc', () {
    test('parses nested folioCloud map like production Firestore', () {
      final data = <String, dynamic>{
        'stripeCustomerId': 'cus_test',
        'folioCloud': <String, dynamic>{
          'active': true,
          'subscriptionStatus': 'active',
          'subscriptionPriceId': 'price_1TK2TxLAKNSgRCusiZ7z3ZGU',
          'features': <String, dynamic>{
            'backup': true,
            'cloudAi': true,
            'publishWeb': true,
          },
        },
        'ink.monthlyBalance': 500,
        'ink.monthlyPeriodKey': '2026-04',
      };

      final snap = FolioCloudSnapshot.fromUserDoc(data);

      expect(snap.active, isTrue);
      expect(snap.subscriptionStatus, 'active');
      expect(snap.backup, isTrue);
      expect(snap.cloudAi, isTrue);
      expect(snap.publishWeb, isTrue);
      expect(snap.canUseCloudBackup, isTrue);
      expect(snap.canUseCloudAi, isTrue);
      expect(snap.canPublishToWeb, isTrue);
      expect(snap.ink.monthlyBalance, 500);
      expect(snap.ink.monthlyPeriodKey, '2026-04');
    });

    test('infers active from subscriptionStatus when active flag missing', () {
      final data = <String, dynamic>{
        'folioCloud': <String, dynamic>{
          'subscriptionStatus': 'active',
          'features': <String, dynamic>{
            'backup': true,
            'cloudAi': true,
            'publishWeb': true,
          },
        },
      };
      final snap = FolioCloudSnapshot.fromUserDoc(data);
      expect(snap.active, isTrue);
      expect(snap.subscriptionStatus, 'active');
    });

    test('returns empty entitlements when folioCloud missing', () {
      final snap = FolioCloudSnapshot.fromUserDoc(<String, dynamic>{
        'stripeCustomerId': 'cus_x',
      });
      expect(snap.active, isFalse);
      expect(snap.subscriptionStatus, isNull);
      expect(snap.canUseCloudAi, isFalse);
    });

    test('null data yields empty', () {
      expect(FolioCloudSnapshot.fromUserDoc(null), FolioCloudSnapshot.empty);
    });

    test('negative ink field is shown as 0 (server clamps same way when debiting)', () {
      final snap = FolioCloudSnapshot.fromUserDoc(<String, dynamic>{
        'folioCloud': <String, dynamic>{
          'active': true,
          'features': <String, dynamic>{
            'cloudAi': true,
          },
        },
        'ink': <String, dynamic>{
          'monthlyBalance': 40,
          'purchasedBalance': -12,
        },
      });
      expect(snap.ink.monthlyBalance, 40);
      expect(snap.ink.purchasedBalance, 0);
      expect(snap.ink.totalInk, 40);
    });

    test('caps absurd ink fields for display', () {
      final snap = FolioCloudSnapshot.fromUserDoc(<String, dynamic>{
        'folioCloud': <String, dynamic>{
          'active': true,
          'features': <String, dynamic>{
            'backup': true,
            'cloudAi': true,
            'publishWeb': true,
          },
        },
        'ink': <String, dynamic>{
          'monthlyBalance': 500,
          'purchasedBalance': 5000000,
        },
      });
      expect(snap.ink.monthlyBalance, 500);
      expect(snap.ink.purchasedBalance, 100000);
    });
  });

  group('FolioCloudEntitlementsController.applyInkBalancesFromCloudAi', () {
    test('updates ink and preserves plan flags and monthlyPeriodKey', () {
      final c = FolioCloudEntitlementsController();
      c.snapshot = FolioCloudSnapshot(
        active: true,
        subscriptionStatus: 'active',
        backup: true,
        cloudAi: true,
        publishWeb: false,
        ink: FolioInkSnapshot(
          monthlyBalance: 100,
          purchasedBalance: 5,
          monthlyPeriodKey: '2026-04',
        ),
      );
      c.applyInkBalancesFromCloudAi(
        monthlyBalance: 40,
        purchasedBalance: 12,
      );
      expect(c.snapshot.ink.monthlyBalance, 40);
      expect(c.snapshot.ink.purchasedBalance, 12);
      expect(c.snapshot.ink.monthlyPeriodKey, '2026-04');
      expect(c.snapshot.canUseCloudAi, isTrue);
    });
  });
}
