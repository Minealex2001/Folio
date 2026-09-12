import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Libretas cuyo borrado local (mover a papelera) todavía no se confirmó en
/// la nube — por llamada en curso, fallo de red, o dispositivo offline en el
/// momento del borrado. Mientras un id esté aquí:
/// - `_discoverAndMaterializeRemoteVaults` nunca la vuelve a materializar,
///   aunque la respuesta remota (posiblemente en caché/desfasada) no la
///   marque todavía como borrada.
/// - El siguiente `syncAllVaults()` reintenta la llamada de borrado a la nube.
///
/// Se limpia en cuanto `/vaults` confirma `trashed:true` para ese id, y como
/// red de seguridad se descarta pasados 14 días por si la confirmación nunca
/// llega (cuenta eliminada, vault ya purgado, etc.).
class DeviceSyncPendingTrashStore {
  static const _prefsKey = 'folio_device_sync_pending_trash_v1';
  static const _maxAge = Duration(days: 14);

  Map<String, int> _byVault = {};
  bool _loaded = false;

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_prefsKey);
    if (raw == null || raw.isEmpty) {
      _byVault = {};
      return;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        _byVault = {};
        return;
      }
      final next = <String, int>{};
      final cutoff = DateTime.now()
          .subtract(_maxAge)
          .millisecondsSinceEpoch;
      for (final e in decoded.entries) {
        final ms = e.value is num
            ? (e.value as num).toInt()
            : int.tryParse('${e.value}') ?? 0;
        if (ms > cutoff) next['${e.key}'] = ms;
      }
      _byVault = next;
    } catch (_) {
      _byVault = {};
    }
  }

  Future<void> _persist() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_prefsKey, jsonEncode(_byVault));
  }

  Future<Set<String>> pendingVaultIds() async {
    await _ensureLoaded();
    return _byVault.keys.toSet();
  }

  Future<bool> isPending(String vaultId) async {
    await _ensureLoaded();
    return _byVault.containsKey(vaultId);
  }

  Future<void> markPending(String vaultId) async {
    await _ensureLoaded();
    _byVault[vaultId] = DateTime.now().millisecondsSinceEpoch;
    await _persist();
  }

  Future<void> clear(String vaultId) async {
    await _ensureLoaded();
    if (_byVault.remove(vaultId) != null) {
      await _persist();
    }
  }
}
