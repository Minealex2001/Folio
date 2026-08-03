import 'package:http/http.dart' as http;

import '../../config/folio_backend_config.dart';
import 'admin_api_base.dart';

class AdminBillingApi extends AdminApiBase {
  const AdminBillingApi();

  Future<Map<String, dynamic>> userBilling(String uid) async {
    final uri = Uri.parse('${FolioBackendConfig.apiV1Prefix}/admin/billing/users/$uid');
    final res = await authorized((h) => http.get(uri, headers: h));
    ensureOk(res);
    return jsonMap(res);
  }

  Future<AdminPage> webhookEvents({int page = 0, int limit = 25}) async {
    final uri =
        Uri.parse('${FolioBackendConfig.apiV1Prefix}/admin/billing/webhook-events').replace(
      queryParameters: {'page': '$page', 'limit': '$limit'},
    );
    final res = await authorized((h) => http.get(uri, headers: h));
    return parsePage(res, fallbackLimit: limit);
  }
}
