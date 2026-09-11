import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config/folio_backend_config.dart';
import 'admin_api_base.dart';

/// Admin console: `/api/v1/admin/organizations/**`.
class AdminOrganizationsApi extends AdminApiBase {
  const AdminOrganizationsApi();

  Future<AdminPage> list({int page = 0, int limit = 25, String? query}) async {
    final uri = Uri.parse('${FolioBackendConfig.apiV1Prefix}/admin/organizations').replace(
      queryParameters: {
        'page': '$page',
        'limit': '$limit',
        if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
      },
    );
    final res = await authorized((h) => http.get(uri, headers: h));
    return parsePage(res, fallbackLimit: limit);
  }

  Future<Map<String, dynamic>> detail(String orgId) async {
    final uri = Uri.parse('${FolioBackendConfig.apiV1Prefix}/admin/organizations/$orgId');
    final res = await authorized((h) => http.get(uri, headers: h));
    ensureOk(res);
    return jsonMap(res);
  }

  Future<Map<String, dynamic>> grantCloud(
    String orgId, {
    int? seats,
    int? inkDrops,
  }) async {
    final uri = Uri.parse(
      '${FolioBackendConfig.apiV1Prefix}/admin/organizations/$orgId/entitlements/grant-cloud',
    );
    final body = <String, dynamic>{
      if (seats != null) 'seats': seats,
      if (inkDrops != null) 'inkDrops': inkDrops,
    };
    final res = await authorized(
      (h) => http.post(uri, headers: h, body: jsonEncode(body)),
    );
    ensureOk(res);
    return jsonMap(res);
  }

  Future<Map<String, dynamic>> revokeCloud(String orgId) async {
    final uri = Uri.parse(
      '${FolioBackendConfig.apiV1Prefix}/admin/organizations/$orgId/entitlements/revoke-cloud',
    );
    final res = await authorized((h) => http.post(uri, headers: h));
    ensureOk(res);
    return jsonMap(res);
  }

  Future<Map<String, dynamic>> grantInk(String orgId, {int? inkDrops}) async {
    final uri = Uri.parse(
      '${FolioBackendConfig.apiV1Prefix}/admin/organizations/$orgId/ink/grant',
    );
    final body = <String, dynamic>{
      if (inkDrops != null) 'inkDrops': inkDrops,
    };
    final res = await authorized(
      (h) => http.post(uri, headers: h, body: jsonEncode(body)),
    );
    ensureOk(res);
    return jsonMap(res);
  }
}
