import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
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
  ///
  /// [kdfProfile] deja elegir el perfil Argon2id (`VaultCrypto.profileBalanced`
  /// o `VaultCrypto.profileHardened`) con el que se envuelve el DEK; `null`
  /// usa el perfil reforzado por defecto (`VaultCrypto.currentWrapVersion`).
  Future<Uint8List?> createVault({
    String? password,
    bool encrypted = true,
    List<FolioPage>? initialPages,
    VaultStarterContent starterContent = VaultStarterContent.enabled,
    AppLocalizations? starterL10n,
    List<FolioUsageIntent> usageIntents = const [FolioUsageIntent.notes],
    bool includeQuillStarterPage = false,
    int? kdfProfile,
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
        version: kdfProfile,
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
  ///
  /// En web no hay filesystem: el candado usa el `vaultId` activo (string)
  /// para no llamar a `VaultPaths.vaultDirectory()` / path_provider.
  Future<VaultPayload> loadPayload(List<int>? dekBytes) async {
    final lockKey = await _payloadLockKey();
    return VaultLocalStorage.runExclusive(lockKey, () async {
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

  Future<String> _payloadLockKey() async {
    if (kIsWeb) {
      final id = VaultPaths.activeVaultId;
      if (id == null || id.isEmpty) {
        throw StateError('No hay libreta activa');
      }
      return id;
    }
    final vaultDir = await VaultPaths.vaultDirectory();
    return vaultDir.path;
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
    final lockKey = await _payloadLockKey();
    await VaultLocalStorage.runExclusive(lockKey, () async {
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

  /// Va bajo el mismo candado por libreta que `loadPayload`/`savePayload`
  /// (ver nota en la línea ~108) para que esta lectura-descifrado-reescritura
  /// de `vault.keys` no pueda solaparse con una restauración de cloud/sync
  /// headless tocando el mismo archivo.
  ///
  /// [targetVersion] fuerza el perfil Argon2id del nuevo envoltorio. Si se
  /// omite, se **conserva** el perfil actual de la libreta (legacy se sube a
  /// `profileBalanced`, ya que nunca se vuelve a escribir en formato legacy;
  /// v1/v2 se mantienen tal cual) — así cambiar de contraseña no re-endurece
  /// silenciosamente el cifrado de quien eligió el perfil "Balanceado".
  Future<void> rewrapDek({
    required String currentPassword,
    required String newPassword,
    int? targetVersion,
  }) async {
    final vaultDir = await VaultPaths.vaultDirectory();
    await VaultLocalStorage.runExclusive(vaultDir.path, () async {
      final wrapped = await VaultPaths.readWrappedDek();
      if (wrapped == null) throw StateError('vault.keys no encontrado');
      final currentVersion = VaultCrypto.wrapVersion(wrapped);
      final effectiveTarget =
          targetVersion ??
          (currentVersion == 0 ? VaultCrypto.profileBalanced : currentVersion);
      final dek = await VaultCrypto.unwrapDek(
        wrapped: wrapped,
        password: currentPassword,
      );
      final rewrapped = await VaultCrypto.wrapDek(
        dek: dek,
        password: newPassword,
        version: effectiveTarget,
      );
      await VaultPaths.writeWrappedDek(rewrapped);
    });
  }

  /// Si `vault.keys` está en formato legacy (sin byte de versión), lo
  /// re-envuelve en el sitio con la misma contraseña al perfil "Balanceado"
  /// (`VaultCrypto.profileBalanced`) — migración transparente al desbloquear
  /// que cierra el hueco de vaults antiguos débiles. NO fuerza a nadie ya en
  /// v1/v2 hacia el perfil reforzado: eso solo ocurre si el usuario lo pide
  /// explícitamente vía `upgradeToHardenedProfile`. Best-effort: un fallo
  /// aquí (I/O, contraseña ya no coincide por una carrera rarísima, etc.) no
  /// debe afectar a una sesión que ya se desbloqueó con éxito.
  Future<void> upgradeKdfIfNeeded(String password) async {
    try {
      final wrapped = await VaultPaths.readWrappedDek();
      if (wrapped == null) return;
      if (VaultCrypto.wrapVersion(wrapped) >= VaultCrypto.profileBalanced) {
        return;
      }
      await rewrapDek(
        currentPassword: password,
        newPassword: password,
        targetVersion: VaultCrypto.profileBalanced,
      );
    } catch (_) {
      // Best-effort: la libreta ya está desbloqueada: no propagar el error.
    }
  }

  /// Acción explícita del usuario ("Actualizar a cifrado reforzado" en
  /// Ajustes): sube `vault.keys` al perfil `profileHardened` con la misma
  /// contraseña. A diferencia de `upgradeKdfIfNeeded`, NO es best-effort —
  /// propaga errores (p. ej. contraseña incorrecta) para que la UI los muestre.
  Future<void> upgradeToHardenedProfile(String password) => rewrapDek(
    currentPassword: password,
    newPassword: password,
    targetVersion: VaultCrypto.profileHardened,
  );

  /// Perfil Argon2id actual de `vault.keys` (`0` = legacy, `1` = Balanceado,
  /// `2` = Reforzado), sin necesitar la contraseña — para mostrar el estado
  /// en Ajustes. Devuelve `null` si la libreta no tiene `vault.keys` (p. ej.
  /// libreta en texto plano).
  Future<int?> currentKdfProfile() async {
    final wrapped = await VaultPaths.readWrappedDek();
    if (wrapped == null) return null;
    return VaultCrypto.wrapVersion(wrapped);
  }

  /// Pasa una libreta en texto plano a cifrado con [password]. Sobreescribe
  /// `vault.mode`, `vault.keys` y `vault.bin`.
  Future<Uint8List> encryptPlainVaultWithPassword({
    required VaultPayload payload,
    required String password,
    int? kdfProfile,
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
      version: kdfProfile,
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
