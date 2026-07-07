import '../l10n/generated/app_localizations.dart';
import '../models/folio_page.dart';
import '../models/folio_usage_intent.dart';
import 'vault_starter_catalog.dart';

enum VaultStarterContent {
  enabled,
  disabled,
}

const int kVaultStarterMaxPages = 6;

List<FolioPage> buildVaultStarterPages({
  required VaultStarterContent starterContent,
  required AppLocalizations l10n,
  required List<FolioUsageIntent> usageIntents,
  bool includeQuillPage = false,
}) {
  if (starterContent == VaultStarterContent.disabled) {
    return const [];
  }

  final intents = FolioUsageIntent.sanitizeSelection(usageIntents);
  final primary = intents.first;
  final kinds = <VaultStarterPageKind>[
    VaultStarterPageKind.home,
  ];

  for (final intent in intents) {
    for (final kind in starterKindsForIntent(intent)) {
      if (!kinds.contains(kind)) {
        kinds.add(kind);
      }
      if (kinds.length >= kVaultStarterMaxPages) break;
    }
    if (kinds.length >= kVaultStarterMaxPages) break;
  }

  if (kinds.length < kVaultStarterMaxPages &&
      !kinds.contains(VaultStarterPageKind.shortcuts)) {
    kinds.add(VaultStarterPageKind.shortcuts);
  }

  if (includeQuillPage &&
      kinds.length < kVaultStarterMaxPages &&
      !kinds.contains(VaultStarterPageKind.quill)) {
    kinds.add(VaultStarterPageKind.quill);
  }

  final capped = kinds.take(kVaultStarterMaxPages).toList();
  return capped
      .map(
        (kind) => buildStarterPage(
          kind,
          l10n,
          primaryIntent: primary,
        ),
      )
      .toList();
}
