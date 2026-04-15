import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folio/data/vault_repository.dart';
import 'package:folio/l10n/generated/app_localizations.dart';

void main() {
  group('VaultRepository starter content', () {
    test('crea páginas iniciales por defecto según locale', () {
      final l10nEs = lookupAppLocalizations(const Locale('es'));
      final pages = buildVaultStarterPages(VaultStarterContent.enabled, l10nEs);

      expect(pages.map((p) => p.id).toList(), [
        'starter_home',
        'starter_capabilities',
        'starter_quill',
      ]);
      expect(pages.first.title, l10nEs.vaultStarterHomeTitle);
      expect(
        pages.any((page) => page.title == l10nEs.vaultStarterCapabilitiesTitle),
        isTrue,
      );
      expect(
        pages.any((page) => page.title == l10nEs.vaultStarterQuillTitle),
        isTrue,
      );

      final l10nEn = lookupAppLocalizations(const Locale('en'));
      final pagesEn = buildVaultStarterPages(VaultStarterContent.enabled, l10nEn);
      expect(pagesEn.first.title, l10nEn.vaultStarterHomeTitle);
      expect(pagesEn.first.title, isNot(equals(pages.first.title)));
    });

    test('permite desactivar las páginas iniciales', () {
      final pages = buildVaultStarterPages(
        VaultStarterContent.disabled,
        lookupAppLocalizations(const Locale('es')),
      );

      expect(pages, isEmpty);
    });
  });
}
