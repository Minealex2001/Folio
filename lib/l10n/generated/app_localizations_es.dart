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
  String get newVault => 'Nueva libreta';

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
  String get savingVaultTooltip => 'Guardando la libreta cifrada en disco…';

  @override
  String get autosaveSoonTooltip => 'Guardado automático en unos instantes…';

  @override
  String get welcomeTitle => 'Bienvenida';

  @override
  String get welcomeBody =>
      'Folio guarda tus páginas solo en este dispositivo, cifradas con una contraseña maestra. Si la olvidas, no podremos recuperar los datos.\n\nNo hay sincronización en la nube.';

  @override
  String get createNewVault => 'Crear libreta nueva';

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
  String get backupPlainNoPasswordHint =>
      'Esta copia no está cifrada. No necesitas contraseña para importarla.';

  @override
  String get importVault => 'Importar libreta';

  @override
  String get masterPasswordTitle => 'Tu contraseña maestra';

  @override
  String masterPasswordHint(int min) {
    return 'Al menos $min caracteres. La usarás cada vez que abras Folio.';
  }

  @override
  String get createStarterPagesTitle => 'Crear páginas iniciales de ayuda';

  @override
  String get createStarterPagesBody =>
      'Añade una pequeña guía con ejemplos, atajos y capacidades de Folio. Podrás borrar esas páginas después.';

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
      'Se creará una libreta cifrada en este equipo. Podrás añadir después Windows Hello, biometría o una passkey para desbloquear más rápido (Ajustes).';

  @override
  String get quillIntroTitle => 'Conoce a Quill';

  @override
  String get quillIntroBody =>
      'Quill es la asistente integrada de Folio. Puede ayudarte a escribir, editar y entender tus páginas, además de resolver dudas sobre cómo usar la app.';

  @override
  String get quillIntroCapabilityWrite =>
      'Puede redactar, resumir o reescribir contenido dentro de tus páginas.';

  @override
  String get quillIntroCapabilityExplain =>
      'También responde preguntas sobre Folio, atajos, bloques y cómo organizar tus notas.';

  @override
  String get quillIntroCapabilityContext =>
      'Puedes dejar que use la página abierta como contexto o elegir varias páginas de referencia.';

  @override
  String get quillIntroCapabilityExamples =>
      'Lo mejor es hablarle de forma natural: Quill decide si responder o editar.';

  @override
  String get quillIntroExamplesTitle => 'Ejemplos rápidos';

  @override
  String get quillIntroExampleOne => 'Resume esta página en tres puntos.';

  @override
  String get quillIntroExampleTwo =>
      'Cambia el título y mejora la introducción.';

  @override
  String get quillIntroExampleThree => '¿Cómo añado una imagen o una tabla?';

  @override
  String get quillIntroFootnote =>
      'Si todavía no activas la IA, podrás hacerlo más tarde. Esta introducción es para que sepas qué puede hacer Quill cuando la uses.';

  @override
  String get createVault => 'Crear libreta';

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
    return 'No se pudo crear la libreta: $error';
  }

  @override
  String get encryptedVault => 'Libreta cifrada';

  @override
  String get unlock => 'Desbloquear';

  @override
  String get quickUnlock => 'Hello / biometría';

  @override
  String get passkey => 'Passkey';

  @override
  String get unlockFailed => 'Contraseña incorrecta o libreta dañada.';

  @override
  String get appearance => 'Apariencia';

  @override
  String get security => 'Seguridad';

  @override
  String get vaultBackup => 'Copia de la libreta';

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
    return 'No se pudo borrar la libreta: $error';
  }

  @override
  String get filePathReadError => 'No se pudo leer la ruta del archivo.';

  @override
  String get importedVaultSuccessSnack =>
      'Libreta importada. Aparece en el selector del panel lateral; la actual sigue igual.';

  @override
  String get exportVaultDialogTitle => 'Exportar copia de la libreta';

  @override
  String get exportVaultDialogBody =>
      'Para crear un archivo de copia, confirma tu identidad con la libreta actual desbloqueada.';

  @override
  String get verifyAndExport => 'Verificar y exportar';

  @override
  String get saveVaultBackupDialogTitle => 'Guardar copia de la libreta';

  @override
  String get importVaultDialogTitle => 'Importar copia de la libreta';

  @override
  String get importVaultDialogBody =>
      'Se añadirá una libreta nueva desde el archivo. La libreta que tienes abierta ahora no se borra ni se modifica.\n\nLa contraseña del archivo será la de la libreta importada (para abrirla al cambiar de libreta).\n\nLa passkey y el desbloqueo rápido (Hello / biometría) no van en la copia y no son transferibles; podrás configurarlos en esa libreta después.\n\n¿Continuar?';

  @override
  String get verifyAndContinue => 'Verificar y continuar';

  @override
  String get verifyAndDelete => 'Verificar con contraseña y borrar';

  @override
  String get importIdentityBody =>
      'Demuestra que eres tú con la libreta actual desbloqueada antes de importar.';

  @override
  String get wipeVaultDialogTitle => 'Borrar libreta';

  @override
  String get wipeVaultDialogBody =>
      'Se eliminarán todas las páginas y la contraseña maestra dejará de ser válida. Esta acción no se puede deshacer.\n\n¿Seguro que quieres continuar?';

  @override
  String get wipeIdentityBody =>
      'Para borrar la libreta, demuestra que eres tú.';

  @override
  String get exportZipTitle => 'Exportar copia (.zip)';

  @override
  String get exportZipSubtitle =>
      'Contraseña, Hello o passkey de la libreta actual';

  @override
  String get importZipTitle => 'Importar copia (.zip)';

  @override
  String get importZipSubtitle =>
      'Añade libreta nueva · identidad actual + contraseña del archivo';

  @override
  String get backupInfoBody =>
      'El archivo contiene los mismos datos cifrados que en disco (vault.keys y vault.bin), sin exponer el contenido en claro. Las imágenes en adjuntos van tal cual.\n\nLa passkey y el desbloqueo rápido no se incluyen en la copia y no son transferibles entre dispositivos; en cada libreta importada podrás configurarlos de nuevo.\n\nImportar añade una libreta nueva; no sustituye la que tienes abierta.';

  @override
  String get wipeCardTitle => 'Borrar libreta y empezar de cero';

  @override
  String get wipeCardSubtitle => 'Requiere contraseña, Hello o passkey.';

  @override
  String get switchVaultTooltip => 'Cambiar libreta';

  @override
  String get switchVaultTitle => 'Cambiar de libreta';

  @override
  String get switchVaultBody =>
      'Se cerrará la sesión de esta libreta y tendrás que desbloquear la otra con su contraseña, Hello o passkey (si los tienes configurados allí).';

  @override
  String get renameVaultTitle => 'Renombrar libreta';

  @override
  String get nameLabel => 'Nombre';

  @override
  String get deleteOtherVaultTitle => 'Eliminar otra libreta';

  @override
  String get deleteVaultConfirmTitle => '¿Eliminar libreta?';

  @override
  String deleteVaultConfirmBody(Object name) {
    return 'Se borrará por completo «$name». No se puede deshacer.';
  }

  @override
  String get vaultDeletedSnack => 'Libreta eliminada.';

  @override
  String get noOtherVaultsSnack => 'No hay otras libretas que borrar.';

  @override
  String get addVault => 'Añadir libreta';

  @override
  String get renameActiveVault => 'Renombrar libreta activa';

  @override
  String get deleteOtherVault => 'Eliminar otra libreta…';

  @override
  String get activeVaultLabel => 'Libreta activa';

  @override
  String get sidebarVaultsLoading => 'Cargando libretas…';

  @override
  String get sidebarVaultsEmpty => 'No hay libretas disponibles';

  @override
  String get forceSyncTooltip => 'Forzar sincronización';

  @override
  String get searchDialogFooterHint =>
      'Enter abre el resultado resaltado · Ctrl+↑ / Ctrl+↓ navegar · Esc cierra';

  @override
  String get searchFilterTasks => 'Tareas';

  @override
  String get searchRecentQueries => 'Búsquedas recientes';

  @override
  String get searchShortcutsHelpTooltip => 'Atajos de teclado';

  @override
  String get searchShortcutsHelpTitle => 'Búsqueda global';

  @override
  String get searchShortcutsHelpBody =>
      'Enter: abrir el resultado resaltado\nCtrl+↑ o Ctrl+↓: anterior / siguiente\nEsc: cerrar';

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
  String get pageOutlineTitle => 'Índice';

  @override
  String get pageOutlineEmpty =>
      'Añade encabezados (H1–H3) para generar el índice.';

  @override
  String get showPageOutline => 'Mostrar índice';

  @override
  String get hidePageOutline => 'Ocultar índice';

  @override
  String get tocBlockTitle => 'Tabla de contenidos';

  @override
  String get showSidebar => 'Mostrar panel lateral';

  @override
  String get hideSidebar => 'Ocultar panel lateral';

  @override
  String get resizeSidebarHandle => 'Redimensionar panel lateral';

  @override
  String get resizeSidebarHandleHint =>
      'Arrastra horizontalmente para cambiar el ancho del panel';

  @override
  String get resizeAiPanelHeightHandle => 'Redimensionar altura del asistente';

  @override
  String get resizeAiPanelHeightHandleHint =>
      'Arrastra verticalmente para cambiar la altura del panel';

  @override
  String get sidebarAutoRevealTitle => 'Mostrar panel al acercar al borde';

  @override
  String get sidebarAutoRevealSubtitle =>
      'Si el panel está oculto, acerca el puntero al borde izquierdo para verlo un momento.';

  @override
  String get newRootPageTooltip => 'Nueva página (raíz)';

  @override
  String get blockOptions => 'Opciones del bloque';

  @override
  String get dragToReorder => 'Arrastrar para reordenar';

  @override
  String get addBlock => 'Añadir bloque';

  @override
  String get blockMentionPageSubtitle => 'Mencionar página';

  @override
  String get blockTypesSheetTitle => 'Tipos de bloque';

  @override
  String get blockTypesSheetSubtitle => 'Elige cómo se verá este bloque';

  @override
  String get blockTypeFilterEmpty => 'Nada coincide con tu búsqueda';

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
  String get openInYoutubeBrowser => 'Abrir en el navegador';

  @override
  String get pasteUrlTitle => 'Pegar enlace como';

  @override
  String get pasteAsUrl => 'URL';

  @override
  String get pasteAsEmbed => 'Insertar';

  @override
  String get pasteAsBookmark => 'Marcador';

  @override
  String get pasteAsMention => 'Mención';

  @override
  String get pasteAsUrlSubtitle => 'Insertar enlace markdown en el texto';

  @override
  String get pasteAsEmbedSubtitle =>
      'Bloque vídeo con vista previa (YouTube) o marcador';

  @override
  String get pasteAsBookmarkSubtitle => 'Tarjeta con título y enlace';

  @override
  String get pasteAsMentionSubtitle => 'Enlace a una página de esta libreta';

  @override
  String get tableAddRow => 'Fila';

  @override
  String get tableRemoveRow => 'Quitar fila';

  @override
  String get tableAddColumn => 'Columna';

  @override
  String get tableRemoveColumn => 'Quitar col.';

  @override
  String get tablePasteFromClipboard => 'Pegar tabla';

  @override
  String get pickPageForMention => 'Elegir página';

  @override
  String get bookmarkTitleHint => 'Título';

  @override
  String get bookmarkOpenLink => 'Abrir enlace';

  @override
  String get bookmarkSetUrl => 'Establecer URL…';

  @override
  String get bookmarkBlockHint => 'Pega un enlace o usa el menú del bloque';

  @override
  String get bookmarkRemove => 'Quitar marcador';

  @override
  String get embedUnavailable =>
      'La vista web embebida no está disponible en esta plataforma. Abre el enlace en el navegador.';

  @override
  String get embedOpenBrowser => 'Abrir en el navegador';

  @override
  String get embedSetUrl => 'Establecer URL del inserto…';

  @override
  String get embedRemove => 'Quitar inserto';

  @override
  String get embedEmptyHint =>
      'Pega un enlace o establece la URL desde el menú del bloque';

  @override
  String get blockSizeSmaller => 'Más pequeño';

  @override
  String get blockSizeLarger => 'Más grande';

  @override
  String get blockSizeHalf => '50%';

  @override
  String get blockSizeThreeQuarter => '75%';

  @override
  String get blockSizeFull => '100%';

  @override
  String get pasteAsEmbedSubtitleWeb =>
      'Mostrar la página dentro del bloque (si el sistema lo permite)';

  @override
  String get pasteAsMentionSubtitleRich =>
      'Enlace con título de la página (p. ej. YouTube)';

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
      'La libreta se guarda en seguida; el historial añade una entrada cuando dejas de editar y el contenido cambió.';

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
  String get aiAssistantTitle => 'Quill';

  @override
  String get aiNoPageSelected => 'Sin página seleccionada';

  @override
  String get aiChatContextDisabledSubtitle =>
      'No se envía texto de páginas al modelo';

  @override
  String aiChatContextUsesCurrentPage(Object title) {
    return 'Contexto: página actual ($title)';
  }

  @override
  String get aiChatContextOnePageFallback => 'Contexto: 1 página';

  @override
  String aiChatContextNPages(int count) {
    return '$count páginas en el contexto del chat';
  }

  @override
  String get aiChatPageContextTooltip =>
      'Incluir texto de páginas en el contexto del modelo';

  @override
  String get aiChatChooseContextPagesTooltip =>
      'Elegir qué páginas aportan texto al contexto';

  @override
  String get aiChatContextPagesDialogTitle => 'Páginas en el contexto del chat';

  @override
  String get aiChatContextPagesClear => 'Vaciar lista';

  @override
  String get aiChatContextPagesApply => 'Aplicar';

  @override
  String get aiTypingSemantics => 'Quill está escribiendo';

  @override
  String get aiRenameChatTooltip => 'Renombrar chat';

  @override
  String get aiRenameChatDialogTitle => 'Título del chat';

  @override
  String get aiRenameChatLabel => 'Texto en la pestaña';

  @override
  String get quillWorkspaceTourTitle => 'Quill te puede acompañar aquí';

  @override
  String get quillWorkspaceTourBodyReady =>
      'Tienes el chat de Quill listo para preguntar, editar páginas y trabajar con contexto de notas.';

  @override
  String get quillWorkspaceTourBodyUnavailable =>
      'Aunque ahora no esté activa, Quill vive en este espacio de trabajo y puedes activarla más tarde desde Ajustes.';

  @override
  String get quillWorkspaceTourPointsTitle => 'Qué conviene saber';

  @override
  String get quillWorkspaceTourPointOne =>
      'Sirve tanto para conversar como para editar títulos y bloques.';

  @override
  String get quillWorkspaceTourPointTwo =>
      'Puede usar la página abierta o varias páginas como contexto.';

  @override
  String get quillWorkspaceTourPointThree =>
      'Si tocas un ejemplo de abajo, se rellenará el chat cuando Quill esté disponible.';

  @override
  String get quillWorkspaceTourExamplesTitle => 'Prueba con mensajes como';

  @override
  String get quillWorkspaceTourExampleOne =>
      'Explícame cómo organizar esta página.';

  @override
  String get quillWorkspaceTourExampleTwo =>
      'Usa estas dos páginas para hacer un resumen común.';

  @override
  String get quillWorkspaceTourExampleThree =>
      'Reescribe este bloque con un tono más claro.';

  @override
  String get quillTourDismiss => 'Entendido';

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
      'Empieza una conversación.\nQuill decidirá automáticamente qué hacer con tu mensaje.\nTambién puedes preguntar cómo usar Folio (atajos, ajustes, páginas o este chat).';

  @override
  String get aiChatEmptyFocusComposer => 'Escribe un mensaje';

  @override
  String get aiInputHint => 'Escribe tu mensaje. Quill actuará como agente.';

  @override
  String get aiInputHintCopilot => 'Escribe tu mensaje...';

  @override
  String get aiContextComposerHint => 'Sin contexto añadido';

  @override
  String get aiContextComposerHelper => 'Usa @ para añadir contexto';

  @override
  String aiContextCurrentPageChip(Object title) {
    return 'Página actual: $title';
  }

  @override
  String get aiContextCurrentPageFallback => 'Página actual';

  @override
  String get aiContextAddFile => 'Adjuntar archivo';

  @override
  String get aiContextAddPage => 'Adjuntar página';

  @override
  String get aiShowPanel => 'Mostrar panel IA';

  @override
  String get aiHidePanel => 'Ocultar panel IA';

  @override
  String get aiPanelResizeHandle => 'Redimensionar panel de IA';

  @override
  String get aiPanelResizeHandleHint =>
      'Arrastra horizontalmente para cambiar el ancho del asistente';

  @override
  String get importMarkdownPage => 'Importar Markdown';

  @override
  String get exportMarkdownPage => 'Exportar Markdown';

  @override
  String get workspaceUndoTooltip => 'Deshacer (Ctrl+Z)';

  @override
  String get workspaceRedoTooltip => 'Rehacer (Ctrl+Y)';

  @override
  String get workspaceMoreActionsTooltip => 'Más acciones';

  @override
  String get closeCurrentPage => 'Cerrar página actual';

  @override
  String aiErrorWithDetails(Object error) {
    return 'Error IA: $error';
  }

  @override
  String get aiServiceUnreachable =>
      'No se pudo conectar con el servicio de IA en el endpoint configurado. Inicia Ollama o LM Studio y revisa la URL.';

  @override
  String get aiLaunchProviderWithApp => 'Abrir app de IA al iniciar Folio';

  @override
  String get aiLaunchProviderWithAppHint =>
      'Intenta lanzar Ollama o LM Studio en Windows si el endpoint es localhost. En LM Studio puede hacer falta iniciar el servidor manualmente.';

  @override
  String get aiContextWindowTokens => 'Ventana de contexto del modelo (tokens)';

  @override
  String get aiContextWindowTokensHint =>
      'Sirve para la barra de contexto del chat. Ajústala a tu modelo (p. ej. 8192, 131072).';

  @override
  String get aiContextUsageUnavailable =>
      'El servidor no informó del uso de tokens en la última respuesta.';

  @override
  String aiContextUsageSummary(Object prompt, Object completion) {
    return 'Prompt $prompt · Salida $completion';
  }

  @override
  String aiContextUsageTooltip(int window) {
    return 'Última petición respecto a la ventana configurada ($window tokens).';
  }

  @override
  String get aiChatKeyboardHint => 'Enter para enviar · Ctrl+Enter nueva línea';

  @override
  String aiChatInkRemaining(int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: 'Quedan $total gotas de tinta',
      one: 'Queda 1 gota de tinta',
    );
    return '$_temp0';
  }

  @override
  String aiChatInkBreakdownTooltip(int monthly, int purchased) {
    return 'Mes $monthly · Compradas $purchased';
  }

  @override
  String get aiAgentThought => 'Pensamiento de Quill';

  @override
  String get aiAlwaysShowThought => 'Mostrar siempre pensamiento de IA';

  @override
  String get aiAlwaysShowThoughtHint =>
      'Si está desactivado, se mostrará plegado con flecha en cada mensaje.';

  @override
  String get aiBetaBadge => 'BETA';

  @override
  String get aiBetaEnableTitle => 'IA en fase BETA';

  @override
  String get aiBetaEnableBody =>
      'Esta funcionalidad está en fase BETA y puede fallar o comportarse de forma inesperada.\n\n¿Quieres activarla igualmente?';

  @override
  String get aiBetaEnableConfirm => 'Activar BETA';

  @override
  String get ai => 'IA';

  @override
  String get aiEnableToggleTitle => 'Activar IA';

  @override
  String get aiProviderLabel => 'Proveedor';

  @override
  String get aiProviderNone => 'Ninguno';

  @override
  String get aiEndpoint => 'Endpoint';

  @override
  String get aiModel => 'Modelo';

  @override
  String get aiTimeoutMs => 'Timeout (ms)';

  @override
  String get aiAllowRemoteEndpoint => 'Permitir endpoint remoto';

  @override
  String get aiAllowRemoteEndpointAllowed => 'Hosts remotos permitidos';

  @override
  String get aiAllowRemoteEndpointLocalhostOnly => 'Solo localhost';

  @override
  String get aiAllowRemoteEndpointNotConfirmed =>
      'El acceso a endpoints remotos está habilitado, pero todavía no se ha confirmado.';

  @override
  String get aiConnectToListModels => 'Conectar para listar modelos';

  @override
  String aiProviderAutoConfigured(Object provider) {
    return 'Proveedor IA detectado y configurado: $provider';
  }

  @override
  String get aiSetupAssistantTitle => 'Asistente de instalación IA';

  @override
  String get aiSetupAssistantSubtitle =>
      'Detecta y configura Ollama o LM Studio automáticamente.';

  @override
  String get aiSetupWizardTitle => 'Asistente IA';

  @override
  String get aiSetupChooseProviderTitle => 'Elige proveedor IA';

  @override
  String get aiSetupChooseProviderBody =>
      'Primero elige cuál quieres usar. Después te guiamos en su instalación y configuración.';

  @override
  String get aiSetupNoProviderTitle => 'No se detectó ningún proveedor activo';

  @override
  String get aiSetupNoProviderBody =>
      'No encontramos Ollama o LM Studio en ejecución y accesibles.\nSigue los pasos para instalar/iniciar uno de ellos y pulsa Reintentar.';

  @override
  String get aiSetupOllamaTitle => 'Paso 1: Instalar Ollama';

  @override
  String get aiSetupOllamaBody =>
      'Instala Ollama, ejecuta el servicio y verifica que responda en http://127.0.0.1:11434.';

  @override
  String get aiSetupLmStudioTitle => 'Paso 2: Instalar LM Studio';

  @override
  String get aiSetupLmStudioBody =>
      'Instala LM Studio, inicia su servidor local (OpenAI compatible) y verifica que responda en http://127.0.0.1:1234.';

  @override
  String get aiSetupOpenSettingsHint =>
      'Cuando uno de los proveedores esté operativo, pulsa Reintentar para autoconfigurarlo.';

  @override
  String get aiCompareCloudVsLocalTitle => 'Cloud vs local';

  @override
  String get aiCompareCloudTitle => 'Folio Cloud';

  @override
  String get aiCompareLocalTitle => 'Local (Ollama / LM Studio)';

  @override
  String get aiCompareCloudBulletNoSetup =>
      'Sin configuración local: funciona al iniciar sesión.';

  @override
  String get aiCompareCloudBulletNeedsSub =>
      'Requiere suscripción para IA en la nube.';

  @override
  String get aiCompareCloudBulletInk =>
      'Usa tinta para la IA en la nube (packs + recarga mensual).';

  @override
  String get aiCompareLocalBulletPrivacy => 'Privacidad local (tu equipo).';

  @override
  String get aiCompareLocalBulletNoInk => 'Sin tinta: no depende del saldo.';

  @override
  String get aiCompareLocalBulletSetup =>
      'Requiere instalar y arrancar un proveedor en localhost.';

  @override
  String get quillGlobalScopeNoticeTitle =>
      'Quill funciona en todas las libretas';

  @override
  String get quillGlobalScopeNoticeBody =>
      'Quill es un ajuste global de la app. Si lo activas ahora, quedará disponible para cualquier libreta en esta instalación, no solo para la actual.';

  @override
  String get quillGlobalScopeNoticeConfirm => 'Entiendo';

  @override
  String get searchByNameOrShortcut => 'Buscar por nombre o atajo…';

  @override
  String get search => 'Buscar';

  @override
  String get open => 'Abrir';

  @override
  String get exit => 'Salir';

  @override
  String get trayMenuCloseApplication => 'Cerrar aplicación';

  @override
  String get keyboardShortcutsSection => 'Teclado (en la app)';

  @override
  String get shortcutTestAction => 'Probar';

  @override
  String get shortcutChangeAction => 'Cambiar';

  @override
  String shortcutTestHint(Object combo) {
    return 'Con el foco fuera de un campo de texto, “$combo” debería funcionar en el escritorio.';
  }

  @override
  String get shortcutResetAllTitle => 'Restaurar atajos por defecto';

  @override
  String get shortcutResetAllSubtitle =>
      'Vuelve a poner todos los atajos de la app como al instalar Folio.';

  @override
  String get shortcutResetDoneSnack => 'Atajos restaurados.';

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
  String get searchAllVaultHint => 'Buscar en toda la libreta...';

  @override
  String get typeToSearch => 'Escribe para buscar';

  @override
  String get noSearchResults => 'Sin resultados';

  @override
  String get searchFilterAll => 'Todo';

  @override
  String get searchFilterTitles => 'Títulos';

  @override
  String get searchFilterContent => 'Contenido';

  @override
  String get searchSortRelevance => 'Relevancia';

  @override
  String get searchSortRecent => 'Recientes';

  @override
  String get settingsSearchSections => 'Buscar en ajustes';

  @override
  String get settingsSearchSectionsHint =>
      'Filtra categorías en la barra lateral';

  @override
  String get scheduledVaultBackupTitle => 'Copia cifrada programada';

  @override
  String get scheduledVaultBackupSubtitle =>
      'Con la libreta desbloqueada, cada copia es de la libreta abierta ahora. Folio guarda un ZIP en la carpeta indicada según el intervalo.';

  @override
  String get scheduledVaultBackupChooseFolder => 'Carpeta de copias';

  @override
  String get scheduledVaultBackupIntervalLabel => 'Intervalo (horas)';

  @override
  String scheduledVaultBackupLastRun(Object time) {
    return 'Última copia: $time';
  }

  @override
  String get scheduledVaultBackupSnackOk => 'Copia programada guardada.';

  @override
  String scheduledVaultBackupSnackFail(Object error) {
    return 'Error en la copia programada: $error';
  }

  @override
  String vaultBackupOpenVaultHint(String name) {
    return 'Las copias son de la libreta abierta ahora: «$name».';
  }

  @override
  String get vaultBackupRunNowTile => 'Copia programada ahora';

  @override
  String get vaultBackupRunNowSubtitle =>
      'Ejecuta ya la copia programada (disco y/o nube según lo tengas configurado), sin esperar al intervalo.';

  @override
  String get vaultBackupRunNowNeedFolder =>
      'Elige una carpeta local o activa «Subir también a Folio Cloud» para copia solo en la nube.';

  @override
  String get vaultIdentitySyncTitle => 'Sincronización';

  @override
  String get vaultIdentitySyncBody =>
      'Introduce la contraseña de la libreta (o Hello / passkey) para continuar.';

  @override
  String get vaultIdentityCloudBackupTitle => 'Copias en la nube';

  @override
  String get vaultIdentityCloudBackupBody =>
      'Confirma la identidad de la libreta para listar o descargar copias cifradas.';

  @override
  String get aiRewriteDialogTitle => 'Reescribir con IA';

  @override
  String get aiPreviewTitle => 'Vista previa';

  @override
  String get aiInstructionHint => 'Ejemplo: hazlo más claro y breve';

  @override
  String get aiApply => 'Aplicar';

  @override
  String get aiGenerating => 'Generando…';

  @override
  String get aiSummarizeSelection => 'Resumir con IA…';

  @override
  String get aiExtractTasksDates => 'Extraer tareas y fechas…';

  @override
  String get aiPreviewReadOnlyHint =>
      'Puedes editar el texto antes de aplicar.';

  @override
  String get aiRewriteApplied => 'Bloque actualizado.';

  @override
  String get aiUndoRewrite => 'Deshacer';

  @override
  String get aiInsertBelow => 'Insertar debajo';

  @override
  String get unlockVaultTitle => 'Desbloquear libreta';

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
      'Importa un ZIP exportado por Notion. Puedes añadirlo a la libreta actual o crear una nueva.';

  @override
  String get importNotionSelectTargetTitle => 'Destino de la importación';

  @override
  String get importNotionSelectTargetBody =>
      'Elige si quieres importar la exportacion de Notion en la libreta actual o crear una libreta nueva a partir de ella.';

  @override
  String get importNotionTargetCurrent => 'Libreta actual';

  @override
  String get importNotionTargetNew => 'Libreta nueva';

  @override
  String get importNotionDefaultVaultName => 'Importado desde Notion';

  @override
  String get importNotionNewVaultPasswordTitle =>
      'Contraseña para libreta nueva';

  @override
  String get importNotionSuccessCurrent =>
      'Notion importado en la libreta actual.';

  @override
  String get importNotionSuccessNew => 'Libreta nueva importada desde Notion.';

  @override
  String importNotionError(Object error) {
    return 'No se pudo importar Notion: $error';
  }

  @override
  String get importNotionWarningsTitle => 'Avisos de importación';

  @override
  String get importNotionWarningsBody =>
      'La importación finalizó con los siguientes avisos:';

  @override
  String get ok => 'Aceptar';

  @override
  String get notionExportGuideTitle => 'Como exportar desde Notion';

  @override
  String get notionExportGuideBody =>
      'En Notion, abre Settings -> Export all workspace content, elige HTML o Markdown y descarga el archivo ZIP. Luego usa esta opcion de importacion en Folio.';

  @override
  String get appBetaBannerMessage =>
      'Estás usando una versión beta. Puede haber fallos; haz copias de seguridad de la libreta con frecuencia.';

  @override
  String get appBetaBannerDismiss => 'Entendido';

  @override
  String get integrations => 'Integraciones';

  @override
  String get integrationsAppsApprovedHint =>
      'Las apps externas aprobadas pueden usar el puente de integracion local.';

  @override
  String get integrationsAppsApprovedTitle => 'Apps externas aprobadas';

  @override
  String get integrationsAppsApprovedNone =>
      'Todavia no has aprobado ninguna app externa.';

  @override
  String get integrationsAppsApprovedRevoke => 'Revocar acceso';

  @override
  String integrationsApprovedAppDetails(
    Object appId,
    Object appVersion,
    Object integrationVersion,
  ) {
    return '$appId · App $appVersion · Integracion $integrationVersion';
  }

  @override
  String get integrationApprovalTitle => 'Aprobar integracion externa';

  @override
  String get integrationApprovalUpdateTitle =>
      'Aprobar actualizacion de integracion';

  @override
  String integrationApprovalBody(
    Object appName,
    Object appVersion,
    Object integrationVersion,
  ) {
    return '\"$appName\" quiere conectarse a Folio usando la version $appVersion de la app y la version $integrationVersion de la integracion.';
  }

  @override
  String integrationApprovalUpdateBody(
    Object appName,
    Object previousVersion,
    Object integrationVersion,
  ) {
    return '\"$appName\" ya habia sido aprobada con la version $previousVersion de la integracion. Ahora quiere conectarse con la version $integrationVersion de la integracion, asi que Folio necesita tu aprobacion otra vez.';
  }

  @override
  String get integrationApprovalUnknownVersion => 'desconocida';

  @override
  String get integrationApprovalAppId => 'ID de la app';

  @override
  String get integrationApprovalAppVersion => 'Version de la app';

  @override
  String get integrationApprovalProtocolVersion => 'Version de la integracion';

  @override
  String get integrationApprovalCanDoTitle =>
      'Lo que esta integracion puede hacer';

  @override
  String get integrationApprovalCanDoSessions =>
      'Crear sesiones efimeras de importacion en Folio.';

  @override
  String get integrationApprovalCanDoImport =>
      'Enviar documentacion en Markdown para crear o actualizar paginas mediante el puente de importacion.';

  @override
  String get integrationApprovalCanDoMetadata =>
      'Guardar trazas de importacion como la app cliente, la sesion y metadatos de origen en las paginas importadas.';

  @override
  String get integrationApprovalCanDoUnlockedVault =>
      'Importar solo mientras la libreta este disponible y la peticion incluya el secreto configurado.';

  @override
  String get integrationApprovalCannotDoTitle => 'Lo que no puede hacer';

  @override
  String get integrationApprovalCannotDoRead =>
      'No puede leer el contenido de tu libreta a traves de este puente.';

  @override
  String get integrationApprovalCannotDoBypassLock =>
      'No puede saltarse el bloqueo de la libreta, el cifrado ni tu aprobacion explicita.';

  @override
  String get integrationApprovalCannotDoWithoutSecret =>
      'No puede acceder a endpoints protegidos sin el secreto compartido.';

  @override
  String get integrationApprovalCannotDoRemoteAccess =>
      'No puede usar el puente desde fuera de localhost.';

  @override
  String get integrationApprovalDeny => 'Denegar';

  @override
  String get integrationApprovalApprove => 'Aprobar';

  @override
  String get integrationApprovalApproveUpdate => 'Aprobar esta actualizacion';

  @override
  String get about => 'Acerca de';

  @override
  String get installedVersion => 'Version instalada';

  @override
  String get updaterGithubRepository => 'Repositorio de actualizaciones';

  @override
  String get updaterBetaDescription =>
      'Las betas son releases de GitHub marcadas como pre-release.';

  @override
  String get updaterStableDescription =>
      'Solo se tiene en cuenta la ultima release estable.';

  @override
  String get checkUpdates => 'Buscar actualizaciones';

  @override
  String get noEncryptionConfirmTitle => 'Crear libreta sin cifrado';

  @override
  String get noEncryptionConfirmBody =>
      'Tus datos se guardarán sin contraseña y sin cifrado. Cualquier persona con acceso a este dispositivo podrá leerlos.';

  @override
  String get createVaultWithoutEncryption => 'Crear sin cifrado';

  @override
  String get plainVaultSecurityNotice =>
      'Esta libreta no está cifrada: no aplican la passkey, el desbloqueo rápido (Hello), el bloqueo por inactividad, el bloqueo al minimizar ni la contraseña maestra.';

  @override
  String get encryptPlainVaultTitle => 'Cifrar esta libreta';

  @override
  String get encryptPlainVaultBody =>
      'Elige una contraseña maestra. Todo lo guardado en este dispositivo se cifrará. Si la olvidas, no podremos recuperar los datos.';

  @override
  String get encryptPlainVaultConfirm => 'Cifrar libreta';

  @override
  String get encryptPlainVaultSuccessSnack => 'La libreta ya está cifrada';

  @override
  String get aiCopyMessage => 'Copiar';

  @override
  String get aiCopyCode => 'Copiar código';

  @override
  String get aiCopiedToClipboard => 'Copiado al portapapeles';

  @override
  String get aiHelpful => 'Útil';

  @override
  String get aiNotHelpful => 'No útil';

  @override
  String get aiThinkingMessage => 'Quill está pensando...';

  @override
  String get aiMessageTimestampNow => 'ahora';

  @override
  String aiMessageTimestampMinutes(int n) {
    return 'hace $n min';
  }

  @override
  String aiMessageTimestampHours(int n) {
    return 'hace $n h';
  }

  @override
  String aiMessageTimestampDays(int n) {
    return 'hace $n días';
  }

  @override
  String get templateGalleryTitle => 'Plantillas de página';

  @override
  String get templateImport => 'Importar';

  @override
  String get templateImportPickTitle => 'Seleccionar archivo de plantilla';

  @override
  String get templateImportSuccess => 'Plantilla importada';

  @override
  String templateImportError(Object error) {
    return 'Error al importar: $error';
  }

  @override
  String get templateExportPickTitle => 'Guardar archivo de plantilla';

  @override
  String get templateExportSuccess => 'Plantilla exportada';

  @override
  String templateExportError(Object error) {
    return 'Error al exportar: $error';
  }

  @override
  String get templateSearchHint => 'Buscar plantillas...';

  @override
  String get templateEmptyHint =>
      'Sin plantillas.\nGuarda una página como plantilla o importa una.';

  @override
  String templateBlockCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'bloques',
      one: 'bloque',
    );
    return '$count $_temp0';
  }

  @override
  String get templateUse => 'Usar plantilla';

  @override
  String get templateExport => 'Exportar';

  @override
  String get templateBlankPage => 'Página en blanco';

  @override
  String get templateFromGallery => 'Desde plantilla…';

  @override
  String get saveAsTemplate => 'Guardar como plantilla';

  @override
  String get saveAsTemplateTitle => 'Guardar como plantilla';

  @override
  String get templateNameHint => 'Nombre de plantilla';

  @override
  String get templateDescriptionHint => 'Descripción (opcional)';

  @override
  String get templateCategoryHint => 'Categoría (opcional)';

  @override
  String get templateSaved => 'Guardado como plantilla';

  @override
  String templateCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'plantillas',
      one: 'plantilla',
    );
    return '$count $_temp0';
  }

  @override
  String templateFilteredCount(int visible, int total) {
    return 'Mostrando $visible de $total plantillas';
  }

  @override
  String get templateSortRecent => 'Más recientes';

  @override
  String get templateSortName => 'Nombre';

  @override
  String get templateEdit => 'Editar plantilla';

  @override
  String get templateUpdated => 'Plantilla actualizada';

  @override
  String get templateDeleteConfirmTitle => 'Eliminar plantilla';

  @override
  String templateDeleteConfirmBody(Object name) {
    return 'La plantilla \"$name\" se eliminará de esta libreta.';
  }

  @override
  String templateCreatedOn(Object date) {
    return 'Creada $date';
  }

  @override
  String get templatePreviewEmpty =>
      'Esta plantilla todavía no tiene vista previa de texto.';

  @override
  String get templateSelectHint =>
      'Selecciona una plantilla para inspeccionarla, editar sus metadatos o exportarla.';

  @override
  String get clear => 'Limpiar';

  @override
  String get cloudAccountSectionTitle => 'Cuenta Folio Cloud';

  @override
  String get cloudAccountSectionDescription =>
      'Opcional. Inicia sesión para suscribirte a copias en la nube, IA hospedada y publicación web. Tu libreta sigue siendo local salvo que uses esas funciones.';

  @override
  String get cloudAccountChipOptional => 'Opcional';

  @override
  String get cloudAccountChipPaidCloud => 'Copias, IA y web';

  @override
  String get cloudAccountUnavailable =>
      'No hay inicio de sesión en la nube (Firebase no arrancó). Revisa la conexión o ejecuta flutterfire configure con tu proyecto.';

  @override
  String get cloudAccountEmailLabel => 'Correo';

  @override
  String get cloudAccountPasswordLabel => 'Contraseña';

  @override
  String get cloudAccountSignIn => 'Iniciar sesión';

  @override
  String get cloudAccountCreateAccount => 'Crear cuenta';

  @override
  String get cloudAccountForgotPassword => '¿Olvidaste la contraseña?';

  @override
  String get cloudAccountSignOut => 'Cerrar sesión';

  @override
  String cloudAccountSignedInAs(Object email) {
    return 'Sesión iniciada como $email';
  }

  @override
  String cloudAccountUid(Object uid) {
    return 'ID de usuario: $uid';
  }

  @override
  String get cloudAuthDialogTitleSignIn => 'Iniciar sesión en Folio Cloud';

  @override
  String get cloudAuthDialogTitleRegister => 'Crear cuenta de Folio Cloud';

  @override
  String get cloudAuthDialogTitleReset => 'Restablecer contraseña';

  @override
  String get cloudPasswordResetSent =>
      'Si existe una cuenta con ese correo, se envió un enlace de restablecimiento.';

  @override
  String get cloudAuthErrorInvalidEmail => 'Ese correo no es válido.';

  @override
  String get cloudAuthErrorWrongPassword => 'Contraseña incorrecta.';

  @override
  String get cloudAuthErrorUserNotFound => 'No hay cuenta con ese correo.';

  @override
  String get cloudAuthErrorUserDisabled => 'Esta cuenta está deshabilitada.';

  @override
  String get cloudAuthErrorEmailAlreadyInUse =>
      'Ese correo ya está registrado.';

  @override
  String get cloudAuthErrorWeakPassword => 'La contraseña es demasiado débil.';

  @override
  String get cloudAuthErrorInvalidCredential =>
      'Correo o contraseña no válidos.';

  @override
  String get cloudAuthErrorNetwork => 'Error de red. Comprueba la conexión.';

  @override
  String get cloudAuthErrorTooManyRequests =>
      'Demasiados intentos. Prueba más tarde.';

  @override
  String get cloudAuthErrorOperationNotAllowed =>
      'Este método de inicio de sesión no está habilitado en Firebase.';

  @override
  String get cloudAuthErrorGeneric =>
      'No se pudo iniciar sesión. Inténtalo de nuevo.';

  @override
  String get cloudAuthDialogTitle => 'Folio Cloud';

  @override
  String get cloudAuthSubtitleSignIn =>
      'Usa el correo y la contraseña de Folio Cloud. Nada de esto cambia tu libreta local.';

  @override
  String get cloudAuthSubtitleRegister =>
      'Crea credenciales para Folio Cloud. Tus notas en este dispositivo no se suben hasta que actives copias u otras funciones de pago.';

  @override
  String get cloudAuthModeSignIn => 'Iniciar sesión';

  @override
  String get cloudAuthModeRegister => 'Registrarse';

  @override
  String get cloudAuthConfirmPasswordLabel => 'Confirmar contraseña';

  @override
  String get cloudAuthValidationRequired => 'Este campo es obligatorio.';

  @override
  String get cloudAuthValidationPasswordShort => 'Usa al menos 6 caracteres.';

  @override
  String get cloudAuthValidationConfirmMismatch =>
      'Las contraseñas no coinciden.';

  @override
  String get cloudAccountSignedOutPrompt =>
      'Inicia sesión o regístrate para suscribirte a Folio Cloud y usar copias, IA en la nube y publicación.';

  @override
  String get cloudAuthResetHint =>
      'Te enviaremos un enlace por correo para elegir una nueva contraseña.';

  @override
  String get cloudAccountEmailVerified => 'Verificado';

  @override
  String get cloudAccountSignOutHelp =>
      'Tu libreta local sigue en este dispositivo.';

  @override
  String get folioCloudSubsectionPlan => 'Plan y estado';

  @override
  String get folioCloudSubsectionInk => 'Saldo de tinta';

  @override
  String get folioCloudSubsectionSubscription => 'Suscripción y facturación';

  @override
  String get folioCloudSubsectionBackupPublish => 'Copias y publicación';

  @override
  String get folioCloudSubscriptionActive => 'Suscripción activa';

  @override
  String folioCloudSubscriptionActiveWithStatus(String status) {
    return 'Suscripción activa ($status)';
  }

  @override
  String get folioCloudSubscriptionNoneTitle => 'Sin suscripción Folio Cloud';

  @override
  String get folioCloudSubscriptionNoneSubtitle =>
      'Activa un plan para copias cifradas, IA en la nube y publicación web.';

  @override
  String get folioCloudFeatureBackup => 'Copia en la nube';

  @override
  String get folioCloudFeatureCloudAi => 'IA en la nube';

  @override
  String get folioCloudFeaturePublishWeb => 'Publicación web';

  @override
  String get folioCloudFeatureOn => 'Incluida';

  @override
  String get folioCloudFeatureOff => 'No incluida';

  @override
  String get folioCloudPostPaymentHint =>
      'Si acabas de pagar y ves las funciones en «no», pulsa «Actualizar desde Stripe».';

  @override
  String get folioCloudBackupCleanupWarning =>
      'Copia subida, pero no se pudo limpiar copias antiguas (se reintentará más tarde).';

  @override
  String get folioCloudInkMonthly => 'Mes';

  @override
  String get folioCloudInkPurchased => 'Compradas';

  @override
  String get folioCloudInkTotal => 'Total';

  @override
  String folioCloudInkCount(int count) {
    return '$count';
  }

  @override
  String get folioCloudPlanActiveHeadline => 'Plan mensual Folio Cloud activo';

  @override
  String get folioCloudSubscribeMonthly => 'Folio Cloud 4,99 €/mes';

  @override
  String get folioCloudBuyInk => 'Comprar tinta';

  @override
  String get folioCloudInkSmall => 'Tintero pequeño (1,99 €)';

  @override
  String get folioCloudInkMedium => 'Tintero mediano (4,99 €)';

  @override
  String get folioCloudInkLarge => 'Tintero grande (9,99 €)';

  @override
  String get folioCloudManageSubscription => 'Gestionar suscripción';

  @override
  String get folioCloudRefreshFromStripe => 'Actualizar';

  @override
  String get folioCloudUploadEncryptedBackup => 'Copia a la nube ahora';

  @override
  String get folioCloudUploadEncryptedBackupSubtitle =>
      'Folio genera la copia cifrada de la libreta abierta y la sube solo; no tienes que exportar un .zip.';

  @override
  String get folioCloudUploadSnackOk =>
      'Copia de la libreta guardada en la nube.';

  @override
  String get scheduledVaultBackupCloudSyncTitle =>
      'Subir también a Folio Cloud';

  @override
  String get scheduledVaultBackupCloudSyncSubtitle =>
      'Tras cada copia programada, sube automáticamente el mismo ZIP a tu cuenta. Si no quieres copia en disco, deja la carpeta sin elegir y activa solo esta opción.';

  @override
  String get folioCloudCloudBackupsList => 'Copias en la nube';

  @override
  String get folioCloudBackupsUsed => 'Usadas';

  @override
  String get folioCloudBackupsLimit => 'Límite';

  @override
  String get folioCloudBackupsRemaining => 'Restantes';

  @override
  String get folioCloudPublishTestPage => 'Publicar página de prueba';

  @override
  String get folioCloudPublishedPagesList => 'Páginas publicadas';

  @override
  String get folioCloudReauthDialogTitle => 'Confirmar cuenta Folio Cloud';

  @override
  String get folioCloudReauthDialogBody =>
      'Introduce la contraseña de tu cuenta Folio Cloud (la del inicio de sesión en la nube) para listar y descargar copias. No es la contraseña de la libreta local.';

  @override
  String get folioCloudReauthRequiresPasswordProvider =>
      'Esta sesión no usa contraseña de Folio Cloud. Cierra sesión en la cuenta e inicia de nuevo con correo y contraseña si necesitas descargar copias.';

  @override
  String get folioCloudAiNoInkTitle => 'Sin tinta para la IA en la nube';

  @override
  String get folioCloudAiNoInkBody =>
      'Puedes comprar un tintero en Folio Cloud, esperar la recarga mensual o cambiar a IA local (Ollama o LM Studio) en la sección de IA de Ajustes.';

  @override
  String get folioCloudAiNoInkActionCloud => 'Folio Cloud y tinta';

  @override
  String get folioCloudAiNoInkActionLocal => 'Proveedor de IA';

  @override
  String get folioCloudAiZeroInkBanner =>
      'Tinta de IA en la nube: 0 gotas. Abre Ajustes para comprar tinta o usar IA local.';

  @override
  String folioCloudInkPurchaseAppliedHint(Object purchased) {
    return 'Compra aplicada: $purchased gotas compradas disponibles para IA en la nube.';
  }

  @override
  String get onboardingCloudBackupCta => 'Iniciar sesión y descargar copia';

  @override
  String get onboardingCloudBackupPickVaultSubtitle =>
      'Elige qué libreta quieres restaurar.';

  @override
  String get onboardingFolioCloudTitle => 'Folio Cloud';

  @override
  String get onboardingFolioCloudBody =>
      'Activa funciones en la nube cuando las necesites: copias cifradas, Quill hospedada y publicación web. Tu libreta sigue siendo local salvo que uses estas funciones.';

  @override
  String get onboardingFolioCloudFeatureBackupTitle =>
      'Copias cifradas en la nube';

  @override
  String get onboardingFolioCloudFeatureBackupBody =>
      'Guarda y descarga copias de la libreta desde tu cuenta. En escritorio, listar/descargar se hace desde Folio Cloud.';

  @override
  String get onboardingFolioCloudFeatureAiTitle => 'IA en la nube + tinta';

  @override
  String get onboardingFolioCloudFeatureAiBody =>
      'Quill funciona en Folio Cloud con suscripción. La tinta se consume por uso; también puedes usar IA local (Ollama/LM Studio).';

  @override
  String get onboardingFolioCloudFeatureWebTitle => 'Publicación web';

  @override
  String get onboardingFolioCloudFeatureWebBody =>
      'Publica páginas seleccionadas y controla qué se hace público. El resto de la libreta no se comparte.';

  @override
  String get onboardingFolioCloudLaterInSettings => 'Lo veré en Ajustes';
}
