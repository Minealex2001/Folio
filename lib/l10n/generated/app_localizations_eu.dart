// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Basque (`eu`).
class AppLocalizationsEu extends AppLocalizations {
  AppLocalizationsEu([String locale = 'eu']) : super(locale);

  @override
  String get appTitle => 'Folio';

  @override
  String get loading => 'Kargatzen…';

  @override
  String get newVault => 'Gorde-leku berria';

  @override
  String stepOfTotal(int current, int total) {
    return '$total(e)tik $current. urratsa';
  }

  @override
  String get back => 'Atzera';

  @override
  String get continueAction => 'Jarraitu';

  @override
  String get cancel => 'Utzi';

  @override
  String get retry => 'Saiatu berriro';

  @override
  String get settings => 'Ezarpenak';

  @override
  String get lockNow => 'Blokeatu';

  @override
  String get pageHistory => 'Orrialdearen historia';

  @override
  String get untitled => 'Izenbururik gabea';

  @override
  String get noPages => 'Orrialderik ez';

  @override
  String get createPage => 'Sortu orrialdea';

  @override
  String get selectPage => 'Hautatu orrialde bat';

  @override
  String get saveInProgress => 'Gordetzen…';

  @override
  String get savePending => 'Gordetzeko zain';

  @override
  String get savingVaultTooltip => 'Gorde-leku enkriptatua diskoan gordetzen…';

  @override
  String get autosaveSoonTooltip => 'Gordetze automatikoa une batean…';

  @override
  String get welcomeTitle => 'Ongi etorri';

  @override
  String get welcomeBody =>
      'Foliok gailu honetan bakarrik gordetzen ditu zure orrialdeak, pasahitz nagusi batekin enkriptatuta. Ahazten baduzu, ezingo ditugu zure datuak berreskuratu.\n\nEz dago hodeiko sinkronizaziorik.';

  @override
  String get createNewVault => 'Sortu gorde-leku berria';

  @override
  String get importBackupZip => 'Inportatu babeskopia (.zip)';

  @override
  String get importBackupTitle => 'Inportatu babeskopia';

  @override
  String get importBackupBody =>
      'Fitxategiak beste gailuko datu enkriptatu berdinak ditu. Babeskopia hori sortzeko erabilitako pasahitz nagusia behar duzu.\n\nSarbide-gakoak (passkeys) eta desblokeatze azkarra (Hello) ez daude barne eta ez dira transferigarriak; geroago konfigura ditzakezu Ezarpenetan.';

  @override
  String get chooseZipFile => 'Hautatu .zip fitxategia';

  @override
  String get changeFile => 'Aldatu fitxategia';

  @override
  String get backupPasswordLabel => 'Babeskopiaren pasahitza';

  @override
  String get backupPlainNoPasswordHint =>
      'Babeskopia hau ez dago enkriptatuta. Ez da pasahitzik behar inportatzeko.';

  @override
  String get importVault => 'Inportatu gorde-lekua';

  @override
  String get masterPasswordTitle => 'Zure pasahitz nagusia';

  @override
  String masterPasswordHint(int min) {
    return 'Gutxienez $min karaktere. Folio irekitzen duzun bakoitzean erabiliko duzu.';
  }

  @override
  String get createStarterPagesTitle => 'Sortu hasierako laguntza-orriak';

  @override
  String get createStarterPagesBody =>
      'Adibideak, lasterbideak eta Folioren gaitasunak biltzen dituen gida txiki bat gehitzen du. Orrialde horiek geroago ezaba ditzakezu.';

  @override
  String get passwordLabel => 'Pasahitza';

  @override
  String get confirmPasswordLabel => 'Berretsi pasahitza';

  @override
  String get next => 'Hurrengoa';

  @override
  String get readyTitle => 'Dena prest';

  @override
  String get readyBody =>
      'Gorde-leku enkriptatu bat sortuko da gailu honetan. Geroago, Windows Hello, biometria edo sarbide-gako bat gehitu ahal izango duzu desblokeatze azkarragoa izateko (Ezarpenak).';

  @override
  String get quillIntroTitle => 'Ezagutu Quill';

  @override
  String get quillIntroBody =>
      'Quill Folioren laguntzaile integratua da. Zure orrialdeak idazten, editatzen eta ulertzen lagun zaitzake, eta aplikazioa erabiltzeari buruzko galderak erantzun ditzake.';

  @override
  String get quillIntroCapabilityWrite =>
      'Zure orrialdeen barruko edukia zirriborratu, laburtu edo berridatzi dezake.';

  @override
  String get quillIntroCapabilityExplain =>
      'Foliori, lasterbideei, blokeei eta oharrak nola antolatu buruzko galderak ere erantzuten ditu.';

  @override
  String get quillIntroCapabilityContext =>
      'Uneko orrialdea testuinguru gisa erabiltzen utz diezaiokezu, edo erreferentziazko hainbat orrialde hauta ditzakezu.';

  @override
  String get quillIntroCapabilityExamples =>
      'Zatirik onena: hitz egin iezaiozu modu naturalean eta Quillek erabakiko du erantzun ala editatu behar duen.';

  @override
  String get quillIntroExamplesTitle => 'Adibide azkarrak';

  @override
  String get quillIntroExampleOne => 'Laburtu orrialde hau hiru puntutan.';

  @override
  String get quillIntroExampleTwo => 'Aldatu izenburua eta hobetu sarrera.';

  @override
  String get quillIntroExampleThree =>
      'Nola gehitzen dut irudi bat edo taula bat?';

  @override
  String get quillIntroFootnote =>
      'Adimen Artifiziala oraindik gaituta ez badago, geroago aktiba dezakezu. Sarrera hau Quill erabiltzen duzunean zer egin dezakeen ulertzeko dago hemen.';

  @override
  String get createVault => 'Sortu gorde-lekua';

  @override
  String minCharactersError(int min) {
    return 'Gutxienez $min karaktere.';
  }

  @override
  String get passwordMismatchError => 'Pasahitzak ez datoz bat.';

  @override
  String get passwordMustBeStrongError =>
      'Pasahitzak sendoa izan behar du jarraitzeko.';

  @override
  String get passwordStrengthLabel => 'Indarra';

  @override
  String get passwordStrengthVeryWeak => 'Oso ahula';

  @override
  String get passwordStrengthWeak => 'Ahula';

  @override
  String get passwordStrengthFair => 'Onargarria';

  @override
  String get passwordStrengthStrong => 'Sendoa';

  @override
  String get showPassword => 'Erakutsi pasahitza';

  @override
  String get hidePassword => 'Ezkutatu pasahitza';

  @override
  String get chooseZipError => 'Hautatu .zip fitxategi bat.';

  @override
  String get enterBackupPasswordError => 'Sartu babeskopiaren pasahitza.';

  @override
  String importFailedError(Object error) {
    return 'Ezin izan da inportatu: $error';
  }

  @override
  String createVaultFailedError(Object error) {
    return 'Ezin izan da gorde-lekua sortu: $error';
  }

  @override
  String get encryptedVault => 'Gorde-leku enkriptatua';

  @override
  String get unlock => 'Desblokeatu';

  @override
  String get quickUnlock => 'Hello / biometria';

  @override
  String get passkey => 'Sarbide-gakoa';

  @override
  String get unlockFailed => 'Pasahitz okerra edo gorde-leku kaltetua.';

  @override
  String get appearance => 'Itxura';

  @override
  String get security => 'Segurtasuna';

  @override
  String get vaultBackup => 'Gorde-lekuaren babeskopia';

  @override
  String get data => 'Datuak';

  @override
  String get systemTheme => 'Sistemarena';

  @override
  String get lightTheme => 'Argia';

  @override
  String get darkTheme => 'Iluna';

  @override
  String get language => 'Hizkuntza';

  @override
  String get useSystemLanguage => 'Erabili sistemaren hizkuntza';

  @override
  String get spanishLanguage => 'Gaztelania';

  @override
  String get englishLanguage => 'Ingelesa';

  @override
  String get brazilianPortugueseLanguage => 'Portugesa (Brasil)';

  @override
  String get catalanLanguage => 'Katalana';

  @override
  String get galicianLanguage => 'Galiziera';

  @override
  String get basqueLanguage => 'Euskara';

  @override
  String get active => 'Aktiboa';

  @override
  String get inactive => 'Inaktiboa';

  @override
  String get remove => 'Kendu';

  @override
  String get enable => 'Gaitu';

  @override
  String get register => 'Erregistratu';

  @override
  String get revoke => 'Indargabetu';

  @override
  String get save => 'Gorde';

  @override
  String get delete => 'Ezabatu';

  @override
  String get rename => 'Aldatu izena';

  @override
  String get change => 'Aldatu';

  @override
  String get importAction => 'Inportatu';

  @override
  String get masterPassword => 'Pasahitz nagusia';

  @override
  String get confirmIdentity => 'Berretsi nortasuna';

  @override
  String get quickUnlockTitle => 'Desblokeatze azkarra (Hello / biometria)';

  @override
  String get passkeyThisDevice => 'WebAuthn gailu honetan';

  @override
  String get lockOnMinimize => 'Blokeatu minimizatzean';

  @override
  String get changeMasterPassword => 'Aldatu pasahitz nagusia';

  @override
  String get requiresCurrentPassword => 'Uneko pasahitza behar du';

  @override
  String get lockAutoByInactivity =>
      'Blokeatze automatikoa jarduerarik gabe egotean';

  @override
  String minutesShort(int minutes) {
    return '$minutes min';
  }

  @override
  String get settingsAppearanceHint =>
      'Kolore nagusiak Windows-en nabarmentze-kolorea jarraitzen du eskuragarri dagoenean.';

  @override
  String get backupFilePasswordLabel => 'Babeskopia fitxategiaren pasahitza';

  @override
  String get backupFilePasswordHelper =>
      'Erabili babeskopia hau sortzeko erabilitako pasahitz nagusia, ez beste gailu batekoa.';

  @override
  String get backupPasswordDialogTitle => 'Babeskopiaren pasahitza';

  @override
  String get currentPasswordLabel => 'Uneko pasahitza';

  @override
  String get newPasswordLabel => 'Pasahitz berria';

  @override
  String get confirmNewPasswordLabel => 'Berretsi pasahitz berria';

  @override
  String passwordStrengthWithValue(Object value) {
    return 'Indarra: $value';
  }

  @override
  String get fillAllFieldsError => 'Bete eremu guztiak.';

  @override
  String get newPasswordsMismatchError => 'Pasahitz berriak ez datoz bat.';

  @override
  String get newPasswordMustBeStrongError =>
      'Pasahitz berriak sendoa izan behar du.';

  @override
  String get newPasswordMustDifferError =>
      'Pasahitz berriak ezberdina izan behar du.';

  @override
  String get incorrectPasswordError => 'Pasahitz okerra.';

  @override
  String get useHelloBiometrics => 'Erabili Hello / biometria';

  @override
  String get usePasskey => 'Erabili sarbide-gakoa';

  @override
  String get quickUnlockEnabledSnack => 'Desblokeatze azkarra gaituta';

