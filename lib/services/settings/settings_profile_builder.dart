import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import '../../app/app_settings.dart';
import '../../app/workspace_prefs_keys.dart';
import '../../data/folio_settings_profile_format.dart';
import '../../models/folio_usage_intent.dart';
import '../secure_credential_storage.dart';

/// Construye perfiles de ajustes (app / libreta) listos para cifrar y subir.
class SettingsProfileBuilder {
  const SettingsProfileBuilder();

  FolioSettingsIconRef _iconRef(CustomIconEntry e) => FolioSettingsIconRef(
        id: e.id,
        label: e.label,
        source: e.source,
        mimeType: e.mimeType,
        createdAtMs: e.createdAtMs,
      );

  /// Bytes de iconos locales referenciados por el perfil de app.
  Future<Map<String, List<int>>> collectIconBytes(AppSettings settings) async {
    final out = <String, List<int>>{};
    Future<void> add(CustomIconEntry e) async {
      if (e.id.isEmpty || e.filePath.isEmpty) return;
      if (out.containsKey(e.id)) return;
      final f = File(e.filePath);
      if (!f.existsSync()) return;
      out[e.id] = await f.readAsBytes();
    }

    for (final e in settings.customIcons) {
      await add(e);
    }
    for (final list in settings.integrationCustomIconsByApp.values) {
      for (final e in list) {
        await add(e);
      }
    }
    return out;
  }

