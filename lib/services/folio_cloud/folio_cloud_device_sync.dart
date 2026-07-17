import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../../app/app_settings.dart';
import '../../data/vault_paths.dart';
import '../../session/vault_session.dart';
import '../app_logger.dart';
import '../folio_firestore_support.dart';
import '../sync/vault_sync_merge.dart';
import '../sync/vault_sync_pack.dart';
import 'folio_cloud_callable.dart';
import 'folio_cloud_entitlements.dart';
import 'folio_cloud_pack_crypto.dart';
import 'folio_firestore_rest.dart';
import 'folio_storage_transport.dart';

/// Sincronización multi-dispositivo vía Folio Cloud (pack cifrado + señal Firestore).
///
/// Solo sube cuando el fingerprint del contenido local cambia. Logs mínimos.
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

  static const Duration _pushDebounce = Duration(seconds: 3);
  static const Duration _pollInterval = Duration(seconds: 10);
  static const int _maxPackBytes = 80 * 1024 * 1024;

  Timer? _pushDebounceTimer;
  Timer? _pollTimer;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _metaSub;
  bool _pushInFlight = false;
  bool _pullInFlight = false;
  bool _dirty = false;
  String _lastAppliedFingerprint = '';
  String _lastPushedFingerprint = '';
  String? _boundVaultId;
  int _lastRemoteRev = 0;
  /// Cache local para no llamar a `folioGetDeviceSyncMeta` en cada push.
  String _cachedPackPath = '';
  int _cachedPackSize = 0;
  String _status = '';

  String get statusMessage => _status;
  int get lastRemoteRev => _lastRemoteRev;

  bool get isEnabled =>
      _settings.cloudDeviceSyncEnabled &&
      _entitlements.snapshot.canUseCloudBackup &&
      Firebase.apps.isNotEmpty &&
      FirebaseAuth.instance.currentUser != null;

  void onLocalSnapshotPersisted() {
    if (!isEnabled) return;
    if (_session.state != VaultFlowState.unlocked) return;
    _dirty = true;
    _pushDebounceTimer?.cancel();
    _pushDebounceTimer = Timer(_pushDebounce, () {
      unawaited(_pushIfNeeded());
    });
  }

  Future<void> start() async {
    await stopWatching();
    if (!isEnabled) return;
    final vaultId = VaultPaths.activeVaultId;
    if (vaultId == null || vaultId.isEmpty) return;
    _boundVaultId = vaultId;
    debugPrint(
      '[cloud_sync] start vaultId=$vaultId device=${_settings.syncDeviceId}',
    );
    await _refreshRemoteMetaOnce();
    if (folioFirestoreSupported) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      _metaSub = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('vaultSync')
          .doc(vaultId)
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
    _pollTimer = Timer.periodic(_pollInterval, (_) {
      unawaited(_refreshRemoteMetaOnce());
    });
  }

  Future<void> stopWatching() async {
    await _metaSub?.cancel();
    _metaSub = null;
    _pollTimer?.cancel();
    _pollTimer = null;
    if (_boundVaultId != null) {
      debugPrint('[cloud_sync] stop vaultId=$_boundVaultId');
    }
    _boundVaultId = null;
  }

  Future<void> disposeController() async {
    _pushDebounceTimer?.cancel();
    await stopWatching();
  }

  @override
  void dispose() {
    unawaited(disposeController());
    super.dispose();
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
    if (_session.state != VaultFlowState.unlocked) return;

    final deviceId = '${data['deviceId'] ?? ''}'.trim();
    final fingerprint = '${data['contentFingerprint'] ?? ''}'.trim();
    final packPath = '${data['packStoragePath'] ?? ''}'.trim();
    final packSize = _asInt(data['packSizeBytes']);
    final revRaw = data['rev'];
    final rev = revRaw is num
        ? revRaw.toInt()
        : int.tryParse('$revRaw') ?? 0;

    if (packPath.isEmpty || fingerprint.isEmpty) return;

    // Actualiza cache de pack remoto (sirve para el próximo push local).
    if (packPath.isNotEmpty) {
      _cachedPackPath = packPath;
      if (packSize > 0) _cachedPackSize = packSize;
    }

    if (deviceId.isNotEmpty && deviceId == _settings.syncDeviceId) {
      _lastPushedFingerprint = fingerprint;
      _lastAppliedFingerprint = fingerprint;
      _lastRemoteRev = rev > _lastRemoteRev ? rev : _lastRemoteRev;
      return;
    }
    if (fingerprint == _lastAppliedFingerprint) return;
    if (rev > 0 &&
        rev <= _lastRemoteRev &&
        fingerprint == _lastAppliedFingerprint) {
      return;
    }

    await _pullAndMerge(
      packStoragePath: packPath,
      fingerprint: fingerprint,
      rev: rev,
    );
  }

  Future<void> _pushIfNeeded() async {
    if (_pushInFlight) {
      _dirty = true;
      return;
    }
    if (!_dirty) return;
    if (!isEnabled) return;
    if (_session.state != VaultFlowState.unlocked) return;
    final vaultId = VaultPaths.activeVaultId;
    if (vaultId == null || vaultId.isEmpty) return;

    _dirty = false;
    _pushInFlight = true;
    try {
      final raw = await _session.exportSyncSnapshotBytes();
      if (raw == null || raw.isEmpty) return;

      final pack = VaultSyncPack.decodeFlexible(raw);
      final fp = VaultSyncMergeEngine.payloadFingerprintShort(pack.payload);

      // Sin cambio de contenido → no Storage ni callables.
      if (fp == _lastPushedFingerprint) {
        return;
      }

      _setStatus('pushing');
      debugPrint(
        '[cloud_sync] push vaultId=$vaultId fp=$fp '
        '(prev=$_lastPushedFingerprint) pages=${pack.payload.pages.length}',
      );

      final packKey = await _session.cloudPackEncryptionKey();
      final cipher = await cloudPackEncryptBytes(
        plain: raw,
        packKey: packKey,
      );
      if (cipher.length > _maxPackBytes) {
        throw StateError('Sync pack too large (${cipher.length} bytes)');
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final oldPath = _cachedPackPath;
      final oldSize = _cachedPackSize;

      final stamp =
          DateTime.now().toUtc().toIso8601String().replaceAll(':', '-');
      final path =
          'users/${user.uid}/vaults/$vaultId/device-sync/packs/pack-$stamp.bin';
      await folioStoragePutData(
        FirebaseStorage.instance.ref().child(path),
        cipher,
      );

      final finalize = await callFolioHttpsCallable(
        'folioFinalizeDeviceSync',
        <String, dynamic>{
          'vaultId': vaultId,
          'packStoragePath': path,
          'packSizeBytes': cipher.length,
          'contentFingerprint': fp,
          'deviceId': _settings.syncDeviceId,
          'deviceName': _settings.syncDeviceName,
          if (oldPath.isNotEmpty) 'oldPackStoragePath': oldPath,
          if (oldSize > 0) 'oldPackSizeBytes': oldSize,
        },
      );

      _lastPushedFingerprint = fp;
      _lastAppliedFingerprint = fp;
      _cachedPackPath = path;
      _cachedPackSize = cipher.length;
      if (finalize is Map) {
        final rev = _asInt(finalize['rev']);
        if (rev > _lastRemoteRev) _lastRemoteRev = rev;
      }
      await _settings.setSyncLastSuccessMs(
        DateTime.now().millisecondsSinceEpoch,
      );
      debugPrint('[cloud_sync] push ok fp=$fp bytes=${cipher.length}');
      _setStatus('idle');
      notifyListeners();
    } catch (e, st) {
      AppLogger.error(
        'cloud device sync push failed',
        tag: 'cloud_sync',
        error: e,
        stackTrace: st,
      );
      debugPrint('[cloud_sync] push FAILED: $e');
      _dirty = true;
      _setStatus('error');
      _onEvent?.call('Folio Cloud sync push failed: $e');
    } finally {
      _pushInFlight = false;
      if (_dirty) {
        _pushDebounceTimer?.cancel();
        _pushDebounceTimer = Timer(_pushDebounce, () {
          unawaited(_pushIfNeeded());
        });
      }
    }
  }

  Future<void> _pullAndMerge({
    required String packStoragePath,
    required String fingerprint,
    required int rev,
  }) async {
    if (_pullInFlight) return;
    // Evita re-descargar el mismo pack.
    if (fingerprint == _lastAppliedFingerprint) return;

    _pullInFlight = true;
    _setStatus('pulling');
    debugPrint('[cloud_sync] pull rev=$rev fp=$fingerprint');
    try {
      final packKey = await _session.cloudPackEncryptionKey();
      final cipher = await folioStorageGetData(
        FirebaseStorage.instance.ref().child(packStoragePath),
        _maxPackBytes,
      );
      if (cipher == null || cipher.isEmpty) {
        throw StateError('Empty sync pack download');
      }
      final plain = await cloudPackDecryptBytes(
        blob: cipher,
        packKey: packKey,
      );
      final applied = await _session.applySyncSnapshotBytes(
        plain,
        'cloud:${_settings.syncDeviceId}',
      );
      if (!applied.ok) {
        throw StateError('applySyncSnapshotBytes failed');
      }

      _lastAppliedFingerprint = fingerprint;
      if (rev > _lastRemoteRev) _lastRemoteRev = rev;
      _cachedPackPath = packStoragePath;
      await _settings.setSyncLastSuccessMs(
        DateTime.now().millisecondsSinceEpoch,
      );

      // Solo re-subir si el merge cambió el contenido local.
      if (applied.changed) {
        debugPrint('[cloud_sync] pull merged local changes → schedule push');
        _dirty = true;
        _pushDebounceTimer?.cancel();
        _pushDebounceTimer = Timer(_pushDebounce, () {
          unawaited(_pushIfNeeded());
        });
      } else {
        // Contenido ya igual: adoptamos el fp remoto como «pushed».
        _lastPushedFingerprint = fingerprint;
        debugPrint('[cloud_sync] pull ok (sin cambios locales)');
      }
      _setStatus('idle');
      notifyListeners();
    } catch (e, st) {
      AppLogger.error(
        'cloud device sync pull failed',
        tag: 'cloud_sync',
        error: e,
        stackTrace: st,
      );
      debugPrint('[cloud_sync] pull FAILED: $e');
      _setStatus('error');
      _onEvent?.call('Folio Cloud sync pull failed: $e');
    } finally {
      _pullInFlight = false;
    }
  }

  void _setStatus(String s) {
    if (_status == s) return;
    _status = s;
    notifyListeners();
  }

  static int _asInt(Object? v) {
    if (v is num) return v.toInt();
    return int.tryParse('$v') ?? 0;
  }
}
