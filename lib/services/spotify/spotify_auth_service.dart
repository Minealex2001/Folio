import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart' show Sha256;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../../config/folio_local_secrets.dart';
import '../../models/spotify_integration_state.dart';
import '../app_logger.dart';
import '../env/local_env.dart';
import 'spotify_auth_config.dart';
import 'spotify_auth_errors.dart';
import '../../services/folio_cloud/folio_cloud_identity.dart';
import '../../config/folio_backend_config.dart';
import '../oauth/oauth_deep_link_io.dart'
    if (dart.library.html) '../oauth/oauth_deep_link_stub.dart' as deeplink;
import '../oauth/oauth_launch.dart';
import '../oauth/oauth_mobile.dart';
import 'spotify_oauth_loopback_io.dart'
    if (dart.library.html) 'spotify_oauth_loopback_stub.dart' as loopback;
import 'spotify_oauth_web_stub.dart'
    if (dart.library.html) 'spotify_oauth_web.dart' as web_oauth;

export 'spotify_auth_errors.dart';

class SpotifyAuthService {
  SpotifyAuthService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const _uuid = Uuid();

  static String overrideClientId = '';

  static String spotifyClientId() {
    final override = overrideClientId.trim();
    if (override.isNotEmpty) return override;
    // Debe ser `const`: en Web/JS `String.fromEnvironment` no-const lanza.
    const define = String.fromEnvironment('SPOTIFY_OAUTH_CLIENT_ID');
    final fromDefine = define.trim();
    if (fromDefine.isNotEmpty) return fromDefine;
    final fromDart = FolioLocalSecrets.spotifyOAuthClientId.trim();
    if (fromDart.isNotEmpty) return fromDart;
    final local = (LocalEnv.get('SPOTIFY_OAUTH_CLIENT_ID') ?? '').trim();
    if (local.isNotEmpty) return local;
    final fromOs = loopback.readOsEnv('SPOTIFY_OAUTH_CLIENT_ID');
    if (fromOs.isNotEmpty) return fromOs;
    return SpotifyAuthConfig.officialClientId;
  }

  /// Inicia OAuth 2.0 (PKCE) y devuelve una [SpotifyConnection] lista para usar.
  Future<SpotifyConnection> connect({
    required String label,
    List<String> scopes = SpotifyAuthConfig.defaultScopes,
    SpotifyAuthCancelToken? cancelToken,
  }) async {
    if (kIsWeb) {
      return _connectWeb(
        label: label,
        scopes: scopes,
        cancelToken: cancelToken,
      );
    }
    if (oauthUsesMobileDeepLink) {
      return _connectMobile(
        label: label,
        scopes: scopes,
        cancelToken: cancelToken,
      );
    }
    return _connectLoopback(
      label: label,
      scopes: scopes,
      cancelToken: cancelToken,
    );
  }

  Future<SpotifyConnection> _connectMobile({
    required String label,
    required List<String> scopes,
    SpotifyAuthCancelToken? cancelToken,
  }) async {
    final clientId = spotifyClientId();
    if (clientId.isEmpty) {
      throw StateError(
        'Falta SPOTIFY_OAUTH_CLIENT_ID. Configúralo en folio_local_secrets.dart '
        'o con --dart-define=SPOTIFY_OAUTH_CLIENT_ID=...',
      );
    }

    final redirectUri = SpotifyAuthConfig.mobileRedirectUri;
    final state = _randomToken(16);
    final codeVerifier = _randomToken(64);
    final codeChallenge = await _pkceCodeChallenge(codeVerifier);

    final authUri = Uri.https('accounts.spotify.com', '/authorize', {
      'client_id': clientId,
      'response_type': 'code',
      'redirect_uri': redirectUri.toString(),
      'state': state,
      'scope': scopes.join(' '),
      'code_challenge_method': 'S256',
      'code_challenge': codeChallenge,
    });

    AppLogger.info(
      'Launching Spotify OAuth (mobile)',
      tag: 'spotify',
      context: {'redirectUri': redirectUri.toString()},
    );

    final codeFuture = deeplink.awaitMobileOAuthCode(
      provider: SpotifyAuthConfig.oauthProvider,
      expectedState: state,
      whenCancelled: cancelToken?.whenCancelled,
    );

    final opened = await launchOAuthAuthorizeUrl(authUri);
    if (!opened) {
      cancelToken?.cancel();
      throw StateError(
        'No se pudo abrir el navegador para OAuth de Spotify. '
        'Abre manualmente esta URL:\n$authUri',
      );
    }

    final code = await codeFuture;

    final tokenJson = await _exchangeCode(
      code: code,
      clientId: clientId,
      redirectUri: redirectUri,
      codeVerifier: codeVerifier,
    );

    return _connectionFromTokenJson(
      tokenJson: tokenJson,
      label: label,
      accessTokenOverride: null,
    );
  }