  @override
  String get quickUnlockDisabledSnack => 'Desblokeatze azkarra desgaituta';

  @override
  String get quickUnlockEnableFailed =>
      'Ezin izan da desblokeatze azkarra gaitu.';

  @override
  String get passkeyRevokeConfirmTitle => 'Sarbide-gakoa kendu?';

  @override
  String get passkeyRevokeConfirmBody =>
      'Pasahitz nagusia beharko duzu desblokeatzeko gailu honetan sarbide-gako berri bat erregistratu arte.';

  @override
  String get passkeyRegisteredSnack => 'Sarbide-gakoa erregistratuta';

  @override
  String get passkeyRevokedSnack => 'Sarbide-gakoa indargabetuta';

  @override
  String get masterPasswordUpdatedSnack => 'Pasahitz nagusia eguneratuta';

  @override
  String get backupSavedSuccessSnack => 'Babeskopia ongi gorde da.';

  @override
  String exportFailedError(Object error) {
    return 'Ezin izan da esportatu: $error';
  }

  @override
  String importFailedGenericError(Object error) {
    return 'Ezin izan da inportatu: $error';
  }

  @override
  String wipeFailedError(Object error) {
    return 'Ezin izan da gorde-lekua ezabatu: $error';
  }

  @override
  String get filePathReadError => 'Ezin izan da fitxategiaren bidea irakurri.';

  @override
  String get importedVaultSuccessSnack =>
      'Gorde-lekua inportatuta. Alboko barrako gorde-leku aldatzailean agertuko da; unekoak aldaketarik gabe jarraitzen du.';

  @override
  String get exportVaultDialogTitle => 'Esportatu gorde-lekuaren babeskopia';

  @override
  String get exportVaultDialogBody =>
      'Babeskopia-fitxategi bat sortzeko, berretsi zure nortasuna unean desblokeatuta dagoen gorde-lekuarekin.';

  @override
  String get verifyAndExport => 'Egiaztatu eta esportatu';

  @override
  String get saveVaultBackupDialogTitle => 'Gorde gorde-lekuaren babeskopia';

  @override
  String get importVaultDialogTitle => 'Inportatu gorde-lekuaren babeskopia';

  @override
  String get importVaultDialogBody =>
      'Gorde-leku berri bat gehituko da fitxategitik. Unean irekita duzun gorde-lekua ez da ezabatuko ezta aldatuko ere.\n\nFitxategiaren pasahitza inportatutako gorde-lekuaren pasahitza izango da (gorde-lekuz aldatu ondoren irekitzean erabiltzen dena).\n\nSarbide-gakoak eta desblokeatze azkarra ez daude babeskopietan barne eta ez dira transferigarriak; geroago konfigura ditzakezu gorde-leku horretarako.\n\nJarraitu nahi duzu?';

  @override
  String get verifyAndContinue => 'Egiaztatu eta jarraitu';

  @override
  String get verifyAndDelete => 'Egiaztatu pasahitzarekin eta ezabatu';

  @override
  String get importIdentityBody =>
      'Frogatu zeu zarela unean desblokeatuta dagoen gorde-lekuarekin inportatu aurretik.';

  @override
  String get wipeVaultDialogTitle => 'Ezabatu gorde-lekua';

  @override
  String get wipeVaultDialogBody =>
      'Orrialde guztiak ezabatuko dira eta pasahitz nagusiak balioa galduko du. Ekintza hau ezin da desegin.\n\nZiur zaude jarraitu nahi duzulakoan?';

  @override
  String get wipeIdentityBody =>
      'Gorde-lekua ezabatzeko, frogatu zeure nortasuna.';

  @override
  String get exportZipTitle => 'Esportatu babeskopia (.zip)';

  @override
  String get exportZipSubtitle =>
      'Pasahitza, Hello edo sarbide-gakoa uneko gorde-lekutik';

  @override
  String get importZipTitle => 'Inportatu babeskopia (.zip)';

  @override
  String get importZipSubtitle =>
      'Gorde-leku berri bat gehitzen du · uneko nortasuna + fitxategiaren pasahitza';

  @override
  String get backupInfoBody =>
      'Fitxategiak diskoko datu enkriptatu berdinak ditu (vault.keys eta vault.bin), edukia agerian utzi gabe. Erantsitako irudiak dauden bezala sartzen dira.\n\nSarbide-gakoak eta desblokeatze azkarra ez daude babeskopietan eta ez dira gailu batetik bestera pasatzen; berriro konfigura ditzakezu inportatutako gorde-leku bakoitzerako.\n\nInportatzeak gorde-leku berri bat gehitzen du; ez du unean irekita dagoena ordezkatzen.';

  @override
  String get wipeCardTitle => 'Ezabatu gorde-lekua eta hasi berriro';

  @override
  String get wipeCardSubtitle => 'Pasahitza, Hello edo sarbide-gakoa behar du.';

  @override
  String get switchVaultTooltip => 'Aldatu gorde-lekuz';

  @override
  String get switchVaultTitle => 'Aldatu gorde-lekuz';

  @override
  String get switchVaultBody =>
      'Gorde-lekuaren saio hau itxi egingo da eta beste gorde-lekua bere pasahitzarekin, Hello-rekin edo sarbide-gakoarekin desblokeatu beharko duzu (han konfiguratuta badago).';

  @override
  String get renameVaultTitle => 'Aldatu gorde-lekuaren izena';

  @override
  String get nameLabel => 'Izena';

  @override
  String get deleteOtherVaultTitle => 'Ezabatu beste gorde-leku bat';

  @override
  String get deleteVaultConfirmTitle => 'Ezabatu gorde-lekua?';

  @override
  String deleteVaultConfirmBody(Object name) {
    return '«$name» gorde-lekua erabat ezabatuko da. Hau ezin da desegin.';
  }

  @override
  String get vaultDeletedSnack => 'Gorde-lekua ezabatuta.';

  @override
  String get noOtherVaultsSnack => 'Ez dago ezabatzeko beste gorde-lekurik.';

  @override
  String get addVault => 'Gehitu gorde-lekua';

  @override
  String get renameActiveVault => 'Aldatu gorde-leku aktiboaren izena';

  @override
  String get deleteOtherVault => 'Ezabatu beste gorde-leku bat…';

  @override
  String get activeVaultLabel => 'Gorde-leku aktiboa';

  @override
  String get sidebarVaultsLoading => 'Gorde-lekuak kargatzen…';

  @override
  String get sidebarVaultsEmpty => 'Ez dago gorde-lekurik eskuragarri';

  @override
  String get forceSyncTooltip => 'Behartu sinkronizazioa';

  @override
  String get searchDialogFooterHint =>
      'Sartu-k nabarmendutako emaitza irekitzen du · Ctrl+↑ / Ctrl+↓ nabigatzeko · Esc itxi';

  @override
  String get searchFilterTasks => 'Atazak';

  @override
  String get searchRecentQueries => 'Azken bilaketak';

  @override
  String get searchShortcutsHelpTooltip => 'Teklatuko lasterbideak';

  @override
  String get searchShortcutsHelpTitle => 'Bilaketa orokorra';

  @override
  String get searchShortcutsHelpBody =>
      'Sartu: ireki nabarmendutako emaitza\nCtrl+↑ edo Ctrl+↓: aurreko / hurrengo emaitza\nEsc: itxi';

  @override
  String get renamePageTitle => 'Aldatu orrialdearen izena';

  @override
  String get titleLabel => 'Izenburua';

  @override
  String get rootPage => 'Erroa';

  @override
  String movePageTitle(Object title) {
    return 'Mugitu “$title”';
  }

  @override
  String get subpage => 'Azpiorrialdea';

  @override
  String get move => 'Mugitu';

  @override
  String get pages => 'Orrialdeak';

  @override
  String get pageOutlineTitle => 'Eskema';

  @override
  String get pageOutlineEmpty => 'Gehitu izenburuak (H1–H3) eskema osatzeko.';

  @override
  String get showPageOutline => 'Erakutsi eskema';

  @override
  String get hidePageOutline => 'Ezkutatu eskema';

  @override
  String get tocBlockTitle => 'Edukien aurkibidea';

  @override
  String get showSidebar => 'Erakutsi alboko barra';

  @override
  String get hideSidebar => 'Ezkutatu alboko barra';

  @override
  String get resizeSidebarHandle => 'Aldatu alboko barraren tamaina';

  @override
  String get resizeSidebarHandleHint =>
      'Arrastatu horizontalki alboko barraren zabalera aldatzeko';

  @override
  String get resizeAiPanelHeightHandle => 'Aldatu laguntzailearen altuera';

  @override
  String get resizeAiPanelHeightHandleHint =>
      'Arrastatu bertikalki laguntzailearen panelaren altuera aldatzeko';

  @override
  String get sidebarAutoRevealTitle => 'Erakutsi alboko barra ertzetik';

  @override
  String get sidebarAutoRevealSubtitle =>
      'Alboko barra ezkutatuta dagoenean, mugitu erakuslea ezkerreko ertzeraino aldi baterako erakusteko.';

  @override
  String get newRootPageTooltip => 'Orrialde berria (erroa)';

  @override
  String get blockOptions => 'Blokearen aukerak';

  @override
  String get meetingNoteTitle => 'Bilerako oharra';

  @override
  String get meetingNoteDesktopOnly => 'Mahaigainean bakarrik erabilgarri.';

  @override
  String get meetingNoteStartRecording => 'Hasi grabazioa';

  @override
  String get meetingNotePreparing => 'Prestatzen…';

  @override
  String get meetingNoteTranscriptionLanguage => 'Transkripzio-hizkuntza';

  @override
  String get meetingNoteLangAuto => 'Automatikoa';

  @override
  String get meetingNoteLangEs => 'Gaztelania';

  @override
  String get meetingNoteLangEn => 'Ingelesa';

  @override
  String get meetingNoteLangPt => 'Portugesa';

  @override
  String get meetingNoteLangFr => 'Frantsesa';

  @override
  String get meetingNoteLangIt => 'Italiera';

  @override
  String get meetingNoteLangDe => 'Alemana';

  @override
  String get meetingNoteDevicesInSettings =>
      'Sarrera/irteera gailuak Ezarpenak > Mahaigaina atalean konfiguratzen dira.';

  @override
  String meetingNoteModelInSettings(Object model) {
    return 'Transkripzio-eredua: $model (Ezarpenak > Mahaigaina atalean).';
  }

  @override
  String get meetingNoteDescription =>
      'Mikrofonoa eta sistemaren audioa grabatzen ditu. Transkripzioa lokalean sortzen da.';

  @override
  String meetingNoteWhisperInitError(Object error) {
    return 'Ezin izan da Whisper abiarazi: $error';
  }

  @override
  String get meetingNoteAudioAccessError =>
      'Ezin izan da mikrofonoa/gailuak atzitu.';

  @override
  String get meetingNoteMicrophoneAccessError =>
      'Ezin izan da mikrofonoa atzitu.';

  @override
  String get meetingNoteChunkTranscriptionError =>
      'Ezin izan da audio zati hau transkribatu.';

