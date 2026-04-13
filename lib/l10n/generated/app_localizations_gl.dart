// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Galician (`gl`).
class AppLocalizationsGl extends AppLocalizations {
  AppLocalizationsGl([String locale = 'gl']) : super(locale);

  @override
  String get appTitle => 'Folio';

  @override
  String get loading => 'Cargando…';

  @override
  String get newVault => 'Nova caixa forte';

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
  String get retry => 'Tentar de novo';

  @override
  String get settings => 'Axustes';

  @override
  String get lockNow => 'Bloquear';

  @override
  String get pageHistory => 'Historial da páxina';

  @override
  String get untitled => 'Sen título';

  @override
  String get noPages => 'Non hai páxinas';

  @override
  String get createPage => 'Crear páxina';

  @override
  String get selectPage => 'Seleccionar unha páxina';

  @override
  String get saveInProgress => 'Gardando…';

  @override
  String get savePending => 'Pendente de gardar';

  @override
  String get savingVaultTooltip =>
      'Gardando a caixa forte cifrada no disco… [cite: 2]';

  @override
  String get autosaveSoonTooltip => 'Gardado automático nun momento…';

  @override
  String get welcomeTitle => 'Benvida';

  @override
  String get welcomeBody =>
      'Folio garda as túas páxinas só neste dispositivo, cifradas cunha contrasinal mestra. Se a esqueces, non podemos recuperar os teus datos.\n\nNon hai sincronización na nube.';

  @override
  String get createNewVault => 'Crear nova caixa forte';

  @override
  String get importBackupZip => 'Importar copia de seguridade (.zip)';

  @override
  String get importBackupTitle => 'Importar copia de seguridade';

  @override
  String get importBackupBody =>
      'O ficheiro contén os mesmos datos cifrados que o outro dispositivo. [cite: 3] Precisas a contrasinal mestra utilizada para crear esa copia.\n\nAs chaves de acceso (passkey) e o desbloqueo rápido (Hello) non están incluídos e non son transferibles; [cite: 3, 4] podes configuralos máis tarde en Axustes.';

  @override
  String get chooseZipFile => 'Escoller ficheiro .zip';

  @override
  String get changeFile => 'Cambiar ficheiro';

  @override
  String get backupPasswordLabel => 'Contrasinal da copia';

  @override
  String get backupPlainNoPasswordHint =>
      'Esta copia de seguridade non está cifrada. [cite: 5] Non se require contrasinal para importala.';

  @override
  String get importVault => 'Importar caixa forte';

  @override
  String get masterPasswordTitle => 'A túa contrasinal mestra';

  @override
  String masterPasswordHint(int min) {
    return 'Polo menos $min caracteres. [cite: 6] Usaraa cada vez que abras Folio.';
  }

  @override
  String get createStarterPagesTitle => 'Crear páxinas de axuda iniciais';

  @override
  String get createStarterPagesBody =>
      'Engade unha pequena guía con exemplos, atallos e funcións de Folio. [cite: 7] Podes eliminar esas páxinas máis tarde.';

  @override
  String get passwordLabel => 'Contrasinal';

  @override
  String get confirmPasswordLabel => 'Confirmar contrasinal';

  @override
  String get next => 'Seguinte';

  @override
  String get readyTitle => 'Todo listo';

  @override
  String get readyBody =>
      'Crearase unha caixa forte cifrada neste dispositivo. [cite: 8] Máis tarde podes engadir Windows Hello, biometría ou unha chave de acceso para un desbloqueo máis rápido (Axustes).';

  @override
  String get quillIntroTitle => 'Coñece a Quill';

  @override
  String get quillIntroBody =>
      'Quill é o asistente integrado de Folio. [cite: 9] Pode axudarte a escribir, editar e entender as túas páxinas, e tamén responder preguntas sobre como usar a aplicación.';

  @override
  String get quillIntroCapabilityWrite =>
      'Pode redactar, resumir ou reescribir contido dentro das túas páxinas.';

  @override
  String get quillIntroCapabilityExplain =>
      'Tamén responde preguntas sobre Folio, atallos, bloques e como organizar as túas notas.';

  @override
  String get quillIntroCapabilityContext =>
      'Podes deixar que use a páxina actual como contexto ou escoller varias páxinas de referencia.';

  @override
  String get quillIntroCapabilityExamples =>
      'A mellor parte: fálalle con naturalidade e Quill decidirá se debe responder ou editar.';

  @override
  String get quillIntroExamplesTitle => 'Exemplos rápidos';

  @override
  String get quillIntroExampleOne => 'Resume esta páxina en tres puntos.';

  @override
  String get quillIntroExampleTwo =>
      'Cambia o título [cite: 10] e mellora a introdución.';

  @override
  String get quillIntroExampleThree => 'Como engado unha imaxe ou unha táboa?';

  @override
  String get quillIntroFootnote =>
      'Se a IA aínda non está activada, podes activala máis tarde. [cite: 11] Esta introdución está aquí para que entendes o que pode facer Quill cando o uses.';

  @override
  String get createVault => 'Crear caixa forte';

  @override
  String minCharactersError(int min) {
    return 'Mínimo $min caracteres.';
  }

  @override
  String get passwordMismatchError => 'As contrasinais non coinciden.';

  @override
  String get passwordMustBeStrongError =>
      'A contrasinal debe ser Forte para continuar.';

  @override
  String get passwordStrengthLabel => 'Seguridade';

  @override
  String get passwordStrengthVeryWeak => 'Moi feble';

  @override
  String get passwordStrengthWeak => 'Feble';

  @override
  String get passwordStrengthFair => 'Aceptable';

  @override
  String get passwordStrengthStrong => 'Forte';

  @override
  String get showPassword => 'Amosar contrasinal';

  @override
  String get hidePassword => 'Agochar contrasinal';

  @override
  String get chooseZipError => 'Escolle un ficheiro .zip.';

  @override
  String get enterBackupPasswordError => 'Introduce a contrasinal da copia.';

  @override
  String importFailedError(Object error) {
    return 'Non se puido [cite: 12] importar: $error';
  }

  @override
  String createVaultFailedError(Object error) {
    return 'Non se puido crear a caixa forte: $error';
  }

  @override
  String get encryptedVault => 'Caixa forte cifrada';

  @override
  String get unlock => 'Desbloquear';

  @override
  String get quickUnlock => 'Hello / biometría';

  @override
  String get passkey => 'Chave de acceso';

  @override
  String get unlockFailed => 'Contrasinal incorrecta ou caixa forte danada.';

  @override
  String get appearance => 'Apariencia';

  @override
  String get security => 'Seguridade';

  @override
  String get vaultBackup => 'Copia da caixa forte';

  @override
  String get data => 'Datos';

  @override
  String get systemTheme => 'Sistema';

  @override
  String get lightTheme => 'Claro';

  @override
  String get darkTheme => 'Escuro';

  @override
  String get language => 'Idioma';

  @override
  String get useSystemLanguage => 'Usar o idioma do sistema';

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
  String get active => 'Activo';

  @override
  String get inactive => 'Inactivo';

  @override
  String get remove => 'Eliminar';

  @override
  String get enable => 'Activar';

  @override
  String get register => 'Rexistrar';

  @override
  String get revoke => 'Revogar';

  @override
  String get save => 'Gardar';

  @override
  String get delete => 'Eliminar';

  @override
  String get rename => 'Renomear';

  @override
  String get change => 'Cambiar';

  @override
  String get importAction => 'Importar';

  @override
  String get masterPassword => 'Contrasinal mestra';

  @override
  String get confirmIdentity => 'Confirmar identidade';

  @override
  String get quickUnlockTitle => 'Desbloqueo rápido (Hello / biometría)';

  @override
  String get passkeyThisDevice => 'WebAuthn neste dispositivo';

  @override
  String get lockOnMinimize => 'Bloquear ao minimizar';

  @override
  String get changeMasterPassword => 'Cambiar contrasinal mestra';

  @override
  String get requiresCurrentPassword => 'Require a contrasinal actual';

  @override
  String get lockAutoByInactivity => 'Bloqueo automático por inactividade';

  @override
  String minutesShort(int minutes) {
    return '$minutes min';
  }

  @override
  String get settingsAppearanceHint =>
      'A cor principal segue a cor de acento de Windows cando está dispoñible.';

  @override
  String get backupFilePasswordLabel => 'Contrasinal do ficheiro de copia';

  @override
  String get backupFilePasswordHelper =>
      'Usa a contrasinal mestra utilizada para crear esta copia, non a doutro dispositivo.';

  @override
  String get backupPasswordDialogTitle => 'Contrasinal da copia';

  @override
  String get currentPasswordLabel => 'Contrasinal [cite: 14] actual';

  @override
  String get newPasswordLabel => 'Nova contrasinal';

  @override
  String get confirmNewPasswordLabel => 'Confirmar nova contrasinal';

  @override
  String passwordStrengthWithValue(Object value) {
    return 'Seguridade: $value';
  }

  @override
  String get fillAllFieldsError => 'Encha todos os campos.';

  @override
  String get newPasswordsMismatchError =>
      'As novas contrasinais non coinciden.';

  @override
  String get newPasswordMustBeStrongError =>
      'A nova contrasinal debe ser Forte.';

  @override
  String get newPasswordMustDifferError =>
      'A nova contrasinal debe ser diferente.';

  @override
  String get incorrectPasswordError => 'Contrasinal incorrecta.';

  @override
  String get useHelloBiometrics => 'Usar Hello / biometría';

  @override
  String get usePasskey => 'Usar chave de acceso';

  @override
  String get quickUnlockEnabledSnack => 'Desbloqueo rápido activado';

  @override
  String get quickUnlockDisabledSnack => 'Desbloqueo rápido desactivado';

  @override
  String get quickUnlockEnableFailed =>
      'Non se puido activar o desbloqueo rápido.';

  @override
  String get passkeyRevokeConfirmTitle => 'Eliminar chave de acceso?';

  @override
  String get passkeyRevokeConfirmBody =>
      'Precisarás a túa contrasinal mestra para desbloquear ata que rexistres unha nova chave de acceso [cite: 15] neste dispositivo.';

