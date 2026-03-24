import 'dart:typed_data';

import '../crypto/vault_crypto.dart';
import '../models/block.dart';
import '../models/folio_page.dart';
import 'vault_payload.dart';
import 'vault_paths.dart';

class VaultRepository {
  static const String _modeEncrypted = 'encrypted';
  static const String _modePlain = 'plain';

  Future<bool> isPlaintextVault() async {
    final modePath = await VaultPaths.vaultModePath();
    if (!modePath.existsSync()) return false;
    final raw = await modePath.readAsString();
    return raw.trim().toLowerCase() == _modePlain;
  }

  /// Crea cofre nuevo: escribe `vault.keys` y `vault.bin`.
  Future<Uint8List?> createVault({
    String? password,
    bool encrypted = true,
    List<FolioPage>? initialPages,
  }) async {
    final payload = VaultPayload(
      pages:
          initialPages ??
          [
            FolioPage(
              id: 'p1',
              title: 'Welcome',
              blocks: [
                FolioBlock(
                  id: 'p1_b0',
                  type: 'paragraph',
                  text:
                      'Folio guarda tus páginas cifradas en este dispositivo. '
                      'Usa la barra lateral para organizar el árbol y escribe en bloques. '
                      'Pulsa / para cambiar el tipo de bloque.',
                ),
              ],
            ),
            FolioPage(
              id: 'p2',
              title: 'Daily notes',
              parentId: 'p1',
              blocks: [
                FolioBlock(id: 'p2_b0', type: 'bullet', text: 'Primera nota'),
              ],
            ),
            FolioPage(
              id: 'p3',
              title: 'Draft',
              blocks: [FolioBlock(id: 'p3_b0', type: 'paragraph', text: '')],
            ),
          ],
    );
    final modePath = await VaultPaths.vaultModePath();
    final payloadPath = await VaultPaths.cipherPayloadPath();
    final wrappedPath = await VaultPaths.wrappedDekPath();
    if (encrypted) {
      if (password == null || password.isEmpty) {
        throw StateError('Se requiere contraseña para cofre cifrado');
      }
      final dekBytes = VaultCrypto.randomBytes(VaultCrypto.dekLength);
      final wrapped = await VaultCrypto.wrapDek(
        dek: dekBytes,
        password: password,
      );
      final dek = await VaultCrypto.dekFromBytes(dekBytes);
      final enc = await VaultCrypto.encryptPayload(
        plain: payload.encodeUtf8(),
        dek: dek,
      );
      await wrappedPath.writeAsBytes(wrapped);
      await payloadPath.writeAsBytes(enc);
      await modePath.writeAsString(_modeEncrypted, flush: true);
      return dekBytes;
    }
    if (wrappedPath.existsSync()) {
      await wrappedPath.delete();
    }
    await payloadPath.writeAsBytes(payload.encodeUtf8());
    await modePath.writeAsString(_modePlain, flush: true);
    return null;
  }

  Future<Uint8List> unlockWithPassword(String password) async {
    final wrapped = await (await VaultPaths.wrappedDekPath()).readAsBytes();
    return VaultCrypto.unwrapDek(wrapped: wrapped, password: password);
  }

  Future<VaultPayload> loadPayload(List<int>? dekBytes) async {
    final raw = await (await VaultPaths.cipherPayloadPath()).readAsBytes();
    if (await isPlaintextVault()) {
      return VaultPayload.decodeUtf8(raw);
    }
    if (dekBytes == null) {
      throw StateError('Se requiere DEK para abrir cofre cifrado');
    }
    final dek = await VaultCrypto.dekFromBytes(dekBytes);
    final clear = await VaultCrypto.decryptPayload(blob: raw, dek: dek);
    return VaultPayload.decodeUtf8(clear);
  }

  Future<void> savePayload(VaultPayload payload, List<int>? dekBytes) async {
    if (await isPlaintextVault()) {
      await (await VaultPaths.cipherPayloadPath()).writeAsBytes(payload.encodeUtf8());
      return;
    }
    if (dekBytes == null) {
      throw StateError('Se requiere DEK para guardar cofre cifrado');
    }
    final dek = await VaultCrypto.dekFromBytes(dekBytes);
    final enc = await VaultCrypto.encryptPayload(
      plain: payload.encodeUtf8(),
      dek: dek,
    );
    await (await VaultPaths.cipherPayloadPath()).writeAsBytes(enc);
  }

  Future<void> rewrapDek({
    required String currentPassword,
    required String newPassword,
  }) async {
    final wrappedPath = await VaultPaths.wrappedDekPath();
    final wrapped = await wrappedPath.readAsBytes();
    final dek = await VaultCrypto.unwrapDek(
      wrapped: wrapped,
      password: currentPassword,
    );
    final rewrapped = await VaultCrypto.wrapDek(dek: dek, password: newPassword);
    await wrappedPath.writeAsBytes(rewrapped, flush: true);
  }
}
