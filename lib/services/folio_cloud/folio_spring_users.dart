import 'dart:convert';

import '../../config/folio_backend_config.dart';
import 'folio_cloud_http_client.dart';
import 'folio_cloud_identity.dart';

/// `GET /api/v1/users/lookup?email=...` — resuelve un email a uid (solo
/// cuentas verificadas y activas). Devuelve `null` si no hay match, si la
/// cuenta no está verificada/activa, o si el llamante no tiene collab
/// habilitado — el servidor no distingue estos casos en la respuesta (ver
/// `UserLookupService` en el backend, mitigación de enumeración de usuarios).
Future<String?> folioSpringLookupUserUidByEmail(
  String email, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  if (!folioCloudHasSession()) return null;
  final trimmed = email.trim();
  if (trimmed.isEmpty) return null;

  for (var attempt = 0; attempt < 2; attempt++) {
    final token = await folioCloudBearerToken(forceRefresh: attempt > 0);
    if (token == null || token.isEmpty) return null;

    final uri = Uri.parse(
      '${FolioBackendConfig.apiV1Prefix}/users/lookup',
    ).replace(queryParameters: {'email': trimmed});
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
    if (res.statusCode == 404) return null;
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw StateError('users/lookup HTTP ${res.statusCode}: ${res.body}');
    }
    if (res.body.isEmpty) return null;
    final decoded = jsonDecode(res.body);
    if (decoded is! Map) return null;
    return decoded['uid']?.toString();
  }
  return null;
}
