import 'package:flutter/material.dart';

import '../../app/app_settings.dart';
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
    final page = _s.selectedPage;

    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: const Text('Folio'),
        actions: [
          if (_s.hasPendingDiskSave || _s.isPersistingToDisk)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 4),
              child: Center(
                child: Tooltip(
                  message: _s.isPersistingToDisk
                      ? 'Guardando el cofre cifrado en disco…'
                      : 'Guardado automático en unos instantes…',
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
                        _s.isPersistingToDisk ? 'Guardando…' : 'Por guardar',
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
              tooltip: 'Historial de la página',
              icon: const Icon(Icons.history_rounded),
              onPressed: _openPageHistoryScreen,
            ),
          IconButton(
            tooltip: 'Ajustes',
            icon: const Icon(Icons.settings_outlined),
            onPressed: _openSettings,
          ),
          IconButton(
            tooltip: 'Bloquear',
            icon: const Icon(Icons.lock_outline),
            onPressed: () => _s.lock(),
          ),
        ],
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 300,
            child: Material(
              color: scheme.surfaceContainerLow,
              child: Sidebar(session: _s),
            ),
          ),
          VerticalDivider(width: 1, thickness: 1, color: scheme.outlineVariant),
          Expanded(
            child: Material(
              color: scheme.surface,
              child: page == null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
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
                              'Sin páginas',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(28, 20, 28, 12),
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
                              hintText: 'Sin título',
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
        ],
      ),
    );
  }
}
