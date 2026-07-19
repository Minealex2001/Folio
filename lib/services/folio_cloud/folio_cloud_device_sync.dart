import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cryptography/cryptography.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../../app/app_settings.dart';
import '../../crypto/vault_crypto.dart';
import '../../data/vault_paths.dart';
import '../../data/vault_registry.dart';
import '../../session/vault_session.dart';
import '../app_logger.dart';
import '../folio_firestore_support.dart';
import '../sync/vault_sync_merge.dart';
import '../sync/vault_sync_pack.dart';
import 'device_sync_vault_bootstrap.dart';
import 'device_sync_vault_status.dart';
import 'device_sync_key_cache.dart';
import 'folio_cloud_device_sync_incremental.dart';
import 'folio_cloud_entitlements.dart';
import 'folio_cloud_pack_crypto.dart';
import 'folio_firestore_rest.dart';
import 'folio_storage_transport.dart';
import 'headless_device_sync_vault.dart';

/// Sincronización multi-dispositivo vía Folio Cloud (pack cifrado + señal Firestore).
///
/// Cifrado con la DEK en memoria (libreta desbloqueada) o clave derivada estable
/// del vault en claro. **Nunca pide contraseña** ni usa restore-wrap de cloud-pack.
/// Solo sube cuando el fingerprint del contenido local cambia. Logs mínimos;
/// los fallos de fondo no spamean snacks (solo log).
///
/// Formato v2: manifiesto + blobs content-addressed (payload + adjuntos).
/// Formato v1 (legacy): un único pack monolítico bajo `device-sync/packs/`.
class FolioCloudDeviceSyncController extends ChangeNotifier {
  FolioCloudDeviceSyncController({
    required AppSettings appSettings,
    required VaultSession session,
    required FolioCloudEntitlementsController entitlements,
    void Function(String message)? onEvent,
  }) : _settings = appSettings,
       _session = session,
       _entitlements = entitlements,
       _onEvent = onEvent;

  final AppSettings _settings;
  final VaultSession _session;
  final FolioCloudEntitlementsController _entitlements;
  final void Function(String message)? _onEvent;
  bool _disposed = false;

  static const Duration _pushDebounce = Duration(seconds: 10);
  /// Poll de meta remota de la libreta activa, solo en primer plano.
  static const Duration _pollIntervalForeground = Duration(seconds: 30);
  /// Poll de todas las libretas (incl. bloqueadas / no activas), solo en primer plano.
  static const Duration _allVaultsPollInterval = Duration(minutes: 15);
  static const int _maxPackBytes = 80 * 1024 * 1024;

  Timer? _pushDebounceTimer;
  Timer? _pollTimer;
  Timer? _allVaultsPollTimer;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _metaSub;
  bool _pushInFlight = false;
  bool _pullInFlight = false;
  bool _dirty = false;
  bool _appInForeground = true;
  String _lastAppliedFingerprint = '';
  String _lastPushedFingerprint = '';
  /// Fingerprint remoto cuyo pull falló por blobs ausentes (evitar bucle).
  String _pullBrokenFingerprint = '';
  String? _boundVaultId;
  int _lastRemoteRev = 0;
  /// Cache local para no llamar a `folioGetDeviceSyncMeta` en cada push.
  String _cachedPackPath = '';
  int _cachedPackSize = 0;
  /// Manifiesto v2 remoto (path + tamaño + blobIds conocidos).
  String _cachedManifestPath = '';
  int _cachedManifestSize = 0;
  Set<String> _cachedRemoteBlobIds = {};
  String _status = '';
  String? _lastError;
  /// Evita spamear el mismo error en snacks.
  String _lastNotifiedError = '';
  Map<String, dynamic>? _pendingRemoteMeta;
  int _lastSyncSuccessMs = 0;
  /// Progreso de subida incremental (0–1); null si no aplica.
  double? _transferProgress;
  int _blobsCompleted = 0;
  int _blobsTotal = 0;
  final DeviceSyncVaultAckStore _ackStore = DeviceSyncVaultAckStore();
  final HeadlessDeviceSyncVault _headless = HeadlessDeviceSyncVault();
  List<DeviceSyncVaultStatus> _vaultStatuses = const [];
  bool _ackLoaded = false;
  bool _vaultStatusRefreshInFlight = false;
  bool _allVaultsSyncInFlight = false;

  int get lastSyncSuccessMs => _lastSyncSuccessMs;
  String get statusMessage => _status;
  String? get lastError => _lastError;
  int get lastRemoteRev => _lastRemoteRev;
  double? get transferProgress => _transferProgress;
  int get blobsCompleted => _blobsCompleted;
  int get blobsTotal => _blobsTotal;
  bool get isSyncing =>
      _status == 'pushing' || _status == 'pulling' || _pushInFlight || _pullInFlight;
  List<DeviceSyncVaultStatus> get vaultStatuses =>
      List.unmodifiable(_vaultStatuses);

  /// Todas las libretas locales están al día (o sin pack en la nube).
  bool get allVaultsSynced =>
      _vaultStatuses.isNotEmpty &&
      _vaultStatuses.every((v) => v.isOk) &&
      !isSyncing &&
      _status != 'error';

  int get vaultsNeedingAttention => _vaultStatuses
      .where(
        (v) =>
            v.phase == DeviceSyncVaultPhase.error ||
            v.phase == DeviceSyncVaultPhase.pending,
      )
      .length;

  bool get isEnabled =>
      _settings.cloudDeviceSyncEnabled &&
      _entitlements.snapshot.canUseCloudBackup &&
      Firebase.apps.isNotEmpty &&
      FirebaseAuth.instance.currentUser != null;

  /// Pausa o reanuda solo el **pull** (poll + listener). El push no cambia.
  void setAppInForeground(bool foreground) {
    if (_appInForeground == foreground) return;
    _appInForeground = foreground;
    if (!isEnabled) return;
    if (foreground) {
      unawaited(_resumePullWatching());
    } else {
      unawaited(_stopPullWatching());
    }
  }

