import 'package:flutter_test/flutter_test.dart';
import 'package:folio/features/settings/settings_search_filter.dart';

class _Item {
  const _Item(this.label, [this.searchExtra = const []]);
  final String label;
  final List<String> searchExtra;
}

void main() {
  group('SettingsSearchFilter', () {
    const filter = SettingsSearchFilter();
    final items = [
      const _Item('Cloud', ['sync', 'backup']),
      const _Item('Vault', ['security', 'lock']),
      const _Item('AI', ['assistant', 'quill']),
    ];

    List<String> labelsFor(String query) =>
        filter
            .filter(
              items,
              query,
              label: (i) => i.label,
              searchExtra: (i) => i.searchExtra,
            )
            .map((i) => i.label)
            .toList();

    test('empty query returns all items unfiltered, in original order', () {
      expect(labelsFor(''), ['Cloud', 'Vault', 'AI']);
    });

    test('whitespace-only query is treated as empty', () {
      expect(labelsFor('   '), ['Cloud', 'Vault', 'AI']);
    });

    test('matches on label, case-insensitively', () {
      expect(labelsFor('cloud'), ['Cloud']);
      expect(labelsFor('VAULT'), ['Vault']);
    });

    test('matches on searchExtra keywords, not just the label', () {
      expect(labelsFor('backup'), ['Cloud']);
      expect(labelsFor('assistant'), ['AI']);
    });

    test('matches substrings, not just whole words', () {
      expect(labelsFor('sec'), ['Vault']);
    });

    test('returns an empty list when nothing matches', () {
      expect(labelsFor('nonexistent-term'), isEmpty);
    });

    test('does not mutate or reorder the underlying list', () {
      final original = List<_Item>.from(items);
      filter.filter(
        items,
        'vault',
        label: (i) => i.label,
        searchExtra: (i) => i.searchExtra,
      );
      expect(items.map((i) => i.label), original.map((i) => i.label));
    });
  });
}
