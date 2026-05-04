import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:firebase_core/firebase_core.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../../config/folio_local_secrets.dart';
import '../../firebase_options.dart';
import '../../models/jira_integration_state.dart';
import '../app_logger.dart';
import '../env/local_env.dart';
import '../folio_cloud/folio_cloud_callable.dart';

class JiraAuthCancelledException implements Exception {
  const JiraAuthCancelledException();
  @override
  String toString() => 'OAuth cancelado por el usuario.';
}

class JiraAuthCancelToken {
  final Completer<void> _c = Completer<void>();
  bool get isCancelled => _c.isCompleted;
  Future<void> get whenCancelled => _c.future;
  void cancel() {
    if (!_c.isCompleted) _c.complete();
  }
}

class JiraAuthService {
  JiraAuthService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _uuid = Uuid();

  /// Override temporal configurado por el usuario en Ajustes.
  static String overrideClientId = '';

  /// Client ID oficial de Folio para Jira Cloud OAuth 3LO (PKCE).
  ///
  /// Importante: NO usar/embeder Client Secret en una app cliente.
  static const String _officialCloudClientId = '7HEIa3N2dGmMWWscFmYnjGRLNSjzg8hI';

  /// Puerto fijo para OAuth loopback.
  ///
  /// Atlassian requiere que el redirect URI registrado coincida exactamente,
  /// así que no podemos usar puertos aleatorios.
  static const int _oauthLoopbackPort = 45747;

  static String _readEnv(String key) {
    final define = String.fromEnvironment(key).trim();
    if (define.isNotEmpty) return define;
    final fromDart = FolioLocalSecrets.valueForDefineKey(key).trim();
    if (fromDart.isNotEmpty) return fromDart;
    final local = (LocalEnv.get(key) ?? '').trim();
    if (local.isNotEmpty) return local;
    return (Platform.environment[key] ?? '').trim();
  }

  static String jiraCloudClientSecret() => _readEnv('JIRA_OAUTH_CLIENT_SECRET');

  /// Client ID para Jira Cloud OAuth 3LO (PKCE).
  ///
  /// Orden de prioridad:
  /// 1) `overrideClientId` (Ajustes, dev)
  /// 2) `JIRA_OAUTH_CLIENT_ID` (env o --dart-define)
  /// 3) Client ID oficial (fallback)
  static String jiraCloudClientId() {
    final env = _readEnv('JIRA_OAUTH_CLIENT_ID');
    if (env.isNotEmpty) return env;
    return _officialCloudClientId;
  }

