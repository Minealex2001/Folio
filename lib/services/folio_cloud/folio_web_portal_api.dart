import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint, immutable;

import 'folio_web_portal_http_io.dart'
    if (dart.library.html) 'folio_web_portal_http_web.dart' as portal_http;

/// Normaliza el código copiado desde la web (espacios, mayúsculas).
String normalizeFolioWebLinkCode(String raw) {
  return raw.trim().replaceAll(RegExp(r'\s+'), '').toUpperCase();
}

/// Espejo de `/api/folio/entitlement` (cuenta web / Stripe); no sustituye a Firestore.
@immutable
class FolioWebEntitlementSnapshot {
  const FolioWebEntitlementSnapshot({
    required this.linked,
    this.folioCloud,
    this.folioCloudStatus,
    this.folioCloudPeriodEnd,
    this.folioInkCredits,
  });

  final bool linked;
  final bool? folioCloud;
  final String? folioCloudStatus;
  final String? folioCloudPeriodEnd;
  final int? folioInkCredits;

  static FolioWebEntitlementSnapshot? tryParseJsonObject(Object? decoded) {
    if (decoded is! Map) return null;
    final m = _stringKeyed(decoded);
    final linked = m['linked'];
    if (linked is! bool) return null;
    return FolioWebEntitlementSnapshot(
      linked: linked,
      folioCloud: _asBoolOrNull(m['folioCloud']),
      folioCloudStatus: m['folioCloudStatus']?.toString(),
      folioCloudPeriodEnd: m['folioCloudPeriodEnd']?.toString(),
      folioInkCredits: _asIntOrNull(m['folioInkCredits']),
    );
  }
}

Map<String, dynamic> _stringKeyed(Map raw) {
  final out = <String, dynamic>{};
  for (final e in raw.entries) {
    out['${e.key}'] = e.value;
  }
  return out;
}

bool? _asBoolOrNull(Object? v) {
  if (v == null) return null;
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) {
    final s = v.toLowerCase().trim();
    if (s == 'true' || s == '1') return true;
    if (s == 'false' || s == '0') return false;
  }
  return null;
}

int? _asIntOrNull(Object? v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v.trim());
  return null;
}

enum FolioWebPortalErrorKind {
  invalidBaseUrl,
  network,
  timeout,
  badRequest,
  unauthorized,
  forbidden,
  notFound,
  conflict,
  adminNotConfigured,
  serverError,
  invalidJson,
  linkRejected,
  entitlementParse,
}

/// Error de API portal; [detail] puede ser mensaje del servidor o técnico.
class FolioWebPortalException implements Exception {
  FolioWebPortalException(
    this.kind, {
    this.statusCode,
    this.detail,
  });

  final FolioWebPortalErrorKind kind;
  final int? statusCode;
  final String? detail;

  @override
  String toString() =>
      'FolioWebPortalException($kind, status=$statusCode, detail=$detail)';
}

String? extractFolioPortalErrorMessage(String body) {
  try {
    final decoded = jsonDecode(body);
    if (decoded is Map) {
      final m = _stringKeyed(decoded);
      for (final key in ['message', 'error', 'detail', 'reason']) {
        final v = m[key];
        if (v is String && v.trim().isNotEmpty) return v.trim();
      }
    }
  } catch (_) {
    /* ignore */
  }
  return null;
}

FolioWebPortalErrorKind _kindForClientError(int code) {
  switch (code) {
    case 401:
      return FolioWebPortalErrorKind.unauthorized;
    case 403:
      return FolioWebPortalErrorKind.forbidden;
    case 404:
      return FolioWebPortalErrorKind.notFound;
    case 409:
      return FolioWebPortalErrorKind.conflict;
    default:
      return FolioWebPortalErrorKind.badRequest;
  }
}

Uri? _portalBaseUri(String baseUrl) {
  final t = baseUrl.trim();
  if (t.isEmpty) return null;
  final withScheme =
      t.startsWith('http://') || t.startsWith('https://') ? t : 'https://$t';
  return Uri.tryParse(withScheme);
}

