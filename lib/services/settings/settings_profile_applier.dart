import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/app_settings.dart';
import '../../app/workspace_prefs_keys.dart';
import '../../data/folio_settings_profile_format.dart';
import '../../models/folio_usage_intent.dart';
import '../../models/quill_system_prompt.dart';
import '../secure_credential_storage.dart';
import '../updater/update_release_channel.dart';

/// Aplica un perfil de ajustes descargado (modo replace).
class SettingsProfileApplier {
  const SettingsProfileApplier();

  Future<void> applyAppProfile({
    required AppSettings settings,
    required FolioSettingsProfile profile,
    required Map<String, String> localIconPathsById,
  }) async {
    if (profile.kind != FolioSettingsProfileKind.app) {
      throw ArgumentError('Se esperaba perfil de app');
    }
    final s = profile.settings;
    final secrets = profile.secrets;

    Future<void> applyBool(
      String key,
      Future<void> Function(bool) setter,
    ) async {
      final v = s[key];
      if (v is bool) await setter(v);
    }

    Future<void> applyInt(String key, Future<void> Function(int) setter) async {
      final v = s[key];
      if (v is num) await setter(v.toInt());
    }

    Future<void> applyDouble(
      String key,
      Future<void> Function(double) setter,
    ) async {
      final v = s[key];
      if (v is num) await setter(v.toDouble());
    }

    Future<void> applyString(
      String key,
      Future<void> Function(String) setter,
    ) async {
      final v = s[key];
      if (v is String) await setter(v);
    }

    final themeRaw = s['themeMode']?.toString();
    if (themeRaw != null) {
      final mode = FolioThemeMode.values
          .where((e) => e.name == themeRaw)
          .firstOrNull;
      if (mode != null) {
        await settings.setThemeMode(mode);
      }
    }
    // Perfiles antiguos: ThemeMode + flag OLED separado.
    final legacyOled = s['oledThemeEnabled'];
    if (legacyOled == true &&
        settings.themeMode != FolioThemeMode.oled &&
        settings.themeMode != FolioThemeMode.light) {
      await settings.setThemeMode(FolioThemeMode.oled);
    }
    await applyDouble('uiScale', settings.setUiScale);
    final scaleMode = s['uiScaleMode']?.toString();
    if (scaleMode != null) {
      final m =
          UiScaleMode.values.where((e) => e.name == scaleMode).firstOrNull;
      if (m != null) await settings.setUiScaleMode(m);
    }
    final localeCode = s['localeCode'];
    if (localeCode is String && localeCode.isNotEmpty) {
      await settings.setLocale(Locale(localeCode));
    } else if (s.containsKey('localeCode') && localeCode == null) {
      await settings.setLocale(null);
    }
    final accent = s['accentColorMode']?.toString();
    if (accent != null) {
      final m = FolioAccentColorMode.values
          .where((e) => e.name == accent)
          .firstOrNull;
      if (m != null) await settings.setAccentColorMode(m);
    }
    await applyInt('customAccentArgb', settings.setCustomAccentArgb);
    await applyInt('vaultIdleLockMinutes', settings.setVaultIdleLockMinutes);
    await applyBool('vaultLockOnMinimize', settings.setVaultLockOnMinimize);
    await applyBool(
      'enableGlobalSearchHotkey',
      settings.setEnableGlobalSearchHotkey,
    );
    await applyString('globalSearchHotkey', settings.setGlobalSearchHotkey);
    await applyBool('minimizeToTray', settings.setMinimizeToTray);
    await applyBool('closeToTray', settings.setCloseToTray);
    await applyBool(
      'windowsNotificationsEnabled',
      settings.setWindowsNotificationsEnabled,
    );
    await applyBool(
      'launchAtStartupEnabled',
      settings.setLaunchAtStartupEnabled,
    );

    await applyBool('aiEnabled', settings.setAiEnabled);
    final provider = s['aiProvider']?.toString();
    if (provider != null) {
      final p = AiProvider.values.where((e) => e.name == provider).firstOrNull;
      if (p != null) await settings.setAiProvider(p);
    }
    await applyString('aiBaseUrl', settings.setAiBaseUrl);
    await applyString('aiModel', settings.setAiModel);
    await applyInt('aiTimeoutMs', settings.setAiTimeoutMs);
    final endpoint = s['aiEndpointMode']?.toString();
    if (endpoint != null) {
      final m =
          AiEndpointMode.values.where((e) => e.name == endpoint).firstOrNull;
      if (m != null) await settings.setAiEndpointMode(m);
    }
    await applyBool(
      'aiRemoteEndpointConfirmed',
      settings.setAiRemoteEndpointConfirmed,
    );
    await applyBool('aiAlwaysShowThought', settings.setAiAlwaysShowThought);
    await applyBool(
      'quillToolCallingEnabled',
      settings.setQuillToolCallingEnabled,
    );
    await applyBool('mcpServerEnabled', settings.setMcpServerEnabled);
    await applyBool(
      'aiLaunchProviderWithApp',
      settings.setAiLaunchProviderWithApp,
    );
    await applyInt('aiContextWindowTokens', settings.setAiContextWindowTokens);
    await applyString('aiPersona', settings.setAiPersona);
    await applyString('aiCustomSystemPrompt', settings.setAiCustomSystemPrompt);
    await applyString('activeQuillPromptId', settings.setActiveQuillPromptId);

    final promptsRaw = s['quillSystemPrompts'];
    if (promptsRaw is List) {
      for (final item in promptsRaw) {
        if (item is Map) {
          final prompt = QuillSystemPrompt.fromJson(
            Map<String, dynamic>.from(item),
          );
          if (prompt.id.isEmpty || prompt.isSystemDefault) continue;
          await settings.addQuillSystemPrompt(prompt);
        }
      }
    }

    final intentsRaw = s['usageIntents'];
    if (intentsRaw is String) {
      await settings.setUsageIntents(FolioUsageIntent.parseList(intentsRaw));
    }
    await applyBool('hasSeenQuillIntro', settings.setHasSeenQuillIntro);
    await applyBool(
      'hasSeenQuillWorkspaceTour',
      settings.setHasSeenQuillWorkspaceTour,
    );
    await applyBool(
      'hasAcceptedQuillGlobalScope',
      settings.setHasAcceptedQuillGlobalScope,
    );
    await applyBool(
      'hasCompletedQuillSetup',
      settings.setHasCompletedQuillSetup,
    );
    await applyString(
      'lastSeenReleaseNotesVersion',
      settings.setLastSeenReleaseNotesVersion,
    );
    final channel = s['updateReleaseChannel']?.toString();
    if (channel != null) {
      final c = UpdateReleaseChannel.values
          .where((e) => e.name == channel)
          .firstOrNull;
      if (c != null) await settings.setUpdateReleaseChannel(c);
    }
    await applyBool('betaBannerDismissed', settings.setBetaBannerDismissed);

    final shortcutsJson = s['inAppShortcutsJson']?.toString();
    if (shortcutsJson != null && shortcutsJson.isNotEmpty) {
      await settings.applyInAppShortcutsJson(shortcutsJson);
    }
    await applyString('jiraOAuthClientId', settings.setJiraOAuthClientId);

    final approvedRaw = s['approvedIntegrationApps'];
    if (approvedRaw is Map) {
      for (final e in approvedRaw.entries) {
        final appId = '${e.key}'.trim();
        if (appId.isEmpty) continue;
        final approval = IntegrationAppApproval.fromStored(appId, e.value);
        await settings.approveIntegrationApp(
          appId: approval.appId,
          appName: approval.appName,
          appVersion: approval.appVersion,
          integrationVersion: approval.integrationVersion,
        );
      }
    }

    await applyBool('enterCreatesNewBlock', settings.setEnterCreatesNewBlock);
    final recent = s['recentSearchQueries'];
    if (recent is List) {
      await settings.replaceRecentSearchQueries(
        recent.map((e) => '$e').toList(),
      );
    }
    await applyBool('telemetryEnabled', settings.setTelemetryEnabled);
    await applyBool('autoCrashReports', settings.setAutoCrashReports);
    await applyBool(
      'driveDeleteOriginalsOnUpload',
      settings.setDriveDeleteOriginalsOnUpload,
    );

    await applyDouble('editorContentWidth', settings.setEditorContentWidth);
    await applyDouble(
      'workspaceSidebarWidth',
      settings.setWorkspaceSidebarWidth,
    );
    await applyBool(
      'workspaceSidebarCollapsed',
      settings.setWorkspaceSidebarCollapsed,
    );
    await applyBool(
      'workspaceSidebarAutoReveal',
      settings.setWorkspaceSidebarAutoReveal,
    );
    await applyBool(
      'workspaceSidebarShowRecentPages',
      settings.setWorkspaceSidebarShowRecentPages,
    );
    await applyBool(
      'workspaceSidebarRecentPagesCollapsed',
      settings.setWorkspaceSidebarRecentPagesCollapsed,
    );
    await applyBool('workspaceOpenToHome', settings.setWorkspaceOpenToHome);
    await applyBool(
      'workspacePageOutlineVisible',
      settings.setWorkspacePageOutlineVisible,
    );
    await applyBool(
      'workspaceBacklinksVisible',
      settings.setWorkspaceBacklinksVisible,
    );
    await applyBool(
      'workspaceCommentsVisible',
      settings.setWorkspaceCommentsVisible,
    );
    await applyBool(
      'workspaceHomeShowFolioCloudCard',
      settings.setWorkspaceHomeShowFolioCloudCard,
    );
    await applyBool(
      'workspaceHomeShowRootPages',
      settings.setWorkspaceHomeShowRootPages,
    );
    await applyBool(
      'workspaceHomeShowMiniStats',
      settings.setWorkspaceHomeShowMiniStats,
    );
    await applyBool(
      'workspaceHomeShowTasksSection',
      settings.setWorkspaceHomeShowTasksSection,
    );
    await applyBool(
      'workspaceHomeShowQuickActions',
      settings.setWorkspaceHomeShowQuickActions,
    );
    await applyBool('workspaceHomeShowTip', settings.setWorkspaceHomeShowTip);
    await applyBool(
      'workspaceHomeShowVaultStatus',
      settings.setWorkspaceHomeShowVaultStatus,
    );
    await applyBool(
      'workspaceHomeShowOnboarding',
      settings.setWorkspaceHomeShowOnboarding,
    );
    await applyBool(
      'workspaceHomeShowWhatsNew',
      settings.setWorkspaceHomeShowWhatsNew,
    );
    final col = s['workspaceHomeColumnLayout']?.toString();
    if (col != null) {
      final m = WorkspaceHomeColumnLayout.values
          .where((e) => e.name == col)
          .firstOrNull;
      if (m != null) await settings.setWorkspaceHomeColumnLayout(m);
    }
    await applyBool(
      'workspaceHomeClockShowSeconds',
      settings.setWorkspaceHomeClockShowSeconds,
    );
    await applyBool(
      'workspaceHomeClock24Hour',
      settings.setWorkspaceHomeClock24Hour,
    );
    await applyBool(
      'workspaceHomeClockShowTimezone',
      settings.setWorkspaceHomeClockShowTimezone,
    );
    await applyString(
      'workspaceHomeWhatsNewDismissedVersion',
      settings.setWorkspaceHomeWhatsNewDismissedForVersion,
    );
    final leftOrder = s['workspaceHomeLeftSectionOrder'];
    if (leftOrder is List) {
      await settings.setWorkspaceHomeLeftSectionOrder(
        leftOrder.map((e) => '$e').toList(),
      );
    }
    final rightOrder = s['workspaceHomeRightSectionOrder'];
    if (rightOrder is List) {
      await settings.setWorkspaceHomeRightSectionOrder(
        rightOrder.map((e) => '$e').toList(),
      );
    }
    await applyBool('aiChatPanelCollapsed', settings.setAiChatPanelCollapsed);
    await applyDouble('aiChatPanelWidth', settings.setAiChatPanelWidth);
    await applyDouble('aiChatPanelHeight', settings.setAiChatPanelHeight);
    await applyBool('aiChatSplitView', settings.setAiChatSplitView);
    await applyBool(
      'aiQuillCopilotExperimental',
      settings.setAiQuillCopilotExperimental,
    );
    await applyBool('syncEnabled', settings.setSyncEnabled);
    await applyBool('syncRelayEnabled', settings.setSyncRelayEnabled);
    await applyString('syncDeviceName', settings.setSyncDeviceName);
    await applyBool(
      'cloudDeviceSyncEnabled',
      settings.setCloudDeviceSyncEnabled,
    );
    await applyBool(
      'cloudAppProfileSyncEnabled',
      settings.setCloudAppProfileSyncEnabled,
    );
    await applyString(
      'meetingNoteMicDeviceId',
      settings.setMeetingNoteMicDeviceId,
    );
    await applyString(
      'meetingNoteSystemDeviceId',
      settings.setMeetingNoteSystemDeviceId,
    );
    await applyString('meetingNoteModelId', settings.setMeetingNoteModelId);
    await applyBool(
      'meetingNoteAutoWhisperModel',
      settings.setMeetingNoteAutoWhisperModel,
    );
    await applyBool(
      'meetingNoteForceLocalTranscription',
      settings.setMeetingNoteForceLocalTranscription,
    );

    final apiKey = secrets['aiApiKey'];
    if (apiKey != null) await settings.setAiApiKey(apiKey);
    final mcpToken = secrets['mcpServerAuthToken'];
    if (mcpToken != null) await settings.setMcpServerAuthToken(mcpToken);

    for (final ref in profile.icons) {
      final path = localIconPathsById[ref.id];
      if (path == null || path.isEmpty) continue;
      await settings.addOrUpdateCustomIcon(
        CustomIconEntry(
          id: ref.id,
          label: ref.label,
          source: ref.source,
          filePath: path,
          mimeType: ref.mimeType,
          createdAtMs: ref.createdAtMs,
        ),
      );
    }
    for (final e in profile.integrationIconsByApp.entries) {
      final list = <CustomIconEntry>[];
      for (final ref in e.value) {
        final path = localIconPathsById[ref.id];
        if (path == null || path.isEmpty) continue;
        list.add(
          CustomIconEntry(
            id: ref.id,
            label: ref.label,
            source: ref.source,
            filePath: path,
            mimeType: ref.mimeType,
            createdAtMs: ref.createdAtMs,
          ),
        );
      }
      if (list.isNotEmpty) {
        await settings.replaceIntegrationCustomIconsForApp(e.key, list);
      }
    }
  }

