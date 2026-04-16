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
  String get formatToolbarScrollPrevious => 'Ver ferramentas anteriores';

  @override
  String get formatToolbarScrollNext => 'Ver máis ferramentas';

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
  String get exportPage => 'Exportar…';

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
      'Instala LM Studio, inicia o seu servidor local e verifica que responde en http://127.0.0.1:1234.';

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
  String get tasksCaptureSettingsSection => 'Tarefas (captura rápida)';

  @override
  String get taskInboxPageTitle => 'Bandexa de tarefas';

  @override
  String get taskInboxPageSubtitle =>
      'Páxina onde se gardan as tarefas engadidas con captura rápida.';

  @override
  String get taskInboxNone => 'Sen definir (créase ao gardar a primeira)';

  @override
  String get taskInboxDefaultTitle => 'Bandexa de tarefas';

  @override
  String get taskAliasManageTitle => 'Alias de destino';

  @override
  String get taskAliasManageSubtitle =>
      'Usa `#etiqueta` ou `@etiqueta` ao final da captura. Define a clave sen símbolo (ex. traballo) e a páxina destino.';

  @override
  String get taskAliasAddButton => 'Engadir alias';

  @override
  String get taskAliasTagLabel => 'Etiqueta';

  @override
  String get taskAliasTargetLabel => 'Páxina';

  @override
  String get taskAliasDeleteTooltip => 'Quitar';

  @override
  String get taskQuickAddTitle => 'Captura rápida de tarefa';

  @override
  String get taskQuickAddHint =>
      'Ex.: Mercar leite mañá alta #traballo. Tamén: due:2026-04-20, p1, en progreso.';

  @override
  String get taskQuickAddConfirm => 'Engadir';

  @override
  String get taskQuickAddSuccess => 'Tarefa engadida.';

  @override
  String get taskQuickAddAliasTargetMissing =>
      'A páxina dese alias xa non existe.';

  @override
  String get taskHubTitle => 'Todas as tarefas';

  @override
  String get taskHubClose => 'Pechar vista';

  @override
  String get taskHubDashboardHelpTitle => 'Ideas tipo dashboard';

  @override
  String get taskHubDashboardHelpBody =>
      'Crea unha páxina co bloque columnas e enlaza páxinas de listas por contexto, ou usa un bloque base de datos con datas e estados para un taboleiro.';

  @override
  String get taskHubEmpty => 'Non hai tarefas neste caderno.';

  @override
  String get taskHubFilterAll => 'Todas';

  @override
  String get taskHubFilterActive => 'Pendentes';

  @override
  String get taskHubFilterDone => 'Feitas';

  @override
  String get taskHubFilterDueToday => 'Vencen hoxe';

  @override
  String get taskHubFilterDueWeek => 'Esta semana';

  @override
  String get taskHubFilterOverdue => 'Vencidas';

  @override
  String get taskHubOpen => 'Abrir';

  @override
  String get taskHubMarkDone => 'Feito';

  @override
  String get taskHubIncludeTodos => 'Incluír checklists';

  @override
  String get sidebarQuickAddTask => 'Tarefa rápida';

  @override
  String get sidebarTaskHub => 'Todas as tarefas';

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
      'Mentres a caixa forte estea desbloqueada, Folio cópiaa automáticamente co intervalo escollido. Activa a copia en carpeta, na nube, ou as dúas.';

  @override
  String get scheduledVaultBackupFolderTitle => 'Copia en carpeta';

  @override
  String get scheduledVaultBackupFolderSubtitle =>
      'Garda unha copia cifrada en ZIP na carpeta configurada en cada intervalo.';

  @override
  String get scheduledVaultBackupChooseFolder => 'Carpeta de copia';

  @override
  String get scheduledVaultBackupClearFolderTooltip => 'Quitar carpeta';

  @override
  String get scheduledVaultBackupCloudOnlyTitle =>
      'Copias programadas só na nube';

  @override
  String get scheduledVaultBackupCloudOnlySubtitle =>
      'Non garda ZIPs no disco. Sobe copias só á nube.';

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
  String vaultBackupDiskSizeApprox(String size) {
    return 'Tamaño aproximado no disco: $size';
  }

  @override
  String get vaultBackupDiskSizeLoading => 'Calculando o tamaño no disco…';

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
  String get folioCloudMicrosoftStoreBillingTitle =>
      'Microsoft Store (Windows)';

  @override
  String get folioCloudMicrosoftStoreBillingSubtitle =>
      'A mesma subscrición e tinta que con Stripe; a Tenda cobra e o servidor valida a compra. Configura os ids de produto con --dart-define e Azure AD en Cloud Functions.';

  @override
  String get folioCloudMicrosoftStoreSubscribeButton => 'Subscrición na Tenda';

  @override
  String get folioCloudMicrosoftStoreSyncButton => 'Sincronizar coa Tenda';

  @override
  String get folioCloudMicrosoftStoreInkTitle => 'Tinta — Microsoft Store';

  @override
  String get folioCloudMicrosoftStoreInkPackSmall => 'Tintero pequeno (Tenda)';

  @override
  String get folioCloudMicrosoftStoreInkPackMedium => 'Tintero mediano (Tenda)';

  @override
  String get folioCloudMicrosoftStoreInkPackLarge => 'Tintero grande (Tenda)';

  @override
  String get folioCloudMicrosoftStoreSyncedSnack =>
      'Sincronizado con Microsoft Store.';

  @override
  String get folioCloudMicrosoftStoreAppliedSnack =>
      'Compra aplicada. Se non ves os cambios, preme sincronizar.';

  @override
  String get folioCloudPurchaseChannelTitle => 'Onde queres pagar?';

  @override
  String get folioCloudPurchaseChannelBody =>
      'Podes usar a Microsoft Store integrada en Windows ou pagar con tarxeta no navegador (Stripe). O plan e a tinta son os mesmos.';

  @override
  String get folioCloudPurchaseChannelMicrosoftStore => 'Microsoft Store';

  @override
  String get folioCloudPurchaseChannelStripe => 'No navegador (Stripe)';

  @override
  String get folioCloudPurchaseChannelCancel => 'Cancelar';

  @override
  String get folioCloudPurchaseChannelStoreNotConfigured =>
      'A opción da Tenda non está configurada nesta compilación (faltan ids de produto).';

  @override
  String get folioCloudPurchaseChannelStoreNotConfiguredHint =>
      'Compila con --dart-define=MS_STORE_… ou usa o pago no navegador.';

  @override
  String get folioCloudMicrosoftStoreSyncHint =>
      'En Windows, «Actualizar» tamén sincroniza a Microsoft Store (mesmo botón que Stripe).';

  @override
  String get folioCloudUploadEncryptedBackup => 'Facer copia na nube agora';

  @override
  String get folioCloudUploadEncryptedBackupSubtitle =>
      'Folio crea unha copia cifrada da túa caixa forte aberta e súbea—sen exportación ZIP manual.';

  @override
  String get folioCloudUploadSnackOk => 'Copia da caixa forte gardada na nube.';

  @override
  String get scheduledVaultBackupCloudSyncTitle => 'Copia en Folio Cloud';

  @override
  String get scheduledVaultBackupCloudSyncSubtitle =>
      'En cada intervalo programado, sobe automáticamente unha copia cifrada á túa conta de Folio Cloud.';

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
  String get updaterOpenApkDownloadQuestion => 'Abrir a descarga do APK agora?';

  @override
  String get updaterManualCheckUnsupportedPlatform =>
      'O actualizador integrado só está dispoñible en Windows e Android.';

  @override
  String get updaterManualCheckAlreadyLatest =>
      'Xa tes a versión máis recente.';

  @override
  String updaterDialogLineCurrentVersion(Object currentVersion) {
    return 'Versión actual: $currentVersion';
  }

  @override
  String updaterDialogLineNewVersion(Object releaseVersion) {
    return 'Versión nova: $releaseVersion';
  }

  @override
  String get updaterApkUrlInvalidSnack =>
      'Non se atopou un URL válido do APK na release.';

  @override
  String get updaterApkOpenFailedSnack =>
      'Non se puido abrir a descarga do APK.';

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
  String get title => 'Título';

  @override
  String get description => 'Descrición';

  @override
  String get priority => 'Prioridade';

  @override
  String get status => 'Estado';

  @override
  String get none => 'Ningunha';

  @override
  String get low => 'Baixa';

  @override
  String get medium => 'Media';

  @override
  String get high => 'Alta';

  @override
  String get startDate => 'Data de inicio';

  @override
  String get dueDate => 'Data de vencemento';

  @override
  String get timeSpentMinutes => 'Tempo investido (minutos)';

  @override
  String get taskBlocked => 'Bloqueada';

  @override
  String get taskBlockedReason => 'Motivo do bloqueo';

  @override
  String get subtasks => 'Subtarefas';

  @override
  String get add => 'Engadir';

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

  @override
  String get blockEditorEnterHintNewBlock =>
      'Intro: bloque novo (en código: Intro = liña)';

  @override
  String get blockEditorEnterHintNewLine => 'Intro: nova liña';

  @override
  String blockEditorShortcutsHintMobile(String enterHint) {
    return '$enterHint · / para bloques · toca o bloque para máis accións';
  }

  @override
  String blockEditorShortcutsHintDesktop(String enterHint) {
    return '$enterHint · Maiús+Intro: liña · / tipos · # título (mesma liña) · - · * · [] · ``` espazo · táboa/imaxe en / · formato: barra ao enfocar ou ** _ <u> ` ~~';
  }

  @override
  String blockEditorSelectedBlocksBanner(int count) {
    return '$count bloques seleccionados · Maiús: rango · Ctrl/Cmd: alternar';
  }

  @override
  String get blockEditorDuplicate => 'Duplicar';

  @override
  String get blockEditorClearSelectionTooltip => 'Limpar selección';

  @override
  String get blockEditorMenuRewriteWithAi => 'Reescribir con IA…';

  @override
  String get blockEditorMenuMoveUp => 'Mover arriba';

  @override
  String get blockEditorMenuMoveDown => 'Mover abaixo';

  @override
  String get blockEditorMenuDuplicateBlock => 'Duplicar bloque';

  @override
  String get blockEditorMenuAppearance => 'Aparencia…';

  @override
  String get blockEditorMenuCalloutIcon => 'Icona do callout…';

  @override
  String blockEditorCalloutMenuType(String typeName) {
    return 'Tipo: $typeName';
  }

  @override
  String get blockEditorCopyLink => 'Copiar ligazón';

  @override
  String get blockEditorMenuCreateSubpage => 'Crear subpáxina';

  @override
  String get blockEditorMenuLinkPage => 'Ligar páxina…';

  @override
  String get blockEditorMenuOpenSubpage => 'Abrir subpáxina';

  @override
  String get blockEditorMenuPickImage => 'Elixir imaxe…';

  @override
  String get blockEditorMenuRemoveImage => 'Quitar imaxe';

  @override
  String get blockEditorMenuCodeLanguage => 'Linguaxe do código…';

  @override
  String get blockEditorMenuEditDiagram => 'Editar diagrama…';

  @override
  String get blockEditorMenuBackToPreview => 'Volver á vista previa';

  @override
  String get blockEditorMenuChangeFile => 'Cambiar ficheiro…';

  @override
  String get blockEditorMenuRemoveFile => 'Quitar ficheiro';

  @override
  String get blockEditorMenuChangeVideo => 'Cambiar vídeo…';

  @override
  String get blockEditorMenuRemoveVideo => 'Quitar vídeo';

  @override
  String get blockEditorMenuChangeAudio => 'Cambiar audio…';

  @override
  String get blockEditorMenuRemoveAudio => 'Quitar audio';

  @override
  String get blockEditorMenuEditLabel => 'Editar etiqueta…';

  @override
  String get blockEditorMenuAddRow => 'Engadir fila';

  @override
  String get blockEditorMenuRemoveLastRow => 'Quitar última fila';

  @override
  String get blockEditorMenuAddColumn => 'Engadir columna';

  @override
  String get blockEditorMenuRemoveLastColumn => 'Quitar última columna';

  @override
  String get blockEditorMenuAddProperty => 'Engadir propiedade';

  @override
  String get blockEditorMenuChangeBlockType => 'Cambiar tipo de bloque…';

  @override
  String get blockEditorMenuDeleteBlock => 'Eliminar bloque';

  @override
  String get blockEditorAppearanceTitle => 'Aparencia do bloque';

  @override
  String get blockEditorAppearanceSubtitle =>
      'Personaliza tamaño, cor do texto e fondo para este bloque.';

  @override
  String get blockEditorAppearanceSize => 'Tamaño';

  @override
  String get blockEditorAppearanceTextColor => 'Cor do texto';

  @override
  String get blockEditorAppearanceBackground => 'Fondo';

  @override
  String get blockEditorAppearancePreviewEmpty => 'Así se verá este bloque.';

  @override
  String get blockEditorReset => 'Restablecer';

  @override
  String get blockEditorCodeLanguageTitle => 'Linguaxe do código';

  @override
  String get blockEditorCodeLanguageSubtitle =>
      'Realzado de sintaxe segundo a linguaxe elixida.';

  @override
  String get blockEditorTemplateButtonTitle => 'Etiqueta do botón de plantilla';

  @override
  String get blockEditorTemplateButtonFieldLabel => 'Texto do botón';

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
  String get blockEditorTextColorError => 'Erro';

  @override
  String get blockEditorBackgroundNone => 'Sen fondo';

  @override
  String get blockEditorBackgroundSurface => 'Superficie';

  @override
  String get blockEditorBackgroundPrimary => 'Primario';

  @override
  String get blockEditorBackgroundSecondary => 'Secundario';

  @override
  String get blockEditorBackgroundTertiary => 'Acento';

  @override
  String get blockEditorBackgroundError => 'Erro';

  @override
  String get blockEditorCmdDuplicatePrev => 'Duplicar bloque anterior';

  @override
  String get blockEditorCmdDuplicatePrevHint =>
      'Clona o bloque inmediatamente anterior';

  @override
  String get blockEditorCmdInsertDate => 'Inserir data';

  @override
  String get blockEditorCmdInsertDateHint => 'Escribe a data actual';

  @override
  String get blockEditorCmdMentionPage => 'Mencionar páxina';

  @override
  String get blockEditorCmdMentionPageHint =>
      'Insire ligazón interna a unha páxina';

  @override
  String get blockEditorCmdTurnInto => 'Converter bloque';

  @override
  String get blockEditorCmdTurnIntoHint => 'Elixir tipo de bloque no selector';

  @override
  String get blockEditorMarkTaskComplete => 'Marcar tarefa completada';

  @override
  String get blockEditorCalloutIconPickerTitle => 'Icona do callout';

  @override
  String get blockEditorCalloutIconPickerHelper =>
      'Selecciona unha icona para cambiar o ton visual do bloque destacado.';

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
      'Aínda non importaches iconas en Axustes.';

  @override
  String get blockTypeSectionBasicText => 'Texto básico';

  @override
  String get blockTypeSectionLists => 'Listas';

  @override
  String get blockTypeSectionMedia => 'Multimedia e datos';

  @override
  String get blockTypeSectionAdvanced => 'Avanzado e deseño';

  @override
  String get blockTypeSectionEmbeds => 'Integracións';

  @override
  String get blockTypeParagraphLabel => 'Texto';

  @override
  String get blockTypeParagraphHint => 'Parágrafo';

  @override
  String get blockTypeChildPageLabel => 'Páxina';

  @override
  String get blockTypeChildPageHint => 'Subpáxina ligada';

  @override
  String get blockTypeH1Label => 'Título 1';

  @override
  String get blockTypeH1Hint => 'Título grande · #';

  @override
  String get blockTypeH2Label => 'Título 2';

  @override
  String get blockTypeH2Hint => 'Subtítulo · ##';

  @override
  String get blockTypeH3Label => 'Título 3';

  @override
  String get blockTypeH3Hint => 'Título menor · ###';

  @override
  String get blockTypeQuoteLabel => 'Cita';

  @override
  String get blockTypeQuoteHint => 'Texto citado';

  @override
  String get blockTypeDividerLabel => 'Divisor';

  @override
  String get blockTypeDividerHint => 'Separador · ---';

  @override
  String get blockTypeCalloutLabel => 'Bloque destacado';

  @override
  String get blockTypeCalloutHint => 'Aviso con icona';

  @override
  String get blockTypeBulletLabel => 'Lista con viñetas';

  @override
  String get blockTypeBulletHint => 'Lista con puntos';

  @override
  String get blockTypeNumberedLabel => 'Lista numerada';

  @override
  String get blockTypeNumberedHint => 'Lista 1, 2, 3';

  @override
  String get blockTypeTodoLabel => 'Lista de tarefas';

  @override
  String get blockTypeTodoHint => 'Checklist';

  @override
  String get blockTypeTaskLabel => 'Tarefa enriquecida';

  @override
  String get blockTypeTaskHint => 'Estado / prioridade / data';

  @override
  String get blockTypeToggleLabel => 'Despregable';

  @override
  String get blockTypeToggleHint => 'Mostrar ou agochar contido';

  @override
  String get blockTypeImageLabel => 'Imaxe';

  @override
  String get blockTypeImageHint => 'Imaxe local ou externa';

  @override
  String get blockTypeBookmarkLabel => 'Marcador con vista previa';

  @override
  String get blockTypeBookmarkHint => 'Tarxeta con ligazón';

  @override
  String get blockTypeVideoLabel => 'Vídeo';

  @override
  String get blockTypeVideoHint => 'Ficheiro ou URL';

  @override
  String get blockTypeAudioLabel => 'Audio';

  @override
  String get blockTypeAudioHint => 'Reprodutor de audio';

  @override
  String get blockTypeMeetingNoteLabel => 'Nota de reunión';

  @override
  String get blockTypeMeetingNoteHint => 'Graba e transcribe unha reunión';

  @override
  String get blockTypeCodeLabel => 'Código (Java, Python…)';

  @override
  String get blockTypeCodeHint => 'Bloque con sintaxe';

  @override
  String get blockTypeFileLabel => 'Ficheiro / PDF';

  @override
  String get blockTypeFileHint => 'Anexo ou PDF';

  @override
  String get blockTypeTableLabel => 'Táboa';

  @override
  String get blockTypeTableHint => 'Filas e columnas';

  @override
  String get blockTypeDatabaseLabel => 'Base de datos';

  @override
  String get blockTypeDatabaseHint => 'Vista lista/táboa/táboiro';

  @override
  String get blockTypeKanbanLabel => 'Kanban';

  @override
  String get blockTypeKanbanHint =>
      'Vista táboiro para as tarefas desta páxina';

  @override
  String get kanbanBlockRowTitle => 'Táboiro Kanban';

  @override
  String get kanbanBlockRowSubtitle =>
      'Ao abrir a páxina móstrase o táboiro. Na barra usa «Abrir editor de bloques» para editar ou quitar este bloque.';

  @override
  String get kanbanRowTodosExcluded => 'Sen checklists';

  @override
  String get kanbanToolbarOpenEditor => 'Abrir editor de bloques';

  @override
  String get kanbanToolbarAddTask => 'Engadir tarefa';

  @override
  String get kanbanClassicModeBanner =>
      'Editor de bloques: podes mover ou eliminar o bloque Kanban.';

  @override
  String get kanbanBackToBoard => 'Volver ao táboiro';

  @override
  String get kanbanMultipleBlocksSnack =>
      'Esta páxina ten máis dun bloque Kanban; úsase o primeiro.';

  @override
  String get kanbanEmptyColumn => 'Sen tarefas';

  @override
  String get blockTypeDriveLabel => 'Arquivo Drive';

  @override
  String get blockTypeDriveHint => 'Xestor de ficheiros integrado';

  @override
  String get driveBlockRowTitle => 'Arquivo Drive';

  @override
  String driveBlockRowSubtitle(int files, int folders) {
    return '$files ficheiros · $folders cartafoles';
  }

  @override
  String get driveNewFolder => 'Novo cartafol';

  @override
  String get driveUploadFile => 'Subir ficheiro';

  @override
  String get driveImportFromVault => 'Importar do vault';

  @override
  String get driveViewGrid => 'Grade';

  @override
  String get driveViewList => 'Lista';

  @override
  String get driveEditBlock => 'Editar bloque';

  @override
  String get driveFolderEmpty => 'Este cartafol está baleiro';

  @override
  String get driveDeleteConfirm => 'Eliminar este ficheiro?';

  @override
  String get driveOpenFile => 'Abrir ficheiro';

  @override
  String get driveMoveTo => 'Mover a…';

  @override
  String get driveClassicModeBanner =>
      'Editor de bloques: podes mover ou eliminar o bloque Drive.';

  @override
  String get driveBackToDrive => 'Volver ao drive';

  @override
  String get driveMultipleBlocksSnack =>
      'Esta páxina ten máis dun bloque Drive; úsase o primeiro.';

  @override
  String get driveDeleteOriginalsTitle => 'Eliminar orixinais ao importar';

  @override
  String get driveDeleteOriginalsSubtitle =>
      'Ao subir ficheiros ao drive, os orixinais elimínanse automaticamente do disco.';

  @override
  String get blockTypeEquationLabel => 'Ecuación (LaTeX)';

  @override
  String get blockTypeEquationHint => 'Fórmulas matemáticas';

  @override
  String get blockTypeMermaidLabel => 'Diagrama (Mermaid)';

  @override
  String get blockTypeMermaidHint => 'Diagrama de fluxo ou esquema';

  @override
  String get blockTypeTocLabel => 'Táboa de contidos';

  @override
  String get blockTypeTocHint => 'Índice automático';

  @override
  String get blockTypeBreadcrumbLabel => 'Migas de pan';

  @override
  String get blockTypeBreadcrumbHint => 'Ruta de navegación';

  @override
  String get blockTypeTemplateButtonLabel => 'Botón de plantilla';

  @override
  String get blockTypeTemplateButtonHint => 'Inserir bloque predefinido';

  @override
  String get blockTypeColumnListLabel => 'Columnas';

  @override
  String get blockTypeColumnListHint => 'Deseño en columnas';

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
    return 'Esta app xa estaba aprobada coa integración $previousVersion e agora solicita acceso coa versión $integrationVersion.';
  }

  @override
  String integrationDialogBodyNew(
    Object appName,
    Object appVersion,
    Object integrationVersion,
  ) {
    return '«$appName» quere usar a ponte local de Folio coa app versión $appVersion e a integración $integrationVersion.';
  }

  @override
  String get integrationChipLocalhostOnly => 'Só localhost';

  @override
  String get integrationChipRevocableApproval => 'Aprobación revogábel';

  @override
  String get integrationChipNoSharedSecret => 'Sen segredo compartido';

  @override
  String get integrationChipScopedByAppId => 'Permiso por appId';

  @override
  String get integrationMetaPreviouslyApprovedVersion =>
      'Versión anterior aprobada';

  @override
  String get integrationSectionWhatAppCanDo => 'O que esta app poderá facer';

  @override
  String get integrationCapEphemeralSessionsTitle =>
      'Abrir sesións locais efémeras';

  @override
  String get integrationCapEphemeralSessionsBody =>
      'Poderá iniciar unha sesión temporal para falar coa ponte local de Folio neste dispositivo.';

  @override
  String get integrationCapImportPagesTitle =>
      'Importar e actualizar as súas propias páxinas';

  @override
  String get integrationCapImportPagesBody =>
      'Poderá crear páxinas, listalas e actualizar só as que a mesma app importara antes.';

  @override
  String get integrationCapCustomEmojisTitle =>
      'Xestionar os seus emojis personalizados';

  @override
  String get integrationCapCustomEmojisBody =>
      'Poderá listar, crear, substituír e borrar só o seu catálogo de emojis ou iconas importadas.';

  @override
  String get integrationCapUnlockedVaultTitle =>
      'Traballar só co caderno desbloqueado';

  @override
  String get integrationCapUnlockedVaultBody =>
      'As peticións só funcionan cando Folio está aberto, o caderno está dispoñible e a sesión actual segue activa.';

  @override
  String get integrationSectionWhatStaysBlocked => 'O que seguirá bloqueado';

  @override
  String get integrationBlockNoSeeAllTitle => 'Non pode ver todo o teu contido';

  @override
  String get integrationBlockNoSeeAllBody =>
      'Non obtén acceso xeral ao caderno. Só pode listar o que ela mesma importou mediante o seu appId.';

  @override
  String get integrationBlockNoBypassTitle =>
      'Non pode saltarse o bloqueo nin o cifrado';

  @override
  String get integrationBlockNoBypassBody =>
      'Se o caderno está bloqueado ou non hai sesión activa, Folio rexeitará a operación.';

  @override
  String get integrationBlockNoOtherAppsTitle =>
      'Non pode tocar datos doutras apps';

  @override
  String get integrationBlockNoOtherAppsBody =>
      'Tampouco pode xestionar páxinas importadas ou emojis rexistrados por outras apps aprobadas.';

  @override
  String get integrationBlockNoRemoteTitle =>
      'Non pode entrar desde fóra do teu equipo';

  @override
  String get integrationBlockNoRemoteBody =>
      'A ponte segue limitada a localhost e esta aprobación pódese revogar máis tarde dende Axustes.';

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
      'Elixe como queres aplicar o ficheiro Markdown.';

  @override
  String get markdownImportModeNewPage => 'Páxina nova';

  @override
  String get markdownImportModeAppend => 'Anexar á actual';

  @override
  String get markdownImportModeReplace => 'Substituír a actual';

  @override
  String get markdownImportCouldNotReadPath =>
      'Non se puido ler a ruta do ficheiro.';

  @override
  String markdownImportedBlocks(Object pageTitle, int blockCount) {
    return 'Markdown importado: $pageTitle ($blockCount bloques).';
  }

  @override
  String markdownImportFailedWithError(Object error) {
    return 'Non se puido importar o Markdown: $error';
  }

  @override
  String get importPage => 'Importar…';

  @override
  String get exportMarkdownFileDialogTitle => 'Exportar páxina a Markdown';

  @override
  String get markdownExportSuccess => 'Páxina exportada a Markdown.';

  @override
  String markdownExportFailedWithError(Object error) {
    return 'Non se puido exportar a páxina: $error';
  }

  @override
  String get exportPageDialogTitle => 'Exportar páxina';

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
  String get exportHtmlFileDialogTitle => 'Exportar páxina a HTML';

  @override
  String get htmlExportSuccess => 'Páxina exportada a HTML.';

  @override
  String htmlExportFailedWithError(Object error) {
    return 'Non se puido exportar a páxina: $error';
  }

  @override
  String get exportTxtFileDialogTitle => 'Exportar páxina a texto';

  @override
  String get txtExportSuccess => 'Páxina exportada a texto.';

  @override
  String txtExportFailedWithError(Object error) {
    return 'Non se puido exportar a páxina: $error';
  }

  @override
  String get exportJsonFileDialogTitle => 'Exportar páxina a JSON';

  @override
  String get jsonExportSuccess => 'Páxina exportada a JSON.';

  @override
  String jsonExportFailedWithError(Object error) {
    return 'Non se puido exportar a páxina: $error';
  }

  @override
  String get exportPdfFileDialogTitle => 'Exportar páxina a PDF';

  @override
  String get pdfExportSuccess => 'Páxina exportada a PDF.';

  @override
  String pdfExportFailedWithError(Object error) {
    return 'Non se puido exportar a páxina: $error';
  }

  @override
  String get firebaseUnavailablePublish => 'Firebase non está dispoñible.';

  @override
  String get signInCloudToPublishWeb =>
      'Inicia sesión na conta na nube (Axustes) para publicar.';

  @override
  String get planMissingWebPublish =>
      'O teu plan non inclúe publicación web ou a subscrición non está activa.';

  @override
  String get publishWebDialogTitle => 'Publicar na web';

  @override
  String get publishWebSlugLabel => 'URL (slug)';

  @override
  String get publishWebSlugHint => 'a-mina-nota';

  @override
  String get publishWebSlugHelper =>
      'Letras, números e guións. Quedará na URL pública.';

  @override
  String get publishWebAction => 'Publicar';

  @override
  String get publishWebEmptySlug => 'Slug baleiro.';

  @override
  String publishWebSuccessWithUrl(Object url) {
    return 'Publicado: $url';
  }

  @override
  String publishWebFailedWithError(Object error) {
    return 'Non se puido publicar: $error';
  }

  @override
  String get publishWebMenuLabel => 'Publicar na web';

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
  String get databaseSortAz => 'Ordenar A-Z';

  @override
  String get databaseSortLabel => 'Ordenar';

  @override
  String get databaseFilterAnd => 'E';

  @override
  String get databaseFilterOr => 'OU';

  @override
  String get databaseSortDescending => 'Desc';

  @override
  String get databaseNewPropertyDialogTitle => 'Nova propiedade';

  @override
  String databaseConfigurePropertyTitle(Object name) {
    return 'Configurar: $name';
  }

  @override
  String get databaseLocalCurrentBadge => 'BD local actual';

  @override
  String databaseRelateRowsTitle(Object name) {
    return 'Relacionar filas ($name)';
  }

  @override
  String get databaseBoardNeedsGroupProperty =>
      'Configura unha propiedade de grupo para o taboleiro.';

  @override
  String get databaseGroupPropertyMissing =>
      'A propiedade de grupo xa non existe.';

  @override
  String get databaseCalendarNeedsDateProperty =>
      'Configura unha propiedade de data para o calendario.';

  @override
  String get databaseNoDatedEvents => 'Sen eventos con data.';

  @override
  String get databaseConfigurePropertyTooltip => 'Configurar propiedade';

  @override
  String get databaseFormulaHintExample =>
      'if(contains(Nome,\"x\"), add(1,2), 0)';

  @override
  String get createAction => 'Crear';

  @override
  String get confirmAction => 'Confirmar';

  @override
  String get confirmRemoteEndpointTitle => 'Confirmar endpoint remoto';

  @override
  String get shortcutGlobalSearchKeyChord => 'Ctrl + Maiús + F';

  @override
  String get updateChannelRelease => 'Release';

  @override
  String get updateChannelBeta => 'Beta';

  @override
  String get blockActionChooseAudio => 'Escoller audio…';

  @override
  String get blockActionCreateSubpage => 'Crear subpáxina';

  @override
  String get blockActionLinkPage => 'Ligar páxina…';

  @override
  String get defaultNewPageTitle => 'Páxina nova';

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
      'O ficheiro non é un modelo Folio válido.';

  @override
  String get templateButtonDefaultLabel => 'Plantilla';

  @override
  String get pageHtmlExportPublishedWithFolio => 'Publicado con Folio';

  @override
  String get releaseReadinessSemverOk => 'Versión SemVer válida';

  @override
  String get releaseReadinessEncryptedVault => 'Caderno cifrado';

  @override
  String get releaseReadinessAiRemotePolicy => 'Política de endpoint de IA';

  @override
  String get releaseReadinessVaultUnlocked => 'Caderno desbloqueado';

  @override
  String get releaseReadinessStableChannel => 'Canal estable seleccionado';

  @override
  String get aiPromptUserMessage => 'Mensaxe do usuario:';

  @override
  String get aiPromptOriginalMessage => 'Mensaxe orixinal:';

  @override
  String get aiPromptOriginalUserMessage => 'Mensaxe orixinal do usuario:';

  @override
  String get customIconImportEmptySource => 'A fonte da icona está baleira.';

  @override
  String get customIconImportInvalidUrl => 'O URL da icona non é válido.';

  @override
  String get customIconImportInvalidSvg => 'O SVG copiado non é válido.';

  @override
  String get customIconImportHttpHttpsOnly =>
      'Só se admiten URL http ou https.';

  @override
  String get customIconImportDataUriMimeList =>
      'Só se admiten data:image/svg+xml, data:image/gif, data:image/webp ou data:image/png.';

  @override
  String get customIconImportUnsupportedFormat =>
      'Formato non compatible. Usa SVG, PNG, GIF ou WebP.';

  @override
  String get customIconImportSvgTooLarge =>
      'O SVG é demasiado grande para importalo.';

  @override
  String get customIconImportEmbeddedImageTooLarge =>
      'A imaxe incrustada é demasiado grande para importala.';

  @override
  String customIconImportDownloadFailed(Object code) {
    return 'Non se puido descargar a icona ($code).';
  }

  @override
  String get customIconImportRemoteTooLarge =>
      'A icona remota é demasiado grande.';

  @override
  String get customIconImportConnectFailed =>
      'Non se puido conectar para descargar a icona.';

  @override
  String get customIconImportCertFailed =>
      'Fallo de certificado ao descargar a icona.';

  @override
  String get customIconLabelDefault => 'Icona personalizada';

  @override
  String get customIconLabelImported => 'Icona importada';

  @override
  String get customIconImportSucceeded => 'Icona importada correctamente.';

  @override
  String get customIconClipboardEmpty => 'O portapapeis está baleiro.';

  @override
  String get customIconRemoved => 'Icona eliminada.';

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
  String get codeLangPlainText => 'Texto simple';

  @override
  String settingsAppRevoked(Object appId) {
    return 'App revogada: $appId';
  }

  @override
  String get settingsDeviceRevokedSnack => 'Dispositivo revogado.';

  @override
  String get settingsAiConnectionOk => 'Conexión de IA OK';

  @override
  String settingsAiConnectionError(Object error) {
    return 'Erro de conexión: $error';
  }

  @override
  String settingsAiListModelsFailed(Object error) {
    return 'Non se puideron listar modelos: $error';
  }

  @override
  String get folioCloudCallableNotSignedIn =>
      'Debes iniciar sesión para chamar a Cloud Functions';

  @override
  String get folioCloudCallableUnexpectedResponse =>
      'Resposta inesperada de Cloud Functions';

  @override
  String folioCloudCallableHttpError(int code, Object name) {
    return 'HTTP $code ao chamar a $name';
  }

  @override
  String get folioCloudCallableNoIdToken =>
      'Sen token de ID para Cloud Functions. Inicia sesión de novo en Folio Cloud.';

  @override
  String get folioCloudCallableUnexpectedFallback =>
      'Resposta inesperada da copia de seguranza de Cloud Functions';

  @override
  String folioCloudCallableHttpAiComplete(int code) {
    return 'HTTP $code ao chamar folioCloudAiCompleteHttp';
  }

  @override
  String get cloudAccountEmailMismatch =>
      'O correo non coincide coa sesión actual.';

  @override
  String get cloudIdentityInvalidAuthResponse =>
      'Resposta de autenticación non válida.';

  @override
  String get templateButtonPlaceholderText => 'Texto da plantilla…';

  @override
  String get aiProviderOllamaName => 'Ollama';

  @override
  String get aiProviderLmStudioName => 'LM Studio';

  @override
  String get blockAudioEmptyHint => 'Elixe un ficheiro de audio';

  @override
  String get blockChildPageTitle => 'Bloque de páxina';

  @override
  String get blockChildPageNoLink => 'Sen subpáxina ligada.';

  @override
  String get mermaidExpandedLoadError =>
      'Non se puido mostrar o diagrama ampliado.';

  @override
  String get mermaidPreviewTooltip =>
      'Toca para ampliar e facer zoom. PNG mediante mermaid.ink (servizo externo).';

  @override
  String get aiEndpointInvalidUrl => 'URL non válida. Usa http://host:porto.';

  @override
  String get aiEndpointRemoteNotAllowed =>
      'O endpoint remoto non está permitido sen confirmación.';

  @override
  String get settingsAiSelectProviderFirst =>
      'Selecciona primeiro un provedor de IA.';

  @override
  String get releaseReadinessAiSummaryDisabled => 'IA desactivada';

  @override
  String get releaseReadinessAiSummaryQuillCloud =>
      'Folio Cloud IA (sen endpoint local)';

  @override
  String releaseReadinessAiSummaryEndpointOk(Object url) {
    return 'Endpoint válido: $url';
  }

  @override
  String get releaseReadinessDetailSemverInvalid =>
      'A versión instalada non cumpre SemVer.';

  @override
  String get releaseReadinessDetailVaultNotEncrypted =>
      'O caderno actual non está cifrado.';

  @override
  String get releaseReadinessDetailVaultLocked =>
      'Desbloquea o caderno para validar exportación/importación e o fluxo real.';

  @override
  String get releaseReadinessDetailBetaChannel =>
      'O canal beta de actualizacións está activo.';

  @override
  String get releaseReadinessReportTitle =>
      'Folio: preparación para o lanzamento';

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
    return 'Canal de actualizacións: $value';
  }

  @override
  String releaseReadinessReportActiveVault(Object id) {
    return 'Caderno activo: $id';
  }

  @override
  String releaseReadinessReportVaultPath(Object path) {
    return 'Ruta do caderno: $path';
  }

  @override
  String releaseReadinessReportUnlocked(Object value) {
    return 'Caderno desbloqueado: $value';
  }

  @override
  String releaseReadinessReportEncrypted(Object value) {
    return 'Caderno cifrado: $value';
  }

  @override
  String releaseReadinessReportAiEnabled(Object value) {
    return 'IA habilitada: $value';
  }

  @override
  String releaseReadinessReportAiPolicy(Object value) {
    return 'Política de endpoint IA: $value';
  }

  @override
  String releaseReadinessReportAiDetail(Object detail) {
    return 'Detalle IA: $detail';
  }

  @override
  String releaseReadinessReportStatus(Object value) {
    return 'Estado de lanzamento: $value';
  }

  @override
  String releaseReadinessReportBlockers(int count) {
    return 'Bloqueadores pendentes: $count';
  }

  @override
  String releaseReadinessReportWarnings(int count) {
    return 'Advertencias pendentes: $count';
  }

  @override
  String get releaseReadinessExportWordYes => 'si';

  @override
  String get releaseReadinessExportWordNo => 'non';

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
  String get releaseReadinessPolicyError => 'erro';

  @override
  String get settingsSignInFolioCloudSnack => 'Inicia sesión en Folio Cloud.';

  @override
  String get settingsNotSyncedYet => 'Aínda sen sincronizar';

  @override
  String get settingsDeviceNameTitle => 'Nome do dispositivo';

  @override
  String get settingsDeviceNameHintExample => 'Exemplo: Pixel de Alejandra';

  @override
  String get settingsPairingModeEnabledTwoMin =>
      'Modo de vinculación activo durante 2 minutos.';

  @override
  String get settingsPairingEnableModeFirst =>
      'Primeiro activa o modo de vinculación e logo elixe un dispositivo detectado.';

  @override
  String get settingsPairingSameEmojisBothDevices =>
      'Activa o modo de vinculación en ambos dispositivos e agarda os mesmos 3 emojis.';

  @override
  String get settingsPairingCouldNotStart =>
      'Non se puido iniciar a vinculación. Activa o modo en ambos dispositivos e agarda os mesmos 3 emojis.';

  @override
  String get settingsConfirmPairingTitle => 'Confirmar vinculación';

  @override
  String get settingsPairingCheckOtherDeviceEmojis =>
      'Comproba que no outro dispositivo aparecen estes mesmos 3 emojis:';

  @override
  String get settingsPairingPopupInstructions =>
      'Este popup tamén aparecerá no outro dispositivo. Para completar a ligazón, pulsa Vincular aquí e logo Vincular no outro.';

  @override
  String get settingsLinkDevice => 'Vincular';

  @override
  String get settingsPairingConfirmationSent =>
      'Confirmación enviada. Falta que o outro dispositivo pulse Vincular no seu popup.';

  @override
  String get settingsResolveConflictsTitle => 'Resolver conflitos';

  @override
  String get settingsNoPendingConflicts => 'Non hai conflitos pendentes.';

  @override
  String settingsSyncConflictCardSubtitle(
    Object fromPeerId,
    int remotePageCount,
    Object detectedAt,
  ) {
    return 'Orixe: $fromPeerId\nPáxinas remotas: $remotePageCount\nDetectado: $detectedAt';
  }

  @override
  String get settingsSyncConflictHeading => 'Conflito de sincronización';

  @override
  String get settingsLocalVersionKeptSnack => 'Conservouse a versión local.';

  @override
  String get settingsKeepLocal => 'Manter local';

  @override
  String get settingsRemoteVersionAppliedSnack => 'Aplicouse a versión remota.';

  @override
  String get settingsCouldNotApplyRemoteSnack =>
      'Non se puido aplicar a versión remota.';

  @override
  String get settingsAcceptRemote => 'Aceptar remota';

  @override
  String get settingsClose => 'Pechar';

  @override
  String get settingsSectionDeviceSyncNav => 'Sincronización';

  @override
  String get settingsSectionVault => 'Caderno';

  @override
  String get settingsSectionVaultHeroDescription =>
      'Seguridade ao desbloquear, copias, programación a disco e xestión de datos neste dispositivo.';

  @override
  String get settingsSectionUiWorkspace => 'Interface e escritorio';

  @override
  String get settingsSectionUiWorkspaceHeroDescription =>
      'Tema, idioma, escala, editor, opcións de escritorio e atallos de teclado.';

  @override
  String get settingsSubsectionVaultBackupImport => 'Copias e importación';

  @override
  String get settingsSubsectionVaultScheduledLocal =>
      'Copia programada (local)';

  @override
  String get settingsSubsectionDrive => 'Drive';

  @override
  String get settingsSubsectionVaultData => 'Datos (zona de perigo)';

  @override
  String get folioCloudSubsectionAccount => 'Conta';

  @override
  String get folioCloudSubsectionEncryptedBackups => 'Copias cifradas (nube)';

  @override
  String get folioCloudSubsectionPublishing => 'Publicación web';

  @override
  String get settingsFolioCloudSubsectionScheduledCloud =>
      'Copia programada a Folio Cloud';

  @override
  String get settingsScheduledCloudUploadRequiresSchedule =>
      'Activa antes a copia programada en Caderno › Copia programada (local).';

  @override
  String get settingsSyncHeroTitle => 'Sincronización entre dispositivos';

  @override
  String get settingsSyncHeroDescription =>
      'Emparella equipos na rede local; o relay só axuda a negociar a conexión e non envía o contido do vault.';

  @override
  String get settingsSyncChipPairingCode => 'Código de ligazón';

  @override
  String get settingsSyncChipAutoDiscovery => 'Detección automática';

  @override
  String get settingsSyncChipOptionalRelay => 'Relay opcional';

  @override
  String get settingsSyncEnableTitle =>
      'Activar sincronización entre dispositivos';

  @override
  String get settingsSyncSearchingSubtitle =>
      'Buscando dispositivos con Folio aberto na rede local...';

  @override
  String settingsSyncDevicesFoundOnLan(int count) {
    return '$count dispositivos detectados na LAN.';
  }

  @override
  String get settingsSyncDisabledSubtitle =>
      'A sincronización está desactivada.';

  @override
  String get settingsSyncRelayTitle => 'Usar relay de sinalización';

  @override
  String get settingsSyncRelaySubtitle =>
      'Non envía o contido do vault, só axuda a negociar a conexión se falla a LAN.';

  @override
  String get settingsEdit => 'Editar';

  @override
  String get settingsSyncEmojiModeTitle =>
      'Activar modo vinculación por emojis';

  @override
  String get settingsSyncEmojiModeSubtitle =>
      'Actívao en ambos dispositivos para iniciar a vinculación sen escribir códigos.';

  @override
  String get settingsSyncPairingStatusTitle => 'Estado do modo vinculación';

  @override
  String get settingsSyncPairingActiveSubtitle =>
      'Activo durante 2 minutos. Xa podes iniciar a vinculación desde un dispositivo detectado.';

  @override
  String get settingsSyncPairingInactiveSubtitle =>
      'Inactivo. Actívao aquí e no outro dispositivo para empezar a vincular.';

  @override
  String get settingsSyncLastSyncTitle => 'Última sincronización';

  @override
  String get settingsSyncPendingConflictsTitle => 'Conflitos pendentes';

  @override
  String get settingsSyncNoConflictsSubtitle => 'Sen conflitos pendentes.';

  @override
  String settingsSyncConflictsNeedReview(int count) {
    return '$count conflitos requiren revisión manual.';
  }

  @override
  String get settingsResolve => 'Resolver';

  @override
  String get settingsSyncDiscoveredDevicesTitle => 'Dispositivos detectados';

  @override
  String get settingsSyncNoDevicesYetHint =>
      'Aínda non se detectaron dispositivos. Asegúrate de que ambas apps están abertas na mesma rede.';

  @override
  String get settingsSyncPeerReadyToLink => 'Listo para vincular.';

  @override
  String get settingsSyncPeerOtherInPairingMode =>
      'O outro dispositivo está en modo vinculación. Actívao aquí para iniciar a ligazón.';

  @override
  String get settingsSyncPeerDetectedLan => 'Detectado na rede local.';

  @override
  String get settingsSyncLinkedDevicesTitle => 'Dispositivos vinculados';

  @override
  String get settingsSyncNoLinkedDevicesYet =>
      'Aínda non hai dispositivos ligados.';

  @override
  String settingsSyncPeerIdLabel(Object peerId) {
    return 'ID: $peerId';
  }

  @override
  String get settingsRevoke => 'Revogar';

  @override
  String get sidebarPageIconTitle => 'Icona da páxina';

  @override
  String get sidebarPageIconPickerHelper =>
      'Elixe unha icona rápida, unha importada ou abre o selector completo.';

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
      'Aínda non importaches iconas en Axustes.';

  @override
  String get settingsStripeSubscriptionRefreshed =>
      'Facturación Folio Cloud actualizada.';

  @override
  String get settingsStripeBillingPortalUnavailable =>
      'Portal de facturación non dispoñible.';

  @override
  String get settingsCouldNotOpenLink => 'Non se puido abrir a ligazón.';

  @override
  String get settingsStripeCheckoutUnavailable =>
      'Pago non dispoñible (configura Stripe no servidor).';

  @override
  String get settingsCloudBackupEnablePlanSnack =>
      'Activa Folio Cloud coa función de copia na nube incluída no teu plan.';

  @override
  String get settingsNoActiveVault => 'Non hai libreta activa.';

  @override
  String get settingsCloudBackupsNeedPlan =>
      'Necesitas Folio Cloud activo con copia na nube.';

  @override
  String settingsCloudBackupsDialogTitle(int count) {
    return 'Copias na nube ($count/10)';
  }

  @override
  String get settingsCloudBackupsVaultLabel => 'Caixa forte';

  @override
  String get settingsCloudBackupsEmpty => 'Aínda non hai copias nesta conta.';

  @override
  String get settingsCloudBackupDownloadTooltip => 'Descargar';

  @override
  String get settingsCloudBackupActionDownload => 'Descargar';

  @override
  String get settingsCloudBackupActionImportOverwrite =>
      'Importar (sobrescribir)';

  @override
  String get settingsCloudBackupSaveDialogTitle => 'Gardar copia';

  @override
  String get settingsCloudBackupDownloadedSnack => 'Copia descargada.';

  @override
  String get settingsCloudBackupDeletedSnack => 'Copia borrada.';

  @override
  String get settingsCloudBackupImportedSnack => 'Importación completada.';

  @override
  String get settingsCloudBackupVaultMustBeUnlocked =>
      'A libreta debe estar desbloqueada.';

  @override
  String settingsCloudBackupsTotalLabel(Object size) {
    return 'Total: $size';
  }

  @override
  String get settingsCloudBackupImportOverwriteTitle =>
      'Importar (sobrescribir)';

  @override
  String get settingsCloudBackupImportOverwriteBody =>
      'Isto sobrescribirá o contido da libreta aberta. Asegúrate de ter unha copia local antes de continuar.';

  @override
  String get settingsCloudBackupDeleteWarning =>
      'Seguro que queres borrar esta copia da nube? Esta acción non se pode desfacer.';

  @override
  String get settingsPublishedRequiresPlan =>
      'Necesitas Folio Cloud con publicación web activa.';

  @override
  String get settingsPublishedPagesTitle => 'Páxinas publicadas';

  @override
  String get settingsPublishedPagesEmpty => 'Aínda non hai páxinas publicadas.';

  @override
  String get settingsPublishedDeleteDialogTitle => '¿Eliminar publicación?';

  @override
  String get settingsPublishedDeleteDialogBody =>
      'Borrarase o HTML público e a ligazón deixará de funcionar.';

  @override
  String get settingsPublishedRemovedSnack => 'Publicación eliminada.';

  @override
  String get settingsCouldNotReadInstalledVersion =>
      'Non se puido ler a versión instalada.';

  @override
  String settingsCouldNotOpenReleaseNotes(Object error) {
    return 'Non se puideron abrir as notas de versión: $error';
  }

  @override
  String settingsUpdateFailed(Object error) {
    return 'Non se puido actualizar: $error';
  }

  @override
  String get settingsSessionEndedSnack => 'Sesión pechada';

  @override
  String get settingsLabelYes => 'Si';

  @override
  String get settingsLabelNo => 'Non';

  @override
  String get settingsSecurityEncryptedHeroDescription =>
      'Desbloqueo rápido, passkey, bloqueo automático e contrasinal mestre do vault cifrado.';

  @override
  String get settingsUnencryptedVaultTitle => 'Vault sen cifrar';

  @override
  String get settingsUnencryptedVaultChipDataOnDisk => 'Datos en disco';

  @override
  String get settingsUnencryptedVaultChipEncryptionAvailable =>
      'Cifrado dispoñible';

  @override
  String get settingsAppearanceChipTheme => 'Tema';

  @override
  String get settingsAppearanceChipZoom => 'Zoom';

  @override
  String get settingsAppearanceChipLanguage => 'Idioma';

  @override
  String get settingsAppearanceChipEditorWorkspace => 'Editor e espazo';

  @override
  String get settingsWindowsScaleFollowTitle => 'Seguir escala de Windows';

  @override
  String get settingsWindowsScaleFollowSubtitle =>
      'Usa automaticamente a escala do sistema en Windows.';

  @override
  String get settingsInterfaceZoomTitle => 'Zoom da interface';

  @override
  String get settingsInterfaceZoomSubtitle =>
      'Aumenta ou reduce o tamaño xeral da app.';

  @override
  String get settingsUiZoomReset => 'Restablecer';

  @override
  String get settingsEditorSubsection => 'Editor';

  @override
  String get settingsEditorContentWidthTitle => 'Ancho do contido';

  @override
  String get settingsEditorContentWidthSubtitle =>
      'Define canto ancho ocupan os bloques no editor.';

  @override
  String get settingsEnterCreatesNewBlockTitle => 'Intro crea un bloque novo';

  @override
  String get settingsEnterCreatesNewBlockSubtitleWhenEnabled =>
      'Desactiva para que Intro insira salto de liña.';

  @override
  String get settingsEnterCreatesNewBlockSubtitleWhenDisabled =>
      'Agora Intro insire salto de liña. Maiús+Intro tamén funciona.';

  @override
  String get settingsWorkspaceSubsection => 'Espazo de traballo';

  @override
  String get settingsCustomIconsTitle => 'Iconas personalizadas';

  @override
  String get settingsCustomIconsDescription =>
      'Importa unha URL PNG, GIF ou WebP, ou un data:image compatible copiado desde páxinas como notionicons.so. Despois poderás usalo como icona de páxina ou de callout.';

  @override
  String settingsCustomIconsSavedCount(int count) {
    return '$count gardados';
  }

  @override
  String get settingsCustomIconsChipUrl => 'URL PNG, GIF ou WebP';

  @override
  String get settingsCustomIconsChipDataImage => 'data:image/*';

  @override
  String get settingsCustomIconsChipPaste => 'Pegar desde portapapeis';

  @override
  String get settingsCustomIconsImportTitle => 'Importar nova icona';

  @override
  String get settingsCustomIconsImportSubtitle =>
      'Podes poñerlle nome e pegar a fonte manualmente ou traela directamente do portapapeis.';

  @override
  String get settingsCustomIconsFieldNameLabel => 'Nome';

  @override
  String get settingsCustomIconsFieldNameHint => 'Opcional';

  @override
  String get settingsCustomIconsFieldSourceLabel => 'URL ou data:image';

  @override
  String get settingsCustomIconsFieldSourceHint =>
      'https://…gif | …webp | …png ou data:image/…';

  @override
  String get settingsCustomIconsImportButton => 'Importar icona';

  @override
  String get settingsCustomIconsFromClipboard => 'Desde portapapeis';

  @override
  String get settingsCustomIconsLibraryTitle => 'Biblioteca';

  @override
  String get settingsCustomIconsLibrarySubtitle =>
      'Listos para usar en toda a app';

  @override
  String get settingsCustomIconsEmpty => 'Aínda non importaches iconas.';

  @override
  String get settingsCustomIconsDeleteTooltip => 'Eliminar icona';

  @override
  String get settingsCustomIconsReferenceCopiedSnack => 'Referencia copiada.';

  @override
  String get settingsCustomIconsCopyToken => 'Copiar token';

  @override
  String get settingsAiHeroQuillWithLocalAlt =>
      'A IA execútase en Quill Cloud (subscrición con IA na nube ou tinta mercada). Elixe outro provedor abaixo para Ollama ou LM Studio en local.';

  @override
  String get settingsAiHeroQuillCloudOnly =>
      'A IA execútase en Quill Cloud (subscrición con IA na nube ou tinta mercada).';

  @override
  String get settingsAiHeroLocalDefault =>
      'Conecta Ollama ou LM Studio en local; o asistente usa o modelo e o contexto que configures aquí.';

  @override
  String get settingsAiHeroQuillMobileOnly =>
      'Neste dispositivo Quill só pode usar Quill Cloud. Elixe Quill Cloud como provedor cando queiras activar a IA.';

  @override
  String get settingsAiChipCloud => 'Na nube';

  @override
  String get settingsAiSnackFirebaseUnavailableBuild =>
      'Firebase non está dispoñible nesta compilación.';

  @override
  String get settingsAiSnackSignInCloudAccount =>
      'Inicia sesión na conta na nube (Axustes).';

  @override
  String settingsAiProviderSwitchFailed(Object error) {
    return 'Non se puido cambiar o provedor de IA: $error';
  }

  @override
  String get settingsAboutHeroDescription =>
      'Versión instalada, orixe de actualizacións e comprobación manual de novidades.';

  @override
  String get settingsOpenReleaseNotes => 'Ver notas de versión';

  @override
  String get settingsUpdateChannelLabel => 'Canle';

  @override
  String get settingsUpdateChannelRelease => 'Release';

  @override
  String get settingsUpdateChannelBeta => 'Beta';

  @override
  String get settingsDataHeroDescription =>
      'Accións permanentes sobre ficheiros locais. Fai unha copia de seguranza antes de borrar.';

  @override
  String get settingsDangerZoneTitle => 'Zona de perigo';

  @override
  String get settingsDesktopHeroDescription =>
      'Atallos globais, bandexa do sistema e comportamento da xanela no escritorio.';

  @override
  String get settingsShortcutsHeroDescription =>
      'Combinacións só dentro de Folio. Proba unha tecla antes de gardala.';

  @override
  String get settingsShortcutsTestChip => 'Probar';

  @override
  String get settingsIntegrationsChipApprovedPermissions =>
      'Permisos aprobados';

  @override
  String get settingsIntegrationsChipRevocableAccess => 'Acceso revogábel';

  @override
  String get settingsIntegrationsChipExternalApps => 'Apps externas';

  @override
  String get settingsIntegrationsActiveConnectionsTitle => 'Conexións activas';

  @override
  String get settingsIntegrationsActiveConnectionsSubtitle =>
      'Apps que xa poden interactuar con Folio';

  @override
  String get settingsViewInkUsageTable => 'Ver táboa de consumo';

  @override
  String get settingsCloudInkUsageTableTitle =>
      'Táboa de consumo de gotas (Quill Cloud)';

  @override
  String get settingsCloudInkUsageTableIntro =>
      'Custo base por acción. Pódense aplicar suplementos por prompts longos e por tokens de saída.';

  @override
  String get settingsCloudInkDrops => 'gotas';

  @override
  String get settingsCloudInkTableCachedNotice =>
      'Mostrando táboa en caché local (sen conexión ao backend).';

  @override
  String get settingsCloudInkOpRewriteBlock => 'Reescribir bloque';

  @override
  String get settingsCloudInkOpSummarizeSelection => 'Resumir selección';

  @override
  String get settingsCloudInkOpExtractTasks => 'Extraer tarefas';

  @override
  String get settingsCloudInkOpSummarizePage => 'Resumir páxina';

  @override
  String get settingsCloudInkOpGenerateInsert => 'Xerar inserción';

  @override
  String get settingsCloudInkOpGeneratePage => 'Xerar páxina';

  @override
  String get settingsCloudInkOpChatTurn => 'Quenda de chat';

  @override
  String get settingsCloudInkOpAgentMain => 'Execución de axente';

  @override
  String get settingsCloudInkOpAgentFollowup => 'Seguimento de axente';

  @override
  String get settingsCloudInkOpEditPagePanel => 'Edición de páxina (panel)';

  @override
  String get settingsCloudInkOpDefault => 'Operación por defecto';

  @override
  String get settingsDesktopRailSubtitle =>
      'Elixe unha categoría na lista ou desprázate polo contido.';

  @override
  String get settingsCloudInkViewTableButton => 'Ver táboa';

  @override
  String get settingsCloudInkHostedAiQuillCloudHint =>
      'Prezos de referencia para IA na nube en Quill Cloud.';

  @override
  String get vaultStarterHomeTitle => 'Comeza aquí';

  @override
  String get vaultStarterHomeHeading => 'O teu caderno xa está listo';

  @override
  String get vaultStarterHomeIntro =>
      'Folio organiza as túas páxinas nun árbore, edita o contido por bloques e mantén os datos neste dispositivo. Esta mini guía dache un mapa rápido do que podes facer desde o primeiro minuto.';

  @override
  String get vaultStarterHomeCallout =>
      'Podes borrar, renomear ou mover estas páxinas cando queiras. Son só unha base para arrancar máis rápido.';

  @override
  String get vaultStarterHomeSectionTips => 'O máis útil para empezar';

  @override
  String get vaultStarterHomeBulletSlash =>
      'Pulsa / dentro dun parágrafo para inserir cabeceiras, listas, táboas, bloques de código, Mermaid e máis.';

  @override
  String get vaultStarterHomeBulletSidebar =>
      'Usa o panel lateral para crear páxinas e subpáxinas, e reorganiza a árbore segundo a túa forma de traballar.';

  @override
  String get vaultStarterHomeBulletSettings =>
      'Abre Axustes para activar IA, configurar copia de seguranza, cambiar idioma ou engadir desbloqueo rápido.';

  @override
  String get vaultStarterHomeTodo1 =>
      'Crear a miña primeira páxina de traballo';

  @override
  String get vaultStarterHomeTodo2 =>
      'Probar o menú / para inserir un bloque novo';

  @override
  String get vaultStarterHomeTodo3 =>
      'Revisar Axustes e decidir se quero activar Quill ou un método de desbloqueo rápido';

  @override
  String get vaultStarterCapabilitiesTitle => 'Que pode facer Folio';

  @override
  String get vaultStarterCapabilitiesSectionMain => 'Capacidades principais';

  @override
  String get vaultStarterCapabilitiesBullet1 =>
      'Tomar notas con estrutura libre usando parágrafos, títulos, listas, checklists, citas e divisores.';

  @override
  String get vaultStarterCapabilitiesBullet2 =>
      'Traballar con bloques especiais como táboas, bases de datos, ficheiros, audio, vídeo, embeds e diagramas Mermaid.';

  @override
  String get vaultStarterCapabilitiesBullet3 =>
      'Buscar contido, revisar historial de páxina e manter revisións dentro do mesmo caderno.';

  @override
  String get vaultStarterCapabilitiesBullet4 =>
      'Exportar ou importar datos, incluíndo copia do caderno e importación desde Notion.';

  @override
  String get vaultStarterCapabilitiesSectionShortcuts => 'Atallos rápidos';

  @override
  String get vaultStarterCapabilitiesShortcutN =>
      'Ctrl+N crea unha páxina nova.';

  @override
  String get vaultStarterCapabilitiesShortcutSearch =>
      'Ctrl+K ou Ctrl+F abre a busca.';

  @override
  String get vaultStarterCapabilitiesShortcutSettings =>
      'Ctrl+, abre Axustes e Ctrl+L bloquea o caderno.';

  @override
  String get vaultStarterCapabilitiesAiCallout =>
      'A IA non se activa por defecto. Se decides usar Quill, configúraa en Axustes e elixes provedor, modelo e permisos de contexto.';

  @override
  String get vaultStarterQuillTitle => 'Quill e privacidade';

  @override
  String get vaultStarterQuillSectionWhat => 'Que pode facer Quill';

  @override
  String get vaultStarterQuillBullet1 =>
      'Resumir, reescribir ou expandir o contido dunha páxina.';

  @override
  String get vaultStarterQuillBullet2 =>
      'Responder dúbidas sobre bloques, atallos e formas de organizar as túas notas en Folio.';

  @override
  String get vaultStarterQuillBullet3 =>
      'Traballar coa páxina aberta como contexto ou con varias páxinas que selecciones como referencia.';

  @override
  String get vaultStarterQuillSectionPrivacy => 'Privacidade e seguranza';

  @override
  String get vaultStarterQuillPrivacyBody =>
      'As túas páxinas viven neste dispositivo. Se habilitas IA, revisa que contexto compartes e con que provedor. Se esqueces o contrasinal mestre dun caderno cifrado, Folio non pode recuperalo por ti.';

  @override
  String get vaultStarterQuillBackupCallout =>
      'Fai unha copia do caderno cando teñas contido importante. A copia conserva os datos e anexos, pero non transfere Hello nin passkeys entre dispositivos.';

  @override
  String get vaultStarterQuillMermaidCaption => 'Proba rápida de Mermaid:';

  @override
  String get vaultStarterQuillMermaidSource =>
      'graph TD\nInicio[Crear caderno] --> Organizar[Organizar páxinas]\nOrganizar --> Escribir[Escribir e enlazar ideas]\nEscribir --> Revisar[Buscar, revisar e mellorar]';
}