  /// Inicia OAuth 3LO (PKCE) y devuelve una conexión Cloud lista para usar.
  Future<JiraConnection> connectCloud({
    required String label,
    List<String> scopes = const [
      'read:jira-work',
      'write:jira-work',
      // Requerido por Jira Software board APIs (según doc del endpoint /rest/agile/1.0/board).
      'read:project:jira',
      // Requerido para endpoints que devuelven issues (p.ej. /board/{id}/issue).
      'read:issue-details:jira',
      // Jira Software (Agile REST API) usa scopes granulares (no existe "read:jira-software").
      // - Listar boards/backlogs/issues en board.
      'read:board-scope:jira-software',
      // - Leer configuración del board (columnas/statuses) para importar columnas.
      'read:board-scope.admin:jira-software',
      'offline_access',
    ],
    JiraAuthCancelToken? cancelToken,
  }) async {
    final clientId =
        overrideClientId.trim().isNotEmpty ? overrideClientId.trim() : jiraCloudClientId();
    final clientSecret = jiraCloudClientSecret().trim();

    // Loopback callback (puerto fijo).
    HttpServer server;
    try {
      server = await HttpServer.bind(
        InternetAddress.loopbackIPv4,
        _oauthLoopbackPort,
        shared: false,
      );
    } catch (e) {
      throw StateError(
        'No se pudo abrir el callback OAuth en http://127.0.0.1:$_oauthLoopbackPort/callback. '
        'Comprueba que el puerto $_oauthLoopbackPort esté libre y vuelve a intentar. '
        'Detalle: $e',
      );
    }
    final redirectUri =
        Uri.parse('http://127.0.0.1:$_oauthLoopbackPort/callback');

    final state = _randomToken(16);

    final authUri = Uri.https('auth.atlassian.com', '/authorize', {
      'audience': 'api.atlassian.com',
      'client_id': clientId,
      'scope': scopes.join(' '),
      'redirect_uri': redirectUri.toString(),
      'state': state,
      'response_type': 'code',
      'prompt': 'consent',
    });

    AppLogger.info(
      'Launching Jira Cloud OAuth',
      tag: 'jira',
      context: {'redirectUri': redirectUri.toString()},
    );

    // En Windows algunos entornos devuelven `true` pero no abren nada con ciertos modos.
    // Probamos dos modos antes de fallar.
    final openedExternal =
        await launchUrl(authUri, mode: LaunchMode.externalApplication);
    final openedDefault =
        openedExternal ? true : await launchUrl(authUri, mode: LaunchMode.platformDefault);
    if (!openedExternal && !openedDefault) {
      await server.close(force: true);
      throw StateError(
        'No se pudo abrir el navegador para OAuth de Jira. '
        'Abre manualmente esta URL:\n$authUri',
      );
    }

    final code = await _awaitOAuthCode(
      server,
      expectedState: state,
      cancelToken: cancelToken,
    );

    final Map<String, dynamic> tokenJson;
    if (clientSecret.isNotEmpty) {
      final tokenResp = await _client.post(
        Uri.https('auth.atlassian.com', '/oauth/token'),
        headers: {
          'content-type': 'application/json',
          'authorization':
              'Basic ${base64Encode(utf8.encode('$clientId:$clientSecret'))}',
        },
        body: jsonEncode({
          'grant_type': 'authorization_code',
          'client_id': clientId,
          'client_secret': clientSecret,
          'code': code,
          'redirect_uri': redirectUri.toString(),
        }),
      );
      if (tokenResp.statusCode < 200 || tokenResp.statusCode >= 300) {
        throw StateError(
          'OAuth token exchange falló (${tokenResp.statusCode}): ${tokenResp.body}',
        );
      }
      tokenJson = Map<String, dynamic>.from(jsonDecode(tokenResp.body) as Map);
    } else {
      tokenJson = await _exchangeJiraCodeViaFolioCloud(
        code: code,
        clientId: clientId,
        redirectUri: redirectUri,
      );
    }
    final accessToken = (tokenJson['access_token'] as String? ?? '').trim();
    final refreshToken = (tokenJson['refresh_token'] as String? ?? '').trim();
    final expiresIn = (tokenJson['expires_in'] as num?)?.toInt() ?? 0;
    if (accessToken.isEmpty) {
      throw StateError('OAuth completado, pero falta access_token.');
    }
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final expiresAtMs =
        expiresIn > 0 ? nowMs + (expiresIn * 1000) : (nowMs + 55 * 60 * 1000);

    // Discover accessible resources (cloudId + URLs).
    final resourcesResp = await _client.get(
      Uri.https('api.atlassian.com', '/oauth/token/accessible-resources'),
      headers: {'authorization': 'Bearer $accessToken'},
    );
    if (resourcesResp.statusCode < 200 || resourcesResp.statusCode >= 300) {
      throw StateError(
        'No se pudieron leer recursos accesibles (${resourcesResp.statusCode}): ${resourcesResp.body}',
      );
    }
    final resources = jsonDecode(resourcesResp.body);
    if (resources is! List || resources.isEmpty) {
      throw StateError('La cuenta no tiene recursos accesibles en Jira Cloud.');
    }
    final first = resources.first;
    if (first is! Map) {
      throw StateError('Respuesta inválida de recursos accesibles.');
    }
    final cloudId = (first['id'] as String? ?? '').trim();
    final siteUrl = (first['url'] as String? ?? '').trim();
    if (cloudId.isEmpty) {
      throw StateError('No se pudo resolver cloudId desde recursos accesibles.');
    }

    return JiraConnection(
      id: 'jira_cloud_${_uuid.v4()}',
      deployment: JiraDeployment.cloud,
      label: label.trim().isEmpty ? 'Jira Cloud' : label.trim(),
      cloudId: cloudId,
      siteUrl: siteUrl.isEmpty ? null : siteUrl,
      accessToken: accessToken,
      refreshToken: refreshToken.isEmpty ? null : refreshToken,
      expiresAtMs: expiresAtMs,
    );
  }

  JiraConnection connectServer({
    required String label,
    required String baseUrl,
    required String pat,
  }) {
    final normalizedBase = _normalizeBaseUrl(baseUrl);
    if (normalizedBase == null) {
      throw const FormatException('baseUrl inválida.');
    }
    final token = pat.trim();
    if (token.isEmpty) {
      throw const FormatException('El token/PAT es obligatorio.');
    }
    return JiraConnection(
      id: 'jira_server_${_uuid.v4()}',
      deployment: JiraDeployment.server,
      label: label.trim().isEmpty ? 'Jira Server' : label.trim(),
      baseUrl: normalizedBase.toString(),
      pat: token,
    );
  }

  static Uri? _normalizeBaseUrl(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return null;
    final uri = Uri.tryParse(t);
    if (uri == null) return null;
    if (uri.scheme != 'http' && uri.scheme != 'https') return null;
    if (uri.host.trim().isEmpty) return null;
    // Remove trailing slash.
    final normalizedPath = uri.path.endsWith('/')
        ? uri.path.substring(0, uri.path.length - 1)
        : uri.path;
    return uri.replace(path: normalizedPath, query: '', fragment: '');
  }

