import 'package:firebase_core/firebase_core.dart';

import 'folio_cloud_callable.dart';

/// Must match [CheckoutKind] in Cloud Functions (`createCheckoutSession`).
enum FolioCheckoutKind {
  folioCloudMonthly,
  inkSmall,
  inkMedium,
  inkLarge,
}

String _kindParam(FolioCheckoutKind k) {
  switch (k) {
    case FolioCheckoutKind.folioCloudMonthly:
      return 'folio_cloud_monthly';
    case FolioCheckoutKind.inkSmall:
      return 'ink_small';
    case FolioCheckoutKind.inkMedium:
      return 'ink_medium';
    case FolioCheckoutKind.inkLarge:
      return 'ink_large';
  }
}

/// Stripe Checkout URL from Cloud Function (server holds Stripe secret).
Future<Uri?> createFolioCheckoutUri(FolioCheckoutKind kind) async {
  if (Firebase.apps.isEmpty) return null;
  final res = await callFolioHttpsCallable(
    'createCheckoutSession',
    <String, dynamic>{'kind': _kindParam(kind)},
  );
  final url = (res as Map?)?.cast<String, dynamic>()['url'] as String?;
  if (url == null || url.isEmpty) return null;
  return Uri.parse(url);
}
