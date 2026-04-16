// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Catalan Valencian (`ca`).
class AppLocalizationsCa extends AppLocalizations {
  AppLocalizationsCa([String locale = 'ca']) : super(locale);

  @override
  String get appTitle => 'Folio';

  @override
  String get loading => 'Carregant…';

  @override
  String get newVault => 'Nova caixa forta';

  @override
  String stepOfTotal(int current, int total) {
    return 'Pas $current de $total';
  }

  @override
  String get back => 'Enrere';

  @override
  String get continueAction => 'Continua';

  @override
  String get cancel => 'Cancel·la';

  @override
  String get retry => 'Torna-ho a provar';

  @override
  String get settings => 'Configuració';

  @override
  String get lockNow => 'Bloqueja';

  @override
  String get pageHistory => 'Historial de la pàgina';

  @override
  String get untitled => 'Sense títol';

  @override
  String get noPages => 'No hi ha pàgines';

  @override
  String get createPage => 'Crea una pàgina';

  @override
  String get selectPage => 'Selecciona una pàgina';

  @override
  String get saveInProgress => 'Desant…';

  @override
  String get savePending => 'Pendent de desar';

  @override
  String get savingVaultTooltip => 'Desant la caixa forta xifrada al disc…';

  @override
  String get autosaveSoonTooltip => 'Desat automàtic en un moment…';

  @override
  String get welcomeTitle => 'Benvingut';

  @override
  String get welcomeBody =>
      'Folio desa les teves pàgines només en aquest dispositiu, xifrades amb una contrasenya mestra. Si la oblides, no podrem recuperar les teves dades.\n\nNo hi ha sincronització al núvol.';

  @override
  String get createNewVault => 'Crea una nova caixa forta';

  @override
  String get importBackupZip => 'Importa còpia de seguretat (.zip)';

  @override
  String get importBackupTitle => 'Importa còpia de seguretat';

  @override
  String get importBackupBody =>
      'El fitxer conté les mateixes dades xifrades que l\'altre dispositiu. Necessites la contrasenya mestra utilitzada per crear aquesta còpia.\n\nLes claus de pas (passkeys) i el desbloqueig ràpid (Hello) no s\'inclouen i no són transferibles; pots configurar-los més tard a Configuració.';

  @override
  String get chooseZipFile => 'Tria un fitxer .zip';

  @override
  String get changeFile => 'Canvia el fitxer';

  @override
  String get backupPasswordLabel => 'Contrasenya de la còpia';

  @override
  String get backupPlainNoPasswordHint =>
      'Aquesta còpia de seguretat no està xifrada. No es requereix contrasenya per importar-la.';

  @override
  String get importVault => 'Importa la caixa forta';

  @override
  String get masterPasswordTitle => 'La teva contrasenya mestra';

  @override
  String masterPasswordHint(int min) {
    return 'Com a mínim $min caràcters. La utilitzaràs cada vegada que obris el Folio.';
  }

  @override
  String get createStarterPagesTitle => 'Crea pàgines d\'ajuda inicials';

  @override
  String get createStarterPagesBody =>
      'Afegeix una petita guia amb exemples, dreceres i capacitats del Folio. Pots suprimir aquestes pàgines més tard.';

  @override
  String get passwordLabel => 'Contrasenya';

  @override
  String get confirmPasswordLabel => 'Confirma la contrasenya';

  @override
  String get next => 'Següent';

  @override
  String get readyTitle => 'Tot a punt';

  @override
  String get readyBody =>
      'Es crearà una caixa forta xifrada en aquest dispositiu. Més tard podràs afegir Windows Hello, biometria o una clau de pas per a un desbloqueig més ràpid (Configuració).';

  @override
  String get quillIntroTitle => 'Coneix el Quill';

  @override
  String get quillIntroBody =>
      'El Quill és l\'assistent integrat del Folio. Pot ajudar-te a escriure, editar i entendre les teves pàgines, i també respondre preguntes sobre com utilitzar l\'aplicació.';

  @override
  String get quillIntroCapabilityWrite =>
      'Pot redactar, resumir o reescriure contingut dins de les teves pàgines.';

  @override
  String get quillIntroCapabilityExplain =>
      'També respon preguntes sobre el Folio, dreceres, blocs i com organitzar les teves notes.';

  @override
  String get quillIntroCapabilityContext =>
      'Pots permetre que utilitzi la pàgina actual com a context o triar diverses pàgines de referència.';

  @override
  String get quillIntroCapabilityExamples =>
      'La millor part: parla-li amb naturalitat i el Quill decidirà si ha de respondre o editar.';

  @override
  String get quillIntroExamplesTitle => 'Exemples ràpids';

  @override
  String get quillIntroExampleOne => 'Resumeix aquesta pàgina en tres punts.';

  @override
  String get quillIntroExampleTwo =>
      'Canvia el títol i millora la introducció.';

  @override
  String get quillIntroExampleThree => 'Com afegeixo una imatge o una taula?';

  @override
  String get quillIntroFootnote =>
      'Si la IA encara no està activada, pots fer-ho més tard. Aquesta introducció és perquè entenguis què pot fer el Quill quan l\'utilitzis.';

  @override
  String get createVault => 'Crea la caixa forta';

  @override
  String minCharactersError(int min) {
    return 'Mínim $min caràcters.';
  }

  @override
  String get passwordMismatchError => 'Les contrasenyes no coincideixen.';

  @override
  String get passwordMustBeStrongError =>
      'La contrasenya ha de ser forta per continuar.';

  @override
  String get passwordStrengthLabel => 'Seguretat';

  @override
  String get passwordStrengthVeryWeak => 'Molt feble';

  @override
  String get passwordStrengthWeak => 'Feble';

  @override
  String get passwordStrengthFair => 'Acceptable';

  @override
  String get passwordStrengthStrong => 'Forta';

  @override
  String get showPassword => 'Mostra la contrasenya';

  @override
  String get hidePassword => 'Amaga la contrasenya';

  @override
  String get chooseZipError => 'Tria un fitxer .zip.';

  @override
  String get enterBackupPasswordError =>
      'Introdueix la contrasenya de la còpia de seguretat.';

  @override
  String importFailedError(Object error) {
    return 'No s\'ha pogut importar: $error';
  }

  @override
  String createVaultFailedError(Object error) {
    return 'No s\'ha pogut crear la caixa forta: $error';
  }

  @override
  String get encryptedVault => 'Caixa forta xifrada';

  @override
  String get unlock => 'Desbloqueja';

  @override
  String get quickUnlock => 'Hello / biometria';

  @override
  String get passkey => 'Clau de pas';

  @override
  String get unlockFailed => 'Contrasenya incorrecta o caixa forta danyada.';

  @override
  String get appearance => 'Aparença';

  @override
  String get security => 'Seguretat';

  @override
  String get vaultBackup => 'Còpia de la caixa forta';

  @override
  String get data => 'Dades';

  @override
  String get systemTheme => 'Sistema';

  @override
  String get lightTheme => 'Clar';

  @override
  String get darkTheme => 'Fosc';

  @override
  String get language => 'Idioma';

  @override
  String get useSystemLanguage => 'Utilitza l\'idioma del sistema';

  @override
  String get spanishLanguage => 'Castellà';

  @override
  String get englishLanguage => 'Anglès';

  @override
  String get brazilianPortugueseLanguage => 'Portugués (Brasil)';

  @override
  String get catalanLanguage => 'Català / Valencià';

  @override
  String get galicianLanguage => 'Gallec';

  @override
  String get basqueLanguage => 'Basc';

  @override
  String get active => 'Actiu';

  @override
  String get inactive => 'Inactiu';

  @override
  String get remove => 'Elimina';

  @override
  String get enable => 'Activa';

  @override
  String get register => 'Registra';

  @override
  String get revoke => 'Revoca';

  @override
  String get save => 'Desa';

  @override
  String get delete => 'Suprimeix';

  @override
  String get rename => 'Reanomena';

  @override
  String get change => 'Canvia';

  @override
  String get importAction => 'Importa';

  @override
  String get masterPassword => 'Contrasenya mestra';

  @override
  String get confirmIdentity => 'Confirma la identitat';

  @override
  String get quickUnlockTitle => 'Desbloqueig ràpid (Hello / biometria)';

  @override
  String get passkeyThisDevice => 'WebAuthn en aquest dispositiu';

  @override
  String get lockOnMinimize => 'Bloqueja en minimitzar';

  @override
  String get changeMasterPassword => 'Canvia la contrasenya mestra';

  @override
  String get requiresCurrentPassword => 'Requereix la contrasenya actual';

  @override
  String get lockAutoByInactivity => 'Bloqueig automàtic per inactivitat';

  @override
  String minutesShort(int minutes) {
    return '$minutes min';
  }

  @override
  String get settingsAppearanceHint =>
      'El color principal segueix el color de realç de Windows quan està disponible.';

  @override
  String get backupFilePasswordLabel => 'Contrasenya del fitxer de còpia';

  @override
  String get backupFilePasswordHelper =>
      'Utilitza la contrasenya mestra que es va fer servir per crear aquesta còpia, no la d\'un altre dispositiu.';

  @override
  String get backupPasswordDialogTitle => 'Contrasenya de la còpia';

  @override
  String get currentPasswordLabel => 'Contrasenya actual';

  @override
  String get newPasswordLabel => 'Nova contrasenya';

  @override
  String get confirmNewPasswordLabel => 'Confirma la nova contrasenya';

  @override
  String passwordStrengthWithValue(Object value) {
    return 'Seguretat: $value';
  }

  @override
  String get fillAllFieldsError => 'Emplena tots els camps.';

  @override
  String get newPasswordsMismatchError =>
      'Les noves contrasenyes no coincideixen.';

  @override
  String get newPasswordMustBeStrongError =>
      'La nova contrasenya ha de ser forta.';

  @override
  String get newPasswordMustDifferError =>
      'La nova contrasenya ha de ser diferent.';

  @override
  String get incorrectPasswordError => 'Contrasenya incorrecta.';

  @override
  String get useHelloBiometrics => 'Utilitza Hello / biometria';

  @override
  String get usePasskey => 'Utilitza la clau de pas';

  @override
  String get quickUnlockEnabledSnack => 'Desbloqueig ràpid activat';

  @override
  String get quickUnlockDisabledSnack => 'Desbloqueig ràpid desactivat';

  @override
  String get quickUnlockEnableFailed =>
      'No s\'ha pogut activar el desbloqueig ràpid.';

  @override
  String get passkeyRevokeConfirmTitle => 'Vols eliminar la clau de pas?';

  @override
  String get passkeyRevokeConfirmBody =>
      'Necessitaràs la teva contrasenya mestra per desbloquejar fins que registris una nova clau de pas en aquest dispositiu.';

  @override
  String get passkeyRegisteredSnack => 'Clau de pas registrada';

  @override
  String get passkeyRevokedSnack => 'Clau de pas revocada';

  @override
  String get masterPasswordUpdatedSnack => 'Contrasenya mestra actualitzada';

  @override
  String get backupSavedSuccessSnack =>
      'Còpia de seguretat desada correctament.';

  @override
  String exportFailedError(Object error) {
    return 'No s\'ha pogut exportar: $error';
  }

  @override
  String importFailedGenericError(Object error) {
    return 'No s\'ha pogut importar: $error';
  }

  @override
  String wipeFailedError(Object error) {
    return 'No s\'ha pogut suprimir la caixa forta: $error';
  }

  @override
  String get filePathReadError => 'No s\'ha pogut llegir la ruta del fitxer.';

  @override
  String get importedVaultSuccessSnack =>
      'Caixa forta importada. Apareixerà al selector lateral; la caixa actual no ha canviat.';

  @override
  String get exportVaultDialogTitle => 'Exporta còpia de la caixa forta';

  @override
  String get exportVaultDialogBody =>
      'Per crear un fitxer de còpia de seguretat, confirma la teva identitat amb la caixa forta actualment desbloquejada.';

  @override
  String get verifyAndExport => 'Verifica i exporta';

  @override
  String get saveVaultBackupDialogTitle => 'Desa la còpia de la caixa forta';

  @override
  String get importVaultDialogTitle => 'Importa una còpia de la caixa forta';

  @override
  String get importVaultDialogBody =>
      'S\'afegirà una nova caixa forta des del fitxer. La caixa actual no serà suprimida ni modificada.\n\nLa contrasenya del fitxer serà la contrasenya de la caixa importada.\n\nLes claus de pas i el desbloqueig ràpid no s\'inclouen a les còpies; podràs configurar-los més tard per a aquesta caixa.\n\nVols continuar?';

  @override
  String get verifyAndContinue => 'Verifica i continua';

  @override
  String get verifyAndDelete => 'Verifica amb contrasenya i suprimeix';

  @override
  String get importIdentityBody =>
      'Demostra que ets tu amb la caixa forta actualment desbloquejada abans d\'importar.';

  @override
  String get wipeVaultDialogTitle => 'Suprimeix la caixa forta';

  @override
  String get wipeVaultDialogBody =>
      'Es suprimiran totes les pàgines i la contrasenya mestra ja no serà vàlida. Aquesta acció no es pot desfer.\n\nEstàs segur que vols continuar?';

  @override
  String get wipeIdentityBody =>
      'Per suprimir la caixa forta, demostra la teva identitat.';

  @override
  String get exportZipTitle => 'Exporta còpia (.zip)';

  @override
  String get exportZipSubtitle =>
      'Contrasenya, Hello o clau de pas de la caixa actual';

  @override
  String get importZipTitle => 'Importa còpia (.zip)';

  @override
  String get importZipSubtitle =>
      'Afegeix una nova caixa · identitat actual + contrasenya del fitxer';

  @override
  String get backupInfoBody =>
      'El fitxer conté les mateixes dades xifrades que al disc (vault.keys i vault.bin), sense exposar el contingut en text pla. Les imatges adjuntes s\'inclouen tal qual.\n\nLes claus de pas i el desbloqueig ràpid no són transferibles entre dispositius; els pots tornar a configurar per a cada caixa importada.\n\nImportar afegeix una nova caixa forta; no substitueix la que està oberta actualment.';

  @override
  String get wipeCardTitle => 'Suprimeix la caixa forta i comença de nou';

  @override
  String get wipeCardSubtitle => 'Requereix contrasenya, Hello o clau de pas.';

  @override
  String get switchVaultTooltip => 'Canvia de caixa forta';

  @override
  String get switchVaultTitle => 'Canvia de caixa forta';

  @override
  String get switchVaultBody =>
      'Es tancarà la sessió d\'aquesta caixa forta i hauràs de desbloquejar l\'altra amb la seva contrasenya, Hello o clau de pas.';

  @override
  String get renameVaultTitle => 'Reanomena la caixa forta';

  @override
  String get nameLabel => 'Nom';

  @override
  String get deleteOtherVaultTitle => 'Suprimeix una altra caixa forta';

  @override
  String get deleteVaultConfirmTitle => 'Vols suprimir la caixa forta?';

  @override
  String deleteVaultConfirmBody(Object name) {
    return 'La caixa forta «$name» es suprimirà completament. Això no es pot desfer.';
  }

  @override
  String get vaultDeletedSnack => 'Caixa forta suprimida.';

  @override
  String get noOtherVaultsSnack =>
      'No hi ha altres caixes fortes per suprimir.';

  @override
  String get addVault => 'Afegeix una caixa forta';

  @override
  String get renameActiveVault => 'Reanomena la caixa activa';

  @override
  String get deleteOtherVault => 'Suprimeix una altra caixa forta…';

  @override
  String get activeVaultLabel => 'Caixa forta activa';

  @override
  String get sidebarVaultsLoading => 'Carregant caixes fortes…';

  @override
  String get sidebarVaultsEmpty => 'No hi ha caixes fortes disponibles';

  @override
  String get forceSyncTooltip => 'Força la sincronització';

  @override
  String get searchDialogFooterHint =>
      'Retorn obre el resultat destacat · Ctrl+↑ / Ctrl+↓ per navegar · Esc tanca';

  @override
  String get searchFilterTasks => 'Tasques';

  @override
  String get searchRecentQueries => 'Cerques recents';

  @override
  String get searchShortcutsHelpTooltip => 'Dreceres de teclat';

  @override
  String get searchShortcutsHelpTitle => 'Cerca global';

  @override
  String get searchShortcutsHelpBody =>
      'Retorn: obre el resultat destacat\nCtrl+↑ o Ctrl+↓: anterior / següent resultat\nEsc: tanca';

  @override
  String get renamePageTitle => 'Reanomena la pàgina';

  @override
  String get titleLabel => 'Títol';

  @override
  String get rootPage => 'Arrel';

  @override
  String movePageTitle(Object title) {
    return 'Mou “$title”';
  }

  @override
  String get subpage => 'Subpàgina';

  @override
  String get move => 'Mou';

  @override
  String get pages => 'Pàgines';

  @override
  String get pageOutlineTitle => 'Esquema';

  @override
  String get pageOutlineEmpty =>
      'Afegeix encapçalaments (H1–H3) per crear l\'esquema.';

  @override
  String get showPageOutline => 'Mostra l\'esquema';

  @override
  String get hidePageOutline => 'Amaga l\'esquema';

  @override
  String get tocBlockTitle => 'Taula de continguts';

  @override
  String get showSidebar => 'Mostra la barra lateral';

  @override
  String get hideSidebar => 'Amaga la barra lateral';

  @override
  String get resizeSidebarHandle => 'Redimensiona la barra lateral';

  @override
  String get resizeSidebarHandleHint =>
      'Arrossega horitzontalment per canviar l\'amplada de la barra lateral';

  @override
  String get resizeAiPanelHeightHandle =>
      'Redimensiona l\'alçada de l\'assistent';

  @override
  String get resizeAiPanelHeightHandleHint =>
      'Arrossega verticalment per canviar l\'alçada del panell de l\'assistent';

  @override
  String get sidebarAutoRevealTitle =>
      'Mostra la barra lateral en apropar el punter';

  @override
  String get sidebarAutoRevealSubtitle =>
      'Quan la barra lateral estigui amagada, mou el punter al marge esquerre per mostrar-la temporalment.';

  @override
  String get newRootPageTooltip => 'Nova pàgina (arrel)';

