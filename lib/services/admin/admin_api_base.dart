import 'dart:convert';

import 'package:http/http.dart' as http;

import '../folio_cloud/folio_cloud_identity.dart';

/// Shared shape for every `{items,total,page,limit}` admin list endpoint.
class AdminPage {
  const AdminPage({
    required this.items,
    required this.total,
    required this.page,
    required this.limit,
  });

  final List<Map<String, dynamic>> items;
  final int total;
  final int page;
  final int limit;

  int get totalPages => total == 0 ? 1 : ((total - 1) ~/ (limit == 0 ? 1 : limit)) + 1;
}

/// Shared HTTP plumbing for admin console API clients (`/api/v1/admin/...`),
/// authenticated with the caller's JWT (staff/admin-role gating happens server-side).
abstract class AdminApiBase {
  const AdminApiBase();

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

  Future<http.Response> authorized(
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

  void ensureOk(http.Response res, {bool allowNoContent = false}) {
    if (allowNoContent && res.statusCode == 204) return;
    if (res.statusCode >= 200 && res.statusCode < 300) return;
    throw StateError('admin HTTP ${res.statusCode}: ${res.body}');
  }

  Map<String, dynamic> jsonMap(http.Response res) {
    if (res.body.isEmpty) return <String, dynamic>{};
    final decoded = jsonDecode(res.body);
    if (decoded is! Map) {
      throw StateError('admin: expected JSON object');
    }
    return decoded.map((k, v) => MapEntry('$k', v));
  }

  List<Map<String, dynamic>> jsonList(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((e) => e.map((k, v) => MapEntry('$k', v)))
        .toList();
  }

  /// Parses the shared `{items,total,page,limit}` envelope used by every admin list endpoint.
  AdminPage parsePage(http.Response res, {int fallbackLimit = 25}) {
    ensureOk(res);
    final map = jsonMap(res);
    return AdminPage(
      items: jsonList(map['items']),
      total: (map['total'] as num?)?.toInt() ?? 0,
      page: (map['page'] as num?)?.toInt() ?? 0,
      limit: (map['limit'] as num?)?.toInt() ?? fallbackLimit,
    );
  }
}
