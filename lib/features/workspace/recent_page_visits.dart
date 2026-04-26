import 'package:flutter/foundation.dart';

import 'package:shared_preferences/shared_preferences.dart';

/// Cuántas páginas recientes muestra el panel lateral (chips).
const int kRecentPageVisitsSidebarDisplayLimit = 6;

/// Cuántas entradas se persisten y puede mostrar la pantalla de inicio.
const int kRecentPageVisitsStorageLimit = 12;

/// Alias legible para la carga en inicio (coincide con almacenamiento).
const int kRecentPageVisitsHomeLoadLimit = kRecentPageVisitsStorageLimit;

/// @deprecated Usar [kRecentPageVisitsSidebarDisplayLimit] o [kRecentPageVisitsStorageLimit].
const int kRecentPageVisitsLimit = kRecentPageVisitsSidebarDisplayLimit;

/// Notifica cuando cambia la lista persistida (p. ej. sidebar guarda recientes).
final class RecentPageVisitsChangeNotifier extends ChangeNotifier {
  RecentPageVisitsChangeNotifier._();
  static final RecentPageVisitsChangeNotifier instance =
      RecentPageVisitsChangeNotifier._();

  void notifyRecentsPersisted() => notifyListeners();
}

/// Misma raíz de clave que el sidebar histórico para migración in-place.
const String _recentPrefsPrefix = 'folio_sidebar_recent_pages_';

String recentPageVisitsPrefsKey(String? vaultId) {
  final safeVault =
      (vaultId == null || vaultId.isEmpty) ? 'default' : vaultId;
  return '$_recentPrefsPrefix$safeVault';
}

/// Una visita reciente a una página (persistida con marca temporal).
class RecentPageVisit {
  const RecentPageVisit({
    required this.pageId,
    required this.visitedAtMs,
  });

  final String pageId;
  final int visitedAtMs;
}

/// Carga, guarda y migra la lista de páginas recientes en [SharedPreferences].
///
/// Formato almacenado: cada entrada es `pageId|visitedAtMs`.
/// Formato legado: solo `pageId` (sin `|`); al cargar se asignan tiempos
/// aproximados conservando el orden (más reciente primero).
class RecentPageVisitsStore {
  RecentPageVisitsStore._();

  static bool _entryHasTimestamp(String e) {
    final pipe = e.lastIndexOf('|');
    if (pipe <= 0) return false;
    return int.tryParse(e.substring(pipe + 1)) != null;
  }

  static List<RecentPageVisit> decodeRawList(List<String> saved) {
    if (saved.isEmpty) return [];
    final legacy = saved.every((e) => !_entryHasTimestamp(e));
    final now = DateTime.now().millisecondsSinceEpoch;
    if (legacy) {
      return [
        for (var i = 0; i < saved.length; i++)
          RecentPageVisit(
            pageId: saved[i].trim(),
            visitedAtMs: now - i * 1000,
          ),
      ];
    }
    final out = <RecentPageVisit>[];
    for (final e in saved) {
      final v = _parseEntry(e, now);
      if (v != null) out.add(v);
    }
    return out;
  }

  static RecentPageVisit? _parseEntry(String e, int fallbackMs) {
    final pipe = e.lastIndexOf('|');
    if (pipe <= 0) {
      final id = e.trim();
      if (id.isEmpty) return null;
      return RecentPageVisit(pageId: id, visitedAtMs: fallbackMs);
    }
    final id = e.substring(0, pipe).trim();
    final ms = int.tryParse(e.substring(pipe + 1));
    if (id.isEmpty || ms == null) return null;
    return RecentPageVisit(pageId: id, visitedAtMs: ms);
  }

  static List<String> encodeList(List<RecentPageVisit> visits) {
    return [
      for (final v in visits) '${v.pageId}|${v.visitedAtMs}',
    ];
  }

  /// Orden por [visitedAtMs] descendente; una entrada por [pageId].
  static List<RecentPageVisit> filterAndRank({
    required List<RecentPageVisit> raw,
    required Set<String> validPageIds,
    int limit = kRecentPageVisitsStorageLimit,
  }) {
    final filtered =
        raw.where((v) => validPageIds.contains(v.pageId)).toList()
          ..sort((a, b) => b.visitedAtMs.compareTo(a.visitedAtMs));
    final seen = <String>{};
    final out = <RecentPageVisit>[];
    for (final v in filtered) {
      if (seen.add(v.pageId)) out.add(v);
      if (out.length >= limit) break;
    }
    return out;
  }

  static Future<List<RecentPageVisit>> load({
    required String? vaultId,
    required Set<String> validPageIds,
    int limit = kRecentPageVisitsStorageLimit,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = recentPageVisitsPrefsKey(vaultId);
    final saved = prefs.getStringList(key) ?? const <String>[];
    if (saved.isEmpty) return [];
    final legacy =
        saved.isNotEmpty && saved.every((e) => !_entryHasTimestamp(e));
    final decoded = decodeRawList(saved);
    final ranked = filterAndRank(
      raw: decoded,
      validPageIds: validPageIds,
      limit: limit,
    );
    if (legacy && ranked.isNotEmpty) {
      await save(
        vaultId: vaultId,
        visits: ranked,
        limit: kRecentPageVisitsStorageLimit,
      );
    }
    return ranked;
  }

  static Future<void> save({
    required String? vaultId,
    required List<RecentPageVisit> visits,
    int limit = kRecentPageVisitsStorageLimit,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = recentPageVisitsPrefsKey(vaultId);
    final trimmed = visits.take(limit).toList(growable: false);
    await prefs.setStringList(key, encodeList(trimmed));
    RecentPageVisitsChangeNotifier.instance.notifyRecentsPersisted();
  }

  /// Coloca [pageId] al frente con tiempo actual (o [visitedAtMs]).
  static List<RecentPageVisit> withNewVisit(
    List<RecentPageVisit> current,
    String pageId, {
    int limit = kRecentPageVisitsStorageLimit,
    int? visitedAtMs,
  }) {
    final ms = visitedAtMs ?? DateTime.now().millisecondsSinceEpoch;
    final rest = current.where((v) => v.pageId != pageId);
    return [
      RecentPageVisit(pageId: pageId, visitedAtMs: ms),
      ...rest,
    ].take(limit).toList(growable: false);
  }
}
