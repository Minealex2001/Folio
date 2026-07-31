import 'dart:convert';
import 'dart:io';
import 'dart:math';

import '../ai/ai_tool.dart';
import '../ai/folio_tool_registry.dart';
import 'folio_mcp_tool_bridge.dart';

/// Error de protocolo JSON-RPC 2.0 (código + mensaje, ver spec MCP/JSON-RPC).
class McpError implements Exception {
  const McpError(this.code, this.message);
  final int code;
  final String message;

  @override
  String toString() => 'McpError($code, $message)';
}

/// Identidad del cliente MCP conectado, extraída de `clientInfo` en la
/// petición `initialize`. `appId` se usa como clave en el mismo sistema de
/// aprobaciones que ya usan los bridges de Integraciones/Run2Doc
/// (`AppSettings.approveIntegrationApp`), con el prefijo `mcp:` para que se
/// distinga en la lista de "Integraciones" de Ajustes.
class McpClientIdentity {
  const McpClientIdentity({
    required this.appId,
    required this.appName,
    required this.appVersion,
  });

  final String appId;
  final String appName;
  final String appVersion;
}

/// Servidor MCP local de Folio: expone el catálogo de `FolioToolRegistry` a
/// clientes MCP externos (Cursor, Claude Desktop, Claude Code…).
///
/// Transporte: Streamable HTTP simplificado sobre loopback — POST JSON-RPC con
/// respuesta `application/json`, GET/DELETE → 405 (sin SSE), cabecera
/// `Mcp-Session-Id` tras `initialize`. Compatible con el cliente HTTP de Cursor.
///
/// Seguridad: solo `127.0.0.1`, Bearer token, validación de `Origin` y
/// aprobación explícita por cliente antes de ejecutar tools.
class FolioMcpServer {
  FolioMcpServer(
    this._registry, {
    required Future<bool> Function(McpClientIdentity client) onApproveClient,
    required bool Function(McpClientIdentity client) isClientApproved,
    required Future<void> Function(McpClientIdentity client) onClientObserved,
  }) : _onApproveClient = onApproveClient,
       _isClientApproved = isClientApproved,
       _onClientObserved = onClientObserved;

  final FolioToolRegistry _registry;
  final Future<bool> Function(McpClientIdentity client) _onApproveClient;
  final bool Function(McpClientIdentity client) _isClientApproved;
  final Future<void> Function(McpClientIdentity client) _onClientObserved;
  HttpServer? _server;
  String? _authToken;
  final Map<String, McpClientIdentity> _sessions = {};

  /// Puerto fijo del servidor MCP local.
  /// Distinto de Integraciones (45831) y Run2Doc (45832) para que los tres
  /// puedan convivir. Así el `mcp.json` de Cursor no cambia en cada arranque.
  static const int defaultPort = 45833;

  /// Path canónico del endpoint MCP (también se acepta `/`).
  static const String endpointPath = '/mcp';

  static const protocolVersion = '2025-03-26';

  /// Versión de capacidades Folio expuestas por MCP (independiente del
  /// `protocolVersion` del wire protocol). Al subirla, las aprobaciones
  /// guardadas con una versión anterior dejan de valer y el usuario debe
  /// volver a autorizar el cliente (p. ej. al añadir lectura de páginas).
  static const capabilitiesVersion = '2';

  static const supportedProtocolVersions = {
    '2024-11-05',
    '2025-03-26',
    '2025-06-18',
    '2025-11-25',
  };

  static const _sessionHeader = 'mcp-session-id';

  bool get isRunning => _server != null;
  int? get port => _server?.port;
  String? get authToken => _authToken;
  McpClientIdentity? get connectedClient =>
      _sessions.isEmpty ? null : _sessions.values.last;

  /// URL lista para pegar en `mcp.json` (`url`).
  static String endpointUrl({int port = defaultPort}) =>
      'http://127.0.0.1:$port$endpointPath';

  /// Fragmento JSON listo para pegar en `~/.cursor/mcp.json`
  /// (Streamable HTTP nativo: `url` + `headers`).
  static String cursorClientConfigJson({
    required String endpoint,
    required String authToken,
  }) {
    final encodedUrl = jsonEncode(endpoint);
    final encodedAuth = jsonEncode('Bearer $authToken');
    return '''
{
  "mcpServers": {
    "folio": {
      "url": $encodedUrl,
      "headers": {
        "Authorization": $encodedAuth
      }
    }
  }
}'''.trim();
  }

