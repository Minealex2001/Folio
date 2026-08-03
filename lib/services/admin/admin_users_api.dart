import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config/folio_backend_config.dart';
import 'admin_api_base.dart';

/// Admin console: `/api/v1/admin/whoami` + `/api/v1/admin/users/**`.
class AdminUsersApi extends AdminApiBase {
  const AdminUsersApi();

  /// Resolves the caller's admin role ('NONE' | 'SUPPORT' | 'MODERATOR' | 'BILLING_ADMIN' |
  /// 'SUPER_ADMIN'). UI-convenience only — the backend re-checks on every action.
  Future<String> whoami() async {
    final uri = Uri.parse('${FolioBackendConfig.apiV1Prefix}/admin/whoami');
    final res = await authorized((h) => http.get(uri, headers: h));
    ensureOk(res);
    return (jsonMap(res)['role'] as String?) ?? 'NONE';
  }

  Future<AdminPage> listUsers({
    int page = 0,
    int limit = 25,
    String? query,
    String? status,
    bool staffOnly = false,
  }) async {
    final uri =
        Uri.parse('${FolioBackendConfig.apiV1Prefix}/admin/users').replace(
      queryParameters: {
        'page': '$page',
        'limit': '$limit',
        if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
        if (status != null && status.isNotEmpty) 'status': status,
        if (staffOnly) 'staffOnly': 'true',
      },
    );
    final res = await authorized((h) => http.get(uri, headers: h));
    return parsePage(res, fallbackLimit: limit);
  }

  Future<Map<String, dynamic>> getUserDetail(String uid) async {
    final uri = Uri.parse('${FolioBackendConfig.apiV1Prefix}/admin/users/$uid');
    final res = await authorized((h) => http.get(uri, headers: h));
    ensureOk(res);
    return jsonMap(res);
  }

  Future<Map<String, dynamic>> setUserRole(String uid, String role) async {
    final uri = Uri.parse('${FolioBackendConfig.apiV1Prefix}/admin/users/$uid/role');
    final res = await authorized(
      (h) => http.post(uri, headers: h, body: jsonEncode({'role': role})),
    );
    ensureOk(res);
    return jsonMap(res);
  }
}
