import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as p;

import '../../crypto/vault_crypto.dart';
import '../../data/storage/vault_storage.dart';
import '../../data/vault_local_storage.dart';
import '../../data/vault_payload.dart';
import '../../data/vault_paths.dart';
import '../../data/vault_registry.dart';
import '../../models/folio_page.dart';
import '../../models/local_collab.dart';
import '../quick_unlock_storage.dart';
import '../app_logger.dart';
import '../sync/vault_sync_merge.dart';
import '../sync/vault_sync_pack.dart';
import 'device_sync_key_cache.dart';
import 'folio_cloud_identity.dart';

/// Lectura/escritura de una libreta para device-sync sin abrirla en la UI.
///
/// Usa [VaultStorage] (disco o IndexedDB en web); no depende de `path_provider`.
class HeadlessDeviceSyncVault {
  HeadlessDeviceSyncVault({
    DeviceSyncKeyCache? keyCache,
    QuickUnlockStorage? quickUnlock,
  }) : _keys = keyCache ?? DeviceSyncKeyCache(),
       _quick = quickUnlock ?? QuickUnlockStorage();

  final DeviceSyncKeyCache _keys;
  final QuickUnlockStorage _quick;
  final _merge = VaultSyncMergeEngine();

  DeviceSyncKeyCache get keyCache => _keys;