  Future<Map<String, dynamic>> _exchangeJiraCodeViaFolioCloud({
    required String code,
    required String clientId,
    required Uri redirectUri,
  }) async {
    if (Firebase.apps.isEmpty) {
      throw StateError(
        'Falta JIRA_OAUTH_CLIENT_SECRET en este equipo y Firebase no está inicializado. '
        'Opciones (en este orden de uso habitual): lib/config/folio_local_secrets.dart (copia desde .example), '
        '--dart-define al compilar, %APPDATA%\\Folio\\.env en escritorio Windows, '
        'o Cloud Functions con JIRA_OAUTH_CLIENT_SECRET (folioJiraExchangeOAuth).',
      );
    }
    final projectId = DefaultFirebaseOptions.currentPlatform.projectId;
    final uri = Uri.parse(
      'https://$kFolioCloudFunctionsRegion-$projectId.cloudfunctions.net/folioJiraExchangeOAuth',
    );
    AppLogger.info(
      'Jira OAuth token via Folio Cloud',
      tag: 'jira',
      context: {'uri': uri.toString()},
    );
    final resp = await _client.post(
      uri,
      headers: {'content-type': 'application/json; charset=utf-8'},
      body: jsonEncode({
        'code': code,
        'redirectUri': redirectUri.toString(),
        'clientId': clientId,
      }),
    );
    late final Map<String, dynamic> mapTry;
    try {
      final decoded = jsonDecode(resp.body);
      if (decoded is! Map) {
        throw StateError('bad shape');
      }
      mapTry = Map<String, dynamic>.from(decoded);
    } catch (_) {
      throw StateError(
        'Respuesta inválida del servidor Jira OAuth (${resp.statusCode}): ${resp.body}',
      );
    }
    if (resp.statusCode == 503 &&
        mapTry['error']?.toString() == 'jira_oauth_not_configured') {
      throw StateError(
        'El servidor Folio no tiene configurado JIRA_OAUTH_CLIENT_SECRET. '
        'Contacta al administrador o define el secret en lib/config/folio_local_secrets.dart '
        '(preferido); en escritorio Windows también en %APPDATA%\\Folio\\.env.',
      );
    }
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      final err =
          mapTry['error']?.toString() ?? mapTry['body']?.toString() ?? resp.body;
      throw StateError(
        'Intercambio OAuth Jira vía servidor falló (${resp.statusCode}): $err',
      );
    }
    return mapTry;
  }

  Future<String> _awaitOAuthCode(
    HttpServer server, {
    required String expectedState,
    JiraAuthCancelToken? cancelToken,
  }) async {
    final completer = Completer<String>();
    late StreamSubscription<HttpRequest> sub;
    sub = server.listen((request) async {
      try {
        if (request.uri.path != '/callback') {
          request.response.statusCode = HttpStatus.notFound;
          await request.response.close();
          return;
        }
        final state = (request.uri.queryParameters['state'] ?? '').trim();
        final code = (request.uri.queryParameters['code'] ?? '').trim();
        final err = (request.uri.queryParameters['error'] ?? '').trim();
        final desc =
            (request.uri.queryParameters['error_description'] ?? '').trim();
        if (state != expectedState) {
          request.response.statusCode = HttpStatus.badRequest;
          request.response.headers.contentType = ContentType.html;
          request.response.write('<h2>OAuth error</h2><p>Invalid state.</p>');
          await request.response.close();
          return;
        }
        if (err.isNotEmpty) {
          request.response.statusCode = HttpStatus.ok;
          request.response.headers.contentType = ContentType.html;
          request.response.write(
            '<h2>OAuth cancelado</h2><p>$err</p><p>$desc</p><p>Puedes cerrar esta pestaña.</p>',
          );
          await request.response.close();
          if (!completer.isCompleted) {
            completer.completeError(StateError('$err $desc'.trim()));
          }
          return;
        }
        if (code.isEmpty) {
          request.response.statusCode = HttpStatus.badRequest;
          request.response.headers.contentType = ContentType.html;
          request.response.write('<h2>OAuth error</h2><p>Missing code.</p>');
          await request.response.close();
          return;
        }
        request.response.statusCode = HttpStatus.ok;
        request.response.headers.contentType = ContentType.html;
        request.response.write(
          '<h2>Conectado</h2><p>Ya puedes volver a Folio. Puedes cerrar esta pestaña.</p>',
        );
        await request.response.close();
        if (!completer.isCompleted) completer.complete(code);
      } catch (e) {
        if (!completer.isCompleted) completer.completeError(e);
      } finally {
        // We only need one request.
        await sub.cancel();
        await server.close(force: true);
      }
    });

    Future<String> waitForCode() async {
      return completer.future.timeout(
        const Duration(minutes: 5),
        onTimeout: () async {
          await sub.cancel();
          await server.close(force: true);
          throw TimeoutException('Timeout esperando callback OAuth.');
        },
      );
    }

    if (cancelToken == null) return waitForCode();

    try {
      final result = await Future.any<Object>([
        waitForCode(),
        cancelToken.whenCancelled.then<Object>((_) => const JiraAuthCancelledException()),
      ]);
      if (result is JiraAuthCancelledException) throw result;
      return result as String;
    } finally {
      if (cancelToken.isCancelled) {
        // Si el usuario cancela, aseguramos que el servidor se cierre.
        try {
          await sub.cancel();
        } catch (_) {}
        try {
          await server.close(force: true);
        } catch (_) {}
      }
    }
  }

  static String _randomToken(int byteLength) {
    final r = Random.secure();
    final bytes = List<int>.generate(byteLength, (_) => r.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }
}

