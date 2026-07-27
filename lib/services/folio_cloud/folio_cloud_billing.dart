import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../../config/folio_backend_config.dart';
import 'folio_cloud_callable.dart';
import 'folio_cloud_identity.dart';

bool get _folioCloudBackendReady =>
    FolioBackendConfig.useSpring
        ? folioCloudHasSession() || FolioBackendConfig.baseUrl.isNotEmpty
        : Firebase.apps.isNotEmpty;

/// Opens Stripe Customer Portal via Cloud Function (server holds Stripe secret).
Future<Uri?> createBillingPortalUri() async {
  if (!_folioCloudBackendReady) return null;
  final res = await callFolioHttpsCallable(
    'createBillingPortalSession',
    <String, dynamic>{'debug': kDebugMode},
  );
  final url = (res as Map?)?.cast<String, dynamic>()['url'] as String?;
  if (url == null || url.isEmpty) return null;
  return Uri.parse(url);
}

/// Vuelve a leer la suscripción en Stripe y actualiza Firestore (por si el webhook fue lento o falló).
Future<void> syncFolioCloudSubscriptionFromStripe() async {
  if (!_folioCloudBackendReady) return;
  await callFolioHttpsCallable(
    'syncFolioCloudSubscriptionFromStripe',
    <String, dynamic>{'debug': kDebugMode},
  );
}

/// Valida la colección de Microsoft Store en el servidor y fusiona `folioCloud` / tinta.
Future<Map<String, dynamic>> validateMicrosoftStoreEntitlements({
  required String collectionsId,
}) async {
  if (!_folioCloudBackendReady) {
    throw StateError(
      FolioBackendConfig.useSpring
          ? 'Spring backend not configured'
          : 'Firebase not initialized',
    );
  }
  final res = await callFolioHttpsCallable(
    'validateMicrosoftStoreEntitlements',
    <String, dynamic>{'collectionsId': collectionsId},
  );
  return Map<String, dynamic>.from(res as Map);
}