  /// Fragmento JSON para Claude Desktop (`claude_desktop_config.json`).
  ///
  /// Claude Desktop no acepta `url` HTTP/HTTPS en ese archivo (solo stdio) y
  /// rechaza HTTP plano sin puente. Usamos `npx mcp-remote` con `--allow-http`
  /// y el Bearer en `env` (mismo patrón que otros MCP locales HTTP).
  static String claudeDesktopClientConfigJson({
    required String endpoint,
    required String authToken,
  }) {
    final encodedEndpoint = jsonEncode(endpoint);
    final encodedAuth = jsonEncode('Bearer $authToken');
    return '''
{
  "mcpServers": {
    "folio": {
      "command": "npx",
      "args": [
        "-y",
        "mcp-remote@latest",
        $encodedEndpoint,
        "--allow-http",
        "--header",
        "Authorization:\${AUTH_HEADER}"
      ],
      "env": {
        "AUTH_HEADER": $encodedAuth
      }
    }
  }
  }'''.trim();
  }

  /// Arranca en loopback con [port] fijo (por defecto [defaultPort]).
  /// Si se pasa [authToken], se reutiliza (token persistido); si no, se genera.
  ///
  /// Uso standalone (tests, o antes de la unificación con el bridge de
  /// Integraciones): bindea su propio [HttpServer]. En producción, en
  /// cambio, [prepareToken] es lo que se usa -- el bridge de Integraciones
  /// (puerto 45831) enruta `/mcp` a [handleRequest] directamente, sin que
  /// este servidor bindee su propio puerto.
  Future<int> start({int port = defaultPort, String? authToken}) async {
    final existing = _server;
    if (existing != null) return existing.port;

    if (!(Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
      throw StateError(
        'El servidor MCP de Folio solo está disponible en Windows/Mac/Linux.',
      );
    }

    prepareToken(authToken: authToken);
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
    _server = server;
    server.listen(handleRequest, onError: (_) {});
    return server.port;
  }

  /// Genera/fija el token de autenticación sin bindear un [HttpServer]
  /// propio -- para cuando otro servidor (el bridge de Integraciones) va a
  /// enrutar peticiones `/mcp` a [handleRequest] por su cuenta.
  void prepareToken({String? authToken}) {
    _authToken = (authToken != null && authToken.trim().isNotEmpty)
        ? authToken.trim()
        : _generateToken();
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    _authToken = null;
    _sessions.clear();
  }

  String _generateToken() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(24, (_) => rnd.nextInt(256));
    return base64Url.encode(bytes);
  }

