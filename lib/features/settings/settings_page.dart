import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:passkeys/exceptions.dart';
import 'package:record/record.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path/path.dart' as p;

import '../../app/app_settings.dart';
import '../../models/quill_system_prompt.dart';
import '../../app/folio_build_flags.dart';
import '../../app/folio_distribution.dart';
import '../../app/folio_store_listing.dart';
import '../../app/folio_in_app_shortcuts.dart';
import '../../app/ui_tokens.dart';
import '../../app/widgets/folio_dialog.dart';
import '../../app/widgets/folio_icon_token_view.dart';
import '../../app/widgets/folio_password_field.dart';
import '../../app/widgets/vault_backup_progress_dialog.dart';
import '../../app/widgets/folio_in_app_checkout_dialog.dart';
import '../../app/widgets/folio_skeletons.dart';
import '../../app/widgets/folio_error_card.dart';
import 'in_app_shortcut_capture_dialog.dart';
import '../../crypto/vault_crypto.dart';
import '../../data/notion_import/notion_importer.dart';
import '../../data/vault_registry.dart';
import '../../data/vault_paths.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../data/vault_backup.dart';
import '../../services/ai/ai_service.dart';
import '../../services/ai/ai_provider_detector.dart';
import '../../services/ai/ai_safety_policy.dart';
import '../../services/ai/folio_cloud_ai_service.dart';
import '../../services/ai/lmstudio_ai_service.dart';
import '../../services/ai/ollama_ai_service.dart';
import '../../services/ai/openai_compatible_ai_service.dart';
import '../../services/custom_icon_import_service.dart';
import 'widgets/iconify_icon_browser.dart';
import '../../services/cloud_account/cloud_account_controller.dart';
import '../../services/folio_cloud/folio_cloud_reachability.dart';
import '../../services/folio_cloud/folio_cloud_backup.dart';
import '../../services/folio_cloud/folio_cloud_callable.dart';
import '../../services/folio_cloud/folio_cloud_pack_sync.dart';
import '../../services/folio_cloud/folio_cloud_billing.dart';
import '../../services/folio_cloud/folio_cloud_checkout.dart';
import '../../services/folio_cloud/folio_cloud_conversion_flow.dart';
import '../../services/folio_cloud/folio_cloud_entitlements.dart';
import '../../services/folio_cloud/folio_cloud_ai_pricing.dart';
import '../../services/folio_cloud/folio_cloud_publish.dart';
import '../../services/folio_cloud/folio_web_portal_api.dart';
import '../../services/device_sync/device_sync_controller.dart';
import '../../services/device_sync/device_sync_models.dart';
import '../../services/system_audio_service.dart';
import '../../services/transcription_hardware_profile.dart';
import '../../services/whisper_service.dart';
import '../../services/updater/github_release_updater.dart';
import '../../services/updater/update_release_channel.dart';
import '../../session/vault_session.dart';
import '../release_notes/release_notes_page.dart';
import 'jira_integration_settings.dart';
import 'youtrack_integration_settings.dart';
import 'release_readiness.dart';
import 'folio_cloud_reauth_dialog.dart';
import 'folio_cloud_subscription_pitch_page.dart';
import 'vault_identity_verify_dialog.dart';
import '../../services/folio_diagnostic_reporter.dart';
import '../../services/platform/browser_file_download.dart';
import '../../services/secure_credential_storage.dart';
import '../../services/backup_destinations/backup_export_runner.dart';
import '../../services/backup_destinations/backup_destination.dart';
import 'remote_backup_config_dialog.dart';
import 'remote_backup_restore_dialog.dart';
import 'remote_backup_export_destination_dialog.dart';
import '../../services/app_store/app_store_service.dart';
import '../../services/app_store/folio_built_in_apps.dart';
import '../app_store/app_store_screen.dart';
import 'widgets/telemetry_sent_data_widget.dart';
import '../telemetry_dashboard/telemetry_dashboard_page.dart';
import '../../services/folio_firestore_sync.dart';

part 'settings_page_widgets.dart';
part 'settings_page_dialogs.dart';
part 'settings_page_panels.dart';
part 'settings_page_folio_cloud.dart';
part 'settings_page_state_backup_flows.dart';
part 'settings_page_state_folio_cloud.dart';
part 'settings_page_state_ai.dart';
part 'settings_page_state_cloud_vault.dart';
part 'settings_page_state_backup_security.dart';

