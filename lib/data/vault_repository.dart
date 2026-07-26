import 'dart:typed_data';

import 'package:flutter/widgets.dart' show Locale;

import '../core/errors/vault_corruption_exception.dart';
import '../crypto/vault_crypto.dart';
import '../domain/vault/vault_migration.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/folio_page.dart';
import '../models/folio_usage_intent.dart';
import 'vault_local_storage.dart'
    show VaultEmptyOverwriteException, VaultLocalStorage;
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
    var wrapped = await VaultPaths.readWrappedDek();
    if (wrapped == null) {
      // Recuperación: si el archivo principal falta, intenta la copia .bak.
      wrapped = await VaultPaths.readWrappedDekBackup();
      if (wrapped == null) throw StateError('vault.keys no encontrado');
      await VaultPaths.restoreWrappedDekFromBackup();
    }
    try {
      return await VaultCrypto.unwrapDek(wrapped: wrapped, password: password);
    } on VaultCryptoException {
      // Puede ser contraseña incorrecta o vault.keys corrupto: probar .bak
      // solo si difiere del principal (evita segundo intento inútil).
      final backup = await VaultPaths.readWrappedDekBackup();
      if (backup == null || _bytesEqual(backup, wrapped)) rethrow;
      final dek = await VaultCrypto.unwrapDek(
        wrapped: backup,
        password: password,
      );
      // El backup funciona y el principal no: restaurar el principal.
      await VaultPaths.restoreWrappedDekFromBackup();
      return dek;
    }
  }

  static bool _bytesEqual(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Va bajo el mismo candado por libreta que `VaultLocalStorage` (formato
  /// v1), para que una lectura/escritura v0 no pueda solaparse con una
  /// migración v0→v1 o un sync headless tocando la misma libreta.
  Future<VaultPayload> loadPayload(List<int>? dekBytes) async {
    final vaultDir = await VaultPaths.vaultDirectory();
    return VaultLocalStorage.runExclusive(vaultDir.path, () async {
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
    });
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

  /// El chequeo anti-vacío (`_existingV0PageCount`, que a su vez llama a
  /// [loadPayload]) corre ANTES de tomar el candado de abajo — si estuviera
  /// dentro, `loadPayload` intentaría re-entrar en el mismo candado y
  /// bloquearía para siempre. Es un chequeo best-effort igualmente (ver su
  /// doc), así que esa pequeña ventana no atómica no empeora nada; lo que sí
  /// gana en firmeza es que la escritura real ya no puede solaparse con una
  /// migración v0→v1 o un sync headless de la misma libreta.
  Future<void> savePayload(VaultPayload payload, List<int>? dekBytes) async {
    if (payload.pages.isEmpty) {
      final existingPages = await _existingV0PageCount(dekBytes);
      if (existingPages > 0) {
        throw VaultEmptyOverwriteException(
          'Refusing to replace vault.bin ($existingPages pages) with an '
          'empty payload',
        );
      }
    }
    final vaultDir = await VaultPaths.vaultDirectory();
    await VaultLocalStorage.runExclusive(vaultDir.path, () async {
      if (await isPlaintextVault()) {
        await VaultPaths.writeCipherPayload(
          Uint8List.fromList(payload.encodeUtf8()),
        );
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
    });
  }

  /// Best-effort: cuenta páginas del `vault.bin` actual antes de sobrescribir
  /// con un payload vacío. Si no se puede leer (no existe aún, corrupto, DEK
  /// que no coincide) no bloquea el guardado — solo protege el caso claro de
  /// "había contenido en disco, el payload entrante llega vacío".
  Future<int> _existingV0PageCount(List<int>? dekBytes) async {
    try {
      final existing = await loadPayload(dekBytes);
      return existing.pages.length;
    } catch (_) {
      return 0;
    }
  }

  /// Restaura `vault.bin` desde la copia `.bak` local. También intenta
  /// recuperar `vault.keys` y `vault.mode` si faltan y tienen `.bak`.
  Future<bool> restoreCipherPayloadFromLocalBackup() async {
    final restored = await VaultPaths.restoreCipherPayloadFromBackup();
    try {
      if (await VaultPaths.readWrappedDek() == null) {
        await VaultPaths.restoreWrappedDekFromBackup();
      }
      if (await VaultPaths.readVaultMode() == null) {
        await VaultPaths.restoreVaultModeFromBackup();
      }
    } catch (_) {
      // La restauración de keys/mode es best-effort.
    }
    return restored;
  }

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
