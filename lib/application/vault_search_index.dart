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
      final blockIds = <String>[];
      final blockTypes = <String>[];
      for (final block in page.blocks) {
        final text = _blockSearchText(block);
        if (text.isNotEmpty) {
          blocks.add(text);
          blockIds.add(block.id);
          blockTypes.add(block.type);
        }
      }
      _pages[page.id] = _IndexedPage(
        pageId: page.id,
        titleLower: title.toLowerCase(),
        title: title.isEmpty ? 'Sin título' : title,
        blockTextsLower: blocks, // Keep original case for snippets!
        blockIds: blockIds,
        blockTypes: blockTypes,
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
    final queryLower = query.toLowerCase().trim();
    if (queryLower.isEmpty ||
        (!includeTitleMatches && !includeContentMatches)) {
      return const [];
    }
    final terms = queryLower
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();
    if (terms.isEmpty) return const [];

    final out = <VaultSearchResult>[];
    for (final entry in _pages.values) {
      final pageLastEditedMs = lastEditedMs?.call(entry.pageId) ?? 0;
      
      final titleMatchesAll = terms.every((t) => entry.titleLower.contains(t));
      if (includeTitleMatches && titleMatchesAll) {
        final exactIdx = entry.titleLower.indexOf(queryLower);
        var titleScore = 200;
        if (exactIdx >= 0) {
          titleScore += 100 + (30 - exactIdx.clamp(0, 30)) * 2;
        } else {
          var sumIdx = 0;
          for (final t in terms) {
            sumIdx += entry.titleLower.indexOf(t).clamp(0, 200);
          }
          titleScore += 50 - (sumIdx ~/ terms.length);
        }
        if (entry.title.length <= 42) titleScore += 15;

        out.add(
          VaultSearchResult(
            pageId: entry.pageId,
            pageTitle: entry.title,
            snippet: _snippetAroundMulti(entry.title, queryLower, terms),
            matchKind: VaultSearchMatchKind.title,
            pageLastEditedMs: pageLastEditedMs,
            score: titleScore,
          ),
        );
      }

      if (includeContentMatches) {
        for (var i = 0; i < entry.blockTextsLower.length; i++) {
          final haystack = entry.blockTextsLower[i];
          final haystackLower = haystack.toLowerCase();
          
          final blockMatchesAll = terms.every((t) => haystackLower.contains(t));
          if (!blockMatchesAll) continue;

          final blockId = i < entry.blockIds.length ? entry.blockIds[i] : null;
          final blockType = i < entry.blockTypes.length ? entry.blockTypes[i] : null;
          if (tasksOnly && (blockId == null || (blockType != 'todo' && blockType != 'task'))) {
            continue;
          }

          final exactIdx = haystackLower.indexOf(queryLower);
          var contentScore = 100;
          if (exactIdx >= 0) {
            contentScore += 50 + (30 - exactIdx.clamp(0, 30));
          } else {
            var sumIdx = 0;
            for (final t in terms) {
              sumIdx += haystackLower.indexOf(t).clamp(0, 100);
            }
            contentScore += 30 - (sumIdx ~/ terms.length);
          }

          final snippet = _snippetAroundMulti(haystack, queryLower, terms);
          if (snippet.length <= 88) contentScore += 8;

          out.add(
            VaultSearchResult(
              pageId: entry.pageId,
              pageTitle: entry.title,
              blockId: blockId,
              blockType: blockType,
              snippet: snippet,
              matchKind: VaultSearchMatchKind.content,
              pageLastEditedMs: pageLastEditedMs,
              score: contentScore,
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

  /// Elimina el índice persistido en disco (usado en libretas cifradas para
  /// no dejar texto en claro fuera del blob cifrado).
  static Future<void> deleteFromVault(String vaultId) async {
    try {
      await VaultStorage.instance.deleteVaultFile(vaultId, indexFileName);
    } catch (_) {
      // Best-effort: si no existe o no se puede borrar, no bloquea el flujo.
    }
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
    final base = (txt.isNotEmpty && url.isNotEmpty)
        ? '$txt $url'
        : (txt.isNotEmpty ? txt : url);
    if (b.type != 'meeting_note') return base;
    // Fase 1 del roadmap de producto (Knowledge Search) — `b.text` ya es el
    // transcript en bruto (ver `_renderMeetingNoteExport` en
    // `integrations_markdown_codec.dart`), pero el título, el resumen
    // estructurado (Fase 13 de meeting_note) y las notas de preparación
    // vivían fuera de cualquier índice: una búsqueda por una decisión o un
    // action item de una reunión no encontraba nada aunque el transcript
    // completo sí estuviera indexado.
    final extra = <String>[];
    final title = b.meetingNoteTitle?.trim();
    if (title != null && title.isNotEmpty) extra.add(title);
    final prep = b.meetingNotePrepNotes?.trim();
    if (prep != null && prep.isNotEmpty) extra.add(prep);
    final summary = b.meetingNoteSummary;
    if (summary != null) {
      final narrative = (summary['narrative'] as String?)?.trim() ?? '';
      if (narrative.isNotEmpty) extra.add(narrative);
      final keyPoints = (summary['keyPoints'] as List?) ?? const [];
      for (final p in keyPoints) {
        if (p is String && p.trim().isNotEmpty) extra.add(p.trim());
      }
      final actionItems = (summary['actionItems'] as List?) ?? const [];
      for (final raw in actionItems) {
        if (raw is! Map) continue;
        final itemTitle = (raw['title'] as String?)?.trim() ?? '';
        if (itemTitle.isNotEmpty) extra.add(itemTitle);
      }
    }
    if (extra.isEmpty) return base;
    return base.isEmpty ? extra.join(' ') : '$base ${extra.join(' ')}';
  }

  static String _snippetAroundMulti(String text, String queryLower, List<String> terms) {
    final clean = text.replaceAll('\n', ' ').trim();
    if (clean.isEmpty) return '';
    final lower = clean.toLowerCase();
    
    var idx = lower.indexOf(queryLower);
    var matchedLength = queryLower.length;
    
    if (idx < 0 && terms.isNotEmpty) {
      for (final term in terms) {
        final tIdx = lower.indexOf(term);
        if (tIdx >= 0) {
          idx = tIdx;
          matchedLength = term.length;
          break;
        }
      }
    }
    
    if (idx < 0) {
      return clean.length <= 96 ? clean : '${clean.substring(0, 96)}...';
    }
    
    final start = (idx - 28).clamp(0, clean.length);
    final end = (idx + matchedLength + 68).clamp(0, clean.length);
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
    required this.blockTypes,
  });

  final String pageId;
  final String titleLower;
  final String title;
  final List<String> blockTextsLower;
  final List<String> blockIds;
  final List<String> blockTypes;

  Map<String, dynamic> toJson() => {
    'pageId': pageId,
    'titleLower': titleLower,
    'title': title,
    'blockTextsLower': blockTextsLower,
    'blockIds': blockIds,
    'blockTypes': blockTypes,
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
      blockTypes: (json['blockTypes'] as List<dynamic>? ?? const [])
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
