import 'package:flutter/widgets.dart';

import '../../l10n/generated/app_localizations.dart';
import 'folio_cloud_catalog_prices.dart';

/// Etiquetas de catálogo con importe vivo de Stripe (fallback «…» si aún no hay datos).
abstract final class FolioCloudCatalogLabels {
  static String _orEllipsis(String? price) =>
      (price == null || price.trim().isEmpty) ? '…' : price;

  static String subscribeMonthly(
    BuildContext context,
    AppLocalizations l10n,
    FolioCloudCatalogPricesSnapshot? catalog,
  ) {
    return l10n.folioCloudSubscribeMonthly(
      _orEllipsis(catalog?.format(context, 'folio_cloud_monthly')),
    );
  }

  static String subscribeStudent(
    BuildContext context,
    AppLocalizations l10n,
    FolioCloudCatalogPricesSnapshot? catalog,
  ) {
    return l10n.folioCloudSubscribeStudent(
      _orEllipsis(catalog?.format(context, 'folio_student_monthly')),
    );
  }

  static String subscribeFamily(
    BuildContext context,
    AppLocalizations l10n,
    FolioCloudCatalogPricesSnapshot? catalog,
  ) {
    return l10n.folioCloudSubscribeFamily(
      _orEllipsis(catalog?.format(context, 'folio_family_monthly')),
      _orEllipsis(catalog?.format(context, 'folio_family_member')),
    );
  }

  static String inkSmall(
    BuildContext context,
    AppLocalizations l10n,
    FolioCloudCatalogPricesSnapshot? catalog,
  ) {
    return l10n.folioCloudInkSmall(
      _orEllipsis(catalog?.format(context, 'ink_small')),
    );
  }

  static String inkMedium(
    BuildContext context,
    AppLocalizations l10n,
    FolioCloudCatalogPricesSnapshot? catalog,
  ) {
    return l10n.folioCloudInkMedium(
      _orEllipsis(catalog?.format(context, 'ink_medium')),
    );
  }

  static String inkLarge(
    BuildContext context,
    AppLocalizations l10n,
    FolioCloudCatalogPricesSnapshot? catalog,
  ) {
    return l10n.folioCloudInkLarge(
      _orEllipsis(catalog?.format(context, 'ink_large')),
    );
  }

  static String backupStorageSmall(
    BuildContext context,
    AppLocalizations l10n,
    FolioCloudCatalogPricesSnapshot? catalog,
  ) {
    return l10n.folioCloudBackupStorageLibrarySmallDetail(
      _orEllipsis(catalog?.format(context, 'backup_storage_pack_small')),
    );
  }

  static String backupStorageMedium(
    BuildContext context,
    AppLocalizations l10n,
    FolioCloudCatalogPricesSnapshot? catalog,
  ) {
    return l10n.folioCloudBackupStorageLibraryMediumDetail(
      _orEllipsis(catalog?.format(context, 'backup_storage_pack_medium')),
    );
  }

  static String backupStorageLarge(
    BuildContext context,
    AppLocalizations l10n,
    FolioCloudCatalogPricesSnapshot? catalog,
  ) {
    return l10n.folioCloudBackupStorageLibraryLargeDetail(
      _orEllipsis(catalog?.format(context, 'backup_storage_pack_large')),
    );
  }

  static String onboardingSubscribe(
    BuildContext context,
    AppLocalizations l10n,
    FolioCloudCatalogPricesSnapshot? catalog,
  ) {
    return l10n.onboardingFolioCloudCtaSubscribe(
      _orEllipsis(catalog?.format(context, 'folio_cloud_monthly')),
    );
  }
}
