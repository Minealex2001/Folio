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
///
/// Multi-cuenta: cada entrada puede llevar [VaultEntry.accountUid]. El filtro
/// activo ([bindAccountUid]) limita [vaults]/[activeVaultId] a esa cuenta.
/// Multi-equipo: [bindOrganizationId] null = solo personales; no-null = solo
/// workspaces de ese equipo.
class VaultRegistry {
  VaultRegistry._();

  static final VaultRegistry instance = VaultRegistry._();

  static const _vaultsJsonKey = 'folio_vault_registry_v1';
  static const _activeIdKeyPrefix = 'folio_active_vault_id_v1';

  static const _uuid = Uuid();

  List<VaultEntry> _vaults = [];
  final Map<String, String?> _activeByScope = {};

  String? _boundAccountUid;
  String? _boundOrganizationId;

  /// Vincula el registro a una cuenta (+ opcionalmente un equipo).
  ///
  /// [organizationId] null → contexto personal (sin workspaces de equipo).
  /// [organizationId] no null → solo libretas de ese equipo.
  Future<void> bindContext({
    String? accountUid,
    String? organizationId,
  }) async {
    _boundAccountUid = accountUid;
    _boundOrganizationId = organizationId;
    await load();
  }

  @Deprecated('Use bindContext')
  Future<void> bindAccountUid(String? accountUid) =>
      bindContext(accountUid: accountUid);

  String? get boundAccountUid => _boundAccountUid;
  String? get boundOrganizationId => _boundOrganizationId;

  String get _activeKey {
    final acc = _boundAccountUid ?? '_local';
    final org = _boundOrganizationId ?? '_personal';
    return '${_activeIdKeyPrefix}_${acc}_$org';
  }

  bool _matchesContext(VaultEntry e) {
    final acc = _boundAccountUid;
    if (acc != null && acc.isNotEmpty) {
      final entryAcc = e.accountUid;
      if (entryAcc == null || entryAcc.isEmpty) {
        // Unclaimed legacy: only visible before any account-scoped migration.
        // After migration, every personal vault has accountUid.
        return false;
      }
      if (entryAcc != acc) return false;
    }
    final org = _boundOrganizationId;
    if (org == null || org.isEmpty) {
      return !e.isTeamWorkspace;
    }
    return e.organizationId == org;
  }

  /// Libretas activas (no en papelera) del contexto vinculado.
  List<VaultEntry> get vaults => List.unmodifiable(
        _vaults.where((e) => !e.isTrashed && _matchesContext(e)),
      );

  /// Todas las libretas registradas localmente, incluidas las de la papelera.
  List<VaultEntry> get allVaults => List.unmodifiable(_vaults);

  List<VaultEntry> get trashedVaults => List.unmodifiable(
        _vaults.where((e) => e.isTrashed && _matchesContext(e)),
      );

  String? get activeVaultId => _activeByScope[_activeKey];

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
    await _claimLegacyVaultsForBoundAccount();
    final scoped = prefs.getString(_activeKey);
    final legacyGlobal = prefs.getString('folio_active_vault_id_v1');
    _activeByScope[_activeKey] = scoped ??
        (_boundAccountUid == null ? legacyGlobal : null);
  }

  /// Asigna [accountUid] a entradas legacy sin dueño solo en la primera migración
  /// (ninguna entrada del registro tiene aún accountUid).
  Future<void> _claimLegacyVaultsForBoundAccount() async {
    final acc = _boundAccountUid;
    if (acc == null || acc.isEmpty) return;
    final anyClaimed = _vaults.any(
      (e) => e.accountUid != null && e.accountUid!.isNotEmpty,
    );
    if (anyClaimed) return;
    var changed = false;
    _vaults = _vaults.map((e) {
      if ((e.accountUid == null || e.accountUid!.isEmpty) && !e.isTeamWorkspace) {
        changed = true;
        return e.copyWith(accountUid: acc);
      }
      return e;
    }).toList();
    if (changed) await _saveVaultsJson();
  }

  Future<void> _saveVaultsJson() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(_vaults.map((e) => e.toJson()).toList());
    await prefs.setString(_vaultsJsonKey, encoded);
  }

  Future<void> setActiveVaultId(String? id) async {
    _activeByScope[_activeKey] = id;
    final prefs = await SharedPreferences.getInstance();
    if (id == null || id.isEmpty) {
      await prefs.remove(_activeKey);
    } else {
      await prefs.setString(_activeKey, id);
    }
  }

  Future<void> add(VaultEntry entry) async {
    final withAccount = entry.accountUid == null && _boundAccountUid != null
        ? entry.copyWith(accountUid: _boundAccountUid)
        : entry;
    if (_vaults.any((e) => e.id == withAccount.id)) {
      _vaults = _vaults
          .map((e) => e.id == withAccount.id ? withAccount : e)
          .toList();
      await _saveVaultsJson();
      return;
    }
    _vaults = [..._vaults, withAccount];
    await _saveVaultsJson();
  }

  Future<void> upsert(VaultEntry entry) async {
    final withAccount = entry.accountUid == null && _boundAccountUid != null
        ? entry.copyWith(accountUid: _boundAccountUid)
        : entry;
    if (_vaults.any((e) => e.id == withAccount.id)) {
      _vaults =
          _vaults.map((e) => e.id == withAccount.id ? withAccount : e).toList();
    } else {
      _vaults = [..._vaults, withAccount];
    }
    await _saveVaultsJson();
  }

  Future<void> remove(String id) async {
    _vaults = _vaults.where((e) => e.id != id).toList();
    await _saveVaultsJson();
    if (activeVaultId == id) {
      await setActiveVaultId(null);
    }
  }

  Future<void> trash(String id) async {
    _vaults = _vaults
        .map((e) => e.id == id ? e.copyWith(trashedAt: DateTime.now()) : e)
        .toList();
    await _saveVaultsJson();
    if (activeVaultId == id) {
      await setActiveVaultId(null);
    }
  }

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
    if (kIsWeb) return;
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
      accountUid: _boundAccountUid,
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
