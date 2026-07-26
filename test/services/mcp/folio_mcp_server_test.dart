import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:folio/services/ai/folio_tool_registry.dart';
import 'package:folio/services/mcp/folio_mcp_server.dart';
import 'package:folio/session/vault_session.dart';

Future<Map<String, dynamic>> _rpc(
  FolioMcpServer server, {
  required String method,
  Map<String, dynamic>? params,
  Object? id = 1,
  String? bearerOverride,
  String? sessionId,
  String path = FolioMcpServer.endpointPath,
}) async {
  final client = HttpClient();
  try {
    final req = await client.postUrl(
      Uri.parse('http://127.0.0.1:${server.port}$path'),
    );
    req.headers.contentType = ContentType.json;
    req.headers.set(HttpHeaders.acceptHeader, 'application/json, text/event-stream');
    req.headers.set(
      HttpHeaders.authorizationHeader,
      'Bearer ${bearerOverride ?? server.authToken}',
    );
    if (sessionId != null) {
      req.headers.set('mcp-session-id', sessionId);
    }
    req.write(
      jsonEncode({
        'jsonrpc': '2.0',
        if (id != null) 'id': id,
        'method': method,
        if (params != null) 'params': params,
      }),
    );
    final res = await req.close();
    final body = await utf8.decodeStream(res);
    final out = <String, dynamic>{
      '_statusCode': res.statusCode,
      '_sessionId': res.headers.value('mcp-session-id'),
    };
    if (body.isEmpty) return out;
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      out.addAll(decoded);
    } else {
      out['_raw'] = decoded;
    }
    return out;
  } finally {
    client.close(force: true);
  }
}

/// Harness de aprobación en memoria, imitando el sistema real
/// `AppSettings.approveIntegrationApp`/`isIntegrationAppApproved` sin
/// depender de SharedPreferences en el test.
class _FakeApprovalStore {
  _FakeApprovalStore({this.autoApprove = true});

  /// Si es `false`, simula que el usuario cierra/rechaza el diálogo.
  bool autoApprove;
  final Set<String> _approved = {};
  final List<McpClientIdentity> approvalPrompts = [];
  final List<McpClientIdentity> observed = [];

  Future<bool> onApproveClient(McpClientIdentity client) async {
    approvalPrompts.add(client);
    if (!autoApprove) return false;
    _approved.add(client.appId);
    return true;
  }

  bool isClientApproved(McpClientIdentity client) => _approved.contains(client.appId);

  Future<void> onClientObserved(McpClientIdentity client) async {
    observed.add(client);
  }
}

