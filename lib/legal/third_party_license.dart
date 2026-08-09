/// Curated third-party / open-source attribution entry for Folio About.
///
/// Keep [ThirdPartyLicensesCatalog] and `THIRD_PARTY_NOTICES.md` in sync
/// by hand when adding or changing entries.
enum ThirdPartyLicenseCategory {
  openSource,
  dartPackages,
  backendPackages,
  fonts,
  assets,
  nativeOrRuntime,
  other,
}

class ThirdPartyLicenseEntry {
  const ThirdPartyLicenseEntry({
    required this.id,
    required this.name,
    required this.license,
    required this.category,
    this.copyright,
    this.description,
    this.sourceUrl,
    this.licenseText,
    this.showInAboutUi = true,
    this.includeInNoticesFile = true,
  });

  final String id;

  /// Project / package name. Do not translate.
  final String name;

  /// Short license identifier (e.g. MIT, BSD-3-Clause). Do not translate.
  final String license;

  final String? copyright;
  final String? description;
  final String? sourceUrl;

  /// Full license / notice text when shown in the in-app viewer.
  final String? licenseText;

  final ThirdPartyLicenseCategory category;
  final bool showInAboutUi;
  final bool includeInNoticesFile;

  bool get hasSourceUrl => (sourceUrl ?? '').trim().isNotEmpty;
  bool get hasLicenseText => (licenseText ?? '').trim().isNotEmpty;
  bool get hasCopyright => (copyright ?? '').trim().isNotEmpty;
}
