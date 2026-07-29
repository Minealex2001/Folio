import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart' show Sha256;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../../config/folio_local_secrets.dart';
import '../../models/slack_integration_state.dart';
import '../app_logger.dart';
import '../env/local_env.dart';
import '../oauth/oauth_loopback_io.dart'
    if (dart.library.html) '../oauth/oauth_loopback_stub.dart' as loopback;
import 'slack_auth_config.dart';

import '../../services/folio_cloud/folio_cloud_identity.dart';
import '../../config/folio_backend_config.dart';
class SlackAuthCancelToken {
  final Completer<void> _c = Completer<void>();
  Future<void> get whenCancelled => _c.future;
  void cancel() {
    if (!_c.isCompleted) _c.complete();
  }
}

class SlackAuthService {
  SlackAuthService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const _uuid = Uuid();
  static String overrideClientId = '';

  static String slackClientId() {
    final override = overrideClientId.trim();
    if (override.isNotEmpty) return override;
    const define = String.fromEnvironment('SLACK_OAUTH_CLIENT_ID');
    final fromDefine = define.trim();
    if (fromDefine.isNotEmpty) return fromDefine;
    final fromDart = FolioLocalSecrets.slackOAuthClientId.trim();
    if (fromDart.isNotEmpty) return fromDart;
    final local = (LocalEnv.get('SLACK_OAUTH_CLIENT_ID') ?? '').trim();
    if (local.isNotEmpty) return local;
    final fromOs = loopback.readOsEnv('SLACK_OAUTH_CLIENT_ID');
    if (fromOs.isNotEmpty) return fromOs;
    return SlackAuthConfig.officialClientId;
  }

  /// OAuth 2.0 PKCE (desktop loopback). Web: lanza [UnsupportedError] por ahora.
  Future<SlackConnection> connect({
    required String label,
    List<String> scopes = SlackAuthConfig.defaultScopes,
    SlackAuthCancelToken? cancelToken,
  }) async {
    if (kIsWeb) {
      throw UnsupportedError(
        'Slack OAuth en Web aún no está disponible; usa Incoming Webhook.',
      );
    }
    final clientId = slackClientId();
    if (clientId.isEmpty) {
      throw StateError(
        'Falta SLACK_OAUTH_CLIENT_ID. Configúralo en folio_local_secrets.dart '
        'o con --dart-define=SLACK_OAUTH_CLIENT_ID=...',
      );
    }
    if (!folioCloudHasSession() || !folioCloudHasSession()) {
      throw StateError('Se requiere sesión Folio Cloud para OAuth de Slack.');
    }

    final redirectUri = SlackAuthConfig.loopbackRedirectUri;
    final state = _randomToken(16);
    final codeVerifier = _randomToken(64);
    final codeChallenge = await _pkceCodeChallenge(codeVerifier);

    final authUri = Uri.https('slack.com', '/oauth/v2/authorize', {
      'client_id': clientId,
      'scope': scopes.join(','),
      'redirect_uri': redirectUri.toString(),
      'state': state,
      'code_challenge': codeChallenge,
      'code_challenge_method': 'S256',
    });

    final codeFuture = loopback.awaitLoopbackOAuthCode(
      port: SlackAuthConfig.oauthLoopbackPort,
      expectedState: state,
      whenCancelled: cancelToken?.whenCancelled,
    );

    final opened =
        await launchUrl(authUri, mode: LaunchMode.externalApplication) ||
        await launchUrl(authUri, mode: LaunchMode.platformDefault);
    if (!opened) {
      cancelToken?.cancel();
      throw StateError('No se pudo abrir el navegador para OAuth de Slack.');
    }

    final code = await codeFuture;
    final tokenJson = await _exchangeCode(
      code: code,
      clientId: clientId,
      redirectUri: redirectUri,
      codeVerifier: codeVerifier,
    );

    final accessToken = (tokenJson['access_token'] as String? ?? '').trim();
    final refreshToken = (tokenJson['refresh_token'] as String? ?? '').trim();
    final team = tokenJson['team'];
    final teamId = team is Map
        ? (team['id'] as String? ?? '').trim()
        : (tokenJson['team_id'] as String? ?? '').trim();
    final botUserId = (tokenJson['bot_user_id'] as String? ?? '').trim();
    final incoming = tokenJson['incoming_webhook'];
    String webhookUrl = '';
    String channelId = '';
    if (incoming is Map) {
      webhookUrl = (incoming['url'] as String? ?? '').trim();
      channelId = (incoming['channel_id'] as String? ?? '').trim();
    }
    if (accessToken.isEmpty && webhookUrl.isEmpty) {
      throw StateError('Slack OAuth no devolvió token ni webhook.');
    }

    AppLogger.info('Slack OAuth connected', tag: 'slack', context: {
      'teamId': teamId,
      'hasWebhook': webhookUrl.isNotEmpty,
    });

    return SlackConnection(
      id: _uuid.v4(),
      label: label.trim().isEmpty ? 'Slack' : label.trim(),
      webhookUrl: webhookUrl,
      accessToken: accessToken,
      refreshToken: refreshToken,
      teamId: teamId,
      botUserId: botUserId,
      channelId: channelId,
    );
  }

  Future<Map<String, dynamic>> _exchangeCode({
    required String code,
    required String clientId,
    required Uri redirectUri,
    required String codeVerifier,
  }) async {
    final uri = Uri.parse(
      '${FolioBackendConfig.apiV1Prefix}/integrations/slack/oauth-exchange',
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
      }),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw StateError('Slack token exchange failed: ${res.statusCode} ${res.body}');
    }
    final decoded = jsonDecode(res.body);
    if (decoded is! Map) throw StateError('Slack token exchange: invalid JSON');
    return Map<String, dynamic>.from(decoded);
  }

  static Future<String> _pkceCodeChallenge(String verifier) async {
    final digest = await Sha256().hash(utf8.encode(verifier));
    return base64UrlEncode(digest.bytes).replaceAll('=', '');
  }

  static String _randomToken(int length) {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
    final rnd = Random.secure();
    return List.generate(length, (_) => chars[rnd.nextInt(chars.length)]).join();
  }
}

String base64UrlEncode(List<int> bytes) {
  return base64Url.encode(bytes);
}
