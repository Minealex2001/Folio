// Gateway: platform-specific CustomIconBlobStore.
// Native: filesystem under app support. Web: IndexedDB via idb_shim.
export 'custom_icon_blob_store_io.dart'
    if (dart.library.html) 'custom_icon_blob_store_web.dart';
