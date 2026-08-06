import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../../config/folio_backend_config.dart';
import '../app_logger.dart';
import '../folio_cloud/folio_cloud_http_client.dart';

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

  FolioSpringSessionProfile copyWith({
    String? email,
    String? displayName,
    bool? emailVerified,
  }) {
    return FolioSpringSessionProfile(
      uid: uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      emailVerified: emailVerified ?? this.emailVerified,
    );
  }
}

/// Slot persistido de una cuenta Folio Cloud en el dispositivo.
@immutable
class FolioCloudAccountSlot {
  const FolioCloudAccountSlot({
    required this.uid,
    required this.email,
    this.displayName,
    this.emailVerified = false,
    required this.accessToken,
    required this.refreshToken,
    this.accessExpiresAtMs,
  });

  final String uid;
  final String email;
  final String? displayName;
  final bool emailVerified;
  final String accessToken;
  final String refreshToken;
  final int? accessExpiresAtMs;

  FolioSpringSessionProfile get profile => FolioSpringSessionProfile(
        uid: uid,
        email: email,
        displayName: displayName,
        emailVerified: emailVerified,
      );

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'email': email,
        if (displayName != null) 'displayName': displayName,
        'emailVerified': emailVerified,
        'accessToken': accessToken,
        'refreshToken': refreshToken,
        if (accessExpiresAtMs != null) 'accessExpiresAtMs': accessExpiresAtMs,
      };

  factory FolioCloudAccountSlot.fromJson(Map<String, dynamic> m) {
    return FolioCloudAccountSlot(
      uid: '${m['uid'] ?? ''}',
      email: '${m['email'] ?? ''}',
      displayName: m['displayName']?.toString(),
      emailVerified: m['emailVerified'] == true || m['emailVerified'] == '1',
      accessToken: '${m['accessToken'] ?? ''}',
      refreshToken: '${m['refreshToken'] ?? ''}',
      accessExpiresAtMs: m['accessExpiresAtMs'] is num
          ? (m['accessExpiresAtMs'] as num).toInt()
          : int.tryParse('${m['accessExpiresAtMs'] ?? ''}'),
    );
  }

  FolioCloudAccountSlot copyWith({
    String? email,
    String? displayName,
    bool? emailVerified,
    String? accessToken,
    String? refreshToken,
    int? accessExpiresAtMs,
  }) {
    return FolioCloudAccountSlot(
      uid: uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      emailVerified: emailVerified ?? this.emailVerified,
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      accessExpiresAtMs: accessExpiresAtMs ?? this.accessExpiresAtMs,
    );
  }
}

/// Sesión JWT propia (access + refresh) con soporte multi-cuenta en dispositivo.
///
/// Varias cuentas pueden coexistir; [uid]/[profile] reflejan la cuenta activa.
/// Login añade o actualiza un slot sin expulsar las demás.
class FolioSpringAuthSession extends ChangeNotifier {
  FolioSpringAuthSession({
    FlutterSecureStorage? storage,
    http.Client? httpClient,
  }) : _storage =
           storage ??
           const FlutterSecureStorage(
             aOptions: AndroidOptions(encryptedSharedPreferences: true),
           ),
       // Cliente compartido: keep-alive + fallback api.folio.com.es → backendfolio.
       _http = httpClient ?? folioCloudHttpClient;

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

  // Legacy single-slot keys (migrated once into v2 store).
  static const _kAccess = 'folio_spring_access_token_v1';
  static const _kRefresh = 'folio_spring_refresh_token_v1';
  static const _kEmail = 'folio_spring_email_v1';
  static const _kDisplayName = 'folio_spring_display_name_v1';
  static const _kEmailVerified = 'folio_spring_email_verified_v1';

  static const _kAccountsV2 = 'folio_spring_accounts_v2';
  static const _kActiveUidV2 = 'folio_spring_active_uid_v2';