String settingsCloudInkOperationLabel(
  AppLocalizations l10n,
  String operationKind,
) {
  switch (operationKind) {
    case 'rewrite_block':
      return l10n.settingsCloudInkOpRewriteBlock;
    case 'summarize_selection':
      return l10n.settingsCloudInkOpSummarizeSelection;
    case 'extract_tasks':
      return l10n.settingsCloudInkOpExtractTasks;
    case 'summarize_page':
      return l10n.settingsCloudInkOpSummarizePage;
    case 'generate_insert':
      return l10n.settingsCloudInkOpGenerateInsert;
    case 'generate_page':
      return l10n.settingsCloudInkOpGeneratePage;
    case 'chat_turn':
      return l10n.settingsCloudInkOpChatTurn;
    case 'agent_main':
      return l10n.settingsCloudInkOpAgentMain;
    case 'agent_followup':
      return l10n.settingsCloudInkOpAgentFollowup;
    case 'edit_page_panel':
      return l10n.settingsCloudInkOpEditPagePanel;
    case 'default':
      return l10n.settingsCloudInkOpDefault;
    default:
      return operationKind;
  }
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.session,
    required this.appSettings,
    required this.deviceSyncController,
    required this.cloudAccountController,
    required this.folioCloudEntitlements,
    this.initialSection,
  });

  final VaultSession session;
  final AppSettings appSettings;
  final DeviceSyncController deviceSyncController;
  final CloudAccountController cloudAccountController;
  final FolioCloudEntitlementsController folioCloudEntitlements;
  final String? initialSection;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  static const _idleOptions = <int>[1, 5, 10, 15, 30, 60];
  VaultSession get _s => widget.session;
  AppSettings get _app => widget.appSettings;
  DeviceSyncController get _sync => widget.deviceSyncController;
  CloudAccountController get _cloud => widget.cloudAccountController;
  FolioCloudEntitlementsController get _folio => widget.folioCloudEntitlements;
  final ScrollController _settingsScrollController = ScrollController();
  final TextEditingController _settingsSectionFilterController =
      TextEditingController();
  _SettingsSectionId? _selectedMobileSection;

  var _quickEnabled = false;
  var _passkeyRegistered = false;
  late final TextEditingController _aiBaseUrlController;
  late final TextEditingController _aiApiKeyController;
  late final TextEditingController _aiTimeoutController;
  late final TextEditingController _aiContextWindowController;
  late final TextEditingController _customIconSourceController;
  late final TextEditingController _customIconLabelController;
  late final TextEditingController _webLinkCodeController;
  List<String> _availableModels = const [];
  bool _loadingModels = false;
  bool _checkingUpdates = false;
  bool _openingReleaseNotes = false;
  bool _detectingAiProvider = false;
  bool _importingCustomIcon = false;
  String _installedVersionLabel = '...';
  bool _folioCloudActionBusy = false;
  bool _webLinkBusy = false;
  bool _cloudBackupCountBusy = false;
  final AudioRecorder _meetingNoteDeviceProbe = AudioRecorder();
  List<InputDevice> _meetingNoteMicDevices = const [];
  List<SystemAudioDevice> _meetingNoteSystemDevices = const [];
  final CustomIconImportService _customIconImportService =
      CustomIconImportService();

  String? _taskInboxPageIdLoaded;
  Map<String, String> _taskAliasesLoaded = const {};
  VaultBackupPrefs _vaultBackupPrefs = const VaultBackupPrefs();
  final SecureCredentialStorage _backupCredentials = SecureCredentialStorage();
  bool _deferHeavyBuild = true;
  bool _didRunDeferredInit = false;

  /// `setState` is `@protected`, so the `extension ... on _SettingsPageState`
  /// blocks in the `settings_page_state_*.dart` part files (used to split
  /// this class's methods across files) can't call it directly. Route
  /// through this regular instance method instead.
  void _rebuild(VoidCallback fn) => setState(fn);

  void _runDeferredInitIfNeeded() {
    if (_didRunDeferredInit) return;
    _didRunDeferredInit = true;

    unawaited(_loadMeetingNoteDevices());
    _refreshSecurityFlags();
    _loadInstalledVersionInfo();
    _refreshReleaseReadiness();
    unawaited(_refreshCloudBackupCount());
    unawaited(_loadTaskCapturePrefs());
    unawaited(_loadVaultBackupPrefs());
  }

  void _onCloudOrFolioChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();
    _aiBaseUrlController = TextEditingController(text: _app.aiBaseUrl);
    _aiApiKeyController = TextEditingController(text: _app.aiApiKey);
    _aiTimeoutController = TextEditingController(
      text: _app.aiTimeoutMs.toString(),
    );
    _aiContextWindowController = TextEditingController(
      text: _app.aiContextWindowTokens.toString(),
    );
    _customIconSourceController = TextEditingController();
    _customIconLabelController = TextEditingController();
    _webLinkCodeController = TextEditingController();
    _availableModels = _app.cachedAiModelsFor(_app.aiProvider);
    _settingsSectionFilterController.addListener(() {
      if (mounted) setState(() {});
    });
    _cloud.addListener(_onCloudOrFolioChanged);
    _folio.addListener(_onCloudOrFolioChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Evita el “parón” al navegar: primer frame ligero, luego render/cargas.
      setState(() => _deferHeavyBuild = false);
      _runDeferredInitIfNeeded();
      // Jump to a specific section if requested (e.g. opening from the chat panel)
      if (widget.initialSection != null) {
        final target = _SettingsSectionId.values.firstWhere(
          (id) => id.name == widget.initialSection,
          orElse: () => _SettingsSectionId.ai,
        );
        setState(() => _selectedMobileSection = target);
      }
    });
  }

  Future<void> _loadTaskCapturePrefs() async {
    if (!_s.isUnlocked) return;
    final vid = _s.activeVaultId;
    final inbox = await _app.getTaskInboxPageId(vid);
    final aliases = await _app.getTaskAliasPageMap(vid);
    if (!mounted) return;
    setState(() {
      _taskInboxPageIdLoaded = inbox;
      _taskAliasesLoaded = Map<String, String>.from(aliases);
    });
  }

  String? get _vaultId => _s.activeVaultId;

  Future<void> _loadVaultBackupPrefs() async {
    if (!_s.isUnlocked) return;
    final prefs = await _app.getVaultBackupPrefs(_vaultId);
    if (!mounted) return;
    setState(() => _vaultBackupPrefs = prefs);
  }

  Future<void> _addTaskAliasDialog() async {
    final l10n = AppLocalizations.of(context);
    var tag = '';
    String? pageId = _s.pages.isEmpty ? null : _s.pages.first.id;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSt) {
            return FolioDialog(
              title: Text(l10n.taskAliasAddButton),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: l10n.taskAliasTagLabel,
                        hintText: 'trabajo',
                      ),
                      onChanged: (v) => tag = v,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      // ignore: deprecated_member_use
                      value: pageId,
                      decoration: InputDecoration(
                        labelText: l10n.taskAliasTargetLabel,
                        border: const OutlineInputBorder(),
                      ),
                      items: _s.pages
                          .map(
                            (p) => DropdownMenuItem<String>(
                              value: p.id,
                              child: Text(
                                p.title.trim().isEmpty
                                    ? l10n.untitledFallback
                                    : p.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setSt(() => pageId = v),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(l10n.cancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(l10n.save),
                ),
              ],
            );
          },
        );
      },
    );
    if (ok != true || !mounted) return;
    final key = tag.trim().toLowerCase().replaceAll(RegExp(r'^[#@]+'), '');
    final pid = pageId?.trim() ?? '';
    if (key.isEmpty || pid.isEmpty) return;
    final next = Map<String, String>.from(_taskAliasesLoaded)..[key] = pid;
    await _app.setTaskAliasPageMap(_s.activeVaultId, next);
    if (mounted) {
      setState(() => _taskAliasesLoaded = next);
    }
  }

  Future<void> _removeTaskAlias(String key) async {
    final next = Map<String, String>.from(_taskAliasesLoaded)..remove(key);
    await _app.setTaskAliasPageMap(_s.activeVaultId, next);
    if (mounted) {
      setState(() => _taskAliasesLoaded = next);
    }
  }

  @override
  void dispose() {
    _cloud.removeListener(_onCloudOrFolioChanged);
    _folio.removeListener(_onCloudOrFolioChanged);
    _settingsScrollController.dispose();
    _settingsSectionFilterController.dispose();
    _aiBaseUrlController.dispose();
    _aiApiKeyController.dispose();
    _aiTimeoutController.dispose();
    _aiContextWindowController.dispose();
    _customIconSourceController.dispose();
    _customIconLabelController.dispose();
    _webLinkCodeController.dispose();
    unawaited(_meetingNoteDeviceProbe.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (_deferHeavyBuild) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.settings)),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
              const SizedBox(height: 12),
              Text(l10n.loading),
            ],
          ),
        ),
      );
    }
    final scheme = Theme.of(context).colorScheme;
    final windowWidth = MediaQuery.sizeOf(context).width;
    final showDesktopOnlySections = FolioAdaptive.shouldUseDesktopSections(
      windowWidth,
    );
    final desktopSections = <_SettingsSectionNavItem>[
      _SettingsSectionNavItem(
        id: _SettingsSectionId.cloud,
        label: l10n.cloudAccountSectionTitle,
      ),
      _SettingsSectionNavItem(
        id: _SettingsSectionId.vault,
        label: l10n.settingsSectionVault,
        searchExtra: [
          l10n.security,
          l10n.vaultBackup,
          l10n.data,
          l10n.settingsDangerZoneTitle,
        ],
      ),
      _SettingsSectionNavItem(
        id: _SettingsSectionId.uiWorkspace,
        label: l10n.settingsSectionUiWorkspace,
        searchExtra: [
          l10n.appearance,
          l10n.desktopSection,
          l10n.keyboardShortcutsSection,
        ],
      ),
      if (_app.isAiAvailable)
        _SettingsSectionNavItem(id: _SettingsSectionId.ai, label: l10n.ai),
      _SettingsSectionNavItem(
        id: _SettingsSectionId.sync,
        label: l10n.settingsSectionDeviceSyncNav,
      ),
      _SettingsSectionNavItem(id: _SettingsSectionId.about, label: l10n.about),
      if (showDesktopOnlySections)
        _SettingsSectionNavItem(
          id: _SettingsSectionId.integrations,
          label: l10n.integrations,
        ),
    ];
    return AnimatedBuilder(
      animation: _app,
      builder: (context, _) {
        return WillPopScope(
          onWillPop: () async {
            if (_selectedMobileSection != null) {
              setState(() {
                _selectedMobileSection = null;
              });
              return false;
            }
            return true;
          },
          child: Scaffold(
            appBar: AppBar(
              title: Text(
                (_selectedMobileSection != null)
                    ? _getSectionTitle(l10n, _selectedMobileSection!)
                    : l10n.settings,
              ),
              leading: (_selectedMobileSection != null)
                  ? IconButton(
                      icon: const Icon(Icons.arrow_back_rounded),
                      onPressed: () {
                        setState(() {
                          _selectedMobileSection = null;
                        });
                      },
                    )
                  : null,
            ),
            body: LayoutBuilder(
              builder: (context, constraints) {
                final wide =
                    constraints.maxWidth >= FolioDesktop.mediumBreakpoint ||
                    FolioAdaptive.isAndroidDesktopLikeWidth(constraints.maxWidth);
                final settingsContent = ListenableBuilder(
                  listenable: _s,
                  builder: (context, _) {
                    return RepaintBoundary(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              scheme.surfaceContainer.withValues(alpha: 0.72),
                              scheme.surfaceContainerLow,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: scheme.outlineVariant.withValues(alpha: 0.35),
                          ),
                        ),
                        child: AnimatedSwitcher(
                          duration: FolioMotion.medium1,
                          switchInCurve: FolioMotion.emphasized,
                          switchOutCurve: FolioMotion.emphasized,
                          transitionBuilder: (child, animation) {
                            final offsetAnimation = Tween<Offset>(
                              begin: const Offset(0.08, 0.0),
                              end: Offset.zero,
                            ).animate(animation);
                            return FadeTransition(
                              opacity: animation,
                              child: SlideTransition(
                                position: offsetAnimation,
                                child: child,
                              ),
                            );
                          },
                          child: ListView(
                            key: ValueKey<String>('${wide}_${_selectedMobileSection?.name}'),
                            controller: _settingsScrollController,
                            cacheExtent: 480,
                            padding: const EdgeInsets.symmetric(
                              vertical: 24,
                              horizontal: 16,
                            ),
                            children: [
                              if (_selectedMobileSection == null) ...[
                                _SettingsOverviewBanner(
                                  appSettings: _app,
                                  session: _s,
                                  entitlements: _folio,
                                ),
                                const SizedBox(height: 12),
                                Semantics(
                                  label: l10n.settingsSearchSections,
                                  textField: true,
                                  child: TextField(
                                    controller: _settingsSectionFilterController,
                                    decoration: InputDecoration(
                                      prefixIcon: const Icon(Icons.search_rounded),
                                      labelText: l10n.settingsSearchSections,
                                      hintText: l10n.settingsSearchSectionsHint,
                                      border: const OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                                                          if (_settingsSectionFilterController.text.trim().isNotEmpty) ...[
                                  ..._buildSearchResults(context, _settingsSectionFilterController.text, l10n, scheme),
                                ] else ...[
                                  if (wide)
                                    GridView.builder(
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                                        maxCrossAxisExtent: 380,
                                        mainAxisSpacing: 16,
                                        crossAxisSpacing: 16,
                                        mainAxisExtent: 110,
                                      ),
                                      itemCount: _filterDesktopSections(desktopSections).length,
                                      itemBuilder: (context, idx) {
                                        final sec = _filterDesktopSections(desktopSections)[idx];
                                        return _SettingsMenuTile(
                                          sec: sec,
                                          l10n: l10n,
                                          scheme: scheme,
                                          app: _app,
                                          cloud: _cloud,
                                          installedVersionLabel: _installedVersionLabel,
                                          onTap: () {
                                            setState(() {
                                              _selectedMobileSection = sec.id;
                                            });
                                            if (_settingsScrollController.hasClients) {
                                              _settingsScrollController.jumpTo(0);
                                            }
                                          },
                                        );
                                      },
                                    )
                                  else
                                    ..._filterDesktopSections(desktopSections).map(
                                      (sec) => _SettingsMenuTile(
                                        sec: sec,
                                        l10n: l10n,
                                        scheme: scheme,
                                        app: _app,
                                        cloud: _cloud,
                                        installedVersionLabel: _installedVersionLabel,
                                        onTap: () {
                                          setState(() {
                                            _selectedMobileSection = sec.id;
                                          });
                                          if (_settingsScrollController.hasClients) {
                                            _settingsScrollController.jumpTo(0);
                                          }
                                        },
                                      ),
                                    ),
                                ],
                              ],

                          Visibility(
                            visible:
                                _selectedMobileSection ==
                                    _SettingsSectionId.cloud,
                            maintainState: false,
                            child: KeyedSubtree(
                              key: const ValueKey(_SettingsSectionId.cloud),
                              child: _SettingsPanel(
                                margin: const EdgeInsets.only(bottom: 24),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    _SettingsPanelHeroCard(
                                      icon: Icons.cloud_circle_outlined,
                                      title: l10n.cloudAccountSectionTitle,
                                      description:
                                          l10n.cloudAccountSectionDescription,
                                      chips: [
                                        _SettingsInfoChip(
                                          icon: Icons.lock_outline_rounded,
                                          label: l10n.cloudAccountChipOptional,
                                        ),
                                        _SettingsInfoChip(
                                          icon: Icons.payments_outlined,
                                          label: l10n.cloudAccountChipPaidCloud,
                                        ),
                                      ],
                                    ),
                                    const Divider(height: 1),
                                    ListenableBuilder(
                                      listenable: _cloud,
                                      builder: (context, _) {
                                        if (!_cloud.isAvailable) {
                                          return Padding(
                                            padding: const EdgeInsets.fromLTRB(
                                              16,
                                              8,
                                              16,
                                              20,
                                            ),
                                            child: DecoratedBox(
                                              decoration: BoxDecoration(
                                                color: scheme.errorContainer
                                                    .withValues(alpha: 0.22),
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                                border: Border.all(
                                                  color: scheme.outlineVariant
                                                      .withValues(alpha: 0.45),
                                                ),
                                              ),
                                              child: Padding(
                                                padding: const EdgeInsets.all(
                                                  16,
                                                ),
                                                child: Row(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Icon(
                                                      Icons.cloud_off_rounded,
                                                      color: scheme.error,
                                                      size: 26,
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Expanded(
                                                      child: Text(
                                                        l10n.cloudAccountUnavailable,
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .bodyMedium
                                                            ?.copyWith(
                                                              height: 1.4,
                                                              color: scheme
                                                                  .onSurfaceVariant,
                                                            ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          );
                                        }
                                        late final Widget accountCard;
                                        if (_cloud.isSignedIn) {
                                          final u = _cloud.user!;
                                          final email =
                                              u.email?.trim().isNotEmpty == true
                                              ? u.email!.trim()
                                              : '—';
                                          final initial =
                                              email.isNotEmpty && email != '—'
                                              ? email[0].toUpperCase()
                                              : '?';
                                          accountCard = Padding(
                                            padding: const EdgeInsets.fromLTRB(
                                              16,
                                              4,
                                              16,
                                              20,
                                            ),
                                            child: DecoratedBox(
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                  colors: [
                                                    scheme.primaryContainer
                                                        .withValues(
                                                          alpha: 0.35,
                                                        ),
                                                    scheme
                                                        .surfaceContainerHighest,
                                                  ],
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(18),
                                                border: Border.all(
                                                  color: scheme.outlineVariant
                                                      .withValues(alpha: 0.4),
                                                ),
                                              ),
                                              child: Padding(
                                                padding: const EdgeInsets.all(
                                                  18,
                                                ),
                                                child: Semantics(
                                                  container: true,
                                                  label: l10n
                                                      .cloudAccountSignedInAs(
                                                        email,
                                                      ),
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .stretch,
                                                    children: [
                                                      Row(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          CircleAvatar(
                                                            radius: 26,
                                                            backgroundColor:
                                                                scheme.primary
                                                                    .withValues(
                                                                      alpha:
                                                                          0.18,
                                                                    ),
                                                            child: Text(
                                                              initial,
                                                              style: Theme.of(context)
                                                                  .textTheme
                                                                  .titleLarge
                                                                  ?.copyWith(
                                                                    color: scheme
                                                                        .primary,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w700,
                                                                  ),
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                            width: 14,
                                                          ),
                                                          Expanded(
                                                            child: Column(
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .start,
                                                              children: [
                                                                Row(
                                                                  crossAxisAlignment:
                                                                      CrossAxisAlignment
                                                                          .start,
                                                                  children: [
                                                                    Expanded(
                                                                      child: Text(
                                                                        email,
                                                                        style:
                                                                            Theme.of(
                                                                              context,
                                                                            ).textTheme.titleSmall?.copyWith(
                                                                              fontWeight: FontWeight.w700,
                                                                            ),
                                                                      ),
                                                                    ),
                                                                    if (email !=
                                                                        '—')
                                                                      IconButton(
                                                                        tooltip:
                                                                            l10n.cloudAccountCopyEmail,
                                                                        onPressed: () async {
                                                                          await Clipboard.setData(
                                                                            ClipboardData(
                                                                              text: email,
                                                                            ),
                                                                          );
                                                                          if (!context
                                                                              .mounted) {
                                                                            return;
                                                                          }
                                                                          ScaffoldMessenger.of(
                                                                            context,
                                                                          ).showSnackBar(
                                                                            SnackBar(
                                                                              content: Text(
                                                                                l10n.cloudAccountEmailCopied,
                                                                              ),
                                                                            ),
                                                                          );
                                                                        },
                                                                        icon: const Icon(
                                                                          Icons
                                                                              .content_copy_rounded,
                                                                          size:
                                                                              20,
                                                                        ),
                                                                      ),
                                                                  ],
                                                                ),
                                                                if (u
                                                                    .emailVerified)
                                                                  Padding(
                                                                    padding:
                                                                        const EdgeInsets.only(
                                                                          top:
                                                                              6,
                                                                        ),
                                                                    child: Row(
                                                                      mainAxisSize:
                                                                          MainAxisSize
                                                                              .min,
                                                                      children: [
                                                                        Icon(
                                                                          Icons
                                                                              .verified_rounded,
                                                                          size:
                                                                              16,
                                                                          color:
                                                                              scheme.primary,
                                                                        ),
                                                                        const SizedBox(
                                                                          width:
                                                                              4,
                                                                        ),
                                                                        Text(
                                                                          l10n.cloudAccountEmailVerified,
                                                                          style:
                                                                              Theme.of(
                                                                                context,
                                                                              ).textTheme.labelSmall?.copyWith(
                                                                                color: scheme.primary,
                                                                                fontWeight: FontWeight.w600,
                                                                              ),
                                                                        ),
                                                                      ],
                                                                    ),
                                                                  ),
                                                                const SizedBox(
                                                                  height: 6,
                                                                ),
                                                                SelectableText(
                                                                  l10n.cloudAccountUid(
                                                                    _shortCloudUid(
                                                                      u.uid,
                                                                    ),
                                                                  ),
                                                                  style: Theme.of(context)
                                                                      .textTheme
                                                                      .bodySmall
                                                                      ?.copyWith(
                                                                        fontFamily:
                                                                            'monospace',
                                                                        color: scheme
                                                                            .onSurfaceVariant,
                                                                      ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      if (u.email != null &&
                                                          u.email!
                                                              .trim()
                                                              .isNotEmpty &&
                                                          !u.emailVerified) ...[
                                                        const SizedBox(
                                                          height: 12,
                                                        ),
                                                        DecoratedBox(
                                                          decoration: BoxDecoration(
                                                            color: scheme
                                                                .errorContainer
                                                                .withValues(
                                                                  alpha: 0.35,
                                                                ),
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  14,
                                                                ),
                                                            border: Border.all(
                                                              color: scheme
                                                                  .outlineVariant
                                                                  .withValues(
                                                                    alpha: 0.45,
                                                                  ),
                                                            ),
                                                          ),
                                                          child: Padding(
                                                            padding:
                                                                const EdgeInsets.all(
                                                                  14,
                                                                ),
                                                            child: Column(
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .stretch,
                                                              children: [
                                                                Text(
                                                                  l10n.cloudAccountEmailUnverifiedBanner,
                                                                  style: Theme.of(context)
                                                                      .textTheme
                                                                      .bodySmall
                                                                      ?.copyWith(
                                                                        color: scheme
                                                                            .onSurfaceVariant,
                                                                        height:
                                                                            1.35,
                                                                      ),
                                                                ),
                                                                const SizedBox(
                                                                  height: 10,
                                                                ),
                                                                Wrap(
                                                                  spacing: 8,
                                                                  runSpacing: 8,
                                                                  children: [
                                                                    OutlinedButton(
                                                                      onPressed: () {
                                                                        unawaited(
                                                                          _sendCloudEmailVerification(),
                                                                        );
                                                                      },
                                                                      child: Text(
                                                                        l10n.cloudAccountResendVerification,
                                                                      ),
                                                                    ),
                                                                    TextButton(
                                                                      onPressed: () {
                                                                        unawaited(
                                                                          _reloadCloudUserVerificationStatus(),
                                                                        );
                                                                      },
                                                                      child: Text(
                                                                        l10n.cloudAccountReloadVerification,
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                      const SizedBox(
                                                        height: 14,
                                                      ),
                                                      Text(
                                                        l10n.cloudAccountSignOutHelp,
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .bodySmall
                                                            ?.copyWith(
                                                              color: scheme
                                                                  .onSurfaceVariant,
                                                              height: 1.35,
                                                            ),
                                                      ),
                                                      if (email != '—') ...[
                                                        const SizedBox(
                                                          height: 10,
                                                        ),
                                                        Align(
                                                          alignment: Alignment
                                                              .centerLeft,
                                                          child: TextButton.icon(
                                                            onPressed: () {
                                                              unawaited(
                                                                _showCloudPasswordResetDialog(
                                                                  fixedEmail:
                                                                      email,
                                                                ),
                                                              );
                                                            },
                                                            icon: const Icon(
                                                              Icons
                                                                  .lock_reset_rounded,
                                                              size: 20,
                                                            ),
                                                            label: Text(
                                                              l10n.cloudAccountResetPasswordEmail,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                      const SizedBox(
                                                        height: 14,
                                                      ),
                                                      OutlinedButton.icon(
                                                        onPressed: () async {
                                                          try {
                                                            await _cloud
                                                                .signOut();
                                                            if (!context
                                                                .mounted) {
                                                              return;
                                                            }
                                                            ScaffoldMessenger.of(
                                                              context,
                                                            ).showSnackBar(
                                                              SnackBar(
                                                                content: Text(
                                                                  AppLocalizations.of(
                                                                    context,
                                                                  ).settingsSessionEndedSnack,
                                                                ),
                                                              ),
                                                            );
                                                          } catch (e) {
                                                            if (!context
                                                                .mounted) {
                                                              return;
                                                            }
                                                            ScaffoldMessenger.of(
                                                              context,
                                                            ).showSnackBar(
                                                              SnackBar(
                                                                content: Text(
                                                                  '$e',
                                                                ),
                                                              ),
                                                            );
                                                          }
                                                        },
                                                        icon: const Icon(
                                                          Icons.logout_rounded,
                                                          size: 20,
                                                        ),
                                                        label: Text(
                                                          l10n.cloudAccountSignOut,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          );
                                        } else {
                                          accountCard = Padding(
                                            padding: const EdgeInsets.fromLTRB(
                                              16,
                                              4,
                                              16,
                                              20,
                                            ),
                                            child: DecoratedBox(
                                              decoration: BoxDecoration(
                                                color:
                                                    scheme.surfaceContainerLow,
                                                borderRadius:
                                                    BorderRadius.circular(18),
                                                border: Border.all(
                                                  color: scheme.outlineVariant
                                                      .withValues(alpha: 0.4),
                                                ),
                                              ),
                                              child: Padding(
                                                padding: const EdgeInsets.all(
                                                  18,
                                                ),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment
                                                          .stretch,
                                                  children: [
                                                    Text(
                                                      l10n.cloudAccountSignedOutPrompt,
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .bodyMedium
                                                          ?.copyWith(
                                                            height: 1.4,
                                                            color: scheme
                                                                .onSurfaceVariant,
                                                          ),
                                                    ),
                                                    const SizedBox(height: 18),
                                                    LayoutBuilder(
                                                      builder: (context, constraints) {
                                                        final narrow =
                                                            constraints
                                                                .maxWidth <
                                                            420;
                                                        final signInBtn = FilledButton(
                                                          onPressed: () =>
                                                              _showCloudAuthDialog(
                                                                register: false,
                                                              ),
                                                          child: Text(
                                                            l10n.cloudAccountSignIn,
                                                          ),
                                                        );
                                                        final registerBtn =
                                                            OutlinedButton(
                                                              onPressed: () =>
                                                                  _showCloudAuthDialog(
                                                                    register:
                                                                        true,
                                                                  ),
                                                              child: Text(
                                                                l10n.cloudAccountCreateAccount,
                                                              ),
                                                            );
                                                        if (narrow) {
                                                          return Column(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .stretch,
                                                            children: [
                                                              signInBtn,
                                                              const SizedBox(
                                                                height: 10,
                                                              ),
                                                              registerBtn,
                                                            ],
                                                          );
                                                        }
                                                        return Row(
                                                          children: [
                                                            Expanded(
                                                              child: signInBtn,
                                                            ),
                                                            const SizedBox(
                                                              width: 12,
                                                            ),
                                                            Expanded(
                                                              child:
                                                                  registerBtn,
                                                            ),
                                                          ],
                                                        );
                                                      },
                                                    ),
                                                    const SizedBox(height: 8),
                                                    Center(
                                                      child: TextButton.icon(
                                                        onPressed:
                                                            _showCloudPasswordResetDialog,
                                                        icon: const Icon(
                                                          Icons
                                                              .mail_outline_rounded,
                                                          size: 20,
                                                        ),
                                                        label: Text(
                                                          l10n.cloudAccountForgotPassword,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          );
                                        }
                                        return Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            _SettingsSubsectionTitle(
                                              title: l10n
                                                  .folioCloudSubsectionAccount,
                                              scheme: scheme,
                                              topPadding: 8,
                                            ),
                                            const Divider(height: 1),
                                            accountCard,
                                          ],
                                        );
                                      },
                                    ),
                                    ListenableBuilder(
                                      listenable: Listenable.merge([
                                        _cloud,
                                        _folio,
                                      ]),
                                      builder: (context, _) {
                                        if (!AppSettings
                                            .folioWebPortalLinkEnabled) {
                                          return const SizedBox.shrink();
                                        }
                                        if (!_folio.isAvailable ||
                                            !_cloud.isSignedIn) {
                                          return const SizedBox.shrink();
                                        }
                                        final panelScheme = Theme.of(
                                          context,
                                        ).colorScheme;
                                        final panelL10n = AppLocalizations.of(
                                          context,
                                        );
                                        final webSnap =
                                            _folio.webPortalEntitlement;
                                        return Padding(
                                          padding: const EdgeInsets.fromLTRB(
                                            16,
                                            8,
                                            16,
                                            8,
                                          ),
                                          child: DecoratedBox(
                                            decoration: BoxDecoration(
                                              color: panelScheme
                                                  .surfaceContainerLow,
                                              borderRadius:
                                                  BorderRadius.circular(18),
                                              border: Border.all(
                                                color: panelScheme
                                                    .outlineVariant
                                                    .withValues(alpha: 0.4),
                                              ),
                                            ),
                                            child: Padding(
                                              padding: const EdgeInsets.all(18),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.stretch,
                                                children: [
                                                  Text(
                                                    panelL10n
                                                        .folioWebPortalSubsectionTitle,
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .titleSmall
                                                        ?.copyWith(
                                                          fontWeight:
                                                              FontWeight.w700,
                                                        ),
                                                  ),
                                                  const SizedBox(height: 6),
                                                  Text(
                                                    panelL10n
                                                        .folioWebMirrorNote,
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .bodySmall
                                                        ?.copyWith(
                                                          color: panelScheme
                                                              .onSurfaceVariant,
                                                          height: 1.35,
                                                        ),
                                                  ),
                                                  const SizedBox(height: 14),
                                                  Text(
                                                    panelL10n
                                                        .folioWebPortalLinkHelp,
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .bodySmall
                                                        ?.copyWith(
                                                          color: panelScheme
                                                              .onSurfaceVariant,
                                                          height: 1.35,
                                                        ),
                                                  ),
                                                  const SizedBox(height: 10),
                                                  TextField(
                                                    controller:
                                                        _webLinkCodeController,
                                                    decoration: InputDecoration(
                                                      labelText: panelL10n
                                                          .folioWebPortalLinkCodeLabel,
                                                      border:
                                                          const OutlineInputBorder(),
                                                    ),
                                                    textCapitalization:
                                                        TextCapitalization
                                                            .characters,
                                                    autocorrect: false,
                                                    enabled: !_webLinkBusy,
                                                  ),
                                                  const SizedBox(height: 12),
                                                  Row(
                                                    children: [
                                                      Expanded(
                                                        child: FilledButton(
                                                          onPressed:
                                                              _webLinkBusy
                                                              ? null
                                                              : _linkFolioWebPortalAccount,
                                                          child: _webLinkBusy
                                                              ? const SizedBox(
                                                                  height: 22,
                                                                  width: 22,
                                                                  child: CircularProgressIndicator(
                                                                    strokeWidth:
                                                                        2,
                                                                  ),
                                                                )
                                                              : Text(
                                                                  panelL10n
                                                                      .folioWebPortalLinkButton,
                                                                ),
                                                        ),
                                                      ),
                                                      IconButton(
                                                        tooltip: panelL10n
                                                            .folioWebPortalRefreshWeb,
                                                        onPressed:
                                                            _refreshFolioWebPortalEntitlement,
                                                        icon: const Icon(
                                                          Icons.refresh_rounded,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  if (_folio
                                                          .webPortalRefreshError !=
                                                      null) ...[
                                                    const SizedBox(height: 10),
                                                    Text(
                                                      _l10nFolioWebPortalError(
                                                        panelL10n,
                                                        _folio
                                                            .webPortalRefreshError!,
                                                      ),
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .bodySmall
                                                          ?.copyWith(
                                                            color: panelScheme
                                                                .error,
                                                          ),
                                                    ),
                                                  ],
                                                  if (webSnap != null) ...[
                                                    const SizedBox(height: 14),
                                                    Text(
                                                      webSnap.linked
                                                          ? panelL10n
                                                                .folioWebEntitlementLinked
                                                          : panelL10n
                                                                .folioWebEntitlementNotLinked,
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .bodyMedium
                                                          ?.copyWith(
                                                            fontWeight:
                                                                FontWeight.w600,
                                                          ),
                                                    ),
                                                    if (webSnap.folioCloud !=
                                                        null) ...[
                                                      const SizedBox(height: 6),
                                                      Text(
                                                        panelL10n.folioWebEntitlementWebPlan(
                                                          webSnap.folioCloud!
                                                              ? panelL10n
                                                                    .settingsLabelYes
                                                              : panelL10n
                                                                    .settingsLabelNo,
                                                        ),
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .bodySmall
                                                            ?.copyWith(
                                                              color: panelScheme
                                                                  .onSurfaceVariant,
                                                            ),
                                                      ),
                                                    ],
                                                    if (webSnap.folioCloudStatus !=
                                                            null &&
                                                        webSnap
                                                            .folioCloudStatus!
                                                            .isNotEmpty) ...[
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        panelL10n
                                                            .folioWebEntitlementWebStatus(
                                                              webSnap
                                                                  .folioCloudStatus!,
                                                            ),
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .bodySmall
                                                            ?.copyWith(
                                                              color: panelScheme
                                                                  .onSurfaceVariant,
                                                            ),
                                                      ),
                                                    ],
                                                    if (webSnap.folioCloudPeriodEnd !=
                                                            null &&
                                                        webSnap
                                                            .folioCloudPeriodEnd!
                                                            .isNotEmpty) ...[
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        panelL10n
                                                            .folioWebEntitlementWebPeriodEnd(
                                                              webSnap
                                                                  .folioCloudPeriodEnd!,
                                                            ),
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .bodySmall
                                                            ?.copyWith(
                                                              color: panelScheme
                                                                  .onSurfaceVariant,
                                                            ),
                                                      ),
                                                    ],
                                                    if (webSnap
                                                            .folioInkCredits !=
                                                        null) ...[
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        panelL10n
                                                            .folioWebEntitlementWebInk(
                                                              webSnap
                                                                  .folioInkCredits!,
                                                            ),
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .bodySmall
                                                            ?.copyWith(
                                                              color: panelScheme
                                                                  .onSurfaceVariant,
                                                            ),
                                                      ),
                                                    ],
                                                  ],
                                                ],
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                    ListenableBuilder(
                                      listenable: Listenable.merge([
                                        _cloud,
                                        _folio,
                                      ]),
                                      builder: (context, _) {
                                        if (!_folio.isAvailable) {
                                          return const SizedBox.shrink();
                                        }
                                        if (!_cloud.isSignedIn) {
                                          return _FolioCloudGuestPitchTeaser(
                                            scheme: scheme,
                                            l10n: l10n,
                                            onOpenPitch:
                                                _openFolioCloudSubscriptionPitch,
                                            onShowInkTable:
                                                _showCloudInkPricingTableDialog,
                                          );
                                        }
                                        return _FolioCloudSubscriptionPanel(
                                          scheme: scheme,
                                          l10n: l10n,
                                          snap: _folio.snapshot,
                                          busy: _folioCloudActionBusy,
                                          showMicrosoftStoreBillingNote: false,
                                          onSubscribeMonthly: () =>
                                              _openFolioCheckout(
                                                FolioCheckoutKind
                                                    .folioCloudMonthly,
                                              ),
                                          onOpenPitch:
                                              _openFolioCloudSubscriptionPitch,
                                          onInkSmall: () => _openFolioCheckout(
                                            FolioCheckoutKind.inkSmall,
                                          ),
                                          onInkMedium: () => _openFolioCheckout(
                                            FolioCheckoutKind.inkMedium,
                                          ),
                                          onInkLarge: () => _openFolioCheckout(
                                            FolioCheckoutKind.inkLarge,
                                          ),
                                          onBackupStoragePackSmall: () =>
                                              _openFolioCheckout(
                                                FolioCheckoutKind
                                                    .backupStoragePackSmall,
                                              ),
                                          onBackupStoragePackMedium: () =>
                                              _openFolioCheckout(
                                                FolioCheckoutKind
                                                    .backupStoragePackMedium,
                                              ),
                                          onBackupStoragePackLarge: () =>
                                              _openFolioCheckout(
                                                FolioCheckoutKind
                                                    .backupStoragePackLarge,
                                              ),
                                          onBillingPortal:
                                              _openFolioBillingPortal,
                                          onRefreshBilling:
                                              _syncFolioCloudBilling,
                                          onOpenBackups:
                                              _openFolioCloudBackupsDialog,
                                          onPublishedPages:
                                              _openPublishedPagesDialog,
                                          onSubscribeFamily: () =>
                                              _openFolioCheckout(
                                                FolioCheckoutKind
                                                    .folioFamilyMonthly,
                                              ),
                                          onSubscribeStudent: () =>
                                              _openFolioCheckout(
                                                FolioCheckoutKind
                                                    .folioStudentMonthly,
                                              ),
                                          onVerifyStudent: _verifyStudentStatus,
                                          onRemoveFamilyMember: _removeFamilyMember,
                                          onInviteFamilyMember: _inviteFamilyMember,
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          Visibility(
                            visible:
                                _selectedMobileSection ==
                                    _SettingsSectionId.vault,
                            maintainState: false,
                            child: KeyedSubtree(
                              key: const ValueKey(_SettingsSectionId.vault),
                              child: _SettingsPanel(
                                margin: const EdgeInsets.only(bottom: 24),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    _SettingsPanelHeroCard(
                                      icon: Icons.menu_book_outlined,
                                      title: l10n.settingsSectionVault,
                                      description: l10n
                                          .settingsSectionVaultHeroDescription,
                                      chips: [
                                        _SettingsInfoChip(
                                          icon: Icons.shield_outlined,
                                          label: l10n.security,
                                        ),
                                        _SettingsInfoChip(
                                          icon: Icons.backup_outlined,
                                          label: l10n.vaultBackup,
                                        ),
                                        _SettingsInfoChip(
                                          icon: Icons.storage_rounded,
                                          label: l10n.data,
                                        ),
                                      ],
                                    ),
                                    const Divider(height: 1),
                                    _SettingsSubsectionTitle(
                                      title: l10n.security,
                                      scheme: scheme,
                                      topPadding: 8,
                                    ),
                                    const Divider(height: 1),
                                    if (_s.vaultUsesEncryption) ...[
                                      ListTile(
                                        leading: const Icon(Icons.fingerprint),
                                        title: Text(l10n.quickUnlockTitle),
                                        subtitle: Text(
                                          _quickEnabled
                                              ? l10n.active
                                              : l10n.inactive,
                                        ),
                                        trailing: _quickEnabled
                                            ? TextButton(
                                                onPressed: () async {
                                                  await _s.disableQuickUnlock();
                                                  await _refreshSecurityFlags();
                                                  _snack(
                                                    l10n.quickUnlockDisabledSnack,
                                                  );
                                                },
                                                child: Text(l10n.remove),
                                              )
                                            : FilledButton.tonal(
                                                onPressed: () async {
                                                  try {
                                                    await _s
                                                        .enableDeviceQuickUnlock();
                                                    await _refreshSecurityFlags();
                                                    _snack(
                                                      l10n.quickUnlockEnabledSnack,
                                                    );
                                                  } catch (e) {
                                                    _snack(
                                                      '${l10n.quickUnlockEnableFailed} $e',
                                                    );
                                                  }
                                                },
                                                child: Text(l10n.enable),
                                              ),
                                      ),
                                      const Divider(height: 1),
                                      ListTile(
                                        leading: const Icon(Icons.key_rounded),
                                        title: Text(l10n.passkey),
                                        subtitle: Text(l10n.passkeyThisDevice),
                                        trailing: _passkeyRegistered
                                            ? TextButton(
                                                onPressed: () async {
                                                  final ok = await showDialog<bool>(
                                                    context: context,
                                                    builder: (ctx) => AlertDialog(
                                                      title: Text(
                                                        l10n.passkeyRevokeConfirmTitle,
                                                      ),
                                                      content: Text(
                                                        l10n.passkeyRevokeConfirmBody,
                                                      ),
                                                      actions: [
                                                        TextButton(
                                                          onPressed: () =>
                                                              Navigator.of(
                                                                ctx,
                                                              ).pop(false),
                                                          child: Text(
                                                            AppLocalizations.of(
                                                              ctx,
                                                            ).cancel,
                                                          ),
                                                        ),
                                                        FilledButton(
                                                          onPressed: () =>
                                                              Navigator.of(
                                                                ctx,
                                                              ).pop(true),
                                                          child: Text(
                                                            l10n.revoke,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                  if (ok != true || !mounted) {
                                                    return;
                                                  }
                                                  await _s.revokePasskey();
                                                  await _refreshSecurityFlags();
                                                  if (!mounted) return;
                                                  _snack(
                                                    l10n.passkeyRevokedSnack,
                                                  );
                                                },
                                                child: Text(l10n.revoke),
                                              )
                                            : FilledButton.tonal(
                                                onPressed: () async {
                                                  try {
                                                    await _s.registerPasskey();
                                                    await _refreshSecurityFlags();
                                                    _snack(
                                                      l10n.passkeyRegisteredSnack,
                                                    );
                                                  } on PasskeyAuthCancelledException {
                                                    // ignorar
                                                  } catch (e) {
                                                    _snack('$e');
                                                  }
                                                },
                                                child: Text(l10n.register),
                                              ),
                                      ),
                                      const Divider(height: 1),
                                      ListTile(
                                        leading: const Icon(Icons.lock_outline),
                                        title: Text(l10n.lockNow),
                                        onTap: () async {
                                          await _s.lock();
                                          if (context.mounted) {
                                            Navigator.pop(context);
                                          }
                                        },
                                      ),
                                      const Divider(height: 1),
                                      ListTile(
                                        leading: const Icon(
                                          Icons.timer_outlined,
                                        ),
                                        title: Text(l10n.lockAutoByInactivity),
                                        subtitle: Text(
                                          l10n.minutesShort(
                                            _app.vaultIdleLockMinutes,
                                          ),
                                        ),
                                        trailing: DropdownButton<int>(
                                          value: _app.vaultIdleLockMinutes,
                                          underline: const SizedBox.shrink(),
                                          onChanged: (value) {
                                            if (value == null) return;
                                            _app.setVaultIdleLockMinutes(value);
                                          },
                                          items: _idleOptions
                                              .map(
                                                (m) => DropdownMenuItem<int>(
                                                  value: m,
                                                  child: Text(
                                                    l10n.minutesShort(m),
                                                  ),
                                                ),
                                              )
                                              .toList(),
                                        ),
                                      ),
                                      const Divider(height: 1),
                                      SwitchListTile(
                                        secondary: const Icon(
                                          Icons.minimize_rounded,
                                        ),
                                        title: Text(l10n.lockOnMinimize),
                                        value: _app.vaultLockOnMinimize,
                                        onChanged: _app.setVaultLockOnMinimize,
                                      ),
                                      const Divider(height: 1),
                                      ListTile(
                                        leading: const Icon(
                                          Icons.password_rounded,
                                        ),
                                        title: Text(l10n.changeMasterPassword),
                                        subtitle: Text(
                                          l10n.requiresCurrentPassword,
                                        ),
                                        onTap: _openChangeMasterPasswordFlow,
                                      ),
                                    ] else ...[
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                          20,
                                          0,
                                          20,
                                          20,
                                        ),
                                        child: FilledButton.icon(
                                          onPressed: () =>
                                              _openEncryptPlainVaultDialog(),
                                          icon: const Icon(
                                            Icons.lock_rounded,
                                            size: 20,
                                          ),
                                          label: Text(
                                            l10n.encryptPlainVaultConfirm,
                                          ),
                                        ),
                                      ),
                                    ],
                                    const Divider(height: 1),
                                    _SettingsSubsectionTitle(
                                      title: l10n
                                          .settingsSubsectionVaultBackupImport,
                                      scheme: scheme,
                                      topPadding: 8,
                                    ),
                                    const Divider(height: 1),
                                    if (_s.state == VaultFlowState.unlocked)
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                          16,
                                          12,
                                          16,
                                          4,
                                        ),
                                        child: FutureBuilder<String>(
                                          key: ValueKey(_s.activeVaultId),
                                          future: _s
                                              .getActiveVaultDisplayLabel(),
                                          builder: (ctx, snap) {
                                            if (!snap.hasData) {
                                              return const SizedBox.shrink();
                                            }
                                            return Text(
                                              l10n.vaultBackupOpenVaultHint(
                                                snap.data!,
                                              ),
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.copyWith(
                                                    color:
                                                        scheme.onSurfaceVariant,
                                                    height: 1.35,
                                                  ),
                                            );
                                          },
                                        ),
                                      ),
                                    if (_s.state == VaultFlowState.unlocked)
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                          16,
                                          0,
                                          16,
                                          8,
                                        ),
                                        child: FutureBuilder<int>(
                                          key: ValueKey(_s.activeVaultId),
                                          future:
                                              _loadActiveVaultDiskUsageBytes(),
                                          builder: (ctx, diskSnap) {
                                            final small = Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  color:
                                                      scheme.onSurfaceVariant,
                                                  height: 1.35,
                                                );
                                            if (diskSnap.connectionState ==
                                                ConnectionState.waiting) {
                                              return Text(
                                                l10n.vaultBackupDiskSizeLoading,
                                                style: small,
                                              );
                                            }
                                            if (diskSnap.hasError ||
                                                !diskSnap.hasData) {
                                              return const SizedBox.shrink();
                                            }
                                            return Text(
                                              l10n.vaultBackupDiskSizeApprox(
                                                _formatByteSize(diskSnap.data!),
                                              ),
                                              style: small,
                                            );
                                          },
                                        ),
                                      ),
                                    ListTile(
                                      leading: const Icon(
                                        Icons.file_download_outlined,
                                      ),
                                      title: Text(l10n.exportZipTitle),
                                      subtitle: Text(l10n.exportZipSubtitle),
                                      onTap: _s.state == VaultFlowState.unlocked
                                          ? _openExportBackupFlow
                                          : null,
                                    ),
                                    const Divider(height: 1),
                                    ListTile(
                                      leading: const Icon(
                                        Icons.file_upload_outlined,
                                      ),
                                      title: Text(l10n.importZipTitle),
                                      subtitle: Text(l10n.importZipSubtitle),
                                      onTap: _s.state == VaultFlowState.unlocked
                                          ? _openImportBackupFlow
                                          : null,
                                    ),
                                    const Divider(height: 1),
                                    ListTile(
                                      leading: const Icon(
                                        Icons.note_add_outlined,
                                      ),
                                      title: Text(l10n.importNotionTitle),
                                      subtitle: Text(l10n.importNotionSubtitle),
                                      onTap: _s.state == VaultFlowState.unlocked
                                          ? _openImportNotionFlow
                                          : null,
                                    ),
                                    const Divider(height: 1),
                                    Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            l10n.notionExportGuideTitle,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleSmall
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            l10n.notionExportGuideBody,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  color:
                                                      scheme.onSurfaceVariant,
                                                  height: 1.4,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Divider(height: 1),
                                    _SettingsSubsectionTitle(
                                      title: l10n
                                          .settingsSubsectionVaultScheduledLocal,
                                      scheme: scheme,
                                      topPadding: 8,
                                    ),
                                    const Divider(height: 1),
                                    SwitchListTile(
                                      secondary: const Icon(
                                        Icons.schedule_rounded,
                                      ),
                                      title: Text(
                                        l10n.scheduledVaultBackupTitle,
                                      ),
                                      subtitle: Text(
                                        l10n.scheduledVaultBackupSubtitle,
                                      ),
                                      value: _vaultBackupPrefs.enabled,
                                      onChanged:
                                          _s.state == VaultFlowState.unlocked
                                          ? (v) async {
                                              await _app.setVaultBackupEnabled(
                                                _vaultId,
                                                v,
                                              );
                                              await _loadVaultBackupPrefs();
                                            }
                                          : null,
                                    ),
                                    const Divider(height: 1),
                                    _SettingsSubsectionTitle(
                                      title: l10n.remoteBackupConfigTitle,
                                      scheme: scheme,
                                      topPadding: 4,
                                    ),
                                    ListTile(
                                      leading: const Icon(
                                        Icons.lan_outlined,
                                      ),
                                      title: Text(
                                        l10n.remoteBackupConfigureFolder,
                                      ),
                                      subtitle: Text(
                                        _vaultBackupPrefs.directory.isEmpty
                                            ? '—'
                                            : _vaultBackupPrefs.directory,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      onTap:
                                          _s.state == VaultFlowState.unlocked
                                          ? () => _openRemoteBackupConfig(
                                              initialTab: 0,
                                            )
                                          : null,
                                    ),
                                    ListTile(
                                      leading: const Icon(
                                        Icons.cloud_outlined,
                                      ),
                                      title: Text(
                                        l10n.remoteBackupConfigureWebdav,
                                      ),
                                      subtitle: Text(
                                        _vaultBackupPrefs.webdavBaseUrl.isEmpty
                                            ? '—'
                                            : _vaultBackupPrefs.webdavBaseUrl,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      onTap:
                                          _s.state == VaultFlowState.unlocked
                                          ? () => _openRemoteBackupConfig(
                                              initialTab: 1,
                                            )
                                          : null,
                                    ),
                                    ListTile(
                                      leading: const Icon(
                                        Icons.restore_outlined,
                                      ),
                                      title: Text(l10n.remoteBackupRestoreOpen),
                                      subtitle: Text(
                                        l10n.remoteBackupRestoreTitle,
                                      ),
                                      onTap: _s.state == VaultFlowState.unlocked
                                          ? _openRemoteBackupRestore
                                          : null,
                                    ),
                                    if (_vaultBackupPrefs.enabled) ...[
                                      ListTile(
                                        isThreeLine: true,
                                        leading: const Icon(
                                          Icons.timer_outlined,
                                        ),
                                        title: Text(
                                          l10n.scheduledVaultBackupIntervalLabel,
                                        ),
                                        subtitle: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const SizedBox(height: 4),
                                            Text(
                                              _scheduledVaultBackupIntervalSummary(
                                                l10n,
                                                _vaultBackupPrefs
                                                    .intervalMinutes,
                                              ),
                                            ),
                                            SliderTheme(
                                              data: SliderTheme.of(
                                                context,
                                              ).copyWith(trackHeight: 3),
                                              child: Slider(
                                                min: 0,
                                                max:
                                                    (AppSettings
                                                                .scheduledVaultBackupIntervalChoicesMinutes
                                                                .length -
                                                            1)
                                                        .toDouble(),
                                                divisions:
                                                    AppSettings
                                                        .scheduledVaultBackupIntervalChoicesMinutes
                                                        .length -
                                                    1,
                                                value:
                                                    AppSettings.vaultBackupIntervalChoiceIndex(
                                                      _vaultBackupPrefs
                                                          .intervalMinutes,
                                                    ).toDouble(),
                                                onChanged:
                                                    _s.state ==
                                                        VaultFlowState.unlocked
                                                    ? (v) async {
                                                        final i = v.round().clamp(
                                                          0,
                                                          AppSettings
                                                                  .scheduledVaultBackupIntervalChoicesMinutes
                                                                  .length -
                                                              1,
                                                        );
                                                        final minutes = AppSettings
                                                            .scheduledVaultBackupIntervalChoicesMinutes[i];
                                                        await _app
                                                            .setVaultBackupIntervalMinutes(
                                                              _vaultId,
                                                              minutes,
                                                            );
                                                        await _loadVaultBackupPrefs();
                                                      }
                                                    : null,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // — Backup a carpeta —
                                      const Divider(height: 1),
                                      SwitchListTile(
                                        secondary: const Icon(
                                          Icons.folder_open_outlined,
                                        ),
                                        title: Text(
                                          l10n.scheduledVaultBackupFolderTitle,
                                        ),
                                        subtitle: Text(
                                          l10n.scheduledVaultBackupFolderSubtitle,
                                        ),
                                        value: _vaultBackupPrefs.folderEnabled,
                                        onChanged:
                                            _s.state == VaultFlowState.unlocked
                                            ? (v) async {
                                                await _app
                                                    .setVaultBackupFolderEnabled(
                                                      _vaultId,
                                                      v,
                                                    );
                                                await _loadVaultBackupPrefs();
                                              }
                                            : null,
                                      ),
                                      if (_vaultBackupPrefs.folderEnabled) ...[
                                        ListTile(
                                          leading: const Icon(
                                            Icons.folder_rounded,
                                          ),
                                          title: Text(
                                            l10n.scheduledVaultBackupChooseFolder,
                                          ),
                                          subtitle: Text(
                                            _vaultBackupPrefs.directory.isEmpty
                                                ? '—'
                                                : _vaultBackupPrefs.directory,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          trailing:
                                              _vaultBackupPrefs
                                                  .directory
                                                  .isEmpty
                                              ? null
                                              : IconButton(
                                                  tooltip: l10n
                                                      .scheduledVaultBackupClearFolderTooltip,
                                                  icon: const Icon(
                                                    Icons.close_rounded,
                                                  ),
                                                  onPressed:
                                                      _s.state ==
                                                          VaultFlowState
                                                              .unlocked
                                                      ? () async {
                                                          await _app
                                                              .setVaultBackupDirectory(
                                                                _vaultId,
                                                                '',
                                                              );
                                                          await _loadVaultBackupPrefs();
                                                        }
                                                      : null,
                                                ),
                                          onTap:
                                              _s.state ==
                                                  VaultFlowState.unlocked
                                              ? _pickScheduledVaultBackupFolder
                                              : null,
                                        ),
                                        ListTile(
                                          leading: const Icon(
                                            Icons.edit_road_outlined,
                                          ),
                                          title: Text(
                                            l10n.remoteBackupEnterNetworkPath,
                                          ),
                                          onTap:
                                              _s.state ==
                                                  VaultFlowState.unlocked
                                              ? _enterNetworkBackupPath
                                              : null,
                                        ),
                                        ListTile(
                                          leading: const Icon(
                                            Icons.history_rounded,
                                          ),
                                          title: Text(
                                            l10n.scheduledVaultBackupLastRun(
                                              _formatScheduledBackupTime(
                                                _vaultBackupPrefs.lastMs,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                      // — Backup WebDAV —
                                      const Divider(height: 1),
                                      SwitchListTile(
                                        secondary: const Icon(
                                          Icons.cloud_outlined,
                                        ),
                                        title: Text(
                                          l10n.remoteBackupWebdavTitle,
                                        ),
                                        subtitle: Text(
                                          l10n.remoteBackupWebdavSubtitle,
                                        ),
                                        value: _vaultBackupPrefs.webdavEnabled,
                                        onChanged:
                                            _s.state == VaultFlowState.unlocked
                                            ? (v) async {
                                                await _app
                                                    .setVaultBackupWebdavEnabled(
                                                      _vaultId,
                                                      v,
                                                    );
                                                await _loadVaultBackupPrefs();
                                              }
                                            : null,
                                      ),
                                      if (_vaultBackupPrefs.webdavEnabled &&
                                          _vaultBackupPrefs
                                              .webdavBaseUrl
                                              .isNotEmpty) ...[
                                        ListTile(
                                          leading: const Icon(
                                            Icons.link_outlined,
                                          ),
                                          title: Text(
                                            l10n.remoteBackupWebdavUrlLabel,
                                          ),
                                          subtitle: Text(
                                            _vaultBackupPrefs.webdavBaseUrl,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                      // — Backup en la nube —
                                      ListenableBuilder(
                                        listenable: Listenable.merge([
                                          _cloud,
                                          _folio,
                                          _app,
                                          _s,
                                        ]),
                                        builder: (context, _) {
                                          if (!_folio.isAvailable ||
                                              !_cloud.isSignedIn) {
                                            return const SizedBox.shrink();
                                          }
                                          return Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.stretch,
                                            children: [
                                              const Divider(height: 1),
                                              SwitchListTile(
                                                secondary: const Icon(
                                                  Icons.cloud_upload_outlined,
                                                ),
                                                title: Text(
                                                  l10n.scheduledVaultBackupCloudSyncTitle,
                                                ),
                                                subtitle: Text(
                                                  l10n.scheduledVaultBackupCloudSyncSubtitle,
                                                ),
                                                value:
                                                    _vaultBackupPrefs.alsoCloud,
                                                onChanged:
                                                    _s.state ==
                                                            VaultFlowState
                                                                .unlocked &&
                                                        !_folioCloudActionBusy
                                                    ? (v) {
                                                        unawaited(
                                                          _app
                                                              .setVaultBackupAlsoCloud(
                                                                _vaultId,
                                                                v,
                                                              )
                                                              .then((_) async {
                                                                await _loadVaultBackupPrefs();
                                                              }),
                                                        );
                                                      }
                                                    : null,
                                              ),
                                            ],
                                          );
                                        },
                                      ),
                                    ],
                                    if (_vaultBackupPrefs.enabled)
                                      ListTile(
                                        leading: const Icon(
                                          Icons.save_alt_rounded,
                                        ),
                                        title: Text(l10n.vaultBackupRunNowTile),
                                        subtitle: Text(
                                          l10n.vaultBackupRunNowSubtitle,
                                        ),
                                        onTap:
                                            _s.state == VaultFlowState.unlocked
                                            ? _runBackupNowToScheduledFolder
                                            : null,
                                      ),
                                    const Divider(height: 1),
                                    _SettingsSubsectionTitle(
                                      title: l10n.settingsSubsectionDrive,
                                      scheme: scheme,
                                      topPadding: 8,
                                    ),
                                    const Divider(height: 1),
                                    SwitchListTile(
                                      secondary: const Icon(
                                        Icons.folder_copy_rounded,
                                      ),
                                      title: Text(
                                        l10n.driveDeleteOriginalsTitle,
                                      ),
                                      subtitle: Text(
                                        l10n.driveDeleteOriginalsSubtitle,
                                      ),
                                      value: _app.driveDeleteOriginalsOnUpload,
                                      onChanged:
                                          _app.setDriveDeleteOriginalsOnUpload,
                                    ),
                                    const Divider(height: 1),
                                    _SettingsSubsectionTitle(
                                      title: l10n.settingsSubsectionVaultData,
                                      scheme: scheme,
                                      topPadding: 8,
                                    ),
                                    const Divider(height: 1),
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        16,
                                        0,
                                        16,
                                        8,
                                      ),
                                      child: Card(
                                        color: scheme.errorContainer.withValues(
                                          alpha: 0.2,
                                        ),
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          side: BorderSide(
                                            color: scheme.error.withValues(
                                              alpha: 0.5,
                                            ),
                                          ),
                                          borderRadius: const BorderRadius.all(
                                            Radius.circular(20),
                                          ),
                                        ),
                                        child: ListTile(
                                          leading: Icon(
                                            Icons.delete_forever_outlined,
                                            color: scheme.error,
                                          ),
                                          title: Text(
                                            l10n.wipeCardTitle,
                                            style: TextStyle(
                                              color: scheme.error,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          subtitle: Text(
                                            l10n.wipeCardSubtitle,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  color: scheme.error
                                                      .withValues(alpha: 0.8),
                                                ),
                                          ),
                                          onTap: _openWipeFlow,
                                        ),
                                      ),
                                    ),
                                    const Divider(height: 1),
                                    ListTile(
                                      leading: const Icon(Icons.delete_outline),
                                      title: Text(l10n.deleteOtherVault),
                                      subtitle: Text(
                                        l10n.deleteOtherVaultTitle,
                                      ),
                                      onTap: _deleteOtherVault,
                                    ),
                                    if (_s.isUnlocked) ...[
                                      const Divider(height: 1),
                                      _SettingsSubsectionTitle(
                                        title: l10n.tasksCaptureSettingsSection,
                                        scheme: scheme,
                                        topPadding: 8,
                                      ),
                                      const Divider(height: 1),
                                      ListTile(
                                        leading: const Icon(
                                          Icons.inbox_rounded,
                                        ),
                                        title: Text(l10n.taskInboxPageTitle),
                                        subtitle: Text(
                                          l10n.taskInboxPageSubtitle,
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                          16,
                                          0,
                                          16,
                                          8,
                                        ),
                                        child: DropdownButtonFormField<String?>(
                                          // ignore: deprecated_member_use
                                          value:
                                              _taskInboxPageIdLoaded != null &&
                                                  _s.pages.any(
                                                    (p) =>
                                                        p.id ==
                                                        _taskInboxPageIdLoaded,
                                                  )
                                              ? _taskInboxPageIdLoaded
                                              : null,
                                          decoration: InputDecoration(
                                            labelText: l10n.taskInboxPageTitle,
                                            border: const OutlineInputBorder(),
                                          ),
                                          items: [
                                            DropdownMenuItem<String?>(
                                              value: null,
                                              child: Text(l10n.taskInboxNone),
                                            ),
                                            ..._s.pages.map(
                                              (p) => DropdownMenuItem<String?>(
                                                value: p.id,
                                                child: Text(
                                                  p.title.trim().isEmpty
                                                      ? l10n.untitledFallback
                                                      : p.title,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ),
                                          ],
                                          onChanged: (v) async {
                                            await _app.setTaskInboxPageId(
                                              _s.activeVaultId,
                                              v,
                                            );
                                            if (mounted) {
                                              setState(
                                                () =>
                                                    _taskInboxPageIdLoaded = v,
                                              );
                                            }
                                          },
                                        ),
                                      ),
                                      ListTile(
                                        leading: const Icon(Icons.tag_rounded),
                                        title: Text(l10n.taskAliasManageTitle),
                                        subtitle: Text(
                                          l10n.taskAliasManageSubtitle,
                                        ),
                                        trailing: TextButton(
                                          onPressed: _addTaskAliasDialog,
                                          child: Text(l10n.taskAliasAddButton),
                                        ),
                                      ),
                                      if (_taskAliasesLoaded.isNotEmpty)
                                        ..._taskAliasesLoaded.entries.map((e) {
                                          final matches = _s.pages
                                              .where((x) => x.id == e.value)
                                              .toList();
                                          final p = matches.isEmpty
                                              ? null
                                              : matches.first;
                                          final pageLabel = p == null
                                              ? e.value
                                              : (p.title.trim().isEmpty
                                                    ? l10n.untitledFallback
                                                    : p.title);
                                          return ListTile(
                                            title: Text('#${e.key}'),
                                            subtitle: Text(pageLabel),
                                            trailing: IconButton(
                                              tooltip:
                                                  l10n.taskAliasDeleteTooltip,
                                              icon: const Icon(
                                                Icons.delete_outline,
                                              ),
                                              onPressed: () =>
                                                  _removeTaskAlias(e.key),
                                            ),
                                          );
                                        }),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),

                          Visibility(
                            visible:
                                _selectedMobileSection ==
                                    _SettingsSectionId.uiWorkspace,
                            maintainState: false,
                            child: KeyedSubtree(
                              key: const ValueKey(_SettingsSectionId.uiWorkspace),
                              child: _SettingsPanel(
                                margin: const EdgeInsets.only(bottom: 24),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    _SettingsPanelHeroCard(
                                      icon: Icons.tune_rounded,
                                      title: l10n.settingsSectionUiWorkspace,
                                      description: l10n
                                          .settingsSectionUiWorkspaceHeroDescription,
                                      chips: [
                                        _SettingsInfoChip(
                                          icon: Icons.palette_outlined,
                                          label: l10n.appearance,
                                        ),
                                        if (showDesktopOnlySections) ...[
                                          _SettingsInfoChip(
                                            icon: Icons.desktop_windows_rounded,
                                            label: l10n.desktopSection,
                                          ),
                                          _SettingsInfoChip(
                                            icon: Icons.keyboard_rounded,
                                            label:
                                                l10n.keyboardShortcutsSection,
                                          ),
                                        ],
                                      ],
                                    ),
                                    const Divider(height: 1),
                                    _SettingsSubsectionTitle(
                                      title: l10n.appearance,
                                      scheme: scheme,
                                      topPadding: 8,
                                    ),
                                    const Divider(height: 1),
                                    _SettingsPanelHeroCard(
                                      icon: Icons.palette_outlined,
                                      title: l10n.appearance,
                                      description: l10n.settingsAppearanceHint,
                                      chips: [
                                        _SettingsInfoChip(
                                          icon: Icons.brightness_auto,
                                          label:
                                              l10n.settingsAppearanceChipTheme,
                                        ),
                                        _SettingsInfoChip(
                                          icon: Icons.zoom_in_rounded,
                                          label:
                                              l10n.settingsAppearanceChipZoom,
                                        ),
                                        _SettingsInfoChip(
                                          icon: Icons.translate_rounded,
                                          label: l10n
                                              .settingsAppearanceChipLanguage,
                                        ),
                                        _SettingsInfoChip(
                                          icon: Icons.edit_outlined,
                                          label: l10n
                                              .settingsAppearanceChipEditorWorkspace,
                                        ),
                                      ],
                                    ),
                                    const Divider(height: 1),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                      ),
                                      child: SegmentedButton<ThemeMode>(
                                        segments: [
                                          ButtonSegment<ThemeMode>(
                                            value: ThemeMode.system,
                                            label: Text(l10n.systemTheme),
                                            icon: const Icon(
                                              Icons.brightness_auto,
                                              size: 18,
                                            ),
                                          ),
                                          ButtonSegment<ThemeMode>(
                                            value: ThemeMode.light,
                                            label: Text(l10n.lightTheme),
                                            icon: const Icon(
                                              Icons.light_mode_outlined,
                                              size: 18,
                                            ),
                                          ),
                                          ButtonSegment<ThemeMode>(
                                            value: ThemeMode.dark,
                                            label: Text(l10n.darkTheme),
                                            icon: const Icon(
                                              Icons.dark_mode_outlined,
                                              size: 18,
                                            ),
                                          ),
                                        ],
                                        selected: {_app.themeMode},
                                        onSelectionChanged: (s) {
                                          _app.setThemeMode(s.first);
                                        },
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                      ),
                                      child: Card(
                                        child: SwitchListTile(
                                          title: Text(
                                            l10n.settingsOledThemeTitle,
                                          ),
                                          subtitle: Text(
                                            l10n.settingsOledThemeBody,
                                          ),
                                          value: _app.oledThemeEnabled,
                                          onChanged: (value) {
                                            _app.setOledThemeEnabled(value);
                                          },
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      l10n.settingsAccentColorTitle,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleSmall,
                                    ),
                                    const SizedBox(height: 8),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                      ),
                                      child: SegmentedButton<FolioAccentColorMode>(
                                        segments: [
                                          ButtonSegment<FolioAccentColorMode>(
                                            value: FolioAccentColorMode
                                                .followSystem,
                                            label: Text(
                                              l10n.settingsAccentFollowSystem,
                                            ),
                                            icon: const Icon(
                                              Icons.palette_outlined,
                                              size: 18,
                                            ),
                                          ),
                                          ButtonSegment<FolioAccentColorMode>(
                                            value: FolioAccentColorMode
                                                .folioDefault,
                                            label: Text(
                                              l10n.settingsAccentFolioDefault,
                                            ),
                                            icon: const Icon(
                                              Icons.brush_outlined,
                                              size: 18,
                                            ),
                                          ),
                                          ButtonSegment<FolioAccentColorMode>(
                                            value: FolioAccentColorMode.custom,
                                            label: Text(
                                              l10n.settingsAccentCustom,
                                            ),
                                            icon: const Icon(
                                              Icons.color_lens_outlined,
                                              size: 18,
                                            ),
                                          ),
                                        ],
                                        selected: {_app.accentColorMode},
                                        onSelectionChanged: (s) {
                                          _app.setAccentColorMode(s.first);
                                        },
                                      ),
                                    ),
                                    if (_app.accentColorMode ==
                                        FolioAccentColorMode.custom) ...[
                                      const SizedBox(height: 8),
                                      ListTile(
                                        leading: Icon(
                                          Icons.color_lens,
                                          color: Color(_app.customAccentArgb),
                                        ),
                                        title: Text(
                                          l10n.settingsAccentPickColor,
                                        ),
                                        trailing: const Icon(
                                          Icons.chevron_right,
                                        ),
                                        onTap: () async {
                                          const presets = <int>[
                                            0xFF455A64,
                                            0xFF1565C0,
                                            0xFF0277BD,
                                            0xFF6A1B9A,
                                            0xFFAD1457,
                                            0xFF2E7D32,
                                            0xFF558B2F,
                                            0xFFBF360C,
                                            0xFF00695C,
                                            0xFF283593,
                                            0xFF4E342E,
                                            0xFF37474F,
                                          ];
                                          final picked = await showDialog<int>(
                                            context: context,
                                            builder: (ctx) {
                                              return AlertDialog(
                                                title: Text(
                                                  l10n.settingsAccentPickColor,
                                                ),
                                                content: Wrap(
                                                  spacing: 10,
                                                  runSpacing: 10,
                                                  children: [
                                                    for (final a in presets)
                                                      Material(
                                                        color: Color(a),
                                                        elevation: 2,
                                                        shape:
                                                            const CircleBorder(),
                                                        child: InkWell(
                                                          customBorder:
                                                              const CircleBorder(),
                                                          onTap: () =>
                                                              Navigator.pop(
                                                                ctx,
                                                                a,
                                                              ),
                                                          child: const SizedBox(
                                                            width: 44,
                                                            height: 44,
                                                          ),
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(ctx),
                                                    child: Text(l10n.cancel),
                                                  ),
                                                ],
                                              );
                                            },
                                          );
                                          if (picked != null && mounted) {
                                            await _app.setCustomAccentArgb(
                                              picked,
                                            );
                                          }
                                        },
                                      ),
                                    ],
                                    const SizedBox(height: 12),
                                    const Divider(height: 1),
                                    _SettingsSubsectionTitle(
                                      title: l10n.settingsPrivacySectionTitle,
                                      scheme: scheme,
                                      topPadding: 8,
                                    ),
                                    const Divider(height: 1),
                                    SwitchListTile(
                                      secondary: const Icon(
                                        Icons.analytics_outlined,
                                      ),
                                      title: Text(l10n.settingsTelemetryTitle),
                                      subtitle: Text(
                                        l10n.settingsTelemetrySubtitle,
                                      ),
                                      value: _app.telemetryEnabled,
                                      onChanged: (v) =>
                                          _app.setTelemetryEnabled(v),
                                    ),
                                    const TelemetrySentDataWidget(),
                                    // Botón de Dashboard solo si es staff
                                    if (_folio.snapshot.folioStaff)
                                      ListTile(
                                        leading: const Icon(
                                          Icons.dashboard_outlined,
                                        ),
                                        title: Text(
                                          l10n.telemetryDashboardTitle,
                                        ),
                                        subtitle: Text(
                                          l10n.settingsTelemetryDashboardListSubtitle,
                                        ),
                                        trailing: const Icon(
                                          Icons.arrow_forward_ios,
                                          size: 16,
                                        ),
                                        onTap: () async {
                                          await FolioFirestoreSync.flush();
                                          if (!context.mounted) return;
                                          Navigator.of(context).push(
                                            MaterialPageRoute<void>(
                                              settings: const RouteSettings(
                                                name: 'telemetry_dashboard',
                                              ),
                                              builder: (context) =>
                                                  TelemetryDashboardPage(
                                                    folioCloudSnapshot:
                                                        _folio.snapshot,
                                                  ),
                                            ),
                                          );
                                        },
                                      ),
                                    const Divider(height: 1),
                                    SwitchListTile(
                                      secondary: const Icon(
                                        Icons.bug_report_outlined,
                                      ),
                                      title: Text(
                                        l10n.settingsAutoCrashReportsTitle,
                                      ),
                                      subtitle: Text(
                                        l10n.settingsAutoCrashReportsSubtitle,
                                      ),
                                      value: _app.autoCrashReports,
                                      onChanged: (v) =>
                                          _app.setAutoCrashReports(v),
                                    ),
                                    const Divider(height: 1),
                                    ListTile(
                                      leading: const Icon(Icons.mail_outline),
                                      title: Text(l10n.settingsReportBugButton),
                                      subtitle: Text(
                                        l10n.settingsPrivacyFootnote,
                                      ),
                                      onTap: _reportBugFlow,
                                    ),
                                    const Divider(height: 1),
                                    SwitchListTile(
                                      secondary: const Icon(
                                        Icons.desktop_windows,
                                      ),
                                      title: Text(
                                        l10n.settingsWindowsScaleFollowTitle,
                                      ),
                                      subtitle: Text(
                                        l10n.settingsWindowsScaleFollowSubtitle,
                                      ),
                                      value:
                                          _app.uiScaleMode ==
                                          UiScaleMode.followWindows,
                                      onChanged:
                                          !kIsWeb &&
                                              defaultTargetPlatform ==
                                                  TargetPlatform.windows
                                          ? (value) {
                                              _app.setUiScaleMode(
                                                value
                                                    ? UiScaleMode.followWindows
                                                    : UiScaleMode.manual,
                                              );
                                            }
                                          : null,
                                    ),
                                    const Divider(height: 1),
                                    ListTile(
                                      leading: const Icon(
                                        Icons.zoom_in_rounded,
                                      ),
                                      title: Text(
                                        l10n.settingsInterfaceZoomTitle,
                                      ),
                                      subtitle: Text(
                                        l10n.settingsInterfaceZoomSubtitle,
                                      ),
                                      enabled:
                                          _app.uiScaleMode ==
                                          UiScaleMode.manual,
                                      trailing: Text(
                                        '${((_app.uiScaleMode == UiScaleMode.followWindows ? MediaQuery.of(context).devicePixelRatio : _app.uiScale) * 100).round()}%',
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelLarge
                                            ?.copyWith(
                                              color: scheme.onSurfaceVariant,
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        16,
                                        0,
                                        16,
                                        8,
                                      ),
                                      child: Slider(
                                        value: _app.uiScale,
                                        min: AppSettings.minUiScale,
                                        max: AppSettings.maxUiScale,
                                        divisions:
                                            ((AppSettings.maxUiScale -
                                                        AppSettings
                                                            .minUiScale) /
                                                    0.05)
                                                .round(),
                                        label:
                                            '${(_app.uiScale * 100).round()}%',
                                        onChangeStart: (_) {
                                          if (_app.uiScaleMode ==
                                              UiScaleMode.followWindows) {
                                            _app.setUiScaleMode(
                                              UiScaleMode.manual,
                                            );
                                          }
                                        },
                                        onChanged:
                                            _app.uiScaleMode ==
                                                UiScaleMode.manual
                                            ? (value) {
                                                _app.setUiScale(value);
                                              }
                                            : null,
                                      ),
                                    ),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: Padding(
                                        padding: const EdgeInsets.only(
                                          right: 16,
                                          bottom: 8,
                                        ),
                                        child: TextButton.icon(
                                          onPressed: () async {
                                            await _app.setUiScaleMode(
                                              UiScaleMode.manual,
                                            );
                                            await _app.setUiScale(
                                              AppSettings.defaultUiScale,
                                            );
                                          },
                                          icon: const Icon(
                                            Icons.refresh_rounded,
                                          ),
                                          label: Text(l10n.settingsUiZoomReset),
                                        ),
                                      ),
                                    ),
                                    const Divider(height: 1),
                                    ListTile(
                                      leading: const Icon(
                                        Icons.translate_rounded,
                                      ),
                                      title: Text(l10n.language),
                                      subtitle: Text(
                                        _app.locale == null
                                            ? l10n.useSystemLanguage
                                            : {
                                                    'es': l10n.spanishLanguage,
                                                    'en': l10n.englishLanguage,
                                                    'pt': l10n
                                                        .brazilianPortugueseLanguage,
                                                    'ca': l10n.catalanLanguage,
                                                    'gl': l10n.galicianLanguage,
                                                    'eu': l10n.basqueLanguage,
                                                  }[_app
                                                      .locale!
                                                      .languageCode] ??
                                                  _app.locale!.languageCode,
                                      ),
                                      trailing: DropdownButton<String?>(
                                        value: _app.locale?.languageCode,
                                        underline: const SizedBox.shrink(),
                                        onChanged: (code) {
                                          _app.setLocale(
                                            code == null ? null : Locale(code),
                                          );
                                        },
                                        items: [
                                          DropdownMenuItem<String?>(
                                            value: null,
                                            child: Text(l10n.useSystemLanguage),
                                          ),
                                          DropdownMenuItem<String?>(
                                            value: 'es',
                                            child: Text(l10n.spanishLanguage),
                                          ),
                                          DropdownMenuItem<String?>(
                                            value: 'en',
                                            child: Text(l10n.englishLanguage),
                                          ),
                                          DropdownMenuItem<String?>(
                                            value: 'pt',
                                            child: Text(
                                              l10n.brazilianPortugueseLanguage,
                                            ),
                                          ),
                                          DropdownMenuItem<String?>(
                                            value: 'ca',
                                            child: Text(l10n.catalanLanguage),
                                          ),
                                          DropdownMenuItem<String?>(
                                            value: 'gl',
                                            child: Text(l10n.galicianLanguage),
                                          ),
                                          DropdownMenuItem<String?>(
                                            value: 'eu',
                                            child: Text(l10n.basqueLanguage),
                                          ),
                                        ],
                                      ),
                                    ),
                                    _SettingsSubsectionTitle(
                                      title: l10n.settingsEditorSubsection,
                                      scheme: scheme,
                                    ),
                                    const Divider(height: 1),
                                    ListTile(
                                      leading: const Icon(
                                        Icons.width_full_rounded,
                                      ),
                                      title: Text(
                                        l10n.settingsEditorContentWidthTitle,
                                      ),
                                      subtitle: Text(
                                        l10n.settingsEditorContentWidthSubtitle,
                                      ),
                                      trailing: Text(
                                        '${_app.editorContentWidth.round()} px',
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelLarge
                                            ?.copyWith(
                                              color: scheme.onSurfaceVariant,
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        16,
                                        0,
                                        16,
                                        8,
                                      ),
                                      child: Slider(
                                        value: _app.editorContentWidth,
                                        min: AppSettings.minEditorContentWidth,
                                        max: AppSettings.maxEditorContentWidth,
                                        divisions:
                                            ((AppSettings.maxEditorContentWidth -
                                                        AppSettings
                                                            .minEditorContentWidth) /
                                                    20)
                                                .round(),
                                        label:
                                            '${_app.editorContentWidth.round()} px',
                                        onChanged: (value) {
                                          _app.setEditorContentWidth(value);
                                        },
                                      ),
                                    ),
                                    const Divider(height: 1),
                                    SwitchListTile(
                                      secondary: const Icon(
                                        Icons.keyboard_return,
                                      ),
                                      title: Text(
                                        l10n.settingsEnterCreatesNewBlockTitle,
                                      ),
                                      subtitle: Text(
                                        _app.enterCreatesNewBlock
                                            ? l10n.settingsEnterCreatesNewBlockSubtitleWhenEnabled
                                            : l10n.settingsEnterCreatesNewBlockSubtitleWhenDisabled,
                                      ),
                                      value: _app.enterCreatesNewBlock,
                                      onChanged: _app.setEnterCreatesNewBlock,
                                    ),
                                    _SettingsSubsectionTitle(
                                      title: l10n.settingsWorkspaceSubsection,
                                      scheme: scheme,
                                    ),
                                    const Divider(height: 1),
                                    SwitchListTile(
                                      secondary: const Icon(
                                        Icons.view_sidebar_rounded,
                                      ),
                                      title: Text(l10n.sidebarAutoRevealTitle),
                                      subtitle: Text(
                                        l10n.sidebarAutoRevealSubtitle,
                                      ),
                                      value: _app.workspaceSidebarAutoReveal,
                                      onChanged: (v) =>
                                          _app.setWorkspaceSidebarAutoReveal(v),
                                    ),
                                    SwitchListTile(
                                      secondary: const Icon(
                                        Icons.home_outlined,
                                      ),
                                      title: Text(
                                        l10n.settingsWorkspaceOpenToHomeTitle,
                                      ),
                                      subtitle: Text(
                                        l10n.settingsWorkspaceOpenToHomeSubtitle,
                                      ),
                                      value: _app.workspaceOpenToHome,
                                      onChanged: (v) =>
                                          _app.setWorkspaceOpenToHome(v),
                                    ),
                                    _SettingsPanel(
                                      margin: const EdgeInsets.only(bottom: 24),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          _SettingsPanelHeroCard(
                                            icon: Icons.emoji_symbols_rounded,
                                            title:
                                                l10n.settingsCustomIconsTitle,
                                            description: l10n
                                                .settingsCustomIconsDescription,
                                            trailingBadge: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 5,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: scheme.surface,
                                                borderRadius:
                                                    BorderRadius.circular(999),
                                              ),
                                              child: Text(
                                                l10n.settingsCustomIconsSavedCount(
                                                  _app.customIcons.length,
                                                ),
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .labelMedium
                                                    ?.copyWith(
                                                      color: scheme.primary,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                              ),
                                            ),
                                            chips: [
                                              _SettingsInfoChip(
                                                icon: Icons.link_rounded,
                                                label: l10n
                                                    .settingsCustomIconsChipUrl,
                                              ),
                                              _SettingsInfoChip(
                                                icon: Icons.code_rounded,
                                                label: l10n
                                                    .settingsCustomIconsChipDataImage,
                                              ),
                                              _SettingsInfoChip(
                                                icon:
                                                    Icons.content_paste_rounded,
                                                label: l10n
                                                    .settingsCustomIconsChipPaste,
                                              ),
                                            ],
                                          ),
                                          const Divider(height: 1),
                                          Padding(
                                            padding: const EdgeInsets.fromLTRB(
                                              16,
                                              0,
                                              16,
                                              16,
                                            ),
                                            child: Container(
                                              padding: const EdgeInsets.all(16),
                                              decoration: BoxDecoration(
                                                color:
                                                    scheme.surfaceContainerLow,
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                                border: Border.all(
                                                  color: scheme.outlineVariant
                                                      .withValues(alpha: 0.45),
                                                ),
                                              ),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.stretch,
                                                children: [
                                                  Text(
                                                    l10n.settingsCustomIconsImportTitle,
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .titleSmall
                                                        ?.copyWith(
                                                          fontWeight:
                                                              FontWeight.w700,
                                                        ),
                                                  ),
                                                  const SizedBox(height: 6),
                                                  Text(
                                                    l10n.settingsCustomIconsImportSubtitle,
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .bodySmall
                                                        ?.copyWith(
                                                          color: scheme
                                                              .onSurfaceVariant,
                                                          height: 1.35,
                                                        ),
                                                  ),
                                                  const SizedBox(height: 14),
                                                  TextField(
                                                    controller:
                                                        _customIconLabelController,
                                                    decoration: InputDecoration(
                                                      labelText: l10n
                                                          .settingsCustomIconsFieldNameLabel,
                                                      hintText: l10n
                                                          .settingsCustomIconsFieldNameHint,
                                                      prefixIcon: const Icon(
                                                        Icons.edit_outlined,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 12),
                                                  TextField(
                                                    controller:
                                                        _customIconSourceController,
                                                    minLines: 3,
                                                    maxLines: 5,
                                                    decoration: InputDecoration(
                                                      labelText: l10n
                                                          .settingsCustomIconsFieldSourceLabel,
                                                      hintText: l10n
                                                          .settingsCustomIconsFieldSourceHint,
                                                      alignLabelWithHint: true,
                                                      prefixIcon: const Padding(
                                                        padding:
                                                            EdgeInsets.only(
                                                              bottom: 42,
                                                            ),
                                                        child: Icon(
                                                          Icons.link_rounded,
                                                        ),
                                                      ),
                                                    ),
                                                    onSubmitted: (_) =>
                                                        _importCustomIconFromSource(
                                                          _customIconSourceController
                                                              .text,
                                                        ),
                                                  ),
                                                  const SizedBox(height: 14),
                                                  Row(
                                                    children: [
                                                      Expanded(
                                                        child: FilledButton.icon(
                                                          onPressed:
                                                              _importingCustomIcon
                                                              ? null
                                                              : () => _importCustomIconFromSource(
                                                                  _customIconSourceController
                                                                      .text,
                                                                ),
                                                          icon:
                                                              _importingCustomIcon
                                                              ? const SizedBox(
                                                                  width: 16,
                                                                  height: 16,
                                                                  child: CircularProgressIndicator(
                                                                    strokeWidth:
                                                                        2,
                                                                  ),
                                                                )
                                                              : const Icon(
                                                                  Icons
                                                                      .download_rounded,
                                                                ),
                                                          label: Text(
                                                            l10n.settingsCustomIconsImportButton,
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 10),
                                                      Expanded(
                                                        child: OutlinedButton.icon(
                                                          onPressed:
                                                              _importingCustomIcon
                                                              ? null
                                                              : _importCustomIconFromClipboard,
                                                          icon: const Icon(
                                                            Icons
                                                                .content_paste_rounded,
                                                          ),
                                                          label: Text(
                                                            l10n.settingsCustomIconsFromClipboard,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.fromLTRB(
                                              16,
                                              0,
                                              16,
                                              16,
                                            ),
                                            child: IconifyIconBrowser(
                                              appSettings: _app,
                                              importService:
                                                  _customIconImportService,
                                              onSnack: _snack,
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.fromLTRB(
                                              16,
                                              0,
                                              16,
                                              8,
                                            ),
                                            child: Row(
                                              children: [
                                                Text(
                                                  l10n.settingsCustomIconsLibraryTitle,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .titleSmall
                                                      ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  l10n.settingsCustomIconsLibrarySubtitle,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(
                                                        color: scheme
                                                            .onSurfaceVariant,
                                                      ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (_app.customIcons.isEmpty)
                                            Padding(
                                              padding:
                                                  const EdgeInsets.fromLTRB(
                                                    16,
                                                    0,
                                                    16,
                                                    16,
                                                  ),
                                              child: Container(
                                                padding: const EdgeInsets.all(
                                                  18,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: scheme
                                                      .surfaceContainerLow,
                                                  borderRadius:
                                                      BorderRadius.circular(18),
                                                  border: Border.all(
                                                    color: scheme.outlineVariant
                                                        .withValues(
                                                          alpha: 0.45,
                                                        ),
                                                  ),
                                                ),
                                                child: Row(
                                                  children: [
                                                    Container(
                                                      width: 42,
                                                      height: 42,
                                                      decoration: BoxDecoration(
                                                        color: scheme.surface,
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              12,
                                                            ),
                                                      ),
                                                      child: Icon(
                                                        Icons
                                                            .inventory_2_outlined,
                                                        color: scheme
                                                            .onSurfaceVariant,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Expanded(
                                                      child: Text(
                                                        l10n.settingsCustomIconsEmpty,
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .bodySmall
                                                            ?.copyWith(
                                                              color: scheme
                                                                  .onSurfaceVariant,
                                                              height: 1.35,
                                                            ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            )
                                          else
                                            Padding(
                                              padding:
                                                  const EdgeInsets.fromLTRB(
                                                    16,
                                                    0,
                                                    16,
                                                    16,
                                                  ),
                                              child: Wrap(
                                                spacing: 12,
                                                runSpacing: 12,
                                                children: _app.customIcons.map((
                                                  entry,
                                                ) {
                                                  return Container(
                                                    width: 182,
                                                    padding:
                                                        const EdgeInsets.all(
                                                          14,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: scheme
                                                          .surfaceContainerLow,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            20,
                                                          ),
                                                      border: Border.all(
                                                        color: scheme
                                                            .outlineVariant,
                                                      ),
                                                    ),
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        Row(
                                                          children: [
                                                            Container(
                                                              width: 44,
                                                              height: 44,
                                                              decoration:
                                                                  BoxDecoration(
                                                                    color: scheme
                                                                        .surface,
                                                                    borderRadius:
                                                                        BorderRadius.circular(
                                                                          14,
                                                                        ),
                                                                  ),
                                                              child: Center(
                                                                child: FolioIconTokenView(
                                                                  appSettings:
                                                                      _app,
                                                                  token: entry
                                                                      .token,
                                                                  fallbackText:
                                                                      '📄',
                                                                  size: 26,
                                                                ),
                                                              ),
                                                            ),
                                                            const Spacer(),
                                                            IconButton(
                                                              tooltip: l10n
                                                                  .settingsCustomIconsDeleteTooltip,
                                                              onPressed: () =>
                                                                  _removeCustomIcon(
                                                                    entry,
                                                                  ),
                                                              icon: const Icon(
                                                                Icons
                                                                    .delete_outline_rounded,
                                                                size: 20,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                        const SizedBox(
                                                          height: 10,
                                                        ),
                                                        Text(
                                                          entry.label,
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          style: Theme.of(context)
                                                              .textTheme
                                                              .titleSmall
                                                              ?.copyWith(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w700,
                                                              ),
                                                        ),
                                                        const SizedBox(
                                                          height: 4,
                                                        ),
                                                        Text(
                                                          entry.mimeType,
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          style: Theme.of(context)
                                                              .textTheme
                                                              .bodySmall
                                                              ?.copyWith(
                                                                color: scheme
                                                                    .onSurfaceVariant,
                                                              ),
                                                        ),
                                                        const SizedBox(
                                                          height: 10,
                                                        ),
                                                        SizedBox(
                                                          width:
                                                              double.infinity,
                                                          child: OutlinedButton.icon(
                                                            onPressed: () async {
                                                              await Clipboard.setData(
                                                                ClipboardData(
                                                                  text: entry
                                                                      .token,
                                                                ),
                                                              );
                                                              if (!context
                                                                  .mounted) {
                                                                return;
                                                              }
                                                              _snack(
                                                                l10n.settingsCustomIconsReferenceCopiedSnack,
                                                              );
                                                            },
                                                            icon: const Icon(
                                                              Icons
                                                                  .content_copy_rounded,
                                                              size: 18,
                                                            ),
                                                            label: Text(
                                                              l10n.settingsCustomIconsCopyToken,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                }).toList(),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    if (showDesktopOnlySections) ...[
                                      const Divider(height: 1),
                                      _SettingsSubsectionTitle(
                                        title: l10n.desktopSection,
                                        scheme: scheme,
                                        topPadding: 8,
                                      ),
                                      const Divider(height: 1),
                                      _SettingsPanelHeroCard(
                                        icon: Icons.desktop_windows_rounded,
                                        title: l10n.desktopSection,
                                        description:
                                            l10n.settingsDesktopHeroDescription,
                                        chips: [
                                          _SettingsInfoChip(
                                            icon: Icons.search_rounded,
                                            label: l10n
                                                .settingsDesktopHeroChipGlobalSearch,
                                          ),
                                          _SettingsInfoChip(
                                            icon: Icons.minimize_rounded,
                                            label: l10n
                                                .settingsDesktopHeroChipMinimizeTray,
                                          ),
                                          _SettingsInfoChip(
                                            icon: Icons.close_rounded,
                                            label: l10n
                                                .settingsDesktopHeroChipCloseTray,
                                          ),
                                        ],
                                      ),
                                      const Divider(height: 1),
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                          16,
                                          12,
                                          16,
                                          12,
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Icon(
                                                  Icons.keyboard_rounded,
                                                  color:
                                                      scheme.onSurfaceVariant,
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        l10n.globalSearchHotkey,
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .titleMedium
                                                            ?.copyWith(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                            ),
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        _app.enableGlobalSearchHotkey
                                                            ? l10n.hotkeyCombination
                                                            : l10n.inactive,
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .bodySmall
                                                            ?.copyWith(
                                                              color: scheme
                                                                  .onSurfaceVariant,
                                                            ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                Switch(
                                                  value: _app
                                                      .enableGlobalSearchHotkey,
                                                  onChanged: _app
                                                      .setEnableGlobalSearchHotkey,
                                                ),
                                              ],
                                            ),
                                            if (_app
                                                .enableGlobalSearchHotkey) ...[
                                              const SizedBox(height: 12),
                                              Text(
                                                l10n.hotkeyCombination,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .labelLarge
                                                    ?.copyWith(
                                                      color: scheme
                                                          .onSurfaceVariant,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                              ),
                                              const SizedBox(height: 6),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                    ),
                                                decoration: BoxDecoration(
                                                  border: Border.all(
                                                    color:
                                                        scheme.outlineVariant,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                child: DropdownButton<String>(
                                                  isExpanded: true,
                                                  value:
                                                      _app.globalSearchHotkey,
                                                  underline:
                                                      const SizedBox.shrink(),
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  items: [
                                                    DropdownMenuItem(
                                                      value: 'Alt+Space',
                                                      child: Text(
                                                        l10n.hotkeyAltSpace,
                                                      ),
                                                    ),
                                                    DropdownMenuItem(
                                                      value: 'Ctrl+Shift+Space',
                                                      child: Text(
                                                        l10n.hotkeyCtrlShiftSpace,
                                                      ),
                                                    ),
                                                    DropdownMenuItem(
                                                      value: 'Ctrl+Shift+K',
                                                      child: Text(
                                                        l10n.hotkeyCtrlShiftK,
                                                      ),
                                                    ),
                                                    const DropdownMenuItem(
                                                      value: 'Ctrl+Shift+F',
                                                      child: Text(
                                                        'Ctrl + Shift + F',
                                                      ),
                                                    ),
                                                    const DropdownMenuItem(
                                                      value: 'Ctrl+Alt+Space',
                                                      child: Text(
                                                        'Ctrl + Alt + Space',
                                                      ),
                                                    ),
                                                  ],
                                                  onChanged: (value) {
                                                    if (value != null) {
                                                      _app.setGlobalSearchHotkey(
                                                        value,
                                                      );
                                                    }
                                                  },
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      const Divider(height: 1),
                                      SwitchListTile(
                                        secondary: const Icon(
                                          Icons.minimize_outlined,
                                        ),
                                        title: Text(l10n.minimizeToTray),
                                        value: _app.minimizeToTray,
                                        onChanged: _app.setMinimizeToTray,
                                      ),
                                      const Divider(height: 1),
                                      SwitchListTile(
                                        secondary: const Icon(
                                          Icons.close_rounded,
                                        ),
                                        title: Text(l10n.closeToTray),
                                        value: _app.closeToTray,
                                        onChanged: _app.setCloseToTray,
                                      ),
                                      if (!kIsWeb &&
                                          defaultTargetPlatform ==
                                              TargetPlatform.windows) ...[
                                        const Divider(height: 1),
                                        SwitchListTile(
                                          secondary: const Icon(
                                            Icons.notifications_outlined,
                                          ),
                                          title: Text(
                                            l10n.settingsWindowsNotifications,
                                          ),
                                          subtitle: Text(
                                            l10n.settingsWindowsNotificationsSubtitle,
                                          ),
                                          value:
                                              _app.windowsNotificationsEnabled,
                                          onChanged: _app
                                              .setWindowsNotificationsEnabled,
                                        ),
                                      ],
                                      const Divider(height: 1),
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                          16,
                                          12,
                                          16,
                                          16,
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            _SettingsSubsectionTitle(
                                              title: l10n
                                                  .meetingNoteSettingsSection,
                                              scheme: scheme,
                                              topPadding: 0,
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              l10n.meetingNoteSettingsDescription,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.copyWith(
                                                    color:
                                                        scheme.onSurfaceVariant,
                                                  ),
                                            ),
                                            const SizedBox(height: 12),
                                            Builder(
                                              builder: (ctx) {
                                                final hw =
                                                    TranscriptionHardwareProfile.loadCached();
                                                return Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment
                                                          .stretch,
                                                  children: [
                                                    Text(
                                                      l10n.meetingNoteSettingsHardwareIntro,
                                                      style: Theme.of(ctx)
                                                          .textTheme
                                                          .labelMedium
                                                          ?.copyWith(
                                                            color: scheme
                                                                .onSurfaceVariant,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                          ),
                                                    ),
                                                    const SizedBox(height: 6),
                                                    Text(
                                                      l10n.meetingNoteHardwareSummary(
                                                        hw.logicalCpuCount,
                                                        hw.ramLabelForUi(
                                                          l10n.meetingNoteHardwareRamUnknown,
                                                        ),
                                                      ),
                                                      style: Theme.of(ctx)
                                                          .textTheme
                                                          .bodySmall
                                                          ?.copyWith(
                                                            color: scheme
                                                                .onSurfaceVariant,
                                                          ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      l10n.meetingNoteHardwareRecommended(
                                                        _meetingModelLabel(
                                                          l10n,
                                                          hw.recommendedWhisperModelId,
                                                        ),
                                                      ),
                                                      style: Theme.of(ctx)
                                                          .textTheme
                                                          .bodySmall
                                                          ?.copyWith(
                                                            color: scheme
                                                                .onSurfaceVariant,
                                                          ),
                                                    ),
                                                    const SizedBox(height: 10),
                                                    SwitchListTile(
                                                      contentPadding:
                                                          EdgeInsets.zero,
                                                      title: Text(
                                                        l10n.meetingNoteSettingsAutoWhisperModel,
                                                      ),
                                                      value: _app
                                                          .meetingNoteAutoWhisperModel,
                                                      onChanged: (v) {
                                                        unawaited(
                                                          _app.setMeetingNoteAutoWhisperModel(
                                                            v,
                                                          ),
                                                        );
                                                      },
                                                    ),
                                                    if (!hw
                                                        .isLocalTranscriptionViable) ...[
                                                      const SizedBox(height: 8),
                                                      SwitchListTile(
                                                        contentPadding:
                                                            EdgeInsets.zero,
                                                        title: Text(
                                                          l10n.meetingNoteSettingsForceLocalTranscription,
                                                        ),
                                                        value: _app
                                                            .meetingNoteForceLocalTranscription,
                                                        onChanged: (v) {
                                                          unawaited(
                                                            _app.setMeetingNoteForceLocalTranscription(
                                                              v,
                                                            ),
                                                          );
                                                        },
                                                      ),
                                                    ],
                                                    const SizedBox(height: 12),
                                                  ],
                                                );
                                              },
                                            ),
                                            DropdownButtonFormField<String>(
                                              key: ValueKey<String>(
                                                'meeting-mic-${_app.meetingNoteMicDeviceId}-${_meetingNoteMicDevices.length}',
                                              ),
                                              initialValue: (() {
                                                final id =
                                                    _app.meetingNoteMicDeviceId;
                                                if (id.isEmpty) return '';
                                                return _meetingMicExists(id)
                                                    ? id
                                                    : '';
                                              })(),
                                              decoration: InputDecoration(
                                                labelText: l10n
                                                    .meetingNoteSettingsMicrophone,
                                                border:
                                                    const OutlineInputBorder(),
                                                isDense: true,
                                                suffixIcon: IconButton(
                                                  tooltip: l10n
                                                      .meetingNoteSettingsRefreshDevices,
                                                  onPressed:
                                                      _loadMeetingNoteDevices,
                                                  icon: const Icon(
                                                    Icons.refresh,
                                                  ),
                                                ),
                                              ),
                                              items: _meetingMicDropdownItems(
                                                l10n,
                                              ),
                                              onChanged: (value) {
                                                unawaited(
                                                  _app.setMeetingNoteMicDeviceId(
                                                    value ?? '',
                                                  ),
                                                );
                                              },
                                            ),
                                            const SizedBox(height: 10),
                                            DropdownButtonFormField<String>(
                                              key: ValueKey<String>(
                                                'meeting-system-${_app.meetingNoteSystemDeviceId}-${_meetingNoteSystemDevices.length}',
                                              ),
                                              initialValue: (() {
                                                final id = _app
                                                    .meetingNoteSystemDeviceId;
                                                if (id.isEmpty) return '';
                                                return _meetingSystemExists(id)
                                                    ? id
                                                    : '';
                                              })(),
                                              decoration: InputDecoration(
                                                labelText: l10n
                                                    .meetingNoteSettingsSystemOutput,
                                                border:
                                                    const OutlineInputBorder(),
                                                isDense: true,
                                              ),
                                              items:
                                                  _meetingSystemDropdownItems(
                                                    l10n,
                                                  ),
                                              onChanged: (value) {
                                                unawaited(
                                                  _app.setMeetingNoteSystemDeviceId(
                                                    value ?? '',
                                                  ),
                                                );
                                              },
                                            ),
                                            const SizedBox(height: 10),
                                            DropdownButtonFormField<String>(
                                              key: ValueKey<String>(
                                                'meeting-model-${_app.meetingNoteAutoWhisperModel}-${_app.resolvedMeetingNoteWhisperModelId()}',
                                              ),
                                              initialValue: (() {
                                                final id = _app
                                                    .resolvedMeetingNoteWhisperModelId();
                                                return _meetingModelExists(id)
                                                    ? id
                                                    : 'base';
                                              })(),
                                              decoration: InputDecoration(
                                                labelText: l10n
                                                    .meetingNoteSettingsModel,
                                                border: OutlineInputBorder(),
                                                isDense: true,
                                              ),
                                              items: WhisperService
                                                  .supportedModels
                                                  .map(
                                                    (
                                                      m,
                                                    ) => DropdownMenuItem<String>(
                                                      value: m.id,
                                                      child: Text(
                                                        '${_meetingModelLabel(l10n, m.id)} (~${m.approxSizeMb} MB)',
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),
                                                  )
                                                  .toList(),
                                              onChanged:
                                                  _app.meetingNoteAutoWhisperModel
                                                  ? null
                                                  : (value) {
                                                      unawaited(
                                                        _app.setMeetingNoteModelId(
                                                          value ?? 'base',
                                                        ),
                                                      );
                                                    },
                                            ),
                                            const SizedBox(height: 12),
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                bottom: 8,
                                              ),
                                              child: Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  const Icon(
                                                    Icons
                                                        .record_voice_over_rounded,
                                                    size: 16,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      l10n.meetingNoteDiarizationHint,
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .bodySmall
                                                          ?.copyWith(
                                                            color: scheme
                                                                .onSurfaceVariant,
                                                          ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Divider(height: 1),
                                      _SettingsSubsectionTitle(
                                        title: l10n.keyboardShortcutsSection,
                                        scheme: scheme,
                                        topPadding: 8,
                                      ),
                                      const Divider(height: 1),
                                      _SettingsPanelHeroCard(
                                        icon: Icons.keyboard_rounded,
                                        title: l10n.keyboardShortcutsSection,
                                        description: l10n
                                            .settingsShortcutsHeroDescription,
                                        chips: [
                                          _SettingsInfoChip(
                                            icon: Icons.ads_click_rounded,
                                            label:
                                                l10n.settingsShortcutsTestChip,
                                          ),
                                          _SettingsInfoChip(
                                            icon: Icons.restart_alt_rounded,
                                            label: l10n.shortcutResetAllTitle,
                                          ),
                                        ],
                                      ),
                                      const Divider(height: 1),
                                      for (final id
                                          in FolioInAppShortcut.values) ...[
                                        if (id !=
                                            FolioInAppShortcut.values.first)
                                          const Divider(height: 1),
                                        ListTile(
                                          leading: const Icon(
                                            Icons.keyboard_rounded,
                                          ),
                                          title: Text(id.settingsLabel),
                                          subtitle: Text(
                                            _app.describeInAppShortcut(id),
                                          ),
                                          trailing: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              TextButton(
                                                onPressed: () {
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                        l10n.shortcutTestHint(
                                                          _app.describeInAppShortcut(
                                                            id,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  );
                                                },
                                                child: Text(
                                                  l10n.shortcutTestAction,
                                                ),
                                              ),
                                              TextButton(
                                                onPressed: () async {
                                                  final next =
                                                      await showDialog<
                                                        SingleActivator
                                                      >(
                                                        context: context,
                                                        builder: (ctx) =>
                                                            const InAppShortcutCaptureDialog(),
                                                      );
                                                  if (next != null &&
                                                      context.mounted) {
                                                    await _app.setInAppShortcut(
                                                      id,
                                                      next,
                                                    );
                                                  }
                                                },
                                                child: Text(
                                                  l10n.shortcutChangeAction,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                      const Divider(height: 1),
                                      ListTile(
                                        leading: const Icon(
                                          Icons.restore_rounded,
                                        ),
                                        title: Text(l10n.shortcutResetAllTitle),
                                        subtitle: Text(
                                          l10n.shortcutResetAllSubtitle,
                                        ),
                                        onTap: () async {
                                          await _app
                                              .resetInAppShortcutsToDefaults();
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  l10n.shortcutResetDoneSnack,
                                                ),
                                              ),
                                            );
                                          }
                                        },
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),

                          if (_app.isAiAvailable) ...[
                            Visibility(
                              visible:
                                  _selectedMobileSection ==
                                      _SettingsSectionId.ai,
                              maintainState: false,
                              child: KeyedSubtree(
                                key: const ValueKey(_SettingsSectionId.ai),
                                child: _SettingsPanel(
                                  margin: const EdgeInsets.only(bottom: 24),
                                  child: Column(
                                    children: [
                                      _SettingsPanelHeroCard(
                                        icon: Icons.smart_toy_outlined,
                                        title: l10n.ai,
                                        description:
                                            _app.aiProvider ==
                                                AiProvider.quillCloud
                                            ? (aiLocalProvidersSupported
                                                  ? l10n.settingsAiHeroQuillWithLocalAlt
                                                  : l10n.settingsAiHeroQuillCloudOnly)
                                            : (aiLocalProvidersSupported
                                                  ? l10n.settingsAiHeroLocalDefault
                                                  : l10n.settingsAiHeroQuillMobileOnly),
                                        chips:
                                            _app.aiProvider ==
                                                AiProvider.quillCloud
                                            ? [
                                                _SettingsInfoChip(
                                                  icon: Icons.cloud_outlined,
                                                  label:
                                                      l10n.settingsAiChipCloud,
                                                ),
                                                _SettingsInfoChip(
                                                  icon: Icons.hub_outlined,
                                                  label: l10n.aiProviderLabel,
                                                ),
                                              ]
                                            : [
                                                _SettingsInfoChip(
                                                  icon: Icons.hub_outlined,
                                                  label: l10n.aiProviderLabel,
                                                ),
                                                if (aiLocalProvidersSupported) ...[
                                                  _SettingsInfoChip(
                                                    icon: Icons
                                                        .psychology_outlined,
                                                    label: l10n.aiModel,
                                                  ),
                                                  _SettingsInfoChip(
                                                    icon: Icons
                                                        .assistant_navigation,
                                                    label: l10n
                                                        .aiSetupAssistantTitle,
                                                  ),
                                                ],
                                              ],
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                          16,
                                          12,
                                          16,
                                          12,
                                        ),
                                        child: Builder(
                                          builder: (context) {
                                            final theme = Theme.of(context);
                                            return Container(
                                              padding: const EdgeInsets.all(14),
                                              decoration: BoxDecoration(
                                                color: scheme
                                                    .surfaceContainerHighest
                                                    .withValues(alpha: 0.55),
                                                borderRadius:
                                                    BorderRadius.circular(18),
                                                border: Border.all(
                                                  color: scheme.outlineVariant
                                                      .withValues(alpha: 0.45),
                                                ),
                                              ),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.stretch,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Icon(
                                                        Icons
                                                            .compare_arrows_rounded,
                                                        color: scheme.primary,
                                                      ),
                                                      const SizedBox(width: 10),
                                                      Expanded(
                                                        child: Text(
                                                          l10n.aiCompareCloudVsLocalTitle,
                                                          style: theme
                                                              .textTheme
                                                              .titleSmall
                                                              ?.copyWith(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w800,
                                                              ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 10),
                                                  LayoutBuilder(
                                                    builder: (context, constraints) {
                                                      final narrow =
                                                          constraints.maxWidth <
                                                          560;
                                                      Widget card({
                                                        required IconData icon,
                                                        required String title,
                                                        required List<String>
                                                        bullets,
                                                      }) {
                                                        return Container(
                                                          padding:
                                                              const EdgeInsets.all(
                                                                12,
                                                              ),
                                                          decoration: BoxDecoration(
                                                            color: scheme
                                                                .surface
                                                                .withValues(
                                                                  alpha: 0.9,
                                                                ),
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  16,
                                                                ),
                                                            border: Border.all(
                                                              color: scheme
                                                                  .outlineVariant
                                                                  .withValues(
                                                                    alpha: 0.35,
                                                                  ),
                                                            ),
                                                          ),
                                                          child: Column(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .stretch,
                                                            children: [
                                                              Row(
                                                                children: [
                                                                  Icon(
                                                                    icon,
                                                                    color: scheme
                                                                        .primary,
                                                                  ),
                                                                  const SizedBox(
                                                                    width: 8,
                                                                  ),
                                                                  Expanded(
                                                                    child: Text(
                                                                      title,
                                                                      style: theme
                                                                          .textTheme
                                                                          .labelLarge
                                                                          ?.copyWith(
                                                                            fontWeight:
                                                                                FontWeight.w800,
                                                                          ),
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                              const SizedBox(
                                                                height: 8,
                                                              ),
                                                              ...bullets.map(
                                                                (b) => Padding(
                                                                  padding:
                                                                      const EdgeInsets.only(
                                                                        bottom:
                                                                            4,
                                                                      ),
                                                                  child: Text(
                                                                    '• $b',
                                                                    style: theme
                                                                        .textTheme
                                                                        .bodySmall
                                                                        ?.copyWith(
                                                                          color:
                                                                              scheme.onSurfaceVariant,
                                                                          height:
                                                                              1.35,
                                                                        ),
                                                                  ),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        );
                                                      }

                                                      final cloudCard = card(
                                                        icon: Icons
                                                            .cloud_outlined,
                                                        title: l10n
                                                            .aiCompareCloudTitle,
                                                        bullets: [
                                                          l10n.aiCompareCloudBulletNoSetup,
                                                          l10n.aiCompareCloudBulletNeedsSub,
                                                          l10n.aiCompareCloudBulletInk,
                                                        ],
                                                      );
                                                      final localCard = card(
                                                        icon: Icons
                                                            .computer_outlined,
                                                        title: l10n
                                                            .aiCompareLocalTitle,
                                                        bullets: [
                                                          l10n.aiCompareLocalBulletPrivacy,
                                                          l10n.aiCompareLocalBulletNoInk,
                                                          l10n.aiCompareLocalBulletSetup,
                                                        ],
                                                      );

                                                      if (!aiLocalProvidersSupported) {
                                                        return cloudCard;
                                                      }
                                                      if (narrow) {
                                                        return Column(
                                                          children: [
                                                            cloudCard,
                                                            const SizedBox(
                                                              height: 10,
                                                            ),
                                                            localCard,
                                                          ],
                                                        );
                                                      }
                                                      return Row(
                                                        children: [
                                                          Expanded(
                                                            child: cloudCard,
                                                          ),
                                                          const SizedBox(
                                                            width: 10,
                                                          ),
                                                          Expanded(
                                                            child: localCard,
                                                          ),
                                                        ],
                                                      );
                                                    },
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                      const Divider(height: 1),
                                      SwitchListTile(
                                        secondary: const Icon(
                                          Icons.smart_toy_outlined,
                                        ),
                                        title: Text(l10n.aiEnableToggleTitle),
                                        subtitle: Text(
                                          _app.aiEnabled
                                              ? l10n.active
                                              : l10n.inactive,
                                        ),
                                        value: _app.aiEnabled,
                                        onChanged: _detectingAiProvider
                                            ? null
                                            : (v) async {
                                                if (v && !_app.aiEnabled) {
                                                  final confirmed =
                                                      await _confirmAiBetaEnable();
                                                  if (!confirmed) return;
                                                  final acceptedScope =
                                                      await _confirmQuillGlobalScopeIfNeeded();
                                                  if (!acceptedScope) return;
                                                  if (!_app
                                                      .hasCompletedQuillSetup) {
                                                    if (aiLocalProvidersSupported) {
                                                      final configured =
                                                          await _autoDetectAndConfigureAiProvider();
                                                      if (!configured) return;
                                                    }
                                                    await _app
                                                        .setHasCompletedQuillSetup(
                                                          true,
                                                        );
                                                  }
                                                  await _saveAiFields();
                                                  await _app.setAiEnabled(true);
                                                  return;
                                                }
                                                await _saveAiFields();
                                                await _app.setAiEnabled(v);
                                              },
                                      ),
                                      if (_detectingAiProvider)
                                        const Padding(
                                          padding: EdgeInsets.fromLTRB(
                                            16,
                                            0,
                                            16,
                                            12,
                                          ),
                                          child: LinearProgressIndicator(),
                                        ),
                                      if (aiLocalProvidersSupported &&
                                          (_app.aiProvider == AiProvider.ollama ||
                                              _app.aiProvider == AiProvider.lmStudio)) ...[
                                        const Divider(height: 1),
                                        ListTile(
                                          leading: const Icon(
                                            Icons.assistant_navigation,
                                          ),
                                          title: Text(
                                            l10n.aiSetupAssistantTitle,
                                          ),
                                          subtitle: Text(
                                            l10n.aiSetupAssistantSubtitle,
                                          ),
                                          trailing: const Icon(
                                            Icons.chevron_right_rounded,
                                          ),
                                          onTap: _detectingAiProvider
                                              ? null
                                              : _autoDetectAndConfigureAiProvider,
                                        ),
                                      ],
                                      const Divider(height: 1),
                                      SwitchListTile(
                                        secondary: const Icon(
                                          Icons.psychology_outlined,
                                        ),
                                        title: Text(l10n.aiAlwaysShowThought),
                                        subtitle: Text(
                                          l10n.aiAlwaysShowThoughtHint,
                                        ),
                                        value: _app.aiAlwaysShowThought,
                                        onChanged: _app.aiEnabled
                                            ? _app.setAiAlwaysShowThought
                                            : null,
                                      ),
                                      SwitchListTile(
                                        secondary: const Icon(
                                          Icons.view_column_outlined,
                                        ),
                                        title: Text(
                                          l10n.settingsAiChatSplitViewTitle,
                                        ),
                                        subtitle: Text(
                                          l10n.settingsAiChatSplitViewSubtitle,
                                        ),
                                        value: _app.aiChatSplitView,
                                        onChanged: _app.aiEnabled
                                            ? (v) async {
                                                await _app.setAiChatSplitView(
                                                  v,
                                                );
                                                if (mounted) setState(() {});
                                              }
                                            : null,
                                      ),
                                      SwitchListTile(
                                        secondary: const Icon(
                                          Icons.auto_fix_high_outlined,
                                        ),
                                        title: Text(
                                          l10n
                                              .settingsAiQuillCopilotExperimentalTitle,
                                        ),
                                        subtitle: Text(
                                          l10n
                                              .settingsAiQuillCopilotExperimentalSubtitle,
                                        ),
                                        value:
                                            _app.aiQuillCopilotExperimental,
                                        onChanged: _app.aiEnabled
                                            ? (v) async {
                                                await _app
                                                    .setAiQuillCopilotExperimental(
                                                      v,
                                                    );
                                                if (mounted) setState(() {});
                                              }
                                            : null,
                                      ),
                                      if (aiLocalProvidersSupported &&
                                          _app.aiProvider !=
                                              AiProvider.quillCloud) ...[
                                        const Divider(height: 1),
                                        SwitchListTile(
                                          secondary: const Icon(
                                            Icons.rocket_launch_outlined,
                                          ),
                                          title: Text(
                                            l10n.aiLaunchProviderWithApp,
                                          ),
                                          subtitle: Text(
                                            l10n.aiLaunchProviderWithAppHint,
                                          ),
                                          value: _app.aiLaunchProviderWithApp,
                                          onChanged: _app.aiEnabled
                                              ? (v) async {
                                                  await _app
                                                      .setAiLaunchProviderWithApp(
                                                        v,
                                                      );
                                                }
                                              : null,
                                        ),
                                        const Divider(height: 1),
                                        ListTile(
                                          leading: const Icon(
                                            Icons.memory_outlined,
                                          ),
                                          title: Text(
                                            l10n.aiContextWindowTokens,
                                          ),
                                          subtitle: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                l10n.aiContextWindowTokensHint,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodySmall
                                                    ?.copyWith(
                                                      color: scheme
                                                          .onSurfaceVariant,
                                                    ),
                                              ),
                                              TextField(
                                                controller:
                                                    _aiContextWindowController,
                                                enabled: _app.aiEnabled,
                                                keyboardType:
                                                    TextInputType.number,
                                                decoration:
                                                    const InputDecoration(
                                                      hintText: '131072',
                                                      border: InputBorder.none,
                                                      enabledBorder:
                                                          InputBorder.none,
                                                      focusedBorder:
                                                          InputBorder.none,
                                                      contentPadding:
                                                          EdgeInsets.zero,
                                                    ),
                                                onSubmitted: (_) =>
                                                    _saveAiFields(),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                      const SizedBox.shrink(),
                                      const Divider(height: 1),
                                      ListTile(
                                        leading: const Icon(Icons.hub_outlined),
                                        title: Text(l10n.aiProviderLabel),
                                        trailing: DropdownButton<AiProvider>(
                                          value: _app.aiProvider,
                                          underline: const SizedBox.shrink(),
                                          onChanged: (value) async {
                                            if (value == null) return;
                                            if (value ==
                                                AiProvider.quillCloud) {
                                              if (!_folio.isAvailable) {
                                                _snack(
                                                  l10n.settingsAiSnackFirebaseUnavailableBuild,
                                                );
                                                return;
                                              }
                                              if (!_cloud.isSignedIn) {
                                                _snack(
                                                  l10n.settingsAiSnackSignInCloudAccount,
                                                );
                                                return;
                                              }
                                              if (!_folio
                                                  .snapshot
                                                  .canUseCloudAi) {
                                                _snack(
                                                  l10n.aiProviderFolioCloudBlockedSnack,
                                                );
                                                return;
                                              }
                                            }
                                            try {
                                              await _app.setAiProvider(value);
                                              if (!mounted) return;
                                              setState(() {
                                                _availableModels = _app
                                                    .cachedAiModelsFor(value);
                                              });
                                              if (_availableModels.isNotEmpty &&
                                                  !_availableModels.contains(
                                                    _app.aiModel,
                                                  )) {
                                                await _app.setAiModel(
                                                  _availableModels.first,
                                                );
                                              }
                                              _aiBaseUrlController.text = _app
                                                  .defaultUrlForProvider(value);
                                              await _saveAiFields();
                                              if (value ==
                                                  AiProvider.quillCloud) {
                                                await _loadAiModels();
                                              }
                                            } catch (e) {
                                              if (!mounted) return;
                                              _snack(
                                                l10n.settingsAiProviderSwitchFailed(
                                                  '$e',
                                                ),
                                              );
                                            }
                                          },
                                          items: [
                                            DropdownMenuItem(
                                              value: AiProvider.none,
                                              child: Text(l10n.aiProviderNone),
                                            ),
                                            if (aiLocalProvidersSupported) ...[
                                              DropdownMenuItem(
                                                value: AiProvider.ollama,
                                                child: Text('Ollama'),
                                              ),
                                              DropdownMenuItem(
                                                value: AiProvider.lmStudio,
                                                child: Text('LM Studio'),
                                              ),
                                            ],
                                            DropdownMenuItem(
                                              value: AiProvider.openAi,
                                              child: const Text('OpenAI'),
                                            ),
                                            DropdownMenuItem(
                                              value: AiProvider.gemini,
                                              child: const Text('Gemini'),
                                            ),
                                            DropdownMenuItem(
                                              value: AiProvider.quillCloud,
                                              child: const Text('Quill Cloud'),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (_app.aiProvider == AiProvider.ollama ||
                                          _app.aiProvider == AiProvider.lmStudio ||
                                          _app.aiProvider == AiProvider.openAi ||
                                          _app.aiProvider == AiProvider.gemini) ...[
                                        const Divider(height: 1),
                                        ListTile(
                                          leading: const Icon(
                                            Icons.link_rounded,
                                          ),
                                          title: Text(l10n.aiEndpoint),
                                          subtitle: TextField(
                                            controller: _aiBaseUrlController,
                                            decoration: const InputDecoration(
                                              hintText:
                                                  'http://127.0.0.1:11434',
                                              border: InputBorder.none,
                                              enabledBorder: InputBorder.none,
                                              focusedBorder: InputBorder.none,
                                              contentPadding: EdgeInsets.zero,
                                            ),
                                            onSubmitted: (_) => _saveAiFields(),
                                          ),
                                        ),
                                        if (_app.aiProvider == AiProvider.openAi ||
                                            _app.aiProvider == AiProvider.gemini) ...[
                                          const Divider(height: 1),
                                          ListTile(
                                            leading: const Icon(
                                              Icons.key_rounded,
                                            ),
                                            title: const Text('Clave API (API Key)'),
                                            subtitle: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                TextField(
                                                  controller: _aiApiKeyController,
                                                  obscureText: true,
                                                  decoration: const InputDecoration(
                                                    hintText: 'Ingresa tu API Key',
                                                    border: InputBorder.none,
                                                    enabledBorder: InputBorder.none,
                                                    focusedBorder: InputBorder.none,
                                                    contentPadding: EdgeInsets.zero,
                                                  ),
                                                  onSubmitted: (_) => _saveAiFields(),
                                                ),
                                                if (_app.aiProvider == AiProvider.gemini)
                                                  Padding(
                                                    padding: const EdgeInsets.only(top: 4, bottom: 4),
                                                    child: Text(
                                                      'Consigue tu clave API en aistudio.google.com',
                                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                        color: scheme.primary,
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                    ),
                                                  ),
                                                if (_app.aiProvider == AiProvider.openAi)
                                                  Padding(
                                                    padding: const EdgeInsets.only(top: 4, bottom: 4),
                                                    child: Text(
                                                      'Consigue tu clave API en platform.openai.com',
                                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                        color: scheme.primary,
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ],
                                        const Divider(height: 1),
                                        ListTile(
                                          leading: const Icon(
                                            Icons.psychology_alt_outlined,
                                          ),
                                          title: Text(l10n.aiModel),
                                          subtitle: _loadingModels
                                              ? const Padding(
                                                  padding: EdgeInsets.symmetric(
                                                    vertical: 8,
                                                  ),
                                                  child:
                                                      LinearProgressIndicator(),
                                                )
                                              : DropdownButton<String>(
                                                  value:
                                                      _availableModels.contains(
                                                        _app.aiModel,
                                                      )
                                                      ? _app.aiModel
                                                      : null,
                                                  hint: Text(
                                                    l10n.aiConnectToListModels,
                                                  ),
                                                  isExpanded: true,
                                                  underline:
                                                      const SizedBox.shrink(),
                                                  onChanged:
                                                      _availableModels.isEmpty
                                                      ? null
                                                      : (value) {
                                                          if (value != null) {
                                                            _app.setAiModel(
                                                              value,
                                                            );
                                                          }
                                                        },
                                                  items: _availableModels
                                                      .map(
                                                        (m) =>
                                                            DropdownMenuItem<
                                                              String
                                                            >(
                                                              value: m,
                                                              child: Text(m),
                                                            ),
                                                      )
                                                      .toList(),
                                                ),
                                        ),
                                        const Divider(height: 1),
                                        ListTile(
                                          leading: const Icon(
                                            Icons.timer_outlined,
                                          ),
                                          title: Text(l10n.aiTimeoutMs),
                                          subtitle: TextField(
                                            controller: _aiTimeoutController,
                                            keyboardType: TextInputType.number,
                                            decoration: const InputDecoration(
                                              hintText: '30000',
                                              border: InputBorder.none,
                                              enabledBorder: InputBorder.none,
                                              focusedBorder: InputBorder.none,
                                              contentPadding: EdgeInsets.zero,
                                            ),
                                            onSubmitted: (_) => _saveAiFields(),
                                          ),
                                        ),
                                        if (_app.aiProvider == AiProvider.ollama ||
                                            _app.aiProvider == AiProvider.lmStudio) ...[
                                          const Divider(height: 1),
                                          SwitchListTile(
                                            secondary: const Icon(
                                              Icons.public_outlined,
                                            ),
                                            title: Text(
                                              l10n.aiAllowRemoteEndpoint,
                                            ),
                                            subtitle: Text(
                                              _app.aiEndpointMode ==
                                                      AiEndpointMode.allowRemote
                                                  ? l10n.aiAllowRemoteEndpointAllowed
                                                  : l10n.aiAllowRemoteEndpointLocalhostOnly,
                                            ),
                                            value:
                                                _app.aiEndpointMode ==
                                                AiEndpointMode.allowRemote,
                                            onChanged: (v) async {
                                              await _app.setAiEndpointMode(
                                                v
                                                    ? AiEndpointMode.allowRemote
                                                    : AiEndpointMode
                                                          .localhostOnly,
                                              );
                                              if (v) {
                                                await _confirmRemoteEndpointIfNeeded();
                                              }
                                            },
                                          ),
                                          if (_app.aiEndpointMode ==
                                                  AiEndpointMode.allowRemote &&
                                              !_app.aiRemoteEndpointConfirmed)
                                            Padding(
                                              padding: const EdgeInsets.fromLTRB(
                                                16,
                                                0,
                                                16,
                                                16,
                                              ),
                                              child: Text(
                                                l10n.aiAllowRemoteEndpointNotConfirmed,
                                                style: TextStyle(
                                                  color: Colors.orange,
                                                ),
                                              ),
                                            ),
                                        ],
                                        const Divider(height: 1),
                                        ListTile(
                                          leading: const Icon(
                                            Icons.network_check_rounded,
                                          ),
                                          title: Text(
                                            l10n.aiConnectToListModels,
                                          ),
                                          onTap: _testAiConnection,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],

                          // ─── Quill Instructions Section ───
                          Visibility(
                            visible: _selectedMobileSection == _SettingsSectionId.ai,
                            maintainState: false,
                            child: _SettingsPanel(
                              margin: const EdgeInsets.only(top: 16, bottom: 24),
                              child: StatefulBuilder(
                                builder: (context, setInnerState) {
                                  final prompts = _app.quillSystemPrompts;
                                  final theme = Theme.of(context);
                                  final scheme = Theme.of(context).colorScheme;
                                  final isEs = Localizations.localeOf(context).languageCode == 'es';
                                  final l10n = AppLocalizations.of(context);
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      ListTile(
                                        leading: const Icon(Icons.psychology_alt_outlined),
                                        title: Text(isEs ? 'Instrucciones de Quill' : 'Quill Instructions'),
                                        subtitle: Text(
                                          isEs
                                              ? 'Crea instrucciones personalizadas para que Quill las use automáticamente'
                                              : 'Create custom instructions for Quill to use automatically',
                                        ),
                                        trailing: FilledButton.tonalIcon(
                                          icon: const Icon(Icons.add, size: 16),
                                          label: Text(isEs ? 'Nueva' : 'New'),
                                          onPressed: () async {
                                            await _showEditQuillPromptDialog(null);
                                            setInnerState(() {});
                                          },
                                        ),
                                      ),
                                      const Divider(height: 1),
                                      ...prompts.map((item) {
                                        return Column(
                                          children: [
                                            ListTile(
                                              leading: Icon(
                                                item.isSystemDefault
                                                    ? Icons.auto_awesome_rounded
                                                    : Icons.notes_rounded,
                                                color: item.isSystemDefault
                                                    ? scheme.primary
                                                    : scheme.onSurfaceVariant,
                                                size: 20,
                                              ),
                                              title: Text(
                                                item.name,
                                                style: theme.textTheme.titleSmall?.copyWith(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              subtitle: Text(
                                                item.prompt,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: theme.textTheme.bodySmall?.copyWith(
                                                  color: scheme.onSurfaceVariant,
                                                ),
                                              ),
                                              trailing: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  IconButton(
                                                    icon: Icon(
                                                      item.isSystemDefault
                                                          ? Icons.visibility_outlined
                                                          : Icons.edit_outlined,
                                                      size: 20,
                                                    ),
                                                    tooltip: item.isSystemDefault
                                                        ? (isEs ? 'Ver' : 'View')
                                                        : (isEs ? 'Editar' : 'Edit'),
                                                    onPressed: () async {
                                                      await _showEditQuillPromptDialog(
                                                        item,
                                                        readOnly: item.isSystemDefault,
                                                      );
                                                      setInnerState(() {});
                                                    },
                                                  ),
                                                  if (!item.isSystemDefault)
                                                    IconButton(
                                                      icon: Icon(
                                                        Icons.delete_outline_rounded,
                                                        size: 20,
                                                        color: scheme.error,
                                                      ),
                                                      tooltip: isEs ? 'Eliminar' : 'Delete',
                                                      onPressed: () async {
                                                        final confirm = await showDialog<bool>(
                                                          context: context,
                                                          builder: (ctx) => FolioDialog(
                                                            title: Text(isEs
                                                                ? '¿Eliminar instrucciones?'
                                                                : 'Delete instructions?'),
                                                            content: Text(isEs
                                                                ? '¿Estás seguro de que quieres eliminar "${item.name}"?'
                                                                : 'Are you sure you want to delete "${item.name}"?'),
                                                            actions: [
                                                              TextButton(
                                                                onPressed: () => Navigator.pop(ctx, false),
                                                                child: Text(l10n.cancel),
                                                              ),
                                                              FilledButton(
                                                                onPressed: () => Navigator.pop(ctx, true),
                                                                style: FilledButton.styleFrom(
                                                                  backgroundColor: scheme.error,
                                                                  foregroundColor: scheme.onError,
                                                                ),
                                                                child: Text(l10n.delete),
                                                              ),
                                                            ],
                                                          ),
                                                        );
                                                        if (confirm == true) {
                                                          await _app.deleteQuillSystemPrompt(item.id);
                                                          setInnerState(() {});
                                                          if (mounted) setState(() {});
                                                        }
                                                      },
                                                    ),
                                                ],
                                              ),
                                            ),
                                            const Divider(height: 1),
                                          ],
                                        );
                                      }),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ),

                          Visibility(
                            visible:
                                _selectedMobileSection ==
                                    _SettingsSectionId.sync,
                            maintainState: false,
                            child: KeyedSubtree(
                              key: const ValueKey(_SettingsSectionId.sync),
                              child: AnimatedBuilder(
                                animation: _sync,
                                builder: (context, _) => _SettingsPanel(
                                  margin: const EdgeInsets.only(bottom: 24),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      _SettingsPanelHeroCard(
                                        icon: Icons.sync_rounded,
                                        title: l10n.settingsSyncHeroTitle,
                                        description:
                                            l10n.settingsSyncHeroDescription,
                                        chips: [
                                          _SettingsInfoChip(
                                            icon: Icons.shield_outlined,
                                            label: l10n
                                                .settingsSyncChipPairingCode,
                                          ),
                                          _SettingsInfoChip(
                                            icon: Icons.search_rounded,
                                            label: l10n
                                                .settingsSyncChipAutoDiscovery,
                                          ),
                                          _SettingsInfoChip(
                                            icon: Icons.cloud_outlined,
                                            label: l10n
                                                .settingsSyncChipOptionalRelay,
                                          ),
                                        ],
                                      ),
                                      const Divider(height: 1),
                                      SwitchListTile(
                                        secondary: const Icon(
                                          Icons.sync_rounded,
                                        ),
                                        title: Text(
                                          l10n.settingsSyncEnableTitle,
                                        ),
                                        subtitle: Text(
                                          _app.syncEnabled
                                              ? (_sync.discoveredPeers.isEmpty
                                                    ? l10n.settingsSyncSearchingSubtitle
                                                    : l10n.settingsSyncDevicesFoundOnLan(
                                                        _sync
                                                            .discoveredPeers
                                                            .length,
                                                      ))
                                              : l10n.settingsSyncDisabledSubtitle,
                                        ),
                                        value: _app.syncEnabled,
                                        onChanged: (v) async {
                                          if (!v) {
                                            await _app.setSyncEnabled(false);
                                            if (mounted) setState(() {});
                                            return;
                                          }
                                          if (_s.state !=
                                              VaultFlowState.unlocked) {
                                            return;
                                          }
                                          final l10nSync = AppLocalizations.of(
                                            context,
                                          );
                                          final ok = await _verifyVaultIdentity(
                                            title: Text(
                                              l10nSync.vaultIdentitySyncTitle,
                                            ),
                                            body: Text(
                                              l10nSync.vaultIdentitySyncBody,
                                            ),
                                          );
                                          if (!ok || !mounted) return;
                                          await _app.setSyncEnabled(true);
                                          if (mounted) setState(() {});
                                        },
                                      ),
                                      const Divider(height: 1),
                                      SwitchListTile(
                                        secondary: const Icon(
                                          Icons.hub_outlined,
                                        ),
                                        title: Text(
                                          l10n.settingsSyncRelayTitle,
                                        ),
                                        subtitle: Text(
                                          l10n.settingsSyncRelaySubtitle,
                                        ),
                                        value: _app.syncRelayEnabled,
                                        onChanged: _app.syncEnabled
                                            ? (v) async {
                                                if (v) {
                                                  final l10nRelay =
                                                      AppLocalizations.of(
                                                        context,
                                                      );
                                                  final ok = await _verifyVaultIdentity(
                                                    title: Text(
                                                      l10nRelay
                                                          .vaultIdentitySyncTitle,
                                                    ),
                                                    body: Text(
                                                      l10nRelay
                                                          .vaultIdentitySyncBody,
                                                    ),
                                                  );
                                                  if (!ok || !mounted) return;
                                                }
                                                await _app.setSyncRelayEnabled(
                                                  v,
                                                );
                                                if (mounted) setState(() {});
                                              }
                                            : null,
                                      ),
                                      const Divider(height: 1),
                                      ListTile(
                                        leading: const Icon(
                                          Icons.devices_outlined,
                                        ),
                                        title: Text(
                                          l10n.settingsDeviceNameTitle,
                                        ),
                                        subtitle: Text(_app.syncDeviceName),
                                        trailing: TextButton(
                                          onPressed: _editSyncDeviceName,
                                          child: Text(l10n.settingsEdit),
                                        ),
                                      ),
                                      const Divider(height: 1),
                                      ListTile(
                                        leading: const Icon(Icons.pin_outlined),
                                        title: Text(
                                          l10n.settingsSyncEmojiModeTitle,
                                        ),
                                        subtitle: Text(
                                          l10n.settingsSyncEmojiModeSubtitle,
                                        ),
                                        onTap: _app.syncEnabled
                                            ? _activateEmojiPairingMode
                                            : null,
                                      ),
                                      const Divider(height: 1),
                                      ListTile(
                                        leading: const Icon(
                                          Icons.emoji_emotions_outlined,
                                        ),
                                        title: Text(
                                          l10n.settingsSyncPairingStatusTitle,
                                        ),
                                        subtitle: Text(
                                          _sync.isPairingModeActive
                                              ? l10n.settingsSyncPairingActiveSubtitle
                                              : l10n.settingsSyncPairingInactiveSubtitle,
                                        ),
                                      ),
                                      const Divider(height: 1),
                                      ListTile(
                                        leading: const Icon(
                                          Icons.history_toggle_off,
                                        ),
                                        title: Text(
                                          l10n.settingsSyncLastSyncTitle,
                                        ),
                                        subtitle: Text(_formatLastSyncLabel()),
                                      ),
                                      const Divider(height: 1),
                                      ListTile(
                                        leading: const Icon(
                                          Icons.warning_amber_rounded,
                                        ),
                                        title: Text(
                                          l10n.settingsSyncPendingConflictsTitle,
                                        ),
                                        subtitle: Text(
                                          _app.syncPendingConflicts <= 0
                                              ? l10n.settingsSyncNoConflictsSubtitle
                                              : l10n.settingsSyncConflictsNeedReview(
                                                  _app.syncPendingConflicts,
                                                ),
                                        ),
                                        trailing: _app.syncPendingConflicts > 0
                                            ? TextButton(
                                                onPressed:
                                                    _showSyncConflictsDialog,
                                                child: Text(
                                                  l10n.settingsResolve,
                                                ),
                                              )
                                            : null,
                                        onTap: _app.syncPendingConflicts > 0
                                            ? _showSyncConflictsDialog
                                            : null,
                                      ),
                                      const Divider(height: 1),
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                          16,
                                          12,
                                          16,
                                          6,
                                        ),
                                        child: Text(
                                          l10n.settingsSyncDiscoveredDevicesTitle,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleSmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                          16,
                                          0,
                                          16,
                                          10,
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            if (_sync.discoveredPeers.isEmpty)
                                              Text(
                                                l10n.settingsSyncNoDevicesYetHint,
                                                style: Theme.of(
                                                  context,
                                                ).textTheme.bodySmall,
                                              )
                                            else
                                              ..._sync.discoveredPeers.map((
                                                peer,
                                              ) {
                                                final hasActiveCode =
                                                    (peer.pairingCode ?? '')
                                                        .trim()
                                                        .isNotEmpty;
                                                final pairingReady =
                                                    _sync.isPairingModeActive &&
                                                    hasActiveCode;
                                                final subtitle = pairingReady
                                                    ? l10n.settingsSyncPeerReadyToLink
                                                    : hasActiveCode
                                                    ? l10n.settingsSyncPeerOtherInPairingMode
                                                    : l10n.settingsSyncPeerDetectedLan;
                                                return Container(
                                                  margin: const EdgeInsets.only(
                                                    bottom: 8,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: scheme
                                                        .surfaceContainerLow,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          14,
                                                        ),
                                                    border: Border.all(
                                                      color: scheme
                                                          .outlineVariant
                                                          .withValues(
                                                            alpha: 0.5,
                                                          ),
                                                    ),
                                                  ),
                                                  child: ListTile(
                                                    dense: true,
                                                    leading: const Icon(
                                                      Icons.wifi_tethering,
                                                    ),
                                                    title: Text(
                                                      peer.deviceName,
                                                    ),
                                                    subtitle: Text(subtitle),
                                                    trailing: FilledButton.tonal(
                                                      onPressed:
                                                          _app.syncEnabled &&
                                                              pairingReady
                                                          ? () =>
                                                                _submitPairingCodeDialog(
                                                                  peer: peer,
                                                                )
                                                          : null,
                                                      child: Text(
                                                        l10n.settingsLinkDevice,
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              }),
                                          ],
                                        ),
                                      ),
                                      const Divider(height: 1),
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                          16,
                                          12,
                                          16,
                                          16,
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              l10n.settingsSyncLinkedDevicesTitle,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleSmall
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                            ),
                                            const SizedBox(height: 10),
                                            if (_sync.peers.isEmpty)
                                              Text(
                                                l10n.settingsSyncNoLinkedDevicesYet,
                                                style: Theme.of(
                                                  context,
                                                ).textTheme.bodySmall,
                                              )
                                            else
                                              ..._sync.peers.map((peer) {
                                                return Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        bottom: 8,
                                                      ),
                                                  child: Container(
                                                    decoration: BoxDecoration(
                                                      color: scheme
                                                          .surfaceContainerLow,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            14,
                                                          ),
                                                      border: Border.all(
                                                        color: scheme
                                                            .outlineVariant
                                                            .withValues(
                                                              alpha: 0.5,
                                                            ),
                                                      ),
                                                    ),
                                                    child: ListTile(
                                                      dense: true,
                                                      leading: const Icon(
                                                        Icons.devices,
                                                      ),
                                                      title: Text(
                                                        peer.deviceName,
                                                      ),
                                                      subtitle: Text(
                                                        l10n.settingsSyncPeerIdLabel(
                                                          peer.peerId,
                                                        ),
                                                      ),
                                                      trailing: TextButton(
                                                        onPressed: () =>
                                                            _revokeSyncPeer(
                                                              peer,
                                                            ),
                                                        child: Text(
                                                          l10n.settingsRevoke,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              }),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),

                          Visibility(
                            visible:
                                _selectedMobileSection ==
                                    _SettingsSectionId.about,
                            maintainState: false,
                            child: KeyedSubtree(
                              key: const ValueKey(_SettingsSectionId.about),
                              child: _SettingsPanel(
                                margin: const EdgeInsets.only(bottom: 24),
                                child: Column(
                                  children: [
                                    _SettingsPanelHeroCard(
                                      icon: Icons.info_outline_rounded,
                                      title: l10n.about,
                                      description:
                                          l10n.settingsAboutHeroDescription,
                                    ),
                                    const Divider(height: 1),
                                    ListTile(
                                      leading: const Icon(
                                        Icons.info_outline_rounded,
                                      ),
                                      title: Text(l10n.installedVersion),
                                      subtitle: Text(_installedVersionLabel),
                                    ),
                                    const Divider(height: 1),
                                    ListTile(
                                      leading: const Icon(
                                        Icons.article_outlined,
                                      ),
                                      title: Text(
                                        l10n.settingsOpenReleaseNotes,
                                      ),
                                      trailing: _openingReleaseNotes
                                          ? const SizedBox(
                                              height: 20,
                                              width: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : null,
                                      onTap: _openingReleaseNotes
                                          ? null
                                          : _openReleaseNotesNow,
                                    ),
                                    if (FolioDistribution
                                        .offersGitHubSelfUpdate) ...[
                                      if (showDesktopOnlySections) ...[
                                        const Divider(height: 1),
                                        ListTile(
                                          leading: const Icon(
                                            Icons.cloud_outlined,
                                          ),
                                          title: Text(
                                            l10n.updaterGithubRepository,
                                          ),
                                          subtitle: Text(
                                            '${_app.updaterGithubOwner}/${_app.updaterGithubRepo}',
                                          ),
                                        ),
                                      ],
                                      const Divider(height: 1),
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                          16,
                                          8,
                                          16,
                                          8,
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            Text(
                                              l10n.settingsUpdateChannelLabel,
                                              style: Theme.of(
                                                context,
                                              ).textTheme.titleSmall,
                                            ),
                                            const SizedBox(height: 8),
                                            SegmentedButton<
                                                UpdateReleaseChannel>(
                                              segments: [
                                                ButtonSegment<
                                                    UpdateReleaseChannel>(
                                                  value: UpdateReleaseChannel
                                                      .stable,
                                                  label: Text(
                                                    l10n
                                                        .settingsUpdateChannelRelease,
                                                  ),
                                                  icon: const Icon(
                                                    Icons.verified_outlined,
                                                    size: 18,
                                                  ),
                                                ),
                                                ButtonSegment<
                                                    UpdateReleaseChannel>(
                                                  value: UpdateReleaseChannel
                                                      .beta,
                                                  label: Text(
                                                    l10n
                                                        .settingsUpdateChannelBeta,
                                                  ),
                                                  icon: const Icon(
                                                    Icons.science_outlined,
                                                    size: 18,
                                                  ),
                                                ),
                                              ],
                                              selected: {
                                                _app.updateReleaseChannel,
                                              },
                                              onSelectionChanged: (s) {
                                                _app.setUpdateReleaseChannel(
                                                  s.first,
                                                );
                                              },
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              _app.updateReleaseChannel ==
                                                      UpdateReleaseChannel.beta
                                                  ? l10n.updaterBetaDescription
                                                  : l10n
                                                      .updaterStableDescription,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.copyWith(
                                                    color: scheme
                                                        .onSurfaceVariant,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Divider(height: 1),
                                      ListTile(
                                        leading: const Icon(
                                          Icons.system_update_rounded,
                                        ),
                                        title: Text(l10n.checkUpdates),
                                        trailing: _checkingUpdates
                                            ? const SizedBox(
                                                height: 20,
                                                width: 20,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                ),
                                              )
                                            : null,
                                        onTap: _checkingUpdates
                                            ? null
                                            : _checkUpdatesNow,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),

                          if (showDesktopOnlySections) ...[
                            Visibility(
                              visible:
                                  _selectedMobileSection ==
                                      _SettingsSectionId.integrations,
                              maintainState: false,
                              child: KeyedSubtree(
                                key: const ValueKey(_SettingsSectionId.integrations),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _SettingsPanel(
                                      margin: const EdgeInsets.only(bottom: 24),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          ListenableBuilder(
                                            listenable:
                                                AppStoreService.instance,
                                            builder: (context, _) {
                                              final installed = AppStoreService
                                                  .instance
                                                  .installedApps;
                                              return ListTile(
                                                leading: const Icon(
                                                  Icons.extension_outlined,
                                                ),
                                                title: const Text(
                                                  'Tienda de Apps',
                                                ),
                                                subtitle: Text(
                                                  installed.isEmpty
                                                      ? 'Sin apps instaladas'
                                                      : '${installed.length} app${installed.length == 1 ? '' : 's'} instalada${installed.length == 1 ? '' : 's'}',
                                                ),
                                                trailing: FilledButton.tonal(
                                                  onPressed: () {
                                                    Navigator.of(
                                                      context,
                                                    ).push<void>(
                                                      MaterialPageRoute<void>(
                                                        builder: (_) =>
                                                            const AppStoreScreen(),
                                                      ),
                                                    );
                                                  },
                                                  child: const Text(
                                                    'Abrir tienda',
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                    _SettingsPanel(
                                      margin: const EdgeInsets.only(bottom: 24),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          _IntegrationsHero(
                                            approvedCount: _app
                                                .approvedIntegrationAppApprovals
                                                .length,
                                            hintText: l10n
                                                .integrationsAppsApprovedHint,
                                            title: l10n.integrations,
                                            featureChips: [
                                              _SettingsInfoChip(
                                                icon: Icons
                                                    .verified_user_outlined,
                                                label: l10n
                                                    .settingsIntegrationsChipApprovedPermissions,
                                              ),
                                              _SettingsInfoChip(
                                                icon: Icons.lock_open_outlined,
                                                label: l10n
                                                    .settingsIntegrationsChipRevocableAccess,
                                              ),
                                              _SettingsInfoChip(
                                                icon: Icons.devices_outlined,
                                                label: l10n
                                                    .settingsIntegrationsChipExternalApps,
                                              ),
                                            ],
                                          ),
                                          const Divider(height: 1),
                                          Padding(
                                            padding: const EdgeInsets.fromLTRB(
                                              16,
                                              0,
                                              16,
                                              16,
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                ListenableBuilder(
                                                  listenable:
                                                      AppStoreService.instance,
                                                  builder: (context, _) {
                                                    final jiraInstalled =
                                                        AppStoreService.instance
                                                            .isInstalled(
                                                              FolioBuiltInApps
                                                                  .jiraId,
                                                            );
                                                    final youtrackInstalled =
                                                        AppStoreService.instance
                                                            .isInstalled(
                                                              FolioBuiltInApps
                                                                  .youtrackId,
                                                            );
                                                    if (!jiraInstalled &&
                                                        !youtrackInstalled) {
                                                      return const SizedBox.shrink();
                                                    }
                                                    return Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          l10n.settingsIntegrationsNativeTitle,
                                                          style: Theme.of(context)
                                                              .textTheme
                                                              .titleSmall
                                                              ?.copyWith(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w800,
                                                              ),
                                                        ),
                                                        const SizedBox(
                                                          height: 10,
                                                        ),
                                                        if (jiraInstalled) ...[
                                                          JiraIntegrationCard(
                                                            session: _s,
                                                            appSettings: _app,
                                                          ),
                                                          const SizedBox(
                                                            height: 10,
                                                          ),
                                                        ],
                                                        if (youtrackInstalled) ...[
                                                          YouTrackIntegrationCard(
                                                            session: _s,
                                                            appSettings: _app,
                                                          ),
                                                          const SizedBox(
                                                            height: 10,
                                                          ),
                                                        ],
                                                        const SizedBox(
                                                          height: 8,
                                                        ),
                                                      ],
                                                    );
                                                  },
                                                ),
                                                Row(
                                                  children: [
                                                    Text(
                                                      l10n.settingsIntegrationsActiveConnectionsTitle,
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .titleSmall
                                                          ?.copyWith(
                                                            fontWeight:
                                                                FontWeight.w700,
                                                          ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      l10n.settingsIntegrationsActiveConnectionsSubtitle,
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .bodySmall
                                                          ?.copyWith(
                                                            color: scheme
                                                                .onSurfaceVariant,
                                                          ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 12),
                                                if (_app
                                                    .approvedIntegrationAppApprovals
                                                    .isEmpty)
                                                  Container(
                                                    width: double.infinity,
                                                    padding:
                                                        const EdgeInsets.all(
                                                          18,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: scheme
                                                          .surfaceContainerLow,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            18,
                                                          ),
                                                      border: Border.all(
                                                        color: scheme
                                                            .outlineVariant
                                                            .withValues(
                                                              alpha: 0.45,
                                                            ),
                                                      ),
                                                    ),
                                                    child: Row(
                                                      children: [
                                                        Container(
                                                          width: 44,
                                                          height: 44,
                                                          decoration: BoxDecoration(
                                                            color:
                                                                scheme.surface,
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  14,
                                                                ),
                                                          ),
                                                          child: Icon(
                                                            Icons.hub_outlined,
                                                            color: scheme
                                                                .onSurfaceVariant,
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                          width: 12,
                                                        ),
                                                        Expanded(
                                                          child: Text(
                                                            l10n.integrationsAppsApprovedNone,
                                                            style: Theme.of(context)
                                                                .textTheme
                                                                .bodySmall
                                                                ?.copyWith(
                                                                  color: scheme
                                                                      .onSurfaceVariant,
                                                                  height: 1.35,
                                                                ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  )
                                                else
                                                  Wrap(
                                                    spacing: 12,
                                                    runSpacing: 12,
                                                    children: _app
                                                        .approvedIntegrationAppApprovals
                                                        .map(
                                                          (
                                                            entry,
                                                          ) => _IntegrationAppCard(
                                                            entry: entry,
                                                            detailsText: l10n.integrationsApprovedAppDetails(
                                                              entry.appId,
                                                              entry
                                                                      .appVersion
                                                                      .isEmpty
                                                                  ? l10n.integrationApprovalUnknownVersion
                                                                  : entry
                                                                        .appVersion,
                                                              entry
                                                                      .integrationVersion
                                                                      .isEmpty
                                                                  ? l10n.integrationApprovalUnknownVersion
                                                                  : entry
                                                                        .integrationVersion,
                                                            ),
                                                            revokeLabel: l10n
                                                                .integrationsAppsApprovedRevoke,
                                                            onRevoke: () =>
                                                                _revokeIntegrationApp(
                                                                  entry.appId,
                                                                ),
                                                          ),
                                                        )
                                                        .toList(),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                );
                },
              );
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1000),
                  child: Padding(
                    padding: EdgeInsets.all(wide ? 24.0 : 16.0),
                    child: settingsContent,
                  ),
                ),
              );
            },
          ),
        ),
      );
    },
  );
}
}

