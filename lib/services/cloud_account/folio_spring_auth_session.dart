import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../../config/folio_backend_config.dart';
import '../app_logger.dart';

/// Perfil de sesión Spring (sustituye [User] de Firebase Auth en modo Spring).
@immutable
class FolioSpringSessionProfile {
  const FolioSpringSessionProfile({
    required this.uid,
    required this.email,
    this.displayName,
    this.emailVerified = false,
  });

  final String uid;
  final String email;
  final String? displayName;
  final bool emailVerified;
}

/// Sesión JWT propia (access + refresh) persistida en [FlutterSecureStorage].
///
/// Mismo almacén seguro que el resto de secretos de la app (Keychain / DPAPI).
class FolioSpringAuthSession extends ChangeNotifier {
  FolioSpringAuthSession({
    FlutterSecureStorage? storage,
    http.Client? httpClient,
  }) : _storage =
           storage ??
           const FlutterSecureStorage(
             aOptions: AndroidOptions(encryptedSharedPreferences: true),
           ),
       _http = httpClient ?? http.Client();

  static FolioSpringAuthSession? _shared;
  static FolioSpringAuthSession get instance =>
      _shared ??= FolioSpringAuthSession();

  /// Sustituye la instancia compartida (tests).
  @visibleForTesting
  static void debugSetInstance(FolioSpringAuthSession? session) {
    _shared = session;
  }

  final FlutterSecureStorage _storage;
  final http.Client _http;

  static const _kAccess = 'folio_spring_access_token_v1';
  static const _kRefresh = 'folio_spring_refresh_token_v1';
  static const _kEmail = 'folio_spring_email_v1';
  static const _kDisplayName = 'folio_spring_display_name_v1';
  static const _kEmailVerified = 'folio_spring_email_verified_v1';

  String? _accessToken;
  String? _refreshToken;
  FolioSpringSessionProfile? _profile;
  DateTime? _accessExpiresAt;
  Future<void>? _refreshInFlight;

  FolioSpringSessionProfile? get profile => _profile;
  bool get isSignedIn => _profile != null && (_accessToken?.isNotEmpty == true ||
      _refreshToken?.isNotEmpty == true);

  String? get uid => _profile?.uid;
  String? get email => _profile?.email;
  String? get displayName => _profile?.displayName;
  bool get emailVerified => _profile?.emailVerified ?? false;

  /// Restaura tokens desde el almacén seguro (arranque de app).
  Future<void> restore() async {
    if (!FolioBackendConfig.useSpring) return;
    try {
      final access = await _storage.read(key: _kAccess);
      final refresh = await _storage.read(key: _kRefresh);
      final email = await _storage.read(key: _kEmail);
      final displayName = await _storage.read(key: _kDisplayName);
      final verifiedRaw = await _storage.read(key: _kEmailVerified);
      _accessToken = (access != null && access.isNotEmpty) ? access : null;
      _refreshToken = (refresh != null && refresh.isNotEmpty) ? refresh : null;
      if (_accessToken != null) {
        final claims = decodeJwtPayload(_accessToken!);
        final sub = claims?['sub']?.toString();
        final claimEmail = claims?['email']?.toString();
        if (sub != null && sub.isNotEmpty) {
          _profile = FolioSpringSessionProfile(
            uid: sub,
            email: (email?.isNotEmpty == true)
                ? email!
                : (claimEmail ?? ''),
            displayName: displayName,
            emailVerified: verifiedRaw == '1' || verifiedRaw == 'true',
          );
          _accessExpiresAt = _expFromClaims(claims);
        }
      }
      AppLogger.info(
        'spring session restore',
        tag: 'auth',
        context: {
          'signedIn': isSignedIn,
          'hasRefresh': _refreshToken != null,
        },
      );
      notifyListeners();
    } catch (e, st) {
      AppLogger.error(
        'spring session restore failed',
        tag: 'auth',
        error: e,
        stackTrace: st,
      );
    }
  }

