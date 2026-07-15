import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/errors/folio_exception.dart';

class IconifyCatalogException extends FolioException {
  const IconifyCatalogException(super.message);
}

class IconifyCuratedCollection {
  const IconifyCuratedCollection({required this.prefix});

  /// Vacío = todas las colecciones.
  final String prefix;
}

class IconifyIconItem {
  const IconifyIconItem({
    required this.fullName,
    required this.prefix,
    required this.name,
    this.collectionLabel,
  });

  final String fullName;
  final String prefix;
  final String name;
  final String? collectionLabel;

  String previewUrl(IconifyCatalogService service) =>
      service.svgUrl(prefix: prefix, name: name, preview: true);
}

class IconifySearchResult {
  const IconifySearchResult({
    required this.icons,
    required this.total,
    required this.start,
    required this.limit,
  });

  final List<IconifyIconItem> icons;
  final int total;
  final int start;
  final int limit;

  bool get hasMore => start + icons.length < total;
}

class IconifyCatalogService {
  IconifyCatalogService({http.Client? client})
    : _client = client ?? http.Client();

  static const String baseUrl = 'https://api.iconify.design';
  static const int defaultLimit = 32;
  static const int maxLimit = 64;

  static const List<IconifyCuratedCollection> curatedCollections =
      <IconifyCuratedCollection>[
        IconifyCuratedCollection(prefix: ''),
        IconifyCuratedCollection(prefix: 'lucide'),
        IconifyCuratedCollection(prefix: 'tabler'),
        IconifyCuratedCollection(prefix: 'mdi'),
        IconifyCuratedCollection(prefix: 'ph'),
        IconifyCuratedCollection(prefix: 'ri'),
        IconifyCuratedCollection(prefix: 'carbon'),
        IconifyCuratedCollection(prefix: 'iconoir'),
        IconifyCuratedCollection(prefix: 'fluent'),
        IconifyCuratedCollection(prefix: 'solar'),
      ];

  final http.Client _client;

  String svgUrl({
    required String prefix,
    required String name,
    bool preview = false,
  }) {
    final params = preview
        ? <String, String>{'height': '48', 'box': '1'}
        : <String, String>{'height': 'none', 'box': '1'};
    return Uri.parse('$baseUrl/$prefix/$name.svg')
        .replace(queryParameters: params)
        .toString();
  }

  Future<IconifySearchResult> searchIcons({
    required String query,
    String? prefix,
    int start = 0,
    int limit = defaultLimit,
  }) async {
    final term = query.trim();
    if (term.length < 2) {
      throw const IconifyCatalogException('QUERY_TOO_SHORT');
    }
    final safeLimit = limit.clamp(1, maxLimit);
    final params = <String, String>{
      'query': term,
      'limit': safeLimit.toString(),
      'start': start.clamp(0, 9999).toString(),
    };
    final trimmedPrefix = prefix?.trim() ?? '';
    if (trimmedPrefix.isNotEmpty) {
      params['prefix'] = trimmedPrefix;
    }
    final uri = Uri.parse('$baseUrl/search').replace(queryParameters: params);
    final response = await _get(uri);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw IconifyCatalogException('HTTP_${response.statusCode}');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw const IconifyCatalogException('INVALID_RESPONSE');
    }
    final rawIcons = decoded['icons'];
    if (rawIcons is! List) {
      throw const IconifyCatalogException('INVALID_RESPONSE');
    }
    final collectionsRaw = decoded['collections'];
    final collections = collectionsRaw is Map
        ? Map<String, dynamic>.from(collectionsRaw)
        : const <String, dynamic>{};
    final icons = <IconifyIconItem>[];
    for (final raw in rawIcons) {
      if (raw is! String) continue;
      final parts = raw.split(':');
      if (parts.length != 2) continue;
      final itemPrefix = parts[0].trim();
      final itemName = parts[1].trim();
      if (itemPrefix.isEmpty || itemName.isEmpty) continue;
      final collectionMeta = collections[itemPrefix];
      String? collectionLabel;
      if (collectionMeta is Map) {
        collectionLabel = (collectionMeta['name'] as String?)?.trim();
      }
      icons.add(
        IconifyIconItem(
          fullName: raw,
          prefix: itemPrefix,
          name: itemName,
          collectionLabel: collectionLabel,
        ),
      );
    }
    return IconifySearchResult(
      icons: icons,
      total: _readInt(decoded['total']) ?? icons.length,
      start: _readInt(decoded['start']) ?? start,
      limit: _readInt(decoded['limit']) ?? safeLimit,
    );
  }

  Future<List<int>> downloadSvg({
    required String prefix,
    required String name,
  }) async {
    final uri = Uri.parse(svgUrl(prefix: prefix, name: name));
    final response = await _get(uri);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw IconifyCatalogException('HTTP_${response.statusCode}');
    }
    final bytes = response.bodyBytes;
    if (bytes.isEmpty) {
      throw const IconifyCatalogException('EMPTY_SVG');
    }
    return bytes;
  }

  Future<http.Response> _get(Uri uri) async {
    try {
      return await _client
          .get(uri)
          .timeout(const Duration(seconds: 15));
    } on IconifyCatalogException {
      rethrow;
    } catch (_) {
      throw const IconifyCatalogException('OFFLINE');
    }
  }

  int? _readInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}
