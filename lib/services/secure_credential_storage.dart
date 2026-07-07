import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Ámbito de contraseñas para destinos de copia de seguridad remotos.
enum BackupCredentialScope { folder, webdav }

/// Almacén seguro de contraseñas de backup (Keychain / Keystore / DPAPI).
class SecureCredentialStorage {
  SecureCredentialStorage({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
          );

  final FlutterSecureStorage _storage;

  static String _key(String vaultId, BackupCredentialScope scope) {
    final vid = vaultId.trim();
    switch (scope) {
      case BackupCredentialScope.folder:
        return 'folio_backup_folder_password_$vid';
      case BackupCredentialScope.webdav:
        return 'folio_backup_webdav_password_$vid';
    }
  }

  Future<String?> readPassword(
    String vaultId,
    BackupCredentialScope scope,
  ) async {
    final v = await _storage.read(key: _key(vaultId, scope));
    if (v == null || v.isEmpty) return null;
    return v;
  }

  Future<void> writePassword(
    String vaultId,
    BackupCredentialScope scope,
    String password,
  ) async {
    final safe = password;
    if (safe.isEmpty) {
      await deletePassword(vaultId, scope);
      return;
    }
    await _storage.write(key: _key(vaultId, scope), value: safe);
  }

  Future<void> deletePassword(String vaultId, BackupCredentialScope scope) async {
    await _storage.delete(key: _key(vaultId, scope));
  }
}