/// `POST /api/auth/folio/link` — sin cookies; solo JSON.
Future<void> linkFolioWebAccount({
  required String portalBaseUrl,
  required String linkCode,
  required String idToken,
  Duration connectionTimeout = const Duration(seconds: 15),
  Duration bodyTimeout = const Duration(seconds: 30),
}) async {
  final base = _portalBaseUri(portalBaseUrl);
  if (base == null) {
    throw FolioWebPortalException(
      FolioWebPortalErrorKind.invalidBaseUrl,
      detail: portalBaseUrl,
    );
  }
  final pathPrefix = base.path.endsWith('/')
      ? base.path.substring(0, base.path.length - 1)
      : base.path;
  final uri = Uri(
    scheme: base.scheme,
    host: base.host,
    port: base.hasPort ? base.port : null,
    path: '$pathPrefix/api/auth/folio/link',
  );

  final payload = jsonEncode(<String, String>{
    'linkCode': normalizeFolioWebLinkCode(linkCode),
    'idToken': idToken,
  });

  try {
    final res = await portal_http.folioPortalHttpRequest(
      uri: uri,
      method: 'POST',
      headers: {
        'Content-Type': 'application/json; charset=utf-8',
        'Accept': 'application/json',
      },
      body: payload,
      connectionTimeout: connectionTimeout,
      bodyTimeout: bodyTimeout,
    );

    if (res.statusCode == 503) {
      throw FolioWebPortalException(
        FolioWebPortalErrorKind.adminNotConfigured,
        statusCode: 503,
        detail: extractFolioPortalErrorMessage(res.body),
      );
    }

    if (res.statusCode >= 200 && res.statusCode < 300) {
      try {
        final decoded = jsonDecode(res.body);
        if (decoded is Map && decoded['ok'] == true) {
          return;
        }
      } catch (_) {
        throw FolioWebPortalException(
          FolioWebPortalErrorKind.invalidJson,
          statusCode: res.statusCode,
          detail: res.body,
        );
      }
      throw FolioWebPortalException(
        FolioWebPortalErrorKind.linkRejected,
        statusCode: res.statusCode,
        detail: extractFolioPortalErrorMessage(res.body),
      );
    }

    if (res.statusCode >= 400 && res.statusCode < 500) {
      throw FolioWebPortalException(
        _kindForClientError(res.statusCode),
        statusCode: res.statusCode,
        detail: extractFolioPortalErrorMessage(res.body),
      );
    }

    throw FolioWebPortalException(
      FolioWebPortalErrorKind.serverError,
      statusCode: res.statusCode,
      detail: extractFolioPortalErrorMessage(res.body),
    );
  } on FolioWebPortalException {
    rethrow;
  } on TimeoutException catch (e) {
    throw FolioWebPortalException(
      FolioWebPortalErrorKind.timeout,
      detail: e.message,
    );
  } catch (e, st) {
    debugPrint('linkFolioWebAccount: $e\n$st');
    throw FolioWebPortalException(
      FolioWebPortalErrorKind.network,
      detail: '$e',
    );
  }
}

/// `GET /api/folio/entitlement` con Bearer.
Future<FolioWebEntitlementSnapshot> fetchFolioWebEntitlement({
  required String portalBaseUrl,
  required String idToken,
  Duration connectionTimeout = const Duration(seconds: 15),
  Duration bodyTimeout = const Duration(seconds: 30),
}) async {
  final base = _portalBaseUri(portalBaseUrl);
  if (base == null) {
    throw FolioWebPortalException(
      FolioWebPortalErrorKind.invalidBaseUrl,
      detail: portalBaseUrl,
    );
  }
  final pathPrefix = base.path.endsWith('/')
      ? base.path.substring(0, base.path.length - 1)
      : base.path;
  final uri = Uri(
    scheme: base.scheme,
    host: base.host,
    port: base.hasPort ? base.port : null,
    path: '$pathPrefix/api/folio/entitlement',
  );

  try {
    final res = await portal_http.folioPortalHttpRequest(
      uri: uri,
      method: 'GET',
      headers: {
        'Authorization': 'Bearer $idToken',
        'Accept': 'application/json',
      },
      connectionTimeout: connectionTimeout,
      bodyTimeout: bodyTimeout,
    );

    if (res.statusCode == 503) {
      throw FolioWebPortalException(
        FolioWebPortalErrorKind.adminNotConfigured,
        statusCode: 503,
        detail: extractFolioPortalErrorMessage(res.body),
      );
    }

    if (res.statusCode < 200 || res.statusCode >= 300) {
      if (res.statusCode >= 400 && res.statusCode < 500) {
        throw FolioWebPortalException(
          _kindForClientError(res.statusCode),
          statusCode: res.statusCode,
          detail: extractFolioPortalErrorMessage(res.body),
        );
      }
      throw FolioWebPortalException(
        FolioWebPortalErrorKind.serverError,
        statusCode: res.statusCode,
        detail: extractFolioPortalErrorMessage(res.body),
      );
    }

    Object? decoded;
    try {
      decoded = jsonDecode(res.body);
    } catch (_) {
      throw FolioWebPortalException(
        FolioWebPortalErrorKind.invalidJson,
        statusCode: res.statusCode,
        detail: res.body,
      );
    }
    final snap = FolioWebEntitlementSnapshot.tryParseJsonObject(decoded);
    if (snap == null) {
      throw FolioWebPortalException(
        FolioWebPortalErrorKind.entitlementParse,
        statusCode: res.statusCode,
        detail: res.body,
      );
    }
    return snap;
  } on FolioWebPortalException {
    rethrow;
  } on TimeoutException catch (e) {
    throw FolioWebPortalException(
      FolioWebPortalErrorKind.timeout,
      detail: e.message,
    );
  } catch (e, st) {
    debugPrint('fetchFolioWebEntitlement: $e\n$st');
    throw FolioWebPortalException(
      FolioWebPortalErrorKind.network,
      detail: '$e',
    );
  }
}
