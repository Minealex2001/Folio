// Gateway file: re-exports the platform-specific VaultStorage implementation.
// On native (dart:io available), uses file-system storage.
// On web (dart.library.html available), uses IndexedDB via idb_shim.
export 'vault_storage_io.dart' if (dart.library.html) 'vault_storage_web.dart';
