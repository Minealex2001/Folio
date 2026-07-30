import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config/folio_backend_config.dart';
import '../folio_cloud/folio_cloud_identity.dart';

/// REST de control-plane / snapshot de sala collab (modo Spring).
class CollabSpringApi {
  CollabSpringApi({http.Client? httpClient}) : _http = httpClient ?? http.Client();

  final http.Client _http;

  Uri _roomUri(String roomId) =>
      Uri.parse('${FolioBackendConfig.apiV1Prefix}/collab/rooms/$roomId');

  Uri _chatUri(String roomId, {int? beforeMs}) {
    final base = '${FolioBackendConfig.apiV1Prefix}/collab/rooms/$roomId/chat';
    if (beforeMs == null) return Uri.parse(base);
    return Uri.parse(base).replace(
      queryParameters: {'beforeMs': '$beforeMs'},
    );
  }

  Future<Map<String, String>> _authHeaders({bool forceRefresh = false}) async {
    final token = await folioCloudBearerToken(forceRefresh: forceRefresh);
    if (token == null || token.isEmpty) {
      throw StateError('not_signed_in');
    }
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json; charset=utf-8',
      'Accept': 'application/json',
    };
  }

  /// `GET /api/v1/collab/rooms/{roomId}`
  Future<Map<String, dynamic>> getRoom(String roomId) async {
    Future<http.Response> once({required bool forceRefresh}) async {
      final headers = await _authHeaders(forceRefresh: forceRefresh);
      return _http.get(_roomUri(roomId), headers: headers).timeout(
        const Duration(seconds: 20),
      );
    }

    var res = await once(forceRefresh: false);
    if (res.statusCode == 401) {
      res = await once(forceRefresh: true);
    }
    if (res.statusCode == 403 || res.statusCode == 404) {
      throw CollabSpringApiException(
        code: res.statusCode == 404 ? 'not_found' : 'permission_denied',
        message: 'HTTP ${res.statusCode}',
        statusCode: res.statusCode,
      );
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw CollabSpringApiException(
        code: 'http_error',
        message: 'HTTP ${res.statusCode}',
        statusCode: res.statusCode,
      );
    }
    return _decodeMap(res.body);
  }

  /// `PUT /api/v1/collab/rooms/{roomId}` (fallback si STOMP no está listo).
  Future<Map<String, dynamic>> putRoomUpdate(
    String roomId,
    Map<String, dynamic> body,
  ) async {
    Future<http.Response> once({required bool forceRefresh}) async {
      final headers = await _authHeaders(forceRefresh: forceRefresh);
      return _http
          .put(_roomUri(roomId), headers: headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 20));
    }

    var res = await once(forceRefresh: false);
    if (res.statusCode == 401) {
      res = await once(forceRefresh: true);
    }
    if (res.statusCode == 403 || res.statusCode == 404) {
      throw CollabSpringApiException(
        code: res.statusCode == 404 ? 'not_found' : 'permission_denied',
        message: 'HTTP ${res.statusCode}',
        statusCode: res.statusCode,
      );
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw CollabSpringApiException(
        code: 'http_error',
        message: 'HTTP ${res.statusCode}',
        statusCode: res.statusCode,
      );
    }
    if (res.body.isEmpty) return const {'ok': true};
    return _decodeMap(res.body);
  }

  /// `GET /api/v1/collab/rooms/{roomId}/chat` (historial paginado, más antiguo primero).
  /// [beforeMs] pide la página anterior al mensaje más antiguo ya cargado.
  Future<List<Map<String, dynamic>>> getChatHistory(
    String roomId, {
    int? beforeMs,
  }) async {
    Future<http.Response> once({required bool forceRefresh}) async {
      final headers = await _authHeaders(forceRefresh: forceRefresh);
      return _http
          .get(_chatUri(roomId, beforeMs: beforeMs), headers: headers)
          .timeout(const Duration(seconds: 20));
    }

    var res = await once(forceRefresh: false);
    if (res.statusCode == 401) {
      res = await once(forceRefresh: true);
    }
    if (res.statusCode == 403 || res.statusCode == 404) {
      throw CollabSpringApiException(
        code: res.statusCode == 404 ? 'not_found' : 'permission_denied',
        message: 'HTTP ${res.statusCode}',
        statusCode: res.statusCode,
      );
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw CollabSpringApiException(
        code: 'http_error',
        message: 'HTTP ${res.statusCode}',
        statusCode: res.statusCode,
      );
    }
    return _decodeList(res.body);
  }

  /// `POST /api/v1/collab/rooms/{roomId}/chat` (fallback si STOMP no está listo).
  Future<Map<String, dynamic>> postChatMessage(
    String roomId,
    String contentCipher,
  ) async {
    Future<http.Response> once({required bool forceRefresh}) async {
      final headers = await _authHeaders(forceRefresh: forceRefresh);
      return _http
          .post(
            _chatUri(roomId),
            headers: headers,
            body: jsonEncode({'contentCipher': contentCipher}),
          )
          .timeout(const Duration(seconds: 20));
    }

    var res = await once(forceRefresh: false);
    if (res.statusCode == 401) {
      res = await once(forceRefresh: true);
    }
    if (res.statusCode == 403 || res.statusCode == 404) {
      throw CollabSpringApiException(
        code: res.statusCode == 404 ? 'not_found' : 'permission_denied',
        message: 'HTTP ${res.statusCode}',
        statusCode: res.statusCode,
      );
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw CollabSpringApiException(
        code: 'http_error',
        message: 'HTTP ${res.statusCode}',
        statusCode: res.statusCode,
      );
    }
    return _decodeMap(res.body);
  }

  static List<Map<String, dynamic>> _decodeList(String body) {
    if (body.isEmpty) return const [];
    final decoded = jsonDecode(body);
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map>()
        .map((e) => e.map((k, v) => MapEntry('$k', v)))
        .toList();
  }

  static Map<String, dynamic> _decodeMap(String body) {
    if (body.isEmpty) return const {};
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) {
      return decoded.map((k, v) => MapEntry('$k', v));
    }
    return const {};
  }
}

class CollabSpringApiException implements Exception {
  const CollabSpringApiException({
    required this.code,
    required this.message,
    this.statusCode,
  });

  final String code;
  final String message;
  final int? statusCode;

  @override
  String toString() => 'CollabSpringApiException($code): $message';
}
