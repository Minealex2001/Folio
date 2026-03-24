// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'Folio';

  @override
  String get loading => 'Cargando…';

  @override
  String get newVault => 'Nuevo cofre';

  @override
  String stepOfTotal(int current, int total) {
    return 'Paso $current de $total';
  }

  @override
  String get back => 'Atrás';

  @override
  String get continueAction => 'Continuar';

  @override
  String get cancel => 'Cancelar';

  @override
  String get retry => 'Reintentar';

  @override
  String get settings => 'Ajustes';

  @override
  String get lockNow => 'Bloquear';

  @override
  String get pageHistory => 'Historial de la página';

  @override
  String get untitled => 'Sin título';

  @override
  String get noPages => 'Sin páginas';

  @override
  String get createPage => 'Crear página';

  @override
  String get selectPage => 'Selecciona una página';

  @override
  String get saveInProgress => 'Guardando…';

  @override
  String get savePending => 'Por guardar';

  @override
  String get savingVaultTooltip => 'Guardando el cofre cifrado en disco…';

  @override
  String get autosaveSoonTooltip => 'Guardado automático en unos instantes…';

  @override
  String get welcomeTitle => 'Bienvenida';

  @override
  String get welcomeBody =>
      'Folio guarda tus páginas solo en este dispositivo, cifradas con una contraseña maestra. Si la olvidas, no podremos recuperar los datos.\n\nNo hay sincronización en la nube.';

  @override
  String get createNewVault => 'Crear cofre nuevo';

  @override
  String get importBackupZip => 'Importar una copia (.zip)';

  @override
  String get importBackupTitle => 'Importar copia';

  @override
  String get importBackupBody =>
      'El archivo contiene los mismos datos cifrados que en el otro equipo. Necesitas la contraseña maestra con la que se creó esa copia.\n\nLa passkey y el desbloqueo rápido (Hello) no van en el archivo y no son transferibles; podrás configurarlos después en Ajustes.';

  @override
  String get chooseZipFile => 'Elegir archivo .zip';

  @override
  String get changeFile => 'Cambiar archivo';

  @override
  String get backupPasswordLabel => 'Contraseña de la copia';

  @override
  String get importVault => 'Importar cofre';

  @override
  String get masterPasswordTitle => 'Tu contraseña maestra';

  @override
  String masterPasswordHint(int min) {
    return 'Al menos $min caracteres. La usarás cada vez que abras Folio.';
  }

  @override
  String get passwordLabel => 'Contraseña';

  @override
  String get confirmPasswordLabel => 'Confirmar contraseña';

  @override
  String get next => 'Siguiente';

  @override
  String get readyTitle => 'Todo listo';

  @override
  String get readyBody =>
      'Se creará un cofre cifrado en este equipo. Podrás añadir después Windows Hello, biometría o una passkey para desbloquear más rápido (Ajustes).';

  @override
  String get createVault => 'Crear cofre';

  @override
  String minCharactersError(int min) {
    return 'Mínimo $min caracteres.';
  }

  @override
  String get passwordMismatchError => 'Las contraseñas no coinciden.';

  @override
  String get chooseZipError => 'Elige un archivo .zip.';

  @override
  String get enterBackupPasswordError => 'Introduce la contraseña de la copia.';

  @override
  String importFailedError(Object error) {
    return 'No se pudo importar: $error';
  }

  @override
  String createVaultFailedError(Object error) {
    return 'No se pudo crear el cofre: $error';
  }

  @override
  String get encryptedVault => 'Cofre cifrado';

  @override
  String get unlock => 'Desbloquear';

  @override
  String get quickUnlock => 'Hello / biometría';

  @override
  String get passkey => 'Passkey';

  @override
  String get unlockFailed => 'Contraseña incorrecta o cofre dañado.';

  @override
  String get appearance => 'Apariencia';

  @override
  String get security => 'Seguridad';

  @override
  String get vaultBackup => 'Copia del cofre';

  @override
  String get data => 'Datos';

  @override
  String get systemTheme => 'Sistema';

  @override
  String get lightTheme => 'Claro';

  @override
  String get darkTheme => 'Oscuro';

  @override
  String get language => 'Idioma';

  @override
  String get useSystemLanguage => 'Usar idioma del sistema';

  @override
  String get spanishLanguage => 'Español';

  @override
  String get englishLanguage => 'Inglés';
}
