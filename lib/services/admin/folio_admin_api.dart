import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config/folio_backend_config.dart';
import '../folio_cloud/folio_cloud_identity.dart';

/// Cliente de moderación admin (`/api/v1/admin/...`) autenticado con JWT staff.
class FolioAdminApi {
  FolioAdminApi();

  Future<Map<String, String>> _headers({bool forceRefresh = false}) async {
    final token = await folioCloudBearerToken(forceRefresh: forceRefresh);
    if (token == null || token.isEmpty) {
      throw StateError('Not signed in');
    }
    return <String, String>{
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json; charset=utf-8',
      'Accept': 'application/json',
    };
  }

  Future<http.Response> _authorized(
    Future<http.Response> Function(Map<String, String> headers) send,
  ) async {
    var headers = await _headers();
    var res = await send(headers);
    if (res.statusCode == 401) {
      headers = await _headers(forceRefresh: true);
      res = await send(headers);
    }
    return res;
  }

  void _ensureOk(http.Response res, {bool allowNoContent = false}) {
    if (allowNoContent && res.statusCode == 204) return;
    if (res.statusCode >= 200 && res.statusCode < 300) return;
    throw StateError('admin HTTP ${res.statusCode}: ${res.body}');
  }

  Map<String, dynamic> _jsonMap(http.Response res) {
    if (res.body.isEmpty) return <String, dynamic>{};
    final decoded = jsonDecode(res.body);
    if (decoded is! Map) {
      throw StateError('admin: expected JSON object');
    }
    return decoded.map((k, v) => MapEntry('$k', v));
  }

  Future<Map<String, dynamic>> lookupUser({String? email, String? uid}) async {
    final uri = Uri.parse('${FolioBackendConfig.apiV1Prefix}/admin/users/lookup');
    final body = <String, dynamic>{
      if (uid != null && uid.trim().isNotEmpty) 'uid': uid.trim(),
      if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
    };
    final res = await _authorized(
      (h) => http.post(uri, headers: h, body: jsonEncode(body)),
    );
    _ensureOk(res);
    return _jsonMap(res);
  }

  Future<Map<String, dynamic>> setUserStatus({
    String? email,
    String? uid,
    required String status,
  }) async {
    final uri = Uri.parse('${FolioBackendConfig.apiV1Prefix}/admin/users/status');
    final body = <String, dynamic>{
      if (uid != null && uid.trim().isNotEmpty) 'uid': uid.trim(),
      if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
      'status': status,
    };
    final res = await _authorized(
      (h) => http.post(uri, headers: h, body: jsonEncode(body)),
    );
    _ensureOk(res);
    return _jsonMap(res);
  }

  Future<Map<String, dynamic>> setUploadBan({
    String? email,
    String? uid,
    required bool banned,
  }) async {
    final uri = Uri.parse(
      '${FolioBackendConfig.apiV1Prefix}/admin/community-templates/ban-upload',
    );
    final body = <String, dynamic>{
      if (uid != null && uid.trim().isNotEmpty) 'uid': uid.trim(),
      if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
      'banned': banned,
    };
    final res = await _authorized(
      (h) => http.post(uri, headers: h, body: jsonEncode(body)),
    );
    _ensureOk(res);
    return _jsonMap(res);
  }

  Future<void> deleteCommunityTemplate(String templateId) async {
    final uri = Uri.parse(
      '${FolioBackendConfig.apiV1Prefix}/admin/community-templates/$templateId',
    );
    final res = await _authorized((h) => http.delete(uri, headers: h));
    _ensureOk(res, allowNoContent: true);
  }

  Future<Map<String, dynamic>> purgeCommunityTemplatesByOwner({
    String? email,
    String? uid,
  }) async {
    final uri = Uri.parse(
      '${FolioBackendConfig.apiV1Prefix}/admin/community-templates/by-owner',
    );
    final body = <String, dynamic>{
      if (uid != null && uid.trim().isNotEmpty) 'uid': uid.trim(),
      if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
    };
    final res = await _authorized(
      (h) => http.delete(uri, headers: h, body: jsonEncode(body)),
    );
    _ensureOk(res);
    return _jsonMap(res);
  }

  Future<List<Map<String, dynamic>>> listOpenReports({int limit = 50}) async {
    final uri = Uri.parse(
      '${FolioBackendConfig.apiV1Prefix}/admin/community-templates/reports',
    ).replace(queryParameters: {'status': 'open', 'limit': '$limit'});
    final res = await _authorized((h) => http.get(uri, headers: h));
    _ensureOk(res);
    final map = _jsonMap(res);
    final items = map['items'];
    if (items is! List) return const [];
    return items
        .whereType<Map>()
        .map((e) => e.map((k, v) => MapEntry('$k', v)))
        .toList();
  }

  Future<void> resolveReport(String reportId) async {
    final uri = Uri.parse(
      '${FolioBackendConfig.apiV1Prefix}/admin/community-templates/reports/$reportId/resolve',
    );
    final res = await _authorized((h) => http.post(uri, headers: h));
    _ensureOk(res);
  }
}