  /// Si la libreta activa cambió, rebind del pull + actualización inmediata.
  /// No toca el push ni reinicia el timer de todas las libretas.
  Future<void> onActiveVaultMaybeChanged() async {
    if (!isEnabled) return;
    final vaultId = VaultPaths.activeVaultId;
    final next = (vaultId != null && vaultId.isNotEmpty) ? vaultId : null;
    if (next == _boundVaultId) return;
    AppLogger.debug(
      'active vault changed for pull',
      tag: 'cloud_sync',
      context: {
        'from': _boundVaultId ?? '(none)',
        'to': next ?? '(none)',
      },
    );
    _boundVaultId = next;
    _resetBoundVaultCaches();
    await _metaSub?.cancel();
    _metaSub = null;
    _pollTimer?.cancel();
    _pollTimer = null;
    if (next != null) {
      await _refreshRemoteMetaOnce();
    }
    if (_appInForeground) {
      _startActiveVaultPullWatching();
    }
  }

  void onLocalSnapshotPersisted() {
    if (!isEnabled) return;
    // Solo la libreta activa desbloqueada puede empujar cambios en memoria.
    if (_session.state != VaultFlowState.unlocked) return;
    // Idle: solo push tras ~10 s sin nuevos guardados (= usuario dejó de editar).
    _dirty = true;
    _pushDebounceTimer?.cancel();
    _pushDebounceTimer = Timer(_pushDebounce, () {
      unawaited(_pushIfNeeded());
    });
  }

  /// Push inmediato de la libreta activa (cambiar de vault/página o sync manual).
  /// Cancela el debounce y espera a que termine la subida.
  Future<void> flushPushNow() async {
    if (!isEnabled) return;
    if (_session.state != VaultFlowState.unlocked) return;
    _pushDebounceTimer?.cancel();
    _dirty = true;
    await _pushIfNeeded(force: true);
  }

  /// Si hay push pendiente (idle timer o dirty), lo ejecuta ya.
  Future<void> flushPushIfPending() async {
    if (!isEnabled) return;
    if (_session.state != VaultFlowState.unlocked) return;
    if (!_dirty && _pushDebounceTimer == null) return;
    _pushDebounceTimer?.cancel();
    _pushDebounceTimer = null;
    if (!_dirty) return;
    await _pushIfNeeded(force: true);
  }

  /// Fuerza sync de todas las libretas locales (también bloqueadas).
  Future<bool> syncNow() async {
    if (!isEnabled) return false;
    await syncAllVaults();
    return _status != 'error' && vaultsNeedingAttention == 0;
  }