  Future<bool> isPlain(String vaultId) async {
    final raw = await VaultStorage.instance.readVaultFile(
      vaultId,
      VaultPaths.vaultModeFile,
    );
    if (raw != null) {
      return String.fromCharCodes(raw).trim().toLowerCase() == 'plain';
    }
    // Sin vault.mode: si no hay vault.keys y vault.bin es JSON legible → plain.
    final keys = await VaultStorage.instance.readVaultFile(
      vaultId,
      VaultPaths.wrappedDekFile,
    );
    if (keys != null && keys.isNotEmpty) return false;
    final bin = await VaultStorage.instance.readVaultFile(
      vaultId,
      VaultPaths.cipherPayloadFile,
    );
    if (bin == null || bin.isEmpty) return false;
    try {
      final text = String.fromCharCodes(bin).trimLeft();
      if (!text.startsWith('{')) return false;
      VaultPayload.decodeUtf8(bin);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Resuelve la clave de pack. Null si la libreta cifrada nunca se desbloqueó
  /// en este dispositivo (aún no hay DEK en caché ni quick-unlock).
  Future<SecretKey?> resolvePackKey(String vaultId) async {
    final uid = folioCloudCurrentUid();
    if (await isPlain(vaultId)) {
      if (uid != null && uid.isNotEmpty) {
        try {
          final secret = await DeviceSyncKeyCache.ensureAccountSyncSecret(vaultId);
          final key = await DeviceSyncKeyCache.plainPackKey(
            uid: uid,
            vaultId: vaultId,
            accountSecret: secret,
          );
          final raw = await key.extractBytes();
          await _keys.save(vaultId, raw);
          return key;
        } catch (e) {
          // Sin red/Cloud Function no hay forma de obtener el secreto de
          // cuenta; se trata como "aún no disponible" en vez de propagar.
          AppLogger.debug(
            'resolvePackKey: account sync secret unavailable',
            tag: 'cloud_sync',
            context: {'vaultId': vaultId, 'error': '$e'},
          );
          return null;
        }
      }
      return _keys.ensurePlainVaultSyncKey(vaultId);
    }
    final cached = await _keys.readSecretKey(vaultId);
    if (cached != null) return cached;
    final quick = await _quick.readDek(vaultId);
    if (quick != null) {
      AppLogger.debug(
        'headless pack key from quick unlock',
        tag: 'cloud_sync',
        context: {'vaultId': vaultId},
      );
      await _keys.save(vaultId, quick);
      return VaultCrypto.dekFromBytes(quick);
    }
    AppLogger.debug(
      'headless pack key miss',
      tag: 'cloud_sync',
      context: {'vaultId': vaultId},
    );
    return null;
  }

  /// Versión de formato en disco (`vault.format`). En web el canónico sigue
  /// siendo `vault.bin` (el árbol v1 es nativo).
  Future<int> _formatVersion(String vaultId) async {
    if (kIsWeb) return 0;
    try {
      final dir = await VaultPaths.vaultDirectoryForId(vaultId);
      final marker = File(p.join(dir.path, 'vault.format'));
      if (marker.existsSync()) {
        return int.tryParse((await marker.readAsString()).trim()) ?? 0;
      }
      // Marker ausente: si ya hay árbol v1, no tratar como v0 (vault.bin puede
      // estar vacío tras migrar y provocaba "install remote" destructivo).
      final treeJson = File(p.join(dir.path, 'repo', 'tree.json'));
      if (treeJson.existsSync()) return 1;
      return 0;
    } catch (_) {
      return 0;
    }
  }

  Future<VaultPayload?> loadPayload(String vaultId, SecretKey packKey) async {
    final format = await _formatVersion(vaultId);
    if (format >= 1) {
      // v1: el árbol `repo/` es canónico. NO leer `vault.bin` (queda obsoleto
      // tras migrar/editar) — eso hacía que dispositivos bloqueados empujaran
      // snapshots viejos y "pesaran" de más en la nube.
      try {
        final dir = await VaultPaths.vaultDirectoryForId(vaultId);
        final fromTree = await VaultLocalStorage.loadFromTreeAt(dir);
        if (fromTree == null) {
          AppLogger.debug(
            'headless loadPayload: v1 sin árbol',
            tag: 'cloud_sync',
            context: {'vaultId': vaultId},
          );
          return null;
        }
        return _withRegistryDisplayName(vaultId, fromTree);
      } catch (e, st) {
        AppLogger.error(
          'headless loadPayload v1 tree failed',
          tag: 'cloud_sync',
          error: e,
          stackTrace: st,
          context: {'vaultId': vaultId},
        );
        return null;
      }
    }

    final cipher = await VaultStorage.instance.readVaultFile(
      vaultId,
      VaultPaths.cipherPayloadFile,
    );
    if (cipher == null || cipher.isEmpty) {
      AppLogger.debug(
        'headless loadPayload empty',
        tag: 'cloud_sync',
        context: {'vaultId': vaultId},
      );
      return null;
    }
    late final VaultPayload payload;
    if (await isPlain(vaultId)) {
      payload = VaultPayload.decodeUtf8(cipher);
    } else {
      final clear = await VaultCrypto.decryptPayload(
        blob: cipher,
        dek: packKey,
      );
      payload = VaultPayload.decodeUtf8(clear);
    }
    return _withRegistryDisplayName(vaultId, payload);
  }

  Future<VaultPayload> _withRegistryDisplayName(
    String vaultId,
    VaultPayload payload,
  ) async {
    final fromPayload = payload.displayName.trim();
    if (fromPayload.isNotEmpty) return payload;
    final registry = VaultRegistry.instance;
    await registry.load();
    final name = registry.entryFor(vaultId)?.displayName.trim() ?? '';
    if (name.isEmpty) return payload;
    return VaultPayload(
      version: payload.version,
      pages: payload.pages,
      displayName: name,
      pageOrderByParent: payload.pageOrderByParent,
      pageRevisions: payload.pageRevisions,
      pageAcl: payload.pageAcl,
      localProfiles: payload.localProfiles,
      comments: payload.comments,
      aiChatThreads: payload.aiChatThreads,
      aiActiveChatIndex: payload.aiActiveChatIndex,
      pageTemplates: payload.pageTemplates,
      jira: payload.jira,
      youtrack: payload.youtrack,
      trello: payload.trello,
      pageTombstones: payload.pageTombstones,
      syncClock: payload.syncClock,
      mcpReadablePageIds: payload.mcpReadablePageIds,
    );
  }

  Future<void> _applyDisplayNameToRegistry(
    String vaultId,
    String raw,
  ) async {
    final name = raw.trim();
    if (name.isEmpty) return;
    final registry = VaultRegistry.instance;
    await registry.load();
    final current = registry.entryFor(vaultId)?.displayName.trim() ?? '';
    if (current == name) return;
    await registry.rename(vaultId, name);
  }

  Future<void> savePayload({
    required String vaultId,
    required SecretKey packKey,
    required VaultPayload payload,
  }) async {
    AppLogger.debug(
      'headless savePayload',
      tag: 'cloud_sync',
      context: {
        'vaultId': vaultId,
        'pages': payload.pages.length,
        'displayName': payload.displayName,
      },
    );
    await _applyDisplayNameToRegistry(vaultId, payload.displayName);
    final format = await _formatVersion(vaultId);
    final dir = await VaultPaths.vaultDirectoryForId(vaultId);
    if (format >= 1) {
      await VaultLocalStorage.decomposeAndStoreAt(dir, payload);
      return;
    }
    if (payload.pages.isEmpty) {
      // Libreta aún no migrada localmente a v1 (p. ej. dispositivo que nunca
      // se desbloqueó en UI): vault.bin no tiene ningún guard de escritura,
      // a diferencia del árbol v1. Best-effort: si no se puede leer el
      // contenido actual, no bloqueamos (podría ser la primera escritura).
      // Se hace ANTES del candado (loadPayload en v0 no lo toma, así que no
      // hay riesgo de reentrada, pero sí de una ventana no atómica — igual
      // de best-effort que antes de este cambio).
      int existingPages = 0;
      try {
        final existing = await loadPayload(vaultId, packKey);
        existingPages = existing?.pages.length ?? 0;
      } catch (_) {
        existingPages = 0;
      }
      if (existingPages > 0) {
        AppLogger.warn(
          'headless savePayload (v0) skipped: refusing empty overwrite',
          tag: 'cloud_sync',
          context: {'vaultId': vaultId, 'existingPages': existingPages},
        );
        return;
      }
    }
    // Bajo el mismo candado que el árbol v1: evita que esta escritura v0
    // corra a la vez que una migración v0→v1 o un sync v1 de esta libreta.
    await VaultLocalStorage.runExclusive(dir.path, () async {
      final plain = payload.encodeUtf8();
      if (await isPlain(vaultId)) {
        await VaultStorage.instance.writeVaultFile(
          vaultId,
          VaultPaths.cipherPayloadFile,
          Uint8List.fromList(plain),
        );
        return;
      }
      final enc = await VaultCrypto.encryptPayload(plain: plain, dek: packKey);
      await VaultStorage.instance.writeVaultFile(
        vaultId,
        VaultPaths.cipherPayloadFile,
        enc,
      );
    });
  }

  /// Lee solo una página del árbol v1 (`repo/pages/...`), sin recomponer la
  /// libreta entera. Solo aplica al formato v1 en árbol — el legado v0 no
  /// tiene granularidad de página, así que devuelve `null` para él (el
  /// llamador debe recurrir a [loadPayload] completo en ese caso).
  Future<FolioPage?> loadSinglePage(String vaultId, String pageId) async {
    final format = await _formatVersion(vaultId);
    if (format < 1) return null;
    final dir = await VaultPaths.vaultDirectoryForId(vaultId);
    return VaultLocalStorage.loadPageFromTreeAt(dir, pageId);
  }

  Future<List<LocalPageComment>> loadSinglePageComments(
    String vaultId,
    String pageId,
  ) async {
    final format = await _formatVersion(vaultId);
    if (format < 1) return const [];
    final dir = await VaultPaths.vaultDirectoryForId(vaultId);
    return VaultLocalStorage.loadPageCommentsFromTreeAt(dir, pageId);
  }

  /// Escribe atómicamente solo una página en el árbol v1, sin reescribir la
  /// libreta entera. Requiere que la libreta ya esté migrada a v1 (`repo/`
  /// existente) — si no, lanza igual que [VaultLocalStorage.storePageAt].
  Future<void> saveSinglePage(
    String vaultId,
    FolioPage page,
    List<LocalPageComment> allComments,
  ) async {
    final dir = await VaultPaths.vaultDirectoryForId(vaultId);
    await VaultLocalStorage.storePageAt(dir, page, allComments);
  }

  Future<Uint8List?> exportPackBytes(String vaultId, SecretKey packKey) async {
    final payload = await loadPayload(vaultId, packKey);
    if (payload == null) return null;
    final pack = await buildVaultSyncPackFromDiskForVault(
      vaultId: vaultId,
      payload: payload,
    );
    return Uint8List.fromList(pack.encodeUtf8());
  }

  /// True si en disco hay árbol v1 con páginas (aunque loadPayload falle).
  Future<bool> _diskTreeHasPages(String vaultId) async {
    if (kIsWeb) return false;
    try {
      final dir = await VaultPaths.vaultDirectoryForId(vaultId);
      final treeDir = Directory(p.join(dir.path, 'repo'));
      return VaultLocalStorage.countPageDirs(treeDir) > 0;
    } catch (_) {
      return false;
    }
  }

  /// Merge remoto sobre disco. Devuelve si cambió el contenido local.
  Future<({bool ok, bool changed, String? fingerprint})> applyRemotePack({
    required String vaultId,
    required SecretKey packKey,
    required List<int> remotePackBytes,
    VaultPayload? baseline,
  }) async {
    try {
      final pack = VaultSyncPack.decodeFlexible(remotePackBytes);
      await materializeVaultSyncPackAttachmentsForVault(vaultId, pack);
      final local = await loadPayload(vaultId, packKey);
      if (local == null) {
        // No instalar remoto vacío / no pisar un árbol local que load no vio
        // (p. ej. race repo.tmp, vault.bin vacío tras migrar a v1).
        final remotePages = pack.payload.pages.length;
        final diskHasPages = await _diskTreeHasPages(vaultId);
        if (remotePages == 0) {
          AppLogger.warn(
            'headless applyRemotePack skipped: remote empty and no local',
            tag: 'cloud_sync',
            context: {'vaultId': vaultId, 'diskHasPages': diskHasPages},
          );
          return (ok: true, changed: false, fingerprint: null);
        }
        if (diskHasPages) {
          AppLogger.warn(
            'headless applyRemotePack skipped: loadPayload null but repo has pages',
            tag: 'cloud_sync',
            context: {'vaultId': vaultId, 'remotePages': remotePages},
          );
          return (ok: false, changed: false, fingerprint: null);
        }
        // Primera materialización / libreta vacía: instalar remoto tal cual.
        await savePayload(
          vaultId: vaultId,
          packKey: packKey,
          payload: pack.payload,
        );
        final outFp = VaultSyncMergeEngine.payloadFingerprint(pack.payload);
        AppLogger.info(
          'headless applyRemotePack installed remote (no local)',
          tag: 'cloud_sync',
          context: {'vaultId': vaultId},
        );
        return (ok: true, changed: true, fingerprint: outFp);
      }
      // No dejar que un remoto vacío borre contenido local vía merge/save.
      if (local.pages.isNotEmpty && pack.payload.pages.isEmpty) {
        AppLogger.warn(
          'headless applyRemotePack skipped: refuse empty remote over local pages',
          tag: 'cloud_sync',
          context: {
            'vaultId': vaultId,
            'localPages': local.pages.length,
          },
        );
        return (
          ok: true,
          changed: false,
          fingerprint: VaultSyncMergeEngine.payloadFingerprint(local),
        );
      }
      final localFp = VaultSyncMergeEngine.payloadFingerprint(local);
      final remoteFp = VaultSyncMergeEngine.payloadFingerprint(pack.payload);
      if (localFp == remoteFp) {
        AppLogger.debug(
          'headless applyRemotePack: identical',
          tag: 'cloud_sync',
          context: {'vaultId': vaultId},
        );
        await _applyDisplayNameToRegistry(vaultId, pack.payload.displayName);
        return (ok: true, changed: false, fingerprint: localFp);
      }
      final result = _merge.merge(
        local: local,
        remote: pack.payload,
        baseline: baseline,
      );
      await savePayload(
        vaultId: vaultId,
        packKey: packKey,
        payload: result.payload,
      );
      await materializeVaultSyncPackAttachmentsForVault(
        vaultId,
        VaultSyncPack(payload: result.payload, attachments: pack.attachments),
      );
      final outFp = VaultSyncMergeEngine.payloadFingerprint(result.payload);
      AppLogger.info(
        'headless applyRemotePack ok',
        tag: 'cloud_sync',
        context: {
          'vaultId': vaultId,
          'changed': result.changed,
        },
      );
      return (ok: true, changed: result.changed, fingerprint: outFp);
    } on VaultEmptyOverwriteException catch (e) {
      // La propia guarda anti-vaciado nos ha protegido de una escritura
      // vacía (p. ej. una lectura a medio mover del árbol por una carrera
      // con la sesión activa) — esto es un rechazo benigno, no un fallo:
      // el disco sigue intacto. No debe verse como error de sync en la UI.
      AppLogger.warn(
        'headless applyRemotePack skipped: local guard refused empty write',
        tag: 'cloud_sync',
        context: {'vaultId': vaultId, 'error': '$e'},
      );
      return (ok: true, changed: false, fingerprint: null);
    } catch (e) {
      AppLogger.error(
        'headless applyRemotePack failed',
        tag: 'cloud_sync',
        error: e,
        context: {'vaultId': vaultId},
      );
      return (ok: false, changed: false, fingerprint: null);
    }
  }
}

/// Construye pack vía [VaultStorage] (web + escritorio).
Future<VaultSyncPack> buildVaultSyncPackFromDiskForVault({
  required String vaultId,
  required VaultPayload payload,
}) async {
  final paths = VaultSyncMergeEngine.collectAttachmentPaths(payload);
  final attachments = <VaultSyncPackAttachment>[];
  final storage = VaultStorage.instance;
  final sha = Sha256();
  for (final rel in paths) {
    final normalized = rel.replaceAll(r'\', '/');
    final bytes = await storage.readAttachment(vaultId, normalized) ??
        await storage.readVaultFile(vaultId, normalized);
    if (bytes == null || bytes.isEmpty) continue;
    final hash = await sha.hash(bytes);
    final hex =
        hash.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    attachments.add(
      VaultSyncPackAttachment(
        path: normalized,
        sha256Hex: hex,
        bytes: bytes,
      ),
    );
  }
  return VaultSyncPack(payload: payload, attachments: attachments);
}

Future<void> materializeVaultSyncPackAttachmentsForVault(
  String vaultId,
  VaultSyncPack pack,
) async {
  if (pack.attachments.isEmpty) return;
  final storage = VaultStorage.instance;
  final sha = Sha256();
  final prefix = '${VaultPaths.attachmentsDirName}/';
  for (final att in pack.attachments) {
    final path = att.path.replaceAll(r'\', '/');
    if (!path.startsWith(prefix)) continue;
    if (att.sha256Hex.isNotEmpty) {
      final existing = await storage.readAttachment(vaultId, path) ??
          await storage.readVaultFile(vaultId, path);
      if (existing != null && existing.isNotEmpty) {
        final hash = await sha.hash(existing);
        final hex =
            hash.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
        if (hex == att.sha256Hex) continue;
      }
    }
    await storage.writeVaultFile(
      vaultId,
      path,
      Uint8List.fromList(att.bytes),
    );
  }
}