  Future<void> applyVaultProfile({
    required AppSettings settings,
    required FolioSettingsProfile profile,
    SecureCredentialStorage? credentials,
  }) async {
    if (profile.kind != FolioSettingsProfileKind.vault) {
      throw ArgumentError('Se esperaba perfil de libreta');
    }
    final vid = (profile.vaultId ?? '').trim();
    if (vid.isEmpty) throw ArgumentError('vaultId vacío');

    final backupRaw = profile.settings['backup'];
    if (backupRaw is Map) {
      final prefs = VaultBackupPrefs.fromJson(
        Map<String, Object?>.from(backupRaw),
      );
      await settings.updateVaultBackupPrefs(vid, prefs);
    }

    final workspace = profile.settings['workspace'];
    if (workspace is Map) {
      final p = await SharedPreferences.getInstance();
      final anchor = workspace['homeOnboardAnchor'];
      if (anchor is String && anchor.isNotEmpty) {
        await p.setString(WorkspacePrefsKeys.homeOnboardAnchor(vid), anchor);
      }
      final dismissed = workspace['homeOnboardDismissed'];
      if (dismissed is bool) {
        await p.setBool(WorkspacePrefsKeys.homeOnboardDismissed(vid), dismissed);
      }
      final guest = workspace['homeCloudGuestDismiss'];
      if (guest is bool) {
        await p.setBool(WorkspacePrefsKeys.homeCloudGuestDismiss(vid), guest);
      }
      final explore = workspace['homeOnboardCloudExploreDone'];
      if (explore is bool) {
        await p.setBool(
          WorkspacePrefsKeys.homeOnboardCloudExploreDone(vid),
          explore,
        );
      }
      final lastPage = workspace['lastSelectedPageId'];
      if (lastPage is String && lastPage.isNotEmpty) {
        await p.setString('folio_last_selected_page_$vid', lastPage);
      }
      final inbox = workspace['taskInboxPageId'];
      if (inbox is String) {
        await settings.setTaskInboxPageId(vid, inbox);
      }
      final aliases = workspace['taskAliasPageMap'];
      if (aliases is Map) {
        final map = <String, String>{};
        for (final e in aliases.entries) {
          map['${e.key}'] = '${e.value}';
        }
        await settings.setTaskAliasPageMap(vid, map);
      }
    }

    final creds = credentials ?? SecureCredentialStorage();
    final folderPw = profile.secrets['backupFolderPassword'];
    if (folderPw != null && folderPw.isNotEmpty) {
      await creds.writePassword(vid, BackupCredentialScope.folder, folderPw);
    }
    final webdavPw = profile.secrets['backupWebdavPassword'];
    if (webdavPw != null && webdavPw.isNotEmpty) {
      await creds.writePassword(vid, BackupCredentialScope.webdav, webdavPw);
    }
  }
}
