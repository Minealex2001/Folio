import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../../core/errors/folio_exception.dart';
import '../app_logger.dart';
import '../oauth/oauth_deep_link_io.dart'
    if (dart.library.html) '../oauth/oauth_deep_link_stub.dart' as deeplink;
import '../oauth/oauth_launch.dart';

import '../../config/folio_backend_config.dart';

/// Sesión de Notion obtenida tras el OAuth. Deliberadamente NO persistida
/// (ni en el vault ni en disco): la importación directa de Notion es puntual
/// (one-shot), no una integración de sync continuo, así que no hace falta
/// guardar el access token para reconectar más tarde.
class NotionOAuthSession {
  const NotionOAuthSession({
    required this.accessToken,
    required this.workspaceName,
    this.workspaceIcon,
    this.botId,
  });

  final String accessToken;
  final String workspaceName;
  final String? workspaceIcon;
  final String? botId;
}

class NotionAuthCancelledException extends FolioException {
  const NotionAuthCancelledException() : super('OAuth cancelado por el usuario.');
}

class NotionAuthCancelToken {
  final Completer<void> _c = Completer<void>();
  bool get isCancelled => _c.isCompleted;
  Future<void> get whenCancelled => _c.future;
  void cancel() {
    if (!_c.isCompleted) _c.complete();
  }
}

class NotionAuthService {
  NotionAuthService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// Override temporal configurado por el usuario en Ajustes (desarrollo).
  static String overrideClientId = '';

  static const String oauthProvider = 'notion';

  /// Redirect URI registrado con Notion: DEBE ser https — Notion rechaza
  /// tanto direcciones IP (el loopback `http://127.0.0.1:<puerto>/callback`
  /// que usan Jira/Spotify en desktop) como esquemas custom como `folio://`
  /// directamente. Por eso aquí se registra una página del propio backend de
  /// Folio (`NotionOAuthController.oauthCallback`) que, al cargar, hace un
  /// segundo salto redirigiendo a `folio://oauth/notion/callback` — la app
  /// Windows ya registra ese protocolo a nivel de SO y reenvía el enlace a
  /// la instancia en ejecución (`windows/runner/main.cpp`,
  /// `RegisterFolioProtocol`/`ForwardProtocolLaunchArgument`), y
  /// `package:app_links` (ya usado para el flujo móvil) soporta desktop
  /// igual que Android/iOS. La app sigue esperando ese deep link como único
  /// punto de entrega del `code` (ver `codeFuture` abajo); el valor de este
  /// getter solo se usa para construir la URL de autorización de Notion.
  static Uri get redirectUri => Uri.parse('${FolioBackendConfig.apiV1Prefix}/integrations/notion/oauth-callback');

  /// Client ID de la Public Connection de Notion registrada para Folio.
  /// A diferencia de Jira, Notion no tiene un client id oficial por defecto
  /// embebido — hay que configurarlo (no es secreto, solo identifica la
  /// integración registrada en developers.notion.com).
  static String notionClientId() {
    final override = overrideClientId.trim();
    if (override.isNotEmpty) return override;
    const define = String.fromEnvironment('NOTION_OAUTH_CLIENT_ID');
    if (define.trim().isNotEmpty) return define.trim();
    return (Platform.environment['NOTION_OAUTH_CLIENT_ID'] ?? '').trim();
  }