  Future<SpotifyConnection> _connectLoopback({
    required String label,
    required List<String> scopes,
    SpotifyAuthCancelToken? cancelToken,
  }) async {
    final clientId = spotifyClientId();
    if (clientId.isEmpty) {
      throw StateError(
        'Falta SPOTIFY_OAUTH_CLIENT_ID. Configúralo en folio_local_secrets.dart '
        'o con --dart-define=SPOTIFY_OAUTH_CLIENT_ID=...',
      );
    }

    final redirectUri = SpotifyAuthConfig.loopbackRedirectUri;
    final state = _randomToken(16);
    final codeVerifier = _randomToken(64);
    final codeChallenge = await _pkceCodeChallenge(codeVerifier);

    final authUri = Uri.https('accounts.spotify.com', '/authorize', {
      'client_id': clientId,
      'response_type': 'code',
      'redirect_uri': redirectUri.toString(),
      'state': state,
      'scope': scopes.join(' '),
      'code_challenge_method': 'S256',
      'code_challenge': codeChallenge,
    });

    AppLogger.info(
      'Launching Spotify OAuth',
      tag: 'spotify',
      context: {'redirectUri': redirectUri.toString()},
    );

    // Bind del servidor antes de abrir el navegador.
    final codeFuture = loopback.awaitLoopbackOAuthCode(
      port: SpotifyAuthConfig.oauthLoopbackPort,
      expectedState: state,
      whenCancelled: cancelToken?.whenCancelled,
    );

    final opened = await launchOAuthAuthorizeUrl(authUri);
    if (!opened) {
      cancelToken?.cancel();
      throw StateError(
        'No se pudo abrir el navegador para OAuth de Spotify. '
        'Abre manualmente esta URL:\n$authUri',
      );
    }

    final code = await codeFuture;

    final tokenJson = await _exchangeCode(
      code: code,
      clientId: clientId,
      redirectUri: redirectUri,
      codeVerifier: codeVerifier,
    );

    return _connectionFromTokenJson(
      tokenJson: tokenJson,
      label: label,
      accessTokenOverride: null,
    );
  }

  Future<SpotifyConnection> _connectWeb({
    required String label,
    required List<String> scopes,
    SpotifyAuthCancelToken? cancelToken,
  }) async {
    final clientId = spotifyClientId();
    if (clientId.isEmpty) {
      throw StateError('Falta SPOTIFY_OAUTH_CLIENT_ID para OAuth en Web.');
    }
    if (!folioCloudHasSession()) {
      throw StateError(
        'Firebase no está inicializado (requerido para OAuth Web).',
      );
    }

    final state = _randomToken(16);
    final codeVerifier = _randomToken(64);
    final codeChallenge = await _pkceCodeChallenge(codeVerifier);

    // Misma origen que Folio → localStorage/postMessage funcionan.
    // Registrar en Spotify Dashboard: {origin}/spotify_oauth_callback.html
    final redirectUri = Uri.parse(
      '${Uri.base.origin}/spotify_oauth_callback.html',
    );

    final authUri = Uri.https('accounts.spotify.com', '/authorize', {
      'client_id': clientId,
      'response_type': 'code',
      'redirect_uri': redirectUri.toString(),
      'state': state,
      'scope': scopes.join(' '),
      'code_challenge_method': 'S256',
      'code_challenge': codeChallenge,
    });

    web_oauth.clearPendingOAuthResult();

    AppLogger.info(
      'Launching Spotify OAuth (web)',
      tag: 'spotify',
      context: {'redirectUri': redirectUri.toString()},
    );

    final codeFuture = web_oauth.awaitWebOAuthCode(
      expectedState: state,
      whenCancelled: cancelToken?.whenCancelled,
    );

    // En web abrir en pestaña nueva; en el resto de plataformas el helper
    // no aplica aquí porque este método solo se llama con kIsWeb.
    final opened = await launchUrl(
      authUri,
      mode: LaunchMode.platformDefault,
      webOnlyWindowName: '_blank',
    );
    if (!opened) {
      cancelToken?.cancel();
      throw StateError('No se pudo abrir el navegador para OAuth de Spotify.');
    }

    final code = await codeFuture;

    final tokenJson = await _exchangeCodeViaCloud(
      code: code,
      clientId: clientId,
      redirectUri: redirectUri,
      codeVerifier: codeVerifier,
    );

    return _connectionFromTokenJson(
      tokenJson: tokenJson,
      label: label,
      accessTokenOverride: null,
    );
  }