  /// Maneja una petición HTTP completa (CORS/OPTIONS, método, auth Bearer,
  /// parseo JSON-RPC, dispatch, respuesta) -- público para que el bridge de
  /// Integraciones pueda enrutarle peticiones `/mcp` sin que este servidor
  /// posea su propio [HttpServer].
  Future<void> handleRequest(HttpRequest request) async {
    final response = request.response;
    try {
      if (!_isOriginAllowed(request.headers.value('origin'))) {
        response.statusCode = HttpStatus.forbidden;
        response.headers.contentType = ContentType.json;
        response.write(
          jsonEncode(_errorEnvelope(null, -32001, 'Origin no permitido')),
        );
        await response.close();
        return;
      }

      final method = request.method.toUpperCase();
      if (method == 'OPTIONS') {
        _setCorsHeaders(response, request);
        response.statusCode = HttpStatus.noContent;
        await response.close();
        return;
      }

      if (method == 'GET' || method == 'DELETE') {
        // Streamable HTTP: sin SSE ni cierre de sesión por DELETE.
        response.statusCode = HttpStatus.methodNotAllowed;
        response.headers.set(HttpHeaders.allowHeader, 'POST, OPTIONS');
        await response.close();
        return;
      }

      if (method != 'POST') {
        response.statusCode = HttpStatus.methodNotAllowed;
        response.headers.set(HttpHeaders.allowHeader, 'POST, OPTIONS');
        await response.close();
        return;
      }

      _setCorsHeaders(response, request);

      final expectedToken = _authToken;
      final authHeader = request.headers.value(HttpHeaders.authorizationHeader);
      if (expectedToken != null && authHeader != 'Bearer $expectedToken') {
        response.statusCode = HttpStatus.unauthorized;
        response.headers.contentType = ContentType.json;
        response.write(
          jsonEncode(_errorEnvelope(null, -32001, 'Unauthorized')),
        );
        await response.close();
        return;
      }

      final rawBody = await utf8.decoder.bind(request).join();
      if (rawBody.trim().isEmpty) {
        response.statusCode = HttpStatus.badRequest;
        response.headers.contentType = ContentType.json;
        response.write(
          jsonEncode(_errorEnvelope(null, -32700, 'Parse error')),
        );
        await response.close();
        return;
      }

      final decoded = jsonDecode(rawBody);
      if (decoded is List) {
        // Batch: procesamos secuencialmente y devolvemos array de respuestas
        // (sin entradas para notificaciones).
        final results = <Map<String, dynamic>>[];
        String? sessionId = request.headers.value(_sessionHeader);
        for (final item in decoded) {
          if (item is! Map) continue;
          final rpc = Map<String, dynamic>.from(item);
          final handled = await _handleRpcObject(
            rpc,
            incomingSessionId: sessionId,
          );
          if (handled.sessionId != null) sessionId = handled.sessionId;
          if (handled.body != null) results.add(handled.body!);
          if (handled.sessionId != null) {
            response.headers.set(_sessionHeader, handled.sessionId!);
          }
        }
        response.statusCode =
            results.isEmpty ? HttpStatus.accepted : HttpStatus.ok;
        if (results.isNotEmpty) {
          response.headers.contentType = ContentType.json;
          response.write(jsonEncode(results));
        }
        await response.close();
        return;
      }

      if (decoded is! Map) {
        response.statusCode = HttpStatus.badRequest;
        response.headers.contentType = ContentType.json;
        response.write(
          jsonEncode(_errorEnvelope(null, -32700, 'Parse error')),
        );
        await response.close();
        return;
      }

      final rpc = Map<String, dynamic>.from(decoded);
      final handled = await _handleRpcObject(
        rpc,
        incomingSessionId: request.headers.value(_sessionHeader),
      );
      if (handled.sessionId != null) {
        response.headers.set(_sessionHeader, handled.sessionId!);
      }
      if (handled.body == null) {
        response.statusCode = HttpStatus.accepted;
        await response.close();
        return;
      }
      response.statusCode = HttpStatus.ok;
      response.headers.contentType = ContentType.json;
      response.write(jsonEncode(handled.body));
      await response.close();
    } catch (e) {
      if (!response.headers.chunkedTransferEncoding &&
          response.contentLength == -1) {
        try {
          response.statusCode = HttpStatus.internalServerError;
          response.headers.contentType = ContentType.json;
          response.write(
            jsonEncode(
              _errorEnvelope(null, -32603, 'Internal error: $e'),
            ),
          );
        } catch (_) {}
      }
      try {
        await response.close();
      } catch (_) {}
    }
  }

  void _setCorsHeaders(HttpResponse response, HttpRequest request) {
    final origin = request.headers.value('origin');
    if (origin != null && _isOriginAllowed(origin)) {
      response.headers.set('Access-Control-Allow-Origin', origin);
      response.headers.set('Access-Control-Allow-Headers',
          'Authorization, Content-Type, Accept, Mcp-Session-Id, MCP-Protocol-Version');
      response.headers.set('Access-Control-Allow-Methods', 'POST, GET, DELETE, OPTIONS');
      response.headers.set('Access-Control-Expose-Headers', 'Mcp-Session-Id');
    }
  }

  /// Permite ausente (clientes desktop/Node), `null`, localhost y 127.0.0.1.
  bool _isOriginAllowed(String? origin) {
    if (origin == null || origin.isEmpty || origin == 'null') return true;
    final uri = Uri.tryParse(origin);
    if (uri == null) return false;
    final host = uri.host.toLowerCase();
    return host == 'localhost' || host == '127.0.0.1' || host == '::1';
  }

  Future<_RpcHandleResult> _handleRpcObject(
    Map<String, dynamic> rpc, {
    String? incomingSessionId,
  }) async {
    final id = rpc['id'];
    final method = rpc['method'] as String?;
    final rawParams = rpc['params'];
    final params =
        rawParams is Map ? Map<String, dynamic>.from(rawParams) : <String, dynamic>{};

    // Notificaciones JSON-RPC (sin `id`): 202 sin cuerpo.
    if (id == null) {
      return const _RpcHandleResult(body: null);
    }

    try {
      final dispatched = await _dispatch(
        method,
        params,
        incomingSessionId: incomingSessionId,
      );
      return _RpcHandleResult(
        body: {'jsonrpc': '2.0', 'id': id, 'result': dispatched.result},
        sessionId: dispatched.sessionId,
      );
    } on McpError catch (e) {
      return _RpcHandleResult(
        body: _errorEnvelope(id, e.code, e.message),
      );
    }
  }