  Future<void> login({
    required String email,
    required String password,
  }) async {
    final uri = Uri.parse('${FolioBackendConfig.apiV1Prefix}/auth/login');
    final resp = await _postJson(uri, {
      'email': email.trim(),
      'password': password,
    });
    await _applyTokenResponse(resp, fallbackEmail: email.trim());
  }

  Future<void> register({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final uri = Uri.parse('${FolioBackendConfig.apiV1Prefix}/auth/register');
    final body = <String, dynamic>{
      'email': email.trim(),
      'password': password,
      if (displayName != null && displayName.trim().isNotEmpty)
        'displayName': displayName.trim(),
    };
    final resp = await _postJson(uri, body, expectStatus: const {201, 200});
    // Tras registro, login para obtener JWT (el register no emite tokens).
    await login(email: email, password: password);
    final uid = resp['uid']?.toString();
    final dn = resp['displayName']?.toString();
    if (uid != null && _profile != null) {
      _profile = FolioSpringSessionProfile(
        uid: _profile!.uid,
        email: _profile!.email,
        displayName: dn ?? _profile!.displayName,
        emailVerified: false,
      );
      await _persistProfileFields();
      notifyListeners();
    }
  }

  Future<void> forgotPassword(String email) async {
    final uri =
        Uri.parse('${FolioBackendConfig.apiV1Prefix}/auth/forgot-password');
    await _postJson(uri, {'email': email.trim()});
  }

  Future<void> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    final uri =
        Uri.parse('${FolioBackendConfig.apiV1Prefix}/auth/reset-password');
    await _postJson(uri, {
      'token': token.trim(),
      'newPassword': newPassword,
    });
  }

  Future<void> resendVerification() async {
    final token = await getAccessToken();
    if (token == null) {
      throw StateError('Not signed in');
    }
    final uri = Uri.parse(
      '${FolioBackendConfig.apiV1Prefix}/auth/resend-verification',
    );
    await _postJson(uri, const {}, bearer: token);
  }

  /// Revalida email+password contra `/auth/login` (reauth sensible).
  Future<void> verifyPassword({
    required String email,
    required String password,
  }) async {
    final sessionEmail = _profile?.email.trim().toLowerCase();
    final trimmed = email.trim();
    if (sessionEmail != null &&
        sessionEmail.isNotEmpty &&
        trimmed.toLowerCase() != sessionEmail) {
      throw StateError('El correo no coincide con la sesión actual.');
    }
    final uri = Uri.parse('${FolioBackendConfig.apiV1Prefix}/auth/login');
    // Login de verificación: no sustituye tokens si falla; si ok, rotamos.
    await _postJson(uri, {
      'email': trimmed,
      'password': password,
    });
  }

  Future<void> logout() async {
    final refresh = _refreshToken;
    final access = _accessToken;
    try {
      if (refresh != null && refresh.isNotEmpty && access != null) {
        final uri = Uri.parse('${FolioBackendConfig.apiV1Prefix}/auth/logout');
        await _postJson(
          uri,
          {'refreshToken': refresh},
          bearer: access,
          swallowErrors: true,
        );
      }
    } finally {
      await clear();
    }
  }

  Future<void> clear() async {
    _accessToken = null;
    _refreshToken = null;
    _profile = null;
    _accessExpiresAt = null;
    await Future.wait([
      _storage.delete(key: _kAccess),
      _storage.delete(key: _kRefresh),
      _storage.delete(key: _kEmail),
      _storage.delete(key: _kDisplayName),
      _storage.delete(key: _kEmailVerified),
    ]);
    notifyListeners();
  }

