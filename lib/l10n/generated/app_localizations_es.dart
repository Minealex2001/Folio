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
  String get pasteAsMentionSubtitle => 'Enlace a una página de este cofre';

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
  String get aiInputHint => 'Escribe tu mensaje. Quill actuará como agente.';

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
      'El acceso a endpoints remotos esta habilitado, pero todavia no se ha confirmado.';

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
  String get quillGlobalScopeNoticeTitle =>
      'Quill funciona en todos los cofres';

  @override
  String get quillGlobalScopeNoticeBody =>
      'Quill es un ajuste global de la app. Si lo activas ahora, quedará disponible para cualquier cofre en esta instalación, no solo para el actual.';

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
  String get importNotionSelectTargetBody =>
      'Elige si quieres importar la exportacion de Notion en el cofre actual o crear un cofre nuevo a partir de ella.';

  @override
  String get importNotionTargetCurrent => 'Cofre actual';

  @override
  String get importNotionTargetNew => 'Cofre nuevo';

  @override
  String get importNotionDefaultVaultName => 'Importado desde Notion';

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

  @override
  String get notionExportGuideTitle => 'Como exportar desde Notion';

  @override
  String get notionExportGuideBody =>
      'En Notion, abre Settings -> Export all workspace content, elige HTML o Markdown y descarga el archivo ZIP. Luego usa esta opcion de importacion en Folio.';

  @override
  String get appBetaBannerMessage =>
      'Estás usando una versión beta. Puede haber fallos; haz copias de seguridad del cofre con frecuencia.';

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
      'Importar solo mientras el cofre este disponible y la peticion incluya el secreto configurado.';

  @override
  String get integrationApprovalCannotDoTitle => 'Lo que no puede hacer';

  @override
  String get integrationApprovalCannotDoRead =>
      'No puede leer el contenido de tu cofre a traves de este puente.';

  @override
  String get integrationApprovalCannotDoBypassLock =>
      'No puede saltarse el bloqueo del cofre, el cifrado ni tu aprobacion explicita.';

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
  String get noEncryptionConfirmTitle => 'Crear cofre sin cifrado';

  @override
  String get noEncryptionConfirmBody =>
      'Tus datos se guardarán sin contraseña y sin cifrado. Cualquier persona con acceso a este dispositivo podrá leerlos.';

  @override
  String get createVaultWithoutEncryption => 'Crear sin cifrado';

  @override
  String get plainVaultSecurityNotice =>
      'Este cofre no está cifrado: no aplican la passkey, el desbloqueo rápido (Hello), el bloqueo por inactividad, el bloqueo al minimizar ni la contraseña maestra.';

  @override
  String get encryptPlainVaultTitle => 'Cifrar este cofre';

  @override
  String get encryptPlainVaultBody =>
      'Elige una contraseña maestra. Todo lo guardado en este dispositivo se cifrará. Si la olvidas, no podremos recuperar los datos.';

  @override
  String get encryptPlainVaultConfirm => 'Cifrar cofre';

  @override
  String get encryptPlainVaultSuccessSnack => 'El cofre ya está cifrado';
}
