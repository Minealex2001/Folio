import 'package:http/http.dart' as http;

import '../../config/folio_backend_config.dart';
import 'admin_api_base.dart';

class AdminVaultSharesApi extends AdminApiBase {
  const AdminVaultSharesApi();

  Future<AdminPage> list({int page = 0, int limit = 25, bool activeOnly = false}) async {
    final uri = Uri.parse('${FolioBackendConfig.apiV1Prefix}/admin/vault-shares').replace(
      queryParameters: {'page': '$page', 'limit': '$limit', 'activeOnly': '$activeOnly'},
    );
    final res = await authorized((h) => http.get(uri, headers: h));
    return parsePage(res, fallbackLimit: limit);
  }
}
