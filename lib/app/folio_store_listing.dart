import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:url_launcher/url_launcher.dart';

import '../config/folio_local_secrets.dart';

/// Enlaces a la ficha de la app en tiendas (build `microsoft_store` / `play_store`).
///
/// Microsoft: id de producto de Partner Center; prioridad `--dart-define` >
/// [FolioLocalSecrets.microsoftStoreListingProductId] / `valueForDefineKey`.
/// Android: [playStoreApplicationId] por defecto coincide con `applicationId` del módulo app.
abstract final class FolioStoreListing {
  static const String _microsoftStoreListingProductIdFromDefine =
      String.fromEnvironment(
    'FOLIO_MS_STORE_LISTING_PRODUCT_ID',
    defaultValue: '',
  );

  static String get _microsoftStoreListingProductIdResolved {
    final fromDefine = _microsoftStoreListingProductIdFromDefine.trim();
    if (fromDefine.isNotEmpty) return fromDefine;
    return FolioLocalSecrets.valueForDefineKey(
      'FOLIO_MS_STORE_LISTING_PRODUCT_ID',
    ).trim();
  }

  static const String playStoreApplicationId = String.fromEnvironment(
    'FOLIO_PLAY_STORE_APP_ID',
    defaultValue: 'com.minealexgames.folio',
  );

  static bool get hasMicrosoftStoreListingProductId =>
      _microsoftStoreListingProductIdResolved.isNotEmpty;

  /// Abre la Microsoft Store en la ficha del producto (protocolo `ms-windows-store`, con
  /// reserva a la URL web).
  static Future<bool> openMicrosoftStoreProductPage() async {
    final id = _microsoftStoreListingProductIdResolved;
    if (id.isEmpty) return false;
    final storeUri = Uri.parse('ms-windows-store://pdp/?ProductId=$id');
    final webUri = Uri.parse('https://apps.microsoft.com/detail/$id');
    try {
      if (await launchUrl(storeUri, mode: LaunchMode.externalApplication)) {
        return true;
      }
    } catch (_) {}
    try {
      return await launchUrl(webUri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  /// Abre Google Play en la ficha de la app (`market://` en Android si aplica).
  static Future<bool> openGooglePlayAppPage() async {
    final pkg = playStoreApplicationId.trim();
    if (pkg.isEmpty) return false;
    final marketUri = Uri.parse('market://details?id=$pkg');
    final httpsUri = Uri.parse(
      'https://play.google.com/store/apps/details?id=$pkg',
    );
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        if (await launchUrl(marketUri, mode: LaunchMode.externalApplication)) {
          return true;
        }
      } catch (_) {}
    }
    try {
      return await launchUrl(httpsUri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}
