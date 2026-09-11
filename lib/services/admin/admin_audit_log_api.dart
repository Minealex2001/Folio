import 'package:http/http.dart' as http;

import '../../config/folio_backend_config.dart';
import 'admin_api_base.dart';

class AdminAuditLogApi extends AdminApiBase {
  const AdminAuditLogApi();

  Future<AdminPage> list({int page = 0, int limit = 50}) async {
    final uri = Uri.parse('${FolioBackendConfig.apiV1Prefix}/admin/audit-log').replace(
      queryParameters: {'page': '$page', 'limit': '$limit'},
    );
    final res = await authorized((h) => http.get(uri, headers: h));
    return parsePage(res, fallbackLimit: limit);
  }
}
