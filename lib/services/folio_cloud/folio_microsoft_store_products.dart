/// Identificadores de producto en Partner Center (Microsoft Store).
/// En CI o local: `flutter build windows --dart-define=MS_STORE_PRODUCT_FOLIO_CLOUD_MONTHLY=...`
class FolioMicrosoftStoreProducts {
  FolioMicrosoftStoreProducts._();

  static const String folioCloudMonthly = String.fromEnvironment(
    'MS_STORE_PRODUCT_FOLIO_CLOUD_MONTHLY',
    defaultValue: '',
  );

  static const String inkSmall = String.fromEnvironment(
    'MS_STORE_INK_SMALL',
    defaultValue: '',
  );

  static const String inkMedium = String.fromEnvironment(
    'MS_STORE_INK_MEDIUM',
    defaultValue: '',
  );

  static const String inkLarge = String.fromEnvironment(
    'MS_STORE_INK_LARGE',
    defaultValue: '',
  );

  static bool get hasMonthlyProductId => folioCloudMonthly.trim().isNotEmpty;
}
