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
            'realtimeCollab': true,
          },
        },
        'folioBackup': <String, dynamic>{
          'quotaBytes': 6000000000,
          'usedBytes': 1000,
          'purchasedBytes': 1000000000,
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
      expect(snap.realtimeCollab, isTrue);
      expect(snap.canUseCloudBackup, isTrue);
      expect(snap.canUseCloudAi, isTrue);
      expect(snap.canPublishToWeb, isTrue);
      expect(snap.canRealtimeCollab, isTrue);
      expect(snap.ink.monthlyBalance, 500);
      expect(snap.ink.monthlyPeriodKey, '2026-04');
      expect(snap.backupQuotaBytes, 6000000000);
      expect(snap.backupUsedBytes, 1000);
      expect(snap.backupPurchasedBytes, 1000000000);
      expect(snap.backupSubscriptionExtraBytes, 0);
      expect(snap.backupExtraBytesTotal, 1000000000);
    });

    test('parses stripeSubscriptionExtraBytes under folioBackup', () {
      final data = <String, dynamic>{
        'folioCloud': <String, dynamic>{
          'active': true,
          'features': <String, dynamic>{'backup': true},
        },
        'folioBackup': <String, dynamic>{
          'purchasedBytes': 100,
          'stripeSubscriptionExtraBytes': 2000000000,
        },
      };
      final snap = FolioCloudSnapshot.fromUserDoc(data);
      expect(snap.backupPurchasedBytes, 100);
      expect(snap.backupSubscriptionExtraBytes, 2000000000);
      expect(snap.backupExtraBytesTotal, 2000000100);
    });

    test('infers active from subscriptionStatus when active flag missing', () {
      final data = <String, dynamic>{
        'folioCloud': <String, dynamic>{
          'subscriptionStatus': 'active',
          'features': <String, dynamic>{
            'backup': true,
            'cloudAi': true,
            'publishWeb': true,
            'realtimeCollab': true,
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

    test('canUseCloudAi with purchased ink only (no subscription)', () {
      final snap = FolioCloudSnapshot.fromUserDoc(<String, dynamic>{
        'ink': <String, dynamic>{
          'monthlyBalance': 0,
          'purchasedBalance': 100,
        },
      });
      expect(snap.active, isFalse);
      expect(snap.cloudAi, isFalse);
      expect(snap.canUseCloudAi, isTrue);
    });

    test('canUseCloudAi false when inactive subscription and no purchased ink', () {
      final snap = FolioCloudSnapshot.fromUserDoc(<String, dynamic>{
        'folioCloud': <String, dynamic>{
          'active': false,
          'features': <String, dynamic>{'cloudAi': true},
        },
        'ink': <String, dynamic>{
          'monthlyBalance': 0,
          'purchasedBalance': 0,
        },
      });
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

    test('purchased ink is not capped; huge monthlyBalance is capped for display', () {
      final snap = FolioCloudSnapshot.fromUserDoc(<String, dynamic>{
        'folioCloud': <String, dynamic>{
          'active': true,
          'features': <String, dynamic>{
            'backup': true,
            'cloudAi': true,
            'publishWeb': true,
            'realtimeCollab': true,
          },
        },
        'ink': <String, dynamic>{
          'monthlyBalance': 5000000,
          'purchasedBalance': 5000000,
        },
      });
      expect(snap.ink.monthlyBalance, 100000);
      expect(snap.ink.purchasedBalance, 5000000);
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
        realtimeCollab: false,
        backupQuotaBytes: 6000000000,
        backupUsedBytes: 1234,
        backupPurchasedBytes: 1000000000,
        backupSubscriptionExtraBytes: 500000000,
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
      expect(c.snapshot.backupQuotaBytes, 6000000000);
      expect(c.snapshot.backupUsedBytes, 1234);
      expect(c.snapshot.backupPurchasedBytes, 1000000000);
      expect(c.snapshot.backupSubscriptionExtraBytes, 500000000);
    });
  });
}
