import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config/folio_backend_config.dart';
import 'admin_api_base.dart';

class AdminDiagnosticsApi extends AdminApiBase {
  const AdminDiagnosticsApi();

  Future<AdminPage> list({int page = 0, int limit = 25, String? status, String? kind}) async {
    final uri = Uri.parse('${FolioBackendConfig.apiV1Prefix}/admin/diagnostics').replace(
      queryParameters: {
        'page': '$page',
        'limit': '$limit',
        if (status != null && status.isNotEmpty) 'status': status,
        if (kind != null && kind.isNotEmpty) 'kind': kind,
      },
    );
    final res = await authorized((h) => http.get(uri, headers: h));
    return parsePage(res, fallbackLimit: limit);
  }

  Future<Map<String, dynamic>> detail(String id) async {
    final uri = Uri.parse('${FolioBackendConfig.apiV1Prefix}/admin/diagnostics/$id');
    final res = await authorized((h) => http.get(uri, headers: h));
    ensureOk(res);
    return jsonMap(res);
  }

  Future<Map<String, dynamic>> setStatus(String id, String status) async {
    final uri = Uri.parse('${FolioBackendConfig.apiV1Prefix}/admin/diagnostics/$id/status');
    final res = await authorized(
      (h) => http.post(uri, headers: h, body: jsonEncode({'status': status})),
    );
    ensureOk(res);
    return jsonMap(res);
  }
}