  @override
  String get passkeyRegisteredSnack => 'Chave de acceso rexistrada';

  @override
  String get passkeyRevokedSnack => 'Chave de acceso revogada';

  @override
  String get masterPasswordUpdatedSnack => 'Contrasinal mestra actualizada';

  @override
  String get backupSavedSuccessSnack =>
      'Copia de seguridade gardada con éxito.';

  @override
  String exportFailedError(Object error) {
    return 'Non se puido exportar: $error';
  }

  @override
  String importFailedGenericError(Object error) {
    return 'Non se puido importar: $error';
  }

  @override
  String wipeFailedError(Object error) {
    return 'Non se puido eliminar a caixa forte: $error';
  }

  @override
  String get filePathReadError => 'Non se puido ler a ruta do ficheiro.';

  @override
  String get importedVaultSuccessSnack =>
      'Caixa forte importada. [cite: 16] Aparece no selector lateral; a actual permanece sen cambios.';

  @override
  String get exportVaultDialogTitle => 'Exportar copia da caixa forte';

  @override
  String get exportVaultDialogBody =>
      'Para crear un ficheiro de copia, confirma a túa identidade coa caixa forte actualmente desbloqueada.';

  @override
  String get verifyAndExport => 'Verificar e exportar';

  @override
  String get saveVaultBackupDialogTitle => 'Gardar copia da caixa forte';

  @override
  String get importVaultDialogTitle => 'Importar copia da caixa forte';

  @override
  String get importVaultDialogBody =>
      'Engadirase unha nova caixa forte dende o ficheiro. [cite: 17] A túa caixa forte actual non se elimina nin se modifica.\n\nA contrasinal do ficheiro será a da caixa forte importada.\n\nAs chaves de acceso e o desbloqueo rápido non se inclúen nas copias; [cite: 18] podes configuralos máis tarde para esa caixa forte.\n\nContinuar?';

  @override
  String get verifyAndContinue => 'Verificar e continuar';

  @override
  String get verifyAndDelete => 'Verificar con contrasinal e eliminar';

  @override
  String get importIdentityBody =>
      'Demostra que es ti coa caixa forte actual antes de importar.';

  @override
  String get wipeVaultDialogTitle => 'Eliminar caixa forte';

  @override
  String get wipeVaultDialogBody =>
      'Eliminaranse todas as páxinas e a contrasinal mestra deixará de ser válida. [cite: 19] Esta acción non se pode deshacer.\n\nEstás seguro de que queres continuar?';

  @override
  String get wipeIdentityBody =>
      'Para eliminar a caixa forte, demostra a túa identidade.';

  @override
  String get exportZipTitle => 'Exportar copia (.zip)';

  @override
  String get exportZipSubtitle =>
      'Contrasinal, Hello ou chave de acceso da caixa actual';

  @override
  String get importZipTitle => 'Importar copia (.zip)';

  @override
  String get importZipSubtitle =>
      'Engade unha nova caixa forte · identidade actual + contrasinal do ficheiro';

  @override
  String get backupInfoBody =>
      'O ficheiro contén os mesmos datos cifrados que no disco (vault.keys e vault.bin), sen expoñer o contido en texto plano. [cite: 20] As imaxes adxuntas inclúense tal cal.\n\nAs chaves de acceso e o desbloqueo rápido non son transferibles entre dispositivos; [cite: 21] podes configuralos de novo para cada caixa forte importada.\n\nImportar engade unha nova caixa forte; [cite: 22] non substitúe á que está aberta.';

  @override
  String get wipeCardTitle => 'Eliminar caixa forte e comezar de novo';

  @override
  String get wipeCardSubtitle =>
      'Require contrasinal, Hello ou chave de acceso.';

  @override
  String get switchVaultTooltip => 'Cambiar de caixa forte';

  @override
  String get switchVaultTitle => 'Cambiar de caixa forte';

  @override
  String get switchVaultBody =>
      'Pecherase esta sesión e terás que desbloquear a outra caixa forte coa súa contrasinal, Hello ou chave de acceso.';

  @override
  String get renameVaultTitle => 'Renomear caixa forte';

  @override
  String get nameLabel => 'Nome';

  @override
  String get deleteOtherVaultTitle => 'Eliminar outra caixa forte';

  @override
  String get deleteVaultConfirmTitle => 'Eliminar caixa forte?';

  @override
  String deleteVaultConfirmBody(Object name) {
    return 'A caixa forte «$name» eliminarase por completo. [cite: 23] Isto non se pode deshacer.';
  }

  @override
  String get vaultDeletedSnack => 'Caixa forte eliminada.';

  @override
  String get noOtherVaultsSnack =>
      'Non hai outras caixas fortes para eliminar.';

  @override
  String get addVault => 'Engadir caixa forte';

  @override
  String get renameActiveVault => 'Renomear caixa forte activa';

  @override
  String get deleteOtherVault => 'Eliminar outra caixa forte…';

  @override
  String get activeVaultLabel => 'Caixa forte activa';

  @override
  String get sidebarVaultsLoading => 'Cargando caixas fortes…';

  @override
  String get sidebarVaultsEmpty => 'Non hai caixas fortes dispoñibles';

  @override
  String get forceSyncTooltip => 'Forzar sincronización';

  @override
  String get searchDialogFooterHint =>
      'Intro abre o resultado resaltado · Ctrl+↑ / Ctrl+↓ navegar · Esc pecha';

  @override
  String get searchFilterTasks => 'Tarefas';

  @override
  String get searchRecentQueries => 'Buscas recentes';

  @override
  String get searchShortcutsHelpTooltip => 'Atallos de teclado';

  @override
  String get searchShortcutsHelpTitle => 'Busca global';

  @override
  String get searchShortcutsHelpBody =>
      'Intro: abrir o resultado resaltado\nCtrl+↑ ou Ctrl+↓: anterior / seguinte resultado\nEsc: pechar';

  @override
  String get renamePageTitle => 'Renomear páxina';

  @override
  String get titleLabel => 'Título';

  @override
  String get rootPage => 'Raíz';

  @override
  String movePageTitle(Object title) {
    return 'Mover “$title”';
  }

  @override
  String get subpage => 'Subpáxina';

  @override
  String get move => 'Mover';

  @override
  String get pages => 'Páxinas';

  @override
  String get pageOutlineTitle => 'Esquema';

  @override
  String get pageOutlineEmpty =>
      'Engade encabezados (H1–H3) para construír o esquema.';

  @override
  String get showPageOutline => 'Amosar esquema';

  @override
  String get hidePageOutline => 'Agochar esquema';

  @override
  String get tocBlockTitle => 'Índice de contidos';

  @override
  String get showSidebar => 'Amosar barra lateral';

  @override
  String get hideSidebar => 'Agochar barra lateral';

  @override
  String get resizeSidebarHandle => 'Redimensionar barra lateral';

  @override
  String get resizeSidebarHandleHint =>
      'Arrastra horizontalmente para cambiar o ancho da barra lateral';

  @override
  String get resizeAiPanelHeightHandle => 'Redimensionar altura do asistente';

  @override
  String get resizeAiPanelHeightHandleHint =>
      'Arrastra verticalmente para cambiar a altura do panel do asistente';

  @override
  String get sidebarAutoRevealTitle =>
      'Amosar barra lateral ao achegar o punteiro';

  @override
  String get sidebarAutoRevealSubtitle =>
      'Cando a barra lateral estea agochada, move o [cite: 25] punteiro ao bordo esquerdo para amosala temporalmente.';

  @override
  String get newRootPageTooltip => 'Nova páxina (raíz)';

  @override
  String get blockOptions => 'Opcións do bloque';

  @override
  String get meetingNoteTitle => 'Nota de reunión';

  @override
  String get meetingNoteDesktopOnly => 'Dispoñible só en escritorio.';

  @override
  String get meetingNoteStartRecording => 'Iniciar gravación';

  @override
  String get meetingNotePreparing => 'Preparando…';

  @override
  String get meetingNoteTranscriptionLanguage => 'Idioma da transcrición';

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
      'Os dispositivos de entrada/saída configúranse en Axustes > Escritorio.';

  @override
  String meetingNoteModelInSettings(Object model) {
    return 'Modelo de transcrición: $model (en Axustes > Escritorio).';
  }

  @override
  String get meetingNoteDescription =>
      'Grava o micrófono e o audio do sistema. A transcrición xérase localmente.';

  @override
  String meetingNoteWhisperInitError(Object error) {
    return 'Non se puido inicializar Whisper: $error';
  }

  @override
  String get meetingNoteAudioAccessError =>
      'Non se puido acceder ao micrófono/dispositivos.';

  @override
  String get meetingNoteMicrophoneAccessError =>
      'Non se puido acceder ao micrófono.';

  @override
  String get meetingNoteChunkTranscriptionError =>
      'Non se puido transcribir este fragmento de audio.';

  @override
  String get meetingNoteProviderLocal => 'Local (Whisper)';

  @override
  String get meetingNoteProviderCloud => 'Quill Cloud';

  @override
  String get meetingNoteProviderCloudCost =>
      '1 Ink por cada 5 min. [cite: 27] gravados';

  @override
  String get meetingNoteCloudFallbackNotice =>
      'Nube non dispoñible. Usando Whisper local.';

  @override
  String get meetingNoteCloudInkExhaustedNotice =>
      'Ink insuficiente. [cite: 28] Cambiando a Whisper local.';

  @override
  String meetingNoteCloudRecordingBadge(Object language) {
    return 'Quill Cloud | Idioma: $language';
  }

  @override
  String get meetingNoteCloudProcessing => 'Procesando con Quill Cloud…';

  @override
  String get meetingNoteCloudProcessingSubtitle =>
      'Detectando falantes e mellorando a calidade. [cite: 29] Agarda, por favor.';

  @override
  String meetingNoteCloudProgress(int done, int total) {
    return 'Fragmentos procesados: $done/$total';
  }

  @override
  String meetingNoteCloudEta(Object remaining) {
    return 'Tempo restante estimado: $remaining';
  }

  @override
  String get meetingNoteCloudEtaCalculating => 'Calculando o tempo restante...';

  @override
  String get meetingNoteCloudRequiresAccount =>
      'Require unha conta de Folio Cloud con Ink.';