  Future<_DispatchResult> _dispatch(
    String? method,
    Map<String, dynamic> params, {
    String? incomingSessionId,
  }) async {
    switch (method) {
      case 'initialize':
        return _handleInitialize(params);
      case 'ping':
        _requireSession(incomingSessionId);
        return const _DispatchResult(result: <String, dynamic>{});
      case 'tools/list':
        await _requireApprovedClient(incomingSessionId);
        return _DispatchResult(
          result: {
            'tools':
                _registry.definitions.map(aiToolDefinitionToMcpTool).toList(),
          },
        );
      case 'tools/call':
        await _requireApprovedClient(incomingSessionId);
        return _DispatchResult(result: await _handleToolsCall(params));
      default:
        throw McpError(-32601, 'Método desconocido: $method');
    }
  }

  Future<_DispatchResult> _handleInitialize(Map<String, dynamic> params) async {
    final clientInfo = params['clientInfo'];
    final rawName = clientInfo is Map ? clientInfo['name'] as String? : null;
    final rawVersion =
        clientInfo is Map ? clientInfo['version'] as String? : null;
    final name = (rawName ?? '').trim();
    final identity = McpClientIdentity(
      appId: 'mcp:${name.isEmpty ? 'unknown-client' : name}',
      appName: name.isEmpty ? 'Cliente MCP' : name,
      appVersion: (rawVersion ?? '').trim(),
    );

    if (_isClientApproved(identity)) {
      await _onClientObserved(identity);
    } else {
      final approved = await _onApproveClient(identity);
      if (!approved) {
        throw const McpError(-32001, 'El usuario no autorizó la conexión MCP.');
      }
    }

    final requested = params['protocolVersion'] as String?;
    final negotiated = (requested != null &&
            supportedProtocolVersions.contains(requested))
        ? requested
        : protocolVersion;

    // Un solo slot por cliente: re-initialize (Cursor/mcp-remote, diálogo de
    // re-aprobación, reintentos) no debe acumular sesiones huérfanas que
    // rompan tools/call cuando falta o caduca Mcp-Session-Id.
    _sessions.removeWhere((_, existing) => existing.appId == identity.appId);

    final sessionId = _generateToken();
    _sessions[sessionId] = identity;

    return _DispatchResult(
      result: {
        'protocolVersion': negotiated,
        'serverInfo': {'name': 'folio', 'version': '1.0.0'},
        'capabilities': {'tools': <String, dynamic>{}},
      },
      sessionId: sessionId,
    );
  }

  McpClientIdentity _requireSession(String? sessionId) {
    if (sessionId != null) {
      final existing = _sessions[sessionId];
      if (existing != null) return existing;
    }
    if (_sessions.isEmpty) {
      throw const McpError(-32002, 'Llama a "initialize" antes de usar tools.');
    }
    // Sin cabecera, o con sesión antigua tras un re-initialize: usar la más
    // reciente (el Map de Dart preserva orden de inserción).
    return _sessions.values.last;
  }

  Future<void> _requireApprovedClient(String? sessionId) async {
    final client = _requireSession(sessionId);
    if (!_isClientApproved(client)) {
      throw const McpError(-32001, 'Cliente MCP no autorizado.');
    }
  }

  Future<Map<String, dynamic>> _handleToolsCall(
    Map<String, dynamic> params,
  ) async {
    final name = params['name'] as String?;
    if (name == null || name.trim().isEmpty) {
      throw const McpError(-32602, 'Falta "name" en tools/call');
    }
    final rawArgs = params['arguments'];
    final args =
        rawArgs is Map ? Map<String, dynamic>.from(rawArgs) : <String, dynamic>{};
    final call = AiToolCall(
      id: 'mcp_${DateTime.now().microsecondsSinceEpoch}',
      name: name,
      arguments: args,
    );
    final result = await _registry.execute(call);
    return aiToolResultToMcpContent(result);
  }

  Map<String, dynamic> _errorEnvelope(dynamic id, int code, String message) => {
        'jsonrpc': '2.0',
        if (id != null) 'id': id,
        'error': {'code': code, 'message': message},
      };
}

class _RpcHandleResult {
  const _RpcHandleResult({this.body, this.sessionId});
  final Map<String, dynamic>? body;
  final String? sessionId;
}

class _DispatchResult {
  const _DispatchResult({required this.result, this.sessionId});
  final Map<String, dynamic> result;
  final String? sessionId;
}
