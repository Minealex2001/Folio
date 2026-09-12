import 'package:http/http.dart' as http;

import '../../config/folio_backend_config.dart';
import 'admin_api_base.dart';

class AdminPublishedPagesApi extends AdminApiBase {
  const AdminPublishedPagesApi();

  Future<AdminPage> list({int page = 0, int limit = 25, String? ownerUid}) async {
    final uri =
        Uri.parse('${FolioBackendConfig.apiV1Prefix}/admin/published-pages').replace(
      queryParameters: {
        'page': '$page',
        'limit': '$limit',
        if (ownerUid != null && ownerUid.trim().isNotEmpty) 'ownerUid': ownerUid.trim(),
      },
    );
    final res = await authorized((h) => http.get(uri, headers: h));
    return parsePage(res, fallbackLimit: limit);
  }

  Future<void> delete(String id) async {
    final uri = Uri.parse('${FolioBackendConfig.apiV1Prefix}/admin/published-pages/$id');
    final res = await authorized((h) => http.delete(uri, headers: h));
    ensureOk(res, allowNoContent: true);
  }
}