  @override
  String get meetingNoteCloudRequiresAiEnabled =>
      'Activa a IA en Axustes para usar a transcrición na nube (Quill Cloud).';

  @override
  String meetingNoteHardwareSummary(int cpus, Object ramLabel) {
    return '$cpus núcleos · $ramLabel';
  }

  @override
  String get meetingNoteHardwareRamUnknown => 'RAM descoñecida';

  @override
  String meetingNoteHardwareRecommended(Object modelLabel) {
    return 'Modelo recomendado para este equipo: $modelLabel';
  }

  @override
  String get meetingNoteLocalTranscriptionNotViable =>
      'Este equipo non cumpre os requisitos mínimos para transcrición local. Só se gardará o audio, agás que actives «Forzar transcrición local» en Axustes ou uses Quill Cloud con IA activada.';

  @override
  String get meetingNoteGenerateTranscription => 'Xerar transcrición';

  @override
  String get meetingNoteGenerateTranscriptionSubtitle =>
      'Desactívao para gardar só o audio nesta nota.';

  @override
  String get meetingNoteSettingsAutoWhisperModel =>
      'Escoller modelo automaticamente segundo o hardware';

  @override
  String get meetingNoteSettingsForceLocalTranscription =>
      'Forzar transcrición local (pode ir lento ou inestable)';

  @override
  String get meetingNoteSettingsHardwareIntro =>
      'Rendemento detectado para transcrición local.';

  @override
  String get meetingNoteRecordingAudioOnlyBadge => 'Só audio';

  @override
  String get meetingNotePerNoteTranscriptionOffHint =>
      'A transcrición está desactivada para esta nota.';

  @override
  String get meetingNoteTranscriptionProvider => 'Motor de transcrición';

  @override
  String meetingNoteRecordingTime(Object mm, Object ss) {
    return 'Gravando  $mm:$ss';
  }

  @override
  String meetingNoteRecordingBadge(Object language, Object model) {
    return 'Idioma: $language | [cite: 31] Modelo: $model';
  }

  @override
  String get meetingNoteSystemAudioCaptured => 'Audio do sistema capturado';

  @override
  String get meetingNoteStop => 'Parar';

  @override
  String get meetingNoteWaitingTranscription => 'Agardando pola transcrición…';

  @override
  String get meetingNoteTranscribing => 'Transcribindo…';

  @override
  String get meetingNoteTranscriptionTitle => 'Transcrición';

  @override
  String get meetingNoteNoTranscription => 'Non hai transcrición dispoñible.';

  @override
  String get meetingNoteNewRecording => 'Nova gravación';

  @override
  String get meetingNoteSettingsSection => 'Nota de reunión (audio)';

  @override
  String get meetingNoteSettingsDescription =>
      'Estes dispositivos úsanse por defecto ao gravar unha nota de reunión.';

  @override
  String get meetingNoteSettingsMicrophone => 'Microfón';

  @override
  String get meetingNoteSettingsRefreshDevices => 'Actualizar lista';

  @override
  String get meetingNoteSettingsSystemDefault => 'Predeterminado do sistema';

  @override
  String get meetingNoteSettingsSystemOutput => 'Saída do sistema (loopback)';

  @override
  String get meetingNoteSettingsModel => 'Modelo de transcrición';

  @override
  String get meetingNoteDiarizationHint =>
      'Procesamento 100% local [cite: 32] no teu dispositivo.';

  @override
  String get meetingNoteModelTiny => 'Rápido';

  @override
  String get meetingNoteModelBase => 'Equilibrado';

  @override
  String get meetingNoteModelSmall => 'Preciso';

  @override
  String get meetingNoteModelMedium => 'Avanzado';

  @override
  String get meetingNoteModelTurbo => 'Máxima calidade';

  @override
  String get meetingNoteCopyTranscript => 'Copiar transcrición';

  @override
  String get meetingNoteSendToAi => 'Enviar á IA…';

  @override
  String get meetingNoteAiPayloadLabel => 'Que enviar á IA?';

  @override
  String get meetingNoteAiPayloadTranscript => 'Só a transcrición';

  @override
  String get meetingNoteAiPayloadAudio => 'Só o audio';

  @override
  String get meetingNoteAiPayloadBoth => 'Transcrición + audio';

  @override
  String get meetingNoteAiInstructionHint =>
      'ex: [cite: 33] resumir os puntos clave';

  @override
  String get meetingNoteAiNoAudio => 'Non hai audio dispoñible para este modo';

  @override
  String get meetingNoteAiInstruction => 'Instrución para a IA';

  @override
  String get dragToReorder => 'Arrastrar para reordenar';

  @override
  String get addBlock => 'Engadir bloque';

  @override
  String get blockMentionPageSubtitle => 'Mencionar páxina';

  @override
  String get blockTypesSheetTitle => 'Tipos de bloque';

  @override
  String get blockTypesSheetSubtitle => 'Escolle como se verá este bloque';

  @override
  String get blockTypeFilterEmpty => 'Nada coincide coa túa busca';

  @override
  String get fileNotFound => 'Ficheiro non atopado';

  @override
  String get couldNotLoadImage => 'Non se puido cargar a imaxe';

  @override
  String get noImageHint => 'Sen imaxe · usa o menú ⋮ ou o botón de abaixo';

  @override
  String get chooseImage => 'Escoller imaxe';

  @override
  String get replaceFile => 'Substituír ficheiro';

  @override
  String get removeFile => 'Eliminar ficheiro';

  @override
  String get replaceVideo => 'Substituír vídeo';

  @override
  String get removeVideo => 'Eliminar vídeo';

  @override
  String get openExternal => 'Abrir externamente';

  @override
  String get openVideoExternal => 'Abrir vídeo externamente';

  @override
  String get play => 'Reproducir';

  @override
  String get pause => 'Pausar';

  @override
  String get mute => 'Silenciar';

  @override
  String get unmute => 'Activar son';

  @override
  String get fileResolveError => 'Erro ao resolver o ficheiro';

  @override
  String get videoResolveError => 'Erro ao resolver o vídeo';

  @override
  String get fileMissing => 'Ficheiro non atopado';

  @override
  String get videoMissing => 'Vídeo non atopado';

  @override
  String get chooseFile => 'Escoller ficheiro';

  @override
  String get chooseVideo => 'Escoller vídeo';

  @override
  String get noEmbeddedPreview => 'Sen vista previa integrada para este tipo';

  @override
  String get couldNotReadFile => 'Non se puido ler o ficheiro';

  @override
  String get couldNotLoadVideo => 'Non se puido cargar o vídeo';

  @override
  String get couldNotPreviewPdf => 'Non se puido previsualizar o PDF';

  @override
  String get openInYoutubeBrowser => 'Abrir no navegador';

  @override
  String get pasteUrlTitle => 'Pegar ligazón como';

  @override
  String get pasteAsUrl => 'URL';

  @override
  String get pasteAsEmbed => 'Incrustado';

  @override
  String get pasteAsBookmark => 'Marcador';

  @override
  String get pasteAsMention => 'Mención';

  @override
  String get pasteAsUrlSubtitle => 'Inserir ligazón markdown no texto';

  @override
  String get pasteAsEmbedSubtitle =>
      'Bloque de vídeo con vista previa [cite: 35] (YouTube) ou marcador';

  @override
  String get pasteAsBookmarkSubtitle => 'Tarxeta con título e ligazón';

  @override
  String get pasteAsMentionSubtitle =>
      'Ligazón a unha páxina nesta caixa forte';

  @override
  String get tableAddRow => 'Fila';

  @override
  String get tableRemoveRow => 'Eliminar fila';

  @override
  String get tableAddColumn => 'Columna';

  @override
  String get tableRemoveColumn => 'Eliminar col.';

  @override
  String get tablePasteFromClipboard => 'Pegar táboa';

  @override
  String get pickPageForMention => 'Escoller páxina';

  @override
  String get bookmarkTitleHint => 'Título';

  @override
  String get bookmarkOpenLink => 'Abrir ligazón';

  @override
  String get bookmarkSetUrl => 'Definir URL…';

  @override
  String get bookmarkBlockHint => 'Pega unha ligazón ou usa o menú do bloque';

  @override
  String get bookmarkRemove => 'Eliminar marcador';

  @override
  String get embedUnavailable =>
      'A vista web integrada non está dispoñible nesta plataforma. [cite: 36] Abre a ligazón no teu navegador.';

  @override
  String get embedOpenBrowser => 'Abrir no navegador';

  @override
  String get embedSetUrl => 'Definir URL do incrustado…';

  @override
  String get embedRemove => 'Eliminar incrustado';

  @override
  String get embedEmptyHint =>
      'Pega unha ligazón ou define a URL dende o menú do bloque';

  @override
  String get blockSizeSmaller => 'Máis pequeno';

  @override
  String get blockSizeLarger => 'Máis grande';

  @override
  String get blockSizeHalf => '50%';

  @override
  String get blockSizeThreeQuarter => '75%';

  @override
  String get blockSizeFull => '100%';

  @override
  String get pasteAsEmbedSubtitleWeb =>
      'Amosar a páxina dentro do bloque (se é compatible)';

  @override
  String get pasteAsMentionSubtitleRich =>
      'Ligazón co título da páxina (ex: YouTube)';

  @override
  String get formatToolbar => 'Barra de formato';

  @override
  String get linkTitle => 'Ligazón';

  @override
  String get visibleTextLabel => 'Texto visible';

  @override
  String get urlLabel => 'URL';

  @override
  String get urlHint => 'https://…';

  @override
  String get insert => 'Inserir';

  @override
  String get defaultLinkText => 'texto';

  @override
  String get boldTip => 'Negrita (**)';

  @override
  String get italicTip => 'Cursiva (_)';

  @override
  String get underlineTip => 'Subliñado [cite: 37] (<u>)';

  @override
  String get inlineCodeTip => 'Códido en liña (`)';

  @override
  String get strikeTip => 'Riscado (~~)';

  @override
  String get linkTip => 'Ligazón';

  @override
  String get pageHistoryTitle => 'Historial de versións';

  @override
  String get restoreVersionTitle => 'Restaurar versión';

