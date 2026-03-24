import 'package:flutter/material.dart';

import '../../app/app_settings.dart';
import '../../app/ui_tokens.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../session/vault_session.dart';
import '../settings/settings_page.dart';
import 'widgets/block_editor.dart';
import 'widgets/page_history_sheet.dart';
import 'widgets/sidebar.dart';

class WorkspacePage extends StatefulWidget {
  const WorkspacePage({
    super.key,
    required this.session,
    required this.appSettings,
  });

  final VaultSession session;
  final AppSettings appSettings;

  @override
  State<WorkspacePage> createState() => _WorkspacePageState();
}

class _WorkspacePageState extends State<WorkspacePage> {
  late final TextEditingController _titleController;
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  VaultSession get _s => widget.session;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _s.addListener(_onSession);
    _syncTitleFromSession();
  }

  @override
  void dispose() {
    _s.removeListener(_onSession);
    _titleController.dispose();
    super.dispose();
  }

  void _onSession() {
    if (!mounted) return;
    _syncTitleFromSession();
    setState(() {});
  }

  void _syncTitleFromSession() {
    final p = _s.selectedPage;
    final next = p?.title ?? '';
    if (_titleController.text != next) {
      _titleController.value = TextEditingValue(
        text: next,
        selection: TextSelection.collapsed(offset: next.length),
      );
    }
  }

  void _openSettings() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (ctx) =>
            SettingsPage(session: _s, appSettings: widget.appSettings),
      ),
    );
  }

  void _openPageHistoryScreen() {
    final page = _s.selectedPage;
    if (page == null) return;
    openPageHistoryScreen(context: context, session: _s, page: page);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final page = _s.selectedPage;

    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 1000;
    final sidePanel = Material(
      color: scheme.surfaceContainerLow,
      child: Sidebar(session: _s),
    );
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: scheme.surfaceContainerLow,
      drawer: compact
          ? Drawer(
              width: width.clamp(260, 340),
              child: SafeArea(child: sidePanel),
            )
          : null,
      appBar: AppBar(
        title: Text(l10n.appTitle),
        leading: compact
            ? IconButton(
                tooltip: MaterialLocalizations.of(context).openAppDrawerTooltip,
                icon: const Icon(Icons.menu_rounded),
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              )
            : null,
        actions: [
          if (_s.hasPendingDiskSave || _s.isPersistingToDisk)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: FolioSpace.xs),
              child: Center(
                child: Tooltip(
                  message: _s.isPersistingToDisk
                      ? l10n.savingVaultTooltip
                      : l10n.autosaveSoonTooltip,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_s.isPersistingToDisk)
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: scheme.primary,
                          ),
                        )
                      else
                        Icon(
                          Icons.save_outlined,
                          size: 22,
                          color: scheme.primary.withValues(alpha: 0.85),
                        ),
                      const SizedBox(width: 8),
                      Text(
                        _s.isPersistingToDisk
                            ? l10n.saveInProgress
                            : l10n.savePending,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (page != null)
            IconButton(
              tooltip: l10n.pageHistory,
              icon: const Icon(Icons.history_rounded),
              onPressed: _openPageHistoryScreen,
            ),
          IconButton(
            tooltip: l10n.settings,
            icon: const Icon(Icons.settings_outlined),
            onPressed: _openSettings,
          ),
          IconButton(
            tooltip: l10n.lockNow,
            icon: const Icon(Icons.lock_outline),
            onPressed: () => _s.lock(),
          ),
        ],
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!compact) SizedBox(width: 320, child: sidePanel),
          Expanded(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                compact ? 0 : FolioSpace.sm,
                0,
                compact ? 0 : FolioSpace.md,
                compact ? 0 : FolioSpace.md,
              ),
              child: Material(
                color: scheme.surface,
                elevation: compact ? 0 : 2,
                shadowColor: scheme.shadow.withValues(alpha: 0.1),
                borderRadius: compact
                    ? BorderRadius.zero
                    : BorderRadius.circular(FolioRadius.lg),
                clipBehavior: Clip.antiAlias,
              child: page == null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(FolioSpace.xl),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.description_outlined,
                              size: 56,
                              color: scheme.onSurfaceVariant.withValues(
                                alpha: 0.6,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              l10n.noPages,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                            const SizedBox(height: FolioSpace.md),
                            FilledButton.icon(
                              onPressed: () => _s.addPage(parentId: null),
                              icon: const Icon(Icons.add_rounded),
                              label: Text(l10n.createPage),
                            ),
                          ],
                        ),
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(
                        FolioSpace.lg,
                        FolioSpace.md,
                        FolioSpace.lg,
                        FolioSpace.sm,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: _titleController,
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: scheme.onSurface,
                                ),
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              filled: false,
                              hintText: l10n.untitled,
                              isDense: true,
                              hintStyle: TextStyle(
                                color: scheme.onSurfaceVariant.withValues(
                                  alpha: 0.7,
                                ),
                              ),
                            ),
                            onChanged: (v) {
                              if (page.id == _s.selectedPageId) {
                                _s.renamePage(page.id, v);
                              }
                            },
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: BlockEditor(
                              key: ValueKey('${page.id}-${_s.contentEpoch}'),
                              session: _s,
                            ),
                          ),
                        ],
                      ),
                    ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
