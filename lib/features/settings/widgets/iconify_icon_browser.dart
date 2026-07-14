import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/app_settings.dart';
import '../../../app/ui_tokens.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../services/custom_icon_import_service.dart';
import '../../../services/iconify/iconify_catalog_service.dart';

class IconifyIconBrowser extends StatefulWidget {
  const IconifyIconBrowser({
    super.key,
    required this.appSettings,
    required this.importService,
    required this.onSnack,
  });

  final AppSettings appSettings;
  final CustomIconImportService importService;
  final ValueChanged<String> onSnack;

  @override
  State<IconifyIconBrowser> createState() => _IconifyIconBrowserState();
}

class _IconifyIconBrowserState extends State<IconifyIconBrowser> {
  final IconifyCatalogService _catalogService = IconifyCatalogService();
  final TextEditingController _searchController = TextEditingController();

  Timer? _debounce;
  String _selectedPrefix = '';
  List<IconifyIconItem> _icons = const [];
  int _total = 0;
  int _start = 0;
  bool _loading = false;
  bool _loadingMore = false;
  bool _importing = false;
  String? _importingFullName;
  String? _errorKey;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _scheduleSearch() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      unawaited(_runSearch(reset: true));
    });
  }

  Future<void> _runSearch({required bool reset}) async {
    final query = _searchController.text.trim();
    if (query.length < 2) {
      if (!mounted) return;
      setState(() {
        _icons = const [];
        _total = 0;
        _start = 0;
        _errorKey = null;
      });
      return;
    }
    if (reset) {
      setState(() {
        _loading = true;
        _errorKey = null;
        _start = 0;
      });
    } else {
      setState(() => _loadingMore = true);
    }
    try {
      final result = await _catalogService.searchIcons(
        query: query,
        prefix: _selectedPrefix.isEmpty ? null : _selectedPrefix,
        start: reset ? 0 : _start,
      );
      if (!mounted) return;
      setState(() {
        _total = result.total;
        _start = reset
            ? result.icons.length
            : _start + result.icons.length;
        _icons = reset
            ? result.icons
            : <IconifyIconItem>[..._icons, ...result.icons];
        _errorKey = result.icons.isEmpty ? 'empty' : null;
      });
    } on IconifyCatalogException catch (e) {
      if (mounted) {
        setState(() {
          _errorKey = e.message == 'OFFLINE' ? 'offline' : 'searchFailed';
          if (reset) {
            _icons = const [];
            _total = 0;
            _start = 0;
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorKey = 'searchFailed';
          if (reset) {
            _icons = const [];
            _total = 0;
            _start = 0;
          }
        });
      }
    }
    if (mounted) {
      setState(() {
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  Future<void> _importIcon(IconifyIconItem item) async {
    if (_importing) return;
    final l10n = AppLocalizations.of(context);
    setState(() {
      _importing = true;
      _importingFullName = item.fullName;
    });
    try {
      final bytes = await _catalogService.downloadSvg(
        prefix: item.prefix,
        name: item.name,
      );
      final source = _catalogService.svgUrl(
        prefix: item.prefix,
        name: item.name,
      );
      final entry = await widget.importService.importFromBytes(
        l10n: l10n,
        bytes: bytes,
        mimeType: 'image/svg+xml',
        label: item.name,
        source: source,
      );
      await widget.appSettings.addOrUpdateCustomIcon(entry);
      if (!mounted) return;
      widget.onSnack(l10n.settingsIconifyImportSucceeded);
    } on IconifyCatalogException {
      if (!mounted) return;
      widget.onSnack(l10n.settingsIconifyImportFailed);
    } on CustomIconImportException catch (e) {
      if (!mounted) return;
      widget.onSnack(e.message);
    } catch (_) {
      if (mounted) {
        widget.onSnack(l10n.settingsIconifyImportFailed);
      }
    }
    if (mounted) {
      setState(() {
        _importing = false;
        _importingFullName = null;
      });
    }
  }

  String _collectionLabel(AppLocalizations l10n, String prefix) {
    switch (prefix) {
      case '':
        return l10n.settingsIconifyCollectionAll;
      case 'lucide':
        return l10n.settingsIconifyCollectionLucide;
      case 'tabler':
        return l10n.settingsIconifyCollectionTabler;
      case 'mdi':
        return l10n.settingsIconifyCollectionMdi;
      case 'ph':
        return l10n.settingsIconifyCollectionPhosphor;
      case 'ri':
        return l10n.settingsIconifyCollectionRemix;
      case 'carbon':
        return l10n.settingsIconifyCollectionCarbon;
      case 'iconoir':
        return l10n.settingsIconifyCollectionIconoir;
      case 'fluent':
        return l10n.settingsIconifyCollectionFluent;
      case 'solar':
        return l10n.settingsIconifyCollectionSolar;
      default:
        return prefix;
    }
  }

  String? _statusMessage(AppLocalizations l10n) {
    return switch (_errorKey) {
      'empty' => l10n.settingsIconifyEmpty,
      'offline' => l10n.settingsIconifyOffline,
      'searchFailed' => l10n.settingsIconifySearchFailed,
      _ => null,
    };
  }

  Future<void> _openAttribution() async {
    final uri = Uri.parse('https://iconify.design');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final status = _statusMessage(l10n);
    final hasMore = _icons.isNotEmpty && _start < _total;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.settingsIconifyTitle,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.settingsIconifyDescription,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: l10n.settingsIconifySearchHint,
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _loading
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : null,
                  ),
                  onChanged: (_) => _scheduleSearch(),
                  onSubmitted: (_) => unawaited(_runSearch(reset: true)),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 196,
                child: DropdownMenu<String>(
                  initialSelection: _selectedPrefix,
                  label: Text(l10n.settingsIconifyCollectionLabel),
                  dropdownMenuEntries: [
                    for (final collection
                        in IconifyCatalogService.curatedCollections)
                      DropdownMenuEntry<String>(
                        value: collection.prefix,
                        label: _collectionLabel(l10n, collection.prefix),
                      ),
                  ],
                  onSelected: (value) {
                    if (value == null) return;
                    setState(() => _selectedPrefix = value);
                    if (_searchController.text.trim().length >= 2) {
                      unawaited(_runSearch(reset: true));
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (status != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                status,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          if (_icons.isNotEmpty)
            Wrap(
              spacing: FolioSpace.xs,
              runSpacing: FolioSpace.xs,
              children: [
                for (final item in _icons)
                  _IconifyResultTile(
                    item: item,
                    previewUrl: item.previewUrl(_catalogService),
                    importing:
                        _importing && _importingFullName == item.fullName,
                    disabled: _importing,
                    onTap: () => unawaited(_importIcon(item)),
                  ),
              ],
            ),
          if (hasMore) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _loadingMore ? null : () => unawaited(_runSearch(reset: false)),
              icon: _loadingMore
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.expand_more_rounded),
              label: Text(l10n.settingsIconifyLoadMore),
            ),
          ],
          const SizedBox(height: 12),
          TextButton(
            onPressed: _openAttribution,
            child: Text(l10n.settingsIconifyAttribution),
          ),
        ],
      ),
    );
  }
}

class _IconifyResultTile extends StatelessWidget {
  const _IconifyResultTile({
    required this.item,
    required this.previewUrl,
    required this.importing,
    required this.disabled,
    required this.onTap,
  });

  final IconifyIconItem item;
  final String previewUrl;
  final bool importing;
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: item.fullName,
      child: InkWell(
        borderRadius: BorderRadius.circular(FolioRadius.md),
        onTap: disabled ? null : onTap,
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: scheme.surfaceContainer,
            borderRadius: BorderRadius.circular(FolioRadius.md),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Center(
            child: importing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : SvgPicture.network(
                    previewUrl,
                    width: 28,
                    height: 28,
                    placeholderBuilder: (_) => Icon(
                      Icons.image_not_supported_outlined,
                      size: 20,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
