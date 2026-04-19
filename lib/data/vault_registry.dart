import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'vault_paths.dart';

/// Entrada del registro de libretas (metadatos en prefs, datos en disco por [id]).
class VaultEntry {
  const VaultEntry({
    required this.id,
    required this.displayName,
    required this.createdAtMs,
  });

  final String id;
  final String displayName;
  final int createdAtMs;

  Map<String, Object?> toJson() => {
    'id': id,
    'displayName': displayName,
    'createdAtMs': createdAtMs,
  };

  factory VaultEntry.fromJson(Map<String, Object?> j) {
    return VaultEntry(
      id: j['id']! as String,
      displayName: j['displayName']! as String,
      createdAtMs: (j['createdAtMs'] as num).toInt(),
    );
  }
}

/// Registro persistente de libretas y libreta activa.
class VaultRegistry {
  VaultRegistry._();

  static final VaultRegistry instance = VaultRegistry._();

  static const _vaultsJsonKey = 'folio_vault_registry_v1';
  static const _activeIdKey = 'folio_active_vault_id_v1';

  static const _uuid = Uuid();

  List<VaultEntry> _vaults = [];
  String? _activeVaultId;

  List<VaultEntry> get vaults => List.unmodifiable(_vaults);

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
    if (_vaults.any((e) => e.id == entry.id)) return;
    _vaults = [..._vaults, entry];
    await _saveVaultsJson();
  }

  Future<void> remove(String id) async {
    _vaults = _vaults.where((e) => e.id != id).toList();
    await _saveVaultsJson();
    if (_activeVaultId == id) {
      await setActiveVaultId(null);
    }
  }

  Future<void> rename(String id, String displayName) async {
    final t = displayName.trim();
    if (t.isEmpty) return;
    _vaults = _vaults
        .map(
          (e) => e.id == id
              ? VaultEntry(id: e.id, displayName: t, createdAtMs: e.createdAtMs)
              : e,
        )
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