  @override
  String get blockOptions => 'Opcions del bloc';

  @override
  String get meetingNoteTitle => 'Nota de reunió';

  @override
  String get meetingNoteDesktopOnly => 'Només disponible a l\'escriptori.';

  @override
  String get meetingNoteStartRecording => 'Inicia la gravació';

  @override
  String get meetingNotePreparing => 'Preparant…';

  @override
  String get meetingNoteTranscriptionLanguage => 'Idioma de la transcripció';

  @override
  String get meetingNoteLangAuto => 'Automàtic';

  @override
  String get meetingNoteLangEs => 'Castellà';

  @override
  String get meetingNoteLangEn => 'Anglès';

  @override
  String get meetingNoteLangPt => 'Portuguès';

  @override
  String get meetingNoteLangFr => 'Francès';

  @override
  String get meetingNoteLangIt => 'Italià';

  @override
  String get meetingNoteLangDe => 'Alemany';

  @override
  String get meetingNoteDevicesInSettings =>
      'Els dispositius d\'entrada/sortida es configuren a Configuració > Escriptori.';

  @override
  String meetingNoteModelInSettings(Object model) {
    return 'Model de transcripció: $model (a Configuració > Escriptori).';
  }

  @override
  String get meetingNoteDescription =>
      'Grava el micròfon i l\'àudio del sistema. La transcripció es genera localment.';

  @override
  String meetingNoteWhisperInitError(Object error) {
    return 'No s\'ha pogut inicialitzar Whisper: $error';
  }

  @override
  String get meetingNoteAudioAccessError =>
      'No s\'ha pogut accedir al micròfon/dispositius.';

  @override
  String get meetingNoteMicrophoneAccessError =>
      'No s\'ha pogut accedir al micròfon.';

  @override
  String get meetingNoteChunkTranscriptionError =>
      'No s\'ha pogut transcriure aquest fragment d\'àudio.';

  @override
  String get meetingNoteProviderLocal => 'Local (Whisper)';

  @override
  String get meetingNoteProviderCloud => 'Quill Cloud';

  @override
  String get meetingNoteProviderCloudCost => '1 Ink per cada 5 min. gravats';

  @override
  String get meetingNoteCloudFallbackNotice =>
      'Núvol no disponible. S\'utilitzarà Whisper local.';

  @override
  String get meetingNoteCloudInkExhaustedNotice =>
      'Ink insuficient. Canviant a Whisper local.';

  @override
  String meetingNoteCloudRecordingBadge(Object language) {
    return 'Quill Cloud | Idioma: $language';
  }

  @override
  String get meetingNoteCloudProcessing => 'Processant amb Quill Cloud…';

  @override
  String get meetingNoteCloudProcessingSubtitle =>
      'Detectant parlants i millorant la qualitat. Espera, si us plau.';

  @override
  String meetingNoteCloudProgress(int done, int total) {
    return 'Fragments processats: $done/$total';
  }

  @override
  String meetingNoteCloudEta(Object remaining) {
    return 'Temps restant estimat: $remaining';
  }

  @override
  String get meetingNoteCloudEtaCalculating => 'Calculant el temps restant...';

  @override
  String get meetingNoteCloudRequiresAccount =>
      'Requereix un compte de Folio Cloud amb Ink.';

  @override
  String get meetingNoteCloudRequiresAiEnabled =>
      'Activa la IA a Configuració per usar la transcripció al núvol (Quill Cloud).';

  @override
  String meetingNoteHardwareSummary(int cpus, Object ramLabel) {
    return '$cpus nuclis · $ramLabel';
  }

  @override
  String get meetingNoteHardwareRamUnknown => 'RAM desconeguda';

  @override
  String meetingNoteHardwareRecommended(Object modelLabel) {
    return 'Model recomanat per a aquest equip: $modelLabel';
  }

  @override
  String get meetingNoteLocalTranscriptionNotViable =>
      'Aquest equip no compleix els requisits mínims per a la transcripció local. Només es guardarà l\'àudio, tret que activis «Forçar transcripció local» a Configuració o facis servir Quill Cloud amb IA activada.';

  @override
  String get meetingNoteGenerateTranscription => 'Generar transcripció';

  @override
  String get meetingNoteGenerateTranscriptionSubtitle =>
      'Desactiva-ho per guardar només l\'àudio en aquesta nota.';

  @override
  String get meetingNoteSettingsAutoWhisperModel =>
      'Trieu el model automàticament segons el maquinari';

  @override
  String get meetingNoteSettingsForceLocalTranscription =>
      'Forçar transcripció local (pot ser lenta o inestable)';

  @override
  String get meetingNoteSettingsHardwareIntro =>
      'Rendiment detectat per a la transcripció local.';

  @override
  String get meetingNoteRecordingAudioOnlyBadge => 'Només àudio';

  @override
  String get meetingNotePerNoteTranscriptionOffHint =>
      'La transcripció està desactivada per a aquesta nota.';

  @override
  String get meetingNoteTranscriptionProvider => 'Motor de transcripció';

  @override
  String meetingNoteRecordingTime(Object mm, Object ss) {
    return 'Gravant $mm:$ss';
  }

  @override
  String meetingNoteRecordingBadge(Object language, Object model) {
    return 'Idioma: $language | Model: $model';
  }

  @override
  String get meetingNoteSystemAudioCaptured => 'Àudio del sistema capturat';

  @override
  String get meetingNoteStop => 'Atura';

  @override
  String get meetingNoteWaitingTranscription => 'Esperant la transcripció…';

  @override
  String get meetingNoteTranscribing => 'Transcrivint…';

  @override
  String get meetingNoteTranscriptionTitle => 'Transcripció';

  @override
  String get meetingNoteNoTranscription =>
      'No hi ha cap transcripció disponible.';

  @override
  String get meetingNoteNewRecording => 'Nova gravació';

  @override
  String get meetingNoteSettingsSection => 'Nota de reunió (àudio)';

  @override
  String get meetingNoteSettingsDescription =>
      'Aquests dispositius s\'utilitzen per defecte quan es grava una nota de reunió.';

  @override
  String get meetingNoteSettingsMicrophone => 'Micròfon';

  @override
  String get meetingNoteSettingsRefreshDevices => 'Actualitza la llista';

  @override
  String get meetingNoteSettingsSystemDefault => 'Per defecte del sistema';

  @override
  String get meetingNoteSettingsSystemOutput =>
      'Sortida del sistema (loopback)';

  @override
  String get meetingNoteSettingsModel => 'Model de transcripció';

  @override
  String get meetingNoteDiarizationHint =>
      'Processament 100% local al teu dispositiu.';

  @override
  String get meetingNoteModelTiny => 'Ràpid';

  @override
  String get meetingNoteModelBase => 'Equilibrat';

  @override
  String get meetingNoteModelSmall => 'Precís';

  @override
  String get meetingNoteModelMedium => 'Avançat';

  @override
  String get meetingNoteModelTurbo => 'Màxima qualitat';

  @override
  String get meetingNoteCopyTranscript => 'Copia la transcripció';

  @override
  String get meetingNoteSendToAi => 'Envia a la IA…';

  @override
  String get meetingNoteAiPayloadLabel => 'Què vols enviar a la IA?';

  @override
  String get meetingNoteAiPayloadTranscript => 'Només la transcripció';

  @override
  String get meetingNoteAiPayloadAudio => 'Només l\'àudio';

  @override
  String get meetingNoteAiPayloadBoth => 'Transcripció + àudio';

  @override
  String get meetingNoteAiInstructionHint => 'p. ex. resumeix els punts clau';

  @override
  String get meetingNoteAiNoAudio =>
      'No hi ha àudio disponible per a aquest mode';

  @override
  String get meetingNoteAiInstruction => 'Instrucció per a la IA';

  @override
  String get dragToReorder => 'Arrossega per reordenar';

  @override
  String get addBlock => 'Afegeix un bloc';

  @override
  String get blockMentionPageSubtitle => 'Menciona una pàgina';

  @override
  String get blockTypesSheetTitle => 'Tipos de bloc';

  @override
  String get blockTypesSheetSubtitle => 'Tria l\'aparença d\'aquest bloc';

  @override
  String get blockTypeFilterEmpty => 'No hi ha resultats per a la cerca';

  @override
  String get fileNotFound => 'Fitxer no trobat';

  @override
  String get couldNotLoadImage => 'No s\'ha pogut carregar la imatge';

  @override
  String get noImageHint =>
      'Sense imatge · utilitza el menú ⋮ o el botó de sota';

  @override
  String get chooseImage => 'Tria una imatge';

  @override
  String get replaceFile => 'Substitueix el fitxer';

  @override
  String get removeFile => 'Elimina el fitxer';

  @override
  String get replaceVideo => 'Substitueix el vídeo';

  @override
  String get removeVideo => 'Elimina el vídeo';

  @override
  String get openExternal => 'Obre externament';

  @override
  String get openVideoExternal => 'Obre el vídeo externament';

  @override
  String get play => 'Reprodueix';

  @override
  String get pause => 'Pausa';

  @override
  String get mute => 'Silencia';

  @override
  String get unmute => 'Activa el so';

  @override
  String get fileResolveError => 'Error en resoldre el fitxer';

  @override
  String get videoResolveError => 'Error en resoldre el vídeo';

  @override
  String get fileMissing => 'Fitxer no trobat';

  @override
  String get videoMissing => 'Vídeo no trobat';

  @override
  String get chooseFile => 'Tria un fitxer';

  @override
  String get chooseVideo => 'Tria un vídeo';

  @override
  String get noEmbeddedPreview =>
      'Sense vista prèvia integrada per a aquest tipus';

  @override
  String get couldNotReadFile => 'No s\'ha pogut llegir el fitxer';

  @override
  String get couldNotLoadVideo => 'No s\'ha pogut carregar el vídeo';

  @override
  String get couldNotPreviewPdf => 'No s\'ha pogut previsualitzar el PDF';

  @override
  String get openInYoutubeBrowser => 'Obre al navegador';

  @override
  String get pasteUrlTitle => 'Enganxa l\'enllaç com a';

  @override
  String get pasteAsUrl => 'URL';

  @override
  String get pasteAsEmbed => 'Incrustat';

  @override
  String get pasteAsBookmark => 'Marcador';

  @override
  String get pasteAsMention => 'Menció';

  @override
  String get pasteAsUrlSubtitle => 'Insereix un enllaç markdown al text';

  @override
  String get pasteAsEmbedSubtitle =>
      'Bloc de vídeo amb vista prèvia (YouTube) o marcador';

  @override
  String get pasteAsBookmarkSubtitle => 'Targeta amb títol i enllaç';

  @override
  String get pasteAsMentionSubtitle =>
      'Enllaç a una pàgina d\'aquesta caixa forta';

  @override
  String get tableAddRow => 'Fila';

  @override
  String get tableRemoveRow => 'Suprimeix la fila';

  @override
  String get tableAddColumn => 'Columna';

  @override
  String get tableRemoveColumn => 'Suprimeix la col.';

  @override
  String get tablePasteFromClipboard => 'Enganxa la taula';

  @override
  String get pickPageForMention => 'Tria una pàgina';

  @override
  String get bookmarkTitleHint => 'Títol';

  @override
  String get bookmarkOpenLink => 'Obre l\'enllaç';

  @override
  String get bookmarkSetUrl => 'Defineix la URL…';

  @override
  String get bookmarkBlockHint =>
      'Enganxa un enllaç o utilitza el menú del bloc';

  @override
  String get bookmarkRemove => 'Elimina el marcador';

  @override
  String get embedUnavailable =>
      'La vista web integrada no està disponible en aquesta plataforma. Obre l\'enllaç al navegador.';

  @override
  String get embedOpenBrowser => 'Obre al navegador';

  @override
  String get embedSetUrl => 'Defineix la URL de l\'incrustat…';

  @override
  String get embedRemove => 'Elimina l\'incrustat';

  @override
  String get embedEmptyHint =>
      'Enganxa un enllaç o defineix la URL des del menú del bloc';

  @override
  String get blockSizeSmaller => 'Més petit';

  @override
  String get blockSizeLarger => 'Més gran';

  @override
  String get blockSizeHalf => '50%';

  @override
  String get blockSizeThreeQuarter => '75%';

  @override
  String get blockSizeFull => '100%';

  @override
  String get pasteAsEmbedSubtitleWeb =>
      'Mostra la pàgina dins del bloc (si és compatible)';

  @override
  String get pasteAsMentionSubtitleRich =>
      'Enllaç amb el títol de la pàgina (p. ex. YouTube)';

  @override
  String get formatToolbar => 'Barra de format';

  @override
  String get formatToolbarScrollPrevious => 'Eines anteriors';

  @override
  String get formatToolbarScrollNext => 'Més eines';

  @override
  String get linkTitle => 'Enllaç';

  @override
  String get visibleTextLabel => 'Text visible';

  @override
  String get urlLabel => 'URL';

  @override
  String get urlHint => 'https://…';

  @override
  String get insert => 'Insereix';

  @override
  String get defaultLinkText => 'text';

  @override
  String get boldTip => 'Negreta (**)';

  @override
  String get italicTip => 'Cursiva (_)';

  @override
  String get underlineTip => 'Subratllat (<u>)';

  @override
  String get inlineCodeTip => 'Codi en línia (`)';

  @override
  String get strikeTip => 'Ratllat (~~)';

  @override
  String get linkTip => 'Enllaç';

  @override
  String get pageHistoryTitle => 'Historial de versions';

  @override
  String get restoreVersionTitle => 'Restaura la versió';

  @override
  String get restoreVersionBody =>
      'El títol i el contingut de la pàgina se substituiran per aquesta versió. L\'estat actual es desarà primer a l\'historial.';

  @override
  String get restore => 'Restaura';

  @override
  String get deleteVersionTitle => 'Suprimeix la versió';

  @override
  String get deleteVersionBody =>
      'Aquesta entrada s\'eliminarà de l\'historial. El text actual de la pàgina no canviarà.';

  @override
  String get noVersionsYet => 'Encara no hi ha versions';

  @override
  String get historyAppearsHint =>
      'Quan deixis d\'escriure uns segons, l\'historial de canvis apareixerà aquí.';

  @override
  String get versionControl => 'Control de versions';

  @override
  String get historyHeaderBody =>
      'La caixa forta es desa ràpidament; l\'historial afegeix una entrada quan deixes d\'editar i el contingut ha canviat.';

