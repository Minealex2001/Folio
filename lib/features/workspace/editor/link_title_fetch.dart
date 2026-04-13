import 'dart:convert';

import 'package:http/http.dart' as http;

import 'folio_youtube.dart';

/// Obtiene título aproximado (og:title o &lt;title&gt;). Respuesta acotada en tamaño.
Future<String?> fetchWebPageTitle(
  Uri uri, {
  Duration timeout = const Duration(seconds: 6),
}) async {
  try {
    final r = await http
        .get(
          uri,
          headers: const {'User-Agent': 'Folio/1.0 (link preview)'},
        )
        .timeout(timeout);
    if (r.statusCode < 200 || r.statusCode >= 400) return null;
    var body = r.body;
    if (body.length > 65536) {
      body = body.substring(0, 65536);
    }
    final og = RegExp(
      r'''property\s*=\s*["']og:title["'][^>]*content\s*=\s*["']([^"']+)["']''',
      caseSensitive: false,
    ).firstMatch(body);
    if (og != null) {
      final t = og.group(1)?.trim();
      if (t != null && t.isNotEmpty) return _stripEntities(t);
    }
    final og2 = RegExp(
      r'''content\s*=\s*["']([^"']+)["'][^>]*property\s*=\s*["']og:title["']''',
      caseSensitive: false,
    ).firstMatch(body);
    if (og2 != null) {
      final t = og2.group(1)?.trim();
      if (t != null && t.isNotEmpty) return _stripEntities(t);
    }
    final title = RegExp(
      r'<title[^>]*>([^<]{1,500})</title>',
      caseSensitive: false,
    ).firstMatch(body);
    if (title != null) {
      final t = title.group(1)?.trim();
      if (t != null && t.isNotEmpty) return _stripEntities(t);
    }
  } catch (_) {}
  return null;
}

String _stripEntities(String s) {
  return s
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .trim();
}

/// Título vía API oEmbed de YouTube (si la URL es de YouTube).
Future<String?> fetchYoutubeOEmbedTitle(
  String pageUrl, {
  Duration timeout = const Duration(seconds: 6),
}) async {
  if (folioYoutubeVideoIdFromUrl(pageUrl) == null) return null;
  try {
    final uri = Uri.https('www.youtube.com', '/oembed', {
      'url': pageUrl,
      'format': 'json',
    });
    final r = await http
        .get(
          uri,
          headers: const {'User-Agent': 'Folio/1.0 (link preview)'},
        )
        .timeout(timeout);
    if (r.statusCode < 200 || r.statusCode >= 400) return null;
    final j = jsonDecode(r.body);
    if (j is! Map<String, dynamic>) return null;
    final t = j['title'] as String?;
    if (t == null || t.trim().isEmpty) return null;
    return _stripEntities(t.trim());
  } catch (_) {
    return null;
  }
}

/// Título para insertar como “mención” de enlace: YouTube (oEmbed) u OG/&lt;title&gt;.
Future<String> fetchLinkTitleForMention(String url) async {
  final yt = await fetchYoutubeOEmbedTitle(url);
  if (yt != null && yt.isNotEmpty) return yt;
  final uri = Uri.tryParse(url.trim());
  if (uri != null && uri.hasScheme) {
    final t = await fetchWebPageTitle(uri);
    if (t != null && t.isNotEmpty) return t;
  }
  final host = uri?.host;
  if (host != null && host.isNotEmpty) return host;
  return 'Link';
}
