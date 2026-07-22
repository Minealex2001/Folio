import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../app_logger.dart';
import 'sync_conflict_entry.dart';

/// Persistencia de la cola de conflictos de sync por libreta.
class SyncConflictStore {
  static const _prefsPrefix = 'folio_sync_conflicts_v1_';

  static String _key(String vaultId) => '$_prefsPrefix${vaultId.trim()}';

  Future<List<SyncConflictEntry>> load(String vaultId) async {
    final id = vaultId.trim();
    if (id.isEmpty) return const [];
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_key(id));
      if (raw == null || raw.isEmpty) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final out = <SyncConflictEntry>[];
      for (final item in decoded) {
        if (item is! Map) continue;
        final entry = SyncConflictEntry.fromJson(
          Map<String, dynamic>.from(item),
        );
        if (entry != null) out.add(entry);
      }
      return out;
    } catch (e) {
      AppLogger.warn(
        'sync conflict store load failed',
        tag: 'sync',
        context: {'vaultId': id, 'error': '$e'},
      );
      return const [];
    }
  }

  Future<void> save(String vaultId, List<SyncConflictEntry> entries) async {
    final id = vaultId.trim();
    if (id.isEmpty) return;
    try {
      final p = await SharedPreferences.getInstance();
      if (entries.isEmpty) {
        await p.remove(_key(id));
        return;
      }
      await p.setString(
        _key(id),
        jsonEncode(entries.map((e) => e.toJson()).toList()),
      );
    } catch (e) {
      AppLogger.warn(
        'sync conflict store save failed',
        tag: 'sync',
        context: {'vaultId': id, 'error': '$e'},
      );
    }
  }
}
