import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/app_settings.dart';
import '../../../app/workspace_prefs_keys.dart';
import '../../../app/ui_tokens.dart';
import '../../../app/widgets/folio_icon_token_view.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../models/folio_page.dart';
import '../../../models/vault_task_list_entry.dart';
import '../../../session/vault_session.dart';
import '../../../services/cloud_account/cloud_account_controller.dart';
import '../../../services/folio_cloud/folio_cloud_entitlements.dart';
import '../recent_page_visits.dart';

/// Pantalla de inicio del workspace (sin página seleccionada).
class WorkspaceHomeView extends StatefulWidget {
  const WorkspaceHomeView({
    super.key,
    required this.session,
    required this.appSettings,
    required this.onCreatePage,
    this.onOpenSearch,
    required this.onSelectPage,
    required this.compact,
    required this.mobileOptimized,
    this.onOpenTaskInPage,
    this.onAskAiAboutUpcomingTasks,
    this.onOpenSettings,
    this.onOpenGraph,
    this.onOpenTemplateGallery,
    this.onLockVault,
    this.onForceSyncDevices,
    this.onQuickAddTask,
    this.onAddRootFolder,
    this.onImportMarkdown,
    required this.cloudAccount,
    required this.folioCloudEntitlements,
    required this.mobilePreviewReadOnly,
    required this.onOpenReleaseNotes,
  });

  final VaultSession session;
  final AppSettings appSettings;
  final CloudAccountController cloudAccount;
  final FolioCloudEntitlementsController folioCloudEntitlements;
  final bool mobilePreviewReadOnly;
  final Future<void> Function(BuildContext context) onOpenReleaseNotes;
  final VoidCallback onCreatePage;
  final void Function([String? initialQuery])? onOpenSearch;
  final ValueChanged<String> onSelectPage;
  final bool compact;
  final bool mobileOptimized;
  final void Function(String pageId, String blockId)? onOpenTaskInPage;
  final VoidCallback? onAskAiAboutUpcomingTasks;
  final VoidCallback? onOpenSettings;
  final VoidCallback? onOpenGraph;
  final VoidCallback? onOpenTemplateGallery;
  final VoidCallback? onLockVault;
  final VoidCallback? onForceSyncDevices;
  final VoidCallback? onQuickAddTask;
  final VoidCallback? onAddRootFolder;
  final VoidCallback? onImportMarkdown;

  @override
  State<WorkspaceHomeView> createState() => _WorkspaceHomeViewState();
}

class _WorkspaceHomeViewState extends State<WorkspaceHomeView> {
  static const double _twoColumnBreakpoint = 880;
  static const int _kWorkspaceHomeTipCount = 12;

  final TextEditingController _filterController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<RecentPageVisit> _visits = const [];
  String? _lastVaultId;
  Set<String> _lastPageIds = const {};
  Timer? _clockTimer;
  Timer? _recentsDebounce;
  DateTime _now = DateTime.now();
  int? _onboardAnchorMs;
  bool _onboardDismissedLoaded = false;
  bool _onboardDismissed = false;
  late final Future<PackageInfo> _packageInfoFuture = PackageInfo.fromPlatform();

