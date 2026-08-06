import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:folio/config/folio_backend_config.dart';
import 'package:folio/services/folio_cloud/folio_cloud_http_client.dart';

void main() {
  tearDown(FolioBackendConfig.debugResetHostFallback);

  group('FolioBackendConfig host fallback', () {
    test('maps api.folio.com.es → backendfolio', () {
      expect(
        FolioBackendConfig.fallbackBaseUrlFor('https://api.folio.com.es'),
        FolioBackendConfig.fallbackApiBaseUrl,
      );
      expect(
        FolioBackendConfig.fallbackBaseUrlForHost('api.folio.com.es'),
        'https://backendfolio.minealexgames.com',
      );
    });

    test('maps api-beta.folio.com.es → backendfoliobeta', () {
      expect(
        FolioBackendConfig.fallbackBaseUrlFor(
          'https://api-beta.folio.com.es/',
        ),
        FolioBackendConfig.fallbackApiBetaBaseUrl,
      );
      expect(
        FolioBackendConfig.fallbackBaseUrlForHost('api-beta.folio.com.es'),
        'https://backendfoliobeta.minealexgames.com',
      );
    });

    test('no fallback for Minealex / local / railway hosts', () {
      expect(
        FolioBackendConfig.fallbackBaseUrlFor(
          'https://backendfolio.minealexgames.com',
        ),
        isNull,
      );
      expect(
        FolioBackendConfig.fallbackBaseUrlFor('http://127.0.0.1:18080'),
        isNull,
      );
      expect(
        FolioBackendConfig.fallbackBaseUrlFor(
          'https://folio-prod.up.railway.app',
        ),
        isNull,
      );
    });

    test('sticky override switches apiBaseUrl and collabWsUrl', () {
      FolioBackendConfig.activateHostFallback(
        FolioBackendConfig.fallbackApiBetaBaseUrl,
      );
      expect(FolioBackendConfig.isUsingHostFallback, isTrue);
      expect(
        FolioBackendConfig.apiBaseUrl,
        'https://backendfoliobeta.minealexgames.com',
      );
      expect(
        FolioBackendConfig.collabWsUrl,
        'wss://backendfoliobeta.minealexgames.com/ws/collab',
      );
    });

    test('rewriteUriWithFallback preserves path and query', () {
      final uri = Uri.parse(
        'https://api.folio.com.es/api/v1/auth/login?x=1',
      );
      final rewritten = FolioBackendConfig.rewriteUriWithFallback(uri);
      expect(
        rewritten.toString(),
        'https://backendfolio.minealexgames.com/api/v1/auth/login?x=1',
      );
    });
  });

  group('FolioCloudHttpClient host fallback', () {
    test('retries on ClientException and sticks to fallback host', () async {
      var calls = 0;
      final inner = MockClient((request) async {
        calls++;
        if (request.url.host == 'api-beta.folio.com.es') {
          throw http.ClientException('Connection refused', request.url);
        }
        expect(request.url.host, 'backendfoliobeta.minealexgames.com');
        expect(request.url.path, '/api/v1/auth/login');
        return http.Response('{"ok":true}', 200);
      });

      final client = FolioCloudHttpClient(inner);
      final res = await client.get(
        Uri.parse('https://api-beta.folio.com.es/api/v1/auth/login'),
      );

      expect(res.statusCode, 200);
      expect(calls, 2);
      expect(FolioBackendConfig.isUsingHostFallback, isTrue);
      expect(
        FolioBackendConfig.apiBaseUrl,
        'https://backendfoliobeta.minealexgames.com',
      );
    });

    test('retries on probe timeout', () async {
      var calls = 0;
      final inner = MockClient((request) async {
        calls++;
        if (request.url.host == 'api.folio.com.es') {
          await Future<void>.delayed(const Duration(seconds: 30));
          return http.Response('late', 200);
        }
        return http.Response('{"ok":true}', 200);
      });

      final client = FolioCloudHttpClient(inner);
      final res = await client
          .get(Uri.parse('https://api.folio.com.es/api/v1/ping'))
          .timeout(const Duration(seconds: 20));

      expect(res.statusCode, 200);
      expect(calls, 2);
      expect(
        FolioBackendConfig.sessionBaseUrlOverride,
        'https://backendfolio.minealexgames.com',
      );
    });

    test('does not fallback when host has no mapping', () async {
      final inner = MockClient((request) async {
        throw http.ClientException('down', request.url);
      });
      final client = FolioCloudHttpClient(inner);
      expect(
        () => client.get(Uri.parse('http://127.0.0.1:18080/api/v1/ping')),
        throwsA(isA<http.ClientException>()),
      );
      expect(FolioBackendConfig.isUsingHostFallback, isFalse);
    });
  });
}
