import 'dart:convert';
import 'dart:typed_data';

import '../data/storage/vault_storage.dart';
import '../models/folio_page.dart';
import '../models/block.dart';
import '../session/vault_session.dart';

/// Índice de búsqueda en memoria, regenerable desde el vault.
class VaultSearchIndex {
  VaultSearchIndex();

  static const String indexFileName = 'search_index.json';

  final Map<String, _IndexedPage> _pages = {};
  int _version = 0;

  int get version => _version;

  void rebuildFromPages(List<FolioPage> pages) {
    _pages.clear();
    for (final page in pages) {
      final title = page.title.trim().isEmpty ? '' : page.title.trim();
      final blocks = <String>[];
      for (final block in page.blocks) {
        final text = _blockSearchText(block);
        if (text.isNotEmpty) blocks.add(text);
      }
      _pages[page.id] = _IndexedPage(
        pageId: page.id,
        titleLower: title.toLowerCase(),
        title: title.isEmpty ? 'Sin título' : title,
        blockTextsLower: blocks.map((b) => b.toLowerCase()).toList(),
        blockIds: page.blocks.map((b) => b.id).toList(),
      );
    }
    _version++;
  }

  List<VaultSearchResult> search(
    String query, {
    int limit = 80,
    bool includeTitleMatches = true,
    bool includeContentMatches = true,
    bool sortByRecency = false,
    bool tasksOnly = false,
    int Function(String pageId)? lastEditedMs,
  }) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty ||
        (!includeTitleMatches && !includeContentMatches)) {
      return const [];
    }
    final out = <VaultSearchResult>[];
    for (final entry in _pages.values) {
      final pageLastEditedMs = lastEditedMs?.call(entry.pageId) ?? 0;
      if (includeTitleMatches && entry.titleLower.contains(q)) {
        final startsAt = entry.titleLower.indexOf(q);
        final titleScore =
            220 - (startsAt.clamp(0, 200)) + (entry.title.length <= 42 ? 15 : 0);
        out.add(
          VaultSearchResult(
            pageId: entry.pageId,
            pageTitle: entry.title,
            snippet: _snippetAround(entry.title, q),
            matchKind: VaultSearchMatchKind.title,
            pageLastEditedMs: pageLastEditedMs,
            score: titleScore,
          ),
        );
      }
      if (includeContentMatches) {
        for (var i = 0; i < entry.blockTextsLower.length; i++) {
          final haystackLower = entry.blockTextsLower[i];
          final idx = haystackLower.indexOf(q);
          if (idx < 0) continue;
          final blockId = i < entry.blockIds.length ? entry.blockIds[i] : null;
          if (tasksOnly && blockId == null) continue;
          final haystack = entry.blockTextsLower[i];
          out.add(
            VaultSearchResult(
              pageId: entry.pageId,
              pageTitle: entry.title,
              blockId: blockId,
              snippet: _snippetAround(haystack, q),
              matchKind: VaultSearchMatchKind.content,
              pageLastEditedMs: pageLastEditedMs,
              score: 120 - (idx.clamp(0, 100)),
            ),
          );
        }
      }
    }
    out.sort((a, b) {
      if (sortByRecency) {
        final byRecency = b.pageLastEditedMs.compareTo(a.pageLastEditedMs);
        if (byRecency != 0) return byRecency;
      }
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      return a.pageTitle.toLowerCase().compareTo(b.pageTitle.toLowerCase());
    });
    if (out.length <= limit) return out;
    return out.take(limit).toList(growable: false);
  }

  Future<void> persistToVault(String vaultId) async {
    final payload = jsonEncode({
      'version': _version,
      'pages': _pages.values.map((p) => p.toJson()).toList(),
    });
    await VaultStorage.instance.writeVaultFile(
      vaultId,
      indexFileName,
      Uint8List.fromList(utf8.encode(payload)),
    );
  }

  Future<void> loadFromVault(String vaultId) async {
    final raw = await VaultStorage.instance.readVaultFile(
      vaultId,
      indexFileName,
    );
    if (raw == null) return;
    try {
      final map = jsonDecode(utf8.decode(raw)) as Map<String, dynamic>;
      _version = (map['version'] as num?)?.toInt() ?? 0;
      _pages.clear();
      final list = map['pages'] as List<dynamic>? ?? const [];
      for (final item in list) {
        if (item is! Map) continue;
        final indexed = _IndexedPage.fromJson(Map<String, dynamic>.from(item));
        _pages[indexed.pageId] = indexed;
      }
    } catch (_) {
      _pages.clear();
      _version = 0;
    }
  }

  static String _blockSearchText(FolioBlock b) {
    final txt = b.text.trim();
    final url = b.url?.trim() ?? '';
    if (txt.isNotEmpty && url.isNotEmpty) return '$txt $url';
    return txt.isNotEmpty ? txt : url;
  }

  static String _snippetAround(String text, String queryLower) {
    final clean = text.replaceAll('\n', ' ').trim();
    if (clean.isEmpty) return '';
    final lower = clean.toLowerCase();
    final idx = lower.indexOf(queryLower);
    if (idx < 0) {
      return clean.length <= 96 ? clean : '${clean.substring(0, 96)}...';
    }
    final start = (idx - 28).clamp(0, clean.length);
    final end = (idx + queryLower.length + 68).clamp(0, clean.length);
    final chunk = clean.substring(start, end).trim();
    final prefix = start > 0 ? '... ' : '';
    final suffix = end < clean.length ? ' ...' : '';
    return '$prefix$chunk$suffix';
  }
}

class _IndexedPage {
  const _IndexedPage({
    required this.pageId,
    required this.titleLower,
    required this.title,
    required this.blockTextsLower,
    required this.blockIds,
  });

  final String pageId;
  final String titleLower;
  final String title;
  final List<String> blockTextsLower;
  final List<String> blockIds;

  Map<String, dynamic> toJson() => {
    'pageId': pageId,
    'titleLower': titleLower,
    'title': title,
    'blockTextsLower': blockTextsLower,
    'blockIds': blockIds,
  };

  factory _IndexedPage.fromJson(Map<String, dynamic> json) {
    return _IndexedPage(
      pageId: '${json['pageId']}',
      titleLower: '${json['titleLower']}',
      title: '${json['title']}',
      blockTextsLower: (json['blockTextsLower'] as List<dynamic>? ?? const [])
          .map((e) => '$e')
          .toList(),
      blockIds: (json['blockIds'] as List<dynamic>? ?? const [])
          .map((e) => '$e')
          .toList(),
    );
  }
}

/// Evaluación de Drift como caché de lectura (no fuente de verdad).
class DriftCacheEvaluation {
  const DriftCacheEvaluation._();

  static const String recommendation =
      'Mantener vault.bin como fuente de verdad. Introducir Drift solo cuando '
      'métricas de beta muestren libretas >500 páginas con búsqueda >200 ms '
      'o backlinks frecuentes. Usarlo como índice FTS desencriptado regenerable, '
      'no como reemplazo del blob cifrado.';
}
