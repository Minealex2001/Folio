import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config/folio_backend_config.dart';
import 'admin_api_base.dart';

class AdminSettingsApi extends AdminApiBase {
  const AdminSettingsApi();

  Future<List<Map<String, dynamic>>> list() async {
    final uri = Uri.parse('${FolioBackendConfig.apiV1Prefix}/admin/app-settings');
    final res = await authorized((h) => http.get(uri, headers: h));
    ensureOk(res);
    final decoded = jsonDecode(res.body);
    if (decoded is! List) return const [];
    return jsonList(decoded);
  }

  Future<Map<String, dynamic>> update(String key, String value) async {
    final uri = Uri.parse('${FolioBackendConfig.apiV1Prefix}/admin/app-settings/$key');
    final res = await authorized(
      (h) => http.put(uri, headers: h, body: jsonEncode({'value': value})),
    );
    ensureOk(res);
    return jsonMap(res);
  }

  Future<Map<String, dynamic>> clear(String key) async {
    final uri = Uri.parse('${FolioBackendConfig.apiV1Prefix}/admin/app-settings/$key');
    final res = await authorized((h) => http.delete(uri, headers: h));
    ensureOk(res);
    return jsonMap(res);
  }
}