  /// Inicia el flujo OAuth 2.0 de la Public Connection de Notion
  /// (developers.notion.com/guides/get-started/authorization) y devuelve una
  /// sesión con el access token y la info del workspace conectado.
  ///
  /// El intercambio code→token SIEMPRE pasa por el backend de Folio: Notion
  /// no soporta PKCE, así que el client_secret confidencial es imprescindible
  /// y nunca puede vivir en el binario de Flutter (a diferencia de Jira, que
  /// puede hacer el intercambio directo si el usuario configura su propio
  /// secret local).
  Future<NotionOAuthSession> connect({
    required String label,
    NotionAuthCancelToken? cancelToken,
  }) async {
    final clientId = notionClientId();
    if (clientId.isEmpty) {
      throw StateError(
        'Falta el Client ID de la Public Connection de Notion. '
        'Regístrala en developers.notion.com y configura NOTION_OAUTH_CLIENT_ID.',
      );
    }

    final state = _randomToken(16);

    final authUri = Uri.https('api.notion.com', '/v1/oauth/authorize', {
      'client_id': clientId,
      'redirect_uri': redirectUri.toString(),
      'response_type': 'code',
      // Cada página/base de datos compartida requiere elección manual del
      // usuario en la propia pantalla de autorización de Notion — Folio
      // nunca ve más que lo que el usuario decide compartir ahí.
      'owner': 'user',
      'state': state,
    });

    AppLogger.info(
      'Launching Notion OAuth',
      tag: 'notion',
      context: {'redirectUri': redirectUri.toString()},
    );

    final codeFuture = deeplink.awaitMobileOAuthCode(
      provider: oauthProvider,
      expectedState: state,
      whenCancelled: cancelToken?.whenCancelled,
    );

    final opened = await launchOAuthAuthorizeUrl(authUri);
    if (!opened) {
      cancelToken?.cancel();
      throw StateError(
        'No se pudo abrir el navegador para OAuth de Notion. '
        'Abre manualmente esta URL:\n$authUri',
      );
    }

    final code = await codeFuture;

    final tokenJson = await _exchangeCodeViaBackend(code: code, clientId: clientId);

    final accessToken = (tokenJson['access_token'] as String? ?? '').trim();
    if (accessToken.isEmpty) {
      throw StateError('OAuth completado, pero falta access_token.');
    }
    final workspaceName = (tokenJson['workspace_name'] as String? ?? '').trim();
    final workspaceIcon = (tokenJson['workspace_icon'] as String?)?.trim();
    final botId = (tokenJson['bot_id'] as String?)?.trim();

    return NotionOAuthSession(
      accessToken: accessToken,
      workspaceName: workspaceName.isEmpty ? (label.trim().isEmpty ? 'Notion' : label.trim()) : workspaceName,
      workspaceIcon: (workspaceIcon != null && workspaceIcon.isNotEmpty) ? workspaceIcon : null,
      botId: (botId != null && botId.isNotEmpty) ? botId : null,
    );
  }

  Future<Map<String, dynamic>> _exchangeCodeViaBackend({
    required String code,
    required String clientId,
  }) async {
    final uri = Uri.parse('${FolioBackendConfig.apiV1Prefix}/integrations/notion/oauth-exchange');
    AppLogger.info('Notion OAuth token via Folio backend', tag: 'notion', context: {'uri': uri.toString()});
    final resp = await _client
        .post(
          uri,
          headers: {'content-type': 'application/json; charset=utf-8'},
          body: jsonEncode({
            'code': code,
            'clientId': clientId,
          }),
        )
        .timeout(const Duration(seconds: 30));
    late final Map<String, dynamic> mapTry;
    try {
      final decoded = jsonDecode(resp.body);
      if (decoded is! Map) {
        throw StateError('bad shape');
      }
      mapTry = Map<String, dynamic>.from(decoded);
    } catch (_) {
      throw StateError('Respuesta inválida del servidor Notion OAuth (${resp.statusCode}): ${resp.body}');
    }
    if (resp.statusCode == 503 && mapTry['error']?.toString() == 'notion_oauth_not_configured') {
      throw StateError(
        'El servidor Folio no tiene configurado NOTION_OAUTH_CLIENT_SECRET. '
        'Contacta al administrador.',
      );
    }
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      final err = mapTry['error']?.toString() ?? mapTry['body']?.toString() ?? resp.body;
      throw StateError('Intercambio OAuth Notion vía servidor falló (${resp.statusCode}): $err');
    }
    return mapTry;
  }

  static String _randomToken(int byteLength) {
    final r = Random.secure();
    final bytes = List<int>.generate(byteLength, (_) => r.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }
}
