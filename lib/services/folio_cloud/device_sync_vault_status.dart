import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Fase agregada de sync cloud para una libreta en este dispositivo.
enum DeviceSyncVaultPhase {
  /// Activa y subiendo/bajando ahora.
  syncing,

  /// Fingerprint/rev local al día con la nube.
  synced,

  /// Libreta cifrada sin clave de sync en este dispositivo (hace falta
  /// desbloquearla **una vez** aquí; después sync en segundo plano).
  needsUnlock,

  /// Aún no hay pack en la nube para esta libreta.
  emptyCloud,

  /// Error en la libreta activa.
  error,

  /// Esperando primera sync de la libreta activa.
  pending,
}

class DeviceSyncVaultStatus {
  const DeviceSyncVaultStatus({
    required this.vaultId,
    required this.displayName,
    required this.phase,
    required this.isActive,
    this.lastSuccessMs = 0,
    this.remoteRev = 0,
    this.detail,
  });

  final String vaultId;
  final String displayName;
  final DeviceSyncVaultPhase phase;
  final bool isActive;
  final int lastSuccessMs;
  final int remoteRev;
  final String? detail;

  bool get isOk =>
      phase == DeviceSyncVaultPhase.synced ||
      phase == DeviceSyncVaultPhase.emptyCloud;

  /// Ya no bloqueamos la UI pidiendo desbloqueo; el sync adopta la clave sola.
  bool get wantsOpenAction =>
      !isActive &&
      phase != DeviceSyncVaultPhase.needsUnlock &&
      phase != DeviceSyncVaultPhase.pending;
}

class DeviceSyncVaultAck {
  const DeviceSyncVaultAck({
    required this.fingerprint,
    required this.rev,
    required this.successMs,
    this.baselineSnapshotId = '',
  });

  final String fingerprint;
  final int rev;
  final int successMs;

  /// Id del snapshot (`VaultSnapshotManager`) que representa el ancestro
  /// común persistido tras el último push/pull/merge exitoso — el baseline
  /// que permite fast-forward real entre reinicios de la app.
  final String baselineSnapshotId;

  Map<String, Object?> toJson() => {
        'fp': fingerprint,
        'rev': rev,
        'ms': successMs,
        if (baselineSnapshotId.isNotEmpty) 'baseline': baselineSnapshotId,
      };

  static DeviceSyncVaultAck? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final fp = '${raw['fp'] ?? ''}'.trim();
    final rev = raw['rev'] is num
        ? (raw['rev'] as num).toInt()
        : int.tryParse('${raw['rev']}') ?? 0;
    final ms = raw['ms'] is num
        ? (raw['ms'] as num).toInt()
        : int.tryParse('${raw['ms']}') ?? 0;
    final baseline = '${raw['baseline'] ?? ''}'.trim();
    if (fp.isEmpty) return null;
    return DeviceSyncVaultAck(
      fingerprint: fp,
      rev: rev,
      successMs: ms,
      baselineSnapshotId: baseline,
    );
  }
}

/// Persistencia de último fingerprint/rev sincronizado por libreta.
class DeviceSyncVaultAckStore {
  static const _prefsKey = 'folio_device_sync_vault_ack_v1';

  Map<String, DeviceSyncVaultAck> _byVault = {};

  Map<String, DeviceSyncVaultAck> get all => Map.unmodifiable(_byVault);

  DeviceSyncVaultAck? forVault(String vaultId) => _byVault[vaultId];

  Future<void> load() async {
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
      final next = <String, DeviceSyncVaultAck>{};
      for (final e in decoded.entries) {
        final ack = DeviceSyncVaultAck.fromJson(e.value);
        if (ack != null) next['${e.key}'] = ack;
      }
      _byVault = next;
    } catch (_) {
      _byVault = {};
    }
  }

  Future<void> saveAck({
    required String vaultId,
    required String fingerprint,
    required int rev,
    required int successMs,
    /// Si se omite, conserva el `baselineSnapshotId` ya guardado para esta
    /// libreta (la mayoría de llamadas a `saveAck` no tocan el baseline).
    String? baselineSnapshotId,
  }) async {
    final id = vaultId.trim();
    final fp = fingerprint.trim();
    if (id.isEmpty || fp.isEmpty) return;
    _byVault[id] = DeviceSyncVaultAck(
      fingerprint: fp,
      rev: rev,
      successMs: successMs,
      baselineSnapshotId:
          baselineSnapshotId ?? _byVault[id]?.baselineSnapshotId ?? '',
    );
    final p = await SharedPreferences.getInstance();
    await p.setString(
      _prefsKey,
      jsonEncode(_byVault.map((k, v) => MapEntry(k, v.toJson()))),
    );
  }
}

/// Último manifiesto (por página) aplicado con éxito, por libreta: el
/// `blobId` de cada página + el del "resto de la libreta" tal como quedaron
/// tras el último push/pull. Comparar el manifiesto remoto fresco contra este
/// mapa (sin descargar nada) es lo que permite saber qué páginas cambiaron en
/// la nube desde la última vez, para bajar/subir solo esas.
class DeviceSyncPageManifest {
  const DeviceSyncPageManifest({
    required this.vaultBlobId,
    required this.pageBlobIds,
  });

  final String vaultBlobId;
  final Map<String, String> pageBlobIds;

  Map<String, Object?> toJson() => {
        'vault': vaultBlobId,
        'pages': pageBlobIds,
      };

  static DeviceSyncPageManifest? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final vault = '${raw['vault'] ?? ''}'.trim();
    final pagesRaw = raw['pages'];
    final pages = <String, String>{};
    if (pagesRaw is Map) {
      for (final e in pagesRaw.entries) {
        final id = '${e.key}'.trim();
        final blobId = '${e.value ?? ''}'.trim();
        if (id.isNotEmpty && blobId.isNotEmpty) pages[id] = blobId;
      }
    }
    return DeviceSyncPageManifest(vaultBlobId: vault, pageBlobIds: pages);
  }
}

/// Persistencia por libreta del último [DeviceSyncPageManifest] aplicado.
class DeviceSyncPageManifestStore {
  static const _prefsKey = 'folio_device_sync_page_manifest_v1';

  Map<String, DeviceSyncPageManifest> _byVault = {};

  DeviceSyncPageManifest? forVault(String vaultId) => _byVault[vaultId];

  Future<void> load() async {
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
      final next = <String, DeviceSyncPageManifest>{};
      for (final e in decoded.entries) {
        final manifest = DeviceSyncPageManifest.fromJson(e.value);
        if (manifest != null) next['${e.key}'] = manifest;
      }
      _byVault = next;
    } catch (_) {
      _byVault = {};
    }
  }

  Future<void> save({
    required String vaultId,
    required String vaultBlobId,
    required Map<String, String> pageBlobIds,
  }) async {
    final id = vaultId.trim();
    if (id.isEmpty) return;
    _byVault[id] = DeviceSyncPageManifest(
      vaultBlobId: vaultBlobId,
      pageBlobIds: Map<String, String>.from(pageBlobIds),
    );
    final p = await SharedPreferences.getInstance();
    await p.setString(
      _prefsKey,
      jsonEncode(_byVault.map((k, v) => MapEntry(k, v.toJson()))),
    );
  }
}