  Future<SpotifyConnection> _connectionFromTokenJson({
    required Map<String, dynamic> tokenJson,
    required String label,
    String? accessTokenOverride,
  }) async {
    final accessToken =
        (accessTokenOverride ?? tokenJson['access_token'] as String? ?? '')
            .trim();
    final refreshToken = (tokenJson['refresh_token'] as String? ?? '').trim();
    final expiresIn = (tokenJson['expires_in'] as num?)?.toInt() ?? 3600;
    if (accessToken.isEmpty) {
      throw StateError('OAuth completado, pero falta access_token.');
    }
    final expiresAt = DateTime.now().toUtc().add(Duration(seconds: expiresIn));

    final profile = await _fetchProfile(accessToken);
    final displayName = (profile['display_name'] as String? ?? '').trim();
    final userId = (profile['id'] as String? ?? '').trim();
    final scope = (tokenJson['scope'] as String? ?? '').trim();

    return SpotifyConnection(
      id: 'spotify_${_uuid.v4()}',
      label: label.trim().isEmpty
          ? (displayName.isEmpty ? 'Spotify' : displayName)
          : label.trim(),
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresAt: expiresAt,
      spotifyUserId: userId.isEmpty ? null : userId,
      displayName: displayName.isEmpty ? null : displayName,
      grantedScopes: scope.isEmpty
          ? const []
          : scope.split(' ').where((s) => s.isNotEmpty).toList(growable: false),
    );
  }

