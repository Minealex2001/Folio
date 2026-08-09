import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_settings.dart';
import '../../app/ui_tokens.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../services/folio_cloud/folio_cloud_vault_share.dart';
import '../../session/vault_session.dart';
import '../workspace/editor/block_editor.dart';
import '../workspace/shell/sidebar/sidebar_page_tree.dart';

/// Viewer de libreta pública en `…/s/{token}`: shell Folio + [BlockEditor] read-only.
class PublicVaultSharePage extends StatefulWidget {
  const PublicVaultSharePage({super.key, required this.token});

  final String token;

  @override
  State<PublicVaultSharePage> createState() => _PublicVaultSharePageState();
}

class _PublicVaultSharePageState extends State<PublicVaultSharePage> {
  static const _pollInterval = Duration(seconds: 8);

  late final VaultSession _session;
  late final AppSettings _appSettings;
  Timer? _timer;
  String _title = 'Folio';
  String _status = '';
  String? _error;
  int _rev = -1;
  String? _fingerprint;
  final Set<String> _collapsed = {};
  bool _ready = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_status.isEmpty) {
      _status = AppLocalizations.of(context).publicShareLoading;
    }
  }

  @override
  void initState() {
    super.initState();
    _session = VaultSession();
    _appSettings = AppSettings();
    unawaited(_tick());
    _timer = Timer.periodic(_pollInterval, (_) => unawaited(_tick()));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _session.dispose();
    super.dispose();
  }

  Future<void> _tick() async {
    try {
      final meta = await fetchVaultPublicMetaUnauthed(widget.token);
      final name = '${meta['displayName'] ?? ''}'.trim();
      final rev = (meta['rev'] as num?)?.toInt() ?? 0;
      final fp = '${meta['fingerprint'] ?? ''}';
      if (!mounted) return;
      if (name.isNotEmpty) {
        setState(() => _title = name);
      }

      final unchanged =
          rev == _rev && fp == (_fingerprint ?? '') && _ready;
      if (unchanged) {
        setState(() {
          _error = null;
          _status = AppLocalizations.of(context).publicShareUpToDateRev('$_rev');
        });
        return;
      }

      final content = await fetchVaultPublicContentUnauthed(widget.token);
      if (!mounted) return;
      final pages = hydrateVaultPublicViewPages(content);
      _session.loadPublicReadOnlySnapshot(
        pages,
        preferredPageId: _session.selectedPageId,
      );
      setState(() {
        _rev = rev;
        _fingerprint = fp;
        _error = null;
        _ready = true;
        _status = AppLocalizations.of(context).publicShareUpdatedRev('$rev');
        if (name.isEmpty) {
          final dn = '${content['displayName'] ?? ''}'.trim();
          if (dn.isNotEmpty) _title = dn;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _status = AppLocalizations.of(context).publicShareLoadError;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final wide = MediaQuery.sizeOf(context).width >= 900;

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: scheme.surfaceContainerLow,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: FolioSpace.lg,
                  vertical: FolioSpace.sm,
                ),
                child: Row(
                  children: [
                    Text(
                      'Folio',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(width: FolioSpace.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            AppLocalizations.of(context).publicShareReadOnly,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      _status,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Divider(height: 1, color: scheme.outlineVariant),
          if (_error != null && !_ready)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(FolioSpace.xl),
                  child: Text(
                    AppLocalizations.of(context).publicShareCouldNotLoad(_error!),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: scheme.error),
                  ),
                ),
              ),
            )
          else if (!_ready)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else
            Expanded(
              child: ListenableBuilder(
                listenable: _session,
                builder: (context, _) {
                  final nav = _PublicShareNav(
                    session: _session,
                    collapsed: _collapsed,
                    onToggleCollapsed: (id) {
                      setState(() {
                        if (_collapsed.contains(id)) {
                          _collapsed.remove(id);
                        } else {
                          _collapsed.add(id);
                        }
                      });
                    },
                    onSelect: _session.selectPage,
                  );
                  final editor = _PublicShareEditor(
                    session: _session,
                    appSettings: _appSettings,
                  );
                  if (wide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          width: 280,
                          child: Material(
                            color: scheme.surfaceContainerLowest,
                            child: nav,
                          ),
                        ),
                        VerticalDivider(
                          width: 1,
                          color: scheme.outlineVariant,
                        ),
                        Expanded(child: editor),
                      ],
                    );
                  }
                  return Column(
                    children: [
                      SizedBox(
                        height: MediaQuery.sizeOf(context).height * 0.28,
                        child: Material(
                          color: scheme.surfaceContainerLowest,
                          child: nav,
                        ),
                      ),
                      Divider(height: 1, color: scheme.outlineVariant),
                      Expanded(child: editor),
                    ],
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _PublicShareNav extends StatelessWidget {
  const _PublicShareNav({
    required this.session,
    required this.collapsed,
    required this.onToggleCollapsed,
    required this.onSelect,
  });

  final VaultSession session;
  final Set<String> collapsed;
  final ValueChanged<String> onToggleCollapsed;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final pages = session.activePages;
    if (pages.isEmpty) {
      return Center(child: Text(AppLocalizations.of(context).publicShareNoPages));
    }
    final built = buildSidebarVisiblePageRows(
      pages,
      pageOrderForParent: session.pageOrderForParent,
      isCollapsed: collapsed.contains,
    );
    final scheme = Theme.of(context).colorScheme;
    return ListView.builder(
      padding: const EdgeInsets.symmetric(
        vertical: FolioSpace.sm,
        horizontal: FolioSpace.xs,
      ),
      itemCount: built.rows.length,
      itemBuilder: (context, i) {
        final row = built.rows[i];
        final page = row.page;
        final selected = page.id == session.selectedPageId;
        final hasChildren = built.hasChildrenById[page.id] == true;
        final emoji = page.emoji?.trim() ?? '';
        return Padding(
          padding: EdgeInsets.only(left: row.indent),
          child: ListTile(
            dense: true,
            selected: selected,
            selectedTileColor: scheme.primary.withValues(alpha: 0.12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(FolioRadius.md),
            ),
            leading: hasChildren
                ? IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 28,
                      height: 28,
                    ),
                    onPressed: () => onToggleCollapsed(page.id),
                    icon: Icon(
                      collapsed.contains(page.id)
                          ? Icons.chevron_right
                          : Icons.expand_more,
                      size: 18,
                    ),
                  )
                : const SizedBox(width: 28),
            title: Text(
              emoji.isEmpty ? page.title : '$emoji ${page.title}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () => onSelect(page.id),
          ),
        );
      },
    );
  }
}

class _PublicShareEditor extends StatelessWidget {
  const _PublicShareEditor({
    required this.session,
    required this.appSettings,
  });

  final VaultSession session;
  final AppSettings appSettings;

  @override
  Widget build(BuildContext context) {
    final page = session.selectedPage;
    if (page == null) {
      return Center(
        child: Text(
          AppLocalizations.of(context).publicShareSelectPage,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    final scheme = Theme.of(context).colorScheme;
    final emoji = page.emoji?.trim() ?? '';
    final maxWidth = appSettings.editorContentWidth;

    return ColoredBox(
      color: scheme.surface,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth + FolioSpace.xl * 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  FolioSpace.xl,
                  FolioSpace.lg,
                  FolioSpace.xl,
                  FolioSpace.sm,
                ),
                child: Text(
                  emoji.isEmpty ? page.title : '$emoji ${page.title}',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              Expanded(
                child: KeyedSubtree(
                  key: ValueKey('${page.id}-${session.contentEpoch}'),
                  child: BlockEditor(
                    session: session,
                    appSettings: appSettings,
                    readOnlyMode: true,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