void main() {
  late VaultSession session;
  late _FakeApprovalStore approvals;
  late FolioMcpServer server;
  String? lastSessionId;

  setUp(() async {
    session = VaultSession();
    session.debugMarkUnlockedForTests();
    approvals = _FakeApprovalStore();
    server = FolioMcpServer(
      FolioToolRegistry(session),
      onApproveClient: approvals.onApproveClient,
      isClientApproved: approvals.isClientApproved,
      onClientObserved: approvals.onClientObserved,
    );
    // Puerto 0 en tests para evitar choques con Folio en ejecución.
    await server.start(port: 0, authToken: 'test-token-fixed');
    lastSessionId = null;
  });

  tearDown(() async {
    await server.stop();
  });

  Future<void> initializeAsClient({
    String name = 'Claude Desktop',
    String version = '1.0.0',
  }) async {
    final res = await _rpc(
      server,
      method: 'initialize',
      params: {
        'protocolVersion': '2025-03-26',
        'clientInfo': {'name': name, 'version': version},
        'capabilities': <String, dynamic>{},
      },
    );
    expect(res['_statusCode'], 200, reason: 'initialize debe completarse: $res');
    lastSessionId = res['_sessionId'] as String?;
    expect(lastSessionId, isNotNull);
  }

  test('start() bindea a loopback con token fijo y puerto asignado', () {
    expect(server.isRunning, isTrue);
    expect(server.port, greaterThan(0));
    expect(server.authToken, 'test-token-fixed');
  });

  test('defaultPort es estático (45833) y endpointUrl apunta a /mcp', () {
    expect(FolioMcpServer.defaultPort, 45833);
    expect(
      FolioMcpServer.endpointUrl(),
      'http://127.0.0.1:45833/mcp',
    );
  });

  test('cursorClientConfigJson incluye url y Bearer listos para mcp.json', () {
    final json = FolioMcpServer.cursorClientConfigJson(
      endpoint: 'http://127.0.0.1:45833/mcp',
      authToken: 'tok"en',
    );
    final decoded = jsonDecode(json) as Map<String, dynamic>;
    final folio = decoded['mcpServers']['folio'] as Map<String, dynamic>;
    expect(folio['url'], 'http://127.0.0.1:45833/mcp');
    expect(folio['headers']['Authorization'], 'Bearer tok"en');
  });

  test('claudeDesktopClientConfigJson usa mcp-remote con --allow-http', () {
    final json = FolioMcpServer.claudeDesktopClientConfigJson(
      endpoint: 'http://127.0.0.1:45833/mcp',
      authToken: 'secret',
    );
    final decoded = jsonDecode(json) as Map<String, dynamic>;
    final folio = decoded['mcpServers']['folio'] as Map<String, dynamic>;
    expect(folio['command'], 'npx');
    final args = (folio['args'] as List).cast<String>();
    expect(args, contains('mcp-remote@latest'));
    expect(args, contains('--allow-http'));
    expect(args, contains('http://127.0.0.1:45833/mcp'));
    expect(args, contains(r'Authorization:${AUTH_HEADER}'));
    expect(folio['env']['AUTH_HEADER'], 'Bearer secret');
  });

  test('GET al endpoint responde 405 (sin SSE)', () async {
    final client = HttpClient();
    try {
      final req = await client.getUrl(
        Uri.parse('http://127.0.0.1:${server.port}/mcp'),
      );
      req.headers.set(HttpHeaders.acceptHeader, 'text/event-stream');
      final res = await req.close();
      expect(res.statusCode, 405);
      await res.drain<void>();
    } finally {
      client.close(force: true);
    }
  });

  group('aprobación de cliente (primer uso)', () {
    test('initialize pide aprobación y la registra en el mismo sistema que Integraciones', () async {
      await initializeAsClient(name: 'Claude Desktop', version: '2.1.0');

      expect(approvals.approvalPrompts, hasLength(1));
      final client = approvals.approvalPrompts.single;
      expect(client.appId, 'mcp:Claude Desktop');
      expect(client.appName, 'Claude Desktop');
      expect(client.appVersion, '2.1.0');
      expect(approvals.isClientApproved(client), isTrue);
    });

    test('si el usuario rechaza el diálogo, initialize falla y no se aprueba', () async {
      approvals.autoApprove = false;
      final res = await _rpc(
        server,
        method: 'initialize',
        params: {
          'clientInfo': {'name': 'Cliente Sospechoso', 'version': '0.1'},
        },
      );

      expect(res['error']['code'], -32001);
      expect(
        approvals.isClientApproved(
          const McpClientIdentity(
            appId: 'mcp:Cliente Sospechoso',
            appName: '',
            appVersion: '',
          ),
        ),
        isFalse,
      );
    });

    test('tools/list y tools/call fallan si no se ha llamado a initialize antes', () async {
      final res = await _rpc(server, method: 'tools/list');
      expect(res['error']['code'], -32002);
    });

    test('una vez aprobado, un segundo initialize no vuelve a mostrar el diálogo', () async {
      await initializeAsClient();
      await initializeAsClient();

      expect(approvals.approvalPrompts, hasLength(1));
      expect(approvals.observed, hasLength(1));
    });

    test('tras re-initialize, tools/call funciona sin Mcp-Session-Id', () async {
      await initializeAsClient(name: 'Cursor');
      final staleSessionId = lastSessionId;
      await initializeAsClient(name: 'Cursor');
      // Simula cliente que reutiliza sesión antigua o no manda cabecera.
      final withStale = await _rpc(
        server,
        method: 'tools/list',
        sessionId: staleSessionId,
      );
      expect(withStale['error'], isNull, reason: '$withStale');
      expect(withStale['result']['tools'], isA<List>());

      final withoutHeader = await _rpc(server, method: 'tools/list');
      expect(withoutHeader['error'], isNull, reason: '$withoutHeader');
      expect(withoutHeader['result']['tools'], isA<List>());
    });

    test('sin clientInfo, se usa una identidad genérica "unknown-client"', () async {
      final res = await _rpc(server, method: 'initialize');
      expect(res['_statusCode'], 200);
      expect(approvals.approvalPrompts.single.appId, 'mcp:unknown-client');
    });
  });

  test('initialize devuelve protocolVersion negociado y capabilities.tools', () async {
    final res = await _rpc(
      server,
      method: 'initialize',
      params: {
        'protocolVersion': '2025-03-26',
        'capabilities': <String, dynamic>{},
        'clientInfo': {'name': 'cursor', 'version': '1'},
      },
    );
    expect(res['_statusCode'], 200);
    expect(res['result']['protocolVersion'], '2025-03-26');
    expect(res['result']['capabilities']['tools'], isA<Map>());
    expect(res['_sessionId'], isNotNull);
  });

  test('tools/list devuelve el catálogo de FolioToolRegistry en formato MCP', () async {
    await initializeAsClient();
    final res = await _rpc(
      server,
      method: 'tools/list',
      sessionId: lastSessionId,
    );
    final tools = (res['result']['tools'] as List).cast<Map<String, dynamic>>();

    expect(tools, isNotEmpty);
    final createPage = tools.firstWhere((t) => t['name'] == 'create_page');
    expect(createPage['description'], isA<String>());
    expect(createPage['inputSchema']['type'], 'object');
    expect(createPage['inputSchema']['properties'], contains('title'));
    // Formato MCP: sin el envoltorio {type: function, function: {...}} de OpenAI.
    expect(createPage.containsKey('function'), isFalse);
  });

  test('tools/call ejecuta create_page y muta el vault', () async {
    await initializeAsClient();
    final res = await _rpc(
      server,
      method: 'tools/call',
      sessionId: lastSessionId,
      params: {
        'name': 'create_page',
        'arguments': {
          'title': 'Página MCP',
          'blocks': [
            {'type': 'paragraph', 'text': 'Hola desde MCP'},
          ],
        },
      },
    );

    expect(res['_statusCode'], 200);
    final result = res['result'] as Map<String, dynamic>;
    expect(result['isError'], isFalse);
    final text = (result['content'] as List).first['text'] as String;
    expect(text, contains('Página MCP'));
    expect(session.pages, hasLength(1));
    expect(session.pages.single.title, 'Página MCP');
  });

  test(
    'tools/call empty_trash sin onConfirmIrreversibleTool no pide confirmación',
    () async {
      await initializeAsClient();
      session.addPage(parentId: null);
      session.addPage(parentId: null);
      final trashId = session.pages.last.id;
      session.movePageToTrash(trashId);

      final res = await _rpc(
        server,
        method: 'tools/call',
        sessionId: lastSessionId,
        params: {
          'name': 'empty_trash',
          'arguments': <String, dynamic>{},
        },
      );

      expect(res['_statusCode'], 200);
      final result = res['result'] as Map<String, dynamic>;
      expect(result['isError'], isNot(true));
      expect(session.pages.any((p) => p.id == trashId), isFalse);
    },
  );

  test('tools/call devuelve isError:true para una tool que falla', () async {
    await initializeAsClient();
    final res = await _rpc(
      server,
      method: 'tools/call',
      sessionId: lastSessionId,
      params: {
        'name': 'rename_page',
        'arguments': {'pageId': 'no-existe', 'title': 'X'},
      },
    );

    final result = res['result'] as Map<String, dynamic>;
    expect(result['isError'], isTrue);
  });

  test('tools/call sin "name" devuelve un error JSON-RPC (-32602)', () async {
    await initializeAsClient();
    final res = await _rpc(
      server,
      method: 'tools/call',
      sessionId: lastSessionId,
      params: {'arguments': {}},
    );
    expect(res['error']['code'], -32602);
  });

  test('un método desconocido devuelve -32601', () async {
    final res = await _rpc(server, method: 'no/existe');
    expect(res['error']['code'], -32601);
  });

  test('una notificación (sin id) no devuelve cuerpo, solo 202', () async {
    final res = await _rpc(server, method: 'notifications/initialized', id: null);
    expect(res['_statusCode'], 202);
  });

  test('rechaza peticiones sin el token correcto con 401', () async {
    final res = await _rpc(server, method: 'tools/list', bearerOverride: 'token-incorrecto');
    expect(res['_statusCode'], 401);
    expect(res['error']['code'], -32001);
  });

  test('stop() detiene el servidor, libera el puerto y olvida las sesiones', () async {
    await initializeAsClient();
    expect(server.connectedClient, isNotNull);
    await server.stop();
    expect(server.isRunning, isFalse);
    expect(server.port, isNull);
    expect(server.connectedClient, isNull);

    final again = FolioMcpServer(
      FolioToolRegistry(session),
      onApproveClient: approvals.onApproveClient,
      isClientApproved: approvals.isClientApproved,
      onClientObserved: approvals.onClientObserved,
    );
    final newPort = await again.start(port: 0);
    expect(newPort, greaterThan(0));
    await again.stop();
  });
}