  FolioSettingsProfile buildAppProfile(AppSettings settings) {
    final secrets = <String, String>{};
    if (settings.aiApiKey.trim().isNotEmpty) {
      secrets['aiApiKey'] = settings.aiApiKey.trim();
    }
    if (settings.mcpServerAuthToken.trim().isNotEmpty) {
      secrets['mcpServerAuthToken'] = settings.mcpServerAuthToken.trim();
    }

    final approved = <String, Object?>{};
    for (final a in settings.approvedIntegrationAppApprovals) {
      approved[a.appId] = a.toJson();
    }

    final settingsMap = <String, Object?>{
      'themeMode': settings.themeMode.name,
      'oledThemeEnabled': settings.oledThemeEnabled,
      'uiScale': settings.uiScale,
      'uiScaleMode': settings.uiScaleMode.name,
      'localeCode': settings.locale?.languageCode,
      'accentColorMode': settings.accentColorMode.name,
      'customAccentArgb': settings.customAccentArgb,
      'vaultIdleLockMinutes': settings.vaultIdleLockMinutes,
      'vaultLockOnMinimize': settings.vaultLockOnMinimize,
      'enableGlobalSearchHotkey': settings.enableGlobalSearchHotkey,
      'globalSearchHotkey': settings.globalSearchHotkey,
      'minimizeToTray': settings.minimizeToTray,
      'closeToTray': settings.closeToTray,
      'windowsNotificationsEnabled': settings.windowsNotificationsEnabled,
      'launchAtStartupEnabled': settings.launchAtStartupEnabled,
      'aiEnabled': settings.aiEnabled,
      'aiProvider': settings.aiProvider.name,
      'aiBaseUrl': settings.aiBaseUrl,
      'aiModel': settings.aiModel,
      'aiTimeoutMs': settings.aiTimeoutMs,
      'aiEndpointMode': settings.aiEndpointMode.name,
      'aiRemoteEndpointConfirmed': settings.aiRemoteEndpointConfirmed,
      'aiAlwaysShowThought': settings.aiAlwaysShowThought,
      'quillToolCallingEnabled': settings.quillToolCallingEnabled,
      'mcpServerEnabled': settings.mcpServerEnabled,
      'aiLaunchProviderWithApp': settings.aiLaunchProviderWithApp,
      'aiContextWindowTokens': settings.aiContextWindowTokens,
      'aiPersona': settings.aiPersona,
      'aiCustomSystemPrompt': settings.aiCustomSystemPrompt,
      'activeQuillPromptId': settings.activeQuillPromptId,
      'quillSystemPrompts':
          settings.quillSystemPrompts.map((e) => e.toJson()).toList(),
      'usageIntents': FolioUsageIntent.encodeList(settings.usageIntents),
      'hasSeenQuillIntro': settings.hasSeenQuillIntro,
      'hasSeenQuillWorkspaceTour': settings.hasSeenQuillWorkspaceTour,
      'hasAcceptedQuillGlobalScope': settings.hasAcceptedQuillGlobalScope,
      'hasCompletedQuillSetup': settings.hasCompletedQuillSetup,
      'lastSeenReleaseNotesVersion': settings.lastSeenReleaseNotesVersion,
      'updateReleaseChannel': settings.updateReleaseChannel.name,
      'betaBannerDismissed': settings.betaBannerDismissed,
      'inAppShortcutsJson': settings.exportInAppShortcutsJson(),
      'jiraOAuthClientId': settings.jiraOAuthClientId,
      'approvedIntegrationApps': approved,
      'enterCreatesNewBlock': settings.enterCreatesNewBlock,
      'recentSearchQueries': settings.recentSearchQueries,
      'telemetryEnabled': settings.telemetryEnabled,
      'autoCrashReports': settings.autoCrashReports,
      'driveDeleteOriginalsOnUpload': settings.driveDeleteOriginalsOnUpload,
      'editorContentWidth': settings.editorContentWidth,
      'workspaceSidebarWidth': settings.workspaceSidebarWidth,
      'workspaceSidebarCollapsed': settings.workspaceSidebarCollapsed,
      'workspaceSidebarAutoReveal': settings.workspaceSidebarAutoReveal,
      'workspaceSidebarShowRecentPages': settings.workspaceSidebarShowRecentPages,
      'workspaceSidebarRecentPagesCollapsed':
          settings.workspaceSidebarRecentPagesCollapsed,
      'workspaceOpenToHome': settings.workspaceOpenToHome,
      'workspacePageOutlineVisible': settings.workspacePageOutlineVisible,
      'workspaceBacklinksVisible': settings.workspaceBacklinksVisible,
      'workspaceCommentsVisible': settings.workspaceCommentsVisible,
      'workspaceHomeShowFolioCloudCard': settings.workspaceHomeShowFolioCloudCard,
      'workspaceHomeShowRootPages': settings.workspaceHomeShowRootPages,
      'workspaceHomeShowMiniStats': settings.workspaceHomeShowMiniStats,
      'workspaceHomeShowTasksSection': settings.workspaceHomeShowTasksSection,
      'workspaceHomeShowQuickActions': settings.workspaceHomeShowQuickActions,
      'workspaceHomeShowTip': settings.workspaceHomeShowTip,
      'workspaceHomeShowVaultStatus': settings.workspaceHomeShowVaultStatus,
      'workspaceHomeShowOnboarding': settings.workspaceHomeShowOnboarding,
      'workspaceHomeShowWhatsNew': settings.workspaceHomeShowWhatsNew,
      'workspaceHomeColumnLayout': settings.workspaceHomeColumnLayout.name,
      'workspaceHomeClockShowSeconds': settings.workspaceHomeClockShowSeconds,
      'workspaceHomeClock24Hour': settings.workspaceHomeClock24Hour,
      'workspaceHomeClockShowTimezone': settings.workspaceHomeClockShowTimezone,
      'workspaceHomeWhatsNewDismissedVersion':
          settings.workspaceHomeWhatsNewDismissedVersion,
      'workspaceHomeLeftSectionOrder': settings.workspaceHomeLeftSectionOrder,
      'workspaceHomeRightSectionOrder': settings.workspaceHomeRightSectionOrder,
      'aiChatPanelCollapsed': settings.aiChatPanelCollapsed,
      'aiChatPanelWidth': settings.aiChatPanelWidth,
      'aiChatPanelHeight': settings.aiChatPanelHeight,
      'aiChatSplitView': settings.aiChatSplitView,
      'aiQuillCopilotExperimental': settings.aiQuillCopilotExperimental,
      'syncEnabled': settings.syncEnabled,
      'syncRelayEnabled': settings.syncRelayEnabled,
      'syncDeviceName': settings.syncDeviceName,
      'cloudDeviceSyncEnabled': settings.cloudDeviceSyncEnabled,
      'cloudAppProfileSyncEnabled': settings.cloudAppProfileSyncEnabled,
      'meetingNoteMicDeviceId': settings.meetingNoteMicDeviceId,
      'meetingNoteSystemDeviceId': settings.meetingNoteSystemDeviceId,
      'meetingNoteModelId': settings.meetingNoteModelId,
      'meetingNoteAutoWhisperModel': settings.meetingNoteAutoWhisperModel,
      'meetingNoteForceLocalTranscription':
          settings.meetingNoteForceLocalTranscription,
    };

    return FolioSettingsProfile(
      kind: FolioSettingsProfileKind.app,
      settings: settingsMap,
      secrets: secrets,
      icons: settings.customIcons.map(_iconRef).toList(growable: false),
      integrationIconsByApp: {
        for (final e in settings.integrationCustomIconsByApp.entries)
          e.key: e.value.map(_iconRef).toList(growable: false),
      },
      exportedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<FolioSettingsProfile> buildVaultProfile({
    required AppSettings settings,
    required String vaultId,
    SecureCredentialStorage? credentials,
  }) async {
    final vid = vaultId.trim();
    final prefs = await settings.getVaultBackupPrefs(vid);
    final secrets = <String, String>{};
    final creds = credentials ?? SecureCredentialStorage();
    final folderPw =
        await creds.readPassword(vid, BackupCredentialScope.folder);
    if (folderPw != null && folderPw.isNotEmpty) {
      secrets['backupFolderPassword'] = folderPw;
    }
    final webdavPw =
        await creds.readPassword(vid, BackupCredentialScope.webdav);
    if (webdavPw != null && webdavPw.isNotEmpty) {
      secrets['backupWebdavPassword'] = webdavPw;
    }

    final p = await SharedPreferences.getInstance();
    final workspace = <String, Object?>{
      'homeOnboardAnchor':
          p.getString(WorkspacePrefsKeys.homeOnboardAnchor(vid)),
      'homeOnboardDismissed':
          p.getBool(WorkspacePrefsKeys.homeOnboardDismissed(vid)),
      'homeCloudGuestDismiss':
          p.getBool(WorkspacePrefsKeys.homeCloudGuestDismiss(vid)),
      'homeOnboardCloudExploreDone':
          p.getBool(WorkspacePrefsKeys.homeOnboardCloudExploreDone(vid)),
      'lastSelectedPageId':
          p.getString('folio_last_selected_page_$vid'),
      'taskInboxPageId': await settings.getTaskInboxPageId(vid),
      'taskAliasPageMap': await settings.getTaskAliasPageMap(vid),
    };

    return FolioSettingsProfile(
      kind: FolioSettingsProfileKind.vault,
      vaultId: vid,
      settings: <String, Object?>{
        'backup': prefs.toJson(),
        'workspace': workspace,
      },
      secrets: secrets,
      exportedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
  }
}
