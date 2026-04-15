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
  String get brazilianPortugueseLanguage => 'Portugués (Brasil)';

  @override
  String get catalanLanguage => 'Catalán / Valenciano';

  @override
  String get galicianLanguage => 'Gallego';

  @override
  String get basqueLanguage => 'Euskera';

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
  String get quickUnlockEnableFailed =>
      'No se pudo activar el desbloqueo rápido.';

  @override
  String get passkeyRevokeConfirmTitle => '¿Quitar la passkey?';

  @override
  String get passkeyRevokeConfirmBody =>
      'Necesitarás la contraseña maestra para desbloquear hasta que registres una passkey nueva en este dispositivo.';

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
  String get meetingNoteTitle => 'Nota de reunión';

  @override
  String get meetingNoteDesktopOnly => 'Solo disponible en escritorio.';

  @override
  String get meetingNoteStartRecording => 'Iniciar grabación';

  @override
  String get meetingNotePreparing => 'Preparando…';

  @override
  String get meetingNoteTranscriptionLanguage => 'Idioma de transcripción';

  @override
  String get meetingNoteLangAuto => 'Automático';

  @override
  String get meetingNoteLangEs => 'Español';

  @override
  String get meetingNoteLangEn => 'Inglés';

  @override
  String get meetingNoteLangPt => 'Portugués';

  @override
  String get meetingNoteLangFr => 'Francés';

  @override
  String get meetingNoteLangIt => 'Italiano';

  @override
  String get meetingNoteLangDe => 'Alemán';

  @override
  String get meetingNoteDevicesInSettings =>
      'Los dispositivos de entrada/salida se configuran en Ajustes > Escritorio.';

  @override
  String meetingNoteModelInSettings(Object model) {
    return 'Modelo de transcripción: $model (en Ajustes > Escritorio).';
  }

  @override
  String get meetingNoteDescription =>
      'Graba micrófono y audio del sistema. La transcripción se genera localmente.';

  @override
  String meetingNoteWhisperInitError(Object error) {
    return 'No se pudo inicializar Whisper: $error';
  }

  @override
  String get meetingNoteAudioAccessError =>
      'No se pudo acceder al micrófono/dispositivos.';

  @override
  String get meetingNoteMicrophoneAccessError =>
      'No se pudo acceder al micrófono.';

  @override
  String get meetingNoteChunkTranscriptionError =>
      'No se pudo transcribir este fragmento de audio.';

  @override
  String get meetingNoteProviderLocal => 'Local (Whisper)';

  @override
  String get meetingNoteProviderCloud => 'Quill Cloud';

  @override
  String get meetingNoteProviderCloudCost => '1 Tinta por cada 5 min. grabados';

  @override
  String get meetingNoteCloudFallbackNotice =>
      'Cloud no disponible. Usando Whisper local.';

  @override
  String get meetingNoteCloudInkExhaustedNotice =>
      'Tinta insuficiente. Cambiando a Whisper local.';

  @override
  String meetingNoteCloudRecordingBadge(Object language) {
    return 'Quill Cloud | Idioma: $language';
  }

  @override
  String get meetingNoteCloudProcessing => 'Procesando con Quill Cloud…';

  @override
  String get meetingNoteCloudProcessingSubtitle =>
      'Detectando hablantes y mejorando calidad. Un momento.';

  @override
  String meetingNoteCloudProgress(int done, int total) {
    return 'Segmentos procesados: $done/$total';
  }

  @override
  String meetingNoteCloudEta(Object remaining) {
    return 'Tiempo restante estimado: $remaining';
  }

  @override
  String get meetingNoteCloudEtaCalculating => 'Calculando tiempo restante...';

  @override
  String get meetingNoteCloudRequiresAccount =>
      'Requiere cuenta Folio Cloud con Tinta.';

  @override
  String get meetingNoteCloudRequiresAiEnabled =>
      'Activa la IA en Ajustes para usar la transcripción en la nube (Quill Cloud).';

  @override
  String meetingNoteHardwareSummary(int cpus, Object ramLabel) {
    return '$cpus núcleos · $ramLabel';
  }

  @override
  String get meetingNoteHardwareRamUnknown => 'RAM desconocida';

  @override
  String meetingNoteHardwareRecommended(Object modelLabel) {
    return 'Modelo recomendado para este equipo: $modelLabel';
  }

  @override
  String get meetingNoteLocalTranscriptionNotViable =>
      'Este equipo no cumple los requisitos mínimos para transcripción local. Solo se guardará el audio, salvo que actives «Forzar transcripción local» en Ajustes o uses Quill Cloud con IA activada.';

  @override
  String get meetingNoteGenerateTranscription => 'Generar transcripción';

  @override
  String get meetingNoteGenerateTranscriptionSubtitle =>
      'Desactívalo para guardar solo el audio en esta nota.';

  @override
  String get meetingNoteSettingsAutoWhisperModel =>
      'Elegir modelo automáticamente según el hardware';

  @override
  String get meetingNoteSettingsForceLocalTranscription =>
      'Forzar transcripción local (puede ir lento o inestable)';

  @override
  String get meetingNoteSettingsHardwareIntro =>
      'Rendimiento detectado para transcripción local.';

  @override
  String get meetingNoteRecordingAudioOnlyBadge => 'Solo audio';

  @override
  String get meetingNotePerNoteTranscriptionOffHint =>
      'La transcripción está desactivada para esta nota.';

  @override
  String get meetingNoteTranscriptionProvider => 'Motor de transcripción';

  @override
  String meetingNoteRecordingTime(Object mm, Object ss) {
    return 'Grabando  $mm:$ss';
  }

  @override
  String meetingNoteRecordingBadge(Object language, Object model) {
    return 'Idioma: $language | Modelo: $model';
  }

  @override
  String get meetingNoteSystemAudioCaptured => 'Audio del sistema capturado';

  @override
  String get meetingNoteStop => 'Detener';

  @override
  String get meetingNoteWaitingTranscription => 'Esperando transcripción…';

  @override
  String get meetingNoteTranscribing => 'Transcribiendo…';

  @override
  String get meetingNoteTranscriptionTitle => 'Transcripción';

  @override
  String get meetingNoteNoTranscription => 'Sin transcripción disponible.';

  @override
  String get meetingNoteNewRecording => 'Nueva grabación';

  @override
  String get meetingNoteSettingsSection => 'Nota de reunión (audio)';

  @override
  String get meetingNoteSettingsDescription =>
      'Estos dispositivos se usan por defecto al grabar una nota de reunión.';

  @override
  String get meetingNoteSettingsMicrophone => 'Micrófono';

  @override
  String get meetingNoteSettingsRefreshDevices => 'Actualizar lista';

  @override
  String get meetingNoteSettingsSystemDefault => 'Predeterminado del sistema';

  @override
  String get meetingNoteSettingsSystemOutput => 'Salida del sistema (loopback)';

  @override
  String get meetingNoteSettingsModel => 'Modelo de transcripción';

  @override
  String get meetingNoteDiarizationHint =>
      'Procesamiento 100% local en tu dispositivo.';

  @override
  String get meetingNoteModelTiny => 'Rápido';

  @override
  String get meetingNoteModelBase => 'Equilibrado';

  @override
  String get meetingNoteModelSmall => 'Preciso';

  @override
  String get meetingNoteModelMedium => 'Avanzado';

  @override
  String get meetingNoteModelTurbo => 'Máxima calidad';

  @override
  String get meetingNoteCopyTranscript => 'Copiar transcripción';

  @override
  String get meetingNoteSendToAi => 'Enviar a IA…';

  @override
  String get meetingNoteAiPayloadLabel => '¿Qué enviar a la IA?';

  @override
  String get meetingNoteAiPayloadTranscript => 'Solo transcripción';

  @override
  String get meetingNoteAiPayloadAudio => 'Solo audio';

  @override
  String get meetingNoteAiPayloadBoth => 'Transcripción + audio';

  @override
  String get meetingNoteAiInstructionHint => 'p. ej. resume los puntos clave';

  @override
  String get meetingNoteAiNoAudio => 'No hay audio disponible para este modo';

  @override
  String get meetingNoteAiInstruction => 'Instrucción para la IA';

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
  String get formatToolbarScrollPrevious => 'Ver herramientas anteriores';

  @override
  String get formatToolbarScrollNext => 'Ver más herramientas';

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
  String get exportPage => 'Exportar…';

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
      'Instala LM Studio, inicia su servidor local y verifica que responda en http://127.0.0.1:1234.';

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
      'Suscripción con IA en la nube o tinta comprada.';

  @override
  String get aiCompareCloudBulletInk =>
      'Usa tinta para la IA en la nube (packs + recarga mensual).';

  @override
  String get aiProviderFolioCloudBlockedSnack =>
      'Necesitas suscripción Folio Cloud con IA en la nube o comprar tinta en Ajustes → Folio Cloud.';

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
  String get scheduledVaultBackupIntervalLabel => 'Intervalo entre copias';

  @override
  String scheduledVaultBackupEveryNMinutes(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n minutos',
      one: '1 minuto',
    );
    return '$_temp0';
  }

  @override
  String scheduledVaultBackupEveryNHours(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n horas',
      one: '1 hora',
    );
    return '$_temp0';
  }

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
  String vaultBackupDiskSizeApprox(String size) {
    return 'Tamaño aproximado en disco: $size';
  }

  @override
  String get vaultBackupDiskSizeLoading => 'Calculando tamaño en disco…';

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
  String get integrationApprovalEncryptedChip => 'Contenido cifrado (v2)';

  @override
  String get integrationApprovalUnencryptedChip => 'Contenido en claro (v1)';

  @override
  String get integrationApprovalEncryptedTitle =>
      'Version 2: cifrado obligatorio de contenido';

  @override
  String get integrationApprovalEncryptedDescription =>
      'Esta version exige payload cifrado para importar y actualizar contenido mediante el bridge local.';

  @override
  String get integrationApprovalUnencryptedTitle =>
      'Version 1: contenido sin cifrar';

  @override
  String get integrationApprovalUnencryptedDescription =>
      'Esta version permite payload en claro para contenido. Si quieres cifrado en tránsito, actualiza la integracion a la version 2.';

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
  String get templateGalleryTabLocal => 'Locales';

  @override
  String get templateGalleryTabCommunity => 'Comunidad';

  @override
  String get templateCommunitySignInCta =>
      'Inicia sesión para compartir y explorar plantillas de la comunidad.';

  @override
  String get templateCommunitySignInButton => 'Iniciar sesión';

  @override
  String get templateCommunityUnavailable =>
      'Las plantillas de la comunidad requieren Firebase. Revisa la conexión o la configuración.';

  @override
  String get templateCommunityEmpty =>
      'Aún no hay plantillas en la comunidad. Comparte la primera desde la pestaña Locales.';

  @override
  String templateCommunityLoadError(Object error) {
    return 'No se pudieron cargar las plantillas: $error';
  }

  @override
  String get templateCommunityRetry => 'Reintentar';

  @override
  String get templateCommunityRefresh => 'Actualizar';

  @override
  String get templateCommunityShareTitle => 'Compartir con la comunidad';

  @override
  String get templateCommunityShareBody =>
      'Tu plantilla será pública: cualquiera podrá verla y descargarla. Revisa que no incluya datos personales o confidenciales.';

  @override
  String get templateCommunityShareConfirm => 'Compartir';

  @override
  String get templateCommunityShareSuccess =>
      'Plantilla compartida con la comunidad';

  @override
  String templateCommunityShareError(Object error) {
    return 'No se pudo compartir: $error';
  }

  @override
  String get templateCommunityAddToVault => 'Guardar en mis plantillas';

  @override
  String get templateCommunityAddedToVault => 'Guardada en tus plantillas';

  @override
  String get templateCommunityDeleteTitle => 'Quitar de la comunidad';

  @override
  String templateCommunityDeleteBody(Object name) {
    return '¿Eliminar \"$name\" de la tienda comunitaria? No se puede deshacer.';
  }

  @override
  String get templateCommunityDeleteSuccess => 'Eliminada de la comunidad';

  @override
  String templateCommunityDeleteError(Object error) {
    return 'No se pudo eliminar: $error';
  }

  @override
  String templateCommunityDownloadError(Object error) {
    return 'No se pudo descargar la plantilla: $error';
  }

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
  String get cloudAccountEmailUnverifiedBanner =>
      'Verifica tu correo para asegurar tu cuenta Folio Cloud.';

  @override
  String get cloudAccountResendVerification =>
      'Reenviar correo de verificación';

  @override
  String get cloudAccountReloadVerification => 'Ya verifiqué';

  @override
  String get cloudAccountVerificationSent => 'Correo de verificación enviado.';

  @override
  String get cloudAccountVerificationStillPending =>
      'El correo sigue sin verificarse. Abre el enlace de tu bandeja de entrada.';

  @override
  String get cloudAccountVerificationNowVerified => 'Correo verificado.';

  @override
  String get cloudAccountResetPasswordEmail =>
      'Restablecer contraseña por correo';

  @override
  String get cloudAccountCopyEmail => 'Copiar correo';

  @override
  String get cloudAccountEmailCopied => 'Correo copiado.';

  @override
  String get folioWebPortalSubsectionTitle => 'Cuenta web';

  @override
  String get folioWebPortalLinkCodeLabel => 'Código de emparejamiento';

  @override
  String get folioWebPortalLinkHelp =>
      'Genera el código en la web, en Ajustes → cuenta Folio, e introdúcelo aquí en los próximos 10 minutos.';

  @override
  String get folioWebPortalLinkButton => 'Vincular';

  @override
  String get folioWebPortalLinkSuccess => 'Cuenta web vinculada correctamente.';

  @override
  String get folioWebPortalNeedSignIn =>
      'Inicia sesión en Folio Cloud para vincular la cuenta web.';

  @override
  String get folioWebMirrorNote =>
      'Copias, IA y publicación siguen gobernadas por Folio Cloud (Firestore). Lo siguiente refleja tu cuenta en la web.';

  @override
  String get folioWebEntitlementLinked => 'Cuenta web vinculada';

  @override
  String get folioWebEntitlementNotLinked => 'Cuenta web no vinculada';

  @override
  String folioWebEntitlementWebPlan(String value) {
    return 'Folio Cloud (web): $value';
  }

  @override
  String folioWebEntitlementWebStatus(String value) {
    return 'Estado (web): $value';
  }

  @override
  String folioWebEntitlementWebPeriodEnd(String value) {
    return 'Fin de periodo (web): $value';
  }

  @override
  String folioWebEntitlementWebInk(int count) {
    return 'Tinta (web): $count';
  }

  @override
  String get folioWebPortalRefreshWeb => 'Actualizar estado web';

  @override
  String get folioWebPortalErrorNetwork =>
      'No se pudo conectar con el portal. Comprueba la conexión.';

  @override
  String get folioWebPortalErrorTimeout =>
      'El portal tardó demasiado en responder.';

  @override
  String get folioWebPortalErrorAdminNotConfigured =>
      'Folio Firebase Admin no está configurado en el servidor (revisa el backend).';

  @override
  String get folioWebPortalErrorUnauthorized =>
      'Sesión no válida. Vuelve a iniciar sesión en Folio Cloud.';

  @override
  String get folioWebPortalErrorGeneric =>
      'No se pudo completar la operación con el portal.';

  @override
  String folioWebPortalServerMessage(String message) {
    return '$message';
  }

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
  String get folioCloudPitchScreenTitle => 'Folio Cloud';

  @override
  String get folioCloudPitchHeadline =>
      'Tu libreta sigue en el dispositivo. La nube entra cuando tú quieres.';

  @override
  String get folioCloudPitchSubhead =>
      'Un plan mensual desbloquea copias cifradas, IA alojada en la nube con recarga mensual de tinta y publicación web: solo lo que decidas compartir.';

  @override
  String get folioCloudPitchLearnMore => 'Ver qué incluye';

  @override
  String get folioCloudPitchCtaNeedAccount => 'Iniciar sesión o crear cuenta';

  @override
  String get folioCloudPitchGuestTeaserTitle => 'Cuenta Folio Cloud';

  @override
  String get folioCloudPitchGuestTeaserBody =>
      'Cuenta opcional: mira qué incluye el plan y entra cuando quieras suscribirte.';

  @override
  String get folioCloudPitchOpenSettingsToSignIn =>
      'Abre Ajustes e inicia sesión en Folio Cloud (sección Folio Cloud) para suscribirte.';

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
  String get folioCloudMicrosoftStoreBillingTitle =>
      'Microsoft Store (Windows)';

  @override
  String get folioCloudMicrosoftStoreBillingSubtitle =>
      'Misma suscripción y tinteros que con Stripe; la Tienda cobra y el servidor valida la compra. Configura los ids de producto con --dart-define y Azure AD en Cloud Functions.';

  @override
  String get folioCloudMicrosoftStoreSubscribeButton =>
      'Suscripción en la Tienda';

  @override
  String get folioCloudMicrosoftStoreSyncButton => 'Sincronizar con la Tienda';

  @override
  String get folioCloudMicrosoftStoreInkTitle => 'Tinta — Microsoft Store';

  @override
  String get folioCloudMicrosoftStoreInkPackSmall => 'Tintero pequeño (Tienda)';

  @override
  String get folioCloudMicrosoftStoreInkPackMedium =>
      'Tintero mediano (Tienda)';

  @override
  String get folioCloudMicrosoftStoreInkPackLarge => 'Tintero grande (Tienda)';

  @override
  String get folioCloudMicrosoftStoreSyncedSnack =>
      'Sincronizado con Microsoft Store.';

  @override
  String get folioCloudMicrosoftStoreAppliedSnack =>
      'Compra aplicada. Si no ves los cambios, pulsa sincronizar.';

  @override
  String get folioCloudPurchaseChannelTitle => '¿Dónde quieres pagar?';

  @override
  String get folioCloudPurchaseChannelBody =>
      'Puedes usar la Microsoft Store integrada en Windows o pagar con tarjeta en el navegador (Stripe). El plan y la tinta son los mismos.';

  @override
  String get folioCloudPurchaseChannelMicrosoftStore => 'Microsoft Store';

  @override
  String get folioCloudPurchaseChannelStripe => 'En el navegador (Stripe)';

  @override
  String get folioCloudPurchaseChannelCancel => 'Cancelar';

  @override
  String get folioCloudPurchaseChannelStoreNotConfigured =>
      'La opción de la Tienda no está configurada en esta compilación (faltan ids de producto).';

  @override
  String get folioCloudPurchaseChannelStoreNotConfiguredHint =>
      'Compila con --dart-define=MS_STORE_… o usa el pago en el navegador.';

  @override
  String get folioCloudMicrosoftStoreSyncHint =>
      'En Windows, «Actualizar» también sincroniza la Microsoft Store (mismo botón que Stripe).';

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
      'Quill en la nube con suscripción Folio Cloud (IA en la nube) o solo comprando tinta. La tinta se consume por uso; también puedes usar IA local (Ollama/LM Studio).';

  @override
  String get onboardingFolioCloudFeatureWebTitle => 'Publicación web';

  @override
  String get onboardingFolioCloudFeatureWebBody =>
      'Publica páginas seleccionadas y controla qué se hace público. El resto de la libreta no se comparte.';

  @override
  String get onboardingFolioCloudLaterInSettings => 'Lo veré en Ajustes';

  @override
  String get collabMenuAction => 'Colaboración en vivo';

  @override
  String get collabSheetTitle => 'Colaboración en vivo';

  @override
  String get collabHeaderSubtitle =>
      'Cuenta Folio obligatoria. Crear sala requiere plan con anfitrión; unirse solo necesita el código. Contenido y chat van cifrados de extremo a extremo; el servidor no ve tu texto.';

  @override
  String get collabNoRoomHint =>
      'Crea una sala (si tu plan incluye anfitrión) o pega el código que te comparta el anfitrión (emojis y números).';

  @override
  String get collabCreateRoom => 'Crear sala';

  @override
  String get collabJoinCodeLabel => 'Código de sala';

  @override
  String get collabJoinCodeHint => 'Ej.: dos emojis y 4 dígitos';

  @override
  String get collabJoinRoom => 'Unirse';

  @override
  String get collabJoinFailed => 'Código no válido o sala llena.';

  @override
  String get collabShareCodeLabel => 'Comparte este código';

  @override
  String get collabCopyJoinCode => 'Copiar código';

  @override
  String get collabCopied => 'Copiado';

  @override
  String get collabHostRequiresPlan =>
      'Para crear salas necesitas Folio Cloud con la función de colaboración (anfitrión). Puedes unirte a salas ajenas con un código sin ese plan.';

  @override
  String get collabChatEmptyHint => 'Aún no hay mensajes. Saluda a tu equipo.';

  @override
  String get collabMessageHint => 'Escribe un mensaje…';

  @override
  String get collabArchivedOk => 'Chat archivado en comentarios de la página.';

  @override
  String get collabArchiveToPage => 'Archivar chat en la página';

  @override
  String get collabLeaveRoom => 'Salir de la sala';

  @override
  String get collabNeedsJoinCode =>
      'Introduce el código de sala para descifrar esta sesión.';

  @override
  String get collabMissingJoinCodeHint =>
      'La página está enlazada a una sala pero aquí no hay código guardado. Pega el código del anfitrión para descifrar contenido y chat.';

  @override
  String get collabUnlockWithCode => 'Descifrar con código';

  @override
  String get collabHidePanel => 'Ocultar panel de colaboración';

  @override
  String get shortcutsCaptureTitle => 'Nuevo atajo';

  @override
  String get shortcutsCaptureHint => 'Pulsa las teclas (Esc cancela).';

  @override
  String get updaterStartupDialogTitleStable => 'Actualización disponible';

  @override
  String get updaterStartupDialogTitleBeta => 'Beta disponible';

  @override
  String updaterStartupDialogBody(Object releaseVersion) {
    return 'Hay una nueva versión ($releaseVersion) disponible.';
  }

  @override
  String get updaterStartupDialogQuestion =>
      '¿Quieres descargar e instalar ahora?';

  @override
  String get updaterStartupDialogLater => 'Más tarde';

  @override
  String get updaterStartupDialogUpdateNow => 'Actualizar ahora';

  @override
  String get updaterStartupDialogBetaNote => 'Versión beta (pre-release).';

  @override
  String get updaterOpenApkDownloadQuestion => '¿Abrir descarga del APK ahora?';

  @override
  String get updaterManualCheckUnsupportedPlatform =>
      'El actualizador integrado solo está disponible en Windows y Android.';

  @override
  String get updaterManualCheckAlreadyLatest =>
      'Ya tienes la versión más reciente.';

  @override
  String updaterDialogLineCurrentVersion(Object currentVersion) {
    return 'Versión actual: $currentVersion';
  }

  @override
  String updaterDialogLineNewVersion(Object releaseVersion) {
    return 'Nueva versión: $releaseVersion';
  }

  @override
  String get updaterApkUrlInvalidSnack =>
      'No se encontró URL válida del APK en el release.';

  @override
  String get updaterApkOpenFailedSnack =>
      'No se pudo abrir la descarga del APK.';

  @override
  String get toggleTitleHint => 'Título del desplegable';

  @override
  String get toggleBodyHint => 'Contenido…';

  @override
  String get taskStatusTodo => 'Por hacer';

  @override
  String get taskStatusInProgress => 'En progreso';

  @override
  String get taskStatusDone => 'Hecho';

  @override
  String get taskPriorityNone => 'Sin prioridad';

  @override
  String get taskPriorityLow => 'Baja';

  @override
  String get taskPriorityMedium => 'Media';

  @override
  String get taskPriorityHigh => 'Alta';

  @override
  String get taskTitleHint => 'Descripción de la tarea…';

  @override
  String get taskPriorityTooltip => 'Prioridad';

  @override
  String get taskNoDueDate => 'Sin fecha límite';

  @override
  String get taskSubtaskHint => 'Subtarea…';

  @override
  String get taskRemoveSubtask => 'Quitar subtarea';

  @override
  String get taskAddSubtask => 'Añadir subtarea';

  @override
  String get templateEmojiLabel => 'Emoji';

  @override
  String aiGenericErrorWithReason(Object reason) {
    return 'Error IA: $reason';
  }

  @override
  String get calloutTypeTooltip => 'Tipo de callout';

  @override
  String get calloutTypeInfo => 'Info';

  @override
  String get calloutTypeSuccess => 'Éxito';

  @override
  String get calloutTypeWarning => 'Advertencia';

  @override
  String get calloutTypeError => 'Error';

  @override
  String get calloutTypeNote => 'Nota';

  @override
  String get blockEditorEnterHintNewBlock =>
      'Enter: bloque nuevo (en código: Enter = línea)';

  @override
  String get blockEditorEnterHintNewLine => 'Enter: nueva línea';

  @override
  String blockEditorShortcutsHintMobile(String enterHint) {
    return '$enterHint · / para bloques · toca el bloque para más acciones';
  }

  @override
  String blockEditorShortcutsHintDesktop(String enterHint) {
    return '$enterHint · Shift+Enter: línea · / tipos · # título (misma línea) · - · * · [] · ``` espacio · tabla/imagen en / · formato: barra al enfocar o ** _ <u> ` ~~';
  }

  @override
  String blockEditorSelectedBlocksBanner(int count) {
    return '$count bloques seleccionados · Shift: rango · Ctrl/Cmd: alternar';
  }

  @override
  String get blockEditorDuplicate => 'Duplicar';

  @override
  String get blockEditorClearSelectionTooltip => 'Limpiar selección';

  @override
  String get blockEditorMenuRewriteWithAi => 'Reescribir con IA…';

  @override
  String get blockEditorMenuMoveUp => 'Mover arriba';

  @override
  String get blockEditorMenuMoveDown => 'Mover abajo';

  @override
  String get blockEditorMenuDuplicateBlock => 'Duplicar bloque';

  @override
  String get blockEditorMenuAppearance => 'Apariencia…';

  @override
  String get blockEditorMenuCalloutIcon => 'Icono del callout…';

  @override
  String blockEditorCalloutMenuType(String typeName) {
    return 'Tipo: $typeName';
  }

  @override
  String get blockEditorCopyLink => 'Copiar enlace';

  @override
  String get blockEditorMenuCreateSubpage => 'Crear subpágina';

  @override
  String get blockEditorMenuLinkPage => 'Enlazar página…';

  @override
  String get blockEditorMenuOpenSubpage => 'Abrir subpágina';

  @override
  String get blockEditorMenuPickImage => 'Elegir imagen…';

  @override
  String get blockEditorMenuRemoveImage => 'Quitar imagen';

  @override
  String get blockEditorMenuCodeLanguage => 'Lenguaje del código…';

  @override
  String get blockEditorMenuEditDiagram => 'Editar diagrama…';

  @override
  String get blockEditorMenuBackToPreview => 'Volver a vista previa';

  @override
  String get blockEditorMenuChangeFile => 'Cambiar archivo…';

  @override
  String get blockEditorMenuRemoveFile => 'Quitar archivo';

  @override
  String get blockEditorMenuChangeVideo => 'Cambiar video…';

  @override
  String get blockEditorMenuRemoveVideo => 'Quitar video';

  @override
  String get blockEditorMenuChangeAudio => 'Cambiar audio…';

  @override
  String get blockEditorMenuRemoveAudio => 'Quitar audio';

  @override
  String get blockEditorMenuEditLabel => 'Editar etiqueta…';

  @override
  String get blockEditorMenuAddRow => 'Añadir fila';

  @override
  String get blockEditorMenuRemoveLastRow => 'Quitar última fila';

  @override
  String get blockEditorMenuAddColumn => 'Añadir columna';

  @override
  String get blockEditorMenuRemoveLastColumn => 'Quitar última columna';

  @override
  String get blockEditorMenuAddProperty => 'Añadir propiedad';

  @override
  String get blockEditorMenuChangeBlockType => 'Cambiar tipo de bloque…';

  @override
  String get blockEditorMenuDeleteBlock => 'Eliminar bloque';

  @override
  String get blockEditorAppearanceTitle => 'Apariencia del bloque';

  @override
  String get blockEditorAppearanceSubtitle =>
      'Personaliza tamaño, color del texto y fondo para este bloque.';

  @override
  String get blockEditorAppearanceSize => 'Tamaño';

  @override
  String get blockEditorAppearanceTextColor => 'Color del texto';

  @override
  String get blockEditorAppearanceBackground => 'Fondo';

  @override
  String get blockEditorAppearancePreviewEmpty => 'Así se verá este bloque.';

  @override
  String get blockEditorReset => 'Restablecer';

  @override
  String get blockEditorCodeLanguageTitle => 'Lenguaje del código';

  @override
  String get blockEditorCodeLanguageSubtitle =>
      'Resaltado de sintaxis según el lenguaje elegido.';

  @override
  String get blockEditorTemplateButtonTitle => 'Etiqueta del botón plantilla';

  @override
  String get blockEditorTemplateButtonFieldLabel => 'Texto del botón';

  @override
  String get blockEditorTemplateButtonDefaultLabel => 'Plantilla';

  @override
  String get blockEditorTextColorDefault => 'Tema';

  @override
  String get blockEditorTextColorSubtle => 'Suave';

  @override
  String get blockEditorTextColorPrimary => 'Primario';

  @override
  String get blockEditorTextColorSecondary => 'Secundario';

  @override
  String get blockEditorTextColorTertiary => 'Acento';

  @override
  String get blockEditorTextColorError => 'Error';

  @override
  String get blockEditorBackgroundNone => 'Sin fondo';

  @override
  String get blockEditorBackgroundSurface => 'Sutil';

  @override
  String get blockEditorBackgroundPrimary => 'Primario';

  @override
  String get blockEditorBackgroundSecondary => 'Secundario';

  @override
  String get blockEditorBackgroundTertiary => 'Acento';

  @override
  String get blockEditorBackgroundError => 'Error';

  @override
  String get blockEditorCmdDuplicatePrev => 'Duplicar bloque anterior';

  @override
  String get blockEditorCmdDuplicatePrevHint =>
      'Clona el bloque inmediatamente anterior';

  @override
  String get blockEditorCmdInsertDate => 'Insertar fecha';

  @override
  String get blockEditorCmdInsertDateHint => 'Escribe la fecha actual';

  @override
  String get blockEditorCmdMentionPage => 'Mencionar página';

  @override
  String get blockEditorCmdMentionPageHint =>
      'Inserta enlace interno a una página';

  @override
  String get blockEditorCmdTurnInto => 'Convertir bloque';

  @override
  String get blockEditorCmdTurnIntoHint =>
      'Elegir tipo de bloque con el selector';

  @override
  String get blockEditorMarkTaskComplete => 'Marcar tarea completada';

  @override
  String get blockEditorCalloutIconPickerTitle => 'Icono del callout';

  @override
  String get blockEditorCalloutIconPickerHelper =>
      'Selecciona un icono para cambiar el tono visual del bloque destacado.';

  @override
  String get blockEditorIconPickerCustomEmoji => 'Emoji personalizado';

  @override
  String get blockEditorIconPickerQuickTab => 'Rápidos';

  @override
  String get blockEditorIconPickerImportedTab => 'Importados';

  @override
  String get blockEditorIconPickerAllTab => 'Todos';

  @override
  String get blockEditorIconPickerEmptyImported =>
      'Todavía no has importado iconos en Ajustes.';

  @override
  String get blockTypeSectionBasicText => 'Texto básico';

  @override
  String get blockTypeSectionLists => 'Listas';

  @override
  String get blockTypeSectionMedia => 'Multimedia y datos';

  @override
  String get blockTypeSectionAdvanced => 'Avanzado y diseño';

  @override
  String get blockTypeSectionEmbeds => 'Integraciones';

  @override
  String get blockTypeParagraphLabel => 'Texto';

  @override
  String get blockTypeParagraphHint => 'Párrafo';

  @override
  String get blockTypeChildPageLabel => 'Página';

  @override
  String get blockTypeChildPageHint => 'Subpágina enlazada';

  @override
  String get blockTypeH1Label => 'Encabezado 1';

  @override
  String get blockTypeH1Hint => 'Título grande  ·  #';

  @override
  String get blockTypeH2Label => 'Encabezado 2';

  @override
  String get blockTypeH2Hint => 'Subtítulo  ·  ##';

  @override
  String get blockTypeH3Label => 'Encabezado 3';

  @override
  String get blockTypeH3Hint => 'Encabezado menor  ·  ###';

  @override
  String get blockTypeQuoteLabel => 'Cita';

  @override
  String get blockTypeQuoteHint => 'Texto citado';

  @override
  String get blockTypeDividerLabel => 'Divisor';

  @override
  String get blockTypeDividerHint => 'Separador  ·  ---';

  @override
  String get blockTypeCalloutLabel => 'Bloque destacado';

  @override
  String get blockTypeCalloutHint => 'Aviso con icono';

  @override
  String get blockTypeBulletLabel => 'Lista con viñetas';

  @override
  String get blockTypeBulletHint => 'Lista con puntos';

  @override
  String get blockTypeNumberedLabel => 'Lista numerada';

  @override
  String get blockTypeNumberedHint => 'Lista 1, 2, 3';

  @override
  String get blockTypeTodoLabel => 'Lista de tareas';

  @override
  String get blockTypeTodoHint => 'Checklist';

  @override
  String get blockTypeTaskLabel => 'Tarea enriquecida';

  @override
  String get blockTypeTaskHint => 'Estado / prioridad / fecha';

  @override
  String get blockTypeToggleLabel => 'Desplegable';

  @override
  String get blockTypeToggleHint => 'Mostrar/ocultar contenido';

  @override
  String get blockTypeImageLabel => 'Imagen';

  @override
  String get blockTypeImageHint => 'Imagen local o externa';

  @override
  String get blockTypeBookmarkLabel => 'Marcador con vista previa';

  @override
  String get blockTypeBookmarkHint => 'Tarjeta con enlace';

  @override
  String get blockTypeVideoLabel => 'Vídeo';

  @override
  String get blockTypeVideoHint => 'Archivo o enlace';

  @override
  String get blockTypeAudioLabel => 'Audio';

  @override
  String get blockTypeAudioHint => 'Reproductor de audio';

  @override
  String get blockTypeMeetingNoteLabel => 'Nota de reunión';

  @override
  String get blockTypeMeetingNoteHint => 'Graba y transcribe una reunión';

  @override
  String get blockTypeCodeLabel => 'Código (Java, Python…)';

  @override
  String get blockTypeCodeHint => 'Bloque con sintaxis';

  @override
  String get blockTypeFileLabel => 'Archivo / PDF';

  @override
  String get blockTypeFileHint => 'Adjunto o PDF';

  @override
  String get blockTypeTableLabel => 'Tabla';

  @override
  String get blockTypeTableHint => 'Filas y columnas';

  @override
  String get blockTypeDatabaseLabel => 'Base de datos';

  @override
  String get blockTypeDatabaseHint => 'Vista lista/tabla/tablero';

  @override
  String get blockTypeEquationLabel => 'Ecuación (LaTeX)';

  @override
  String get blockTypeEquationHint => 'Fórmulas matemáticas';

  @override
  String get blockTypeMermaidLabel => 'Diagrama (Mermaid)';

  @override
  String get blockTypeMermaidHint => 'Diagrama de flujo o esquema';

  @override
  String get blockTypeTocLabel => 'Tabla de contenidos';

  @override
  String get blockTypeTocHint => 'Índice automático';

  @override
  String get blockTypeBreadcrumbLabel => 'Migas de pan';

  @override
  String get blockTypeBreadcrumbHint => 'Ruta de navegación';

  @override
  String get blockTypeTemplateButtonLabel => 'Botón de plantilla';

  @override
  String get blockTypeTemplateButtonHint => 'Insertar bloque predefinido';

  @override
  String get blockTypeColumnListLabel => 'Columnas';

  @override
  String get blockTypeColumnListHint => 'Diseño en columnas';

  @override
  String get blockTypeEmbedLabel => 'Incrustado web';

  @override
  String get blockTypeEmbedHint => 'YouTube, Figma, Docs…';

  @override
  String get integrationDialogTitleUpdatePermission =>
      'Actualizar permiso de integración';

  @override
  String get integrationDialogTitleAllowConnect =>
      'Permitir que esta app se conecte';

  @override
  String integrationDialogBodyUpdate(
    Object previousVersion,
    Object integrationVersion,
  ) {
    return 'Esta app ya estaba aprobada con la integración $previousVersion y ahora pide acceso con la versión $integrationVersion.';
  }

  @override
  String integrationDialogBodyNew(
    Object appName,
    Object appVersion,
    Object integrationVersion,
  ) {
    return '«$appName» quiere usar el puente local de Folio con la app versión $appVersion y la integración $integrationVersion.';
  }

  @override
  String get integrationChipLocalhostOnly => 'Solo localhost';

  @override
  String get integrationChipRevocableApproval => 'Aprobación revocable';

  @override
  String get integrationChipNoSharedSecret => 'Sin secreto compartido';

  @override
  String get integrationChipScopedByAppId => 'Permiso por appId';

  @override
  String get integrationMetaPreviouslyApprovedVersion =>
      'Versión anterior aprobada';

  @override
  String get integrationSectionWhatAppCanDo => 'Lo que esta app podrá hacer';

  @override
  String get integrationCapEphemeralSessionsTitle =>
      'Abrir sesiones locales efímeras';

  @override
  String get integrationCapEphemeralSessionsBody =>
      'Podrá iniciar una sesión temporal para hablar con el puente local de Folio desde este dispositivo.';

  @override
  String get integrationCapImportPagesTitle =>
      'Importar y actualizar sus propias páginas';

  @override
  String get integrationCapImportPagesBody =>
      'Podrá crear páginas, listarlas y actualizar solo las páginas que esa misma app haya importado antes.';

  @override
  String get integrationCapCustomEmojisTitle =>
      'Gestionar sus emojis personalizados';

  @override
  String get integrationCapCustomEmojisBody =>
      'Podrá listar, crear, reemplazar y borrar solo su propio catálogo de emojis o iconos importados.';

  @override
  String get integrationCapUnlockedVaultTitle =>
      'Trabajar solo con la libreta abierta';

  @override
  String get integrationCapUnlockedVaultBody =>
      'Las peticiones solo funcionan cuando Folio está abierto, la libreta está disponible y la sesión actual sigue activa.';

  @override
  String get integrationSectionWhatStaysBlocked => 'Lo que seguirá bloqueado';

  @override
  String get integrationBlockNoSeeAllTitle => 'No puede ver todo tu contenido';

  @override
  String get integrationBlockNoSeeAllBody =>
      'No obtiene acceso general a la libreta. Solo puede listar lo que ella misma importó mediante su appId.';

  @override
  String get integrationBlockNoBypassTitle =>
      'No puede saltarse bloqueo ni cifrado';

  @override
  String get integrationBlockNoBypassBody =>
      'Si la libreta está bloqueada o no hay sesión activa, Folio rechazará la operación.';

  @override
  String get integrationBlockNoOtherAppsTitle =>
      'No puede tocar datos de otras apps';

  @override
  String get integrationBlockNoOtherAppsBody =>
      'Tampoco puede gestionar páginas importadas o emojis registrados por otras apps aprobadas.';

  @override
  String get integrationBlockNoRemoteTitle =>
      'No puede entrar desde fuera de tu equipo';

  @override
  String get integrationBlockNoRemoteBody =>
      'El puente sigue limitado a localhost y esta aprobación se puede revocar más tarde desde Ajustes.';

  @override
  String integrationSnackMarkdownImportDone(Object pageTitle) {
    return 'Importación completada: $pageTitle.';
  }

  @override
  String integrationSnackJsonImportDone(Object pageTitle) {
    return 'Importación JSON completada: $pageTitle.';
  }

  @override
  String integrationSnackPageUpdateDone(Object pageTitle) {
    return 'Actualización de integración completada: $pageTitle.';
  }

  @override
  String get markdownImportModeDialogTitle => 'Importar Markdown';

  @override
  String get markdownImportModeDialogBody =>
      'Elige cómo quieres aplicar el archivo Markdown.';

  @override
  String get markdownImportModeNewPage => 'Página nueva';

  @override
  String get markdownImportModeAppend => 'Anexar a la actual';

  @override
  String get markdownImportModeReplace => 'Reemplazar actual';

  @override
  String get markdownImportCouldNotReadPath =>
      'No se pudo leer la ruta del archivo.';

  @override
  String markdownImportedBlocks(Object pageTitle, int blockCount) {
    return 'Markdown importado: $pageTitle ($blockCount bloques).';
  }

  @override
  String markdownImportFailedWithError(Object error) {
    return 'No se pudo importar el Markdown: $error';
  }

  @override
  String get importPage => 'Importar…';

  @override
  String get exportMarkdownFileDialogTitle => 'Exportar página a Markdown';

  @override
  String get markdownExportSuccess => 'Página exportada a Markdown.';

  @override
  String markdownExportFailedWithError(Object error) {
    return 'No se pudo exportar la página: $error';
  }

  @override
  String get exportPageDialogTitle => 'Exportar página';

  @override
  String get exportPageFormatMarkdown => 'Markdown (.md)';

  @override
  String get exportPageFormatHtml => 'HTML (.html)';

  @override
  String get exportPageFormatTxt => 'Texto (.txt)';

  @override
  String get exportPageFormatJson => 'JSON (.json)';

  @override
  String get exportPageFormatPdf => 'PDF (.pdf)';

  @override
  String get exportHtmlFileDialogTitle => 'Exportar página a HTML';

  @override
  String get htmlExportSuccess => 'Página exportada a HTML.';

  @override
  String htmlExportFailedWithError(Object error) {
    return 'No se pudo exportar la página: $error';
  }

  @override
  String get exportTxtFileDialogTitle => 'Exportar página a texto';

  @override
  String get txtExportSuccess => 'Página exportada a texto.';

  @override
  String txtExportFailedWithError(Object error) {
    return 'No se pudo exportar la página: $error';
  }

  @override
  String get exportJsonFileDialogTitle => 'Exportar página a JSON';

  @override
  String get jsonExportSuccess => 'Página exportada a JSON.';

  @override
  String jsonExportFailedWithError(Object error) {
    return 'No se pudo exportar la página: $error';
  }

  @override
  String get exportPdfFileDialogTitle => 'Exportar página a PDF';

  @override
  String get pdfExportSuccess => 'Página exportada a PDF.';

  @override
  String pdfExportFailedWithError(Object error) {
    return 'No se pudo exportar la página: $error';
  }

  @override
  String get firebaseUnavailablePublish => 'Firebase no está disponible.';

  @override
  String get signInCloudToPublishWeb =>
      'Inicia sesión en la cuenta en la nube (Ajustes) para publicar.';

  @override
  String get planMissingWebPublish =>
      'Tu plan no incluye publicación web o la suscripción no está activa.';

  @override
  String get publishWebDialogTitle => 'Publicar en la web';

  @override
  String get publishWebSlugLabel => 'URL (slug)';

  @override
  String get publishWebSlugHint => 'mi-nota';

  @override
  String get publishWebSlugHelper =>
      'Letras, números y guiones. Quedará en la URL pública.';

  @override
  String get publishWebAction => 'Publicar';

  @override
  String get publishWebEmptySlug => 'Slug vacío.';

  @override
  String publishWebSuccessWithUrl(Object url) {
    return 'Publicado: $url';
  }

  @override
  String publishWebFailedWithError(Object error) {
    return 'No se pudo publicar: $error';
  }

  @override
  String get publishWebMenuLabel => 'Publicar en la web';

  @override
  String get mobileFabDone => 'Listo';

  @override
  String get mobileFabEdit => 'Editar';

  @override
  String get mobileFabAddBlock => 'Bloque';

  @override
  String get mermaidPreviewDialogTitle => 'Diagrama';

  @override
  String get mermaidDiagramSemanticsLabel =>
      'Diagrama Mermaid, toca para ampliar';

  @override
  String get databaseSortAz => 'Orden A-Z';

  @override
  String get databaseSortLabel => 'Ordenar';

  @override
  String get databaseFilterAnd => 'Y';

  @override
  String get databaseFilterOr => 'O';

  @override
  String get databaseSortDescending => 'Desc';

  @override
  String get databaseNewPropertyDialogTitle => 'Nueva propiedad';

  @override
  String databaseConfigurePropertyTitle(Object name) {
    return 'Configurar: $name';
  }

  @override
  String get databaseLocalCurrentBadge => 'DB local actual';

  @override
  String databaseRelateRowsTitle(Object name) {
    return 'Relacionar filas ($name)';
  }

  @override
  String get databaseBoardNeedsGroupProperty =>
      'Configura una propiedad de grupo para tablero.';

  @override
  String get databaseGroupPropertyMissing =>
      'La propiedad de grupo ya no existe.';

  @override
  String get databaseCalendarNeedsDateProperty =>
      'Configura una propiedad de fecha para calendario.';

  @override
  String get databaseNoDatedEvents => 'Sin eventos con fecha.';

  @override
  String get databaseConfigurePropertyTooltip => 'Configurar propiedad';

  @override
  String get databaseFormulaHintExample =>
      'if(contains(Nombre,\"x\"), add(1,2), 0)';

  @override
  String get createAction => 'Crear';

  @override
  String get confirmAction => 'Confirmar';

  @override
  String get confirmRemoteEndpointTitle => 'Confirmar endpoint remoto';

  @override
  String get shortcutGlobalSearchKeyChord => 'Ctrl + Shift + F';

  @override
  String get updateChannelRelease => 'Release';

  @override
  String get updateChannelBeta => 'Beta';

  @override
  String get blockActionChooseAudio => 'Elegir audio…';

  @override
  String get blockActionCreateSubpage => 'Crear subpágina';

  @override
  String get blockActionLinkPage => 'Enlazar página…';

  @override
  String get defaultNewPageTitle => 'Nueva página';

  @override
  String defaultPageDuplicateTitle(Object title) {
    return '$title (copia)';
  }

  @override
  String aiChatTitleNumbered(int n) {
    return 'Chat $n';
  }

  @override
  String get invalidFolioTemplateFile =>
      'El archivo no es un template Folio válido.';

  @override
  String get templateButtonDefaultLabel => 'Plantilla';

  @override
  String get pageHtmlExportPublishedWithFolio => 'Publicado con Folio';

  @override
  String get releaseReadinessSemverOk => 'Versión SemVer válida';

  @override
  String get releaseReadinessEncryptedVault => 'Libreta cifrada';

  @override
  String get releaseReadinessAiRemotePolicy => 'Política endpoint IA';

  @override
  String get releaseReadinessVaultUnlocked => 'Libreta desbloqueada';

  @override
  String get releaseReadinessStableChannel => 'Canal estable seleccionado';

  @override
  String get aiPromptUserMessage => 'Mensaje del usuario:';

  @override
  String get aiPromptOriginalMessage => 'Mensaje original:';

  @override
  String get aiPromptOriginalUserMessage => 'Mensaje original del usuario:';

  @override
  String get customIconImportEmptySource => 'La fuente del icono está vacía.';

  @override
  String get customIconImportInvalidUrl => 'La URL del icono no es válida.';

  @override
  String get customIconImportInvalidSvg => 'El SVG copiado no es válido.';

  @override
  String get customIconImportHttpHttpsOnly =>
      'Solo se admiten URLs http o https.';

  @override
  String get customIconImportDataUriMimeList =>
      'Solo se admiten data:image/svg+xml, data:image/gif, data:image/webp o data:image/png.';

  @override
  String get customIconImportUnsupportedFormat =>
      'Formato no compatible. Usa SVG, PNG, GIF o WebP.';

  @override
  String get customIconImportSvgTooLarge =>
      'El SVG es demasiado grande para importarlo.';

  @override
  String get customIconImportEmbeddedImageTooLarge =>
      'La imagen embebida es demasiado grande para importarla.';

  @override
  String customIconImportDownloadFailed(Object code) {
    return 'No se pudo descargar el icono ($code).';
  }

  @override
  String get customIconImportRemoteTooLarge =>
      'El icono remoto es demasiado grande.';

  @override
  String get customIconImportConnectFailed =>
      'No se pudo conectar para descargar el icono.';

  @override
  String get customIconImportCertFailed =>
      'Fallo de certificado al descargar el icono.';

  @override
  String get customIconLabelDefault => 'Icono personalizado';

  @override
  String get customIconLabelImported => 'Icono importado';

  @override
  String get customIconImportSucceeded => 'Icono importado correctamente.';

  @override
  String get customIconClipboardEmpty => 'El portapapeles está vacío.';

  @override
  String get customIconRemoved => 'Icono eliminado.';

  @override
  String get whisperModelTiny => 'Tiny (rápido)';

  @override
  String get whisperModelBaseQ8 => 'Base q8 (equilibrado)';

  @override
  String get whisperModelSmallQ8 => 'Small q8 (alta precisión, menos disco)';

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
  String get codeLangPlainText => 'Texto plano';

  @override
  String settingsAppRevoked(Object appId) {
    return 'App revocada: $appId';
  }

  @override
  String get settingsDeviceRevokedSnack => 'Dispositivo revocado.';

  @override
  String get settingsAiConnectionOk => 'Conexión IA OK';

  @override
  String settingsAiConnectionError(Object error) {
    return 'Error de conexión: $error';
  }

  @override
  String settingsAiListModelsFailed(Object error) {
    return 'No se pudieron listar modelos: $error';
  }

  @override
  String get folioCloudCallableNotSignedIn =>
      'Debes iniciar sesión para llamar a Cloud Functions';

  @override
  String get folioCloudCallableUnexpectedResponse =>
      'Respuesta inesperada de Cloud Functions';

  @override
  String folioCloudCallableHttpError(int code, Object name) {
    return 'HTTP $code al llamar a $name';
  }

  @override
  String get folioCloudCallableNoIdToken =>
      'Sin token de ID para Cloud Functions. Vuelve a iniciar sesión en Folio Cloud.';

  @override
  String get folioCloudCallableUnexpectedFallback =>
      'Respuesta inesperada del respaldo de Cloud Functions';

  @override
  String folioCloudCallableHttpAiComplete(int code) {
    return 'HTTP $code al llamar a folioCloudAiCompleteHttp';
  }

  @override
  String get cloudAccountEmailMismatch =>
      'El correo no coincide con la sesión actual.';

  @override
  String get cloudIdentityInvalidAuthResponse =>
      'Respuesta de autenticación no válida.';

  @override
  String get templateButtonPlaceholderText => 'Texto de la plantilla…';

  @override
  String get aiProviderOllamaName => 'Ollama';

  @override
  String get aiProviderLmStudioName => 'LM Studio';

  @override
  String get blockAudioEmptyHint => 'Elige un archivo de audio';

  @override
  String get blockChildPageTitle => 'Bloque página';

  @override
  String get blockChildPageNoLink => 'Sin subpágina enlazada.';

  @override
  String get mermaidExpandedLoadError =>
      'No se pudo mostrar el diagrama ampliado.';

  @override
  String get mermaidPreviewTooltip =>
      'Toca para ampliar y hacer zoom. PNG vía mermaid.ink (servicio externo).';

  @override
  String get aiEndpointInvalidUrl => 'URL inválida. Usa http://host:puerto.';

  @override
  String get aiEndpointRemoteNotAllowed =>
      'Endpoint remoto no permitido sin confirmación.';

  @override
  String get settingsAiSelectProviderFirst =>
      'Selecciona un proveedor IA primero.';

  @override
  String get releaseReadinessAiSummaryDisabled => 'IA desactivada';

  @override
  String get releaseReadinessAiSummaryQuillCloud =>
      'Folio Cloud IA (sin endpoint local)';

  @override
  String releaseReadinessAiSummaryEndpointOk(Object url) {
    return 'Endpoint válido: $url';
  }

  @override
  String get releaseReadinessDetailSemverInvalid =>
      'La versión instalada no cumple SemVer.';

  @override
  String get releaseReadinessDetailVaultNotEncrypted =>
      'La libreta actual no está cifrada.';

  @override
  String get releaseReadinessDetailVaultLocked =>
      'Desbloquea la libreta para validar export/import y flujo real.';

  @override
  String get releaseReadinessDetailBetaChannel =>
      'El canal beta está activo para actualizaciones.';

  @override
  String get releaseReadinessReportTitle => 'Folio: preparación para release';

  @override
  String releaseReadinessReportInstalledVersion(Object label) {
    return 'Versión instalada: $label';
  }

  @override
  String releaseReadinessReportSemver(Object value) {
    return 'SemVer válido: $value';
  }

  @override
  String releaseReadinessReportChannel(Object value) {
    return 'Canal de actualizaciones: $value';
  }

  @override
  String releaseReadinessReportActiveVault(Object id) {
    return 'Libreta activa: $id';
  }

  @override
  String releaseReadinessReportVaultPath(Object path) {
    return 'Ruta libreta: $path';
  }

  @override
  String releaseReadinessReportUnlocked(Object value) {
    return 'Libreta desbloqueada: $value';
  }

  @override
  String releaseReadinessReportEncrypted(Object value) {
    return 'Libreta cifrada: $value';
  }

  @override
  String releaseReadinessReportAiEnabled(Object value) {
    return 'IA habilitada: $value';
  }

  @override
  String releaseReadinessReportAiPolicy(Object value) {
    return 'Política endpoint IA: $value';
  }

  @override
  String releaseReadinessReportAiDetail(Object detail) {
    return 'Detalle IA: $detail';
  }

  @override
  String releaseReadinessReportStatus(Object value) {
    return 'Estado release: $value';
  }

  @override
  String releaseReadinessReportBlockers(int count) {
    return 'Bloqueadores pendientes: $count';
  }

  @override
  String releaseReadinessReportWarnings(int count) {
    return 'Advertencias pendientes: $count';
  }

  @override
  String get releaseReadinessExportWordYes => 'sí';

  @override
  String get releaseReadinessExportWordNo => 'no';

  @override
  String get releaseReadinessChannelStable => 'estable';

  @override
  String get releaseReadinessChannelBeta => 'beta';

  @override
  String get releaseReadinessStatusReady => 'listo';

  @override
  String get releaseReadinessStatusBlocked => 'bloqueado';

  @override
  String get releaseReadinessPolicyOk => 'correcto';

  @override
  String get releaseReadinessPolicyError => 'error';

  @override
  String get settingsSignInFolioCloudSnack => 'Inicia sesión en Folio Cloud.';

  @override
  String get settingsNotSyncedYet => 'Aún sin sincronizar';

  @override
  String get settingsDeviceNameTitle => 'Nombre del dispositivo';

  @override
  String get settingsDeviceNameHintExample => 'Ejemplo: Pixel de Alejandra';

  @override
  String get settingsPairingModeEnabledTwoMin =>
      'Modo vinculación activado durante 2 minutos.';

  @override
  String get settingsPairingEnableModeFirst =>
      'Primero activa el modo vinculación y luego elige un dispositivo detectado.';

  @override
  String get settingsPairingSameEmojisBothDevices =>
      'Activa el modo vinculación en ambos dispositivos y espera a que aparezcan los mismos 3 emojis.';

  @override
  String get settingsPairingCouldNotStart =>
      'No se pudo iniciar la vinculación. Activa el modo vinculación en ambos dispositivos y espera a ver los mismos 3 emojis.';

  @override
  String get settingsConfirmPairingTitle => 'Confirmar vinculación';

  @override
  String get settingsPairingCheckOtherDeviceEmojis =>
      'Comprueba que en el otro dispositivo aparecen estos mismos 3 emojis:';

  @override
  String get settingsPairingPopupInstructions =>
      'Este popup también aparecerá en el otro dispositivo. Para completar el enlace, pulsa Vincular aquí y luego Vincular en el otro.';

  @override
  String get settingsLinkDevice => 'Vincular';

  @override
  String get settingsPairingConfirmationSent =>
      'Confirmación enviada. Falta que el otro dispositivo pulse Vincular en su popup.';

  @override
  String get settingsResolveConflictsTitle => 'Resolver conflictos';

  @override
  String get settingsNoPendingConflicts => 'No hay conflictos pendientes.';

  @override
  String settingsSyncConflictCardSubtitle(
    Object fromPeerId,
    int remotePageCount,
    Object detectedAt,
  ) {
    return 'Origen: $fromPeerId\nPáginas remotas: $remotePageCount\nDetectado: $detectedAt';
  }

  @override
  String get settingsSyncConflictHeading => 'Conflicto de sincronización';

  @override
  String get settingsLocalVersionKeptSnack => 'Se conservó la versión local.';

  @override
  String get settingsKeepLocal => 'Mantener local';

  @override
  String get settingsRemoteVersionAppliedSnack =>
      'Se aplicó la versión remota.';

  @override
  String get settingsCouldNotApplyRemoteSnack =>
      'No se pudo aplicar la versión remota.';

  @override
  String get settingsAcceptRemote => 'Aceptar remota';

  @override
  String get settingsClose => 'Cerrar';

  @override
  String get settingsSectionDeviceSyncNav => 'Sincronización';

  @override
  String get settingsSectionVault => 'Libreta';

  @override
  String get settingsSectionVaultHeroDescription =>
      'Seguridad al desbloquear, copias, programación a disco y gestión de datos en este dispositivo.';

  @override
  String get settingsSectionUiWorkspace => 'Interfaz y escritorio';

  @override
  String get settingsSectionUiWorkspaceHeroDescription =>
      'Tema, idioma, escala, editor, opciones de escritorio y atajos de teclado.';

  @override
  String get settingsSubsectionVaultBackupImport => 'Copias e importación';

  @override
  String get settingsSubsectionVaultScheduledLocal =>
      'Copia programada (local)';

  @override
  String get settingsSubsectionVaultData => 'Datos (zona peligrosa)';

  @override
  String get folioCloudSubsectionAccount => 'Cuenta';

  @override
  String get folioCloudSubsectionEncryptedBackups => 'Copias cifradas (nube)';

  @override
  String get folioCloudSubsectionPublishing => 'Publicación web';

  @override
  String get settingsFolioCloudSubsectionScheduledCloud =>
      'Copia programada a Folio Cloud';

  @override
  String get settingsScheduledCloudUploadRequiresSchedule =>
      'Activa antes la copia programada en Libreta › Copia programada (local).';

  @override
  String get settingsSyncHeroTitle => 'Sincronización entre dispositivos';

  @override
  String get settingsSyncHeroDescription =>
      'Empareja equipos en la red local; el relay solo ayuda a negociar la conexión, no envía el contenido del vault.';

  @override
  String get settingsSyncChipPairingCode => 'Código de enlace';

  @override
  String get settingsSyncChipAutoDiscovery => 'Detección automática';

  @override
  String get settingsSyncChipOptionalRelay => 'Relay opcional';

  @override
  String get settingsSyncEnableTitle =>
      'Activar sincronización entre dispositivos';

  @override
  String get settingsSyncSearchingSubtitle =>
      'Buscando dispositivos con Folio abierto en la red local...';

  @override
  String settingsSyncDevicesFoundOnLan(int count) {
    return '$count dispositivos detectados en LAN.';
  }

  @override
  String get settingsSyncDisabledSubtitle =>
      'La sincronización está desactivada.';

  @override
  String get settingsSyncRelayTitle => 'Usar relay de señalización';

  @override
  String get settingsSyncRelaySubtitle =>
      'No envía contenido del vault, solo ayuda a negociar la conexión si la LAN falla.';

  @override
  String get settingsEdit => 'Editar';

  @override
  String get settingsSyncEmojiModeTitle =>
      'Activar modo vinculación por emojis';

  @override
  String get settingsSyncEmojiModeSubtitle =>
      'Actívalo en ambos dispositivos para iniciar el proceso de vinculación sin escribir códigos.';

  @override
  String get settingsSyncPairingStatusTitle => 'Estado del modo vinculación';

  @override
  String get settingsSyncPairingActiveSubtitle =>
      'Activo durante 2 minutos. Ya puedes iniciar la vinculación desde un dispositivo detectado.';

  @override
  String get settingsSyncPairingInactiveSubtitle =>
      'Inactivo. Actívalo aquí y en el otro dispositivo para empezar a vincular.';

  @override
  String get settingsSyncLastSyncTitle => 'Última sincronización';

  @override
  String get settingsSyncPendingConflictsTitle => 'Conflictos pendientes';

  @override
  String get settingsSyncNoConflictsSubtitle => 'Sin conflictos pendientes.';

  @override
  String settingsSyncConflictsNeedReview(int count) {
    return '$count conflictos requieren revisión manual.';
  }

  @override
  String get settingsResolve => 'Resolver';

  @override
  String get settingsSyncDiscoveredDevicesTitle => 'Dispositivos detectados';

  @override
  String get settingsSyncNoDevicesYetHint =>
      'No se detectaron dispositivos todavía. Asegura que ambas apps estén abiertas en la misma red.';

  @override
  String get settingsSyncPeerReadyToLink => 'Listo para vincular.';

  @override
  String get settingsSyncPeerOtherInPairingMode =>
      'El otro dispositivo está en modo vinculación. Actívalo aquí para iniciar el enlace.';

  @override
  String get settingsSyncPeerDetectedLan => 'Detectado en la red local.';

  @override
  String get settingsSyncLinkedDevicesTitle => 'Dispositivos vinculados';

  @override
  String get settingsSyncNoLinkedDevicesYet =>
      'Aún no hay dispositivos enlazados.';

  @override
  String settingsSyncPeerIdLabel(Object peerId) {
    return 'ID: $peerId';
  }

  @override
  String get settingsRevoke => 'Revocar';

  @override
  String get sidebarPageIconTitle => 'Icono de la página';

  @override
  String get sidebarPageIconPickerHelper =>
      'Elige un icono rápido, uno importado o abre el selector completo.';

  @override
  String get sidebarPageIconCustomEmoji => 'Emoji personalizado';

  @override
  String get sidebarPageIconRemove => 'Quitar';

  @override
  String get sidebarPageIconTabQuick => 'Rápidos';

  @override
  String get sidebarPageIconTabImported => 'Importados';

  @override
  String get sidebarPageIconTabAll => 'Todos';

  @override
  String get sidebarPageIconEmptyImported =>
      'Todavía no has importado iconos en Ajustes.';

  @override
  String get settingsStripeSubscriptionRefreshed =>
      'Facturación Folio Cloud actualizada.';

  @override
  String get settingsStripeBillingPortalUnavailable =>
      'Portal de facturación no disponible.';

  @override
  String get settingsCouldNotOpenLink => 'No se pudo abrir el enlace.';

  @override
  String get settingsStripeCheckoutUnavailable =>
      'Pago no disponible (configura Stripe en el servidor).';

  @override
  String get settingsCloudBackupEnablePlanSnack =>
      'Activa Folio Cloud con la función de copia en la nube incluida en tu plan.';

  @override
  String get settingsNoActiveVault => 'No hay libreta activa.';

  @override
  String get settingsCloudBackupsNeedPlan =>
      'Necesitas Folio Cloud activo con copia en la nube.';

  @override
  String settingsCloudBackupsDialogTitle(int count) {
    return 'Copias en la nube ($count/10)';
  }

  @override
  String get settingsCloudBackupsEmpty => 'Aún no hay copias en esta cuenta.';

  @override
  String get settingsCloudBackupDownloadTooltip => 'Descargar';

  @override
  String get settingsCloudBackupSaveDialogTitle => 'Guardar copia';

  @override
  String get settingsCloudBackupDownloadedSnack => 'Copia descargada.';

  @override
  String get settingsPublishedRequiresPlan =>
      'Necesitas Folio Cloud con publicación web activa.';

  @override
  String get settingsPublishedPagesTitle => 'Páginas publicadas';

  @override
  String get settingsPublishedPagesEmpty => 'Aún no hay páginas publicadas.';

  @override
  String get settingsPublishedDeleteDialogTitle => '¿Eliminar publicación?';

  @override
  String get settingsPublishedDeleteDialogBody =>
      'Se borrará el HTML público y el enlace dejará de funcionar.';

  @override
  String get settingsPublishedRemovedSnack => 'Publicación eliminada.';

  @override
  String get settingsCouldNotReadInstalledVersion =>
      'No se pudo leer la versión instalada.';

  @override
  String settingsCouldNotOpenReleaseNotes(Object error) {
    return 'No se pudieron abrir las notas de versión: $error';
  }

  @override
  String settingsUpdateFailed(Object error) {
    return 'No se pudo actualizar: $error';
  }

  @override
  String get settingsSessionEndedSnack => 'Sesión cerrada';

  @override
  String get settingsLabelYes => 'Sí';

  @override
  String get settingsLabelNo => 'No';

  @override
  String get settingsSecurityEncryptedHeroDescription =>
      'Desbloqueo rápido, passkey, bloqueo automático y contraseña maestra del vault cifrado.';

  @override
  String get settingsUnencryptedVaultTitle => 'Vault sin cifrar';

  @override
  String get settingsUnencryptedVaultChipDataOnDisk => 'Datos en disco';

  @override
  String get settingsUnencryptedVaultChipEncryptionAvailable =>
      'Cifrado disponible';

  @override
  String get settingsAppearanceChipTheme => 'Tema';

  @override
  String get settingsAppearanceChipZoom => 'Zoom';

  @override
  String get settingsAppearanceChipLanguage => 'Idioma';

  @override
  String get settingsAppearanceChipEditorWorkspace => 'Editor y espacio';

  @override
  String get settingsWindowsScaleFollowTitle => 'Seguir escala de Windows';

  @override
  String get settingsWindowsScaleFollowSubtitle =>
      'Usa automáticamente la escala del sistema en Windows.';

  @override
  String get settingsInterfaceZoomTitle => 'Zoom de la interfaz';

  @override
  String get settingsInterfaceZoomSubtitle =>
      'Aumenta o reduce el tamaño general de la app.';

  @override
  String get settingsUiZoomReset => 'Restablecer';

  @override
  String get settingsEditorSubsection => 'Editor';

  @override
  String get settingsEditorContentWidthTitle => 'Ancho del contenido';

  @override
  String get settingsEditorContentWidthSubtitle =>
      'Define cuánto ancho ocupan los bloques en el editor.';

  @override
  String get settingsEnterCreatesNewBlockTitle => 'Enter crea un bloque nuevo';

  @override
  String get settingsEnterCreatesNewBlockSubtitleWhenEnabled =>
      'Desactiva para que Enter inserte salto de línea.';

  @override
  String get settingsEnterCreatesNewBlockSubtitleWhenDisabled =>
      'Ahora Enter inserta salto de línea. Usa Shift+Enter igual.';

  @override
  String get settingsWorkspaceSubsection => 'Espacio de trabajo';

  @override
  String get settingsCustomIconsTitle => 'Iconos personalizados';

  @override
  String get settingsCustomIconsDescription =>
      'Importa una URL PNG, GIF o WebP, o un data:image compatible copiado desde páginas como notionicons.so. Después podrás usarlo como icono de página o de callout.';

  @override
  String settingsCustomIconsSavedCount(int count) {
    return '$count guardados';
  }

  @override
  String get settingsCustomIconsChipUrl => 'URL PNG, GIF o WebP';

  @override
  String get settingsCustomIconsChipDataImage => 'data:image/*';

  @override
  String get settingsCustomIconsChipPaste => 'Pegar desde portapapeles';

  @override
  String get settingsCustomIconsImportTitle => 'Importar nuevo icono';

  @override
  String get settingsCustomIconsImportSubtitle =>
      'Puedes ponerle nombre y pegar la fuente manualmente o traerla directamente desde el portapapeles.';

  @override
  String get settingsCustomIconsFieldNameLabel => 'Nombre';

  @override
  String get settingsCustomIconsFieldNameHint => 'Opcional';

  @override
  String get settingsCustomIconsFieldSourceLabel => 'URL o data:image';

  @override
  String get settingsCustomIconsFieldSourceHint =>
      'https://…gif | …webp | …png o data:image/…';

  @override
  String get settingsCustomIconsImportButton => 'Importar icono';

  @override
  String get settingsCustomIconsFromClipboard => 'Desde portapapeles';

  @override
  String get settingsCustomIconsLibraryTitle => 'Biblioteca';

  @override
  String get settingsCustomIconsLibrarySubtitle =>
      'Listos para usar en toda la app';

  @override
  String get settingsCustomIconsEmpty => 'Todavía no has importado iconos.';

  @override
  String get settingsCustomIconsDeleteTooltip => 'Eliminar icono';

  @override
  String get settingsCustomIconsReferenceCopiedSnack => 'Referencia copiada.';

  @override
  String get settingsCustomIconsCopyToken => 'Copiar token';

  @override
  String get settingsAiHeroQuillWithLocalAlt =>
      'La IA se ejecuta en Quill Cloud (suscripción con IA en la nube o tinta comprada). Elige otro proveedor abajo para Ollama o LM Studio en local.';

  @override
  String get settingsAiHeroQuillCloudOnly =>
      'La IA se ejecuta en Quill Cloud (suscripción con IA en la nube o tinta comprada).';

  @override
  String get settingsAiHeroLocalDefault =>
      'Conecta Ollama o LM Studio en local; el asistente usa el modelo y el contexto que configures aquí.';

  @override
  String get settingsAiHeroQuillMobileOnly =>
      'En este dispositivo Quill solo puede usar Quill Cloud. Elige Quill Cloud como proveedor cuando quieras activar la IA.';

  @override
  String get settingsAiChipCloud => 'En la nube';

  @override
  String get settingsAiSnackFirebaseUnavailableBuild =>
      'Firebase no está disponible en esta compilación.';

  @override
  String get settingsAiSnackSignInCloudAccount =>
      'Inicia sesión en la cuenta en la nube (Ajustes).';

  @override
  String settingsAiProviderSwitchFailed(Object error) {
    return 'Error al cambiar proveedor: $error';
  }

  @override
  String get settingsAboutHeroDescription =>
      'Versión instalada, origen de actualizaciones y comprobación manual de novedades.';

  @override
  String get settingsOpenReleaseNotes => 'Ver notas de versión';

  @override
  String get settingsUpdateChannelLabel => 'Canal';

  @override
  String get settingsUpdateChannelRelease => 'Release';

  @override
  String get settingsUpdateChannelBeta => 'Beta';

  @override
  String get settingsDataHeroDescription =>
      'Acciones permanentes sobre archivos locales. Haz una copia de seguridad antes de borrar.';

  @override
  String get settingsDangerZoneTitle => 'Zona de peligro';

  @override
  String get settingsDesktopHeroDescription =>
      'Atajos globales, bandeja del sistema y comportamiento de la ventana en el escritorio.';

  @override
  String get settingsShortcutsHeroDescription =>
      'Combinaciones solo dentro de Folio. Prueba una tecla antes de guardarla.';

  @override
  String get settingsShortcutsTestChip => 'Probar';

  @override
  String get settingsIntegrationsChipApprovedPermissions =>
      'Permisos aprobados';

  @override
  String get settingsIntegrationsChipRevocableAccess => 'Acceso revocable';

  @override
  String get settingsIntegrationsChipExternalApps => 'Apps externas';

  @override
  String get settingsIntegrationsActiveConnectionsTitle => 'Conexiones activas';

  @override
  String get settingsIntegrationsActiveConnectionsSubtitle =>
      'Apps que ya pueden interactuar con Folio';

  @override
  String get settingsViewInkUsageTable => 'Ver tabla de consumo';

  @override
  String get settingsCloudInkUsageTableTitle =>
      'Tabla de consumo de gotas (Quill Cloud)';

  @override
  String get settingsCloudInkUsageTableIntro =>
      'Coste base por acción. Se pueden aplicar suplementos por prompts largos y por tokens de salida.';

  @override
  String get settingsCloudInkDrops => 'gotas';

  @override
  String get settingsCloudInkTableCachedNotice =>
      'Mostrando tabla en caché local (sin conexión al backend).';

  @override
  String get settingsCloudInkOpRewriteBlock => 'Reescribir bloque';

  @override
  String get settingsCloudInkOpSummarizeSelection => 'Resumir selección';

  @override
  String get settingsCloudInkOpExtractTasks => 'Extraer tareas';

  @override
  String get settingsCloudInkOpSummarizePage => 'Resumir página';

  @override
  String get settingsCloudInkOpGenerateInsert => 'Generar inserción';

  @override
  String get settingsCloudInkOpGeneratePage => 'Generar página';

  @override
  String get settingsCloudInkOpChatTurn => 'Turno de chat';

  @override
  String get settingsCloudInkOpAgentMain => 'Ejecución de agente';

  @override
  String get settingsCloudInkOpAgentFollowup => 'Seguimiento de agente';

  @override
  String get settingsCloudInkOpEditPagePanel => 'Edición de página (panel)';

  @override
  String get settingsCloudInkOpDefault => 'Operación por defecto';

  @override
  String get settingsDesktopRailSubtitle =>
      'Elige una categoría en la lista o desplázate por el contenido.';

  @override
  String get settingsCloudInkViewTableButton => 'Ver tabla';

  @override
  String get settingsCloudInkHostedAiQuillCloudHint =>
      'Precios de referencia para IA en nube en Quill Cloud.';

  @override
  String get vaultStarterHomeTitle => 'Empieza aquí';

  @override
  String get vaultStarterHomeHeading => 'Tu libreta ya está lista';

  @override
  String get vaultStarterHomeIntro =>
      'Folio organiza tus páginas en un árbol, edita contenido por bloques y mantiene los datos en este dispositivo. Esta mini guía te deja un mapa rápido de lo que puedes hacer desde el primer minuto.';

  @override
  String get vaultStarterHomeCallout =>
      'Puedes borrar, renombrar o mover estas páginas cuando quieras. Son solo una base para arrancar más rápido.';

  @override
  String get vaultStarterHomeSectionTips => 'Lo más útil para empezar';

  @override
  String get vaultStarterHomeBulletSlash =>
      'Pulsa / dentro de un párrafo para insertar encabezados, listas, tablas, bloques de código, Mermaid y más.';

  @override
  String get vaultStarterHomeBulletSidebar =>
      'Usa el panel lateral para crear páginas y subpáginas, y reorganiza el árbol según tu forma de trabajar.';

  @override
  String get vaultStarterHomeBulletSettings =>
      'Abre Ajustes para activar IA, configurar copia de seguridad, cambiar idioma o añadir desbloqueo rápido.';

  @override
  String get vaultStarterHomeTodo1 => 'Crear mi primera página de trabajo';

  @override
  String get vaultStarterHomeTodo2 =>
      'Probar el menú / para insertar un bloque nuevo';

  @override
  String get vaultStarterHomeTodo3 =>
      'Revisar Ajustes y decidir si quiero activar Quill o un método de desbloqueo rápido';

  @override
  String get vaultStarterCapabilitiesTitle => 'Qué puede hacer Folio';

  @override
  String get vaultStarterCapabilitiesSectionMain => 'Capacidades principales';

  @override
  String get vaultStarterCapabilitiesBullet1 =>
      'Tomar notas con estructura libre usando párrafos, títulos, listas, checklists, citas y divisores.';

  @override
  String get vaultStarterCapabilitiesBullet2 =>
      'Trabajar con bloques especiales como tablas, bases de datos, archivos, audio, vídeo, embeds y diagramas Mermaid.';

  @override
  String get vaultStarterCapabilitiesBullet3 =>
      'Buscar contenido, revisar historial de página y mantener revisiones dentro de la misma libreta.';

  @override
  String get vaultStarterCapabilitiesBullet4 =>
      'Exportar o importar datos, incluyendo copia de la libreta e importación desde Notion.';

  @override
  String get vaultStarterCapabilitiesSectionShortcuts => 'Atajos rápidos';

  @override
  String get vaultStarterCapabilitiesShortcutN =>
      'Ctrl+N crea una página nueva.';

  @override
  String get vaultStarterCapabilitiesShortcutSearch =>
      'Ctrl+K o Ctrl+F abre la búsqueda.';

  @override
  String get vaultStarterCapabilitiesShortcutSettings =>
      'Ctrl+, abre Ajustes y Ctrl+L bloquea la libreta.';

  @override
  String get vaultStarterCapabilitiesAiCallout =>
      'La IA no se activa por defecto. Si decides usar Quill, la configuras en Ajustes y eliges proveedor, modelo y permisos de contexto.';

  @override
  String get vaultStarterQuillTitle => 'Quill y privacidad';

  @override
  String get vaultStarterQuillSectionWhat => 'Qué puede hacer Quill';

  @override
  String get vaultStarterQuillBullet1 =>
      'Resumir, reescribir o expandir el contenido de una página.';

  @override
  String get vaultStarterQuillBullet2 =>
      'Responder dudas sobre bloques, atajos y formas de organizar tus notas en Folio.';

  @override
  String get vaultStarterQuillBullet3 =>
      'Trabajar con la página abierta como contexto o con varias páginas que selecciones como referencia.';

  @override
  String get vaultStarterQuillSectionPrivacy => 'Privacidad y seguridad';

  @override
  String get vaultStarterQuillPrivacyBody =>
      'Tus páginas viven en este dispositivo. Si habilitas IA, revisa qué contexto compartes y con qué proveedor. Si olvidas la contraseña maestra de una libreta cifrada, Folio no puede recuperarlo por ti.';

  @override
  String get vaultStarterQuillBackupCallout =>
      'Haz una copia de la libreta cuando tengas contenido importante. La copia conserva los datos y adjuntos, pero no transfiere Hello ni passkeys entre dispositivos.';

  @override
  String get vaultStarterQuillMermaidCaption => 'Prueba rápida de Mermaid:';

  @override
  String get vaultStarterQuillMermaidSource =>
      'graph TD\nInicio[Crear libreta] --> Organizar[Organizar páginas]\nOrganizar --> Escribir[Escribir y enlazar ideas]\nEscribir --> Revisar[Buscar, revisar y mejorar]';
}
