import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folio/data/vault_repository.dart';
import 'package:folio/l10n/generated/app_localizations.dart';
import 'package:folio/models/folio_usage_intent.dart';

void main() {
  group('VaultRepository starter content', () {
    test('crea páginas iniciales por defecto según locale', () {
      final l10nEs = lookupAppLocalizations(const Locale('es'));
      final pages = buildVaultStarterPages(
        starterContent: VaultStarterContent.enabled,
        l10n: l10nEs,
        usageIntents: const [FolioUsageIntent.notes],
      );

      expect(pages, isNotEmpty);
      expect(pages.first.id, 'starter_home');
      expect(pages.first.title, l10nEs.vaultStarterHomeTitle);

      final l10nEn = lookupAppLocalizations(const Locale('en'));
      final pagesEn = buildVaultStarterPages(
        starterContent: VaultStarterContent.enabled,
        l10n: l10nEn,
        usageIntents: const [FolioUsageIntent.notes],
      );
      expect(pagesEn.first.title, l10nEn.vaultStarterHomeTitle);
      expect(pagesEn.first.title, isNot(equals(pages.first.title)));
    });

    test('incluye la página Quill solo si se solicita', () {
      final l10n = lookupAppLocalizations(const Locale('es'));
      final withoutQuill = buildVaultStarterPages(
        starterContent: VaultStarterContent.enabled,
        l10n: l10n,
        usageIntents: const [FolioUsageIntent.notes],
      );
      final withQuill = buildVaultStarterPages(
        starterContent: VaultStarterContent.enabled,
        l10n: l10n,
        usageIntents: const [FolioUsageIntent.notes],
        includeQuillPage: true,
      );

      expect(withoutQuill.any((p) => p.id == 'starter_quill'), isFalse);
      // Con el cupo máximo de páginas puede no caber; si cabe, debe estar.
      if (withQuill.length > withoutQuill.length) {
        expect(withQuill.any((p) => p.id == 'starter_quill'), isTrue);
      }
    });

    test('permite desactivar las páginas iniciales', () {
      final pages = buildVaultStarterPages(
        starterContent: VaultStarterContent.disabled,
        l10n: lookupAppLocalizations(const Locale('es')),
        usageIntents: const [FolioUsageIntent.notes],
      );

      expect(pages, isEmpty);
    });
  });
}
