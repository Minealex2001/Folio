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
  String get importVault => 'Import vault';

  @override
  String get masterPasswordTitle => 'Your master password';

  @override
  String masterPasswordHint(int min) {
    return 'At least $min characters. You will use it every time you open Folio.';
  }

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
  String get newRootPageTooltip => 'New page (root)';

  @override
  String get blockOptions => 'Block options';

  @override
  String get dragToReorder => 'Drag to reorder';

  @override
  String get addBlock => 'Add block';

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
  String get aiInputHint => 'Type your message. Quill will act as an agent.';

  @override
  String get aiShowPanel => 'Show AI panel';

  @override
  String get aiHidePanel => 'Hide AI panel';

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
  String get aiProviderNone => 'None';

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
      'Install LM Studio, start its local server (OpenAI-compatible), and verify it responds at http://127.0.0.1:1234.';

  @override
  String get aiSetupOpenSettingsHint =>
      'When one provider is operational, press Retry to auto-configure it.';

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
  String get importNotionTargetCurrent => 'Current vault';

  @override
  String get importNotionTargetNew => 'New vault';

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
  String get appBetaBannerMessage =>
      'You are using a beta build. You may run into bugs; back up your vault regularly.';

  @override
  String get appBetaBannerDismiss => 'Got it';

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
}
