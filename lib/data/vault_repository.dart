import 'dart:typed_data';

import '../crypto/vault_crypto.dart';
import '../models/block.dart';
import '../models/folio_page.dart';
import 'vault_payload.dart';
import 'vault_paths.dart';

class VaultRepository {
  /// Crea cofre nuevo: escribe `vault.keys` y `vault.bin`.
  Future<Uint8List> createVault({
    required String password,
    List<FolioPage>? initialPages,
  }) async {
    final dekBytes = VaultCrypto.randomBytes(VaultCrypto.dekLength);
    final wrapped = await VaultCrypto.wrapDek(
      dek: dekBytes,
      password: password,
    );
    final dek = await VaultCrypto.dekFromBytes(dekBytes);
    final payload = VaultPayload(
      pages:
          initialPages ??
          [
            FolioPage(
              id: 'p1',
              title: 'Bienvenida',
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
              title: 'Notas del día',
              parentId: 'p1',
              blocks: [
                FolioBlock(id: 'p2_b0', type: 'bullet', text: 'Primera nota'),
              ],
            ),
            FolioPage(
              id: 'p3',
              title: 'Borrador',
              blocks: [FolioBlock(id: 'p3_b0', type: 'paragraph', text: '')],
            ),
          ],
    );
    final enc = await VaultCrypto.encryptPayload(
      plain: payload.encodeUtf8(),
      dek: dek,
    );
    await (await VaultPaths.wrappedDekPath()).writeAsBytes(wrapped);
    await (await VaultPaths.cipherPayloadPath()).writeAsBytes(enc);
    return dekBytes;
  }

  Future<Uint8List> unlockWithPassword(String password) async {
    final wrapped = await (await VaultPaths.wrappedDekPath()).readAsBytes();
    return VaultCrypto.unwrapDek(wrapped: wrapped, password: password);
  }

  Future<VaultPayload> loadPayload(List<int> dekBytes) async {
    final dek = await VaultCrypto.dekFromBytes(dekBytes);
    final enc = await (await VaultPaths.cipherPayloadPath()).readAsBytes();
    final clear = await VaultCrypto.decryptPayload(blob: enc, dek: dek);
    return VaultPayload.decodeUtf8(clear);
  }

  Future<void> savePayload(VaultPayload payload, List<int> dekBytes) async {
    final dek = await VaultCrypto.dekFromBytes(dekBytes);
    final enc = await VaultCrypto.encryptPayload(
      plain: payload.encodeUtf8(),
      dek: dek,
    );
    await (await VaultPaths.cipherPayloadPath()).writeAsBytes(enc);
  }
}
