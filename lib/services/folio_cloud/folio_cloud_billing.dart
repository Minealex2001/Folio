import 'package:flutter/foundation.dart';

import '../../config/folio_backend_config.dart';
import 'folio_cloud_callable.dart';
import 'folio_cloud_identity.dart';

bool get _folioCloudBackendReady =>
    FolioBackendConfig.useSpring
        ? folioCloudHasSession() || FolioBackendConfig.baseUrl.isNotEmpty
        : folioCloudHasSession();

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

/// Reclama el mes gratis de Folio Cloud por completar la importación directa
/// de Notion durante el onboarding (primer uso). Idempotente en el servidor
/// (`UserFolioCloudEntity.notionImportBonusClaimedAt`): una segunda llamada
/// del mismo usuario no concede un segundo mes.
///
/// Requiere sesión de Folio Cloud — si el usuario nunca ha iniciado sesión
/// (import puramente local, sin cuenta), no hay entitlement al que atarle el
/// bono, así que se lanza sin intentar la llamada. El llamante decide si
/// tratar el fallo como crítico; en el flujo de onboarding se ignora en
/// silencio (el import en sí ya se completó igual).
Future<bool> claimNotionImportBonus() async {
  if (!_folioCloudBackendReady || !folioCloudHasSession()) return false;
  final res = await callFolioHttpsCallable('claimNotionImportBonus', <String, dynamic>{});
  return (res is Map ? res['granted'] : null) != false;
}
