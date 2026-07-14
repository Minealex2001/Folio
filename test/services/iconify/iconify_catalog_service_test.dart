import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:folio/services/iconify/iconify_catalog_service.dart';

void main() {
  group('IconifyCatalogService', () {
    test('parses search response', () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/search');
        expect(request.url.queryParameters['query'], 'home');
        expect(request.url.queryParameters['prefix'], 'lucide');
        return http.Response(
          jsonEncode({
            'icons': ['lucide:home', 'lucide:house'],
            'total': 12,
            'start': 0,
            'limit': 32,
            'collections': {
              'lucide': {'name': 'Lucide'},
            },
          }),
          200,
        );
      });
      final service = IconifyCatalogService(client: client);
      final result = await service.searchIcons(
        query: 'home',
        prefix: 'lucide',
      );
      expect(result.icons, hasLength(2));
      expect(result.icons.first.fullName, 'lucide:home');
      expect(result.icons.first.prefix, 'lucide');
      expect(result.icons.first.name, 'home');
      expect(result.icons.first.collectionLabel, 'Lucide');
      expect(result.total, 12);
      expect(result.hasMore, isTrue);
    });

    test('throws on offline search', () async {
      final client = MockClient((_) async {
        throw const SocketException('offline');
      });
      final service = IconifyCatalogService(client: client);
      expect(
        () => service.searchIcons(query: 'home'),
        throwsA(
          isA<IconifyCatalogException>().having(
            (e) => e.message,
            'message',
            'OFFLINE',
          ),
        ),
      );
    });

    test('downloadSvg returns bytes', () async {
      const svg = '<svg xmlns="http://www.w3.org/2000/svg"></svg>';
      final client = MockClient((request) async {
        expect(request.url.path, '/lucide/home.svg');
        return http.Response(svg, 200);
      });
      final service = IconifyCatalogService(client: client);
      final bytes = await service.downloadSvg(prefix: 'lucide', name: 'home');
      expect(utf8.decode(bytes), svg);
    });

    test('svgUrl uses preview and download params', () {
      final service = IconifyCatalogService();
      expect(
        service.svgUrl(prefix: 'lucide', name: 'home', preview: true),
        'https://api.iconify.design/lucide/home.svg?height=48&box=1',
      );
      expect(
        service.svgUrl(prefix: 'lucide', name: 'home'),
        'https://api.iconify.design/lucide/home.svg?height=none&box=1',
      );
    });
  });
}
