import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart' show Sha256;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../../config/folio_local_secrets.dart';
import '../../models/teams_integration_state.dart';
import '../app_logger.dart';
import '../env/local_env.dart';
import '../oauth/oauth_deep_link_io.dart'
    if (dart.library.html) '../oauth/oauth_deep_link_stub.dart' as deeplink;
import '../oauth/oauth_launch.dart';
import '../oauth/oauth_loopback_io.dart'
    if (dart.library.html) '../oauth/oauth_loopback_stub.dart' as loopback;
import '../oauth/oauth_mobile.dart';
import 'teams_auth_config.dart';

import '../../services/folio_cloud/folio_cloud_identity.dart';
import '../../config/folio_backend_config.dart';
class TeamsAuthCancelToken {
  final Completer<void> _c = Completer<void>();
  Future<void> get whenCancelled => _c.future;
  void cancel() {
    if (!_c.isCompleted) _c.complete();
  }
}

class TeamsAuthService {
  TeamsAuthService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const _uuid = Uuid();
  static String overrideClientId = '';

  static String teamsClientId() {
    final override = overrideClientId.trim();
    if (override.isNotEmpty) return override;
    const define = String.fromEnvironment('TEAMS_OAUTH_CLIENT_ID');
    final fromDefine = define.trim();
    if (fromDefine.isNotEmpty) return fromDefine;
    final fromDart = FolioLocalSecrets.teamsOAuthClientId.trim();
    if (fromDart.isNotEmpty) return fromDart;
    final local = (LocalEnv.get('TEAMS_OAUTH_CLIENT_ID') ?? '').trim();
    if (local.isNotEmpty) return local;
    final fromOs = loopback.readOsEnv('TEAMS_OAUTH_CLIENT_ID');
    if (fromOs.isNotEmpty) return fromOs;
    return TeamsAuthConfig.officialClientId;
  }

  Future<TeamsConnection> connect({
    required String label,
    List<String> scopes = TeamsAuthConfig.defaultScopes,
    TeamsAuthCancelToken? cancelToken,
  }) async {
    if (kIsWeb) {
      throw UnsupportedError(
        'Teams OAuth en Web aún no está disponible; usa Incoming Webhook.',
      );
    }
    final clientId = teamsClientId();
    if (clientId.isEmpty) {
      throw StateError(
        'Falta TEAMS_OAUTH_CLIENT_ID. Configúralo en folio_local_secrets.dart.',
      );
    }
    if (!folioCloudHasSession() || !folioCloudHasSession()) {
      throw StateError('Se requiere sesión Folio Cloud para OAuth de Teams.');
    }

    final useMobile = oauthUsesMobileDeepLink;
    final redirectUri = useMobile
        ? TeamsAuthConfig.mobileRedirectUri
        : TeamsAuthConfig.loopbackRedirectUri;
    final state = _randomToken(16);
    final codeVerifier = _randomToken(64);
    final codeChallenge = await _pkceCodeChallenge(codeVerifier);

    final authUri = Uri.parse(TeamsAuthConfig.authorizeUrl).replace(
      queryParameters: {
        'client_id': clientId,
        'response_type': 'code',
        'redirect_uri': redirectUri.toString(),
        'response_mode': 'query',
        'scope': scopes.join(' '),
        'state': state,
        'code_challenge': codeChallenge,
        'code_challenge_method': 'S256',
      },
    );

    final codeFuture = useMobile
        ? deeplink.awaitMobileOAuthCode(
            provider: TeamsAuthConfig.oauthProvider,
            expectedState: state,
            whenCancelled: cancelToken?.whenCancelled,
          )
        : loopback.awaitLoopbackOAuthCode(
            port: TeamsAuthConfig.oauthLoopbackPort,
            expectedState: state,
            whenCancelled: cancelToken?.whenCancelled,
          );

    final opened = await launchOAuthAuthorizeUrl(authUri);
    if (!opened) {
      cancelToken?.cancel();
      throw StateError('No se pudo abrir el navegador para OAuth de Teams.');
    }

    final code = await codeFuture;
    final tokenJson = await _exchangeCode(
      code: code,
      clientId: clientId,
      redirectUri: redirectUri,
      codeVerifier: codeVerifier,
      scope: scopes.join(' '),
    );

    final accessToken = (tokenJson['access_token'] as String? ?? '').trim();
    final refreshToken = (tokenJson['refresh_token'] as String? ?? '').trim();
    final expiresIn = tokenJson['expires_in'];
    DateTime? expiresAt;
    if (expiresIn is num) {
      expiresAt =
          DateTime.now().toUtc().add(Duration(seconds: expiresIn.toInt()));
    }
    if (accessToken.isEmpty) {
      throw StateError('Teams OAuth no devolvió access_token.');
    }

    AppLogger.info('Teams OAuth connected', tag: 'teams');

    return TeamsConnection(
      id: _uuid.v4(),
      label: label.trim().isEmpty ? 'Teams' : label.trim(),
      webhookUrl: '',
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresAt: expiresAt?.toIso8601String() ?? '',
    );
  }

  Future<Map<String, dynamic>> _exchangeCode({
    required String code,
    required String clientId,
    required Uri redirectUri,
    required String codeVerifier,
    required String scope,
  }) async {
    final uri = Uri.parse(
      '${FolioBackendConfig.apiV1Prefix}/integrations/teams/oauth-exchange',
    );
    final token = await folioCloudBearerToken();
    if (token == null || token.isEmpty) {
      throw StateError('Inicia sesión en Folio Cloud.');
    }
    final res = await _client.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'grantType': 'authorization_code',
        'code': code,
        'clientId': clientId,
        'redirectUri': redirectUri.toString(),
        'codeVerifier': codeVerifier,
        'scope': scope,
      }),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw StateError(
        'Teams token exchange failed: ${res.statusCode} ${res.body}',
      );
    }
    final decoded = jsonDecode(res.body);
    if (decoded is! Map) throw StateError('Teams token exchange: invalid JSON');
    return Map<String, dynamic>.from(decoded);
  }

  static Future<String> _pkceCodeChallenge(String verifier) async {
    final digest = await Sha256().hash(utf8.encode(verifier));
    return base64Url.encode(digest.bytes).replaceAll('=', '');
  }

  static String _randomToken(int length) {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
    final rnd = Random.secure();
    return List.generate(length, (_) => chars[rnd.nextInt(chars.length)]).join();
  }
}
