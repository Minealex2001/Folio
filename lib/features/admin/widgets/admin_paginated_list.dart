import 'package:flutter/material.dart';

import '../../../app/widgets/folio_skeletons.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../services/admin/admin_api_base.dart';

/// Reusable searchable/paginated list for every admin console section — one fetch signature,
/// one loading/empty/error treatment, one pagination footer. Keeps every section visually
/// consistent instead of each screen reinventing its own list chrome.
class AdminPaginatedList extends StatefulWidget {
  const AdminPaginatedList({
    super.key,
    required this.fetch,
    required this.itemBuilder,
    this.searchable = true,
    required this.searchHint,
    required this.emptyLabel,
    this.pageSize = 25,
    this.extraActions,
    this.controllerBuilder,
  });

  final Future<AdminPage> Function(int page, int limit, String? query) fetch;
  final Widget Function(BuildContext context, Map<String, dynamic> item) itemBuilder;
  final bool searchable;
  final String searchHint;
  final String emptyLabel;
  final int pageSize;

  /// Extra widgets rendered next to the search bar (e.g. filter chips).
  final List<Widget>? extraActions;

  /// Exposes the list's reload function to the caller (e.g. to refresh after a mutation).
  final void Function(AdminPaginatedListController controller)? controllerBuilder;

  @override
  State<AdminPaginatedList> createState() => _AdminPaginatedListState();
}

class AdminPaginatedListController {
  _AdminPaginatedListState? _state;
  void reload() => _state?._load();
}

class _AdminPaginatedListState extends State<AdminPaginatedList> {
  final _searchController = TextEditingController();
  bool _loading = true;
  String? _error;
  AdminPage? _data;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    widget.controllerBuilder?.call(AdminPaginatedListController().._state = this);
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load({int? page}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await widget.fetch(
        page ?? _page,
        widget.pageSize,
        widget.searchable ? _searchController.text : null,
      );
      if (!mounted) return;
      setState(() {
        _data = result;
        _page = result.page;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        if (widget.searchable || widget.extraActions != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                if (widget.searchable)
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        labelText: widget.searchHint,
                        prefixIcon: const Icon(Icons.search_rounded),
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      onSubmitted: (_) => _load(page: 0),
                    ),
                  ),
                if (widget.searchable) const SizedBox(width: 12),
                if (widget.searchable)
                  FilledButton.tonal(
                    onPressed: () => _load(page: 0),
                    child: Text(l10n.search),
                  ),
                if (widget.extraActions != null) ...[
                  const SizedBox(width: 12),
                  ...widget.extraActions!,
                ],
              ],
            ),
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(_error!, style: TextStyle(color: scheme.error)),
          ),
        Expanded(
          child: _loading
              ? const Center(child: FolioLoadingIndicator())
              : (_data?.items.isEmpty ?? true)
                  ? Center(child: Text(widget.emptyLabel))
                  : RefreshIndicator(
                      onRefresh: () => _load(),
                      child: ListView.separated(
                        padding: const EdgeInsets.only(bottom: 8),
                        itemCount: _data!.items.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) =>
                            widget.itemBuilder(context, _data!.items[index]),
                      ),
                    ),
        ),
        if (_data != null && _data!.totalPages > 1)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: _page > 0 ? () => _load(page: _page - 1) : null,
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Text(l10n.adminPaginationSummary(_page + 1, _data!.totalPages, _data!.total)),
                IconButton(
                  onPressed: _page + 1 < _data!.totalPages ? () => _load(page: _page + 1) : null,
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
