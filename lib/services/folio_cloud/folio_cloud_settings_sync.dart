import 'dart:async';
import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';

import '../../app/app_settings.dart';
import '../../data/folio_settings_profile_format.dart';
import '../../data/vault_paths.dart';
import '../app_logger.dart';
import '../custom_icon_import_service.dart';
import '../settings/folio_app_profile_crypto.dart';
import '../settings/settings_profile_applier.dart';
import '../settings/settings_profile_builder.dart';
import 'folio_cloud_callable.dart';
import 'folio_cloud_exception.dart';
import 'folio_cloud_entitlements.dart';
import 'folio_cloud_identity.dart';
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
  /// No es un poll continuo: solo respalda la comprobación de arranque
  /// (`start()`) cuando no hay listener de Firestore (p. ej. Windows) o si
  /// falla. Cambios remotos se recogen como mucho 1 vez al día o al
  /// reiniciar la app, no en un poll de segundos.
  static const Duration _dailyCheckInterval = Duration(days: 1);
  static const int _maxPackBytes = 16 * 1024 * 1024;

  Timer? _appPushTimer;
  Timer? _vaultPushTimer;
  Timer? _pollTimer;
  StreamSubscription<void>? _metaSub;
  /// True mientras el ciclo start()/daily-check está activo. Evita que
  /// `start()` haga stop+refreshMeta si ya está watching.
  bool _watching = false;
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
      folioCloudHasSession();

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
    if (_watching) return;
    if (!isEnabled) return;
    _watching = true;
    final uid = folioCloudCurrentUid();
    if (uid != null &&
        _settings.cloudAppProfileAckUid == uid &&
        _settings.cloudAppProfileAckFingerprint.isNotEmpty &&
        _lastAppFp.isEmpty) {
      _lastAppFp = _settings.cloudAppProfileAckFingerprint;
    }
    try {
      await _refreshMetaOnce(promptIfNewer: true);
      if (!_watching) return;
      _startDailyCheck();
    } catch (_) {
      _watching = false;
      rethrow;
    }
  }

  /// Fallback cuando no hay listener de Firestore en tiempo real: comprueba
  /// cambios remotos como mucho 1 vez al día. El arranque (`start()`) ya hizo
  /// una comprobación inmediata vía `_refreshMetaOnce`; esto no es un poll
  /// de segundos, es solo para sesiones muy largas sin reiniciar la app.
  void _startDailyCheck() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_dailyCheckInterval, (_) {
      unawaited(_refreshMetaOnce(promptIfNewer: false));
    });
  }

  Future<void> stopWatching() async {
    _watching = false;
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
    final uid = folioCloudCurrentUid() ?? '';
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
    final uid = folioCloudCurrentUid() ?? '';
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
    bool reclaimWithLocal = false,
  }) async {
    final uid = folioCloudCurrentUid();
    if (uid == null) throw StateError('Not signed in');

    // Reclamar cuenta: usar/crear clave local y siempre devolver wrap para
    // sobrescribir el canónico del servidor (pack y wrap quedan alineados).
    if (reclaimWithLocal) {
      final exported = await _crypto.exportLocalKeyWrap(
        uid: uid,
        password: password,
      );
      return (key: exported.key, newWrapB64: exported.wrapB64);
    }

    // Siempre consultar el wrap canónico de la cuenta cuando sea posible.
    // Preferir la caché local a ciegas generaba packs cifrados con clave
    // huérfana mientras el wrap remoto seguía siendo otro → MAC al restaurar.
    // Sin wrap remoto (cuenta nueva): Firebase devolvía ""; Spring alineado.
    // Por si un backend antiguo aún lanza failed-precondition, lo tratamos
    // como vacío.
    String? wrapB64;
    try {
      final wrapRes = await callFolioHttpsCallable(
        'folioGetAppProfileRestoreWrap',
        <String, dynamic>{},
      );
      if (wrapRes is Map) {
        final w =
            '${wrapRes['restoreWrapB64'] ?? wrapRes['wrapB64'] ?? ''}'.trim();
        if (w.isNotEmpty) wrapB64 = w;
      }
    } on FolioCloudException catch (e) {
      if (e.code != 'failed-precondition') rethrow;
      AppLogger.debug(
        'no remote app profile wrap yet',
        tag: 'settings_sync',
        context: {'message': e.message},
      );
    }

    return _crypto.ensurePackKey(
      uid: uid,
      restoreWrapB64: wrapB64,
      restorePassword: password,
      preferRemoteWrap: wrapB64 != null && wrapB64.isNotEmpty,
    );
  }

  /// Descifra un pack de perfil con recuperación de un solo intento: si la
  /// clave local no coincide (MAC inválida), reintenta adoptando la clave
  /// canónica de la cuenta desde el servidor (ver `adoptCanonicalKey`).
  Future<Uint8List> _decryptProfileWithRecovery({
    required String uid,
    required SecretKey key,
    required Uint8List cipher,
    String password = '',
  }) async {
    try {
      return await FolioAppProfileCrypto.decryptProfile(
        blob: cipher,
        packKey: key,
      );
    } on SecretBoxAuthenticationError {
      final wrapRes = await callFolioHttpsCallable(
        'folioGetAppProfileRestoreWrap',
        <String, dynamic>{},
      );
      final wrapB64 = wrapRes is Map
          ? '${wrapRes['restoreWrapB64'] ?? wrapRes['wrapB64'] ?? ''}'.trim()
          : '';
      final recovered = wrapB64.isEmpty
          ? null
          : await _crypto.adoptCanonicalKey(
              uid: uid,
              restoreWrapB64: wrapB64,
              restorePassword: password,
            );
      if (recovered == null) {
        AppLogger.warn(
          'MAC fail: no recoverable wrap',
          tag: 'settings_sync',
          context: {'wrapEmpty': wrapB64.isEmpty},
        );
        rethrow;
      }
      AppLogger.warn(
        'app profile local key mismatched canonical key; recovered from server wrap',
        tag: 'settings_sync',
      );
      try {
        return await FolioAppProfileCrypto.decryptProfile(
          blob: cipher,
          packKey: recovered,
        );
      } on SecretBoxAuthenticationError {
        // Pack cifrado con clave distinta al wrap canónico (carrera push).
        AppLogger.warn(
          'MAC fail after canonical adopt: pack/wrap mismatch',
          tag: 'settings_sync',
        );
        rethrow;
      }
    }
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
    await pushAppProfileNow(notifyUser: true, reclaimWithLocal: true);
  }

  Future<bool> pushAppProfileNow({
    String password = '',
    bool notifyUser = false,
    bool reclaimWithLocal = false,
  }) async {
    if (!isEnabled) {
      _lastError = 'sync_disabled';
      AppLogger.info(
        'push skipped',
        tag: 'settings_sync',
        context: {
          'enabled': _settings.cloudAppProfileSyncEnabled,
          'backup': _entitlements.snapshot.canUseCloudBackup,
          'user': folioCloudCurrentUid(),
        },
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
      final uid = folioCloudCurrentUid();
      if (uid == null) {
        _lastError = 'not_signed_in';
        return false;
      }

      // Fingerprint local ANTES de red: evita callables si no hay cambio real.
      // Se calcula sobre la vista estable (sin `exportedAtMs`, que cambia en
      // cada build) para no forzar una resubida cuando nada cambió de verdad.
      final profile = _builder.buildAppProfile(_settings);
      final plain = profile.encodeUtf8();
      final fp = await FolioAppProfileCrypto.fingerprint(
        profile.encodeUtf8(includeExportedAt: false),
      );
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
      final resolved = await _resolvePackKey(
        password: password,
        reclaimWithLocal: reclaimWithLocal,
      );
      final packKey = resolved.key;

      final cipher = await FolioAppProfileCrypto.encryptProfile(
        plain: plain,
        packKey: packKey,
      );
      if (cipher.length > _maxPackBytes) {
        throw StateError('App profile pack too large');
      }

      AppLogger.debug('push step=icons', tag: 'settings_sync');
      final iconBytes = await _builder.collectIconBytes(_settings);
      final iconIds = <String>[];
      for (final e in iconBytes.entries) {
        if (e.value.length > CustomIconImportService.maxBytes) {
          AppLogger.debug(
            'skip oversized icon',
            tag: 'settings_sync',
            context: {'iconId': e.key, 'bytes': e.value.length},
          );
          continue;
        }
        try {
          final iconPath = 'users/$uid/app-profile/icons/${e.key}';
          await folioStoragePutData(
            iconPath,
            Uint8List.fromList(e.value),
          );
          iconIds.add(e.key);
        } catch (eIcon) {
          AppLogger.warn(
            'icon upload failed',
            tag: 'settings_sync',
            context: {'iconId': e.key, 'error': '$eIcon'},
          );
        }
      }

      final stamp =
          DateTime.now().toUtc().toIso8601String().replaceAll(':', '-');
      final path = 'users/$uid/app-profile/packs/pack-$stamp.bin';
      AppLogger.debug(
        'push step=upload',
        tag: 'settings_sync',
        context: {'path': path, 'bytes': cipher.length},
      );
      await folioStoragePutData(
        path,
        cipher,
      );

      final oldPath = '${meta?['packStoragePath'] ?? ''}'.trim();
      final oldSize = _asInt(meta?['packSizeBytes']);
      final hasWrap = meta?['hasRestoreWrap'] == true;
      // Si el servidor aún no tiene wrap (o reclamamos), hay que subirlo aunque
      // la clave ya estuviera en caché local (newWrapB64 sería null).
      var wrapToUpload = resolved.newWrapB64;
      if ((!hasWrap || reclaimWithLocal) && wrapToUpload == null) {
        final exported = await _crypto.exportLocalKeyWrap(
          uid: uid,
          password: password,
        );
        wrapToUpload = exported.wrapB64;
      }
      final shouldUploadWrap =
          wrapToUpload != null && (!hasWrap || reclaimWithLocal);

      AppLogger.debug('push step=finalize', tag: 'settings_sync');
      await callFolioHttpsCallable('folioFinalizeAppProfile', <String, dynamic>{
        'packStoragePath': path,
        'packSizeBytes': cipher.length,
        'contentFingerprint': fp,
        'iconIds': iconIds,
        if (oldPath.isNotEmpty) 'oldPackStoragePath': oldPath,
        if (oldSize > 0) 'oldPackSizeBytes': oldSize,
        if (shouldUploadWrap) 'restoreWrapB64': base64Encode(wrapToUpload),
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
      AppLogger.info(
        'push ok',
        tag: 'settings_sync',
        context: {'fingerprint': fp},
      );
      return true;
    } catch (e, st) {
      _lastError = _formatSyncError(e);
      AppLogger.error(
        'push app profile failed',
        tag: 'settings_sync',
        error: e,
        stackTrace: st,
      );
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
    var remoteRev = 0;
    try {
      final uid = folioCloudCurrentUid();
      if (uid == null) {
        _lastError = 'not_signed_in';
        return false;
      }
      final meta = await fetchAppProfileMeta();
      final path = '${meta?['packStoragePath'] ?? ''}'.trim();
      final fp = '${meta?['contentFingerprint'] ?? ''}'.trim();
      remoteRev = _asInt(meta?['rev']);
      if (path.isEmpty) {
        _lastError = 'empty_cloud_profile';
        AppLogger.info(
          'restore skipped: no pack in cloud yet',
          tag: 'settings_sync',
        );
        return false;
      }

      final resolved = await _resolvePackKey(password: password);
      final cipher = await folioStorageGetData(
        path,
        _maxPackBytes,
      );
      if (cipher == null || cipher.isEmpty) {
        throw StateError('Empty app profile pack');
      }
      final plain = await _decryptProfileWithRecovery(
        uid: uid,
        key: resolved.key,
        cipher: cipher,
        password: password,
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
      _lastAppRev = remoteRev;
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
      // Evita reintentos infinitos en cada poll/snapshot con la misma rev.
      if (remoteRev > _lastAppRev) {
        _lastAppRev = remoteRev;
      }
      if (e is SecretBoxAuthenticationError && !_promptPending) {
        _promptPending = true;
        notifyListeners();
      }
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
      final iconPath = 'users/$uid/app-profile/icons/$iconId';
      final data = await folioStorageGetData(
        iconPath,
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
      AppLogger.info(
        'vault push skipped',
        tag: 'settings_sync',
        context: {
          'enabled': _settings.cloudAppProfileSyncEnabled,
          'backup': _entitlements.snapshot.canUseCloudBackup,
          'user': folioCloudCurrentUid(),
        },
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
      AppLogger.info('vault push skipped: empty vaultId', tag: 'settings_sync');
      return false;
    }
    _setStatus('pushing_vault');
    _lastError = null;
    try {
      final uid = folioCloudCurrentUid();
      if (uid == null) {
        _lastError = 'not_signed_in';
        AppLogger.info(
          'vault push skipped: not signed in',
          tag: 'settings_sync',
        );
        return false;
      }

      AppLogger.debug(
        'vault push step=key',
        tag: 'settings_sync',
        context: {'vaultId': vid},
      );
      final resolved = await _resolvePackKey(password: password);

      AppLogger.debug(
        'vault push step=build',
        tag: 'settings_sync',
        context: {'vaultId': vid},
      );
      final profile = await _builder.buildVaultProfile(
        settings: _settings,
        vaultId: vid,
      );
      final plain = profile.encodeUtf8();
      // Fingerprint estable (sin `exportedAtMs`): evita resubir si el
      // contenido real no cambió desde el último push/pull conocido.
      final fp = await FolioAppProfileCrypto.fingerprint(
        profile.encodeUtf8(includeExportedAt: false),
      );

      AppLogger.debug(
        'vault push step=meta',
        tag: 'settings_sync',
        context: {'vaultId': vid},
      );
      Map<String, dynamic>? prev;
      try {
        final res = await callFolioHttpsCallable(
          'folioGetVaultProfileMeta',
          <String, dynamic>{'vaultId': vid},
        );
        if (res is Map) prev = Map<String, dynamic>.from(res);
        AppLogger.debug(
          'vault push previous meta',
          tag: 'settings_sync',
          context: {
            'prevRev': prev?['rev'],
            'prevPath': prev?['packStoragePath'],
          },
        );
      } catch (e) {
        AppLogger.debug(
          'vault push meta fetch failed (ok if first)',
          tag: 'settings_sync',
          context: {'error': '$e'},
        );
      }

      final remoteFp = '${prev?['contentFingerprint'] ?? ''}'.trim();
      if (remoteFp.isNotEmpty && remoteFp == fp) {
        AppLogger.info(
          'vault push skipped: no content change',
          tag: 'settings_sync',
          context: {'vaultId': vid},
        );
        _lastError = null;
        _setStatus('idle');
        return true;
      }

      AppLogger.debug(
        'vault push step=encrypt',
        tag: 'settings_sync',
        context: {
          'plainBytes': plain.length,
          'secretsCount': profile.secrets.length,
        },
      );
      final cipher = await FolioAppProfileCrypto.encryptProfile(
        plain: plain,
        packKey: resolved.key,
      );

      final stamp =
          DateTime.now().toUtc().toIso8601String().replaceAll(':', '-');
      final path = 'users/$uid/vault-profiles/$vid/packs/pack-$stamp.bin';
      AppLogger.debug(
        'vault push step=upload',
        tag: 'settings_sync',
        context: {'path': path, 'bytes': cipher.length},
      );
      await folioStoragePutData(
        path,
        cipher,
      );

      final oldPath = '${prev?['packStoragePath'] ?? ''}'.trim();
      final oldSize = _asInt(prev?['packSizeBytes']);

      AppLogger.debug(
        'vault push step=finalize',
        tag: 'settings_sync',
        context: {'vaultId': vid},
      );
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
      AppLogger.info(
        'vault push ok',
        tag: 'settings_sync',
        context: {'vaultId': vid, 'result': '$finalize'},
      );
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
      AppLogger.info(
        'vault restore skipped: sync disabled',
        tag: 'settings_sync',
      );
      return false;
    }
    final vid = vaultId.trim();
    if (vid.isEmpty) {
      _lastError = 'empty_vault_id';
      AppLogger.info(
        'vault restore skipped: empty vaultId',
        tag: 'settings_sync',
      );
      return false;
    }
    _setStatus('pulling_vault');
    _lastError = null;
    try {
      final uid = folioCloudCurrentUid();
      if (uid == null) {
        _lastError = 'not_signed_in';
        AppLogger.info(
          'vault restore skipped: not signed in',
          tag: 'settings_sync',
        );
        return false;
      }
      AppLogger.debug(
        'vault restore step=meta',
        tag: 'settings_sync',
        context: {'vaultId': vid},
      );
      final res = await callFolioHttpsCallable(
        'folioGetVaultProfileMeta',
        <String, dynamic>{'vaultId': vid},
      );
      if (res is! Map) {
        _lastError = 'invalid_meta';
        AppLogger.warn(
          'vault restore invalid meta',
          tag: 'settings_sync',
          context: {'response': '$res'},
        );
        return false;
      }
      final meta = Map<String, dynamic>.from(res);
      final path = '${meta['packStoragePath'] ?? ''}'.trim();
      final rev = _asInt(meta['rev']);
      final fp = '${meta['contentFingerprint'] ?? ''}'.trim();
      AppLogger.debug(
        'vault restore meta',
        tag: 'settings_sync',
        context: {'rev': rev, 'path': path, 'fingerprint': fp},
      );
      if (path.isEmpty) {
        _lastError = 'empty_cloud_vault_profile';
        AppLogger.info(
          'vault restore skipped: no pack in cloud',
          tag: 'settings_sync',
          context: {'vaultId': vid},
        );
        return false;
      }

      AppLogger.debug('vault restore step=key', tag: 'settings_sync');
      final resolved = await _resolvePackKey(password: password);
      AppLogger.debug(
        'vault restore step=download',
        tag: 'settings_sync',
        context: {'path': path},
      );
      final cipher = await folioStorageGetData(
        path,
        _maxPackBytes,
      );
      if (cipher == null || cipher.isEmpty) {
        _lastError = 'empty_pack';
        AppLogger.warn('vault restore empty cipher', tag: 'settings_sync');
        return false;
      }
      AppLogger.debug(
        'vault restore step=decrypt',
        tag: 'settings_sync',
        context: {'bytes': cipher.length},
      );
      final plain = await _decryptProfileWithRecovery(
        uid: uid,
        key: resolved.key,
        cipher: cipher,
        password: password,
      );
      final profile = FolioSettingsProfile.decodeUtf8(plain);
      AppLogger.debug(
        'vault restore step=apply',
        tag: 'settings_sync',
        context: {
          'kind': profile.kind.name,
          'secretsCount': profile.secrets.length,
        },
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
      AppLogger.info(
        'vault restore ok',
        tag: 'settings_sync',
        context: {'vaultId': vid},
      );
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
    if (e is FolioCloudException) {
      final code = e.code.trim();
      final msg = e.message.trim();
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
