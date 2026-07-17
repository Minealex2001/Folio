import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cryptography/cryptography.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../../app/app_settings.dart';
import '../../data/folio_settings_profile_format.dart';
import '../../data/vault_paths.dart';
import '../app_logger.dart';
import '../custom_icon_import_service.dart';
import '../folio_firestore_support.dart';
import '../settings/folio_app_profile_crypto.dart';
import '../settings/settings_profile_applier.dart';
import '../settings/settings_profile_builder.dart';
import 'folio_cloud_callable.dart';
import 'folio_cloud_entitlements.dart';
import 'folio_storage_transport.dart';

/// Sync de perfiles de ajustes (app + libreta) vía Folio Cloud.
class FolioCloudSettingsSyncController extends ChangeNotifier {
  FolioCloudSettingsSyncController({
    required AppSettings appSettings,
    required FolioCloudEntitlementsController entitlements,
    void Function(String message)? onEvent,
  }) : _settings = appSettings,
       _entitlements = entitlements,
       _onEvent = onEvent {
    _settings.addListener(_onSettingsChanged);
    _settings.onAppProfileChanged = markAppProfileDirty;
    _settings.onVaultProfileChanged = markVaultProfileDirty;
  }

  final AppSettings _settings;
  final FolioCloudEntitlementsController _entitlements;
  final void Function(String message)? _onEvent;
  final SettingsProfileBuilder _builder = const SettingsProfileBuilder();
  final SettingsProfileApplier _applier = const SettingsProfileApplier();
  final FolioAppProfileCrypto _crypto = FolioAppProfileCrypto();
  final CustomIconImportService _iconImport = CustomIconImportService();

  static const Duration _pushDebounce = Duration(seconds: 5);
  static const Duration _pollInterval = Duration(seconds: 8);
  static const int _maxPackBytes = 16 * 1024 * 1024;

  Timer? _appPushTimer;
  Timer? _vaultPushTimer;
  Timer? _pollTimer;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _metaSub;
  bool _appDirty = false;
  bool _pushInFlight = false;
  bool _pullInFlight = false;
  bool _suppressDirty = false;
  String _lastAppFp = '';
  int _lastAppRev = 0;
  String _status = '';
  bool _promptPending = false;
  String? _lastError;

  String get statusMessage => _status;
  bool get hasRemoteProfilePromptPending => _promptPending;
  int get lastAppRev => _lastAppRev;
  String? get lastError => _lastError;

  bool get isEnabled =>
      _settings.cloudAppProfileSyncEnabled &&
      _entitlements.snapshot.canUseCloudBackup &&
      Firebase.apps.isNotEmpty &&
      FirebaseAuth.instance.currentUser != null;

  void markAppProfileDirty() {
    if (_suppressDirty || !isEnabled) return;
    _appDirty = true;
    _appPushTimer?.cancel();
    _appPushTimer = Timer(_pushDebounce, () => unawaited(pushAppProfileNow()));
  }

  void markVaultProfileDirty(String vaultId) {
    if (_suppressDirty || !isEnabled) return;
    _vaultPushTimer?.cancel();
    _vaultPushTimer = Timer(
      _pushDebounce,
      () => unawaited(pushVaultProfileNow(vaultId)),
    );
  }

  void _onSettingsChanged() => markAppProfileDirty();

