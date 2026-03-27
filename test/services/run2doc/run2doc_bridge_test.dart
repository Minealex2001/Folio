import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:folio/services/run2doc/run2doc_bridge.dart';
import 'package:folio/services/run2doc/run2doc_markdown_codec.dart';

void main() {
  group('Run2DocBridgeController auth without secret', () {
    late Run2DocBridgeController bridge;

    setUp(() async {
      bridge = Run2DocBridgeController(
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
        onReplaceCustomEmojis: (_, __) async {},
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
          Run2DocLaunchSession.fixedPort,
          '/session/start',
        );
        req.headers.set(Run2DocBridgeController.headerAppId, 'app-a');
        req.headers.set(Run2DocBridgeController.headerAppName, 'App A');
        req.headers.set(Run2DocBridgeController.headerAppVersion, '1.0.0');
        req.headers.set(
          Run2DocBridgeController.headerIntegrationVersion,
          Run2DocBridgeController.supportedIntegrationVersion,
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
      bridge = Run2DocBridgeController(
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
        onReplaceCustomEmojis: (_, __) async {},
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
        Run2DocLaunchSession.fixedPort,
        '/health',
      );
      req.headers.set(Run2DocBridgeController.headerAppId, 'blocked-app');
      req.headers.set(Run2DocBridgeController.headerAppName, 'Blocked App');
      req.headers.set(Run2DocBridgeController.headerAppVersion, '1.0.0');
      req.headers.set(
        Run2DocBridgeController.headerIntegrationVersion,
        Run2DocBridgeController.supportedIntegrationVersion,
      );

      final resp = await req.close();
      final body = await utf8.decoder.bind(resp).join();
      client.close(force: true);

      expect(resp.statusCode, HttpStatus.forbidden);
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      expect(decoded['error'], 'APP_NOT_APPROVED');
    });
  });
}
