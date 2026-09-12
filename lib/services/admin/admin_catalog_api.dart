import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config/folio_backend_config.dart';
import 'admin_api_base.dart';

class AdminCatalogApi extends AdminApiBase {
  const AdminCatalogApi();

  Future<AdminPage> list({int page = 0, int limit = 25, String? query}) async {
    final uri =
        Uri.parse('${FolioBackendConfig.apiV1Prefix}/admin/community-templates-catalog').replace(
      queryParameters: {
        'page': '$page',
        'limit': '$limit',
        if (query != null && query.trim().isNotEmpty) 'query': query.trim(),
      },
    );
    final res = await authorized((h) => http.get(uri, headers: h));
    return parsePage(res, fallbackLimit: limit);
  }

  Future<Map<String, dynamic>> update(
    String id, {
    String? name,
    String? description,
    String? category,
    String? emoji,
  }) async {
    final uri =
        Uri.parse('${FolioBackendConfig.apiV1Prefix}/admin/community-templates-catalog/$id');
    final body = <String, dynamic>{
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (category != null) 'category': category,
      if (emoji != null) 'emoji': emoji,
    };
    final res = await authorized((h) => http.put(uri, headers: h, body: jsonEncode(body)));
    ensureOk(res);
    return jsonMap(res);
  }
}