  final Map<String, FolioCloudAccountSlot> _accounts = {};
  String? _activeUid;
  Future<void>? _refreshInFlight;

  FolioSpringSessionProfile? get profile => _accounts[_activeUid]?.profile;

  bool get isSignedIn {
    final slot = _accounts[_activeUid];
    return slot != null &&
        (slot.accessToken.isNotEmpty || slot.refreshToken.isNotEmpty);
  }

  String? get uid => _activeUid;
  String? get email => profile?.email;
  String? get displayName => profile?.displayName;
  bool get emailVerified => profile?.emailVerified ?? false;

  /// Cuentas guardadas en el dispositivo (incluye la activa).
  List<FolioCloudAccountSlot> get accounts {
    final list = _accounts.values.toList()
      ..sort((a, b) => a.email.toLowerCase().compareTo(b.email.toLowerCase()));
    return List.unmodifiable(list);
  }

  String? get activeUid => _activeUid;

  FolioCloudAccountSlot? get activeSlot =>
      _activeUid == null ? null : _accounts[_activeUid];

  /// Restaura tokens desde el almacén seguro (arranque de app).
  Future<void> restore() async {
    if (!FolioBackendConfig.useSpring) return;
    try {
      await _loadAccountsV2();
      if (_accounts.isEmpty) {
        await _migrateLegacySingleSlotIfNeeded();
      }
      if (_activeUid != null && !_accounts.containsKey(_activeUid)) {
        _activeUid = _accounts.keys.isEmpty ? null : _accounts.keys.first;
        await _persistActiveUid();
      }
      if (_activeUid == null && _accounts.isNotEmpty) {
        _activeUid = _accounts.keys.first;
        await _persistActiveUid();
      }
      AppLogger.info(
        'spring session restore',
        tag: 'auth',
        context: {
          'signedIn': isSignedIn,
          'accountCount': _accounts.length,
          'activeUid': _activeUid,
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

  Future<void> _loadAccountsV2() async {
    final raw = await _storage.read(key: _kAccountsV2);
    final active = await _storage.read(key: _kActiveUidV2);
    _accounts.clear();
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          for (final item in decoded) {
            if (item is Map) {
              final slot = FolioCloudAccountSlot.fromJson(
                item.map((k, v) => MapEntry('$k', v)),
              );
              if (slot.uid.isNotEmpty) {
                _accounts[slot.uid] = slot;
              }
            }
          }
        }
      } catch (_) {
        _accounts.clear();
      }
    }
    _activeUid = (active != null && active.isNotEmpty) ? active : null;
  }

  Future<void> _migrateLegacySingleSlotIfNeeded() async {
    final access = await _storage.read(key: _kAccess);
    final refresh = await _storage.read(key: _kRefresh);
    if (access == null || access.isEmpty) return;
    final claims = decodeJwtPayload(access);
    final sub = claims?['sub']?.toString();
    if (sub == null || sub.isEmpty) return;
    final email = await _storage.read(key: _kEmail);
    final displayName = await _storage.read(key: _kDisplayName);
    final verifiedRaw = await _storage.read(key: _kEmailVerified);
    final claimEmail = claims?['email']?.toString();
    final exp = _expFromClaims(claims);
    final slot = FolioCloudAccountSlot(
      uid: sub,
      email: (email?.isNotEmpty == true) ? email! : (claimEmail ?? ''),
      displayName: displayName,
      emailVerified: verifiedRaw == '1' || verifiedRaw == 'true',
      accessToken: access,
      refreshToken: refresh ?? '',
      accessExpiresAtMs: exp?.millisecondsSinceEpoch,
    );
    _accounts[sub] = slot;
    _activeUid = sub;
    await _persistAccounts();
    await _persistActiveUid();
    await Future.wait([
      _storage.delete(key: _kAccess),
      _storage.delete(key: _kRefresh),
      _storage.delete(key: _kEmail),
      _storage.delete(key: _kDisplayName),
      _storage.delete(key: _kEmailVerified),
    ]);
    AppLogger.info(
      'spring session migrated legacy single-slot to multi-account',
      tag: 'auth',
      context: {'uid': sub},
    );
  }

  Future<void> _persistAccounts() async {
    final list = _accounts.values.map((s) => s.toJson()).toList();
    await _storage.write(key: _kAccountsV2, value: jsonEncode(list));
  }

  Future<void> _persistActiveUid() async {
    final id = _activeUid;
    if (id == null || id.isEmpty) {
      await _storage.delete(key: _kActiveUidV2);
    } else {
      await _storage.write(key: _kActiveUidV2, value: id);
    }
  }

  /// Cambia la cuenta activa sin cerrar las demás.
  Future<void> switchAccount(String uid) async {
    if (!_accounts.containsKey(uid)) {
      throw StateError('Account not found: $uid');
    }
    if (_activeUid == uid) return;
    _activeUid = uid;
    await _persistActiveUid();
    notifyListeners();
    AppLogger.info(
      'spring account switched',
      tag: 'auth',
      context: {'uid': uid},
    );
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
    await login(email: email, password: password);
    final dn = resp['displayName']?.toString();
    if (_profileOrThrow() != null && dn != null && dn.isNotEmpty) {
      await updateLocalProfile(displayName: dn);
    }
  }

  FolioSpringSessionProfile? _profileOrThrow() => profile;

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

  Future<void> verifyEmailToken(String token) async {
    final uri =
        Uri.parse('${FolioBackendConfig.apiV1Prefix}/auth/verify-email');
    await _postJson(uri, {'token': token.trim()});
  }

  Future<void> confirmStudentEmailToken(String token) async {
    final trimmed = token.trim();
    final primary = Uri.parse(
      '${FolioBackendConfig.apiV1Prefix}/family/confirm-student',
    );
    try {
      await _postJson(primary, {'token': trimmed});
    } on FolioSpringAuthException catch (e) {
      final code = e.statusCode;
      if (code != 401 && code != 404) rethrow;
      final base = FolioBackendConfig.apiBaseUrl.toLowerCase();
      if (base.contains('api-beta') || base.contains('backendfoliobeta')) {
        rethrow;
      }
      final fallback = Uri.parse(
        'https://api-beta.folio.com.es/api/v1/family/confirm-student',
      );
      await _postJson(fallback, {'token': trimmed});
    }
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

  Future<void> verifyPassword({
    required String email,
    required String password,
  }) async {
    final sessionEmail = profile?.email.trim().toLowerCase();
    final trimmed = email.trim();
    if (sessionEmail != null &&
        sessionEmail.isNotEmpty &&
        trimmed.toLowerCase() != sessionEmail) {
      throw StateError('El correo no coincide con la sesión actual.');
    }
    final uri = Uri.parse('${FolioBackendConfig.apiV1Prefix}/auth/login');
    await _postJson(uri, {
      'email': trimmed,
      'password': password,
    });
  }

  /// Cierra solo la cuenta activa (las demás permanecen).
  Future<void> logout() async {
    final active = _activeUid;
    if (active == null) {
      await clear();
      return;
    }
    await removeAccount(active);
  }

  /// Elimina un slot concreto. Si era el activo, activa otra o queda sin sesión.
  Future<void> removeAccount(String uid) async {
    final slot = _accounts[uid];
    if (slot != null) {
      try {
        if (slot.refreshToken.isNotEmpty && slot.accessToken.isNotEmpty) {
          final uri =
              Uri.parse('${FolioBackendConfig.apiV1Prefix}/auth/logout');
          await _postJson(
            uri,
            {'refreshToken': slot.refreshToken},
            bearer: slot.accessToken,
            swallowErrors: true,
          );
        }
      } catch (_) {}
    }
    _accounts.remove(uid);
    if (_activeUid == uid) {
      _activeUid = _accounts.keys.isEmpty ? null : _accounts.keys.first;
    }
    await _persistAccounts();
    await _persistActiveUid();
    notifyListeners();
  }

  /// Cierra todas las cuentas del dispositivo.
  Future<void> clear() async {
    _accounts.clear();
    _activeUid = null;
    await _storage.delete(key: _kAccountsV2);
    await _storage.delete(key: _kActiveUidV2);
    await Future.wait([
      _storage.delete(key: _kAccess),
      _storage.delete(key: _kRefresh),
      _storage.delete(key: _kEmail),
      _storage.delete(key: _kDisplayName),
      _storage.delete(key: _kEmailVerified),
    ]);
    notifyListeners();
  }

  Future<String?> getAccessToken({bool forceRefresh = false}) async {
    final slot = activeSlot;
    if (slot == null) return null;
    final exp = slot.accessExpiresAtMs == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(
            slot.accessExpiresAtMs!,
            isUtc: true,
          );
    final nearExpiry = exp == null ||
        DateTime.now().toUtc().isAfter(
              exp.subtract(const Duration(seconds: 60)),
            );
    if (slot.accessToken.isNotEmpty && !forceRefresh && !nearExpiry) {
      return slot.accessToken;
    }
    if (slot.refreshToken.isEmpty) {
      if (nearExpiry) return null;
      return slot.accessToken.isNotEmpty ? slot.accessToken : null;
    }
    try {
      await _refreshTokens();
    } catch (e, st) {
      AppLogger.warn(
        'spring token refresh failed',
        tag: 'auth',
        context: {'error': '$e', 'stack': '$st'},
      );
      if (forceRefresh || nearExpiry) {
        return null;
      }
    }
    return activeSlot?.accessToken;
  }

  Future<void> _refreshTokens() async {
    final existing = _refreshInFlight;
    if (existing != null) {
      await existing;
      return;
    }
    final fut = () async {
      final slot = activeSlot;
      if (slot == null || slot.refreshToken.isEmpty) {
        throw StateError('No refresh token');
      }
      final uri = Uri.parse('${FolioBackendConfig.apiV1Prefix}/auth/refresh');
      final resp = await _postJson(uri, {'refreshToken': slot.refreshToken});
      await _applyTokenResponse(
        resp,
        fallbackEmail: slot.email,
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
    final previous = _accounts[sub];
    final expiresAt = DateTime.now().toUtc().add(Duration(seconds: expiresIn));
    final slot = FolioCloudAccountSlot(
      uid: sub,
      email: claimEmail,
      displayName: previous?.displayName,
      emailVerified: resp['emailVerified'] == true ||
          previous?.emailVerified == true,
      accessToken: access,
      refreshToken: refresh,
      accessExpiresAtMs: expiresAt.millisecondsSinceEpoch,
    );
    _accounts[sub] = slot;
    _activeUid = sub;
    await _persistAccounts();
    await _persistActiveUid();
    notifyListeners();
    AppLogger.info(
      'spring tokens applied',
      tag: 'auth',
      context: {
        'uid': sub,
        'expiresIn': expiresIn,
        'accountCount': _accounts.length,
      },
    );
  }

  Future<void> updateLocalProfile({
    String? displayName,
    bool? emailVerified,
  }) async {
    final uid = _activeUid;
    final slot = uid == null ? null : _accounts[uid];
    if (slot == null) return;
    _accounts[uid!] = slot.copyWith(
      displayName: displayName ?? slot.displayName,
      emailVerified: emailVerified ?? slot.emailVerified,
    );
    await _persistAccounts();
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
      'user_suspended' => 'user-disabled',
      _ => apiError.replaceAll('_', '-'),
    };
  }
  if (statusCode == 401) return 'invalid-credential';
  if (statusCode == 409) return 'email-already-in-use';
  return 'unknown';
}