  /// Access token válido; refresca si hace falta o si [forceRefresh].
  Future<String?> getAccessToken({bool forceRefresh = false}) async {
    if (_accessToken != null &&
        _accessToken!.isNotEmpty &&
        !forceRefresh &&
        !_isAccessExpiredOrNear()) {
      return _accessToken;
    }
    if (_refreshToken == null || _refreshToken!.isEmpty) {
      // Sin refresh no podemos renovar: no devolver access caducado (provoca 401 en cadena).
      if (_isAccessExpiredOrNear()) {
        return null;
      }
      return (_accessToken != null && _accessToken!.isNotEmpty)
          ? _accessToken
          : null;
    }
    try {
      await _refreshTokens();
    } catch (e, st) {
      AppLogger.warn(
        'spring token refresh failed',
        tag: 'auth',
        context: {'error': '$e', 'stack': '$st'},
      );
      if (forceRefresh || _isAccessExpiredOrNear()) {
        return null;
      }
    }
    return _accessToken;
  }

  bool _isAccessExpiredOrNear() {
    final exp = _accessExpiresAt;
    if (exp == null) return true;
    // Margen 60s antes de exp.
    return DateTime.now().toUtc().isAfter(
      exp.subtract(const Duration(seconds: 60)),
    );
  }

  Future<void> _refreshTokens() async {
    final existing = _refreshInFlight;
    if (existing != null) {
      await existing;
      return;
    }
    final fut = () async {
      final refresh = _refreshToken;
      if (refresh == null || refresh.isEmpty) {
        throw StateError('No refresh token');
      }
      final uri = Uri.parse('${FolioBackendConfig.apiV1Prefix}/auth/refresh');
      final resp = await _postJson(uri, {'refreshToken': refresh});
      await _applyTokenResponse(
        resp,
        fallbackEmail: _profile?.email ?? '',
      );
    }();
    _refreshInFlight = fut;
    try {
      await fut;
    } finally {
      _refreshInFlight = null;
    }
  }

  Future<void> _applyTokenResponse(
    Map<String, dynamic> resp, {
    required String fallbackEmail,
  }) async {
    final access = resp['accessToken']?.toString() ?? '';
    final refresh = resp['refreshToken']?.toString() ?? '';
    final expiresIn = _asInt(resp['expiresIn']) ?? 900;
    if (access.isEmpty || refresh.isEmpty) {
      throw StateError('Token response missing access/refresh');
    }
    final claims = decodeJwtPayload(access);
    final sub = claims?['sub']?.toString() ?? '';
    final claimEmail = claims?['email']?.toString() ?? fallbackEmail;
    if (sub.isEmpty) {
      throw StateError('Access token missing sub claim');
    }
    _accessToken = access;
    _refreshToken = refresh;
    _accessExpiresAt = DateTime.now().toUtc().add(Duration(seconds: expiresIn));
    _profile = FolioSpringSessionProfile(
      uid: sub,
      email: claimEmail,
      displayName: _profile?.displayName,
      emailVerified: resp['emailVerified'] == true,
    );
    await _storage.write(key: _kAccess, value: access);
    await _storage.write(key: _kRefresh, value: refresh);
    await _persistProfileFields();
    notifyListeners();
    AppLogger.info(
      'spring tokens applied',
      tag: 'auth',
      context: {'uid': sub, 'expiresIn': expiresIn},
    );
  }

  Future<void> _persistProfileFields() async {
    final p = _profile;
    if (p == null) return;
    await _storage.write(key: _kEmail, value: p.email);
    if (p.displayName != null) {
      await _storage.write(key: _kDisplayName, value: p.displayName!);
    }
    await _storage.write(
      key: _kEmailVerified,
      value: p.emailVerified ? '1' : '0',
    );
  }

  Future<void> updateLocalProfile({
    String? displayName,
    bool? emailVerified,
  }) async {
    final p = _profile;
    if (p == null) return;
    _profile = FolioSpringSessionProfile(
      uid: p.uid,
      email: p.email,
      displayName: displayName ?? p.displayName,
      emailVerified: emailVerified ?? p.emailVerified,
    );
    await _persistProfileFields();
    notifyListeners();
  }

