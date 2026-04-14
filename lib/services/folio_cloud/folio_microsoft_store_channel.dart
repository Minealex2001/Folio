import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// MethodChannel nativo Windows: `Windows.Services.Store` (MSIX / Microsoft Store).
class FolioMicrosoftStoreChannel {
  FolioMicrosoftStoreChannel._();

  static const MethodChannel _ch = MethodChannel('folio/microsoft_store');

  static bool get isRuntimeSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  static Future<Map<String, dynamic>?> getLicenseStatus() async {
    final raw = await _ch.invokeMethod<Object?>('getLicenseStatus');
    return _asStringKeyedMap(raw);
  }

  static Future<String?> getCustomerCollectionsId() async {
    return _ch.invokeMethod<String>('getCustomerCollectionsId');
  }

  static Future<Map<String, dynamic>?> requestPurchase(String storeProductId) async {
    final raw = await _ch.invokeMethod<Object?>(
      'requestPurchase',
      <String, Object>{'storeProductId': storeProductId},
    );
    return _asStringKeyedMap(raw);
  }

  static Map<String, dynamic>? _asStringKeyedMap(Object? raw) {
    if (raw == null) return null;
    if (raw is! Map) return null;
    return raw.map((k, v) => MapEntry('$k', v));
  }
}