  Future<void> start() async {
    await stopWatching();
    if (!isEnabled) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null &&
        _settings.cloudAppProfileAckUid == uid &&
        _settings.cloudAppProfileAckFingerprint.isNotEmpty &&
        _lastAppFp.isEmpty) {
      _lastAppFp = _settings.cloudAppProfileAckFingerprint;
    }
    await _refreshMetaOnce(promptIfNewer: true);
    if (folioFirestoreSupported) {
      if (uid == null) return;
      _metaSub = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('appProfile')
          .doc('meta')
          .snapshots()
          .listen(
            (snap) => unawaited(_onRemoteAppMeta(snap.data())),
            onError: (Object e) {
              AppLogger.warn(
                'appProfile snapshots failed; polling',
                tag: 'settings_sync',
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
      unawaited(_refreshMetaOnce(promptIfNewer: false));
    });
  }

  Future<void> stopWatching() async {
    await _metaSub?.cancel();
    _metaSub = null;
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> disposeController() async {
    _appPushTimer?.cancel();
    _vaultPushTimer?.cancel();
    _settings.removeListener(_onSettingsChanged);
    if (identical(_settings.onAppProfileChanged, markAppProfileDirty)) {
      _settings.onAppProfileChanged = null;
    }
    if (identical(_settings.onVaultProfileChanged, markVaultProfileDirty)) {
      _settings.onVaultProfileChanged = null;
    }
    await stopWatching();
  }

  @override
  void dispose() {
    unawaited(disposeController());
    super.dispose();
  }

  Future<Map<String, dynamic>?> fetchAppProfileMeta() async {
    if (!isEnabled) return null;
    try {
      final res = await callFolioHttpsCallable(
        'folioGetAppProfileMeta',
        <String, dynamic>{},
      );
      if (res is Map) return Map<String, dynamic>.from(res);
    } catch (e, st) {
      AppLogger.warn(
        'folioGetAppProfileMeta failed',
        tag: 'settings_sync',
        context: {'error': '$e', 'stack': '$st'},
      );
    }
    return null;
  }

  Future<void> _refreshMetaOnce({required bool promptIfNewer}) async {
    if (!isEnabled) return;
    final meta = await fetchAppProfileMeta();
    if (meta == null) return;
    await _onRemoteAppMeta(meta, promptIfNewer: promptIfNewer);
  }

  Future<void> _onRemoteAppMeta(
    Map<String, dynamic>? data, {
    bool promptIfNewer = false,
  }) async {
    if (data == null || data.isEmpty) return;
    if (_promptPending) return;
    final fp = '${data['contentFingerprint'] ?? ''}'.trim();
    final path = '${data['packStoragePath'] ?? ''}'.trim();
    final rev = _asInt(data['rev']);
    final updatedAtMs = _asUpdatedAtMs(data['updatedAt']);
    if (path.isEmpty || fp.isEmpty) return;

    if (_isRemoteAppProfileAcknowledged(fp: fp, updatedAtMs: updatedAtMs)) {
      _lastAppFp = fp;
      _lastAppRev = rev > _lastAppRev ? rev : _lastAppRev;
      return;
    }

    if (fp == _lastAppFp) {
      _lastAppRev = rev > _lastAppRev ? rev : _lastAppRev;
      await _acknowledgeRemoteAppProfile(fp: fp, updatedAtMs: updatedAtMs);
      return;
    }
    if (promptIfNewer && _lastAppFp.isEmpty && rev > 0) {
      // Si el local ya coincide con la nube, no preguntar.
      try {
        final localProfile = _builder.buildAppProfile(_settings);
        final localFp = await FolioAppProfileCrypto.fingerprint(
          localProfile.encodeUtf8(),
        );
        if (localFp == fp) {
          _lastAppFp = fp;
          _lastAppRev = rev;
          await _acknowledgeRemoteAppProfile(fp: fp, updatedAtMs: updatedAtMs);
          return;
        }
      } catch (_) {}
      _promptPending = true;
      notifyListeners();
      return;
    }
    if (rev > _lastAppRev && _lastAppFp.isNotEmpty) {
      await restoreAppProfileFromCloud();
    }
  }

  bool _isRemoteAppProfileAcknowledged({
    required String fp,
    required int updatedAtMs,
  }) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty || _settings.cloudAppProfileAckUid != uid) return false;
    final ackFp = _settings.cloudAppProfileAckFingerprint;
    if (ackFp.isNotEmpty && ackFp == fp) return true;
    final ackMs = _settings.cloudAppProfileAckUpdatedAtMs;
    return ackMs > 0 && updatedAtMs > 0 && ackMs == updatedAtMs;
  }

