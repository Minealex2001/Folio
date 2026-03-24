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
  String get passwordMustBeStrongError =>
      'La contraseña debe ser Fuerte para continuar.';

  @override
  String get passwordStrengthLabel => 'Seguridad';

  @override
  String get passwordStrengthVeryWeak => 'Muy débil';

  @override
  String get passwordStrengthWeak => 'Débil';

  @override
  String get passwordStrengthFair => 'Aceptable';

  @override
  String get passwordStrengthStrong => 'Fuerte';

  @override
  String get showPassword => 'Mostrar contraseña';

  @override
  String get hidePassword => 'Ocultar contraseña';

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

  @override
  String get active => 'Activado';

  @override
  String get inactive => 'Desactivado';

  @override
  String get remove => 'Quitar';

  @override
  String get enable => 'Activar';

  @override
  String get register => 'Registrar';

  @override
  String get revoke => 'Revocar';

  @override
  String get save => 'Guardar';

  @override
  String get delete => 'Eliminar';

  @override
  String get rename => 'Renombrar';

  @override
  String get change => 'Cambiar';

  @override
  String get importAction => 'Importar';

  @override
  String get masterPassword => 'Contraseña maestra';

  @override
  String get confirmIdentity => 'Confirma identidad';

  @override
  String get quickUnlockTitle => 'Desbloqueo rápido (Hello / biometría)';

  @override
  String get passkeyThisDevice => 'WebAuthn en este dispositivo';

  @override
  String get lockOnMinimize => 'Bloquear al minimizar';

  @override
  String get changeMasterPassword => 'Cambiar contraseña maestra';

  @override
  String get requiresCurrentPassword => 'Requiere contraseña actual';

  @override
  String get lockAutoByInactivity => 'Bloqueo automático por inactividad';

  @override
  String minutesShort(int minutes) {
    return '$minutes min';
  }

  @override
  String get settingsAppearanceHint =>
      'El color principal sigue al acento de Windows cuando está disponible.';

  @override
  String get backupFilePasswordLabel => 'Contraseña del archivo de copia';

  @override
  String get backupFilePasswordHelper =>
      'Es la contraseña maestra con la que se creó la copia, no la de otro dispositivo.';

  @override
  String get backupPasswordDialogTitle => 'Contraseña de la copia';

  @override
  String get currentPasswordLabel => 'Contraseña actual';

  @override
  String get newPasswordLabel => 'Nueva contraseña';

  @override
  String get confirmNewPasswordLabel => 'Confirmar nueva contraseña';

  @override
  String passwordStrengthWithValue(Object value) {
    return 'Seguridad: $value';
  }

  @override
  String get fillAllFieldsError => 'Completa todos los campos.';

  @override
  String get newPasswordsMismatchError =>
      'Las contraseñas nuevas no coinciden.';

  @override
  String get newPasswordMustBeStrongError =>
      'La nueva contraseña debe ser Fuerte.';

  @override
  String get newPasswordMustDifferError =>
      'La nueva contraseña debe ser distinta.';

  @override
  String get incorrectPasswordError => 'Contraseña incorrecta.';

  @override
  String get useHelloBiometrics => 'Usar Hello / biometría';

  @override
  String get usePasskey => 'Usar passkey';

  @override
  String get quickUnlockEnabledSnack => 'Desbloqueo rápido activado';

  @override
  String get quickUnlockDisabledSnack => 'Desbloqueo rápido desactivado';

  @override
  String get passkeyRegisteredSnack => 'Passkey registrada';

  @override
  String get passkeyRevokedSnack => 'Passkey revocada';

  @override
  String get masterPasswordUpdatedSnack => 'Contraseña maestra actualizada';

  @override
  String get backupSavedSuccessSnack => 'Copia guardada correctamente.';

  @override
  String exportFailedError(Object error) {
    return 'No se pudo exportar: $error';
  }

  @override
  String importFailedGenericError(Object error) {
    return 'No se pudo importar: $error';
  }

  @override
  String wipeFailedError(Object error) {
    return 'No se pudo borrar el cofre: $error';
  }

  @override
  String get filePathReadError => 'No se pudo leer la ruta del archivo.';

  @override
  String get importedVaultSuccessSnack =>
      'Cofre importado. Aparece en el selector del panel lateral; el actual sigue igual.';

  @override
  String get exportVaultDialogTitle => 'Exportar copia del cofre';

  @override
  String get exportVaultDialogBody =>
      'Para crear un archivo de copia, confirma tu identidad con el cofre actual desbloqueado.';

  @override
  String get verifyAndExport => 'Verificar y exportar';

  @override
  String get saveVaultBackupDialogTitle => 'Guardar copia del cofre';

  @override
  String get importVaultDialogTitle => 'Importar copia del cofre';

  @override
  String get importVaultDialogBody =>
      'Se añadirá un cofre nuevo desde el archivo. El cofre que tienes abierto ahora no se borra ni se modifica.\n\nLa contraseña del archivo será la del cofre importado (para abrirlo al cambiar de cofre).\n\nLa passkey y el desbloqueo rápido (Hello / biometría) no van en la copia y no son transferibles; podrás configurarlos en ese cofre después.\n\n¿Continuar?';

  @override
  String get verifyAndContinue => 'Verificar y continuar';

  @override
  String get verifyAndDelete => 'Verificar con contraseña y borrar';

  @override
  String get importIdentityBody =>
      'Demuestra que eres tú con el cofre actual desbloqueado antes de importar.';

  @override
  String get wipeVaultDialogTitle => 'Borrar cofre';

  @override
  String get wipeVaultDialogBody =>
      'Se eliminarán todas las páginas y la contraseña maestra dejará de ser válida. Esta acción no se puede deshacer.\n\n¿Seguro que quieres continuar?';

  @override
  String get wipeIdentityBody => 'Para borrar el cofre, demuestra que eres tú.';

  @override
  String get exportZipTitle => 'Exportar copia (.zip)';

  @override
  String get exportZipSubtitle =>
      'Contraseña, Hello o passkey del cofre actual';

  @override
  String get importZipTitle => 'Importar copia (.zip)';

  @override
  String get importZipSubtitle =>
      'Añade cofre nuevo · identidad actual + contraseña del archivo';

  @override
  String get backupInfoBody =>
      'El archivo contiene los mismos datos cifrados que en disco (vault.keys y vault.bin), sin exponer el contenido en claro. Las imágenes en adjuntos van tal cual.\n\nLa passkey y el desbloqueo rápido no se incluyen en la copia y no son transferibles entre dispositivos; en cada cofre importado podrás configurarlos de nuevo.\n\nImportar añade un cofre nuevo; no sustituye el que tienes abierto.';

  @override
  String get wipeCardTitle => 'Borrar cofre y empezar de cero';

  @override
  String get wipeCardSubtitle => 'Requiere contraseña, Hello o passkey.';

  @override
  String get switchVaultTooltip => 'Cambiar cofre';

  @override
  String get switchVaultTitle => 'Cambiar de cofre';

  @override
  String get switchVaultBody =>
      'Se cerrará la sesión de este cofre y tendrás que desbloquear el otro con su contraseña, Hello o passkey (si los tienes configurados allí).';

  @override
  String get renameVaultTitle => 'Renombrar cofre';

  @override
  String get nameLabel => 'Nombre';

  @override
  String get deleteOtherVaultTitle => 'Eliminar otro cofre';

  @override
  String get deleteVaultConfirmTitle => '¿Eliminar cofre?';

  @override
  String deleteVaultConfirmBody(Object name) {
    return 'Se borrará por completo «$name». No se puede deshacer.';
  }

  @override
  String get vaultDeletedSnack => 'Cofre eliminado.';

  @override
  String get noOtherVaultsSnack => 'No hay otros cofres que borrar.';

  @override
  String get addVault => 'Añadir cofre';

  @override
  String get renameActiveVault => 'Renombrar cofre activo';

  @override
  String get deleteOtherVault => 'Eliminar otro cofre…';

  @override
  String get activeVaultLabel => 'Cofre activo';

  @override
  String get renamePageTitle => 'Renombrar página';

  @override
  String get titleLabel => 'Título';

  @override
  String get rootPage => 'Raíz';

  @override
  String movePageTitle(Object title) {
    return 'Mover «$title»';
  }

  @override
  String get subpage => 'Subpágina';

  @override
  String get move => 'Mover';

  @override
  String get pages => 'Páginas';

  @override
  String get newRootPageTooltip => 'Nueva página (raíz)';

  @override
  String get blockOptions => 'Opciones del bloque';

  @override
  String get dragToReorder => 'Arrastrar para reordenar';

  @override
  String get addBlock => 'Añadir bloque';

  @override
  String get fileNotFound => 'Archivo no encontrado';

  @override
  String get couldNotLoadImage => 'No se pudo cargar la imagen';

  @override
  String get noImageHint => 'Sin imagen · menú ⋮ o botón de abajo';

  @override
  String get chooseImage => 'Elegir imagen';

  @override
  String get replaceFile => 'Cambiar archivo';

  @override
  String get removeFile => 'Quitar archivo';

  @override
  String get replaceVideo => 'Cambiar video';

  @override
  String get removeVideo => 'Quitar video';

  @override
  String get openExternal => 'Abrir externo';

  @override
  String get openVideoExternal => 'Abrir video externo';

  @override
  String get play => 'Reproducir';

  @override
  String get pause => 'Pausar';

  @override
  String get mute => 'Silenciar';

  @override
  String get unmute => 'Activar sonido';

  @override
  String get fileResolveError => 'Error resolviendo archivo';

  @override
  String get videoResolveError => 'Error resolviendo video';

  @override
  String get fileMissing => 'No se encuentra el archivo';

  @override
  String get videoMissing => 'No se encuentra el video';

  @override
  String get chooseFile => 'Elegir archivo';

  @override
  String get chooseVideo => 'Elegir video';

  @override
  String get noEmbeddedPreview => 'Sin preview embebido para este tipo';

  @override
  String get couldNotReadFile => 'No se pudo leer el archivo';

  @override
  String get couldNotLoadVideo => 'No se pudo cargar el video';

  @override
  String get couldNotPreviewPdf => 'No se pudo previsualizar el PDF';

  @override
  String get formatToolbar => 'Barra de formato';

  @override
  String get linkTitle => 'Enlace';

  @override
  String get visibleTextLabel => 'Texto visible';

  @override
  String get urlLabel => 'URL';

  @override
  String get urlHint => 'https://…';

  @override
  String get insert => 'Insertar';

  @override
  String get defaultLinkText => 'texto';

  @override
  String get boldTip => 'Negrita (**)';

  @override
  String get italicTip => 'Cursiva (_)';

  @override
  String get underlineTip => 'Subrayado (<u>)';

  @override
  String get inlineCodeTip => 'Código inline (`)';

  @override
  String get strikeTip => 'Tachado (~~)';

  @override
  String get linkTip => 'Enlace';

  @override
  String get pageHistoryTitle => 'Historial de versiones';

  @override
  String get restoreVersionTitle => 'Restaurar versión';

  @override
  String get restoreVersionBody =>
      'Se sustituirá el título y el contenido de la página por esta versión. El estado actual se guardará antes en el historial.';

  @override
  String get restore => 'Restaurar';

  @override
  String get deleteVersionTitle => 'Borrar versión';

  @override
  String get deleteVersionBody =>
      'Esta entrada desaparecerá del historial. El texto actual de la página no cambia.';

  @override
  String get noVersionsYet => 'Sin versiones todavía';

  @override
  String get historyAppearsHint =>
      'Cuando dejes de escribir unos segundos, aquí aparecerá el historial de cambios.';

  @override
  String get versionControl => 'Control de versiones';

  @override
  String get historyHeaderBody =>
      'El cofre se guarda en seguida; el historial añade una entrada cuando dejas de editar y el contenido cambió.';

  @override
  String versionsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'versiones',
      one: 'versión',
    );
    return '$count $_temp0';
  }

  @override
  String get untitledFallback => 'Sin título';

  @override
  String get comparedWithPrevious => 'Comparado con la versión anterior';

  @override
  String get changesFromEmptyStart => 'Cambios desde el inicio vacío';

  @override
  String get contentLabel => 'Contenido';

  @override
  String get titleLabelSimple => 'Título';

  @override
  String get emptyValue => '(vacío)';

  @override
  String get noTextChanges => 'Sin cambios en el texto.';

  @override
  String get aiAssistantTitle => 'Asistente IA';

  @override
  String get aiNoPageSelected => 'Sin página seleccionada';

  @override
  String get aiExpand => 'Expandir';

  @override
  String get aiCollapse => 'Colapsar';

  @override
  String get aiDeleteCurrentChat => 'Borrar chat actual';

  @override
  String get aiNewChat => 'Nuevo';

  @override
  String get aiAttach => 'Adjuntar';

  @override
  String get aiChatEmptyHint =>
      'Empieza una conversación.\nLa IA decidirá automáticamente qué hacer con tu mensaje.';

  @override
  String get aiInputHint => 'Escribe tu mensaje. La IA actuará como agente.';

  @override
  String get aiShowPanel => 'Mostrar panel IA';

  @override
  String get aiHidePanel => 'Ocultar panel IA';

  @override
  String get closeCurrentPage => 'Cerrar página actual';

  @override
  String aiErrorWithDetails(Object error) {
    return 'Error IA: $error';
  }

  @override
  String get aiAgentThought => 'Pensamiento del agente';

  @override
  String get aiAlwaysShowThought => 'Mostrar siempre pensamiento de IA';

  @override
  String get aiAlwaysShowThoughtHint =>
      'Si está desactivado, se mostrará plegado con flecha en cada mensaje.';

  @override
  String get searchByNameOrShortcut => 'Buscar por nombre o atajo…';

  @override
  String get search => 'Buscar';

  @override
  String get open => 'Abrir';

  @override
  String get exit => 'Salir';

  @override
  String get desktopSection => 'Desktop';

  @override
  String get globalSearchHotkey => 'Atajo global de búsqueda';

  @override
  String get hotkeyCombination => 'Combinación de teclas';

  @override
  String get hotkeyAltSpace => 'Alt + Space';

  @override
  String get hotkeyCtrlShiftSpace => 'Ctrl + Shift + Space';

  @override
  String get hotkeyCtrlShiftK => 'Ctrl + Shift + K';

  @override
  String get minimizeToTray => 'Minimizar a bandeja';

  @override
  String get closeToTray => 'Cerrar a bandeja';

  @override
  String get searchAllVaultHint => 'Buscar en todo el cofre...';

  @override
  String get typeToSearch => 'Escribe para buscar';

  @override
  String get noSearchResults => 'Sin resultados';

  @override
  String get unlockVaultTitle => 'Desbloquear cofre';

  @override
  String get miniUnlockFailed => 'No se pudo desbloquear.';

  @override
  String get importNotionTitle => 'Importar desde Notion (.zip)';

  @override
  String get importNotionSubtitle => 'Export ZIP de Notion (Markdown/HTML)';

  @override
  String get importNotionDialogTitle => 'Importar desde Notion';

  @override
  String get importNotionDialogBody =>
      'Importa un ZIP exportado por Notion. Puedes añadirlo al cofre actual o crear uno nuevo.';

  @override
  String get importNotionSelectTargetTitle => 'Destino de la importación';

  @override
  String get importNotionTargetCurrent => 'Cofre actual';

  @override
  String get importNotionTargetNew => 'Cofre nuevo';

  @override
  String get importNotionNewVaultPasswordTitle => 'Contraseña para cofre nuevo';

  @override
  String get importNotionSuccessCurrent =>
      'Notion importado en el cofre actual.';

  @override
  String get importNotionSuccessNew => 'Cofre nuevo importado desde Notion.';

  @override
  String importNotionError(Object error) {
    return 'No se pudo importar Notion: $error';
  }
}
