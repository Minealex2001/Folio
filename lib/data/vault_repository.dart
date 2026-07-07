import 'dart:typed_data';

import 'package:flutter/widgets.dart' show Locale;

import '../core/errors/vault_corruption_exception.dart';
import '../crypto/vault_crypto.dart';
import '../domain/vault/vault_migration.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/folio_page.dart';
import '../models/folio_usage_intent.dart';
import 'vault_payload.dart';
import 'vault_paths.dart';
import 'vault_starter_pages.dart';

export 'vault_starter_pages.dart' show VaultStarterContent, buildVaultStarterPages;

class VaultRepository {
  static const String _modeEncrypted = 'encrypted';
  static const String _modePlain = 'plain';

  Future<bool> isPlaintextVault() async {
    final raw = await VaultPaths.readVaultMode();
    if (raw == null) return false;
    return raw.trim().toLowerCase() == _modePlain;
  }

  /// Crea libreta nueva: escribe `vault.keys` y `vault.bin`.
  Future<Uint8List?> createVault({
    String? password,
    bool encrypted = true,
    List<FolioPage>? initialPages,
    VaultStarterContent starterContent = VaultStarterContent.enabled,
    AppLocalizations? starterL10n,
    List<FolioUsageIntent> usageIntents = const [FolioUsageIntent.notes],
    bool includeQuillStarterPage = false,
  }) async {
    final l10n = starterL10n ?? lookupAppLocalizations(const Locale('es'));
    final payload = VaultPayload(
      pages:
          initialPages ??
          buildVaultStarterPages(
            starterContent: starterContent,
            l10n: l10n,
            usageIntents: usageIntents,
            includeQuillPage: includeQuillStarterPage,
          ),
    );
    if (encrypted) {
      if (password == null || password.isEmpty) {
        throw StateError('Se requiere contraseña para libreta cifrada');
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
      await VaultPaths.writeWrappedDek(wrapped);
      await VaultPaths.writeCipherPayload(enc);
      await VaultPaths.writeVaultMode(_modeEncrypted);
      return dekBytes;
    }
    await VaultPaths.deleteWrappedDek();
    await VaultPaths.writeCipherPayload(Uint8List.fromList(payload.encodeUtf8()));
    await VaultPaths.writeVaultMode(_modePlain);
    return null;
  }

  Future<Uint8List> unlockWithPassword(String password) async {
    final wrapped = await VaultPaths.readWrappedDek();
    if (wrapped == null) throw StateError('vault.keys no encontrado');
    return VaultCrypto.unwrapDek(wrapped: wrapped, password: password);
  }

  Future<VaultPayload> loadPayload(List<int>? dekBytes) async {
    final primary = await VaultPaths.readCipherPayload();
    if (primary == null) {
      throw StateError('vault.bin no encontrado');
    }
    try {
      return await _decodeAndMigrate(primary, dekBytes);
    } on VaultCorruptionException {
      final backup = await VaultPaths.readCipherPayloadBackup();
      if (backup == null) rethrow;
      return await _decodeAndMigrate(
        backup,
        dekBytes,
        restoredFromBackup: true,
      );
    }
  }

  Future<VaultPayload> _decodeAndMigrate(
    Uint8List raw,
    List<int>? dekBytes, {
    bool restoredFromBackup = false,
  }) async {
    try {
      final VaultPayload payload;
      if (await isPlaintextVault()) {
        payload = VaultPayload.decodeUtf8(raw);
      } else {
        if (dekBytes == null) {
          throw StateError('Se requiere DEK para abrir libreta cifrada');
        }
        final dek = await VaultCrypto.dekFromBytes(dekBytes);
        final clear = await VaultCrypto.decryptPayload(blob: raw, dek: dek);
        payload = VaultPayload.decodeUtf8(clear);
      }
      return migrateVaultPayload(payload);
    } on VaultCorruptionException {
      rethrow;
    } on VaultCryptoException catch (e) {
      throw VaultCorruptionException(
        'No se pudo descifrar la libreta',
        cause: e,
        restoredFromBackup: restoredFromBackup,
      );
    } catch (e) {
      throw VaultCorruptionException(
        'No se pudo leer la libreta',
        cause: e,
        restoredFromBackup: restoredFromBackup,
      );
    }
  }

  Future<void> savePayload(VaultPayload payload, List<int>? dekBytes) async {
    if (await isPlaintextVault()) {
      await VaultPaths.writeCipherPayload(Uint8List.fromList(payload.encodeUtf8()));
      return;
    }
    if (dekBytes == null) {
      throw StateError('Se requiere DEK para guardar libreta cifrada');
    }
    final dek = await VaultCrypto.dekFromBytes(dekBytes);
    final enc = await VaultCrypto.encryptPayload(
      plain: payload.encodeUtf8(),
      dek: dek,
    );
    await VaultPaths.writeCipherPayload(enc);
  }

  /// Restaura `vault.bin` desde la copia `.bak` local.
  Future<bool> restoreCipherPayloadFromLocalBackup() =>
      VaultPaths.restoreCipherPayloadFromBackup();

  Future<void> rewrapDek({
    required String currentPassword,
    required String newPassword,
  }) async {
    final wrapped = await VaultPaths.readWrappedDek();
    if (wrapped == null) throw StateError('vault.keys no encontrado');
    final dek = await VaultCrypto.unwrapDek(
      wrapped: wrapped,
      password: currentPassword,
    );
    final rewrapped = await VaultCrypto.wrapDek(
      dek: dek,
      password: newPassword,
    );
    await VaultPaths.writeWrappedDek(rewrapped);
  }

  /// Pasa una libreta en texto plano a cifrado con [password]. Sobreescribe
  /// `vault.mode`, `vault.keys` y `vault.bin`.
  Future<Uint8List> encryptPlainVaultWithPassword({
    required VaultPayload payload,
    required String password,
  }) async {
    if (!(await isPlaintextVault())) {
      throw StateError('La libreta no está en modo texto plano');
    }
    if (password.isEmpty) {
      throw StateError('Se requiere contraseña');
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
    await VaultPaths.writeWrappedDek(wrapped);
    await VaultPaths.writeCipherPayload(enc);
    await VaultPaths.writeVaultMode(_modeEncrypted);
    return dekBytes;
  }
}
