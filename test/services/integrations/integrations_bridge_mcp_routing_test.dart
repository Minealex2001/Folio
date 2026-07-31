import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:folio/services/ai/folio_tool_registry.dart';
import 'package:folio/services/integrations/integrations_bridge.dart';
import 'package:folio/services/integrations/integrations_markdown_codec.dart';
import 'package:folio/services/mcp/folio_mcp_server.dart';
import 'package:folio/session/vault_session.dart';

/// v0.8.0 workstream 3b: MCP is no longer a separate HttpServer on its own
/// port (45833) -- it's routed through the Integrations bridge (45831) via
/// IntegrationsBridgeController.setMcpServer(). These tests cover exactly
/// that unification, as the plan's "sequencing safeguard" step: verify the
/// new routing behavior directly, on top of the untouched standalone
/// FolioMcpServer protocol tests in folio_mcp_server_test.dart.
void main() {
  late IntegrationsBridgeController bridge;
  late int port;
  late VaultSession session;

  IntegrationsBridgeController buildBridge() => IntegrationsBridgeController(
    onImport: (_) async => const FolioMarkdownImportResult(
      pageId: 'p1',
      pageTitle: 'Imported',
      blockCount: 1,
      mode: FolioMarkdownImportMode.newPage,
    ),
    onUpdate: (_) async => const FolioMarkdownImportResult(
      pageId: 'p1',
      pageTitle: 'Updated',
      blockCount: 1,
      mode: FolioMarkdownImportMode.replaceCurrentPage,
    ),
    onListPages: (_) async => const <Map<String, Object?>>[],
    onListCustomEmojis: (_) async => const <Map<String, Object?>>[],
    onImportJson: (_) async => const FolioMarkdownImportResult(
      pageId: 'p1',
      pageTitle: 'Imported JSON',
      blockCount: 1,
      mode: FolioMarkdownImportMode.newPage,
    ),
    onReplaceCustomEmojis: (payload, replaceAll) async {},
    onUpsertCustomEmoji: (_) async => const <String, Object?>{},
    onDeleteCustomEmoji: (_) async {},
    onApproveClient: (_) async => true,
    onClientObserved: (_) async {},
    isClientApproved: (_) => true,
    appInfoProvider: () => const <String, Object?>{},
    port: 0,
  );

  Future<Map<String, dynamic>> postJsonRpc({
    required String method,
    Map<String, dynamic>? params,
    String? bearer,
    String path = '/mcp',
  }) async {
    final client = HttpClient();
    try {
      final req = await client.postUrl(
        Uri.parse('http://127.0.0.1:$port$path'),
      );
      req.headers.contentType = ContentType.json;
      if (bearer != null) {
        req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $bearer');
      }
      req.write(
        jsonEncode({
          'jsonrpc': '2.0',
          'id': 1,
          'method': method,
          if (params != null) 'params': params,
        }),
      );
      final res = await req.close();
      final body = await utf8.decodeStream(res);
      final out = <String, dynamic>{'_statusCode': res.statusCode};
      if (body.isNotEmpty) {
        out.addAll(jsonDecode(body) as Map<String, dynamic>);
      }
      return out;
    } finally {
      client.close(force: true);
    }
  }

  setUp(() async {
    session = VaultSession();
    session.debugMarkUnlockedForTests();
    bridge = buildBridge();
    await bridge.start();
    port = bridge.port;
  });

  tearDown(() async {
    await bridge.dispose();
  });

  test('GET /mcp returns 404 when no MCP server is wired (feature disabled)', () async {
    final client = HttpClient();
    try {
      final req = await client.getUrl(Uri.parse('http://127.0.0.1:$port/mcp'));
      final res = await req.close();
      expect(res.statusCode, HttpStatus.notFound);
      await res.drain<void>();
    } finally {
      client.close(force: true);
    }
  });

  test(
    'once setMcpServer is wired, /mcp serves the MCP JSON-RPC protocol on the Integrations bridge port',
    () async {
      final mcp = FolioMcpServer(
        FolioToolRegistry(session),
        onApproveClient: (_) async => true,
        isClientApproved: (_) => true,
        onClientObserved: (_) async {},
      );
      mcp.prepareToken(authToken: 'test-token');
      bridge.setMcpServer(mcp);

      final res = await postJsonRpc(
        method: 'initialize',
        params: {
          'protocolVersion': '2025-03-26',
          'clientInfo': {'name': 'Test Client', 'version': '1.0.0'},
          'capabilities': <String, dynamic>{},
        },
        bearer: 'test-token',
      );

      expect(res['_statusCode'], HttpStatus.ok);
      expect(res['result']['protocolVersion'], '2025-03-26');

      // prepareToken() never bound its own HttpServer -- the request above
      // was served entirely on the bridge's own port.
      expect(mcp.isRunning, isFalse);
      expect(mcp.port, isNull);
    },
  );

  test('/mcp rejects the wrong Bearer token independently of the bridge auth model', () async {
    final mcp = FolioMcpServer(
      FolioToolRegistry(session),
      onApproveClient: (_) async => true,
      isClientApproved: (_) => true,
      onClientObserved: (_) async {},
    );
    mcp.prepareToken(authToken: 'right-token');
    bridge.setMcpServer(mcp);

    final res = await postJsonRpc(method: 'tools/list', bearer: 'wrong-token');
    expect(res['_statusCode'], HttpStatus.unauthorized);
  });

  test('unwiring the MCP server (setMcpServer(null)) makes /mcp 404 again', () async {
    final mcp = FolioMcpServer(
      FolioToolRegistry(session),
      onApproveClient: (_) async => true,
      isClientApproved: (_) => true,
      onClientObserved: (_) async {},
    );
    mcp.prepareToken(authToken: 'test-token');
    bridge.setMcpServer(mcp);

    final before = await postJsonRpc(method: 'ping', bearer: 'test-token');
    expect(before['_statusCode'], isNot(HttpStatus.notFound));

    bridge.setMcpServer(null);

    final client = HttpClient();
    try {
      final req = await client.getUrl(Uri.parse('http://127.0.0.1:$port/mcp'));
      final res = await req.close();
      expect(res.statusCode, HttpStatus.notFound);
      await res.drain<void>();
    } finally {
      client.close(force: true);
    }
  });

  test('wiring an MCP server does not affect the Integrations REST routes', () async {
    final mcp = FolioMcpServer(
      FolioToolRegistry(session),
      onApproveClient: (_) async => true,
      isClientApproved: (_) => true,
      onClientObserved: (_) async {},
    );
    mcp.prepareToken(authToken: 'test-token');
    bridge.setMcpServer(mcp);

    final client = HttpClient();
    try {
      final req = await client.getUrl(Uri.parse('http://127.0.0.1:$port/health'));
      req.headers.set(
        IntegrationsBridgeController.headerAppId,
        'app-a',
      );
      req.headers.set(IntegrationsBridgeController.headerAppName, 'App A');
      req.headers.set(IntegrationsBridgeController.headerAppVersion, '1.0.0');
      req.headers.set(
        IntegrationsBridgeController.headerIntegrationVersion,
        IntegrationsBridgeController.supportedIntegrationVersion,
      );
      final res = await req.close();
      final body = await utf8.decodeStream(res);
      expect(res.statusCode, HttpStatus.ok);
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      expect(decoded['ok'], true);
    } finally {
      client.close(force: true);
    }
  });
}
