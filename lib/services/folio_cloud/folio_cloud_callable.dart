import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../config/folio_backend_config.dart';
import '../app_logger.dart';
import 'folio_cloud_exception.dart';
import 'folio_cloud_http_client.dart';
import 'folio_cloud_identity.dart';
import 'folio_spring_callable_routes.dart';

/// Tras Fase 30 todas las callables van por HTTP Spring.
bool get folioHttpsCallableUsesHttp => true;

/// Hook solo para tests: si se asigna, sustituye por completo la llamada de
/// red real en [callFolioHttpsCallable] (evita mockear HTTP/tokens para
/// probar lógica que depende de callables, p. ej. el loop de subida de notas
/// de reunión). Debe quedar en `null` fuera de tests.
@visibleForTesting
Future<dynamic> Function(String name, Object? parameters)?
    debugCallFolioHttpsCallableOverride;

String _trimLeadingBom(String s) {
  var t = s.trimLeft();
  if (t.isNotEmpty && t.codeUnitAt(0) == 0xfeff) {
    t = t.substring(1);
  }
  return t.trimLeft();
}

String _previewForCallableFailure(String body) {
  final collapsed = body.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (collapsed.isEmpty) return 'Cuerpo vacío.';
  const max = 200;
  return collapsed.length <= max
      ? collapsed
      : '${collapsed.substring(0, max)}…';
}

Map<String, dynamic> _paramsAsMap(Object? parameters) {
  if (parameters == null) return <String, dynamic>{};
  if (parameters is Map<String, dynamic>) {
    return Map<String, dynamic>.from(parameters);
  }
  if (parameters is Map) {
    return parameters.map((k, v) => MapEntry('$k', v));
  }
  return <String, dynamic>{'value': parameters};
}

/// Equivalente legacy a `HttpsCallable.call` (payload JSON del API Spring).
Future<dynamic> callFolioHttpsCallable(
  String name, [
  Object? parameters,
]) async {
  final override = debugCallFolioHttpsCallableOverride;
  if (override != null) return override(name, parameters);

  AppLogger.debug(
    'callable call',
    tag: 'cloud_sync',
    context: {
      'name': name,
      'viaHttp': true,
      'backend': FolioBackendConfig.modeLabel,
    },
  );

  try {
    final result = await _callFolioSpringRest(name, parameters);
    AppLogger.debug(
      'callable ok',
      tag: 'cloud_sync',
      context: {'name': name, 'viaHttp': true, 'backend': 'spring'},
    );
    return result;
  } catch (e, st) {
    AppLogger.error(
      'callable failed',
      tag: 'cloud_sync',
      error: e,
      stackTrace: st,
      context: {'name': name, 'viaHttp': true, 'backend': 'spring'},
    );
    rethrow;
  }
}

Future<dynamic> _callFolioSpringRest(String name, Object? parameters) async {
  final route = resolveFolioSpringApiRoute(name);
  if (route == null) {
    throw FolioCloudException(
      message: 'No Spring route mapping for callable "$name"',
      code: 'unimplemented',
    );
  }

  final params = _paramsAsMap(parameters);
  final path = route.pathBuilder(params);
  final uri = Uri.parse(
    '${FolioBackendConfig.apiV1Prefix}/${path.replaceFirst(RegExp(r'^/'), '')}',
  );

  final maxAttempts = route.requiresAuth ? 2 : 1;
  for (var attempt = 0; attempt < maxAttempts; attempt++) {
    final forceRefresh = attempt > 0;
    String? token;
    if (route.requiresAuth) {
      token = await folioCloudBearerToken(forceRefresh: forceRefresh);
      if (token == null || token.isEmpty) {
        throw FolioCloudException(
          message: 'Must be signed in to call Folio Cloud API',
          code: 'unauthenticated',
        );
      }
    } else {
      token = await folioCloudBearerToken(forceRefresh: false);
    }

    final headers = <String, String>{
      'Content-Type': 'application/json; charset=utf-8',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };

    late http.Response resp;
    try {
      switch (route.method.toUpperCase()) {
        case 'GET':
          resp = await folioCloudHttpClient
              .get(uri, headers: headers)
              .timeout(const Duration(seconds: 120));
        case 'PATCH':
          resp = await folioCloudHttpClient
              .patch(
                uri,
                headers: headers,
                body: route.omitBody ? null : jsonEncode(params),
              )
              .timeout(const Duration(seconds: 120));
        case 'PUT':
          resp = await folioCloudHttpClient
              .put(
                uri,
                headers: headers,
                body: route.omitBody ? null : jsonEncode(params),
              )
              .timeout(const Duration(seconds: 120));
        case 'DELETE':
          resp = await folioCloudHttpClient
              .delete(uri, headers: headers)
              .timeout(const Duration(seconds: 120));
        case 'POST':
        default:
          resp = await folioCloudHttpClient
              .post(
                uri,
                headers: headers,
                body: route.omitBody ? '{}' : jsonEncode(params),
              )
              .timeout(const Duration(seconds: 120));
      }
    } on TimeoutException catch (e) {
      throw FolioCloudException(
        message: 'Folio Cloud API request timed out: $e',
        code: 'deadline-exceeded',
      );
    }

    if (resp.statusCode == 401 && route.requiresAuth && attempt == 0) {
      continue;
    }

    final jsonText = _trimLeadingBom(resp.body);
    if (resp.statusCode == 204 || jsonText.isEmpty) {
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        return <String, dynamic>{'ok': true};
      }
    }

    dynamic decoded;
    try {
      decoded = jsonText.isEmpty ? null : jsonDecode(jsonText);
    } catch (_) {
      throw FolioCloudException(
        message:
            'Folio Cloud API no devolvió JSON (HTTP ${resp.statusCode}). '
            '${_previewForCallableFailure(jsonText)}',
        code: 'unknown',
      );
    }

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      var message = 'HTTP ${resp.statusCode} calling $name';
      var code = 'unknown';
      if (decoded is Map) {
        message = decoded['message']?.toString() ??
            decoded['error']?.toString() ??
            message;
        final status = decoded['status'] ?? decoded['error'];
        if (status != null && status is! Map) {
          code = status.toString().toLowerCase().replaceAll('_', '-');
        }
        if (resp.statusCode == 401) code = 'unauthenticated';
        if (resp.statusCode == 403) code = 'permission-denied';
        if (resp.statusCode == 404) code = 'not-found';
        if (resp.statusCode == 429) code = 'resource-exhausted';
      }
      throw FolioCloudException(message: message, code: code);
    }

    if (decoded is Map) {
      return Map<String, dynamic>.from(
        decoded.map((k, v) => MapEntry('$k', v)),
      );
    }
    return decoded;
  }

  throw FolioCloudException(
    message:
        'Folio Cloud API rejected the session (401). Sign out and sign in again.',
    code: 'unauthenticated',
  );
}

/// Callable `folioGetBackupStorageUsage`.
Future<Map<String, dynamic>> folioGetBackupStorageUsageCallable() async {
  if (!folioCloudHasSession()) {
    throw StateError('Not signed in');
  }
  final raw = await callFolioHttpsCallable(
    'folioGetBackupStorageUsage',
    <String, dynamic>{},
  );
  if (raw is! Map) {
    throw StateError('Respuesta inválida');
  }
  return Map<String, dynamic>.from(raw);
}
