import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../legal/third_party_license.dart';
import '../../legal/third_party_licenses_catalog.dart';
import 'third_party_license_detail_page.dart';

/// Lists curated third-party / OSS attributions and opens Flutter's full
/// package [LicensePage] for the transitive Dart/Flutter tree.
class ThirdPartyLicensesPage extends StatefulWidget {
  const ThirdPartyLicensesPage({super.key});

  @override
  State<ThirdPartyLicensesPage> createState() => _ThirdPartyLicensesPageState();
}

class _ThirdPartyLicensesPageState extends State<ThirdPartyLicensesPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final filtered = _filteredEntries(_query);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.thirdPartyLicensesTitle)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            children: [
              Text(
                l10n.thirdPartyLicensesIntro,
                style: textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              SearchBar(
                hintText: l10n.thirdPartyLicensesSearchHint,
                leading: const Icon(Icons.search),
                onChanged: (value) => setState(() => _query = value),
                trailing: [
                  if (_query.trim().isNotEmpty)
                    IconButton(
                      tooltip: l10n.thirdPartyLicensesClearSearch,
                      onPressed: () => setState(() => _query = ''),
                      icon: const Icon(Icons.clear),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.inventory_2_outlined,
                  color: scheme.primary,
                ),
                title: Text(l10n.thirdPartyLicensesFlutterPackagesTitle),
                subtitle: Text(
                  l10n.thirdPartyLicensesFlutterPackagesSubtitle,
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  showLicensePage(
                    context: context,
                    applicationName: 'Folio',
                  );
                },
              ),
              const Divider(height: 32),
              if (filtered.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(l10n.thirdPartyLicensesEmpty),
                )
              else
                for (final category in ThirdPartyLicenseCategory.values) ...[
                  ..._sectionForCategory(
                    context: context,
                    l10n: l10n,
                    scheme: scheme,
                    textTheme: textTheme,
                    category: category,
                    items: filtered
                        .where((e) => e.category == category)
                        .toList(growable: false),
                  ),
                ],
            ],
          ),
        ),
      ),
    );
  }

  List<ThirdPartyLicenseEntry> _filteredEntries(String query) {
    final q = query.trim().toLowerCase();
    final all = ThirdPartyLicensesCatalog.uiEntries;
    if (q.isEmpty) return all;
    return all
        .where((e) {
          return e.name.toLowerCase().contains(q) ||
              e.license.toLowerCase().contains(q) ||
              (e.copyright ?? '').toLowerCase().contains(q) ||
              (e.description ?? '').toLowerCase().contains(q);
        })
        .toList(growable: false);
  }

  List<Widget> _sectionForCategory({
    required BuildContext context,
    required AppLocalizations l10n,
    required ColorScheme scheme,
    required TextTheme textTheme,
    required ThirdPartyLicenseCategory category,
    required List<ThirdPartyLicenseEntry> items,
  }) {
    if (items.isEmpty) return const [];

    return [
      Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 8),
        child: Text(
          _categoryLabel(l10n, category),
          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      for (final entry in items)
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(entry.name),
          subtitle: Text(
            [
              entry.license,
              if (entry.hasCopyright) entry.copyright!,
            ].join(' · '),
            style: textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => ThirdPartyLicenseDetailPage(entry: entry),
              ),
            );
          },
        ),
      const SizedBox(height: 8),
    ];
  }

  String _categoryLabel(
    AppLocalizations l10n,
    ThirdPartyLicenseCategory category,
  ) {
    switch (category) {
      case ThirdPartyLicenseCategory.openSource:
        return l10n.thirdPartyLicensesCategoryOpenSource;
      case ThirdPartyLicenseCategory.dartPackages:
        return l10n.thirdPartyLicensesCategoryDartPackages;
      case ThirdPartyLicenseCategory.backendPackages:
        return l10n.thirdPartyLicensesCategoryBackendPackages;
      case ThirdPartyLicenseCategory.fonts:
        return l10n.thirdPartyLicensesCategoryFonts;
      case ThirdPartyLicenseCategory.assets:
        return l10n.thirdPartyLicensesCategoryAssets;
      case ThirdPartyLicenseCategory.nativeOrRuntime:
        return l10n.thirdPartyLicensesCategoryNativeOrRuntime;
      case ThirdPartyLicenseCategory.other:
        return l10n.thirdPartyLicensesCategoryOther;
    }
  }
}

/// Opens [uri] in an external application when possible.
Future<void> launchThirdPartySourceUrl(Uri uri) async {
  if (!await canLaunchUrl(uri)) return;
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}
