import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'vault_entry.dart';
import 'vault_paths.dart';

export 'vault_entry.dart';

/// Registro persistente de libretas y libreta activa.
class VaultRegistry {
  VaultRegistry._();

  static final VaultRegistry instance = VaultRegistry._();

  static const _vaultsJsonKey = 'folio_vault_registry_v1';
  static const _activeIdKey = 'folio_active_vault_id_v1';

  static const _uuid = Uuid();

  List<VaultEntry> _vaults = [];
  String? _activeVaultId;

  /// Libretas activas (no en papelera) — lo que usa el resto de la app.
  List<VaultEntry> get vaults =>
      List.unmodifiable(_vaults.where((e) => !e.isTrashed));

  /// Todas las libretas registradas localmente, incluidas las de la papelera.
  List<VaultEntry> get allVaults => List.unmodifiable(_vaults);

  /// Solo las libretas en papelera localmente (con copia local de archivos).
  List<VaultEntry> get trashedVaults =>
      List.unmodifiable(_vaults.where((e) => e.isTrashed));

  String? get activeVaultId => _activeVaultId;

  bool containsVault(String id) => _vaults.any((e) => e.id == id);

  VaultEntry? entryFor(String id) {
    try {
      return _vaults.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_vaultsJsonKey);
    if (raw == null || raw.isEmpty) {
      _vaults = [];
    } else {
      try {
        final list = jsonDecode(raw) as List<dynamic>;
        _vaults = list
            .map(
              (e) => VaultEntry.fromJson(Map<String, Object?>.from(e as Map)),
            )
            .toList();
      } catch (_) {
        _vaults = [];
      }
    }
    _activeVaultId = prefs.getString(_activeIdKey);
  }

  Future<void> _saveVaultsJson() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(_vaults.map((e) => e.toJson()).toList());
    await prefs.setString(_vaultsJsonKey, encoded);
  }

  Future<void> setActiveVaultId(String? id) async {
    _activeVaultId = id;
    final prefs = await SharedPreferences.getInstance();
    if (id == null || id.isEmpty) {
      await prefs.remove(_activeIdKey);
    } else {
      await prefs.setString(_activeIdKey, id);
    }
  }

  Future<void> add(VaultEntry entry) async {
    if (_vaults.any((e) => e.id == entry.id)) {
      // Upsert shared metadata if already present.
      _vaults = _vaults
          .map((e) => e.id == entry.id ? entry : e)
          .toList();
      await _saveVaultsJson();
      return;
    }
    _vaults = [..._vaults, entry];
    await _saveVaultsJson();
  }

  Future<void> upsert(VaultEntry entry) async {
    if (_vaults.any((e) => e.id == entry.id)) {
      _vaults = _vaults.map((e) => e.id == entry.id ? entry : e).toList();
    } else {
      _vaults = [..._vaults, entry];
    }
    await _saveVaultsJson();
  }

  Future<void> remove(String id) async {
    _vaults = _vaults.where((e) => e.id != id).toList();
    await _saveVaultsJson();
    if (_activeVaultId == id) {
      await setActiveVaultId(null);
    }
  }

  /// Mueve una libreta a la papelera: sigue en el registro (y sus archivos en
  /// disco), pero deja de aparecer en [vaults]/el selector.
  Future<void> trash(String id) async {
    _vaults = _vaults
        .map((e) => e.id == id ? e.copyWith(trashedAt: DateTime.now()) : e)
        .toList();
    await _saveVaultsJson();
    if (_activeVaultId == id) {
      await setActiveVaultId(null);
    }
  }

  /// Saca una libreta de la papelera (undo del [trash]).
  Future<void> restoreFromTrash(String id) async {
    _vaults = _vaults
        .map((e) => e.id == id ? e.copyWith(clearTrashedAt: true) : e)
        .toList();
    await _saveVaultsJson();
  }

  Future<void> rename(String id, String displayName) async {
    final t = displayName.trim();
    if (t.isEmpty) return;
    _vaults = _vaults
        .map((e) => e.id == id ? e.copyWith(displayName: t) : e)
        .toList();
    await _saveVaultsJson();
  }

  /// Migra `folio_vault/` legacy a `folio_vaults/<uuid>/` y registra una libreta.
  Future<void> migrateFromLegacyIfNeeded() async {
    if (kIsWeb) return; // No hay filesystem legacy en web
    await load();
    if (_vaults.isNotEmpty) return;

    final support = await getApplicationSupportDirectory();
    final legacy = Directory(
      p.join(support.path, VaultPaths.legacyVaultDirName),
    );
    if (!legacy.existsSync()) return;

    final keys = File(p.join(legacy.path, VaultPaths.wrappedDekFile));
    if (!keys.existsSync()) return;

    final id = _uuid.v4();
    final dest = Directory(
      p.join(support.path, VaultPaths.vaultsContainerDirName, id),
    );
    await dest.create(recursive: true);
    await _moveDirectoryContents(legacy, dest);
    try {
      if (legacy.existsSync()) {
        await legacy.delete(recursive: true);
      }
    } catch (_) {}

    final entry = VaultEntry(
      id: id,
      displayName: 'Vault',
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    _vaults = [entry];
    await _saveVaultsJson();
    await setActiveVaultId(id);
  }

  static Future<void> _moveDirectoryContents(
    Directory from,
    Directory to,
  ) async {
    await for (final entity in from.list(followLinks: false)) {
      final name = p.basename(entity.path);
      final newPath = p.join(to.path, name);
      if (entity is File) {
        await entity.copy(newPath);
        await entity.delete();
      } else if (entity is Directory) {
        final subDest = Directory(newPath);
        await subDest.create(recursive: true);
        await _moveDirectoryContents(entity, subDest);
        await entity.delete(recursive: true);
      }
    }
  }
}
