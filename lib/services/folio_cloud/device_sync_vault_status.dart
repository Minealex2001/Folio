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
  });

  final String fingerprint;
  final int rev;
  final int successMs;

  Map<String, Object?> toJson() => {
        'fp': fingerprint,
        'rev': rev,
        'ms': successMs,
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
    if (fp.isEmpty) return null;
    return DeviceSyncVaultAck(fingerprint: fp, rev: rev, successMs: ms);
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
  }) async {
    final id = vaultId.trim();
    final fp = fingerprint.trim();
    if (id.isEmpty || fp.isEmpty) return;
    _byVault[id] = DeviceSyncVaultAck(
      fingerprint: fp,
      rev: rev,
      successMs: successMs,
    );
    final p = await SharedPreferences.getInstance();
    await p.setString(
      _prefsKey,
      jsonEncode(_byVault.map((k, v) => MapEntry(k, v.toJson()))),
    );
  }
}
