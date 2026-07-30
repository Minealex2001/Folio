import 'dart:convert';

import '../../config/folio_backend_config.dart';
import 'folio_cloud_http_client.dart';
import 'folio_cloud_identity.dart';

/// GET `/api/v1/account/me` → mapa compatible con `FolioCloudSnapshot.fromUserDoc`.
Future<Map<String, dynamic>?> folioSpringFetchAccountMeAsUserDoc({
  Duration timeout = const Duration(seconds: 20),
}) async {
  if (!FolioBackendConfig.useSpring) return null;
  if (!folioCloudHasSession()) return null;

  for (var attempt = 0; attempt < 2; attempt++) {
    final token = await folioCloudBearerToken(forceRefresh: attempt > 0);
    if (token == null || token.isEmpty) return null;

    final uri = Uri.parse('${FolioBackendConfig.apiV1Prefix}/account/me');
    final res = await folioCloudHttpClient
        .get(
          uri,
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        )
        .timeout(timeout);

    if (res.statusCode == 401 && attempt == 0) continue;
    if (res.statusCode == 404) return <String, dynamic>{};
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw StateError('account/me HTTP ${res.statusCode}: ${res.body}');
    }
    if (res.body.isEmpty) return <String, dynamic>{};
    final decoded = jsonDecode(res.body);
    if (decoded is! Map) return <String, dynamic>{};
    return folioSpringAccountMeToUserDoc(
      decoded.map((k, v) => MapEntry('$k', v)),
    );
  }
  return null;
}

/// Normaliza el JSON de AccountMeResponse al shape Firestore `users/{uid}`.
Map<String, dynamic> folioSpringAccountMeToUserDoc(Map<String, dynamic> me) {
  final folioCloudRaw = me['folioCloud'];
  final inkRaw = me['ink'];

  Map<String, dynamic> folioCloud = <String, dynamic>{};
  if (folioCloudRaw is Map) {
    folioCloud = folioCloudRaw.map((k, v) => MapEntry('$k', v));
  }

  // Spring expone `features` como JSON string o mapa.
  final featuresRaw = folioCloud['features'];
  Map<String, dynamic> features = <String, dynamic>{};
  if (featuresRaw is Map) {
    features = featuresRaw.map((k, v) => MapEntry('$k', v));
  } else if (featuresRaw is String && featuresRaw.trim().isNotEmpty) {
    try {
      final parsed = jsonDecode(featuresRaw);
      if (parsed is Map) {
        features = parsed.map((k, v) => MapEntry('$k', v));
      }
    } catch (_) {}
  }
  folioCloud['features'] = features;

  // El cliente lee `folioCloud.plan` en la raíz (Firestore); Spring lo guarda en features.plan.
  final planFromFeatures = features['plan']?.toString();
  if ((folioCloud['plan'] == null || '${folioCloud['plan']}'.trim().isEmpty) &&
      planFromFeatures != null &&
      planFromFeatures.trim().isNotEmpty) {
    folioCloud['plan'] = planFromFeatures.trim();
  }

  // Aliases booleanos que el cliente Firestore usaba en la raíz de folioCloud.
  folioCloud['isFamily'] = folioCloud['family'] ?? folioCloud['isFamily'];
  folioCloud['isStudent'] = folioCloud['student'] ?? folioCloud['isStudent'];
  folioCloud['folioStaff'] = me['folioStaff'] ?? folioCloud['folioStaff'];

  Map<String, dynamic> ink = <String, dynamic>{};
  if (inkRaw is Map) {
    ink = inkRaw.map((k, v) => MapEntry('$k', v));
  }

  return <String, dynamic>{
    'uid': me['uid'],
    'email': me['email'],
    'displayName': me['displayName'],
    'folioStaff': me['folioStaff'] == true,
    'folioCloud': folioCloud,
    'ink': ink,
    if (me['emailVerifiedAt'] != null)
      'emailVerifiedAt': me['emailVerifiedAt'],
  };
}
