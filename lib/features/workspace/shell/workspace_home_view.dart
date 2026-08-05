import 'dart:async';

import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/app_settings.dart';
import '../../../app/workspace_prefs_keys.dart';
import '../../../config/models/dashboard_config.dart';
import '../../../config/models/widget_instance_config.dart';
import '../../../app/ui_tokens.dart';
import '../../../app/widgets/folio_icon_token_view.dart';
import '../../../app/widgets/folio_skeletons.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../models/folio_page.dart';
import '../../../models/vault_task_list_entry.dart';
import '../../../session/vault_session.dart';
import '../../../services/cloud_account/cloud_account_controller.dart';
import '../../../services/folio_cloud/folio_cloud_entitlements.dart';
import '../../../widget_catalog/widget_catalog.dart';
import '../recent_page_visits.dart';

import '../../../services/folio_cloud/folio_cloud_identity.dart';
/// Pantalla de inicio del workspace (sin página seleccionada).
class WorkspaceHomeView extends StatefulWidget {
  const WorkspaceHomeView({
    super.key,
    required this.session,
    required this.appSettings,
    required this.dashboardGridController,
    required this.onCreatePage,
    this.onOpenSearch,
    required this.onSelectPage,
    required this.compact,
    required this.mobileOptimized,
    this.onOpenTaskInPage,
    this.onAskAiAboutUpcomingTasks,
    this.onOpenSettings,
    this.onOpenSyncConflicts,
    this.onOpenGraph,
    this.onOpenTemplateGallery,
    this.onLockVault,
    this.onForceSyncDevices,
    this.onQuickAddTask,
    this.onOpenVaultTasks,
    this.onAddRootFolder,
    this.onImportMarkdown,
    this.onOpenFolioCloudPitch,
    required this.cloudAccount,
    required this.folioCloudEntitlements,
    required this.mobilePreviewReadOnly,
    required this.onOpenReleaseNotes,
  });

  final VaultSession session;
  final AppSettings appSettings;
  final DashboardGridController dashboardGridController;
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
  final VoidCallback? onOpenSyncConflicts;
  final VoidCallback? onOpenGraph;
  final VoidCallback? onOpenTemplateGallery;
  final VoidCallback? onLockVault;
  final VoidCallback? onForceSyncDevices;
  final VoidCallback? onQuickAddTask;
  final VoidCallback? onOpenVaultTasks;
  final VoidCallback? onAddRootFolder;
  final VoidCallback? onImportMarkdown;
  final VoidCallback? onOpenFolioCloudPitch;

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
  bool _cloudGuestDismissed = false;
  bool _cloudExploreDone = false;
  late final Future<PackageInfo> _packageInfoFuture = PackageInfo.fromPlatform();