  @override
  String get meetingNoteProviderLocal => 'Lokala (Whisper)';

  @override
  String get meetingNoteProviderCloud => 'Quill Cloud';

  @override
  String get meetingNoteProviderCloudCost =>
      'Ink 1 grabatutako 5 minutu bakoitzeko';

  @override
  String get meetingNoteCloudFallbackNotice =>
      'Hodeia ez dago erabilgarri. Whisper lokala erabiltzen.';

  @override
  String get meetingNoteCloudInkExhaustedNotice =>
      'Ink nahikorik ez. Whisper lokalera aldatzen.';

  @override
  String meetingNoteCloudRecordingBadge(Object language) {
    return 'Quill Cloud | Hizkuntza: $language';
  }

  @override
  String get meetingNoteCloudProcessing => 'Quill Cloud-ekin prozesatzen…';

  @override
  String get meetingNoteCloudProcessingSubtitle =>
      'Hizlariak detektatzen eta kalitatea hobetzen. Itxaron, mesedez.';

  @override
  String meetingNoteCloudProgress(int done, int total) {
    return 'Prozesatutako zatiak: $done/$total';
  }

  @override
  String meetingNoteCloudEta(Object remaining) {
    return 'Gainerako denbora estimatua: $remaining';
  }

  @override
  String get meetingNoteCloudEtaCalculating =>
      'Gainerako denbora kalkulatzen...';

  @override
  String get meetingNoteCloudRequiresAccount =>
      'Ink duen Folio Cloud kontu bat behar du.';

  @override
  String get meetingNoteTranscriptionProvider => 'Transkripzio-motorra';

  @override
  String meetingNoteRecordingTime(Object mm, Object ss) {
    return 'Grabatzen: $mm:$ss';
  }

  @override
  String meetingNoteRecordingBadge(Object language, Object model) {
    return 'Hizkuntza: $language | Eredua: $model';
  }

  @override
  String get meetingNoteSystemAudioCaptured => 'Sistemaren audioa grabatuta';

  @override
  String get meetingNoteStop => 'Gelditu';

  @override
  String get meetingNoteWaitingTranscription => 'Transkripzioaren zain…';

  @override
  String get meetingNoteTranscribing => 'Transkribatzen…';

  @override
  String get meetingNoteTranscriptionTitle => 'Transkripzioa';

  @override
  String get meetingNoteNoTranscription =>
      'Ez dago transkripziorik eskuragarri.';

  @override
  String get meetingNoteNewRecording => 'Grabazio berria';

  @override
  String get meetingNoteSettingsSection => 'Bilerako oharra (audioa)';

  @override
  String get meetingNoteSettingsDescription =>
      'Gailu hauek erabiltzen dira lehenetsi gisa bilerako ohar bat grabatzean.';

  @override
  String get meetingNoteSettingsMicrophone => 'Mikrofonoa';

  @override
  String get meetingNoteSettingsRefreshDevices => 'Eguneratu zerrenda';

  @override
  String get meetingNoteSettingsSystemDefault => 'Sistemarena lehenetsi gisa';

  @override
  String get meetingNoteSettingsSystemOutput => 'Sistemaren irteera (loopback)';

  @override
  String get meetingNoteSettingsModel => 'Transkripzio-eredua';

  @override
  String get meetingNoteDiarizationHint =>
      '%100 prozesatze lokala zure gailuan.';

  @override
  String get meetingNoteModelTiny => 'Azkarra';

  @override
  String get meetingNoteModelBase => 'Orekatua';

  @override
  String get meetingNoteModelSmall => 'Zehatza';

  @override
  String get meetingNoteCopyTranscript => 'Kopiatu transkripzioa';

  @override
  String get meetingNoteSendToAi => 'Bidali AAra…';

  @override
  String get meetingNoteAiPayloadLabel => 'Zer bidali AAra?';

  @override
  String get meetingNoteAiPayloadTranscript => 'Transkripzioa bakarrik';

  @override
  String get meetingNoteAiPayloadAudio => 'Audioa bakarrik';

  @override
  String get meetingNoteAiPayloadBoth => 'Transkripzioa + audioa';

  @override
  String get meetingNoteAiInstructionHint => 'adib: laburtu puntu nagusiak';

  @override
  String get meetingNoteAiNoAudio =>
      'Ez dago audiorik eskuragarri modu honetarako';

  @override
  String get meetingNoteAiInstruction => 'AArentzako argibidea';

  @override
  String get dragToReorder => 'Arrastatu berrantolatzeko';

  @override
  String get addBlock => 'Gehitu blokea';

  @override
  String get blockMentionPageSubtitle => 'Aipatu orrialdea';

  @override
  String get blockTypesSheetTitle => 'Bloke motak';

  @override
  String get blockTypesSheetSubtitle =>
      'Aukeratu bloke honek izango duen itxura';

  @override
  String get blockTypeFilterEmpty => 'Bilaketarekin ez dator bat ezer';

  @override
  String get fileNotFound => 'Ez da fitxategia aurkitu';

  @override
  String get couldNotLoadImage => 'Ezin izan da irudia kargatu';

  @override
  String get noImageHint => 'Irudirik ez · erabili ⋮ menua edo azpiko botoia';

  @override
  String get chooseImage => 'Hautatu irudia';

  @override
  String get replaceFile => 'Ordeztu fitxategia';

  @override
  String get removeFile => 'Kendu fitxategia';

  @override
  String get replaceVideo => 'Ordeztu bideoa';

  @override
  String get removeVideo => 'Kendu bideoa';

  @override
  String get openExternal => 'Ireki kanpotik';

  @override
  String get openVideoExternal => 'Ireki bideoa kanpotik';

  @override
  String get play => 'Erreproduzitu';

  @override
  String get pause => 'Pausatu';

  @override
  String get mute => 'Mututu';

  @override
  String get unmute => 'Aktibatu soinua';

  @override
  String get fileResolveError => 'Errorea fitxategia ebaztean';

  @override
  String get videoResolveError => 'Errorea bideoa ebaztean';

  @override
  String get fileMissing => 'Ez da fitxategia aurkitu';

  @override
  String get videoMissing => 'Ez da bideoa aurkitu';

  @override
  String get chooseFile => 'Hautatu fitxategia';

  @override
  String get chooseVideo => 'Hautatu bideoa';

  @override
  String get noEmbeddedPreview =>
      'Mota honetarako ez dago aurrebista integraturik';

  @override
  String get couldNotReadFile => 'Ezin izan da fitxategia irakurri';

  @override
  String get couldNotLoadVideo => 'Ezin izan da bideoa kargatu';

  @override
  String get couldNotPreviewPdf => 'Ezin izan da PDFa aurreikusi';

  @override
  String get openInYoutubeBrowser => 'Ireki nabigatzailean';

  @override
  String get pasteUrlTitle => 'Itsatsi esteka honela';

  @override
  String get pasteAsUrl => 'URL';

  @override
  String get pasteAsEmbed => 'Txertatua';

  @override
  String get pasteAsBookmark => 'Laster-marka';

  @override
  String get pasteAsMention => 'Aipamena';

  @override
  String get pasteAsUrlSubtitle => 'Txertatu markdown esteka testuan';

  @override
  String get pasteAsEmbedSubtitle =>
      'Bideo-blokea aurrebistarekin (YouTube) edo laster-marka';

  @override
  String get pasteAsBookmarkSubtitle => 'Txartela izenburu eta estekarekin';

  @override
  String get pasteAsMentionSubtitle =>
      'Gorde-leku honetako orrialde baterako esteka';

  @override
  String get tableAddRow => 'Errenkada';

  @override
  String get tableRemoveRow => 'Kendu errenkada';

  @override
  String get tableAddColumn => 'Zutabea';

  @override
  String get tableRemoveColumn => 'Kendu zut.';

  @override
  String get tablePasteFromClipboard => 'Itsatsi taula';

  @override
  String get pickPageForMention => 'Hautatu orrialdea';

  @override
  String get bookmarkTitleHint => 'Izenburua';

  @override
  String get bookmarkOpenLink => 'Ireki esteka';

  @override
  String get bookmarkSetUrl => 'Ezarri URLa…';

  @override
  String get bookmarkBlockHint =>
      'Itsatsi esteka bat edo erabili blokearen menua';

  @override
  String get bookmarkRemove => 'Kendu laster-marka';

  @override
  String get embedUnavailable =>
      'Txertatutako web-ikuspegia ez dago eskuragarri plataforma honetan. Ireki esteka nabigatzailean.';

  @override
  String get embedOpenBrowser => 'Ireki nabigatzailean';

  @override
  String get embedSetUrl => 'Ezarri txertatze-URLa…';

  @override
  String get embedRemove => 'Kendu txertatzea';

  @override
  String get embedEmptyHint =>
      'Itsatsi esteka bat edo ezarri URLa blokeko menutik';

  @override
  String get blockSizeSmaller => 'Txikiagoa';

  @override
  String get blockSizeLarger => 'Handiagoa';

  @override
  String get blockSizeHalf => '50%';

  @override
  String get blockSizeThreeQuarter => '75%';

  @override
  String get blockSizeFull => '100%';

  @override
  String get pasteAsEmbedSubtitleWeb =>
      'Erakutsi orrialdea blokearen barruan (bateragarria denean)';

  @override
  String get pasteAsMentionSubtitleRich =>
      'Esteka orrialdearen izenburuarekin (adib: YouTube)';

  @override
  String get formatToolbar => 'Formatu-barra';

  @override
  String get linkTitle => 'Esteka';

  @override
  String get visibleTextLabel => 'Ikusgai dagoen testua';

  @override
  String get urlLabel => 'URL';

  @override
  String get urlHint => 'https://…';

  @override
  String get insert => 'Txertatu';

  @override
  String get defaultLinkText => 'testua';

  @override
  String get boldTip => 'Lodia (**)';

  @override
  String get italicTip => 'Etzana (_)';

  @override
  String get underlineTip => 'Azpimarratua (<u>)';

  @override
  String get inlineCodeTip => 'Kodea lerroan (`)';

  @override
  String get strikeTip => 'Marratua (~~)';

  @override
  String get linkTip => 'Esteka';

  @override
  String get pageHistoryTitle => 'Bertsioen historia';

  @override
  String get restoreVersionTitle => 'Berreskuratu bertsioa';

  @override
  String get restoreVersionBody =>
      'Orrialdearen izenburua eta edukia bertsio honekin ordezkatuko dira. Uneko egoera historian gordeko da lehenik.';

  @override
  String get restore => 'Berreskuratu';

  @override
  String get deleteVersionTitle => 'Ezabatu bertsioa';

  @override
  String get deleteVersionBody =>
      'Sarrera hau historiatik kenduko da. Uneko orrialdeko testua ez da aldatuko.';

  @override
  String get noVersionsYet => 'Bertsiorik ez oraindik';

  @override
  String get historyAppearsHint =>
      'Segundo batzuez idazteari uzten diozunean, aldaketen historia hemen agertuko da.';

  @override
  String get versionControl => 'Bertsio-kontrola';

