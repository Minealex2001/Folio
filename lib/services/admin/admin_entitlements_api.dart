import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config/folio_backend_config.dart';
import 'admin_api_base.dart';

/// Personal Cloud QA grants: `/api/v1/admin/entitlements/*` + `/admin/ink/grant`.
class AdminEntitlementsApi extends AdminApiBase {
  const AdminEntitlementsApi();

  Future<Map<String, dynamic>> grantCloud(
    String uid, {
    int? inkDrops,
    bool alsoStaff = false,
  }) async {
    final uri = Uri.parse('${FolioBackendConfig.apiV1Prefix}/admin/entitlements/grant-cloud');
    final body = <String, dynamic>{
      'uid': uid,
      if (inkDrops != null) 'inkDrops': inkDrops,
      if (alsoStaff) 'alsoStaff': true,
    };
    final res = await authorized(
      (h) => http.post(uri, headers: h, body: jsonEncode(body)),
    );
    ensureOk(res);
    return jsonMap(res);
  }

  Future<Map<String, dynamic>> revokeCloud(String uid) async {
    final uri = Uri.parse('${FolioBackendConfig.apiV1Prefix}/admin/entitlements/revoke-cloud');
    final res = await authorized(
      (h) => http.post(uri, headers: h, body: jsonEncode({'uid': uid})),
    );
    ensureOk(res);
    return jsonMap(res);
  }

  Future<Map<String, dynamic>> grantInk(String uid, {int? inkDrops}) async {
    final uri = Uri.parse('${FolioBackendConfig.apiV1Prefix}/admin/ink/grant');
    final body = <String, dynamic>{
      'uid': uid,
      if (inkDrops != null) 'inkDrops': inkDrops,
    };
    final res = await authorized(
      (h) => http.post(uri, headers: h, body: jsonEncode(body)),
    );
    ensureOk(res);
    return jsonMap(res);
  }
}
