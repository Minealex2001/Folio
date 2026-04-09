import 'package:firebase_core/firebase_core.dart';

import 'folio_cloud_callable.dart';

/// Opens Stripe Customer Portal via Cloud Function (server holds Stripe secret).
Future<Uri?> createBillingPortalUri() async {
  if (Firebase.apps.isEmpty) return null;
  final res = await callFolioHttpsCallable('createBillingPortalSession');
  final url = (res as Map?)?.cast<String, dynamic>()['url'] as String?;
  if (url == null || url.isEmpty) return null;
  return Uri.parse(url);
}

/// Vuelve a leer la suscripción en Stripe y actualiza Firestore (por si el webhook fue lento o falló).
Future<void> syncFolioCloudSubscriptionFromStripe() async {
  if (Firebase.apps.isEmpty) return;
  await callFolioHttpsCallable('syncFolioCloudSubscriptionFromStripe');
}
