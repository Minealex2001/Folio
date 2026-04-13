import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folio/services/integrations/integrations_bridge.dart';
import 'package:folio/services/integrations/integrations_markdown_codec.dart';

void main() {
  group('IntegrationsBridgeController auth without secret', () {
    late IntegrationsBridgeController bridge;

    setUp(() async {
      bridge = IntegrationsBridgeController(
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
      );
      await bridge.start();
    });

    tearDown(() async {
      await bridge.dispose();
    });

    test(
      'POST /session/start works without X-Folio-Integration-Secret',
      () async {
        final client = HttpClient();
        final req = await client.post(
          InternetAddress.loopbackIPv4.host,
          IntegrationsLaunchSession.fixedPort,
          '/session/start',
        );
        req.headers.set(IntegrationsBridgeController.headerAppId, 'app-a');
        req.headers.set(IntegrationsBridgeController.headerAppName, 'App A');
        req.headers.set(IntegrationsBridgeController.headerAppVersion, '1.0.0');
        req.headers.set(
          IntegrationsBridgeController.headerIntegrationVersion,
          IntegrationsBridgeController.supportedIntegrationVersion,
        );

        final resp = await req.close();
        final body = await utf8.decoder.bind(resp).join();
        client.close(force: true);

        expect(resp.statusCode, HttpStatus.ok);
        final decoded = jsonDecode(body) as Map<String, dynamic>;
        expect(decoded['ok'], true);
        expect((decoded['sessionId'] as String?)?.isNotEmpty, true);
        expect((decoded['nonce'] as String?)?.isNotEmpty, true);
      },
    );

    test('non-approved app is still blocked', () async {
      await bridge.dispose();
      bridge = IntegrationsBridgeController(
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
        onApproveClient: (_) async => false,
        onClientObserved: (_) async {},
        isClientApproved: (_) => false,
        appInfoProvider: () => const <String, Object?>{},
      );
      await bridge.start();

      final client = HttpClient();
      final req = await client.get(
        InternetAddress.loopbackIPv4.host,
        IntegrationsLaunchSession.fixedPort,
        '/health',
      );
      req.headers.set(IntegrationsBridgeController.headerAppId, 'blocked-app');
      req.headers.set(
        IntegrationsBridgeController.headerAppName,
        'Blocked App',
      );
      req.headers.set(IntegrationsBridgeController.headerAppVersion, '1.0.0');
      req.headers.set(
        IntegrationsBridgeController.headerIntegrationVersion,
        IntegrationsBridgeController.supportedIntegrationVersion,
      );

      final resp = await req.close();
      final body = await utf8.decoder.bind(resp).join();
      client.close(force: true);

      expect(resp.statusCode, HttpStatus.forbidden);
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      expect(decoded['error'], 'APP_NOT_APPROVED');
    });

    test('v1 allows plaintext payload for markdown import', () async {
      final client = HttpClient();
      final startReq = await client.post(
        InternetAddress.loopbackIPv4.host,
        IntegrationsLaunchSession.fixedPort,
        '/session/start',
      );
      startReq.headers.set(IntegrationsBridgeController.headerAppId, 'app-v1');
      startReq.headers.set(
        IntegrationsBridgeController.headerAppName,
        'App V1',
      );
      startReq.headers.set(
        IntegrationsBridgeController.headerAppVersion,
        '1.0.0',
      );
      startReq.headers.set(
        IntegrationsBridgeController.headerIntegrationVersion,
        IntegrationsBridgeController.legacyIntegrationVersion,
      );

      final startResp = await startReq.close();
      final startBody = await utf8.decoder.bind(startResp).join();
      expect(startResp.statusCode, HttpStatus.ok);
      final session = jsonDecode(startBody) as Map<String, dynamic>;
      final sessionId = session['sessionId'] as String;
      final nonce = session['nonce'] as String;

      final importReq = await client.post(
        InternetAddress.loopbackIPv4.host,
        IntegrationsLaunchSession.fixedPort,
        '/imports/markdown',
      );
      importReq.headers.set(HttpHeaders.authorizationHeader, 'Bearer $nonce');
      importReq.headers.set(IntegrationsBridgeController.headerAppId, 'app-v1');
      importReq.headers.set(
        IntegrationsBridgeController.headerAppName,
        'App V1',
      );
      importReq.headers.set(
        IntegrationsBridgeController.headerAppVersion,
        '1.0.0',
      );
      importReq.headers.set(
        IntegrationsBridgeController.headerIntegrationVersion,
        IntegrationsBridgeController.legacyIntegrationVersion,
      );
      importReq.headers.contentType = ContentType.json;
      importReq.write(
        jsonEncode({
          'sessionId': sessionId,
          'title': 'v1 import',
          'markdown': '# Hola',
          'importMode': 'newPage',
        }),
      );

      final importResp = await importReq.close();
      final importBody = await utf8.decoder.bind(importResp).join();
      client.close(force: true);

      expect(importResp.statusCode, HttpStatus.ok);
      final decoded = jsonDecode(importBody) as Map<String, dynamic>;
      expect(decoded['ok'], true);
    });

    test('v2 rejects plaintext payload for markdown import', () async {
      final client = HttpClient();
      final startReq = await client.post(
        InternetAddress.loopbackIPv4.host,
        IntegrationsLaunchSession.fixedPort,
        '/session/start',
      );
      startReq.headers.set(IntegrationsBridgeController.headerAppId, 'app-v2');
      startReq.headers.set(
        IntegrationsBridgeController.headerAppName,
        'App V2',
      );
      startReq.headers.set(
        IntegrationsBridgeController.headerAppVersion,
        '2.0.0',
      );
      startReq.headers.set(
        IntegrationsBridgeController.headerIntegrationVersion,
        IntegrationsBridgeController.supportedIntegrationVersion,
      );

      final startResp = await startReq.close();
      final startBody = await utf8.decoder.bind(startResp).join();
      expect(startResp.statusCode, HttpStatus.ok);
      final session = jsonDecode(startBody) as Map<String, dynamic>;
      final sessionId = session['sessionId'] as String;
      final nonce = session['nonce'] as String;

      final importReq = await client.post(
        InternetAddress.loopbackIPv4.host,
        IntegrationsLaunchSession.fixedPort,
        '/imports/markdown',
      );
      importReq.headers.set(HttpHeaders.authorizationHeader, 'Bearer $nonce');
      importReq.headers.set(IntegrationsBridgeController.headerAppId, 'app-v2');
      importReq.headers.set(
        IntegrationsBridgeController.headerAppName,
        'App V2',
      );
      importReq.headers.set(
        IntegrationsBridgeController.headerAppVersion,
        '2.0.0',
      );
      importReq.headers.set(
        IntegrationsBridgeController.headerIntegrationVersion,
        IntegrationsBridgeController.supportedIntegrationVersion,
      );
      importReq.headers.contentType = ContentType.json;
      importReq.write(
        jsonEncode({
          'sessionId': sessionId,
          'title': 'v2 plain import',
          'markdown': '# Hola',
          'importMode': 'newPage',
        }),
      );

      final importResp = await importReq.close();
      final importBody = await utf8.decoder.bind(importResp).join();
      client.close(force: true);

      expect(importResp.statusCode, HttpStatus.badRequest);
      final decoded = jsonDecode(importBody) as Map<String, dynamic>;
      expect(decoded['error'], 'ENCRYPTION_REQUIRED');
    });

    test('v2 accepts encrypted payload for markdown import', () async {
      final client = HttpClient();
      final startReq = await client.post(
        InternetAddress.loopbackIPv4.host,
        IntegrationsLaunchSession.fixedPort,
        '/session/start',
      );
      startReq.headers.set(
        IntegrationsBridgeController.headerAppId,
        'app-v2-encrypted',
      );
      startReq.headers.set(
        IntegrationsBridgeController.headerAppName,
        'App V2 Encrypted',
      );
      startReq.headers.set(
        IntegrationsBridgeController.headerAppVersion,
        '2.0.0',
      );
      startReq.headers.set(
        IntegrationsBridgeController.headerIntegrationVersion,
        IntegrationsBridgeController.supportedIntegrationVersion,
      );

      final startResp = await startReq.close();
      final startBody = await utf8.decoder.bind(startResp).join();
      expect(startResp.statusCode, HttpStatus.ok);
      final session = jsonDecode(startBody) as Map<String, dynamic>;
      final sessionId = session['sessionId'] as String;
      final nonce = session['nonce'] as String;

      final clearPayload = <String, Object?>{
        'title': 'v2 encrypted import',
        'markdown': '# Hola cifrado',
        'importMode': 'newPage',
      };
      final envelope = await _buildEncryptedEnvelope(
        sessionId: sessionId,
        nonce: nonce,
        clearPayload: clearPayload,
      );

      final importReq = await client.post(
        InternetAddress.loopbackIPv4.host,
        IntegrationsLaunchSession.fixedPort,
        '/imports/markdown',
      );
      importReq.headers.set(HttpHeaders.authorizationHeader, 'Bearer $nonce');
      importReq.headers.set(
        IntegrationsBridgeController.headerAppId,
        'app-v2-encrypted',
      );
      importReq.headers.set(
        IntegrationsBridgeController.headerAppName,
        'App V2 Encrypted',
      );
      importReq.headers.set(
        IntegrationsBridgeController.headerAppVersion,
        '2.0.0',
      );
      importReq.headers.set(
        IntegrationsBridgeController.headerIntegrationVersion,
        IntegrationsBridgeController.supportedIntegrationVersion,
      );
      importReq.headers.contentType = ContentType.json;
      importReq.write(jsonEncode(envelope));

      final importResp = await importReq.close();
      final importBody = await utf8.decoder.bind(importResp).join();
      client.close(force: true);

      expect(importResp.statusCode, HttpStatus.ok);
      final decoded = jsonDecode(importBody) as Map<String, dynamic>;
      expect(decoded['ok'], true);
    });
  });
}

Future<Map<String, Object?>> _buildEncryptedEnvelope({
  required String sessionId,
  required String nonce,
  required Map<String, Object?> clearPayload,
}) async {
  final clearText = jsonEncode(<String, Object?>{
    'sessionId': sessionId,
    ...clearPayload,
  });
  final keyMaterial = utf8.encode('folio-integrations-v2|$sessionId|$nonce');
  final digest = await Sha256().hash(keyMaterial);
  final key = SecretKey(digest.bytes);
  final iv = List<int>.generate(12, (index) => (index + 1) * 3);
  final box = await AesGcm.with256bits().encrypt(
    utf8.encode(clearText),
    secretKey: key,
    nonce: iv,
  );
  return <String, Object?>{
    'sessionId': sessionId,
    'encryptedPayload': {
      'alg': IntegrationsBridgeController.v2EncryptionAlgorithm,
      'iv': base64UrlEncode(box.nonce).replaceAll('=', ''),
      'tag': base64UrlEncode(box.mac.bytes).replaceAll('=', ''),
      'ciphertext': base64UrlEncode(box.cipherText).replaceAll('=', ''),
    },
  };
}