  Future<void> _acknowledgeRemoteAppProfile({
    required String fp,
    required int updatedAtMs,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty || fp.isEmpty) return;
    await _settings.setCloudAppProfileAcknowledged(
      uid: uid,
      fingerprint: fp,
      updatedAtMs: updatedAtMs,
    );
  }

  void clearPromptPending() {
    _promptPending = false;
    notifyListeners();
  }

  Future<({SecretKey key, Uint8List? newWrapB64})> _resolvePackKey({
    String password = '',
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw StateError('Not signed in');

    String? wrapB64;
    try {
      final wrapRes = await callFolioHttpsCallable(
        'folioGetAppProfileRestoreWrap',
        <String, dynamic>{},
      );
      if (wrapRes is Map) {
        final w = '${wrapRes['restoreWrapB64'] ?? ''}'.trim();
        if (w.isNotEmpty) wrapB64 = w;
      }
    } catch (_) {}

    return _crypto.ensurePackKey(
      uid: uid,
      restoreWrapB64: wrapB64,
      restorePassword: password,
    );
  }

  /// Usuario elige «empezar de nuevo»: no importa el remoto; sube el local.
  Future<void> keepLocalAndPush() async {
    _promptPending = false;
    final meta = await fetchAppProfileMeta();
    _lastAppRev = _asInt(meta?['rev']);
    final remoteFp = '${meta?['contentFingerprint'] ?? ''}'.trim();
    final updatedAtMs = _asUpdatedAtMs(meta?['updatedAt']);
    // Evita re-prompt en el siguiente arranque aunque falle el push.
    if (remoteFp.isNotEmpty) {
      await _acknowledgeRemoteAppProfile(
        fp: remoteFp,
        updatedAtMs: updatedAtMs,
      );
    }
    // Evita re-prompt mientras se sube el estado local.
    if (_lastAppFp.isEmpty) {
      _lastAppFp = remoteFp.isNotEmpty ? remoteFp : '__local_pending__';
    }
    notifyListeners();
    await pushAppProfileNow(notifyUser: true);
  }

  Future<bool> pushAppProfileNow({
    String password = '',
    bool notifyUser = false,
  }) async {
    if (!isEnabled) {
      _lastError = 'sync_disabled';
      debugPrint(
        '[settings_sync] push skipped: enabled=${_settings.cloudAppProfileSyncEnabled} '
        'backup=${_entitlements.snapshot.canUseCloudBackup} '
        'user=${FirebaseAuth.instance.currentUser?.uid}',
      );
      if (notifyUser) {
        _onEvent?.call('Folio Cloud: sincronización de ajustes desactivada');
      }
      return false;
    }
    if (_pushInFlight) {
      _appDirty = true;
      return false;
    }
    _pushInFlight = true;
    _lastError = null;
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        _lastError = 'not_signed_in';
        return false;
      }

      // Fingerprint local ANTES de red: evita callables si no hay cambio real.
      final profile = _builder.buildAppProfile(_settings);
      final plain = profile.encodeUtf8();
      final fp = await FolioAppProfileCrypto.fingerprint(plain);
      if (fp == _lastAppFp) {
        _appDirty = false;
        return true;
      }

      final meta = await fetchAppProfileMeta();
      final remoteFp = '${meta?['contentFingerprint'] ?? ''}'.trim();
      if (remoteFp.isNotEmpty && remoteFp == fp) {
        _lastAppFp = fp;
        _lastAppRev = _asInt(meta?['rev']);
        _appDirty = false;
        await _acknowledgeRemoteAppProfile(
          fp: fp,
          updatedAtMs: _asUpdatedAtMs(meta?['updatedAt']),
        );
        return true;
      }

      _setStatus('pushing');
      final resolved = await _resolvePackKey(password: password);
      final packKey = resolved.key;
      final wrapToUpload = resolved.newWrapB64;

      final cipher = await FolioAppProfileCrypto.encryptProfile(
        plain: plain,
        packKey: packKey,
      );
      if (cipher.length > _maxPackBytes) {
        throw StateError('App profile pack too large');
      }

      debugPrint('[settings_sync] push step=icons');
      final iconBytes = await _builder.collectIconBytes(_settings);
      final iconIds = <String>[];
      for (final e in iconBytes.entries) {
        if (e.value.length > CustomIconImportService.maxBytes) {
          debugPrint(
            '[settings_sync] skip oversized icon ${e.key} bytes=${e.value.length}',
          );
          continue;
        }
        try {
          final ref = FirebaseStorage.instance.ref().child(
            'users/$uid/app-profile/icons/${e.key}',
          );
          await folioStoragePutData(ref, Uint8List.fromList(e.value));
          iconIds.add(e.key);
        } catch (eIcon) {
          debugPrint('[settings_sync] icon upload failed ${e.key}: $eIcon');
        }
      }

      final stamp =
          DateTime.now().toUtc().toIso8601String().replaceAll(':', '-');
      final path = 'users/$uid/app-profile/packs/pack-$stamp.bin';
      debugPrint('[settings_sync] push step=upload path=$path bytes=${cipher.length}');
      await folioStoragePutData(
        FirebaseStorage.instance.ref().child(path),
        cipher,
      );

      final oldPath = '${meta?['packStoragePath'] ?? ''}'.trim();
      final oldSize = _asInt(meta?['packSizeBytes']);
      final hasWrap = meta?['hasRestoreWrap'] == true;

      debugPrint('[settings_sync] push step=finalize');
      await callFolioHttpsCallable('folioFinalizeAppProfile', <String, dynamic>{
        'packStoragePath': path,
        'packSizeBytes': cipher.length,
        'contentFingerprint': fp,
        'iconIds': iconIds,
        if (oldPath.isNotEmpty) 'oldPackStoragePath': oldPath,
        if (oldSize > 0) 'oldPackSizeBytes': oldSize,
        if (wrapToUpload != null && !hasWrap)
          'restoreWrapB64': base64Encode(wrapToUpload),
      });

      _lastAppFp = fp;
      _appDirty = false;
      _lastError = null;
      _setStatus('idle');
      await _acknowledgeRemoteAppProfile(
        fp: fp,
        updatedAtMs: DateTime.now().millisecondsSinceEpoch,
      );
      notifyListeners();
      debugPrint('[settings_sync] push ok rev fingerprint=$fp');
      return true;
    } catch (e, st) {
      _lastError = _formatSyncError(e);
      AppLogger.error(
        'push app profile failed',
        tag: 'settings_sync',
        error: e,
        stackTrace: st,
      );
      debugPrint('[settings_sync] push FAILED: $e');
      debugPrint('$st');
      _setStatus('error');
      if (notifyUser) {
        _onEvent?.call(_lastError!);
      }
      return false;
    } finally {
      _pushInFlight = false;
      if (_appDirty) {
        _appPushTimer?.cancel();
        _appPushTimer = Timer(
          _pushDebounce,
          () => unawaited(pushAppProfileNow()),
        );
      }
    }
  }

  Future<bool> restoreAppProfileFromCloud({String password = ''}) async {
    if (!isEnabled) {
      _lastError = 'sync_disabled';
      return false;
    }
    if (_pullInFlight) return false;
    _pullInFlight = true;
    _setStatus('pulling');
    _lastError = null;
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        _lastError = 'not_signed_in';
        return false;
      }
      final meta = await fetchAppProfileMeta();
      final path = '${meta?['packStoragePath'] ?? ''}'.trim();
      final fp = '${meta?['contentFingerprint'] ?? ''}'.trim();
      if (path.isEmpty) {
        _lastError = 'empty_cloud_profile';
        debugPrint('[settings_sync] restore skipped: no pack in cloud yet');
        return false;
      }

      final resolved = await _resolvePackKey(password: password);
      final cipher = await folioStorageGetData(
        FirebaseStorage.instance.ref().child(path),
        _maxPackBytes,
      );
      if (cipher == null || cipher.isEmpty) {
        throw StateError('Empty app profile pack');
      }
      final plain = await FolioAppProfileCrypto.decryptProfile(
        blob: cipher,
        packKey: resolved.key,
      );
      final profile = FolioSettingsProfile.decodeUtf8(plain);

      final paths = <String, String>{};
      for (final icon in profile.icons) {
        await _downloadIcon(
          uid: uid,
          iconId: icon.id,
          mime: icon.mimeType,
          out: paths,
        );
      }
      for (final list in profile.integrationIconsByApp.values) {
        for (final icon in list) {
          await _downloadIcon(
            uid: uid,
            iconId: icon.id,
            mime: icon.mimeType,
            out: paths,
          );
        }
      }

      _suppressDirty = true;
      try {
        await _applier.applyAppProfile(
          settings: _settings,
          profile: profile,
          localIconPathsById: paths,
        );
      } finally {
        _suppressDirty = false;
      }

      _lastAppFp = fp;
      _lastAppRev = _asInt(meta?['rev']);
      _promptPending = false;
      _lastError = null;
      _setStatus('idle');
      await _acknowledgeRemoteAppProfile(
        fp: fp,
        updatedAtMs: _asUpdatedAtMs(meta?['updatedAt']),
      );
      notifyListeners();
      return true;
    } catch (e, st) {
      _lastError = _formatSyncError(e);
      AppLogger.error(
        'restore app profile failed',
        tag: 'settings_sync',
        error: e,
        stackTrace: st,
      );
      debugPrint('[settings_sync] restore FAILED: $e');
      _setStatus('error');
      return false;
    } finally {
      _pullInFlight = false;
    }
  }

  Future<void> _downloadIcon({
    required String uid,
    required String iconId,
    required String mime,
    required Map<String, String> out,
  }) async {
    if (iconId.isEmpty || out.containsKey(iconId)) return;
    try {
      final ref = FirebaseStorage.instance.ref().child(
        'users/$uid/app-profile/icons/$iconId',
      );
      final data = await folioStorageGetData(
        ref,
        CustomIconImportService.maxBytes,
      );
      if (data == null || data.isEmpty) return;
      final path = await _iconImport.writeIconBytesWithId(
        id: iconId,
        bytes: data,
        mimeType: mime.isEmpty ? 'image/png' : mime,
      );
      out[iconId] = path;
    } catch (e) {
      AppLogger.warn(
        'icon download failed',
        tag: 'settings_sync',
        context: {'iconId': iconId, 'error': '$e'},
      );
    }
  }

  Future<bool> pushVaultProfileNow(
    String vaultId, {
    String password = '',
    bool notifyUser = false,
  }) async {
    if (!isEnabled) {
      _lastError = 'sync_disabled';
      debugPrint(
        '[settings_sync] vault push skipped: enabled=${_settings.cloudAppProfileSyncEnabled} '
        'backup=${_entitlements.snapshot.canUseCloudBackup} '
        'user=${FirebaseAuth.instance.currentUser?.uid}',
      );
      if (notifyUser) {
        _onEvent?.call('Folio Cloud: sincronización de ajustes desactivada');
      }
      return false;
    }
    final vid = vaultId.trim().isEmpty
        ? (VaultPaths.activeVaultId ?? '')
        : vaultId.trim();
    if (vid.isEmpty) {
      _lastError = 'empty_vault_id';
      debugPrint('[settings_sync] vault push skipped: empty vaultId');
      return false;
    }
    _setStatus('pushing_vault');
    _lastError = null;
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        _lastError = 'not_signed_in';
        debugPrint('[settings_sync] vault push skipped: not signed in');
        return false;
      }

      debugPrint('[settings_sync] vault push step=key vaultId=$vid');
      final resolved = await _resolvePackKey(password: password);

      debugPrint('[settings_sync] vault push step=build vaultId=$vid');
      final profile = await _builder.buildVaultProfile(
        settings: _settings,
        vaultId: vid,
      );
      final plain = profile.encodeUtf8();
      final fp = await FolioAppProfileCrypto.fingerprint(plain);
      debugPrint(
        '[settings_sync] vault push step=encrypt '
        'plainBytes=${plain.length} secrets=${profile.secrets.length}',
      );
      final cipher = await FolioAppProfileCrypto.encryptProfile(
        plain: plain,
        packKey: resolved.key,
      );

      debugPrint('[settings_sync] vault push step=meta vaultId=$vid');
      Map<String, dynamic>? prev;
      try {
        final res = await callFolioHttpsCallable(
          'folioGetVaultProfileMeta',
          <String, dynamic>{'vaultId': vid},
        );
        if (res is Map) prev = Map<String, dynamic>.from(res);
        debugPrint(
          '[settings_sync] vault push prevRev=${prev?['rev']} '
          'prevPath=${prev?['packStoragePath']}',
        );
      } catch (e) {
        debugPrint('[settings_sync] vault push meta fetch failed (ok if first): $e');
      }

      final stamp =
          DateTime.now().toUtc().toIso8601String().replaceAll(':', '-');
      final path = 'users/$uid/vault-profiles/$vid/packs/pack-$stamp.bin';
      debugPrint(
        '[settings_sync] vault push step=upload path=$path bytes=${cipher.length}',
      );
      await folioStoragePutData(
        FirebaseStorage.instance.ref().child(path),
        cipher,
      );

      final oldPath = '${prev?['packStoragePath'] ?? ''}'.trim();
      final oldSize = _asInt(prev?['packSizeBytes']);

      debugPrint('[settings_sync] vault push step=finalize vaultId=$vid');
      final finalize = await callFolioHttpsCallable(
        'folioFinalizeVaultProfile',
        <String, dynamic>{
          'vaultId': vid,
          'packStoragePath': path,
          'packSizeBytes': cipher.length,
          'contentFingerprint': fp,
          if (oldPath.isNotEmpty) 'oldPackStoragePath': oldPath,
          if (oldSize > 0) 'oldPackSizeBytes': oldSize,
        },
      );
      debugPrint('[settings_sync] vault push ok vaultId=$vid result=$finalize');
      _lastError = null;
      _setStatus('idle');
      notifyListeners();
      return true;
    } catch (e, st) {
      _lastError = _formatSyncError(e);
      AppLogger.error(
        'push vault profile failed',
        tag: 'settings_sync',
        error: e,
        stackTrace: st,
        context: {'vaultId': vaultId},
      );
      debugPrint('[settings_sync] vault push FAILED vaultId=$vaultId: $e');
      debugPrint('$st');
      _setStatus('error');
      if (notifyUser) {
        _onEvent?.call(_lastError!);
      }
      return false;
    }
  }

  Future<bool> restoreVaultProfileFromCloud(
    String vaultId, {
    String password = '',
  }) async {
    if (!isEnabled) {
      _lastError = 'sync_disabled';
      debugPrint('[settings_sync] vault restore skipped: sync disabled');
      return false;
    }
    final vid = vaultId.trim();
    if (vid.isEmpty) {
      _lastError = 'empty_vault_id';
      debugPrint('[settings_sync] vault restore skipped: empty vaultId');
      return false;
    }
    _setStatus('pulling_vault');
    _lastError = null;
    try {
      debugPrint('[settings_sync] vault restore step=meta vaultId=$vid');
      final res = await callFolioHttpsCallable(
        'folioGetVaultProfileMeta',
        <String, dynamic>{'vaultId': vid},
      );
      if (res is! Map) {
        _lastError = 'invalid_meta';
        debugPrint('[settings_sync] vault restore invalid meta: $res');
        return false;
      }
      final meta = Map<String, dynamic>.from(res);
      final path = '${meta['packStoragePath'] ?? ''}'.trim();
      final rev = _asInt(meta['rev']);
      final fp = '${meta['contentFingerprint'] ?? ''}'.trim();
      debugPrint(
        '[settings_sync] vault restore meta rev=$rev path=$path fp=$fp',
      );
      if (path.isEmpty) {
        _lastError = 'empty_cloud_vault_profile';
        debugPrint(
          '[settings_sync] vault restore skipped: no pack in cloud for $vid',
        );
        return false;
      }

      debugPrint('[settings_sync] vault restore step=key');
      final resolved = await _resolvePackKey(password: password);
      debugPrint('[settings_sync] vault restore step=download path=$path');
      final cipher = await folioStorageGetData(
        FirebaseStorage.instance.ref().child(path),
        _maxPackBytes,
      );
      if (cipher == null || cipher.isEmpty) {
        _lastError = 'empty_pack';
        debugPrint('[settings_sync] vault restore empty cipher');
        return false;
      }
      debugPrint(
        '[settings_sync] vault restore step=decrypt bytes=${cipher.length}',
      );
      final plain = await FolioAppProfileCrypto.decryptProfile(
        blob: cipher,
        packKey: resolved.key,
      );
      final profile = FolioSettingsProfile.decodeUtf8(plain);
      debugPrint(
        '[settings_sync] vault restore step=apply '
        'kind=${profile.kind.name} secrets=${profile.secrets.length}',
      );
      _suppressDirty = true;
      try {
        await _applier.applyVaultProfile(
          settings: _settings,
          profile: profile,
        );
      } finally {
        _suppressDirty = false;
      }
      _lastError = null;
      _setStatus('idle');
      notifyListeners();
      debugPrint('[settings_sync] vault restore ok vaultId=$vid');
      return true;
    } catch (e, st) {
      _lastError = _formatSyncError(e);
      AppLogger.error(
        'restore vault profile failed',
        tag: 'settings_sync',
        error: e,
        stackTrace: st,
        context: {'vaultId': vaultId},
      );
      debugPrint('[settings_sync] vault restore FAILED vaultId=$vaultId: $e');
      debugPrint('$st');
      _setStatus('error');
      return false;
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

  /// Normaliza `updatedAt` de callable/Firestore a epoch ms.
  static int _asUpdatedAtMs(Object? v) {
    if (v == null) return 0;
    if (v is Timestamp) return v.millisecondsSinceEpoch;
    if (v is DateTime) return v.millisecondsSinceEpoch;
    if (v is num) {
      final n = v.toInt();
      // Segundos vs milisegundos.
      if (n > 0 && n < 100000000000) return n * 1000;
      return n;
    }
    if (v is Map) {
      final sec = v['_seconds'] ?? v['seconds'];
      final nsec = v['_nanoseconds'] ?? v['nanoseconds'] ?? 0;
      if (sec is num) {
        return sec.toInt() * 1000 + ((nsec is num ? nsec.toInt() : 0) ~/ 1000000);
      }
    }
    final s = '$v'.trim();
    if (s.isEmpty) return 0;
    final asInt = int.tryParse(s);
    if (asInt != null) {
      if (asInt > 0 && asInt < 100000000000) return asInt * 1000;
      return asInt;
    }
    final dt = DateTime.tryParse(s);
    return dt?.millisecondsSinceEpoch ?? 0;
  }

  static String _formatSyncError(Object e) {
    if (e is FirebaseFunctionsException) {
      final code = e.code.trim();
      final msg = (e.message ?? '').trim();
      if (code == 'not-found') {
        return 'Folio Cloud: función de perfil no desplegada ($code)';
      }
      if (msg.isNotEmpty) return 'Folio Cloud: $msg';
      return 'Folio Cloud: error $code';
    }
    final s = '$e'.trim();
    if (s.length > 160) return 'Folio Cloud: ${s.substring(0, 160)}…';
    return 'Folio Cloud: $s';
  }
}