  Future<Map<String, dynamic>> _postJson(
    Uri uri,
    Map<String, dynamic> body, {
    String? bearer,
    Set<int> expectStatus = const {200},
    bool swallowErrors = false,
  }) async {
    try {
      final headers = <String, String>{
        'Content-Type': 'application/json; charset=utf-8',
        if (bearer != null && bearer.isNotEmpty)
          'Authorization': 'Bearer $bearer',
      };
      final res = await _http
          .post(uri, headers: headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 20));
      if (!expectStatus.contains(res.statusCode)) {
        if (swallowErrors) return const {};
        final msg = _errorMessage(res.body) ??
            'HTTP ${res.statusCode} ${uri.path}';
        throw FolioSpringAuthException(
          code: _mapAuthErrorCode(res.statusCode, res.body),
          message: msg,
          statusCode: res.statusCode,
        );
      }
      if (res.body.isEmpty) return const {};
      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) {
        return decoded.map((k, v) => MapEntry('$k', v));
      }
      return const {};
    } on TimeoutException {
      throw const FolioSpringAuthException(
        code: 'network-request-failed',
        message: 'Request timed out',
      );
    }
  }
}

class FolioSpringAuthException implements Exception {
  const FolioSpringAuthException({
    required this.code,
    required this.message,
    this.statusCode,
  });

  final String code;
  final String message;
  final int? statusCode;

  @override
  String toString() => 'FolioSpringAuthException($code): $message';
}

/// Decodifica el payload JWT (sin verificar firma — eso lo hace el servidor).
Map<String, dynamic>? decodeJwtPayload(String token) {
  final parts = token.split('.');
  if (parts.length < 2) return null;
  try {
    final normalized = base64Url.normalize(parts[1]);
    final json = utf8.decode(base64Url.decode(normalized));
    final decoded = jsonDecode(json);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) {
      return decoded.map((k, v) => MapEntry('$k', v));
    }
  } catch (_) {}
  return null;
}

DateTime? _expFromClaims(Map<String, dynamic>? claims) {
  final exp = claims?['exp'];
  if (exp is int) {
    return DateTime.fromMillisecondsSinceEpoch(exp * 1000, isUtc: true);
  }
  if (exp is num) {
    return DateTime.fromMillisecondsSinceEpoch(
      (exp * 1000).round(),
      isUtc: true,
    );
  }
  return null;
}

int? _asInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse('$v');
}

String? _errorMessage(String body) {
  if (body.isEmpty) return null;
  try {
    final decoded = jsonDecode(body);
    if (decoded is Map) {
      final msg = decoded['message'] ?? decoded['error'] ?? decoded['detail'];
      if (msg != null) return msg.toString();
    }
  } catch (_) {}
  final collapsed = body.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (collapsed.length > 180) return '${collapsed.substring(0, 180)}…';
  return collapsed.isEmpty ? null : collapsed;
}

String? _apiErrorField(String body) {
  if (body.isEmpty) return null;
  try {
    final decoded = jsonDecode(body);
    if (decoded is Map) {
      final err = decoded['error'];
      if (err != null) {
        final s = err.toString().trim();
        if (s.isNotEmpty) return s;
      }
    }
  } catch (_) {}
  return null;
}

String _mapAuthErrorCode(int statusCode, String body) {
  final apiError = _apiErrorField(body);
  if (apiError != null) {
    return switch (apiError) {
      'password_reset_required' => 'password-reset-required',
      'invalid_credentials' => 'invalid-credential',
      'invalid_refresh' => 'invalid-credential',
      'invalid_token' => 'invalid-token',
      'token_used' => 'token-used',
      'token_expired' => 'token-expired',
      'already_verified' => 'already-verified',
      'user_not_found' => 'user-not-found',
      _ => apiError.replaceAll('_', '-'),
    };
  }
  if (statusCode == 401) return 'invalid-credential';
  if (statusCode == 409) return 'email-already-in-use';
  return 'unknown';
}