  @override
  String get restoreVersionBody =>
      'O título e o contido da páxina substituiranse por esta versión. [cite: 38] O estado actual gardarase primeiro no historial.';

  @override
  String get restore => 'Restaurar';

  @override
  String get deleteVersionTitle => 'Eliminar versión';

  @override
  String get deleteVersionBody =>
      'Esta entrada eliminarase do historial. [cite: 39] O texto actual da páxina non cambia.';

  @override
  String get noVersionsYet => 'Aínda sen versións';

  @override
  String get historyAppearsHint =>
      'Despois de deixar de escribir uns segundos, o historial de cambios aparecerá aquí.';

  @override
  String get versionControl => 'Control de versións';

  @override
  String get historyHeaderBody =>
      'A caixa forte gárdase rapidamente; [cite: 40] o historial engade unha entrada cando deixas de editar e o contido cambiou.';

  @override
  String versionsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'versións',
      one: 'versión',
    );
    return '$count $_temp0';
  }

  @override
  String get untitledFallback => 'Sen título';

  @override
  String get comparedWithPrevious => 'Comparado coa versión anterior';

  @override
  String get changesFromEmptyStart => 'Cambios dende o inicio baleiro';

  @override
  String get contentLabel => 'Contido';

  @override
  String get titleLabelSimple => 'Título';

  @override
  String get emptyValue => '(baleiro)';

  @override
  String get noTextChanges => 'Sen cambios de texto.';

  @override
  String get aiAssistantTitle => 'Quill';

  @override
  String get aiNoPageSelected => 'Ningunha páxina seleccionada';

  @override
  String get aiChatContextDisabledSubtitle =>
      'Texto da páxina non enviado ao modelo';

  @override
  String aiChatContextUsesCurrentPage(Object title) {
    return 'Contexto: páxina actual ($title)';
  }

  @override
  String get aiChatContextOnePageFallback => 'Contexto: 1 páxina';

  @override
  String aiChatContextNPages(int count) {
    return '$count páxinas no contexto do chat';
  }

  @override
  String get aiChatPageContextTooltip =>
      'Incluír o texto da páxina no contexto do modelo';

  @override
  String get aiChatChooseContextPagesTooltip =>
      'Escoller que páxinas engaden texto ao contexto';

  @override
  String get aiChatContextPagesDialogTitle => 'Páxinas no contexto do chat';

  @override
  String get aiChatContextPagesClear => 'Limpar lista';

  @override
  String get aiChatContextPagesApply => 'Aplicar';

  @override
  String get aiTypingSemantics => 'Quill está escribindo';

  @override
  String get aiRenameChatTooltip => 'Renomear chat';

  @override
  String get aiRenameChatDialogTitle => 'Título do chat';

  @override
  String get aiRenameChatLabel => 'Título amosado na pestana';

  @override
  String get quillWorkspaceTourTitle => 'Quill pode axudar dende aquí';

  @override
  String get quillWorkspaceTourBodyReady =>
      'O teu chat con Quill está listo para preguntas, edicións de páxina e fluxos con contexto.';

  @override
  String get quillWorkspaceTourBodyUnavailable =>
      'Aínda que non estea activo agora, Quill pertence a este espazo e poderás activalo máis tarde dende Axustes.';

  @override
  String get quillWorkspaceTourPointsTitle =>
      'O que [cite: 42] paga a pena saber';

  @override
  String get quillWorkspaceTourPointOne =>
      'Funciona tanto como asistente conversacional como editor para títulos e bloques.';

  @override
  String get quillWorkspaceTourPointTwo =>
      'Pode usar a páxina actual ou varias páxinas como contexto.';

  @override
  String get quillWorkspaceTourPointThree =>
      'Se tocas un exemplo de abaixo, cubrirase o chat cando Quill estea dispoñible.';

  @override
  String get quillWorkspaceTourExamplesTitle => 'Proba mensaxes como';

  @override
  String get quillWorkspaceTourExampleOne =>
      'Explica como organizar esta páxina.';

  @override
  String get quillWorkspaceTourExampleTwo =>
      'Usa estas dúas páxinas para facer un resumo compartido.';

  @override
  String get quillWorkspaceTourExampleThree =>
      'Reescribe este bloque nun ton máis claro.';

  @override
  String get quillTourDismiss => 'Entendido';

  @override
  String get aiExpand => 'Expandir';

  @override
  String get aiCollapse => 'Contraer';

  @override
  String get aiDeleteCurrentChat => 'Eliminar chat actual';

  @override
  String get aiNewChat => 'Novo';

  @override
  String get aiAttach => 'Adxuntar';

  @override
  String get aiChatEmptyHint =>
      'Inicia unha conversa.\nQuill decidirá automaticamente que facer coa túa mensaxe.\nTamén podes preguntar como usar Folio (atallos, axustes, páxinas ou este chat).';

  @override
  String get aiChatEmptyFocusComposer => 'Escribe unha mensaxe';

  @override
  String get aiInputHint =>
      'Escribe a túa mensaxe. Quill actuará como un axente.';

  @override
  String get aiInputHintCopilot => 'Escribe a túa mensaxe...';

  @override
  String get aiContextComposerHint => 'Sen contexto engadido';

  @override
  String get aiContextComposerHelper => 'Usa @ para engadir contexto';

  @override
  String aiContextCurrentPageChip(Object title) {
    return 'Páxina actual: $title';
  }

  @override
  String get aiContextCurrentPageFallback => 'Páxina actual';

  @override
  String get aiContextAddFile => 'Adxuntar ficheiro';

  @override
  String get aiContextAddPage => 'Adxuntar páxina';

  @override
  String get aiShowPanel => 'Amosar panel de IA';

  @override
  String get aiHidePanel => 'Agochar panel de IA';

  @override
  String get aiPanelResizeHandle => 'Redimensionar panel de IA';

  @override
  String get aiPanelResizeHandleHint =>
      'Arrastra horitzontalmente para cambiar o ancho do panel do asistente';

  @override
  String get importMarkdownPage => 'Importar Markdown';

  @override
  String get exportMarkdownPage => 'Exportar Markdown';

  @override
  String get workspaceUndoTooltip => 'Desfacer (Ctrl+Z)';

  @override
  String get workspaceRedoTooltip => 'Refacer (Ctrl+Y)';

  @override
  String get workspaceMoreActionsTooltip => 'Máis accións';

  @override
  String get closeCurrentPage => 'Pechar páxina actual';

  @override
  String aiErrorWithDetails(Object error) {
    return 'Erro de IA: $error';
  }

  @override
  String get aiServiceUnreachable =>
      'Non se puido contactar co servizo de IA no enderezo configurado. [cite: 46] Inicia Ollama ou LM Studio e revisa a URL.';

  @override
  String get aiLaunchProviderWithApp =>
      'Abrir a app de IA cando se inicie Folio';

  @override
  String get aiLaunchProviderWithAppHint =>
      'Tenta iniciar Ollama ou LM Studio en Windows cando o enderezo é localhost. [cite: 47] LM Studio pode precisar que o seu servidor se inicie manualmente.';

  @override
  String get aiContextWindowTokens => 'Xanela de contexto do modelo (tokens)';

  @override
  String get aiContextWindowTokensHint =>
      'Usado para a barra de contexto no chat de IA. [cite: 48] Debe coincidir co teu modelo (ex: 8192, 131072).';

  @override
  String get aiContextUsageUnavailable =>
      'Non se informou do uso de tokens na última resposta.';

  @override
  String aiContextUsageSummary(Object prompt, Object completion) {
    return 'Prompt $prompt · Saída $completion';
  }

  @override
  String aiContextUsageTooltip(int window) {
    return 'Última petición vs a túa xanela de contexto configurada ($window tokens).';
  }

  @override
  String get aiChatKeyboardHint =>
      'Intro para enviar · Ctrl+Intro para nova liña';

  @override
  String aiChatInkRemaining(int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: 'quedan $total gotas de ink',
      one: 'queda 1 gota de ink',
    );
    return '$_temp0';
  }

  @override
  String aiChatInkBreakdownTooltip(int monthly, int purchased) {
    return 'Mensual $monthly · Comprado $purchased';
  }

  @override
  String get aiAgentThought => 'Pensamento de Quill';

  @override
  String get aiAlwaysShowThought =>
      'Amosar sempre [cite: 49] o pensamento da IA';

  @override
  String get aiAlwaysShowThoughtHint =>
      'Se está desactivado, aparece contraído cunha frecha en cada mensaxe.';

  @override
  String get aiBetaBadge => 'BETA';

  @override
  String get aiBetaEnableTitle => 'A IA está en BETA';

  @override
  String get aiBetaEnableBody =>
      'Esta función está actualmente en BETA e pode fallar ou comportarse de forma inesperada.\n\nQueres activala de todos xeitos?';

  @override
  String get aiBetaEnableConfirm => 'Activar BETA';

  @override
  String get ai => 'IA';

  @override
  String get aiEnableToggleTitle => 'Activar IA';

  @override
  String get aiProviderLabel => 'Provedor';

  @override
  String get aiProviderNone => 'Ningún';

  @override
  String get aiEndpoint => 'Endpoint (enderezo)';

  @override
  String get aiModel => 'Modelo';

  @override
  String get aiTimeoutMs => 'Tempo de espera (ms)';

  @override
  String get aiAllowRemoteEndpoint => 'Permitir endpoint remoto';

  @override
  String get aiAllowRemoteEndpointAllowed => 'Hosts remotos permitidos';

  @override
  String get aiAllowRemoteEndpointLocalhostOnly => 'Só localhost';

  @override
  String get aiAllowRemoteEndpointNotConfirmed =>
      'O acceso ao endpoint remoto está activado pero aínda non foi confirmado.';

  @override
  String get aiConnectToListModels => 'Conectar para listar modelos';

  @override
  String aiProviderAutoConfigured(Object provider) {
    return 'Provedor de IA detectado e configurado: $provider';
  }

  @override
  String get aiSetupAssistantTitle => 'Asistente de configuración de IA';

  @override
  String get aiSetupAssistantSubtitle =>
      'Detectar e configurar Ollama ou LM Studio automaticamente.';

  @override
  String get aiSetupWizardTitle => 'Asistente de configuración de IA';

  @override
  String get aiSetupChooseProviderTitle => 'Escoller provedor de IA';

  @override
  String get aiSetupChooseProviderBody =>
      'Primeiro escolle que provedor queres usar. [cite: 51] Despois guiarémoste na instalación e configuración.';

  @override
  String get aiSetupNoProviderTitle => 'Non se detectou provedor activo';

  @override
  String get aiSetupNoProviderBody =>
      'Non atopamos Ollama ou LM Studio en execución.\nSegue os pasos para instalar/iniciar un deles e preme Tentar de novo.';

  @override
  String get aiSetupOllamaTitle => 'Paso 1: Instalar Ollama';

  @override
  String get aiSetupOllamaBody =>
      'Instala Ollama, executa o servizo local e verifica que responde en http://127.0.0.1:11434.';

  @override
  String get aiSetupLmStudioTitle => 'Paso 2: Instalar LM Studio';

  @override
  String get aiSetupLmStudioBody =>
      'Instala LM Studio, inicia o seu servidor local (compatible con OpenAI) e verifica que responde en http://127.0.0.1:1234.';

  @override
  String get aiSetupOpenSettingsHint =>
      'Cando un provedor estea operativo, preme Tentar de novo para configuralo automaticamente.';

  @override
  String get aiCompareCloudVsLocalTitle => 'Nube vs local';

  @override
  String get aiCompareCloudTitle => 'Folio [cite: 52] Cloud';

  @override
  String get aiCompareLocalTitle => 'Local (Ollama / LM Studio)';

  @override
  String get aiCompareCloudBulletNoSetup =>
      'Sen configuración local: funciona tras iniciar sesión.';

  @override
  String get aiCompareCloudBulletNeedsSub =>
      'Subscrición a Folio Cloud con IA na nube ou ink comprado.';

  @override
  String get aiCompareCloudBulletInk =>
      'Usa ink para a IA na nube (paquetes + recarga mensual).';

  @override
  String get aiProviderFolioCloudBlockedSnack =>
      'Precisas un plan activo de Folio Cloud con IA na nube ou ink comprado — mira en Axustes → Folio Cloud.';

  @override
  String get aiCompareLocalBulletPrivacy =>
      'Privacidade local (na túa máquina).';

  @override
  String get aiCompareLocalBulletNoInk => 'Sen ink: non depende dun saldo.';

  @override
  String get aiCompareLocalBulletSetup =>
      'Require instalar e executar un provedor en localhost.';

  @override
  String get quillGlobalScopeNoticeTitle =>
      'Quill funciona en todas as caixas fortes';

  @override
  String get quillGlobalScopeNoticeBody =>
      'Quill é un axuste a nivel de aplicación. [cite: 53] Se o activas agora, estará dispoñible para calquera caixa forte desta instalación.';

  @override
  String get quillGlobalScopeNoticeConfirm => 'Enténdoo';

  @override
  String get searchByNameOrShortcut => 'Buscar por nome ou atallo…';

  @override
  String get search => 'Buscar';

  @override
  String get open => 'Abrir';

  @override
  String get exit => 'Saír';

  @override
  String get trayMenuCloseApplication => 'Pechar aplicación';

  @override
  String get keyboardShortcutsSection => 'Teclado (na app)';

  @override
  String get shortcutTestAction => 'Proba';

  @override
  String get shortcutChangeAction => 'Cambiar';

  @override
  String shortcutTestHint(Object combo) {
    return 'Co foco fóra dun campo de texto, “$combo” debería funcionar no espazo de traballo.';
  }

  @override
  String get shortcutResetAllTitle => 'Restaurar atallos por defecto';

  @override
  String get shortcutResetAllSubtitle =>
      'Restablece todos os atallos aos predeterminados de Folio.';

  @override
  String get shortcutResetDoneSnack =>
      'Atallos restaurados aos valores por defecto.';

  @override
  String get desktopSection => 'Escritorio';

  @override
  String get globalSearchHotkey => 'Atallo de [cite: 54] busca global';

  @override
  String get hotkeyCombination => 'Combinación de teclas';

  @override
  String get hotkeyAltSpace => 'Alt + Espazo';

  @override
  String get hotkeyCtrlShiftSpace => 'Ctrl + Maiús + Espazo';

  @override
  String get hotkeyCtrlShiftK => 'Ctrl + Maiús + K';

  @override
  String get minimizeToTray => 'Minimizar á bandexa';

  @override
  String get closeToTray => 'Pechar á bandexa';

  @override
  String get searchAllVaultHint => 'Buscar en toda a caixa forte...';

  @override
  String get typeToSearch => 'Escribe para buscar';

  @override
  String get noSearchResults => 'Sen resultados';

  @override
  String get searchFilterAll => 'Todo';

  @override
  String get searchFilterTitles => 'Títulos';

  @override
  String get searchFilterContent => 'Contido';

  @override
  String get searchSortRelevance => 'Relevancia';

  @override
  String get searchSortRecent => 'Recente';

  @override
  String get settingsSearchSections => 'Axustes de busca';

  @override
  String get settingsSearchSectionsHint =>
      'Filtrar categorías na barra lateral';

  @override
  String get scheduledVaultBackupTitle => 'Copia cifrada programada';

  @override
  String get scheduledVaultBackupSubtitle =>
      'Mentres a caixa forte estea desbloqueada, cada copia é da caixa aberta nese momento. [cite: 55] Folio garda un ZIP na carpeta de abaixo co intervalo escollido.';

  @override
  String get scheduledVaultBackupChooseFolder => 'Carpeta de copia';

  @override
  String get scheduledVaultBackupIntervalLabel => 'Intervalo (horas)';

  @override
  String scheduledVaultBackupLastRun(Object time) {
    return 'Última copia: $time';
  }

  @override
  String get scheduledVaultBackupSnackOk => 'Copia programada gardada.';

  @override
  String scheduledVaultBackupSnackFail(Object error) {
    return 'Fallou a copia programada: $error';
  }

  @override
  String vaultBackupOpenVaultHint(String name) {
    return 'As copias son para a caixa forte aberta agora: “$name”.';
  }

  @override
  String get vaultBackupRunNowTile => 'Executar copia programada agora';

  @override
  String get vaultBackupRunNowSubtitle =>
      'Executa a copia agora (disco e/ou nube) sen agardar polo intervalo.';

  @override
  String get vaultBackupRunNowNeedFolder =>
      'Escolle unha carpeta local ou activa “Tamén subir [cite: 56] a Folio Cloud” para copias só na nube.';

  @override
  String get vaultIdentitySyncTitle => 'Sincronización';

  @override
  String get vaultIdentitySyncBody =>
      'Introduce a contrasinal da caixa forte (ou Hello / passkey) para continuar.';

  @override
  String get vaultIdentityCloudBackupTitle => 'Copias na nube';

  @override
  String get vaultIdentityCloudBackupBody =>
      'Confirma a identidade da caixa forte para listar ou descargar copias cifradas.';

  @override
  String get aiRewriteDialogTitle => 'Reescribir con IA';

  @override
  String get aiPreviewTitle => 'Vista previa';

  @override
  String get aiInstructionHint => 'Exemplo: facelo máis claro e curto';

  @override
  String get aiApply => 'Aplicar';

  @override
  String get aiGenerating => 'Xerando…';

  @override
  String get aiSummarizeSelection => 'Resumir con IA…';

  @override
  String get aiExtractTasksDates => 'Extraer tarefas e datas…';

  @override
  String get aiPreviewReadOnlyHint =>
      'Podes editar o texto de abaixo antes de aplicar.';

  @override
  String get aiRewriteApplied => 'Bloque actualizado.';

  @override
  String get aiUndoRewrite => 'Desfacer';

  @override
  String get aiInsertBelow => 'Inserir abaixo';

  @override
  String get unlockVaultTitle => 'Desbloquear caixa forte';

  @override
  String get miniUnlockFailed => 'Non se puido desbloquear.';

  @override
  String get importNotionTitle => 'Importar dende Notion (.zip)';

  @override
  String get importNotionSubtitle =>
      'Exportación ZIP de Notion (Markdown/HTML)';

  @override
  String get importNotionDialogTitle => 'Importar dende Notion';

  @override
  String get importNotionDialogBody =>
      'Importa un ZIP exportado por Notion. Podes engadilo á caixa actual ou crear unha nova.';

  @override
  String get importNotionSelectTargetTitle => 'Destino da importación';

  @override
  String get importNotionSelectTargetBody =>
      'Escolle se queres importar a Notion á túa caixa forte actual ou crear unha nova.';

  @override
  String get importNotionTargetCurrent => 'Caixa forte actual';

  @override
  String get importNotionTargetNew => 'Nova caixa forte';

  @override
  String get importNotionDefaultVaultName => 'Importado de Notion';

  @override
  String get importNotionNewVaultPasswordTitle =>
      'Contrasinal para a nova caixa forte';

  @override
  String get importNotionSuccessCurrent =>
      'Notion importado na caixa forte actual.';

  @override
  String get importNotionSuccessNew =>
      'Nova caixa forte importada dende Notion.';

  @override
  String importNotionError(Object error) {
    return 'Non se puido importar Notion: $error';
  }

  @override
  String get importNotionWarningsTitle => 'Avisos da importación';

  @override
  String get importNotionWarningsBody =>
      'A importación completouse con algúns avisos:';

  @override
  String get ok => 'Aceptar';

  @override
  String get notionExportGuideTitle => 'Como [cite: 59] exportar dende Notion';

  @override
  String get notionExportGuideBody =>
      'En Notion, vai a Axustes -> Exportar todo o contido, escolle HTML ou Markdown e descarga o ZIP. [cite: 60] Despois usa esta opción en Folio.';

  @override
  String get appBetaBannerMessage =>
      'Estás a usar unha versión beta. Podes atopar erros; [cite: 61] fai copias de seguridade a miúdo.';

  @override
  String get appBetaBannerDismiss => 'Entendido';

  @override
  String get integrations => 'Integracións';

  @override
  String get integrationsAppsApprovedHint =>
      'As aplicacións aprobadas poden usar a ponte de integración local.';

  @override
  String get integrationsAppsApprovedTitle => 'Apps externas aprobadas';

  @override
  String get integrationsAppsApprovedNone =>
      'Aínda non aprobaches ningunha aplicación externa.';

  @override
  String get integrationsAppsApprovedRevoke => 'Revogar acceso';

  @override
  String integrationsApprovedAppDetails(
    Object appId,
    Object appVersion,
    Object integrationVersion,
  ) {
    return '$appId · App $appVersion · Integración $integrationVersion';
  }

  @override
  String get integrationApprovalTitle => 'Aprobar integración externa';

  @override
  String get integrationApprovalUpdateTitle =>
      'Aprovar actualización de integración';

  @override
  String integrationApprovalBody(
    Object appName,
    Object appVersion,
    Object integrationVersion,
  ) {
    return '\"$appName\" quere conectarse a Folio usando a versión de app $appVersion e a de integración $integrationVersion.';
  }

  @override
  String integrationApprovalUpdateBody(
    Object appName,
    Object previousVersion,
    Object integrationVersion,
  ) {
    return '\"$appName\" xa fora [cite: 62] aprobado anteriormente. Agora quere conectarse cunha nova versión de integración $integrationVersion, polo que Folio precisa a túa aprobación de novo.';
  }

  @override
  String get integrationApprovalUnknownVersion => 'descoñecida';

  @override
  String get integrationApprovalAppId => 'ID da App';

  @override
  String get integrationApprovalAppVersion => 'Versión da App';

  @override
  String get integrationApprovalProtocolVersion => 'Versión da integración';

  @override
  String get integrationApprovalCanDoTitle => 'Que pode facer esta integración';

  @override
  String get integrationApprovalCanDoSessions =>
      'Crear sesións de importación temporais en Folio.';

  @override
  String get integrationApprovalCanDoImport =>
      'Enviar documentación Markdown para crear ou actualizar páxinas.';

  @override
  String get integrationApprovalCanDoMetadata =>
      'Gardar metadatos de orixe nas páxinas importadas.';

  @override
  String get integrationApprovalCanDoUnlockedVault =>
      'Importar só mentres a caixa forte estea dispoñible e [cite: 63] a petición inclúa o segredo configurado.';

  @override
  String get integrationApprovalCannotDoTitle => 'O que non pode facer';

  @override
  String get integrationApprovalCannotDoRead =>
      'Non pode ler o contido da túa caixa forte.';

  @override
  String get integrationApprovalCannotDoBypassLock =>
      'Non pode saltar o bloqueo, o cifrado ou a túa aprobación.';

  @override
  String get integrationApprovalCannotDoWithoutSecret =>
      'Non pode acceder a funcións protexidas sen o segredo compartido.';

  @override
  String get integrationApprovalCannotDoRemoteAccess =>
      'Non pode usar a ponte dende fóra de localhost.';

  @override
  String get integrationApprovalEncryptedChip => 'Contido cifrado (v2)';

  @override
  String get integrationApprovalUnencryptedChip => 'Contido sen cifrar (v1)';

  @override
  String get integrationApprovalEncryptedTitle =>
      'Versión 2: cifrado de contido obrigatorio';

  @override
  String get integrationApprovalEncryptedDescription =>
      'Esta versión require que os datos estean cifrados para importar contido.';

  @override
  String get integrationApprovalUnencryptedTitle =>
      'Versión 1: contido sen cifrar';

  @override
  String get integrationApprovalUnencryptedDescription =>
      'Esta versión [cite: 64] permite o envío de contido en texto plano. Se precisas cifrado de transporte, actualiza á versión 2.';

  @override
  String get integrationApprovalDeny => 'Denegar';

  @override
  String get integrationApprovalApprove => 'Aprobar';

  @override
  String get integrationApprovalApproveUpdate => 'Aprobar esta actualización';

  @override
  String get about => 'Acerca de';

  @override
  String get installedVersion => 'Versión instalada';

  @override
  String get updaterGithubRepository => 'Repositorio de actualizacións';

  @override
  String get updaterBetaDescription =>
      'As betas son lanzamentos de GitHub marcados como pre-lanzamento.';

  @override
  String get updaterStableDescription =>
      'Só se considera o último lanzamento estable.';

  @override
  String get checkUpdates => 'Buscar actualizacións';

  @override
  String get noEncryptionConfirmTitle => 'Crear caixa forte sen cifrado';

  @override
  String get noEncryptionConfirmBody =>
      'Os teus datos gardaranse sen contrasinal e sen cifrar. [cite: 65] Calquera con acceso a este dispositivo poderá lelos.';

  @override
  String get createVaultWithoutEncryption => 'Crear sen cifrado';

  @override
  String get plainVaultSecurityNotice =>
      'Esta caixa forte non está cifrada. [cite: 66] Non se aplica a chave de acceso, o Hello nin o bloqueo automático.';

  @override
  String get encryptPlainVaultTitle => 'Cifrar esta caixa forte';

  @override
  String get encryptPlainVaultBody =>
      'Escolle unha contrasinal mestra. [cite: 67] Todos os datos serán cifrados. Se a esqueces, non poderás recuperalos.';

  @override
  String get encryptPlainVaultConfirm => 'Cifrar caixa forte';

  @override
  String get encryptPlainVaultSuccessSnack =>
      'A caixa forte agora está cifrada';

  @override
  String get aiCopyMessage => 'Copiar';

  @override
  String get aiCopyCode => 'Copiar código';

  @override
  String get aiCopiedToClipboard => 'Copiado ao portapapeis';

  @override
  String get aiHelpful => 'Útil';

  @override
  String get aiNotHelpful => 'Non é útil';

  @override
  String get aiThinkingMessage => 'Quill está pensando...';

  @override
  String get aiMessageTimestampNow => 'agora';

  @override
  String aiMessageTimestampMinutes(int n) {
    return 'fa $n min';
  }

  @override
  String aiMessageTimestampHours(int n) {
    return 'fa $n h';
  }

  @override
  String aiMessageTimestampDays(int n) {
    return 'fa $n días';
  }

  @override
  String get templateGalleryTitle => 'Modelos de páxina';

  @override
  String get templateImport => 'Importar';

  @override
  String get templateImportPickTitle => 'Selecciona un ficheiro de modelo';

  @override
  String get templateImportSuccess => 'Modelo importado';

  @override
  String templateImportError(Object error) {
    return 'Erro ao importar: $error';
  }

  @override
  String get templateExportPickTitle => 'Gardar ficheiro de modelo';

  @override
  String get templateExportSuccess => 'Modelo exportado';

  @override
  String templateExportError(Object error) {
    return 'Erro ao exportar: $error';
  }

  @override
  String get templateSearchHint => 'Buscar modelos...';

  @override
  String get templateEmptyHint =>
      'Aínda non hai modelos.\nGarda unha páxina como modelo ou importa un.';

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
  String get templateUse => 'Usar modelo';

  @override
  String get templateExport => 'Exportar';

  @override
  String get templateBlankPage => 'Páxina en branco';

  @override
  String get templateFromGallery => 'Dende modelo…';

  @override
  String get saveAsTemplate => 'Gardar como modelo';

  @override
  String get saveAsTemplateTitle => 'Gardar como modelo';

  @override
  String get templateNameHint => 'Nome do modelo';

  @override
  String get templateDescriptionHint => 'Descrición (opcional)';

  @override
  String get templateCategoryHint => 'Categoría (opcional)';

  @override
  String get templateSaved => 'Gardado como modelo';

  @override
  String templateCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'modelos',
      one: 'modelo',
    );
    return '$count $_temp0';
  }

  @override
  String templateFilteredCount(int visible, int total) {
    return 'Amosando $visible de $total modelos';
  }

  @override
  String get templateSortRecent => 'Máis novos';

  @override
  String get templateSortName => 'Nome';

  @override
  String get templateEdit => 'Editar modelo';

  @override
  String get templateUpdated => 'Modelo actualizado';

  @override
  String get templateDeleteConfirmTitle => 'Eliminar modelo';

  @override
  String templateDeleteConfirmBody(Object name) {
    return 'O modelo \"$name\" eliminarase desta caixa forte.';
  }

  @override
  String templateCreatedOn(Object date) {
    return 'Creado o $date';
  }

  @override
  String get templatePreviewEmpty =>
      'Este modelo aínda non ten vista previa de texto.';

  @override
  String get templateSelectHint =>
      'Selecciona un modelo para inspeccionalo, editar os seus metadatos [cite: 70] ou exportalo.';

  @override
  String get templateGalleryTabLocal => 'Local';

  @override
  String get templateGalleryTabCommunity => 'Comunidade';

  @override
  String get templateCommunitySignInCta =>
      'Inicia sesión para compartir e ver modelos da comunidade.';

  @override
  String get templateCommunitySignInButton => 'Entrar';

  @override
  String get templateCommunityUnavailable =>
      'Os modelos da comunidade requiren Firebase. [cite: 71] Revisa a túa conexión.';

  @override
  String get templateCommunityEmpty =>
      'Aínda non hai modelos da comunidade. [cite: 72] Sé o primeiro en compartir un dende a pestana Local.';

  @override
  String templateCommunityLoadError(Object error) {
    return 'Non se puideron cargar os modelos da comunidade: $error';
  }

  @override
  String get templateCommunityRetry => 'Tentar de novo';

  @override
  String get templateCommunityRefresh => 'Actualizar';

  @override
  String get templateCommunityShareTitle => 'Compartir coa comunidade';

  @override
  String get templateCommunityShareBody =>
      'O teu modelo será público para calquera. [cite: 73] Elimina contido persoal antes de compartir.';

  @override
  String get templateCommunityShareConfirm => 'Compartir';

  @override
  String get templateCommunityShareSuccess =>
      'Modelo compartido coa comunidade';

  @override
  String templateCommunityShareError(Object error) {
    return 'Non se puido compartir: $error';
  }

  @override
  String get templateCommunityAddToVault => 'Gardar nos meus modelos';

  @override
  String get templateCommunityAddedToVault => 'Gardado nos teus modelos';

  @override
  String get templateCommunityDeleteTitle => 'Eliminar da comunidade';

  @override
  String templateCommunityDeleteBody(Object name) {
    return 'Eliminar \"$name\" do almacén da comunidade? [cite: 74] Isto non se pode deshacer.';
  }

  @override
  String get templateCommunityDeleteSuccess => 'Eliminado da comunidade';

  @override
  String templateCommunityDeleteError(Object error) {
    return 'Non se puido eliminar: $error';
  }

  @override
  String templateCommunityDownloadError(Object error) {
    return 'Non se puido descargar o modelo: $error';
  }

  @override
  String get clear => 'Limpar';

  @override
  String get cloudAccountSectionTitle => 'Conta de Folio Cloud';

  @override
  String get cloudAccountSectionDescription =>
      'Opcional. [cite: 75] Inicia sesión para subscribirte a copias na nube, IA hospedada e publicación web. [cite: 76] A túa caixa forte permanece local a menos que uses esas funcións.';

  @override
  String get cloudAccountChipOptional => 'Opcional';

  @override
  String get cloudAccountChipPaidCloud => 'Copias, IA e web';

  @override
  String get cloudAccountUnavailable =>
      'O inicio de sesión non está dispoñible (Firebase non iniciou). [cite: 77] Revisa a túa conexión.';

  @override
  String get cloudAccountEmailLabel => 'Correo';

  @override
  String get cloudAccountPasswordLabel => 'Contrasinal';

  @override
  String get cloudAccountSignIn => 'Entrar';

  @override
  String get cloudAccountCreateAccount => 'Crear conta';

  @override
  String get cloudAccountForgotPassword => 'Esqueciches a contrasinal?';

  @override
  String get cloudAccountSignOut => 'Saír';

  @override
  String cloudAccountSignedInAs(Object email) {
    return 'Sesión iniciada como $email';
  }

  @override
  String cloudAccountUid(Object uid) {
    return 'ID de usuario: $uid';
  }

  @override
  String get cloudAuthDialogTitleSignIn => 'Entrar en Folio Cloud';

  @override
  String get cloudAuthDialogTitleRegister => 'Crear conta de Folio Cloud';

  @override
  String get cloudAuthDialogTitleReset => 'Restablecer contrasinal';

  @override
  String get cloudPasswordResetSent =>
      'Se existe unha conta para ese correo, enviouse unha ligazón.';

  @override
  String get cloudAuthErrorInvalidEmail =>
      'Ese enderezo de correo non é válido.';

  @override
  String get cloudAuthErrorWrongPassword => 'Contrasinal incorrecta.';

  @override
  String get cloudAuthErrorUserNotFound =>
      'Non se atopou [cite: 78] ningunha conta para ese correo.';

  @override
  String get cloudAuthErrorUserDisabled => 'Esta conta foi desactivada.';

  @override
  String get cloudAuthErrorEmailAlreadyInUse =>
      'Ese correo xa está rexistrado.';

  @override
  String get cloudAuthErrorWeakPassword => 'A contrasinal é moi feble.';

  @override
  String get cloudAuthErrorInvalidCredential =>
      'Correo ou contrasinal non válidos.';

  @override
  String get cloudAuthErrorNetwork =>
      'Erro de rede. [cite: 79] Revisa a túa conexión.';

  @override
  String get cloudAuthErrorTooManyRequests =>
      'Demasiados intentos. Téntao máis tarde.';

  @override
  String get cloudAuthErrorOperationNotAllowed =>
      'Este método de acceso non está habilitado en Firebase.';

  @override
  String get cloudAuthErrorGeneric =>
      'Erro ao entrar. [cite: 80] Téntao de novo.';

  @override
  String get cloudAuthDialogTitle => 'Folio Cloud';

  @override
  String get cloudAuthSubtitleSignIn =>
      'Usa o teu correo e contrasinal de Folio Cloud. [cite: 81] Nada aquí cambia a túa caixa forte local.';

  @override
  String get cloudAuthSubtitleRegister =>
      'Crea credenciais para Folio Cloud. [cite: 82] As túas notas non se subirán ata que actives as copias ou funcións de pago.';

  @override
  String get cloudAuthModeSignIn => 'Entrar';

  @override
  String get cloudAuthModeRegister => 'Rexistrarse';

  @override
  String get cloudAuthConfirmPasswordLabel => 'Confirmar contrasinal';

  @override
  String get cloudAuthValidationRequired => 'Este campo é obrigatorio.';

  @override
  String get cloudAuthValidationPasswordShort => 'Usa polo menos 6 caracteres.';

  @override
  String get cloudAuthValidationConfirmMismatch =>
      'As contrasinais non coinciden.';

  @override
  String get cloudAccountSignedOutPrompt =>
      'Entra ou rexístrate para subscribirte a Folio Cloud e usar as copias, a IA na nube e a publicación.';

  @override
  String get cloudAuthResetHint =>
      'Enviarémosche unha ligazón para poñer unha nova contrasinal.';

  @override
  String get cloudAccountEmailVerified => 'Verificado';

  @override
  String get cloudAccountSignOutHelp =>
      'A túa caixa forte local queda neste dispositivo.';

  @override
  String get cloudAccountEmailUnverifiedBanner =>
      'Verifica o teu correo para asegurar a túa conta de Folio Cloud.';

  @override
  String get cloudAccountResendVerification =>
      'Reenviar correo de verificación';

  @override
  String get cloudAccountReloadVerification => 'Xa verifiquei';

  @override
  String get cloudAccountVerificationSent => 'Correo de verificación enviado.';

  @override
  String get cloudAccountVerificationStillPending =>
      'O correo aínda non está verificado. [cite: 84] Abre a ligazón na túa bandexa de entrada.';

  @override
  String get cloudAccountVerificationNowVerified => 'Correo verificado.';

  @override
  String get cloudAccountResetPasswordEmail =>
      'Restablecer contrasinal por correo';

  @override
  String get cloudAccountCopyEmail => 'Copiar correo';

  @override
  String get cloudAccountEmailCopied => 'Correo copiado.';

  @override
  String get folioWebPortalSubsectionTitle => 'Conta web';

  @override
  String get folioWebPortalLinkCodeLabel => 'Código de ligazón';

  @override
  String get folioWebPortalLinkHelp =>
      'Xera o código na web en Axustes → Conta Folio e introdúceo aquí antes de 10 minutos.';

  @override
  String get folioWebPortalLinkButton => 'Ligar';

  @override
  String get folioWebPortalLinkSuccess => 'Conta web ligada con éxito.';

  @override
  String get folioWebPortalNeedSignIn =>
      'Entra en Folio Cloud para ligar a túa conta web.';

  @override
  String get folioWebMirrorNote =>
      'As copias, a IA e a publicación réxense por Folio Cloud (Firestore). [cite: 85] O de abaixo reflicte a túa conta web.';

  @override
  String get folioWebEntitlementLinked => 'Conta web ligada';

  @override
  String get folioWebEntitlementNotLinked => 'Conta web non ligada';

  @override
  String folioWebEntitlementWebPlan(String value) {
    return 'Plan de Folio Cloud (web): $value';
  }

  @override
  String folioWebEntitlementWebStatus(String value) {
    return 'Estado (web): $value';
  }

  @override
  String folioWebEntitlementWebPeriodEnd(String value) {
    return 'Fin do período (web): $value';
  }

  @override
  String folioWebEntitlementWebInk(int count) {
    return 'Ink (web): $count';
  }

  @override
  String get folioWebPortalRefreshWeb => 'Actualizar estado web';

  @override
  String get folioWebPortalErrorNetwork =>
      'Non se puido contactar co portal. [cite: 86] Revisa a túa conexión.';

  @override
  String get folioWebPortalErrorTimeout =>
      'O portal tardou demasiado en responder.';

  @override
  String get folioWebPortalErrorAdminNotConfigured =>
      'Folio Firebase Admin non está configurado no servidor.';

  @override
  String get folioWebPortalErrorUnauthorized =>
      'Sesión non válida. [cite: 87] Entra de novo en Folio Cloud.';

  @override
  String get folioWebPortalErrorGeneric =>
      'Non se puido completar a petición ao portal.';

  @override
  String folioWebPortalServerMessage(String message) {
    return '$message';
  }

  @override
  String get folioCloudSubsectionPlan => 'Plan e estado';

  @override
  String get folioCloudSubsectionInk => 'Saldo de Ink';

  @override
  String get folioCloudSubsectionSubscription => 'Subscrición e facturación';

  @override
  String get folioCloudSubsectionBackupPublish => 'Copias e publicación';

  @override
  String get folioCloudSubscriptionActive => 'Subscrición activa';

  @override
  String folioCloudSubscriptionActiveWithStatus(String status) {
    return 'Subscrición activa ($status)';
  }

  @override
  String get folioCloudSubscriptionNoneTitle => 'Sen subscripció a Folio Cloud';

  @override
  String get folioCloudSubscriptionNoneSubtitle =>
      'Activa un plan para ter copias cifradas, IA na nube e publicación web.';

  @override
  String get folioCloudFeatureBackup => 'Copia na nube';

  @override
  String get folioCloudFeatureCloudAi => 'IA na nube';

  @override
  String get folioCloudFeaturePublishWeb => 'Publicación web';

  @override
  String get folioCloudFeatureOn => 'Incluído';

  @override
  String get folioCloudFeatureOff => 'Non incluído';

  @override
  String get folioCloudPostPaymentHint =>
      'Se [cite: 88] acabas de pagar e non aparecen os cambios, preme «Actualizar dende Stripe».';

  @override
  String get folioCloudBackupCleanupWarning =>
      'Copia subida, pero non se puideron limpar as copias antigas (tentarase máis tarde).';

  @override
  String get folioCloudInkMonthly => 'Mensual';

  @override
  String get folioCloudInkPurchased => 'Comprado';

  @override
  String get folioCloudInkTotal => 'Total';

  @override
  String folioCloudInkCount(int count) {
    return '$count';
  }

  @override
  String get folioCloudPlanActiveHeadline =>
      'Plan mensual de Folio Cloud activo';

  @override
  String get folioCloudSubscribeMonthly => 'Folio Cloud 4,99 €/mes';

  @override
  String get folioCloudPitchScreenTitle => 'Folio Cloud';

  @override
  String get folioCloudPitchHeadline =>
      'A túa caixa forte é local. [cite: 89] A nube funciona cando ti queres.';

  @override
  String get folioCloudPitchSubhead =>
      'Un plan mensual desbloquea as copias cifradas, a IA na nube con saldo mensual de ink e a publicación web—só para o que escollas compartir.';

  @override
  String get folioCloudPitchLearnMore => 'Mira que inclúe';

  @override
  String get folioCloudPitchCtaNeedAccount => 'Entrar ou crear conta';

  @override
  String get folioCloudPitchGuestTeaserTitle => 'Conta de Folio Cloud';

  @override
  String get folioCloudPitchGuestTeaserBody =>
      'Conta opcional: mira o que inclúe o plan e entra cando queiras subscribirte.';

  @override
  String get folioCloudPitchOpenSettingsToSignIn =>
      'Abre Axustes e entra en Folio Cloud para subscribirte.';

  @override
  String get folioCloudBuyInk => 'Comprar ink';

  @override
  String get folioCloudInkSmall => 'Ink Pequeno (1,99 €)';

  @override
  String get folioCloudInkMedium => 'Ink Medio (4,99 €)';

  @override
  String get folioCloudInkLarge => 'Ink [cite: 90] Grande (9,99 €)';

  @override
  String get folioCloudManageSubscription => 'Xestionar subscrición';

  @override
  String get folioCloudRefreshFromStripe => 'Actualizar';

  @override
  String get folioCloudUploadEncryptedBackup => 'Facer copia na nube agora';

  @override
  String get folioCloudUploadEncryptedBackupSubtitle =>
      'Folio crea unha copia cifrada da túa caixa forte aberta e súbea—sen exportación ZIP manual.';

  @override
  String get folioCloudUploadSnackOk => 'Copia da caixa forte gardada na nube.';

  @override
  String get scheduledVaultBackupCloudSyncTitle => 'Tamén subir a Folio Cloud';

  @override
  String get scheduledVaultBackupCloudSyncSubtitle =>
      'Tras cada copia programada, sube automaticamente o mesmo ZIP á túa conta. [cite: 91] Para copias só na nube, deixa a carpeta sen definir e activa esta opción.';

  @override
  String get folioCloudCloudBackupsList => 'Copias na nube';

  @override
  String get folioCloudBackupsUsed => 'Usado';

  @override
  String get folioCloudBackupsLimit => 'Límite';

  @override
  String get folioCloudBackupsRemaining => 'Restante';

  @override
  String get folioCloudPublishTestPage => 'Publicar páxina de proba';

  @override
  String get folioCloudPublishedPagesList => 'Páxinas publicadas';

  @override
  String get folioCloudReauthDialogTitle => 'Confirmar conta de Folio Cloud';

  @override
  String get folioCloudReauthDialogBody =>
      'Introduce a contrasinal da túa conta Folio Cloud (a que usas para entrar na nube) para listar e descargar copias. [cite: 92] Non é a contrasinal da túa caixa forte local.';

  @override
  String get folioCloudReauthRequiresPasswordProvider =>
      'Esta sesión non usa unha contrasinal de Folio Cloud. [cite: 93] Sae e entra de novo con correo e contrasinal se precisas descargar copias.';

  @override
  String get folioCloudAiNoInkTitle => 'Sen ink de IA na nube';

  @override
  String get folioCloudAiNoInkBody =>
      'Compra ink en Folio Cloud, agarda á recarga mensual ou cambia á IA local (Ollama ou LM Studio) na sección de IA.';

  @override
  String get folioCloudAiNoInkActionCloud => 'Folio Cloud e ink';

  @override
  String get folioCloudAiNoInkActionLocal => 'Provedor de IA';

  @override
  String get folioCloudAiZeroInkBanner =>
      'O ink para IA na nube é 0 — abre Axustes para comprar ink ou usa IA local.';

  @override
  String folioCloudInkPurchaseAppliedHint(Object purchased) {
    return 'Compra aplicada: $purchased ink comprado dispoñible para a IA na nube.';
  }

  @override
  String get onboardingCloudBackupCta =>
      'Entrar e [cite: 94] descargar unha copia';

  @override
  String get onboardingCloudBackupPickVaultSubtitle =>
      'Escolle que caixa forte queres restaurar.';

  @override
  String get onboardingFolioCloudTitle => 'Folio Cloud';

  @override
  String get onboardingFolioCloudBody =>
      'Activa as funcións na nube cando as necesites: copias cifradas, Quill hospedado e publicación web. [cite: 95] A túa caixa forte permanece local a menos que uses estas funcións.';

  @override
  String get onboardingFolioCloudFeatureBackupTitle =>
      'Copias cifradas na nube';

  @override
  String get onboardingFolioCloudFeatureBackupBody =>
      'Garda e descarga copias das túas caixas fortes dende a túa conta. [cite: 96] En escritorio, o listado e descarga fano vía Folio Cloud.';

  @override
  String get onboardingFolioCloudFeatureAiTitle => 'IA na nube + ink';

  @override
  String get onboardingFolioCloudFeatureAiBody =>
      'Quill hospedado cunha subscrición a Folio Cloud ou comprando ink. [cite: 97] O ink consómese polo uso; tamén podes usar IA local (Ollama/LM Studio).';

  @override
  String get onboardingFolioCloudFeatureWebTitle => 'Publicación web';

  @override
  String get onboardingFolioCloudFeatureWebBody =>
      'Publica páxinas seleccionadas e controla que se fai público. [cite: 98] O resto da caixa forte non se comparte.';

  @override
  String get onboardingFolioCloudLaterInSettings => 'Mirareino en Axustes';

  @override
  String get collabMenuAction => 'Colaboración en vivo';

  @override
  String get collabSheetTitle => 'Colaboración en vivo';

  @override
  String get collabHeaderSubtitle =>
      'Precísase conta de Folio. [cite: 99] Hostatjar require un plan con colaboración; unirse só precisa un código. O contido e o chat están cifrados de extremo a extremo; [cite: 100] o servidor nunca ve o teu texto.';

  @override
  String get collabNoRoomHint =>
      'Crea unha sala (se o teu plan inclúe hostatxe) ou pega o código do anfitrión (emojis + díxitos).';

  @override
  String get collabCreateRoom => 'Crear sala';

  @override
  String get collabJoinCodeLabel => 'Código da sala';

  @override
  String get collabJoinCodeHint => 'ex: [cite: 101] dous emojis + 4 díxitos';

  @override
  String get collabJoinRoom => 'Unirse';

  @override
  String get collabJoinFailed => 'Código non válido ou sala chea.';

  @override
  String get collabShareCodeLabel => 'Comparte este código';

  @override
  String get collabCopyJoinCode => 'Copiar código';

  @override
  String get collabCopied => 'Copiado';

  @override
  String get collabHostRequiresPlan =>
      'Crear salas require Folio Cloud con colaboración (hostatxe). [cite: 102] Podes unirte a salas doutros cun código sen ese plan.';

  @override
  String get collabChatEmptyHint =>
      'Sen mensaxes aínda. [cite: 103] Saúda ao teu equipo.';

  @override
  String get collabMessageHint => 'Escribe unha mensaxe…';

  @override
  String get collabArchivedOk => 'Chat arquivado como comentarios de páxina.';

  @override
  String get collabArchiveToPage => 'Arquivar chat na páxina';

  @override
  String get collabLeaveRoom => 'Saír da sala';

  @override
  String get collabNeedsJoinCode =>
      'Introduce o código da sala para descifrar esta sesión de colaboración.';

  @override
  String get collabMissingJoinCodeHint =>
      'Esta páxina está ligada a unha sala pero non hai código gardado. [cite: 104] Pega o código do anfitrión para descifrar o contido e o chat.';

  @override
  String get collabUnlockWithCode => 'Desbloquear con código';

  @override
  String get collabHidePanel => 'Agochar panel de colaboración';

  @override
  String get shortcutsCaptureTitle => 'Novo atallo';

  @override
  String get shortcutsCaptureHint => 'Preme as teclas (Esc cancela).';

  @override
  String get updaterStartupDialogTitleStable => 'Actualización dispoñible';

  @override
  String get updaterStartupDialogTitleBeta => 'Beta dispoñible';

  @override
  String updaterStartupDialogBody(Object releaseVersion) {
    return 'Unha nova versión ($releaseVersion) está dispoñible.';
  }

  @override
  String get updaterStartupDialogQuestion =>
      'Queres descargala e instalala agora?';

  @override
  String get updaterStartupDialogLater => 'Máis tarde';

  @override
  String get updaterStartupDialogUpdateNow => 'Actualizar agora';

  @override
  String get updaterStartupDialogBetaNote => 'Versión Beta (pre-lanzamento).';

  @override
  String get toggleTitleHint => 'Título do interruptor';

  @override
  String get toggleBodyHint => 'Contido…';

  @override
  String get taskStatusTodo => 'Por facer';

  @override
  String get taskStatusInProgress => 'En curso';

  @override
  String get taskStatusDone => 'Feito';

  @override
  String get taskPriorityNone => 'Sen prioridade';

  @override
  String get taskPriorityLow => 'Baixa';

  @override
  String get taskPriorityMedium => 'Media';

  @override
  String get taskPriorityHigh => 'Alta';

  @override
  String get taskTitleHint => 'Descrición da tarefa…';

  @override
  String get taskPriorityTooltip => 'Prioridade';

  @override
  String get taskNoDueDate => 'Sen data de entrega';

  @override
  String get taskSubtaskHint => 'Subtarefa…';

  @override
  String get taskRemoveSubtask => 'Eliminar subtarefa';

  @override
  String get taskAddSubtask => 'Engadir subtarefa';

  @override
  String get templateEmojiLabel => 'Emoji';

  @override
  String aiGenericErrorWithReason(Object reason) {
    return 'Erro de IA: $reason';
  }

  @override
  String get calloutTypeTooltip => 'Tipo de chamada';

  @override
  String get calloutTypeInfo => 'Info';

  @override
  String get calloutTypeSuccess => 'Éxito';

  @override
  String get calloutTypeWarning => 'Aviso';

  @override
  String get calloutTypeError => 'Erro';

  @override
  String get calloutTypeNote => 'Nota';
}