  @override
  String get historyHeaderBody =>
      'Gorde-lekua bizkor gordetzen da; historiak sarrera bat gehitzen du editatzeari uzten diozunean eta edukia aldatu denean.';

  @override
  String versionsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'bertsio',
      one: 'bertsio',
    );
    return '$count $_temp0';
  }

  @override
  String get untitledFallback => 'Izenbururik gabea';

  @override
  String get comparedWithPrevious => 'Aurreko bertsioarekin alderatuta';

  @override
  String get changesFromEmptyStart => 'Hasiera hutsunetik egindako aldaketak';

  @override
  String get contentLabel => 'Edukia';

  @override
  String get titleLabelSimple => 'Izenburua';

  @override
  String get emptyValue => '(hutsik)';

  @override
  String get noTextChanges => 'Ez dago aldaketarik testuan.';

  @override
  String get aiAssistantTitle => 'Quill';

  @override
  String get aiNoPageSelected => 'Ez da orrialderik hautatu';

  @override
  String get aiChatContextDisabledSubtitle =>
      'Orrialdeko testua ez zaio ereduari bidali';

  @override
  String aiChatContextUsesCurrentPage(Object title) {
    return 'Testuingurua: uneko orrialdea ($title)';
  }

  @override
  String get aiChatContextOnePageFallback => 'Testuingurua: orrialde 1';

  @override
  String aiChatContextNPages(int count) {
    return '$count orrialde txataren testuinguruan';
  }

  @override
  String get aiChatPageContextTooltip =>
      'Sartu orrialdeko testua ereduaren testuinguruan';

  @override
  String get aiChatChooseContextPagesTooltip =>
      'Aukeratu zein orrialdek gehitzen duten testua testuingurura';

  @override
  String get aiChatContextPagesDialogTitle =>
      'Txataren testuinguruko orrialdeak';

  @override
  String get aiChatContextPagesClear => 'Garbitu zerrenda';

  @override
  String get aiChatContextPagesApply => 'Aplikatu';

  @override
  String get aiTypingSemantics => 'Quill idazten ari da';

  @override
  String get aiRenameChatTooltip => 'Aldatu txataren izena';

  @override
  String get aiRenameChatDialogTitle => 'Txataren izenburua';

  @override
  String get aiRenameChatLabel => 'Pestanan erakusten den izenburua';

  @override
  String get quillWorkspaceTourTitle => 'Quillek hemendik lagun zaitzake';

  @override
  String get quillWorkspaceTourBodyReady =>
      'Zure Quill txata prest dago galderetarako, orrialde-edizioetarako eta oharren testuinguru-fluxuetarako.';

  @override
  String get quillWorkspaceTourBodyUnavailable =>
      'Une honetan aktibo ez badago ere, Quill espazio honetakoa da eta geroago gaitu dezakezu Ezarpenetan.';

  @override
  String get quillWorkspaceTourPointsTitle => 'Jakin beharrekoa';

  @override
  String get quillWorkspaceTourPointOne =>
      'Elkarrizketa-laguntzaile gisa zein izenburu eta blokeen editore gisa funtzionatzen du.';

  @override
  String get quillWorkspaceTourPointTwo =>
      'Uneko orrialdea edo hainbat orrialde erabil ditzake testuinguru gisa.';

  @override
  String get quillWorkspaceTourPointThree =>
      'Beheko adibideren bat sakatzen baduzu, txata aurrez beteko da Quill erabilgarri dagoenean.';

  @override
  String get quillWorkspaceTourExamplesTitle => 'Probatu agindu hauek';

  @override
  String get quillWorkspaceTourExampleOne =>
      'Azaldu nola antolatu orrialde hau.';

  @override
  String get quillWorkspaceTourExampleTwo =>
      'Erabili bi orrialde hauek laburpen partekatu bat egiteko.';

  @override
  String get quillWorkspaceTourExampleThree =>
      'Berridatzi bloke hau tonu argiagoan.';

  @override
  String get quillTourDismiss => 'Ulertuta';

  @override
  String get aiExpand => 'Zabaldu';

  @override
  String get aiCollapse => 'Tolestu';

  @override
  String get aiDeleteCurrentChat => 'Ezabatu uneko txata';

  @override
  String get aiNewChat => 'Berria';

  @override
  String get aiAttach => 'Erantsi';

  @override
  String get aiChatEmptyHint =>
      'Hasi elkarrizketa bat.\nQuillek automatikoki erabakiko du zer egin zure mezuarekin.\nFolio nola erabili ere galdetu diezaiokezu (lasterbideak, ezarpenak, orrialdeak edo txat hau).';

  @override
  String get aiChatEmptyFocusComposer => 'Idatzi mezu bat';

  @override
  String get aiInputHint =>
      'Idatzi zure mezua. Quillek agente gisa jardungo du.';

  @override
  String get aiInputHintCopilot => 'Idatzi zure mezua...';

  @override
  String get aiContextComposerHint => 'Ez da testuingururik gehitu';

  @override
  String get aiContextComposerHelper => 'Erabili @ testuingurua gehitzeko';

  @override
  String aiContextCurrentPageChip(Object title) {
    return 'Uneko orrialdea: $title';
  }

  @override
  String get aiContextCurrentPageFallback => 'Uneko orrialdea';

  @override
  String get aiContextAddFile => 'Erantsi fitxategia';

  @override
  String get aiContextAddPage => 'Erantsi orrialdea';

  @override
  String get aiShowPanel => 'Erakutsi AA panela';

  @override
  String get aiHidePanel => 'Ezkutatu AA panela';

  @override
  String get aiPanelResizeHandle => 'Aldatu AA panelaren tamaina';

  @override
  String get aiPanelResizeHandleHint =>
      'Arrastatu horizontalki laguntzailearen panelaren zabalera aldatzeko';

  @override
  String get importMarkdownPage => 'Inportatu Markdown';

  @override
  String get exportMarkdownPage => 'Esportatu Markdown';

  @override
  String get workspaceUndoTooltip => 'Desegin (Ctrl+Z)';

  @override
  String get workspaceRedoTooltip => 'Berregin (Ctrl+Y)';

  @override
  String get workspaceMoreActionsTooltip => 'Ekintza gehiago';

  @override
  String get closeCurrentPage => 'Itxi uneko orrialdea';

  @override
  String aiErrorWithDetails(Object error) {
    return 'AA errorea: $error';
  }

  @override
  String get aiServiceUnreachable =>
      'Ezin izan da AA zerbitzuarekin harremanetan jarri konfiguratutako helbidean. Abiarazi Ollama edo LM Studio eta egiaztatu URLa.';

  @override
  String get aiLaunchProviderWithApp => 'Ireki AA aplikazioa Folio abiaraztean';

  @override
  String get aiLaunchProviderWithAppHint =>
      'Ollama edo LM Studio Windows-en abiarazten saiatzen da helbidea localhost denean. LM Studio-k bere zerbitzaria eskuz abiaraztea behar izan dezake oraindik.';

  @override
  String get aiContextWindowTokens => 'Ereduaren testuinguru-leihoa (tokenak)';

  @override
  String get aiContextWindowTokensHint =>
      'AA txataren testuinguru-barrarako erabiltzen da. Zure ereduarekin bat etorri behar du (adib: 8192, 131072).';

  @override
  String get aiContextUsageUnavailable =>
      'Ez da token erabileraren berri eman azken erantzunean.';

  @override
  String aiContextUsageSummary(Object prompt, Object completion) {
    return 'Prompt-a $prompt · Irteera $completion';
  }

  @override
  String aiContextUsageTooltip(int window) {
    return 'Azken eskaera vs konfiguratutako testuinguru-leihoa ($window token).';
  }

  @override
  String get aiChatKeyboardHint =>
      'Sartu bidaltzeko · Ctrl+Sartu lerro berrirako';

  @override
  String aiChatInkRemaining(int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$total ink tanta geratzen dira',
      one: 'Ink tanta 1 geratzen da',
    );
    return '$_temp0';
  }

  @override
  String aiChatInkBreakdownTooltip(int monthly, int purchased) {
    return 'Hilekoa $monthly · Erositakoa $purchased';
  }

  @override
  String get aiAgentThought => 'Quillen pentsamendua';

  @override
  String get aiAlwaysShowThought => 'Erakutsi beti AAren pentsamendua';

  @override
  String get aiAlwaysShowThoughtHint =>
      'Desgaituta badago, tolestuta agertzen da mezu bakoitzean gezi batekin.';

  @override
  String get aiBetaBadge => 'BETA';

  @override
  String get aiBetaEnableTitle => 'AA BETA fasean dago';

  @override
  String get aiBetaEnableBody =>
      'Eginbide hau BETA fasean dago une honetan eta huts egin dezake edo modu ustekabean joka dezake.\n\nGaitu nahi duzu hala ere?';

  @override
  String get aiBetaEnableConfirm => 'Gaitu BETA';

  @override
  String get ai => 'AA';

  @override
  String get aiEnableToggleTitle => 'Gaitu AA';

  @override
  String get aiProviderLabel => 'Hornitzailea';

  @override
  String get aiProviderNone => 'Bat ere ez';

  @override
  String get aiEndpoint => 'Endpoint-a (helbidea)';

  @override
  String get aiModel => 'Eredua';

  @override
  String get aiTimeoutMs => 'Itxaroteko denbora (ms)';

  @override
  String get aiAllowRemoteEndpoint => 'Onartu urrutiko endpoint-ak';

  @override
  String get aiAllowRemoteEndpointAllowed => 'Urrutiko host-ak onartuta';

  @override
  String get aiAllowRemoteEndpointLocalhostOnly => 'Localhost bakarrik';

  @override
  String get aiAllowRemoteEndpointNotConfirmed =>
      'Urrutiko endpoint atzipena gaituta dago baina oraindik ez da berretsi.';

  @override
  String get aiConnectToListModels => 'Konektatu ereduak zerrendatzeko';

  @override
  String aiProviderAutoConfigured(Object provider) {
    return 'AA hornitzailea detektatu eta konfiguratu da: $provider';
  }

  @override
  String get aiSetupAssistantTitle => 'AA konfiguratzeko laguntzailea';

  @override
  String get aiSetupAssistantSubtitle =>
      'Detektatu eta konfiguratu Ollama edo LM Studio automatikoki.';

  @override
  String get aiSetupWizardTitle => 'AA konfiguratzeko laguntzailea';

  @override
  String get aiSetupChooseProviderTitle => 'Hautatu AA hornitzailea';

  @override
  String get aiSetupChooseProviderBody =>
      'Lehenik hautatu zein hornitzaile erabili nahi duzun. Ondoren, instalazioan eta konfigurazioan gidatuko zaitugu.';

  @override
  String get aiSetupNoProviderTitle => 'Ez da hornitzaile aktiborik detektatu';

  @override
  String get aiSetupNoProviderBody =>
      'Ezin izan dugu Ollama edo LM Studio martxan aurkitu.\nJarraitu urratsak horietako bat instalatzeko/abiarazteko eta sakatu Saiatu berriro.';

  @override
  String get aiSetupOllamaTitle => '1. urratsa: Instalatu Ollama';

  @override
  String get aiSetupOllamaBody =>
      'Instalatu Ollama, exekutatu tokiko zerbitzua eta egiaztatu http://127.0.0.1:11434 helbidean erantzuten duela.';

  @override
  String get aiSetupLmStudioTitle => '2. urratsa: Instalatu LM Studio';

  @override
  String get aiSetupLmStudioBody =>
      'Instalatu LM Studio, abiarazi bere tokiko zerbitzaria (OpenAI-rekin bateragarria) eta egiaztatu http://127.0.0.1:1234 helbidean erantzuten duela.';

  @override
  String get aiSetupOpenSettingsHint =>
      'Hornitzaile bat martxan dagoenean, sakatu Saiatu berriro automatikoki konfiguratzeko.';

  @override
  String get aiCompareCloudVsLocalTitle => 'Hodeia vs lokala';

  @override
  String get aiCompareCloudTitle => 'Folio Cloud';

  @override
  String get aiCompareLocalTitle => 'Lokala (Ollama / LM Studio)';

  @override
  String get aiCompareCloudBulletNoSetup =>
      'Tokiko konfiguraziorik gabe: saioa hasi ondoren funtzionatzen du.';

  @override
  String get aiCompareCloudBulletNeedsSub =>
      'Folio Cloud harpidetza hodeiko AArekin edo erositako ink-arekin.';

  @override
  String get aiCompareCloudBulletInk =>
      'Hodeiko AArako ink-a erabiltzen du (paketeak + hileroko karga).';

  @override
  String get aiProviderFolioCloudBlockedSnack =>
      'Folio Cloud plan aktibo bat behar duzu hodeiko AArekin edo erositako ink-arekin — ikusi Ezarpenak → Folio Cloud.';

  @override
  String get aiCompareLocalBulletPrivacy =>
      'Tokiko pribatutasuna (zure makinan).';

  @override
  String get aiCompareLocalBulletNoInk =>
      'Ink-ik gabe: ez dago saldo bati lotuta.';

  @override
  String get aiCompareLocalBulletSetup =>
      'Hornitzaile bat localhost-en instalatzea eta exekutatzea eskatzen du.';

  @override
  String get quillGlobalScopeNoticeTitle =>
      'Quillek gorde-leku guztietan funtzionatzen du';

  @override
  String get quillGlobalScopeNoticeBody =>
      'Quill aplikazio-mailako ezarpen bat da. Orain gaitzen baduzu, instalazio honetako edozein gorde-lekutan egongo da erabilgarri.';

  @override
  String get quillGlobalScopeNoticeConfirm => 'Ulertzen dut';

  @override
  String get searchByNameOrShortcut => 'Bilatu izenez edo lasterbidez…';

  @override
  String get search => 'Bilatu';

  @override
  String get open => 'Ireki';

  @override
  String get exit => 'Irten';

  @override
  String get trayMenuCloseApplication => 'Itxi aplikazioa';

  @override
  String get keyboardShortcutsSection => 'Teklatua (aplikazioan)';

  @override
  String get shortcutTestAction => 'Probatu';

  @override
  String get shortcutChangeAction => 'Aldatu';

  @override
  String shortcutTestHint(Object combo) {
    return 'Fokua testu-eremu batetik kanpo dagoela, “$combo”-k espazioan funtzionatu beharko luke.';
  }

  @override
  String get shortcutResetAllTitle => 'Berreskuratu lasterbide lehenetsiak';

  @override
  String get shortcutResetAllSubtitle =>
      'Aplikazioko lasterbide guztiak Folioren balio lehenetsietara itzultzen ditu.';

  @override
  String get shortcutResetDoneSnack =>
      'Lasterbideak balio lehenetsietara itzuli dira.';

  @override
  String get desktopSection => 'Mahaigaina';

  @override
  String get globalSearchHotkey => 'Bilaketa orokorreko lasterbidea';

  @override
  String get hotkeyCombination => 'Tekla-konbinazioa';

  @override
  String get hotkeyAltSpace => 'Alt + Espazioa';

  @override
  String get hotkeyCtrlShiftSpace => 'Ctrl + Shift + Espazioa';

  @override
  String get hotkeyCtrlShiftK => 'Ctrl + Shift + K';

  @override
  String get minimizeToTray => 'Minimizatu sistemaren erretilura';

  @override
  String get closeToTray => 'Itxi sistemaren erretilura';

  @override
  String get searchAllVaultHint => 'Bilatu gorde-leku osoan...';

  @override
  String get typeToSearch => 'Idatzi bilatzeko';

  @override
  String get noSearchResults => 'Emaitzarik ez';

  @override
  String get searchFilterAll => 'Denak';

  @override
  String get searchFilterTitles => 'Izenburuak';

  @override
  String get searchFilterContent => 'Edukia';

  @override
  String get searchSortRelevance => 'Garrantzia';

  @override
  String get searchSortRecent => 'Berrienak';

  @override
  String get settingsSearchSections => 'Bilaketa-ezarpenak';

  @override
  String get settingsSearchSectionsHint => 'Iragazi kategoriak alboko barran';

  @override
  String get scheduledVaultBackupTitle =>
      'Programatutako babeskopia enkriptatua';

  @override
  String get scheduledVaultBackupSubtitle =>
      'Gorde-lekua desblokeatuta dagoen bitartean, babeskopia bakoitza unean irekita dagoen gorde-lekuarena da. Foliok ZIP bat gordeko du beheko karpetan aukeratutako maiztasunarekin.';

  @override
  String get scheduledVaultBackupChooseFolder => 'Babeskopia-karpeta';

  @override
  String get scheduledVaultBackupIntervalLabel => 'Maiztasuna (orduak)';

  @override
  String scheduledVaultBackupLastRun(Object time) {
    return 'Azken babeskopia: $time';
  }

  @override
  String get scheduledVaultBackupSnackOk =>
      'Programatutako babeskopia gorde da.';

  @override
  String scheduledVaultBackupSnackFail(Object error) {
    return 'Programatutako babeskopiak huts egin du: $error';
  }

  @override
  String vaultBackupOpenVaultHint(String name) {
    return 'Babeskopiak une honetan irekita dagoen gorde-lekuarentzat dira: “$name”.';
  }

  @override
  String get vaultBackupRunNowTile =>
      'Exekutatu programatutako babeskopia orain';

  @override
  String get vaultBackupRunNowSubtitle =>
      'Exekutatu programatutako babeskopia orain (diskoan eta/edo hodeian) itxaron gabe.';

  @override
  String get vaultBackupRunNowNeedFolder =>
      'Hautatu tokiko babeskopia-karpeta bat, edo aktibatu “Igo Folio Cloud-era ere” hodeian soilik gordetzeko.';

  @override
  String get vaultIdentitySyncTitle => 'Sinkronizazioa';

  @override
  String get vaultIdentitySyncBody =>
      'Sartu gorde-lekuaren pasahitza (edo Hello / sarbide-gakoa) jarraitzeko.';

  @override
  String get vaultIdentityCloudBackupTitle => 'Hodeiko babeskopiak';

  @override
  String get vaultIdentityCloudBackupBody =>
      'Berretsi gorde-lekuaren nortasuna babeskopia enkriptatuak zerrendatzeko edo deskargatzeko.';

  @override
  String get aiRewriteDialogTitle => 'Berridatzi AArekin';

  @override
  String get aiPreviewTitle => 'Aurrebista';

  @override
  String get aiInstructionHint =>
      'Adibidez: egin ezazu argiagoa eta laburragoa';

  @override
  String get aiApply => 'Aplikatu';

  @override
  String get aiGenerating => 'Sortzen…';

  @override
  String get aiSummarizeSelection => 'Laburtu AArekin…';

  @override
  String get aiExtractTasksDates => 'Erauzi atazak eta datak…';

  @override
  String get aiPreviewReadOnlyHint =>
      'Beheko testua edita dezakezu aplikatu aurretik.';

  @override
  String get aiRewriteApplied => 'Blokea eguneratuta.';

  @override
  String get aiUndoRewrite => 'Desegin';

  @override
  String get aiInsertBelow => 'Txertatu azpian';

  @override
  String get unlockVaultTitle => 'Desblokeatu gorde-lekua';

  @override
  String get miniUnlockFailed => 'Ezin izan da desblokeatu.';

  @override
  String get importNotionTitle => 'Inportatu Notion-etik (.zip)';

  @override
  String get importNotionSubtitle => 'Notion ZIP esportazioa (Markdown/HTML)';

  @override
  String get importNotionDialogTitle => 'Inportatu Notion-etik';

  @override
  String get importNotionDialogBody =>
      'Inportatu Notion-ek esportatutako ZIP bat. Uneko gorde-lekuan gehitu dezakezu edo berri bat sortu.';

  @override
  String get importNotionSelectTargetTitle => 'Inportazioaren helburua';

  @override
  String get importNotionSelectTargetBody =>
      'Aukeratu Notion-en esportazioa uneko gorde-lekuan inportatu nahi duzun ala gorde-leku berri bat sortu nahi duzun hartatik.';

  @override
  String get importNotionTargetCurrent => 'Uneko gorde-lekua';

  @override
  String get importNotionTargetNew => 'Gorde-leku berria';

  @override
  String get importNotionDefaultVaultName => 'Notion-etik inportatua';

  @override
  String get importNotionNewVaultPasswordTitle =>
      'Gorde-leku berrirako pasahitza';

  @override
  String get importNotionSuccessCurrent =>
      'Notion uneko gorde-lekuan inportatu da.';

  @override
  String get importNotionSuccessNew =>
      'Gorde-leku berria inportatu da Notion-etik.';

  @override
  String importNotionError(Object error) {
    return 'Ezin izan da Notion inportatu: $error';
  }

  @override
  String get importNotionWarningsTitle => 'Inportazio abisuak';

  @override
  String get importNotionWarningsBody =>
      'Inportazioa abisu batzuekin osatu da:';

  @override
  String get ok => 'Ados';

  @override
  String get notionExportGuideTitle => 'Nola esportatu Notion-etik';

  @override
  String get notionExportGuideBody =>
      'Notion-en, ireki Settings -> Export all workspace content, hautatu HTML edo Markdown eta deskargatu ZIP fitxategia. Ondoren, erabili inportazio aukera hau Folio-n.';

  @override
  String get appBetaBannerMessage =>
      'Beta bertsio bat erabiltzen ari zara. Akatsak aurki ditzakezu; egin babeskopiak maiz.';

  @override
  String get appBetaBannerDismiss => 'Ulertuta';

  @override
  String get integrations => 'Integrazioak';

  @override
  String get integrationsAppsApprovedHint =>
      'Onartutako kanpoko aplikazioek tokiko integrazio-zubia erabil dezakete.';

  @override
  String get integrationsAppsApprovedTitle => 'Onartutako kanpoko aplikazioak';

  @override
  String get integrationsAppsApprovedNone =>
      'Oraindik ez duzu kanpoko aplikaziorik onartu.';

  @override
  String get integrationsAppsApprovedRevoke => 'Revokatu sarbidea';

  @override
  String integrationsApprovedAppDetails(
    Object appId,
    Object appVersion,
    Object integrationVersion,
  ) {
    return '$appId · App $appVersion · Integrazioa $integrationVersion';
  }

  @override
  String get integrationApprovalTitle => 'Onartu kanpoko integrazioa';

  @override
  String get integrationApprovalUpdateTitle =>
      'Onartu eguneratutako integrazioa';

  @override
  String integrationApprovalBody(
    Object appName,
    Object appVersion,
    Object integrationVersion,
  ) {
    return '\"$appName\" aplikazioak Foliorekin konektatu nahi du $appVersion bertsioarekin eta $integrationVersion integrazio-bertsioarekin.';
  }

  @override
  String integrationApprovalUpdateBody(
    Object appName,
    Object previousVersion,
    Object integrationVersion,
  ) {
    return '\"$appName\" lehenago onartu zen $previousVersion integrazio-bertsioarekin. Orain $integrationVersion integrazio-bertsioarekin konektatu nahi du, beraz, Foliok zure oniritzia behar du berriro.';
  }

  @override
  String get integrationApprovalUnknownVersion => 'ezezaguna';

  @override
  String get integrationApprovalAppId => 'Aplikazioaren IDa';

  @override
  String get integrationApprovalAppVersion => 'Aplikazioaren bertsioa';

  @override
  String get integrationApprovalProtocolVersion => 'Integrazio-bertsioa';

  @override
  String get integrationApprovalCanDoTitle =>
      'Zer egin dezake integrazio honek';

  @override
  String get integrationApprovalCanDoSessions =>
      'Inportazio-saio laburrak sortu Folio-n.';

  @override
  String get integrationApprovalCanDoImport =>
      'Markdown dokumentazioa bidali orrialdeak sortzeko edo eguneratzeko inportazio-zubiaren bidez.';

  @override
  String get integrationApprovalCanDoMetadata =>
      'Inportazioaren jatorria (bezero-aplikazioa, saioa eta iturburuko metadatuak) gordetzea inportatutako orrialdeetan.';

  @override
  String get integrationApprovalCanDoUnlockedVault =>
      'Gorde-lekua erabilgarri dagoen bitartean soilik inportatzea eta eskaerak konfiguratutako sekretua duenean.';

  @override
  String get integrationApprovalCannotDoTitle => 'Zer EZIN duen egin';

  @override
  String get integrationApprovalCannotDoRead =>
      'Ezin du zure gorde-lekuaren edukia irakurri zubi honen bidez.';

  @override
  String get integrationApprovalCannotDoBypassLock =>
      'Ezin du gorde-lekuaren blokeoa, enkriptatzea edo zure baimena saihestu.';

  @override
  String get integrationApprovalCannotDoWithoutSecret =>
      'Ezin du babestutako helbideetara sartu sekretu partekaturik gabe.';

  @override
  String get integrationApprovalCannotDoRemoteAccess =>
      'Ezin du zubia localhost-etik kanpo erabili.';

  @override
  String get integrationApprovalEncryptedChip => 'Eduki enkriptatua (v2)';

  @override
  String get integrationApprovalUnencryptedChip =>
      'Enkriptatu gabeko edukia (v1)';

  @override
  String get integrationApprovalEncryptedTitle =>
      '2. bertsioa: eduki-enkriptatze derrigorrezkoa';

  @override
  String get integrationApprovalEncryptedDescription =>
      'Bertsio honek datu enkriptatuak behar ditu edukia inportatzeko eta eguneratzeko.';

  @override
  String get integrationApprovalUnencryptedTitle =>
      '1. bertsioa: enkriptatu gabeko edukia';

  @override
  String get integrationApprovalUnencryptedDescription =>
      'Bertsio honek testu arrunta onartzen du edukiarentzat. Garraio-enkriptatzea behar baduzu, eguneratu integrazioa 2. bertsiora.';

  @override
  String get integrationApprovalDeny => 'Ukatu';

  @override
  String get integrationApprovalApprove => 'Onartu';

  @override
  String get integrationApprovalApproveUpdate => 'Onartu eguneratze hau';

  @override
  String get about => 'Honi buruz';

  @override
  String get installedVersion => 'Instalatutako bertsioa';

  @override
  String get updaterGithubRepository => 'Eguneratze-biltegia';

  @override
  String get updaterBetaDescription =>
      'Betak GitHub-en aurre-lanzamendu gisa markatutako bertsioak dira.';

  @override
  String get updaterStableDescription =>
      'Azken bertsio egonkorra bakarrik hartzen da kontuan.';

  @override
  String get checkUpdates => 'Bilatu eguneratzeak';

  @override
  String get noEncryptionConfirmTitle => 'Sortu gorde-lekua enkriptatu gabe';

  @override
  String get noEncryptionConfirmBody =>
      'Zure datuak pasahitzik gabe eta enkriptatu gabe gordeko dira. Gailu honetara sarbidea duen edonork irakur ditzake.';

  @override
  String get createVaultWithoutEncryption => 'Sortu enkriptatu gabe';

  @override
  String get plainVaultSecurityNotice =>
      'Gorde-leku hau ez dago enkriptatuta. Sarbide-gakoa, Hello, blokeatze automatikoa eta pasahitz nagusia ez dira aplikatzen.';

  @override
  String get encryptPlainVaultTitle => 'Enkriptatu gorde-leku hau';

  @override
  String get encryptPlainVaultBody =>
      'Aukeratu pasahitz nagusi bat. Gailu honetako datu guztiak enkriptatuko dira. Ahazten baduzu, ezingo dira berreskuratu.';

  @override
  String get encryptPlainVaultConfirm => 'Enkriptatu gorde-lekua';

  @override
  String get encryptPlainVaultSuccessSnack =>
      'Gorde-lekua enkriptatuta dago orain';

  @override
  String get aiCopyMessage => 'Kopiatu';

  @override
  String get aiCopyCode => 'Kopiatu kodea';

  @override
  String get aiCopiedToClipboard => 'Portapapelean kopiatuta';

  @override
  String get aiHelpful => 'Lagungarria';

  @override
  String get aiNotHelpful => 'Ez da lagungarria';

  @override
  String get aiThinkingMessage => 'Quill pentsatzen ari da...';

  @override
  String get aiMessageTimestampNow => 'orain';

  @override
  String aiMessageTimestampMinutes(int n) {
    return 'duela $n min';
  }

  @override
  String aiMessageTimestampHours(int n) {
    return 'duela $n h';
  }

  @override
  String aiMessageTimestampDays(int n) {
    return 'duela $n egun';
  }

  @override
  String get templateGalleryTitle => 'Orrialde-txantiloiak';

  @override
  String get templateImport => 'Inportatu';

  @override
  String get templateImportPickTitle => 'Hautatu txantiloi-fitxategi bat';

  @override
  String get templateImportSuccess => 'Txantiloia inportatuta';

  @override
  String templateImportError(Object error) {
    return 'Errorea inportatzean: $error';
  }

  @override
  String get templateExportPickTitle => 'Gorde txantiloi-fitxategia';

  @override
  String get templateExportSuccess => 'Txantiloia esportatuta';

  @override
  String templateExportError(Object error) {
    return 'Errorea esportatzean: $error';
  }

  @override
  String get templateSearchHint => 'Bilatu txantiloiak...';

  @override
  String get templateEmptyHint =>
      'Txantiloirik ez oraindik.\nGarda orrialde bat txantiloi gisa edo inportatu bat.';

  @override
  String templateBlockCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'bloke',
      one: 'bloke',
    );
    return '$count $_temp0';
  }

  @override
  String get templateUse => 'Erabili txantiloia';

  @override
  String get templateExport => 'Esportatu';

  @override
  String get templateBlankPage => 'Orrialde zuria';

  @override
  String get templateFromGallery => 'Txantiloitik…';

  @override
  String get saveAsTemplate => 'Gorde txantiloi gisa';

  @override
  String get saveAsTemplateTitle => 'Gorde txantiloi gisa';

  @override
  String get templateNameHint => 'Txantiloiaren izena';

  @override
  String get templateDescriptionHint => 'Deskribapena (aukerakoa)';

  @override
  String get templateCategoryHint => 'Kategoria (aukerakoa)';

  @override
  String get templateSaved => 'Txantiloi gisa gordeta';

  @override
  String templateCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'txantiloi',
      one: 'txantiloi',
    );
    return '$count $_temp0';
  }

  @override
  String templateFilteredCount(int visible, int total) {
    return '$total(e)tik $visible txantiloi erakusten';
  }

  @override
  String get templateSortRecent => 'Berrienak';

  @override
  String get templateSortName => 'Izena';

  @override
  String get templateEdit => 'Editatu txantiloia';

  @override
  String get templateUpdated => 'Txantiloia eguneratuta';

  @override
  String get templateDeleteConfirmTitle => 'Ezabatu txantiloia';

  @override
  String templateDeleteConfirmBody(Object name) {
    return '\"$name\" txantiloia gorde-leku honetatik kenduko da.';
  }

  @override
  String templateCreatedOn(Object date) {
    return '$date(e)an sortua';
  }

  @override
  String get templatePreviewEmpty =>
      'Txantiloi honek ez du testu-aurrebistarik oraindik.';

  @override
  String get templateSelectHint =>
      'Hautatu txantiloi bat ikuskatzeko, metadatuak editatzeko edo esportatzeko.';

  @override
  String get templateGalleryTabLocal => 'Lokala';

  @override
  String get templateGalleryTabCommunity => 'Komunitatea';

  @override
  String get templateCommunitySignInCta =>
      'Hasi saioa komunitateko txantiloiak partekatzeko eta arakatzeko.';

  @override
  String get templateCommunitySignInButton => 'Hasi saioa';

  @override
  String get templateCommunityUnavailable =>
      'Komunitateko txantiloiek Firebase behar dute. Egiaztatu konexioa.';

  @override
  String get templateCommunityEmpty =>
      'Ez dago komunitateko txantiloirik oraindik. Izan zaitez lehena partekatzen Tokikoa pestanatik.';

  @override
  String templateCommunityLoadError(Object error) {
    return 'Ezin izan dira komunitateko txantiloiak kargatu: $error';
  }

  @override
  String get templateCommunityRetry => 'Saiatu berriro';

  @override
  String get templateCommunityRefresh => 'Eguneratu';

  @override
  String get templateCommunityShareTitle => 'Partekatu komunitatearekin';

  @override
  String get templateCommunityShareBody =>
      'Zure txantiloia publikoa izango da edonork ikusteko eta deskargatzeko. Kendu eduki pertsonal edo konfidentziala partekatu aurretik.';

  @override
  String get templateCommunityShareConfirm => 'Partekatu';

  @override
  String get templateCommunityShareSuccess =>
      'Txantiloia komunitatearekin partekatu da';

  @override
  String templateCommunityShareError(Object error) {
    return 'Ezin izan da partekatu: $error';
  }

  @override
  String get templateCommunityAddToVault => 'Gorde nire txantiloietan';

  @override
  String get templateCommunityAddedToVault => 'Zure txantiloietan gordeta';

  @override
  String get templateCommunityDeleteTitle => 'Kendu komunitatetik';

  @override
  String templateCommunityDeleteBody(Object name) {
    return 'Ezabatu \"$name\" komunitateko dendatik? Hau ezin da desegin.';
  }

  @override
  String get templateCommunityDeleteSuccess => 'Komunitatetik kenduta';

  @override
  String templateCommunityDeleteError(Object error) {
    return 'Ezin izan da kendu: $error';
  }

  @override
  String templateCommunityDownloadError(Object error) {
    return 'Ezin izan da txantiloia deskargatu: $error';
  }

  @override
  String get clear => 'Garbitu';

  @override
  String get cloudAccountSectionTitle => 'Folio Cloud kontua';

  @override
  String get cloudAccountSectionDescription =>
      'Aukerakoa. Hasi saioa hodeiko babeskopietara, AA hospedatura eta web-argitalpenera harpidetzeko. Gorde-lekua lokala izango da eginbide horiek erabili ezean.';

  @override
  String get cloudAccountChipOptional => 'Aukerakoa';

  @override
  String get cloudAccountChipPaidCloud => 'Babeskopiak, AA eta Web-a';

  @override
  String get cloudAccountUnavailable =>
      'Hodeiko saioa hastea ez dago erabilgarri (Firebase ez da abiarazi). Egiaztatu konexioa.';

  @override
  String get cloudAccountEmailLabel => 'Posta elektronikoa';

  @override
  String get cloudAccountPasswordLabel => 'Pasahitza';

  @override
  String get cloudAccountSignIn => 'Hasi saioa';

  @override
  String get cloudAccountCreateAccount => 'Sortu kontua';

  @override
  String get cloudAccountForgotPassword => 'Pasahitza ahaztu duzu?';

  @override
  String get cloudAccountSignOut => 'Irten';

  @override
  String cloudAccountSignedInAs(Object email) {
    return 'Saioa hasita: $email';
  }

  @override
  String cloudAccountUid(Object uid) {
    return 'Erabiltzailearen IDa: $uid';
  }

  @override
  String get cloudAuthDialogTitleSignIn => 'Hasi saioa Folio Cloud-en';

  @override
  String get cloudAuthDialogTitleRegister => 'Sortu Folio Cloud kontua';

  @override
  String get cloudAuthDialogTitleReset => 'Berrezarri pasahitza';

  @override
  String get cloudPasswordResetSent =>
      'Posta horrekin kontu bat badago, berrezartzeko esteka bidali da.';

  @override
  String get cloudAuthErrorInvalidEmail => 'Posta helbide horrek ez du balio.';

  @override
  String get cloudAuthErrorWrongPassword => 'Pasahitz okerra.';

  @override
  String get cloudAuthErrorUserNotFound =>
      'Ez da konturik aurkitu posta horrekin.';

  @override
  String get cloudAuthErrorUserDisabled => 'Kontu hau desgaitu egin da.';

  @override
  String get cloudAuthErrorEmailAlreadyInUse =>
      'Posta hori erregistratuta dago jada.';

  @override
  String get cloudAuthErrorWeakPassword => 'Pasahitza ahulegia da.';

  @override
  String get cloudAuthErrorInvalidCredential =>
      'Posta edo pasahitz baliogabea.';

  @override
  String get cloudAuthErrorNetwork => 'Sareko errorea. Egiaztatu konexioa.';

  @override
  String get cloudAuthErrorTooManyRequests =>
      'Saiakera gehiegi. Saiatu berriro geroago.';

  @override
  String get cloudAuthErrorOperationNotAllowed =>
      'Saioa hasteko modu hau ez dago gaituta.';

  @override
  String get cloudAuthErrorGeneric =>
      'Ezin izan da saioa hasi. Saiatu berriro.';

  @override
  String get cloudAuthDialogTitle => 'Folio Cloud';

  @override
  String get cloudAuthSubtitleSignIn =>
      'Erabili zure Folio Cloud posta eta pasahitza. Hemengo ezerk ez du zure tokiko gorde-lekua aldatzen.';

  @override
  String get cloudAuthSubtitleRegister =>
      'Sortu Folio Cloud kredentzialak. Zure oharrak ez dira igoko babeskopiak edo ordainpeko eginbideak aktibatu arte.';

  @override
  String get cloudAuthModeSignIn => 'Hasi saioa';

  @override
  String get cloudAuthModeRegister => 'Erregistratu';

  @override
  String get cloudAuthConfirmPasswordLabel => 'Berretsi pasahitza';

  @override
  String get cloudAuthValidationRequired => 'Eremu hau derrigorrezkoa da.';

  @override
  String get cloudAuthValidationPasswordShort =>
      'Erabili gutxienez 6 karaktere.';

  @override
  String get cloudAuthValidationConfirmMismatch => 'Pasahitzak ez datoz bat.';

  @override
  String get cloudAccountSignedOutPrompt =>
      'Hasi saioa edo erregistratu Folio Cloud-era harpidetzeko eta babeskopiak, hodeiko AA eta argitalpena erabiltzeko.';

  @override
  String get cloudAuthResetHint =>
      'Posta bidez esteka bat bidaliko dizugu pasahitz berria jartzeko.';

  @override
  String get cloudAccountEmailVerified => 'Verifikatuta';

  @override
  String get cloudAccountSignOutHelp =>
      'Zure tokiko gorde-lekua gailu honetan geratuko da.';

  @override
  String get cloudAccountEmailUnverifiedBanner =>
      'Verifikatu zure posta Folio Cloud kontua segurtatzeko.';

  @override
  String get cloudAccountResendVerification =>
      'Bidali berriro verifikazio-posta';

  @override
  String get cloudAccountReloadVerification => 'Verifikatu dut jada';

  @override
  String get cloudAccountVerificationSent => 'Verifikazio-posta bidali da.';

  @override
  String get cloudAccountVerificationStillPending =>
      'Posta oraindik ez dago verifikatuta. Ireki esteka zure sarrera-ontzian.';

  @override
  String get cloudAccountVerificationNowVerified => 'Posta verifikatuta.';

  @override
  String get cloudAccountResetPasswordEmail =>
      'Berrezarri pasahitza posta bidez';

  @override
  String get cloudAccountCopyEmail => 'Kopiatu posta';

  @override
  String get cloudAccountEmailCopied => 'Posta kopiatuta.';

  @override
  String get folioWebPortalSubsectionTitle => 'Web kontua';

  @override
  String get folioWebPortalLinkCodeLabel => 'Lotura-kodea';

  @override
  String get folioWebPortalLinkHelp =>
      'Sortu kodea web aplikazioan Ezarpenak → Folio kontua atalean, eta sartu hemen 10 minutu baino lehen.';

  @override
  String get folioWebPortalLinkButton => 'Lotu';

  @override
  String get folioWebPortalLinkSuccess => 'Web kontua ongi lotu da.';

  @override
  String get folioWebPortalNeedSignIn =>
      'Hasi saioa Folio Cloud-en web kontua lotzeko.';

  @override
  String get folioWebMirrorNote =>
      'Babeskopiak, AA eta argitalpena Folio Cloud bidez kudeatzen dira oraindik. Behekoak zure web kontua islatzen du.';

  @override
  String get folioWebEntitlementLinked => 'Web kontua lotuta';

  @override
  String get folioWebEntitlementNotLinked => 'Web kontua lotu gabe';

  @override
  String folioWebEntitlementWebPlan(String value) {
    return 'Folio Cloud plana (web): $value';
  }

  @override
  String folioWebEntitlementWebStatus(String value) {
    return 'Egoera (web): $value';
  }

  @override
  String folioWebEntitlementWebPeriodEnd(String value) {
    return 'Epea amaitzea (web): $value';
  }

  @override
  String folioWebEntitlementWebInk(int count) {
    return 'Ink (web): $count';
  }

  @override
  String get folioWebPortalRefreshWeb => 'Eguneratu web-egoera';

  @override
  String get folioWebPortalErrorNetwork =>
      'Ezin izan da portalarekin harremanetan jarri. Egiaztatu konexioa.';

  @override
  String get folioWebPortalErrorTimeout =>
      'Portalak gehiegi itxaron du erantzuteko.';

  @override
  String get folioWebPortalErrorAdminNotConfigured =>
      'Folio Firebase Admin ez dago zerbitzarian konfiguratuta.';

  @override
  String get folioWebPortalErrorUnauthorized =>
      'Saio baliogabea. Hasi saioa Folio Cloud-en berriro.';

  @override
  String get folioWebPortalErrorGeneric =>
      'Ezin izan da portalera egindako eskaera osatu.';

  @override
  String folioWebPortalServerMessage(String message) {
    return '$message';
  }

  @override
  String get folioCloudSubsectionPlan => 'Plana eta egoera';

  @override
  String get folioCloudSubsectionInk => 'Ink saldoa';

  @override
  String get folioCloudSubsectionSubscription => 'Harpidetza eta fakturazio';

  @override
  String get folioCloudSubsectionBackupPublish => 'Babeskopiak eta argitalpena';

  @override
  String get folioCloudSubscriptionActive => 'Harpidetza aktiboa';

  @override
  String folioCloudSubscriptionActiveWithStatus(String status) {
    return 'Harpidetza aktiboa ($status)';
  }

  @override
  String get folioCloudSubscriptionNoneTitle =>
      'Folio Cloud harpidetzarik gabe';

  @override
  String get folioCloudSubscriptionNoneSubtitle =>
      'Aktibatu plan bat babeskopia enkriptatuak, hodeiko AA eta web-argitalpena izateko.';

  @override
  String get folioCloudFeatureBackup => 'Hodeiko babeskopia';

  @override
  String get folioCloudFeatureCloudAi => 'Hodeiko AA';

  @override
  String get folioCloudFeaturePublishWeb => 'Web-argitalpena';

  @override
  String get folioCloudFeatureOn => 'Barne';

  @override
  String get folioCloudFeatureOff => 'Ez dago barne';

  @override
  String get folioCloudPostPaymentHint =>
      'Ordaindu berri baduzu eta eginbideak ez badira agertzen, sakatu «Eguneratu Stripe-tik».';

  @override
  String get folioCloudBackupCleanupWarning =>
      'Babeskopia igota, baina babeskopia zaharrak ezin izan dira garbitu (geroago saiatuko da).';

  @override
  String get folioCloudInkMonthly => 'Hilekoa';

  @override
  String get folioCloudInkPurchased => 'Erositakoa';

  @override
  String get folioCloudInkTotal => 'Guztira';

  @override
  String folioCloudInkCount(int count) {
    return '$count';
  }

  @override
  String get folioCloudPlanActiveHeadline => 'Folio Cloud hileko plan aktiboa';

  @override
  String get folioCloudSubscribeMonthly => 'Folio Cloud 4,99 €/hilean';

  @override
  String get folioCloudPitchScreenTitle => 'Folio Cloud';

  @override
  String get folioCloudPitchHeadline =>
      'Zure gorde-lekua lokala da. Hodeiak nahi duzunean funtzionatzen du.';

  @override
  String get folioCloudPitchSubhead =>
      'Hileko plan batek babeskopia enkriptatuak, hodeiko AA hileroko ink kargarekin eta web-argitalpena desblokeatzen ditu — partekatu nahi duzunarentzat bakarrik.';

  @override
  String get folioCloudPitchLearnMore => 'Ikusi zer sartzen den';

  @override
  String get folioCloudPitchCtaNeedAccount => 'Hasi saioa edo sortu kontua';

  @override
  String get folioCloudPitchGuestTeaserTitle => 'Folio Cloud kontua';

  @override
  String get folioCloudPitchGuestTeaserBody =>
      'Aukerako kontua: ikusi zer sartzen den planean eta hasi saioa harpidetu nahi duzunean.';

  @override
  String get folioCloudPitchOpenSettingsToSignIn =>
      'Ireki Ezarpenak eta hasi saioa Folio Cloud-en harpidetzeko.';

  @override
  String get folioCloudBuyInk => 'Erosi ink-a';

  @override
  String get folioCloudInkSmall => 'Ink Txikia (1,99 €)';

  @override
  String get folioCloudInkMedium => 'Ink Ertaina (4,99 €)';

  @override
  String get folioCloudInkLarge => 'Ink Handia (9,99 €)';

  @override
  String get folioCloudManageSubscription => 'Kudeatu harpidetza';

  @override
  String get folioCloudRefreshFromStripe => 'Eguneratu';

  @override
  String get folioCloudUploadEncryptedBackup => 'Egin babeskopia hodeian orain';

  @override
  String get folioCloudUploadEncryptedBackupSubtitle =>
      'Foliok irekita duzun gorde-lekuaren babeskopia enkriptatu bat sortu eta igotzen du — ZIP esportazio eskuzkorik gabe.';

  @override
  String get folioCloudUploadSnackOk =>
      'Gorde-lekuaren babeskopia hodeian gordeta.';

  @override
  String get scheduledVaultBackupCloudSyncTitle => 'Igo Folio Cloud-era ere';

  @override
  String get scheduledVaultBackupCloudSyncSubtitle =>
      'Programatutako babeskopia bakoitzaren ondoren, ZIP bera automatikoki igotzen du zure kontura. Hodeian soilik gordetzeko, utzi tokiko karpeta hautatu gabe.';

  @override
  String get folioCloudCloudBackupsList => 'Hodeiko babeskopiak';

  @override
  String get folioCloudBackupsUsed => 'Erabilita';

  @override
  String get folioCloudBackupsLimit => 'Muga';

  @override
  String get folioCloudBackupsRemaining => 'Geratzen dena';

  @override
  String get folioCloudPublishTestPage => 'Argitaratu probako orrialdea';

  @override
  String get folioCloudPublishedPagesList => 'Argitaratutako orrialdeak';

  @override
  String get folioCloudReauthDialogTitle => 'Berretsi Folio Cloud kontua';

  @override
  String get folioCloudReauthDialogBody =>
      'Sartu zure Folio Cloud kontuaren pasahitza (hodeian sartzeko erabiltzen duzuna) babeskopiak ikusteko eta deskargatzeko. Hau ez da zure tokiko gorde-lekuaren pasahitza.';

  @override
  String get folioCloudReauthRequiresPasswordProvider =>
      'Saio honek ez du Folio Cloud pasahitzik erabiltzen. Irten eta hasi saioa berriro posta eta pasahitzarekin babeskopiak deskargatu behar badituzu.';

  @override
  String get folioCloudAiNoInkTitle => 'Ez da hodeiko AA ink-ik geratzen';

  @override
  String get folioCloudAiNoInkBody =>
      'Erosi ink-a Folio Cloud atalean, itxaron hileroko kargara edo aldatu AA lokalera (Ollama edo LM Studio) AA atalean.';

  @override
  String get folioCloudAiNoInkActionCloud => 'Folio Cloud eta ink-a';

  @override
  String get folioCloudAiNoInkActionLocal => 'AA hornitzailea';

  @override
  String get folioCloudAiZeroInkBanner =>
      'Hodeiko AA ink-a 0 da — ireki Ezarpenak ink-a erosteko edo erabili AA lokala.';

  @override
  String folioCloudInkPurchaseAppliedHint(Object purchased) {
    return 'Erosketa aplikatuta: $purchased ink erosi hodeiko AArako eskuragarri.';
  }

  @override
  String get onboardingCloudBackupCta =>
      'Hasi saioa eta deskargatu babeskopia bat';

  @override
  String get onboardingCloudBackupPickVaultSubtitle =>
      'Aukeratu zein gorde-leku berreskuratu nahi duzun.';

  @override
  String get onboardingFolioCloudTitle => 'Folio Cloud';

  @override
  String get onboardingFolioCloudBody =>
      'Gaitu hodeiko eginbideak behar dituzunean: babeskopia enkriptatuak, Quill hospedatua eta web-argitalpena. Zure gorde-lekua lokala izango da eginbide horiek erabili ezean.';

  @override
  String get onboardingFolioCloudFeatureBackupTitle =>
      'Hodeiko babeskopia enkriptatuak';

  @override
  String get onboardingFolioCloudFeatureBackupBody =>
      'Gorde eta deskargatu gorde-lekuen babeskopiak zure kontutik.';

  @override
  String get onboardingFolioCloudFeatureAiTitle => 'Hodeiko AA + ink-a';

  @override
  String get onboardingFolioCloudFeatureAiBody =>
      'Quill hospedatua Folio Cloud harpidetzarekin edo ink-a erosita. Ink-a erabileraren arabera kontsumitzen da; AA lokala ere erabil dezakezu.';

  @override
  String get onboardingFolioCloudFeatureWebTitle => 'Web-argitalpena';

  @override
  String get onboardingFolioCloudFeatureWebBody =>
      'Argitaratu hautatutako orrialdeak eta kontrolatu zer bihurtzen den publiko. Gainerako gorde-lekua ez da partekatzen.';

  @override
  String get onboardingFolioCloudLaterInSettings =>
      'Geroago ikusiko dut Ezarpenetan';

  @override
  String get collabMenuAction => 'Zuzeneko lankidetza';

  @override
  String get collabSheetTitle => 'Zuzeneko lankidetza';

  @override
  String get collabHeaderSubtitle =>
      'Folio kontua behar da. Hostatzeak plan bat behar du; unetzeak kodea bakarrik. Edukia eta txata muturretik muturrera enkriptatuta daude; zerbitzariak ezin du zure testua ikusi.';

  @override
  String get collabNoRoomHint =>
      'Sortu gela bat (zure planak hostatzea badu) edo itsatsi anfitrioiaren kodea (emojia + digituak).';

  @override
  String get collabCreateRoom => 'Sortu gela';

  @override
  String get collabJoinCodeLabel => 'Gelaren kodea';

  @override
  String get collabJoinCodeHint => 'adib: bi emoji + 4 digitu';

  @override
  String get collabJoinRoom => 'Unitu';

  @override
  String get collabJoinFailed => 'Kode baliogabea edo gela beteta dago.';

  @override
  String get collabShareCodeLabel => 'Partekatu kode hau';

  @override
  String get collabCopyJoinCode => 'Kopiatu kodea';

  @override
  String get collabCopied => 'Kopiatuta';

  @override
  String get collabHostRequiresPlan =>
      'Gelak sortzeko Folio Cloud lankidetzarekin (hostatzea) behar da. Besteen geletara kode batekin unitu zaitezke plan hori gabe.';

  @override
  String get collabChatEmptyHint => 'Mezurik ez oraindik. Agurtu zure taldea.';

  @override
  String get collabMessageHint => 'Idatzi mezu bat…';

  @override
  String get collabArchivedOk => 'Txata orrialdeko iruzkin gisa artxibatuta.';

  @override
  String get collabArchiveToPage => 'Artxibatu txata orrialdean';

  @override
  String get collabLeaveRoom => 'Irten gelatik';

  @override
  String get collabNeedsJoinCode =>
      'Sartu gelaren kodea lankidetza-saio hau descifratzeko.';

  @override
  String get collabMissingJoinCodeHint =>
      'Orrialde hau gela bati lotuta dago baina ez dago koderik gordeta hemen. Itsatsi anfitrioiaren kodea edukia descifratzeko.';

  @override
  String get collabUnlockWithCode => 'Desblokeatu kodearekin';

  @override
  String get collabHidePanel => 'Ezkutatu lankidetza-panela';

  @override
  String get shortcutsCaptureTitle => 'Lasterbide berria';

  @override
  String get shortcutsCaptureHint => 'Sakatu teklak (Esc-ek utzi egiten du).';

  @override
  String get updaterStartupDialogTitleStable => 'Eguneratzea eskuragarri';

  @override
  String get updaterStartupDialogTitleBeta => 'Beta eskuragarri';

  @override
  String updaterStartupDialogBody(Object releaseVersion) {
    return 'Bertsio berri bat ($releaseVersion) eskuragarri dago.';
  }

  @override
  String get updaterStartupDialogQuestion =>
      'Deskargatu eta instalatu nahi duzu orain?';

  @override
  String get updaterStartupDialogLater => 'Geroago';

  @override
  String get updaterStartupDialogUpdateNow => 'Eguneratu orain';

  @override
  String get updaterStartupDialogBetaNote =>
      'Beta bertsioa (aurre-lanzamendua).';

  @override
  String get toggleTitleHint => 'Interruptorearen izenburua';

  @override
  String get toggleBodyHint => 'Edukia…';

  @override
  String get taskStatusTodo => 'Egiteko';

  @override
  String get taskStatusInProgress => 'Abian';

  @override
  String get taskStatusDone => 'Eginda';

  @override
  String get taskPriorityNone => 'Prioritaterik gabe';

  @override
  String get taskPriorityLow => 'Baxua';

  @override
  String get taskPriorityMedium => 'Ertaina';

  @override
  String get taskPriorityHigh => 'Altua';

  @override
  String get taskTitleHint => 'Atazaren deskribapena…';

  @override
  String get taskPriorityTooltip => 'Prioritatea';

  @override
  String get taskNoDueDate => 'Muga-egunik gabe';

  @override
  String get taskSubtaskHint => 'Azpiataza…';

  @override
  String get taskRemoveSubtask => 'Kendu azpiataza';

  @override
  String get taskAddSubtask => 'Gehitu azpiataza';

  @override
  String get templateEmojiLabel => 'Emojia';

  @override
  String aiGenericErrorWithReason(Object reason) {
    return 'AA errorea: $reason';
  }

  @override
  String get calloutTypeTooltip => 'Aipamen mota';

  @override
  String get calloutTypeInfo => 'Info';

  @override
  String get calloutTypeSuccess => 'Arrakasta';

  @override
  String get calloutTypeWarning => 'Abisua';

  @override
  String get calloutTypeError => 'Errorea';

  @override
  String get calloutTypeNote => 'Oharra';
}
