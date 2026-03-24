import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In es, this message translates to:
  /// **'Folio'**
  String get appTitle;

  /// No description provided for @loading.
  ///
  /// In es, this message translates to:
  /// **'Cargando…'**
  String get loading;

  /// No description provided for @newVault.
  ///
  /// In es, this message translates to:
  /// **'Nuevo cofre'**
  String get newVault;

  /// No description provided for @stepOfTotal.
  ///
  /// In es, this message translates to:
  /// **'Paso {current} de {total}'**
  String stepOfTotal(int current, int total);

  /// No description provided for @back.
  ///
  /// In es, this message translates to:
  /// **'Atrás'**
  String get back;

  /// No description provided for @continueAction.
  ///
  /// In es, this message translates to:
  /// **'Continuar'**
  String get continueAction;

  /// No description provided for @cancel.
  ///
  /// In es, this message translates to:
  /// **'Cancelar'**
  String get cancel;

  /// No description provided for @retry.
  ///
  /// In es, this message translates to:
  /// **'Reintentar'**
  String get retry;

  /// No description provided for @settings.
  ///
  /// In es, this message translates to:
  /// **'Ajustes'**
  String get settings;

  /// No description provided for @lockNow.
  ///
  /// In es, this message translates to:
  /// **'Bloquear'**
  String get lockNow;

  /// No description provided for @pageHistory.
  ///
  /// In es, this message translates to:
  /// **'Historial de la página'**
  String get pageHistory;

  /// No description provided for @untitled.
  ///
  /// In es, this message translates to:
  /// **'Sin título'**
  String get untitled;

  /// No description provided for @noPages.
  ///
  /// In es, this message translates to:
  /// **'Sin páginas'**
  String get noPages;

  /// No description provided for @createPage.
  ///
  /// In es, this message translates to:
  /// **'Crear página'**
  String get createPage;

  /// No description provided for @selectPage.
  ///
  /// In es, this message translates to:
  /// **'Selecciona una página'**
  String get selectPage;

  /// No description provided for @saveInProgress.
  ///
  /// In es, this message translates to:
  /// **'Guardando…'**
  String get saveInProgress;

  /// No description provided for @savePending.
  ///
  /// In es, this message translates to:
  /// **'Por guardar'**
  String get savePending;

  /// No description provided for @savingVaultTooltip.
  ///
  /// In es, this message translates to:
  /// **'Guardando el cofre cifrado en disco…'**
  String get savingVaultTooltip;

  /// No description provided for @autosaveSoonTooltip.
  ///
  /// In es, this message translates to:
  /// **'Guardado automático en unos instantes…'**
  String get autosaveSoonTooltip;

  /// No description provided for @welcomeTitle.
  ///
  /// In es, this message translates to:
  /// **'Bienvenida'**
  String get welcomeTitle;

  /// No description provided for @welcomeBody.
  ///
  /// In es, this message translates to:
  /// **'Folio guarda tus páginas solo en este dispositivo, cifradas con una contraseña maestra. Si la olvidas, no podremos recuperar los datos.\n\nNo hay sincronización en la nube.'**
  String get welcomeBody;

  /// No description provided for @createNewVault.
  ///
  /// In es, this message translates to:
  /// **'Crear cofre nuevo'**
  String get createNewVault;

  /// No description provided for @importBackupZip.
  ///
  /// In es, this message translates to:
  /// **'Importar una copia (.zip)'**
  String get importBackupZip;

  /// No description provided for @importBackupTitle.
  ///
  /// In es, this message translates to:
  /// **'Importar copia'**
  String get importBackupTitle;

  /// No description provided for @importBackupBody.
  ///
  /// In es, this message translates to:
  /// **'El archivo contiene los mismos datos cifrados que en el otro equipo. Necesitas la contraseña maestra con la que se creó esa copia.\n\nLa passkey y el desbloqueo rápido (Hello) no van en el archivo y no son transferibles; podrás configurarlos después en Ajustes.'**
  String get importBackupBody;

  /// No description provided for @chooseZipFile.
  ///
  /// In es, this message translates to:
  /// **'Elegir archivo .zip'**
  String get chooseZipFile;

  /// No description provided for @changeFile.
  ///
  /// In es, this message translates to:
  /// **'Cambiar archivo'**
  String get changeFile;

  /// No description provided for @backupPasswordLabel.
  ///
  /// In es, this message translates to:
  /// **'Contraseña de la copia'**
  String get backupPasswordLabel;

  /// No description provided for @importVault.
  ///
  /// In es, this message translates to:
  /// **'Importar cofre'**
  String get importVault;

  /// No description provided for @masterPasswordTitle.
  ///
  /// In es, this message translates to:
  /// **'Tu contraseña maestra'**
  String get masterPasswordTitle;

  /// No description provided for @masterPasswordHint.
  ///
  /// In es, this message translates to:
  /// **'Al menos {min} caracteres. La usarás cada vez que abras Folio.'**
  String masterPasswordHint(int min);

  /// No description provided for @passwordLabel.
  ///
  /// In es, this message translates to:
  /// **'Contraseña'**
  String get passwordLabel;

  /// No description provided for @confirmPasswordLabel.
  ///
  /// In es, this message translates to:
  /// **'Confirmar contraseña'**
  String get confirmPasswordLabel;

  /// No description provided for @next.
  ///
  /// In es, this message translates to:
  /// **'Siguiente'**
  String get next;

  /// No description provided for @readyTitle.
  ///
  /// In es, this message translates to:
  /// **'Todo listo'**
  String get readyTitle;

  /// No description provided for @readyBody.
  ///
  /// In es, this message translates to:
  /// **'Se creará un cofre cifrado en este equipo. Podrás añadir después Windows Hello, biometría o una passkey para desbloquear más rápido (Ajustes).'**
  String get readyBody;

  /// No description provided for @createVault.
  ///
  /// In es, this message translates to:
  /// **'Crear cofre'**
  String get createVault;

  /// No description provided for @minCharactersError.
  ///
  /// In es, this message translates to:
  /// **'Mínimo {min} caracteres.'**
  String minCharactersError(int min);

  /// No description provided for @passwordMismatchError.
  ///
  /// In es, this message translates to:
  /// **'Las contraseñas no coinciden.'**
  String get passwordMismatchError;

  /// No description provided for @chooseZipError.
  ///
  /// In es, this message translates to:
  /// **'Elige un archivo .zip.'**
  String get chooseZipError;

  /// No description provided for @enterBackupPasswordError.
  ///
  /// In es, this message translates to:
  /// **'Introduce la contraseña de la copia.'**
  String get enterBackupPasswordError;

  /// No description provided for @importFailedError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo importar: {error}'**
  String importFailedError(Object error);

  /// No description provided for @createVaultFailedError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo crear el cofre: {error}'**
  String createVaultFailedError(Object error);

  /// No description provided for @encryptedVault.
  ///
  /// In es, this message translates to:
  /// **'Cofre cifrado'**
  String get encryptedVault;

  /// No description provided for @unlock.
  ///
  /// In es, this message translates to:
  /// **'Desbloquear'**
  String get unlock;

  /// No description provided for @quickUnlock.
  ///
  /// In es, this message translates to:
  /// **'Hello / biometría'**
  String get quickUnlock;

  /// No description provided for @passkey.
  ///
  /// In es, this message translates to:
  /// **'Passkey'**
  String get passkey;

  /// No description provided for @unlockFailed.
  ///
  /// In es, this message translates to:
  /// **'Contraseña incorrecta o cofre dañado.'**
  String get unlockFailed;

  /// No description provided for @appearance.
  ///
  /// In es, this message translates to:
  /// **'Apariencia'**
  String get appearance;

  /// No description provided for @security.
  ///
  /// In es, this message translates to:
  /// **'Seguridad'**
  String get security;

  /// No description provided for @vaultBackup.
  ///
  /// In es, this message translates to:
  /// **'Copia del cofre'**
  String get vaultBackup;

  /// No description provided for @data.
  ///
  /// In es, this message translates to:
  /// **'Datos'**
  String get data;

  /// No description provided for @systemTheme.
  ///
  /// In es, this message translates to:
  /// **'Sistema'**
  String get systemTheme;

  /// No description provided for @lightTheme.
  ///
  /// In es, this message translates to:
  /// **'Claro'**
  String get lightTheme;

  /// No description provided for @darkTheme.
  ///
  /// In es, this message translates to:
  /// **'Oscuro'**
  String get darkTheme;

  /// No description provided for @language.
  ///
  /// In es, this message translates to:
  /// **'Idioma'**
  String get language;

  /// No description provided for @useSystemLanguage.
  ///
  /// In es, this message translates to:
  /// **'Usar idioma del sistema'**
  String get useSystemLanguage;

  /// No description provided for @spanishLanguage.
  ///
  /// In es, this message translates to:
  /// **'Español'**
  String get spanishLanguage;

  /// No description provided for @englishLanguage.
  ///
  /// In es, this message translates to:
  /// **'Inglés'**
  String get englishLanguage;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
