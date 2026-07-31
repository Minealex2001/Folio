import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folio/l10n/generated/app_localizations.dart';

/// Regression guard for the v0.8.0 migration off the legacy `_t(es, en)`
/// helper in `database_block_editor.dart`: every locale must resolve a
/// real, non-empty string for each new `database*` key, so ca/eu/gl/pt
/// users never again fall back to silent English.
void main() {
  final getters = <String, String Function(AppLocalizations)>{
    'databaseCalendarLabel': (l10n) => l10n.databaseCalendarLabel,
    'databaseGalleryLabel': (l10n) => l10n.databaseGalleryLabel,
    'databaseTimelineLabel': (l10n) => l10n.databaseTimelineLabel,
    'databaseViewLabel': (l10n) => l10n.databaseViewLabel,
    'databaseCopySuffix': (l10n) => l10n.databaseCopySuffix,
    'databaseNewView': (l10n) => l10n.databaseNewView,
    'databaseRenameView': (l10n) => l10n.databaseRenameView,
    'databaseVisibleProperties': (l10n) => l10n.databaseVisibleProperties,
    'databaseNewRow': (l10n) => l10n.databaseNewRow,
    'databaseApplyFilter': (l10n) => l10n.databaseApplyFilter,
    'databaseEditableLabel': (l10n) => l10n.databaseEditableLabel,
    'databaseLockedLabel': (l10n) => l10n.databaseLockedLabel,
    'databaseViewOptions': (l10n) => l10n.databaseViewOptions,
    'databaseDuplicateView': (l10n) => l10n.databaseDuplicateView,
    'databaseDeleteView': (l10n) => l10n.databaseDeleteView,
    'databaseNewButtonLabel': (l10n) => l10n.databaseNewButtonLabel,
    'databaseConfigureLabel': (l10n) => l10n.databaseConfigureLabel,
    'databaseDeleteRow': (l10n) => l10n.databaseDeleteRow,
    'databaseQueryBuilder': (l10n) => l10n.databaseQueryBuilder,
    'databaseFilterLabel': (l10n) => l10n.databaseFilterLabel,
    'databaseClearFilters': (l10n) => l10n.databaseClearFilters,
    'databaseLogicLabel': (l10n) => l10n.databaseLogicLabel,
    'databaseValueLabel': (l10n) => l10n.databaseValueLabel,
    'databaseRemoveFilter': (l10n) => l10n.databaseRemoveFilter,
    'databaseRemoveSort': (l10n) => l10n.databaseRemoveSort,
    'databaseRowActions': (l10n) => l10n.databaseRowActions,
    'databaseDuplicateRow': (l10n) => l10n.databaseDuplicateRow,
    'databaseNoValue': (l10n) => l10n.databaseNoValue,
    'databaseGenerateWithAi': (l10n) => l10n.databaseGenerateWithAi,
    'databaseNoDate': (l10n) => l10n.databaseNoDate,
    'databaseFormulaLabel': (l10n) => l10n.databaseFormulaLabel,
    'databaseNoStatus': (l10n) => l10n.databaseNoStatus,
    'databaseConfigureStartDateProperty': (l10n) =>
        l10n.databaseConfigureStartDateProperty,
    'databaseNoRowsWithDates': (l10n) => l10n.databaseNoRowsWithDates,
    'databaseQuickFilterMainColumn': (l10n) =>
        l10n.databaseQuickFilterMainColumn,
  };

  for (final locale in AppLocalizations.supportedLocales) {
    test(
      'all database* view labels resolve to a non-empty string for '
      '${locale.languageCode}',
      () async {
        final l10n = await AppLocalizations.delegate.load(locale);
        for (final entry in getters.entries) {
          final value = entry.value(l10n);
          expect(
            value.isNotEmpty,
            true,
            reason: '${entry.key} is empty for locale ${locale.languageCode}',
          );
        }
      },
    );
  }

  test('es and en values match the pre-migration source strings', () async {
    final es = await AppLocalizations.delegate.load(const Locale('es'));
    final en = await AppLocalizations.delegate.load(const Locale('en'));

    expect(es.databaseCalendarLabel, 'Calendario');
    expect(en.databaseCalendarLabel, 'Calendar');
    expect(es.databaseNoRowsWithDates, 'No hay filas con fechas.');
    expect(en.databaseNoRowsWithDates, 'No rows with dates.');
    expect(es.databaseRemoveSort, 'Quitar sort');
    expect(en.databaseRemoveSort, 'Remove sort');
  });
}
