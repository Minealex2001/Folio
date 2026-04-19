import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ca.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_eu.dart';
import 'app_localizations_gl.dart';
import 'app_localizations_pt.dart';

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
    Locale('ca'),
    Locale('en'),
    Locale('es'),
    Locale('eu'),
    Locale('gl'),
    Locale('pt'),
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
  /// **'Nueva libreta'**
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
  /// **'Guardando la libreta cifrada en disco…'**
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
  /// **'Crear libreta nueva'**
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

  /// No description provided for @backupPlainNoPasswordHint.
  ///
  /// In es, this message translates to:
  /// **'Esta copia no está cifrada. No necesitas contraseña para importarla.'**
  String get backupPlainNoPasswordHint;

  /// No description provided for @importVault.
  ///
  /// In es, this message translates to:
  /// **'Importar libreta'**
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

  /// No description provided for @createStarterPagesTitle.
  ///
  /// In es, this message translates to:
  /// **'Crear páginas iniciales de ayuda'**
  String get createStarterPagesTitle;

  /// No description provided for @createStarterPagesBody.
  ///
  /// In es, this message translates to:
  /// **'Añade una pequeña guía con ejemplos, atajos y capacidades de Folio. Podrás borrar esas páginas después.'**
  String get createStarterPagesBody;

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
  /// **'Se creará una libreta cifrada en este equipo. Podrás añadir después Windows Hello, biometría o una passkey para desbloquear más rápido (Ajustes).'**
  String get readyBody;

  /// No description provided for @quillIntroTitle.
  ///
  /// In es, this message translates to:
  /// **'Conoce a Quill'**
  String get quillIntroTitle;

  /// No description provided for @quillIntroBody.
  ///
  /// In es, this message translates to:
  /// **'Quill es la asistente integrada de Folio. Puede ayudarte a escribir, editar y entender tus páginas, además de resolver dudas sobre cómo usar la app.'**
  String get quillIntroBody;

  /// No description provided for @quillIntroCapabilityWrite.
  ///
  /// In es, this message translates to:
  /// **'Puede redactar, resumir o reescribir contenido dentro de tus páginas.'**
  String get quillIntroCapabilityWrite;

  /// No description provided for @quillIntroCapabilityExplain.
  ///
  /// In es, this message translates to:
  /// **'También responde preguntas sobre Folio, atajos, bloques y cómo organizar tus notas.'**
  String get quillIntroCapabilityExplain;

  /// No description provided for @quillIntroCapabilityContext.
  ///
  /// In es, this message translates to:
  /// **'Puedes dejar que use la página abierta como contexto o elegir varias páginas de referencia.'**
  String get quillIntroCapabilityContext;

  /// No description provided for @quillIntroCapabilityExamples.
  ///
  /// In es, this message translates to:
  /// **'Lo mejor es hablarle de forma natural: Quill decide si responder o editar.'**
  String get quillIntroCapabilityExamples;

  /// No description provided for @quillIntroExamplesTitle.
  ///
  /// In es, this message translates to:
  /// **'Ejemplos rápidos'**
  String get quillIntroExamplesTitle;

  /// No description provided for @quillIntroExampleOne.
  ///
  /// In es, this message translates to:
  /// **'Resume esta página en tres puntos.'**
  String get quillIntroExampleOne;

  /// No description provided for @quillIntroExampleTwo.
  ///
  /// In es, this message translates to:
  /// **'Cambia el título y mejora la introducción.'**
  String get quillIntroExampleTwo;

  /// No description provided for @quillIntroExampleThree.
  ///
  /// In es, this message translates to:
  /// **'¿Cómo añado una imagen o una tabla?'**
  String get quillIntroExampleThree;

  /// No description provided for @quillIntroFootnote.
  ///
  /// In es, this message translates to:
  /// **'Si todavía no activas la IA, podrás hacerlo más tarde. Esta introducción es para que sepas qué puede hacer Quill cuando la uses.'**
  String get quillIntroFootnote;

  /// No description provided for @createVault.
  ///
  /// In es, this message translates to:
  /// **'Crear libreta'**
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

  /// No description provided for @passwordMustBeStrongError.
  ///
  /// In es, this message translates to:
  /// **'La contraseña debe ser Fuerte para continuar.'**
  String get passwordMustBeStrongError;

  /// No description provided for @passwordStrengthLabel.
  ///
  /// In es, this message translates to:
  /// **'Seguridad'**
  String get passwordStrengthLabel;

  /// No description provided for @passwordStrengthVeryWeak.
  ///
  /// In es, this message translates to:
  /// **'Muy débil'**
  String get passwordStrengthVeryWeak;

  /// No description provided for @passwordStrengthWeak.
  ///
  /// In es, this message translates to:
  /// **'Débil'**
  String get passwordStrengthWeak;

  /// No description provided for @passwordStrengthFair.
  ///
  /// In es, this message translates to:
  /// **'Aceptable'**
  String get passwordStrengthFair;

  /// No description provided for @passwordStrengthStrong.
  ///
  /// In es, this message translates to:
  /// **'Fuerte'**
  String get passwordStrengthStrong;

  /// No description provided for @showPassword.
  ///
  /// In es, this message translates to:
  /// **'Mostrar contraseña'**
  String get showPassword;

  /// No description provided for @hidePassword.
  ///
  /// In es, this message translates to:
  /// **'Ocultar contraseña'**
  String get hidePassword;

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
  /// **'No se pudo crear la libreta: {error}'**
  String createVaultFailedError(Object error);

  /// No description provided for @encryptedVault.
  ///
  /// In es, this message translates to:
  /// **'Libreta cifrada'**
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
  /// **'Contraseña incorrecta o libreta dañada.'**
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
  /// **'Copia de la libreta'**
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

  /// No description provided for @brazilianPortugueseLanguage.
  ///
  /// In es, this message translates to:
  /// **'Portugués (Brasil)'**
  String get brazilianPortugueseLanguage;

  /// No description provided for @catalanLanguage.
  ///
  /// In es, this message translates to:
  /// **'Catalán / Valenciano'**
  String get catalanLanguage;

  /// No description provided for @galicianLanguage.
  ///
  /// In es, this message translates to:
  /// **'Gallego'**
  String get galicianLanguage;

  /// No description provided for @basqueLanguage.
  ///
  /// In es, this message translates to:
  /// **'Euskera'**
  String get basqueLanguage;

  /// No description provided for @active.
  ///
  /// In es, this message translates to:
  /// **'Activado'**
  String get active;

  /// No description provided for @inactive.
  ///
  /// In es, this message translates to:
  /// **'Desactivado'**
  String get inactive;

  /// No description provided for @remove.
  ///
  /// In es, this message translates to:
  /// **'Quitar'**
  String get remove;

  /// No description provided for @enable.
  ///
  /// In es, this message translates to:
  /// **'Activar'**
  String get enable;

  /// No description provided for @register.
  ///
  /// In es, this message translates to:
  /// **'Registrar'**
  String get register;

  /// No description provided for @revoke.
  ///
  /// In es, this message translates to:
  /// **'Revocar'**
  String get revoke;

  /// No description provided for @save.
  ///
  /// In es, this message translates to:
  /// **'Guardar'**
  String get save;

  /// No description provided for @delete.
  ///
  /// In es, this message translates to:
  /// **'Eliminar'**
  String get delete;

  /// No description provided for @rename.
  ///
  /// In es, this message translates to:
  /// **'Renombrar'**
  String get rename;

  /// No description provided for @change.
  ///
  /// In es, this message translates to:
  /// **'Cambiar'**
  String get change;

  /// No description provided for @importAction.
  ///
  /// In es, this message translates to:
  /// **'Importar'**
  String get importAction;

  /// No description provided for @masterPassword.
  ///
  /// In es, this message translates to:
  /// **'Contraseña maestra'**
  String get masterPassword;

  /// No description provided for @confirmIdentity.
  ///
  /// In es, this message translates to:
  /// **'Confirma identidad'**
  String get confirmIdentity;

  /// No description provided for @quickUnlockTitle.
  ///
  /// In es, this message translates to:
  /// **'Desbloqueo rápido (Hello / biometría)'**
  String get quickUnlockTitle;

  /// No description provided for @passkeyThisDevice.
  ///
  /// In es, this message translates to:
  /// **'WebAuthn en este dispositivo'**
  String get passkeyThisDevice;

  /// No description provided for @lockOnMinimize.
  ///
  /// In es, this message translates to:
  /// **'Bloquear al minimizar'**
  String get lockOnMinimize;

  /// No description provided for @changeMasterPassword.
  ///
  /// In es, this message translates to:
  /// **'Cambiar contraseña maestra'**
  String get changeMasterPassword;

  /// No description provided for @requiresCurrentPassword.
  ///
  /// In es, this message translates to:
  /// **'Requiere contraseña actual'**
  String get requiresCurrentPassword;

  /// No description provided for @lockAutoByInactivity.
  ///
  /// In es, this message translates to:
  /// **'Bloqueo automático por inactividad'**
  String get lockAutoByInactivity;

  /// No description provided for @minutesShort.
  ///
  /// In es, this message translates to:
  /// **'{minutes} min'**
  String minutesShort(int minutes);

  /// No description provided for @settingsAppearanceHint.
  ///
  /// In es, this message translates to:
  /// **'Elige el brillo del tema, el origen del color de acento (Windows, Folio o personalizado), el zoom y el idioma.'**
  String get settingsAppearanceHint;

  /// No description provided for @backupFilePasswordLabel.
  ///
  /// In es, this message translates to:
  /// **'Contraseña del archivo de copia'**
  String get backupFilePasswordLabel;

  /// No description provided for @backupFilePasswordHelper.
  ///
  /// In es, this message translates to:
  /// **'Es la contraseña maestra con la que se creó la copia, no la de otro dispositivo.'**
  String get backupFilePasswordHelper;

  /// No description provided for @backupPasswordDialogTitle.
  ///
  /// In es, this message translates to:
  /// **'Contraseña de la copia'**
  String get backupPasswordDialogTitle;

  /// No description provided for @currentPasswordLabel.
  ///
  /// In es, this message translates to:
  /// **'Contraseña actual'**
  String get currentPasswordLabel;

  /// No description provided for @newPasswordLabel.
  ///
  /// In es, this message translates to:
  /// **'Nueva contraseña'**
  String get newPasswordLabel;

  /// No description provided for @confirmNewPasswordLabel.
  ///
  /// In es, this message translates to:
  /// **'Confirmar nueva contraseña'**
  String get confirmNewPasswordLabel;

  /// No description provided for @passwordStrengthWithValue.
  ///
  /// In es, this message translates to:
  /// **'Seguridad: {value}'**
  String passwordStrengthWithValue(Object value);

  /// No description provided for @fillAllFieldsError.
  ///
  /// In es, this message translates to:
  /// **'Completa todos los campos.'**
  String get fillAllFieldsError;

  /// No description provided for @newPasswordsMismatchError.
  ///
  /// In es, this message translates to:
  /// **'Las contraseñas nuevas no coinciden.'**
  String get newPasswordsMismatchError;

  /// No description provided for @newPasswordMustBeStrongError.
  ///
  /// In es, this message translates to:
  /// **'La nueva contraseña debe ser Fuerte.'**
  String get newPasswordMustBeStrongError;

  /// No description provided for @newPasswordMustDifferError.
  ///
  /// In es, this message translates to:
  /// **'La nueva contraseña debe ser distinta.'**
  String get newPasswordMustDifferError;

  /// No description provided for @incorrectPasswordError.
  ///
  /// In es, this message translates to:
  /// **'Contraseña incorrecta.'**
  String get incorrectPasswordError;

  /// No description provided for @useHelloBiometrics.
  ///
  /// In es, this message translates to:
  /// **'Usar Hello / biometría'**
  String get useHelloBiometrics;

  /// No description provided for @usePasskey.
  ///
  /// In es, this message translates to:
  /// **'Usar passkey'**
  String get usePasskey;

  /// No description provided for @quickUnlockEnabledSnack.
  ///
  /// In es, this message translates to:
  /// **'Desbloqueo rápido activado'**
  String get quickUnlockEnabledSnack;

  /// No description provided for @quickUnlockDisabledSnack.
  ///
  /// In es, this message translates to:
  /// **'Desbloqueo rápido desactivado'**
  String get quickUnlockDisabledSnack;

  /// No description provided for @quickUnlockEnableFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo activar el desbloqueo rápido.'**
  String get quickUnlockEnableFailed;

  /// No description provided for @passkeyRevokeConfirmTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Quitar la passkey?'**
  String get passkeyRevokeConfirmTitle;

  /// No description provided for @passkeyRevokeConfirmBody.
  ///
  /// In es, this message translates to:
  /// **'Necesitarás la contraseña maestra para desbloquear hasta que registres una passkey nueva en este dispositivo.'**
  String get passkeyRevokeConfirmBody;

  /// No description provided for @passkeyRegisteredSnack.
  ///
  /// In es, this message translates to:
  /// **'Passkey registrada'**
  String get passkeyRegisteredSnack;

  /// No description provided for @passkeyRevokedSnack.
  ///
  /// In es, this message translates to:
  /// **'Passkey revocada'**
  String get passkeyRevokedSnack;

  /// No description provided for @masterPasswordUpdatedSnack.
  ///
  /// In es, this message translates to:
  /// **'Contraseña maestra actualizada'**
  String get masterPasswordUpdatedSnack;

  /// No description provided for @backupSavedSuccessSnack.
  ///
  /// In es, this message translates to:
  /// **'Copia guardada correctamente.'**
  String get backupSavedSuccessSnack;

  /// No description provided for @exportFailedError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo exportar: {error}'**
  String exportFailedError(Object error);

  /// No description provided for @importFailedGenericError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo importar: {error}'**
  String importFailedGenericError(Object error);

  /// No description provided for @wipeFailedError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo borrar la libreta: {error}'**
  String wipeFailedError(Object error);

  /// No description provided for @filePathReadError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo leer la ruta del archivo.'**
  String get filePathReadError;

  /// No description provided for @importedVaultSuccessSnack.
  ///
  /// In es, this message translates to:
  /// **'Libreta importada. Aparece en el selector del panel lateral; la actual sigue igual.'**
  String get importedVaultSuccessSnack;

  /// No description provided for @exportVaultDialogTitle.
  ///
  /// In es, this message translates to:
  /// **'Exportar copia de la libreta'**
  String get exportVaultDialogTitle;

  /// No description provided for @exportVaultDialogBody.
  ///
  /// In es, this message translates to:
  /// **'Para crear un archivo de copia, confirma tu identidad con la libreta actual desbloqueada.'**
  String get exportVaultDialogBody;

  /// No description provided for @verifyAndExport.
  ///
  /// In es, this message translates to:
  /// **'Verificar y exportar'**
  String get verifyAndExport;

  /// No description provided for @saveVaultBackupDialogTitle.
  ///
  /// In es, this message translates to:
  /// **'Guardar copia de la libreta'**
  String get saveVaultBackupDialogTitle;

  /// No description provided for @importVaultDialogTitle.
  ///
  /// In es, this message translates to:
  /// **'Importar copia de la libreta'**
  String get importVaultDialogTitle;

  /// No description provided for @importVaultDialogBody.
  ///
  /// In es, this message translates to:
  /// **'Se añadirá una libreta nueva desde el archivo. La libreta que tienes abierta ahora no se borra ni se modifica.\n\nLa contraseña del archivo será la de la libreta importada (para abrirla al cambiar de libreta).\n\nLa passkey y el desbloqueo rápido (Hello / biometría) no van en la copia y no son transferibles; podrás configurarlos en esa libreta después.\n\n¿Continuar?'**
  String get importVaultDialogBody;

  /// No description provided for @verifyAndContinue.
  ///
  /// In es, this message translates to:
  /// **'Verificar y continuar'**
  String get verifyAndContinue;

  /// No description provided for @verifyAndDelete.
  ///
  /// In es, this message translates to:
  /// **'Verificar con contraseña y borrar'**
  String get verifyAndDelete;

  /// No description provided for @importIdentityBody.
  ///
  /// In es, this message translates to:
  /// **'Demuestra que eres tú con la libreta actual desbloqueada antes de importar.'**
  String get importIdentityBody;

  /// No description provided for @wipeVaultDialogTitle.
  ///
  /// In es, this message translates to:
  /// **'Borrar libreta'**
  String get wipeVaultDialogTitle;

  /// No description provided for @wipeVaultDialogBody.
  ///
  /// In es, this message translates to:
  /// **'Se eliminarán todas las páginas y la contraseña maestra dejará de ser válida. Esta acción no se puede deshacer.\n\n¿Seguro que quieres continuar?'**
  String get wipeVaultDialogBody;

  /// No description provided for @wipeIdentityBody.
  ///
  /// In es, this message translates to:
  /// **'Para borrar la libreta, demuestra que eres tú.'**
  String get wipeIdentityBody;

  /// No description provided for @exportZipTitle.
  ///
  /// In es, this message translates to:
  /// **'Exportar copia (.zip)'**
  String get exportZipTitle;

  /// No description provided for @exportZipSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Contraseña, Hello o passkey de la libreta actual'**
  String get exportZipSubtitle;

  /// No description provided for @importZipTitle.
  ///
  /// In es, this message translates to:
  /// **'Importar copia (.zip)'**
  String get importZipTitle;

  /// No description provided for @importZipSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Añade libreta nueva · identidad actual + contraseña del archivo'**
  String get importZipSubtitle;

  /// No description provided for @backupInfoBody.
  ///
  /// In es, this message translates to:
  /// **'El archivo contiene los mismos datos cifrados que en disco (vault.keys y vault.bin), sin exponer el contenido en claro. Las imágenes en adjuntos van tal cual.\n\nLa passkey y el desbloqueo rápido no se incluyen en la copia y no son transferibles entre dispositivos; en cada libreta importada podrás configurarlos de nuevo.\n\nImportar añade una libreta nueva; no sustituye la que tienes abierta.'**
  String get backupInfoBody;

  /// No description provided for @wipeCardTitle.
  ///
  /// In es, this message translates to:
  /// **'Borrar libreta y empezar de cero'**
  String get wipeCardTitle;

  /// No description provided for @wipeCardSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Requiere contraseña, Hello o passkey.'**
  String get wipeCardSubtitle;

  /// No description provided for @switchVaultTooltip.
  ///
  /// In es, this message translates to:
  /// **'Cambiar libreta'**
  String get switchVaultTooltip;

  /// No description provided for @switchVaultTitle.
  ///
  /// In es, this message translates to:
  /// **'Cambiar de libreta'**
  String get switchVaultTitle;

  /// No description provided for @switchVaultBody.
  ///
  /// In es, this message translates to:
  /// **'Se cerrará la sesión de esta libreta y tendrás que desbloquear la otra con su contraseña, Hello o passkey (si los tienes configurados allí).'**
  String get switchVaultBody;

  /// No description provided for @renameVaultTitle.
  ///
  /// In es, this message translates to:
  /// **'Renombrar libreta'**
  String get renameVaultTitle;

  /// No description provided for @nameLabel.
  ///
  /// In es, this message translates to:
  /// **'Nombre'**
  String get nameLabel;

  /// No description provided for @deleteOtherVaultTitle.
  ///
  /// In es, this message translates to:
  /// **'Eliminar otra libreta'**
  String get deleteOtherVaultTitle;

  /// No description provided for @deleteVaultConfirmTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Eliminar libreta?'**
  String get deleteVaultConfirmTitle;

  /// No description provided for @deleteVaultConfirmBody.
  ///
  /// In es, this message translates to:
  /// **'Se borrará por completo «{name}». No se puede deshacer.'**
  String deleteVaultConfirmBody(Object name);

  /// No description provided for @vaultDeletedSnack.
  ///
  /// In es, this message translates to:
  /// **'Libreta eliminada.'**
  String get vaultDeletedSnack;

  /// No description provided for @noOtherVaultsSnack.
  ///
  /// In es, this message translates to:
  /// **'No hay otras libretas que borrar.'**
  String get noOtherVaultsSnack;

  /// No description provided for @addVault.
  ///
  /// In es, this message translates to:
  /// **'Añadir libreta'**
  String get addVault;

  /// No description provided for @renameActiveVault.
  ///
  /// In es, this message translates to:
  /// **'Renombrar libreta activa'**
  String get renameActiveVault;

  /// No description provided for @deleteOtherVault.
  ///
  /// In es, this message translates to:
  /// **'Eliminar otra libreta…'**
  String get deleteOtherVault;

  /// No description provided for @activeVaultLabel.
  ///
  /// In es, this message translates to:
  /// **'Libreta activa'**
  String get activeVaultLabel;

  /// No description provided for @sidebarVaultsLoading.
  ///
  /// In es, this message translates to:
  /// **'Cargando libretas…'**
  String get sidebarVaultsLoading;

  /// No description provided for @sidebarVaultsEmpty.
  ///
  /// In es, this message translates to:
  /// **'No hay libretas disponibles'**
  String get sidebarVaultsEmpty;

  /// No description provided for @forceSyncTooltip.
  ///
  /// In es, this message translates to:
  /// **'Forzar sincronización'**
  String get forceSyncTooltip;

  /// No description provided for @searchDialogFooterHint.
  ///
  /// In es, this message translates to:
  /// **'Enter abre el resultado resaltado · Ctrl+↑ / Ctrl+↓ navegar · Esc cierra'**
  String get searchDialogFooterHint;

  /// No description provided for @searchFilterTasks.
  ///
  /// In es, this message translates to:
  /// **'Tareas'**
  String get searchFilterTasks;

  /// No description provided for @searchRecentQueries.
  ///
  /// In es, this message translates to:
  /// **'Búsquedas recientes'**
  String get searchRecentQueries;

  /// No description provided for @searchShortcutsHelpTooltip.
  ///
  /// In es, this message translates to:
  /// **'Atajos de teclado'**
  String get searchShortcutsHelpTooltip;

  /// No description provided for @searchShortcutsHelpTitle.
  ///
  /// In es, this message translates to:
  /// **'Búsqueda global'**
  String get searchShortcutsHelpTitle;

  /// No description provided for @searchShortcutsHelpBody.
  ///
  /// In es, this message translates to:
  /// **'Enter: abrir el resultado resaltado\nCtrl+↑ o Ctrl+↓: anterior / siguiente\nEsc: cerrar'**
  String get searchShortcutsHelpBody;

  /// No description provided for @renamePageTitle.
  ///
  /// In es, this message translates to:
  /// **'Renombrar página'**
  String get renamePageTitle;

  /// No description provided for @titleLabel.
  ///
  /// In es, this message translates to:
  /// **'Título'**
  String get titleLabel;

  /// No description provided for @rootPage.
  ///
  /// In es, this message translates to:
  /// **'Raíz'**
  String get rootPage;

  /// No description provided for @movePageTitle.
  ///
  /// In es, this message translates to:
  /// **'Mover «{title}»'**
  String movePageTitle(Object title);

  /// No description provided for @subpage.
  ///
  /// In es, this message translates to:
  /// **'Subpágina'**
  String get subpage;

  /// No description provided for @move.
  ///
  /// In es, this message translates to:
  /// **'Mover'**
  String get move;

  /// No description provided for @pages.
  ///
  /// In es, this message translates to:
  /// **'Páginas'**
  String get pages;

  /// No description provided for @pageOutlineTitle.
  ///
  /// In es, this message translates to:
  /// **'Índice'**
  String get pageOutlineTitle;

  /// No description provided for @pageOutlineEmpty.
  ///
  /// In es, this message translates to:
  /// **'Añade encabezados (H1–H3) para generar el índice.'**
  String get pageOutlineEmpty;

  /// No description provided for @showPageOutline.
  ///
  /// In es, this message translates to:
  /// **'Mostrar índice'**
  String get showPageOutline;

  /// No description provided for @hidePageOutline.
  ///
  /// In es, this message translates to:
  /// **'Ocultar índice'**
  String get hidePageOutline;

  /// No description provided for @backlinksTitle.
  ///
  /// In es, this message translates to:
  /// **'Referencias entrantes'**
  String get backlinksTitle;

  /// No description provided for @backlinksEmpty.
  ///
  /// In es, this message translates to:
  /// **'Ninguna página enlaza aquí todavía.'**
  String get backlinksEmpty;

  /// No description provided for @showBacklinks.
  ///
  /// In es, this message translates to:
  /// **'Mostrar referencias'**
  String get showBacklinks;

  /// No description provided for @hideBacklinks.
  ///
  /// In es, this message translates to:
  /// **'Ocultar referencias'**
  String get hideBacklinks;

  /// No description provided for @commentsTitle.
  ///
  /// In es, this message translates to:
  /// **'Comentarios'**
  String get commentsTitle;

  /// No description provided for @commentsEmpty.
  ///
  /// In es, this message translates to:
  /// **'Sin comentarios. ¡Sé el primero!'**
  String get commentsEmpty;

  /// No description provided for @commentsAddHint.
  ///
  /// In es, this message translates to:
  /// **'Escribe un comentario…'**
  String get commentsAddHint;

  /// No description provided for @commentsResolve.
  ///
  /// In es, this message translates to:
  /// **'Resolver'**
  String get commentsResolve;

  /// No description provided for @commentsReopen.
  ///
  /// In es, this message translates to:
  /// **'Reabrir'**
  String get commentsReopen;

  /// No description provided for @commentsDelete.
  ///
  /// In es, this message translates to:
  /// **'Eliminar'**
  String get commentsDelete;

  /// No description provided for @commentsResolved.
  ///
  /// In es, this message translates to:
  /// **'Resuelto'**
  String get commentsResolved;

  /// No description provided for @showComments.
  ///
  /// In es, this message translates to:
  /// **'Mostrar comentarios'**
  String get showComments;

  /// No description provided for @hideComments.
  ///
  /// In es, this message translates to:
  /// **'Ocultar comentarios'**
  String get hideComments;

  /// No description provided for @propTitle.
  ///
  /// In es, this message translates to:
  /// **'Propiedades'**
  String get propTitle;

  /// No description provided for @propAdd.
  ///
  /// In es, this message translates to:
  /// **'Añadir propiedad'**
  String get propAdd;

  /// No description provided for @propRemove.
  ///
  /// In es, this message translates to:
  /// **'Eliminar propiedad'**
  String get propRemove;

  /// No description provided for @propRename.
  ///
  /// In es, this message translates to:
  /// **'Renombrar'**
  String get propRename;

  /// No description provided for @propTypeText.
  ///
  /// In es, this message translates to:
  /// **'Texto'**
  String get propTypeText;

  /// No description provided for @propTypeNumber.
  ///
  /// In es, this message translates to:
  /// **'Número'**
  String get propTypeNumber;

  /// No description provided for @propTypeDate.
  ///
  /// In es, this message translates to:
  /// **'Fecha'**
  String get propTypeDate;

  /// No description provided for @propTypeSelect.
  ///
  /// In es, this message translates to:
  /// **'Selección'**
  String get propTypeSelect;

  /// No description provided for @propTypeStatus.
  ///
  /// In es, this message translates to:
  /// **'Estado'**
  String get propTypeStatus;

  /// No description provided for @propTypeUrl.
  ///
  /// In es, this message translates to:
  /// **'URL'**
  String get propTypeUrl;

  /// No description provided for @propTypeCheckbox.
  ///
  /// In es, this message translates to:
  /// **'Casilla'**
  String get propTypeCheckbox;

  /// No description provided for @propNotSet.
  ///
  /// In es, this message translates to:
  /// **'Vacío'**
  String get propNotSet;

  /// No description provided for @propAddOption.
  ///
  /// In es, this message translates to:
  /// **'Añadir opción'**
  String get propAddOption;

  /// No description provided for @propStatusNotStarted.
  ///
  /// In es, this message translates to:
  /// **'No iniciado'**
  String get propStatusNotStarted;

  /// No description provided for @propStatusInProgress.
  ///
  /// In es, this message translates to:
  /// **'En progreso'**
  String get propStatusInProgress;

  /// No description provided for @propStatusDone.
  ///
  /// In es, this message translates to:
  /// **'Hecho'**
  String get propStatusDone;

  /// No description provided for @tagSectionTitle.
  ///
  /// In es, this message translates to:
  /// **'Etiquetas'**
  String get tagSectionTitle;

  /// No description provided for @tagAdd.
  ///
  /// In es, this message translates to:
  /// **'Añadir etiqueta'**
  String get tagAdd;

  /// No description provided for @tagRemove.
  ///
  /// In es, this message translates to:
  /// **'Eliminar etiqueta'**
  String get tagRemove;

  /// No description provided for @tagFilterAll.
  ///
  /// In es, this message translates to:
  /// **'Todas'**
  String get tagFilterAll;

  /// No description provided for @tagInputHint.
  ///
  /// In es, this message translates to:
  /// **'Nueva etiqueta…'**
  String get tagInputHint;

  /// No description provided for @tagNoPagesForFilter.
  ///
  /// In es, this message translates to:
  /// **'No hay páginas con esta etiqueta.'**
  String get tagNoPagesForFilter;

  /// No description provided for @tocBlockTitle.
  ///
  /// In es, this message translates to:
  /// **'Tabla de contenidos'**
  String get tocBlockTitle;

  /// No description provided for @showSidebar.
  ///
  /// In es, this message translates to:
  /// **'Mostrar panel lateral'**
  String get showSidebar;

  /// No description provided for @hideSidebar.
  ///
  /// In es, this message translates to:
  /// **'Ocultar panel lateral'**
  String get hideSidebar;

  /// No description provided for @resizeSidebarHandle.
  ///
  /// In es, this message translates to:
  /// **'Redimensionar panel lateral'**
  String get resizeSidebarHandle;

  /// No description provided for @resizeSidebarHandleHint.
  ///
  /// In es, this message translates to:
  /// **'Arrastra horizontalmente para cambiar el ancho del panel'**
  String get resizeSidebarHandleHint;

  /// No description provided for @resizeAiPanelHeightHandle.
  ///
  /// In es, this message translates to:
  /// **'Redimensionar altura del asistente'**
  String get resizeAiPanelHeightHandle;

  /// No description provided for @resizeAiPanelHeightHandleHint.
  ///
  /// In es, this message translates to:
  /// **'Arrastra verticalmente para cambiar la altura del panel'**
  String get resizeAiPanelHeightHandleHint;

  /// No description provided for @sidebarAutoRevealTitle.
  ///
  /// In es, this message translates to:
  /// **'Mostrar panel al acercar al borde'**
  String get sidebarAutoRevealTitle;

  /// No description provided for @sidebarAutoRevealSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Si el panel está oculto, acerca el puntero al borde izquierdo para verlo un momento.'**
  String get sidebarAutoRevealSubtitle;

  /// No description provided for @newRootPageTooltip.
  ///
  /// In es, this message translates to:
  /// **'Nueva página (raíz)'**
  String get newRootPageTooltip;

  /// No description provided for @blockOptions.
  ///
  /// In es, this message translates to:
  /// **'Opciones del bloque'**
  String get blockOptions;

  /// No description provided for @meetingNoteTitle.
  ///
  /// In es, this message translates to:
  /// **'Nota de reunión'**
  String get meetingNoteTitle;

  /// No description provided for @meetingNoteDesktopOnly.
  ///
  /// In es, this message translates to:
  /// **'Solo disponible en escritorio.'**
  String get meetingNoteDesktopOnly;

  /// No description provided for @meetingNoteStartRecording.
  ///
  /// In es, this message translates to:
  /// **'Iniciar grabación'**
  String get meetingNoteStartRecording;

  /// No description provided for @meetingNotePreparing.
  ///
  /// In es, this message translates to:
  /// **'Preparando…'**
  String get meetingNotePreparing;

  /// No description provided for @meetingNoteTranscriptionLanguage.
  ///
  /// In es, this message translates to:
  /// **'Idioma de transcripción'**
  String get meetingNoteTranscriptionLanguage;

  /// No description provided for @meetingNoteLangAuto.
  ///
  /// In es, this message translates to:
  /// **'Automático'**
  String get meetingNoteLangAuto;

  /// No description provided for @meetingNoteLangEs.
  ///
  /// In es, this message translates to:
  /// **'Español'**
  String get meetingNoteLangEs;

  /// No description provided for @meetingNoteLangEn.
  ///
  /// In es, this message translates to:
  /// **'Inglés'**
  String get meetingNoteLangEn;

  /// No description provided for @meetingNoteLangPt.
  ///
  /// In es, this message translates to:
  /// **'Portugués'**
  String get meetingNoteLangPt;

  /// No description provided for @meetingNoteLangFr.
  ///
  /// In es, this message translates to:
  /// **'Francés'**
  String get meetingNoteLangFr;

  /// No description provided for @meetingNoteLangIt.
  ///
  /// In es, this message translates to:
  /// **'Italiano'**
  String get meetingNoteLangIt;

  /// No description provided for @meetingNoteLangDe.
  ///
  /// In es, this message translates to:
  /// **'Alemán'**
  String get meetingNoteLangDe;

  /// No description provided for @meetingNoteDevicesInSettings.
  ///
  /// In es, this message translates to:
  /// **'Los dispositivos de entrada/salida se configuran en Ajustes > Escritorio.'**
  String get meetingNoteDevicesInSettings;

  /// No description provided for @meetingNoteModelInSettings.
  ///
  /// In es, this message translates to:
  /// **'Modelo de transcripción: {model} (en Ajustes > Escritorio).'**
  String meetingNoteModelInSettings(Object model);

  /// No description provided for @meetingNoteDescription.
  ///
  /// In es, this message translates to:
  /// **'Graba micrófono y audio del sistema. La transcripción se genera localmente.'**
  String get meetingNoteDescription;

  /// No description provided for @meetingNoteWhisperInitError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo inicializar Whisper: {error}'**
  String meetingNoteWhisperInitError(Object error);

  /// No description provided for @meetingNoteAudioAccessError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo acceder al micrófono/dispositivos.'**
  String get meetingNoteAudioAccessError;

  /// No description provided for @meetingNoteMicrophoneAccessError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo acceder al micrófono.'**
  String get meetingNoteMicrophoneAccessError;

  /// No description provided for @meetingNoteChunkTranscriptionError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo transcribir este fragmento de audio.'**
  String get meetingNoteChunkTranscriptionError;

  /// No description provided for @meetingNoteProviderLocal.
  ///
  /// In es, this message translates to:
  /// **'Local (Whisper)'**
  String get meetingNoteProviderLocal;

  /// No description provided for @meetingNoteProviderCloud.
  ///
  /// In es, this message translates to:
  /// **'Quill Cloud'**
  String get meetingNoteProviderCloud;

  /// No description provided for @meetingNoteProviderCloudCost.
  ///
  /// In es, this message translates to:
  /// **'1 Tinta por cada 5 min. grabados'**
  String get meetingNoteProviderCloudCost;

  /// No description provided for @meetingNoteCloudFallbackNotice.
  ///
  /// In es, this message translates to:
  /// **'Cloud no disponible. Usando Whisper local.'**
  String get meetingNoteCloudFallbackNotice;

  /// No description provided for @meetingNoteCloudInkExhaustedNotice.
  ///
  /// In es, this message translates to:
  /// **'Tinta insuficiente. Cambiando a Whisper local.'**
  String get meetingNoteCloudInkExhaustedNotice;

  /// No description provided for @meetingNoteCloudRecordingBadge.
  ///
  /// In es, this message translates to:
  /// **'Quill Cloud | Idioma: {language}'**
  String meetingNoteCloudRecordingBadge(Object language);

  /// No description provided for @meetingNoteCloudProcessing.
  ///
  /// In es, this message translates to:
  /// **'Procesando con Quill Cloud…'**
  String get meetingNoteCloudProcessing;

  /// No description provided for @meetingNoteCloudProcessingSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Detectando hablantes y mejorando calidad. Un momento.'**
  String get meetingNoteCloudProcessingSubtitle;

  /// No description provided for @meetingNoteCloudProgress.
  ///
  /// In es, this message translates to:
  /// **'Segmentos procesados: {done}/{total}'**
  String meetingNoteCloudProgress(int done, int total);

  /// No description provided for @meetingNoteCloudEta.
  ///
  /// In es, this message translates to:
  /// **'Tiempo restante estimado: {remaining}'**
  String meetingNoteCloudEta(Object remaining);

  /// No description provided for @meetingNoteCloudEtaCalculating.
  ///
  /// In es, this message translates to:
  /// **'Calculando tiempo restante...'**
  String get meetingNoteCloudEtaCalculating;

  /// No description provided for @meetingNoteCloudRequiresAccount.
  ///
  /// In es, this message translates to:
  /// **'Requiere cuenta Folio Cloud con Tinta.'**
  String get meetingNoteCloudRequiresAccount;

  /// No description provided for @meetingNoteCloudRequiresAiEnabled.
  ///
  /// In es, this message translates to:
  /// **'Activa la IA en Ajustes para usar la transcripción en la nube (Quill Cloud).'**
  String get meetingNoteCloudRequiresAiEnabled;

  /// No description provided for @meetingNoteHardwareSummary.
  ///
  /// In es, this message translates to:
  /// **'{cpus} núcleos · {ramLabel}'**
  String meetingNoteHardwareSummary(int cpus, Object ramLabel);

  /// No description provided for @meetingNoteHardwareRamUnknown.
  ///
  /// In es, this message translates to:
  /// **'RAM desconocida'**
  String get meetingNoteHardwareRamUnknown;

  /// No description provided for @meetingNoteHardwareRecommended.
  ///
  /// In es, this message translates to:
  /// **'Modelo recomendado para este equipo: {modelLabel}'**
  String meetingNoteHardwareRecommended(Object modelLabel);

  /// No description provided for @meetingNoteLocalTranscriptionNotViable.
  ///
  /// In es, this message translates to:
  /// **'Este equipo no cumple los requisitos mínimos para transcripción local. Solo se guardará el audio, salvo que actives «Forzar transcripción local» en Ajustes o uses Quill Cloud con IA activada.'**
  String get meetingNoteLocalTranscriptionNotViable;

  /// No description provided for @meetingNoteGenerateTranscription.
  ///
  /// In es, this message translates to:
  /// **'Generar transcripción'**
  String get meetingNoteGenerateTranscription;

  /// No description provided for @meetingNoteGenerateTranscriptionSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Desactívalo para guardar solo el audio en esta nota.'**
  String get meetingNoteGenerateTranscriptionSubtitle;

  /// No description provided for @meetingNoteSettingsAutoWhisperModel.
  ///
  /// In es, this message translates to:
  /// **'Elegir modelo automáticamente según el hardware'**
  String get meetingNoteSettingsAutoWhisperModel;

  /// No description provided for @meetingNoteSettingsForceLocalTranscription.
  ///
  /// In es, this message translates to:
  /// **'Forzar transcripción local (puede ir lento o inestable)'**
  String get meetingNoteSettingsForceLocalTranscription;

  /// No description provided for @meetingNoteSettingsHardwareIntro.
  ///
  /// In es, this message translates to:
  /// **'Rendimiento detectado para transcripción local.'**
  String get meetingNoteSettingsHardwareIntro;

  /// No description provided for @meetingNoteRecordingAudioOnlyBadge.
  ///
  /// In es, this message translates to:
  /// **'Solo audio'**
  String get meetingNoteRecordingAudioOnlyBadge;

  /// No description provided for @meetingNotePerNoteTranscriptionOffHint.
  ///
  /// In es, this message translates to:
  /// **'La transcripción está desactivada para esta nota.'**
  String get meetingNotePerNoteTranscriptionOffHint;

  /// No description provided for @meetingNoteTranscriptionProvider.
  ///
  /// In es, this message translates to:
  /// **'Motor de transcripción'**
  String get meetingNoteTranscriptionProvider;

  /// No description provided for @meetingNoteRecordingTime.
  ///
  /// In es, this message translates to:
  /// **'Grabando  {mm}:{ss}'**
  String meetingNoteRecordingTime(Object mm, Object ss);

  /// No description provided for @meetingNoteRecordingBadge.
  ///
  /// In es, this message translates to:
  /// **'Idioma: {language} | Modelo: {model}'**
  String meetingNoteRecordingBadge(Object language, Object model);

  /// No description provided for @meetingNoteSystemAudioCaptured.
  ///
  /// In es, this message translates to:
  /// **'Audio del sistema capturado'**
  String get meetingNoteSystemAudioCaptured;

  /// No description provided for @meetingNoteStop.
  ///
  /// In es, this message translates to:
  /// **'Detener'**
  String get meetingNoteStop;

  /// No description provided for @meetingNoteWaitingTranscription.
  ///
  /// In es, this message translates to:
  /// **'Esperando transcripción…'**
  String get meetingNoteWaitingTranscription;

  /// No description provided for @meetingNoteTranscribing.
  ///
  /// In es, this message translates to:
  /// **'Transcribiendo…'**
  String get meetingNoteTranscribing;

  /// No description provided for @meetingNoteTranscriptionTitle.
  ///
  /// In es, this message translates to:
  /// **'Transcripción'**
  String get meetingNoteTranscriptionTitle;

  /// No description provided for @meetingNoteNoTranscription.
  ///
  /// In es, this message translates to:
  /// **'Sin transcripción disponible.'**
  String get meetingNoteNoTranscription;

  /// No description provided for @meetingNoteNewRecording.
  ///
  /// In es, this message translates to:
  /// **'Nueva grabación'**
  String get meetingNoteNewRecording;

  /// No description provided for @meetingNoteSettingsSection.
  ///
  /// In es, this message translates to:
  /// **'Nota de reunión (audio)'**
  String get meetingNoteSettingsSection;

  /// No description provided for @meetingNoteSettingsDescription.
  ///
  /// In es, this message translates to:
  /// **'Estos dispositivos se usan por defecto al grabar una nota de reunión.'**
  String get meetingNoteSettingsDescription;

  /// No description provided for @meetingNoteSettingsMicrophone.
  ///
  /// In es, this message translates to:
  /// **'Micrófono'**
  String get meetingNoteSettingsMicrophone;

  /// No description provided for @meetingNoteSettingsRefreshDevices.
  ///
  /// In es, this message translates to:
  /// **'Actualizar lista'**
  String get meetingNoteSettingsRefreshDevices;

  /// No description provided for @meetingNoteSettingsSystemDefault.
  ///
  /// In es, this message translates to:
  /// **'Predeterminado del sistema'**
  String get meetingNoteSettingsSystemDefault;

  /// No description provided for @meetingNoteSettingsSystemOutput.
  ///
  /// In es, this message translates to:
  /// **'Salida del sistema (loopback)'**
  String get meetingNoteSettingsSystemOutput;

  /// No description provided for @meetingNoteSettingsModel.
  ///
  /// In es, this message translates to:
  /// **'Modelo de transcripción'**
  String get meetingNoteSettingsModel;

  /// No description provided for @meetingNoteDiarizationHint.
  ///
  /// In es, this message translates to:
  /// **'Procesamiento 100% local en tu dispositivo.'**
  String get meetingNoteDiarizationHint;

  /// No description provided for @meetingNoteModelTiny.
  ///
  /// In es, this message translates to:
  /// **'Rápido'**
  String get meetingNoteModelTiny;

  /// No description provided for @meetingNoteModelBase.
  ///
  /// In es, this message translates to:
  /// **'Equilibrado'**
  String get meetingNoteModelBase;

  /// No description provided for @meetingNoteModelSmall.
  ///
  /// In es, this message translates to:
  /// **'Preciso'**
  String get meetingNoteModelSmall;

  /// No description provided for @meetingNoteModelMedium.
  ///
  /// In es, this message translates to:
  /// **'Avanzado'**
  String get meetingNoteModelMedium;

  /// No description provided for @meetingNoteModelTurbo.
  ///
  /// In es, this message translates to:
  /// **'Máxima calidad'**
  String get meetingNoteModelTurbo;

  /// No description provided for @meetingNoteCopyTranscript.
  ///
  /// In es, this message translates to:
  /// **'Copiar transcripción'**
  String get meetingNoteCopyTranscript;

  /// No description provided for @meetingNoteSendToAi.
  ///
  /// In es, this message translates to:
  /// **'Enviar a IA…'**
  String get meetingNoteSendToAi;

  /// No description provided for @meetingNoteAiPayloadLabel.
  ///
  /// In es, this message translates to:
  /// **'¿Qué enviar a la IA?'**
  String get meetingNoteAiPayloadLabel;

  /// No description provided for @meetingNoteAiPayloadTranscript.
  ///
  /// In es, this message translates to:
  /// **'Solo transcripción'**
  String get meetingNoteAiPayloadTranscript;

  /// No description provided for @meetingNoteAiPayloadAudio.
  ///
  /// In es, this message translates to:
  /// **'Solo audio'**
  String get meetingNoteAiPayloadAudio;

  /// No description provided for @meetingNoteAiPayloadBoth.
  ///
  /// In es, this message translates to:
  /// **'Transcripción + audio'**
  String get meetingNoteAiPayloadBoth;

  /// No description provided for @meetingNoteAiInstructionHint.
  ///
  /// In es, this message translates to:
  /// **'p. ej. resume los puntos clave'**
  String get meetingNoteAiInstructionHint;

  /// No description provided for @meetingNoteAiNoAudio.
  ///
  /// In es, this message translates to:
  /// **'No hay audio disponible para este modo'**
  String get meetingNoteAiNoAudio;

  /// No description provided for @meetingNoteAiInstruction.
  ///
  /// In es, this message translates to:
  /// **'Instrucción para la IA'**
  String get meetingNoteAiInstruction;

  /// No description provided for @dragToReorder.
  ///
  /// In es, this message translates to:
  /// **'Arrastrar para reordenar'**
  String get dragToReorder;

  /// No description provided for @addBlock.
  ///
  /// In es, this message translates to:
  /// **'Añadir bloque'**
  String get addBlock;

  /// No description provided for @blockMentionPageSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Mencionar página'**
  String get blockMentionPageSubtitle;

  /// No description provided for @blockTypesSheetTitle.
  ///
  /// In es, this message translates to:
  /// **'Tipos de bloque'**
  String get blockTypesSheetTitle;

  /// No description provided for @blockTypesSheetSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Elige cómo se verá este bloque'**
  String get blockTypesSheetSubtitle;

  /// No description provided for @blockTypeFilterEmpty.
  ///
  /// In es, this message translates to:
  /// **'Nada coincide con tu búsqueda'**
  String get blockTypeFilterEmpty;

  /// No description provided for @fileNotFound.
  ///
  /// In es, this message translates to:
  /// **'Archivo no encontrado'**
  String get fileNotFound;

  /// No description provided for @couldNotLoadImage.
  ///
  /// In es, this message translates to:
  /// **'No se pudo cargar la imagen'**
  String get couldNotLoadImage;

  /// No description provided for @noImageHint.
  ///
  /// In es, this message translates to:
  /// **'Sin imagen · menú ⋮ o botón de abajo'**
  String get noImageHint;

  /// No description provided for @chooseImage.
  ///
  /// In es, this message translates to:
  /// **'Elegir imagen'**
  String get chooseImage;

  /// No description provided for @replaceFile.
  ///
  /// In es, this message translates to:
  /// **'Cambiar archivo'**
  String get replaceFile;

  /// No description provided for @removeFile.
  ///
  /// In es, this message translates to:
  /// **'Quitar archivo'**
  String get removeFile;

  /// No description provided for @replaceVideo.
  ///
  /// In es, this message translates to:
  /// **'Cambiar video'**
  String get replaceVideo;

  /// No description provided for @removeVideo.
  ///
  /// In es, this message translates to:
  /// **'Quitar video'**
  String get removeVideo;

  /// No description provided for @openExternal.
  ///
  /// In es, this message translates to:
  /// **'Abrir externo'**
  String get openExternal;

  /// No description provided for @openVideoExternal.
  ///
  /// In es, this message translates to:
  /// **'Abrir video externo'**
  String get openVideoExternal;

  /// No description provided for @play.
  ///
  /// In es, this message translates to:
  /// **'Reproducir'**
  String get play;

  /// No description provided for @pause.
  ///
  /// In es, this message translates to:
  /// **'Pausar'**
  String get pause;

  /// No description provided for @mute.
  ///
  /// In es, this message translates to:
  /// **'Silenciar'**
  String get mute;

  /// No description provided for @unmute.
  ///
  /// In es, this message translates to:
  /// **'Activar sonido'**
  String get unmute;

  /// No description provided for @fileResolveError.
  ///
  /// In es, this message translates to:
  /// **'Error resolviendo archivo'**
  String get fileResolveError;

  /// No description provided for @videoResolveError.
  ///
  /// In es, this message translates to:
  /// **'Error resolviendo video'**
  String get videoResolveError;

  /// No description provided for @fileMissing.
  ///
  /// In es, this message translates to:
  /// **'No se encuentra el archivo'**
  String get fileMissing;

  /// No description provided for @videoMissing.
  ///
  /// In es, this message translates to:
  /// **'No se encuentra el video'**
  String get videoMissing;

  /// No description provided for @chooseFile.
  ///
  /// In es, this message translates to:
  /// **'Elegir archivo'**
  String get chooseFile;

  /// No description provided for @chooseVideo.
  ///
  /// In es, this message translates to:
  /// **'Elegir video'**
  String get chooseVideo;

  /// No description provided for @noEmbeddedPreview.
  ///
  /// In es, this message translates to:
  /// **'Sin preview embebido para este tipo'**
  String get noEmbeddedPreview;

  /// No description provided for @couldNotReadFile.
  ///
  /// In es, this message translates to:
  /// **'No se pudo leer el archivo'**
  String get couldNotReadFile;

  /// No description provided for @couldNotLoadVideo.
  ///
  /// In es, this message translates to:
  /// **'No se pudo cargar el video'**
  String get couldNotLoadVideo;

  /// No description provided for @couldNotPreviewPdf.
  ///
  /// In es, this message translates to:
  /// **'No se pudo previsualizar el PDF'**
  String get couldNotPreviewPdf;

  /// No description provided for @openInYoutubeBrowser.
  ///
  /// In es, this message translates to:
  /// **'Abrir en el navegador'**
  String get openInYoutubeBrowser;

  /// No description provided for @pasteUrlTitle.
  ///
  /// In es, this message translates to:
  /// **'Pegar enlace como'**
  String get pasteUrlTitle;

  /// No description provided for @pasteAsUrl.
  ///
  /// In es, this message translates to:
  /// **'URL'**
  String get pasteAsUrl;

  /// No description provided for @pasteAsEmbed.
  ///
  /// In es, this message translates to:
  /// **'Insertar'**
  String get pasteAsEmbed;

  /// No description provided for @pasteAsBookmark.
  ///
  /// In es, this message translates to:
  /// **'Marcador'**
  String get pasteAsBookmark;

  /// No description provided for @pasteAsMention.
  ///
  /// In es, this message translates to:
  /// **'Mención'**
  String get pasteAsMention;

  /// No description provided for @pasteAsUrlSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Insertar enlace markdown en el texto'**
  String get pasteAsUrlSubtitle;

  /// No description provided for @pasteAsEmbedSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Bloque vídeo con vista previa (YouTube) o marcador'**
  String get pasteAsEmbedSubtitle;

  /// No description provided for @pasteAsBookmarkSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Tarjeta con título y enlace'**
  String get pasteAsBookmarkSubtitle;

  /// No description provided for @pasteAsMentionSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Enlace a una página de esta libreta'**
  String get pasteAsMentionSubtitle;

  /// No description provided for @tableAddRow.
  ///
  /// In es, this message translates to:
  /// **'Fila'**
  String get tableAddRow;

  /// No description provided for @tableRemoveRow.
  ///
  /// In es, this message translates to:
  /// **'Quitar fila'**
  String get tableRemoveRow;

  /// No description provided for @tableAddColumn.
  ///
  /// In es, this message translates to:
  /// **'Columna'**
  String get tableAddColumn;

  /// No description provided for @tableRemoveColumn.
  ///
  /// In es, this message translates to:
  /// **'Quitar col.'**
  String get tableRemoveColumn;

  /// No description provided for @tablePasteFromClipboard.
  ///
  /// In es, this message translates to:
  /// **'Pegar tabla'**
  String get tablePasteFromClipboard;

  /// No description provided for @pickPageForMention.
  ///
  /// In es, this message translates to:
  /// **'Elegir página'**
  String get pickPageForMention;

  /// No description provided for @bookmarkTitleHint.
  ///
  /// In es, this message translates to:
  /// **'Título'**
  String get bookmarkTitleHint;

  /// No description provided for @bookmarkOpenLink.
  ///
  /// In es, this message translates to:
  /// **'Abrir enlace'**
  String get bookmarkOpenLink;

  /// No description provided for @bookmarkSetUrl.
  ///
  /// In es, this message translates to:
  /// **'Establecer URL…'**
  String get bookmarkSetUrl;

  /// No description provided for @bookmarkBlockHint.
  ///
  /// In es, this message translates to:
  /// **'Pega un enlace o usa el menú del bloque'**
  String get bookmarkBlockHint;

  /// No description provided for @bookmarkRemove.
  ///
  /// In es, this message translates to:
  /// **'Quitar marcador'**
  String get bookmarkRemove;

  /// No description provided for @embedUnavailable.
  ///
  /// In es, this message translates to:
  /// **'La vista web embebida no está disponible en esta plataforma. Abre el enlace en el navegador.'**
  String get embedUnavailable;

  /// No description provided for @embedOpenBrowser.
  ///
  /// In es, this message translates to:
  /// **'Abrir en el navegador'**
  String get embedOpenBrowser;

  /// No description provided for @embedSetUrl.
  ///
  /// In es, this message translates to:
  /// **'Establecer URL del inserto…'**
  String get embedSetUrl;

  /// No description provided for @embedRemove.
  ///
  /// In es, this message translates to:
  /// **'Quitar inserto'**
  String get embedRemove;

  /// No description provided for @embedEmptyHint.
  ///
  /// In es, this message translates to:
  /// **'Pega un enlace o establece la URL desde el menú del bloque'**
  String get embedEmptyHint;

  /// No description provided for @blockSizeSmaller.
  ///
  /// In es, this message translates to:
  /// **'Más pequeño'**
  String get blockSizeSmaller;

  /// No description provided for @blockSizeLarger.
  ///
  /// In es, this message translates to:
  /// **'Más grande'**
  String get blockSizeLarger;

  /// No description provided for @blockSizeHalf.
  ///
  /// In es, this message translates to:
  /// **'50%'**
  String get blockSizeHalf;

  /// No description provided for @blockSizeThreeQuarter.
  ///
  /// In es, this message translates to:
  /// **'75%'**
  String get blockSizeThreeQuarter;

  /// No description provided for @blockSizeFull.
  ///
  /// In es, this message translates to:
  /// **'100%'**
  String get blockSizeFull;

  /// No description provided for @pasteAsEmbedSubtitleWeb.
  ///
  /// In es, this message translates to:
  /// **'Mostrar la página dentro del bloque (si el sistema lo permite)'**
  String get pasteAsEmbedSubtitleWeb;

  /// No description provided for @pasteAsMentionSubtitleRich.
  ///
  /// In es, this message translates to:
  /// **'Enlace con título de la página (p. ej. YouTube)'**
  String get pasteAsMentionSubtitleRich;

  /// No description provided for @formatToolbar.
  ///
  /// In es, this message translates to:
  /// **'Barra de formato'**
  String get formatToolbar;

  /// No description provided for @formatToolbarScrollPrevious.
  ///
  /// In es, this message translates to:
  /// **'Ver herramientas anteriores'**
  String get formatToolbarScrollPrevious;

  /// No description provided for @formatToolbarScrollNext.
  ///
  /// In es, this message translates to:
  /// **'Ver más herramientas'**
  String get formatToolbarScrollNext;

  /// No description provided for @linkTitle.
  ///
  /// In es, this message translates to:
  /// **'Enlace'**
  String get linkTitle;

  /// No description provided for @visibleTextLabel.
  ///
  /// In es, this message translates to:
  /// **'Texto visible'**
  String get visibleTextLabel;

  /// No description provided for @urlLabel.
  ///
  /// In es, this message translates to:
  /// **'URL'**
  String get urlLabel;

  /// No description provided for @urlHint.
  ///
  /// In es, this message translates to:
  /// **'https://…'**
  String get urlHint;

  /// No description provided for @insert.
  ///
  /// In es, this message translates to:
  /// **'Insertar'**
  String get insert;

  /// No description provided for @defaultLinkText.
  ///
  /// In es, this message translates to:
  /// **'texto'**
  String get defaultLinkText;

  /// No description provided for @boldTip.
  ///
  /// In es, this message translates to:
  /// **'Negrita (**)'**
  String get boldTip;

  /// No description provided for @italicTip.
  ///
  /// In es, this message translates to:
  /// **'Cursiva (_)'**
  String get italicTip;

  /// No description provided for @underlineTip.
  ///
  /// In es, this message translates to:
  /// **'Subrayado (<u>)'**
  String get underlineTip;

  /// No description provided for @inlineCodeTip.
  ///
  /// In es, this message translates to:
  /// **'Código inline (`)'**
  String get inlineCodeTip;

  /// No description provided for @strikeTip.
  ///
  /// In es, this message translates to:
  /// **'Tachado (~~)'**
  String get strikeTip;

  /// No description provided for @linkTip.
  ///
  /// In es, this message translates to:
  /// **'Enlace'**
  String get linkTip;

  /// No description provided for @pageHistoryTitle.
  ///
  /// In es, this message translates to:
  /// **'Historial de versiones'**
  String get pageHistoryTitle;

  /// No description provided for @restoreVersionTitle.
  ///
  /// In es, this message translates to:
  /// **'Restaurar versión'**
  String get restoreVersionTitle;

  /// No description provided for @restoreVersionBody.
  ///
  /// In es, this message translates to:
  /// **'Se sustituirá el título y el contenido de la página por esta versión. El estado actual se guardará antes en el historial.'**
  String get restoreVersionBody;

  /// No description provided for @restore.
  ///
  /// In es, this message translates to:
  /// **'Restaurar'**
  String get restore;

  /// No description provided for @deleteVersionTitle.
  ///
  /// In es, this message translates to:
  /// **'Borrar versión'**
  String get deleteVersionTitle;

  /// No description provided for @deleteVersionBody.
  ///
  /// In es, this message translates to:
  /// **'Esta entrada desaparecerá del historial. El texto actual de la página no cambia.'**
  String get deleteVersionBody;

  /// No description provided for @noVersionsYet.
  ///
  /// In es, this message translates to:
  /// **'Sin versiones todavía'**
  String get noVersionsYet;

  /// No description provided for @historyAppearsHint.
  ///
  /// In es, this message translates to:
  /// **'Cuando dejes de escribir unos segundos, aquí aparecerá el historial de cambios.'**
  String get historyAppearsHint;

  /// No description provided for @versionControl.
  ///
  /// In es, this message translates to:
  /// **'Control de versiones'**
  String get versionControl;

  /// No description provided for @historyHeaderBody.
  ///
  /// In es, this message translates to:
  /// **'La libreta se guarda en seguida; el historial añade una entrada cuando dejas de editar y el contenido cambió.'**
  String get historyHeaderBody;

  /// No description provided for @versionsCount.
  ///
  /// In es, this message translates to:
  /// **'{count} {count, plural, one {versión} other {versiones}}'**
  String versionsCount(int count);

  /// No description provided for @untitledFallback.
  ///
  /// In es, this message translates to:
  /// **'Sin título'**
  String get untitledFallback;

  /// No description provided for @comparedWithPrevious.
  ///
  /// In es, this message translates to:
  /// **'Comparado con la versión anterior'**
  String get comparedWithPrevious;

  /// No description provided for @changesFromEmptyStart.
  ///
  /// In es, this message translates to:
  /// **'Cambios desde el inicio vacío'**
  String get changesFromEmptyStart;

  /// No description provided for @contentLabel.
  ///
  /// In es, this message translates to:
  /// **'Contenido'**
  String get contentLabel;

  /// No description provided for @titleLabelSimple.
  ///
  /// In es, this message translates to:
  /// **'Título'**
  String get titleLabelSimple;

  /// No description provided for @emptyValue.
  ///
  /// In es, this message translates to:
  /// **'(vacío)'**
  String get emptyValue;

  /// No description provided for @noTextChanges.
  ///
  /// In es, this message translates to:
  /// **'Sin cambios en el texto.'**
  String get noTextChanges;

  /// No description provided for @aiAssistantTitle.
  ///
  /// In es, this message translates to:
  /// **'Quill'**
  String get aiAssistantTitle;

  /// No description provided for @aiNoPageSelected.
  ///
  /// In es, this message translates to:
  /// **'Sin página seleccionada'**
  String get aiNoPageSelected;

  /// No description provided for @aiChatContextDisabledSubtitle.
  ///
  /// In es, this message translates to:
  /// **'No se envía texto de páginas al modelo'**
  String get aiChatContextDisabledSubtitle;

  /// No description provided for @aiChatContextUsesCurrentPage.
  ///
  /// In es, this message translates to:
  /// **'Contexto: página actual ({title})'**
  String aiChatContextUsesCurrentPage(Object title);

  /// No description provided for @aiChatContextOnePageFallback.
  ///
  /// In es, this message translates to:
  /// **'Contexto: 1 página'**
  String get aiChatContextOnePageFallback;

  /// No description provided for @aiChatContextNPages.
  ///
  /// In es, this message translates to:
  /// **'{count} páginas en el contexto del chat'**
  String aiChatContextNPages(int count);

  /// No description provided for @aiChatPageContextTooltip.
  ///
  /// In es, this message translates to:
  /// **'Incluir texto de páginas en el contexto del modelo'**
  String get aiChatPageContextTooltip;

  /// No description provided for @aiChatChooseContextPagesTooltip.
  ///
  /// In es, this message translates to:
  /// **'Elegir qué páginas aportan texto al contexto'**
  String get aiChatChooseContextPagesTooltip;

  /// No description provided for @aiChatContextPagesDialogTitle.
  ///
  /// In es, this message translates to:
  /// **'Páginas en el contexto del chat'**
  String get aiChatContextPagesDialogTitle;

  /// No description provided for @aiChatContextPagesClear.
  ///
  /// In es, this message translates to:
  /// **'Vaciar lista'**
  String get aiChatContextPagesClear;

  /// No description provided for @aiChatContextPagesApply.
  ///
  /// In es, this message translates to:
  /// **'Aplicar'**
  String get aiChatContextPagesApply;

  /// No description provided for @aiTypingSemantics.
  ///
  /// In es, this message translates to:
  /// **'Quill está escribiendo'**
  String get aiTypingSemantics;

  /// No description provided for @aiRenameChatTooltip.
  ///
  /// In es, this message translates to:
  /// **'Renombrar chat'**
  String get aiRenameChatTooltip;

  /// No description provided for @aiRenameChatDialogTitle.
  ///
  /// In es, this message translates to:
  /// **'Título del chat'**
  String get aiRenameChatDialogTitle;

  /// No description provided for @aiRenameChatLabel.
  ///
  /// In es, this message translates to:
  /// **'Texto en la pestaña'**
  String get aiRenameChatLabel;

  /// No description provided for @quillWorkspaceTourTitle.
  ///
  /// In es, this message translates to:
  /// **'Quill te puede acompañar aquí'**
  String get quillWorkspaceTourTitle;

  /// No description provided for @quillWorkspaceTourBodyReady.
  ///
  /// In es, this message translates to:
  /// **'Tienes el chat de Quill listo para preguntar, editar páginas y trabajar con contexto de notas.'**
  String get quillWorkspaceTourBodyReady;

  /// No description provided for @quillWorkspaceTourBodyUnavailable.
  ///
  /// In es, this message translates to:
  /// **'Aunque ahora no esté activa, Quill vive en este espacio de trabajo y puedes activarla más tarde desde Ajustes.'**
  String get quillWorkspaceTourBodyUnavailable;

  /// No description provided for @quillWorkspaceTourPointsTitle.
  ///
  /// In es, this message translates to:
  /// **'Qué conviene saber'**
  String get quillWorkspaceTourPointsTitle;

  /// No description provided for @quillWorkspaceTourPointOne.
  ///
  /// In es, this message translates to:
  /// **'Sirve tanto para conversar como para editar títulos y bloques.'**
  String get quillWorkspaceTourPointOne;

  /// No description provided for @quillWorkspaceTourPointTwo.
  ///
  /// In es, this message translates to:
  /// **'Puede usar la página abierta o varias páginas como contexto.'**
  String get quillWorkspaceTourPointTwo;

  /// No description provided for @quillWorkspaceTourPointThree.
  ///
  /// In es, this message translates to:
  /// **'Si tocas un ejemplo de abajo, se rellenará el chat cuando Quill esté disponible.'**
  String get quillWorkspaceTourPointThree;

  /// No description provided for @quillWorkspaceTourExamplesTitle.
  ///
  /// In es, this message translates to:
  /// **'Prueba con mensajes como'**
  String get quillWorkspaceTourExamplesTitle;

  /// No description provided for @quillWorkspaceTourExampleOne.
  ///
  /// In es, this message translates to:
  /// **'Explícame cómo organizar esta página.'**
  String get quillWorkspaceTourExampleOne;

  /// No description provided for @quillWorkspaceTourExampleTwo.
  ///
  /// In es, this message translates to:
  /// **'Usa estas dos páginas para hacer un resumen común.'**
  String get quillWorkspaceTourExampleTwo;

  /// No description provided for @quillWorkspaceTourExampleThree.
  ///
  /// In es, this message translates to:
  /// **'Reescribe este bloque con un tono más claro.'**
  String get quillWorkspaceTourExampleThree;

  /// No description provided for @quillTourDismiss.
  ///
  /// In es, this message translates to:
  /// **'Entendido'**
  String get quillTourDismiss;

  /// No description provided for @aiExpand.
  ///
  /// In es, this message translates to:
  /// **'Expandir'**
  String get aiExpand;

  /// No description provided for @aiCollapse.
  ///
  /// In es, this message translates to:
  /// **'Colapsar'**
  String get aiCollapse;

  /// No description provided for @aiDeleteCurrentChat.
  ///
  /// In es, this message translates to:
  /// **'Borrar chat actual'**
  String get aiDeleteCurrentChat;

  /// No description provided for @aiNewChat.
  ///
  /// In es, this message translates to:
  /// **'Nuevo'**
  String get aiNewChat;

  /// No description provided for @aiAttach.
  ///
  /// In es, this message translates to:
  /// **'Adjuntar'**
  String get aiAttach;

  /// No description provided for @aiChatEmptyHint.
  ///
  /// In es, this message translates to:
  /// **'Empieza una conversación.\nQuill decidirá automáticamente qué hacer con tu mensaje.\nTambién puedes preguntar cómo usar Folio (atajos, ajustes, páginas o este chat).'**
  String get aiChatEmptyHint;

  /// No description provided for @aiChatEmptyFocusComposer.
  ///
  /// In es, this message translates to:
  /// **'Escribe un mensaje'**
  String get aiChatEmptyFocusComposer;

  /// No description provided for @aiInputHint.
  ///
  /// In es, this message translates to:
  /// **'Escribe tu mensaje. Quill actuará como agente.'**
  String get aiInputHint;

  /// No description provided for @aiInputHintCopilot.
  ///
  /// In es, this message translates to:
  /// **'Escribe tu mensaje...'**
  String get aiInputHintCopilot;

  /// No description provided for @aiContextComposerHint.
  ///
  /// In es, this message translates to:
  /// **'Sin contexto añadido'**
  String get aiContextComposerHint;

  /// No description provided for @aiContextComposerHelper.
  ///
  /// In es, this message translates to:
  /// **'Usa @ para añadir contexto'**
  String get aiContextComposerHelper;

  /// No description provided for @aiContextCurrentPageChip.
  ///
  /// In es, this message translates to:
  /// **'Página actual: {title}'**
  String aiContextCurrentPageChip(Object title);

  /// No description provided for @aiContextCurrentPageFallback.
  ///
  /// In es, this message translates to:
  /// **'Página actual'**
  String get aiContextCurrentPageFallback;

  /// No description provided for @aiContextAddFile.
  ///
  /// In es, this message translates to:
  /// **'Adjuntar archivo'**
  String get aiContextAddFile;

  /// No description provided for @aiContextAddPage.
  ///
  /// In es, this message translates to:
  /// **'Adjuntar página'**
  String get aiContextAddPage;

  /// No description provided for @aiShowPanel.
  ///
  /// In es, this message translates to:
  /// **'Mostrar panel IA'**
  String get aiShowPanel;

  /// No description provided for @aiHidePanel.
  ///
  /// In es, this message translates to:
  /// **'Ocultar panel IA'**
  String get aiHidePanel;

  /// No description provided for @aiPanelResizeHandle.
  ///
  /// In es, this message translates to:
  /// **'Redimensionar panel de IA'**
  String get aiPanelResizeHandle;

  /// No description provided for @aiPanelResizeHandleHint.
  ///
  /// In es, this message translates to:
  /// **'Arrastra horizontalmente para cambiar el ancho del asistente'**
  String get aiPanelResizeHandleHint;

  /// No description provided for @importMarkdownPage.
  ///
  /// In es, this message translates to:
  /// **'Importar Markdown'**
  String get importMarkdownPage;

  /// No description provided for @exportMarkdownPage.
  ///
  /// In es, this message translates to:
  /// **'Exportar Markdown'**
  String get exportMarkdownPage;

  /// No description provided for @exportPage.
  ///
  /// In es, this message translates to:
  /// **'Exportar…'**
  String get exportPage;

  /// No description provided for @workspaceUndoTooltip.
  ///
  /// In es, this message translates to:
  /// **'Deshacer (Ctrl+Z)'**
  String get workspaceUndoTooltip;

  /// No description provided for @workspaceRedoTooltip.
  ///
  /// In es, this message translates to:
  /// **'Rehacer (Ctrl+Y)'**
  String get workspaceRedoTooltip;

  /// No description provided for @workspaceMoreActionsTooltip.
  ///
  /// In es, this message translates to:
  /// **'Más acciones'**
  String get workspaceMoreActionsTooltip;

  /// No description provided for @closeCurrentPage.
  ///
  /// In es, this message translates to:
  /// **'Cerrar página actual'**
  String get closeCurrentPage;

  /// No description provided for @aiErrorWithDetails.
  ///
  /// In es, this message translates to:
  /// **'Error IA: {error}'**
  String aiErrorWithDetails(Object error);

  /// No description provided for @aiServiceUnreachable.
  ///
  /// In es, this message translates to:
  /// **'No se pudo conectar con el servicio de IA en el endpoint configurado. Inicia Ollama o LM Studio y revisa la URL.'**
  String get aiServiceUnreachable;

  /// No description provided for @aiLaunchProviderWithApp.
  ///
  /// In es, this message translates to:
  /// **'Abrir app de IA al iniciar Folio'**
  String get aiLaunchProviderWithApp;

  /// No description provided for @aiLaunchProviderWithAppHint.
  ///
  /// In es, this message translates to:
  /// **'Intenta lanzar Ollama o LM Studio en Windows si el endpoint es localhost. En LM Studio puede hacer falta iniciar el servidor manualmente.'**
  String get aiLaunchProviderWithAppHint;

  /// No description provided for @aiContextWindowTokens.
  ///
  /// In es, this message translates to:
  /// **'Ventana de contexto del modelo (tokens)'**
  String get aiContextWindowTokens;

  /// No description provided for @aiContextWindowTokensHint.
  ///
  /// In es, this message translates to:
  /// **'Sirve para la barra de contexto del chat. Ajústala a tu modelo (p. ej. 8192, 131072).'**
  String get aiContextWindowTokensHint;

  /// No description provided for @aiContextUsageUnavailable.
  ///
  /// In es, this message translates to:
  /// **'El servidor no informó del uso de tokens en la última respuesta.'**
  String get aiContextUsageUnavailable;

  /// No description provided for @aiContextUsageSummary.
  ///
  /// In es, this message translates to:
  /// **'Prompt {prompt} · Salida {completion}'**
  String aiContextUsageSummary(Object prompt, Object completion);

  /// No description provided for @aiContextUsageTooltip.
  ///
  /// In es, this message translates to:
  /// **'Última petición respecto a la ventana configurada ({window} tokens).'**
  String aiContextUsageTooltip(int window);

  /// No description provided for @aiChatKeyboardHint.
  ///
  /// In es, this message translates to:
  /// **'Enter para enviar · Ctrl+Enter nueva línea'**
  String get aiChatKeyboardHint;

  /// No description provided for @aiChatInkRemaining.
  ///
  /// In es, this message translates to:
  /// **'{total, plural, one{Queda 1 gota de tinta} other{Quedan {total} gotas de tinta}}'**
  String aiChatInkRemaining(int total);

  /// No description provided for @aiChatInkBreakdownTooltip.
  ///
  /// In es, this message translates to:
  /// **'Mes {monthly} · Compradas {purchased}'**
  String aiChatInkBreakdownTooltip(int monthly, int purchased);

  /// No description provided for @aiAgentThought.
  ///
  /// In es, this message translates to:
  /// **'Pensamiento de Quill'**
  String get aiAgentThought;

  /// No description provided for @aiAlwaysShowThought.
  ///
  /// In es, this message translates to:
  /// **'Mostrar siempre pensamiento de IA'**
  String get aiAlwaysShowThought;

  /// No description provided for @aiAlwaysShowThoughtHint.
  ///
  /// In es, this message translates to:
  /// **'Si está desactivado, se mostrará plegado con flecha en cada mensaje.'**
  String get aiAlwaysShowThoughtHint;

  /// No description provided for @aiBetaBadge.
  ///
  /// In es, this message translates to:
  /// **'BETA'**
  String get aiBetaBadge;

  /// No description provided for @aiBetaEnableTitle.
  ///
  /// In es, this message translates to:
  /// **'IA en fase BETA'**
  String get aiBetaEnableTitle;

  /// No description provided for @aiBetaEnableBody.
  ///
  /// In es, this message translates to:
  /// **'Esta funcionalidad está en fase BETA y puede fallar o comportarse de forma inesperada.\n\n¿Quieres activarla igualmente?'**
  String get aiBetaEnableBody;

  /// No description provided for @aiBetaEnableConfirm.
  ///
  /// In es, this message translates to:
  /// **'Activar BETA'**
  String get aiBetaEnableConfirm;

  /// No description provided for @ai.
  ///
  /// In es, this message translates to:
  /// **'IA'**
  String get ai;

  /// No description provided for @aiEnableToggleTitle.
  ///
  /// In es, this message translates to:
  /// **'Activar IA'**
  String get aiEnableToggleTitle;

  /// No description provided for @aiProviderLabel.
  ///
  /// In es, this message translates to:
  /// **'Proveedor'**
  String get aiProviderLabel;

  /// No description provided for @aiProviderNone.
  ///
  /// In es, this message translates to:
  /// **'Ninguno'**
  String get aiProviderNone;

  /// No description provided for @aiEndpoint.
  ///
  /// In es, this message translates to:
  /// **'Endpoint'**
  String get aiEndpoint;

  /// No description provided for @aiModel.
  ///
  /// In es, this message translates to:
  /// **'Modelo'**
  String get aiModel;

  /// No description provided for @aiTimeoutMs.
  ///
  /// In es, this message translates to:
  /// **'Timeout (ms)'**
  String get aiTimeoutMs;

  /// No description provided for @aiAllowRemoteEndpoint.
  ///
  /// In es, this message translates to:
  /// **'Permitir endpoint remoto'**
  String get aiAllowRemoteEndpoint;

  /// No description provided for @aiAllowRemoteEndpointAllowed.
  ///
  /// In es, this message translates to:
  /// **'Hosts remotos permitidos'**
  String get aiAllowRemoteEndpointAllowed;

  /// No description provided for @aiAllowRemoteEndpointLocalhostOnly.
  ///
  /// In es, this message translates to:
  /// **'Solo localhost'**
  String get aiAllowRemoteEndpointLocalhostOnly;

  /// No description provided for @aiAllowRemoteEndpointNotConfirmed.
  ///
  /// In es, this message translates to:
  /// **'El acceso a endpoints remotos está habilitado, pero todavía no se ha confirmado.'**
  String get aiAllowRemoteEndpointNotConfirmed;

  /// No description provided for @aiConnectToListModels.
  ///
  /// In es, this message translates to:
  /// **'Conectar para listar modelos'**
  String get aiConnectToListModels;

  /// No description provided for @aiProviderAutoConfigured.
  ///
  /// In es, this message translates to:
  /// **'Proveedor IA detectado y configurado: {provider}'**
  String aiProviderAutoConfigured(Object provider);

  /// No description provided for @aiSetupAssistantTitle.
  ///
  /// In es, this message translates to:
  /// **'Asistente de instalación IA'**
  String get aiSetupAssistantTitle;

  /// No description provided for @aiSetupAssistantSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Detecta y configura Ollama o LM Studio automáticamente.'**
  String get aiSetupAssistantSubtitle;

  /// No description provided for @aiSetupWizardTitle.
  ///
  /// In es, this message translates to:
  /// **'Asistente IA'**
  String get aiSetupWizardTitle;

  /// No description provided for @aiSetupChooseProviderTitle.
  ///
  /// In es, this message translates to:
  /// **'Elige proveedor IA'**
  String get aiSetupChooseProviderTitle;

  /// No description provided for @aiSetupChooseProviderBody.
  ///
  /// In es, this message translates to:
  /// **'Primero elige cuál quieres usar. Después te guiamos en su instalación y configuración.'**
  String get aiSetupChooseProviderBody;

  /// No description provided for @aiSetupNoProviderTitle.
  ///
  /// In es, this message translates to:
  /// **'No se detectó ningún proveedor activo'**
  String get aiSetupNoProviderTitle;

  /// No description provided for @aiSetupNoProviderBody.
  ///
  /// In es, this message translates to:
  /// **'No encontramos Ollama o LM Studio en ejecución y accesibles.\nSigue los pasos para instalar/iniciar uno de ellos y pulsa Reintentar.'**
  String get aiSetupNoProviderBody;

  /// No description provided for @aiSetupOllamaTitle.
  ///
  /// In es, this message translates to:
  /// **'Paso 1: Instalar Ollama'**
  String get aiSetupOllamaTitle;

  /// No description provided for @aiSetupOllamaBody.
  ///
  /// In es, this message translates to:
  /// **'Instala Ollama, ejecuta el servicio y verifica que responda en http://127.0.0.1:11434.'**
  String get aiSetupOllamaBody;

  /// No description provided for @aiSetupLmStudioTitle.
  ///
  /// In es, this message translates to:
  /// **'Paso 2: Instalar LM Studio'**
  String get aiSetupLmStudioTitle;

  /// No description provided for @aiSetupLmStudioBody.
  ///
  /// In es, this message translates to:
  /// **'Instala LM Studio, inicia su servidor local y verifica que responda en http://127.0.0.1:1234.'**
  String get aiSetupLmStudioBody;

  /// No description provided for @aiSetupOpenSettingsHint.
  ///
  /// In es, this message translates to:
  /// **'Cuando uno de los proveedores esté operativo, pulsa Reintentar para autoconfigurarlo.'**
  String get aiSetupOpenSettingsHint;

  /// No description provided for @aiCompareCloudVsLocalTitle.
  ///
  /// In es, this message translates to:
  /// **'Cloud vs local'**
  String get aiCompareCloudVsLocalTitle;

  /// No description provided for @aiCompareCloudTitle.
  ///
  /// In es, this message translates to:
  /// **'Folio Cloud'**
  String get aiCompareCloudTitle;

  /// No description provided for @aiCompareLocalTitle.
  ///
  /// In es, this message translates to:
  /// **'Local (Ollama / LM Studio)'**
  String get aiCompareLocalTitle;

  /// No description provided for @aiCompareCloudBulletNoSetup.
  ///
  /// In es, this message translates to:
  /// **'Sin configuración local: funciona al iniciar sesión.'**
  String get aiCompareCloudBulletNoSetup;

  /// No description provided for @aiCompareCloudBulletNeedsSub.
  ///
  /// In es, this message translates to:
  /// **'Suscripción con IA en la nube o tinta comprada.'**
  String get aiCompareCloudBulletNeedsSub;

  /// No description provided for @aiCompareCloudBulletInk.
  ///
  /// In es, this message translates to:
  /// **'Usa tinta para la IA en la nube (packs + recarga mensual).'**
  String get aiCompareCloudBulletInk;

  /// No description provided for @aiProviderFolioCloudBlockedSnack.
  ///
  /// In es, this message translates to:
  /// **'Necesitas suscripción Folio Cloud con IA en la nube o comprar tinta en Ajustes → Folio Cloud.'**
  String get aiProviderFolioCloudBlockedSnack;

  /// No description provided for @aiCompareLocalBulletPrivacy.
  ///
  /// In es, this message translates to:
  /// **'Privacidad local (tu equipo).'**
  String get aiCompareLocalBulletPrivacy;

  /// No description provided for @aiCompareLocalBulletNoInk.
  ///
  /// In es, this message translates to:
  /// **'Sin tinta: no depende del saldo.'**
  String get aiCompareLocalBulletNoInk;

  /// No description provided for @aiCompareLocalBulletSetup.
  ///
  /// In es, this message translates to:
  /// **'Requiere instalar y arrancar un proveedor en localhost.'**
  String get aiCompareLocalBulletSetup;

  /// No description provided for @quillGlobalScopeNoticeTitle.
  ///
  /// In es, this message translates to:
  /// **'Quill funciona en todas las libretas'**
  String get quillGlobalScopeNoticeTitle;

  /// No description provided for @quillGlobalScopeNoticeBody.
  ///
  /// In es, this message translates to:
  /// **'Quill es un ajuste global de la app. Si lo activas ahora, quedará disponible para cualquier libreta en esta instalación, no solo para la actual.'**
  String get quillGlobalScopeNoticeBody;

  /// No description provided for @quillGlobalScopeNoticeConfirm.
  ///
  /// In es, this message translates to:
  /// **'Entiendo'**
  String get quillGlobalScopeNoticeConfirm;

  /// No description provided for @searchByNameOrShortcut.
  ///
  /// In es, this message translates to:
  /// **'Buscar por nombre o atajo…'**
  String get searchByNameOrShortcut;

  /// No description provided for @search.
  ///
  /// In es, this message translates to:
  /// **'Buscar'**
  String get search;

  /// No description provided for @open.
  ///
  /// In es, this message translates to:
  /// **'Abrir'**
  String get open;

  /// No description provided for @exit.
  ///
  /// In es, this message translates to:
  /// **'Salir'**
  String get exit;

  /// No description provided for @trayMenuCloseApplication.
  ///
  /// In es, this message translates to:
  /// **'Cerrar aplicación'**
  String get trayMenuCloseApplication;

  /// No description provided for @keyboardShortcutsSection.
  ///
  /// In es, this message translates to:
  /// **'Teclado (en la app)'**
  String get keyboardShortcutsSection;

  /// No description provided for @tasksCaptureSettingsSection.
  ///
  /// In es, this message translates to:
  /// **'Tareas (captura rápida)'**
  String get tasksCaptureSettingsSection;

  /// No description provided for @taskInboxPageTitle.
  ///
  /// In es, this message translates to:
  /// **'Bandeja de tareas'**
  String get taskInboxPageTitle;

  /// No description provided for @taskInboxPageSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Página donde se guardan las tareas añadidas con captura rápida.'**
  String get taskInboxPageSubtitle;

  /// No description provided for @taskInboxNone.
  ///
  /// In es, this message translates to:
  /// **'Sin definir (se crea al guardar la primera)'**
  String get taskInboxNone;

  /// No description provided for @taskInboxDefaultTitle.
  ///
  /// In es, this message translates to:
  /// **'Bandeja de tareas'**
  String get taskInboxDefaultTitle;

  /// No description provided for @taskAliasManageTitle.
  ///
  /// In es, this message translates to:
  /// **'Alias de destino'**
  String get taskAliasManageTitle;

  /// No description provided for @taskAliasManageSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Usa `#etiqueta` o `@etiqueta` al final de la captura. Define aquí la clave sin símbolo (ej. trabajo) y la página destino.'**
  String get taskAliasManageSubtitle;

  /// No description provided for @taskAliasAddButton.
  ///
  /// In es, this message translates to:
  /// **'Añadir alias'**
  String get taskAliasAddButton;

  /// No description provided for @taskAliasTagLabel.
  ///
  /// In es, this message translates to:
  /// **'Etiqueta'**
  String get taskAliasTagLabel;

  /// No description provided for @taskAliasTargetLabel.
  ///
  /// In es, this message translates to:
  /// **'Página'**
  String get taskAliasTargetLabel;

  /// No description provided for @taskAliasDeleteTooltip.
  ///
  /// In es, this message translates to:
  /// **'Quitar'**
  String get taskAliasDeleteTooltip;

  /// No description provided for @taskQuickAddTitle.
  ///
  /// In es, this message translates to:
  /// **'Captura rápida de tarea'**
  String get taskQuickAddTitle;

  /// No description provided for @taskQuickAddHint.
  ///
  /// In es, this message translates to:
  /// **'Ej.: Comprar leche mañana alta #trabajo. También: due:2026-04-20, p1, en progreso.'**
  String get taskQuickAddHint;

  /// No description provided for @taskQuickAddConfirm.
  ///
  /// In es, this message translates to:
  /// **'Añadir'**
  String get taskQuickAddConfirm;

  /// No description provided for @taskQuickAddSuccess.
  ///
  /// In es, this message translates to:
  /// **'Tarea añadida.'**
  String get taskQuickAddSuccess;

  /// No description provided for @taskQuickAddAliasTargetMissing.
  ///
  /// In es, this message translates to:
  /// **'La página de ese alias ya no existe.'**
  String get taskQuickAddAliasTargetMissing;

  /// No description provided for @taskHubTitle.
  ///
  /// In es, this message translates to:
  /// **'Todas las tareas'**
  String get taskHubTitle;

  /// No description provided for @taskHubClose.
  ///
  /// In es, this message translates to:
  /// **'Cerrar vista'**
  String get taskHubClose;

  /// No description provided for @taskHubDashboardHelpTitle.
  ///
  /// In es, this message translates to:
  /// **'Ideas tipo dashboard'**
  String get taskHubDashboardHelpTitle;

  /// No description provided for @taskHubDashboardHelpBody.
  ///
  /// In es, this message translates to:
  /// **'Crea una página con el bloque columnas y enlaza páginas de listas por contexto, o usa un bloque base de datos con fechas y estados para un tablero. La captura rápida y esta vista se inspiran en apps como Snippets (snippets.ch).'**
  String get taskHubDashboardHelpBody;

  /// No description provided for @taskHubEmpty.
  ///
  /// In es, this message translates to:
  /// **'No hay tareas en esta libreta.'**
  String get taskHubEmpty;

  /// No description provided for @taskHubFilterAll.
  ///
  /// In es, this message translates to:
  /// **'Todas'**
  String get taskHubFilterAll;

  /// No description provided for @taskHubFilterActive.
  ///
  /// In es, this message translates to:
  /// **'Pendientes'**
  String get taskHubFilterActive;

  /// No description provided for @taskHubFilterDone.
  ///
  /// In es, this message translates to:
  /// **'Hechas'**
  String get taskHubFilterDone;

  /// No description provided for @taskHubFilterDueToday.
  ///
  /// In es, this message translates to:
  /// **'Vencen hoy'**
  String get taskHubFilterDueToday;

  /// No description provided for @taskHubFilterDueWeek.
  ///
  /// In es, this message translates to:
  /// **'Esta semana'**
  String get taskHubFilterDueWeek;

  /// No description provided for @taskHubFilterOverdue.
  ///
  /// In es, this message translates to:
  /// **'Vencidas'**
  String get taskHubFilterOverdue;

  /// No description provided for @taskHubOpen.
  ///
  /// In es, this message translates to:
  /// **'Abrir'**
  String get taskHubOpen;

  /// No description provided for @taskHubMarkDone.
  ///
  /// In es, this message translates to:
  /// **'Hecho'**
  String get taskHubMarkDone;

  /// No description provided for @taskHubIncludeTodos.
  ///
  /// In es, this message translates to:
  /// **'Incluir checklists'**
  String get taskHubIncludeTodos;

  /// No description provided for @sidebarQuickAddTask.
  ///
  /// In es, this message translates to:
  /// **'Tarea rápida'**
  String get sidebarQuickAddTask;

  /// No description provided for @sidebarTaskHub.
  ///
  /// In es, this message translates to:
  /// **'Todas las tareas'**
  String get sidebarTaskHub;

  /// No description provided for @shortcutTestAction.
  ///
  /// In es, this message translates to:
  /// **'Probar'**
  String get shortcutTestAction;

  /// No description provided for @shortcutChangeAction.
  ///
  /// In es, this message translates to:
  /// **'Cambiar'**
  String get shortcutChangeAction;

  /// No description provided for @shortcutTestHint.
  ///
  /// In es, this message translates to:
  /// **'Con el foco fuera de un campo de texto, “{combo}” debería funcionar en el escritorio.'**
  String shortcutTestHint(Object combo);

  /// No description provided for @shortcutResetAllTitle.
  ///
  /// In es, this message translates to:
  /// **'Restaurar atajos por defecto'**
  String get shortcutResetAllTitle;

  /// No description provided for @shortcutResetAllSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Vuelve a poner todos los atajos de la app como al instalar Folio.'**
  String get shortcutResetAllSubtitle;

  /// No description provided for @shortcutResetDoneSnack.
  ///
  /// In es, this message translates to:
  /// **'Atajos restaurados.'**
  String get shortcutResetDoneSnack;

  /// No description provided for @desktopSection.
  ///
  /// In es, this message translates to:
  /// **'Desktop'**
  String get desktopSection;

  /// No description provided for @globalSearchHotkey.
  ///
  /// In es, this message translates to:
  /// **'Atajo global de búsqueda'**
  String get globalSearchHotkey;

  /// No description provided for @hotkeyCombination.
  ///
  /// In es, this message translates to:
  /// **'Combinación de teclas'**
  String get hotkeyCombination;

  /// No description provided for @hotkeyAltSpace.
  ///
  /// In es, this message translates to:
  /// **'Alt + Space'**
  String get hotkeyAltSpace;

  /// No description provided for @hotkeyCtrlShiftSpace.
  ///
  /// In es, this message translates to:
  /// **'Ctrl + Shift + Space'**
  String get hotkeyCtrlShiftSpace;

  /// No description provided for @hotkeyCtrlShiftK.
  ///
  /// In es, this message translates to:
  /// **'Ctrl + Shift + K'**
  String get hotkeyCtrlShiftK;

  /// No description provided for @minimizeToTray.
  ///
  /// In es, this message translates to:
  /// **'Minimizar a bandeja'**
  String get minimizeToTray;

  /// No description provided for @closeToTray.
  ///
  /// In es, this message translates to:
  /// **'Cerrar a bandeja'**
  String get closeToTray;

  /// No description provided for @searchAllVaultHint.
  ///
  /// In es, this message translates to:
  /// **'Buscar en toda la libreta...'**
  String get searchAllVaultHint;

  /// No description provided for @typeToSearch.
  ///
  /// In es, this message translates to:
  /// **'Escribe para buscar'**
  String get typeToSearch;

  /// No description provided for @noSearchResults.
  ///
  /// In es, this message translates to:
  /// **'Sin resultados'**
  String get noSearchResults;

  /// No description provided for @searchFilterAll.
  ///
  /// In es, this message translates to:
  /// **'Todo'**
  String get searchFilterAll;

  /// No description provided for @searchFilterTitles.
  ///
  /// In es, this message translates to:
  /// **'Títulos'**
  String get searchFilterTitles;

  /// No description provided for @searchFilterContent.
  ///
  /// In es, this message translates to:
  /// **'Contenido'**
  String get searchFilterContent;

  /// No description provided for @searchSortRelevance.
  ///
  /// In es, this message translates to:
  /// **'Relevancia'**
  String get searchSortRelevance;

  /// No description provided for @searchSortRecent.
  ///
  /// In es, this message translates to:
  /// **'Recientes'**
  String get searchSortRecent;

  /// No description provided for @settingsSearchSections.
  ///
  /// In es, this message translates to:
  /// **'Buscar en ajustes'**
  String get settingsSearchSections;

  /// No description provided for @settingsSearchSectionsHint.
  ///
  /// In es, this message translates to:
  /// **'Filtra categorías en la barra lateral'**
  String get settingsSearchSectionsHint;

  /// No description provided for @scheduledVaultBackupTitle.
  ///
  /// In es, this message translates to:
  /// **'Copia cifrada programada'**
  String get scheduledVaultBackupTitle;

  /// No description provided for @scheduledVaultBackupSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Con la libreta desbloqueada, Folio la copia automáticamente en el intervalo elegido. Activa la copia en carpeta, en la nube, o ambas.'**
  String get scheduledVaultBackupSubtitle;

  /// No description provided for @scheduledVaultBackupFolderTitle.
  ///
  /// In es, this message translates to:
  /// **'Copia en carpeta'**
  String get scheduledVaultBackupFolderTitle;

  /// No description provided for @scheduledVaultBackupFolderSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Guarda una copia cifrada en ZIP en la carpeta configurada en cada intervalo.'**
  String get scheduledVaultBackupFolderSubtitle;

  /// No description provided for @scheduledVaultBackupChooseFolder.
  ///
  /// In es, this message translates to:
  /// **'Carpeta de copias'**
  String get scheduledVaultBackupChooseFolder;

  /// No description provided for @scheduledVaultBackupClearFolderTooltip.
  ///
  /// In es, this message translates to:
  /// **'Quitar carpeta'**
  String get scheduledVaultBackupClearFolderTooltip;

  /// No description provided for @scheduledVaultBackupCloudOnlyTitle.
  ///
  /// In es, this message translates to:
  /// **'Copias programadas solo en la nube'**
  String get scheduledVaultBackupCloudOnlyTitle;

  /// No description provided for @scheduledVaultBackupCloudOnlySubtitle.
  ///
  /// In es, this message translates to:
  /// **'No guarda ZIPs en disco. Sube copias solo a la nube.'**
  String get scheduledVaultBackupCloudOnlySubtitle;

  /// No description provided for @scheduledVaultBackupIntervalLabel.
  ///
  /// In es, this message translates to:
  /// **'Intervalo entre copias'**
  String get scheduledVaultBackupIntervalLabel;

  /// No description provided for @scheduledVaultBackupEveryNMinutes.
  ///
  /// In es, this message translates to:
  /// **'{n, plural, one{1 minuto} other{{n} minutos}}'**
  String scheduledVaultBackupEveryNMinutes(int n);

  /// No description provided for @scheduledVaultBackupEveryNHours.
  ///
  /// In es, this message translates to:
  /// **'{n, plural, one{1 hora} other{{n} horas}}'**
  String scheduledVaultBackupEveryNHours(int n);

  /// No description provided for @scheduledVaultBackupLastRun.
  ///
  /// In es, this message translates to:
  /// **'Última copia: {time}'**
  String scheduledVaultBackupLastRun(Object time);

  /// No description provided for @scheduledVaultBackupSnackOk.
  ///
  /// In es, this message translates to:
  /// **'Copia programada guardada.'**
  String get scheduledVaultBackupSnackOk;

  /// No description provided for @scheduledVaultBackupSnackFail.
  ///
  /// In es, this message translates to:
  /// **'Error en la copia programada: {error}'**
  String scheduledVaultBackupSnackFail(Object error);

  /// No description provided for @vaultBackupOpenVaultHint.
  ///
  /// In es, this message translates to:
  /// **'Las copias son de la libreta abierta ahora: «{name}».'**
  String vaultBackupOpenVaultHint(String name);

  /// No description provided for @vaultBackupDiskSizeApprox.
  ///
  /// In es, this message translates to:
  /// **'Tamaño aproximado en disco: {size}'**
  String vaultBackupDiskSizeApprox(String size);

  /// No description provided for @vaultBackupDiskSizeLoading.
  ///
  /// In es, this message translates to:
  /// **'Calculando tamaño en disco…'**
  String get vaultBackupDiskSizeLoading;

  /// No description provided for @vaultBackupRunNowTile.
  ///
  /// In es, this message translates to:
  /// **'Copia programada ahora'**
  String get vaultBackupRunNowTile;

  /// No description provided for @vaultBackupRunNowSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Ejecuta ya la copia programada (disco y/o nube según lo tengas configurado), sin esperar al intervalo.'**
  String get vaultBackupRunNowSubtitle;

  /// No description provided for @vaultBackupRunNowNeedFolder.
  ///
  /// In es, this message translates to:
  /// **'Elige una carpeta local o activa «Subir también a Folio Cloud» para copia solo en la nube.'**
  String get vaultBackupRunNowNeedFolder;

  /// No description provided for @vaultIdentitySyncTitle.
  ///
  /// In es, this message translates to:
  /// **'Sincronización'**
  String get vaultIdentitySyncTitle;

  /// No description provided for @vaultIdentitySyncBody.
  ///
  /// In es, this message translates to:
  /// **'Introduce la contraseña de la libreta (o Hello / passkey) para continuar.'**
  String get vaultIdentitySyncBody;

  /// No description provided for @vaultIdentityCloudBackupTitle.
  ///
  /// In es, this message translates to:
  /// **'Copias en la nube'**
  String get vaultIdentityCloudBackupTitle;

  /// No description provided for @vaultIdentityCloudBackupBody.
  ///
  /// In es, this message translates to:
  /// **'Confirma la identidad de la libreta para listar o descargar copias cifradas.'**
  String get vaultIdentityCloudBackupBody;

  /// No description provided for @aiRewriteDialogTitle.
  ///
  /// In es, this message translates to:
  /// **'Reescribir con IA'**
  String get aiRewriteDialogTitle;

  /// No description provided for @aiPreviewTitle.
  ///
  /// In es, this message translates to:
  /// **'Vista previa'**
  String get aiPreviewTitle;

  /// No description provided for @aiInstructionHint.
  ///
  /// In es, this message translates to:
  /// **'Ejemplo: hazlo más claro y breve'**
  String get aiInstructionHint;

  /// No description provided for @aiApply.
  ///
  /// In es, this message translates to:
  /// **'Aplicar'**
  String get aiApply;

  /// No description provided for @aiGenerating.
  ///
  /// In es, this message translates to:
  /// **'Generando…'**
  String get aiGenerating;

  /// No description provided for @aiSummarizeSelection.
  ///
  /// In es, this message translates to:
  /// **'Resumir con IA…'**
  String get aiSummarizeSelection;

  /// No description provided for @aiExtractTasksDates.
  ///
  /// In es, this message translates to:
  /// **'Extraer tareas y fechas…'**
  String get aiExtractTasksDates;

  /// No description provided for @aiPreviewReadOnlyHint.
  ///
  /// In es, this message translates to:
  /// **'Puedes editar el texto antes de aplicar.'**
  String get aiPreviewReadOnlyHint;

  /// No description provided for @aiRewriteApplied.
  ///
  /// In es, this message translates to:
  /// **'Bloque actualizado.'**
  String get aiRewriteApplied;

  /// No description provided for @aiUndoRewrite.
  ///
  /// In es, this message translates to:
  /// **'Deshacer'**
  String get aiUndoRewrite;

  /// No description provided for @aiInsertBelow.
  ///
  /// In es, this message translates to:
  /// **'Insertar debajo'**
  String get aiInsertBelow;

  /// No description provided for @unlockVaultTitle.
  ///
  /// In es, this message translates to:
  /// **'Desbloquear libreta'**
  String get unlockVaultTitle;

  /// No description provided for @miniUnlockFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo desbloquear.'**
  String get miniUnlockFailed;

  /// No description provided for @importNotionTitle.
  ///
  /// In es, this message translates to:
  /// **'Importar desde Notion (.zip)'**
  String get importNotionTitle;

  /// No description provided for @importNotionSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Export ZIP de Notion (Markdown/HTML)'**
  String get importNotionSubtitle;

  /// No description provided for @importNotionDialogTitle.
  ///
  /// In es, this message translates to:
  /// **'Importar desde Notion'**
  String get importNotionDialogTitle;

  /// No description provided for @importNotionDialogBody.
  ///
  /// In es, this message translates to:
  /// **'Importa un ZIP exportado por Notion. Puedes añadirlo a la libreta actual o crear una nueva.'**
  String get importNotionDialogBody;

  /// No description provided for @importNotionSelectTargetTitle.
  ///
  /// In es, this message translates to:
  /// **'Destino de la importación'**
  String get importNotionSelectTargetTitle;

  /// No description provided for @importNotionSelectTargetBody.
  ///
  /// In es, this message translates to:
  /// **'Elige si quieres importar la exportacion de Notion en la libreta actual o crear una libreta nueva a partir de ella.'**
  String get importNotionSelectTargetBody;

  /// No description provided for @importNotionTargetCurrent.
  ///
  /// In es, this message translates to:
  /// **'Libreta actual'**
  String get importNotionTargetCurrent;

  /// No description provided for @importNotionTargetNew.
  ///
  /// In es, this message translates to:
  /// **'Libreta nueva'**
  String get importNotionTargetNew;

  /// No description provided for @importNotionDefaultVaultName.
  ///
  /// In es, this message translates to:
  /// **'Importado desde Notion'**
  String get importNotionDefaultVaultName;

  /// No description provided for @importNotionNewVaultPasswordTitle.
  ///
  /// In es, this message translates to:
  /// **'Contraseña para libreta nueva'**
  String get importNotionNewVaultPasswordTitle;

  /// No description provided for @importNotionSuccessCurrent.
  ///
  /// In es, this message translates to:
  /// **'Notion importado en la libreta actual.'**
  String get importNotionSuccessCurrent;

  /// No description provided for @importNotionSuccessNew.
  ///
  /// In es, this message translates to:
  /// **'Libreta nueva importada desde Notion.'**
  String get importNotionSuccessNew;

  /// No description provided for @importNotionError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo importar Notion: {error}'**
  String importNotionError(Object error);

  /// No description provided for @importNotionWarningsTitle.
  ///
  /// In es, this message translates to:
  /// **'Avisos de importación'**
  String get importNotionWarningsTitle;

  /// No description provided for @importNotionWarningsBody.
  ///
  /// In es, this message translates to:
  /// **'La importación finalizó con los siguientes avisos:'**
  String get importNotionWarningsBody;

  /// No description provided for @ok.
  ///
  /// In es, this message translates to:
  /// **'Aceptar'**
  String get ok;

  /// No description provided for @notionExportGuideTitle.
  ///
  /// In es, this message translates to:
  /// **'Como exportar desde Notion'**
  String get notionExportGuideTitle;

  /// No description provided for @notionExportGuideBody.
  ///
  /// In es, this message translates to:
  /// **'En Notion, abre Settings -> Export all workspace content, elige HTML o Markdown y descarga el archivo ZIP. Luego usa esta opcion de importacion en Folio.'**
  String get notionExportGuideBody;

  /// No description provided for @appBetaBannerMessage.
  ///
  /// In es, this message translates to:
  /// **'Estás usando una versión beta. Puede haber fallos; haz copias de seguridad de la libreta con frecuencia.'**
  String get appBetaBannerMessage;

  /// No description provided for @appBetaBannerDismiss.
  ///
  /// In es, this message translates to:
  /// **'Entendido'**
  String get appBetaBannerDismiss;

  /// No description provided for @integrations.
  ///
  /// In es, this message translates to:
  /// **'Integraciones'**
  String get integrations;

  /// No description provided for @integrationsAppsApprovedHint.
  ///
  /// In es, this message translates to:
  /// **'Las apps externas aprobadas pueden usar el puente de integracion local.'**
  String get integrationsAppsApprovedHint;

  /// No description provided for @integrationsAppsApprovedTitle.
  ///
  /// In es, this message translates to:
  /// **'Apps externas aprobadas'**
  String get integrationsAppsApprovedTitle;

  /// No description provided for @integrationsAppsApprovedNone.
  ///
  /// In es, this message translates to:
  /// **'Todavia no has aprobado ninguna app externa.'**
  String get integrationsAppsApprovedNone;

  /// No description provided for @integrationsAppsApprovedRevoke.
  ///
  /// In es, this message translates to:
  /// **'Revocar acceso'**
  String get integrationsAppsApprovedRevoke;

  /// No description provided for @integrationsApprovedAppDetails.
  ///
  /// In es, this message translates to:
  /// **'{appId} · App {appVersion} · Integracion {integrationVersion}'**
  String integrationsApprovedAppDetails(
    Object appId,
    Object appVersion,
    Object integrationVersion,
  );

  /// No description provided for @integrationApprovalTitle.
  ///
  /// In es, this message translates to:
  /// **'Aprobar integracion externa'**
  String get integrationApprovalTitle;

  /// No description provided for @integrationApprovalUpdateTitle.
  ///
  /// In es, this message translates to:
  /// **'Aprobar actualizacion de integracion'**
  String get integrationApprovalUpdateTitle;

  /// No description provided for @integrationApprovalBody.
  ///
  /// In es, this message translates to:
  /// **'\"{appName}\" quiere conectarse a Folio usando la version {appVersion} de la app y la version {integrationVersion} de la integracion.'**
  String integrationApprovalBody(
    Object appName,
    Object appVersion,
    Object integrationVersion,
  );

  /// No description provided for @integrationApprovalUpdateBody.
  ///
  /// In es, this message translates to:
  /// **'\"{appName}\" ya habia sido aprobada con la version {previousVersion} de la integracion. Ahora quiere conectarse con la version {integrationVersion} de la integracion, asi que Folio necesita tu aprobacion otra vez.'**
  String integrationApprovalUpdateBody(
    Object appName,
    Object previousVersion,
    Object integrationVersion,
  );

  /// No description provided for @integrationApprovalUnknownVersion.
  ///
  /// In es, this message translates to:
  /// **'desconocida'**
  String get integrationApprovalUnknownVersion;

  /// No description provided for @integrationApprovalAppId.
  ///
  /// In es, this message translates to:
  /// **'ID de la app'**
  String get integrationApprovalAppId;

  /// No description provided for @integrationApprovalAppVersion.
  ///
  /// In es, this message translates to:
  /// **'Version de la app'**
  String get integrationApprovalAppVersion;

  /// No description provided for @integrationApprovalProtocolVersion.
  ///
  /// In es, this message translates to:
  /// **'Version de la integracion'**
  String get integrationApprovalProtocolVersion;

  /// No description provided for @integrationApprovalCanDoTitle.
  ///
  /// In es, this message translates to:
  /// **'Lo que esta integracion puede hacer'**
  String get integrationApprovalCanDoTitle;

  /// No description provided for @integrationApprovalCanDoSessions.
  ///
  /// In es, this message translates to:
  /// **'Crear sesiones efimeras de importacion en Folio.'**
  String get integrationApprovalCanDoSessions;

  /// No description provided for @integrationApprovalCanDoImport.
  ///
  /// In es, this message translates to:
  /// **'Enviar documentacion en Markdown para crear o actualizar paginas mediante el puente de importacion.'**
  String get integrationApprovalCanDoImport;

  /// No description provided for @integrationApprovalCanDoMetadata.
  ///
  /// In es, this message translates to:
  /// **'Guardar trazas de importacion como la app cliente, la sesion y metadatos de origen en las paginas importadas.'**
  String get integrationApprovalCanDoMetadata;

  /// No description provided for @integrationApprovalCanDoUnlockedVault.
  ///
  /// In es, this message translates to:
  /// **'Importar solo mientras la libreta este disponible y la peticion incluya el secreto configurado.'**
  String get integrationApprovalCanDoUnlockedVault;

  /// No description provided for @integrationApprovalCannotDoTitle.
  ///
  /// In es, this message translates to:
  /// **'Lo que no puede hacer'**
  String get integrationApprovalCannotDoTitle;

  /// No description provided for @integrationApprovalCannotDoRead.
  ///
  /// In es, this message translates to:
  /// **'No puede leer el contenido de tu libreta a traves de este puente.'**
  String get integrationApprovalCannotDoRead;

  /// No description provided for @integrationApprovalCannotDoBypassLock.
  ///
  /// In es, this message translates to:
  /// **'No puede saltarse el bloqueo de la libreta, el cifrado ni tu aprobacion explicita.'**
  String get integrationApprovalCannotDoBypassLock;

  /// No description provided for @integrationApprovalCannotDoWithoutSecret.
  ///
  /// In es, this message translates to:
  /// **'No puede acceder a endpoints protegidos sin el secreto compartido.'**
  String get integrationApprovalCannotDoWithoutSecret;

  /// No description provided for @integrationApprovalCannotDoRemoteAccess.
  ///
  /// In es, this message translates to:
  /// **'No puede usar el puente desde fuera de localhost.'**
  String get integrationApprovalCannotDoRemoteAccess;

  /// No description provided for @integrationApprovalEncryptedChip.
  ///
  /// In es, this message translates to:
  /// **'Contenido cifrado (v2)'**
  String get integrationApprovalEncryptedChip;

  /// No description provided for @integrationApprovalUnencryptedChip.
  ///
  /// In es, this message translates to:
  /// **'Contenido en claro (v1)'**
  String get integrationApprovalUnencryptedChip;

  /// No description provided for @integrationApprovalEncryptedTitle.
  ///
  /// In es, this message translates to:
  /// **'Version 2: cifrado obligatorio de contenido'**
  String get integrationApprovalEncryptedTitle;

  /// No description provided for @integrationApprovalEncryptedDescription.
  ///
  /// In es, this message translates to:
  /// **'Esta version exige payload cifrado para importar y actualizar contenido mediante el bridge local.'**
  String get integrationApprovalEncryptedDescription;

  /// No description provided for @integrationApprovalUnencryptedTitle.
  ///
  /// In es, this message translates to:
  /// **'Version 1: contenido sin cifrar'**
  String get integrationApprovalUnencryptedTitle;

  /// No description provided for @integrationApprovalUnencryptedDescription.
  ///
  /// In es, this message translates to:
  /// **'Esta version permite payload en claro para contenido. Si quieres cifrado en tránsito, actualiza la integracion a la version 2.'**
  String get integrationApprovalUnencryptedDescription;

  /// No description provided for @integrationApprovalDeny.
  ///
  /// In es, this message translates to:
  /// **'Denegar'**
  String get integrationApprovalDeny;

  /// No description provided for @integrationApprovalApprove.
  ///
  /// In es, this message translates to:
  /// **'Aprobar'**
  String get integrationApprovalApprove;

  /// No description provided for @integrationApprovalApproveUpdate.
  ///
  /// In es, this message translates to:
  /// **'Aprobar esta actualizacion'**
  String get integrationApprovalApproveUpdate;

  /// No description provided for @about.
  ///
  /// In es, this message translates to:
  /// **'Acerca de'**
  String get about;

  /// No description provided for @installedVersion.
  ///
  /// In es, this message translates to:
  /// **'Version instalada'**
  String get installedVersion;

  /// No description provided for @updaterGithubRepository.
  ///
  /// In es, this message translates to:
  /// **'Repositorio de actualizaciones'**
  String get updaterGithubRepository;

  /// No description provided for @updaterBetaDescription.
  ///
  /// In es, this message translates to:
  /// **'Las betas son releases de GitHub marcadas como pre-release.'**
  String get updaterBetaDescription;

  /// No description provided for @updaterStableDescription.
  ///
  /// In es, this message translates to:
  /// **'Solo se tiene en cuenta la ultima release estable.'**
  String get updaterStableDescription;

  /// No description provided for @checkUpdates.
  ///
  /// In es, this message translates to:
  /// **'Buscar actualizaciones'**
  String get checkUpdates;

  /// No description provided for @noEncryptionConfirmTitle.
  ///
  /// In es, this message translates to:
  /// **'Crear libreta sin cifrado'**
  String get noEncryptionConfirmTitle;

  /// No description provided for @noEncryptionConfirmBody.
  ///
  /// In es, this message translates to:
  /// **'Tus datos se guardarán sin contraseña y sin cifrado. Cualquier persona con acceso a este dispositivo podrá leerlos.'**
  String get noEncryptionConfirmBody;

  /// No description provided for @createVaultWithoutEncryption.
  ///
  /// In es, this message translates to:
  /// **'Crear sin cifrado'**
  String get createVaultWithoutEncryption;

  /// No description provided for @plainVaultSecurityNotice.
  ///
  /// In es, this message translates to:
  /// **'Esta libreta no está cifrada: no aplican la passkey, el desbloqueo rápido (Hello), el bloqueo por inactividad, el bloqueo al minimizar ni la contraseña maestra.'**
  String get plainVaultSecurityNotice;

  /// No description provided for @encryptPlainVaultTitle.
  ///
  /// In es, this message translates to:
  /// **'Cifrar esta libreta'**
  String get encryptPlainVaultTitle;

  /// No description provided for @encryptPlainVaultBody.
  ///
  /// In es, this message translates to:
  /// **'Elige una contraseña maestra. Todo lo guardado en este dispositivo se cifrará. Si la olvidas, no podremos recuperar los datos.'**
  String get encryptPlainVaultBody;

  /// No description provided for @encryptPlainVaultConfirm.
  ///
  /// In es, this message translates to:
  /// **'Cifrar libreta'**
  String get encryptPlainVaultConfirm;

  /// No description provided for @encryptPlainVaultSuccessSnack.
  ///
  /// In es, this message translates to:
  /// **'La libreta ya está cifrada'**
  String get encryptPlainVaultSuccessSnack;

  /// No description provided for @aiCopyMessage.
  ///
  /// In es, this message translates to:
  /// **'Copiar'**
  String get aiCopyMessage;

  /// No description provided for @aiCopyCode.
  ///
  /// In es, this message translates to:
  /// **'Copiar código'**
  String get aiCopyCode;

  /// No description provided for @aiCopiedToClipboard.
  ///
  /// In es, this message translates to:
  /// **'Copiado al portapapeles'**
  String get aiCopiedToClipboard;

  /// No description provided for @aiHelpful.
  ///
  /// In es, this message translates to:
  /// **'Útil'**
  String get aiHelpful;

  /// No description provided for @aiNotHelpful.
  ///
  /// In es, this message translates to:
  /// **'No útil'**
  String get aiNotHelpful;

  /// No description provided for @aiThinkingMessage.
  ///
  /// In es, this message translates to:
  /// **'Quill está pensando...'**
  String get aiThinkingMessage;

  /// No description provided for @aiMessageTimestampNow.
  ///
  /// In es, this message translates to:
  /// **'ahora'**
  String get aiMessageTimestampNow;

  /// No description provided for @aiMessageTimestampMinutes.
  ///
  /// In es, this message translates to:
  /// **'hace {n} min'**
  String aiMessageTimestampMinutes(int n);

  /// No description provided for @aiMessageTimestampHours.
  ///
  /// In es, this message translates to:
  /// **'hace {n} h'**
  String aiMessageTimestampHours(int n);

  /// No description provided for @aiMessageTimestampDays.
  ///
  /// In es, this message translates to:
  /// **'hace {n} días'**
  String aiMessageTimestampDays(int n);

  /// No description provided for @templateGalleryTitle.
  ///
  /// In es, this message translates to:
  /// **'Plantillas de página'**
  String get templateGalleryTitle;

  /// No description provided for @templateImport.
  ///
  /// In es, this message translates to:
  /// **'Importar'**
  String get templateImport;

  /// No description provided for @templateImportPickTitle.
  ///
  /// In es, this message translates to:
  /// **'Seleccionar archivo de plantilla'**
  String get templateImportPickTitle;

  /// No description provided for @templateImportSuccess.
  ///
  /// In es, this message translates to:
  /// **'Plantilla importada'**
  String get templateImportSuccess;

  /// No description provided for @templateImportError.
  ///
  /// In es, this message translates to:
  /// **'Error al importar: {error}'**
  String templateImportError(Object error);

  /// No description provided for @templateExportPickTitle.
  ///
  /// In es, this message translates to:
  /// **'Guardar archivo de plantilla'**
  String get templateExportPickTitle;

  /// No description provided for @templateExportSuccess.
  ///
  /// In es, this message translates to:
  /// **'Plantilla exportada'**
  String get templateExportSuccess;

  /// No description provided for @templateExportError.
  ///
  /// In es, this message translates to:
  /// **'Error al exportar: {error}'**
  String templateExportError(Object error);

  /// No description provided for @templateSearchHint.
  ///
  /// In es, this message translates to:
  /// **'Buscar plantillas...'**
  String get templateSearchHint;

  /// No description provided for @templateEmptyHint.
  ///
  /// In es, this message translates to:
  /// **'Sin plantillas.\nGuarda una página como plantilla o importa una.'**
  String get templateEmptyHint;

  /// No description provided for @templateBlockCount.
  ///
  /// In es, this message translates to:
  /// **'{count} {count, plural, one {bloque} other {bloques}}'**
  String templateBlockCount(int count);

  /// No description provided for @templateUse.
  ///
  /// In es, this message translates to:
  /// **'Usar plantilla'**
  String get templateUse;

  /// No description provided for @templateExport.
  ///
  /// In es, this message translates to:
  /// **'Exportar'**
  String get templateExport;

  /// No description provided for @templateBlankPage.
  ///
  /// In es, this message translates to:
  /// **'Página en blanco'**
  String get templateBlankPage;

  /// No description provided for @templateFromGallery.
  ///
  /// In es, this message translates to:
  /// **'Desde plantilla…'**
  String get templateFromGallery;

  /// No description provided for @saveAsTemplate.
  ///
  /// In es, this message translates to:
  /// **'Guardar como plantilla'**
  String get saveAsTemplate;

  /// No description provided for @saveAsTemplateTitle.
  ///
  /// In es, this message translates to:
  /// **'Guardar como plantilla'**
  String get saveAsTemplateTitle;

  /// No description provided for @templateNameHint.
  ///
  /// In es, this message translates to:
  /// **'Nombre de plantilla'**
  String get templateNameHint;

  /// No description provided for @templateDescriptionHint.
  ///
  /// In es, this message translates to:
  /// **'Descripción (opcional)'**
  String get templateDescriptionHint;

  /// No description provided for @templateCategoryHint.
  ///
  /// In es, this message translates to:
  /// **'Categoría (opcional)'**
  String get templateCategoryHint;

  /// No description provided for @templateSaved.
  ///
  /// In es, this message translates to:
  /// **'Guardado como plantilla'**
  String get templateSaved;

  /// No description provided for @templateCount.
  ///
  /// In es, this message translates to:
  /// **'{count} {count, plural, one {plantilla} other {plantillas}}'**
  String templateCount(int count);

  /// No description provided for @templateFilteredCount.
  ///
  /// In es, this message translates to:
  /// **'Mostrando {visible} de {total} plantillas'**
  String templateFilteredCount(int visible, int total);

  /// No description provided for @templateSortRecent.
  ///
  /// In es, this message translates to:
  /// **'Más recientes'**
  String get templateSortRecent;

  /// No description provided for @templateSortName.
  ///
  /// In es, this message translates to:
  /// **'Nombre'**
  String get templateSortName;

  /// No description provided for @templateEdit.
  ///
  /// In es, this message translates to:
  /// **'Editar plantilla'**
  String get templateEdit;

  /// No description provided for @templateUpdated.
  ///
  /// In es, this message translates to:
  /// **'Plantilla actualizada'**
  String get templateUpdated;

  /// No description provided for @templateDeleteConfirmTitle.
  ///
  /// In es, this message translates to:
  /// **'Eliminar plantilla'**
  String get templateDeleteConfirmTitle;

  /// No description provided for @templateDeleteConfirmBody.
  ///
  /// In es, this message translates to:
  /// **'La plantilla \"{name}\" se eliminará de esta libreta.'**
  String templateDeleteConfirmBody(Object name);

  /// No description provided for @templateCreatedOn.
  ///
  /// In es, this message translates to:
  /// **'Creada {date}'**
  String templateCreatedOn(Object date);

  /// No description provided for @templatePreviewEmpty.
  ///
  /// In es, this message translates to:
  /// **'Esta plantilla todavía no tiene vista previa de texto.'**
  String get templatePreviewEmpty;

  /// No description provided for @templateSelectHint.
  ///
  /// In es, this message translates to:
  /// **'Selecciona una plantilla para inspeccionarla, editar sus metadatos o exportarla.'**
  String get templateSelectHint;

  /// No description provided for @templateGalleryTabLocal.
  ///
  /// In es, this message translates to:
  /// **'Locales'**
  String get templateGalleryTabLocal;

  /// No description provided for @templateGalleryTabCommunity.
  ///
  /// In es, this message translates to:
  /// **'Comunidad'**
  String get templateGalleryTabCommunity;

  /// No description provided for @templateCommunitySignInCta.
  ///
  /// In es, this message translates to:
  /// **'Inicia sesión para compartir y explorar plantillas de la comunidad.'**
  String get templateCommunitySignInCta;

  /// No description provided for @templateCommunitySignInButton.
  ///
  /// In es, this message translates to:
  /// **'Iniciar sesión'**
  String get templateCommunitySignInButton;

  /// No description provided for @templateCommunityUnavailable.
  ///
  /// In es, this message translates to:
  /// **'Las plantillas de la comunidad requieren Firebase. Revisa la conexión o la configuración.'**
  String get templateCommunityUnavailable;

  /// No description provided for @templateCommunityEmpty.
  ///
  /// In es, this message translates to:
  /// **'Aún no hay plantillas en la comunidad. Comparte la primera desde la pestaña Locales.'**
  String get templateCommunityEmpty;

  /// No description provided for @templateCommunityLoadError.
  ///
  /// In es, this message translates to:
  /// **'No se pudieron cargar las plantillas: {error}'**
  String templateCommunityLoadError(Object error);

  /// No description provided for @templateCommunityRetry.
  ///
  /// In es, this message translates to:
  /// **'Reintentar'**
  String get templateCommunityRetry;

  /// No description provided for @templateCommunityRefresh.
  ///
  /// In es, this message translates to:
  /// **'Actualizar'**
  String get templateCommunityRefresh;

  /// No description provided for @templateCommunityShareTitle.
  ///
  /// In es, this message translates to:
  /// **'Compartir con la comunidad'**
  String get templateCommunityShareTitle;

  /// No description provided for @templateCommunityShareBody.
  ///
  /// In es, this message translates to:
  /// **'Tu plantilla será pública: cualquiera podrá verla y descargarla. Revisa que no incluya datos personales o confidenciales.'**
  String get templateCommunityShareBody;

  /// No description provided for @templateCommunityShareConfirm.
  ///
  /// In es, this message translates to:
  /// **'Compartir'**
  String get templateCommunityShareConfirm;

  /// No description provided for @templateCommunityShareSuccess.
  ///
  /// In es, this message translates to:
  /// **'Plantilla compartida con la comunidad'**
  String get templateCommunityShareSuccess;

  /// No description provided for @templateCommunityShareError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo compartir: {error}'**
  String templateCommunityShareError(Object error);

  /// No description provided for @templateCommunityAddToVault.
  ///
  /// In es, this message translates to:
  /// **'Guardar en mis plantillas'**
  String get templateCommunityAddToVault;

  /// No description provided for @templateCommunityAddedToVault.
  ///
  /// In es, this message translates to:
  /// **'Guardada en tus plantillas'**
  String get templateCommunityAddedToVault;

  /// No description provided for @templateCommunityDeleteTitle.
  ///
  /// In es, this message translates to:
  /// **'Quitar de la comunidad'**
  String get templateCommunityDeleteTitle;

  /// No description provided for @templateCommunityDeleteBody.
  ///
  /// In es, this message translates to:
  /// **'¿Eliminar \"{name}\" de la tienda comunitaria? No se puede deshacer.'**
  String templateCommunityDeleteBody(Object name);

  /// No description provided for @templateCommunityDeleteSuccess.
  ///
  /// In es, this message translates to:
  /// **'Eliminada de la comunidad'**
  String get templateCommunityDeleteSuccess;

  /// No description provided for @templateCommunityDeleteError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo eliminar: {error}'**
  String templateCommunityDeleteError(Object error);

  /// No description provided for @templateCommunityDownloadError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo descargar la plantilla: {error}'**
  String templateCommunityDownloadError(Object error);

  /// No description provided for @clear.
  ///
  /// In es, this message translates to:
  /// **'Limpiar'**
  String get clear;

  /// No description provided for @cloudAccountSectionTitle.
  ///
  /// In es, this message translates to:
  /// **'Cuenta Folio Cloud'**
  String get cloudAccountSectionTitle;

  /// No description provided for @cloudAccountSectionDescription.
  ///
  /// In es, this message translates to:
  /// **'Opcional. Inicia sesión para suscribirte a copias en la nube, IA hospedada y publicación web. Tu libreta sigue siendo local salvo que uses esas funciones.'**
  String get cloudAccountSectionDescription;

  /// No description provided for @cloudAccountChipOptional.
  ///
  /// In es, this message translates to:
  /// **'Opcional'**
  String get cloudAccountChipOptional;

  /// No description provided for @cloudAccountChipPaidCloud.
  ///
  /// In es, this message translates to:
  /// **'Copias, IA y web'**
  String get cloudAccountChipPaidCloud;

  /// No description provided for @cloudAccountUnavailable.
  ///
  /// In es, this message translates to:
  /// **'No hay inicio de sesión en la nube (Firebase no arrancó). Revisa la conexión o ejecuta flutterfire configure con tu proyecto.'**
  String get cloudAccountUnavailable;

  /// No description provided for @cloudAccountEmailLabel.
  ///
  /// In es, this message translates to:
  /// **'Correo'**
  String get cloudAccountEmailLabel;

  /// No description provided for @cloudAccountPasswordLabel.
  ///
  /// In es, this message translates to:
  /// **'Contraseña'**
  String get cloudAccountPasswordLabel;

  /// No description provided for @cloudAccountSignIn.
  ///
  /// In es, this message translates to:
  /// **'Iniciar sesión'**
  String get cloudAccountSignIn;

  /// No description provided for @cloudAccountCreateAccount.
  ///
  /// In es, this message translates to:
  /// **'Crear cuenta'**
  String get cloudAccountCreateAccount;

  /// No description provided for @cloudAccountForgotPassword.
  ///
  /// In es, this message translates to:
  /// **'¿Olvidaste la contraseña?'**
  String get cloudAccountForgotPassword;

  /// No description provided for @cloudAccountSignOut.
  ///
  /// In es, this message translates to:
  /// **'Cerrar sesión'**
  String get cloudAccountSignOut;

  /// No description provided for @cloudAccountSignedInAs.
  ///
  /// In es, this message translates to:
  /// **'Sesión iniciada como {email}'**
  String cloudAccountSignedInAs(Object email);

  /// No description provided for @cloudAccountUid.
  ///
  /// In es, this message translates to:
  /// **'ID de usuario: {uid}'**
  String cloudAccountUid(Object uid);

  /// No description provided for @cloudAuthDialogTitleSignIn.
  ///
  /// In es, this message translates to:
  /// **'Iniciar sesión en Folio Cloud'**
  String get cloudAuthDialogTitleSignIn;

  /// No description provided for @cloudAuthDialogTitleRegister.
  ///
  /// In es, this message translates to:
  /// **'Crear cuenta de Folio Cloud'**
  String get cloudAuthDialogTitleRegister;

  /// No description provided for @cloudAuthDialogTitleReset.
  ///
  /// In es, this message translates to:
  /// **'Restablecer contraseña'**
  String get cloudAuthDialogTitleReset;

  /// No description provided for @cloudPasswordResetSent.
  ///
  /// In es, this message translates to:
  /// **'Si existe una cuenta con ese correo, se envió un enlace de restablecimiento.'**
  String get cloudPasswordResetSent;

  /// No description provided for @cloudAuthErrorInvalidEmail.
  ///
  /// In es, this message translates to:
  /// **'Ese correo no es válido.'**
  String get cloudAuthErrorInvalidEmail;

  /// No description provided for @cloudAuthErrorWrongPassword.
  ///
  /// In es, this message translates to:
  /// **'Contraseña incorrecta.'**
  String get cloudAuthErrorWrongPassword;

  /// No description provided for @cloudAuthErrorUserNotFound.
  ///
  /// In es, this message translates to:
  /// **'No hay cuenta con ese correo.'**
  String get cloudAuthErrorUserNotFound;

  /// No description provided for @cloudAuthErrorUserDisabled.
  ///
  /// In es, this message translates to:
  /// **'Esta cuenta está deshabilitada.'**
  String get cloudAuthErrorUserDisabled;

  /// No description provided for @cloudAuthErrorEmailAlreadyInUse.
  ///
  /// In es, this message translates to:
  /// **'Ese correo ya está registrado.'**
  String get cloudAuthErrorEmailAlreadyInUse;

  /// No description provided for @cloudAuthErrorWeakPassword.
  ///
  /// In es, this message translates to:
  /// **'La contraseña es demasiado débil.'**
  String get cloudAuthErrorWeakPassword;

  /// No description provided for @cloudAuthErrorInvalidCredential.
  ///
  /// In es, this message translates to:
  /// **'Correo o contraseña no válidos.'**
  String get cloudAuthErrorInvalidCredential;

  /// No description provided for @cloudAuthErrorNetwork.
  ///
  /// In es, this message translates to:
  /// **'Error de red. Comprueba la conexión.'**
  String get cloudAuthErrorNetwork;

  /// No description provided for @cloudAuthErrorTooManyRequests.
  ///
  /// In es, this message translates to:
  /// **'Demasiados intentos. Prueba más tarde.'**
  String get cloudAuthErrorTooManyRequests;

  /// No description provided for @cloudAuthErrorOperationNotAllowed.
  ///
  /// In es, this message translates to:
  /// **'Este método de inicio de sesión no está habilitado en Firebase.'**
  String get cloudAuthErrorOperationNotAllowed;

  /// No description provided for @cloudAuthErrorGeneric.
  ///
  /// In es, this message translates to:
  /// **'No se pudo iniciar sesión. Inténtalo de nuevo.'**
  String get cloudAuthErrorGeneric;

  /// No description provided for @cloudAuthDialogTitle.
  ///
  /// In es, this message translates to:
  /// **'Folio Cloud'**
  String get cloudAuthDialogTitle;

  /// No description provided for @cloudAuthSubtitleSignIn.
  ///
  /// In es, this message translates to:
  /// **'Usa el correo y la contraseña de Folio Cloud. Nada de esto cambia tu libreta local.'**
  String get cloudAuthSubtitleSignIn;

  /// No description provided for @cloudAuthSubtitleRegister.
  ///
  /// In es, this message translates to:
  /// **'Crea credenciales para Folio Cloud. Tus notas en este dispositivo no se suben hasta que actives copias u otras funciones de pago.'**
  String get cloudAuthSubtitleRegister;

  /// No description provided for @cloudAuthModeSignIn.
  ///
  /// In es, this message translates to:
  /// **'Iniciar sesión'**
  String get cloudAuthModeSignIn;

  /// No description provided for @cloudAuthModeRegister.
  ///
  /// In es, this message translates to:
  /// **'Registrarse'**
  String get cloudAuthModeRegister;

  /// No description provided for @cloudAuthConfirmPasswordLabel.
  ///
  /// In es, this message translates to:
  /// **'Confirmar contraseña'**
  String get cloudAuthConfirmPasswordLabel;

  /// No description provided for @cloudAuthValidationRequired.
  ///
  /// In es, this message translates to:
  /// **'Este campo es obligatorio.'**
  String get cloudAuthValidationRequired;

  /// No description provided for @cloudAuthValidationPasswordShort.
  ///
  /// In es, this message translates to:
  /// **'Usa al menos 6 caracteres.'**
  String get cloudAuthValidationPasswordShort;

  /// No description provided for @cloudAuthValidationConfirmMismatch.
  ///
  /// In es, this message translates to:
  /// **'Las contraseñas no coinciden.'**
  String get cloudAuthValidationConfirmMismatch;

  /// No description provided for @cloudAccountSignedOutPrompt.
  ///
  /// In es, this message translates to:
  /// **'Inicia sesión o regístrate para suscribirte a Folio Cloud y usar copias, IA en la nube y publicación.'**
  String get cloudAccountSignedOutPrompt;

  /// No description provided for @cloudAuthResetHint.
  ///
  /// In es, this message translates to:
  /// **'Te enviaremos un enlace por correo para elegir una nueva contraseña.'**
  String get cloudAuthResetHint;

  /// No description provided for @cloudAccountEmailVerified.
  ///
  /// In es, this message translates to:
  /// **'Verificado'**
  String get cloudAccountEmailVerified;

  /// No description provided for @cloudAccountSignOutHelp.
  ///
  /// In es, this message translates to:
  /// **'Tu libreta local sigue en este dispositivo.'**
  String get cloudAccountSignOutHelp;

  /// No description provided for @cloudAccountEmailUnverifiedBanner.
  ///
  /// In es, this message translates to:
  /// **'Verifica tu correo para asegurar tu cuenta Folio Cloud.'**
  String get cloudAccountEmailUnverifiedBanner;

  /// No description provided for @cloudAccountResendVerification.
  ///
  /// In es, this message translates to:
  /// **'Reenviar correo de verificación'**
  String get cloudAccountResendVerification;

  /// No description provided for @cloudAccountReloadVerification.
  ///
  /// In es, this message translates to:
  /// **'Ya verifiqué'**
  String get cloudAccountReloadVerification;

  /// No description provided for @cloudAccountVerificationSent.
  ///
  /// In es, this message translates to:
  /// **'Correo de verificación enviado.'**
  String get cloudAccountVerificationSent;

  /// No description provided for @cloudAccountVerificationStillPending.
  ///
  /// In es, this message translates to:
  /// **'El correo sigue sin verificarse. Abre el enlace de tu bandeja de entrada.'**
  String get cloudAccountVerificationStillPending;

  /// No description provided for @cloudAccountVerificationNowVerified.
  ///
  /// In es, this message translates to:
  /// **'Correo verificado.'**
  String get cloudAccountVerificationNowVerified;

  /// No description provided for @cloudAccountResetPasswordEmail.
  ///
  /// In es, this message translates to:
  /// **'Restablecer contraseña por correo'**
  String get cloudAccountResetPasswordEmail;

  /// No description provided for @cloudAccountCopyEmail.
  ///
  /// In es, this message translates to:
  /// **'Copiar correo'**
  String get cloudAccountCopyEmail;

  /// No description provided for @cloudAccountEmailCopied.
  ///
  /// In es, this message translates to:
  /// **'Correo copiado.'**
  String get cloudAccountEmailCopied;

  /// No description provided for @folioWebPortalSubsectionTitle.
  ///
  /// In es, this message translates to:
  /// **'Cuenta web'**
  String get folioWebPortalSubsectionTitle;

  /// No description provided for @folioWebPortalLinkCodeLabel.
  ///
  /// In es, this message translates to:
  /// **'Código de emparejamiento'**
  String get folioWebPortalLinkCodeLabel;

  /// No description provided for @folioWebPortalLinkHelp.
  ///
  /// In es, this message translates to:
  /// **'Genera el código en la web, en Ajustes → cuenta Folio, e introdúcelo aquí en los próximos 10 minutos.'**
  String get folioWebPortalLinkHelp;

  /// No description provided for @folioWebPortalLinkButton.
  ///
  /// In es, this message translates to:
  /// **'Vincular'**
  String get folioWebPortalLinkButton;

  /// No description provided for @folioWebPortalLinkSuccess.
  ///
  /// In es, this message translates to:
  /// **'Cuenta web vinculada correctamente.'**
  String get folioWebPortalLinkSuccess;

  /// No description provided for @folioWebPortalNeedSignIn.
  ///
  /// In es, this message translates to:
  /// **'Inicia sesión en Folio Cloud para vincular la cuenta web.'**
  String get folioWebPortalNeedSignIn;

  /// No description provided for @folioWebMirrorNote.
  ///
  /// In es, this message translates to:
  /// **'Copias, IA y publicación siguen gobernadas por Folio Cloud (Firestore). Lo siguiente refleja tu cuenta en la web.'**
  String get folioWebMirrorNote;

  /// No description provided for @folioWebEntitlementLinked.
  ///
  /// In es, this message translates to:
  /// **'Cuenta web vinculada'**
  String get folioWebEntitlementLinked;

  /// No description provided for @folioWebEntitlementNotLinked.
  ///
  /// In es, this message translates to:
  /// **'Cuenta web no vinculada'**
  String get folioWebEntitlementNotLinked;

  /// No description provided for @folioWebEntitlementWebPlan.
  ///
  /// In es, this message translates to:
  /// **'Folio Cloud (web): {value}'**
  String folioWebEntitlementWebPlan(String value);

  /// No description provided for @folioWebEntitlementWebStatus.
  ///
  /// In es, this message translates to:
  /// **'Estado (web): {value}'**
  String folioWebEntitlementWebStatus(String value);

  /// No description provided for @folioWebEntitlementWebPeriodEnd.
  ///
  /// In es, this message translates to:
  /// **'Fin de periodo (web): {value}'**
  String folioWebEntitlementWebPeriodEnd(String value);

  /// No description provided for @folioWebEntitlementWebInk.
  ///
  /// In es, this message translates to:
  /// **'Tinta (web): {count}'**
  String folioWebEntitlementWebInk(int count);

  /// No description provided for @folioWebPortalRefreshWeb.
  ///
  /// In es, this message translates to:
  /// **'Actualizar estado web'**
  String get folioWebPortalRefreshWeb;

  /// No description provided for @folioWebPortalErrorNetwork.
  ///
  /// In es, this message translates to:
  /// **'No se pudo conectar con el portal. Comprueba la conexión.'**
  String get folioWebPortalErrorNetwork;

  /// No description provided for @folioWebPortalErrorTimeout.
  ///
  /// In es, this message translates to:
  /// **'El portal tardó demasiado en responder.'**
  String get folioWebPortalErrorTimeout;

  /// No description provided for @folioWebPortalErrorAdminNotConfigured.
  ///
  /// In es, this message translates to:
  /// **'Folio Firebase Admin no está configurado en el servidor (revisa el backend).'**
  String get folioWebPortalErrorAdminNotConfigured;

  /// No description provided for @folioWebPortalErrorUnauthorized.
  ///
  /// In es, this message translates to:
  /// **'Sesión no válida. Vuelve a iniciar sesión en Folio Cloud.'**
  String get folioWebPortalErrorUnauthorized;

  /// No description provided for @folioWebPortalErrorGeneric.
  ///
  /// In es, this message translates to:
  /// **'No se pudo completar la operación con el portal.'**
  String get folioWebPortalErrorGeneric;

  /// No description provided for @folioWebPortalServerMessage.
  ///
  /// In es, this message translates to:
  /// **'{message}'**
  String folioWebPortalServerMessage(String message);

  /// No description provided for @folioCloudSubsectionPlan.
  ///
  /// In es, this message translates to:
  /// **'Plan y estado'**
  String get folioCloudSubsectionPlan;

  /// No description provided for @folioCloudSubsectionInk.
  ///
  /// In es, this message translates to:
  /// **'Saldo de tinta'**
  String get folioCloudSubsectionInk;

  /// No description provided for @folioCloudSubsectionSubscription.
  ///
  /// In es, this message translates to:
  /// **'Suscripción y facturación'**
  String get folioCloudSubsectionSubscription;

  /// No description provided for @folioCloudSubsectionBackupPublish.
  ///
  /// In es, this message translates to:
  /// **'Copias y publicación'**
  String get folioCloudSubsectionBackupPublish;

  /// No description provided for @folioCloudSubscriptionActive.
  ///
  /// In es, this message translates to:
  /// **'Suscripción activa'**
  String get folioCloudSubscriptionActive;

  /// No description provided for @folioCloudSubscriptionActiveWithStatus.
  ///
  /// In es, this message translates to:
  /// **'Suscripción activa ({status})'**
  String folioCloudSubscriptionActiveWithStatus(String status);

  /// No description provided for @folioCloudSubscriptionNoneTitle.
  ///
  /// In es, this message translates to:
  /// **'Sin suscripción Folio Cloud'**
  String get folioCloudSubscriptionNoneTitle;

  /// No description provided for @folioCloudSubscriptionNoneSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Activa un plan para copias cifradas, IA en la nube y publicación web.'**
  String get folioCloudSubscriptionNoneSubtitle;

  /// No description provided for @folioCloudFeatureBackup.
  ///
  /// In es, this message translates to:
  /// **'Copia en la nube'**
  String get folioCloudFeatureBackup;

  /// No description provided for @folioCloudFeatureCloudAi.
  ///
  /// In es, this message translates to:
  /// **'IA en la nube'**
  String get folioCloudFeatureCloudAi;

  /// No description provided for @folioCloudFeaturePublishWeb.
  ///
  /// In es, this message translates to:
  /// **'Publicación web'**
  String get folioCloudFeaturePublishWeb;

  /// No description provided for @folioCloudFeatureOn.
  ///
  /// In es, this message translates to:
  /// **'Incluida'**
  String get folioCloudFeatureOn;

  /// No description provided for @folioCloudFeatureOff.
  ///
  /// In es, this message translates to:
  /// **'No incluida'**
  String get folioCloudFeatureOff;

  /// No description provided for @folioCloudPostPaymentHint.
  ///
  /// In es, this message translates to:
  /// **'Si acabas de pagar y ves las funciones en «no», pulsa «Actualizar desde Stripe».'**
  String get folioCloudPostPaymentHint;

  /// No description provided for @folioCloudBackupCleanupWarning.
  ///
  /// In es, this message translates to:
  /// **'Copia subida, pero no se pudo limpiar copias antiguas (se reintentará más tarde).'**
  String get folioCloudBackupCleanupWarning;

  /// No description provided for @folioCloudInkMonthly.
  ///
  /// In es, this message translates to:
  /// **'Mes'**
  String get folioCloudInkMonthly;

  /// No description provided for @folioCloudInkPurchased.
  ///
  /// In es, this message translates to:
  /// **'Compradas'**
  String get folioCloudInkPurchased;

  /// No description provided for @folioCloudInkTotal.
  ///
  /// In es, this message translates to:
  /// **'Total'**
  String get folioCloudInkTotal;

  /// No description provided for @folioCloudInkCount.
  ///
  /// In es, this message translates to:
  /// **'{count}'**
  String folioCloudInkCount(int count);

  /// No description provided for @folioCloudPlanActiveHeadline.
  ///
  /// In es, this message translates to:
  /// **'Plan mensual Folio Cloud activo'**
  String get folioCloudPlanActiveHeadline;

  /// No description provided for @folioCloudSubscribeMonthly.
  ///
  /// In es, this message translates to:
  /// **'Folio Cloud 4,99 €/mes'**
  String get folioCloudSubscribeMonthly;

  /// No description provided for @folioCloudPitchScreenTitle.
  ///
  /// In es, this message translates to:
  /// **'Folio Cloud'**
  String get folioCloudPitchScreenTitle;

  /// No description provided for @folioCloudPitchHeadline.
  ///
  /// In es, this message translates to:
  /// **'Tu libreta sigue en el dispositivo. La nube entra cuando tú quieres.'**
  String get folioCloudPitchHeadline;

  /// No description provided for @folioCloudPitchSubhead.
  ///
  /// In es, this message translates to:
  /// **'Un plan mensual desbloquea copias cifradas, IA alojada en la nube con recarga mensual de tinta y publicación web: solo lo que decidas compartir.'**
  String get folioCloudPitchSubhead;

  /// No description provided for @folioCloudPitchLearnMore.
  ///
  /// In es, this message translates to:
  /// **'Ver qué incluye'**
  String get folioCloudPitchLearnMore;

  /// No description provided for @folioCloudPitchCtaNeedAccount.
  ///
  /// In es, this message translates to:
  /// **'Iniciar sesión o crear cuenta'**
  String get folioCloudPitchCtaNeedAccount;

  /// No description provided for @folioCloudPitchGuestTeaserTitle.
  ///
  /// In es, this message translates to:
  /// **'Cuenta Folio Cloud'**
  String get folioCloudPitchGuestTeaserTitle;

  /// No description provided for @folioCloudPitchGuestTeaserBody.
  ///
  /// In es, this message translates to:
  /// **'Cuenta opcional: mira qué incluye el plan y entra cuando quieras suscribirte.'**
  String get folioCloudPitchGuestTeaserBody;

  /// No description provided for @folioCloudPitchOpenSettingsToSignIn.
  ///
  /// In es, this message translates to:
  /// **'Abre Ajustes e inicia sesión en Folio Cloud (sección Folio Cloud) para suscribirte.'**
  String get folioCloudPitchOpenSettingsToSignIn;

  /// No description provided for @folioCloudBuyInk.
  ///
  /// In es, this message translates to:
  /// **'Comprar tinta'**
  String get folioCloudBuyInk;

  /// No description provided for @folioCloudInkSmall.
  ///
  /// In es, this message translates to:
  /// **'Tintero pequeño (1,99 €)'**
  String get folioCloudInkSmall;

  /// No description provided for @folioCloudInkMedium.
  ///
  /// In es, this message translates to:
  /// **'Tintero mediano (4,99 €)'**
  String get folioCloudInkMedium;

  /// No description provided for @folioCloudInkLarge.
  ///
  /// In es, this message translates to:
  /// **'Tintero grande (9,99 €)'**
  String get folioCloudInkLarge;

  /// No description provided for @folioCloudManageSubscription.
  ///
  /// In es, this message translates to:
  /// **'Gestionar suscripción'**
  String get folioCloudManageSubscription;

  /// No description provided for @folioCloudRefreshFromStripe.
  ///
  /// In es, this message translates to:
  /// **'Actualizar'**
  String get folioCloudRefreshFromStripe;

  /// No description provided for @folioCloudMicrosoftStoreBillingTitle.
  ///
  /// In es, this message translates to:
  /// **'Microsoft Store (Windows)'**
  String get folioCloudMicrosoftStoreBillingTitle;

  /// No description provided for @folioCloudMicrosoftStoreBillingSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Misma suscripción y tinteros que con Stripe; la Tienda cobra y el servidor valida la compra. Configura los ids de producto con --dart-define y Azure AD en Cloud Functions.'**
  String get folioCloudMicrosoftStoreBillingSubtitle;

  /// No description provided for @folioCloudMicrosoftStoreSubscribeButton.
  ///
  /// In es, this message translates to:
  /// **'Suscripción en la Tienda'**
  String get folioCloudMicrosoftStoreSubscribeButton;

  /// No description provided for @folioCloudMicrosoftStoreSyncButton.
  ///
  /// In es, this message translates to:
  /// **'Sincronizar con la Tienda'**
  String get folioCloudMicrosoftStoreSyncButton;

  /// No description provided for @folioCloudMicrosoftStoreInkTitle.
  ///
  /// In es, this message translates to:
  /// **'Tinta — Microsoft Store'**
  String get folioCloudMicrosoftStoreInkTitle;

  /// No description provided for @folioCloudMicrosoftStoreInkPackSmall.
  ///
  /// In es, this message translates to:
  /// **'Tintero pequeño (Tienda)'**
  String get folioCloudMicrosoftStoreInkPackSmall;

  /// No description provided for @folioCloudMicrosoftStoreInkPackMedium.
  ///
  /// In es, this message translates to:
  /// **'Tintero mediano (Tienda)'**
  String get folioCloudMicrosoftStoreInkPackMedium;

  /// No description provided for @folioCloudMicrosoftStoreInkPackLarge.
  ///
  /// In es, this message translates to:
  /// **'Tintero grande (Tienda)'**
  String get folioCloudMicrosoftStoreInkPackLarge;

  /// No description provided for @folioCloudMicrosoftStoreSyncedSnack.
  ///
  /// In es, this message translates to:
  /// **'Sincronizado con Microsoft Store.'**
  String get folioCloudMicrosoftStoreSyncedSnack;

  /// No description provided for @folioCloudMicrosoftStoreAppliedSnack.
  ///
  /// In es, this message translates to:
  /// **'Compra aplicada. Si no ves los cambios, pulsa sincronizar.'**
  String get folioCloudMicrosoftStoreAppliedSnack;

  /// No description provided for @folioCloudPurchaseChannelTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Dónde quieres pagar?'**
  String get folioCloudPurchaseChannelTitle;

  /// No description provided for @folioCloudPurchaseChannelBody.
  ///
  /// In es, this message translates to:
  /// **'Puedes usar la Microsoft Store integrada en Windows o pagar con tarjeta en el navegador (Stripe). El plan y la tinta son los mismos.'**
  String get folioCloudPurchaseChannelBody;

  /// No description provided for @folioCloudPurchaseChannelMicrosoftStore.
  ///
  /// In es, this message translates to:
  /// **'Microsoft Store'**
  String get folioCloudPurchaseChannelMicrosoftStore;

  /// No description provided for @folioCloudPurchaseChannelStripe.
  ///
  /// In es, this message translates to:
  /// **'En el navegador (Stripe)'**
  String get folioCloudPurchaseChannelStripe;

  /// No description provided for @folioCloudPurchaseChannelCancel.
  ///
  /// In es, this message translates to:
  /// **'Cancelar'**
  String get folioCloudPurchaseChannelCancel;

  /// No description provided for @folioCloudPurchaseChannelStoreNotConfigured.
  ///
  /// In es, this message translates to:
  /// **'La opción de la Tienda no está configurada en esta compilación (faltan ids de producto).'**
  String get folioCloudPurchaseChannelStoreNotConfigured;

  /// No description provided for @folioCloudPurchaseChannelStoreNotConfiguredHint.
  ///
  /// In es, this message translates to:
  /// **'Compila con --dart-define=MS_STORE_… o usa el pago en el navegador.'**
  String get folioCloudPurchaseChannelStoreNotConfiguredHint;

  /// No description provided for @folioCloudMicrosoftStoreSyncHint.
  ///
  /// In es, this message translates to:
  /// **'En Windows, «Actualizar» también sincroniza la Microsoft Store (mismo botón que Stripe).'**
  String get folioCloudMicrosoftStoreSyncHint;

  /// No description provided for @folioCloudUploadEncryptedBackup.
  ///
  /// In es, this message translates to:
  /// **'Copia a la nube ahora'**
  String get folioCloudUploadEncryptedBackup;

  /// No description provided for @folioCloudUploadEncryptedBackupSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Folio sube una copia incremental cifrada en la nube de la libreta abierta (solo lo que cambió); no hace falta exportar un .zip.'**
  String get folioCloudUploadEncryptedBackupSubtitle;

  /// No description provided for @folioCloudUploadSnackOk.
  ///
  /// In es, this message translates to:
  /// **'Copia de la libreta guardada en la nube.'**
  String get folioCloudUploadSnackOk;

  /// No description provided for @scheduledVaultBackupCloudSyncTitle.
  ///
  /// In es, this message translates to:
  /// **'Copia en Folio Cloud'**
  String get scheduledVaultBackupCloudSyncTitle;

  /// No description provided for @scheduledVaultBackupCloudSyncSubtitle.
  ///
  /// In es, this message translates to:
  /// **'En cada intervalo programado, sube automáticamente una copia cifrada a tu cuenta de Folio Cloud.'**
  String get scheduledVaultBackupCloudSyncSubtitle;

  /// No description provided for @folioCloudCloudBackupsList.
  ///
  /// In es, this message translates to:
  /// **'Copias en la nube'**
  String get folioCloudCloudBackupsList;

  /// No description provided for @folioCloudBackupsUsed.
  ///
  /// In es, this message translates to:
  /// **'Usadas'**
  String get folioCloudBackupsUsed;

  /// No description provided for @folioCloudBackupsLimit.
  ///
  /// In es, this message translates to:
  /// **'Límite'**
  String get folioCloudBackupsLimit;

  /// No description provided for @folioCloudBackupsRemaining.
  ///
  /// In es, this message translates to:
  /// **'Restantes'**
  String get folioCloudBackupsRemaining;

  /// No description provided for @folioCloudBackupStorageStatUsed.
  ///
  /// In es, this message translates to:
  /// **'Usado (almacenamiento)'**
  String get folioCloudBackupStorageStatUsed;

  /// No description provided for @folioCloudBackupStorageStatQuota.
  ///
  /// In es, this message translates to:
  /// **'Cuota'**
  String get folioCloudBackupStorageStatQuota;

  /// No description provided for @folioCloudBackupStorageStatRemaining.
  ///
  /// In es, this message translates to:
  /// **'Restante'**
  String get folioCloudBackupStorageStatRemaining;

  /// No description provided for @folioCloudBackupStorageExpansionTitle.
  ///
  /// In es, this message translates to:
  /// **'Ampliar almacenamiento de copias'**
  String get folioCloudBackupStorageExpansionTitle;

  /// No description provided for @folioCloudBackupStorageLibrarySmallTitle.
  ///
  /// In es, this message translates to:
  /// **'Librería pequeña'**
  String get folioCloudBackupStorageLibrarySmallTitle;

  /// No description provided for @folioCloudBackupStorageLibrarySmallDetail.
  ///
  /// In es, this message translates to:
  /// **'+20 GB · 1,99 €/mes'**
  String get folioCloudBackupStorageLibrarySmallDetail;

  /// No description provided for @folioCloudBackupStorageLibraryMediumTitle.
  ///
  /// In es, this message translates to:
  /// **'Librería mediana'**
  String get folioCloudBackupStorageLibraryMediumTitle;

  /// No description provided for @folioCloudBackupStorageLibraryMediumDetail.
  ///
  /// In es, this message translates to:
  /// **'+75 GB · 4,99 €/mes'**
  String get folioCloudBackupStorageLibraryMediumDetail;

  /// No description provided for @folioCloudBackupStorageLibraryLargeTitle.
  ///
  /// In es, this message translates to:
  /// **'Librería grande'**
  String get folioCloudBackupStorageLibraryLargeTitle;

  /// No description provided for @folioCloudBackupStorageLibraryLargeDetail.
  ///
  /// In es, this message translates to:
  /// **'+250 GB · 9,99 €/mes'**
  String get folioCloudBackupStorageLibraryLargeDetail;

  /// No description provided for @folioCloudSubscribeBackupStorageAddon.
  ///
  /// In es, this message translates to:
  /// **'Suscribirse'**
  String get folioCloudSubscribeBackupStorageAddon;

  /// No description provided for @folioCloudBackupTypeIncremental.
  ///
  /// In es, this message translates to:
  /// **'Copia incremental (última)'**
  String get folioCloudBackupTypeIncremental;

  /// No description provided for @folioCloudBackupPackNoDownload.
  ///
  /// In es, this message translates to:
  /// **'Las copias incrementales se restauran con «Importar y sobrescribir». No hay descarga de archivo aparte.'**
  String get folioCloudBackupPackNoDownload;

  /// No description provided for @folioCloudBackupQuotaExceeded.
  ///
  /// In es, this message translates to:
  /// **'No hay suficiente almacenamiento para copias en la nube. Compra una ampliación o borra copias completas antiguas en backups/.'**
  String get folioCloudBackupQuotaExceeded;

  /// No description provided for @onboardingCloudBackupNeedLegacyArchive.
  ///
  /// In es, this message translates to:
  /// **'Esta libreta solo tiene una copia incremental en la nube. Para configurar un dispositivo nuevo, descarga un archivo completo (.tar.gz) desde otro dispositivo con Folio o créalo desde Ajustes → exportar.'**
  String get onboardingCloudBackupNeedLegacyArchive;

  /// No description provided for @onboardingCloudBackupNeedRestoreWrap.
  ///
  /// In es, this message translates to:
  /// **'Esta copia incremental aún no tiene clave de recuperación en la nube. En el dispositivo donde creaste la copia, abre Folio → Ajustes → sube la copia a la nube (introduce la contraseña de la libreta cuando se solicite). También puedes usar un archivo completo (.zip) si lo tienes.'**
  String get onboardingCloudBackupNeedRestoreWrap;

  /// No description provided for @onboardingCloudBackupIncrementalRestoreBody.
  ///
  /// In es, this message translates to:
  /// **'Copia incremental en la nube lista. Introduce la contraseña de la libreta (la misma que usas para desbloquearla). Si la libreta estaba en claro, usa la contraseña de recuperación que definiste al subir la copia.'**
  String get onboardingCloudBackupIncrementalRestoreBody;

  /// No description provided for @settingsCloudBackupWrapPasswordTitle.
  ///
  /// In es, this message translates to:
  /// **'Recuperación en otros dispositivos'**
  String get settingsCloudBackupWrapPasswordTitle;

  /// No description provided for @settingsCloudBackupWrapPasswordBody.
  ///
  /// In es, this message translates to:
  /// **'Introduce la contraseña de esta libreta. Se guardará cifrada en tu cuenta para restaurar la copia incremental al instalar Folio en un dispositivo nuevo.'**
  String get settingsCloudBackupWrapPasswordBody;

  /// No description provided for @settingsCloudBackupWrapPasswordRequired.
  ///
  /// In es, this message translates to:
  /// **'Hace falta la contraseña de la libreta.'**
  String get settingsCloudBackupWrapPasswordRequired;

  /// No description provided for @settingsCloudBackupWrapPasswordBodyPlain.
  ///
  /// In es, this message translates to:
  /// **'Opcional: elige una contraseña de recuperación para restaurar esta copia incremental en otro dispositivo. Déjala en blanco si solo usarás este equipo.'**
  String get settingsCloudBackupWrapPasswordBodyPlain;

  /// No description provided for @folioCloudPublishTestPage.
  ///
  /// In es, this message translates to:
  /// **'Publicar página de prueba'**
  String get folioCloudPublishTestPage;

  /// No description provided for @folioCloudPublishedPagesList.
  ///
  /// In es, this message translates to:
  /// **'Páginas publicadas'**
  String get folioCloudPublishedPagesList;

  /// No description provided for @folioCloudReauthDialogTitle.
  ///
  /// In es, this message translates to:
  /// **'Confirmar cuenta Folio Cloud'**
  String get folioCloudReauthDialogTitle;

  /// No description provided for @folioCloudReauthDialogBody.
  ///
  /// In es, this message translates to:
  /// **'Introduce la contraseña de tu cuenta Folio Cloud (la del inicio de sesión en la nube) para listar y descargar copias. No es la contraseña de la libreta local.'**
  String get folioCloudReauthDialogBody;

  /// No description provided for @folioCloudReauthRequiresPasswordProvider.
  ///
  /// In es, this message translates to:
  /// **'Esta sesión no usa contraseña de Folio Cloud. Cierra sesión en la cuenta e inicia de nuevo con correo y contraseña si necesitas descargar copias.'**
  String get folioCloudReauthRequiresPasswordProvider;

  /// No description provided for @folioCloudAiNoInkTitle.
  ///
  /// In es, this message translates to:
  /// **'Sin tinta para la IA en la nube'**
  String get folioCloudAiNoInkTitle;

  /// No description provided for @folioCloudAiNoInkBody.
  ///
  /// In es, this message translates to:
  /// **'Puedes comprar un tintero en Folio Cloud, esperar la recarga mensual o cambiar a IA local (Ollama o LM Studio) en la sección de IA de Ajustes.'**
  String get folioCloudAiNoInkBody;

  /// No description provided for @folioCloudAiNoInkActionCloud.
  ///
  /// In es, this message translates to:
  /// **'Folio Cloud y tinta'**
  String get folioCloudAiNoInkActionCloud;

  /// No description provided for @folioCloudAiNoInkActionLocal.
  ///
  /// In es, this message translates to:
  /// **'Proveedor de IA'**
  String get folioCloudAiNoInkActionLocal;

  /// No description provided for @folioCloudAiZeroInkBanner.
  ///
  /// In es, this message translates to:
  /// **'Tinta de IA en la nube: 0 gotas. Abre Ajustes para comprar tinta o usar IA local.'**
  String get folioCloudAiZeroInkBanner;

  /// No description provided for @folioCloudInkPurchaseAppliedHint.
  ///
  /// In es, this message translates to:
  /// **'Compra aplicada: {purchased} gotas compradas disponibles para IA en la nube.'**
  String folioCloudInkPurchaseAppliedHint(Object purchased);

  /// No description provided for @onboardingCloudBackupCta.
  ///
  /// In es, this message translates to:
  /// **'Iniciar sesión y descargar copia'**
  String get onboardingCloudBackupCta;

  /// No description provided for @onboardingCloudBackupPickVaultSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Elige qué libreta quieres restaurar.'**
  String get onboardingCloudBackupPickVaultSubtitle;

  /// No description provided for @onboardingFolioCloudTitle.
  ///
  /// In es, this message translates to:
  /// **'Folio Cloud'**
  String get onboardingFolioCloudTitle;

  /// No description provided for @onboardingFolioCloudBody.
  ///
  /// In es, this message translates to:
  /// **'Activa funciones en la nube cuando las necesites: copias cifradas, Quill hospedada y publicación web. Tu libreta sigue siendo local salvo que uses estas funciones.'**
  String get onboardingFolioCloudBody;

  /// No description provided for @onboardingFolioCloudFeatureBackupTitle.
  ///
  /// In es, this message translates to:
  /// **'Copias cifradas en la nube'**
  String get onboardingFolioCloudFeatureBackupTitle;

  /// No description provided for @onboardingFolioCloudFeatureBackupBody.
  ///
  /// In es, this message translates to:
  /// **'Guarda y descarga copias de la libreta desde tu cuenta. En escritorio, listar/descargar se hace desde Folio Cloud.'**
  String get onboardingFolioCloudFeatureBackupBody;

  /// No description provided for @onboardingFolioCloudFeatureAiTitle.
  ///
  /// In es, this message translates to:
  /// **'IA en la nube + tinta'**
  String get onboardingFolioCloudFeatureAiTitle;

  /// No description provided for @onboardingFolioCloudFeatureAiBody.
  ///
  /// In es, this message translates to:
  /// **'Quill en la nube con suscripción Folio Cloud (IA en la nube) o solo comprando tinta. La tinta se consume por uso; también puedes usar IA local (Ollama/LM Studio).'**
  String get onboardingFolioCloudFeatureAiBody;

  /// No description provided for @onboardingFolioCloudFeatureWebTitle.
  ///
  /// In es, this message translates to:
  /// **'Publicación web'**
  String get onboardingFolioCloudFeatureWebTitle;

  /// No description provided for @onboardingFolioCloudFeatureWebBody.
  ///
  /// In es, this message translates to:
  /// **'Publica páginas seleccionadas y controla qué se hace público. El resto de la libreta no se comparte.'**
  String get onboardingFolioCloudFeatureWebBody;

  /// No description provided for @onboardingFolioCloudLaterInSettings.
  ///
  /// In es, this message translates to:
  /// **'Lo veré en Ajustes'**
  String get onboardingFolioCloudLaterInSettings;

  /// No description provided for @collabMenuAction.
  ///
  /// In es, this message translates to:
  /// **'Colaboración en vivo'**
  String get collabMenuAction;

  /// No description provided for @collabSheetTitle.
  ///
  /// In es, this message translates to:
  /// **'Colaboración en vivo'**
  String get collabSheetTitle;

  /// No description provided for @collabHeaderSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Cuenta Folio obligatoria. Crear sala requiere plan con anfitrión; unirse solo necesita el código. Contenido y chat van cifrados de extremo a extremo; el servidor no ve tu texto.'**
  String get collabHeaderSubtitle;

  /// No description provided for @collabNoRoomHint.
  ///
  /// In es, this message translates to:
  /// **'Crea una sala (si tu plan incluye anfitrión) o pega el código que te comparta el anfitrión (emojis y números).'**
  String get collabNoRoomHint;

  /// No description provided for @collabCreateRoom.
  ///
  /// In es, this message translates to:
  /// **'Crear sala'**
  String get collabCreateRoom;

  /// No description provided for @collabJoinCodeLabel.
  ///
  /// In es, this message translates to:
  /// **'Código de sala'**
  String get collabJoinCodeLabel;

  /// No description provided for @collabJoinCodeHint.
  ///
  /// In es, this message translates to:
  /// **'Ej.: dos emojis y 4 dígitos'**
  String get collabJoinCodeHint;

  /// No description provided for @collabJoinRoom.
  ///
  /// In es, this message translates to:
  /// **'Unirse'**
  String get collabJoinRoom;

  /// No description provided for @collabJoinFailed.
  ///
  /// In es, this message translates to:
  /// **'Código no válido o sala llena.'**
  String get collabJoinFailed;

  /// No description provided for @collabShareCodeLabel.
  ///
  /// In es, this message translates to:
  /// **'Comparte este código'**
  String get collabShareCodeLabel;

  /// No description provided for @collabCopyJoinCode.
  ///
  /// In es, this message translates to:
  /// **'Copiar código'**
  String get collabCopyJoinCode;

  /// No description provided for @collabCopied.
  ///
  /// In es, this message translates to:
  /// **'Copiado'**
  String get collabCopied;

  /// No description provided for @collabHostRequiresPlan.
  ///
  /// In es, this message translates to:
  /// **'Para crear salas necesitas Folio Cloud con la función de colaboración (anfitrión). Puedes unirte a salas ajenas con un código sin ese plan.'**
  String get collabHostRequiresPlan;

  /// No description provided for @collabChatEmptyHint.
  ///
  /// In es, this message translates to:
  /// **'Aún no hay mensajes. Saluda a tu equipo.'**
  String get collabChatEmptyHint;

  /// No description provided for @collabMessageHint.
  ///
  /// In es, this message translates to:
  /// **'Escribe un mensaje…'**
  String get collabMessageHint;

  /// No description provided for @collabArchivedOk.
  ///
  /// In es, this message translates to:
  /// **'Chat archivado en comentarios de la página.'**
  String get collabArchivedOk;

  /// No description provided for @collabArchiveToPage.
  ///
  /// In es, this message translates to:
  /// **'Archivar chat en la página'**
  String get collabArchiveToPage;

  /// No description provided for @collabLeaveRoom.
  ///
  /// In es, this message translates to:
  /// **'Salir de la sala'**
  String get collabLeaveRoom;

  /// No description provided for @collabNeedsJoinCode.
  ///
  /// In es, this message translates to:
  /// **'Introduce el código de sala para descifrar esta sesión.'**
  String get collabNeedsJoinCode;

  /// No description provided for @collabMissingJoinCodeHint.
  ///
  /// In es, this message translates to:
  /// **'La página está enlazada a una sala pero aquí no hay código guardado. Pega el código del anfitrión para descifrar contenido y chat.'**
  String get collabMissingJoinCodeHint;

  /// No description provided for @collabUnlockWithCode.
  ///
  /// In es, this message translates to:
  /// **'Descifrar con código'**
  String get collabUnlockWithCode;

  /// No description provided for @collabHidePanel.
  ///
  /// In es, this message translates to:
  /// **'Ocultar panel de colaboración'**
  String get collabHidePanel;

  /// No description provided for @shortcutsCaptureTitle.
  ///
  /// In es, this message translates to:
  /// **'Nuevo atajo'**
  String get shortcutsCaptureTitle;

  /// No description provided for @shortcutsCaptureHint.
  ///
  /// In es, this message translates to:
  /// **'Pulsa las teclas (Esc cancela).'**
  String get shortcutsCaptureHint;

  /// No description provided for @updaterStartupDialogTitleStable.
  ///
  /// In es, this message translates to:
  /// **'Actualización disponible'**
  String get updaterStartupDialogTitleStable;

  /// No description provided for @updaterStartupDialogTitleBeta.
  ///
  /// In es, this message translates to:
  /// **'Beta disponible'**
  String get updaterStartupDialogTitleBeta;

  /// No description provided for @updaterStartupDialogBody.
  ///
  /// In es, this message translates to:
  /// **'Hay una nueva versión ({releaseVersion}) disponible.'**
  String updaterStartupDialogBody(Object releaseVersion);

  /// No description provided for @updaterStartupDialogQuestion.
  ///
  /// In es, this message translates to:
  /// **'¿Quieres descargar e instalar ahora?'**
  String get updaterStartupDialogQuestion;

  /// No description provided for @updaterStartupDialogLater.
  ///
  /// In es, this message translates to:
  /// **'Más tarde'**
  String get updaterStartupDialogLater;

  /// No description provided for @updaterStartupDialogUpdateNow.
  ///
  /// In es, this message translates to:
  /// **'Actualizar ahora'**
  String get updaterStartupDialogUpdateNow;

  /// No description provided for @updaterStartupDialogBetaNote.
  ///
  /// In es, this message translates to:
  /// **'Versión beta (pre-release).'**
  String get updaterStartupDialogBetaNote;

  /// No description provided for @updaterOpenApkDownloadQuestion.
  ///
  /// In es, this message translates to:
  /// **'¿Abrir descarga del APK ahora?'**
  String get updaterOpenApkDownloadQuestion;

  /// No description provided for @updaterManualCheckUnsupportedPlatform.
  ///
  /// In es, this message translates to:
  /// **'El actualizador integrado solo está disponible en Windows y Android.'**
  String get updaterManualCheckUnsupportedPlatform;

  /// No description provided for @updaterManualCheckAlreadyLatest.
  ///
  /// In es, this message translates to:
  /// **'Ya tienes la versión más reciente.'**
  String get updaterManualCheckAlreadyLatest;

  /// No description provided for @updaterDialogLineCurrentVersion.
  ///
  /// In es, this message translates to:
  /// **'Versión actual: {currentVersion}'**
  String updaterDialogLineCurrentVersion(Object currentVersion);

  /// No description provided for @updaterDialogLineNewVersion.
  ///
  /// In es, this message translates to:
  /// **'Nueva versión: {releaseVersion}'**
  String updaterDialogLineNewVersion(Object releaseVersion);

  /// No description provided for @updaterApkUrlInvalidSnack.
  ///
  /// In es, this message translates to:
  /// **'No se encontró URL válida del APK en el release.'**
  String get updaterApkUrlInvalidSnack;

  /// No description provided for @updaterApkOpenFailedSnack.
  ///
  /// In es, this message translates to:
  /// **'No se pudo abrir la descarga del APK.'**
  String get updaterApkOpenFailedSnack;

  /// No description provided for @toggleTitleHint.
  ///
  /// In es, this message translates to:
  /// **'Título del desplegable'**
  String get toggleTitleHint;

  /// No description provided for @toggleBodyHint.
  ///
  /// In es, this message translates to:
  /// **'Contenido…'**
  String get toggleBodyHint;

  /// No description provided for @taskStatusTodo.
  ///
  /// In es, this message translates to:
  /// **'Por hacer'**
  String get taskStatusTodo;

  /// No description provided for @taskStatusInProgress.
  ///
  /// In es, this message translates to:
  /// **'En progreso'**
  String get taskStatusInProgress;

  /// No description provided for @taskStatusDone.
  ///
  /// In es, this message translates to:
  /// **'Hecho'**
  String get taskStatusDone;

  /// No description provided for @taskPriorityNone.
  ///
  /// In es, this message translates to:
  /// **'Sin prioridad'**
  String get taskPriorityNone;

  /// No description provided for @taskPriorityLow.
  ///
  /// In es, this message translates to:
  /// **'Baja'**
  String get taskPriorityLow;

  /// No description provided for @taskPriorityMedium.
  ///
  /// In es, this message translates to:
  /// **'Media'**
  String get taskPriorityMedium;

  /// No description provided for @taskPriorityHigh.
  ///
  /// In es, this message translates to:
  /// **'Alta'**
  String get taskPriorityHigh;

  /// No description provided for @taskTitleHint.
  ///
  /// In es, this message translates to:
  /// **'Descripción de la tarea…'**
  String get taskTitleHint;

  /// No description provided for @taskPriorityTooltip.
  ///
  /// In es, this message translates to:
  /// **'Prioridad'**
  String get taskPriorityTooltip;

  /// No description provided for @taskNoDueDate.
  ///
  /// In es, this message translates to:
  /// **'Sin fecha límite'**
  String get taskNoDueDate;

  /// No description provided for @taskSubtaskHint.
  ///
  /// In es, this message translates to:
  /// **'Subtarea…'**
  String get taskSubtaskHint;

  /// No description provided for @taskRemoveSubtask.
  ///
  /// In es, this message translates to:
  /// **'Quitar subtarea'**
  String get taskRemoveSubtask;

  /// No description provided for @taskAddSubtask.
  ///
  /// In es, this message translates to:
  /// **'Añadir subtarea'**
  String get taskAddSubtask;

  /// No description provided for @taskRecurrenceNone.
  ///
  /// In es, this message translates to:
  /// **'Sin repetición'**
  String get taskRecurrenceNone;

  /// No description provided for @taskRecurrenceLabel.
  ///
  /// In es, this message translates to:
  /// **'Repetición'**
  String get taskRecurrenceLabel;

  /// No description provided for @taskRecurrenceDaily.
  ///
  /// In es, this message translates to:
  /// **'Cada día'**
  String get taskRecurrenceDaily;

  /// No description provided for @taskRecurrenceWeekly.
  ///
  /// In es, this message translates to:
  /// **'Cada semana'**
  String get taskRecurrenceWeekly;

  /// No description provided for @taskRecurrenceMonthly.
  ///
  /// In es, this message translates to:
  /// **'Cada mes'**
  String get taskRecurrenceMonthly;

  /// No description provided for @taskRecurrenceYearly.
  ///
  /// In es, this message translates to:
  /// **'Cada año'**
  String get taskRecurrenceYearly;

  /// No description provided for @taskReminderTooltip.
  ///
  /// In es, this message translates to:
  /// **'Recordarme en la fecha límite'**
  String get taskReminderTooltip;

  /// No description provided for @taskReminderOnTooltip.
  ///
  /// In es, this message translates to:
  /// **'Recordatorio activo'**
  String get taskReminderOnTooltip;

  /// No description provided for @taskOverdueReminder.
  ///
  /// In es, this message translates to:
  /// **'Tarea vencida'**
  String get taskOverdueReminder;

  /// No description provided for @taskDueTodayReminder.
  ///
  /// In es, this message translates to:
  /// **'Vence hoy'**
  String get taskDueTodayReminder;

  /// No description provided for @settingsWindowsNotifications.
  ///
  /// In es, this message translates to:
  /// **'Notificaciones de Windows'**
  String get settingsWindowsNotifications;

  /// No description provided for @settingsWindowsNotificationsSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Muestra alertas nativas de Windows cuando una tarea vence hoy o está vencida'**
  String get settingsWindowsNotificationsSubtitle;

  /// No description provided for @title.
  ///
  /// In es, this message translates to:
  /// **'Título'**
  String get title;

  /// No description provided for @description.
  ///
  /// In es, this message translates to:
  /// **'Descripción'**
  String get description;

  /// No description provided for @priority.
  ///
  /// In es, this message translates to:
  /// **'Prioridad'**
  String get priority;

  /// No description provided for @status.
  ///
  /// In es, this message translates to:
  /// **'Estado'**
  String get status;

  /// No description provided for @none.
  ///
  /// In es, this message translates to:
  /// **'Ninguna'**
  String get none;

  /// No description provided for @low.
  ///
  /// In es, this message translates to:
  /// **'Baja'**
  String get low;

  /// No description provided for @medium.
  ///
  /// In es, this message translates to:
  /// **'Media'**
  String get medium;

  /// No description provided for @high.
  ///
  /// In es, this message translates to:
  /// **'Alta'**
  String get high;

  /// No description provided for @startDate.
  ///
  /// In es, this message translates to:
  /// **'Fecha de inicio'**
  String get startDate;

  /// No description provided for @dueDate.
  ///
  /// In es, this message translates to:
  /// **'Fecha límite'**
  String get dueDate;

  /// No description provided for @timeSpentMinutes.
  ///
  /// In es, this message translates to:
  /// **'Tiempo invertido (minutos)'**
  String get timeSpentMinutes;

  /// No description provided for @taskBlocked.
  ///
  /// In es, this message translates to:
  /// **'Bloqueada'**
  String get taskBlocked;

  /// No description provided for @taskBlockedReason.
  ///
  /// In es, this message translates to:
  /// **'Motivo de bloqueo'**
  String get taskBlockedReason;

  /// No description provided for @subtasks.
  ///
  /// In es, this message translates to:
  /// **'Subtareas'**
  String get subtasks;

  /// No description provided for @add.
  ///
  /// In es, this message translates to:
  /// **'Añadir'**
  String get add;

  /// No description provided for @templateEmojiLabel.
  ///
  /// In es, this message translates to:
  /// **'Emoji'**
  String get templateEmojiLabel;

  /// No description provided for @aiGenericErrorWithReason.
  ///
  /// In es, this message translates to:
  /// **'Error IA: {reason}'**
  String aiGenericErrorWithReason(Object reason);

  /// No description provided for @calloutTypeTooltip.
  ///
  /// In es, this message translates to:
  /// **'Tipo de callout'**
  String get calloutTypeTooltip;

  /// No description provided for @calloutTypeInfo.
  ///
  /// In es, this message translates to:
  /// **'Info'**
  String get calloutTypeInfo;

  /// No description provided for @calloutTypeSuccess.
  ///
  /// In es, this message translates to:
  /// **'Éxito'**
  String get calloutTypeSuccess;

  /// No description provided for @calloutTypeWarning.
  ///
  /// In es, this message translates to:
  /// **'Advertencia'**
  String get calloutTypeWarning;

  /// No description provided for @calloutTypeError.
  ///
  /// In es, this message translates to:
  /// **'Error'**
  String get calloutTypeError;

  /// No description provided for @calloutTypeNote.
  ///
  /// In es, this message translates to:
  /// **'Nota'**
  String get calloutTypeNote;

  /// No description provided for @blockEditorEnterHintNewBlock.
  ///
  /// In es, this message translates to:
  /// **'Enter: bloque nuevo (en código: Enter = línea)'**
  String get blockEditorEnterHintNewBlock;

  /// No description provided for @blockEditorEnterHintNewLine.
  ///
  /// In es, this message translates to:
  /// **'Enter: nueva línea'**
  String get blockEditorEnterHintNewLine;

  /// No description provided for @blockEditorShortcutsHintMobile.
  ///
  /// In es, this message translates to:
  /// **'{enterHint} · / para bloques · toca el bloque para más acciones'**
  String blockEditorShortcutsHintMobile(String enterHint);

  /// No description provided for @blockEditorShortcutsHintDesktop.
  ///
  /// In es, this message translates to:
  /// **'{enterHint} · Shift+Enter: línea · / tipos · # título (misma línea) · - · * · [] · ``` espacio · tabla/imagen en / · formato: barra al enfocar o ** _ <u> ` ~~'**
  String blockEditorShortcutsHintDesktop(String enterHint);

  /// No description provided for @blockEditorSelectedBlocksBanner.
  ///
  /// In es, this message translates to:
  /// **'{count} bloques seleccionados · Shift: rango · Ctrl/Cmd: alternar'**
  String blockEditorSelectedBlocksBanner(int count);

  /// No description provided for @blockEditorDuplicate.
  ///
  /// In es, this message translates to:
  /// **'Duplicar'**
  String get blockEditorDuplicate;

  /// No description provided for @blockEditorClearSelectionTooltip.
  ///
  /// In es, this message translates to:
  /// **'Limpiar selección'**
  String get blockEditorClearSelectionTooltip;

  /// No description provided for @blockEditorMenuRewriteWithAi.
  ///
  /// In es, this message translates to:
  /// **'Reescribir con IA…'**
  String get blockEditorMenuRewriteWithAi;

  /// No description provided for @blockEditorMenuMoveUp.
  ///
  /// In es, this message translates to:
  /// **'Mover arriba'**
  String get blockEditorMenuMoveUp;

  /// No description provided for @blockEditorMenuMoveDown.
  ///
  /// In es, this message translates to:
  /// **'Mover abajo'**
  String get blockEditorMenuMoveDown;

  /// No description provided for @blockEditorMenuDuplicateBlock.
  ///
  /// In es, this message translates to:
  /// **'Duplicar bloque'**
  String get blockEditorMenuDuplicateBlock;

  /// No description provided for @blockEditorMenuAppearance.
  ///
  /// In es, this message translates to:
  /// **'Apariencia…'**
  String get blockEditorMenuAppearance;

  /// No description provided for @blockEditorMenuCalloutIcon.
  ///
  /// In es, this message translates to:
  /// **'Icono del callout…'**
  String get blockEditorMenuCalloutIcon;

  /// No description provided for @blockEditorCalloutMenuType.
  ///
  /// In es, this message translates to:
  /// **'Tipo: {typeName}'**
  String blockEditorCalloutMenuType(String typeName);

  /// No description provided for @blockEditorCopyLink.
  ///
  /// In es, this message translates to:
  /// **'Copiar enlace'**
  String get blockEditorCopyLink;

  /// No description provided for @blockEditorMenuCreateSubpage.
  ///
  /// In es, this message translates to:
  /// **'Crear subpágina'**
  String get blockEditorMenuCreateSubpage;

  /// No description provided for @blockEditorMenuLinkPage.
  ///
  /// In es, this message translates to:
  /// **'Enlazar página…'**
  String get blockEditorMenuLinkPage;

  /// No description provided for @blockEditorMenuOpenSubpage.
  ///
  /// In es, this message translates to:
  /// **'Abrir subpágina'**
  String get blockEditorMenuOpenSubpage;

  /// No description provided for @blockEditorMenuPickImage.
  ///
  /// In es, this message translates to:
  /// **'Elegir imagen…'**
  String get blockEditorMenuPickImage;

  /// No description provided for @blockEditorMenuRemoveImage.
  ///
  /// In es, this message translates to:
  /// **'Quitar imagen'**
  String get blockEditorMenuRemoveImage;

  /// No description provided for @blockEditorMenuCodeLanguage.
  ///
  /// In es, this message translates to:
  /// **'Lenguaje del código…'**
  String get blockEditorMenuCodeLanguage;

  /// No description provided for @blockEditorMenuEditDiagram.
  ///
  /// In es, this message translates to:
  /// **'Editar diagrama…'**
  String get blockEditorMenuEditDiagram;

  /// No description provided for @blockEditorMenuBackToPreview.
  ///
  /// In es, this message translates to:
  /// **'Volver a vista previa'**
  String get blockEditorMenuBackToPreview;

  /// No description provided for @blockEditorMenuChangeFile.
  ///
  /// In es, this message translates to:
  /// **'Cambiar archivo…'**
  String get blockEditorMenuChangeFile;

  /// No description provided for @blockEditorMenuRemoveFile.
  ///
  /// In es, this message translates to:
  /// **'Quitar archivo'**
  String get blockEditorMenuRemoveFile;

  /// No description provided for @blockEditorMenuChangeVideo.
  ///
  /// In es, this message translates to:
  /// **'Cambiar video…'**
  String get blockEditorMenuChangeVideo;

  /// No description provided for @blockEditorMenuRemoveVideo.
  ///
  /// In es, this message translates to:
  /// **'Quitar video'**
  String get blockEditorMenuRemoveVideo;

  /// No description provided for @blockEditorMenuChangeAudio.
  ///
  /// In es, this message translates to:
  /// **'Cambiar audio…'**
  String get blockEditorMenuChangeAudio;

  /// No description provided for @blockEditorMenuRemoveAudio.
  ///
  /// In es, this message translates to:
  /// **'Quitar audio'**
  String get blockEditorMenuRemoveAudio;

  /// No description provided for @blockEditorMenuEditLabel.
  ///
  /// In es, this message translates to:
  /// **'Editar etiqueta…'**
  String get blockEditorMenuEditLabel;

  /// No description provided for @blockEditorMenuAddRow.
  ///
  /// In es, this message translates to:
  /// **'Añadir fila'**
  String get blockEditorMenuAddRow;

  /// No description provided for @blockEditorMenuRemoveLastRow.
  ///
  /// In es, this message translates to:
  /// **'Quitar última fila'**
  String get blockEditorMenuRemoveLastRow;

  /// No description provided for @blockEditorMenuAddColumn.
  ///
  /// In es, this message translates to:
  /// **'Añadir columna'**
  String get blockEditorMenuAddColumn;

  /// No description provided for @blockEditorMenuRemoveLastColumn.
  ///
  /// In es, this message translates to:
  /// **'Quitar última columna'**
  String get blockEditorMenuRemoveLastColumn;

  /// No description provided for @blockEditorMenuAddProperty.
  ///
  /// In es, this message translates to:
  /// **'Añadir propiedad'**
  String get blockEditorMenuAddProperty;

  /// No description provided for @blockEditorMenuChangeBlockType.
  ///
  /// In es, this message translates to:
  /// **'Cambiar tipo de bloque…'**
  String get blockEditorMenuChangeBlockType;

  /// No description provided for @blockEditorMenuDeleteBlock.
  ///
  /// In es, this message translates to:
  /// **'Eliminar bloque'**
  String get blockEditorMenuDeleteBlock;

  /// No description provided for @blockEditorAppearanceTitle.
  ///
  /// In es, this message translates to:
  /// **'Apariencia del bloque'**
  String get blockEditorAppearanceTitle;

  /// No description provided for @blockEditorAppearanceSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Personaliza tamaño, color del texto y fondo para este bloque.'**
  String get blockEditorAppearanceSubtitle;

  /// No description provided for @blockEditorAppearanceSize.
  ///
  /// In es, this message translates to:
  /// **'Tamaño'**
  String get blockEditorAppearanceSize;

  /// No description provided for @blockEditorAppearanceTextColor.
  ///
  /// In es, this message translates to:
  /// **'Color del texto'**
  String get blockEditorAppearanceTextColor;

  /// No description provided for @blockEditorAppearanceBackground.
  ///
  /// In es, this message translates to:
  /// **'Fondo'**
  String get blockEditorAppearanceBackground;

  /// No description provided for @blockEditorAppearancePreviewEmpty.
  ///
  /// In es, this message translates to:
  /// **'Así se verá este bloque.'**
  String get blockEditorAppearancePreviewEmpty;

  /// No description provided for @blockEditorReset.
  ///
  /// In es, this message translates to:
  /// **'Restablecer'**
  String get blockEditorReset;

  /// No description provided for @blockEditorCodeLanguageTitle.
  ///
  /// In es, this message translates to:
  /// **'Lenguaje del código'**
  String get blockEditorCodeLanguageTitle;

  /// No description provided for @blockEditorCodeLanguageSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Resaltado de sintaxis según el lenguaje elegido.'**
  String get blockEditorCodeLanguageSubtitle;

  /// No description provided for @blockEditorTemplateButtonTitle.
  ///
  /// In es, this message translates to:
  /// **'Etiqueta del botón plantilla'**
  String get blockEditorTemplateButtonTitle;

  /// No description provided for @blockEditorTemplateButtonFieldLabel.
  ///
  /// In es, this message translates to:
  /// **'Texto del botón'**
  String get blockEditorTemplateButtonFieldLabel;

  /// No description provided for @blockEditorTemplateButtonDefaultLabel.
  ///
  /// In es, this message translates to:
  /// **'Plantilla'**
  String get blockEditorTemplateButtonDefaultLabel;

  /// No description provided for @blockEditorTextColorDefault.
  ///
  /// In es, this message translates to:
  /// **'Tema'**
  String get blockEditorTextColorDefault;

  /// No description provided for @blockEditorTextColorSubtle.
  ///
  /// In es, this message translates to:
  /// **'Suave'**
  String get blockEditorTextColorSubtle;

  /// No description provided for @blockEditorTextColorPrimary.
  ///
  /// In es, this message translates to:
  /// **'Primario'**
  String get blockEditorTextColorPrimary;

  /// No description provided for @blockEditorTextColorSecondary.
  ///
  /// In es, this message translates to:
  /// **'Secundario'**
  String get blockEditorTextColorSecondary;

  /// No description provided for @blockEditorTextColorTertiary.
  ///
  /// In es, this message translates to:
  /// **'Acento'**
  String get blockEditorTextColorTertiary;

  /// No description provided for @blockEditorTextColorError.
  ///
  /// In es, this message translates to:
  /// **'Error'**
  String get blockEditorTextColorError;

  /// No description provided for @blockEditorBackgroundNone.
  ///
  /// In es, this message translates to:
  /// **'Sin fondo'**
  String get blockEditorBackgroundNone;

  /// No description provided for @blockEditorBackgroundSurface.
  ///
  /// In es, this message translates to:
  /// **'Sutil'**
  String get blockEditorBackgroundSurface;

  /// No description provided for @blockEditorBackgroundPrimary.
  ///
  /// In es, this message translates to:
  /// **'Primario'**
  String get blockEditorBackgroundPrimary;

  /// No description provided for @blockEditorBackgroundSecondary.
  ///
  /// In es, this message translates to:
  /// **'Secundario'**
  String get blockEditorBackgroundSecondary;

  /// No description provided for @blockEditorBackgroundTertiary.
  ///
  /// In es, this message translates to:
  /// **'Acento'**
  String get blockEditorBackgroundTertiary;

  /// No description provided for @blockEditorBackgroundError.
  ///
  /// In es, this message translates to:
  /// **'Error'**
  String get blockEditorBackgroundError;

  /// No description provided for @blockEditorCmdDuplicatePrev.
  ///
  /// In es, this message translates to:
  /// **'Duplicar bloque anterior'**
  String get blockEditorCmdDuplicatePrev;

  /// No description provided for @blockEditorCmdDuplicatePrevHint.
  ///
  /// In es, this message translates to:
  /// **'Clona el bloque inmediatamente anterior'**
  String get blockEditorCmdDuplicatePrevHint;

  /// No description provided for @blockEditorCmdInsertDate.
  ///
  /// In es, this message translates to:
  /// **'Insertar fecha'**
  String get blockEditorCmdInsertDate;

  /// No description provided for @blockEditorCmdInsertDateHint.
  ///
  /// In es, this message translates to:
  /// **'Escribe la fecha actual'**
  String get blockEditorCmdInsertDateHint;

  /// No description provided for @blockEditorCmdMentionPage.
  ///
  /// In es, this message translates to:
  /// **'Mencionar página'**
  String get blockEditorCmdMentionPage;

  /// No description provided for @blockEditorCmdMentionPageHint.
  ///
  /// In es, this message translates to:
  /// **'Inserta enlace interno a una página'**
  String get blockEditorCmdMentionPageHint;

  /// No description provided for @blockEditorCmdTurnInto.
  ///
  /// In es, this message translates to:
  /// **'Convertir bloque'**
  String get blockEditorCmdTurnInto;

  /// No description provided for @blockEditorCmdTurnIntoHint.
  ///
  /// In es, this message translates to:
  /// **'Elegir tipo de bloque con el selector'**
  String get blockEditorCmdTurnIntoHint;

  /// No description provided for @blockEditorMarkTaskComplete.
  ///
  /// In es, this message translates to:
  /// **'Marcar tarea completada'**
  String get blockEditorMarkTaskComplete;

  /// No description provided for @blockEditorCalloutIconPickerTitle.
  ///
  /// In es, this message translates to:
  /// **'Icono del callout'**
  String get blockEditorCalloutIconPickerTitle;

  /// No description provided for @blockEditorCalloutIconPickerHelper.
  ///
  /// In es, this message translates to:
  /// **'Selecciona un icono para cambiar el tono visual del bloque destacado.'**
  String get blockEditorCalloutIconPickerHelper;

  /// No description provided for @blockEditorIconPickerCustomEmoji.
  ///
  /// In es, this message translates to:
  /// **'Emoji personalizado'**
  String get blockEditorIconPickerCustomEmoji;

  /// No description provided for @blockEditorIconPickerQuickTab.
  ///
  /// In es, this message translates to:
  /// **'Rápidos'**
  String get blockEditorIconPickerQuickTab;

  /// No description provided for @blockEditorIconPickerImportedTab.
  ///
  /// In es, this message translates to:
  /// **'Importados'**
  String get blockEditorIconPickerImportedTab;

  /// No description provided for @blockEditorIconPickerAllTab.
  ///
  /// In es, this message translates to:
  /// **'Todos'**
  String get blockEditorIconPickerAllTab;

  /// No description provided for @blockEditorIconPickerEmptyImported.
  ///
  /// In es, this message translates to:
  /// **'Todavía no has importado iconos en Ajustes.'**
  String get blockEditorIconPickerEmptyImported;

  /// No description provided for @blockTypeSectionBasicText.
  ///
  /// In es, this message translates to:
  /// **'Texto básico'**
  String get blockTypeSectionBasicText;

  /// No description provided for @blockTypeSectionLists.
  ///
  /// In es, this message translates to:
  /// **'Listas'**
  String get blockTypeSectionLists;

  /// No description provided for @blockTypeSectionMedia.
  ///
  /// In es, this message translates to:
  /// **'Multimedia y datos'**
  String get blockTypeSectionMedia;

  /// No description provided for @blockTypeSectionAdvanced.
  ///
  /// In es, this message translates to:
  /// **'Avanzado y diseño'**
  String get blockTypeSectionAdvanced;

  /// No description provided for @blockTypeSectionEmbeds.
  ///
  /// In es, this message translates to:
  /// **'Integraciones'**
  String get blockTypeSectionEmbeds;

  /// No description provided for @blockTypeParagraphLabel.
  ///
  /// In es, this message translates to:
  /// **'Texto'**
  String get blockTypeParagraphLabel;

  /// No description provided for @blockTypeParagraphHint.
  ///
  /// In es, this message translates to:
  /// **'Párrafo'**
  String get blockTypeParagraphHint;

  /// No description provided for @blockTypeChildPageLabel.
  ///
  /// In es, this message translates to:
  /// **'Página'**
  String get blockTypeChildPageLabel;

  /// No description provided for @blockTypeChildPageHint.
  ///
  /// In es, this message translates to:
  /// **'Subpágina enlazada'**
  String get blockTypeChildPageHint;

  /// No description provided for @blockTypeH1Label.
  ///
  /// In es, this message translates to:
  /// **'Encabezado 1'**
  String get blockTypeH1Label;

  /// No description provided for @blockTypeH1Hint.
  ///
  /// In es, this message translates to:
  /// **'Título grande  ·  #'**
  String get blockTypeH1Hint;

  /// No description provided for @blockTypeH2Label.
  ///
  /// In es, this message translates to:
  /// **'Encabezado 2'**
  String get blockTypeH2Label;

  /// No description provided for @blockTypeH2Hint.
  ///
  /// In es, this message translates to:
  /// **'Subtítulo  ·  ##'**
  String get blockTypeH2Hint;

  /// No description provided for @blockTypeH3Label.
  ///
  /// In es, this message translates to:
  /// **'Encabezado 3'**
  String get blockTypeH3Label;

  /// No description provided for @blockTypeH3Hint.
  ///
  /// In es, this message translates to:
  /// **'Encabezado menor  ·  ###'**
  String get blockTypeH3Hint;

  /// No description provided for @blockTypeQuoteLabel.
  ///
  /// In es, this message translates to:
  /// **'Cita'**
  String get blockTypeQuoteLabel;

  /// No description provided for @blockTypeQuoteHint.
  ///
  /// In es, this message translates to:
  /// **'Texto citado'**
  String get blockTypeQuoteHint;

  /// No description provided for @blockTypeDividerLabel.
  ///
  /// In es, this message translates to:
  /// **'Divisor'**
  String get blockTypeDividerLabel;

  /// No description provided for @blockTypeDividerHint.
  ///
  /// In es, this message translates to:
  /// **'Separador  ·  ---'**
  String get blockTypeDividerHint;

  /// No description provided for @blockTypeCalloutLabel.
  ///
  /// In es, this message translates to:
  /// **'Bloque destacado'**
  String get blockTypeCalloutLabel;

  /// No description provided for @blockTypeCalloutHint.
  ///
  /// In es, this message translates to:
  /// **'Aviso con icono'**
  String get blockTypeCalloutHint;

  /// No description provided for @blockTypeBulletLabel.
  ///
  /// In es, this message translates to:
  /// **'Lista con viñetas'**
  String get blockTypeBulletLabel;

  /// No description provided for @blockTypeBulletHint.
  ///
  /// In es, this message translates to:
  /// **'Lista con puntos'**
  String get blockTypeBulletHint;

  /// No description provided for @blockTypeNumberedLabel.
  ///
  /// In es, this message translates to:
  /// **'Lista numerada'**
  String get blockTypeNumberedLabel;

  /// No description provided for @blockTypeNumberedHint.
  ///
  /// In es, this message translates to:
  /// **'Lista 1, 2, 3'**
  String get blockTypeNumberedHint;

  /// No description provided for @blockTypeTodoLabel.
  ///
  /// In es, this message translates to:
  /// **'Lista de tareas'**
  String get blockTypeTodoLabel;

  /// No description provided for @blockTypeTodoHint.
  ///
  /// In es, this message translates to:
  /// **'Checklist'**
  String get blockTypeTodoHint;

  /// No description provided for @blockTypeTaskLabel.
  ///
  /// In es, this message translates to:
  /// **'Tarea enriquecida'**
  String get blockTypeTaskLabel;

  /// No description provided for @blockTypeTaskHint.
  ///
  /// In es, this message translates to:
  /// **'Estado / prioridad / fecha'**
  String get blockTypeTaskHint;

  /// No description provided for @blockTypeToggleLabel.
  ///
  /// In es, this message translates to:
  /// **'Desplegable'**
  String get blockTypeToggleLabel;

  /// No description provided for @blockTypeToggleHint.
  ///
  /// In es, this message translates to:
  /// **'Mostrar/ocultar contenido'**
  String get blockTypeToggleHint;

  /// No description provided for @blockTypeImageLabel.
  ///
  /// In es, this message translates to:
  /// **'Imagen'**
  String get blockTypeImageLabel;

  /// No description provided for @blockTypeImageHint.
  ///
  /// In es, this message translates to:
  /// **'Imagen local o externa'**
  String get blockTypeImageHint;

  /// No description provided for @blockTypeBookmarkLabel.
  ///
  /// In es, this message translates to:
  /// **'Marcador con vista previa'**
  String get blockTypeBookmarkLabel;

  /// No description provided for @blockTypeBookmarkHint.
  ///
  /// In es, this message translates to:
  /// **'Tarjeta con enlace'**
  String get blockTypeBookmarkHint;

  /// No description provided for @blockTypeVideoLabel.
  ///
  /// In es, this message translates to:
  /// **'Vídeo'**
  String get blockTypeVideoLabel;

  /// No description provided for @blockTypeVideoHint.
  ///
  /// In es, this message translates to:
  /// **'Archivo o enlace'**
  String get blockTypeVideoHint;

  /// No description provided for @blockTypeAudioLabel.
  ///
  /// In es, this message translates to:
  /// **'Audio'**
  String get blockTypeAudioLabel;

  /// No description provided for @blockTypeAudioHint.
  ///
  /// In es, this message translates to:
  /// **'Reproductor de audio'**
  String get blockTypeAudioHint;

  /// No description provided for @blockTypeMeetingNoteLabel.
  ///
  /// In es, this message translates to:
  /// **'Nota de reunión'**
  String get blockTypeMeetingNoteLabel;

  /// No description provided for @blockTypeMeetingNoteHint.
  ///
  /// In es, this message translates to:
  /// **'Graba y transcribe una reunión'**
  String get blockTypeMeetingNoteHint;

  /// No description provided for @blockTypeCodeLabel.
  ///
  /// In es, this message translates to:
  /// **'Código (Java, Python…)'**
  String get blockTypeCodeLabel;

  /// No description provided for @blockTypeCodeHint.
  ///
  /// In es, this message translates to:
  /// **'Bloque con sintaxis'**
  String get blockTypeCodeHint;

  /// No description provided for @blockTypeFileLabel.
  ///
  /// In es, this message translates to:
  /// **'Archivo / PDF'**
  String get blockTypeFileLabel;

  /// No description provided for @blockTypeFileHint.
  ///
  /// In es, this message translates to:
  /// **'Adjunto o PDF'**
  String get blockTypeFileHint;

  /// No description provided for @blockTypeTableLabel.
  ///
  /// In es, this message translates to:
  /// **'Tabla'**
  String get blockTypeTableLabel;

  /// No description provided for @blockTypeTableHint.
  ///
  /// In es, this message translates to:
  /// **'Filas y columnas'**
  String get blockTypeTableHint;

  /// No description provided for @blockTypeDatabaseLabel.
  ///
  /// In es, this message translates to:
  /// **'Base de datos'**
  String get blockTypeDatabaseLabel;

  /// No description provided for @blockTypeDatabaseHint.
  ///
  /// In es, this message translates to:
  /// **'Vista lista/tabla/tablero'**
  String get blockTypeDatabaseHint;

  /// No description provided for @blockTypeKanbanLabel.
  ///
  /// In es, this message translates to:
  /// **'Kanban'**
  String get blockTypeKanbanLabel;

  /// No description provided for @blockTypeKanbanHint.
  ///
  /// In es, this message translates to:
  /// **'Vista tablero para las tareas de esta página'**
  String get blockTypeKanbanHint;

  /// No description provided for @kanbanBlockRowTitle.
  ///
  /// In es, this message translates to:
  /// **'Tablero Kanban'**
  String get kanbanBlockRowTitle;

  /// No description provided for @kanbanBlockRowSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Al abrir la página verás el tablero. En la barra del tablero usa «Abrir editor de bloques» para editar o quitar este bloque.'**
  String get kanbanBlockRowSubtitle;

  /// No description provided for @kanbanRowTodosExcluded.
  ///
  /// In es, this message translates to:
  /// **'Sin checklists'**
  String get kanbanRowTodosExcluded;

  /// No description provided for @kanbanToolbarOpenEditor.
  ///
  /// In es, this message translates to:
  /// **'Abrir editor de bloques'**
  String get kanbanToolbarOpenEditor;

  /// No description provided for @kanbanToolbarAddTask.
  ///
  /// In es, this message translates to:
  /// **'Añadir tarea'**
  String get kanbanToolbarAddTask;

  /// No description provided for @kanbanClassicModeBanner.
  ///
  /// In es, this message translates to:
  /// **'Editor de bloques: puedes mover o eliminar el bloque Kanban.'**
  String get kanbanClassicModeBanner;

  /// No description provided for @kanbanBackToBoard.
  ///
  /// In es, this message translates to:
  /// **'Volver al tablero'**
  String get kanbanBackToBoard;

  /// No description provided for @kanbanMultipleBlocksSnack.
  ///
  /// In es, this message translates to:
  /// **'Esta página tiene más de un bloque Kanban; se usa el primero.'**
  String get kanbanMultipleBlocksSnack;

  /// No description provided for @kanbanEmptyColumn.
  ///
  /// In es, this message translates to:
  /// **'Sin tareas'**
  String get kanbanEmptyColumn;

  /// No description provided for @blockTypeDriveLabel.
  ///
  /// In es, this message translates to:
  /// **'Archivo Drive'**
  String get blockTypeDriveLabel;

  /// No description provided for @blockTypeDriveHint.
  ///
  /// In es, this message translates to:
  /// **'Gestor de archivos integrado'**
  String get blockTypeDriveHint;

  /// No description provided for @driveBlockRowTitle.
  ///
  /// In es, this message translates to:
  /// **'Archivo Drive'**
  String get driveBlockRowTitle;

  /// No description provided for @driveBlockRowSubtitle.
  ///
  /// In es, this message translates to:
  /// **'{files} archivos · {folders} carpetas'**
  String driveBlockRowSubtitle(int files, int folders);

  /// No description provided for @driveNewFolder.
  ///
  /// In es, this message translates to:
  /// **'Nueva carpeta'**
  String get driveNewFolder;

  /// No description provided for @driveUploadFile.
  ///
  /// In es, this message translates to:
  /// **'Subir archivo'**
  String get driveUploadFile;

  /// No description provided for @driveImportFromVault.
  ///
  /// In es, this message translates to:
  /// **'Importar del vault'**
  String get driveImportFromVault;

  /// No description provided for @driveViewGrid.
  ///
  /// In es, this message translates to:
  /// **'Cuadrícula'**
  String get driveViewGrid;

  /// No description provided for @driveViewList.
  ///
  /// In es, this message translates to:
  /// **'Lista'**
  String get driveViewList;

  /// No description provided for @driveEditBlock.
  ///
  /// In es, this message translates to:
  /// **'Editar bloque'**
  String get driveEditBlock;

  /// No description provided for @driveFolderEmpty.
  ///
  /// In es, this message translates to:
  /// **'Esta carpeta está vacía'**
  String get driveFolderEmpty;

  /// No description provided for @driveDeleteConfirm.
  ///
  /// In es, this message translates to:
  /// **'¿Eliminar este archivo?'**
  String get driveDeleteConfirm;

  /// No description provided for @driveOpenFile.
  ///
  /// In es, this message translates to:
  /// **'Abrir archivo'**
  String get driveOpenFile;

  /// No description provided for @driveMoveTo.
  ///
  /// In es, this message translates to:
  /// **'Mover a…'**
  String get driveMoveTo;

  /// No description provided for @driveClassicModeBanner.
  ///
  /// In es, this message translates to:
  /// **'Editor de bloques: puedes mover o eliminar el bloque Drive.'**
  String get driveClassicModeBanner;

  /// No description provided for @driveBackToDrive.
  ///
  /// In es, this message translates to:
  /// **'Volver al drive'**
  String get driveBackToDrive;

  /// No description provided for @driveMultipleBlocksSnack.
  ///
  /// In es, this message translates to:
  /// **'Esta página tiene más de un bloque Drive; se usa el primero.'**
  String get driveMultipleBlocksSnack;

  /// No description provided for @driveDeleteOriginalsTitle.
  ///
  /// In es, this message translates to:
  /// **'Eliminar originales al importar'**
  String get driveDeleteOriginalsTitle;

  /// No description provided for @driveDeleteOriginalsSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Al subir archivos al drive, los originales se eliminan automáticamente del disco.'**
  String get driveDeleteOriginalsSubtitle;

  /// No description provided for @blockTypeEquationLabel.
  ///
  /// In es, this message translates to:
  /// **'Ecuación (LaTeX)'**
  String get blockTypeEquationLabel;

  /// No description provided for @blockTypeEquationHint.
  ///
  /// In es, this message translates to:
  /// **'Fórmulas matemáticas'**
  String get blockTypeEquationHint;

  /// No description provided for @blockTypeMermaidLabel.
  ///
  /// In es, this message translates to:
  /// **'Diagrama (Mermaid)'**
  String get blockTypeMermaidLabel;

  /// No description provided for @blockTypeMermaidHint.
  ///
  /// In es, this message translates to:
  /// **'Diagrama de flujo o esquema'**
  String get blockTypeMermaidHint;

  /// No description provided for @blockTypeTocLabel.
  ///
  /// In es, this message translates to:
  /// **'Tabla de contenidos'**
  String get blockTypeTocLabel;

  /// No description provided for @blockTypeTocHint.
  ///
  /// In es, this message translates to:
  /// **'Índice automático'**
  String get blockTypeTocHint;

  /// No description provided for @blockTypeBreadcrumbLabel.
  ///
  /// In es, this message translates to:
  /// **'Migas de pan'**
  String get blockTypeBreadcrumbLabel;

  /// No description provided for @blockTypeBreadcrumbHint.
  ///
  /// In es, this message translates to:
  /// **'Ruta de navegación'**
  String get blockTypeBreadcrumbHint;

  /// No description provided for @blockTypeTemplateButtonLabel.
  ///
  /// In es, this message translates to:
  /// **'Botón de plantilla'**
  String get blockTypeTemplateButtonLabel;

  /// No description provided for @blockTypeTemplateButtonHint.
  ///
  /// In es, this message translates to:
  /// **'Insertar bloque predefinido'**
  String get blockTypeTemplateButtonHint;

  /// No description provided for @blockTypeColumnListLabel.
  ///
  /// In es, this message translates to:
  /// **'Columnas'**
  String get blockTypeColumnListLabel;

  /// No description provided for @blockTypeColumnListHint.
  ///
  /// In es, this message translates to:
  /// **'Diseño en columnas'**
  String get blockTypeColumnListHint;

  /// No description provided for @blockTypeEmbedLabel.
  ///
  /// In es, this message translates to:
  /// **'Incrustado web'**
  String get blockTypeEmbedLabel;

  /// No description provided for @blockTypeEmbedHint.
  ///
  /// In es, this message translates to:
  /// **'YouTube, Figma, Docs…'**
  String get blockTypeEmbedHint;

  /// No description provided for @integrationDialogTitleUpdatePermission.
  ///
  /// In es, this message translates to:
  /// **'Actualizar permiso de integración'**
  String get integrationDialogTitleUpdatePermission;

  /// No description provided for @integrationDialogTitleAllowConnect.
  ///
  /// In es, this message translates to:
  /// **'Permitir que esta app se conecte'**
  String get integrationDialogTitleAllowConnect;

  /// No description provided for @integrationDialogBodyUpdate.
  ///
  /// In es, this message translates to:
  /// **'Esta app ya estaba aprobada con la integración {previousVersion} y ahora pide acceso con la versión {integrationVersion}.'**
  String integrationDialogBodyUpdate(
    Object previousVersion,
    Object integrationVersion,
  );

  /// No description provided for @integrationDialogBodyNew.
  ///
  /// In es, this message translates to:
  /// **'«{appName}» quiere usar el puente local de Folio con la app versión {appVersion} y la integración {integrationVersion}.'**
  String integrationDialogBodyNew(
    Object appName,
    Object appVersion,
    Object integrationVersion,
  );

  /// No description provided for @integrationChipLocalhostOnly.
  ///
  /// In es, this message translates to:
  /// **'Solo localhost'**
  String get integrationChipLocalhostOnly;

  /// No description provided for @integrationChipRevocableApproval.
  ///
  /// In es, this message translates to:
  /// **'Aprobación revocable'**
  String get integrationChipRevocableApproval;

  /// No description provided for @integrationChipNoSharedSecret.
  ///
  /// In es, this message translates to:
  /// **'Sin secreto compartido'**
  String get integrationChipNoSharedSecret;

  /// No description provided for @integrationChipScopedByAppId.
  ///
  /// In es, this message translates to:
  /// **'Permiso por appId'**
  String get integrationChipScopedByAppId;

  /// No description provided for @integrationMetaPreviouslyApprovedVersion.
  ///
  /// In es, this message translates to:
  /// **'Versión anterior aprobada'**
  String get integrationMetaPreviouslyApprovedVersion;

  /// No description provided for @integrationSectionWhatAppCanDo.
  ///
  /// In es, this message translates to:
  /// **'Lo que esta app podrá hacer'**
  String get integrationSectionWhatAppCanDo;

  /// No description provided for @integrationCapEphemeralSessionsTitle.
  ///
  /// In es, this message translates to:
  /// **'Abrir sesiones locales efímeras'**
  String get integrationCapEphemeralSessionsTitle;

  /// No description provided for @integrationCapEphemeralSessionsBody.
  ///
  /// In es, this message translates to:
  /// **'Podrá iniciar una sesión temporal para hablar con el puente local de Folio desde este dispositivo.'**
  String get integrationCapEphemeralSessionsBody;

  /// No description provided for @integrationCapImportPagesTitle.
  ///
  /// In es, this message translates to:
  /// **'Importar y actualizar sus propias páginas'**
  String get integrationCapImportPagesTitle;

  /// No description provided for @integrationCapImportPagesBody.
  ///
  /// In es, this message translates to:
  /// **'Podrá crear páginas, listarlas y actualizar solo las páginas que esa misma app haya importado antes.'**
  String get integrationCapImportPagesBody;

  /// No description provided for @integrationCapCustomEmojisTitle.
  ///
  /// In es, this message translates to:
  /// **'Gestionar sus emojis personalizados'**
  String get integrationCapCustomEmojisTitle;

  /// No description provided for @integrationCapCustomEmojisBody.
  ///
  /// In es, this message translates to:
  /// **'Podrá listar, crear, reemplazar y borrar solo su propio catálogo de emojis o iconos importados.'**
  String get integrationCapCustomEmojisBody;

  /// No description provided for @integrationCapUnlockedVaultTitle.
  ///
  /// In es, this message translates to:
  /// **'Trabajar solo con la libreta abierta'**
  String get integrationCapUnlockedVaultTitle;

  /// No description provided for @integrationCapUnlockedVaultBody.
  ///
  /// In es, this message translates to:
  /// **'Las peticiones solo funcionan cuando Folio está abierto, la libreta está disponible y la sesión actual sigue activa.'**
  String get integrationCapUnlockedVaultBody;

  /// No description provided for @integrationSectionWhatStaysBlocked.
  ///
  /// In es, this message translates to:
  /// **'Lo que seguirá bloqueado'**
  String get integrationSectionWhatStaysBlocked;

  /// No description provided for @integrationBlockNoSeeAllTitle.
  ///
  /// In es, this message translates to:
  /// **'No puede ver todo tu contenido'**
  String get integrationBlockNoSeeAllTitle;

  /// No description provided for @integrationBlockNoSeeAllBody.
  ///
  /// In es, this message translates to:
  /// **'No obtiene acceso general a la libreta. Solo puede listar lo que ella misma importó mediante su appId.'**
  String get integrationBlockNoSeeAllBody;

  /// No description provided for @integrationBlockNoBypassTitle.
  ///
  /// In es, this message translates to:
  /// **'No puede saltarse bloqueo ni cifrado'**
  String get integrationBlockNoBypassTitle;

  /// No description provided for @integrationBlockNoBypassBody.
  ///
  /// In es, this message translates to:
  /// **'Si la libreta está bloqueada o no hay sesión activa, Folio rechazará la operación.'**
  String get integrationBlockNoBypassBody;

  /// No description provided for @integrationBlockNoOtherAppsTitle.
  ///
  /// In es, this message translates to:
  /// **'No puede tocar datos de otras apps'**
  String get integrationBlockNoOtherAppsTitle;

  /// No description provided for @integrationBlockNoOtherAppsBody.
  ///
  /// In es, this message translates to:
  /// **'Tampoco puede gestionar páginas importadas o emojis registrados por otras apps aprobadas.'**
  String get integrationBlockNoOtherAppsBody;

  /// No description provided for @integrationBlockNoRemoteTitle.
  ///
  /// In es, this message translates to:
  /// **'No puede entrar desde fuera de tu equipo'**
  String get integrationBlockNoRemoteTitle;

  /// No description provided for @integrationBlockNoRemoteBody.
  ///
  /// In es, this message translates to:
  /// **'El puente sigue limitado a localhost y esta aprobación se puede revocar más tarde desde Ajustes.'**
  String get integrationBlockNoRemoteBody;

  /// No description provided for @integrationSnackMarkdownImportDone.
  ///
  /// In es, this message translates to:
  /// **'Importación completada: {pageTitle}.'**
  String integrationSnackMarkdownImportDone(Object pageTitle);

  /// No description provided for @integrationSnackJsonImportDone.
  ///
  /// In es, this message translates to:
  /// **'Importación JSON completada: {pageTitle}.'**
  String integrationSnackJsonImportDone(Object pageTitle);

  /// No description provided for @integrationSnackPageUpdateDone.
  ///
  /// In es, this message translates to:
  /// **'Actualización de integración completada: {pageTitle}.'**
  String integrationSnackPageUpdateDone(Object pageTitle);

  /// No description provided for @markdownImportModeDialogTitle.
  ///
  /// In es, this message translates to:
  /// **'Importar Markdown'**
  String get markdownImportModeDialogTitle;

  /// No description provided for @markdownImportModeDialogBody.
  ///
  /// In es, this message translates to:
  /// **'Elige cómo quieres aplicar el archivo Markdown.'**
  String get markdownImportModeDialogBody;

  /// No description provided for @markdownImportModeNewPage.
  ///
  /// In es, this message translates to:
  /// **'Página nueva'**
  String get markdownImportModeNewPage;

  /// No description provided for @markdownImportModeAppend.
  ///
  /// In es, this message translates to:
  /// **'Anexar a la actual'**
  String get markdownImportModeAppend;

  /// No description provided for @markdownImportModeReplace.
  ///
  /// In es, this message translates to:
  /// **'Reemplazar actual'**
  String get markdownImportModeReplace;

  /// No description provided for @markdownImportCouldNotReadPath.
  ///
  /// In es, this message translates to:
  /// **'No se pudo leer la ruta del archivo.'**
  String get markdownImportCouldNotReadPath;

  /// No description provided for @markdownImportedBlocks.
  ///
  /// In es, this message translates to:
  /// **'Markdown importado: {pageTitle} ({blockCount} bloques).'**
  String markdownImportedBlocks(Object pageTitle, int blockCount);

  /// No description provided for @markdownImportFailedWithError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo importar el Markdown: {error}'**
  String markdownImportFailedWithError(Object error);

  /// No description provided for @importPage.
  ///
  /// In es, this message translates to:
  /// **'Importar…'**
  String get importPage;

  /// No description provided for @exportMarkdownFileDialogTitle.
  ///
  /// In es, this message translates to:
  /// **'Exportar página a Markdown'**
  String get exportMarkdownFileDialogTitle;

  /// No description provided for @markdownExportSuccess.
  ///
  /// In es, this message translates to:
  /// **'Página exportada a Markdown.'**
  String get markdownExportSuccess;

  /// No description provided for @markdownExportFailedWithError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo exportar la página: {error}'**
  String markdownExportFailedWithError(Object error);

  /// No description provided for @exportPageDialogTitle.
  ///
  /// In es, this message translates to:
  /// **'Exportar página'**
  String get exportPageDialogTitle;

  /// No description provided for @exportPageFormatMarkdown.
  ///
  /// In es, this message translates to:
  /// **'Markdown (.md)'**
  String get exportPageFormatMarkdown;

  /// No description provided for @exportPageFormatHtml.
  ///
  /// In es, this message translates to:
  /// **'HTML (.html)'**
  String get exportPageFormatHtml;

  /// No description provided for @exportPageFormatTxt.
  ///
  /// In es, this message translates to:
  /// **'Texto (.txt)'**
  String get exportPageFormatTxt;

  /// No description provided for @exportPageFormatJson.
  ///
  /// In es, this message translates to:
  /// **'JSON (.json)'**
  String get exportPageFormatJson;

  /// No description provided for @exportPageFormatPdf.
  ///
  /// In es, this message translates to:
  /// **'PDF (.pdf)'**
  String get exportPageFormatPdf;

  /// No description provided for @exportHtmlFileDialogTitle.
  ///
  /// In es, this message translates to:
  /// **'Exportar página a HTML'**
  String get exportHtmlFileDialogTitle;

  /// No description provided for @htmlExportSuccess.
  ///
  /// In es, this message translates to:
  /// **'Página exportada a HTML.'**
  String get htmlExportSuccess;

  /// No description provided for @htmlExportFailedWithError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo exportar la página: {error}'**
  String htmlExportFailedWithError(Object error);

  /// No description provided for @exportTxtFileDialogTitle.
  ///
  /// In es, this message translates to:
  /// **'Exportar página a texto'**
  String get exportTxtFileDialogTitle;

  /// No description provided for @txtExportSuccess.
  ///
  /// In es, this message translates to:
  /// **'Página exportada a texto.'**
  String get txtExportSuccess;

  /// No description provided for @txtExportFailedWithError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo exportar la página: {error}'**
  String txtExportFailedWithError(Object error);

  /// No description provided for @exportJsonFileDialogTitle.
  ///
  /// In es, this message translates to:
  /// **'Exportar página a JSON'**
  String get exportJsonFileDialogTitle;

  /// No description provided for @jsonExportSuccess.
  ///
  /// In es, this message translates to:
  /// **'Página exportada a JSON.'**
  String get jsonExportSuccess;

  /// No description provided for @jsonExportFailedWithError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo exportar la página: {error}'**
  String jsonExportFailedWithError(Object error);

  /// No description provided for @exportPdfFileDialogTitle.
  ///
  /// In es, this message translates to:
  /// **'Exportar página a PDF'**
  String get exportPdfFileDialogTitle;

  /// No description provided for @pdfExportSuccess.
  ///
  /// In es, this message translates to:
  /// **'Página exportada a PDF.'**
  String get pdfExportSuccess;

  /// No description provided for @pdfExportFailedWithError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo exportar la página: {error}'**
  String pdfExportFailedWithError(Object error);

  /// No description provided for @firebaseUnavailablePublish.
  ///
  /// In es, this message translates to:
  /// **'Firebase no está disponible.'**
  String get firebaseUnavailablePublish;

  /// No description provided for @signInCloudToPublishWeb.
  ///
  /// In es, this message translates to:
  /// **'Inicia sesión en la cuenta en la nube (Ajustes) para publicar.'**
  String get signInCloudToPublishWeb;

  /// No description provided for @planMissingWebPublish.
  ///
  /// In es, this message translates to:
  /// **'Tu plan no incluye publicación web o la suscripción no está activa.'**
  String get planMissingWebPublish;

  /// No description provided for @publishWebDialogTitle.
  ///
  /// In es, this message translates to:
  /// **'Publicar en la web'**
  String get publishWebDialogTitle;

  /// No description provided for @publishWebSlugLabel.
  ///
  /// In es, this message translates to:
  /// **'URL (slug)'**
  String get publishWebSlugLabel;

  /// No description provided for @publishWebSlugHint.
  ///
  /// In es, this message translates to:
  /// **'mi-nota'**
  String get publishWebSlugHint;

  /// No description provided for @publishWebSlugHelper.
  ///
  /// In es, this message translates to:
  /// **'Letras, números y guiones. Quedará en la URL pública.'**
  String get publishWebSlugHelper;

  /// No description provided for @publishWebAction.
  ///
  /// In es, this message translates to:
  /// **'Publicar'**
  String get publishWebAction;

  /// No description provided for @publishWebEmptySlug.
  ///
  /// In es, this message translates to:
  /// **'Slug vacío.'**
  String get publishWebEmptySlug;

  /// No description provided for @publishWebSuccessWithUrl.
  ///
  /// In es, this message translates to:
  /// **'Publicado: {url}'**
  String publishWebSuccessWithUrl(Object url);

  /// No description provided for @publishWebFailedWithError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo publicar: {error}'**
  String publishWebFailedWithError(Object error);

  /// No description provided for @publishWebMenuLabel.
  ///
  /// In es, this message translates to:
  /// **'Publicar en la web'**
  String get publishWebMenuLabel;

  /// No description provided for @mobileFabDone.
  ///
  /// In es, this message translates to:
  /// **'Listo'**
  String get mobileFabDone;

  /// No description provided for @mobileFabEdit.
  ///
  /// In es, this message translates to:
  /// **'Editar'**
  String get mobileFabEdit;

  /// No description provided for @mobileFabAddBlock.
  ///
  /// In es, this message translates to:
  /// **'Bloque'**
  String get mobileFabAddBlock;

  /// No description provided for @mermaidPreviewDialogTitle.
  ///
  /// In es, this message translates to:
  /// **'Diagrama'**
  String get mermaidPreviewDialogTitle;

  /// No description provided for @mermaidDiagramSemanticsLabel.
  ///
  /// In es, this message translates to:
  /// **'Diagrama Mermaid, toca para ampliar'**
  String get mermaidDiagramSemanticsLabel;

  /// No description provided for @databaseSortAz.
  ///
  /// In es, this message translates to:
  /// **'Orden A-Z'**
  String get databaseSortAz;

  /// No description provided for @databaseSortLabel.
  ///
  /// In es, this message translates to:
  /// **'Ordenar'**
  String get databaseSortLabel;

  /// No description provided for @databaseFilterAnd.
  ///
  /// In es, this message translates to:
  /// **'Y'**
  String get databaseFilterAnd;

  /// No description provided for @databaseFilterOr.
  ///
  /// In es, this message translates to:
  /// **'O'**
  String get databaseFilterOr;

  /// No description provided for @databaseSortDescending.
  ///
  /// In es, this message translates to:
  /// **'Desc'**
  String get databaseSortDescending;

  /// No description provided for @databaseNewPropertyDialogTitle.
  ///
  /// In es, this message translates to:
  /// **'Nueva propiedad'**
  String get databaseNewPropertyDialogTitle;

  /// No description provided for @databaseConfigurePropertyTitle.
  ///
  /// In es, this message translates to:
  /// **'Configurar: {name}'**
  String databaseConfigurePropertyTitle(Object name);

  /// No description provided for @databaseLocalCurrentBadge.
  ///
  /// In es, this message translates to:
  /// **'DB local actual'**
  String get databaseLocalCurrentBadge;

  /// No description provided for @databaseRelateRowsTitle.
  ///
  /// In es, this message translates to:
  /// **'Relacionar filas ({name})'**
  String databaseRelateRowsTitle(Object name);

  /// No description provided for @databaseBoardNeedsGroupProperty.
  ///
  /// In es, this message translates to:
  /// **'Configura una propiedad de grupo para tablero.'**
  String get databaseBoardNeedsGroupProperty;

  /// No description provided for @databaseGroupPropertyMissing.
  ///
  /// In es, this message translates to:
  /// **'La propiedad de grupo ya no existe.'**
  String get databaseGroupPropertyMissing;

  /// No description provided for @databaseCalendarNeedsDateProperty.
  ///
  /// In es, this message translates to:
  /// **'Configura una propiedad de fecha para calendario.'**
  String get databaseCalendarNeedsDateProperty;

  /// No description provided for @databaseNoDatedEvents.
  ///
  /// In es, this message translates to:
  /// **'Sin eventos con fecha.'**
  String get databaseNoDatedEvents;

  /// No description provided for @databaseConfigurePropertyTooltip.
  ///
  /// In es, this message translates to:
  /// **'Configurar propiedad'**
  String get databaseConfigurePropertyTooltip;

  /// No description provided for @databaseFormulaHintExample.
  ///
  /// In es, this message translates to:
  /// **'if(contains(Nombre,\"x\"), add(1,2), 0)'**
  String get databaseFormulaHintExample;

  /// No description provided for @createAction.
  ///
  /// In es, this message translates to:
  /// **'Crear'**
  String get createAction;

  /// No description provided for @confirmAction.
  ///
  /// In es, this message translates to:
  /// **'Confirmar'**
  String get confirmAction;

  /// No description provided for @confirmRemoteEndpointTitle.
  ///
  /// In es, this message translates to:
  /// **'Confirmar endpoint remoto'**
  String get confirmRemoteEndpointTitle;

  /// No description provided for @shortcutGlobalSearchKeyChord.
  ///
  /// In es, this message translates to:
  /// **'Ctrl + Shift + F'**
  String get shortcutGlobalSearchKeyChord;

  /// No description provided for @updateChannelRelease.
  ///
  /// In es, this message translates to:
  /// **'Release'**
  String get updateChannelRelease;

  /// No description provided for @updateChannelBeta.
  ///
  /// In es, this message translates to:
  /// **'Beta'**
  String get updateChannelBeta;

  /// No description provided for @blockActionChooseAudio.
  ///
  /// In es, this message translates to:
  /// **'Elegir audio…'**
  String get blockActionChooseAudio;

  /// No description provided for @blockActionCreateSubpage.
  ///
  /// In es, this message translates to:
  /// **'Crear subpágina'**
  String get blockActionCreateSubpage;

  /// No description provided for @blockActionLinkPage.
  ///
  /// In es, this message translates to:
  /// **'Enlazar página…'**
  String get blockActionLinkPage;

  /// No description provided for @defaultNewPageTitle.
  ///
  /// In es, this message translates to:
  /// **'Nueva página'**
  String get defaultNewPageTitle;

  /// No description provided for @defaultPageDuplicateTitle.
  ///
  /// In es, this message translates to:
  /// **'{title} (copia)'**
  String defaultPageDuplicateTitle(Object title);

  /// No description provided for @aiChatTitleNumbered.
  ///
  /// In es, this message translates to:
  /// **'Chat {n}'**
  String aiChatTitleNumbered(int n);

  /// No description provided for @invalidFolioTemplateFile.
  ///
  /// In es, this message translates to:
  /// **'El archivo no es un template Folio válido.'**
  String get invalidFolioTemplateFile;

  /// No description provided for @templateButtonDefaultLabel.
  ///
  /// In es, this message translates to:
  /// **'Plantilla'**
  String get templateButtonDefaultLabel;

  /// No description provided for @pageHtmlExportPublishedWithFolio.
  ///
  /// In es, this message translates to:
  /// **'Publicado con Folio'**
  String get pageHtmlExportPublishedWithFolio;

  /// No description provided for @releaseReadinessSemverOk.
  ///
  /// In es, this message translates to:
  /// **'Versión SemVer válida'**
  String get releaseReadinessSemverOk;

  /// No description provided for @releaseReadinessEncryptedVault.
  ///
  /// In es, this message translates to:
  /// **'Libreta cifrada'**
  String get releaseReadinessEncryptedVault;

  /// No description provided for @releaseReadinessAiRemotePolicy.
  ///
  /// In es, this message translates to:
  /// **'Política endpoint IA'**
  String get releaseReadinessAiRemotePolicy;

  /// No description provided for @releaseReadinessVaultUnlocked.
  ///
  /// In es, this message translates to:
  /// **'Libreta desbloqueada'**
  String get releaseReadinessVaultUnlocked;

  /// No description provided for @releaseReadinessStableChannel.
  ///
  /// In es, this message translates to:
  /// **'Canal estable seleccionado'**
  String get releaseReadinessStableChannel;

  /// No description provided for @aiPromptUserMessage.
  ///
  /// In es, this message translates to:
  /// **'Mensaje del usuario:'**
  String get aiPromptUserMessage;

  /// No description provided for @aiPromptOriginalMessage.
  ///
  /// In es, this message translates to:
  /// **'Mensaje original:'**
  String get aiPromptOriginalMessage;

  /// No description provided for @aiPromptOriginalUserMessage.
  ///
  /// In es, this message translates to:
  /// **'Mensaje original del usuario:'**
  String get aiPromptOriginalUserMessage;

  /// No description provided for @customIconImportEmptySource.
  ///
  /// In es, this message translates to:
  /// **'La fuente del icono está vacía.'**
  String get customIconImportEmptySource;

  /// No description provided for @customIconImportInvalidUrl.
  ///
  /// In es, this message translates to:
  /// **'La URL del icono no es válida.'**
  String get customIconImportInvalidUrl;

  /// No description provided for @customIconImportInvalidSvg.
  ///
  /// In es, this message translates to:
  /// **'El SVG copiado no es válido.'**
  String get customIconImportInvalidSvg;

  /// No description provided for @customIconImportHttpHttpsOnly.
  ///
  /// In es, this message translates to:
  /// **'Solo se admiten URLs http o https.'**
  String get customIconImportHttpHttpsOnly;

  /// No description provided for @customIconImportDataUriMimeList.
  ///
  /// In es, this message translates to:
  /// **'Solo se admiten data:image/svg+xml, data:image/gif, data:image/webp o data:image/png.'**
  String get customIconImportDataUriMimeList;

  /// No description provided for @customIconImportUnsupportedFormat.
  ///
  /// In es, this message translates to:
  /// **'Formato no compatible. Usa SVG, PNG, GIF o WebP.'**
  String get customIconImportUnsupportedFormat;

  /// No description provided for @customIconImportSvgTooLarge.
  ///
  /// In es, this message translates to:
  /// **'El SVG es demasiado grande para importarlo.'**
  String get customIconImportSvgTooLarge;

  /// No description provided for @customIconImportEmbeddedImageTooLarge.
  ///
  /// In es, this message translates to:
  /// **'La imagen embebida es demasiado grande para importarla.'**
  String get customIconImportEmbeddedImageTooLarge;

  /// No description provided for @customIconImportDownloadFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo descargar el icono ({code}).'**
  String customIconImportDownloadFailed(Object code);

  /// No description provided for @customIconImportRemoteTooLarge.
  ///
  /// In es, this message translates to:
  /// **'El icono remoto es demasiado grande.'**
  String get customIconImportRemoteTooLarge;

  /// No description provided for @customIconImportConnectFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo conectar para descargar el icono.'**
  String get customIconImportConnectFailed;

  /// No description provided for @customIconImportCertFailed.
  ///
  /// In es, this message translates to:
  /// **'Fallo de certificado al descargar el icono.'**
  String get customIconImportCertFailed;

  /// No description provided for @customIconLabelDefault.
  ///
  /// In es, this message translates to:
  /// **'Icono personalizado'**
  String get customIconLabelDefault;

  /// No description provided for @customIconLabelImported.
  ///
  /// In es, this message translates to:
  /// **'Icono importado'**
  String get customIconLabelImported;

  /// No description provided for @customIconImportSucceeded.
  ///
  /// In es, this message translates to:
  /// **'Icono importado correctamente.'**
  String get customIconImportSucceeded;

  /// No description provided for @customIconClipboardEmpty.
  ///
  /// In es, this message translates to:
  /// **'El portapapeles está vacío.'**
  String get customIconClipboardEmpty;

  /// No description provided for @customIconRemoved.
  ///
  /// In es, this message translates to:
  /// **'Icono eliminado.'**
  String get customIconRemoved;

  /// No description provided for @whisperModelTiny.
  ///
  /// In es, this message translates to:
  /// **'Tiny (rápido)'**
  String get whisperModelTiny;

  /// No description provided for @whisperModelBaseQ8.
  ///
  /// In es, this message translates to:
  /// **'Base q8 (equilibrado)'**
  String get whisperModelBaseQ8;

  /// No description provided for @whisperModelSmallQ8.
  ///
  /// In es, this message translates to:
  /// **'Small q8 (alta precisión, menos disco)'**
  String get whisperModelSmallQ8;

  /// No description provided for @whisperModelMediumQ8.
  ///
  /// In es, this message translates to:
  /// **'Medium q8'**
  String get whisperModelMediumQ8;

  /// No description provided for @whisperModelLargeV3TurboQ8.
  ///
  /// In es, this message translates to:
  /// **'Large v3 Turbo q8'**
  String get whisperModelLargeV3TurboQ8;

  /// No description provided for @codeLangDart.
  ///
  /// In es, this message translates to:
  /// **'Dart'**
  String get codeLangDart;

  /// No description provided for @codeLangTypeScript.
  ///
  /// In es, this message translates to:
  /// **'TypeScript'**
  String get codeLangTypeScript;

  /// No description provided for @codeLangJavaScript.
  ///
  /// In es, this message translates to:
  /// **'JavaScript'**
  String get codeLangJavaScript;

  /// No description provided for @codeLangPython.
  ///
  /// In es, this message translates to:
  /// **'Python'**
  String get codeLangPython;

  /// No description provided for @codeLangJson.
  ///
  /// In es, this message translates to:
  /// **'JSON'**
  String get codeLangJson;

  /// No description provided for @codeLangYaml.
  ///
  /// In es, this message translates to:
  /// **'YAML'**
  String get codeLangYaml;

  /// No description provided for @codeLangMarkdown.
  ///
  /// In es, this message translates to:
  /// **'Markdown'**
  String get codeLangMarkdown;

  /// No description provided for @codeLangDiff.
  ///
  /// In es, this message translates to:
  /// **'Diff'**
  String get codeLangDiff;

  /// No description provided for @codeLangSql.
  ///
  /// In es, this message translates to:
  /// **'SQL'**
  String get codeLangSql;

  /// No description provided for @codeLangBash.
  ///
  /// In es, this message translates to:
  /// **'Bash'**
  String get codeLangBash;

  /// No description provided for @codeLangCpp.
  ///
  /// In es, this message translates to:
  /// **'C / C++'**
  String get codeLangCpp;

  /// No description provided for @codeLangJava.
  ///
  /// In es, this message translates to:
  /// **'Java'**
  String get codeLangJava;

  /// No description provided for @codeLangKotlin.
  ///
  /// In es, this message translates to:
  /// **'Kotlin'**
  String get codeLangKotlin;

  /// No description provided for @codeLangRust.
  ///
  /// In es, this message translates to:
  /// **'Rust'**
  String get codeLangRust;

  /// No description provided for @codeLangGo.
  ///
  /// In es, this message translates to:
  /// **'Go'**
  String get codeLangGo;

  /// No description provided for @codeLangHtmlXml.
  ///
  /// In es, this message translates to:
  /// **'HTML / XML'**
  String get codeLangHtmlXml;

  /// No description provided for @codeLangCss.
  ///
  /// In es, this message translates to:
  /// **'CSS'**
  String get codeLangCss;

  /// No description provided for @codeLangPlainText.
  ///
  /// In es, this message translates to:
  /// **'Texto plano'**
  String get codeLangPlainText;

  /// No description provided for @settingsAppRevoked.
  ///
  /// In es, this message translates to:
  /// **'App revocada: {appId}'**
  String settingsAppRevoked(Object appId);

  /// No description provided for @settingsDeviceRevokedSnack.
  ///
  /// In es, this message translates to:
  /// **'Dispositivo revocado.'**
  String get settingsDeviceRevokedSnack;

  /// No description provided for @settingsAiConnectionOk.
  ///
  /// In es, this message translates to:
  /// **'Conexión IA OK'**
  String get settingsAiConnectionOk;

  /// No description provided for @settingsAiConnectionError.
  ///
  /// In es, this message translates to:
  /// **'Error de conexión: {error}'**
  String settingsAiConnectionError(Object error);

  /// No description provided for @settingsAiListModelsFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudieron listar modelos: {error}'**
  String settingsAiListModelsFailed(Object error);

  /// No description provided for @folioCloudCallableNotSignedIn.
  ///
  /// In es, this message translates to:
  /// **'Debes iniciar sesión para llamar a Cloud Functions'**
  String get folioCloudCallableNotSignedIn;

  /// No description provided for @folioCloudCallableUnexpectedResponse.
  ///
  /// In es, this message translates to:
  /// **'Respuesta inesperada de Cloud Functions'**
  String get folioCloudCallableUnexpectedResponse;

  /// No description provided for @folioCloudCallableHttpError.
  ///
  /// In es, this message translates to:
  /// **'HTTP {code} al llamar a {name}'**
  String folioCloudCallableHttpError(int code, Object name);

  /// No description provided for @folioCloudCallableNoIdToken.
  ///
  /// In es, this message translates to:
  /// **'Sin token de ID para Cloud Functions. Vuelve a iniciar sesión en Folio Cloud.'**
  String get folioCloudCallableNoIdToken;

  /// No description provided for @folioCloudCallableUnexpectedFallback.
  ///
  /// In es, this message translates to:
  /// **'Respuesta inesperada del respaldo de Cloud Functions'**
  String get folioCloudCallableUnexpectedFallback;

  /// No description provided for @folioCloudCallableHttpAiComplete.
  ///
  /// In es, this message translates to:
  /// **'HTTP {code} al llamar a folioCloudAiCompleteHttp'**
  String folioCloudCallableHttpAiComplete(int code);

  /// No description provided for @cloudAccountEmailMismatch.
  ///
  /// In es, this message translates to:
  /// **'El correo no coincide con la sesión actual.'**
  String get cloudAccountEmailMismatch;

  /// No description provided for @cloudIdentityInvalidAuthResponse.
  ///
  /// In es, this message translates to:
  /// **'Respuesta de autenticación no válida.'**
  String get cloudIdentityInvalidAuthResponse;

  /// No description provided for @templateButtonPlaceholderText.
  ///
  /// In es, this message translates to:
  /// **'Texto de la plantilla…'**
  String get templateButtonPlaceholderText;

  /// No description provided for @aiProviderOllamaName.
  ///
  /// In es, this message translates to:
  /// **'Ollama'**
  String get aiProviderOllamaName;

  /// No description provided for @aiProviderLmStudioName.
  ///
  /// In es, this message translates to:
  /// **'LM Studio'**
  String get aiProviderLmStudioName;

  /// No description provided for @blockAudioEmptyHint.
  ///
  /// In es, this message translates to:
  /// **'Elige un archivo de audio'**
  String get blockAudioEmptyHint;

  /// No description provided for @blockChildPageTitle.
  ///
  /// In es, this message translates to:
  /// **'Bloque página'**
  String get blockChildPageTitle;

  /// No description provided for @blockChildPageNoLink.
  ///
  /// In es, this message translates to:
  /// **'Sin subpágina enlazada.'**
  String get blockChildPageNoLink;

  /// No description provided for @mermaidExpandedLoadError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo mostrar el diagrama ampliado.'**
  String get mermaidExpandedLoadError;

  /// No description provided for @mermaidPreviewTooltip.
  ///
  /// In es, this message translates to:
  /// **'Toca para ampliar y hacer zoom. PNG vía mermaid.ink (servicio externo).'**
  String get mermaidPreviewTooltip;

  /// No description provided for @aiEndpointInvalidUrl.
  ///
  /// In es, this message translates to:
  /// **'URL inválida. Usa http://host:puerto.'**
  String get aiEndpointInvalidUrl;

  /// No description provided for @aiEndpointRemoteNotAllowed.
  ///
  /// In es, this message translates to:
  /// **'Endpoint remoto no permitido sin confirmación.'**
  String get aiEndpointRemoteNotAllowed;

  /// No description provided for @settingsAiSelectProviderFirst.
  ///
  /// In es, this message translates to:
  /// **'Selecciona un proveedor IA primero.'**
  String get settingsAiSelectProviderFirst;

  /// No description provided for @releaseReadinessAiSummaryDisabled.
  ///
  /// In es, this message translates to:
  /// **'IA desactivada'**
  String get releaseReadinessAiSummaryDisabled;

  /// No description provided for @releaseReadinessAiSummaryQuillCloud.
  ///
  /// In es, this message translates to:
  /// **'Folio Cloud IA (sin endpoint local)'**
  String get releaseReadinessAiSummaryQuillCloud;

  /// No description provided for @releaseReadinessAiSummaryEndpointOk.
  ///
  /// In es, this message translates to:
  /// **'Endpoint válido: {url}'**
  String releaseReadinessAiSummaryEndpointOk(Object url);

  /// No description provided for @releaseReadinessDetailSemverInvalid.
  ///
  /// In es, this message translates to:
  /// **'La versión instalada no cumple SemVer.'**
  String get releaseReadinessDetailSemverInvalid;

  /// No description provided for @releaseReadinessDetailVaultNotEncrypted.
  ///
  /// In es, this message translates to:
  /// **'La libreta actual no está cifrada.'**
  String get releaseReadinessDetailVaultNotEncrypted;

  /// No description provided for @releaseReadinessDetailVaultLocked.
  ///
  /// In es, this message translates to:
  /// **'Desbloquea la libreta para validar export/import y flujo real.'**
  String get releaseReadinessDetailVaultLocked;

  /// No description provided for @releaseReadinessDetailBetaChannel.
  ///
  /// In es, this message translates to:
  /// **'El canal beta está activo para actualizaciones.'**
  String get releaseReadinessDetailBetaChannel;

  /// No description provided for @releaseReadinessReportTitle.
  ///
  /// In es, this message translates to:
  /// **'Folio: preparación para release'**
  String get releaseReadinessReportTitle;

  /// No description provided for @releaseReadinessReportInstalledVersion.
  ///
  /// In es, this message translates to:
  /// **'Versión instalada: {label}'**
  String releaseReadinessReportInstalledVersion(Object label);

  /// No description provided for @releaseReadinessReportSemver.
  ///
  /// In es, this message translates to:
  /// **'SemVer válido: {value}'**
  String releaseReadinessReportSemver(Object value);

  /// No description provided for @releaseReadinessReportChannel.
  ///
  /// In es, this message translates to:
  /// **'Canal de actualizaciones: {value}'**
  String releaseReadinessReportChannel(Object value);

  /// No description provided for @releaseReadinessReportActiveVault.
  ///
  /// In es, this message translates to:
  /// **'Libreta activa: {id}'**
  String releaseReadinessReportActiveVault(Object id);

  /// No description provided for @releaseReadinessReportVaultPath.
  ///
  /// In es, this message translates to:
  /// **'Ruta libreta: {path}'**
  String releaseReadinessReportVaultPath(Object path);

  /// No description provided for @releaseReadinessReportUnlocked.
  ///
  /// In es, this message translates to:
  /// **'Libreta desbloqueada: {value}'**
  String releaseReadinessReportUnlocked(Object value);

  /// No description provided for @releaseReadinessReportEncrypted.
  ///
  /// In es, this message translates to:
  /// **'Libreta cifrada: {value}'**
  String releaseReadinessReportEncrypted(Object value);

  /// No description provided for @releaseReadinessReportAiEnabled.
  ///
  /// In es, this message translates to:
  /// **'IA habilitada: {value}'**
  String releaseReadinessReportAiEnabled(Object value);

  /// No description provided for @releaseReadinessReportAiPolicy.
  ///
  /// In es, this message translates to:
  /// **'Política endpoint IA: {value}'**
  String releaseReadinessReportAiPolicy(Object value);

  /// No description provided for @releaseReadinessReportAiDetail.
  ///
  /// In es, this message translates to:
  /// **'Detalle IA: {detail}'**
  String releaseReadinessReportAiDetail(Object detail);

  /// No description provided for @releaseReadinessReportStatus.
  ///
  /// In es, this message translates to:
  /// **'Estado release: {value}'**
  String releaseReadinessReportStatus(Object value);

  /// No description provided for @releaseReadinessReportBlockers.
  ///
  /// In es, this message translates to:
  /// **'Bloqueadores pendientes: {count}'**
  String releaseReadinessReportBlockers(int count);

  /// No description provided for @releaseReadinessReportWarnings.
  ///
  /// In es, this message translates to:
  /// **'Advertencias pendientes: {count}'**
  String releaseReadinessReportWarnings(int count);

  /// No description provided for @releaseReadinessExportWordYes.
  ///
  /// In es, this message translates to:
  /// **'sí'**
  String get releaseReadinessExportWordYes;

  /// No description provided for @releaseReadinessExportWordNo.
  ///
  /// In es, this message translates to:
  /// **'no'**
  String get releaseReadinessExportWordNo;

  /// No description provided for @releaseReadinessChannelStable.
  ///
  /// In es, this message translates to:
  /// **'estable'**
  String get releaseReadinessChannelStable;

  /// No description provided for @releaseReadinessChannelBeta.
  ///
  /// In es, this message translates to:
  /// **'beta'**
  String get releaseReadinessChannelBeta;

  /// No description provided for @releaseReadinessStatusReady.
  ///
  /// In es, this message translates to:
  /// **'listo'**
  String get releaseReadinessStatusReady;

  /// No description provided for @releaseReadinessStatusBlocked.
  ///
  /// In es, this message translates to:
  /// **'bloqueado'**
  String get releaseReadinessStatusBlocked;

  /// No description provided for @releaseReadinessPolicyOk.
  ///
  /// In es, this message translates to:
  /// **'correcto'**
  String get releaseReadinessPolicyOk;

  /// No description provided for @releaseReadinessPolicyError.
  ///
  /// In es, this message translates to:
  /// **'error'**
  String get releaseReadinessPolicyError;

  /// No description provided for @settingsSignInFolioCloudSnack.
  ///
  /// In es, this message translates to:
  /// **'Inicia sesión en Folio Cloud.'**
  String get settingsSignInFolioCloudSnack;

  /// No description provided for @settingsNotSyncedYet.
  ///
  /// In es, this message translates to:
  /// **'Aún sin sincronizar'**
  String get settingsNotSyncedYet;

  /// No description provided for @settingsDeviceNameTitle.
  ///
  /// In es, this message translates to:
  /// **'Nombre del dispositivo'**
  String get settingsDeviceNameTitle;

  /// No description provided for @settingsDeviceNameHintExample.
  ///
  /// In es, this message translates to:
  /// **'Ejemplo: Pixel de Alejandra'**
  String get settingsDeviceNameHintExample;

  /// No description provided for @settingsPairingModeEnabledTwoMin.
  ///
  /// In es, this message translates to:
  /// **'Modo vinculación activado durante 2 minutos.'**
  String get settingsPairingModeEnabledTwoMin;

  /// No description provided for @settingsPairingEnableModeFirst.
  ///
  /// In es, this message translates to:
  /// **'Primero activa el modo vinculación y luego elige un dispositivo detectado.'**
  String get settingsPairingEnableModeFirst;

  /// No description provided for @settingsPairingSameEmojisBothDevices.
  ///
  /// In es, this message translates to:
  /// **'Activa el modo vinculación en ambos dispositivos y espera a que aparezcan los mismos 3 emojis.'**
  String get settingsPairingSameEmojisBothDevices;

  /// No description provided for @settingsPairingCouldNotStart.
  ///
  /// In es, this message translates to:
  /// **'No se pudo iniciar la vinculación. Activa el modo vinculación en ambos dispositivos y espera a ver los mismos 3 emojis.'**
  String get settingsPairingCouldNotStart;

  /// No description provided for @settingsConfirmPairingTitle.
  ///
  /// In es, this message translates to:
  /// **'Confirmar vinculación'**
  String get settingsConfirmPairingTitle;

  /// No description provided for @settingsPairingCheckOtherDeviceEmojis.
  ///
  /// In es, this message translates to:
  /// **'Comprueba que en el otro dispositivo aparecen estos mismos 3 emojis:'**
  String get settingsPairingCheckOtherDeviceEmojis;

  /// No description provided for @settingsPairingPopupInstructions.
  ///
  /// In es, this message translates to:
  /// **'Este popup también aparecerá en el otro dispositivo. Para completar el enlace, pulsa Vincular aquí y luego Vincular en el otro.'**
  String get settingsPairingPopupInstructions;

  /// No description provided for @settingsLinkDevice.
  ///
  /// In es, this message translates to:
  /// **'Vincular'**
  String get settingsLinkDevice;

  /// No description provided for @settingsPairingConfirmationSent.
  ///
  /// In es, this message translates to:
  /// **'Confirmación enviada. Falta que el otro dispositivo pulse Vincular en su popup.'**
  String get settingsPairingConfirmationSent;

  /// No description provided for @settingsResolveConflictsTitle.
  ///
  /// In es, this message translates to:
  /// **'Resolver conflictos'**
  String get settingsResolveConflictsTitle;

  /// No description provided for @settingsNoPendingConflicts.
  ///
  /// In es, this message translates to:
  /// **'No hay conflictos pendientes.'**
  String get settingsNoPendingConflicts;

  /// No description provided for @settingsSyncConflictCardSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Origen: {fromPeerId}\nPáginas remotas: {remotePageCount}\nDetectado: {detectedAt}'**
  String settingsSyncConflictCardSubtitle(
    Object fromPeerId,
    int remotePageCount,
    Object detectedAt,
  );

  /// No description provided for @settingsSyncConflictHeading.
  ///
  /// In es, this message translates to:
  /// **'Conflicto de sincronización'**
  String get settingsSyncConflictHeading;

  /// No description provided for @settingsLocalVersionKeptSnack.
  ///
  /// In es, this message translates to:
  /// **'Se conservó la versión local.'**
  String get settingsLocalVersionKeptSnack;

  /// No description provided for @settingsKeepLocal.
  ///
  /// In es, this message translates to:
  /// **'Mantener local'**
  String get settingsKeepLocal;

  /// No description provided for @settingsRemoteVersionAppliedSnack.
  ///
  /// In es, this message translates to:
  /// **'Se aplicó la versión remota.'**
  String get settingsRemoteVersionAppliedSnack;

  /// No description provided for @settingsCouldNotApplyRemoteSnack.
  ///
  /// In es, this message translates to:
  /// **'No se pudo aplicar la versión remota.'**
  String get settingsCouldNotApplyRemoteSnack;

  /// No description provided for @settingsAcceptRemote.
  ///
  /// In es, this message translates to:
  /// **'Aceptar remota'**
  String get settingsAcceptRemote;

  /// No description provided for @settingsClose.
  ///
  /// In es, this message translates to:
  /// **'Cerrar'**
  String get settingsClose;

  /// No description provided for @settingsSectionDeviceSyncNav.
  ///
  /// In es, this message translates to:
  /// **'Sincronización'**
  String get settingsSectionDeviceSyncNav;

  /// No description provided for @settingsSectionVault.
  ///
  /// In es, this message translates to:
  /// **'Libreta'**
  String get settingsSectionVault;

  /// No description provided for @settingsSectionVaultHeroDescription.
  ///
  /// In es, this message translates to:
  /// **'Seguridad al desbloquear, copias, programación a disco y gestión de datos en este dispositivo.'**
  String get settingsSectionVaultHeroDescription;

  /// No description provided for @settingsSectionUiWorkspace.
  ///
  /// In es, this message translates to:
  /// **'Interfaz y escritorio'**
  String get settingsSectionUiWorkspace;

  /// No description provided for @settingsSectionUiWorkspaceHeroDescription.
  ///
  /// In es, this message translates to:
  /// **'Tema, idioma, escala, editor, opciones de escritorio y atajos de teclado.'**
  String get settingsSectionUiWorkspaceHeroDescription;

  /// No description provided for @settingsSubsectionVaultBackupImport.
  ///
  /// In es, this message translates to:
  /// **'Copias e importación'**
  String get settingsSubsectionVaultBackupImport;

  /// No description provided for @settingsSubsectionVaultScheduledLocal.
  ///
  /// In es, this message translates to:
  /// **'Copia programada (local)'**
  String get settingsSubsectionVaultScheduledLocal;

  /// No description provided for @settingsSubsectionDrive.
  ///
  /// In es, this message translates to:
  /// **'Drive'**
  String get settingsSubsectionDrive;

  /// No description provided for @settingsSubsectionVaultData.
  ///
  /// In es, this message translates to:
  /// **'Datos (zona peligrosa)'**
  String get settingsSubsectionVaultData;

  /// No description provided for @folioCloudSubsectionAccount.
  ///
  /// In es, this message translates to:
  /// **'Cuenta'**
  String get folioCloudSubsectionAccount;

  /// No description provided for @folioCloudSubsectionEncryptedBackups.
  ///
  /// In es, this message translates to:
  /// **'Copias y almacenamiento (nube)'**
  String get folioCloudSubsectionEncryptedBackups;

  /// No description provided for @folioCloudBackupStorageSectionIntro.
  ///
  /// In es, this message translates to:
  /// **'El uso incluye la copia incremental (cloud-pack) y los archivos completos antiguos en la carpeta backups/. Puedes suscribirte a una librería pequeña, mediana o grande (cuota extra mensual mientras la suscripción esté activa).'**
  String get folioCloudBackupStorageSectionIntro;

  /// No description provided for @folioCloudBackupStoragePurchasedExtra.
  ///
  /// In es, this message translates to:
  /// **'Ampliaciones compradas: +{size}'**
  String folioCloudBackupStoragePurchasedExtra(Object size);

  /// No description provided for @folioCloudBackupStorageBarTitle.
  ///
  /// In es, this message translates to:
  /// **'Uso de almacenamiento'**
  String get folioCloudBackupStorageBarTitle;

  /// No description provided for @folioCloudBackupStorageBarPercent.
  ///
  /// In es, this message translates to:
  /// **'{percent} %'**
  String folioCloudBackupStorageBarPercent(int percent);

  /// No description provided for @folioCloudBackupStorageBarDetail.
  ///
  /// In es, this message translates to:
  /// **'Usado: {used} · Cuota total: {total} · Libre: {free}'**
  String folioCloudBackupStorageBarDetail(
    Object used,
    Object total,
    Object free,
  );

  /// No description provided for @folioCloudSubsectionPublishing.
  ///
  /// In es, this message translates to:
  /// **'Publicación web'**
  String get folioCloudSubsectionPublishing;

  /// No description provided for @settingsFolioCloudSubsectionScheduledCloud.
  ///
  /// In es, this message translates to:
  /// **'Copia programada a Folio Cloud'**
  String get settingsFolioCloudSubsectionScheduledCloud;

  /// No description provided for @settingsScheduledCloudUploadRequiresSchedule.
  ///
  /// In es, this message translates to:
  /// **'Activa antes la copia programada en Libreta › Copia programada (local).'**
  String get settingsScheduledCloudUploadRequiresSchedule;

  /// No description provided for @settingsSyncHeroTitle.
  ///
  /// In es, this message translates to:
  /// **'Sincronización entre dispositivos'**
  String get settingsSyncHeroTitle;

  /// No description provided for @settingsSyncHeroDescription.
  ///
  /// In es, this message translates to:
  /// **'Empareja equipos en la red local; el relay solo ayuda a negociar la conexión, no envía el contenido del vault.'**
  String get settingsSyncHeroDescription;

  /// No description provided for @settingsSyncChipPairingCode.
  ///
  /// In es, this message translates to:
  /// **'Código de enlace'**
  String get settingsSyncChipPairingCode;

  /// No description provided for @settingsSyncChipAutoDiscovery.
  ///
  /// In es, this message translates to:
  /// **'Detección automática'**
  String get settingsSyncChipAutoDiscovery;

  /// No description provided for @settingsSyncChipOptionalRelay.
  ///
  /// In es, this message translates to:
  /// **'Relay opcional'**
  String get settingsSyncChipOptionalRelay;

  /// No description provided for @settingsSyncEnableTitle.
  ///
  /// In es, this message translates to:
  /// **'Activar sincronización entre dispositivos'**
  String get settingsSyncEnableTitle;

  /// No description provided for @settingsSyncSearchingSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Buscando dispositivos con Folio abierto en la red local...'**
  String get settingsSyncSearchingSubtitle;

  /// No description provided for @settingsSyncDevicesFoundOnLan.
  ///
  /// In es, this message translates to:
  /// **'{count} dispositivos detectados en LAN.'**
  String settingsSyncDevicesFoundOnLan(int count);

  /// No description provided for @settingsSyncDisabledSubtitle.
  ///
  /// In es, this message translates to:
  /// **'La sincronización está desactivada.'**
  String get settingsSyncDisabledSubtitle;

  /// No description provided for @settingsSyncRelayTitle.
  ///
  /// In es, this message translates to:
  /// **'Usar relay de señalización'**
  String get settingsSyncRelayTitle;

  /// No description provided for @settingsSyncRelaySubtitle.
  ///
  /// In es, this message translates to:
  /// **'No envía contenido del vault, solo ayuda a negociar la conexión si la LAN falla.'**
  String get settingsSyncRelaySubtitle;

  /// No description provided for @settingsEdit.
  ///
  /// In es, this message translates to:
  /// **'Editar'**
  String get settingsEdit;

  /// No description provided for @settingsSyncEmojiModeTitle.
  ///
  /// In es, this message translates to:
  /// **'Activar modo vinculación por emojis'**
  String get settingsSyncEmojiModeTitle;

  /// No description provided for @settingsSyncEmojiModeSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Actívalo en ambos dispositivos para iniciar el proceso de vinculación sin escribir códigos.'**
  String get settingsSyncEmojiModeSubtitle;

  /// No description provided for @settingsSyncPairingStatusTitle.
  ///
  /// In es, this message translates to:
  /// **'Estado del modo vinculación'**
  String get settingsSyncPairingStatusTitle;

  /// No description provided for @settingsSyncPairingActiveSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Activo durante 2 minutos. Ya puedes iniciar la vinculación desde un dispositivo detectado.'**
  String get settingsSyncPairingActiveSubtitle;

  /// No description provided for @settingsSyncPairingInactiveSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Inactivo. Actívalo aquí y en el otro dispositivo para empezar a vincular.'**
  String get settingsSyncPairingInactiveSubtitle;

  /// No description provided for @settingsSyncLastSyncTitle.
  ///
  /// In es, this message translates to:
  /// **'Última sincronización'**
  String get settingsSyncLastSyncTitle;

  /// No description provided for @settingsSyncPendingConflictsTitle.
  ///
  /// In es, this message translates to:
  /// **'Conflictos pendientes'**
  String get settingsSyncPendingConflictsTitle;

  /// No description provided for @settingsSyncNoConflictsSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Sin conflictos pendientes.'**
  String get settingsSyncNoConflictsSubtitle;

  /// No description provided for @settingsSyncConflictsNeedReview.
  ///
  /// In es, this message translates to:
  /// **'{count} conflictos requieren revisión manual.'**
  String settingsSyncConflictsNeedReview(int count);

  /// No description provided for @settingsResolve.
  ///
  /// In es, this message translates to:
  /// **'Resolver'**
  String get settingsResolve;

  /// No description provided for @settingsSyncDiscoveredDevicesTitle.
  ///
  /// In es, this message translates to:
  /// **'Dispositivos detectados'**
  String get settingsSyncDiscoveredDevicesTitle;

  /// No description provided for @settingsSyncNoDevicesYetHint.
  ///
  /// In es, this message translates to:
  /// **'No se detectaron dispositivos todavía. Asegura que ambas apps estén abiertas en la misma red.'**
  String get settingsSyncNoDevicesYetHint;

  /// No description provided for @settingsSyncPeerReadyToLink.
  ///
  /// In es, this message translates to:
  /// **'Listo para vincular.'**
  String get settingsSyncPeerReadyToLink;

  /// No description provided for @settingsSyncPeerOtherInPairingMode.
  ///
  /// In es, this message translates to:
  /// **'El otro dispositivo está en modo vinculación. Actívalo aquí para iniciar el enlace.'**
  String get settingsSyncPeerOtherInPairingMode;

  /// No description provided for @settingsSyncPeerDetectedLan.
  ///
  /// In es, this message translates to:
  /// **'Detectado en la red local.'**
  String get settingsSyncPeerDetectedLan;

  /// No description provided for @settingsSyncLinkedDevicesTitle.
  ///
  /// In es, this message translates to:
  /// **'Dispositivos vinculados'**
  String get settingsSyncLinkedDevicesTitle;

  /// No description provided for @settingsSyncNoLinkedDevicesYet.
  ///
  /// In es, this message translates to:
  /// **'Aún no hay dispositivos enlazados.'**
  String get settingsSyncNoLinkedDevicesYet;

  /// No description provided for @settingsSyncPeerIdLabel.
  ///
  /// In es, this message translates to:
  /// **'ID: {peerId}'**
  String settingsSyncPeerIdLabel(Object peerId);

  /// No description provided for @settingsRevoke.
  ///
  /// In es, this message translates to:
  /// **'Revocar'**
  String get settingsRevoke;

  /// No description provided for @sidebarPageIconTitle.
  ///
  /// In es, this message translates to:
  /// **'Icono de la página'**
  String get sidebarPageIconTitle;

  /// No description provided for @sidebarPageIconPickerHelper.
  ///
  /// In es, this message translates to:
  /// **'Elige un icono rápido, uno importado o abre el selector completo.'**
  String get sidebarPageIconPickerHelper;

  /// No description provided for @sidebarPageIconCustomEmoji.
  ///
  /// In es, this message translates to:
  /// **'Emoji personalizado'**
  String get sidebarPageIconCustomEmoji;

  /// No description provided for @sidebarPageIconRemove.
  ///
  /// In es, this message translates to:
  /// **'Quitar'**
  String get sidebarPageIconRemove;

  /// No description provided for @sidebarPageIconTabQuick.
  ///
  /// In es, this message translates to:
  /// **'Rápidos'**
  String get sidebarPageIconTabQuick;

  /// No description provided for @sidebarPageIconTabImported.
  ///
  /// In es, this message translates to:
  /// **'Importados'**
  String get sidebarPageIconTabImported;

  /// No description provided for @sidebarPageIconTabAll.
  ///
  /// In es, this message translates to:
  /// **'Todos'**
  String get sidebarPageIconTabAll;

  /// No description provided for @sidebarPageIconEmptyImported.
  ///
  /// In es, this message translates to:
  /// **'Todavía no has importado iconos en Ajustes.'**
  String get sidebarPageIconEmptyImported;

  /// No description provided for @sidebarDeletePageMenuTitle.
  ///
  /// In es, this message translates to:
  /// **'Eliminar página'**
  String get sidebarDeletePageMenuTitle;

  /// No description provided for @sidebarDeleteFolderMenuTitle.
  ///
  /// In es, this message translates to:
  /// **'Quitar carpeta'**
  String get sidebarDeleteFolderMenuTitle;

  /// No description provided for @sidebarDeletePageConfirmInline.
  ///
  /// In es, this message translates to:
  /// **'¿Eliminar «{title}»? No se puede deshacer.'**
  String sidebarDeletePageConfirmInline(Object title);

  /// No description provided for @sidebarDeleteFolderConfirmInline.
  ///
  /// In es, this message translates to:
  /// **'¿Quitar carpeta «{title}»? Las subpáginas pasan a la raíz de la libreta.'**
  String sidebarDeleteFolderConfirmInline(Object title);

  /// No description provided for @settingsStripeSubscriptionRefreshed.
  ///
  /// In es, this message translates to:
  /// **'Facturación Folio Cloud actualizada.'**
  String get settingsStripeSubscriptionRefreshed;

  /// No description provided for @settingsStripeBillingPortalUnavailable.
  ///
  /// In es, this message translates to:
  /// **'Portal de facturación no disponible.'**
  String get settingsStripeBillingPortalUnavailable;

  /// No description provided for @settingsCouldNotOpenLink.
  ///
  /// In es, this message translates to:
  /// **'No se pudo abrir el enlace.'**
  String get settingsCouldNotOpenLink;

  /// No description provided for @settingsStripeCheckoutUnavailable.
  ///
  /// In es, this message translates to:
  /// **'Pago no disponible (configura Stripe en el servidor).'**
  String get settingsStripeCheckoutUnavailable;

  /// No description provided for @settingsCloudBackupEnablePlanSnack.
  ///
  /// In es, this message translates to:
  /// **'Activa Folio Cloud con la función de copia en la nube incluida en tu plan.'**
  String get settingsCloudBackupEnablePlanSnack;

  /// No description provided for @settingsNoActiveVault.
  ///
  /// In es, this message translates to:
  /// **'No hay libreta activa.'**
  String get settingsNoActiveVault;

  /// No description provided for @settingsCloudBackupsNeedPlan.
  ///
  /// In es, this message translates to:
  /// **'Necesitas Folio Cloud activo con copia en la nube.'**
  String get settingsCloudBackupsNeedPlan;

  /// No description provided for @settingsCloudBackupsDialogTitle.
  ///
  /// In es, this message translates to:
  /// **'Copias en la nube ({count}/10)'**
  String settingsCloudBackupsDialogTitle(int count);

  /// No description provided for @settingsCloudBackupsVaultLabel.
  ///
  /// In es, this message translates to:
  /// **'Libreta'**
  String get settingsCloudBackupsVaultLabel;

  /// No description provided for @settingsCloudBackupsEmpty.
  ///
  /// In es, this message translates to:
  /// **'Aún no hay copias en esta cuenta.'**
  String get settingsCloudBackupsEmpty;

  /// No description provided for @settingsCloudBackupDownloadTooltip.
  ///
  /// In es, this message translates to:
  /// **'Descargar'**
  String get settingsCloudBackupDownloadTooltip;

  /// No description provided for @settingsCloudBackupActionDownload.
  ///
  /// In es, this message translates to:
  /// **'Descargar'**
  String get settingsCloudBackupActionDownload;

  /// No description provided for @settingsCloudBackupActionImportOverwrite.
  ///
  /// In es, this message translates to:
  /// **'Importar (machacar)'**
  String get settingsCloudBackupActionImportOverwrite;

  /// No description provided for @settingsCloudBackupSaveDialogTitle.
  ///
  /// In es, this message translates to:
  /// **'Guardar copia'**
  String get settingsCloudBackupSaveDialogTitle;

  /// No description provided for @settingsCloudBackupDownloadedSnack.
  ///
  /// In es, this message translates to:
  /// **'Copia descargada.'**
  String get settingsCloudBackupDownloadedSnack;

  /// No description provided for @settingsCloudBackupDeletedSnack.
  ///
  /// In es, this message translates to:
  /// **'Copia borrada.'**
  String get settingsCloudBackupDeletedSnack;

  /// No description provided for @settingsCloudBackupImportedSnack.
  ///
  /// In es, this message translates to:
  /// **'Importación completada.'**
  String get settingsCloudBackupImportedSnack;

  /// No description provided for @settingsCloudBackupVaultMustBeUnlocked.
  ///
  /// In es, this message translates to:
  /// **'La libreta debe estar desbloqueada.'**
  String get settingsCloudBackupVaultMustBeUnlocked;

  /// No description provided for @settingsCloudBackupsTotalLabel.
  ///
  /// In es, this message translates to:
  /// **'Total: {size}'**
  String settingsCloudBackupsTotalLabel(Object size);

  /// No description provided for @settingsCloudBackupImportOverwriteTitle.
  ///
  /// In es, this message translates to:
  /// **'Importar (machacar)'**
  String get settingsCloudBackupImportOverwriteTitle;

  /// No description provided for @settingsCloudBackupImportOverwriteBody.
  ///
  /// In es, this message translates to:
  /// **'Esto reemplazará (machacará) el contenido de la libreta activa. Asegúrate de tener una copia local antes de continuar.'**
  String get settingsCloudBackupImportOverwriteBody;

  /// No description provided for @settingsCloudBackupDeleteWarning.
  ///
  /// In es, this message translates to:
  /// **'¿Seguro que quieres borrar esta copia de la nube? Esta acción no se puede deshacer.'**
  String get settingsCloudBackupDeleteWarning;

  /// No description provided for @settingsPublishedRequiresPlan.
  ///
  /// In es, this message translates to:
  /// **'Necesitas Folio Cloud con publicación web activa.'**
  String get settingsPublishedRequiresPlan;

  /// No description provided for @settingsPublishedPagesTitle.
  ///
  /// In es, this message translates to:
  /// **'Páginas publicadas'**
  String get settingsPublishedPagesTitle;

  /// No description provided for @settingsPublishedPagesEmpty.
  ///
  /// In es, this message translates to:
  /// **'Aún no hay páginas publicadas.'**
  String get settingsPublishedPagesEmpty;

  /// No description provided for @settingsPublishedDeleteDialogTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Eliminar publicación?'**
  String get settingsPublishedDeleteDialogTitle;

  /// No description provided for @settingsPublishedDeleteDialogBody.
  ///
  /// In es, this message translates to:
  /// **'Se borrará el HTML público y el enlace dejará de funcionar.'**
  String get settingsPublishedDeleteDialogBody;

  /// No description provided for @settingsPublishedRemovedSnack.
  ///
  /// In es, this message translates to:
  /// **'Publicación eliminada.'**
  String get settingsPublishedRemovedSnack;

  /// No description provided for @settingsCouldNotReadInstalledVersion.
  ///
  /// In es, this message translates to:
  /// **'No se pudo leer la versión instalada.'**
  String get settingsCouldNotReadInstalledVersion;

  /// No description provided for @settingsCouldNotOpenReleaseNotes.
  ///
  /// In es, this message translates to:
  /// **'No se pudieron abrir las notas de versión: {error}'**
  String settingsCouldNotOpenReleaseNotes(Object error);

  /// No description provided for @settingsUpdateFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo actualizar: {error}'**
  String settingsUpdateFailed(Object error);

  /// No description provided for @settingsSessionEndedSnack.
  ///
  /// In es, this message translates to:
  /// **'Sesión cerrada'**
  String get settingsSessionEndedSnack;

  /// No description provided for @settingsLabelYes.
  ///
  /// In es, this message translates to:
  /// **'Sí'**
  String get settingsLabelYes;

  /// No description provided for @settingsLabelNo.
  ///
  /// In es, this message translates to:
  /// **'No'**
  String get settingsLabelNo;

  /// No description provided for @settingsSecurityEncryptedHeroDescription.
  ///
  /// In es, this message translates to:
  /// **'Desbloqueo rápido, passkey, bloqueo automático y contraseña maestra del vault cifrado.'**
  String get settingsSecurityEncryptedHeroDescription;

  /// No description provided for @settingsUnencryptedVaultTitle.
  ///
  /// In es, this message translates to:
  /// **'Vault sin cifrar'**
  String get settingsUnencryptedVaultTitle;

  /// No description provided for @settingsUnencryptedVaultChipDataOnDisk.
  ///
  /// In es, this message translates to:
  /// **'Datos en disco'**
  String get settingsUnencryptedVaultChipDataOnDisk;

  /// No description provided for @settingsUnencryptedVaultChipEncryptionAvailable.
  ///
  /// In es, this message translates to:
  /// **'Cifrado disponible'**
  String get settingsUnencryptedVaultChipEncryptionAvailable;

  /// No description provided for @settingsAppearanceChipTheme.
  ///
  /// In es, this message translates to:
  /// **'Tema'**
  String get settingsAppearanceChipTheme;

  /// No description provided for @settingsAppearanceChipZoom.
  ///
  /// In es, this message translates to:
  /// **'Zoom'**
  String get settingsAppearanceChipZoom;

  /// No description provided for @settingsAppearanceChipLanguage.
  ///
  /// In es, this message translates to:
  /// **'Idioma'**
  String get settingsAppearanceChipLanguage;

  /// No description provided for @settingsAppearanceChipEditorWorkspace.
  ///
  /// In es, this message translates to:
  /// **'Editor y espacio'**
  String get settingsAppearanceChipEditorWorkspace;

  /// No description provided for @settingsWindowsScaleFollowTitle.
  ///
  /// In es, this message translates to:
  /// **'Seguir escala de Windows'**
  String get settingsWindowsScaleFollowTitle;

  /// No description provided for @settingsWindowsScaleFollowSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Usa automáticamente la escala del sistema en Windows.'**
  String get settingsWindowsScaleFollowSubtitle;

  /// No description provided for @settingsInterfaceZoomTitle.
  ///
  /// In es, this message translates to:
  /// **'Zoom de la interfaz'**
  String get settingsInterfaceZoomTitle;

  /// No description provided for @settingsInterfaceZoomSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Aumenta o reduce el tamaño general de la app.'**
  String get settingsInterfaceZoomSubtitle;

  /// No description provided for @settingsUiZoomReset.
  ///
  /// In es, this message translates to:
  /// **'Restablecer'**
  String get settingsUiZoomReset;

  /// No description provided for @settingsEditorSubsection.
  ///
  /// In es, this message translates to:
  /// **'Editor'**
  String get settingsEditorSubsection;

  /// No description provided for @settingsEditorContentWidthTitle.
  ///
  /// In es, this message translates to:
  /// **'Ancho del contenido'**
  String get settingsEditorContentWidthTitle;

  /// No description provided for @settingsEditorContentWidthSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Define cuánto ancho ocupan los bloques en el editor.'**
  String get settingsEditorContentWidthSubtitle;

  /// No description provided for @settingsEnterCreatesNewBlockTitle.
  ///
  /// In es, this message translates to:
  /// **'Enter crea un bloque nuevo'**
  String get settingsEnterCreatesNewBlockTitle;

  /// No description provided for @settingsEnterCreatesNewBlockSubtitleWhenEnabled.
  ///
  /// In es, this message translates to:
  /// **'Desactiva para que Enter inserte salto de línea.'**
  String get settingsEnterCreatesNewBlockSubtitleWhenEnabled;

  /// No description provided for @settingsEnterCreatesNewBlockSubtitleWhenDisabled.
  ///
  /// In es, this message translates to:
  /// **'Ahora Enter inserta salto de línea. Usa Shift+Enter igual.'**
  String get settingsEnterCreatesNewBlockSubtitleWhenDisabled;

  /// No description provided for @settingsWorkspaceSubsection.
  ///
  /// In es, this message translates to:
  /// **'Espacio de trabajo'**
  String get settingsWorkspaceSubsection;

  /// No description provided for @settingsCustomIconsTitle.
  ///
  /// In es, this message translates to:
  /// **'Iconos personalizados'**
  String get settingsCustomIconsTitle;

  /// No description provided for @settingsCustomIconsDescription.
  ///
  /// In es, this message translates to:
  /// **'Importa una URL PNG, GIF o WebP, o un data:image compatible copiado desde páginas como notionicons.so. Después podrás usarlo como icono de página o de callout.'**
  String get settingsCustomIconsDescription;

  /// No description provided for @settingsCustomIconsSavedCount.
  ///
  /// In es, this message translates to:
  /// **'{count} guardados'**
  String settingsCustomIconsSavedCount(int count);

  /// No description provided for @settingsCustomIconsChipUrl.
  ///
  /// In es, this message translates to:
  /// **'URL PNG, GIF o WebP'**
  String get settingsCustomIconsChipUrl;

  /// No description provided for @settingsCustomIconsChipDataImage.
  ///
  /// In es, this message translates to:
  /// **'data:image/*'**
  String get settingsCustomIconsChipDataImage;

  /// No description provided for @settingsCustomIconsChipPaste.
  ///
  /// In es, this message translates to:
  /// **'Pegar desde portapapeles'**
  String get settingsCustomIconsChipPaste;

  /// No description provided for @settingsCustomIconsImportTitle.
  ///
  /// In es, this message translates to:
  /// **'Importar nuevo icono'**
  String get settingsCustomIconsImportTitle;

  /// No description provided for @settingsCustomIconsImportSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Puedes ponerle nombre y pegar la fuente manualmente o traerla directamente desde el portapapeles.'**
  String get settingsCustomIconsImportSubtitle;

  /// No description provided for @settingsCustomIconsFieldNameLabel.
  ///
  /// In es, this message translates to:
  /// **'Nombre'**
  String get settingsCustomIconsFieldNameLabel;

  /// No description provided for @settingsCustomIconsFieldNameHint.
  ///
  /// In es, this message translates to:
  /// **'Opcional'**
  String get settingsCustomIconsFieldNameHint;

  /// No description provided for @settingsCustomIconsFieldSourceLabel.
  ///
  /// In es, this message translates to:
  /// **'URL o data:image'**
  String get settingsCustomIconsFieldSourceLabel;

  /// No description provided for @settingsCustomIconsFieldSourceHint.
  ///
  /// In es, this message translates to:
  /// **'https://…gif | …webp | …png o data:image/…'**
  String get settingsCustomIconsFieldSourceHint;

  /// No description provided for @settingsCustomIconsImportButton.
  ///
  /// In es, this message translates to:
  /// **'Importar icono'**
  String get settingsCustomIconsImportButton;

  /// No description provided for @settingsCustomIconsFromClipboard.
  ///
  /// In es, this message translates to:
  /// **'Desde portapapeles'**
  String get settingsCustomIconsFromClipboard;

  /// No description provided for @settingsCustomIconsLibraryTitle.
  ///
  /// In es, this message translates to:
  /// **'Biblioteca'**
  String get settingsCustomIconsLibraryTitle;

  /// No description provided for @settingsCustomIconsLibrarySubtitle.
  ///
  /// In es, this message translates to:
  /// **'Listos para usar en toda la app'**
  String get settingsCustomIconsLibrarySubtitle;

  /// No description provided for @settingsCustomIconsEmpty.
  ///
  /// In es, this message translates to:
  /// **'Todavía no has importado iconos.'**
  String get settingsCustomIconsEmpty;

  /// No description provided for @settingsCustomIconsDeleteTooltip.
  ///
  /// In es, this message translates to:
  /// **'Eliminar icono'**
  String get settingsCustomIconsDeleteTooltip;

  /// No description provided for @settingsCustomIconsReferenceCopiedSnack.
  ///
  /// In es, this message translates to:
  /// **'Referencia copiada.'**
  String get settingsCustomIconsReferenceCopiedSnack;

  /// No description provided for @settingsCustomIconsCopyToken.
  ///
  /// In es, this message translates to:
  /// **'Copiar token'**
  String get settingsCustomIconsCopyToken;

  /// No description provided for @settingsAiHeroQuillWithLocalAlt.
  ///
  /// In es, this message translates to:
  /// **'La IA se ejecuta en Quill Cloud (suscripción con IA en la nube o tinta comprada). Elige otro proveedor abajo para Ollama o LM Studio en local.'**
  String get settingsAiHeroQuillWithLocalAlt;

  /// No description provided for @settingsAiHeroQuillCloudOnly.
  ///
  /// In es, this message translates to:
  /// **'La IA se ejecuta en Quill Cloud (suscripción con IA en la nube o tinta comprada).'**
  String get settingsAiHeroQuillCloudOnly;

  /// No description provided for @settingsAiHeroLocalDefault.
  ///
  /// In es, this message translates to:
  /// **'Conecta Ollama o LM Studio en local; el asistente usa el modelo y el contexto que configures aquí.'**
  String get settingsAiHeroLocalDefault;

  /// No description provided for @settingsAiHeroQuillMobileOnly.
  ///
  /// In es, this message translates to:
  /// **'En este dispositivo Quill solo puede usar Quill Cloud. Elige Quill Cloud como proveedor cuando quieras activar la IA.'**
  String get settingsAiHeroQuillMobileOnly;

  /// No description provided for @settingsAiChipCloud.
  ///
  /// In es, this message translates to:
  /// **'En la nube'**
  String get settingsAiChipCloud;

  /// No description provided for @settingsAiSnackFirebaseUnavailableBuild.
  ///
  /// In es, this message translates to:
  /// **'Firebase no está disponible en esta compilación.'**
  String get settingsAiSnackFirebaseUnavailableBuild;

  /// No description provided for @settingsAiSnackSignInCloudAccount.
  ///
  /// In es, this message translates to:
  /// **'Inicia sesión en la cuenta en la nube (Ajustes).'**
  String get settingsAiSnackSignInCloudAccount;

  /// No description provided for @settingsAiProviderSwitchFailed.
  ///
  /// In es, this message translates to:
  /// **'Error al cambiar proveedor: {error}'**
  String settingsAiProviderSwitchFailed(Object error);

  /// No description provided for @settingsAboutHeroDescription.
  ///
  /// In es, this message translates to:
  /// **'Versión instalada, origen de actualizaciones y comprobación manual de novedades.'**
  String get settingsAboutHeroDescription;

  /// No description provided for @settingsOpenReleaseNotes.
  ///
  /// In es, this message translates to:
  /// **'Ver notas de versión'**
  String get settingsOpenReleaseNotes;

  /// No description provided for @settingsUpdateChannelLabel.
  ///
  /// In es, this message translates to:
  /// **'Canal'**
  String get settingsUpdateChannelLabel;

  /// No description provided for @settingsUpdateChannelRelease.
  ///
  /// In es, this message translates to:
  /// **'Release'**
  String get settingsUpdateChannelRelease;

  /// No description provided for @settingsUpdateChannelBeta.
  ///
  /// In es, this message translates to:
  /// **'Beta'**
  String get settingsUpdateChannelBeta;

  /// No description provided for @settingsDataHeroDescription.
  ///
  /// In es, this message translates to:
  /// **'Acciones permanentes sobre archivos locales. Haz una copia de seguridad antes de borrar.'**
  String get settingsDataHeroDescription;

  /// No description provided for @settingsDangerZoneTitle.
  ///
  /// In es, this message translates to:
  /// **'Zona de peligro'**
  String get settingsDangerZoneTitle;

  /// No description provided for @settingsDesktopHeroDescription.
  ///
  /// In es, this message translates to:
  /// **'Atajos globales, bandeja del sistema y comportamiento de la ventana en el escritorio.'**
  String get settingsDesktopHeroDescription;

  /// No description provided for @settingsShortcutsHeroDescription.
  ///
  /// In es, this message translates to:
  /// **'Combinaciones solo dentro de Folio. Prueba una tecla antes de guardarla.'**
  String get settingsShortcutsHeroDescription;

  /// No description provided for @settingsShortcutsTestChip.
  ///
  /// In es, this message translates to:
  /// **'Probar'**
  String get settingsShortcutsTestChip;

  /// No description provided for @settingsIntegrationsChipApprovedPermissions.
  ///
  /// In es, this message translates to:
  /// **'Permisos aprobados'**
  String get settingsIntegrationsChipApprovedPermissions;

  /// No description provided for @settingsIntegrationsChipRevocableAccess.
  ///
  /// In es, this message translates to:
  /// **'Acceso revocable'**
  String get settingsIntegrationsChipRevocableAccess;

  /// No description provided for @settingsIntegrationsChipExternalApps.
  ///
  /// In es, this message translates to:
  /// **'Apps externas'**
  String get settingsIntegrationsChipExternalApps;

  /// No description provided for @settingsIntegrationsActiveConnectionsTitle.
  ///
  /// In es, this message translates to:
  /// **'Conexiones activas'**
  String get settingsIntegrationsActiveConnectionsTitle;

  /// No description provided for @settingsIntegrationsActiveConnectionsSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Apps que ya pueden interactuar con Folio'**
  String get settingsIntegrationsActiveConnectionsSubtitle;

  /// No description provided for @settingsViewInkUsageTable.
  ///
  /// In es, this message translates to:
  /// **'Ver tabla de consumo'**
  String get settingsViewInkUsageTable;

  /// No description provided for @settingsCloudInkUsageTableTitle.
  ///
  /// In es, this message translates to:
  /// **'Tabla de consumo de gotas (Quill Cloud)'**
  String get settingsCloudInkUsageTableTitle;

  /// No description provided for @settingsCloudInkUsageTableIntro.
  ///
  /// In es, this message translates to:
  /// **'Coste base por acción. Se pueden aplicar suplementos por prompts largos y por tokens de salida.'**
  String get settingsCloudInkUsageTableIntro;

  /// No description provided for @settingsCloudInkDrops.
  ///
  /// In es, this message translates to:
  /// **'gotas'**
  String get settingsCloudInkDrops;

  /// No description provided for @settingsCloudInkTableCachedNotice.
  ///
  /// In es, this message translates to:
  /// **'Mostrando tabla en caché local (sin conexión al backend).'**
  String get settingsCloudInkTableCachedNotice;

  /// No description provided for @settingsCloudInkOpRewriteBlock.
  ///
  /// In es, this message translates to:
  /// **'Reescribir bloque'**
  String get settingsCloudInkOpRewriteBlock;

  /// No description provided for @settingsCloudInkOpSummarizeSelection.
  ///
  /// In es, this message translates to:
  /// **'Resumir selección'**
  String get settingsCloudInkOpSummarizeSelection;

  /// No description provided for @settingsCloudInkOpExtractTasks.
  ///
  /// In es, this message translates to:
  /// **'Extraer tareas'**
  String get settingsCloudInkOpExtractTasks;

  /// No description provided for @settingsCloudInkOpSummarizePage.
  ///
  /// In es, this message translates to:
  /// **'Resumir página'**
  String get settingsCloudInkOpSummarizePage;

  /// No description provided for @settingsCloudInkOpGenerateInsert.
  ///
  /// In es, this message translates to:
  /// **'Generar inserción'**
  String get settingsCloudInkOpGenerateInsert;

  /// No description provided for @settingsCloudInkOpGeneratePage.
  ///
  /// In es, this message translates to:
  /// **'Generar página'**
  String get settingsCloudInkOpGeneratePage;

  /// No description provided for @settingsCloudInkOpChatTurn.
  ///
  /// In es, this message translates to:
  /// **'Turno de chat'**
  String get settingsCloudInkOpChatTurn;

  /// No description provided for @settingsCloudInkOpAgentMain.
  ///
  /// In es, this message translates to:
  /// **'Ejecución de agente'**
  String get settingsCloudInkOpAgentMain;

  /// No description provided for @settingsCloudInkOpAgentFollowup.
  ///
  /// In es, this message translates to:
  /// **'Seguimiento de agente'**
  String get settingsCloudInkOpAgentFollowup;

  /// No description provided for @settingsCloudInkOpEditPagePanel.
  ///
  /// In es, this message translates to:
  /// **'Edición de página (panel)'**
  String get settingsCloudInkOpEditPagePanel;

  /// No description provided for @settingsCloudInkOpDefault.
  ///
  /// In es, this message translates to:
  /// **'Operación por defecto'**
  String get settingsCloudInkOpDefault;

  /// No description provided for @settingsDesktopRailSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Elige una categoría en la lista o desplázate por el contenido.'**
  String get settingsDesktopRailSubtitle;

  /// No description provided for @settingsCloudInkViewTableButton.
  ///
  /// In es, this message translates to:
  /// **'Ver tabla'**
  String get settingsCloudInkViewTableButton;

  /// No description provided for @settingsCloudInkHostedAiQuillCloudHint.
  ///
  /// In es, this message translates to:
  /// **'Precios de referencia para IA en nube en Quill Cloud.'**
  String get settingsCloudInkHostedAiQuillCloudHint;

  /// No description provided for @vaultStarterHomeTitle.
  ///
  /// In es, this message translates to:
  /// **'Empieza aquí'**
  String get vaultStarterHomeTitle;

  /// No description provided for @vaultStarterHomeHeading.
  ///
  /// In es, this message translates to:
  /// **'Tu libreta ya está lista'**
  String get vaultStarterHomeHeading;

  /// No description provided for @vaultStarterHomeIntro.
  ///
  /// In es, this message translates to:
  /// **'Folio organiza tus páginas en un árbol, edita contenido por bloques y mantiene los datos en este dispositivo. Esta mini guía te deja un mapa rápido de lo que puedes hacer desde el primer minuto.'**
  String get vaultStarterHomeIntro;

  /// No description provided for @vaultStarterHomeCallout.
  ///
  /// In es, this message translates to:
  /// **'Puedes borrar, renombrar o mover estas páginas cuando quieras. Son solo una base para arrancar más rápido.'**
  String get vaultStarterHomeCallout;

  /// No description provided for @vaultStarterHomeSectionTips.
  ///
  /// In es, this message translates to:
  /// **'Lo más útil para empezar'**
  String get vaultStarterHomeSectionTips;

  /// No description provided for @vaultStarterHomeBulletSlash.
  ///
  /// In es, this message translates to:
  /// **'Pulsa / dentro de un párrafo para insertar encabezados, listas, tablas, bloques de código, Mermaid y más.'**
  String get vaultStarterHomeBulletSlash;

  /// No description provided for @vaultStarterHomeBulletSidebar.
  ///
  /// In es, this message translates to:
  /// **'Usa el panel lateral para crear páginas y subpáginas, y reorganiza el árbol según tu forma de trabajar.'**
  String get vaultStarterHomeBulletSidebar;

  /// No description provided for @vaultStarterHomeBulletSettings.
  ///
  /// In es, this message translates to:
  /// **'Abre Ajustes para activar IA, configurar copia de seguridad, cambiar idioma o añadir desbloqueo rápido.'**
  String get vaultStarterHomeBulletSettings;

  /// No description provided for @vaultStarterHomeTodo1.
  ///
  /// In es, this message translates to:
  /// **'Crear mi primera página de trabajo'**
  String get vaultStarterHomeTodo1;

  /// No description provided for @vaultStarterHomeTodo2.
  ///
  /// In es, this message translates to:
  /// **'Probar el menú / para insertar un bloque nuevo'**
  String get vaultStarterHomeTodo2;

  /// No description provided for @vaultStarterHomeTodo3.
  ///
  /// In es, this message translates to:
  /// **'Revisar Ajustes y decidir si quiero activar Quill o un método de desbloqueo rápido'**
  String get vaultStarterHomeTodo3;

  /// No description provided for @vaultStarterCapabilitiesTitle.
  ///
  /// In es, this message translates to:
  /// **'Qué puede hacer Folio'**
  String get vaultStarterCapabilitiesTitle;

  /// No description provided for @vaultStarterCapabilitiesSectionMain.
  ///
  /// In es, this message translates to:
  /// **'Capacidades principales'**
  String get vaultStarterCapabilitiesSectionMain;

  /// No description provided for @vaultStarterCapabilitiesBullet1.
  ///
  /// In es, this message translates to:
  /// **'Tomar notas con estructura libre usando párrafos, títulos, listas, checklists, citas y divisores.'**
  String get vaultStarterCapabilitiesBullet1;

  /// No description provided for @vaultStarterCapabilitiesBullet2.
  ///
  /// In es, this message translates to:
  /// **'Trabajar con bloques especiales como tablas, bases de datos, archivos, audio, vídeo, embeds y diagramas Mermaid.'**
  String get vaultStarterCapabilitiesBullet2;

  /// No description provided for @vaultStarterCapabilitiesBullet3.
  ///
  /// In es, this message translates to:
  /// **'Buscar contenido, revisar historial de página y mantener revisiones dentro de la misma libreta.'**
  String get vaultStarterCapabilitiesBullet3;

  /// No description provided for @vaultStarterCapabilitiesBullet4.
  ///
  /// In es, this message translates to:
  /// **'Exportar o importar datos, incluyendo copia de la libreta e importación desde Notion.'**
  String get vaultStarterCapabilitiesBullet4;

  /// No description provided for @vaultStarterCapabilitiesSectionShortcuts.
  ///
  /// In es, this message translates to:
  /// **'Atajos rápidos'**
  String get vaultStarterCapabilitiesSectionShortcuts;

  /// No description provided for @vaultStarterCapabilitiesShortcutN.
  ///
  /// In es, this message translates to:
  /// **'Ctrl+N crea una página nueva.'**
  String get vaultStarterCapabilitiesShortcutN;

  /// No description provided for @vaultStarterCapabilitiesShortcutSearch.
  ///
  /// In es, this message translates to:
  /// **'Ctrl+K o Ctrl+F abre la búsqueda.'**
  String get vaultStarterCapabilitiesShortcutSearch;

  /// No description provided for @vaultStarterCapabilitiesShortcutSettings.
  ///
  /// In es, this message translates to:
  /// **'Ctrl+, abre Ajustes y Ctrl+L bloquea la libreta.'**
  String get vaultStarterCapabilitiesShortcutSettings;

  /// No description provided for @vaultStarterCapabilitiesAiCallout.
  ///
  /// In es, this message translates to:
  /// **'La IA no se activa por defecto. Si decides usar Quill, la configuras en Ajustes y eliges proveedor, modelo y permisos de contexto.'**
  String get vaultStarterCapabilitiesAiCallout;

  /// No description provided for @vaultStarterQuillTitle.
  ///
  /// In es, this message translates to:
  /// **'Quill y privacidad'**
  String get vaultStarterQuillTitle;

  /// No description provided for @vaultStarterQuillSectionWhat.
  ///
  /// In es, this message translates to:
  /// **'Qué puede hacer Quill'**
  String get vaultStarterQuillSectionWhat;

  /// No description provided for @vaultStarterQuillBullet1.
  ///
  /// In es, this message translates to:
  /// **'Resumir, reescribir o expandir el contenido de una página.'**
  String get vaultStarterQuillBullet1;

  /// No description provided for @vaultStarterQuillBullet2.
  ///
  /// In es, this message translates to:
  /// **'Responder dudas sobre bloques, atajos y formas de organizar tus notas en Folio.'**
  String get vaultStarterQuillBullet2;

  /// No description provided for @vaultStarterQuillBullet3.
  ///
  /// In es, this message translates to:
  /// **'Trabajar con la página abierta como contexto o con varias páginas que selecciones como referencia.'**
  String get vaultStarterQuillBullet3;

  /// No description provided for @vaultStarterQuillSectionPrivacy.
  ///
  /// In es, this message translates to:
  /// **'Privacidad y seguridad'**
  String get vaultStarterQuillSectionPrivacy;

  /// No description provided for @vaultStarterQuillPrivacyBody.
  ///
  /// In es, this message translates to:
  /// **'Tus páginas viven en este dispositivo. Si habilitas IA, revisa qué contexto compartes y con qué proveedor. Si olvidas la contraseña maestra de una libreta cifrada, Folio no puede recuperarlo por ti.'**
  String get vaultStarterQuillPrivacyBody;

  /// No description provided for @vaultStarterQuillBackupCallout.
  ///
  /// In es, this message translates to:
  /// **'Haz una copia de la libreta cuando tengas contenido importante. La copia conserva los datos y adjuntos, pero no transfiere Hello ni passkeys entre dispositivos.'**
  String get vaultStarterQuillBackupCallout;

  /// No description provided for @vaultStarterQuillMermaidCaption.
  ///
  /// In es, this message translates to:
  /// **'Prueba rápida de Mermaid:'**
  String get vaultStarterQuillMermaidCaption;

  /// No description provided for @vaultStarterQuillMermaidSource.
  ///
  /// In es, this message translates to:
  /// **'graph TD\nInicio[Crear libreta] --> Organizar[Organizar páginas]\nOrganizar --> Escribir[Escribir y enlazar ideas]\nEscribir --> Revisar[Buscar, revisar y mejorar]'**
  String get vaultStarterQuillMermaidSource;

  /// No description provided for @settingsAccentColorTitle.
  ///
  /// In es, this message translates to:
  /// **'Color de acento'**
  String get settingsAccentColorTitle;

  /// No description provided for @settingsAccentFollowSystem.
  ///
  /// In es, this message translates to:
  /// **'Windows'**
  String get settingsAccentFollowSystem;

  /// No description provided for @settingsAccentFolioDefault.
  ///
  /// In es, this message translates to:
  /// **'Folio'**
  String get settingsAccentFolioDefault;

  /// No description provided for @settingsAccentCustom.
  ///
  /// In es, this message translates to:
  /// **'Personalizado'**
  String get settingsAccentCustom;

  /// No description provided for @settingsAccentPickColor.
  ///
  /// In es, this message translates to:
  /// **'Elegir color predefinido'**
  String get settingsAccentPickColor;

  /// No description provided for @settingsPrivacySectionTitle.
  ///
  /// In es, this message translates to:
  /// **'Privacidad y diagnósticos'**
  String get settingsPrivacySectionTitle;

  /// No description provided for @settingsTelemetryTitle.
  ///
  /// In es, this message translates to:
  /// **'Estadísticas de uso anónimas'**
  String get settingsTelemetryTitle;

  /// No description provided for @settingsTelemetrySubtitle.
  ///
  /// In es, this message translates to:
  /// **'Ayuda a medir instalaciones y uso de funciones. No se envía contenido de la libreta ni títulos.'**
  String get settingsTelemetrySubtitle;

  /// No description provided for @onboardingTelemetryTitle.
  ///
  /// In es, this message translates to:
  /// **'Estadísticas de uso'**
  String get onboardingTelemetryTitle;

  /// No description provided for @onboardingTelemetryBody.
  ///
  /// In es, this message translates to:
  /// **'Folio puede enviar analítica anónima para entender cómo se usa la app. Puedes cambiarlo en cualquier momento en Ajustes.'**
  String get onboardingTelemetryBody;

  /// No description provided for @onboardingTelemetrySwitchTitle.
  ///
  /// In es, this message translates to:
  /// **'Estadísticas de uso anónimas'**
  String get onboardingTelemetrySwitchTitle;

  /// No description provided for @onboardingTelemetrySwitchSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Ayuda a medir instalaciones y uso de funciones. No se envía contenido de la libreta ni títulos.'**
  String get onboardingTelemetrySwitchSubtitle;

  /// No description provided for @onboardingTelemetryFootnote.
  ///
  /// In es, this message translates to:
  /// **'No se envía contenido de la libreta ni títulos de páginas.'**
  String get onboardingTelemetryFootnote;

  /// No description provided for @settingsAutoCrashReportsTitle.
  ///
  /// In es, this message translates to:
  /// **'Enviar diagnósticos de fallos automáticamente'**
  String get settingsAutoCrashReportsTitle;

  /// No description provided for @settingsAutoCrashReportsSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Si hay un error grave, se envía un trozo del log a Folio (opcional, limitado por sesión).'**
  String get settingsAutoCrashReportsSubtitle;

  /// No description provided for @settingsReportBugButton.
  ///
  /// In es, this message translates to:
  /// **'Reportar un error'**
  String get settingsReportBugButton;

  /// No description provided for @settingsPrivacyFootnote.
  ///
  /// In es, this message translates to:
  /// **'Puedes añadir una nota; puede abrirse el enlace de incidencias en el navegador.'**
  String get settingsPrivacyFootnote;

  /// No description provided for @settingsReportBugDialogTitle.
  ///
  /// In es, this message translates to:
  /// **'Reportar un error'**
  String get settingsReportBugDialogTitle;

  /// No description provided for @settingsReportBugDialogBody.
  ///
  /// In es, this message translates to:
  /// **'Enviaremos metadatos anónimos, un trozo del log y tu nota. Después podrás abrir el gestor de incidencias.'**
  String get settingsReportBugDialogBody;

  /// No description provided for @settingsReportBugNoteLabel.
  ///
  /// In es, this message translates to:
  /// **'¿Qué ocurrió? (opcional)'**
  String get settingsReportBugNoteLabel;

  /// No description provided for @settingsReportBugSend.
  ///
  /// In es, this message translates to:
  /// **'Enviar y continuar'**
  String get settingsReportBugSend;

  /// No description provided for @settingsReportBugSentOk.
  ///
  /// In es, this message translates to:
  /// **'Diagnóstico enviado.'**
  String get settingsReportBugSentOk;

  /// No description provided for @settingsReportBugSentFail.
  ///
  /// In es, this message translates to:
  /// **'No se pudo enviar el diagnóstico. Revisa la conexión o inténtalo más tarde.'**
  String get settingsReportBugSentFail;

  /// No description provided for @zenModeEnter.
  ///
  /// In es, this message translates to:
  /// **'Modo zen'**
  String get zenModeEnter;

  /// No description provided for @zenModeExit.
  ///
  /// In es, this message translates to:
  /// **'Salir del modo zen'**
  String get zenModeExit;

  /// No description provided for @syncedBlockCreate.
  ///
  /// In es, this message translates to:
  /// **'Sincronizar bloque'**
  String get syncedBlockCreate;

  /// No description provided for @syncedBlockInsert.
  ///
  /// In es, this message translates to:
  /// **'Insertar bloque sincronizado…'**
  String get syncedBlockInsert;

  /// No description provided for @syncedBlockBadge.
  ///
  /// In es, this message translates to:
  /// **'Bloque sincronizado'**
  String get syncedBlockBadge;

  /// No description provided for @syncedBlockCreated.
  ///
  /// In es, this message translates to:
  /// **'Bloque sincronizado. ID copiado al portapapeles.'**
  String get syncedBlockCreated;

  /// No description provided for @syncedBlockInsertTitle.
  ///
  /// In es, this message translates to:
  /// **'Insertar bloque sincronizado'**
  String get syncedBlockInsertTitle;

  /// No description provided for @syncedBlockIdLabel.
  ///
  /// In es, this message translates to:
  /// **'ID del grupo de sincronización'**
  String get syncedBlockIdLabel;

  /// No description provided for @syncedBlockIdHint.
  ///
  /// In es, this message translates to:
  /// **'Pega el ID copiado de otro bloque sincronizado'**
  String get syncedBlockIdHint;

  /// No description provided for @syncedBlockIdInvalid.
  ///
  /// In es, this message translates to:
  /// **'ID inválido o no encontrado'**
  String get syncedBlockIdInvalid;

  /// No description provided for @syncedBlockUnsync.
  ///
  /// In es, this message translates to:
  /// **'Desincronizar bloque'**
  String get syncedBlockUnsync;

  /// No description provided for @syncedBlockUnsynced.
  ///
  /// In es, this message translates to:
  /// **'Bloque desincronizado'**
  String get syncedBlockUnsynced;

  /// No description provided for @syncedBlockGroupCount.
  ///
  /// In es, this message translates to:
  /// **'{count,plural, =1{1 copia sincronizada} other{{count} copias sincronizadas}}'**
  String syncedBlockGroupCount(int count);

  /// No description provided for @graphViewTitle.
  ///
  /// In es, this message translates to:
  /// **'Vista de grafo'**
  String get graphViewTitle;

  /// No description provided for @graphViewEmpty.
  ///
  /// In es, this message translates to:
  /// **'No hay enlaces entre páginas'**
  String get graphViewEmpty;

  /// No description provided for @graphViewIncludeOrphans.
  ///
  /// In es, this message translates to:
  /// **'Incluir páginas sin enlaces'**
  String get graphViewIncludeOrphans;

  /// No description provided for @graphViewOpenPage.
  ///
  /// In es, this message translates to:
  /// **'Abrir página'**
  String get graphViewOpenPage;

  /// No description provided for @importPdf.
  ///
  /// In es, this message translates to:
  /// **'Importar PDF…'**
  String get importPdf;

  /// No description provided for @importPdfDialogTitle.
  ///
  /// In es, this message translates to:
  /// **'Importar PDF como página'**
  String get importPdfDialogTitle;

  /// No description provided for @importPdfAnnotationsOnly.
  ///
  /// In es, this message translates to:
  /// **'Solo anotaciones del PDF'**
  String get importPdfAnnotationsOnly;

  /// No description provided for @importPdfFullText.
  ///
  /// In es, this message translates to:
  /// **'Texto completo + anotaciones'**
  String get importPdfFullText;

  /// No description provided for @importPdfSuccess.
  ///
  /// In es, this message translates to:
  /// **'PDF importado: {title}'**
  String importPdfSuccess(String title);

  /// No description provided for @importPdfFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo importar el PDF: {error}'**
  String importPdfFailed(String error);

  /// No description provided for @importPdfNoText.
  ///
  /// In es, this message translates to:
  /// **'El PDF no contiene texto extraíble'**
  String get importPdfNoText;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
    'ca',
    'en',
    'es',
    'eu',
    'gl',
    'pt',
  ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ca':
      return AppLocalizationsCa();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'eu':
      return AppLocalizationsEu();
    case 'gl':
      return AppLocalizationsGl();
    case 'pt':
      return AppLocalizationsPt();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