  @override
  void initState() {
    super.initState();
    widget.session.addListener(_onSession);
    widget.appSettings.addListener(_onSettingsOrCloud);
    widget.cloudAccount.addListener(_onSettingsOrCloud);
    widget.folioCloudEntitlements.addListener(_onSettingsOrCloud);
    RecentPageVisitsChangeNotifier.instance.addListener(_onRecentsPersisted);
    _filterController.addListener(_onFilterChanged);
    _restartClockTimer();
    unawaited(_reloadRecents());
    unawaited(_loadOnboardingPrefs());
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _recentsDebounce?.cancel();
    RecentPageVisitsChangeNotifier.instance.removeListener(_onRecentsPersisted);
    widget.session.removeListener(_onSession);
    widget.appSettings.removeListener(_onSettingsOrCloud);
    widget.cloudAccount.removeListener(_onSettingsOrCloud);
    widget.folioCloudEntitlements.removeListener(_onSettingsOrCloud);
    _filterController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onRecentsPersisted() {
    _recentsDebounce?.cancel();
    _recentsDebounce = Timer(const Duration(milliseconds: 150), () {
      if (mounted) unawaited(_reloadRecents());
    });
  }

  void _onSession() {
    final vid = widget.session.activeVaultId;
    final ids = {for (final p in widget.session.pages) p.id};
    if (vid != _lastVaultId || !setEquals(ids, _lastPageIds)) {
      final vaultChanged = vid != _lastVaultId;
      _lastVaultId = vid;
      _lastPageIds = ids;
      unawaited(_reloadRecents());
      if (vaultChanged) {
        _onboardAnchorMs = null;
        _onboardDismissedLoaded = false;
        _onboardDismissed = false;
        unawaited(_loadOnboardingPrefs());
      }
    } else if (mounted) {
      setState(() {});
    }
  }

  void _onFilterChanged() {
    if (mounted) setState(() {});
  }

  void _onSettingsOrCloud() {
    _restartClockTimer();
    if (mounted) setState(() {});
  }

  void _restartClockTimer() {
    _clockTimer?.cancel();
    final interval = widget.appSettings.workspaceHomeClockShowSeconds
        ? const Duration(seconds: 1)
        : const Duration(seconds: 30);
    _clockTimer = Timer.periodic(interval, (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  static String _formatUtcOffset(Duration d) {
    final sign = d.isNegative ? '-' : '+';
    final total = d.inMinutes.abs();
    final h = total ~/ 60;
    final m = total % 60;
    final hh = h.toString().padLeft(2, '0');
    final mm = m.toString().padLeft(2, '0');
    return 'UTC$sign$hh:$mm';
  }

  String _homeClockTimeString(DateTime now, String locale) {
    final sec = widget.appSettings.workspaceHomeClockShowSeconds;
    final h24 = widget.appSettings.workspaceHomeClock24Hour;
    if (h24) {
      return sec
          ? DateFormat('HH:mm:ss', locale).format(now)
          : DateFormat('HH:mm', locale).format(now);
    }
    return sec
        ? DateFormat.jms(locale).format(now)
        : DateFormat.jm(locale).format(now);
  }

  static void _reorderStringList(List<String> list, int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
  }

  String _homeSectionReorderTitle(AppLocalizations l10n, String id) {
    switch (id) {
      case WorkspaceHomeSectionIds.folioCloud:
        return l10n.workspaceHomeToggleFolioCloudTitle;
      case WorkspaceHomeSectionIds.vaultStatus:
        return l10n.workspaceHomeToggleVaultStatusTitle;
      case WorkspaceHomeSectionIds.onboarding:
        return l10n.workspaceHomeToggleOnboardingTitle;
      case WorkspaceHomeSectionIds.whatsNew:
        return l10n.workspaceHomeToggleWhatsNewTitle;
      case WorkspaceHomeSectionIds.search:
        return l10n.workspaceHomeSectionLabelSearch;
      case WorkspaceHomeSectionIds.rootPages:
        return l10n.workspaceHomeToggleRootPagesTitle;
      case WorkspaceHomeSectionIds.miniStats:
        return l10n.workspaceHomeToggleMiniStatsTitle;
      case WorkspaceHomeSectionIds.recents:
        return l10n.workspaceRecentPagesSectionTitle;
      case WorkspaceHomeSectionIds.tasks:
        return l10n.workspaceHomeToggleTasksTitle;
      case WorkspaceHomeSectionIds.quickActions:
        return l10n.workspaceHomeToggleQuickActionsTitle;
      case WorkspaceHomeSectionIds.tip:
        return l10n.workspaceHomeToggleTipTitle;
      case WorkspaceHomeSectionIds.createPage:
        return l10n.workspaceHomeSectionLabelCreatePage;
      default:
        return id;
    }
  }

  void _showReorderHomeSectionsSheet(BuildContext context) {
    final theme = Theme.of(context);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        final sheetL10n = AppLocalizations.of(ctx);
        return SafeArea(
          child: AnimatedBuilder(
            animation: widget.appSettings,
            builder: (context, _) {
              final leftIds = widget.appSettings.workspaceHomeLeftSectionOrder;
              final rightIds = widget.appSettings.workspaceHomeRightSectionOrder;
              return ListView(
                padding: const EdgeInsets.only(
                  left: FolioSpace.lg,
                  right: FolioSpace.lg,
                  bottom: FolioSpace.xl,
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: FolioSpace.sm),
                    child: Text(
                      sheetL10n.workspaceHomeReorderSectionsTitle,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: FolioSpace.md),
                  Text(
                    sheetL10n.workspaceHomeReorderMainColumn,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: FolioSpace.xs),
                  SizedBox(
                    height: 280,
                    child: ReorderableListView.builder(
                      buildDefaultDragHandles: false,
                      itemCount: leftIds.length,
                      onReorder: (oldIndex, newIndex) async {
                        final next = List<String>.from(leftIds);
                        _reorderStringList(next, oldIndex, newIndex);
                        await widget.appSettings
                            .setWorkspaceHomeLeftSectionOrder(next);
                      },
                      itemBuilder: (context, i) {
                        final id = leftIds[i];
                        return ListTile(
                          key: ValueKey('home-left-$id'),
                          leading: ReorderableDragStartListener(
                            index: i,
                            child: const Icon(Icons.drag_handle_rounded),
                          ),
                          title: Text(_homeSectionReorderTitle(sheetL10n, id)),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: FolioSpace.md),
                  Text(
                    sheetL10n.workspaceHomeReorderSideColumn,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: FolioSpace.xs),
                  SizedBox(
                    height: 220,
                    child: ReorderableListView.builder(
                      buildDefaultDragHandles: false,
                      itemCount: rightIds.length,
                      onReorder: (oldIndex, newIndex) async {
                        final next = List<String>.from(rightIds);
                        _reorderStringList(next, oldIndex, newIndex);
                        await widget.appSettings
                            .setWorkspaceHomeRightSectionOrder(next);
                      },
                      itemBuilder: (context, i) {
                        final id = rightIds[i];
                        return ListTile(
                          key: ValueKey('home-right-$id'),
                          leading: ReorderableDragStartListener(
                            index: i,
                            child: const Icon(Icons.drag_handle_rounded),
                          ),
                          title: Text(_homeSectionReorderTitle(sheetL10n, id)),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  String _formatStorageBytes(int b) {
    if (b < 1024) return '$b B';
    final kb = b / 1024;
    if (kb < 1024) {
      return '${kb.toStringAsFixed(kb >= 100 ? 0 : 1)} KB';
    }
    final mb = kb / 1024;
    if (mb < 1024) {
      return '${mb.toStringAsFixed(mb >= 100 ? 0 : 1)} MB';
    }
    final gb = mb / 1024;
    return '${gb.toStringAsFixed(gb >= 100 ? 1 : 2)} GB';
  }

  void _showCustomizeSheet(BuildContext context) {
    final theme = Theme.of(context);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return AnimatedBuilder(
          animation: widget.appSettings,
          builder: (context, _) {
            final sheetL10n = AppLocalizations.of(context);
            return SafeArea(
              child: ListView(
                padding: const EdgeInsets.only(bottom: FolioSpace.xl),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      FolioSpace.lg,
                      FolioSpace.sm,
                      FolioSpace.lg,
                      FolioSpace.xs,
                    ),
                    child: Text(
                      sheetL10n.workspaceHomeCustomizeTitle,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.reorder_rounded),
                    title: Text(sheetL10n.workspaceHomeReorderSectionsTitle),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      Navigator.pop(ctx);
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (context.mounted) {
                          _showReorderHomeSectionsSheet(context);
                        }
                      });
                    },
                  ),
                  ListTile(
                    title: Text(sheetL10n.workspaceHomeColumnLayoutTitle),
                    subtitle: Text(sheetL10n.workspaceHomeColumnLayoutSubtitle),
                    trailing: DropdownButton<WorkspaceHomeColumnLayout>(
                      value: widget.appSettings.workspaceHomeColumnLayout,
                      underline: const SizedBox.shrink(),
                      onChanged: (v) {
                        if (v == null) return;
                        unawaited(
                          widget.appSettings.setWorkspaceHomeColumnLayout(v),
                        );
                      },
                      items: [
                        DropdownMenuItem(
                          value: WorkspaceHomeColumnLayout.auto,
                          child: Text(sheetL10n.workspaceHomeColumnLayoutAuto),
                        ),
                        DropdownMenuItem(
                          value: WorkspaceHomeColumnLayout.single,
                          child: Text(sheetL10n.workspaceHomeColumnLayoutSingle),
                        ),
                        DropdownMenuItem(
                          value: WorkspaceHomeColumnLayout.dual,
                          child: Text(sheetL10n.workspaceHomeColumnLayoutDual),
                        ),
                      ],
                    ),
                  ),
                  SwitchListTile(
                    title: Text(sheetL10n.workspaceHomeClockShowSecondsTitle),
                    subtitle:
                        Text(sheetL10n.workspaceHomeClockShowSecondsSubtitle),
                    value: widget.appSettings.workspaceHomeClockShowSeconds,
                    onChanged: (v) => unawaited(
                      widget.appSettings.setWorkspaceHomeClockShowSeconds(v),
                    ),
                  ),
                  SwitchListTile(
                    title: Text(sheetL10n.workspaceHomeClock24HourTitle),
                    subtitle: Text(sheetL10n.workspaceHomeClock24HourSubtitle),
                    value: widget.appSettings.workspaceHomeClock24Hour,
                    onChanged: (v) => unawaited(
                      widget.appSettings.setWorkspaceHomeClock24Hour(v),
                    ),
                  ),
                  SwitchListTile(
                    title: Text(sheetL10n.workspaceHomeClockShowTimezoneTitle),
                    subtitle:
                        Text(sheetL10n.workspaceHomeClockShowTimezoneSubtitle),
                    value: widget.appSettings.workspaceHomeClockShowTimezone,
                    onChanged: (v) => unawaited(
                      widget.appSettings.setWorkspaceHomeClockShowTimezone(v),
                    ),
                  ),
                  SwitchListTile(
                    title: Text(sheetL10n.workspaceHomeToggleFolioCloudTitle),
                    subtitle:
                        Text(sheetL10n.workspaceHomeToggleFolioCloudSubtitle),
                    value: widget.appSettings.workspaceHomeShowFolioCloudCard,
                    onChanged: (v) => unawaited(
                      widget.appSettings.setWorkspaceHomeShowFolioCloudCard(v),
                    ),
                  ),
                  SwitchListTile(
                    title: Text(sheetL10n.workspaceHomeToggleRootPagesTitle),
                    subtitle:
                        Text(sheetL10n.workspaceHomeToggleRootPagesSubtitle),
                    value: widget.appSettings.workspaceHomeShowRootPages,
                    onChanged: (v) => unawaited(
                      widget.appSettings.setWorkspaceHomeShowRootPages(v),
                    ),
                  ),
                  SwitchListTile(
                    title: Text(sheetL10n.workspaceHomeToggleMiniStatsTitle),
                    subtitle:
                        Text(sheetL10n.workspaceHomeToggleMiniStatsSubtitle),
                    value: widget.appSettings.workspaceHomeShowMiniStats,
                    onChanged: (v) => unawaited(
                      widget.appSettings.setWorkspaceHomeShowMiniStats(v),
                    ),
                  ),
                  SwitchListTile(
                    title: Text(sheetL10n.workspaceHomeToggleTasksTitle),
                    subtitle: Text(sheetL10n.workspaceHomeToggleTasksSubtitle),
                    value: widget.appSettings.workspaceHomeShowTasksSection,
                    onChanged: (v) => unawaited(
                      widget.appSettings.setWorkspaceHomeShowTasksSection(v),
                    ),
                  ),
                  SwitchListTile(
                    title: Text(sheetL10n.workspaceHomeToggleQuickActionsTitle),
                    subtitle: Text(
                      sheetL10n.workspaceHomeToggleQuickActionsSubtitle,
                    ),
                    value: widget.appSettings.workspaceHomeShowQuickActions,
                    onChanged: (v) => unawaited(
                      widget.appSettings.setWorkspaceHomeShowQuickActions(v),
                    ),
                  ),
                  SwitchListTile(
                    title: Text(sheetL10n.workspaceHomeToggleTipTitle),
                    subtitle: Text(sheetL10n.workspaceHomeToggleTipSubtitle),
                    value: widget.appSettings.workspaceHomeShowTip,
                    onChanged: (v) => unawaited(
                      widget.appSettings.setWorkspaceHomeShowTip(v),
                    ),
                  ),
                  SwitchListTile(
                    title: Text(sheetL10n.workspaceHomeToggleVaultStatusTitle),
                    subtitle:
                        Text(sheetL10n.workspaceHomeToggleVaultStatusSubtitle),
                    value: widget.appSettings.workspaceHomeShowVaultStatus,
                    onChanged: (v) => unawaited(
                      widget.appSettings.setWorkspaceHomeShowVaultStatus(v),
                    ),
                  ),
                  SwitchListTile(
                    title: Text(sheetL10n.workspaceHomeToggleOnboardingTitle),
                    subtitle:
                        Text(sheetL10n.workspaceHomeToggleOnboardingSubtitle),
                    value: widget.appSettings.workspaceHomeShowOnboarding,
                    onChanged: (v) => unawaited(
                      widget.appSettings.setWorkspaceHomeShowOnboarding(v),
                    ),
                  ),
                  SwitchListTile(
                    title: Text(sheetL10n.workspaceHomeToggleWhatsNewTitle),
                    subtitle:
                        Text(sheetL10n.workspaceHomeToggleWhatsNewSubtitle),
                    value: widget.appSettings.workspaceHomeShowWhatsNew,
                    onChanged: (v) => unawaited(
                      widget.appSettings.setWorkspaceHomeShowWhatsNew(v),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _loadOnboardingPrefs() async {
    final vid = widget.session.activeVaultId ?? '';
    if (vid.isEmpty) {
      if (!mounted) return;
      setState(() {
        _onboardAnchorMs = null;
        _onboardDismissedLoaded = true;
        _onboardDismissed = false;
      });
      return;
    }
    final p = await SharedPreferences.getInstance();
    final anchorKey = WorkspacePrefsKeys.homeOnboardAnchor(vid);
    var anchor = p.getInt(anchorKey) ?? 0;
    if (anchor == 0) {
      anchor = DateTime.now().millisecondsSinceEpoch;
      await p.setInt(anchorKey, anchor);
    }
    final dismissed =
        p.getBool(WorkspacePrefsKeys.homeOnboardDismissed(vid)) ?? false;
    if (!mounted) return;
    setState(() {
      _onboardAnchorMs = anchor;
      _onboardDismissedLoaded = true;
      _onboardDismissed = dismissed;
    });
  }

  Future<void> _dismissOnboarding() async {
    final vid = widget.session.activeVaultId ?? '';
    if (vid.isEmpty) return;
    final p = await SharedPreferences.getInstance();
    await p.setBool(WorkspacePrefsKeys.homeOnboardDismissed(vid), true);
    if (!mounted) return;
    setState(() => _onboardDismissed = true);
  }

  bool _shouldShowOnboardingCard() {
    if (!widget.appSettings.workspaceHomeShowOnboarding) return false;
    if (!_onboardDismissedLoaded) return false;
    if (_onboardDismissed) return false;
    final anchor = _onboardAnchorMs;
    if (anchor == null) return false;
    final elapsed = DateTime.now().millisecondsSinceEpoch - anchor;
    if (elapsed > 7 * 86400000) return false;
    return true;
  }

  String _backupIntervalLabel(AppLocalizations l10n, int intervalMinutes) {
    if (intervalMinutes < 60) {
      return l10n.scheduledVaultBackupEveryNMinutes(intervalMinutes);
    }
    final h = (intervalMinutes / 60).round().clamp(1, 8760);
    return l10n.scheduledVaultBackupEveryNHours(h);
  }

  Widget _buildVaultStatusSection(
    AppLocalizations l10n,
    ColorScheme scheme,
    TextTheme textTheme,
    String locale,
  ) {
    final vid = widget.session.activeVaultId ?? '';
    return FutureBuilder<VaultBackupPrefs>(
      future: widget.appSettings.getVaultBackupPrefs(
        vid.isEmpty ? null : vid,
      ),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: FolioSpace.sm),
            child: LinearProgressIndicator(minHeight: 3),
          );
        }
        final prefs = snap.data!;
        final conflicts = widget.appSettings.syncPendingConflicts;
        final lines = <Widget>[
          Row(
            children: [
              Icon(Icons.health_and_safety_outlined,
                  color: scheme.primary, size: 22),
              const SizedBox(width: FolioSpace.sm),
              Expanded(
                child: Text(
                  l10n.workspaceHomeVaultStatusTitle,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: FolioSpace.sm),
        ];
        if (!prefs.enabled) {
          lines.add(
            Text(
              l10n.workspaceHomeVaultBackupOff,
              style: textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          );
        } else {
          final when = prefs.lastMs <= 0
              ? l10n.workspaceHomeVaultBackupNeverRun
              : l10n.workspaceHomeVaultBackupLast(
                  DateFormat.yMMMd(locale).add_jm().format(
                        DateTime.fromMillisecondsSinceEpoch(prefs.lastMs),
                      ),
                );
          lines.add(
            Text(
              when,
              style: textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          );
          lines.add(
            Text(
              l10n.workspaceHomeVaultBackupEvery(
                _backupIntervalLabel(l10n, prefs.intervalMinutes),
              ),
              style: textTheme.labelMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          );
        }
        if (conflicts > 0) {
          lines.add(const SizedBox(height: FolioSpace.xs));
          lines.add(
            Text(
              l10n.workspaceHomeVaultSyncConflicts(conflicts),
              style: textTheme.bodyMedium?.copyWith(
                color: scheme.error,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          );
        }
        if (widget.mobilePreviewReadOnly) {
          lines.add(const SizedBox(height: FolioSpace.xs));
          lines.add(
            Text(
              l10n.workspaceHomeVaultReadOnlyHint,
              style: textTheme.bodyMedium?.copyWith(
                color: scheme.tertiary,
                height: 1.35,
              ),
            ),
          );
        }
        return Container(
          padding: const EdgeInsets.all(FolioSpace.md),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(FolioRadius.lg),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: FolioAlpha.track),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: lines,
          ),
        );
      },
    );
  }

  Widget _onboardingStepRow({
    required ColorScheme scheme,
    required TextTheme textTheme,
    required String label,
    required bool done,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            done ? Icons.check_circle_rounded : Icons.circle_outlined,
            size: 22,
            color: done ? scheme.primary : scheme.outlineVariant,
          ),
          const SizedBox(width: FolioSpace.sm),
          Expanded(
            child: Text(
              label,
              style: textTheme.bodyMedium?.copyWith(
                color: scheme.onSurface,
                fontWeight: done ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOnboardingSection(
    AppLocalizations l10n,
    ColorScheme scheme,
    TextTheme textTheme,
  ) {
    final pages = widget.session.pages;
    final hasPage = pages.isNotEmpty;
    final hasSubpage = pages.any((p) => p.parentId != null);
    final usedSearch = widget.appSettings.recentSearchQueries.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(FolioSpace.md),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(FolioRadius.lg),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: FolioAlpha.track),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.flag_outlined, color: scheme.secondary, size: 22),
              const SizedBox(width: FolioSpace.sm),
              Expanded(
                child: Text(
                  l10n.workspaceHomeOnboardingTitle,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                tooltip: l10n.workspaceHomeOnboardingDismiss,
                icon: const Icon(Icons.close_rounded),
                onPressed: () => unawaited(_dismissOnboarding()),
              ),
            ],
          ),
          const SizedBox(height: FolioSpace.xs),
          Text(
            l10n.workspaceHomeOnboardingHint,
            style: textTheme.labelMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: FolioSpace.sm),
          _onboardingStepRow(
            scheme: scheme,
            textTheme: textTheme,
            label: l10n.workspaceHomeOnboardingStepPage,
            done: hasPage,
          ),
          _onboardingStepRow(
            scheme: scheme,
            textTheme: textTheme,
            label: l10n.workspaceHomeOnboardingStepSubpage,
            done: hasSubpage,
          ),
          _onboardingStepRow(
            scheme: scheme,
            textTheme: textTheme,
            label: l10n.workspaceHomeOnboardingStepSearch,
            done: usedSearch,
          ),
        ],
      ),
    );
  }

  Widget _buildWhatsNewSection(
    BuildContext context,
    AppLocalizations l10n,
    ColorScheme scheme,
    TextTheme textTheme,
  ) {
    if (!widget.appSettings.workspaceHomeShowWhatsNew) {
      return const SizedBox.shrink();
    }
    return FutureBuilder<PackageInfo>(
      future: _packageInfoFuture,
      builder: (context, snap) {
        if (!snap.hasData) {
          return const SizedBox(
            height: 40,
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        final info = snap.data!;
        final appVersion = info.version.trim();
        final buildNumber = info.buildNumber.trim();
        if (appVersion.isEmpty) return const SizedBox.shrink();
        final versionLabel = buildNumber.isEmpty
            ? appVersion
            : '$appVersion+$buildNumber';
        final lastSeen = widget.appSettings.lastSeenReleaseNotesVersion.trim();
        final unread =
            lastSeen.isNotEmpty && lastSeen != versionLabel;
        final dismissed =
            widget.appSettings.workspaceHomeWhatsNewDismissedVersion.trim();
        final showCard =
            unread && dismissed != versionLabel;
        if (!showCard) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.all(FolioSpace.md),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(FolioRadius.lg),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: FolioAlpha.track),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.new_releases_outlined,
                      color: scheme.primary, size: 22),
                  const SizedBox(width: FolioSpace.sm),
                  Expanded(
                    child: Text(
                      l10n.workspaceHomeWhatsNewTitle,
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.workspaceHomeWhatsNewDismissTooltip,
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => unawaited(
                      widget.appSettings
                          .setWorkspaceHomeWhatsNewDismissedForVersion(
                        versionLabel,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: FolioSpace.sm),
              Text(
                l10n.workspaceHomeWhatsNewVersion(versionLabel),
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: FolioSpace.xs),
              Text(
                l10n.workspaceHomeWhatsNewUnread,
                style: textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: FolioSpace.sm),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.tonal(
                  onPressed: () => unawaited(
                    widget.onOpenReleaseNotes(context),
                  ),
                  child: Text(l10n.workspaceHomeWhatsNewOpen),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFolioCloudQuickCard({
    required AppLocalizations l10n,
    required ColorScheme scheme,
    required TextTheme textTheme,
    required FolioCloudSnapshot snap,
  }) {
    final ink = snap.ink;
    final quota = snap.backupQuotaBytes;
    final usedBytes = snap.backupUsedBytes;
    final showBackupBar = snap.canUseCloudBackup && quota > 0;
    final remainingBytes =
        showBackupBar ? (quota - usedBytes).clamp(0, quota) : 0;
    final pct = showBackupBar
        ? ((usedBytes / quota) * 100).round().clamp(0, 100)
        : null;

    return Container(
      padding: const EdgeInsets.all(FolioSpace.md),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(FolioRadius.lg),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: FolioAlpha.track),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.cloud_outlined, color: scheme.primary, size: 22),
              const SizedBox(width: FolioSpace.sm),
              Expanded(
                child: Text(
                  l10n.workspaceHomeCloudCardTitle,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (widget.onOpenSettings != null)
                TextButton(
                  onPressed: widget.onOpenSettings,
                  child: Text(l10n.workspaceHomeCloudOpenSettings),
                ),
            ],
          ),
          const SizedBox(height: FolioSpace.sm),
          if (snap.folioStaff)
            Row(
              children: [
                Icon(Icons.water_drop_outlined, color: scheme.tertiary),
                const SizedBox(width: FolioSpace.sm),
                Expanded(
                  child: Text(
                    l10n.workspaceHomeCloudStaffShort,
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            )
          else
            Tooltip(
              message: l10n.aiChatInkBreakdownTooltip(
                ink.monthlyBalance,
                ink.purchasedBalance,
              ),
              child: Row(
                children: [
                  Icon(Icons.water_drop_outlined, color: scheme.tertiary),
                  const SizedBox(width: FolioSpace.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.folioCloudInkTotal,
                          style: textTheme.labelMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          l10n.folioCloudInkCount(ink.totalInk),
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          if (showBackupBar) ...[
            const SizedBox(height: FolioSpace.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: usedBytes / quota,
                minHeight: 6,
                backgroundColor:
                    scheme.surfaceContainerHighest.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: FolioSpace.xs),
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.folioCloudBackupStorageBarTitle,
                    style: textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (pct != null)
                  Text(
                    l10n.folioCloudBackupStorageBarPercent(pct),
                    style: textTheme.labelMedium?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
            Text(
              l10n.folioCloudBackupStorageBarDetail(
                _formatStorageBytes(usedBytes),
                _formatStorageBytes(quota),
                _formatStorageBytes(remainingBytes),
              ),
              style: textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _reloadRecents() async {
    final valid = widget.session.pages.map((p) => p.id).toSet();
    final loaded = await RecentPageVisitsStore.load(
      vaultId: widget.session.activeVaultId,
      validPageIds: valid,
      limit: kRecentPageVisitsHomeLoadLimit,
    );
    if (!mounted) return;
    setState(() => _visits = loaded);
  }

  /// Consejo del día: combina día local y cofre para variar sin depender solo de 4 textos.
  int _tipSlotIndex() {
    final n = DateTime.now();
    final dayBucket =
        DateTime(n.year, n.month, n.day).millisecondsSinceEpoch ~/ 86400000;
    final vid = widget.session.activeVaultId ?? '';
    var salt = 0;
    for (var i = 0; i < vid.length; i++) {
      salt = (salt * 31 + vid.codeUnitAt(i)) & 0x7fffffff;
    }
    return (dayBucket + salt) % _kWorkspaceHomeTipCount;
  }

  String _greeting(AppLocalizations l10n) {
    final h = DateTime.now().hour;
    if (h >= 5 && h < 12) return l10n.workspaceHomeGreetingMorning;
    if (h < 18) return l10n.workspaceHomeGreetingAfternoon;
    if (h < 22) return l10n.workspaceHomeGreetingEvening;
    return l10n.workspaceHomeGreetingNight;
  }

  String _tipText(AppLocalizations l10n, int index) {
    switch (index % _kWorkspaceHomeTipCount) {
      case 1:
        return l10n.workspaceHomeTip1;
      case 2:
        return l10n.workspaceHomeTip2;
      case 3:
        return l10n.workspaceHomeTip3;
      case 4:
        return l10n.workspaceHomeTip4;
      case 5:
        return l10n.workspaceHomeTip5;
      case 6:
        return l10n.workspaceHomeTip6;
      case 7:
        return l10n.workspaceHomeTip7;
      case 8:
        return l10n.workspaceHomeTip8;
      case 9:
        return l10n.workspaceHomeTip9;
      case 10:
        return l10n.workspaceHomeTip10;
      case 11:
        return l10n.workspaceHomeTip11;
      case 0:
      default:
        return l10n.workspaceHomeTip0;
    }
  }

  List<VaultTaskListEntry> _upcomingTasks() {
    final entries =
        widget.session.collectTaskBlocks(includeSimpleTodos: false);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final horizonEnd = today.add(const Duration(days: 14));
    final out = <VaultTaskListEntry>[];
    for (final e in entries) {
      if (e.isDone) continue;
      final dueRaw = e.dueDate;
      if (dueRaw == null || dueRaw.trim().isEmpty) continue;
      final parsed = DateTime.tryParse(dueRaw.trim());
      if (parsed == null) continue;
      final day = DateTime(parsed.year, parsed.month, parsed.day);
      if (day.isAfter(horizonEnd)) continue;
      out.add(e);
    }
    out.sort((a, b) {
      final da = _taskDueDay(a)!;
      final db = _taskDueDay(b)!;
      final c = da.compareTo(db);
      if (c != 0) return c;
      return a.displayTitle.compareTo(b.displayTitle);
    });
    return out.take(12).toList(growable: false);
  }

  DateTime? _taskDueDay(VaultTaskListEntry e) {
    final raw = e.dueDate;
    if (raw == null || raw.trim().isEmpty) return null;
    final parsed = DateTime.tryParse(raw.trim());
    if (parsed == null) return null;
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  Map<DateTime, int> _dueCountByDay(List<VaultTaskListEntry> tasks) {
    final m = <DateTime, int>{};
    for (final e in tasks) {
      final d = _taskDueDay(e);
      if (d == null) continue;
      m[d] = (m[d] ?? 0) + 1;
    }
    return m;
  }

  void _emitOpenGlobalSearch([String? raw]) {
    final q = raw?.trim();
    widget.onOpenSearch?.call(
      (q == null || q.isEmpty) ? null : q,
    );
  }

  Widget _quickTile({
    required ColorScheme scheme,
    required TextTheme textTheme,
    required IconData icon,
    required String label,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(FolioRadius.md),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(FolioRadius.md),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: FolioSpace.sm,
              vertical: FolioSpace.md,
            ),
            child: Row(
              children: [
                Icon(icon, size: 22, color: scheme.primary),
                const SizedBox(width: FolioSpace.sm),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionsPanel({
    required AppLocalizations l10n,
    required ColorScheme scheme,
    required TextTheme textTheme,
  }) {
    final tiles = <Widget>[];

    void pushIf(VoidCallback? cb, IconData icon, String label, String tip) {
      if (cb == null) return;
      tiles.add(
        _quickTile(
          scheme: scheme,
          textTheme: textTheme,
          icon: icon,
          label: label,
          tooltip: tip,
          onPressed: cb,
        ),
      );
    }

    pushIf(
      widget.onOpenSettings,
      Icons.settings_outlined,
      l10n.workspaceHomeQuickSettings,
      l10n.workspaceHomeQuickSettings,
    );
    pushIf(
      widget.onOpenGraph,
      Icons.bubble_chart_rounded,
      l10n.workspaceHomeQuickGraph,
      l10n.workspaceHomeQuickGraph,
    );
    pushIf(
      widget.onOpenTemplateGallery,
      Icons.dashboard_customize_outlined,
      l10n.workspaceHomeQuickTemplates,
      l10n.workspaceHomeQuickTemplates,
    );
    pushIf(
      widget.onLockVault,
      Icons.lock_outline_rounded,
      l10n.workspaceHomeQuickLock,
      l10n.workspaceHomeQuickLock,
    );
    pushIf(
      widget.onForceSyncDevices,
      Icons.sync_rounded,
      l10n.workspaceHomeQuickSync,
      l10n.workspaceHomeQuickSync,
    );
    pushIf(
      widget.onQuickAddTask,
      Icons.add_task_rounded,
      l10n.workspaceHomeQuickTask,
      l10n.workspaceHomeQuickTask,
    );
    pushIf(
      widget.onAddRootFolder,
      Icons.create_new_folder_outlined,
      l10n.workspaceHomeQuickFolder,
      l10n.workspaceHomeQuickFolder,
    );
    pushIf(
      widget.onImportMarkdown,
      Icons.file_upload_outlined,
      l10n.workspaceHomeQuickImport,
      l10n.workspaceHomeQuickImport,
    );

    if (tiles.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.workspaceHomeQuickActionsTitle,
          style: textTheme.titleSmall?.copyWith(
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: FolioSpace.sm),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: FolioSpace.sm,
          crossAxisSpacing: FolioSpace.sm,
          childAspectRatio: 2.2,
          children: tiles,
        ),
      ],
    );
  }

  Widget _buildRecentsSection({
    required AppLocalizations l10n,
    required ColorScheme scheme,
    required TextTheme textTheme,
    required List<RecentPageVisit> filteredVisits,
    required Map<String, FolioPage> pagesById,
    required String query,
    required List<RecentPageVisit> visits,
    required DateFormat dateTimeMedium,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.workspaceRecentPagesSectionTitle,
          style: textTheme.titleSmall?.copyWith(
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: FolioSpace.sm),
        if (filteredVisits.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: FolioSpace.md),
            child: Text(
              visits.isNotEmpty && query.isNotEmpty
                  ? l10n.workspaceHomeNoRecentMatch
                  : l10n.workspaceHomeNoRecentPages,
              style: textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          )
        else
          ...filteredVisits.map((v) {
            final page = pagesById[v.pageId];
            if (page == null) return const SizedBox.shrink();
            final opened = DateTime.fromMillisecondsSinceEpoch(
              v.visitedAtMs,
            );
            final openedStr = dateTimeMedium.format(opened);
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: FolioSpace.sm,
                vertical: FolioSpace.xs,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(FolioRadius.md),
              ),
              tileColor: scheme.surfaceContainerHigh,
              leading: FolioIconTokenView(
                appSettings: widget.appSettings,
                token: page.emoji,
                fallbackText: '📄',
                size: 28,
              ),
              title: Text(
                page.title.trim().isEmpty ? l10n.untitled : page.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                l10n.workspaceHomeVisitedAt(openedStr),
                style: textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              trailing: Icon(
                Icons.chevron_right_rounded,
                color: scheme.onSurfaceVariant,
              ),
              onTap: () => widget.onSelectPage(page.id),
            );
          }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final pagesById = <String, FolioPage>{
      for (final p in widget.session.pages) p.id: p,
    };
    final query = _filterController.text.trim().toLowerCase();
    final filteredVisits = query.isEmpty
        ? _visits
        : _visits.where((v) {
            final page = pagesById[v.pageId];
            if (page == null) return false;
            final title = page.title.toLowerCase();
            return title.contains(query);
          }).toList();

    final now = _now;
    final dateStr = DateFormat.yMMMMEEEEd(locale).format(now);
    final timeStyle = widget.mobileOptimized
        ? theme.textTheme.headlineMedium
        : theme.textTheme.displaySmall;
    final timeStr = _homeClockTimeString(now, locale);
    final dateTimeMedium = DateFormat('yMMMd jm', locale);
    final upcoming = _upcomingTasks();
    final countsByDay = _dueCountByDay(upcoming);
    final today = DateTime(now.year, now.month, now.day);
    final showAiChip = widget.onAskAiAboutUpcomingTasks != null &&
        widget.appSettings.isAiRuntimeEnabled &&
        widget.session.aiEnabled;

    final rootPages = widget.session.pages
        .where((p) => p.parentId == null)
        .take(8)
        .toList(growable: false);
    final showCloudQuick =
        widget.appSettings.workspaceHomeShowFolioCloudCard &&
            Firebase.apps.isNotEmpty &&
            widget.cloudAccount.isSignedIn;

    final body = LayoutBuilder(
      builder: (context, constraints) {
        final layout = widget.appSettings.workspaceHomeColumnLayout;
        var useTwoColumns = !widget.mobileOptimized &&
            !widget.compact &&
            constraints.maxWidth >= _twoColumnBreakpoint;
        if (layout == WorkspaceHomeColumnLayout.single) {
          useTwoColumns = false;
        } else if (layout == WorkspaceHomeColumnLayout.dual) {
          useTwoColumns = !widget.mobileOptimized &&
              !widget.compact &&
              constraints.maxWidth >= 640;
        }
        final maxContentWidth = widget.compact
            ? double.infinity
            : (useTwoColumns ? 1040.0 : 600.0);

        List<Widget> spacedModules(Iterable<Widget?> modules) {
          final out = <Widget>[];
          var first = true;
          for (final w in modules) {
            if (w == null) continue;
            if (!first) {
              out.add(const SizedBox(height: FolioSpace.lg));
            }
            first = false;
            out.add(w);
          }
          return out;
        }

        final heroHeader = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    _greeting(l10n),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: l10n.workspaceHomeCustomizeTooltip,
                  icon: const Icon(Icons.tune_rounded),
                  onPressed: () => _showCustomizeSheet(context),
                ),
              ],
            ),
            const SizedBox(height: FolioSpace.sm),
            Text(
              dateStr,
              style: theme.textTheme.titleMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: FolioSpace.xs),
            Text(
              timeStr,
              style: timeStyle?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: scheme.onSurface,
              ),
            ),
            if (widget.appSettings.workspaceHomeClockShowTimezone) ...[
              const SizedBox(height: FolioSpace.xs),
              Text(
                l10n.workspaceHomeClockTimezoneLine(
                  now.timeZoneName,
                  _formatUtcOffset(now.timeZoneOffset),
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: FolioSpace.lg),
            Text(
              l10n.workspaceHomeHeadline,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: FolioSpace.sm),
            Text(
              l10n.workspaceHomeSubtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
          ],
        );

        Widget? moduleLeft(String id) {
          switch (id) {
            case WorkspaceHomeSectionIds.folioCloud:
              if (!showCloudQuick) return null;
              return _buildFolioCloudQuickCard(
                l10n: l10n,
                scheme: scheme,
                textTheme: theme.textTheme,
                snap: widget.folioCloudEntitlements.snapshot,
              );
            case WorkspaceHomeSectionIds.vaultStatus:
              if (!widget.appSettings.workspaceHomeShowVaultStatus) {
                return null;
              }
              return _buildVaultStatusSection(
                l10n,
                scheme,
                theme.textTheme,
                locale,
              );
            case WorkspaceHomeSectionIds.onboarding:
              if (!_shouldShowOnboardingCard()) return null;
              return _buildOnboardingSection(l10n, scheme, theme.textTheme);
            case WorkspaceHomeSectionIds.whatsNew:
              return _buildWhatsNewSection(
                context,
                l10n,
                scheme,
                theme.textTheme,
              );
            case WorkspaceHomeSectionIds.search:
              return Semantics(
                label: l10n.workspaceHomeSearchSemanticsLabel,
                child: TextField(
                  focusNode: _searchFocusNode,
                  controller: _filterController,
                  decoration: InputDecoration(
                    suffixIcon: widget.onOpenSearch == null
                        ? null
                        : IconButton(
                            tooltip: l10n.workspaceHomeGlobalSearchTooltip,
                            icon: const Icon(Icons.manage_search_rounded),
                            onPressed: () =>
                                _emitOpenGlobalSearch(_filterController.text),
                          ),
                    hintText: l10n.workspaceHomeSearchHint,
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(FolioRadius.md),
                    ),
                  ),
                  textInputAction: TextInputAction.search,
                  onTapOutside: (_) => FocusScope.of(context).unfocus(),
                  onSubmitted: (_) =>
                      _emitOpenGlobalSearch(_filterController.text),
                ),
              );
            case WorkspaceHomeSectionIds.rootPages:
              if (!widget.appSettings.workspaceHomeShowRootPages ||
                  rootPages.isEmpty) {
                return null;
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.workspaceHomeRootPagesTitle,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: FolioSpace.sm),
                  SizedBox(
                    height: 40,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: rootPages.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(width: FolioSpace.xs),
                      itemBuilder: (context, i) {
                        final p = rootPages[i];
                        final title =
                            p.title.trim().isEmpty ? l10n.untitled : p.title;
                        return ActionChip(
                          avatar: FolioIconTokenView(
                            appSettings: widget.appSettings,
                            token: p.emoji,
                            fallbackText: '📄',
                            size: 22,
                          ),
                          label: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onPressed: () => widget.onSelectPage(p.id),
                        );
                      },
                    ),
                  ),
                ],
              );
            case WorkspaceHomeSectionIds.miniStats:
              if (!widget.appSettings.workspaceHomeShowMiniStats) {
                return null;
              }
              return Text(
                l10n.workspaceHomeMiniStats(
                  widget.session.pages.length,
                  upcoming.length,
                ),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              );
            case WorkspaceHomeSectionIds.recents:
              return _buildRecentsSection(
                l10n: l10n,
                scheme: scheme,
                textTheme: theme.textTheme,
                filteredVisits: filteredVisits,
                pagesById: pagesById,
                query: query,
                visits: _visits,
                dateTimeMedium: dateTimeMedium,
              );
            default:
              return null;
          }
        }

        Widget? moduleRight(String id) {
          switch (id) {
            case WorkspaceHomeSectionIds.tasks:
              if (!widget.appSettings.workspaceHomeShowTasksSection) {
                return null;
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.workspaceHomeUpcomingTasksTitle,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: FolioSpace.sm),
                  _WeekStrip(
                    locale: locale,
                    today: today,
                    countsByDay: countsByDay,
                    scheme: scheme,
                    textTheme: theme.textTheme,
                  ),
                  const SizedBox(height: FolioSpace.sm),
                  if (upcoming.isEmpty)
                    Text(
                      l10n.workspaceHomeUpcomingTasksEmpty,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    )
                  else
                    ...upcoming.map((e) {
                      final day = _taskDueDay(e)!;
                      final dueLabel = DateFormat.MMMd(locale).format(day);
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: FolioSpace.sm,
                          vertical: FolioSpace.xs,
                        ),
                        dense: true,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(FolioRadius.md),
                        ),
                        tileColor: scheme.surfaceContainerHighest
                            .withValues(alpha: 0.35),
                        title: Text(
                          e.displayTitle.isEmpty ? l10n.none : e.displayTitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          '${e.pageTitle} · $dueLabel',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        trailing: Icon(
                          Icons.event_rounded,
                          size: 20,
                          color: scheme.tertiary,
                        ),
                        onTap: widget.onOpenTaskInPage == null
                            ? null
                            : () => widget.onOpenTaskInPage!(
                                  e.pageId,
                                  e.blockId,
                                ),
                      );
                    }),
                  if (showAiChip) ...[
                    const SizedBox(height: FolioSpace.md),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: ActionChip(
                        avatar: Icon(
                          Icons.auto_awesome_rounded,
                          size: 18,
                          color: scheme.primary,
                        ),
                        label: Text(l10n.workspaceHomeAiTasksChipLabel),
                        onPressed: widget.onAskAiAboutUpcomingTasks,
                      ),
                    ),
                  ],
                ],
              );
            case WorkspaceHomeSectionIds.quickActions:
              if (!widget.appSettings.workspaceHomeShowQuickActions) {
                return null;
              }
              return _buildQuickActionsPanel(
                l10n: l10n,
                scheme: scheme,
                textTheme: theme.textTheme,
              );
            case WorkspaceHomeSectionIds.tip:
              if (!widget.appSettings.workspaceHomeShowTip) return null;
              return Container(
                padding: const EdgeInsets.all(FolioSpace.md),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(FolioRadius.lg),
                  border: Border.all(
                    color: scheme.outlineVariant.withValues(
                      alpha: FolioAlpha.track,
                    ),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.lightbulb_outline_rounded,
                      size: 20,
                      color: scheme.tertiary,
                    ),
                    const SizedBox(width: FolioSpace.sm),
                    Expanded(
                      child: Text(
                        _tipText(l10n, _tipSlotIndex()),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            case WorkspaceHomeSectionIds.createPage:
              return FilledButton.tonalIcon(
                onPressed: widget.onCreatePage,
                icon: const Icon(Icons.add_rounded),
                label: Text(l10n.createPage),
              );
            default:
              return null;
          }
        }

        final leftOrdered = spacedModules(
          widget.appSettings.workspaceHomeLeftSectionOrder.map(moduleLeft),
        );
        final rightOrdered = spacedModules(
          widget.appSettings.workspaceHomeRightSectionOrder.map(moduleRight),
        );

        final leftColumnChildren = <Widget>[
          heroHeader,
          ...leftOrdered,
        ];

        final rightColumnChildren = <Widget>[
          ...rightOrdered,
        ];

        final scrollContent = useTwoColumns
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 11,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: leftColumnChildren,
                    ),
                  ),
                  const SizedBox(width: FolioSpace.lg),
                  Expanded(
                    flex: 9,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: rightColumnChildren,
                    ),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ...leftColumnChildren,
                  if (rightOrdered.isNotEmpty) ...[
                    const SizedBox(height: FolioSpace.lg),
                    ...rightColumnChildren,
                  ],
                ],
              );

        return SingleChildScrollView(
          padding: const EdgeInsets.all(FolioSpace.xl),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxContentWidth),
                child: scrollContent,
              ),
            ),
          ),
        );
      },
    );

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.escape): () {
          FocusManager.instance.primaryFocus?.unfocus();
        },
      },
      child: body,
    );
  }
}

class _WeekStrip extends StatelessWidget {
  const _WeekStrip({
    required this.locale,
    required this.today,
    required this.countsByDay,
    required this.scheme,
    required this.textTheme,
  });

  final String locale;
  final DateTime today;
  final Map<DateTime, int> countsByDay;
  final ColorScheme scheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(7, (i) {
        final day = today.add(Duration(days: i));
        final n = countsByDay[day] ?? 0;
        return Expanded(
          child: Column(
            children: [
              Text(
                DateFormat.E(locale).format(day),
                style: textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: n > 0
                      ? scheme.primary
                      : scheme.outlineVariant.withValues(alpha: 0.35),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}
