import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../crypto/vault_crypto.dart';
import '../../data/storage/vault_storage.dart';
import '../../data/vault_payload.dart';
import '../../data/vault_paths.dart';
import '../../data/vault_registry.dart';
import '../quick_unlock_storage.dart';
import '../app_logger.dart';
import '../sync/vault_sync_merge.dart';
import '../sync/vault_sync_pack.dart';
import 'device_sync_key_cache.dart';

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
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (await isPlain(vaultId)) {
      if (uid != null && uid.isNotEmpty) {
        final key = await DeviceSyncKeyCache.plainPackKey(
          uid: uid,
          vaultId: vaultId,
        );
        final raw = await key.extractBytes();
        await _keys.save(vaultId, raw);
        return key;
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

  Future<VaultPayload?> loadPayload(String vaultId, SecretKey packKey) async {
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