  Future<Map<String, dynamic>> _fetchProfile(String accessToken) async {
    final resp = await _client
        .get(
          Uri.https('api.spotify.com', '/v1/me'),
          headers: {'authorization': 'Bearer $accessToken'},
        )
        .timeout(const Duration(seconds: 20));
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      return const {};
    }
    final decoded = jsonDecode(resp.body);
    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
    return const {};
  }

  Future<Map<String, dynamic>> exchangeRefreshToken({
    required String refreshToken,
    String? clientId,
  }) async {
    final cid = (clientId ?? spotifyClientId()).trim();
    if (cid.isEmpty) {
      throw StateError('Falta SPOTIFY_OAUTH_CLIENT_ID.');
    }
    if (kIsWeb && folioCloudHasSession()) {
      // En Web el token endpoint de Spotify suele bloquear CORS; usamos proxy.
      return _exchangeRefreshViaCloud(
        refreshToken: refreshToken,
        clientId: cid,
      );
    }
    final resp = await _client
        .post(
          Uri.https('accounts.spotify.com', '/api/token'),
          headers: {'content-type': 'application/x-www-form-urlencoded'},
          body: {
            'grant_type': 'refresh_token',
            'refresh_token': refreshToken,
            'client_id': cid,
          },
        )
        .timeout(const Duration(seconds: 30));
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw StateError(
        'Refresh token Spotify falló (${resp.statusCode}): ${resp.body}',
      );
    }
    final decoded = jsonDecode(resp.body);
    if (decoded is! Map) {
      throw StateError('Respuesta inválida al refrescar token Spotify.');
    }
    return Map<String, dynamic>.from(decoded);
  }

  Future<Map<String, String>> _folioIdTokenHeader() async {
    final token = await folioCloudBearerToken();
    if (token == null || token.isEmpty) {
      throw StateError('Inicia sesión en Folio Cloud.');
    }
    return {'authorization': 'Bearer $token'};
  }

  Future<Map<String, dynamic>> _exchangeRefreshViaCloud({
    required String refreshToken,
    required String clientId,
  }) async {
    // Reutilizamos el mismo endpoint de intercambio con grant distinto si
    // el CF lo soporta; si no, intentamos refresh directo (puede fallar CORS).
    final uri = Uri.parse(
      '${FolioBackendConfig.apiV1Prefix}/integrations/spotify/oauth-exchange',
    );
    final resp = await _client
        .post(
          uri,
          headers: {
            'content-type': 'application/json; charset=utf-8',
            ...await _folioIdTokenHeader(),
          },
          body: jsonEncode({
            'grantType': 'refresh_token',
            'refreshToken': refreshToken,
            'clientId': clientId,
          }),
        )
        .timeout(const Duration(seconds: 30));
    late final Map<String, dynamic> mapTry;
    try {
      final decoded = jsonDecode(resp.body);
      if (decoded is! Map) throw StateError('bad shape');
      mapTry = Map<String, dynamic>.from(decoded);
    } catch (_) {
      throw StateError(
        'Respuesta inválida del servidor Spotify refresh (${resp.statusCode}): ${resp.body}',
      );
    }
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      final err =
          mapTry['error']?.toString() ?? mapTry['body']?.toString() ?? resp.body;
      throw StateError(
        'Refresh Spotify vía servidor falló (${resp.statusCode}): $err',
      );
    }
    return mapTry;
  }

  Future<Map<String, dynamic>> _exchangeCode({
    required String code,
    required String clientId,
    required Uri redirectUri,
    required String codeVerifier,
  }) async {
    if (kIsWeb && folioCloudHasSession()) {
      return _exchangeCodeViaCloud(
        code: code,
        clientId: clientId,
        redirectUri: redirectUri,
        codeVerifier: codeVerifier,
      );
    }
    final resp = await _client
        .post(
          Uri.https('accounts.spotify.com', '/api/token'),
          headers: {'content-type': 'application/x-www-form-urlencoded'},
          body: {
            'grant_type': 'authorization_code',
            'code': code,
            'redirect_uri': redirectUri.toString(),
            'client_id': clientId,
            'code_verifier': codeVerifier,
          },
        )
        .timeout(const Duration(seconds: 30));
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw StateError(
        'OAuth token exchange falló (${resp.statusCode}): ${resp.body}',
      );
    }
    final decoded = jsonDecode(resp.body);
    if (decoded is! Map) {
      throw StateError('Respuesta inválida del token endpoint Spotify.');
    }
    return Map<String, dynamic>.from(decoded);
  }

  Future<Map<String, dynamic>> _exchangeCodeViaCloud({
    required String code,
    required String clientId,
    required Uri redirectUri,
    required String codeVerifier,
  }) async {
    final uri = Uri.parse(
      '${FolioBackendConfig.apiV1Prefix}/integrations/spotify/oauth-exchange',
    );
    final resp = await _client
        .post(
          uri,
          headers: {
            'content-type': 'application/json; charset=utf-8',
            ...await _folioIdTokenHeader(),
          },
          body: jsonEncode({
            'code': code,
            'redirectUri': redirectUri.toString(),
            'clientId': clientId,
            'codeVerifier': codeVerifier,
          }),
        )
        .timeout(const Duration(seconds: 30));
    late final Map<String, dynamic> mapTry;
    try {
      final decoded = jsonDecode(resp.body);
      if (decoded is! Map) throw StateError('bad shape');
      mapTry = Map<String, dynamic>.from(decoded);
    } catch (_) {
      throw StateError(
        'Respuesta inválida del servidor Spotify OAuth (${resp.statusCode}): ${resp.body}',
      );
    }
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      final err =
          mapTry['error']?.toString() ?? mapTry['body']?.toString() ?? resp.body;
      throw StateError(
        'Intercambio OAuth Spotify vía servidor falló (${resp.statusCode}): $err',
      );
    }
    return mapTry;
  }

  static String _randomToken(int byteLength) {
    final r = Random.secure();
    final bytes = List<int>.generate(byteLength, (_) => r.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  static Future<String> _pkceCodeChallenge(String codeVerifier) async {
    final hash = await Sha256().hash(utf8.encode(codeVerifier));
    return base64UrlEncode(hash.bytes).replaceAll('=', '');
  }
}
