import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'folio_cloud_billing.dart';
import 'folio_microsoft_store_channel.dart';
import 'folio_microsoft_store_products.dart';

/// Pon a `true` para volver a sincronizar colección MS → Cloud Functions
/// («Actualizar», al reanudar, etc.). Las compras en Tienda siguen llamando
/// la sync con [force].
const bool kFolioMicrosoftStoreEntitlementsSyncEnabled = false;

/// Obtiene el id de colección del usuario y sincroniza derechos con Cloud Functions.
///
/// Si [kFolioMicrosoftStoreEntitlementsSyncEnabled] es `false`, no hace nada salvo
/// que [force] sea `true` (p. ej. tras [purchaseMicrosoftStoreProductAndSync]).
Future<void> syncFolioMicrosoftStoreEntitlementsFromDevice({
  bool force = false,
}) async {
  if (!force && !kFolioMicrosoftStoreEntitlementsSyncEnabled) {
    debugPrint(
      'FolioMicrosoftStore: sync omitida (kFolioMicrosoftStoreEntitlementsSyncEnabled=false)',
    );
    return;
  }
  if (Firebase.apps.isEmpty) {
    throw StateError('Firebase not initialized');
  }
  if (!FolioMicrosoftStoreChannel.isRuntimeSupported) {
    throw StateError('Microsoft Store channel is only available on Windows');
  }
  final id = await FolioMicrosoftStoreChannel.getCustomerCollectionsId();
  if (id == null || id.trim().isEmpty) {
    throw StateError('Empty Microsoft Store collections id');
  }
  await validateMicrosoftStoreEntitlements(collectionsId: id.trim());
}

/// Compra en la Tienda y, si procede, sincroniza con el backend.
Future<void> purchaseMicrosoftStoreProductAndSync(String storeProductId) async {
  if (storeProductId.trim().isEmpty) {
    throw ArgumentError.value(storeProductId, 'storeProductId');
  }
  final res = await FolioMicrosoftStoreChannel.requestPurchase(
    storeProductId.trim(),
  );
  final name = res?['statusName'] as String? ?? '';
  final ok = name == 'succeeded' || name == 'alreadyPurchased';
  if (!ok) {
    throw StateError(
      res == null
          ? 'Purchase returned no result'
          : 'Purchase not completed: $name',
    );
  }
  await syncFolioMicrosoftStoreEntitlementsFromDevice(force: true);
}

Future<void> purchaseMicrosoftStoreMonthlyIfConfigured() async {
  if (!FolioMicrosoftStoreProducts.hasMonthlyProductId) {
    throw StateError(
      'MS_STORE_PRODUCT_FOLIO_CLOUD_MONTHLY is not set (dart-define)',
    );
  }
  await purchaseMicrosoftStoreProductAndSync(
    FolioMicrosoftStoreProducts.folioCloudMonthly,
  );
}

Future<void> purchaseMicrosoftStoreInk(FolioMicrosoftStoreInkKind kind) async {
  final id = switch (kind) {
    FolioMicrosoftStoreInkKind.small => FolioMicrosoftStoreProducts.inkSmall,
    FolioMicrosoftStoreInkKind.medium => FolioMicrosoftStoreProducts.inkMedium,
    FolioMicrosoftStoreInkKind.large => FolioMicrosoftStoreProducts.inkLarge,
  };
  if (id.trim().isEmpty) {
    throw StateError(
      'Microsoft Store product id not set for this ink pack (dart-define)',
    );
  }
  await purchaseMicrosoftStoreProductAndSync(id.trim());
}

enum FolioMicrosoftStoreInkKind { small, medium, large }

enum FolioMicrosoftStoreBackupStorageKind { small, medium, large }

Future<void> purchaseMicrosoftStoreBackupStorage(
  FolioMicrosoftStoreBackupStorageKind kind,
) async {
  final id = switch (kind) {
    FolioMicrosoftStoreBackupStorageKind.small =>
      FolioMicrosoftStoreProducts.backupStoragePackSmall,
    FolioMicrosoftStoreBackupStorageKind.medium =>
      FolioMicrosoftStoreProducts.backupStoragePackMedium,
    FolioMicrosoftStoreBackupStorageKind.large =>
      FolioMicrosoftStoreProducts.backupStoragePackLarge,
  }
      .trim();
  if (id.isEmpty) {
    throw StateError(
      'Microsoft Store product id not set for this backup tier (dart-define)',
    );
  }
  await purchaseMicrosoftStoreProductAndSync(id);
}