  @override
  void initState() {
    super.initState();
    widget.session.addListener(_onSession);
    widget.appSettings.addListener(_onSettingsOrCloud);
    widget.dashboardGridController.addListener(_onSettingsOrCloud);
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
    widget.dashboardGridController.removeListener(_onSettingsOrCloud);
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
    final ids = {for (final p in widget.session.activePages) p.id};
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

  /// Renderiza [instance] vía el catálogo de widgets (Fase 4) para
  /// cualquier `pluginId` que no sea una de las 12 secciones legacy que
  /// `moduleLeft`/`moduleRight` manejan arriba — el mismo mecanismo que ya
  /// usa `DashboardGridRegion` en modo edición, para que la Home normal y
  /// el editor rendericen exactamente el mismo contenido.
  Widget? _buildCatalogFallback(BuildContext context, WidgetInstanceConfig instance) {
    if (!instance.visible) return null;
    final plugin = WidgetCatalogRegistry.instance[instance.pluginId];
    if (plugin == null) return null;
    final pluginContext = WidgetPluginContext(
      appSettings: widget.appSettings,
      configStore: widget.dashboardGridController.store,
      session: widget.session,
      onOpenSearch: widget.onOpenSearch,
      onCreatePage: widget.onCreatePage,
      onSelectPage: widget.onSelectPage,
    );
    return SizedBox(
      height: instance.height ?? plugin.defaultHeight,
      child: plugin.build(context, instance, pluginContext),
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
    final cloudGuestDismissed =
        p.getBool(WorkspacePrefsKeys.homeCloudGuestDismiss(vid)) ?? false;
    final cloudExploreDone =
        p.getBool(WorkspacePrefsKeys.homeOnboardCloudExploreDone(vid)) ?? false;
    if (!mounted) return;
    setState(() {
      _onboardAnchorMs = anchor;
      _onboardDismissedLoaded = true;
      _onboardDismissed = dismissed;
      _cloudGuestDismissed = cloudGuestDismissed;
      _cloudExploreDone = cloudExploreDone;
    });
  }

  Future<void> _dismissCloudGuestTeaser() async {
    final vid = widget.session.activeVaultId ?? '';
    if (vid.isEmpty) return;
    final p = await SharedPreferences.getInstance();
    await p.setBool(WorkspacePrefsKeys.homeCloudGuestDismiss(vid), true);
    if (!mounted) return;
    setState(() => _cloudGuestDismissed = true);
  }

  Future<void> _markCloudExploreDone() async {
    final vid = widget.session.activeVaultId ?? '';
    if (vid.isEmpty) return;
    final p = await SharedPreferences.getInstance();
    await p.setBool(WorkspacePrefsKeys.homeOnboardCloudExploreDone(vid), true);
    if (!mounted) return;
    setState(() => _cloudExploreDone = true);
  }

  bool _shouldShowCloudGuestTeaser() {
    if (!widget.appSettings.workspaceHomeShowFolioCloudCard) return false;
    if (!folioCloudHasSession()) return false;
    if (_cloudGuestDismissed) return false;
    if (widget.folioCloudEntitlements.snapshot.active) return false;
    final anchor = _onboardAnchorMs;
    if (anchor == null) return false;
    final elapsed = DateTime.now().millisecondsSinceEpoch - anchor;
    if (elapsed > 14 * 86400000) return false;
    return true;
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
    if (AppSettings.isContinuousVaultBackupInterval(intervalMinutes)) {
      return l10n.scheduledVaultBackupEveryChange;
    }
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
          if (prefs.hasNetworkDestination) {
            final destLabels = <String>[];
            if (prefs.hasFolderDestination) {
              destLabels.add(l10n.scheduledVaultBackupFolderTitle);
            }
            if (prefs.hasWebDavDestination) {
              destLabels.add(l10n.remoteBackupWebdavTitle);
            }
            lines.add(
              Text(
                destLabels.join(' · '),
                style: textTheme.labelMedium?.copyWith(
                  color: scheme.primary,
                ),
              ),
            );
          }
        }
        if (conflicts > 0) {
          lines.add(const SizedBox(height: FolioSpace.xs));
          lines.add(
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: widget.onOpenSyncConflicts,
                style: TextButton.styleFrom(
                  foregroundColor: scheme.error,
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  l10n.workspaceHomeVaultSyncConflicts(conflicts),
                  style: textTheme.bodyMedium?.copyWith(
                    color: scheme.error,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
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
    VoidCallback? onTap,
  }) {
    final row = Row(
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
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: onTap == null
          ? row
          : InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(FolioRadius.sm),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: row,
              ),
            ),
    );
  }

  Future<void> _openCloudPitchFromHome() async {
    await _markCloudExploreDone();
    widget.onOpenFolioCloudPitch?.call();
  }

  Widget _buildFolioCloudGuestTeaser({
    required AppLocalizations l10n,
    required ColorScheme scheme,
    required TextTheme textTheme,
  }) {
    return Container(
      padding: const EdgeInsets.all(FolioSpace.md),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(FolioRadius.lg),
        border: Border.all(
          color: scheme.primary.withValues(alpha: 0.2),
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
                  l10n.folioCloudPitchGuestTeaserTitle,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                tooltip: l10n.workspaceHomeOnboardingDismiss,
                icon: const Icon(Icons.close_rounded),
                onPressed: () => unawaited(_dismissCloudGuestTeaser()),
              ),
            ],
          ),
          const SizedBox(height: FolioSpace.xs),
          Text(
            l10n.folioCloudPitchGuestTeaserBody,
            style: textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
          const SizedBox(height: FolioSpace.sm),
          if (widget.onOpenFolioCloudPitch != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => unawaited(_openCloudPitchFromHome()),
                icon: const Icon(Icons.auto_awesome_outlined, size: 18),
                label: Text(l10n.workspaceHomeCloudGuestTeaserCta),
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
    final pages = widget.session.activePages;
    final hasPage = pages.isNotEmpty;
    final hasSubpage = pages.any((p) => p.parentId != null);
    final usedSearch = widget.appSettings.recentSearchQueries.isNotEmpty;
    final showCloudExplore = folioCloudHasSession();
    final cloudExploreDone = _cloudExploreDone ||
        widget.cloudAccount.isSignedIn ||
        widget.folioCloudEntitlements.snapshot.active;
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
          if (showCloudExplore)
            _onboardingStepRow(
              scheme: scheme,
              textTheme: textTheme,
              label: l10n.workspaceHomeOnboardingStepCloudExplore,
              done: cloudExploreDone,
              onTap: cloudExploreDone
                  ? null
                  : () => unawaited(_openCloudPitchFromHome()),
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
            child: FolioLoadingIndicator(
              size: FolioLoadingSize.small,
              centered: true,
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
    final unlimited = snap.folioStaff;
    final showBackupBar =
        snap.canUseCloudBackup && (unlimited || quota > 0);
    final remainingBytes =
        !unlimited && showBackupBar ? (quota - usedBytes).clamp(0, quota) : 0;
    final pct = !unlimited && showBackupBar
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
          Tooltip(
            message: unlimited
                ? l10n.workspaceHomeCloudStaffShort
                : l10n.aiChatInkBreakdownTooltip(
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
                        unlimited
                            ? '∞'
                            : l10n.folioCloudInkCount(ink.totalInk),
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
                value: unlimited ? 0 : usedBytes / quota,
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
                Text(
                  unlimited
                      ? '∞'
                      : l10n.folioCloudBackupStorageBarPercent(pct!),
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
                unlimited ? '∞' : _formatStorageBytes(quota),
                unlimited ? '∞' : _formatStorageBytes(remainingBytes),
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
    final valid = widget.session.activePages.map((p) => p.id).toSet();
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
      widget.onOpenVaultTasks,
      Icons.task_alt_outlined,
      l10n.workspaceHomeQuickVaultTasks,
      l10n.sidebarTaskHub,
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
        LayoutBuilder(
          builder: (context, constraints) {
            final maxW = constraints.maxWidth;
            const spacing = FolioSpace.sm;
            const aspect = 2.2;
            final tileW = (maxW - spacing) / 2;
            final tileH = tileW / aspect;
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                for (final t in tiles)
                  SizedBox(
                    width: tileW,
                    height: tileH,
                    child: t,
                  ),
              ],
            );
          },
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
            // Material propio: evita "ListTile background color or ink
            // splashes may be invisible" cuando hay un contenedor con color
            // entre el tile y el Material ancestro.
            return Material(
              type: MaterialType.transparency,
              child: ListTile(
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
              ),
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
      for (final p in widget.session.activePages) p.id: p,
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
    final dateTimeMedium = DateFormat('yMMMd jm', locale);
    final upcoming = _upcomingTasks();
    final countsByDay = _dueCountByDay(upcoming);
    final today = DateTime(now.year, now.month, now.day);
    final showAiChip = widget.onAskAiAboutUpcomingTasks != null &&
        widget.appSettings.isAiRuntimeEnabled &&
        widget.session.aiEnabled;

    final rootPages = widget.session.activePages
        .where((p) => p.parentId == null)
        .take(8)
        .toList(growable: false);
    final showCloudQuick =
        widget.appSettings.workspaceHomeShowFolioCloudCard &&
            folioCloudHasSession() &&
            widget.cloudAccount.isSignedIn;
    final showCloudGuestTeaser = _shouldShowCloudGuestTeaser();

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

        // Bug real reportado: "Buenas tardes" / fecha / reloj / "Tu
        // espacio" vivían como chrome fijo aparte (heroHeader), separado
        // del reloj — el usuario los ve como una sola pieza. Todo ese
        // bloque ahora es la salida de ClockWidgetPlugin.build() (ver
        // clock_widget_plugin.dart), renderizado a través del catálogo
        // como cualquier otro widget — seleccionable/editable en el editor
        // visual y removible desde el editor de dashboard, en vez de texto
        // fijo imposible de tocar.

        Widget? moduleLeft(WidgetInstanceConfig instance) {
          final id = instance.pluginId;
          switch (id) {
            case WorkspaceHomeSectionIds.folioCloud:
              if (showCloudQuick) {
                return _buildFolioCloudQuickCard(
                  l10n: l10n,
                  scheme: scheme,
                  textTheme: theme.textTheme,
                  snap: widget.folioCloudEntitlements.snapshot,
                );
              }
              if (showCloudGuestTeaser) {
                return _buildFolioCloudGuestTeaser(
                  l10n: l10n,
                  scheme: scheme,
                  textTheme: theme.textTheme,
                );
              }
              return null;
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
                  widget.session.activePages.length,
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
              // Bug real reportado por el usuario: un pack visual (ej.
              // Paper) puede componer su dashboard con plugins del catálogo
              // nuevo (Fase 4) que no son ninguna de las 12 secciones
              // legacy de arriba — antes de esto se veían en el editor
              // ("Editar inicio (beta)") pero desaparecían silenciosamente
              // en la Home normal, dando la sensación de "veo una cosa al
              // entrar y otra al editar".
              return _buildCatalogFallback(context, instance);
          }
        }

        Widget? moduleRight(WidgetInstanceConfig instance) {
          final id = instance.pluginId;
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
                      // Material propio: evita el error de fondo invisible
                      // del ListTile con tileColor (ver _buildRecentsSection).
                      return Material(
                        type: MaterialType.transparency,
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: FolioSpace.sm,
                            vertical: FolioSpace.xs,
                          ),
                          dense: true,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(FolioRadius.md),
                          ),
                          tileColor: scheme.surfaceContainerHighest
                              .withValues(alpha: 0.35),
                          title: Text(
                            e.displayTitle.isEmpty
                                ? l10n.none
                                : e.displayTitle,
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
                        ),
                      );
                    }),
                  if (showAiChip) ...[
                    const SizedBox(height: FolioSpace.md),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: ActionChip(
                        avatar: Icon(
                          FolioIcons.quill,
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
              return _buildCatalogFallback(context, instance);
          }
        }

        // Catálogo de widgets de dashboard (Fase 4/5): el orden renderizado
        // viene del DashboardGridController — el contenido de cada sección
        // (moduleLeft/moduleRight arriba) sigue siendo el switch legacy sin
        // tocar (demasiado acoplado a closures locales para extraerlo sin
        // poder verificarlo visualmente, ver Fase 4 del plan). El hook
        // AppSettings.onWorkspaceHomeDashboardChanged (main.dart) mantiene
        // el controller sincronizado en cada toggle/reorder legacy, así que
        // este orden y `appSettings.workspaceHomeLeftSectionOrder` siempre
        // coinciden — el fallback solo cubre un controller vacío (arranque
        // en frío antes de la primera migración).
        final controllerLeftInstances = widget.dashboardGridController
            .widgetsInRegion(DashboardRegionIds.left);
        final controllerRightInstances = widget.dashboardGridController
            .widgetsInRegion(DashboardRegionIds.right);
        // Fallback de arranque en frío (antes de la primera migración):
        // sin instancias todavía en el controller, se sintetiza una
        // WidgetInstanceConfig mínima por cada id legacy de AppSettings —
        // esas ids son siempre una de las 12 secciones migradas, así que
        // nunca ejercitan _buildCatalogFallback.
        final leftInstances = controllerLeftInstances.isNotEmpty
            ? controllerLeftInstances
            : widget.appSettings.workspaceHomeLeftSectionOrder
                  .map(
                    (id) => WidgetInstanceConfig(
                      instanceId: id,
                      pluginId: id,
                      regionId: DashboardRegionIds.left,
                    ),
                  )
                  .toList();
        final rightInstances = controllerRightInstances.isNotEmpty
            ? controllerRightInstances
            : widget.appSettings.workspaceHomeRightSectionOrder
                  .map(
                    (id) => WidgetInstanceConfig(
                      instanceId: id,
                      pluginId: id,
                      regionId: DashboardRegionIds.right,
                    ),
                  )
                  .toList();
        final leftOrdered = spacedModules(leftInstances.map(moduleLeft));
        final rightOrdered = spacedModules(rightInstances.map(moduleRight));

        final leftColumnChildren = <Widget>[...leftOrdered];

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
