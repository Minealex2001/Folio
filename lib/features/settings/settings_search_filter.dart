/// Pure query -> filtered-list matching for the Settings page's desktop
/// section nav, extracted from `_filterDesktopSections` in
/// `settings_page_state_backup_security.dart`. Generic (rather than tied to
/// settings_page.dart's library-private nav-item type) so it's directly
/// unit-testable without needing access to that private type.
class SettingsSearchFilter {
  const SettingsSearchFilter();

  List<T> filter<T>(
    List<T> items,
    String query, {
    required String Function(T item) label,
    required List<String> Function(T item) searchExtra,
  }) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return items;
    return items.where((item) {
      if (label(item).toLowerCase().contains(q)) return true;
      for (final extra in searchExtra(item)) {
        if (extra.toLowerCase().contains(q)) return true;
      }
      return false;
    }).toList(growable: false);
  }
}
