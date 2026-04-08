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
  /// **'Se creará un cofre cifrado en este equipo. Podrás añadir después Windows Hello, biometría o una passkey para desbloquear más rápido (Ajustes).'**
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
  /// **'El color principal sigue al acento de Windows cuando está disponible.'**
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
  /// **'No se pudo borrar el cofre: {error}'**
  String wipeFailedError(Object error);

  /// No description provided for @filePathReadError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo leer la ruta del archivo.'**
  String get filePathReadError;

  /// No description provided for @importedVaultSuccessSnack.
  ///
  /// In es, this message translates to:
  /// **'Cofre importado. Aparece en el selector del panel lateral; el actual sigue igual.'**
  String get importedVaultSuccessSnack;

  /// No description provided for @exportVaultDialogTitle.
  ///
  /// In es, this message translates to:
  /// **'Exportar copia del cofre'**
  String get exportVaultDialogTitle;

  /// No description provided for @exportVaultDialogBody.
  ///
  /// In es, this message translates to:
  /// **'Para crear un archivo de copia, confirma tu identidad con el cofre actual desbloqueado.'**
  String get exportVaultDialogBody;

  /// No description provided for @verifyAndExport.
  ///
  /// In es, this message translates to:
  /// **'Verificar y exportar'**
  String get verifyAndExport;

  /// No description provided for @saveVaultBackupDialogTitle.
  ///
  /// In es, this message translates to:
  /// **'Guardar copia del cofre'**
  String get saveVaultBackupDialogTitle;

  /// No description provided for @importVaultDialogTitle.
  ///
  /// In es, this message translates to:
  /// **'Importar copia del cofre'**
  String get importVaultDialogTitle;

  /// No description provided for @importVaultDialogBody.
  ///
  /// In es, this message translates to:
  /// **'Se añadirá un cofre nuevo desde el archivo. El cofre que tienes abierto ahora no se borra ni se modifica.\n\nLa contraseña del archivo será la del cofre importado (para abrirlo al cambiar de cofre).\n\nLa passkey y el desbloqueo rápido (Hello / biometría) no van en la copia y no son transferibles; podrás configurarlos en ese cofre después.\n\n¿Continuar?'**
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
  /// **'Demuestra que eres tú con el cofre actual desbloqueado antes de importar.'**
  String get importIdentityBody;

  /// No description provided for @wipeVaultDialogTitle.
  ///
  /// In es, this message translates to:
  /// **'Borrar cofre'**
  String get wipeVaultDialogTitle;

  /// No description provided for @wipeVaultDialogBody.
  ///
  /// In es, this message translates to:
  /// **'Se eliminarán todas las páginas y la contraseña maestra dejará de ser válida. Esta acción no se puede deshacer.\n\n¿Seguro que quieres continuar?'**
  String get wipeVaultDialogBody;

  /// No description provided for @wipeIdentityBody.
  ///
  /// In es, this message translates to:
  /// **'Para borrar el cofre, demuestra que eres tú.'**
  String get wipeIdentityBody;

  /// No description provided for @exportZipTitle.
  ///
  /// In es, this message translates to:
  /// **'Exportar copia (.zip)'**
  String get exportZipTitle;

  /// No description provided for @exportZipSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Contraseña, Hello o passkey del cofre actual'**
  String get exportZipSubtitle;

  /// No description provided for @importZipTitle.
  ///
  /// In es, this message translates to:
  /// **'Importar copia (.zip)'**
  String get importZipTitle;

  /// No description provided for @importZipSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Añade cofre nuevo · identidad actual + contraseña del archivo'**
  String get importZipSubtitle;

  /// No description provided for @backupInfoBody.
  ///
  /// In es, this message translates to:
  /// **'El archivo contiene los mismos datos cifrados que en disco (vault.keys y vault.bin), sin exponer el contenido en claro. Las imágenes en adjuntos van tal cual.\n\nLa passkey y el desbloqueo rápido no se incluyen en la copia y no son transferibles entre dispositivos; en cada cofre importado podrás configurarlos de nuevo.\n\nImportar añade un cofre nuevo; no sustituye el que tienes abierto.'**
  String get backupInfoBody;

  /// No description provided for @wipeCardTitle.
  ///
  /// In es, this message translates to:
  /// **'Borrar cofre y empezar de cero'**
  String get wipeCardTitle;

  /// No description provided for @wipeCardSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Requiere contraseña, Hello o passkey.'**
  String get wipeCardSubtitle;

  /// No description provided for @switchVaultTooltip.
  ///
  /// In es, this message translates to:
  /// **'Cambiar cofre'**
  String get switchVaultTooltip;

  /// No description provided for @switchVaultTitle.
  ///
  /// In es, this message translates to:
  /// **'Cambiar de cofre'**
  String get switchVaultTitle;

  /// No description provided for @switchVaultBody.
  ///
  /// In es, this message translates to:
  /// **'Se cerrará la sesión de este cofre y tendrás que desbloquear el otro con su contraseña, Hello o passkey (si los tienes configurados allí).'**
  String get switchVaultBody;

  /// No description provided for @renameVaultTitle.
  ///
  /// In es, this message translates to:
  /// **'Renombrar cofre'**
  String get renameVaultTitle;

  /// No description provided for @nameLabel.
  ///
  /// In es, this message translates to:
  /// **'Nombre'**
  String get nameLabel;

  /// No description provided for @deleteOtherVaultTitle.
  ///
  /// In es, this message translates to:
  /// **'Eliminar otro cofre'**
  String get deleteOtherVaultTitle;

  /// No description provided for @deleteVaultConfirmTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Eliminar cofre?'**
  String get deleteVaultConfirmTitle;

  /// No description provided for @deleteVaultConfirmBody.
  ///
  /// In es, this message translates to:
  /// **'Se borrará por completo «{name}». No se puede deshacer.'**
  String deleteVaultConfirmBody(Object name);

  /// No description provided for @vaultDeletedSnack.
  ///
  /// In es, this message translates to:
  /// **'Cofre eliminado.'**
  String get vaultDeletedSnack;

  /// No description provided for @noOtherVaultsSnack.
  ///
  /// In es, this message translates to:
  /// **'No hay otros cofres que borrar.'**
  String get noOtherVaultsSnack;

  /// No description provided for @addVault.
  ///
  /// In es, this message translates to:
  /// **'Añadir cofre'**
  String get addVault;

  /// No description provided for @renameActiveVault.
  ///
  /// In es, this message translates to:
  /// **'Renombrar cofre activo'**
  String get renameActiveVault;

  /// No description provided for @deleteOtherVault.
  ///
  /// In es, this message translates to:
  /// **'Eliminar otro cofre…'**
  String get deleteOtherVault;

  /// No description provided for @activeVaultLabel.
  ///
  /// In es, this message translates to:
  /// **'Cofre activo'**
  String get activeVaultLabel;

  /// No description provided for @sidebarVaultsLoading.
  ///
  /// In es, this message translates to:
  /// **'Cargando cofres…'**
  String get sidebarVaultsLoading;

  /// No description provided for @sidebarVaultsEmpty.
  ///
  /// In es, this message translates to:
  /// **'No hay cofres disponibles'**
  String get sidebarVaultsEmpty;

  /// No description provided for @forceSyncTooltip.
  ///
  /// In es, this message translates to:
  /// **'Forzar sincronización'**
  String get forceSyncTooltip;

  /// No description provided for @searchDialogFooterHint.
  ///
  /// In es, this message translates to:
  /// **'Enter abre el primer resultado · Esc cierra'**
  String get searchDialogFooterHint;

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
  /// **'Enlace a una página de este cofre'**
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
  /// **'El cofre se guarda en seguida; el historial añade una entrada cuando dejas de editar y el contenido cambió.'**
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
  /// **'Instala LM Studio, inicia su servidor local (OpenAI compatible) y verifica que responda en http://127.0.0.1:1234.'**
  String get aiSetupLmStudioBody;

  /// No description provided for @aiSetupOpenSettingsHint.
  ///
  /// In es, this message translates to:
  /// **'Cuando uno de los proveedores esté operativo, pulsa Reintentar para autoconfigurarlo.'**
  String get aiSetupOpenSettingsHint;

  /// No description provided for @quillGlobalScopeNoticeTitle.
  ///
  /// In es, this message translates to:
  /// **'Quill funciona en todos los cofres'**
  String get quillGlobalScopeNoticeTitle;

  /// No description provided for @quillGlobalScopeNoticeBody.
  ///
  /// In es, this message translates to:
  /// **'Quill es un ajuste global de la app. Si lo activas ahora, quedará disponible para cualquier cofre en esta instalación, no solo para el actual.'**
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
  /// **'Buscar en todo el cofre...'**
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

  /// No description provided for @unlockVaultTitle.
  ///
  /// In es, this message translates to:
  /// **'Desbloquear cofre'**
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
  /// **'Importa un ZIP exportado por Notion. Puedes añadirlo al cofre actual o crear uno nuevo.'**
  String get importNotionDialogBody;

  /// No description provided for @importNotionSelectTargetTitle.
  ///
  /// In es, this message translates to:
  /// **'Destino de la importación'**
  String get importNotionSelectTargetTitle;

  /// No description provided for @importNotionSelectTargetBody.
  ///
  /// In es, this message translates to:
  /// **'Elige si quieres importar la exportacion de Notion en el cofre actual o crear un cofre nuevo a partir de ella.'**
  String get importNotionSelectTargetBody;

  /// No description provided for @importNotionTargetCurrent.
  ///
  /// In es, this message translates to:
  /// **'Cofre actual'**
  String get importNotionTargetCurrent;

  /// No description provided for @importNotionTargetNew.
  ///
  /// In es, this message translates to:
  /// **'Cofre nuevo'**
  String get importNotionTargetNew;

  /// No description provided for @importNotionDefaultVaultName.
  ///
  /// In es, this message translates to:
  /// **'Importado desde Notion'**
  String get importNotionDefaultVaultName;

  /// No description provided for @importNotionNewVaultPasswordTitle.
  ///
  /// In es, this message translates to:
  /// **'Contraseña para cofre nuevo'**
  String get importNotionNewVaultPasswordTitle;

  /// No description provided for @importNotionSuccessCurrent.
  ///
  /// In es, this message translates to:
  /// **'Notion importado en el cofre actual.'**
  String get importNotionSuccessCurrent;

  /// No description provided for @importNotionSuccessNew.
  ///
  /// In es, this message translates to:
  /// **'Cofre nuevo importado desde Notion.'**
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
  /// **'Estás usando una versión beta. Puede haber fallos; haz copias de seguridad del cofre con frecuencia.'**
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
  /// **'Importar solo mientras el cofre este disponible y la peticion incluya el secreto configurado.'**
  String get integrationApprovalCanDoUnlockedVault;

  /// No description provided for @integrationApprovalCannotDoTitle.
  ///
  /// In es, this message translates to:
  /// **'Lo que no puede hacer'**
  String get integrationApprovalCannotDoTitle;

  /// No description provided for @integrationApprovalCannotDoRead.
  ///
  /// In es, this message translates to:
  /// **'No puede leer el contenido de tu cofre a traves de este puente.'**
  String get integrationApprovalCannotDoRead;

  /// No description provided for @integrationApprovalCannotDoBypassLock.
  ///
  /// In es, this message translates to:
  /// **'No puede saltarse el bloqueo del cofre, el cifrado ni tu aprobacion explicita.'**
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
  /// **'Crear cofre sin cifrado'**
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
  /// **'Este cofre no está cifrado: no aplican la passkey, el desbloqueo rápido (Hello), el bloqueo por inactividad, el bloqueo al minimizar ni la contraseña maestra.'**
  String get plainVaultSecurityNotice;

  /// No description provided for @encryptPlainVaultTitle.
  ///
  /// In es, this message translates to:
  /// **'Cifrar este cofre'**
  String get encryptPlainVaultTitle;

  /// No description provided for @encryptPlainVaultBody.
  ///
  /// In es, this message translates to:
  /// **'Elige una contraseña maestra. Todo lo guardado en este dispositivo se cifrará. Si la olvidas, no podremos recuperar los datos.'**
  String get encryptPlainVaultBody;

  /// No description provided for @encryptPlainVaultConfirm.
  ///
  /// In es, this message translates to:
  /// **'Cifrar cofre'**
  String get encryptPlainVaultConfirm;

  /// No description provided for @encryptPlainVaultSuccessSnack.
  ///
  /// In es, this message translates to:
  /// **'El cofre ya está cifrado'**
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
  /// **'La plantilla \"{name}\" se eliminará de este cofre.'**
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

  /// No description provided for @clear.
  ///
  /// In es, this message translates to:
  /// **'Limpiar'**
  String get clear;
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