  /// Tras desbloquear, cachea la DEK/clave de sync y sube bootstrap de inmediato.
  Future<void> cacheKeyForActiveVault() async {
    // Faltaba este guard: sin él, un llamador que no comprobara `isEnabled`
    // (como ocurría en `_onSession` de folio_app.dart) subía el bootstrap a
    // Firebase Storage aunque el usuario tuviera Cloud Device Sync desactivado.
    if (!isEnabled) return;
    final vaultId = VaultPaths.activeVaultId;
    if (vaultId == null || vaultId.isEmpty) return;
    if (_session.state != VaultFlowState.unlocked) return;
    try {
      if (_session.vaultUsesEncryption) {
        final dek = _session.cloudPackRestoreDekMaterial;
        if (dek != null) {
          await _headless.keyCache.save(vaultId, dek);
        }
      } else {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null && uid.isNotEmpty) {
          final key = await DeviceSyncKeyCache.plainPackKey(
            uid: uid,
            vaultId: vaultId,
          );
          final raw = await key.extractBytes();
          await _headless.keyCache.save(vaultId, raw);
        }
      }
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null && uid.isNotEmpty) {
        await _uploadBootstrapAfterPush(uid: uid, vaultId: vaultId);
      }
    } catch (e) {
      AppLogger.warn(
        'cacheKeyForActiveVault failed',
        tag: 'cloud_sync',
        context: {'error': '$e'},
      );
    }
  }

  Future<void> start() async {
    await stopWatching();
    if (!isEnabled) return;
    final vaultId = VaultPaths.activeVaultId;
    // Sin libreta activa aún: igual sincronizamos el resto en background.
    _boundVaultId = (vaultId != null && vaultId.isNotEmpty) ? vaultId : null;
    _resetBoundVaultCaches();
    AppLogger.debug(
      'start',
      tag: 'cloud_sync',
      context: {
        'vaultId': _boundVaultId ?? '(none)',
        'device': _settings.syncDeviceId,
        'unlocked': _session.isUnlocked,
      },
    );
    await _ensureAckLoaded();
    await cacheKeyForActiveVault();
    if (_boundVaultId != null) {
      await _refreshRemoteMetaOnce();
    }
    unawaited(syncAllVaults());
    if (_appInForeground) {
      _startPullWatching();
    }
    if (_session.isUnlocked &&
        _lastPushedFingerprint.isEmpty &&
        _lastAppliedFingerprint.isEmpty) {
      _dirty = true;
      unawaited(_pushIfNeeded());
    }
  }

  /// Cancela poll + listener de pull sin tocar push ni caches de vault.
  Future<void> _stopPullWatching() async {
    await _metaSub?.cancel();
    _metaSub = null;
    _pollTimer?.cancel();
    _pollTimer = null;
    _allVaultsPollTimer?.cancel();
    _allVaultsPollTimer = null;
  }

  /// Reanuda watchers de pull y fuerza un pull inmediato de la libreta activa.
  Future<void> _resumePullWatching() async {
    if (!_appInForeground || !isEnabled) return;
    await _stopPullWatching();
    if (_boundVaultId != null) {
      await _refreshRemoteMetaOnce();
    }
    _startPullWatching();
  }

  void _startPullWatching() {
    if (!_appInForeground || !isEnabled) return;
    _startAllVaultsPolling();
    _startActiveVaultPullWatching();
  }

  void _startActiveVaultPullWatching() {
    if (!_appInForeground || !isEnabled) return;
    if (_boundVaultId != null && folioFirestoreSupported) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      unawaited(_metaSub?.cancel());
      _metaSub = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('vaultSync')
          .doc(_boundVaultId!)
          .snapshots()
          .listen(
            (snap) => unawaited(_onRemoteMeta(snap.data())),
            onError: (Object e, StackTrace st) {
              AppLogger.warn(
                'vaultSync snapshots failed; falling back to poll',
                tag: 'cloud_sync',
                context: {'error': '$e'},
              );
              _startPolling();
            },
          );
    } else {
      _startPolling();
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    if (!_appInForeground) return;
    _pollTimer = Timer.periodic(_pollIntervalForeground, (_) {
      unawaited(_refreshRemoteMetaOnce());
    });
  }

  void _startAllVaultsPolling() {
    _allVaultsPollTimer?.cancel();
    if (!_appInForeground) return;
    _allVaultsPollTimer = Timer.periodic(_allVaultsPollInterval, (_) {
      unawaited(syncAllVaults());
    });
  }

  Future<void> stopWatching() async {
    await _stopPullWatching();
    if (_boundVaultId != null) {
      AppLogger.debug(
        'stop',
        tag: 'cloud_sync',
        context: {'vaultId': _boundVaultId},
      );
    }
    _boundVaultId = null;
    _resetBoundVaultCaches();
  }

  /// Evita reutilizar pack/manifiesto de otra libreta al cambiar de vault
  /// (p. ej. libreta nueva importada desde la web).
  void _resetBoundVaultCaches() {
    _cachedPackPath = '';
    _cachedPackSize = 0;
    _cachedManifestPath = '';
    _cachedManifestSize = 0;
    _cachedRemoteBlobIds = {};
    _lastAppliedFingerprint = '';
    _lastPushedFingerprint = '';
    _pullBrokenFingerprint = '';
    _lastRemoteRev = 0;
    _pendingRemoteMeta = null;
  }

  Future<void> disposeController() async {
    _pushDebounceTimer?.cancel();
    await stopWatching();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(disposeController());
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }

  Future<void> _refreshRemoteMetaOnce() async {
    if (!isEnabled) return;
    final vaultId = _boundVaultId ?? VaultPaths.activeVaultId;
    if (vaultId == null || vaultId.isEmpty) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      Map<String, dynamic>? data;
      if (folioFirestoreSupported) {
        final snap = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('vaultSync')
            .doc(vaultId)
            .get();
        data = snap.data();
      } else {
        data = await folioFirestoreRestGetDocument(
          'users/$uid/vaultSync/$vaultId',
        );
      }
      await _onRemoteMeta(data);
    } catch (e, st) {
      AppLogger.warn(
        'vaultSync meta refresh failed',
        tag: 'cloud_sync',
        context: {'error': '$e', 'stack': '$st'},
      );
    }
  }

  Future<void> _onRemoteMeta(Map<String, dynamic>? data) async {
    if (data == null || data.isEmpty) return;
    if (!isEnabled) return;
    // Puede aplicarse con libreta bloqueada (headless).

    final deviceId = '${data['deviceId'] ?? ''}'.trim();
    final fingerprint = '${data['contentFingerprint'] ?? ''}'.trim();
    final packPath = '${data['packStoragePath'] ?? ''}'.trim();
    final manifestPath = '${data['manifestStoragePath'] ?? ''}'.trim();
    final packSize = _asInt(data['packSizeBytes']);
    final manifestSize = _asInt(data['manifestSizeBytes']);
    final formatVersion = _asInt(data['syncFormatVersion']);
    final revRaw = data['rev'];
    final rev = revRaw is num
        ? revRaw.toInt()
        : int.tryParse('$revRaw') ?? 0;

    final isV2 = formatVersion >= 2 && manifestPath.isNotEmpty;
    if (!isV2 && (packPath.isEmpty || fingerprint.isEmpty)) return;
    if (isV2 && fingerprint.isEmpty) return;

    if (isV2) {
      _cachedManifestPath = manifestPath;
      if (manifestSize > 0) _cachedManifestSize = manifestSize;
      _cachedPackPath = '';
      _cachedPackSize = 0;
    } else if (packPath.isNotEmpty) {
      _cachedPackPath = packPath;
      if (packSize > 0) _cachedPackSize = packSize;
    }

    if (deviceId.isNotEmpty && deviceId == _settings.syncDeviceId) {
      _lastPushedFingerprint = fingerprint;
      _lastAppliedFingerprint = fingerprint;
      _lastRemoteRev = rev > _lastRemoteRev ? rev : _lastRemoteRev;
      if (isV2 &&
          _cachedRemoteBlobIds.isEmpty &&
          manifestPath.isNotEmpty) {
        unawaited(_warmBlobIdCache(manifestPath));
      }
      return;
    }
    if (fingerprint == _lastAppliedFingerprint) return;
    if (rev > 0 && rev < _lastRemoteRev) return;

    if (_pushInFlight) {
      _pendingRemoteMeta = data;
      return;
    }

    final activeId = VaultPaths.activeVaultId;
    if (_session.isUnlocked &&
        activeId != null &&
        activeId == _boundVaultId) {
      await _pullAndMerge(
        packStoragePath: packPath,
        manifestStoragePath: manifestPath,
        syncFormatVersion: isV2 ? 2 : 1,
        fingerprint: fingerprint,
        rev: rev,
      );
    } else if (_boundVaultId != null && _boundVaultId!.isNotEmpty) {
      await _syncVaultHeadless(
        vaultId: _boundVaultId!,
        forcePull: true,
      );
    }
  }

  Future<void> _pushIfNeeded({bool force = false}) async {
    if (_pushInFlight) {
      _dirty = true;
      return;
    }
    if (_pullInFlight) {
      _pushDebounceTimer?.cancel();
      _pushDebounceTimer = Timer(_pushDebounce, () {
        unawaited(_pushIfNeeded(force: force));
      });
      return;
    }
    if (!_dirty && !force) return;
    if (!isEnabled) return;
    if (_session.state != VaultFlowState.unlocked) return;
    final vaultId = VaultPaths.activeVaultId;
    if (vaultId == null || vaultId.isEmpty) return;
    // Libreta nueva / cambio de vault: no reutilizar rutas de otra libreta.
    if (_boundVaultId != vaultId) {
      _boundVaultId = vaultId;
      _resetBoundVaultCaches();
      await _refreshRemoteMetaOnce();
    }

    _dirty = false;
    _pushInFlight = true;
    try {
      final packKey = await _resolvePackKeyQuietly();
      if (packKey == null) return;

      final raw = await _session.exportSyncSnapshotBytes();
      if (raw == null || raw.isEmpty) return;

      final pack = VaultSyncPack.decodeFlexible(raw);
      final fp = VaultSyncMergeEngine.payloadFingerprintShort(pack.payload);

      if (fp == _lastPushedFingerprint && !force) {
        return;
      }
      // force con mismo fp: solo omitir si no estamos reparando blobs rotos.
      if (fp == _lastPushedFingerprint &&
          force &&
          _cachedRemoteBlobIds.isNotEmpty &&
          fp != _pullBrokenFingerprint) {
        _setStatus('idle');
        return;
      }

      _setStatus('pushing');
      _lastError = null;
      _setTransferProgress(0, 0, 0);
      AppLogger.debug(
        'push',
        tag: 'cloud_sync',
        context: {
          'vaultId': vaultId,
          'fp': fp,
          'prevFp': _lastPushedFingerprint,
          'pages': pack.payload.pages.length,
          'format': 'v2',
        },
      );

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final vaultKey = packKey;
      final accountKey = await resolveAccountProfilePackKeyQuietly();
      final wireKey = accountKey ?? vaultKey;
      final packKeyKind = accountKey != null ? 'account' : 'vault';
      final wrapB64 = await _uploadBootstrapAfterPush(
        uid: user.uid,
        vaultId: vaultId,
      );

      final result = await pushDeviceSyncIncremental(
        uid: user.uid,
        vaultId: vaultId,
        pack: pack,
        packKey: wireKey,
        contentFingerprint: fp,
        deviceId: _settings.syncDeviceId,
        deviceName: _settings.syncDeviceName,
        previousBlobIds: _cachedRemoteBlobIds,
        oldManifestPath: _cachedManifestPath,
        oldManifestSize: _cachedManifestSize,
        oldPackPath: _cachedPackPath,
        oldPackSize: _cachedPackSize,
        displayName: pack.payload.displayName,
        vaultMode: _session.vaultUsesEncryption ? 'encrypted' : 'plain',
        packKeyKind: packKeyKind,
        dekAccountWrapB64: wrapB64 ?? '',
        onProgress: (done, total, fraction) {
          _setTransferProgress(fraction, done, total);
        },
      );

      _lastPushedFingerprint = fp;
      _lastAppliedFingerprint = fp;
      _pullBrokenFingerprint = '';
      _cachedManifestPath = result.manifestPath;
      _cachedManifestSize = result.manifestSizeBytes;
      _cachedRemoteBlobIds = result.blobIds;
      _cachedPackPath = '';
      _cachedPackSize = 0;
      _lastNotifiedError = '';
      _lastError = null;
      if (result.rev > _lastRemoteRev) _lastRemoteRev = result.rev;
      _lastSyncSuccessMs = DateTime.now().millisecondsSinceEpoch;
      await _settings.setSyncLastSuccessMs(_lastSyncSuccessMs);
      await _persistActiveAck(
        fingerprint: fp,
        rev: _lastRemoteRev,
        successMs: _lastSyncSuccessMs,
      );
      AppLogger.debug(
        'push ok',
        tag: 'cloud_sync',
        context: {
          'fp': fp,
          'blobs': result.blobIds.length,
          'manifestBytes': result.manifestSizeBytes,
        },
      );
      _setTransferProgress(null, 0, 0);
      _setStatus('idle');
      notifyListeners();
      if (!folioFirestoreSupported) _burstPoll();
    } catch (e, st) {
      AppLogger.error(
        'cloud device sync push failed',
        tag: 'cloud_sync',
        error: e,
        stackTrace: st,
      );
      _dirty = true;
      _lastError = '$e';
      _setTransferProgress(null, 0, 0);
      _setStatus('error');
      _notifyErrorOnce('push', e);
    } finally {
      _pushInFlight = false;
      if (_dirty) {
        _pushDebounceTimer?.cancel();
        _pushDebounceTimer = Timer(_pushDebounce, () {
          unawaited(_pushIfNeeded());
        });
      }
      final pending = _pendingRemoteMeta;
      if (pending != null) {
        _pendingRemoteMeta = null;
        unawaited(_onRemoteMeta(pending));
      }
    }
  }

  void _burstPoll() {
    const delays = [
      Duration(seconds: 1),
      Duration(seconds: 2),
      Duration(seconds: 4),
    ];
    for (final delay in delays) {
      Timer(delay, () => unawaited(_refreshRemoteMetaOnce()));
    }
  }

  Future<void> _pullAndMerge({
    required String packStoragePath,
    required String manifestStoragePath,
    required int syncFormatVersion,
    required String fingerprint,
    required int rev,
  }) async {
    if (_pullInFlight) return;
    if (fingerprint == _lastAppliedFingerprint) return;
    if (fingerprint.isNotEmpty && fingerprint == _pullBrokenFingerprint) {
      // Manifiesto remoto roto (blobs 404): reparar empujando lo local.
      _dirty = true;
      unawaited(_pushIfNeeded(force: true));
      return;
    }

    _pullInFlight = true;
    _setStatus('pulling');
    _lastError = null;
    _setTransferProgress(0, 0, 0);
    AppLogger.debug(
      'pull',
      tag: 'cloud_sync',
      context: {
        'rev': rev,
        'fp': fingerprint,
        'format': syncFormatVersion,
      },
    );
    try {
      final vaultKey = await _resolvePackKeyQuietly();
      final accountKey = await resolveAccountProfilePackKeyQuietly();
      if (vaultKey == null && accountKey == null) {
        _setStatus('idle');
        return;
      }
      final wireKeys = <SecretKey?>[accountKey, vaultKey];

      late final Uint8List plain;
      if (syncFormatVersion >= 2 && manifestStoragePath.isNotEmpty) {
        plain = await _decryptWirePack(
          keys: wireKeys,
          decryptWith: (key) async {
            final rebuilt = await pullDeviceSyncIncremental(
              manifestStoragePath: manifestStoragePath,
              packKey: key,
              onProgress: (done, total, fraction) {
                _setTransferProgress(fraction, done, total);
              },
            );
            _cachedRemoteBlobIds = rebuilt.blobIds;
            return rebuilt.packBytes;
          },
        );
        _cachedManifestPath = manifestStoragePath;
      } else {
        final cipher = await folioStorageGetData(
          FirebaseStorage.instance.ref().child(packStoragePath),
          _maxPackBytes,
        );
        if (cipher == null || cipher.isEmpty) {
          throw StateError('Empty sync pack download');
        }
        plain = await _decryptWirePack(
          keys: wireKeys,
          decryptWith: (key) =>
              cloudPackDecryptBytes(blob: cipher, packKey: key),
        );
        _cachedPackPath = packStoragePath;
      }

      final applied = await _session.applySyncSnapshotBytes(
        plain,
        'cloud:${_settings.syncDeviceId}',
      );
      if (!applied.ok) {
        throw StateError('applySyncSnapshotBytes failed');
      }

      _lastAppliedFingerprint = fingerprint;
      _pullBrokenFingerprint = '';
      if (rev > _lastRemoteRev) _lastRemoteRev = rev;
      _lastNotifiedError = '';
      _lastError = null;
      _lastSyncSuccessMs = DateTime.now().millisecondsSinceEpoch;
      await _settings.setSyncLastSuccessMs(_lastSyncSuccessMs);
      await _persistActiveAck(
        fingerprint: fingerprint,
        rev: _lastRemoteRev,
        successMs: _lastSyncSuccessMs,
      );

      if (applied.changed) {
        AppLogger.debug(
          'pull merged local changes; schedule push',
          tag: 'cloud_sync',
        );
        _dirty = true;
        _pushDebounceTimer?.cancel();
        _pushDebounceTimer = Timer(_pushDebounce, () {
          unawaited(_pushIfNeeded());
        });
      } else {
        _lastPushedFingerprint = fingerprint;
        AppLogger.debug(
          'pull ok (sin cambios locales)',
          tag: 'cloud_sync',
        );
      }
      _setTransferProgress(null, 0, 0);
      _setStatus('idle');
      notifyListeners();
    } catch (e, st) {
      AppLogger.error(
        'cloud device sync pull failed',
        tag: 'cloud_sync',
        error: e,
        stackTrace: st,
      );
      final msg = '$e';
      final missingBlob = msg.contains('blob missing') ||
          msg.contains('status=404') ||
          msg.contains('Not Found');
      if (missingBlob && fingerprint.isNotEmpty) {
        _pullBrokenFingerprint = fingerprint;
        // Caché de blobs inválida: forzar re-subida completa al reparar.
        _cachedRemoteBlobIds = {};
        _lastPushedFingerprint = '';
        AppLogger.warn(
          'pull: remote blobs missing; will repair with local push',
          tag: 'cloud_sync',
          context: {'fp': fingerprint},
        );
        _dirty = true;
        unawaited(_pushIfNeeded(force: true));
      }
      _lastError = msg;
      _setTransferProgress(null, 0, 0);
      _setStatus(missingBlob ? 'idle' : 'error');
      if (!missingBlob) _notifyErrorOnce('pull', e);
    } finally {
      _pullInFlight = false;
    }
  }

  Future<void> _warmBlobIdCache(String manifestPath) async {
    try {
      final packKey = await _resolvePackKeyQuietly();
      if (packKey == null) return;
      final ids = await peekDeviceSyncManifestBlobIds(
        manifestStoragePath: manifestPath,
        packKey: packKey,
      );
      if (ids.isEmpty) return;
      _cachedRemoteBlobIds = ids;
      _cachedManifestPath = manifestPath;
    } catch (e) {
      AppLogger.warn(
        'device sync blob cache warm failed',
        tag: 'cloud_sync',
        context: {'error': '$e'},
      );
    }
  }

  Future<void> _ensureAckLoaded() async {
    if (_ackLoaded) return;
    await _ackStore.load();
    _ackLoaded = true;
  }

  Future<void> _persistActiveAck({
    required String fingerprint,
    required int rev,
    required int successMs,
  }) async {
    final vaultId = _boundVaultId ?? VaultPaths.activeVaultId;
    if (vaultId == null || vaultId.isEmpty) return;
    await _ensureAckLoaded();
    await _ackStore.saveAck(
      vaultId: vaultId,
      fingerprint: fingerprint,
      rev: rev,
      successMs: successMs,
    );
    unawaited(refreshAllVaultStatuses());
  }

  /// Consulta meta cloud de todas las libretas locales y actualiza el resumen.
  Future<void> refreshAllVaultStatuses() async {
    if (!isEnabled) {
      _vaultStatuses = const [];
      notifyListeners();
      return;
    }
    if (_vaultStatusRefreshInFlight) return;
    _vaultStatusRefreshInFlight = true;
    try {
      await _ensureAckLoaded();
      final entries = await _session.listVaultEntries();
      if (entries.isEmpty) {
        _vaultStatuses = const [];
        notifyListeners();
        return;
      }
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final activeId = VaultPaths.activeVaultId ?? '';
      final out = <DeviceSyncVaultStatus>[];
      for (final e in entries) {
        out.add(await _statusForVault(
          uid: uid,
          entry: e,
          isActive: e.id == activeId,
        ));
      }
      _vaultStatuses = out;
      notifyListeners();
    } catch (e, st) {
      AppLogger.warn(
        'refreshAllVaultStatuses failed',
        tag: 'cloud_sync',
        context: {'error': '$e', 'stack': '$st'},
      );
    } finally {
      _vaultStatusRefreshInFlight = false;
    }
  }

  Future<DeviceSyncVaultStatus> _statusForVault({
    required String uid,
    required VaultEntry entry,
    required bool isActive,
  }) async {
    if (isActive) {
      if (isSyncing) {
        return DeviceSyncVaultStatus(
          vaultId: entry.id,
          displayName: entry.displayName,
          phase: DeviceSyncVaultPhase.syncing,
          isActive: true,
          lastSuccessMs: _lastSyncSuccessMs,
          remoteRev: _lastRemoteRev,
        );
      }
      if (_status == 'error') {
        return DeviceSyncVaultStatus(
          vaultId: entry.id,
          displayName: entry.displayName,
          phase: DeviceSyncVaultPhase.error,
          isActive: true,
          lastSuccessMs: _lastSyncSuccessMs,
          remoteRev: _lastRemoteRev,
          detail: _lastError,
        );
      }
      if (_lastSyncSuccessMs > 0 ||
          _lastAppliedFingerprint.isNotEmpty) {
        return DeviceSyncVaultStatus(
          vaultId: entry.id,
          displayName: entry.displayName,
          phase: DeviceSyncVaultPhase.synced,
          isActive: true,
          lastSuccessMs: _lastSyncSuccessMs,
          remoteRev: _lastRemoteRev,
        );
      }
    }

    Map<String, dynamic>? data;
    try {
      if (folioFirestoreSupported) {
        final snap = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('vaultSync')
            .doc(entry.id)
            .get();
        data = snap.data();
      } else {
        data = await folioFirestoreRestGetDocument(
          'users/$uid/vaultSync/${entry.id}',
        );
      }
    } catch (_) {
      data = null;
    }

    final fp = '${data?['contentFingerprint'] ?? ''}'.trim();
    final path = '${data?['packStoragePath'] ?? ''}'.trim();
    final manifest = '${data?['manifestStoragePath'] ?? ''}'.trim();
    final rev = _asInt(data?['rev']);
    final hasCloud = fp.isNotEmpty && (path.isNotEmpty || manifest.isNotEmpty);
    final ack = _ackStore.forVault(entry.id);

    if (!hasCloud) {
      return DeviceSyncVaultStatus(
        vaultId: entry.id,
        displayName: entry.displayName,
        phase: DeviceSyncVaultPhase.emptyCloud,
        isActive: isActive,
        lastSuccessMs: ack?.successMs ?? 0,
        remoteRev: rev,
      );
    }

    if (ack != null &&
        (ack.fingerprint == fp || (ack.rev > 0 && ack.rev >= rev))) {
      return DeviceSyncVaultStatus(
        vaultId: entry.id,
        displayName: entry.displayName,
        phase: DeviceSyncVaultPhase.synced,
        isActive: isActive,
        lastSuccessMs: ack.successMs,
        remoteRev: rev,
      );
    }

    // Sin clave local: adoptar DEK desde bootstrap remoto (sin desbloquear).
    var packKey = await _headless.resolvePackKey(entry.id);
    packKey ??= await adoptDeviceSyncPackKeyFromBootstrap(
      vaultId: entry.id,
      keyCache: _headless.keyCache,
      headless: _headless,
    );
    if (packKey == null) {
      // Aún no hay wrap en la nube: pendiente de sync del origen, no "desbloquea".
      return DeviceSyncVaultStatus(
        vaultId: entry.id,
        displayName: entry.displayName,
        phase: DeviceSyncVaultPhase.pending,
        isActive: isActive,
        lastSuccessMs: ack?.successMs ?? 0,
        remoteRev: rev,
      );
    }

    return DeviceSyncVaultStatus(
      vaultId: entry.id,
      displayName: entry.displayName,
      phase: DeviceSyncVaultPhase.pending,
      isActive: isActive,
      lastSuccessMs: ack?.successMs ?? 0,
      remoteRev: rev,
    );
  }

  /// Sincroniza todas las libretas locales (headless si están bloqueadas).
  /// Antes, descarga libretas nuevas que solo existan en la nube.
  Future<void> syncAllVaults() async {
    if (!isEnabled) return;
    if (_allVaultsSyncInFlight) return;
    _allVaultsSyncInFlight = true;
    try {
      await _ensureAckLoaded();
      await _discoverAndMaterializeRemoteVaults();
      final entries = await _session.listVaultEntries();
      AppLogger.info(
        'syncAllVaults start',
        tag: 'cloud_sync',
        context: {'vaultCount': entries.length},
      );
      var headless = 0;
      var active = 0;
      for (final e in entries) {
        try {
          // Asegura DEK/clave sin desbloquear (bootstrap de cuenta).
          await adoptDeviceSyncPackKeyFromBootstrap(
            vaultId: e.id,
            keyCache: _headless.keyCache,
            headless: _headless,
          );
          final activeId = VaultPaths.activeVaultId;
          if (e.id == activeId && _session.isUnlocked) {
            active++;
            _dirty = true;
            await _pushIfNeeded(force: true);
            await _refreshRemoteMetaOnce();
          } else {
            headless++;
            await _syncVaultHeadless(vaultId: e.id);
          }
        } catch (err, st) {
          AppLogger.error(
            'syncAllVaults vault failed',
            tag: 'cloud_sync',
            error: err,
            stackTrace: st,
            context: {'vaultId': e.id},
          );
        }
      }
      await refreshAllVaultStatuses();
      AppLogger.info(
        'syncAllVaults done',
        tag: 'cloud_sync',
        context: {
          'vaultCount': entries.length,
          'activeSynced': active,
          'headlessSynced': headless,
        },
      );
    } finally {
      _allVaultsSyncInFlight = false;
    }
  }

  Future<void> _discoverAndMaterializeRemoteVaults() async {
    try {
      final remote = await listRemoteDeviceSyncVaults();
      if (remote.isEmpty) return;
      final local = await _session.listVaultEntries();
      final localIds = {for (final e in local) e.id};
      var added = 0;
      for (final r in remote) {
        if (!r.hasCloudPack) continue;
        if (localIds.contains(r.vaultId)) continue;
        final ok = await materializeRemoteDeviceSyncVault(
          remote: r,
          headless: _headless,
          keyCache: _headless.keyCache,
        );
        if (ok) {
          added++;
          localIds.add(r.vaultId);
        }
      }
      if (added > 0) {
        AppLogger.info(
          'discovered remote vaults materialized',
          tag: 'cloud_sync',
          context: {'added': added},
        );
        // El registry cambió: la UI (selector de libretas) debe refrescarse.
        _session.notifyListeners();
      }
    } catch (e, st) {
      AppLogger.warn(
        'discover remote vaults failed',
        tag: 'cloud_sync',
        context: {'error': '$e'},
      );
      AppLogger.debug(
        'discover remote vaults stack',
        tag: 'cloud_sync',
        context: {'stack': '$st'},
      );
    }
  }

  Future<void> _syncVaultHeadless({
    required String vaultId,
    bool forcePull = false,
  }) async {
    try {
      await _syncVaultHeadlessBody(
        vaultId: vaultId,
        forcePull: forcePull,
      );
    } catch (e, st) {
      AppLogger.error(
        'headless sync failed',
        tag: 'cloud_sync',
        error: e,
        stackTrace: st,
        context: {'vaultId': vaultId},
      );
      _lastError = '$e';
      _setStatus('error');
    }
  }

  Future<void> _syncVaultHeadlessBody({
    required String vaultId,
    bool forcePull = false,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    var packKey = await _headless.resolvePackKey(vaultId);
    packKey ??= await adoptDeviceSyncPackKeyFromBootstrap(
      vaultId: vaultId,
      keyCache: _headless.keyCache,
      headless: _headless,
    );
    // Meta puede traer el wrap aunque Storage aún no tenga el fichero.
    Map<String, dynamic>? data;
    try {
      if (folioFirestoreSupported) {
        final snap = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('vaultSync')
            .doc(vaultId)
            .get();
        data = snap.data();
      } else {
        data = await folioFirestoreRestGetDocument(
          'users/$uid/vaultSync/$vaultId',
        );
      }
    } catch (e) {
      AppLogger.warn(
        'headless meta failed',
        tag: 'cloud_sync',
        context: {'vaultId': vaultId, 'error': '$e'},
      );
      return;
    }
    packKey ??= await _vaultKeyFromMetaWrap(data, vaultId: vaultId);

    final accountKey = await resolveAccountProfilePackKeyQuietly();
    if (packKey == null && accountKey == null) {
      AppLogger.debug(
        'headless skip: no pack key (bootstrap account wrap aún no disponible)',
        tag: 'cloud_sync',
        context: {'vaultId': vaultId},
      );
      return;
    }

    final remoteFp = '${data?['contentFingerprint'] ?? ''}'.trim();
    final packPath = '${data?['packStoragePath'] ?? ''}'.trim();
    final manifestPath = '${data?['manifestStoragePath'] ?? ''}'.trim();
    final formatVersion = _asInt(data?['syncFormatVersion']);
    final rev = _asInt(data?['rev']);
    final deviceId = '${data?['deviceId'] ?? ''}'.trim();
    final packKeyKind = '${data?['packKeyKind'] ?? ''}'.trim();
    final isV2 = formatVersion >= 2 && manifestPath.isNotEmpty;
    final hasRemote =
        remoteFp.isNotEmpty && (packPath.isNotEmpty || manifestPath.isNotEmpty);
    final ack = _ackStore.forVault(vaultId);
    final remoteFromSelf =
        deviceId.isNotEmpty && deviceId == _settings.syncDeviceId;

    // Pull si remoto es más nuevo (u obligado).
    final shouldPull = hasRemote &&
        !remoteFromSelf &&
        (forcePull ||
            ack == null ||
            (ack.fingerprint != remoteFp &&
                (ack.rev <= 0 || rev > ack.rev)));

    if (shouldPull) {
      _setStatus('pulling');
      try {
        final wireKeys = packKeyKind == 'vault'
            ? <SecretKey?>[packKey, accountKey]
            : <SecretKey?>[accountKey, packKey];
        late final Uint8List plain;
        if (isV2) {
          plain = await _decryptWirePack(
            keys: wireKeys,
            decryptWith: (key) async {
              final rebuilt = await pullDeviceSyncIncremental(
                manifestStoragePath: manifestPath,
                packKey: key,
              );
              return rebuilt.packBytes;
            },
          );
        } else {
          final cipher = await folioStorageGetData(
            FirebaseStorage.instance.ref().child(packPath),
            _maxPackBytes,
          );
          if (cipher == null || cipher.isEmpty) {
            throw StateError('Empty sync pack');
          }
          plain = await _decryptWirePack(
            keys: wireKeys,
            decryptWith: (key) =>
                cloudPackDecryptBytes(blob: cipher, packKey: key),
          );
        }
        // Tras pull con clave de cuenta, reintentar adoptar DEK local.
        packKey ??= await adoptDeviceSyncPackKeyFromBootstrap(
          vaultId: vaultId,
          keyCache: _headless.keyCache,
          headless: _headless,
        );
        packKey ??= await _vaultKeyFromMetaWrap(data, vaultId: vaultId);
        if (packKey == null) {
          throw StateError('headless apply needs vault DEK after wire pull');
        }
        final applied = await _headless.applyRemotePack(
          vaultId: vaultId,
          packKey: packKey,
          remotePackBytes: plain,
        );
        if (!applied.ok) throw StateError('headless apply failed');
        await _ackStore.saveAck(
          vaultId: vaultId,
          fingerprint: remoteFp,
          rev: rev,
          successMs: DateTime.now().millisecondsSinceEpoch,
        );
        AppLogger.debug(
          'headless pull ok',
          tag: 'cloud_sync',
          context: {
            'vaultId': vaultId,
            'changed': applied.changed,
          },
        );
      } catch (e, st) {
        AppLogger.error(
          'headless pull failed',
          tag: 'cloud_sync',
          error: e,
          stackTrace: st,
        );
        final msg = '$e';
        final missingBlob = msg.contains('blob missing') ||
            msg.contains('status=404') ||
            msg.contains('Not Found');
        if (!missingBlob) {
          _lastError = msg;
          _setStatus('error');
          return;
        }
        AppLogger.warn(
          'headless pull: missing blobs, will push local',
          tag: 'cloud_sync',
          context: {'vaultId': vaultId},
        );
      }
    }

    if (packKey == null) {
      _setStatus('idle');
      return;
    }

    // Push si el local no está reconocido como el remoto actual.
    final localBytes = await _headless.exportPackBytes(vaultId, packKey);
    if (localBytes == null || localBytes.isEmpty) {
      _setStatus('idle');
      return;
    }
    final pack = VaultSyncPack.decodeFlexible(localBytes);
    final localFp =
        VaultSyncMergeEngine.payloadFingerprintShort(pack.payload);
    if (localFp == remoteFp && hasRemote) {
      await _ackStore.saveAck(
        vaultId: vaultId,
        fingerprint: localFp,
        rev: rev,
        successMs: DateTime.now().millisecondsSinceEpoch,
      );
      _setStatus('idle');
      return;
    }

    _setStatus('pushing');
    try {
      final prevIds = <String>{};
      final wireKey = accountKey ?? packKey;
      final wrapB64 = await _uploadBootstrapAfterPush(uid: uid, vaultId: vaultId);
      final result = await pushDeviceSyncIncremental(
        uid: uid,
        vaultId: vaultId,
        pack: pack,
        packKey: wireKey,
        contentFingerprint: localFp,
        deviceId: _settings.syncDeviceId,
        deviceName: _settings.syncDeviceName,
        previousBlobIds: prevIds,
        oldManifestPath: isV2 ? manifestPath : '',
        oldManifestSize: isV2 ? _asInt(data?['manifestSizeBytes']) : 0,
        oldPackPath: !isV2 ? packPath : '',
        oldPackSize: !isV2 ? _asInt(data?['packSizeBytes']) : 0,
        displayName: pack.payload.displayName,
        vaultMode: await _headless.isPlain(vaultId) ? 'plain' : 'encrypted',
        packKeyKind: accountKey != null ? 'account' : 'vault',
        dekAccountWrapB64: wrapB64 ?? '',
      );
      await _ackStore.saveAck(
        vaultId: vaultId,
        fingerprint: localFp,
        rev: result.rev,
        successMs: DateTime.now().millisecondsSinceEpoch,
      );
      AppLogger.debug(
        'headless push ok',
        tag: 'cloud_sync',
        context: {
          'vaultId': vaultId,
          'fp': localFp,
        },
      );
      _setStatus('idle');
    } catch (e, st) {
      AppLogger.error(
        'headless push failed',
        tag: 'cloud_sync',
        error: e,
        stackTrace: st,
      );
      _lastError = '$e';
      _setStatus('error');
    }
  }

  Future<Uint8List> _decryptWirePack({
    required List<SecretKey?> keys,
    required Future<Uint8List> Function(SecretKey key) decryptWith,
  }) async {
    Object? lastError;
    for (final key in keys) {
      if (key == null) continue;
      try {
        return await decryptWith(key);
      } catch (e) {
        lastError = e;
      }
    }
    throw StateError('device-sync decrypt failed: $lastError');
  }

  Future<SecretKey?> _vaultKeyFromMetaWrap(
    Map<String, dynamic>? data, {
    String? vaultId,
  }) async {
    final b64 = '${data?['dekAccountWrapB64'] ?? ''}'.trim();
    if (b64.isEmpty) return null;
    final accountKey = await resolveAccountProfilePackKeyQuietly();
    if (accountKey == null) return null;
    try {
      final wrap = base64Decode(b64);
      final clear = await cloudPackDecryptBytes(blob: wrap, packKey: accountKey);
      if (clear.length != VaultCrypto.dekLength) return null;
      final id = vaultId ?? _boundVaultId ?? VaultPaths.activeVaultId;
      if (id != null && id.isNotEmpty) {
        await _headless.keyCache.save(id, clear);
      }
      return await VaultCrypto.dekFromBytes(clear);
    } catch (_) {
      return null;
    }
  }

  Future<SecretKey?> _resolvePackKeyQuietly() async {
    if (_session.state != VaultFlowState.unlocked) return null;
    final vaultId = VaultPaths.activeVaultId;
    if (vaultId == null || vaultId.isEmpty) return null;
    if (_session.vaultUsesEncryption) {
      if (_session.cloudPackRestoreDekMaterial == null) {
        AppLogger.warn(
          'device sync skipped: encrypted vault without DEK in memory',
          tag: 'cloud_sync',
        );
        return null;
      }
      try {
        return await _session.cloudPackEncryptionKey();
      } catch (e) {
        AppLogger.warn(
          'device sync pack key unavailable',
          tag: 'cloud_sync',
          context: {'error': '$e'},
        );
        return null;
      }
    }
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) return null;
    try {
      final key = await DeviceSyncKeyCache.plainPackKey(
        uid: uid,
        vaultId: vaultId,
      );
      final raw = await key.extractBytes();
      await _headless.keyCache.save(vaultId, raw);
      return key;
    } catch (e) {
      AppLogger.warn(
        'device sync plain pack key unavailable',
        tag: 'cloud_sync',
        context: {'error': '$e'},
      );
      return null;
    }
  }

  Future<String?> _uploadBootstrapAfterPush({
    required String uid,
    required String vaultId,
  }) async {
    try {
      final isPlain = await _headless.isPlain(vaultId);
      List<int>? dek;
      if (!isPlain) {
        if (VaultPaths.activeVaultId == vaultId && _session.isUnlocked) {
          dek = _session.cloudPackRestoreDekMaterial;
        }
        dek ??= await _headless.keyCache.read(vaultId);
      }
      return await uploadDeviceSyncBootstrap(
        uid: uid,
        vaultId: vaultId,
        encrypted: !isPlain,
        dekBytes: dek,
      );
    } catch (e) {
      AppLogger.warn(
        'device sync bootstrap upload failed',
        tag: 'cloud_sync',
        context: {'vaultId': vaultId, 'error': '$e'},
      );
      return null;
    }
  }

  void _notifyErrorOnce(String phase, Object e) {
    final msg = '$e'.trim();
    if (msg.contains('contraseña de la libreta') ||
        (msg.contains('restore') && msg.contains('wrap'))) {
      return;
    }
    final key = '$phase|$msg';
    if (key == _lastNotifiedError) return;
    _lastNotifiedError = key;
    _onEvent?.call('Folio Cloud sync $phase failed: $e');
  }

  void _setStatus(String s) {
    if (_status == s) return;
    _status = s;
    notifyListeners();
    if (s == 'idle' || s == 'error') {
      unawaited(refreshAllVaultStatuses());
    }
  }

  void _setTransferProgress(double? fraction, int done, int total) {
    _transferProgress = fraction;
    _blobsCompleted = done;
    _blobsTotal = total;
    notifyListeners();
  }

  static int _asInt(Object? v) {
    if (v is num) return v.toInt();
    return int.tryParse('$v') ?? 0;
  }
}
