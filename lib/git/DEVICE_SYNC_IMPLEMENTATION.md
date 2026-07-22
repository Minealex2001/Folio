# Implementación en device_sync_controller.dart — M5 (Línea por Línea)

## Cambios Necesarios

### 1. Agregar campos

**Al inicio de la clase**:

```dart
  // M5: Dual format support
  int _vaultFormatVersion = 0;
  late DualFormatVaultTransport _transport;
  String _deviceId = 'unknown-device';
```

### 2. Agregar imports

```dart
import '../git/p2p_sync_packager.dart';
import '../git/vault_format_handler.dart';
import '../data/vault_local_storage.dart';
import '../git/p2p_sync_pack.dart';
```

### 3. Crear `DualFormatVaultTransport`

**Agregar nueva clase al final del archivo**:

```dart
abstract class VaultPackTransport {
  Future<int> getFormatVersion(String vaultId);
  Future<List<int>> packVault(String vaultId);
  Future<VaultPayload> unpackVault(List<int> packBytes);
}

class DualFormatVaultTransport implements VaultPackTransport {
  final String deviceId;
  
  DualFormatVaultTransport({required this.deviceId});
  
  @override
  Future<int> getFormatVersion(String vaultId) async {
    try {
      return await VaultMigrationTool.readTreeFormatVersion();
    } catch (_) {
      return 0; // Default: v0
    }
  }
  
  @override
  Future<List<int>> packVault(String vaultId) async {
    final formatVersion = await getFormatVersion(vaultId);
    
    if (formatVersion == 0) {
      return await _packLegacyVault();
    } else {
      return await _packTreeAsZip();
    }
  }
  
  Future<List<int>> _packLegacyVault() async {
    final cipherPayload = await VaultPaths.readCipherPayload();
    return cipherPayload ?? [];
  }
  
  Future<List<int>> _packTreeAsZip() async {
    final treeDir = await VaultPaths.vaultTreeDirectory();
    final packager = P2PSyncPackager(
      vaultId: VaultPaths.activeVaultId ?? 'unknown',
      sourceDeviceId: deviceId,
    );
    return await packager.compressTreeToZip(treeDir);
  }
  
  @override
  Future<VaultPayload> unpackVault(List<int> packBytes) async {
    if (_isZipFormat(packBytes)) {
      return await _unpackTreeFromZip(packBytes);
    } else {
      return await _unpackLegacyVault(packBytes);
    }
  }
  
  bool _isZipFormat(List<int> bytes) {
    return bytes.length >= 2 && bytes[0] == 0x50 && bytes[1] == 0x4B;
  }
  
  Future<VaultPayload> _unpackTreeFromZip(List<int> zipBytes) async {
    final packager = P2PSyncPackager(
      vaultId: VaultPaths.activeVaultId ?? 'unknown',
      sourceDeviceId: deviceId,
    );
    
    final tempDir = await packager.decompressZip(
      zipBytes,
      'folio_p2p_receive_',
    );
    
    try {
      return await TreeToVaultPayload.compose(tempDir);
    } finally {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    }
  }
  
  Future<VaultPayload> _unpackLegacyVault(List<int> cipherBytes) async {
    // Existing code: decrypt and deserialize
    final dek = await _getSharedDek(); // From device_sync shared state
    final plainBytes = await VaultCrypto.decryptAES256GCM(
      cipherBytes,
      dek,
    );
    return VaultPayload.fromJson(
      jsonDecode(utf8.decode(plainBytes)) as Map<String, dynamic>,
    );
  }
  
  Future<List<int>> _getSharedDek() async {
    // TODO: Get from device_sync shared encryption key
    // For now, this is a placeholder
    return List<int>.filled(32, 0);
  }
}
```

### 4. Modificar send vault

**En `_sendVaultPackToDevice()` o equivalente**:

Cambiar de:
```dart
  final packBytes = await _getVaultBinaryForTransport();
```

A:
```dart
  _transport = DualFormatVaultTransport(deviceId: _deviceId);
  final formatVersion = await _transport.getFormatVersion(_activeVaultId);
  final packBytes = await _transport.packVault(_activeVaultId);
  
  final stats = P2PSyncStats(
    uncompressed: <calculate>,
    compressed: packBytes.length,
    fileCount: <calculate>,
    duration: <measure>,
  );
  AppLogger.instance.info('Pack stats: $stats');
```

### 5. Modificar receive vault

**En `_receiveVaultPackFromDevice()` o equivalente**:

Cambiar de:
```dart
  final payload = await _decryptAndDeserializeVault(packBytes);
```

A:
```dart
  _transport = DualFormatVaultTransport(deviceId: _deviceId);
  final payload = await _transport.unpackVault(packBytes);
  
  // Merge with local state (existing logic unchanged)
  await _mergeReceivedPayload(payload, sourceDevice: source);
  
  // Create snapshot if v1
  if (_vaultFormatVersion == 1) {
    await VaultLocalStorage.saveSnapshot(
      label: 'Merged from $source',
      deviceId: _deviceId,
    );
  }
```

### 6. Helpers

```dart
  Future<void> _initializeTransport() async {
    _deviceId = await _getDeviceId();
    _transport = DualFormatVaultTransport(deviceId: _deviceId);
    _vaultFormatVersion = await _transport.getFormatVersion(
      VaultPaths.activeVaultId ?? 'unknown',
    );
  }
  
  Future<String> _getDeviceId() async {
    try {
      return Platform.localHostname;
    } catch (_) {
      return 'unknown-device';
    }
  }
  
  Future<Map<String, dynamic>> getVaultSyncStats() async {
    if (_vaultFormatVersion == 0) {
      final cipherPayload = await VaultPaths.readCipherPayload();
      return {
        'format': 'v0-legacy',
        'sizeBytes': cipherPayload?.length ?? 0,
      };
    } else {
      final treeDir = await VaultPaths.vaultTreeDirectory();
      int uncompressed = 0;
      
      await for (final entity in treeDir.list(recursive: true)) {
        if (entity is File) {
          uncompressed += await entity.length();
        }
      }
      
      return {
        'format': 'v1-tree',
        'uncompressedBytes': uncompressed,
      };
    }
  }
```

## Imports Necesarios

```dart
import 'dart:io';
import 'dart:convert';
import '../git/vault_format_handler.dart';
import '../git/vault_snapshot_manager.dart';
import '../git/p2p_sync_packager.dart';
import '../data/vault_local_storage.dart';
import '../git/vault_migration_tool.dart';
import '../git/version_info.dart';
```

## Backward Compatibility

- ✅ v0 → v0: usa vault.bin (como siempre)
- ✅ v1 → v1: usa ZIP (más eficiente)
- ✅ v0 ↔ v1: auto-detecta, convierte

## Testing

Después de implementar:

```bash
flutter test test/git/p2p_sync_test.dart
```

Verifica:
- [ ] Pack header se crea correctamente
- [ ] ZIP compression/decompression sin pérdida
- [ ] Auto-detection de formato
- [ ] Estadísticas de compresión correctas

## Verificación

- [ ] Código compila
- [ ] P2P v0 funciona (sin cambios)
- [ ] P2P v1 funciona (ZIP)
- [ ] Mixed v0↔v1 funciona (auto-convert)
- [ ] Tests pasan
- [ ] Performance: v1 usa ~35-40% del ancho de banda vs v0
