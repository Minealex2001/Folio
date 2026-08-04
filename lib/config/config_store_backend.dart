// Gateway file: re-exports the platform-specific ConfigStoreBackend
// implementation. On native (dart:io available), uses file-system storage
// under the app's sandboxed support directory. On web (dart.library.html
// available), uses IndexedDB via idb_shim. Same technique as
// `lib/data/storage/vault_storage.dart`.
export 'config_store_backend_io.dart'
    if (dart.library.html) 'config_store_backend_web.dart';
