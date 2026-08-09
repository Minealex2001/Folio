import 'package:flutter/foundation.dart';

import 'package:shared_preferences/shared_preferences.dart';

/// Cuántas páginas recientes muestra el panel lateral (chips).
const int kRecentPageVisitsSidebarDisplayLimit = 4;

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
    this.lastBlockId,
  });

  final String pageId;
  final int visitedAtMs;

  /// Fase 2 del roadmap de producto — último bloque enfocado en esta página
  /// al salir de ella (ver `VaultSession.noteLastFocusedBlock`), para que
  /// "continuar donde lo dejaste" pueda saltar directo a la posición de
  /// edición en vez de solo abrir la página desde arriba. `null` = no se
  /// registró ningún foco (o la página se visitó sin editar nada).
  final String? lastBlockId;

  RecentPageVisit copyWith({String? lastBlockId, bool clearLastBlockId = false}) {
    return RecentPageVisit(
      pageId: pageId,
      visitedAtMs: visitedAtMs,
      lastBlockId: clearLastBlockId ? null : (lastBlockId ?? this.lastBlockId),
    );
  }
}

/// Carga, guarda y migra la lista de páginas recientes en [SharedPreferences].
///
/// Formato almacenado: cada entrada es `pageId|visitedAtMs`.
/// Formato legado: solo `pageId` (sin `|`); al cargar se asignan tiempos
/// aproximados conservando el orden (más reciente primero).
class RecentPageVisitsStore {
  RecentPageVisitsStore._();

  static bool _entryHasTimestamp(String e) {
    // Fase 2 del roadmap de producto — formato extendido a
    // `pageId|visitedAtMs|blockId` (blockId opcional): ya no se puede
    // asumir que el segmento tras el ÚLTIMO `|` es el timestamp, así que
    // se parte por `|` y se mira siempre la posición 1.
    final parts = e.split('|');
    if (parts.length < 2) return false;
    return int.tryParse(parts[1]) != null;
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
    final parts = e.split('|');
    final id = parts[0].trim();
    if (id.isEmpty) return null;
    if (parts.length < 2) {
      return RecentPageVisit(pageId: id, visitedAtMs: fallbackMs);
    }
    final ms = int.tryParse(parts[1]);
    if (ms == null) return null;
    final blockId = (parts.length >= 3 && parts[2].trim().isNotEmpty)
        ? parts[2].trim()
        : null;
    return RecentPageVisit(pageId: id, visitedAtMs: ms, lastBlockId: blockId);
  }

  static List<String> encodeList(List<RecentPageVisit> visits) {
    return [
      for (final v in visits)
        (v.lastBlockId == null || v.lastBlockId!.isEmpty)
            ? '${v.pageId}|${v.visitedAtMs}'
            : '${v.pageId}|${v.visitedAtMs}|${v.lastBlockId}',
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

  /// Fase 2 del roadmap de producto — actualiza el `lastBlockId` de la
  /// entrada de [pageId] si existe, sin tocar su posición ni `visitedAtMs`.
  /// No-op si [pageId] no está en la lista (p. ej. se cerró la app antes de
  /// que esa visita llegara a persistirse).
  static List<RecentPageVisit> withUpdatedLastBlock(
    List<RecentPageVisit> current,
    String pageId,
    String blockId,
  ) {
    final idx = current.indexWhere((v) => v.pageId == pageId);
    if (idx < 0 || current[idx].lastBlockId == blockId) return current;
    final next = List<RecentPageVisit>.of(current);
    next[idx] = next[idx].copyWith(lastBlockId: blockId);
    return next;
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