  @override
  String versionsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'versions',
      one: 'versió',
    );
    return '$count $_temp0';
  }

  @override
  String get untitledFallback => 'Sense títol';

  @override
  String get comparedWithPrevious => 'Comparat amb la versió anterior';

  @override
  String get changesFromEmptyStart => 'Canvis des de l\'inici buit';

  @override
  String get contentLabel => 'Contingut';

  @override
  String get titleLabelSimple => 'Títol';

  @override
  String get emptyValue => '(buit)';

  @override
  String get noTextChanges => 'Sense canvis de text.';

  @override
  String get aiAssistantTitle => 'Quill';

  @override
  String get aiNoPageSelected => 'Cap pàgina seleccionada';

  @override
  String get aiChatContextDisabledSubtitle =>
      'El text de la pàgina no s\'envia al model';

  @override
  String aiChatContextUsesCurrentPage(Object title) {
    return 'Context: pàgina actual ($title)';
  }

  @override
  String get aiChatContextOnePageFallback => 'Context: 1 pàgina';

  @override
  String aiChatContextNPages(int count) {
    return '$count pàgines al context del xat';
  }

  @override
  String get aiChatPageContextTooltip =>
      'Inclou el text de la pàgina al context del model';

  @override
  String get aiChatChooseContextPagesTooltip =>
      'Tria quines pàgines afegeixen text al context';

  @override
  String get aiChatContextPagesDialogTitle => 'Pàgines al context del xat';

  @override
  String get aiChatContextPagesClear => 'Neteja la llista';

  @override
  String get aiChatContextPagesApply => 'Aplica';

  @override
  String get aiTypingSemantics => 'El Quill està escrivint';

  @override
  String get aiRenameChatTooltip => 'Reanomena el xat';

  @override
  String get aiRenameChatDialogTitle => 'Títol del xat';

  @override
  String get aiRenameChatLabel => 'Títol que es mostra a la pestanya';

  @override
  String get quillWorkspaceTourTitle => 'El Quill pot ajudar-te des d\'aquí';

  @override
  String get quillWorkspaceTourBodyReady =>
      'El teu xat amb el Quill està a punt per a preguntes, edicions de pàgina i fluxos de treball amb context.';

  @override
  String get quillWorkspaceTourBodyUnavailable =>
      'Encara que no estigui actiu ara mateix, el Quill forma part d\'aquest espai i podràs activar-lo més tard a Configuració.';

  @override
  String get quillWorkspaceTourPointsTitle => 'Què val la pena saber';

  @override
  String get quillWorkspaceTourPointOne =>
      'Funciona com a assistent conversacional i com a editor de títols i blocs.';

  @override
  String get quillWorkspaceTourPointTwo =>
      'Pot utilitzar la pàgina actual o diverses pàgines com a context.';

  @override
  String get quillWorkspaceTourPointThree =>
      'Si toques un exemple de sota, s\'omplirà el xat quan el Quill estigui disponible.';

  @override
  String get quillWorkspaceTourExamplesTitle => 'Prova ordres com';

  @override
  String get quillWorkspaceTourExampleOne =>
      'Explica com organitzar aquesta pàgina.';

  @override
  String get quillWorkspaceTourExampleTwo =>
      'Utilitza aquestes dues pàgines per fer un resum compartit.';

  @override
  String get quillWorkspaceTourExampleThree =>
      'Reescriu aquest bloc amb un to més clar.';

  @override
  String get quillTourDismiss => 'Entesos';

  @override
  String get aiExpand => 'Expandeix';

  @override
  String get aiCollapse => 'Replega';

  @override
  String get aiDeleteCurrentChat => 'Suprimeix el xat actual';

  @override
  String get aiNewChat => 'Nou';

  @override
  String get aiAttach => 'Adjunta';

  @override
  String get aiChatEmptyHint =>
      'Inicia una conversa.\nEl Quill decidirà automàticament què fer amb el teu missatge.\nTambé pots preguntar com utilitzar el Folio (dreceres, configuració, pàgines o aquest xat).';

  @override
  String get aiChatEmptyFocusComposer => 'Escriu un missatge';

  @override
  String get aiInputHint =>
      'Escriu el missatge. El Quill actuarà com un agent.';

  @override
  String get aiInputHintCopilot => 'Escriu el missatge...';

  @override
  String get aiContextComposerHint => 'Sense context afegit';

  @override
  String get aiContextComposerHelper => 'Utilitza @ per afegir context';

  @override
  String aiContextCurrentPageChip(Object title) {
    return 'Pàgina actual: $title';
  }

  @override
  String get aiContextCurrentPageFallback => 'Pàgina actual';

  @override
  String get aiContextAddFile => 'Adjunta un fitxer';

  @override
  String get aiContextAddPage => 'Adjunta una pàgina';

  @override
  String get aiShowPanel => 'Mostra el panell d\'IA';

  @override
  String get aiHidePanel => 'Amaga el panell d\'IA';

  @override
  String get aiPanelResizeHandle => 'Redimensiona el panell d\'IA';

  @override
  String get aiPanelResizeHandleHint =>
      'Arrossega horitzontalment per canviar l\'amplada del panell de l\'assistent';

  @override
  String get importMarkdownPage => 'Importa Markdown';

  @override
  String get exportMarkdownPage => 'Exporta Markdown';

  @override
  String get exportPage => 'Exporta…';

  @override
  String get workspaceUndoTooltip => 'Desfà (Ctrl+Z)';

  @override
  String get workspaceRedoTooltip => 'Refà (Ctrl+Y)';

  @override
  String get workspaceMoreActionsTooltip => 'Més accions';

  @override
  String get closeCurrentPage => 'Tanca la pàgina actual';

  @override
  String aiErrorWithDetails(Object error) {
    return 'Error d\'IA: $error';
  }

  @override
  String get aiServiceUnreachable =>
      'No s\'ha pogut contactar amb el servei d\'IA a l\'adreça configurada. Inicia Ollama o LM Studio i comprova la URL.';

  @override
  String get aiLaunchProviderWithApp =>
      'Obre l\'aplicació d\'IA quan s\'iniciï el Folio';

  @override
  String get aiLaunchProviderWithAppHint =>
      'Intenta iniciar Ollama o LM Studio a Windows quan l\'adreça és localhost. LM Studio pot necessitar que el seu servidor s\'iniciï manualment.';

  @override
  String get aiContextWindowTokens => 'Finestra de context del model (tokens)';

  @override
  String get aiContextWindowTokensHint =>
      'S\'utilitza per a la barra de context al xat d\'IA. Ha de coincidir amb el teu model (p. ex. 8192, 131072).';

  @override
  String get aiContextUsageUnavailable =>
      'No s\'ha informat de l\'ús de tokens en l\'última resposta.';

  @override
  String aiContextUsageSummary(Object prompt, Object completion) {
    return 'Prompt $prompt · Sortida $completion';
  }

  @override
  String aiContextUsageTooltip(int window) {
    return 'Última petició vs la teva finestra de context configurada ($window tokens).';
  }

  @override
  String get aiChatKeyboardHint =>
      'Retorn per enviar · Ctrl+Retorn per a una nova línia';

  @override
  String aiChatInkRemaining(int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: 'Queden $total gotes d\'ink',
      one: 'Queda 1 gota d\'ink',
    );
    return '$_temp0';
  }

  @override
  String aiChatInkBreakdownTooltip(int monthly, int purchased) {
    return 'Mensual $monthly · Comprat $purchased';
  }

  @override
  String get aiAgentThought => 'Pensament del Quill';

  @override
  String get aiAlwaysShowThought => 'Mostra sempre el pensament de la IA';

  @override
  String get aiAlwaysShowThoughtHint =>
      'Si està desactivat, apareix replegat amb una fletxa a cada missatge.';

  @override
  String get aiBetaBadge => 'BETA';

  @override
  String get aiBetaEnableTitle => 'L\'IA està en fase BETA';

  @override
  String get aiBetaEnableBody =>
      'Aquesta funció està actualment en BETA i pot fallar o comportar-se de manera inesperada.\n\nVols activar-la igualment?';

  @override
  String get aiBetaEnableConfirm => 'Activa la BETA';

  @override
  String get ai => 'IA';

  @override
  String get aiEnableToggleTitle => 'Activa la IA';

  @override
  String get aiProviderLabel => 'Proveïdor';

  @override
  String get aiProviderNone => 'Cap';

  @override
  String get aiEndpoint => 'Endpoint (adreça)';

  @override
  String get aiModel => 'Model';

  @override
  String get aiTimeoutMs => 'Temps d\'espera (ms)';

  @override
  String get aiAllowRemoteEndpoint => 'Permet endpoints remots';

  @override
  String get aiAllowRemoteEndpointAllowed => 'Hosts remots permesos';

  @override
  String get aiAllowRemoteEndpointLocalhostOnly => 'Només localhost';

  @override
  String get aiAllowRemoteEndpointNotConfirmed =>
      'L\'accés a endpoints remots està activat però encara no s\'ha confirmat.';

  @override
  String get aiConnectToListModels => 'Connecta per llistar els models';

  @override
  String aiProviderAutoConfigured(Object provider) {
    return 'Proveïdor d\'IA detectat i configurat: $provider';
  }

  @override
  String get aiSetupAssistantTitle => 'Assistent de configuració de l\'IA';

  @override
  String get aiSetupAssistantSubtitle =>
      'Detecta i configura Ollama o LM Studio automàticament.';

  @override
  String get aiSetupWizardTitle => 'Assistent de configuració de l\'IA';

  @override
  String get aiSetupChooseProviderTitle => 'Tria el proveïdor d\'IA';

  @override
  String get aiSetupChooseProviderBody =>
      'Primer tria quin proveïdor vols utilitzar. Després et guiarem en la instal·lació i configuració.';

  @override
  String get aiSetupNoProviderTitle => 'No s\'ha detectat cap proveïdor actiu';

  @override
  String get aiSetupNoProviderBody =>
      'No hem pogut trobar Ollama o LM Studio en funcionament.\nSegueix els passos per instal·lar o iniciar-ne un i prem Torna-ho a provar.';

  @override
  String get aiSetupOllamaTitle => 'Pas 1: Instal·la Ollama';

  @override
  String get aiSetupOllamaBody =>
      'Instal·la Ollama, executa el servei local i verifica que respon a http://127.0.0.1:11434.';

  @override
  String get aiSetupLmStudioTitle => 'Pas 2: Instal·la LM Studio';

  @override
  String get aiSetupLmStudioBody =>
      'Instal·la LM Studio, inicia el seu servidor local i verifica que respon a http://127.0.0.1:1234.';

  @override
  String get aiSetupOpenSettingsHint =>
      'Quan un proveïdor estigui operatiu, prem Torna-ho a provar per configurar-lo automàticament.';

  @override
  String get aiCompareCloudVsLocalTitle => 'Núvol vs local';

  @override
  String get aiCompareCloudTitle => 'Folio Cloud';

  @override
  String get aiCompareLocalTitle => 'Local (Ollama / LM Studio)';

  @override
  String get aiCompareCloudBulletNoSetup =>
      'Sense configuració local: funciona en iniciar sessió.';

  @override
  String get aiCompareCloudBulletNeedsSub =>
      'Subscripció a Folio Cloud amb IA al núvol o ink comprat.';

  @override
  String get aiCompareCloudBulletInk =>
      'Utilitza ink per a l\'IA al núvol (paquets + recàrrega mensual).';

  @override
  String get aiProviderFolioCloudBlockedSnack =>
      'Necessites un pla actiu de Folio Cloud amb IA al núvol o ink comprat — consulta Configuració → Folio Cloud.';

  @override
  String get aiCompareLocalBulletPrivacy =>
      'Privadesa local (a la teva màquina).';

  @override
  String get aiCompareLocalBulletNoInk => 'Sense ink: no depèn d\'un saldo.';

  @override
  String get aiCompareLocalBulletSetup =>
      'Requereix instal·lar i executar un proveïdor a localhost.';

  @override
  String get quillGlobalScopeNoticeTitle =>
      'El Quill funciona en totes les caixes fortes';

  @override
  String get quillGlobalScopeNoticeBody =>
      'El Quill és una configuració a nivell d\'aplicació. Si l\'actives ara, estarà disponible per a qualsevol caixa forta d\'aquesta instal·lació.';

  @override
  String get quillGlobalScopeNoticeConfirm => 'Ho entenc';

  @override
  String get searchByNameOrShortcut => 'Cerca per nom o drecera…';

  @override
  String get search => 'Cerca';

  @override
  String get open => 'Obre';

  @override
  String get exit => 'Surt';

  @override
  String get trayMenuCloseApplication => 'Tanca l\'aplicació';

  @override
  String get keyboardShortcutsSection => 'Teclat (a l\'app)';

  @override
  String get tasksCaptureSettingsSection => 'Tasques (captura ràpida)';

  @override
  String get taskInboxPageTitle => 'Safata de tasques';

  @override
  String get taskInboxPageSubtitle =>
      'Pàgina on es guarden les tasques afegides amb captura ràpida.';

  @override
  String get taskInboxNone => 'Sense definir (es crea en desar la primera)';

  @override
  String get taskInboxDefaultTitle => 'Safata de tasques';

  @override
  String get taskAliasManageTitle => 'Àlies de destinació';

  @override
  String get taskAliasManageSubtitle =>
      'Usa `#etiqueta` o `@etiqueta` al final de la captura. Defineix la clau sense símbol (ex. feina) i la pàgina destí.';

  @override
  String get taskAliasAddButton => 'Afegir àlies';

  @override
  String get taskAliasTagLabel => 'Etiqueta';

  @override
  String get taskAliasTargetLabel => 'Pàgina';

  @override
  String get taskAliasDeleteTooltip => 'Treure';

  @override
  String get taskQuickAddTitle => 'Captura ràpida de tasca';

  @override
  String get taskQuickAddHint =>
      'Ex.: Comprar llet demà alta #feina. També: due:2026-04-20, p1, en progrés.';

  @override
  String get taskQuickAddConfirm => 'Afegir';

  @override
  String get taskQuickAddSuccess => 'Tasca afegida.';

  @override
  String get taskQuickAddAliasTargetMissing =>
      'La pàgina d\'aquest àlies ja no existeix.';

  @override
  String get taskHubTitle => 'Totes les tasques';

  @override
  String get taskHubClose => 'Tancar vista';

  @override
  String get taskHubDashboardHelpTitle => 'Idees tipus dashboard';

  @override
  String get taskHubDashboardHelpBody =>
      'Crea una pàgina amb el bloc columnes i enllaça pàgines de llistes per context, o usa un bloc base de dades amb dates i estats per un tauler. La captura ràpida i aquesta vista s\'inspiren en apps com Snippets (snippets.ch).';

  @override
  String get taskHubEmpty => 'No hi ha tasques en aquesta llibreta.';

  @override
  String get taskHubFilterAll => 'Totes';

  @override
  String get taskHubFilterActive => 'Pendents';

  @override
  String get taskHubFilterDone => 'Fetes';

  @override
  String get taskHubFilterDueToday => 'Vençen avui';

  @override
  String get taskHubFilterDueWeek => 'Aquesta setmana';

  @override
  String get taskHubFilterOverdue => 'Vençudes';

  @override
  String get taskHubOpen => 'Obrir';

  @override
  String get taskHubMarkDone => 'Fet';

  @override
  String get taskHubIncludeTodos => 'Incloure checklists';

  @override
  String get sidebarQuickAddTask => 'Tasca ràpida';

  @override
  String get sidebarTaskHub => 'Totes les tasques';

  @override
  String get shortcutTestAction => 'Prova';

  @override
  String get shortcutChangeAction => 'Canvia';

  @override
  String shortcutTestHint(Object combo) {
    return 'Amb el focus fora d\'un camp de text, “$combo” hauria de funcionar a l\'espai de treball.';
  }

  @override
  String get shortcutResetAllTitle => 'Restaurar dreceres per defecte';

  @override
  String get shortcutResetAllSubtitle =>
      'Restableix totes les dreceres de l\'aplicació als valors per defecte del Folio.';

  @override
  String get shortcutResetDoneSnack =>
      'S\'han restaurat les dreceres per defecte.';

  @override
  String get desktopSection => 'Escriptori';

  @override
  String get globalSearchHotkey => 'Drecera de cerca global';

  @override
  String get hotkeyCombination => 'Combinació de tecles';

  @override
  String get hotkeyAltSpace => 'Alt + Espai';

  @override
  String get hotkeyCtrlShiftSpace => 'Ctrl + Maj + Espai';

  @override
  String get hotkeyCtrlShiftK => 'Ctrl + Maj + K';

  @override
  String get minimizeToTray => 'Minimitza a la safata';

  @override
  String get closeToTray => 'Tanca a la safata';

  @override
  String get searchAllVaultHint => 'Cerca a tota la caixa forta...';

  @override
  String get typeToSearch => 'Escriu per cercar';

  @override
  String get noSearchResults => 'Sense resultats';

  @override
  String get searchFilterAll => 'Tot';

  @override
  String get searchFilterTitles => 'Títols';

  @override
  String get searchFilterContent => 'Contingut';

  @override
  String get searchSortRelevance => 'Rellevància';

  @override
  String get searchSortRecent => 'Recent';

  @override
  String get settingsSearchSections => 'Configuració de cerca';

  @override
  String get settingsSearchSectionsHint =>
      'Filtra categories a la barra lateral';

  @override
  String get scheduledVaultBackupTitle => 'Còpia xifrada programada';

  @override
  String get scheduledVaultBackupSubtitle =>
      'Mentre la caixa forta estigui desbloquejada, es farà una còpia de la caixa actual. El Folio desarà un ZIP a la carpeta de sota amb l\'interval triat.';

  @override
  String get scheduledVaultBackupChooseFolder =>
      'Carpeta de còpia de seguretat';

  @override
  String get scheduledVaultBackupIntervalLabel => 'Interval entre còpies';

  @override
  String scheduledVaultBackupEveryNMinutes(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n minuts',
      one: '1 minut',
    );
    return '$_temp0';
  }

  @override
  String scheduledVaultBackupEveryNHours(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n hores',
      one: '1 hora',
    );
    return '$_temp0';
  }

  @override
  String scheduledVaultBackupLastRun(Object time) {
    return 'Última còpia: $time';
  }

  @override
  String get scheduledVaultBackupSnackOk => 'S\'ha desat la còpia programada.';

  @override
  String scheduledVaultBackupSnackFail(Object error) {
    return 'Ha fallat la còpia programada: $error';
  }

  @override
  String vaultBackupOpenVaultHint(String name) {
    return 'Les còpies són per a la caixa oberta ara: “$name”.';
  }

  @override
  String vaultBackupDiskSizeApprox(String size) {
    return 'Mida aproximada al disc: $size';
  }

  @override
  String get vaultBackupDiskSizeLoading => 'S’està calculant la mida al disc…';

  @override
  String get vaultBackupRunNowTile => 'Executa la còpia programada ara';

  @override
  String get vaultBackupRunNowSubtitle =>
      'Executa la còpia de seguretat ara (al disc i/o al núvol) sense esperar a l\'interval.';

  @override
  String get vaultBackupRunNowNeedFolder =>
      'Tria una carpeta local o activa “Puja també a Folio Cloud” per a còpies només al núvol.';

  @override
  String get vaultIdentitySyncTitle => 'Sincronització';

  @override
  String get vaultIdentitySyncBody =>
      'Introdueix la contrasenya de la caixa (o Hello / clau de pas) per continuar.';

  @override
  String get vaultIdentityCloudBackupTitle => 'Còpies al núvol';

  @override
  String get vaultIdentityCloudBackupBody =>
      'Confirma la identitat de la caixa per llistar o descarregar les còpies xifrades.';

  @override
  String get aiRewriteDialogTitle => 'Reescriu amb l\'IA';

  @override
  String get aiPreviewTitle => 'Vista prèvia';

  @override
  String get aiInstructionHint => 'Exemple: fes-ho més clar i curt';

  @override
  String get aiApply => 'Aplica';

  @override
  String get aiGenerating => 'Generant…';

  @override
  String get aiSummarizeSelection => 'Resumeix amb l\'IA…';

  @override
  String get aiExtractTasksDates => 'Extreu tasques i dates…';

  @override
  String get aiPreviewReadOnlyHint =>
      'Pots editar el text de sota abans d\'aplicar-lo.';

  @override
  String get aiRewriteApplied => 'Bloc actualitzat.';

  @override
  String get aiUndoRewrite => 'Desfà';

  @override
  String get aiInsertBelow => 'Insereix a sota';

  @override
  String get unlockVaultTitle => 'Desbloqueja la caixa forta';

  @override
  String get miniUnlockFailed => 'No s\'ha pogut desbloquejar.';

  @override
  String get importNotionTitle => 'Importa des de Notion (.zip)';

  @override
  String get importNotionSubtitle => 'Exportació ZIP de Notion (Markdown/HTML)';

  @override
  String get importNotionDialogTitle => 'Importa de Notion';

  @override
  String get importNotionDialogBody =>
      'Importa un ZIP exportat per Notion. Pots afegir-ho a la caixa actual o crear-ne una de nova.';

  @override
  String get importNotionSelectTargetTitle => 'Destí de la importació';

  @override
  String get importNotionSelectTargetBody =>
      'Tria si vols importar l\'exportació de Notion a la caixa forta actual o crear-ne una de nova.';

  @override
  String get importNotionTargetCurrent => 'Caixa forta actual';

  @override
  String get importNotionTargetNew => 'Nova caixa forta';

  @override
  String get importNotionDefaultVaultName => 'Importat de Notion';

  @override
  String get importNotionNewVaultPasswordTitle =>
      'Contrasenya per a la nova caixa';

  @override
  String get importNotionSuccessCurrent =>
      'S\'ha importat Notion a la caixa actual.';

  @override
  String get importNotionSuccessNew =>
      'S\'ha creat una nova caixa forta des de Notion.';

  @override
  String importNotionError(Object error) {
    return 'No s\'ha pogut importar Notion: $error';
  }

  @override
  String get importNotionWarningsTitle => 'Avisos d\'importació';

  @override
  String get importNotionWarningsBody =>
      'La importació s\'ha completat amb alguns avisos:';

  @override
  String get ok => 'D\'acord';

  @override
  String get notionExportGuideTitle => 'Com exportar de Notion';

  @override
  String get notionExportGuideBody =>
      'A Notion, ves a Settings -> Export all workspace content, tria HTML o Markdown i descarrega el ZIP. Després utilitza aquesta opció d\'importació al Folio.';

  @override
  String get appBetaBannerMessage =>
      'Estàs utilitzant una versió beta. Pots trobar errors; fes còpies de seguretat sovint.';

  @override
  String get appBetaBannerDismiss => 'Entesos';

  @override
  String get integrations => 'Integracions';

  @override
  String get integrationsAppsApprovedHint =>
      'Les aplicacions externes aprovades poden utilitzar el pont d\'integració local.';

  @override
  String get integrationsAppsApprovedTitle => 'Apps externes aprovades';

  @override
  String get integrationsAppsApprovedNone =>
      'Encara no has aprovat cap aplicació externa.';

  @override
  String get integrationsAppsApprovedRevoke => 'Revoca l\'accés';

  @override
  String integrationsApprovedAppDetails(
    Object appId,
    Object appVersion,
    Object integrationVersion,
  ) {
    return '$appId · App $appVersion · Integració $integrationVersion';
  }

  @override
  String get integrationApprovalTitle => 'Aprova la integració externa';

  @override
  String get integrationApprovalUpdateTitle =>
      'Aprova l\'actualització de la integració';

  @override
  String integrationApprovalBody(
    Object appName,
    Object appVersion,
    Object integrationVersion,
  ) {
    return '\"$appName\" vol connectar-se al Folio amb la versió d\'app $appVersion i d\'integració $integrationVersion.';
  }

  @override
  String integrationApprovalUpdateBody(
    Object appName,
    Object previousVersion,
    Object integrationVersion,
  ) {
    return '\"$appName\" ja estava aprovat amb la versió $previousVersion. Ara vol connectar-se amb la versió $integrationVersion, per la qual cosa el Folio necessita la teva aprovació de nou.';
  }

  @override
  String get integrationApprovalUnknownVersion => 'desconeguda';

  @override
  String get integrationApprovalAppId => 'ID de l\'App';

  @override
  String get integrationApprovalAppVersion => 'Versió de l\'App';

  @override
  String get integrationApprovalProtocolVersion => 'Versió d\'integració';

  @override
  String get integrationApprovalCanDoTitle => 'Què pot fer aquesta integració';

  @override
  String get integrationApprovalCanDoSessions =>
      'Crear sessions d\'importació temporals al Folio.';

  @override
  String get integrationApprovalCanDoImport =>
      'Enviar documentació en Markdown per crear o actualitzar pàgines.';

  @override
  String get integrationApprovalCanDoMetadata =>
      'Emmagatzemar metadades d\'origen a les pàgines importades.';

  @override
  String get integrationApprovalCanDoUnlockedVault =>
      'Importar només mentre la caixa estigui disponible i la petició inclogui el secret configurat.';

  @override
  String get integrationApprovalCannotDoTitle => 'Què NO pot fer';

  @override
  String get integrationApprovalCannotDoRead =>
      'No pot llegir el contingut de la teva caixa forta.';

  @override
  String get integrationApprovalCannotDoBypassLock =>
      'No pot saltar-se el bloqueig, el xifratge o la teva aprovació explícita.';

  @override
  String get integrationApprovalCannotDoWithoutSecret =>
      'No pot accedir a funcions protegides sense el secret compartit.';

  @override
  String get integrationApprovalCannotDoRemoteAccess =>
      'No pot utilitzar el pont des de fora de localhost.';

  @override
  String get integrationApprovalEncryptedChip => 'Contingut xifrat (v2)';

  @override
  String get integrationApprovalUnencryptedChip => 'Contingut no xifrat (v1)';

  @override
  String get integrationApprovalEncryptedTitle =>
      'Versió 2: xifratge de contingut obligatori';

  @override
  String get integrationApprovalEncryptedDescription =>
      'Aquesta versió requereix que les dades estiguin xifrades per importar contingut.';

  @override
  String get integrationApprovalUnencryptedTitle =>
      'Versió 1: contingut no xifrat';

  @override
  String get integrationApprovalUnencryptedDescription =>
      'Aquesta versió permet dades en text pla. Si necessites xifratge de transport, actualitza a la versió 2.';

  @override
  String get integrationApprovalDeny => 'Denega';

  @override
  String get integrationApprovalApprove => 'Aprova';

  @override
  String get integrationApprovalApproveUpdate => 'Aprova l\'actualització';

  @override
  String get about => 'Quant a';

  @override
  String get installedVersion => 'Versió instal·lada';

  @override
  String get updaterGithubRepository => 'Repositori d\'actualitzacions';

  @override
  String get updaterBetaDescription =>
      'Les versions beta són pre-llançaments de GitHub.';

  @override
  String get updaterStableDescription =>
      'Només es tenen en compte els llançaments estables.';

  @override
  String get checkUpdates => 'Cerca actualitzacions';

  @override
  String get noEncryptionConfirmTitle => 'Crea la caixa forta sense xifratge';

  @override
  String get noEncryptionConfirmBody =>
      'Les teves dades es desaran sense contrasenya ni xifratge. Qualsevol persona amb accés al dispositiu les podrà llegir.';

  @override
  String get createVaultWithoutEncryption => 'Crea sense xifratge';

  @override
  String get plainVaultSecurityNotice =>
      'Aquesta caixa forta no està xifrada. No s\'aplicaran les claus de pas, Hello, el bloqueig automàtic ni la contrasenya mestra.';

  @override
  String get encryptPlainVaultTitle => 'Xifra aquesta caixa forta';

  @override
  String get encryptPlainVaultBody =>
      'Tria una contrasenya mestra. Totes les dades d\'aquest dispositiu seran xifrades. Si la oblides, no es podran recuperar.';

  @override
  String get encryptPlainVaultConfirm => 'Xifra la caixa forta';

  @override
  String get encryptPlainVaultSuccessSnack => 'La caixa forta ara està xifrada';

  @override
  String get aiCopyMessage => 'Copia';

  @override
  String get aiCopyCode => 'Copia el codi';

  @override
  String get aiCopiedToClipboard => 'Copiat al porta-retalls';

  @override
  String get aiHelpful => 'Útil';

  @override
  String get aiNotHelpful => 'No és útil';

  @override
  String get aiThinkingMessage => 'El Quill està pensant...';

  @override
  String get aiMessageTimestampNow => 'ara mateix';

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
    return 'fa $n dies';
  }

  @override
  String get templateGalleryTitle => 'Plantilles de pàgina';

  @override
  String get templateImport => 'Importa';

  @override
  String get templateImportPickTitle => 'Selecciona un fitxer de plantilla';

  @override
  String get templateImportSuccess => 'Plantilla importada';

  @override
  String templateImportError(Object error) {
    return 'Error en importar: $error';
  }

  @override
  String get templateExportPickTitle => 'Desa el fitxer de plantilla';

  @override
  String get templateExportSuccess => 'Plantilla exportada';

  @override
  String templateExportError(Object error) {
    return 'Error en exportar: $error';
  }

  @override
  String get templateSearchHint => 'Cerca plantilles...';

  @override
  String get templateEmptyHint =>
      'Encara no hi ha plantilles.\nDesa una pàgina com a plantilla o importa\'n una.';

  @override
  String templateBlockCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'blocs',
      one: 'bloc',
    );
    return '$count $_temp0';
  }

  @override
  String get templateUse => 'Utilitza la plantilla';

  @override
  String get templateExport => 'Exporta';

  @override
  String get templateBlankPage => 'Pàgina en blanc';

  @override
  String get templateFromGallery => 'Des d\'una plantilla…';

  @override
  String get saveAsTemplate => 'Desa com a plantilla';

  @override
  String get saveAsTemplateTitle => 'Desa com a plantilla';

  @override
  String get templateNameHint => 'Nom de la plantilla';

  @override
  String get templateDescriptionHint => 'Descripció (opcional)';

  @override
  String get templateCategoryHint => 'Categoria (opcional)';

  @override
  String get templateSaved => 'S\'ha desat com a plantilla';

  @override
  String templateCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'plantilles',
      one: 'plantilla',
    );
    return '$count $_temp0';
  }

  @override
  String templateFilteredCount(int visible, int total) {
    return 'Mostrant $visible de $total plantilles';
  }

  @override
  String get templateSortRecent => 'Més noves';

  @override
  String get templateSortName => 'Nom';

  @override
  String get templateEdit => 'Edita la plantilla';

  @override
  String get templateUpdated => 'Plantilla actualitzada';

  @override
  String get templateDeleteConfirmTitle => 'Suprimeix la plantilla';

  @override
  String templateDeleteConfirmBody(Object name) {
    return 'La plantilla \"$name\" s\'eliminarà d\'aquesta caixa forta.';
  }

  @override
  String templateCreatedOn(Object date) {
    return 'Creada el $date';
  }

  @override
  String get templatePreviewEmpty =>
      'Aquesta plantilla encara no té vista prèvia de text.';

  @override
  String get templateSelectHint =>
      'Selecciona una plantilla per inspeccionar-la, editar-ne les metadades o exportar-la.';

  @override
  String get templateGalleryTabLocal => 'Local';

  @override
  String get templateGalleryTabCommunity => 'Comunitat';

  @override
  String get templateCommunitySignInCta =>
      'Inicia sessió per compartir i explorar plantilles de la comunitat.';

  @override
  String get templateCommunitySignInButton => 'Inicia sessió';

  @override
  String get templateCommunityUnavailable =>
      'Les plantilles de la comunitat requereixen Firebase. Comprova la teva connexió.';

  @override
  String get templateCommunityEmpty =>
      'Encara no hi ha plantilles de la comunitat. Sigues el primer a compartir-ne una des de la pestanya Local.';

  @override
  String templateCommunityLoadError(Object error) {
    return 'No s\'han pogut carregar les plantilles de la comunitat: $error';
  }

  @override
  String get templateCommunityRetry => 'Torna-ho a provar';

  @override
  String get templateCommunityRefresh => 'Actualitza';

  @override
  String get templateCommunityShareTitle => 'Comparteix amb la comunitat';

  @override
  String get templateCommunityShareBody =>
      'La teva plantilla serà pública. Elimina qualsevol contingut personal o confidencial abans de compartir-la.';

  @override
  String get templateCommunityShareConfirm => 'Comparteix';

  @override
  String get templateCommunityShareSuccess =>
      'Plantilla compartida amb la comunitat';

  @override
  String templateCommunityShareError(Object error) {
    return 'No s\'ha pogut compartir: $error';
  }

  @override
  String get templateCommunityAddToVault => 'Desa a les meves plantilles';

  @override
  String get templateCommunityAddedToVault =>
      'S\'ha desat a les teves plantilles';

  @override
  String get templateCommunityDeleteTitle => 'Elimina de la comunitat';

  @override
  String templateCommunityDeleteBody(Object name) {
    return 'Vols eliminar \"$name\" de la comunitat? Això no es pot desfer.';
  }

  @override
  String get templateCommunityDeleteSuccess => 'Eliminada de la comunitat';

  @override
  String templateCommunityDeleteError(Object error) {
    return 'No s\'ha pogut eliminar: $error';
  }

  @override
  String templateCommunityDownloadError(Object error) {
    return 'No s\'ha pogut descarregar la plantilla: $error';
  }

  @override
  String get clear => 'Neteja';

  @override
  String get cloudAccountSectionTitle => 'Compte de Folio Cloud';

  @override
  String get cloudAccountSectionDescription =>
      'Opcional. Inicia sessió per subscriure\'t a còpies al núvol, IA hospedada i publicació web. La caixa forta es manté local a menys que utilitzis aquestes funcions.';

  @override
  String get cloudAccountChipOptional => 'Opcional';

  @override
  String get cloudAccountChipPaidCloud => 'Còpies, IA i Web';

  @override
  String get cloudAccountUnavailable =>
      'L\'inici de sessió al núvol no està disponible (Firebase no s\'ha iniciat). Comprova la connexió.';

  @override
  String get cloudAccountEmailLabel => 'Correu electrònic';

  @override
  String get cloudAccountPasswordLabel => 'Contrasenya';

  @override
  String get cloudAccountSignIn => 'Inicia sessió';

  @override
  String get cloudAccountCreateAccount => 'Crea un compte';

  @override
  String get cloudAccountForgotPassword => 'Has oblidat la contrasenya?';

  @override
  String get cloudAccountSignOut => 'Tanca la sessió';

  @override
  String cloudAccountSignedInAs(Object email) {
    return 'Sessió iniciada com a $email';
  }

  @override
  String cloudAccountUid(Object uid) {
    return 'ID d\'usuari: $uid';
  }

  @override
  String get cloudAuthDialogTitleSignIn => 'Inicia sessió a Folio Cloud';

  @override
  String get cloudAuthDialogTitleRegister => 'Crea un compte de Folio Cloud';

  @override
  String get cloudAuthDialogTitleReset => 'Restableix la contrasenya';

  @override
  String get cloudPasswordResetSent =>
      'Si existeix un compte amb aquest correu, s\'ha enviat un enllaç de restabliment.';

  @override
  String get cloudAuthErrorInvalidEmail => 'Aquest correu no és vàlid.';

  @override
  String get cloudAuthErrorWrongPassword => 'Contrasenya incorrecta.';

  @override
  String get cloudAuthErrorUserNotFound =>
      'No s\'ha trobat cap compte amb aquest correu.';

  @override
  String get cloudAuthErrorUserDisabled => 'Aquest compte ha estat desactivat.';

  @override
  String get cloudAuthErrorEmailAlreadyInUse =>
      'Aquest correu ja està registrat.';

  @override
  String get cloudAuthErrorWeakPassword => 'La contrasenya és massa feble.';

  @override
  String get cloudAuthErrorInvalidCredential =>
      'Correu o contrasenya no vàlids.';

  @override
  String get cloudAuthErrorNetwork => 'Error de xarxa. Comprova la connexió.';

  @override
  String get cloudAuthErrorTooManyRequests =>
      'Massa intents. Torna-ho a provar més tard.';

  @override
  String get cloudAuthErrorOperationNotAllowed =>
      'Aquest mètode d\'inici de sessió no està habilitat.';

  @override
  String get cloudAuthErrorGeneric =>
      'Error en iniciar la sessió. Torna-ho a provar.';

  @override
  String get cloudAuthDialogTitle => 'Folio Cloud';

  @override
  String get cloudAuthSubtitleSignIn =>
      'Utilitza el teu correu i contrasenya de Folio Cloud. Res aquí canvia la teva caixa forta local.';

  @override
  String get cloudAuthSubtitleRegister =>
      'Crea les credencials de Folio Cloud. Les notes del dispositiu no es pujaran fins que activis les còpies o funcions de pagament.';

  @override
  String get cloudAuthModeSignIn => 'Inicia sessió';

  @override
  String get cloudAuthModeRegister => 'Registra\'t';

  @override
  String get cloudAuthConfirmPasswordLabel => 'Confirma la contrasenya';

  @override
  String get cloudAuthValidationRequired => 'Aquest camp és obligatori.';

  @override
  String get cloudAuthValidationPasswordShort =>
      'Utilitza almenys 6 caràcters.';

  @override
  String get cloudAuthValidationConfirmMismatch =>
      'Les contrasenyes no coincideixen.';

  @override
  String get cloudAccountSignedOutPrompt =>
      'Inicia sessió o registra\'t per subscriure\'t a Folio Cloud i utilitzar còpies, IA al núvol i publicació.';

  @override
  String get cloudAuthResetHint =>
      'T\'enviarem un enllaç per correu per establir una nova contrasenya.';

  @override
  String get cloudAccountEmailVerified => 'Verificat';

  @override
  String get cloudAccountSignOutHelp =>
      'La teva caixa forta local es queda en aquest dispositiu.';

  @override
  String get cloudAccountEmailUnverifiedBanner =>
      'Verifica el teu correu per protegir el teu compte de Folio Cloud.';

  @override
  String get cloudAccountResendVerification =>
      'Torna a enviar el correu de verificació';

  @override
  String get cloudAccountReloadVerification => 'Ja l\'he verificat';

  @override
  String get cloudAccountVerificationSent => 'Correu de verificació enviat.';

  @override
  String get cloudAccountVerificationStillPending =>
      'El correu encara no s\'ha verificat. Obre l\'enllaç de la teva bústia.';

  @override
  String get cloudAccountVerificationNowVerified => 'Correu verificat.';

  @override
  String get cloudAccountResetPasswordEmail =>
      'Restableix la contrasenya per correu';

  @override
  String get cloudAccountCopyEmail => 'Copia el correu';

  @override
  String get cloudAccountEmailCopied => 'Correu copiat.';

  @override
  String get folioWebPortalSubsectionTitle => 'Compte Web';

  @override
  String get folioWebPortalLinkCodeLabel => 'Codi d\'enllaç';

  @override
  String get folioWebPortalLinkHelp =>
      'Genera el codi a l\'aplicació web a Configuració → Compte Folio i introdueix-lo aquí abans de 10 minuts.';

  @override
  String get folioWebPortalLinkButton => 'Enllaça';

  @override
  String get folioWebPortalLinkSuccess => 'Compte web enllaçat correctament.';

  @override
  String get folioWebPortalNeedSignIn =>
      'Inicia sessió a Folio Cloud per enllaçar el compte web.';

  @override
  String get folioWebMirrorNote =>
      'Les còpies, l\'IA i la publicació encara es gestionen per Folio Cloud. El que es mostra a sota reflecteix el teu compte web.';

  @override
  String get folioWebEntitlementLinked => 'Compte web enllaçat';

  @override
  String get folioWebEntitlementNotLinked => 'Compte web no enllaçat';

  @override
  String folioWebEntitlementWebPlan(String value) {
    return 'Pla de Folio Cloud (web): $value';
  }

  @override
  String folioWebEntitlementWebStatus(String value) {
    return 'Estat (web): $value';
  }

  @override
  String folioWebEntitlementWebPeriodEnd(String value) {
    return 'Fi del període (web): $value';
  }

  @override
  String folioWebEntitlementWebInk(int count) {
    return 'Ink (web): $count';
  }

  @override
  String get folioWebPortalRefreshWeb => 'Actualitza l\'estat web';

  @override
  String get folioWebPortalErrorNetwork =>
      'No s\'ha pogut contactar amb el portal. Comprova la connexió.';

  @override
  String get folioWebPortalErrorTimeout =>
      'El portal ha trigat massa a respondre.';

  @override
  String get folioWebPortalErrorAdminNotConfigured =>
      'Folio Firebase Admin no està configurat al servidor.';

  @override
  String get folioWebPortalErrorUnauthorized =>
      'Sessió no vàlida. Torna a iniciar sessió a Folio Cloud.';

  @override
  String get folioWebPortalErrorGeneric =>
      'No s\'ha pogut completar la petició al portal.';

  @override
  String folioWebPortalServerMessage(String message) {
    return '$message';
  }

  @override
  String get folioCloudSubsectionPlan => 'Pla i estat';

  @override
  String get folioCloudSubsectionInk => 'Saldo d\'Ink';

  @override
  String get folioCloudSubsectionSubscription => 'Subscripció i facturació';

  @override
  String get folioCloudSubsectionBackupPublish => 'Còpies i publicació';

  @override
  String get folioCloudSubscriptionActive => 'Subscripció activa';

  @override
  String folioCloudSubscriptionActiveWithStatus(String status) {
    return 'Subscripció activa ($status)';
  }

  @override
  String get folioCloudSubscriptionNoneTitle =>
      'Sense subscripció a Folio Cloud';

  @override
  String get folioCloudSubscriptionNoneSubtitle =>
      'Activa un pla per tenir còpies xifrades, IA al núvol i publicació web.';

  @override
  String get folioCloudFeatureBackup => 'Còpia al núvol';

  @override
  String get folioCloudFeatureCloudAi => 'IA al núvol';

  @override
  String get folioCloudFeaturePublishWeb => 'Publicació web';

  @override
  String get folioCloudFeatureOn => 'Inclòs';

  @override
  String get folioCloudFeatureOff => 'No inclòs';

  @override
  String get folioCloudPostPaymentHint =>
      'Si acabes de pagar i les funcions no apareixen, prem «Actualitza des de Stripe».';

  @override
  String get folioCloudBackupCleanupWarning =>
      'Còpia pujada, però les còpies antigues no s\'han pogut netejar (es tornarà a provar més tard).';

  @override
  String get folioCloudInkMonthly => 'Mensual';

  @override
  String get folioCloudInkPurchased => 'Comprat';

  @override
  String get folioCloudInkTotal => 'Total';

  @override
  String folioCloudInkCount(int count) {
    return '$count';
  }

  @override
  String get folioCloudPlanActiveHeadline => 'Pla mensual de Folio Cloud actiu';

  @override
  String get folioCloudSubscribeMonthly => 'Folio Cloud 4,99 €/mes';

  @override
  String get folioCloudPitchScreenTitle => 'Folio Cloud';

  @override
  String get folioCloudPitchHeadline =>
      'La teva caixa es manté local. El núvol funciona quan tu vols.';

  @override
  String get folioCloudPitchSubhead =>
      'Un pla mensual desbloqueja còpies xifrades, IA al núvol amb saldo mensual d\'ink i publicació web — només per al que decideixis compartir.';

  @override
  String get folioCloudPitchLearnMore => 'Mira què inclou';

  @override
  String get folioCloudPitchCtaNeedAccount => 'Inicia sessió o crea un compte';

  @override
  String get folioCloudPitchGuestTeaserTitle => 'Compte de Folio Cloud';

  @override
  String get folioCloudPitchGuestTeaserBody =>
      'Compte opcional: mira què inclou el pla i entra quan et vulguis subscriure.';

  @override
  String get folioCloudPitchOpenSettingsToSignIn =>
      'Obre Configuració i inicia sessió a Folio Cloud per subscriure\'t.';

  @override
  String get folioCloudBuyInk => 'Compra ink';

  @override
  String get folioCloudInkSmall => 'Ink Petit (1,99 €)';

  @override
  String get folioCloudInkMedium => 'Ink Mitjà (4,99 €)';

  @override
  String get folioCloudInkLarge => 'Ink Gran (9,99 €)';

  @override
  String get folioCloudManageSubscription => 'Gestiona la subscripció';

  @override
  String get folioCloudRefreshFromStripe => 'Actualitza';

  @override
  String get folioCloudMicrosoftStoreBillingTitle =>
      'Microsoft Store (Windows)';

  @override
  String get folioCloudMicrosoftStoreBillingSubtitle =>
      'Mateixa subscripció i tinta que amb Stripe; la Botiga cobra i el servidor valida la compra. Configura els ids de producte amb --dart-define i Azure AD a Cloud Functions.';

  @override
  String get folioCloudMicrosoftStoreSubscribeButton =>
      'Subscripció a la Botiga';

  @override
  String get folioCloudMicrosoftStoreSyncButton => 'Sincronitza amb la Botiga';

  @override
  String get folioCloudMicrosoftStoreInkTitle => 'Tinta — Microsoft Store';

  @override
  String get folioCloudMicrosoftStoreInkPackSmall => 'Tinter petit (Botiga)';

  @override
  String get folioCloudMicrosoftStoreInkPackMedium => 'Tinter mitjà (Botiga)';

  @override
  String get folioCloudMicrosoftStoreInkPackLarge => 'Tinter gran (Botiga)';

  @override
  String get folioCloudMicrosoftStoreSyncedSnack =>
      'Sincronitzat amb Microsoft Store.';

  @override
  String get folioCloudMicrosoftStoreAppliedSnack =>
      'Compra aplicada. Si no veus els canvis, prem sincronitzar.';

  @override
  String get folioCloudPurchaseChannelTitle => 'On vols pagar?';

  @override
  String get folioCloudPurchaseChannelBody =>
      'Pots usar la Microsoft Store integrada a Windows o pagar amb targeta al navegador (Stripe). El pla i la tinta són els mateixos.';

  @override
  String get folioCloudPurchaseChannelMicrosoftStore => 'Microsoft Store';

  @override
  String get folioCloudPurchaseChannelStripe => 'Al navegador (Stripe)';

  @override
  String get folioCloudPurchaseChannelCancel => 'Cancel·lar';

  @override
  String get folioCloudPurchaseChannelStoreNotConfigured =>
      'L’opció de la Botiga no està configurada en aquesta compilació (manquen ids de producte).';

  @override
  String get folioCloudPurchaseChannelStoreNotConfiguredHint =>
      'Compila amb --dart-define=MS_STORE_… o usa el pagament al navegador.';

  @override
  String get folioCloudMicrosoftStoreSyncHint =>
      'A Windows, «Actualitzar» també sincronitza la Microsoft Store (mateix botó que Stripe).';

  @override
  String get folioCloudUploadEncryptedBackup => 'Fes una còpia al núvol ara';

  @override
  String get folioCloudUploadEncryptedBackupSubtitle =>
      'Folio crea una còpia xifrada de la caixa oberta i la puja — sense exportació ZIP manual.';

  @override
  String get folioCloudUploadSnackOk =>
      'S\'ha desat la còpia de la caixa al núvol.';

  @override
  String get scheduledVaultBackupCloudSyncTitle => 'Puja també a Folio Cloud';

  @override
  String get scheduledVaultBackupCloudSyncSubtitle =>
      'Després de cada còpia programada, puja el mateix ZIP al teu compte automàticament. Per a còpies només al núvol, deixa la carpeta local buida.';

  @override
  String get folioCloudCloudBackupsList => 'Còpies al núvol';

  @override
  String get folioCloudBackupsUsed => 'Utilitzat';

  @override
  String get folioCloudBackupsLimit => 'Límit';

  @override
  String get folioCloudBackupsRemaining => 'Restant';

  @override
  String get folioCloudPublishTestPage => 'Publica pàgina de prova';

  @override
  String get folioCloudPublishedPagesList => 'Pàgines publicades';

  @override
  String get folioCloudReauthDialogTitle => 'Confirma el compte de Folio Cloud';

  @override
  String get folioCloudReauthDialogBody =>
      'Introdueix la contrasenya del teu compte Folio Cloud (la que fas servir per entrar al núvol) per llistar i baixar còpies. No és la contrasenya de la teva caixa local.';

  @override
  String get folioCloudReauthRequiresPasswordProvider =>
      'Aquesta sessió no utilitza una contrasenya de Folio Cloud. Tanca la sessió i torna a entrar amb correu i contrasenya.';

  @override
  String get folioCloudAiNoInkTitle => 'No queda saldo d\'ink d\'IA al núvol';

  @override
  String get folioCloudAiNoInkBody =>
      'Compra ink a l\'apartat Folio Cloud, espera la recàrrega mensual o canvia a IA local a la secció d\'IA.';

  @override
  String get folioCloudAiNoInkActionCloud => 'Folio Cloud i ink';

  @override
  String get folioCloudAiNoInkActionLocal => 'Proveïdor d\'IA';

  @override
  String get folioCloudAiZeroInkBanner =>
      'El saldo d\'IA al núvol és 0 — compra ink o utilitza IA local.';

  @override
  String folioCloudInkPurchaseAppliedHint(Object purchased) {
    return 'Compra aplicada: $purchased ink comprat disponible per a IA al núvol.';
  }

  @override
  String get onboardingCloudBackupCta => 'Inicia sessió i baixa una còpia';

  @override
  String get onboardingCloudBackupPickVaultSubtitle =>
      'Tria quina caixa forta vols restaurar.';

  @override
  String get onboardingFolioCloudTitle => 'Folio Cloud';

  @override
  String get onboardingFolioCloudBody =>
      'Activa les funcions al núvol quan les necessitis: còpies xifrades, Quill hospedat i publicació web. La caixa es manté local a menys que utilitzis aquestes funcions.';

  @override
  String get onboardingFolioCloudFeatureBackupTitle =>
      'Còpies xifrades al núvol';

  @override
  String get onboardingFolioCloudFeatureBackupBody =>
      'Desa i descarrega còpies de les teves caixes des del teu compte.';

  @override
  String get onboardingFolioCloudFeatureAiTitle => 'IA al núvol + ink';

  @override
  String get onboardingFolioCloudFeatureAiBody =>
      'Quill hospedat amb una subscripció o comprant ink. L\'ink es consumeix amb l\'ús; també pots utilitzar IA local.';

  @override
  String get onboardingFolioCloudFeatureWebTitle => 'Publicació web';

  @override
  String get onboardingFolioCloudFeatureWebBody =>
      'Publica les pàgines que vulguis i controla què es fa públic. La resta de la teva caixa no es comparteix.';

  @override
  String get onboardingFolioCloudLaterInSettings =>
      'Ho miraré més tard a Configuració';

  @override
  String get collabMenuAction => 'Col·laboració en viu';

  @override
  String get collabSheetTitle => 'Col·laboració en viu';

  @override
  String get collabHeaderSubtitle =>
      'Requereix compte de Folio. Hostatjar requereix un pla; unir-se només requereix el codi. El contingut i el xat estan xifrats d\'extrem a extrem; el servidor mai veu el teu text.';

  @override
  String get collabNoRoomHint =>
      'Crea una sala (si el teu pla inclou hostalatge) o enganxa el codi de l\'hoste.';

  @override
  String get collabCreateRoom => 'Crea una sala';

  @override
  String get collabJoinCodeLabel => 'Codi de la sala';

  @override
  String get collabJoinCodeHint => 'p. ex. dos emojis + 4 dígits';

  @override
  String get collabJoinRoom => 'Uneix-te';

  @override
  String get collabJoinFailed => 'Codi no vàlid o sala plena.';

  @override
  String get collabShareCodeLabel => 'Comparteix aquest codi';

  @override
  String get collabCopyJoinCode => 'Copia el codi';

  @override
  String get collabCopied => 'Copiat';

  @override
  String get collabHostRequiresPlan =>
      'Crear sales requereix Folio Cloud amb col·laboració. Pots unir-te a sales d\'altres amb un codi sense aquest pla.';

  @override
  String get collabChatEmptyHint =>
      'Encara no hi ha missatges. Saluda el teu equip.';

  @override
  String get collabMessageHint => 'Escriu un missatge…';

  @override
  String get collabArchivedOk => 'Xat arxivat com a comentaris de la pàgina.';

  @override
  String get collabArchiveToPage => 'Arxiva el xat a la pàgina';

  @override
  String get collabLeaveRoom => 'Surt de la sala';

  @override
  String get collabNeedsJoinCode =>
      'Introdueix el codi de la sala per desxifrar aquesta sessió de col·laboració.';

  @override
  String get collabMissingJoinCodeHint =>
      'Aquesta pàgina està vinculada a una sala però no hi ha cap codi desat aquí. Enganxa el codi per desxifrar el contingut.';

  @override
  String get collabUnlockWithCode => 'Desbloqueja amb el codi';

  @override
  String get collabHidePanel => 'Amaga el panell de col·laboració';

  @override
  String get shortcutsCaptureTitle => 'Nova drecera';

  @override
  String get shortcutsCaptureHint => 'Prem les tecles (Esc cancel·la).';

  @override
  String get updaterStartupDialogTitleStable => 'Actualització disponible';

  @override
  String get updaterStartupDialogTitleBeta => 'Beta disponible';

  @override
  String updaterStartupDialogBody(Object releaseVersion) {
    return 'Hi ha una nova versió disponible ($releaseVersion).';
  }

  @override
  String get updaterStartupDialogQuestion =>
      'Vols descarregar-la i instal·lar-la ara?';

  @override
  String get updaterStartupDialogLater => 'Més tard';

  @override
  String get updaterStartupDialogUpdateNow => 'Actualitza ara';

  @override
  String get updaterStartupDialogBetaNote => 'Versió Beta (pre-llançament).';

  @override
  String get updaterOpenApkDownloadQuestion =>
      'Vols obrir la descàrrega de l\'APK ara?';

  @override
  String get updaterManualCheckUnsupportedPlatform =>
      'L\'actualitzador integrat només està disponible a Windows i Android.';

  @override
  String get updaterManualCheckAlreadyLatest => 'Ja tens la versió més recent.';

  @override
  String updaterDialogLineCurrentVersion(Object currentVersion) {
    return 'Versió actual: $currentVersion';
  }

  @override
  String updaterDialogLineNewVersion(Object releaseVersion) {
    return 'Versió nova: $releaseVersion';
  }

  @override
  String get updaterApkUrlInvalidSnack =>
      'No s\'ha trobat cap URL vàlida de l\'APK al release.';

  @override
  String get updaterApkOpenFailedSnack =>
      'No s\'ha pogut obrir la descàrrega de l\'APK.';

  @override
  String get toggleTitleHint => 'Títol de l\'alternador';

  @override
  String get toggleBodyHint => 'Contingut…';

  @override
  String get taskStatusTodo => 'Per fer';

  @override
  String get taskStatusInProgress => 'En curs';

  @override
  String get taskStatusDone => 'Fet';

  @override
  String get taskPriorityNone => 'Sense prioritat';

  @override
  String get taskPriorityLow => 'Baixa';

  @override
  String get taskPriorityMedium => 'Mitjana';

  @override
  String get taskPriorityHigh => 'Alta';

  @override
  String get taskTitleHint => 'Descripció de la tasca…';

  @override
  String get taskPriorityTooltip => 'Prioritat';

  @override
  String get taskNoDueDate => 'Sense data de venciment';

  @override
  String get taskSubtaskHint => 'Subtasca…';

  @override
  String get taskRemoveSubtask => 'Suprimeix la subtasca';

  @override
  String get taskAddSubtask => 'Afegeix una subtasca';

  @override
  String get title => 'Títol';

  @override
  String get description => 'Descripció';

  @override
  String get priority => 'Prioritat';

  @override
  String get status => 'Estat';

  @override
  String get none => 'Cap';

  @override
  String get low => 'Baixa';

  @override
  String get medium => 'Mitjana';

  @override
  String get high => 'Alta';

  @override
  String get startDate => 'Data d\'inici';

  @override
  String get dueDate => 'Data de venciment';

  @override
  String get timeSpentMinutes => 'Temps invertit (minuts)';

  @override
  String get taskBlocked => 'Bloquejada';

  @override
  String get taskBlockedReason => 'Motiu del bloqueig';

  @override
  String get subtasks => 'Subtasques';

  @override
  String get add => 'Afegeix';

  @override
  String get templateEmojiLabel => 'Emoji';

  @override
  String aiGenericErrorWithReason(Object reason) {
    return 'Error d\'IA: $reason';
  }

  @override
  String get calloutTypeTooltip => 'Tipus d\'avís';

  @override
  String get calloutTypeInfo => 'Informació';

  @override
  String get calloutTypeSuccess => 'Èxit';

  @override
  String get calloutTypeWarning => 'Avís';

  @override
  String get calloutTypeError => 'Error';

  @override
  String get calloutTypeNote => 'Nota';

  @override
  String get blockEditorEnterHintNewBlock =>
      'Retorn: bloc nou (en codi: Retorn = línia)';

  @override
  String get blockEditorEnterHintNewLine => 'Retorn: línia nova';

  @override
  String blockEditorShortcutsHintMobile(String enterHint) {
    return '$enterHint · / per a blocs · toca el bloc per a més accions';
  }

  @override
  String blockEditorShortcutsHintDesktop(String enterHint) {
    return '$enterHint · Maj+Retorn: línia · / tipus · # títol (mateixa línia) · - · * · [] · ``` espai · taula/imatge a / · format: barra en enfocar o ** _ <u> ` ~~';
  }

  @override
  String blockEditorSelectedBlocksBanner(int count) {
    return '$count blocs seleccionats · Maj: interval · Ctrl/Cmd: alternar';
  }

  @override
  String get blockEditorDuplicate => 'Duplicar';

  @override
  String get blockEditorClearSelectionTooltip => 'Neteja la selecció';

  @override
  String get blockEditorMenuRewriteWithAi => 'Reescriure amb IA…';

  @override
  String get blockEditorMenuMoveUp => 'Mou amunt';

  @override
  String get blockEditorMenuMoveDown => 'Mou avall';

  @override
  String get blockEditorMenuDuplicateBlock => 'Duplica el bloc';

  @override
  String get blockEditorMenuAppearance => 'Aparença…';

  @override
  String get blockEditorMenuCalloutIcon => 'Icona de l’avís…';

  @override
  String blockEditorCalloutMenuType(String typeName) {
    return 'Tipus: $typeName';
  }

  @override
  String get blockEditorCopyLink => 'Copia l’enllaç';

  @override
  String get blockEditorMenuCreateSubpage => 'Crea una subpàgina';

  @override
  String get blockEditorMenuLinkPage => 'Enllaça pàgina…';

  @override
  String get blockEditorMenuOpenSubpage => 'Obre la subpàgina';

  @override
  String get blockEditorMenuPickImage => 'Trieu imatge…';

  @override
  String get blockEditorMenuRemoveImage => 'Treu la imatge';

  @override
  String get blockEditorMenuCodeLanguage => 'Llenguatge del codi…';

  @override
  String get blockEditorMenuEditDiagram => 'Edita el diagrama…';

  @override
  String get blockEditorMenuBackToPreview => 'Torna a la previsualització';

  @override
  String get blockEditorMenuChangeFile => 'Canvia el fitxer…';

  @override
  String get blockEditorMenuRemoveFile => 'Treu el fitxer';

  @override
  String get blockEditorMenuChangeVideo => 'Canvia el vídeo…';

  @override
  String get blockEditorMenuRemoveVideo => 'Treu el vídeo';

  @override
  String get blockEditorMenuChangeAudio => 'Canvia l’àudio…';

  @override
  String get blockEditorMenuRemoveAudio => 'Treu l’àudio';

  @override
  String get blockEditorMenuEditLabel => 'Edita l’etiqueta…';

  @override
  String get blockEditorMenuAddRow => 'Afegeix una fila';

  @override
  String get blockEditorMenuRemoveLastRow => 'Treu l’última fila';

  @override
  String get blockEditorMenuAddColumn => 'Afegeix una columna';

  @override
  String get blockEditorMenuRemoveLastColumn => 'Treu l’última columna';

  @override
  String get blockEditorMenuAddProperty => 'Afegeix una propietat';

  @override
  String get blockEditorMenuChangeBlockType => 'Canvia el tipus de bloc…';

  @override
  String get blockEditorMenuDeleteBlock => 'Suprimeix el bloc';

  @override
  String get blockEditorAppearanceTitle => 'Aparença del bloc';

  @override
  String get blockEditorAppearanceSubtitle =>
      'Personalitza la mida, el color del text i el fons d’aquest bloc.';

  @override
  String get blockEditorAppearanceSize => 'Mida';

  @override
  String get blockEditorAppearanceTextColor => 'Color del text';

  @override
  String get blockEditorAppearanceBackground => 'Fons';

  @override
  String get blockEditorAppearancePreviewEmpty => 'Així es veurà aquest bloc.';

  @override
  String get blockEditorReset => 'Restableix';

  @override
  String get blockEditorCodeLanguageTitle => 'Llenguatge del codi';

  @override
  String get blockEditorCodeLanguageSubtitle =>
      'Ressaltat de sintaxi segons el llenguatge triat.';

  @override
  String get blockEditorTemplateButtonTitle => 'Etiqueta del botó de plantilla';

  @override
  String get blockEditorTemplateButtonFieldLabel => 'Text del botó';

  @override
  String get blockEditorTemplateButtonDefaultLabel => 'Plantilla';

  @override
  String get blockEditorTextColorDefault => 'Tema';

  @override
  String get blockEditorTextColorSubtle => 'Suau';

  @override
  String get blockEditorTextColorPrimary => 'Primari';

  @override
  String get blockEditorTextColorSecondary => 'Secundari';

  @override
  String get blockEditorTextColorTertiary => 'Accent';

  @override
  String get blockEditorTextColorError => 'Error';

  @override
  String get blockEditorBackgroundNone => 'Sense fons';

  @override
  String get blockEditorBackgroundSurface => 'Superfície';

  @override
  String get blockEditorBackgroundPrimary => 'Primari';

  @override
  String get blockEditorBackgroundSecondary => 'Secundari';

  @override
  String get blockEditorBackgroundTertiary => 'Accent';

  @override
  String get blockEditorBackgroundError => 'Error';

  @override
  String get blockEditorCmdDuplicatePrev => 'Duplica el bloc anterior';

  @override
  String get blockEditorCmdDuplicatePrevHint =>
      'Clona el bloc immediatament superior';

  @override
  String get blockEditorCmdInsertDate => 'Insereix la data';

  @override
  String get blockEditorCmdInsertDateHint => 'Escriu la data d’avui';

  @override
  String get blockEditorCmdMentionPage => 'Menciona una pàgina';

  @override
  String get blockEditorCmdMentionPageHint =>
      'Insereix un enllaç intern a una pàgina';

  @override
  String get blockEditorCmdTurnInto => 'Converteix el bloc';

  @override
  String get blockEditorCmdTurnIntoHint => 'Tria el tipus de bloc al selector';

  @override
  String get blockEditorMarkTaskComplete => 'Marca la tasca com a feta';

  @override
  String get blockEditorCalloutIconPickerTitle => 'Icona de l’avís';

  @override
  String get blockEditorCalloutIconPickerHelper =>
      'Trieu una icona per canviar el to visual del bloc d’avís.';

  @override
  String get blockEditorIconPickerCustomEmoji => 'Emoji personalitzat';

  @override
  String get blockEditorIconPickerQuickTab => 'Ràpids';

  @override
  String get blockEditorIconPickerImportedTab => 'Importats';

  @override
  String get blockEditorIconPickerAllTab => 'Tots';

  @override
  String get blockEditorIconPickerEmptyImported =>
      'Encara no heu importat icones a Configuració.';

  @override
  String get blockTypeSectionBasicText => 'Text bàsic';

  @override
  String get blockTypeSectionLists => 'Llistes';

  @override
  String get blockTypeSectionMedia => 'Multimèdia i dades';

  @override
  String get blockTypeSectionAdvanced => 'Avançat i disseny';

  @override
  String get blockTypeSectionEmbeds => 'Integracions';

  @override
  String get blockTypeParagraphLabel => 'Text';

  @override
  String get blockTypeParagraphHint => 'Paràgraf';

  @override
  String get blockTypeChildPageLabel => 'Pàgina';

  @override
  String get blockTypeChildPageHint => 'Subpàgina enllaçada';

  @override
  String get blockTypeH1Label => 'Encapçalament 1';

  @override
  String get blockTypeH1Hint => 'Títol gran · #';

  @override
  String get blockTypeH2Label => 'Encapçalament 2';

  @override
  String get blockTypeH2Hint => 'Subtítol · ##';

  @override
  String get blockTypeH3Label => 'Encapçalament 3';

  @override
  String get blockTypeH3Hint => 'Encapçalament menor · ###';

  @override
  String get blockTypeQuoteLabel => 'Cita';

  @override
  String get blockTypeQuoteHint => 'Text citat';

  @override
  String get blockTypeDividerLabel => 'Divisor';

  @override
  String get blockTypeDividerHint => 'Separador · ---';

  @override
  String get blockTypeCalloutLabel => 'Bloc destacat';

  @override
  String get blockTypeCalloutHint => 'Avís amb icona';

  @override
  String get blockTypeBulletLabel => 'Llista amb vinyetes';

  @override
  String get blockTypeBulletHint => 'Llista amb punts';

  @override
  String get blockTypeNumberedLabel => 'Llista numerada';

  @override
  String get blockTypeNumberedHint => 'Llista 1, 2, 3';

  @override
  String get blockTypeTodoLabel => 'Llista de tasques';

  @override
  String get blockTypeTodoHint => 'Checklist';

  @override
  String get blockTypeTaskLabel => 'Tasca enriquida';

  @override
  String get blockTypeTaskHint => 'Estat / prioritat / data';

  @override
  String get blockTypeToggleLabel => 'Desplegable';

  @override
  String get blockTypeToggleHint => 'Mostrar o amagar contingut';

  @override
  String get blockTypeImageLabel => 'Imatge';

  @override
  String get blockTypeImageHint => 'Imatge local o externa';

  @override
  String get blockTypeBookmarkLabel => 'Marcador amb vista prèvia';

  @override
  String get blockTypeBookmarkHint => 'Targeta amb enllaç';

  @override
  String get blockTypeVideoLabel => 'Vídeo';

  @override
  String get blockTypeVideoHint => 'Fitxer o URL';

  @override
  String get blockTypeAudioLabel => 'Àudio';

  @override
  String get blockTypeAudioHint => 'Reproductor d\'àudio';

  @override
  String get blockTypeMeetingNoteLabel => 'Nota de reunió';

  @override
  String get blockTypeMeetingNoteHint => 'Enregistra i transcriu una reunió';

  @override
  String get blockTypeCodeLabel => 'Codi (Java, Python…)';

  @override
  String get blockTypeCodeHint => 'Bloc amb sintaxi';

  @override
  String get blockTypeFileLabel => 'Fitxer / PDF';

  @override
  String get blockTypeFileHint => 'Adjunt o PDF';

  @override
  String get blockTypeTableLabel => 'Taula';

  @override
  String get blockTypeTableHint => 'Files i columnes';

  @override
  String get blockTypeDatabaseLabel => 'Base de dades';

  @override
  String get blockTypeDatabaseHint => 'Vista de llista/taula/tauler';

  @override
  String get blockTypeKanbanLabel => 'Kanban';

  @override
  String get blockTypeKanbanHint =>
      'Vista de tauler per a les tasques d\'aquesta pàgina';

  @override
  String get kanbanBlockRowTitle => 'Tauler Kanban';

  @override
  String get kanbanBlockRowSubtitle =>
      'En obrir la pàgina es mostra el tauler. A la barra del tauler usa «Obrir editor de blocs» per editar o eliminar aquest bloc.';

  @override
  String get kanbanRowTodosExcluded => 'Sense checklists';

  @override
  String get kanbanToolbarOpenEditor => 'Obrir editor de blocs';

  @override
  String get kanbanToolbarAddTask => 'Afegir tasca';

  @override
  String get kanbanClassicModeBanner =>
      'Editor de blocs: pots moure o eliminar el bloc Kanban.';

  @override
  String get kanbanBackToBoard => 'Tornar al tauler';

  @override
  String get kanbanMultipleBlocksSnack =>
      'Aquesta pàgina té més d\'un bloc Kanban; s\'utilitza el primer.';

  @override
  String get kanbanEmptyColumn => 'Sense tasques';

  @override
  String get blockTypeEquationLabel => 'Equació (LaTeX)';

  @override
  String get blockTypeEquationHint => 'Fórmules matemàtiques';

  @override
  String get blockTypeMermaidLabel => 'Diagrama (Mermaid)';

  @override
  String get blockTypeMermaidHint => 'Diagrama de flux o esquema';

  @override
  String get blockTypeTocLabel => 'Taula de continguts';

  @override
  String get blockTypeTocHint => 'Índex automàtic';

  @override
  String get blockTypeBreadcrumbLabel => 'Rutes de navegació';

  @override
  String get blockTypeBreadcrumbHint => 'Camí de navegació';

  @override
  String get blockTypeTemplateButtonLabel => 'Botó de plantilla';

  @override
  String get blockTypeTemplateButtonHint => 'Inserir bloc predefinit';

  @override
  String get blockTypeColumnListLabel => 'Columnes';

  @override
  String get blockTypeColumnListHint => 'Disseny en columnes';

  @override
  String get blockTypeEmbedLabel => 'Incrustació web';

  @override
  String get blockTypeEmbedHint => 'YouTube, Figma, Docs…';

  @override
  String get integrationDialogTitleUpdatePermission =>
      'Actualitzar permís d\'integració';

  @override
  String get integrationDialogTitleAllowConnect =>
      'Permetre que aquesta app es connecti';

  @override
  String integrationDialogBodyUpdate(
    Object previousVersion,
    Object integrationVersion,
  ) {
    return 'Aquesta app ja estava aprovada amb la integració $previousVersion i ara sol·licita accés amb la versió $integrationVersion.';
  }

  @override
  String integrationDialogBodyNew(
    Object appName,
    Object appVersion,
    Object integrationVersion,
  ) {
    return '«$appName» vol usar el pont local de Folio amb l\'app versió $appVersion i la integració $integrationVersion.';
  }

  @override
  String get integrationChipLocalhostOnly => 'Només localhost';

  @override
  String get integrationChipRevocableApproval => 'Aprovació revocable';

  @override
  String get integrationChipNoSharedSecret => 'Sense secret compartit';

  @override
  String get integrationChipScopedByAppId => 'Permís per appId';

  @override
  String get integrationMetaPreviouslyApprovedVersion =>
      'Versió anterior aprovada';

  @override
  String get integrationSectionWhatAppCanDo => 'Què podrà fer aquesta app';

  @override
  String get integrationCapEphemeralSessionsTitle =>
      'Obrir sessions locals efímeres';

  @override
  String get integrationCapEphemeralSessionsBody =>
      'Podrà iniciar una sessió temporal per parlar amb el pont local de Folio des d\'aquest dispositiu.';

  @override
  String get integrationCapImportPagesTitle =>
      'Importar i actualitzar les seves pròpies pàgines';

  @override
  String get integrationCapImportPagesBody =>
      'Podrà crear pàgines, llistar-les i actualitzar només les que la mateixa app hagi importat abans.';

  @override
  String get integrationCapCustomEmojisTitle =>
      'Gestionar els seus emojis personalitzats';

  @override
  String get integrationCapCustomEmojisBody =>
      'Podrà llistar, crear, reemplaçar i esborrar només el seu catàleg d\'emojis o icones importades.';

  @override
  String get integrationCapUnlockedVaultTitle =>
      'Treballar només amb la llibreta desbloquejada';

  @override
  String get integrationCapUnlockedVaultBody =>
      'Les peticions només funcionen quan Folio està obert, la llibreta està disponible i la sessió actual segueix activa.';

  @override
  String get integrationSectionWhatStaysBlocked => 'Què seguirà bloquejat';

  @override
  String get integrationBlockNoSeeAllTitle => 'No pot veure tot el contingut';

  @override
  String get integrationBlockNoSeeAllBody =>
      'No obté accés general a la llibreta. Només pot llistar el que ella mateixa ha importat amb el seu appId.';

  @override
  String get integrationBlockNoBypassTitle =>
      'No pot saltar-se el bloqueig ni el xifratge';

  @override
  String get integrationBlockNoBypassBody =>
      'Si la llibreta està bloquejada o no hi ha sessió activa, Folio rebutjarà l\'operació.';

  @override
  String get integrationBlockNoOtherAppsTitle =>
      'No pot tocar dades d\'altres apps';

  @override
  String get integrationBlockNoOtherAppsBody =>
      'Tampoc pot gestionar pàgines importades o emojis registrats per altres apps aprovades.';

  @override
  String get integrationBlockNoRemoteTitle =>
      'No pot entrar des de fora del teu equip';

  @override
  String get integrationBlockNoRemoteBody =>
      'El pont segueix limitat a localhost i aquesta aprovació es pot revocar més tard des d\'Ajustos.';

  @override
  String integrationSnackMarkdownImportDone(Object pageTitle) {
    return 'Importació completada: $pageTitle.';
  }

  @override
  String integrationSnackJsonImportDone(Object pageTitle) {
    return 'Importació JSON completada: $pageTitle.';
  }

  @override
  String integrationSnackPageUpdateDone(Object pageTitle) {
    return 'Actualització d\'integració completada: $pageTitle.';
  }

  @override
  String get markdownImportModeDialogTitle => 'Importar Markdown';

  @override
  String get markdownImportModeDialogBody =>
      'Tria com vols aplicar el fitxer Markdown.';

  @override
  String get markdownImportModeNewPage => 'Pàgina nova';

  @override
  String get markdownImportModeAppend => 'Annexar a l\'actual';

  @override
  String get markdownImportModeReplace => 'Substituir l\'actual';

  @override
  String get markdownImportCouldNotReadPath =>
      'No s\'ha pogut llegir el camí del fitxer.';

  @override
  String markdownImportedBlocks(Object pageTitle, int blockCount) {
    return 'Markdown importat: $pageTitle ($blockCount blocs).';
  }

  @override
  String markdownImportFailedWithError(Object error) {
    return 'No s\'ha pogut importar el Markdown: $error';
  }

  @override
  String get importPage => 'Importar…';

  @override
  String get exportMarkdownFileDialogTitle => 'Exportar pàgina a Markdown';

  @override
  String get markdownExportSuccess => 'Pàgina exportada a Markdown.';

  @override
  String markdownExportFailedWithError(Object error) {
    return 'No s\'ha pogut exportar la pàgina: $error';
  }

  @override
  String get exportPageDialogTitle => 'Exportar pàgina';

  @override
  String get exportPageFormatMarkdown => 'Markdown (.md)';

  @override
  String get exportPageFormatHtml => 'HTML (.html)';

  @override
  String get exportPageFormatTxt => 'Text (.txt)';

  @override
  String get exportPageFormatJson => 'JSON (.json)';

  @override
  String get exportPageFormatPdf => 'PDF (.pdf)';

  @override
  String get exportHtmlFileDialogTitle => 'Exportar pàgina a HTML';

  @override
  String get htmlExportSuccess => 'Pàgina exportada a HTML.';

  @override
  String htmlExportFailedWithError(Object error) {
    return 'No s\'ha pogut exportar la pàgina: $error';
  }

  @override
  String get exportTxtFileDialogTitle => 'Exportar pàgina a text';

  @override
  String get txtExportSuccess => 'Pàgina exportada a text.';

  @override
  String txtExportFailedWithError(Object error) {
    return 'No s\'ha pogut exportar la pàgina: $error';
  }

  @override
  String get exportJsonFileDialogTitle => 'Exportar pàgina a JSON';

  @override
  String get jsonExportSuccess => 'Pàgina exportada a JSON.';

  @override
  String jsonExportFailedWithError(Object error) {
    return 'No s\'ha pogut exportar la pàgina: $error';
  }

  @override
  String get exportPdfFileDialogTitle => 'Exportar pàgina a PDF';

  @override
  String get pdfExportSuccess => 'Pàgina exportada a PDF.';

  @override
  String pdfExportFailedWithError(Object error) {
    return 'No s\'ha pogut exportar la pàgina: $error';
  }

  @override
  String get firebaseUnavailablePublish => 'Firebase no està disponible.';

  @override
  String get signInCloudToPublishWeb =>
      'Inicia sessió al compte al núvol (Ajustos) per publicar.';

  @override
  String get planMissingWebPublish =>
      'El teu pla no inclou publicació web o la subscripció no està activa.';

  @override
  String get publishWebDialogTitle => 'Publicar a la web';

  @override
  String get publishWebSlugLabel => 'URL (slug)';

  @override
  String get publishWebSlugHint => 'la-meva-nota';

  @override
  String get publishWebSlugHelper =>
      'Lletres, números i guions. Quedarà a l\'URL pública.';

  @override
  String get publishWebAction => 'Publicar';

  @override
  String get publishWebEmptySlug => 'Slug buit.';

  @override
  String publishWebSuccessWithUrl(Object url) {
    return 'Publicat: $url';
  }

  @override
  String publishWebFailedWithError(Object error) {
    return 'No s\'ha pogut publicar: $error';
  }

  @override
  String get publishWebMenuLabel => 'Publicar a la web';

  @override
  String get mobileFabDone => 'Fet';

  @override
  String get mobileFabEdit => 'Editar';

  @override
  String get mobileFabAddBlock => 'Bloc';

  @override
  String get mermaidPreviewDialogTitle => 'Diagrama';

  @override
  String get mermaidDiagramSemanticsLabel =>
      'Diagrama Mermaid, toca per ampliar';

  @override
  String get databaseSortAz => 'Ordenar A-Z';

  @override
  String get databaseSortLabel => 'Ordenar';

  @override
  String get databaseFilterAnd => 'I';

  @override
  String get databaseFilterOr => 'O';

  @override
  String get databaseSortDescending => 'Desc';

  @override
  String get databaseNewPropertyDialogTitle => 'Propietat nova';

  @override
  String databaseConfigurePropertyTitle(Object name) {
    return 'Configurar: $name';
  }

  @override
  String get databaseLocalCurrentBadge => 'BD local actual';

  @override
  String databaseRelateRowsTitle(Object name) {
    return 'Relacionar files ($name)';
  }

  @override
  String get databaseBoardNeedsGroupProperty =>
      'Configura una propietat de grup per al tauler.';

  @override
  String get databaseGroupPropertyMissing =>
      'La propietat de grup ja no existeix.';

  @override
  String get databaseCalendarNeedsDateProperty =>
      'Configura una propietat de data per al calendari.';

  @override
  String get databaseNoDatedEvents => 'Sense esdeveniments amb data.';

  @override
  String get databaseConfigurePropertyTooltip => 'Configurar propietat';

  @override
  String get databaseFormulaHintExample =>
      'if(contains(Nom,\"x\"), add(1,2), 0)';

  @override
  String get createAction => 'Crear';

  @override
  String get confirmAction => 'Confirmar';

  @override
  String get confirmRemoteEndpointTitle => 'Confirmar endpoint remot';

  @override
  String get shortcutGlobalSearchKeyChord => 'Ctrl + Maj + F';

  @override
  String get updateChannelRelease => 'Release';

  @override
  String get updateChannelBeta => 'Beta';

  @override
  String get blockActionChooseAudio => 'Triar àudio…';

  @override
  String get blockActionCreateSubpage => 'Crear subpàgina';

  @override
  String get blockActionLinkPage => 'Enllaçar pàgina…';

  @override
  String get defaultNewPageTitle => 'Pàgina nova';

  @override
  String defaultPageDuplicateTitle(Object title) {
    return '$title (còpia)';
  }

  @override
  String aiChatTitleNumbered(int n) {
    return 'Xat $n';
  }

  @override
  String get invalidFolioTemplateFile =>
      'El fitxer no és una plantilla Folio vàlida.';

  @override
  String get templateButtonDefaultLabel => 'Plantilla';

  @override
  String get pageHtmlExportPublishedWithFolio => 'Publicat amb Folio';

  @override
  String get releaseReadinessSemverOk => 'Versió SemVer vàlida';

  @override
  String get releaseReadinessEncryptedVault => 'Llibreta xifrada';

  @override
  String get releaseReadinessAiRemotePolicy => 'Política d\'endpoint d\'IA';

  @override
  String get releaseReadinessVaultUnlocked => 'Llibreta desbloquejada';

  @override
  String get releaseReadinessStableChannel => 'Canal estable seleccionat';

  @override
  String get aiPromptUserMessage => 'Missatge de l\'usuari:';

  @override
  String get aiPromptOriginalMessage => 'Missatge original:';

  @override
  String get aiPromptOriginalUserMessage => 'Missatge original de l\'usuari:';

  @override
  String get customIconImportEmptySource => 'La font de la icona està buida.';

  @override
  String get customIconImportInvalidUrl => 'L\'URL de la icona no és vàlida.';

  @override
  String get customIconImportInvalidSvg => 'El SVG copiat no és vàlid.';

  @override
  String get customIconImportHttpHttpsOnly =>
      'Només s\'admeten URL http o https.';

  @override
  String get customIconImportDataUriMimeList =>
      'Només s\'admeten data:image/svg+xml, data:image/gif, data:image/webp o data:image/png.';

  @override
  String get customIconImportUnsupportedFormat =>
      'Format no compatible. Usa SVG, PNG, GIF o WebP.';

  @override
  String get customIconImportSvgTooLarge =>
      'El SVG és massa gran per importar-lo.';

  @override
  String get customIconImportEmbeddedImageTooLarge =>
      'La imatge incrustada és massa gran per importar-la.';

  @override
  String customIconImportDownloadFailed(Object code) {
    return 'No s\'ha pogut baixar la icona ($code).';
  }

  @override
  String get customIconImportRemoteTooLarge => 'La icona remota és massa gran.';

  @override
  String get customIconImportConnectFailed =>
      'No s\'ha pogut connectar per baixar la icona.';

  @override
  String get customIconImportCertFailed =>
      'Error de certificat en baixar la icona.';

  @override
  String get customIconLabelDefault => 'Icona personalitzada';

  @override
  String get customIconLabelImported => 'Icona importada';

  @override
  String get customIconImportSucceeded => 'Icona importada correctament.';

  @override
  String get customIconClipboardEmpty => 'El porta-retalls està buit.';

  @override
  String get customIconRemoved => 'Icona eliminada.';

  @override
  String get whisperModelTiny => 'Tiny (ràpid)';

  @override
  String get whisperModelBaseQ8 => 'Base q8 (equilibrat)';

  @override
  String get whisperModelSmallQ8 => 'Small q8 (alta precisió, menys disc)';

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
  String get codeLangPlainText => 'Text pla';

  @override
  String settingsAppRevoked(Object appId) {
    return 'App revocada: $appId';
  }

  @override
  String get settingsDeviceRevokedSnack => 'Dispositiu revocat.';

  @override
  String get settingsAiConnectionOk => 'Connexió d\'IA OK';

  @override
  String settingsAiConnectionError(Object error) {
    return 'Error de connexió: $error';
  }

  @override
  String settingsAiListModelsFailed(Object error) {
    return 'No s\'han pogut llistar models: $error';
  }

  @override
  String get folioCloudCallableNotSignedIn =>
      'Has d\'iniciar sessió per trucar Cloud Functions';

  @override
  String get folioCloudCallableUnexpectedResponse =>
      'Resposta inesperada de Cloud Functions';

  @override
  String folioCloudCallableHttpError(int code, Object name) {
    return 'HTTP $code en trucar $name';
  }

  @override
  String get folioCloudCallableNoIdToken =>
      'Sense token d\'ID per a Cloud Functions. Torna a iniciar sessió a Folio Cloud.';

  @override
  String get folioCloudCallableUnexpectedFallback =>
      'Resposta inesperada de la còpia de seguretat de Cloud Functions';

  @override
  String folioCloudCallableHttpAiComplete(int code) {
    return 'HTTP $code en trucar folioCloudAiCompleteHttp';
  }

  @override
  String get cloudAccountEmailMismatch =>
      'El correu no coincideix amb la sessió actual.';

  @override
  String get cloudIdentityInvalidAuthResponse =>
      'Resposta d\'autenticació no vàlida.';

  @override
  String get templateButtonPlaceholderText => 'Text de la plantilla…';

  @override
  String get aiProviderOllamaName => 'Ollama';

  @override
  String get aiProviderLmStudioName => 'LM Studio';

  @override
  String get blockAudioEmptyHint => 'Tria un fitxer d\'àudio';

  @override
  String get blockChildPageTitle => 'Bloc de pàgina';

  @override
  String get blockChildPageNoLink => 'Sense subpàgina enllaçada.';

  @override
  String get mermaidExpandedLoadError =>
      'No s\'ha pogut mostrar el diagrama ampliat.';

  @override
  String get mermaidPreviewTooltip =>
      'Toca per ampliar i fer zoom. PNG via mermaid.ink (servei extern).';

  @override
  String get aiEndpointInvalidUrl => 'URL no vàlida. Usa http://host:port.';

  @override
  String get aiEndpointRemoteNotAllowed =>
      'L\'endpoint remot no està permès sense confirmació.';

  @override
  String get settingsAiSelectProviderFirst =>
      'Selecciona primer un proveïdor d\'IA.';

  @override
  String get releaseReadinessAiSummaryDisabled => 'IA desactivada';

  @override
  String get releaseReadinessAiSummaryQuillCloud =>
      'Folio Cloud IA (sense endpoint local)';

  @override
  String releaseReadinessAiSummaryEndpointOk(Object url) {
    return 'Endpoint vàlid: $url';
  }

  @override
  String get releaseReadinessDetailSemverInvalid =>
      'La versió instal·lada no compleix SemVer.';

  @override
  String get releaseReadinessDetailVaultNotEncrypted =>
      'La llibreta actual no està xifrada.';

  @override
  String get releaseReadinessDetailVaultLocked =>
      'Desbloqueja la llibreta per validar exportació/importació i el flux real.';

  @override
  String get releaseReadinessDetailBetaChannel =>
      'El canal beta d\'actualitzacions està actiu.';

  @override
  String get releaseReadinessReportTitle =>
      'Folio: preparació per al llançament';

  @override
  String releaseReadinessReportInstalledVersion(Object label) {
    return 'Versió instal·lada: $label';
  }

  @override
  String releaseReadinessReportSemver(Object value) {
    return 'SemVer vàlid: $value';
  }

  @override
  String releaseReadinessReportChannel(Object value) {
    return 'Canal d\'actualitzacions: $value';
  }

  @override
  String releaseReadinessReportActiveVault(Object id) {
    return 'Llibreta activa: $id';
  }

  @override
  String releaseReadinessReportVaultPath(Object path) {
    return 'Ruta de la llibreta: $path';
  }

  @override
  String releaseReadinessReportUnlocked(Object value) {
    return 'Llibreta desbloquejada: $value';
  }

  @override
  String releaseReadinessReportEncrypted(Object value) {
    return 'Llibreta xifrada: $value';
  }

  @override
  String releaseReadinessReportAiEnabled(Object value) {
    return 'IA habilitada: $value';
  }

  @override
  String releaseReadinessReportAiPolicy(Object value) {
    return 'Política d\'endpoint IA: $value';
  }

  @override
  String releaseReadinessReportAiDetail(Object detail) {
    return 'Detall IA: $detail';
  }

  @override
  String releaseReadinessReportStatus(Object value) {
    return 'Estat del llançament: $value';
  }

  @override
  String releaseReadinessReportBlockers(int count) {
    return 'Bloquejadors pendents: $count';
  }

  @override
  String releaseReadinessReportWarnings(int count) {
    return 'Advertències pendents: $count';
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
  String get releaseReadinessStatusReady => 'llest';

  @override
  String get releaseReadinessStatusBlocked => 'bloquejat';

  @override
  String get releaseReadinessPolicyOk => 'correcte';

  @override
  String get releaseReadinessPolicyError => 'error';

  @override
  String get settingsSignInFolioCloudSnack => 'Inicia sessió a Folio Cloud.';

  @override
  String get settingsNotSyncedYet => 'Encara sense sincronitzar';

  @override
  String get settingsDeviceNameTitle => 'Nom del dispositiu';

  @override
  String get settingsDeviceNameHintExample => 'Exemple: Pixel de l\'Alejandra';

  @override
  String get settingsPairingModeEnabledTwoMin =>
      'Mode de vinculació actiu durant 2 minuts.';

  @override
  String get settingsPairingEnableModeFirst =>
      'Primer activa el mode de vinculació i després tria un dispositiu detectat.';

  @override
  String get settingsPairingSameEmojisBothDevices =>
      'Activa el mode de vinculació en ambdós dispositius i espera els mateixos 3 emojis.';

  @override
  String get settingsPairingCouldNotStart =>
      'No s\'ha pogut iniciar la vinculació. Activa el mode en ambdós dispositius i espera els mateixos 3 emojis.';

  @override
  String get settingsConfirmPairingTitle => 'Confirmar vinculació';

  @override
  String get settingsPairingCheckOtherDeviceEmojis =>
      'Comprova que a l\'altre dispositiu apareixen aquests mateixos 3 emojis:';

  @override
  String get settingsPairingPopupInstructions =>
      'Aquest popup també apareixerà a l\'altre dispositiu. Per completar l\'enllaç, prem Vincular aquí i després Vincular a l\'altre.';

  @override
  String get settingsLinkDevice => 'Vincular';

  @override
  String get settingsPairingConfirmationSent =>
      'Confirmació enviada. Falta que l\'altre dispositiu premi Vincular al seu popup.';

  @override
  String get settingsResolveConflictsTitle => 'Resoldre conflictes';

  @override
  String get settingsNoPendingConflicts => 'No hi ha conflictes pendents.';

  @override
  String settingsSyncConflictCardSubtitle(
    Object fromPeerId,
    int remotePageCount,
    Object detectedAt,
  ) {
    return 'Origen: $fromPeerId\nPàgines remotes: $remotePageCount\nDetectat: $detectedAt';
  }

  @override
  String get settingsSyncConflictHeading => 'Conflicte de sincronització';

  @override
  String get settingsLocalVersionKeptSnack =>
      'S\'ha conservat la versió local.';

  @override
  String get settingsKeepLocal => 'Mantenir local';

  @override
  String get settingsRemoteVersionAppliedSnack =>
      'S\'ha aplicat la versió remota.';

  @override
  String get settingsCouldNotApplyRemoteSnack =>
      'No s\'ha pogut aplicar la versió remota.';

  @override
  String get settingsAcceptRemote => 'Acceptar remota';

  @override
  String get settingsClose => 'Tancar';

  @override
  String get settingsSectionDeviceSyncNav => 'Sincronització';

  @override
  String get settingsSectionVault => 'Llibreta';

  @override
  String get settingsSectionVaultHeroDescription =>
      'Seguretat en desbloquejar, còpies, programació a disc i gestió de dades en aquest dispositiu.';

  @override
  String get settingsSectionUiWorkspace => 'Interfície i escriptori';

  @override
  String get settingsSectionUiWorkspaceHeroDescription =>
      'Tema, idioma, escala, editor, opcions d\'escriptori i dreceres de teclat.';

  @override
  String get settingsSubsectionVaultBackupImport => 'Còpies i importació';

  @override
  String get settingsSubsectionVaultScheduledLocal =>
      'Còpia programada (local)';

  @override
  String get settingsSubsectionVaultData => 'Dades (zona de perill)';

  @override
  String get folioCloudSubsectionAccount => 'Compte';

  @override
  String get folioCloudSubsectionEncryptedBackups => 'Còpies xifrades (núvol)';

  @override
  String get folioCloudSubsectionPublishing => 'Publicació web';

  @override
  String get settingsFolioCloudSubsectionScheduledCloud =>
      'Còpia programada a Folio Cloud';

  @override
  String get settingsScheduledCloudUploadRequiresSchedule =>
      'Activa primer la còpia programada a Llibreta › Còpia programada (local).';

  @override
  String get settingsSyncHeroTitle => 'Sincronització entre dispositius';

  @override
  String get settingsSyncHeroDescription =>
      'Emparella equips a la xarxa local; el relay només ajuda a negociar la connexió i no envia el contingut del vault.';

  @override
  String get settingsSyncChipPairingCode => 'Codi d\'enllaç';

  @override
  String get settingsSyncChipAutoDiscovery => 'Detecció automàtica';

  @override
  String get settingsSyncChipOptionalRelay => 'Relay opcional';

  @override
  String get settingsSyncEnableTitle =>
      'Activar sincronització entre dispositius';

  @override
  String get settingsSyncSearchingSubtitle =>
      'Cercant dispositius amb Folio obert a la xarxa local...';

  @override
  String settingsSyncDevicesFoundOnLan(int count) {
    return '$count dispositius detectats a la LAN.';
  }

  @override
  String get settingsSyncDisabledSubtitle =>
      'La sincronització està desactivada.';

  @override
  String get settingsSyncRelayTitle => 'Usar relay de senyalització';

  @override
  String get settingsSyncRelaySubtitle =>
      'No envia el contingut del vault, només ajuda a negociar la connexió si falla la LAN.';

  @override
  String get settingsEdit => 'Editar';

  @override
  String get settingsSyncEmojiModeTitle =>
      'Activar mode de vinculació per emojis';

  @override
  String get settingsSyncEmojiModeSubtitle =>
      'Activa\'l en ambdós dispositius per iniciar la vinculació sense escriure codis.';

  @override
  String get settingsSyncPairingStatusTitle => 'Estat del mode de vinculació';

  @override
  String get settingsSyncPairingActiveSubtitle =>
      'Actiu durant 2 minuts. Ja pots iniciar la vinculació des d\'un dispositiu detectat.';

  @override
  String get settingsSyncPairingInactiveSubtitle =>
      'Inactiu. Activa\'l aquí i a l\'altre dispositiu per començar a vincular.';

  @override
  String get settingsSyncLastSyncTitle => 'Última sincronització';

  @override
  String get settingsSyncPendingConflictsTitle => 'Conflictes pendents';

  @override
  String get settingsSyncNoConflictsSubtitle => 'Sense conflictes pendents.';

  @override
  String settingsSyncConflictsNeedReview(int count) {
    return '$count conflictes requereixen revisió manual.';
  }

  @override
  String get settingsResolve => 'Resoldre';

  @override
  String get settingsSyncDiscoveredDevicesTitle => 'Dispositius detectats';

  @override
  String get settingsSyncNoDevicesYetHint =>
      'Encara no s\'han detectat dispositius. Assegura\'t que les dues apps estan obertes a la mateixa xarxa.';

  @override
  String get settingsSyncPeerReadyToLink => 'Llest per vincular.';

  @override
  String get settingsSyncPeerOtherInPairingMode =>
      'L\'altre dispositiu està en mode vinculació. Activa\'l aquí per iniciar l\'enllaç.';

  @override
  String get settingsSyncPeerDetectedLan => 'Detectat a la xarxa local.';

  @override
  String get settingsSyncLinkedDevicesTitle => 'Dispositius vinculats';

  @override
  String get settingsSyncNoLinkedDevicesYet =>
      'Encara no hi ha dispositius enllaçats.';

  @override
  String settingsSyncPeerIdLabel(Object peerId) {
    return 'ID: $peerId';
  }

  @override
  String get settingsRevoke => 'Revocar';

  @override
  String get sidebarPageIconTitle => 'Icona de la pàgina';

  @override
  String get sidebarPageIconPickerHelper =>
      'Tria una icona ràpida, una importada o obre el selector complet.';

  @override
  String get sidebarPageIconCustomEmoji => 'Emoji personalitzat';

  @override
  String get sidebarPageIconRemove => 'Treure';

  @override
  String get sidebarPageIconTabQuick => 'Ràpids';

  @override
  String get sidebarPageIconTabImported => 'Importats';

  @override
  String get sidebarPageIconTabAll => 'Tots';

  @override
  String get sidebarPageIconEmptyImported =>
      'Encara no has importat icones a Ajustos.';

  @override
  String get settingsStripeSubscriptionRefreshed =>
      'Facturació Folio Cloud actualitzada.';

  @override
  String get settingsStripeBillingPortalUnavailable =>
      'Portal de facturació no disponible.';

  @override
  String get settingsCouldNotOpenLink => 'No s\'ha pogut obrir l\'enllaç.';

  @override
  String get settingsStripeCheckoutUnavailable =>
      'Pagament no disponible (configura Stripe al servidor).';

  @override
  String get settingsCloudBackupEnablePlanSnack =>
      'Activa Folio Cloud amb la funció de còpia al núvol inclosa al teu pla.';

  @override
  String get settingsNoActiveVault => 'No hi ha llibreta activa.';

  @override
  String get settingsCloudBackupsNeedPlan =>
      'Necessites Folio Cloud actiu amb còpia al núvol.';

  @override
  String settingsCloudBackupsDialogTitle(int count) {
    return 'Còpies al núvol ($count/10)';
  }

  @override
  String get settingsCloudBackupsEmpty =>
      'Encara no hi ha còpies en aquest compte.';

  @override
  String get settingsCloudBackupDownloadTooltip => 'Descarregar';

  @override
  String get settingsCloudBackupSaveDialogTitle => 'Desar còpia';

  @override
  String get settingsCloudBackupDownloadedSnack => 'Còpia descarregada.';

  @override
  String get settingsPublishedRequiresPlan =>
      'Necessites Folio Cloud amb publicació web activa.';

  @override
  String get settingsPublishedPagesTitle => 'Pàgines publicades';

  @override
  String get settingsPublishedPagesEmpty =>
      'Encara no hi ha pàgines publicades.';

  @override
  String get settingsPublishedDeleteDialogTitle => 'Eliminar publicació?';

  @override
  String get settingsPublishedDeleteDialogBody =>
      'S\'esborrarà l\'HTML públic i l\'enllaç deixarà de funcionar.';

  @override
  String get settingsPublishedRemovedSnack => 'Publicació eliminada.';

  @override
  String get settingsCouldNotReadInstalledVersion =>
      'No s\'ha pogut llegir la versió instal·lada.';

  @override
  String settingsCouldNotOpenReleaseNotes(Object error) {
    return 'No s\'han pogut obrir les notes de la versió: $error';
  }

  @override
  String settingsUpdateFailed(Object error) {
    return 'No s\'ha pogut actualitzar: $error';
  }

  @override
  String get settingsSessionEndedSnack => 'Sessió tancada';

  @override
  String get settingsLabelYes => 'Sí';

  @override
  String get settingsLabelNo => 'No';

  @override
  String get settingsSecurityEncryptedHeroDescription =>
      'Desbloqueig ràpid, passkey, bloqueig automàtic i contrasenya mestra del vault xifrat.';

  @override
  String get settingsUnencryptedVaultTitle => 'Vault sense xifrar';

  @override
  String get settingsUnencryptedVaultChipDataOnDisk => 'Dades al disc';

  @override
  String get settingsUnencryptedVaultChipEncryptionAvailable =>
      'Xifrat disponible';

  @override
  String get settingsAppearanceChipTheme => 'Tema';

  @override
  String get settingsAppearanceChipZoom => 'Zoom';

  @override
  String get settingsAppearanceChipLanguage => 'Idioma';

  @override
  String get settingsAppearanceChipEditorWorkspace => 'Editor i espai';

  @override
  String get settingsWindowsScaleFollowTitle => 'Seguir l\'escala de Windows';

  @override
  String get settingsWindowsScaleFollowSubtitle =>
      'Utilitza automàticament l\'escala del sistema a Windows.';

  @override
  String get settingsInterfaceZoomTitle => 'Zoom de la interfície';

  @override
  String get settingsInterfaceZoomSubtitle =>
      'Augmenta o redueix la mida general de l\'app.';

  @override
  String get settingsUiZoomReset => 'Restablir';

  @override
  String get settingsEditorSubsection => 'Editor';

  @override
  String get settingsEditorContentWidthTitle => 'Amplada del contingut';

  @override
  String get settingsEditorContentWidthSubtitle =>
      'Defineix quanta amplada ocupen els blocs a l\'editor.';

  @override
  String get settingsEnterCreatesNewBlockTitle => 'Retorn crea un bloc nou';

  @override
  String get settingsEnterCreatesNewBlockSubtitleWhenEnabled =>
      'Desactiva perquè Retorn insereixi un salt de línia.';

  @override
  String get settingsEnterCreatesNewBlockSubtitleWhenDisabled =>
      'Ara Retorn insereix un salt de línia. Maj+Retorn també funciona.';

  @override
  String get settingsWorkspaceSubsection => 'Espai de treball';

  @override
  String get settingsCustomIconsTitle => 'Icones personalitzades';

  @override
  String get settingsCustomIconsDescription =>
      'Importa una URL PNG, GIF o WebP, o un data:image compatible copiat des de llocs com notionicons.so. Després la podràs usar com a icona de pàgina o callout.';

  @override
  String settingsCustomIconsSavedCount(int count) {
    return '$count desats';
  }

  @override
  String get settingsCustomIconsChipUrl => 'URL PNG, GIF o WebP';

  @override
  String get settingsCustomIconsChipDataImage => 'data:image/*';

  @override
  String get settingsCustomIconsChipPaste => 'Enganxar des del porta-retalls';

  @override
  String get settingsCustomIconsImportTitle => 'Importar icona nova';

  @override
  String get settingsCustomIconsImportSubtitle =>
      'Pots posar-li nom i enganxar la font manualment o portar-la directament del porta-retalls.';

  @override
  String get settingsCustomIconsFieldNameLabel => 'Nom';

  @override
  String get settingsCustomIconsFieldNameHint => 'Opcional';

  @override
  String get settingsCustomIconsFieldSourceLabel => 'URL o data:image';

  @override
  String get settingsCustomIconsFieldSourceHint =>
      'https://…gif | …webp | …png o data:image/…';

  @override
  String get settingsCustomIconsImportButton => 'Importar icona';

  @override
  String get settingsCustomIconsFromClipboard => 'Des del porta-retalls';

  @override
  String get settingsCustomIconsLibraryTitle => 'Biblioteca';

  @override
  String get settingsCustomIconsLibrarySubtitle =>
      'Llestos per usar a tota l\'app';

  @override
  String get settingsCustomIconsEmpty => 'Encara no has importat icones.';

  @override
  String get settingsCustomIconsDeleteTooltip => 'Eliminar icona';

  @override
  String get settingsCustomIconsReferenceCopiedSnack => 'Referència copiada.';

  @override
  String get settingsCustomIconsCopyToken => 'Copiar token';

  @override
  String get settingsAiHeroQuillWithLocalAlt =>
      'La IA s\'executa a Quill Cloud (subscripció amb IA al núvol o tinta comprada). Tria un altre proveïdor a sota per Ollama o LM Studio en local.';

  @override
  String get settingsAiHeroQuillCloudOnly =>
      'La IA s\'executa a Quill Cloud (subscripció amb IA al núvol o tinta comprada).';

  @override
  String get settingsAiHeroLocalDefault =>
      'Connecta Ollama o LM Studio en local; l\'assistent usa el model i el context que configuris aquí.';

  @override
  String get settingsAiHeroQuillMobileOnly =>
      'En aquest dispositiu Quill només pot usar Quill Cloud. Tria Quill Cloud com a proveïdor quan vulguis activar la IA.';

  @override
  String get settingsAiChipCloud => 'Al núvol';

  @override
  String get settingsAiSnackFirebaseUnavailableBuild =>
      'Firebase no està disponible en aquesta compilació.';

  @override
  String get settingsAiSnackSignInCloudAccount =>
      'Inicia sessió al compte al núvol (Ajustos).';

  @override
  String settingsAiProviderSwitchFailed(Object error) {
    return 'No s\'ha pogut canviar el proveïdor d\'IA: $error';
  }

  @override
  String get settingsAboutHeroDescription =>
      'Versió instal·lada, origen d\'actualitzacions i comprovació manual de novetats.';

  @override
  String get settingsOpenReleaseNotes => 'Veure notes de la versió';

  @override
  String get settingsUpdateChannelLabel => 'Canal';

  @override
  String get settingsUpdateChannelRelease => 'Release';

  @override
  String get settingsUpdateChannelBeta => 'Beta';

  @override
  String get settingsDataHeroDescription =>
      'Accions permanents sobre fitxers locals. Fes una còpia de seguretat abans d\'esborrar.';

  @override
  String get settingsDangerZoneTitle => 'Zona de perill';

  @override
  String get settingsDesktopHeroDescription =>
      'Dreceres globals, safata del sistema i comportament de la finestra a l\'escriptori.';

  @override
  String get settingsShortcutsHeroDescription =>
      'Combinacions només dins de Folio. Prova una tecla abans de desar-la.';

  @override
  String get settingsShortcutsTestChip => 'Provar';

  @override
  String get settingsIntegrationsChipApprovedPermissions => 'Permisos aprovats';

  @override
  String get settingsIntegrationsChipRevocableAccess => 'Accés revocable';

  @override
  String get settingsIntegrationsChipExternalApps => 'Apps externes';

  @override
  String get settingsIntegrationsActiveConnectionsTitle => 'Connexions actives';

  @override
  String get settingsIntegrationsActiveConnectionsSubtitle =>
      'Apps que ja poden interactuar amb Folio';

  @override
  String get settingsViewInkUsageTable => 'Veure taula de consum';

  @override
  String get settingsCloudInkUsageTableTitle =>
      'Taula de consum de gotes (Quill Cloud)';

  @override
  String get settingsCloudInkUsageTableIntro =>
      'Cost base per acció. Es poden aplicar suplements per prompts llargs i per tokens de sortida.';

  @override
  String get settingsCloudInkDrops => 'gotes';

  @override
  String get settingsCloudInkTableCachedNotice =>
      'Mostrant taula en memòria cau local (sense connexió al backend).';

  @override
  String get settingsCloudInkOpRewriteBlock => 'Reescriure bloc';

  @override
  String get settingsCloudInkOpSummarizeSelection => 'Resumir selecció';

  @override
  String get settingsCloudInkOpExtractTasks => 'Extreure tasques';

  @override
  String get settingsCloudInkOpSummarizePage => 'Resumir pàgina';

  @override
  String get settingsCloudInkOpGenerateInsert => 'Generar inserció';

  @override
  String get settingsCloudInkOpGeneratePage => 'Generar pàgina';

  @override
  String get settingsCloudInkOpChatTurn => 'Torn de xat';

  @override
  String get settingsCloudInkOpAgentMain => 'Execució d\'agent';

  @override
  String get settingsCloudInkOpAgentFollowup => 'Seguiment d\'agent';

  @override
  String get settingsCloudInkOpEditPagePanel => 'Edició de pàgina (panell)';

  @override
  String get settingsCloudInkOpDefault => 'Operació per defecte';

  @override
  String get settingsDesktopRailSubtitle =>
      'Tria una categoria de la llista o desplaça\'t pel contingut.';

  @override
  String get settingsCloudInkViewTableButton => 'Veure taula';

  @override
  String get settingsCloudInkHostedAiQuillCloudHint =>
      'Preus de referència per a IA al núvol a Quill Cloud.';

  @override
  String get vaultStarterHomeTitle => 'Comença aquí';

  @override
  String get vaultStarterHomeHeading => 'El teu quadern ja està llest';

  @override
  String get vaultStarterHomeIntro =>
      'Folio organitza les pàgines en un arbre, edita el contingut per blocs i manté les dades en aquest dispositiu. Aquesta mini guia et dona un mapa ràpid del que pots fer des del primer minut.';

  @override
  String get vaultStarterHomeCallout =>
      'Pots esborrar, reanomenar o moure aquestes pàgines quan vulguis. Són només una base per arrencar més ràpid.';

  @override
  String get vaultStarterHomeSectionTips => 'El més útil per començar';

  @override
  String get vaultStarterHomeBulletSlash =>
      'Prem / dins d\'un paràgraf per inserir encapçalaments, llistes, taules, blocs de codi, Mermaid i més.';

  @override
  String get vaultStarterHomeBulletSidebar =>
      'Usa el panell lateral per crear pàgines i subpàgines, i reorganitza l\'arbre segons la teva manera de treballar.';

  @override
  String get vaultStarterHomeBulletSettings =>
      'Obre Ajustos per activar IA, configurar còpia de seguretat, canviar idioma o afegir desbloqueig ràpid.';

  @override
  String get vaultStarterHomeTodo1 => 'Crear la meva primera pàgina de treball';

  @override
  String get vaultStarterHomeTodo2 =>
      'Provar el menú / per inserir un bloc nou';

  @override
  String get vaultStarterHomeTodo3 =>
      'Revisar Ajustos i decidir si vull activar Quill o un mètode de desbloqueig ràpid';

  @override
  String get vaultStarterCapabilitiesTitle => 'Què pot fer Folio';

  @override
  String get vaultStarterCapabilitiesSectionMain => 'Capacitats principals';

  @override
  String get vaultStarterCapabilitiesBullet1 =>
      'Prendre notes amb estructura lliure amb paràgrafs, títols, llistes, checklists, cites i divisors.';

  @override
  String get vaultStarterCapabilitiesBullet2 =>
      'Treballar amb blocs especials com taules, bases de dades, fitxers, àudio, vídeo, embeds i diagrames Mermaid.';

  @override
  String get vaultStarterCapabilitiesBullet3 =>
      'Cercar contingut, revisar l\'historial de pàgina i mantenir revisions dins del mateix quadern.';

  @override
  String get vaultStarterCapabilitiesBullet4 =>
      'Exportar o importar dades, incloent còpia del quadern i importació des de Notion.';

  @override
  String get vaultStarterCapabilitiesSectionShortcuts => 'Dreceres ràpides';

  @override
  String get vaultStarterCapabilitiesShortcutN =>
      'Ctrl+N crea una pàgina nova.';

  @override
  String get vaultStarterCapabilitiesShortcutSearch =>
      'Ctrl+K o Ctrl+F obre la cerca.';

  @override
  String get vaultStarterCapabilitiesShortcutSettings =>
      'Ctrl+, obre Ajustos i Ctrl+L bloqueja el quadern.';

  @override
  String get vaultStarterCapabilitiesAiCallout =>
      'La IA no s\'activa per defecte. Si uses Quill, la configures a Ajustos i tries proveïdor, model i permisos de context.';

  @override
  String get vaultStarterQuillTitle => 'Quill i privacitat';

  @override
  String get vaultStarterQuillSectionWhat => 'Què pot fer Quill';

  @override
  String get vaultStarterQuillBullet1 =>
      'Resumir, reescriure o expandir el contingut d\'una pàgina.';

  @override
  String get vaultStarterQuillBullet2 =>
      'Respondre dubtes sobre blocs, dreceres i formes d\'organitzar les teves notes a Folio.';

  @override
  String get vaultStarterQuillBullet3 =>
      'Treballar amb la pàgina oberta com a context o amb diverses pàgines que seleccionis com a referència.';

  @override
  String get vaultStarterQuillSectionPrivacy => 'Privacitat i seguretat';

  @override
  String get vaultStarterQuillPrivacyBody =>
      'Les teves pàgines viuen en aquest dispositiu. Si habilites IA, revisa quin context comparteixes i amb quin proveïdor. Si oblides la contrasenya mestra d\'un quadern xifrat, Folio no la pot recuperar.';

  @override
  String get vaultStarterQuillBackupCallout =>
      'Fes una còpia del quadern quan tinguis contingut important. La còpia conserva dades i adjunts, però no transfereix Hello ni passkeys entre dispositius.';

  @override
  String get vaultStarterQuillMermaidCaption => 'Prova ràpida de Mermaid:';

  @override
  String get vaultStarterQuillMermaidSource =>
      'graph TD\nInici[Crear quadern] --> Organitzar[Organitzar pàgines]\nOrganitzar --> Escriure[Escriure i enllaçar idees]\nEscriure --> Revisar[Cercar, revisar i millorar]';
}
