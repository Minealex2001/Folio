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
  String get createVault => 'Create vault';

  @override
  String minCharactersError(int min) {
    return 'Minimum $min characters.';
  }

  @override
  String get passwordMismatchError => 'Passwords do not match.';

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
}
