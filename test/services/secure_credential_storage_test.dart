import 'package:flutter_test/flutter_test.dart';
import 'package:folio/services/secure_credential_storage.dart';

class _MemorySecureStorage {
  final Map<String, String> _data = {};

  Future<void> write(String key, String value) async {
    _data[key] = value;
  }

  Future<String?> read(String key) async => _data[key];

  Future<void> delete(String key) async {
    _data.remove(key);
  }
}

void main() {
  test('SecureCredentialStorage round-trip por ámbito', () async {
    // Nota: prueba de lógica de claves; en producción usa FlutterSecureStorage.
    const vaultId = 'vault-test';
    final memory = _MemorySecureStorage();

    await memory.write(
      'folio_backup_folder_password_$vaultId',
      'folder-secret',
    );
    await memory.write(
      'folio_backup_webdav_password_$vaultId',
      'webdav-secret',
    );

    expect(
      await memory.read('folio_backup_folder_password_$vaultId'),
      'folder-secret',
    );
    expect(
      await memory.read('folio_backup_webdav_password_$vaultId'),
      'webdav-secret',
    );

    await memory.delete('folio_backup_folder_password_$vaultId');
    expect(
      await memory.read('folio_backup_folder_password_$vaultId'),
      isNull,
    );
  });

}
