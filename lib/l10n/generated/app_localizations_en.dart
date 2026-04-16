// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Folio';

  @override
  String get loading => 'Loading…';

  @override
  String get newVault => 'New vault';

  @override
  String stepOfTotal(int current, int total) {
    return 'Step $current of $total';
  }

  @override
  String get back => 'Back';

  @override
  String get continueAction => 'Continue';

  @override
  String get cancel => 'Cancel';

  @override
  String get retry => 'Retry';

  @override
  String get settings => 'Settings';

  @override
  String get lockNow => 'Lock';

  @override
  String get pageHistory => 'Page history';

  @override
  String get untitled => 'Untitled';

  @override
  String get noPages => 'No pages';

  @override
  String get createPage => 'Create page';

  @override
  String get selectPage => 'Select a page';

  @override
  String get saveInProgress => 'Saving…';

  @override
  String get savePending => 'Pending save';

  @override
  String get savingVaultTooltip => 'Saving encrypted vault to disk…';

  @override
  String get autosaveSoonTooltip => 'Autosave in a moment…';

  @override
  String get welcomeTitle => 'Welcome';

  @override
  String get welcomeBody =>
      'Folio stores your pages only on this device, encrypted with a master password. If you forget it, we cannot recover your data.\n\nThere is no cloud sync.';

  @override
  String get createNewVault => 'Create new vault';

  @override
  String get importBackupZip => 'Import backup (.zip)';

  @override
  String get importBackupTitle => 'Import backup';

  @override
  String get importBackupBody =>
      'The file contains the same encrypted data as the other device. You need the master password used to create that backup.\n\nPasskey and quick unlock (Hello) are not included and are not transferable; you can configure them later in Settings.';

  @override
  String get chooseZipFile => 'Choose .zip file';

  @override
  String get changeFile => 'Change file';

  @override
  String get backupPasswordLabel => 'Backup password';

  @override
  String get backupPlainNoPasswordHint =>
      'This backup is not encrypted. No password is required to import it.';

  @override
  String get importVault => 'Import vault';

  @override
  String get masterPasswordTitle => 'Your master password';

  @override
  String masterPasswordHint(int min) {
    return 'At least $min characters. You will use it every time you open Folio.';
  }

  @override
  String get createStarterPagesTitle => 'Create starter help pages';

  @override
  String get createStarterPagesBody =>
      'Adds a small guide with examples, shortcuts, and Folio capabilities. You can delete those pages later.';

  @override
  String get passwordLabel => 'Password';

  @override
  String get confirmPasswordLabel => 'Confirm password';

  @override
  String get next => 'Next';

  @override
  String get readyTitle => 'All set';

  @override
  String get readyBody =>
      'An encrypted vault will be created on this device. Later you can add Windows Hello, biometrics, or a passkey for faster unlock (Settings).';

  @override
  String get quillIntroTitle => 'Meet Quill';

  @override
  String get quillIntroBody =>
      'Quill is Folio\'s built-in assistant. It can help you write, edit, and understand your pages, and also answer questions about how to use the app.';

  @override
  String get quillIntroCapabilityWrite =>
      'It can draft, summarize, or rewrite content inside your pages.';

  @override
  String get quillIntroCapabilityExplain =>
      'It also answers questions about Folio, shortcuts, blocks, and how to organize your notes.';

  @override
  String get quillIntroCapabilityContext =>
      'You can let it use the current page as context or choose multiple reference pages.';

  @override
  String get quillIntroCapabilityExamples =>
      'The best part: talk naturally to it and Quill will decide whether to answer or edit.';

  @override
  String get quillIntroExamplesTitle => 'Quick examples';

  @override
  String get quillIntroExampleOne => 'Summarize this page in three bullets.';

  @override
  String get quillIntroExampleTwo =>
      'Change the title and improve the introduction.';

  @override
  String get quillIntroExampleThree => 'How do I add an image or a table?';

  @override
  String get quillIntroFootnote =>
      'If AI is not enabled yet, you can activate it later. This intro is here so you understand what Quill can do when you use it.';

  @override
  String get createVault => 'Create vault';

  @override
  String minCharactersError(int min) {
    return 'Minimum $min characters.';
  }

  @override
  String get passwordMismatchError => 'Passwords do not match.';

  @override
  String get passwordMustBeStrongError =>
      'Password must be Strong to continue.';

  @override
  String get passwordStrengthLabel => 'Strength';

  @override
  String get passwordStrengthVeryWeak => 'Very weak';

  @override
  String get passwordStrengthWeak => 'Weak';

  @override
  String get passwordStrengthFair => 'Fair';

  @override
  String get passwordStrengthStrong => 'Strong';

  @override
  String get showPassword => 'Show password';

  @override
  String get hidePassword => 'Hide password';

  @override
  String get chooseZipError => 'Choose a .zip file.';

  @override
  String get enterBackupPasswordError => 'Enter the backup password.';

  @override
  String importFailedError(Object error) {
    return 'Could not import: $error';
  }

  @override
  String createVaultFailedError(Object error) {
    return 'Could not create vault: $error';
  }

  @override
  String get encryptedVault => 'Encrypted vault';

  @override
  String get unlock => 'Unlock';

  @override
  String get quickUnlock => 'Hello / biometrics';

  @override
  String get passkey => 'Passkey';

  @override
  String get unlockFailed => 'Incorrect password or damaged vault.';

  @override
  String get appearance => 'Appearance';

  @override
  String get security => 'Security';

  @override
  String get vaultBackup => 'Vault backup';

  @override
  String get data => 'Data';

  @override
  String get systemTheme => 'System';

  @override
  String get lightTheme => 'Light';

  @override
  String get darkTheme => 'Dark';

  @override
  String get language => 'Language';

  @override
  String get useSystemLanguage => 'Use system language';

  @override
  String get spanishLanguage => 'Spanish';

  @override
  String get englishLanguage => 'English';

  @override
  String get brazilianPortugueseLanguage => 'Portuguese (Brazil)';

  @override
  String get catalanLanguage => 'Catalan / Valencian';

  @override
  String get galicianLanguage => 'Galician';

  @override
  String get basqueLanguage => 'Basque';

  @override
  String get active => 'Active';

  @override
  String get inactive => 'Inactive';

  @override
  String get remove => 'Remove';

  @override
  String get enable => 'Enable';

  @override
  String get register => 'Register';

  @override
  String get revoke => 'Revoke';

  @override
  String get save => 'Save';

  @override
  String get delete => 'Delete';

  @override
  String get rename => 'Rename';

  @override
  String get change => 'Change';

  @override
  String get importAction => 'Import';

  @override
  String get masterPassword => 'Master password';

  @override
  String get confirmIdentity => 'Confirm identity';

  @override
  String get quickUnlockTitle => 'Quick unlock (Hello / biometrics)';

  @override
  String get passkeyThisDevice => 'WebAuthn on this device';

  @override
  String get lockOnMinimize => 'Lock when minimized';

  @override
  String get changeMasterPassword => 'Change master password';

  @override
  String get requiresCurrentPassword => 'Requires current password';

  @override
  String get lockAutoByInactivity => 'Auto-lock after inactivity';

  @override
  String minutesShort(int minutes) {
    return '$minutes min';
  }

  @override
  String get settingsAppearanceHint =>
      'The main color follows the Windows accent color when available.';

  @override
  String get backupFilePasswordLabel => 'Backup file password';

  @override
  String get backupFilePasswordHelper =>
      'Use the master password used to create this backup, not from another device.';

  @override
  String get backupPasswordDialogTitle => 'Backup password';

  @override
  String get currentPasswordLabel => 'Current password';

  @override
  String get newPasswordLabel => 'New password';

  @override
  String get confirmNewPasswordLabel => 'Confirm new password';

  @override
  String passwordStrengthWithValue(Object value) {
    return 'Strength: $value';
  }

  @override
  String get fillAllFieldsError => 'Fill in all fields.';

  @override
  String get newPasswordsMismatchError => 'New passwords do not match.';

  @override
  String get newPasswordMustBeStrongError => 'The new password must be Strong.';

  @override
  String get newPasswordMustDifferError =>
      'The new password must be different.';

  @override
  String get incorrectPasswordError => 'Incorrect password.';

  @override
  String get useHelloBiometrics => 'Use Hello / biometrics';

  @override
  String get usePasskey => 'Use passkey';

  @override
  String get quickUnlockEnabledSnack => 'Quick unlock enabled';

  @override
  String get quickUnlockDisabledSnack => 'Quick unlock disabled';

  @override
  String get quickUnlockEnableFailed => 'Could not enable quick unlock.';

  @override
  String get passkeyRevokeConfirmTitle => 'Remove passkey?';

  @override
  String get passkeyRevokeConfirmBody =>
      'You will need your master password to unlock until you register a new passkey on this device.';

  @override
  String get passkeyRegisteredSnack => 'Passkey registered';

  @override
  String get passkeyRevokedSnack => 'Passkey revoked';

  @override
  String get masterPasswordUpdatedSnack => 'Master password updated';

  @override
  String get backupSavedSuccessSnack => 'Backup saved successfully.';

  @override
  String exportFailedError(Object error) {
    return 'Could not export: $error';
  }

  @override
  String importFailedGenericError(Object error) {
    return 'Could not import: $error';
  }

  @override
  String wipeFailedError(Object error) {
    return 'Could not delete vault: $error';
  }

  @override
  String get filePathReadError => 'Could not read file path.';

  @override
  String get importedVaultSuccessSnack =>
      'Vault imported. It appears in the sidebar vault switcher; the current one remains unchanged.';

  @override
  String get exportVaultDialogTitle => 'Export vault backup';

  @override
  String get exportVaultDialogBody =>
      'To create a backup file, confirm your identity with the currently unlocked vault.';

  @override
  String get verifyAndExport => 'Verify and export';

  @override
  String get saveVaultBackupDialogTitle => 'Save vault backup';

  @override
  String get importVaultDialogTitle => 'Import vault backup';

  @override
  String get importVaultDialogBody =>
      'A new vault will be added from the file. Your currently open vault is not deleted or modified.\n\nThe file password will be the imported vault password (used when opening it after switching vaults).\n\nPasskey and quick unlock (Hello / biometrics) are not included in backups and are not transferable; you can configure them later for that vault.\n\nContinue?';

  @override
  String get verifyAndContinue => 'Verify and continue';

  @override
  String get verifyAndDelete => 'Verify with password and delete';

  @override
  String get importIdentityBody =>
      'Prove it is you with the currently unlocked vault before importing.';

  @override
  String get wipeVaultDialogTitle => 'Delete vault';

  @override
  String get wipeVaultDialogBody =>
      'All pages will be deleted and the master password will no longer be valid. This action cannot be undone.\n\nAre you sure you want to continue?';

  @override
  String get wipeIdentityBody => 'To delete the vault, prove your identity.';

  @override
  String get exportZipTitle => 'Export backup (.zip)';

  @override
  String get exportZipSubtitle =>
      'Password, Hello, or passkey from current vault';

  @override
  String get importZipTitle => 'Import backup (.zip)';

  @override
  String get importZipSubtitle =>
      'Adds a new vault · current identity + file password';

  @override
  String get backupInfoBody =>
      'The file contains the same encrypted data as on disk (vault.keys and vault.bin), without exposing plain content. Attachment images are included as-is.\n\nPasskey and quick unlock are not included in backups and are not transferable between devices; you can set them up again for each imported vault.\n\nImporting adds a new vault; it does not replace the currently open one.';

  @override
  String get wipeCardTitle => 'Delete vault and start over';

  @override
  String get wipeCardSubtitle => 'Requires password, Hello, or passkey.';

  @override
  String get switchVaultTooltip => 'Switch vault';

  @override
  String get switchVaultTitle => 'Switch vault';

  @override
  String get switchVaultBody =>
      'This vault session will be closed and you\'ll need to unlock the other vault with its password, Hello, or passkey (if configured there).';

  @override
  String get renameVaultTitle => 'Rename vault';

  @override
  String get nameLabel => 'Name';

  @override
  String get deleteOtherVaultTitle => 'Delete another vault';

  @override
  String get deleteVaultConfirmTitle => 'Delete vault?';

  @override
  String deleteVaultConfirmBody(Object name) {
    return 'Vault «$name» will be completely deleted. This cannot be undone.';
  }

  @override
  String get vaultDeletedSnack => 'Vault deleted.';

  @override
  String get noOtherVaultsSnack => 'No other vaults to delete.';

  @override
  String get addVault => 'Add vault';

  @override
  String get renameActiveVault => 'Rename active vault';

  @override
  String get deleteOtherVault => 'Delete another vault…';

  @override
  String get activeVaultLabel => 'Active vault';

  @override
  String get sidebarVaultsLoading => 'Loading vaults…';

  @override
  String get sidebarVaultsEmpty => 'No vaults available';

  @override
  String get forceSyncTooltip => 'Force sync';

  @override
  String get searchDialogFooterHint =>
      'Enter opens the highlighted result · Ctrl+↑ / Ctrl+↓ navigate · Esc closes';

  @override
  String get searchFilterTasks => 'Tasks';

  @override
  String get searchRecentQueries => 'Recent searches';

  @override
  String get searchShortcutsHelpTooltip => 'Keyboard shortcuts';

  @override
  String get searchShortcutsHelpTitle => 'Global search';

  @override
  String get searchShortcutsHelpBody =>
      'Enter: open the highlighted result\nCtrl+↑ or Ctrl+↓: previous / next result\nEsc: close';

  @override
  String get renamePageTitle => 'Rename page';

  @override
  String get titleLabel => 'Title';

  @override
  String get rootPage => 'Root';

  @override
  String movePageTitle(Object title) {
    return 'Move “$title”';
  }

  @override
  String get subpage => 'Subpage';

  @override
  String get move => 'Move';

  @override
  String get pages => 'Pages';

  @override
  String get pageOutlineTitle => 'Outline';

  @override
  String get pageOutlineEmpty => 'Add headings (H1–H3) to build the outline.';

  @override
  String get showPageOutline => 'Show outline';

  @override
  String get hidePageOutline => 'Hide outline';

  @override
  String get tocBlockTitle => 'Table of contents';

  @override
  String get showSidebar => 'Show sidebar';

  @override
  String get hideSidebar => 'Hide sidebar';

  @override
  String get resizeSidebarHandle => 'Resize sidebar';

  @override
  String get resizeSidebarHandleHint =>
      'Drag horizontally to change the sidebar width';

  @override
  String get resizeAiPanelHeightHandle => 'Resize assistant height';

  @override
  String get resizeAiPanelHeightHandleHint =>
      'Drag vertically to change the assistant panel height';

  @override
  String get sidebarAutoRevealTitle => 'Peek sidebar from left edge';

  @override
  String get sidebarAutoRevealSubtitle =>
      'When the sidebar is hidden, move the pointer to the left edge to show it temporarily.';

  @override
  String get newRootPageTooltip => 'New page (root)';

  @override
  String get blockOptions => 'Block options';

  @override
  String get meetingNoteTitle => 'Meeting note';

  @override
  String get meetingNoteDesktopOnly => 'Available on desktop only.';

  @override
  String get meetingNoteStartRecording => 'Start recording';

  @override
  String get meetingNotePreparing => 'Preparing…';

  @override
  String get meetingNoteTranscriptionLanguage => 'Transcription language';

  @override
  String get meetingNoteLangAuto => 'Automatic';

  @override
  String get meetingNoteLangEs => 'Spanish';

  @override
  String get meetingNoteLangEn => 'English';

  @override
  String get meetingNoteLangPt => 'Portuguese';

  @override
  String get meetingNoteLangFr => 'French';

  @override
  String get meetingNoteLangIt => 'Italian';

  @override
  String get meetingNoteLangDe => 'German';

  @override
  String get meetingNoteDevicesInSettings =>
      'Input/output devices are configured in Settings > Desktop.';

  @override
  String meetingNoteModelInSettings(Object model) {
    return 'Transcription model: $model (in Settings > Desktop).';
  }

  @override
  String get meetingNoteDescription =>
      'Records microphone and system audio. Transcription is generated locally.';

  @override
  String meetingNoteWhisperInitError(Object error) {
    return 'Could not initialize Whisper: $error';
  }

  @override
  String get meetingNoteAudioAccessError =>
      'Could not access microphone/devices.';

  @override
  String get meetingNoteMicrophoneAccessError => 'Could not access microphone.';

  @override
  String get meetingNoteChunkTranscriptionError =>
      'Could not transcribe this audio chunk.';

  @override
  String get meetingNoteProviderLocal => 'Local (Whisper)';

  @override
  String get meetingNoteProviderCloud => 'Quill Cloud';

  @override
  String get meetingNoteProviderCloudCost => '1 Ink per 5 min. recorded';

  @override
  String get meetingNoteCloudFallbackNotice =>
      'Cloud unavailable. Using local Whisper.';

  @override
  String get meetingNoteCloudInkExhaustedNotice =>
      'Insufficient Ink. Switching to local Whisper.';

  @override
  String meetingNoteCloudRecordingBadge(Object language) {
    return 'Quill Cloud | Language: $language';
  }

  @override
  String get meetingNoteCloudProcessing => 'Processing with Quill Cloud…';

  @override
  String get meetingNoteCloudProcessingSubtitle =>
      'Detecting speakers and improving quality. Please wait.';

  @override
  String meetingNoteCloudProgress(int done, int total) {
    return 'Processed chunks: $done/$total';
  }

  @override
  String meetingNoteCloudEta(Object remaining) {
    return 'Estimated time remaining: $remaining';
  }

  @override
  String get meetingNoteCloudEtaCalculating => 'Calculating remaining time...';

  @override
  String get meetingNoteCloudRequiresAccount =>
      'Requires a Folio Cloud account with Ink.';

  @override
  String get meetingNoteCloudRequiresAiEnabled =>
      'Turn on AI in Settings to use cloud transcription (Quill Cloud).';

  @override
  String meetingNoteHardwareSummary(int cpus, Object ramLabel) {
    return '$cpus cores · $ramLabel';
  }

  @override
  String get meetingNoteHardwareRamUnknown => 'Unknown RAM';

  @override
  String meetingNoteHardwareRecommended(Object modelLabel) {
    return 'Recommended model for this device: $modelLabel';
  }

  @override
  String get meetingNoteLocalTranscriptionNotViable =>
      'This device is below the minimum for local transcription. Only audio will be saved unless you enable “Force local transcription” in Settings or use Quill Cloud with AI enabled.';

  @override
  String get meetingNoteGenerateTranscription => 'Generate transcription';

  @override
  String get meetingNoteGenerateTranscriptionSubtitle =>
      'Turn off to keep audio only for this note.';

  @override
  String get meetingNoteSettingsAutoWhisperModel =>
      'Pick model automatically from hardware';

  @override
  String get meetingNoteSettingsForceLocalTranscription =>
      'Force local transcription (may be slow or unstable)';

  @override
  String get meetingNoteSettingsHardwareIntro =>
      'Detected capability for local transcription.';

  @override
  String get meetingNoteRecordingAudioOnlyBadge => 'Audio only';

  @override
  String get meetingNotePerNoteTranscriptionOffHint =>
      'Transcription is turned off for this note.';

  @override
  String get meetingNoteTranscriptionProvider => 'Transcription engine';

  @override
  String meetingNoteRecordingTime(Object mm, Object ss) {
    return 'Recording  $mm:$ss';
  }

  @override
  String meetingNoteRecordingBadge(Object language, Object model) {
    return 'Language: $language | Model: $model';
  }

  @override
  String get meetingNoteSystemAudioCaptured => 'System audio captured';

  @override
  String get meetingNoteStop => 'Stop';

  @override
  String get meetingNoteWaitingTranscription => 'Waiting for transcription…';

  @override
  String get meetingNoteTranscribing => 'Transcribing…';

  @override
  String get meetingNoteTranscriptionTitle => 'Transcription';

  @override
  String get meetingNoteNoTranscription => 'No transcription available.';

  @override
  String get meetingNoteNewRecording => 'New recording';

  @override
  String get meetingNoteSettingsSection => 'Meeting note (audio)';

  @override
  String get meetingNoteSettingsDescription =>
      'These devices are used by default when recording a meeting note.';

  @override
  String get meetingNoteSettingsMicrophone => 'Microphone';

  @override
  String get meetingNoteSettingsRefreshDevices => 'Refresh list';

  @override
  String get meetingNoteSettingsSystemDefault => 'System default';

  @override
  String get meetingNoteSettingsSystemOutput => 'System output (loopback)';

  @override
  String get meetingNoteSettingsModel => 'Transcription model';

  @override
  String get meetingNoteDiarizationHint =>
      '100% local processing on your device.';

  @override
  String get meetingNoteModelTiny => 'Fast';

  @override
  String get meetingNoteModelBase => 'Balanced';

  @override
  String get meetingNoteModelSmall => 'Accurate';

  @override
  String get meetingNoteModelMedium => 'Advanced';

  @override
  String get meetingNoteModelTurbo => 'Best quality';

  @override
  String get meetingNoteCopyTranscript => 'Copy transcript';

  @override
  String get meetingNoteSendToAi => 'Send to AI…';

  @override
  String get meetingNoteAiPayloadLabel => 'What to send to AI?';

  @override
  String get meetingNoteAiPayloadTranscript => 'Transcript only';

  @override
  String get meetingNoteAiPayloadAudio => 'Audio only';

  @override
  String get meetingNoteAiPayloadBoth => 'Transcript + audio';

  @override
  String get meetingNoteAiInstructionHint => 'e.g. summarise the key points';

  @override
  String get meetingNoteAiNoAudio => 'No audio available for this mode';

  @override
  String get meetingNoteAiInstruction => 'Instruction for AI';

  @override
  String get dragToReorder => 'Drag to reorder';

  @override
  String get addBlock => 'Add block';

  @override
  String get blockMentionPageSubtitle => 'Mention page';

  @override
  String get blockTypesSheetTitle => 'Block types';

  @override
  String get blockTypesSheetSubtitle => 'Choose how this block will look';

  @override
  String get blockTypeFilterEmpty => 'Nothing matches your search';

  @override
  String get fileNotFound => 'File not found';

  @override
  String get couldNotLoadImage => 'Could not load image';

  @override
  String get noImageHint => 'No image · use menu ⋮ or button below';

  @override
  String get chooseImage => 'Choose image';

  @override
  String get replaceFile => 'Replace file';

  @override
  String get removeFile => 'Remove file';

  @override
  String get replaceVideo => 'Replace video';

  @override
  String get removeVideo => 'Remove video';

  @override
  String get openExternal => 'Open externally';

  @override
  String get openVideoExternal => 'Open video externally';

  @override
  String get play => 'Play';

  @override
  String get pause => 'Pause';

  @override
  String get mute => 'Mute';

  @override
  String get unmute => 'Unmute';

  @override
  String get fileResolveError => 'Error resolving file';

  @override
  String get videoResolveError => 'Error resolving video';

  @override
  String get fileMissing => 'File not found';

  @override
  String get videoMissing => 'Video not found';

  @override
  String get chooseFile => 'Choose file';

  @override
  String get chooseVideo => 'Choose video';

  @override
  String get noEmbeddedPreview => 'No embedded preview for this type';

  @override
  String get couldNotReadFile => 'Could not read file';

  @override
  String get couldNotLoadVideo => 'Could not load video';

  @override
  String get couldNotPreviewPdf => 'Could not preview PDF';

  @override
  String get openInYoutubeBrowser => 'Open in browser';

  @override
  String get pasteUrlTitle => 'Paste link as';

  @override
  String get pasteAsUrl => 'URL';

  @override
  String get pasteAsEmbed => 'Embed';

  @override
  String get pasteAsBookmark => 'Bookmark';

  @override
  String get pasteAsMention => 'Mention';

  @override
  String get pasteAsUrlSubtitle => 'Insert markdown link in text';

  @override
  String get pasteAsEmbedSubtitle =>
      'Video block with preview (YouTube) or bookmark';

  @override
  String get pasteAsBookmarkSubtitle => 'Card with title and link';

  @override
  String get pasteAsMentionSubtitle => 'Link to a page in this vault';

  @override
  String get tableAddRow => 'Row';

  @override
  String get tableRemoveRow => 'Remove row';

  @override
  String get tableAddColumn => 'Column';

  @override
  String get tableRemoveColumn => 'Remove col.';

  @override
  String get tablePasteFromClipboard => 'Paste table';

  @override
  String get pickPageForMention => 'Choose page';

  @override
  String get bookmarkTitleHint => 'Title';

  @override
  String get bookmarkOpenLink => 'Open link';

  @override
  String get bookmarkSetUrl => 'Set URL…';

  @override
  String get bookmarkBlockHint => 'Paste a link or use the block menu';

  @override
  String get bookmarkRemove => 'Remove bookmark';

  @override
  String get embedUnavailable =>
      'Embedded web view is not available on this platform. Open the link in your browser.';

  @override
  String get embedOpenBrowser => 'Open in browser';

  @override
  String get embedSetUrl => 'Set embed URL…';

  @override
  String get embedRemove => 'Remove embed';

  @override
  String get embedEmptyHint =>
      'Paste a link or set the URL from the block menu';

  @override
  String get blockSizeSmaller => 'Smaller';

  @override
  String get blockSizeLarger => 'Larger';

  @override
  String get blockSizeHalf => '50%';

  @override
  String get blockSizeThreeQuarter => '75%';

  @override
  String get blockSizeFull => '100%';

  @override
  String get pasteAsEmbedSubtitleWeb =>
      'Show the page inside the block (when supported)';

  @override
  String get pasteAsMentionSubtitleRich =>
      'Link with page title (e.g. YouTube)';

  @override
  String get formatToolbar => 'Format toolbar';

  @override
  String get formatToolbarScrollPrevious => 'Show earlier tools';

  @override
  String get formatToolbarScrollNext => 'Show more tools';

  @override
  String get linkTitle => 'Link';

  @override
  String get visibleTextLabel => 'Visible text';

  @override
  String get urlLabel => 'URL';

  @override
  String get urlHint => 'https://…';

  @override
  String get insert => 'Insert';

  @override
  String get defaultLinkText => 'text';

  @override
  String get boldTip => 'Bold (**)';

  @override
  String get italicTip => 'Italic (_)';

  @override
  String get underlineTip => 'Underline (<u>)';

  @override
  String get inlineCodeTip => 'Inline code (`)';

  @override
  String get strikeTip => 'Strikethrough (~~)';

  @override
  String get linkTip => 'Link';

  @override
  String get pageHistoryTitle => 'Version history';

  @override
  String get restoreVersionTitle => 'Restore version';

  @override
  String get restoreVersionBody =>
      'The page title and content will be replaced with this version. The current state will be saved first in history.';

  @override
  String get restore => 'Restore';

  @override
  String get deleteVersionTitle => 'Delete version';

  @override
  String get deleteVersionBody =>
      'This entry will be removed from history. Current page text does not change.';

  @override
  String get noVersionsYet => 'No versions yet';

  @override
  String get historyAppearsHint =>
      'After you stop typing for a few seconds, change history will appear here.';

  @override
  String get versionControl => 'Version control';

  @override
  String get historyHeaderBody =>
      'The vault saves quickly; history adds an entry when you stop editing and content changed.';

  @override
  String versionsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'versions',
      one: 'version',
    );
    return '$count $_temp0';
  }

  @override
  String get untitledFallback => 'Untitled';

  @override
  String get comparedWithPrevious => 'Compared with previous version';

  @override
  String get changesFromEmptyStart => 'Changes from empty start';

  @override
  String get contentLabel => 'Content';

  @override
  String get titleLabelSimple => 'Title';

  @override
  String get emptyValue => '(empty)';

  @override
  String get noTextChanges => 'No text changes.';

  @override
  String get aiAssistantTitle => 'Quill';

  @override
  String get aiNoPageSelected => 'No page selected';

  @override
  String get aiChatContextDisabledSubtitle => 'Page text not sent to the model';

  @override
  String aiChatContextUsesCurrentPage(Object title) {
    return 'Context: current page ($title)';
  }

  @override
  String get aiChatContextOnePageFallback => 'Context: 1 page';

  @override
  String aiChatContextNPages(int count) {
    return '$count pages in chat context';
  }

  @override
  String get aiChatPageContextTooltip =>
      'Include page text in the model context';

  @override
  String get aiChatChooseContextPagesTooltip =>
      'Choose which pages add text to context';

  @override
  String get aiChatContextPagesDialogTitle => 'Pages in chat context';

  @override
  String get aiChatContextPagesClear => 'Clear list';

  @override
  String get aiChatContextPagesApply => 'Apply';

  @override
  String get aiTypingSemantics => 'Quill is typing';

  @override
  String get aiRenameChatTooltip => 'Rename chat';

  @override
  String get aiRenameChatDialogTitle => 'Chat title';

  @override
  String get aiRenameChatLabel => 'Title shown on the tab';

  @override
  String get quillWorkspaceTourTitle => 'Quill can help from here';

  @override
  String get quillWorkspaceTourBodyReady =>
      'Your Quill chat is ready for questions, page edits, and note context workflows.';

  @override
  String get quillWorkspaceTourBodyUnavailable =>
      'Even if it is not active right now, Quill belongs in this workspace and you can enable it later from Settings.';

  @override
  String get quillWorkspaceTourPointsTitle => 'What is worth knowing';

  @override
  String get quillWorkspaceTourPointOne =>
      'It works both as a conversational assistant and as an editor for titles and blocks.';

  @override
  String get quillWorkspaceTourPointTwo =>
      'It can use the current page or multiple pages as context.';

  @override
  String get quillWorkspaceTourPointThree =>
      'If you tap an example below, it will prefill the chat when Quill is available.';

  @override
  String get quillWorkspaceTourExamplesTitle => 'Try prompts like';

  @override
  String get quillWorkspaceTourExampleOne =>
      'Explain how to organize this page.';

  @override
  String get quillWorkspaceTourExampleTwo =>
      'Use these two pages to make a shared summary.';

  @override
  String get quillWorkspaceTourExampleThree =>
      'Rewrite this block in a clearer tone.';

  @override
  String get quillTourDismiss => 'Got it';

  @override
  String get aiExpand => 'Expand';

  @override
  String get aiCollapse => 'Collapse';

  @override
  String get aiDeleteCurrentChat => 'Delete current chat';

  @override
  String get aiNewChat => 'New';

  @override
  String get aiAttach => 'Attach';

  @override
  String get aiChatEmptyHint =>
      'Start a conversation.\nQuill will automatically decide what to do with your message.\nYou can also ask how to use Folio (shortcuts, settings, pages, or this chat).';

  @override
  String get aiChatEmptyFocusComposer => 'Write a message';

  @override
  String get aiInputHint => 'Type your message. Quill will act as an agent.';

  @override
  String get aiInputHintCopilot => 'Type your message...';

  @override
  String get aiContextComposerHint => 'No context added';

  @override
  String get aiContextComposerHelper => 'Use @ to add context';

  @override
  String aiContextCurrentPageChip(Object title) {
    return 'Current page: $title';
  }

  @override
  String get aiContextCurrentPageFallback => 'Current page';

  @override
  String get aiContextAddFile => 'Attach file';

  @override
  String get aiContextAddPage => 'Attach page';

  @override
  String get aiShowPanel => 'Show AI panel';

  @override
  String get aiHidePanel => 'Hide AI panel';

  @override
  String get aiPanelResizeHandle => 'Resize AI panel';

  @override
  String get aiPanelResizeHandleHint =>
      'Drag horizontally to change the assistant panel width';

  @override
  String get importMarkdownPage => 'Import Markdown';

  @override
  String get exportMarkdownPage => 'Export Markdown';

  @override
  String get exportPage => 'Export…';

  @override
  String get workspaceUndoTooltip => 'Undo (Ctrl+Z)';

  @override
  String get workspaceRedoTooltip => 'Redo (Ctrl+Y)';

  @override
  String get workspaceMoreActionsTooltip => 'More actions';

  @override
  String get closeCurrentPage => 'Close current page';

  @override
  String aiErrorWithDetails(Object error) {
    return 'AI error: $error';
  }

  @override
  String get aiServiceUnreachable =>
      'Could not reach the AI service at the configured endpoint. Start Ollama or LM Studio and check the URL.';

  @override
  String get aiLaunchProviderWithApp => 'Open AI app when Folio starts';

  @override
  String get aiLaunchProviderWithAppHint =>
      'Tries to launch Ollama or LM Studio on Windows when the endpoint is localhost. LM Studio may still need its server started manually.';

  @override
  String get aiContextWindowTokens => 'Model context window (tokens)';

  @override
  String get aiContextWindowTokensHint =>
      'Used for the context bar in AI chat. Match your model (e.g. 8192, 131072).';

  @override
  String get aiContextUsageUnavailable =>
      'Token usage was not reported for the last reply.';

  @override
  String aiContextUsageSummary(Object prompt, Object completion) {
    return 'Prompt $prompt · Output $completion';
  }

  @override
  String aiContextUsageTooltip(int window) {
    return 'Last request vs your configured context window ($window tokens).';
  }

  @override
  String get aiChatKeyboardHint => 'Enter to send · Ctrl+Enter for new line';

  @override
  String aiChatInkRemaining(int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$total ink drops left',
      one: '1 ink drop left',
    );
    return '$_temp0';
  }

  @override
  String aiChatInkBreakdownTooltip(int monthly, int purchased) {
    return 'Monthly $monthly · Purchased $purchased';
  }

  @override
  String get aiAgentThought => 'Quill\'s thought';

  @override
  String get aiAlwaysShowThought => 'Always show AI thought';

  @override
  String get aiAlwaysShowThoughtHint =>
      'If disabled, it appears collapsed with an arrow in each message.';

  @override
  String get aiBetaBadge => 'BETA';

  @override
  String get aiBetaEnableTitle => 'AI is in BETA';

  @override
  String get aiBetaEnableBody =>
      'This feature is currently in BETA and may fail or behave unexpectedly.\n\nDo you want to enable it anyway?';

  @override
  String get aiBetaEnableConfirm => 'Enable BETA';

  @override
  String get ai => 'AI';

  @override
  String get aiEnableToggleTitle => 'Enable AI';

  @override
  String get aiProviderLabel => 'Provider';

  @override
  String get aiProviderNone => 'None';

  @override
  String get aiEndpoint => 'Endpoint';

  @override
  String get aiModel => 'Model';

  @override
  String get aiTimeoutMs => 'Timeout (ms)';

  @override
  String get aiAllowRemoteEndpoint => 'Allow remote endpoint';

  @override
  String get aiAllowRemoteEndpointAllowed => 'Remote hosts allowed';

  @override
  String get aiAllowRemoteEndpointLocalhostOnly => 'Localhost only';

  @override
  String get aiAllowRemoteEndpointNotConfirmed =>
      'Remote endpoint access is enabled but has not been confirmed yet.';

  @override
  String get aiConnectToListModels => 'Connect to list models';

  @override
  String aiProviderAutoConfigured(Object provider) {
    return 'AI provider detected and configured: $provider';
  }

  @override
  String get aiSetupAssistantTitle => 'AI setup assistant';

  @override
  String get aiSetupAssistantSubtitle =>
      'Detect and configure Ollama or LM Studio automatically.';

  @override
  String get aiSetupWizardTitle => 'AI setup assistant';

  @override
  String get aiSetupChooseProviderTitle => 'Choose AI provider';

  @override
  String get aiSetupChooseProviderBody =>
      'First choose which provider you want to use. Then we guide you through installation and setup.';

  @override
  String get aiSetupNoProviderTitle => 'No active provider detected';

  @override
  String get aiSetupNoProviderBody =>
      'We could not find Ollama or LM Studio running and reachable.\nFollow the steps to install/start one of them and press Retry.';

  @override
  String get aiSetupOllamaTitle => 'Step 1: Install Ollama';

  @override
  String get aiSetupOllamaBody =>
      'Install Ollama, run the local service, and verify it responds at http://127.0.0.1:11434.';

  @override
  String get aiSetupLmStudioTitle => 'Step 2: Install LM Studio';

  @override
  String get aiSetupLmStudioBody =>
      'Install LM Studio, start its local server, and verify it responds at http://127.0.0.1:1234.';

  @override
  String get aiSetupOpenSettingsHint =>
      'When one provider is operational, press Retry to auto-configure it.';

  @override
  String get aiCompareCloudVsLocalTitle => 'Cloud vs local';

  @override
  String get aiCompareCloudTitle => 'Folio Cloud';

  @override
  String get aiCompareLocalTitle => 'Local (Ollama / LM Studio)';

  @override
  String get aiCompareCloudBulletNoSetup =>
      'No local setup: works after signing in.';

  @override
  String get aiCompareCloudBulletNeedsSub =>
      'Folio Cloud subscription with cloud AI or purchased ink.';

  @override
  String get aiCompareCloudBulletInk =>
      'Uses ink for cloud AI (packs + monthly refill).';

  @override
  String get aiProviderFolioCloudBlockedSnack =>
      'You need an active Folio Cloud plan with cloud AI or purchased ink — see Settings → Folio Cloud.';

  @override
  String get aiCompareLocalBulletPrivacy => 'Local privacy (your machine).';

  @override
  String get aiCompareLocalBulletNoInk => 'No ink: not tied to a balance.';

  @override
  String get aiCompareLocalBulletSetup =>
      'Requires installing and running a provider on localhost.';

  @override
  String get quillGlobalScopeNoticeTitle => 'Quill works across all vaults';

  @override
  String get quillGlobalScopeNoticeBody =>
      'Quill is an app-level setting. If you enable it now, it will be available for any vault on this installation, not just the current one.';

  @override
  String get quillGlobalScopeNoticeConfirm => 'I understand';

  @override
  String get searchByNameOrShortcut => 'Search by name or shortcut…';

  @override
  String get search => 'Search';

  @override
  String get open => 'Open';

  @override
  String get exit => 'Exit';

  @override
  String get trayMenuCloseApplication => 'Close application';

  @override
  String get keyboardShortcutsSection => 'Keyboard (in app)';

  @override
  String get tasksCaptureSettingsSection => 'Tasks (quick capture)';

  @override
  String get taskInboxPageTitle => 'Task inbox page';

  @override
  String get taskInboxPageSubtitle =>
      'Page where quick-captured tasks are appended.';

  @override
  String get taskInboxNone => 'Not set (created on first save)';

  @override
  String get taskInboxDefaultTitle => 'Task inbox';

  @override
  String get taskAliasManageTitle => 'Destination aliases';

  @override
  String get taskAliasManageSubtitle =>
      'End capture with `#tag` or `@tag`. Define the key without the symbol (e.g. work) and the target page.';

  @override
  String get taskAliasAddButton => 'Add alias';

  @override
  String get taskAliasTagLabel => 'Tag';

  @override
  String get taskAliasTargetLabel => 'Page';

  @override
  String get taskAliasDeleteTooltip => 'Remove';

  @override
  String get taskQuickAddTitle => 'Quick add task';

  @override
  String get taskQuickAddHint =>
      'E.g. Buy milk tomorrow high #work. Also: due:2026-04-20, p1, in progress.';

  @override
  String get taskQuickAddConfirm => 'Add';

  @override
  String get taskQuickAddSuccess => 'Task added.';

  @override
  String get taskQuickAddAliasTargetMissing =>
      'The alias target page no longer exists.';

  @override
  String get taskHubTitle => 'All tasks';

  @override
  String get taskHubClose => 'Close view';

  @override
  String get taskHubDashboardHelpTitle => 'Dashboard-style ideas';

  @override
  String get taskHubDashboardHelpBody =>
      'Create a page with a columns block linking list pages per context, or a database block with dates and statuses for a board. Quick capture and this view are inspired by apps like Snippets (snippets.ch).';

  @override
  String get taskHubEmpty => 'No tasks in this vault.';

  @override
  String get taskHubFilterAll => 'All';

  @override
  String get taskHubFilterActive => 'Open';

  @override
  String get taskHubFilterDone => 'Done';

  @override
  String get taskHubFilterDueToday => 'Due today';

  @override
  String get taskHubFilterDueWeek => 'This week';

  @override
  String get taskHubFilterOverdue => 'Overdue';

  @override
  String get taskHubOpen => 'Open';

  @override
  String get taskHubMarkDone => 'Done';

  @override
  String get taskHubIncludeTodos => 'Include checklist items';

  @override
  String get sidebarQuickAddTask => 'Quick task';

  @override
  String get sidebarTaskHub => 'All tasks';

  @override
  String get shortcutTestAction => 'Test';

  @override
  String get shortcutChangeAction => 'Change';

  @override
  String shortcutTestHint(Object combo) {
    return 'With focus outside a text field, “$combo” should work in the workspace.';
  }

  @override
  String get shortcutResetAllTitle => 'Restore default shortcuts';

  @override
  String get shortcutResetAllSubtitle =>
      'Resets all in-app shortcuts to Folio defaults.';

  @override
  String get shortcutResetDoneSnack => 'Shortcuts restored to defaults.';

  @override
  String get desktopSection => 'Desktop';

  @override
  String get globalSearchHotkey => 'Global search hotkey';

  @override
  String get hotkeyCombination => 'Key combination';

  @override
  String get hotkeyAltSpace => 'Alt + Space';

  @override
  String get hotkeyCtrlShiftSpace => 'Ctrl + Shift + Space';

  @override
  String get hotkeyCtrlShiftK => 'Ctrl + Shift + K';

  @override
  String get minimizeToTray => 'Minimize to tray';

  @override
  String get closeToTray => 'Close to tray';

  @override
  String get searchAllVaultHint => 'Search across the entire vault...';

  @override
  String get typeToSearch => 'Type to search';

  @override
  String get noSearchResults => 'No results';

  @override
  String get searchFilterAll => 'All';

  @override
  String get searchFilterTitles => 'Titles';

  @override
  String get searchFilterContent => 'Content';

  @override
  String get searchSortRelevance => 'Relevance';

  @override
  String get searchSortRecent => 'Recent';

  @override
  String get settingsSearchSections => 'Search settings';

  @override
  String get settingsSearchSectionsHint => 'Filter categories in the sidebar';

  @override
  String get scheduledVaultBackupTitle => 'Scheduled encrypted backup';

  @override
  String get scheduledVaultBackupSubtitle =>
      'While the vault is unlocked, Folio automatically backs it up on the chosen interval. Enable folder backup, cloud backup, or both below.';

  @override
  String get scheduledVaultBackupFolderTitle => 'Backup to folder';

  @override
  String get scheduledVaultBackupFolderSubtitle =>
      'Save an encrypted ZIP backup to the configured folder on each interval.';

  @override
  String get scheduledVaultBackupChooseFolder => 'Backup folder';

  @override
  String get scheduledVaultBackupClearFolderTooltip => 'Clear folder';

  @override
  String get scheduledVaultBackupCloudOnlyTitle =>
      'Cloud-only scheduled backups';

  @override
  String get scheduledVaultBackupCloudOnlySubtitle =>
      'Do not write ZIP files to disk. Upload backups to the cloud only.';

  @override
  String get scheduledVaultBackupIntervalLabel => 'Backup interval';

  @override
  String scheduledVaultBackupEveryNMinutes(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n minutes',
      one: '1 minute',
    );
    return '$_temp0';
  }

  @override
  String scheduledVaultBackupEveryNHours(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n hours',
      one: '1 hour',
    );
    return '$_temp0';
  }

  @override
  String scheduledVaultBackupLastRun(Object time) {
    return 'Last backup: $time';
  }

  @override
  String get scheduledVaultBackupSnackOk => 'Scheduled backup saved.';

  @override
  String scheduledVaultBackupSnackFail(Object error) {
    return 'Scheduled backup failed: $error';
  }

  @override
  String vaultBackupOpenVaultHint(String name) {
    return 'Backups are for the vault open right now: “$name”.';
  }

  @override
  String vaultBackupDiskSizeApprox(String size) {
    return 'Approximate size on disk: $size';
  }

  @override
  String get vaultBackupDiskSizeLoading => 'Calculating size on disk…';

  @override
  String get vaultBackupRunNowTile => 'Run scheduled backup now';

  @override
  String get vaultBackupRunNowSubtitle =>
      'Run the scheduled backup now (disk and/or cloud, depending on your settings) without waiting for the interval.';

  @override
  String get vaultBackupRunNowNeedFolder =>
      'Pick a local backup folder, or turn on “Also upload to Folio Cloud” for cloud-only backups.';

  @override
  String get vaultIdentitySyncTitle => 'Synchronization';

  @override
  String get vaultIdentitySyncBody =>
      'Enter your vault password (or Hello / passkey) to continue.';

  @override
  String get vaultIdentityCloudBackupTitle => 'Cloud backups';

  @override
  String get vaultIdentityCloudBackupBody =>
      'Confirm vault identity to list or download encrypted backups.';

  @override
  String get aiRewriteDialogTitle => 'Rewrite with AI';

  @override
  String get aiPreviewTitle => 'Preview';

  @override
  String get aiInstructionHint => 'Example: make it clearer and shorter';

  @override
  String get aiApply => 'Apply';

  @override
  String get aiGenerating => 'Generating…';

  @override
  String get aiSummarizeSelection => 'Summarize with AI…';

  @override
  String get aiExtractTasksDates => 'Extract tasks & dates…';

  @override
  String get aiPreviewReadOnlyHint =>
      'You can edit the text below before applying.';

  @override
  String get aiRewriteApplied => 'Block updated.';

  @override
  String get aiUndoRewrite => 'Undo';

  @override
  String get aiInsertBelow => 'Insert below';

  @override
  String get unlockVaultTitle => 'Unlock vault';

  @override
  String get miniUnlockFailed => 'Could not unlock.';

  @override
  String get importNotionTitle => 'Import from Notion (.zip)';

  @override
  String get importNotionSubtitle => 'Notion ZIP export (Markdown/HTML)';

  @override
  String get importNotionDialogTitle => 'Import from Notion';

  @override
  String get importNotionDialogBody =>
      'Import a ZIP exported by Notion. You can append into the current vault or create a new one.';

  @override
  String get importNotionSelectTargetTitle => 'Import target';

  @override
  String get importNotionSelectTargetBody =>
      'Choose whether to import the Notion export into your current vault or create a new vault from it.';

  @override
  String get importNotionTargetCurrent => 'Current vault';

  @override
  String get importNotionTargetNew => 'New vault';

  @override
  String get importNotionDefaultVaultName => 'Imported from Notion';

  @override
  String get importNotionNewVaultPasswordTitle => 'Password for new vault';

  @override
  String get importNotionSuccessCurrent =>
      'Notion imported into current vault.';

  @override
  String get importNotionSuccessNew => 'New vault imported from Notion.';

  @override
  String importNotionError(Object error) {
    return 'Could not import Notion: $error';
  }

  @override
  String get importNotionWarningsTitle => 'Import warnings';

  @override
  String get importNotionWarningsBody =>
      'The import completed with some warnings:';

  @override
  String get ok => 'OK';

  @override
  String get notionExportGuideTitle => 'How to export from Notion';

  @override
  String get notionExportGuideBody =>
      'In Notion, open Settings -> Export all workspace content, choose HTML or Markdown, and download the ZIP file. Then use this import option in Folio.';

  @override
  String get appBetaBannerMessage =>
      'You are using a beta build. You may run into bugs; back up your vault regularly.';

  @override
  String get appBetaBannerDismiss => 'Got it';

  @override
  String get integrations => 'Integrations';

  @override
  String get integrationsAppsApprovedHint =>
      'Approved external apps can use the local integration bridge.';

  @override
  String get integrationsAppsApprovedTitle => 'Approved external apps';

  @override
  String get integrationsAppsApprovedNone =>
      'You have not approved any external apps yet.';

  @override
  String get integrationsAppsApprovedRevoke => 'Revoke access';

  @override
  String integrationsApprovedAppDetails(
    Object appId,
    Object appVersion,
    Object integrationVersion,
  ) {
    return '$appId · App $appVersion · Integration $integrationVersion';
  }

  @override
  String get integrationApprovalTitle => 'Approve external integration';

  @override
  String get integrationApprovalUpdateTitle => 'Approve updated integration';

  @override
  String integrationApprovalBody(
    Object appName,
    Object appVersion,
    Object integrationVersion,
  ) {
    return '\"$appName\" wants to connect to Folio using app version $appVersion and integration version $integrationVersion.';
  }

  @override
  String integrationApprovalUpdateBody(
    Object appName,
    Object previousVersion,
    Object integrationVersion,
  ) {
    return '\"$appName\" was previously approved with integration version $previousVersion. It now wants to connect with integration version $integrationVersion, so Folio needs your approval again.';
  }

  @override
  String get integrationApprovalUnknownVersion => 'unknown';

  @override
  String get integrationApprovalAppId => 'App ID';

  @override
  String get integrationApprovalAppVersion => 'App version';

  @override
  String get integrationApprovalProtocolVersion => 'Integration version';

  @override
  String get integrationApprovalCanDoTitle => 'What this integration can do';

  @override
  String get integrationApprovalCanDoSessions =>
      'Create short-lived import sessions in Folio.';

  @override
  String get integrationApprovalCanDoImport =>
      'Send Markdown documentation to create or update pages through the import bridge.';

  @override
  String get integrationApprovalCanDoMetadata =>
      'Store import provenance such as the client app, session, and source metadata on imported pages.';

  @override
  String get integrationApprovalCanDoUnlockedVault =>
      'Import only while the vault is available and the request includes the configured secret.';

  @override
  String get integrationApprovalCannotDoTitle => 'What it cannot do';

  @override
  String get integrationApprovalCannotDoRead =>
      'It cannot read your vault contents through this bridge.';

  @override
  String get integrationApprovalCannotDoBypassLock =>
      'It cannot bypass the vault lock, encryption, or your explicit approval.';

  @override
  String get integrationApprovalCannotDoWithoutSecret =>
      'It cannot access protected endpoints without the shared secret.';

  @override
  String get integrationApprovalCannotDoRemoteAccess =>
      'It cannot use the bridge from outside localhost.';

  @override
  String get integrationApprovalEncryptedChip => 'Encrypted content (v2)';

  @override
  String get integrationApprovalUnencryptedChip => 'Unencrypted content (v1)';

  @override
  String get integrationApprovalEncryptedTitle =>
      'Version 2: mandatory content encryption';

  @override
  String get integrationApprovalEncryptedDescription =>
      'This version requires encrypted payloads to import and update content through the local bridge.';

  @override
  String get integrationApprovalUnencryptedTitle =>
      'Version 1: unencrypted content';

  @override
  String get integrationApprovalUnencryptedDescription =>
      'This version allows plaintext payloads for content. If you need transport encryption, upgrade the integration to version 2.';

  @override
  String get integrationApprovalDeny => 'Deny';

  @override
  String get integrationApprovalApprove => 'Approve';

  @override
  String get integrationApprovalApproveUpdate => 'Approve this update';

  @override
  String get about => 'About';

  @override
  String get installedVersion => 'Installed version';

  @override
  String get updaterGithubRepository => 'Update repository';

  @override
  String get updaterBetaDescription =>
      'Betas are GitHub releases marked as pre-release.';

  @override
  String get updaterStableDescription =>
      'Only the latest stable release is considered.';

  @override
  String get checkUpdates => 'Check for updates';

  @override
  String get noEncryptionConfirmTitle => 'Create vault without encryption';

  @override
  String get noEncryptionConfirmBody =>
      'Your data will be stored without a password and without encryption. Anyone with access to this device can read it.';

  @override
  String get createVaultWithoutEncryption => 'Create without encryption';

  @override
  String get plainVaultSecurityNotice =>
      'This vault is not encrypted. Passkey, quick unlock (Hello), auto-lock after idle time, lock on minimize, and master password do not apply.';

  @override
  String get encryptPlainVaultTitle => 'Encrypt this vault';

  @override
  String get encryptPlainVaultBody =>
      'Choose a master password. All data on this device will be encrypted. If you forget it, your data cannot be recovered.';

  @override
  String get encryptPlainVaultConfirm => 'Encrypt vault';

  @override
  String get encryptPlainVaultSuccessSnack => 'Vault is now encrypted';

  @override
  String get aiCopyMessage => 'Copy';

  @override
  String get aiCopyCode => 'Copy code';

  @override
  String get aiCopiedToClipboard => 'Copied to clipboard';

  @override
  String get aiHelpful => 'Helpful';

  @override
  String get aiNotHelpful => 'Not helpful';

  @override
  String get aiThinkingMessage => 'Quill is thinking...';

  @override
  String get aiMessageTimestampNow => 'now';

  @override
  String aiMessageTimestampMinutes(int n) {
    return '$n min ago';
  }

  @override
  String aiMessageTimestampHours(int n) {
    return '$n h ago';
  }

  @override
  String aiMessageTimestampDays(int n) {
    return '$n days ago';
  }

  @override
  String get templateGalleryTitle => 'Page Templates';

  @override
  String get templateImport => 'Import';

  @override
  String get templateImportPickTitle => 'Select a template file';

  @override
  String get templateImportSuccess => 'Template imported';

  @override
  String templateImportError(Object error) {
    return 'Error importing: $error';
  }

  @override
  String get templateExportPickTitle => 'Save template file';

  @override
  String get templateExportSuccess => 'Template exported';

  @override
  String templateExportError(Object error) {
    return 'Error exporting: $error';
  }

  @override
  String get templateSearchHint => 'Search templates...';

  @override
  String get templateEmptyHint =>
      'No templates yet.\nSave a page as a template or import one.';

  @override
  String templateBlockCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'blocks',
      one: 'block',
    );
    return '$count $_temp0';
  }

  @override
  String get templateUse => 'Use template';

  @override
  String get templateExport => 'Export';

  @override
  String get templateBlankPage => 'Blank page';

  @override
  String get templateFromGallery => 'From template…';

  @override
  String get saveAsTemplate => 'Save as template';

  @override
  String get saveAsTemplateTitle => 'Save as template';

  @override
  String get templateNameHint => 'Template name';

  @override
  String get templateDescriptionHint => 'Description (optional)';

  @override
  String get templateCategoryHint => 'Category (optional)';

  @override
  String get templateSaved => 'Saved as template';

  @override
  String templateCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'templates',
      one: 'template',
    );
    return '$count $_temp0';
  }

  @override
  String templateFilteredCount(int visible, int total) {
    return 'Showing $visible of $total templates';
  }

  @override
  String get templateSortRecent => 'Newest';

  @override
  String get templateSortName => 'Name';

  @override
  String get templateEdit => 'Edit template';

  @override
  String get templateUpdated => 'Template updated';

  @override
  String get templateDeleteConfirmTitle => 'Delete template';

  @override
  String templateDeleteConfirmBody(Object name) {
    return 'Template \"$name\" will be removed from this vault.';
  }

  @override
  String templateCreatedOn(Object date) {
    return 'Created $date';
  }

  @override
  String get templatePreviewEmpty => 'This template has no text preview yet.';

  @override
  String get templateSelectHint =>
      'Select a template to inspect it, edit its metadata, or export it.';

  @override
  String get templateGalleryTabLocal => 'Local';

  @override
  String get templateGalleryTabCommunity => 'Community';

  @override
  String get templateCommunitySignInCta =>
      'Sign in to share and browse community templates.';

  @override
  String get templateCommunitySignInButton => 'Sign in';

  @override
  String get templateCommunityUnavailable =>
      'Community templates require Firebase. Check your connection or configuration.';

  @override
  String get templateCommunityEmpty =>
      'No community templates yet. Be the first to share one from the Local tab.';

  @override
  String templateCommunityLoadError(Object error) {
    return 'Could not load community templates: $error';
  }

  @override
  String get templateCommunityRetry => 'Retry';

  @override
  String get templateCommunityRefresh => 'Refresh';

  @override
  String get templateCommunityShareTitle => 'Share to community';

  @override
  String get templateCommunityShareBody =>
      'Your template will be public for anyone to view and download. Remove personal or confidential content before sharing.';

  @override
  String get templateCommunityShareConfirm => 'Share';

  @override
  String get templateCommunityShareSuccess =>
      'Template shared with the community';

  @override
  String templateCommunityShareError(Object error) {
    return 'Could not share: $error';
  }

  @override
  String get templateCommunityAddToVault => 'Save to my templates';

  @override
  String get templateCommunityAddedToVault => 'Saved to your templates';

  @override
  String get templateCommunityDeleteTitle => 'Remove from community';

  @override
  String templateCommunityDeleteBody(Object name) {
    return 'Delete \"$name\" from the community store? This cannot be undone.';
  }

  @override
  String get templateCommunityDeleteSuccess => 'Removed from community';

  @override
  String templateCommunityDeleteError(Object error) {
    return 'Could not remove: $error';
  }

  @override
  String templateCommunityDownloadError(Object error) {
    return 'Could not download template: $error';
  }

  @override
  String get clear => 'Clear';

  @override
  String get cloudAccountSectionTitle => 'Folio Cloud account';

  @override
  String get cloudAccountSectionDescription =>
      'Optional. Sign in to subscribe to cloud backup, hosted AI, and web publishing. Your vault stays local unless you use those features.';

  @override
  String get cloudAccountChipOptional => 'Optional';

  @override
  String get cloudAccountChipPaidCloud => 'Backups, AI & web';

  @override
  String get cloudAccountUnavailable =>
      'Cloud sign-in is unavailable (Firebase did not start). Check your connection or run flutterfire configure with your project.';

  @override
  String get cloudAccountEmailLabel => 'Email';

  @override
  String get cloudAccountPasswordLabel => 'Password';

  @override
  String get cloudAccountSignIn => 'Sign in';

  @override
  String get cloudAccountCreateAccount => 'Create account';

  @override
  String get cloudAccountForgotPassword => 'Forgot password?';

  @override
  String get cloudAccountSignOut => 'Sign out';

  @override
  String cloudAccountSignedInAs(Object email) {
    return 'Signed in as $email';
  }

  @override
  String cloudAccountUid(Object uid) {
    return 'User ID: $uid';
  }

  @override
  String get cloudAuthDialogTitleSignIn => 'Sign in to Folio Cloud';

  @override
  String get cloudAuthDialogTitleRegister => 'Create Folio Cloud account';

  @override
  String get cloudAuthDialogTitleReset => 'Reset password';

  @override
  String get cloudPasswordResetSent =>
      'If an account exists for that email, a reset link was sent.';

  @override
  String get cloudAuthErrorInvalidEmail => 'That email address is not valid.';

  @override
  String get cloudAuthErrorWrongPassword => 'Wrong password.';

  @override
  String get cloudAuthErrorUserNotFound => 'No account found for that email.';

  @override
  String get cloudAuthErrorUserDisabled => 'This account has been disabled.';

  @override
  String get cloudAuthErrorEmailAlreadyInUse =>
      'That email is already registered.';

  @override
  String get cloudAuthErrorWeakPassword => 'Password is too weak.';

  @override
  String get cloudAuthErrorInvalidCredential => 'Invalid email or password.';

  @override
  String get cloudAuthErrorNetwork => 'Network error. Check your connection.';

  @override
  String get cloudAuthErrorTooManyRequests =>
      'Too many attempts. Try again later.';

  @override
  String get cloudAuthErrorOperationNotAllowed =>
      'This sign-in method is not enabled in Firebase.';

  @override
  String get cloudAuthErrorGeneric => 'Sign-in failed. Try again.';

  @override
  String get cloudAuthDialogTitle => 'Folio Cloud';

  @override
  String get cloudAuthSubtitleSignIn =>
      'Use your Folio Cloud email and password. Nothing here changes your local vault.';

  @override
  String get cloudAuthSubtitleRegister =>
      'Create Folio Cloud credentials. Your notes on this device are not uploaded until you enable backups or other paid features.';

  @override
  String get cloudAuthModeSignIn => 'Sign in';

  @override
  String get cloudAuthModeRegister => 'Register';

  @override
  String get cloudAuthConfirmPasswordLabel => 'Confirm password';

  @override
  String get cloudAuthValidationRequired => 'This field is required.';

  @override
  String get cloudAuthValidationPasswordShort => 'Use at least 6 characters.';

  @override
  String get cloudAuthValidationConfirmMismatch => 'Passwords do not match.';

  @override
  String get cloudAccountSignedOutPrompt =>
      'Sign in or register to subscribe to Folio Cloud and use backups, cloud AI, and publishing.';

  @override
  String get cloudAuthResetHint =>
      'We will email you a link to set a new password.';

  @override
  String get cloudAccountEmailVerified => 'Verified';

  @override
  String get cloudAccountSignOutHelp =>
      'Your local vault stays on this device.';

  @override
  String get cloudAccountEmailUnverifiedBanner =>
      'Verify your email to secure your Folio Cloud account.';

  @override
  String get cloudAccountResendVerification => 'Resend verification email';

  @override
  String get cloudAccountReloadVerification => 'I\'ve verified';

  @override
  String get cloudAccountVerificationSent => 'Verification email sent.';

  @override
  String get cloudAccountVerificationStillPending =>
      'Email is still not verified. Open the link in your inbox.';

  @override
  String get cloudAccountVerificationNowVerified => 'Email verified.';

  @override
  String get cloudAccountResetPasswordEmail => 'Reset password by email';

  @override
  String get cloudAccountCopyEmail => 'Copy email';

  @override
  String get cloudAccountEmailCopied => 'Email copied.';

  @override
  String get folioWebPortalSubsectionTitle => 'Web account';

  @override
  String get folioWebPortalLinkCodeLabel => 'Pairing code';

  @override
  String get folioWebPortalLinkHelp =>
      'Generate the code on the web app under Settings → Folio account, then enter it here within about 10 minutes.';

  @override
  String get folioWebPortalLinkButton => 'Link';

  @override
  String get folioWebPortalLinkSuccess => 'Web account linked successfully.';

  @override
  String get folioWebPortalNeedSignIn =>
      'Sign in to Folio Cloud to link your web account.';

  @override
  String get folioWebMirrorNote =>
      'Backups, AI, and publishing are still governed by Folio Cloud (Firestore). Below reflects your web account.';

  @override
  String get folioWebEntitlementLinked => 'Web account linked';

  @override
  String get folioWebEntitlementNotLinked => 'Web account not linked';

  @override
  String folioWebEntitlementWebPlan(String value) {
    return 'Folio Cloud (web): $value';
  }

  @override
  String folioWebEntitlementWebStatus(String value) {
    return 'Status (web): $value';
  }

  @override
  String folioWebEntitlementWebPeriodEnd(String value) {
    return 'Period end (web): $value';
  }

  @override
  String folioWebEntitlementWebInk(int count) {
    return 'Ink (web): $count';
  }

  @override
  String get folioWebPortalRefreshWeb => 'Refresh web status';

  @override
  String get folioWebPortalErrorNetwork =>
      'Could not reach the portal. Check your connection.';

  @override
  String get folioWebPortalErrorTimeout =>
      'The portal took too long to respond.';

  @override
  String get folioWebPortalErrorAdminNotConfigured =>
      'Folio Firebase Admin is not configured on the server (check the backend).';

  @override
  String get folioWebPortalErrorUnauthorized =>
      'Session invalid. Sign in to Folio Cloud again.';

  @override
  String get folioWebPortalErrorGeneric =>
      'Could not complete the request to the portal.';

  @override
  String folioWebPortalServerMessage(String message) {
    return '$message';
  }

  @override
  String get folioCloudSubsectionPlan => 'Plan & status';

  @override
  String get folioCloudSubsectionInk => 'Ink balance';

  @override
  String get folioCloudSubsectionSubscription => 'Subscription & billing';

  @override
  String get folioCloudSubsectionBackupPublish => 'Backups & publishing';

  @override
  String get folioCloudSubscriptionActive => 'Subscription active';

  @override
  String folioCloudSubscriptionActiveWithStatus(String status) {
    return 'Subscription active ($status)';
  }

  @override
  String get folioCloudSubscriptionNoneTitle => 'No Folio Cloud subscription';

  @override
  String get folioCloudSubscriptionNoneSubtitle =>
      'Activate a plan for encrypted backup, cloud AI, and web publishing.';

  @override
  String get folioCloudFeatureBackup => 'Cloud backup';

  @override
  String get folioCloudFeatureCloudAi => 'Cloud AI';

  @override
  String get folioCloudFeaturePublishWeb => 'Web publishing';

  @override
  String get folioCloudFeatureOn => 'Included';

  @override
  String get folioCloudFeatureOff => 'Not included';

  @override
  String get folioCloudPostPaymentHint =>
      'If you just paid and features show as off, tap «Refresh from Stripe».';

  @override
  String get folioCloudBackupCleanupWarning =>
      'Backup uploaded, but old backups could not be cleaned up (will be retried later).';

  @override
  String get folioCloudInkMonthly => 'Monthly';

  @override
  String get folioCloudInkPurchased => 'Purchased';

  @override
  String get folioCloudInkTotal => 'Total';

  @override
  String folioCloudInkCount(int count) {
    return '$count';
  }

  @override
  String get folioCloudPlanActiveHeadline => 'Folio Cloud monthly plan active';

  @override
  String get folioCloudSubscribeMonthly => 'Folio Cloud €4.99/mo';

  @override
  String get folioCloudPitchScreenTitle => 'Folio Cloud';

  @override
  String get folioCloudPitchHeadline =>
      'Your vault stays local. The cloud works when you want it.';

  @override
  String get folioCloudPitchSubhead =>
      'One monthly plan unlocks encrypted backups, hosted cloud AI with a monthly ink allowance, and publishing to the web—only for what you choose to share.';

  @override
  String get folioCloudPitchLearnMore => 'See what\'s included';

  @override
  String get folioCloudPitchCtaNeedAccount => 'Sign in or create account';

  @override
  String get folioCloudPitchGuestTeaserTitle => 'Folio Cloud account';

  @override
  String get folioCloudPitchGuestTeaserBody =>
      'Optional account: see what the plan includes, then sign in when you want to subscribe.';

  @override
  String get folioCloudPitchOpenSettingsToSignIn =>
      'Open Settings and sign in to Folio Cloud (Folio Cloud section) to subscribe.';

  @override
  String get folioCloudBuyInk => 'Buy ink';

  @override
  String get folioCloudInkSmall => 'Small ink (€1.99)';

  @override
  String get folioCloudInkMedium => 'Medium ink (€4.99)';

  @override
  String get folioCloudInkLarge => 'Large ink (€9.99)';

  @override
  String get folioCloudManageSubscription => 'Manage subscription';

  @override
  String get folioCloudRefreshFromStripe => 'Refresh';

  @override
  String get folioCloudMicrosoftStoreBillingTitle =>
      'Microsoft Store (Windows)';

  @override
  String get folioCloudMicrosoftStoreBillingSubtitle =>
      'Same subscription and ink packs as Stripe; the Store charges and the server validates. Set product ids via --dart-define and Azure AD on Cloud Functions.';

  @override
  String get folioCloudMicrosoftStoreSubscribeButton => 'Subscribe in Store';

  @override
  String get folioCloudMicrosoftStoreSyncButton => 'Sync with Store';

  @override
  String get folioCloudMicrosoftStoreInkTitle => 'Ink — Microsoft Store';

  @override
  String get folioCloudMicrosoftStoreInkPackSmall => 'Small ink pack (Store)';

  @override
  String get folioCloudMicrosoftStoreInkPackMedium => 'Medium ink pack (Store)';

  @override
  String get folioCloudMicrosoftStoreInkPackLarge => 'Large ink pack (Store)';

  @override
  String get folioCloudMicrosoftStoreSyncedSnack =>
      'Synced with Microsoft Store.';

  @override
  String get folioCloudMicrosoftStoreAppliedSnack =>
      'Purchase applied. If something is missing, tap Sync.';

  @override
  String get folioCloudPurchaseChannelTitle => 'Where do you want to pay?';

  @override
  String get folioCloudPurchaseChannelBody =>
      'Use the Microsoft Store built into Windows, or pay by card in the browser (Stripe). The plan and ink are the same.';

  @override
  String get folioCloudPurchaseChannelMicrosoftStore => 'Microsoft Store';

  @override
  String get folioCloudPurchaseChannelStripe => 'In the browser (Stripe)';

  @override
  String get folioCloudPurchaseChannelCancel => 'Cancel';

  @override
  String get folioCloudPurchaseChannelStoreNotConfigured =>
      'The Store option is not configured in this build (product ids missing).';

  @override
  String get folioCloudPurchaseChannelStoreNotConfiguredHint =>
      'Build with --dart-define=MS_STORE_… or use browser checkout.';

  @override
  String get folioCloudMicrosoftStoreSyncHint =>
      'On Windows, Refresh also syncs the Microsoft Store (same button as Stripe).';

  @override
  String get folioCloudUploadEncryptedBackup => 'Back up to cloud now';

  @override
  String get folioCloudUploadEncryptedBackupSubtitle =>
      'Folio builds an encrypted backup of your open vault and uploads it—no manual ZIP export.';

  @override
  String get folioCloudUploadSnackOk => 'Vault backup saved to the cloud.';

  @override
  String get scheduledVaultBackupCloudSyncTitle => 'Backup to Folio Cloud';

  @override
  String get scheduledVaultBackupCloudSyncSubtitle =>
      'After each scheduled backup interval, automatically uploads an encrypted backup to your Folio Cloud account.';

  @override
  String get folioCloudCloudBackupsList => 'Cloud backups';

  @override
  String get folioCloudBackupsUsed => 'Used';

  @override
  String get folioCloudBackupsLimit => 'Limit';

  @override
  String get folioCloudBackupsRemaining => 'Remaining';

  @override
  String get folioCloudPublishTestPage => 'Publish test page';

  @override
  String get folioCloudPublishedPagesList => 'Published pages';

  @override
  String get folioCloudReauthDialogTitle => 'Confirm Folio Cloud account';

  @override
  String get folioCloudReauthDialogBody =>
      'Enter your Folio Cloud account password (the one you use to sign in to the cloud) to list and download backups. This is not your local vault password.';

  @override
  String get folioCloudReauthRequiresPasswordProvider =>
      'This session does not use a Folio Cloud password. Sign out and sign back in with email and password if you need to download backups.';

  @override
  String get folioCloudAiNoInkTitle => 'No cloud AI ink left';

  @override
  String get folioCloudAiNoInkBody =>
      'Buy an ink bottle under Folio Cloud, wait for your monthly refill, or switch to local AI (Ollama or LM Studio) in the AI section of Settings.';

  @override
  String get folioCloudAiNoInkActionCloud => 'Folio Cloud & ink';

  @override
  String get folioCloudAiNoInkActionLocal => 'AI provider';

  @override
  String get folioCloudAiZeroInkBanner =>
      'Cloud AI ink is 0 — open Settings to buy ink or use local AI.';

  @override
  String folioCloudInkPurchaseAppliedHint(Object purchased) {
    return 'Purchase applied: $purchased purchased ink available for cloud AI.';
  }

  @override
  String get onboardingCloudBackupCta => 'Sign in and download a backup';

  @override
  String get onboardingCloudBackupPickVaultSubtitle =>
      'Choose which vault you want to restore.';

  @override
  String get onboardingFolioCloudTitle => 'Folio Cloud';

  @override
  String get onboardingFolioCloudBody =>
      'Enable cloud features when you need them: encrypted backups, hosted Quill, and web publishing. Your vault stays local unless you use these features.';

  @override
  String get onboardingFolioCloudFeatureBackupTitle =>
      'Encrypted cloud backups';

  @override
  String get onboardingFolioCloudFeatureBackupBody =>
      'Store and download vault backups from your account. On desktop, listing/downloading is handled via Folio Cloud.';

  @override
  String get onboardingFolioCloudFeatureAiTitle => 'Cloud AI + ink';

  @override
  String get onboardingFolioCloudFeatureAiBody =>
      'Hosted Quill with a Folio Cloud subscription (cloud AI) or by purchasing ink only. Ink is consumed by usage; you can also use local AI (Ollama/LM Studio).';

  @override
  String get onboardingFolioCloudFeatureWebTitle => 'Web publishing';

  @override
  String get onboardingFolioCloudFeatureWebBody =>
      'Publish selected pages and control what becomes public. The rest of your vault is not shared.';

  @override
  String get onboardingFolioCloudLaterInSettings => 'I’ll check in Settings';

  @override
  String get collabMenuAction => 'Live collaboration';

  @override
  String get collabSheetTitle => 'Live collaboration';

  @override
  String get collabHeaderSubtitle =>
      'Folio account required. Hosting needs a plan with collaboration; joining only needs a code. Room content and chat are end-to-end encrypted; the server never sees your text.';

  @override
  String get collabNoRoomHint =>
      'Create a room (if your plan includes hosting) or paste the host’s code (emojis + digits).';

  @override
  String get collabCreateRoom => 'Create room';

  @override
  String get collabJoinCodeLabel => 'Room code';

  @override
  String get collabJoinCodeHint => 'e.g. two emojis + 4 digits';

  @override
  String get collabJoinRoom => 'Join';

  @override
  String get collabJoinFailed => 'Invalid code or room is full.';

  @override
  String get collabShareCodeLabel => 'Share this code';

  @override
  String get collabCopyJoinCode => 'Copy code';

  @override
  String get collabCopied => 'Copied';

  @override
  String get collabHostRequiresPlan =>
      'Creating rooms requires Folio Cloud with collaboration (hosting). You can join others’ rooms with a code without that plan.';

  @override
  String get collabChatEmptyHint => 'No messages yet. Say hi to your team.';

  @override
  String get collabMessageHint => 'Type a message…';

  @override
  String get collabArchivedOk => 'Chat archived as page comments.';

  @override
  String get collabArchiveToPage => 'Archive chat to page';

  @override
  String get collabLeaveRoom => 'Leave room';

  @override
  String get collabNeedsJoinCode =>
      'Enter the room code to decrypt this collaboration session.';

  @override
  String get collabMissingJoinCodeHint =>
      'This page is linked to a room but no code is saved here. Paste the host’s code to decrypt content and chat.';

  @override
  String get collabUnlockWithCode => 'Unlock with code';

  @override
  String get collabHidePanel => 'Hide collaboration panel';

  @override
  String get shortcutsCaptureTitle => 'New shortcut';

  @override
  String get shortcutsCaptureHint => 'Press the keys (Esc cancels).';

  @override
  String get updaterStartupDialogTitleStable => 'Update available';

  @override
  String get updaterStartupDialogTitleBeta => 'Beta available';

  @override
  String updaterStartupDialogBody(Object releaseVersion) {
    return 'A new version ($releaseVersion) is available.';
  }

  @override
  String get updaterStartupDialogQuestion =>
      'Do you want to download and install it now?';

  @override
  String get updaterStartupDialogLater => 'Later';

  @override
  String get updaterStartupDialogUpdateNow => 'Update now';

  @override
  String get updaterStartupDialogBetaNote => 'Beta version (pre-release).';

  @override
  String get updaterOpenApkDownloadQuestion => 'Open the APK download now?';

  @override
  String get updaterManualCheckUnsupportedPlatform =>
      'The built-in updater is only available on Windows and Android.';

  @override
  String get updaterManualCheckAlreadyLatest =>
      'You already have the latest version.';

  @override
  String updaterDialogLineCurrentVersion(Object currentVersion) {
    return 'Current version: $currentVersion';
  }

  @override
  String updaterDialogLineNewVersion(Object releaseVersion) {
    return 'New version: $releaseVersion';
  }

  @override
  String get updaterApkUrlInvalidSnack =>
      'No valid APK URL was found in the release.';

  @override
  String get updaterApkOpenFailedSnack => 'Could not open the APK download.';

  @override
  String get toggleTitleHint => 'Toggle title';

  @override
  String get toggleBodyHint => 'Content…';

  @override
  String get taskStatusTodo => 'To do';

  @override
  String get taskStatusInProgress => 'In progress';

  @override
  String get taskStatusDone => 'Done';

  @override
  String get taskPriorityNone => 'No priority';

  @override
  String get taskPriorityLow => 'Low';

  @override
  String get taskPriorityMedium => 'Medium';

  @override
  String get taskPriorityHigh => 'High';

  @override
  String get taskTitleHint => 'Task description…';

  @override
  String get taskPriorityTooltip => 'Priority';

  @override
  String get taskNoDueDate => 'No due date';

  @override
  String get taskSubtaskHint => 'Subtask…';

  @override
  String get taskRemoveSubtask => 'Remove subtask';

  @override
  String get taskAddSubtask => 'Add subtask';

  @override
  String get title => 'Title';

  @override
  String get description => 'Description';

  @override
  String get priority => 'Priority';

  @override
  String get status => 'Status';

  @override
  String get none => 'None';

  @override
  String get low => 'Low';

  @override
  String get medium => 'Medium';

  @override
  String get high => 'High';

  @override
  String get startDate => 'Start date';

  @override
  String get dueDate => 'Due date';

  @override
  String get timeSpentMinutes => 'Time spent (minutes)';

  @override
  String get taskBlocked => 'Blocked';

  @override
  String get taskBlockedReason => 'Block reason';

  @override
  String get subtasks => 'Subtasks';

  @override
  String get add => 'Add';

  @override
  String get templateEmojiLabel => 'Emoji';

  @override
  String aiGenericErrorWithReason(Object reason) {
    return 'AI error: $reason';
  }

  @override
  String get calloutTypeTooltip => 'Callout type';

  @override
  String get calloutTypeInfo => 'Info';

  @override
  String get calloutTypeSuccess => 'Success';

  @override
  String get calloutTypeWarning => 'Warning';

  @override
  String get calloutTypeError => 'Error';

  @override
  String get calloutTypeNote => 'Note';

  @override
  String get blockEditorEnterHintNewBlock =>
      'Enter: new block (in code: Enter = line)';

  @override
  String get blockEditorEnterHintNewLine => 'Enter: new line';

  @override
  String blockEditorShortcutsHintMobile(String enterHint) {
    return '$enterHint · / for blocks · tap a block for more actions';
  }

  @override
  String blockEditorShortcutsHintDesktop(String enterHint) {
    return '$enterHint · Shift+Enter: line · / types · # heading (same line) · - · * · [] · ``` space · table/image under / · format: toolbar on focus or ** _ <u> ` ~~';
  }

  @override
  String blockEditorSelectedBlocksBanner(int count) {
    return '$count blocks selected · Shift: range · Ctrl/Cmd: toggle';
  }

  @override
  String get blockEditorDuplicate => 'Duplicate';

  @override
  String get blockEditorClearSelectionTooltip => 'Clear selection';

  @override
  String get blockEditorMenuRewriteWithAi => 'Rewrite with AI…';

  @override
  String get blockEditorMenuMoveUp => 'Move up';

  @override
  String get blockEditorMenuMoveDown => 'Move down';

  @override
  String get blockEditorMenuDuplicateBlock => 'Duplicate block';

  @override
  String get blockEditorMenuAppearance => 'Appearance…';

  @override
  String get blockEditorMenuCalloutIcon => 'Callout icon…';

  @override
  String blockEditorCalloutMenuType(String typeName) {
    return 'Type: $typeName';
  }

  @override
  String get blockEditorCopyLink => 'Copy link';

  @override
  String get blockEditorMenuCreateSubpage => 'Create subpage';

  @override
  String get blockEditorMenuLinkPage => 'Link page…';

  @override
  String get blockEditorMenuOpenSubpage => 'Open subpage';

  @override
  String get blockEditorMenuPickImage => 'Choose image…';

  @override
  String get blockEditorMenuRemoveImage => 'Remove image';

  @override
  String get blockEditorMenuCodeLanguage => 'Code language…';

  @override
  String get blockEditorMenuEditDiagram => 'Edit diagram…';

  @override
  String get blockEditorMenuBackToPreview => 'Back to preview';

  @override
  String get blockEditorMenuChangeFile => 'Change file…';

  @override
  String get blockEditorMenuRemoveFile => 'Remove file';

  @override
  String get blockEditorMenuChangeVideo => 'Change video…';

  @override
  String get blockEditorMenuRemoveVideo => 'Remove video';

  @override
  String get blockEditorMenuChangeAudio => 'Change audio…';

  @override
  String get blockEditorMenuRemoveAudio => 'Remove audio';

  @override
  String get blockEditorMenuEditLabel => 'Edit label…';

  @override
  String get blockEditorMenuAddRow => 'Add row';

  @override
  String get blockEditorMenuRemoveLastRow => 'Remove last row';

  @override
  String get blockEditorMenuAddColumn => 'Add column';

  @override
  String get blockEditorMenuRemoveLastColumn => 'Remove last column';

  @override
  String get blockEditorMenuAddProperty => 'Add property';

  @override
  String get blockEditorMenuChangeBlockType => 'Change block type…';

  @override
  String get blockEditorMenuDeleteBlock => 'Delete block';

  @override
  String get blockEditorAppearanceTitle => 'Block appearance';

  @override
  String get blockEditorAppearanceSubtitle =>
      'Customize size, text color, and background for this block.';

  @override
  String get blockEditorAppearanceSize => 'Size';

  @override
  String get blockEditorAppearanceTextColor => 'Text color';

  @override
  String get blockEditorAppearanceBackground => 'Background';

  @override
  String get blockEditorAppearancePreviewEmpty =>
      'This is how the block will look.';

  @override
  String get blockEditorReset => 'Reset';

  @override
  String get blockEditorCodeLanguageTitle => 'Code language';

  @override
  String get blockEditorCodeLanguageSubtitle =>
      'Syntax highlighting follows the language you pick.';

  @override
  String get blockEditorTemplateButtonTitle => 'Template button label';

  @override
  String get blockEditorTemplateButtonFieldLabel => 'Button text';

  @override
  String get blockEditorTemplateButtonDefaultLabel => 'Template';

  @override
  String get blockEditorTextColorDefault => 'Theme';

  @override
  String get blockEditorTextColorSubtle => 'Subtle';

  @override
  String get blockEditorTextColorPrimary => 'Primary';

  @override
  String get blockEditorTextColorSecondary => 'Secondary';

  @override
  String get blockEditorTextColorTertiary => 'Accent';

  @override
  String get blockEditorTextColorError => 'Error';

  @override
  String get blockEditorBackgroundNone => 'No background';

  @override
  String get blockEditorBackgroundSurface => 'Surface';

  @override
  String get blockEditorBackgroundPrimary => 'Primary';

  @override
  String get blockEditorBackgroundSecondary => 'Secondary';

  @override
  String get blockEditorBackgroundTertiary => 'Accent';

  @override
  String get blockEditorBackgroundError => 'Error';

  @override
  String get blockEditorCmdDuplicatePrev => 'Duplicate previous block';

  @override
  String get blockEditorCmdDuplicatePrevHint => 'Clones the block right above';

  @override
  String get blockEditorCmdInsertDate => 'Insert date';

  @override
  String get blockEditorCmdInsertDateHint => 'Writes today’s date';

  @override
  String get blockEditorCmdMentionPage => 'Mention page';

  @override
  String get blockEditorCmdMentionPageHint => 'Insert internal link to a page';

  @override
  String get blockEditorCmdTurnInto => 'Turn into…';

  @override
  String get blockEditorCmdTurnIntoHint => 'Pick a block type from the picker';

  @override
  String get blockEditorMarkTaskComplete => 'Mark task complete';

  @override
  String get blockEditorCalloutIconPickerTitle => 'Callout icon';

  @override
  String get blockEditorCalloutIconPickerHelper =>
      'Select an icon to change the visual tone of the callout block.';

  @override
  String get blockEditorIconPickerCustomEmoji => 'Custom emoji';

  @override
  String get blockEditorIconPickerQuickTab => 'Quick';

  @override
  String get blockEditorIconPickerImportedTab => 'Imported';

  @override
  String get blockEditorIconPickerAllTab => 'All';

  @override
  String get blockEditorIconPickerEmptyImported =>
      'You have not imported icons in Settings yet.';

  @override
  String get blockTypeSectionBasicText => 'Basic text';

  @override
  String get blockTypeSectionLists => 'Lists';

  @override
  String get blockTypeSectionMedia => 'Media and data';

  @override
  String get blockTypeSectionAdvanced => 'Advanced and layout';

  @override
  String get blockTypeSectionEmbeds => 'Integrations';

  @override
  String get blockTypeParagraphLabel => 'Text';

  @override
  String get blockTypeParagraphHint => 'Paragraph';

  @override
  String get blockTypeChildPageLabel => 'Page';

  @override
  String get blockTypeChildPageHint => 'Linked subpage';

  @override
  String get blockTypeH1Label => 'Heading 1';

  @override
  String get blockTypeH1Hint => 'Large title · #';

  @override
  String get blockTypeH2Label => 'Heading 2';

  @override
  String get blockTypeH2Hint => 'Subtitle · ##';

  @override
  String get blockTypeH3Label => 'Heading 3';

  @override
  String get blockTypeH3Hint => 'Smaller heading · ###';

  @override
  String get blockTypeQuoteLabel => 'Quote';

  @override
  String get blockTypeQuoteHint => 'Quoted text';

  @override
  String get blockTypeDividerLabel => 'Divider';

  @override
  String get blockTypeDividerHint => 'Separator · ---';

  @override
  String get blockTypeCalloutLabel => 'Callout';

  @override
  String get blockTypeCalloutHint => 'Notice with icon';

  @override
  String get blockTypeBulletLabel => 'Bulleted list';

  @override
  String get blockTypeBulletHint => 'Bullet points';

  @override
  String get blockTypeNumberedLabel => 'Numbered list';

  @override
  String get blockTypeNumberedHint => 'List 1, 2, 3';

  @override
  String get blockTypeTodoLabel => 'Task list';

  @override
  String get blockTypeTodoHint => 'Checklist';

  @override
  String get blockTypeTaskLabel => 'Rich task';

  @override
  String get blockTypeTaskHint => 'Status, priority, due date';

  @override
  String get blockTypeToggleLabel => 'Toggle';

  @override
  String get blockTypeToggleHint => 'Show or hide content';

  @override
  String get blockTypeImageLabel => 'Image';

  @override
  String get blockTypeImageHint => 'Local or external image';

  @override
  String get blockTypeBookmarkLabel => 'Link preview';

  @override
  String get blockTypeBookmarkHint => 'Card with link';

  @override
  String get blockTypeVideoLabel => 'Video';

  @override
  String get blockTypeVideoHint => 'File or URL';

  @override
  String get blockTypeAudioLabel => 'Audio';

  @override
  String get blockTypeAudioHint => 'Audio player';

  @override
  String get blockTypeMeetingNoteLabel => 'Meeting note';

  @override
  String get blockTypeMeetingNoteHint => 'Record and transcribe a meeting';

  @override
  String get blockTypeCodeLabel => 'Code (Java, Python…)';

  @override
  String get blockTypeCodeHint => 'Syntax block';

  @override
  String get blockTypeFileLabel => 'File / PDF';

  @override
  String get blockTypeFileHint => 'Attachment or PDF';

  @override
  String get blockTypeTableLabel => 'Table';

  @override
  String get blockTypeTableHint => 'Rows and columns';

  @override
  String get blockTypeDatabaseLabel => 'Database';

  @override
  String get blockTypeDatabaseHint => 'List, table, or board view';

  @override
  String get blockTypeKanbanLabel => 'Kanban';

  @override
  String get blockTypeKanbanHint => 'Board view for tasks on this page';

  @override
  String get kanbanBlockRowTitle => 'Kanban board';

  @override
  String get kanbanBlockRowSubtitle =>
      'Opening this page shows the board. On the board, use “Open block editor” to edit or remove this block.';

  @override
  String get kanbanRowTodosExcluded => 'Checklists off';

  @override
  String get kanbanToolbarOpenEditor => 'Open block editor';

  @override
  String get kanbanToolbarAddTask => 'Add task';

  @override
  String get kanbanClassicModeBanner =>
      'Block editor: you can move or delete the Kanban block.';

  @override
  String get kanbanBackToBoard => 'Back to board';

  @override
  String get kanbanMultipleBlocksSnack =>
      'This page has more than one Kanban block; using the first one.';

  @override
  String get kanbanEmptyColumn => 'No tasks';

  @override
  String get blockTypeDriveLabel => 'File Drive';

  @override
  String get blockTypeDriveHint => 'Integrated file manager';

  @override
  String get driveBlockRowTitle => 'File drive';

  @override
  String driveBlockRowSubtitle(int files, int folders) {
    return '$files files · $folders folders';
  }

  @override
  String get driveNewFolder => 'New folder';

  @override
  String get driveUploadFile => 'Upload file';

  @override
  String get driveImportFromVault => 'Import from vault';

  @override
  String get driveViewGrid => 'Grid';

  @override
  String get driveViewList => 'List';

  @override
  String get driveEditBlock => 'Edit block';

  @override
  String get driveFolderEmpty => 'This folder is empty';

  @override
  String get driveDeleteConfirm => 'Delete this file?';

  @override
  String get driveOpenFile => 'Open file';

  @override
  String get driveMoveTo => 'Move to…';

  @override
  String get driveClassicModeBanner =>
      'Block editor: you can move or delete the Drive block.';

  @override
  String get driveBackToDrive => 'Back to drive';

  @override
  String get driveMultipleBlocksSnack =>
      'This page has more than one Drive block; using the first one.';

  @override
  String get driveDeleteOriginalsTitle => 'Delete originals on import';

  @override
  String get driveDeleteOriginalsSubtitle =>
      'When uploading files to the drive, the originals are automatically deleted from disk.';

  @override
  String get blockTypeEquationLabel => 'Equation (LaTeX)';

  @override
  String get blockTypeEquationHint => 'Math formulas';

  @override
  String get blockTypeMermaidLabel => 'Diagram (Mermaid)';

  @override
  String get blockTypeMermaidHint => 'Flowchart or diagram';

  @override
  String get blockTypeTocLabel => 'Table of contents';

  @override
  String get blockTypeTocHint => 'Auto-generated index';

  @override
  String get blockTypeBreadcrumbLabel => 'Breadcrumbs';

  @override
  String get blockTypeBreadcrumbHint => 'Navigation path';

  @override
  String get blockTypeTemplateButtonLabel => 'Template button';

  @override
  String get blockTypeTemplateButtonHint => 'Insert a preset block';

  @override
  String get blockTypeColumnListLabel => 'Columns';

  @override
  String get blockTypeColumnListHint => 'Multi-column layout';

  @override
  String get blockTypeEmbedLabel => 'Web embed';

  @override
  String get blockTypeEmbedHint => 'YouTube, Figma, Docs…';

  @override
  String get integrationDialogTitleUpdatePermission =>
      'Update integration permission';

  @override
  String get integrationDialogTitleAllowConnect => 'Allow this app to connect';

  @override
  String integrationDialogBodyUpdate(
    Object previousVersion,
    Object integrationVersion,
  ) {
    return 'This app was already approved with integration $previousVersion and is now requesting access with version $integrationVersion.';
  }

  @override
  String integrationDialogBodyNew(
    Object appName,
    Object appVersion,
    Object integrationVersion,
  ) {
    return '\"$appName\" wants to use Folio\'s local bridge with app version $appVersion and integration $integrationVersion.';
  }

  @override
  String get integrationChipLocalhostOnly => 'Localhost only';

  @override
  String get integrationChipRevocableApproval => 'Revocable approval';

  @override
  String get integrationChipNoSharedSecret => 'No shared secret';

  @override
  String get integrationChipScopedByAppId => 'Scoped by appId';

  @override
  String get integrationMetaPreviouslyApprovedVersion =>
      'Previously approved version';

  @override
  String get integrationSectionWhatAppCanDo =>
      'What this app will be able to do';

  @override
  String get integrationCapEphemeralSessionsTitle =>
      'Open short-lived local sessions';

  @override
  String get integrationCapEphemeralSessionsBody =>
      'It can start a temporary session to talk to Folio\'s local bridge on this device.';

  @override
  String get integrationCapImportPagesTitle =>
      'Import and update its own pages';

  @override
  String get integrationCapImportPagesBody =>
      'It can create pages, list them, and update only the pages that the same app previously imported.';

  @override
  String get integrationCapCustomEmojisTitle => 'Manage its custom emojis';

  @override
  String get integrationCapCustomEmojisBody =>
      'It can list, create, replace, and delete only its own catalog of imported custom emojis or icons.';

  @override
  String get integrationCapUnlockedVaultTitle =>
      'Work only while the vault is unlocked';

  @override
  String get integrationCapUnlockedVaultBody =>
      'Requests only work while Folio is open, the vault is available, and the current session is still active.';

  @override
  String get integrationSectionWhatStaysBlocked => 'What will remain blocked';

  @override
  String get integrationBlockNoSeeAllTitle => 'It cannot see all your content';

  @override
  String get integrationBlockNoSeeAllBody =>
      'It does not get general vault access. It can only list what it imported itself through its appId.';

  @override
  String get integrationBlockNoBypassTitle =>
      'It cannot bypass lock or encryption';

  @override
  String get integrationBlockNoBypassBody =>
      'If the vault is locked or there is no active session, Folio will reject the operation.';

  @override
  String get integrationBlockNoOtherAppsTitle =>
      'It cannot touch another app\'s data';

  @override
  String get integrationBlockNoOtherAppsBody =>
      'It also cannot manage imported pages or custom emojis registered by other approved apps.';

  @override
  String get integrationBlockNoRemoteTitle =>
      'It cannot connect from outside your machine';

  @override
  String get integrationBlockNoRemoteBody =>
      'The bridge remains limited to localhost and this approval can be revoked later from Settings.';

  @override
  String integrationSnackMarkdownImportDone(Object pageTitle) {
    return 'Import completed: $pageTitle.';
  }

  @override
  String integrationSnackJsonImportDone(Object pageTitle) {
    return 'JSON import completed: $pageTitle.';
  }

  @override
  String integrationSnackPageUpdateDone(Object pageTitle) {
    return 'Integration update completed: $pageTitle.';
  }

  @override
  String get markdownImportModeDialogTitle => 'Import Markdown';

  @override
  String get markdownImportModeDialogBody =>
      'Choose how to apply the Markdown file.';

  @override
  String get markdownImportModeNewPage => 'New page';

  @override
  String get markdownImportModeAppend => 'Append to current';

  @override
  String get markdownImportModeReplace => 'Replace current';

  @override
  String get markdownImportCouldNotReadPath => 'Could not read the file path.';

  @override
  String markdownImportedBlocks(Object pageTitle, int blockCount) {
    return 'Markdown imported: $pageTitle ($blockCount blocks).';
  }

  @override
  String markdownImportFailedWithError(Object error) {
    return 'Could not import Markdown: $error';
  }

  @override
  String get importPage => 'Import…';

  @override
  String get exportMarkdownFileDialogTitle => 'Export page to Markdown';

  @override
  String get markdownExportSuccess => 'Page exported to Markdown.';

  @override
  String markdownExportFailedWithError(Object error) {
    return 'Could not export page: $error';
  }

  @override
  String get exportPageDialogTitle => 'Export page';

  @override
  String get exportPageFormatMarkdown => 'Markdown (.md)';

  @override
  String get exportPageFormatHtml => 'HTML (.html)';

  @override
  String get exportPageFormatTxt => 'Text (.txt)';

  @override
  String get exportPageFormatJson => 'JSON (.json)';

  @override
  String get exportPageFormatPdf => 'PDF (.pdf)';

  @override
  String get exportHtmlFileDialogTitle => 'Export page to HTML';

  @override
  String get htmlExportSuccess => 'Page exported to HTML.';

  @override
  String htmlExportFailedWithError(Object error) {
    return 'Could not export page: $error';
  }

  @override
  String get exportTxtFileDialogTitle => 'Export page to text';

  @override
  String get txtExportSuccess => 'Page exported to text.';

  @override
  String txtExportFailedWithError(Object error) {
    return 'Could not export page: $error';
  }

  @override
  String get exportJsonFileDialogTitle => 'Export page to JSON';

  @override
  String get jsonExportSuccess => 'Page exported to JSON.';

  @override
  String jsonExportFailedWithError(Object error) {
    return 'Could not export page: $error';
  }

  @override
  String get exportPdfFileDialogTitle => 'Export page to PDF';

  @override
  String get pdfExportSuccess => 'Page exported to PDF.';

  @override
  String pdfExportFailedWithError(Object error) {
    return 'Could not export page: $error';
  }

  @override
  String get firebaseUnavailablePublish => 'Firebase is not available.';

  @override
  String get signInCloudToPublishWeb =>
      'Sign in to your cloud account (Settings) to publish.';

  @override
  String get planMissingWebPublish =>
      'Your plan does not include web publishing or the subscription is not active.';

  @override
  String get publishWebDialogTitle => 'Publish to the web';

  @override
  String get publishWebSlugLabel => 'URL (slug)';

  @override
  String get publishWebSlugHint => 'my-note';

  @override
  String get publishWebSlugHelper =>
      'Letters, numbers, and hyphens. It will appear in the public URL.';

  @override
  String get publishWebAction => 'Publish';

  @override
  String get publishWebEmptySlug => 'Empty slug.';

  @override
  String publishWebSuccessWithUrl(Object url) {
    return 'Published: $url';
  }

  @override
  String publishWebFailedWithError(Object error) {
    return 'Could not publish: $error';
  }

  @override
  String get publishWebMenuLabel => 'Publish to the web';

  @override
  String get mobileFabDone => 'Done';

  @override
  String get mobileFabEdit => 'Edit';

  @override
  String get mobileFabAddBlock => 'Block';

  @override
  String get mermaidPreviewDialogTitle => 'Diagram';

  @override
  String get mermaidDiagramSemanticsLabel => 'Mermaid diagram, tap to enlarge';

  @override
  String get databaseSortAz => 'Sort A-Z';

  @override
  String get databaseSortLabel => 'Sort';

  @override
  String get databaseFilterAnd => 'AND';

  @override
  String get databaseFilterOr => 'OR';

  @override
  String get databaseSortDescending => 'Desc';

  @override
  String get databaseNewPropertyDialogTitle => 'New property';

  @override
  String databaseConfigurePropertyTitle(Object name) {
    return 'Configure: $name';
  }

  @override
  String get databaseLocalCurrentBadge => 'Current local DB';

  @override
  String databaseRelateRowsTitle(Object name) {
    return 'Relate rows ($name)';
  }

  @override
  String get databaseBoardNeedsGroupProperty =>
      'Configure a group property for the board.';

  @override
  String get databaseGroupPropertyMissing =>
      'The group property no longer exists.';

  @override
  String get databaseCalendarNeedsDateProperty =>
      'Configure a date property for the calendar.';

  @override
  String get databaseNoDatedEvents => 'No events with a date.';

  @override
  String get databaseConfigurePropertyTooltip => 'Configure property';

  @override
  String get databaseFormulaHintExample =>
      'if(contains(Name,\"x\"), add(1,2), 0)';

  @override
  String get createAction => 'Create';

  @override
  String get confirmAction => 'Confirm';

  @override
  String get confirmRemoteEndpointTitle => 'Confirm remote endpoint';

  @override
  String get shortcutGlobalSearchKeyChord => 'Ctrl + Shift + F';

  @override
  String get updateChannelRelease => 'Release';

  @override
  String get updateChannelBeta => 'Beta';

  @override
  String get blockActionChooseAudio => 'Choose audio…';

  @override
  String get blockActionCreateSubpage => 'Create subpage';

  @override
  String get blockActionLinkPage => 'Link page…';

  @override
  String get defaultNewPageTitle => 'New page';

  @override
  String defaultPageDuplicateTitle(Object title) {
    return '$title (copy)';
  }

  @override
  String aiChatTitleNumbered(int n) {
    return 'Chat $n';
  }

  @override
  String get invalidFolioTemplateFile =>
      'The file is not a valid Folio template.';

  @override
  String get templateButtonDefaultLabel => 'Template';

  @override
  String get pageHtmlExportPublishedWithFolio => 'Published with Folio';

  @override
  String get releaseReadinessSemverOk => 'Valid SemVer version';

  @override
  String get releaseReadinessEncryptedVault => 'Encrypted vault';

  @override
  String get releaseReadinessAiRemotePolicy => 'AI remote endpoint policy';

  @override
  String get releaseReadinessVaultUnlocked => 'Vault unlocked';

  @override
  String get releaseReadinessStableChannel => 'Stable channel selected';

  @override
  String get aiPromptUserMessage => 'User message:';

  @override
  String get aiPromptOriginalMessage => 'Original message:';

  @override
  String get aiPromptOriginalUserMessage => 'Original user message:';

  @override
  String get customIconImportEmptySource => 'The icon source is empty.';

  @override
  String get customIconImportInvalidUrl => 'The icon URL is not valid.';

  @override
  String get customIconImportInvalidSvg => 'The copied SVG is not valid.';

  @override
  String get customIconImportHttpHttpsOnly =>
      'Only http or https URLs are supported.';

  @override
  String get customIconImportDataUriMimeList =>
      'Only data:image/svg+xml, data:image/gif, data:image/webp, or data:image/png are supported.';

  @override
  String get customIconImportUnsupportedFormat =>
      'Unsupported format. Use SVG, PNG, GIF, or WebP.';

  @override
  String get customIconImportSvgTooLarge => 'The SVG is too large to import.';

  @override
  String get customIconImportEmbeddedImageTooLarge =>
      'The embedded image is too large to import.';

  @override
  String customIconImportDownloadFailed(Object code) {
    return 'Could not download the icon ($code).';
  }

  @override
  String get customIconImportRemoteTooLarge => 'The remote icon is too large.';

  @override
  String get customIconImportConnectFailed =>
      'Could not connect to download the icon.';

  @override
  String get customIconImportCertFailed =>
      'Certificate error while downloading the icon.';

  @override
  String get customIconLabelDefault => 'Custom icon';

  @override
  String get customIconLabelImported => 'Imported icon';

  @override
  String get customIconImportSucceeded => 'Icon imported successfully.';

  @override
  String get customIconClipboardEmpty => 'The clipboard is empty.';

  @override
  String get customIconRemoved => 'Icon removed.';

  @override
  String get whisperModelTiny => 'Tiny (fast)';

  @override
  String get whisperModelBaseQ8 => 'Base q8 (balanced)';

  @override
  String get whisperModelSmallQ8 => 'Small q8 (high accuracy, less disk)';

  @override
  String get whisperModelMediumQ8 => 'Medium q8';

  @override
  String get whisperModelLargeV3TurboQ8 => 'Large v3 Turbo q8';

  @override
  String get codeLangDart => 'Dart';

  @override
  String get codeLangTypeScript => 'TypeScript';

  @override
  String get codeLangJavaScript => 'JavaScript';

  @override
  String get codeLangPython => 'Python';

  @override
  String get codeLangJson => 'JSON';

  @override
  String get codeLangYaml => 'YAML';

  @override
  String get codeLangMarkdown => 'Markdown';

  @override
  String get codeLangDiff => 'Diff';

  @override
  String get codeLangSql => 'SQL';

  @override
  String get codeLangBash => 'Bash';

  @override
  String get codeLangCpp => 'C / C++';

  @override
  String get codeLangJava => 'Java';

  @override
  String get codeLangKotlin => 'Kotlin';

  @override
  String get codeLangRust => 'Rust';

  @override
  String get codeLangGo => 'Go';

  @override
  String get codeLangHtmlXml => 'HTML / XML';

  @override
  String get codeLangCss => 'CSS';

  @override
  String get codeLangPlainText => 'Plain text';

  @override
  String settingsAppRevoked(Object appId) {
    return 'App revoked: $appId';
  }

  @override
  String get settingsDeviceRevokedSnack => 'Device revoked.';

  @override
  String get settingsAiConnectionOk => 'AI connection OK';

  @override
  String settingsAiConnectionError(Object error) {
    return 'Connection error: $error';
  }

  @override
  String settingsAiListModelsFailed(Object error) {
    return 'Could not list models: $error';
  }

  @override
  String get folioCloudCallableNotSignedIn =>
      'You must be signed in to call Cloud Functions';

  @override
  String get folioCloudCallableUnexpectedResponse =>
      'Unexpected response from Cloud Functions';

  @override
  String folioCloudCallableHttpError(int code, Object name) {
    return 'HTTP $code calling $name';
  }

  @override
  String get folioCloudCallableNoIdToken =>
      'No ID token for Cloud Functions. Sign in to Folio Cloud again.';

  @override
  String get folioCloudCallableUnexpectedFallback =>
      'Unexpected response from Cloud Functions fallback';

  @override
  String folioCloudCallableHttpAiComplete(int code) {
    return 'HTTP $code calling folioCloudAiCompleteHttp';
  }

  @override
  String get cloudAccountEmailMismatch =>
      'The email does not match the current session.';

  @override
  String get cloudIdentityInvalidAuthResponse =>
      'Invalid authentication response.';

  @override
  String get templateButtonPlaceholderText => 'Template text…';

  @override
  String get aiProviderOllamaName => 'Ollama';

  @override
  String get aiProviderLmStudioName => 'LM Studio';

  @override
  String get blockAudioEmptyHint => 'Choose an audio file';

  @override
  String get blockChildPageTitle => 'Page block';

  @override
  String get blockChildPageNoLink => 'No linked subpage.';

  @override
  String get mermaidExpandedLoadError => 'Could not show the enlarged diagram.';

  @override
  String get mermaidPreviewTooltip =>
      'Tap to enlarge and zoom. PNG via mermaid.ink (external service).';

  @override
  String get aiEndpointInvalidUrl => 'Invalid URL. Use http://host:port.';

  @override
  String get aiEndpointRemoteNotAllowed =>
      'Remote endpoint is not allowed without confirmation.';

  @override
  String get settingsAiSelectProviderFirst => 'Select an AI provider first.';

  @override
  String get releaseReadinessAiSummaryDisabled => 'AI disabled';

  @override
  String get releaseReadinessAiSummaryQuillCloud =>
      'Folio Cloud AI (no local endpoint)';

  @override
  String releaseReadinessAiSummaryEndpointOk(Object url) {
    return 'Valid endpoint: $url';
  }

  @override
  String get releaseReadinessDetailSemverInvalid =>
      'The installed version does not satisfy SemVer.';

  @override
  String get releaseReadinessDetailVaultNotEncrypted =>
      'The current vault is not encrypted.';

  @override
  String get releaseReadinessDetailVaultLocked =>
      'Unlock the vault to validate export/import and real flow.';

  @override
  String get releaseReadinessDetailBetaChannel =>
      'The beta update channel is active.';

  @override
  String get releaseReadinessReportTitle => 'Folio: release readiness';

  @override
  String releaseReadinessReportInstalledVersion(Object label) {
    return 'Installed version: $label';
  }

  @override
  String releaseReadinessReportSemver(Object value) {
    return 'SemVer valid: $value';
  }

  @override
  String releaseReadinessReportChannel(Object value) {
    return 'Update channel: $value';
  }

  @override
  String releaseReadinessReportActiveVault(Object id) {
    return 'Active vault: $id';
  }

  @override
  String releaseReadinessReportVaultPath(Object path) {
    return 'Vault path: $path';
  }

  @override
  String releaseReadinessReportUnlocked(Object value) {
    return 'Vault unlocked: $value';
  }

  @override
  String releaseReadinessReportEncrypted(Object value) {
    return 'Vault encrypted: $value';
  }

  @override
  String releaseReadinessReportAiEnabled(Object value) {
    return 'AI enabled: $value';
  }

  @override
  String releaseReadinessReportAiPolicy(Object value) {
    return 'AI endpoint policy: $value';
  }

  @override
  String releaseReadinessReportAiDetail(Object detail) {
    return 'AI detail: $detail';
  }

  @override
  String releaseReadinessReportStatus(Object value) {
    return 'Release status: $value';
  }

  @override
  String releaseReadinessReportBlockers(int count) {
    return 'Pending blockers: $count';
  }

  @override
  String releaseReadinessReportWarnings(int count) {
    return 'Pending warnings: $count';
  }

  @override
  String get releaseReadinessExportWordYes => 'yes';

  @override
  String get releaseReadinessExportWordNo => 'no';

  @override
  String get releaseReadinessChannelStable => 'stable';

  @override
  String get releaseReadinessChannelBeta => 'beta';

  @override
  String get releaseReadinessStatusReady => 'ready';

  @override
  String get releaseReadinessStatusBlocked => 'blocked';

  @override
  String get releaseReadinessPolicyOk => 'ok';

  @override
  String get releaseReadinessPolicyError => 'error';

  @override
  String get settingsSignInFolioCloudSnack => 'Sign in to Folio Cloud.';

  @override
  String get settingsNotSyncedYet => 'Not synced yet';

  @override
  String get settingsDeviceNameTitle => 'Device name';

  @override
  String get settingsDeviceNameHintExample => 'Example: Alex Pixel';

  @override
  String get settingsPairingModeEnabledTwoMin =>
      'Pairing mode enabled for 2 minutes.';

  @override
  String get settingsPairingEnableModeFirst =>
      'First enable pairing mode, then choose a discovered device.';

  @override
  String get settingsPairingSameEmojisBothDevices =>
      'Enable pairing mode on both devices and wait until the same 3 emojis appear.';

  @override
  String get settingsPairingCouldNotStart =>
      'Could not start pairing. Enable pairing mode on both devices and wait until the same 3 emojis appear.';

  @override
  String get settingsConfirmPairingTitle => 'Confirm pairing';

  @override
  String get settingsPairingCheckOtherDeviceEmojis =>
      'Check that the other device shows these same 3 emojis:';

  @override
  String get settingsPairingPopupInstructions =>
      'This popup will also appear on the other device. To complete linking, press Link here and then Link on the other one.';

  @override
  String get settingsLinkDevice => 'Link';

  @override
  String get settingsPairingConfirmationSent =>
      'Confirmation sent. The other device still needs to press Link in its popup.';

  @override
  String get settingsResolveConflictsTitle => 'Resolve conflicts';

  @override
  String get settingsNoPendingConflicts => 'There are no pending conflicts.';

  @override
  String settingsSyncConflictCardSubtitle(
    Object fromPeerId,
    int remotePageCount,
    Object detectedAt,
  ) {
    return 'Source: $fromPeerId\nRemote pages: $remotePageCount\nDetected: $detectedAt';
  }

  @override
  String get settingsSyncConflictHeading => 'Sync conflict';

  @override
  String get settingsLocalVersionKeptSnack => 'Local version kept.';

  @override
  String get settingsKeepLocal => 'Keep local';

  @override
  String get settingsRemoteVersionAppliedSnack => 'Remote version applied.';

  @override
  String get settingsCouldNotApplyRemoteSnack =>
      'Could not apply the remote version.';

  @override
  String get settingsAcceptRemote => 'Accept remote';

  @override
  String get settingsClose => 'Close';

  @override
  String get settingsSectionDeviceSyncNav => 'Device sync';

  @override
  String get settingsSectionVault => 'Notebook';

  @override
  String get settingsSectionVaultHeroDescription =>
      'Unlock security, backups, scheduled copies to disk, and data management for this device.';

  @override
  String get settingsSectionUiWorkspace => 'Interface & desktop';

  @override
  String get settingsSectionUiWorkspaceHeroDescription =>
      'Theme, language, scaling, editor layout, desktop options, and keyboard shortcuts.';

  @override
  String get settingsSubsectionVaultBackupImport => 'Backups & import';

  @override
  String get settingsSubsectionVaultScheduledLocal =>
      'Scheduled backup (local)';

  @override
  String get settingsSubsectionDrive => 'Drive';

  @override
  String get settingsSubsectionVaultData => 'Data (danger zone)';

  @override
  String get folioCloudSubsectionAccount => 'Account';

  @override
  String get folioCloudSubsectionEncryptedBackups =>
      'Encrypted backups (cloud)';

  @override
  String get folioCloudSubsectionPublishing => 'Web publishing';

  @override
  String get settingsFolioCloudSubsectionScheduledCloud =>
      'Scheduled backup to Folio Cloud';

  @override
  String get settingsScheduledCloudUploadRequiresSchedule =>
      'Turn on scheduled backup in Notebook › Scheduled backup (local) first.';

  @override
  String get settingsSyncHeroTitle => 'Device synchronization';

  @override
  String get settingsSyncHeroDescription =>
      'Pair machines on the local network; the relay only helps negotiate the connection and does not send vault content.';

  @override
  String get settingsSyncChipPairingCode => 'Pairing code';

  @override
  String get settingsSyncChipAutoDiscovery => 'Auto discovery';

  @override
  String get settingsSyncChipOptionalRelay => 'Optional relay';

  @override
  String get settingsSyncEnableTitle => 'Enable device sync';

  @override
  String get settingsSyncSearchingSubtitle =>
      'Searching for nearby devices with Folio open on local network...';

  @override
  String settingsSyncDevicesFoundOnLan(int count) {
    return '$count devices discovered on LAN.';
  }

  @override
  String get settingsSyncDisabledSubtitle =>
      'Synchronization is currently disabled.';

  @override
  String get settingsSyncRelayTitle => 'Use signaling relay';

  @override
  String get settingsSyncRelaySubtitle =>
      'Does not send vault content, only helps negotiate connectivity when LAN fails.';

  @override
  String get settingsEdit => 'Edit';

  @override
  String get settingsSyncEmojiModeTitle => 'Enable emoji pairing mode';

  @override
  String get settingsSyncEmojiModeSubtitle =>
      'Enable it on both devices to start pairing without typing codes.';

  @override
  String get settingsSyncPairingStatusTitle => 'Pairing mode status';

  @override
  String get settingsSyncPairingActiveSubtitle =>
      'Active for 2 minutes. You can now start pairing from a detected device.';

  @override
  String get settingsSyncPairingInactiveSubtitle =>
      'Inactive. Enable it here and on the other device to start pairing.';

  @override
  String get settingsSyncLastSyncTitle => 'Last synchronization';

  @override
  String get settingsSyncPendingConflictsTitle => 'Pending conflicts';

  @override
  String get settingsSyncNoConflictsSubtitle => 'No pending conflicts.';

  @override
  String settingsSyncConflictsNeedReview(int count) {
    return '$count conflicts require manual review.';
  }

  @override
  String get settingsResolve => 'Resolve';

  @override
  String get settingsSyncDiscoveredDevicesTitle => 'Discovered devices';

  @override
  String get settingsSyncNoDevicesYetHint =>
      'No devices detected yet. Make sure both apps are open on the same network.';

  @override
  String get settingsSyncPeerReadyToLink => 'Ready to link.';

  @override
  String get settingsSyncPeerOtherInPairingMode =>
      'The other device is in pairing mode. Enable it here to start linking.';

  @override
  String get settingsSyncPeerDetectedLan => 'Detected on the local network.';

  @override
  String get settingsSyncLinkedDevicesTitle => 'Linked devices';

  @override
  String get settingsSyncNoLinkedDevicesYet => 'No linked devices yet.';

  @override
  String settingsSyncPeerIdLabel(Object peerId) {
    return 'ID: $peerId';
  }

  @override
  String get settingsRevoke => 'Revoke';

  @override
  String get sidebarPageIconTitle => 'Page icon';

  @override
  String get sidebarPageIconPickerHelper =>
      'Pick a quick icon, an imported one, or open the full picker.';

  @override
  String get sidebarPageIconCustomEmoji => 'Custom emoji';

  @override
  String get sidebarPageIconRemove => 'Remove';

  @override
  String get sidebarPageIconTabQuick => 'Quick';

  @override
  String get sidebarPageIconTabImported => 'Imported';

  @override
  String get sidebarPageIconTabAll => 'All';

  @override
  String get sidebarPageIconEmptyImported =>
      'You have not imported icons in Settings yet.';

  @override
  String get settingsStripeSubscriptionRefreshed =>
      'Folio Cloud billing updated.';

  @override
  String get settingsStripeBillingPortalUnavailable =>
      'Billing portal unavailable.';

  @override
  String get settingsCouldNotOpenLink => 'Could not open the link.';

  @override
  String get settingsStripeCheckoutUnavailable =>
      'Checkout unavailable (configure Stripe on server).';

  @override
  String get settingsCloudBackupEnablePlanSnack =>
      'Enable Folio Cloud with the cloud backup feature included in your plan.';

  @override
  String get settingsNoActiveVault => 'No active vault.';

  @override
  String get settingsCloudBackupsNeedPlan =>
      'You need an active Folio Cloud plan with cloud backup.';

  @override
  String settingsCloudBackupsDialogTitle(int count) {
    return 'Cloud backups ($count/10)';
  }

  @override
  String get settingsCloudBackupsVaultLabel => 'Notebook';

  @override
  String get settingsCloudBackupsEmpty => 'No backups in this account yet.';

  @override
  String get settingsCloudBackupDownloadTooltip => 'Download';

  @override
  String get settingsCloudBackupActionDownload => 'Download';

  @override
  String get settingsCloudBackupActionImportOverwrite => 'Import (overwrite)';

  @override
  String get settingsCloudBackupSaveDialogTitle => 'Save backup';

  @override
  String get settingsCloudBackupDownloadedSnack => 'Backup downloaded.';

  @override
  String get settingsCloudBackupDeletedSnack => 'Backup deleted.';

  @override
  String get settingsCloudBackupImportedSnack => 'Import completed.';

  @override
  String get settingsCloudBackupVaultMustBeUnlocked =>
      'The vault must be unlocked.';

  @override
  String settingsCloudBackupsTotalLabel(Object size) {
    return 'Total: $size';
  }

  @override
  String get settingsCloudBackupImportOverwriteTitle => 'Import (overwrite)';

  @override
  String get settingsCloudBackupImportOverwriteBody =>
      'This will overwrite the contents of the currently open vault. Make sure you have a local backup before continuing.';

  @override
  String get settingsCloudBackupDeleteWarning =>
      'Are you sure you want to delete this cloud backup? This action cannot be undone.';

  @override
  String get settingsPublishedRequiresPlan =>
      'You need Folio Cloud with web publishing enabled.';

  @override
  String get settingsPublishedPagesTitle => 'Published pages';

  @override
  String get settingsPublishedPagesEmpty => 'No published pages yet.';

  @override
  String get settingsPublishedDeleteDialogTitle => 'Remove publication?';

  @override
  String get settingsPublishedDeleteDialogBody =>
      'The public HTML will be removed and the link will stop working.';

  @override
  String get settingsPublishedRemovedSnack => 'Removed.';

  @override
  String get settingsCouldNotReadInstalledVersion =>
      'Could not read installed version.';

  @override
  String settingsCouldNotOpenReleaseNotes(Object error) {
    return 'Could not open release notes: $error';
  }

  @override
  String settingsUpdateFailed(Object error) {
    return 'Could not update: $error';
  }

  @override
  String get settingsSessionEndedSnack => 'Signed out';

  @override
  String get settingsLabelYes => 'Yes';

  @override
  String get settingsLabelNo => 'No';

  @override
  String get settingsSecurityEncryptedHeroDescription =>
      'Quick unlock, passkey, auto-lock, and master password for your encrypted vault.';

  @override
  String get settingsUnencryptedVaultTitle => 'Unencrypted vault';

  @override
  String get settingsUnencryptedVaultChipDataOnDisk => 'Data on disk';

  @override
  String get settingsUnencryptedVaultChipEncryptionAvailable =>
      'Encryption available';

  @override
  String get settingsAppearanceChipTheme => 'Theme';

  @override
  String get settingsAppearanceChipZoom => 'Zoom';

  @override
  String get settingsAppearanceChipLanguage => 'Language';

  @override
  String get settingsAppearanceChipEditorWorkspace => 'Editor & workspace';

  @override
  String get settingsWindowsScaleFollowTitle => 'Follow Windows scale';

  @override
  String get settingsWindowsScaleFollowSubtitle =>
      'Automatically use system scale on Windows.';

  @override
  String get settingsInterfaceZoomTitle => 'Interface zoom';

  @override
  String get settingsInterfaceZoomSubtitle =>
      'Increase or reduce the overall app size.';

  @override
  String get settingsUiZoomReset => 'Reset';

  @override
  String get settingsEditorSubsection => 'Editor';

  @override
  String get settingsEditorContentWidthTitle => 'Content width';

  @override
  String get settingsEditorContentWidthSubtitle =>
      'Controls how wide blocks appear in the editor.';

  @override
  String get settingsEnterCreatesNewBlockTitle => 'Enter creates a new block';

  @override
  String get settingsEnterCreatesNewBlockSubtitleWhenEnabled =>
      'Disable to make Enter insert a line break.';

  @override
  String get settingsEnterCreatesNewBlockSubtitleWhenDisabled =>
      'Enter now inserts a line break. Shift+Enter still works.';

  @override
  String get settingsWorkspaceSubsection => 'Workspace';

  @override
  String get settingsCustomIconsTitle => 'Custom icons';

  @override
  String get settingsCustomIconsDescription =>
      'Import a PNG, GIF, or WebP URL, or a compatible data:image copied from sites like notionicons.so. You can then use it as a page or callout icon.';

  @override
  String settingsCustomIconsSavedCount(int count) {
    return '$count saved';
  }

  @override
  String get settingsCustomIconsChipUrl => 'PNG, GIF, or WebP URL';

  @override
  String get settingsCustomIconsChipDataImage => 'data:image/*';

  @override
  String get settingsCustomIconsChipPaste => 'Paste from clipboard';

  @override
  String get settingsCustomIconsImportTitle => 'Import new icon';

  @override
  String get settingsCustomIconsImportSubtitle =>
      'You can give it a name and paste the source manually or bring it directly from the clipboard.';

  @override
  String get settingsCustomIconsFieldNameLabel => 'Name';

  @override
  String get settingsCustomIconsFieldNameHint => 'Optional';

  @override
  String get settingsCustomIconsFieldSourceLabel => 'URL or data:image';

  @override
  String get settingsCustomIconsFieldSourceHint =>
      'https://…gif | …webp | …png or data:image/…';

  @override
  String get settingsCustomIconsImportButton => 'Import icon';

  @override
  String get settingsCustomIconsFromClipboard => 'From clipboard';

  @override
  String get settingsCustomIconsLibraryTitle => 'Library';

  @override
  String get settingsCustomIconsLibrarySubtitle =>
      'Ready to use across the app';

  @override
  String get settingsCustomIconsEmpty => 'No icons imported yet.';

  @override
  String get settingsCustomIconsDeleteTooltip => 'Delete icon';

  @override
  String get settingsCustomIconsReferenceCopiedSnack => 'Reference copied.';

  @override
  String get settingsCustomIconsCopyToken => 'Copy token';

  @override
  String get settingsAiHeroQuillWithLocalAlt =>
      'AI runs on Quill Cloud (subscription with cloud AI or purchased ink). Pick another provider below for local Ollama or LM Studio.';

  @override
  String get settingsAiHeroQuillCloudOnly =>
      'AI runs on Quill Cloud (subscription with cloud AI or purchased ink).';

  @override
  String get settingsAiHeroLocalDefault =>
      'Connect Ollama or LM Studio locally; the assistant uses the model and context you set here.';

  @override
  String get settingsAiHeroQuillMobileOnly =>
      'On this device Quill can only use Quill Cloud. Choose Quill Cloud as the provider when you want to enable AI.';

  @override
  String get settingsAiChipCloud => 'Hosted';

  @override
  String get settingsAiSnackFirebaseUnavailableBuild =>
      'Firebase is not available in this build.';

  @override
  String get settingsAiSnackSignInCloudAccount =>
      'Sign in to your cloud account (Settings).';

  @override
  String settingsAiProviderSwitchFailed(Object error) {
    return 'Could not switch AI provider: $error';
  }

  @override
  String get settingsAboutHeroDescription =>
      'Installed version, update source, and manual checks for new releases.';

  @override
  String get settingsOpenReleaseNotes => 'Open release notes';

  @override
  String get settingsUpdateChannelLabel => 'Channel';

  @override
  String get settingsUpdateChannelRelease => 'Release';

  @override
  String get settingsUpdateChannelBeta => 'Beta';

  @override
  String get settingsDataHeroDescription =>
      'Permanent actions on local files. Make a backup before deleting.';

  @override
  String get settingsDangerZoneTitle => 'Danger zone';

  @override
  String get settingsDesktopHeroDescription =>
      'Global shortcuts, system tray, and window behavior on desktop.';

  @override
  String get settingsShortcutsHeroDescription =>
      'Shortcuts only inside Folio. Test a key before saving it.';

  @override
  String get settingsShortcutsTestChip => 'Test';

  @override
  String get settingsIntegrationsChipApprovedPermissions =>
      'Approved permissions';

  @override
  String get settingsIntegrationsChipRevocableAccess => 'Revocable access';

  @override
  String get settingsIntegrationsChipExternalApps => 'External apps';

  @override
  String get settingsIntegrationsActiveConnectionsTitle => 'Active connections';

  @override
  String get settingsIntegrationsActiveConnectionsSubtitle =>
      'Apps already allowed to interact with Folio';

  @override
  String get settingsViewInkUsageTable => 'View usage table';

  @override
  String get settingsCloudInkUsageTableTitle => 'Ink usage table (Quill Cloud)';

  @override
  String get settingsCloudInkUsageTableIntro =>
      'Base cost per action. Extra surcharges may apply for long prompts and output token usage.';

  @override
  String get settingsCloudInkDrops => 'drops';

  @override
  String get settingsCloudInkTableCachedNotice =>
      'Showing local cached table (no backend connection).';

  @override
  String get settingsCloudInkOpRewriteBlock => 'Rewrite block';

  @override
  String get settingsCloudInkOpSummarizeSelection => 'Summarize selection';

  @override
  String get settingsCloudInkOpExtractTasks => 'Extract tasks';

  @override
  String get settingsCloudInkOpSummarizePage => 'Summarize page';

  @override
  String get settingsCloudInkOpGenerateInsert => 'Generate insert';

  @override
  String get settingsCloudInkOpGeneratePage => 'Generate page';

  @override
  String get settingsCloudInkOpChatTurn => 'Chat turn';

  @override
  String get settingsCloudInkOpAgentMain => 'Agent main run';

  @override
  String get settingsCloudInkOpAgentFollowup => 'Agent follow-up';

  @override
  String get settingsCloudInkOpEditPagePanel => 'Page edit panel';

  @override
  String get settingsCloudInkOpDefault => 'Fallback operation';

  @override
  String get settingsDesktopRailSubtitle =>
      'Pick a category from the list or scroll the content.';

  @override
  String get settingsCloudInkViewTableButton => 'View table';

  @override
  String get settingsCloudInkHostedAiQuillCloudHint =>
      'Reference pricing for cloud AI on Quill Cloud.';

  @override
  String get vaultStarterHomeTitle => 'Start here';

  @override
  String get vaultStarterHomeHeading => 'Your notebook is ready';

  @override
  String get vaultStarterHomeIntro =>
      'Folio organizes your pages in a tree, edits content in blocks, and keeps data on this device. This short guide maps what you can do from minute one.';

  @override
  String get vaultStarterHomeCallout =>
      'You can delete, rename, or move these pages anytime—they are just a quick starting point.';

  @override
  String get vaultStarterHomeSectionTips => 'Most useful to begin';

  @override
  String get vaultStarterHomeBulletSlash =>
      'Press / in a paragraph to insert headings, lists, tables, code blocks, Mermaid, and more.';

  @override
  String get vaultStarterHomeBulletSidebar =>
      'Use the side panel to create pages and subpages, and reorder the tree to match how you work.';

  @override
  String get vaultStarterHomeBulletSettings =>
      'Open Settings to enable AI, configure backup, change language, or add quick unlock.';

  @override
  String get vaultStarterHomeTodo1 => 'Create my first working page';

  @override
  String get vaultStarterHomeTodo2 => 'Try the / menu to insert a new block';

  @override
  String get vaultStarterHomeTodo3 =>
      'Review Settings and decide whether to enable Quill or quick unlock';

  @override
  String get vaultStarterCapabilitiesTitle => 'What Folio can do';

  @override
  String get vaultStarterCapabilitiesSectionMain => 'Main capabilities';

  @override
  String get vaultStarterCapabilitiesBullet1 =>
      'Take notes with free-form structure using paragraphs, headings, lists, checklists, quotes, and dividers.';

  @override
  String get vaultStarterCapabilitiesBullet2 =>
      'Use special blocks such as tables, databases, files, audio, video, embeds, and Mermaid diagrams.';

  @override
  String get vaultStarterCapabilitiesBullet3 =>
      'Search content, browse page history, and keep revisions inside the same notebook.';

  @override
  String get vaultStarterCapabilitiesBullet4 =>
      'Export or import data, including notebook backup and Notion import.';

  @override
  String get vaultStarterCapabilitiesSectionShortcuts => 'Quick shortcuts';

  @override
  String get vaultStarterCapabilitiesShortcutN => 'Ctrl+N creates a new page.';

  @override
  String get vaultStarterCapabilitiesShortcutSearch =>
      'Ctrl+K or Ctrl+F opens search.';

  @override
  String get vaultStarterCapabilitiesShortcutSettings =>
      'Ctrl+, opens Settings and Ctrl+L locks the notebook.';

  @override
  String get vaultStarterCapabilitiesAiCallout =>
      'AI is off by default. If you use Quill, configure it in Settings—provider, model, and context permissions.';

  @override
  String get vaultStarterQuillTitle => 'Quill and privacy';

  @override
  String get vaultStarterQuillSectionWhat => 'What Quill can do';

  @override
  String get vaultStarterQuillBullet1 =>
      'Summarize, rewrite, or expand the content of a page.';

  @override
  String get vaultStarterQuillBullet2 =>
      'Answer questions about blocks, shortcuts, and how to organize notes in Folio.';

  @override
  String get vaultStarterQuillBullet3 =>
      'Work with the open page as context or with several pages you pick as references.';

  @override
  String get vaultStarterQuillSectionPrivacy => 'Privacy and security';

  @override
  String get vaultStarterQuillPrivacyBody =>
      'Your pages live on this device. If you enable AI, check what context you share and with which provider. If you forget the master password of an encrypted notebook, Folio cannot recover it for you.';

  @override
  String get vaultStarterQuillBackupCallout =>
      'Back up the notebook when you have important content. The backup keeps data and attachments but does not transfer Hello or passkeys across devices.';

  @override
  String get vaultStarterQuillMermaidCaption => 'Quick Mermaid tryout:';

  @override
  String get vaultStarterQuillMermaidSource =>
      'graph TD\nStart[Create notebook] --> Organize[Organize pages]\nOrganize --> Write[Write and link ideas]\nWrite --> Review[Search, review, improve]';
}
