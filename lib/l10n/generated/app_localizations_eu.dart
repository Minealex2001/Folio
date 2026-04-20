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
      'Aukeratu temaren distira, nabarmentze-kolorearen jatorria (Windows, Folio edo pertsonalizatua), zooma eta hizkuntza.';

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
  String get backlinksTitle => 'Sarrerako erreferentziak';

  @override
  String get backlinksEmpty =>
      'Oraindik ez dago orrialde bat hona estekatzeko.';

  @override
  String get showBacklinks => 'Erakutsi erreferentziak';

  @override
  String get hideBacklinks => 'Ezkutatu erreferentziak';

  @override
  String get commentsTitle => 'Iruzkinak';

  @override
  String get commentsEmpty => 'Oraindik ez dago iruzkinik. Izan zaitez lehena!';

  @override
  String get commentsAddHint => 'Gehitu iruzkina…';

  @override
  String get commentsResolve => 'Konpondu';

  @override
  String get commentsReopen => 'Berriro ireki';

  @override
  String get commentsDelete => 'Ezabatu';

  @override
  String get commentsResolved => 'Ebatzita';

  @override
  String get showComments => 'Erakutsi iruzkinak';

  @override
  String get hideComments => 'Ezkutatu iruzkinak';

  @override
  String get propTitle => 'Propietateak';

  @override
  String get propAdd => 'Gehitu propietatea';

  @override
  String get propRemove => 'Ezabatu propietatea';

  @override
  String get propRename => 'Berrizendatu';

  @override
  String get propTypeText => 'Testua';

  @override
  String get propTypeNumber => 'Zenbakia';

  @override
  String get propTypeDate => 'Data';

  @override
  String get propTypeSelect => 'Hautapena';

  @override
  String get propTypeStatus => 'Egoera';

  @override
  String get propTypeUrl => 'URL';

  @override
  String get propTypeCheckbox => 'Kontrol-laukia';

  @override
  String get propNotSet => 'Hutsik';

  @override
  String get propAddOption => 'Gehitu aukera';

  @override
  String get propStatusNotStarted => 'Hasi gabe';

  @override
  String get propStatusInProgress => 'Abian';

  @override
  String get propStatusDone => 'Eginda';

  @override
  String get tagSectionTitle => 'Etiketak';

  @override
  String get tagAdd => 'Etiketa gehitu';

  @override
  String get tagRemove => 'Etiketa ezabatu';

  @override
  String get tagFilterAll => 'Guztiak';

  @override
  String get tagInputHint => 'Etiketa berria…';

  @override
  String get tagNoPagesForFilter => 'Ez dago orririk etiketa honekin.';

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
  String get meetingNoteCloudRequiresAiEnabled =>
      'Aktibatu AA Ezarpenetan hodeiko transkripzioa (Quill Cloud) erabiltzeko.';

  @override
  String meetingNoteHardwareSummary(int cpus, Object ramLabel) {
    return '$cpus nukleo · $ramLabel';
  }

  @override
  String get meetingNoteHardwareRamUnknown => 'RAM ezezaguna';

  @override
  String meetingNoteHardwareRecommended(Object modelLabel) {
    return 'Gailu honetarako gomendatutako eredua: $modelLabel';
  }

  @override
  String get meetingNoteLocalTranscriptionNotViable =>
      'Gailu honek ez ditu transkripzio lokalaren gutxieneko eskakizunak. Soilik audioa gordeko da, «Behartu transkripzio lokala» gaitzen ez baduzu Ezarpenetan edo Quill Cloud AA aktibatuta erabili ezean.';

  @override
  String get meetingNoteGenerateTranscription => 'Sortu transkripzioa';

  @override
  String get meetingNoteGenerateTranscriptionSubtitle =>
      'Desgaitu ohar honetan soilik audioa gordetzeko.';

  @override
  String get meetingNoteSettingsAutoWhisperModel =>
      'Aukeratu eredua automatikoki hardwarearen arabera';

  @override
  String get meetingNoteSettingsForceLocalTranscription =>
      'Behartu transkripzio lokala (motela edo ezegonkorra izan daiteke)';

  @override
  String get meetingNoteSettingsHardwareIntro =>
      'Transkripzio lokalarentzako errendimendua detektatua.';

  @override
  String get meetingNoteRecordingAudioOnlyBadge => 'Audio soilik';

  @override
  String get meetingNotePerNoteTranscriptionOffHint =>
      'Transkripzioa desgaituta dago ohar honetarako.';

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
  String get meetingNoteModelMedium => 'Aurreratua';

  @override
  String get meetingNoteModelTurbo => 'Kalitate maximoa';

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
  String get formatToolbarScrollPrevious => 'Aurreko tresnak';

  @override
  String get formatToolbarScrollNext => 'Tresna gehiago';

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
  String get exportPage => 'Esportatu…';

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
      'Instalatu LM Studio, abiarazi bere tokiko zerbitzaria eta egiaztatu http://127.0.0.1:1234 helbidean erantzuten duela.';

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
  String get tasksCaptureSettingsSection => 'Zereginak (azken harrapaketa)';

  @override
  String get taskInboxPageTitle => 'Zereginen sarrerako orria';

  @override
  String get taskInboxPageSubtitle =>
      'Azken harrapaketaz gehitutako zereginak gordetzen diren orria.';

  @override
  String get taskInboxNone =>
      'Definitu gabe (lehenengoa gordetzean sortzen da)';

  @override
  String get taskInboxDefaultTitle => 'Zereginen sarrerako orria';

  @override
  String get taskAliasManageTitle => 'Helburuko aliasak';

  @override
  String get taskAliasManageSubtitle =>
      'Erabili `#etiketa` edo `@etiketa` amaieran. Definitu gakoa ikurrik gabe (adib. lana) eta helburuko orria.';

  @override
  String get taskAliasAddButton => 'Gehitu aliasa';

  @override
  String get taskAliasTagLabel => 'Etiketa';

  @override
  String get taskAliasTargetLabel => 'Orria';

  @override
  String get taskAliasDeleteTooltip => 'Kendu';

  @override
  String get taskQuickAddTitle => 'Zeregin azken harrapaketa';

  @override
  String get taskQuickAddHint =>
      'Adib.: Erosi esnea bihar altua #lana. Halaber: due:2026-04-20, p1, aurrerapenean.';

  @override
  String get taskQuickAddConfirm => 'Gehitu';

  @override
  String get taskQuickAddSuccess => 'Zeregina gehituta.';

  @override
  String get taskQuickAddAliasTargetMissing =>
      'Aliasaren helburuko orria jada ez dago.';

  @override
  String get taskHubTitle => 'Zeregin guztiak';

  @override
  String get taskHubClose => 'Itxi ikuspegia';

  @override
  String get taskHubDashboardHelpTitle => 'Dashboard estiloko ideiak';

  @override
  String get taskHubDashboardHelpBody =>
      'Sortu zutabe-bloke bat duen orria eta lotu zerrenda-orriak testuinguruka, edo erabili datu-base bloke bat data eta egoerekin. Azken harrapaketa eta ikuspegi hau Snippets bezalako aplikazioetan inspiratuta daude.';

  @override
  String get taskHubEmpty => 'Ez dago zereginik liburu honetan.';

  @override
  String get taskHubFilterAll => 'Guztiak';

  @override
  String get taskHubFilterActive => 'Zain';

  @override
  String get taskHubFilterDone => 'Eginda';

  @override
  String get taskHubFilterDueToday => 'Gaur amaitzen dira';

  @override
  String get taskHubFilterDueWeek => 'Aste honetan';

  @override
  String get taskHubFilterOverdue => 'Epeaz kanpo';

  @override
  String get taskHubOpen => 'Ireki';

  @override
  String get taskHubMarkDone => 'Eginda';

  @override
  String get taskHubIncludeTodos => 'Sartu kontrol-zerrendak';

  @override
  String get sidebarQuickAddTask => 'Zeregin azkarra';

  @override
  String get sidebarTaskHub => 'Zeregin guztiak';

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
      'Gorde-lekua desblokeatuta dagoen bitartean, Foliok automatikoki egiten du babeskopia aukeratutako maiztasunarekin. Aktibatu karpetako babeskopia, hodeikoa, edo biak.';

  @override
  String get scheduledVaultBackupFolderTitle => 'Babeskopia karpetan';

  @override
  String get scheduledVaultBackupFolderSubtitle =>
      'ZIP enkriptatua gordetzen du konfiguratutako karpetan intervalo bakoitzean.';

  @override
  String get scheduledVaultBackupChooseFolder => 'Babeskopia-karpeta';

  @override
  String get scheduledVaultBackupClearFolderTooltip => 'Karpeta garbitu';

  @override
  String get scheduledVaultBackupCloudOnlyTitle =>
      'Programatutako babeskopiak hodeian soilik';

  @override
  String get scheduledVaultBackupCloudOnlySubtitle =>
      'Ez du ZIPik gordetzen diskoan. Babeskopiak hodeira bakarrik igotzen ditu.';

  @override
  String get scheduledVaultBackupIntervalLabel => 'Maiztasuna';

  @override
  String scheduledVaultBackupEveryNMinutes(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n minutu',
      one: '1 minutu',
    );
    return '$_temp0';
  }

  @override
  String scheduledVaultBackupEveryNHours(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n ordu',
      one: '1 ordu',
    );
    return '$_temp0';
  }

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
  String vaultBackupDiskSizeApprox(String size) {
    return 'Diskoan gutxi gorabeherako tamaina: $size';
  }

  @override
  String get vaultBackupDiskSizeLoading => 'Diskoko tamaina kalkulatzen…';

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
  String get folioCloudMicrosoftStoreBillingTitle =>
      'Microsoft Store (Windows)';

  @override
  String get folioCloudMicrosoftStoreBillingSubtitle =>
      'Stripe-rekin berdina: harpidetza eta tinta; dendak kobratzen du eta zerbitzariak eroskera baliozkotzen du. Produktu-id-ak --dart-define-rekin eta Azure AD Cloud Functions-en konfiguratu.';

  @override
  String get folioCloudMicrosoftStoreSubscribeButton => 'Harpidetza dendan';

  @override
  String get folioCloudMicrosoftStoreSyncButton => 'Sinkronizatu dendarekin';

  @override
  String get folioCloudMicrosoftStoreInkTitle => 'Tinta — Microsoft Store';

  @override
  String get folioCloudMicrosoftStoreInkPackSmall => 'Tintazio txiki (denda)';

  @override
  String get folioCloudMicrosoftStoreInkPackMedium => 'Tintazio ertain (denda)';

  @override
  String get folioCloudMicrosoftStoreInkPackLarge => 'Tintazio handi (denda)';

  @override
  String get folioCloudMicrosoftStoreSyncedSnack =>
      'Microsoft Store-rekin sinkronizatuta.';

  @override
  String get folioCloudMicrosoftStoreAppliedSnack =>
      'Erosketa aplikatu da. Aldaketarik ikusten ez baduzu, sakatu sinkronizatu.';

  @override
  String get folioCloudPurchaseChannelTitle => 'Non ordaindu nahi duzu?';

  @override
  String get folioCloudPurchaseChannelBody =>
      'Windows-en integratutako Microsoft Store erabili edo nabigatzailean txartelarekin ordaindu (Stripe). Plana eta tinta berdinak dira.';

  @override
  String get folioCloudPurchaseChannelMicrosoftStore => 'Microsoft Store';

  @override
  String get folioCloudPurchaseChannelStripe => 'Nabigatzailean (Stripe)';

  @override
  String get folioCloudPurchaseChannelCancel => 'Utzi';

  @override
  String get folioCloudPurchaseChannelStoreNotConfigured =>
      'Dendaren aukera ez dago konfiguratuta konpilazio honetan (produktu-id-ak falta dira).';

  @override
  String get folioCloudPurchaseChannelStoreNotConfiguredHint =>
      'Konpilatu --dart-define=MS_STORE_…-rekin edo erabili nabigatzaileko ordainketa.';

  @override
  String get folioCloudMicrosoftStoreSyncHint =>
      'Windows-en, «Eguneratu» Microsoft Store ere sinkronizatzen du (Stripe-rekin botoi bera).';

  @override
  String get folioCloudUploadEncryptedBackup => 'Egin babeskopia hodeian orain';

  @override
  String get folioCloudUploadEncryptedBackupSubtitle =>
      'Foliok irekita duzun gorde-lekuaren babeskopia enkriptatu bat sortu eta igotzen du — ZIP esportazio eskuzkorik gabe.';

  @override
  String get folioCloudUploadSnackOk =>
      'Gorde-lekuaren babeskopia hodeian gordeta.';

  @override
  String get scheduledVaultBackupCloudSyncTitle => 'Babeskopia Folio Cloud-en';

  @override
  String get scheduledVaultBackupCloudSyncSubtitle =>
      'Programatutako intervalo bakoitzean, babeskopia enkriptatua automatikoki igotzen du zure Folio Cloud kontura.';

  @override
  String get folioCloudCloudBackupsList => 'Hodeiko babeskopiak';

  @override
  String get folioCloudBackupsUsed => 'Erabilita';

  @override
  String get folioCloudBackupsLimit => 'Muga';

  @override
  String get folioCloudBackupsRemaining => 'Geratzen dena';

  @override
  String get folioCloudBackupStorageStatUsed => 'Erabilita (biltegiratzea)';

  @override
  String get folioCloudBackupStorageStatQuota => 'Kuota';

  @override
  String get folioCloudBackupStorageStatRemaining => 'Geratzen dena';

  @override
  String get folioCloudBackupStorageExpansionTitle =>
      'Hodeiko babeskopien biltegiratzea zabaldu';

  @override
  String get folioCloudBackupStorageLibrarySmallTitle => 'Liburutegi txikia';

  @override
  String get folioCloudBackupStorageLibrarySmallDetail => '+20 GB · 1,99 €/hil';

  @override
  String get folioCloudBackupStorageLibraryMediumTitle => 'Liburutegi ertaina';

  @override
  String get folioCloudBackupStorageLibraryMediumDetail =>
      '+75 GB · 4,99 €/hil';

  @override
  String get folioCloudBackupStorageLibraryLargeTitle => 'Liburutegi handia';

  @override
  String get folioCloudBackupStorageLibraryLargeDetail =>
      '+250 GB · 9,99 €/hil';

  @override
  String get folioCloudSubscribeBackupStorageAddon => 'Harpidetu';

  @override
  String get folioCloudBackupTypeIncremental =>
      'Babeskopi inkrementala (azkena)';

  @override
  String get folioCloudBackupPackNoDownload =>
      'Babeskopi inkrementalak «Inportatu eta gainidatzi» bidez leheneratzen dira. Ez dago fitxategi deskargarik bereizita.';

  @override
  String get folioCloudBackupQuotaExceeded =>
      'Ez dago hodeiko babeskopientzako biltegiratze nahikorik. Erosi zabaltze bat edo ezabatu backups/ karpetako babeskopi oso zaharrak.';

  @override
  String get onboardingCloudBackupNeedLegacyArchive =>
      'Koaderno honek babeskopi inkrementala soilik du hodeian. Gailu berri bat konfiguratzeko, deskargatu (.tar.gz) fitxategi oso bat Folio duen beste gailu batetik edo sortu ezarpenak → esportatu ataletik.';

  @override
  String get onboardingCloudBackupNeedRestoreWrap =>
      'Babeskopi inkremental honek oraindik ez du berreskuratze-giltza hodeian. Sortu zenuen gailuan, ireki Folio → Ezarpenak → igo babeskopia hodeira (sartu koadernoaren pasahitza eskatzen dizunean). (.zip) fitxategi oso bat ere erabil dezakezu baduzu.';

  @override
  String get onboardingCloudBackupIncrementalRestoreBody =>
      'Hodeiko babeskopi inkrementala prest. Sartu koadernoaren pasahitza (desblokeatzeko erabiltzen duzuna). Koadernoa zifratu gabe bazegoen, erabili igoeran ezarri zenuen berreskuratze-pasahitza.';

  @override
  String get cloudPackRestorePasswordHelper =>
      'Sin contraseña → déjalo en blanco';

  @override
  String get settingsCloudBackupWrapPasswordTitle =>
      'Berreskuratzea beste gailuetan';

  @override
  String get settingsCloudBackupWrapPasswordBody =>
      'Sartu koaderno honen pasahitza. Zure kontuan zifratuta gordeko da babeskopi inkrementala Folio gailu berri batean instalatzean leheneratzeko.';

  @override
  String get settingsCloudBackupWrapPasswordRequired =>
      'Koadernoaren pasahitza beharrezkoa da.';

  @override
  String get settingsCloudBackupWrapPasswordBodyPlain =>
      'Aukerakoa: aukeratu berreskuratze-pasahitza bat babeskopi inkrementala beste gailu batean leheneratzeko. Utzi hutsik gailu hau soilik erabiliko baduzu.';

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
  String get updaterOpenApkDownloadQuestion => 'Ireki APKaren deskarga orain?';

  @override
  String get updaterManualCheckUnsupportedPlatform =>
      'Barne eguneratzailea Windows eta Android-en soilik dago erabilgarri.';

  @override
  String get updaterManualCheckAlreadyLatest => 'Azken bertsioa duzu jada.';

  @override
  String updaterDialogLineCurrentVersion(Object currentVersion) {
    return 'Uneko bertsioa: $currentVersion';
  }

  @override
  String updaterDialogLineNewVersion(Object releaseVersion) {
    return 'Bertsio berria: $releaseVersion';
  }

  @override
  String get updaterApkUrlInvalidSnack =>
      'Ez da baliozko APK URLrik aurkitu release-an.';

  @override
  String get updaterApkOpenFailedSnack =>
      'Ezin izan da APKaren deskarga ireki.';

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
  String get taskRecurrenceNone => 'Errepikatu gabe';

  @override
  String get taskRecurrenceLabel => 'Errepikapena';

  @override
  String get taskRecurrenceDaily => 'Egunero';

  @override
  String get taskRecurrenceWeekly => 'Astero';

  @override
  String get taskRecurrenceMonthly => 'Hilero';

  @override
  String get taskRecurrenceYearly => 'Urtero';

  @override
  String get taskReminderTooltip => 'Gogoratu muga-egunean';

  @override
  String get taskReminderOnTooltip => 'Gogorarazlea aktibo';

  @override
  String get taskOverdueReminder => 'Iraungitako zeregina';

  @override
  String get taskDueTodayReminder => 'Gaur iraungitzen da';

  @override
  String get settingsWindowsNotifications => 'Windows jakinarazpenak';

  @override
  String get settingsWindowsNotificationsSubtitle =>
      'Windows jakinarazpen natiboek erakutsiko dituzte gaur iraungitzen diren edo berandututa dauden zereginak';

  @override
  String get title => 'Izenburua';

  @override
  String get description => 'Deskribapena';

  @override
  String get priority => 'Lehentasuna';

  @override
  String get status => 'Egoera';

  @override
  String get none => 'Bat ere ez';

  @override
  String get low => 'Baxua';

  @override
  String get medium => 'Ertaina';

  @override
  String get high => 'Altua';

  @override
  String get startDate => 'Hasiera-data';

  @override
  String get dueDate => 'Amaiera-data';

  @override
  String get timeSpentMinutes => 'Erabilitako denbora (minutuak)';

  @override
  String get taskBlocked => 'Blokeatuta';

  @override
  String get taskBlockedReason => 'Blokeoaren arrazoia';

  @override
  String get subtasks => 'Azpiatazak';

  @override
  String get add => 'Gehitu';

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

  @override
  String get blockEditorEnterHintNewBlock =>
      'Sartu: bloke berria (kodean: Sartu = lerroa)';

  @override
  String get blockEditorEnterHintNewLine => 'Sartu: lerro berria';

  @override
  String blockEditorShortcutsHintMobile(String enterHint) {
    return '$enterHint · / blokeetarako · sakatu blokeari ekintza gehiagorako';
  }

  @override
  String blockEditorShortcutsHintDesktop(String enterHint) {
    return '$enterHint · Maius+Sartu: lerroa · / motak · # izenburua (lerro berean) · - · * · [] · ``` taula/irudia / · formatua: fokuratzean barra edo ** _ <u> ` ~~';
  }

  @override
  String blockEditorSelectedBlocksBanner(int count) {
    return '$count bloke hautatuak · Maius: tartea · Ktrl/Cmd: txandakatu';
  }

  @override
  String get blockEditorDuplicate => 'Bikoiztu';

  @override
  String get blockEditorClearSelectionTooltip => 'Garbitu hautapena';

  @override
  String get blockEditorMenuRewriteWithAi => 'Berriz idatzi AArekin…';

  @override
  String get blockEditorMenuMoveUp => 'Eraman gora';

  @override
  String get blockEditorMenuMoveDown => 'Eraman behera';

  @override
  String get blockEditorMenuDuplicateBlock => 'Bikoiztu blokea';

  @override
  String get blockEditorMenuAppearance => 'Itxura…';

  @override
  String get blockEditorMenuCalloutIcon => 'Callout ikonoa…';

  @override
  String blockEditorCalloutMenuType(String typeName) {
    return 'Mota: $typeName';
  }

  @override
  String get blockEditorCopyLink => 'Kopiatu esteka';

  @override
  String get blockEditorMenuCreateSubpage => 'Sortu azpiorrialdea';

  @override
  String get blockEditorMenuLinkPage => 'Lotu orrialdea…';

  @override
  String get blockEditorMenuOpenSubpage => 'Ireki azpiorrialdea';

  @override
  String get blockEditorMenuPickImage => 'Aukeratu irudia…';

  @override
  String get blockEditorMenuRemoveImage => 'Kendu irudia';

  @override
  String get blockEditorMenuCodeLanguage => 'Kodearen hizkuntza…';

  @override
  String get blockEditorMenuEditDiagram => 'Editatu diagrama…';

  @override
  String get blockEditorMenuBackToPreview => 'Itzuli aurreikuspena';

  @override
  String get blockEditorMenuChangeFile => 'Aldatu fitxategia…';

  @override
  String get blockEditorMenuRemoveFile => 'Kendu fitxategia';

  @override
  String get blockEditorMenuChangeVideo => 'Aldatu bideoa…';

  @override
  String get blockEditorMenuRemoveVideo => 'Kendu bideoa';

  @override
  String get blockEditorMenuChangeAudio => 'Aldatu audioa…';

  @override
  String get blockEditorMenuRemoveAudio => 'Kendu audioa';

  @override
  String get blockEditorMenuEditLabel => 'Editatu etiketa…';

  @override
  String get blockEditorMenuAddRow => 'Gehitu errenkada';

  @override
  String get blockEditorMenuRemoveLastRow => 'Kendu azken errenkada';

  @override
  String get blockEditorMenuAddColumn => 'Gehitu zutabea';

  @override
  String get blockEditorMenuRemoveLastColumn => 'Kendu azken zutabea';

  @override
  String get blockEditorMenuAddProperty => 'Gehitu propietatea';

  @override
  String get blockEditorMenuChangeBlockType => 'Aldatu bloke mota…';

  @override
  String get blockEditorMenuDeleteBlock => 'Ezabatu blokea';

  @override
  String get blockEditorAppearanceTitle => 'Blokearen itxura';

  @override
  String get blockEditorAppearanceSubtitle =>
      'Pertsonalizatu tamaina, testuaren kolorea eta atzeko planoa bloke honetan.';

  @override
  String get blockEditorAppearanceSize => 'Tamaina';

  @override
  String get blockEditorAppearanceTextColor => 'Testuaren kolorea';

  @override
  String get blockEditorAppearanceBackground => 'Atzeko planoa';

  @override
  String get blockEditorAppearancePreviewEmpty => 'Honela ikusiko da blokea.';

  @override
  String get blockEditorReset => 'Berrezarri';

  @override
  String get blockEditorCodeLanguageTitle => 'Kodearen hizkuntza';

  @override
  String get blockEditorCodeLanguageSubtitle =>
      'Nabarmentzea hautatutako hizkuntzaren arabera.';

  @override
  String get blockEditorTemplateButtonTitle => 'Txantiloi-botoiaren etiketa';

  @override
  String get blockEditorTemplateButtonFieldLabel => 'Botoiaren testua';

  @override
  String get blockEditorTemplateButtonDefaultLabel => 'Txantiloia';

  @override
  String get blockEditorTextColorDefault => 'Gaia';

  @override
  String get blockEditorTextColorSubtle => 'Arina';

  @override
  String get blockEditorTextColorPrimary => 'Lehenetsia';

  @override
  String get blockEditorTextColorSecondary => 'Bigarren mailakoa';

  @override
  String get blockEditorTextColorTertiary => 'Azentua';

  @override
  String get blockEditorTextColorError => 'Errorea';

  @override
  String get blockEditorBackgroundNone => 'Atzeko planorik gabe';

  @override
  String get blockEditorBackgroundSurface => 'Azalera';

  @override
  String get blockEditorBackgroundPrimary => 'Lehenetsia';

  @override
  String get blockEditorBackgroundSecondary => 'Bigarren mailakoa';

  @override
  String get blockEditorBackgroundTertiary => 'Azentua';

  @override
  String get blockEditorBackgroundError => 'Errorea';

  @override
  String get blockEditorCmdDuplicatePrev => 'Bikoiztu aurreko blokea';

  @override
  String get blockEditorCmdDuplicatePrevHint =>
      'Klonatu berehala gaineko blokea';

  @override
  String get blockEditorCmdInsertDate => 'Txertatu data';

  @override
  String get blockEditorCmdInsertDateHint => 'Idatzi gaurko data';

  @override
  String get blockEditorCmdMentionPage => 'Aipatu orrialdea';

  @override
  String get blockEditorCmdMentionPageHint =>
      'Txertatu barne-esteka orrialde batera';

  @override
  String get blockEditorCmdTurnInto => 'Bihurtu blokea';

  @override
  String get blockEditorCmdTurnIntoHint => 'Aukeratu bloke mota hautatzailean';

  @override
  String get blockEditorMarkTaskComplete => 'Markatu ataza osatuta';

  @override
  String get blockEditorCalloutIconPickerTitle => 'Callout ikonoa';

  @override
  String get blockEditorCalloutIconPickerHelper =>
      'Aukeratu ikono bat callout blokearen tonu bisuala aldatzeko.';

  @override
  String get blockEditorIconPickerCustomEmoji => 'Emoji pertsonalizatua';

  @override
  String get blockEditorIconPickerQuickTab => 'Azkarrak';

  @override
  String get blockEditorIconPickerImportedTab => 'Inportatuak';

  @override
  String get blockEditorIconPickerAllTab => 'Denak';

  @override
  String get blockEditorIconPickerEmptyImported =>
      'Oraindik ez duzu ikonorik inportatu Ezarpenetan.';

  @override
  String get blockTypeSectionBasicText => 'Oinarrizko testua';

  @override
  String get blockTypeSectionLists => 'Zerrendak';

  @override
  String get blockTypeSectionMedia => 'Multimedia eta datuak';

  @override
  String get blockTypeSectionAdvanced => 'Aurreratua eta diseinua';

  @override
  String get blockTypeSectionEmbeds => 'Integrazioak';

  @override
  String get blockTypeParagraphLabel => 'Testua';

  @override
  String get blockTypeParagraphHint => 'Paragrafoa';

  @override
  String get blockTypeChildPageLabel => 'Orrialdea';

  @override
  String get blockTypeChildPageHint => 'Lotutako azpiorrialdea';

  @override
  String get blockTypeH1Label => '1. izenburua';

  @override
  String get blockTypeH1Hint => 'Izenburu handia · #';

  @override
  String get blockTypeH2Label => '2. izenburua';

  @override
  String get blockTypeH2Hint => 'Azpiizenburua · ##';

  @override
  String get blockTypeH3Label => '3. izenburua';

  @override
  String get blockTypeH3Hint => 'Izenburu txikiagoa · ###';

  @override
  String get blockTypeQuoteLabel => 'Aipua';

  @override
  String get blockTypeQuoteHint => 'Aipatutako testua';

  @override
  String get blockTypeDividerLabel => 'Zatitzailea';

  @override
  String get blockTypeDividerHint => 'Bereizlea · ---';

  @override
  String get blockTypeCalloutLabel => 'Nabarmendutako blokea';

  @override
  String get blockTypeCalloutHint => 'Jakinarazpena ikonoarekin';

  @override
  String get blockTypeBulletLabel => 'Buletadun zerrenda';

  @override
  String get blockTypeBulletHint => 'Puntudun zerrenda';

  @override
  String get blockTypeNumberedLabel => 'Zenbakidun zerrenda';

  @override
  String get blockTypeNumberedHint => '1, 2, 3 zerrenda';

  @override
  String get blockTypeTodoLabel => 'Ataza-zerrenda';

  @override
  String get blockTypeTodoHint => 'Egiaztapen-zerrenda';

  @override
  String get blockTypeTaskLabel => 'Ataza aberastua';

  @override
  String get blockTypeTaskHint => 'Egoera / lehentasuna / data';

  @override
  String get blockTypeToggleLabel => 'Desplegablea';

  @override
  String get blockTypeToggleHint => 'Edukia erakutsi edo ezkutatu';

  @override
  String get blockTypeImageLabel => 'Irudia';

  @override
  String get blockTypeImageHint => 'Tokiko edo kanpoko irudia';

  @override
  String get blockTypeBookmarkLabel => 'Aurreikuspenarekin laster-marka';

  @override
  String get blockTypeBookmarkHint => 'Estekadun txartela';

  @override
  String get blockTypeVideoLabel => 'Bideoa';

  @override
  String get blockTypeVideoHint => 'Fitxategia edo URLa';

  @override
  String get blockTypeAudioLabel => 'Audioa';

  @override
  String get blockTypeAudioHint => 'Audio erreproduzigailua';

  @override
  String get blockTypeMeetingNoteLabel => 'Bilera-oharra';

  @override
  String get blockTypeMeetingNoteHint => 'Grabatu eta transkribatu bilera bat';

  @override
  String get blockTypeCodeLabel => 'Kodea (Java, Python…)';

  @override
  String get blockTypeCodeHint => 'Sintaxidun blokea';

  @override
  String get blockTypeFileLabel => 'Fitxategia / PDF';

  @override
  String get blockTypeFileHint => 'Eranskina edo PDF';

  @override
  String get blockTypeTableLabel => 'Taula';

  @override
  String get blockTypeTableHint => 'Errenkadak eta zutabeak';

  @override
  String get blockTypeDatabaseLabel => 'Datu-basea';

  @override
  String get blockTypeDatabaseHint => 'Zerrenda/taula/tableroko ikuspegia';

  @override
  String get blockTypeKanbanLabel => 'Kanban';

  @override
  String get blockTypeKanbanHint =>
      'Orrialde honetako zereginentzako tablero-ikuspegia';

  @override
  String get kanbanBlockRowTitle => 'Kanban tableroa';

  @override
  String get kanbanBlockRowSubtitle =>
      'Orrialdea irekitzean tableroa ikusiko duzu. Tableroko barran erabili «Ireki bloke-editorea» bloke hau editatu edo kentzeko.';

  @override
  String get kanbanRowTodosExcluded => 'Checklistik gabe';

  @override
  String get kanbanToolbarOpenEditor => 'Ireki bloke-editorea';

  @override
  String get kanbanToolbarAddTask => 'Gehitu zeregina';

  @override
  String get kanbanClassicModeBanner =>
      'Bloke-editorea: Kanban blokea mugitu edo kendu dezakezu.';

  @override
  String get kanbanBackToBoard => 'Itzuli tablerora';

  @override
  String get kanbanMultipleBlocksSnack =>
      'Orrialde honek Kanban bloke bat baino gehiago ditu; lehena erabiltzen da.';

  @override
  String get kanbanEmptyColumn => 'Zereginik ez';

  @override
  String get blockTypeCanvasLabel => 'Mihise infinitua';

  @override
  String get blockTypeCanvasHint =>
      'Arbela librea nodoekin, formen eta gezietan';

  @override
  String get canvasBlockRowTitle => 'Mihise infinitua';

  @override
  String canvasBlockRowSubtitle(int nodes, int strokes) {
    return '$nodes nodo · $strokes lerro';
  }

  @override
  String get canvasToolbarOpenEditor => 'Ireki bloke editorea';

  @override
  String get canvasToolbarAddNode => 'Gehitu oharra';

  @override
  String get canvasToolbarAddShape => 'Gehitu forma';

  @override
  String get canvasToolbarDraw => 'Marraztu';

  @override
  String get canvasToolbarSelect => 'Hautatu';

  @override
  String get canvasToolbarExport => 'Esportatu irudi gisa';

  @override
  String get canvasToolbarConnect => 'Lotu nodoak';

  @override
  String get canvasToolbarAddBlock => 'Blokea gehitu';

  @override
  String get canvasClassicModeBanner =>
      'Bloke editorea: Mihise blokea mugitu edo ezabatu dezakezu.';

  @override
  String get canvasBackToCanvas => 'Itzuli mihisera';

  @override
  String get canvasMultipleBlocksSnack =>
      'Orrialde honek Mihise bloke bat baino gehiago ditu; lehena erabiltzen da.';

  @override
  String get canvasExportSuccess => 'Mihisea ondo esportatu da';

  @override
  String get canvasExportError => 'Errorea mihisea esportatzerakoan';

  @override
  String get canvasDeleteNodeConfirm => 'Nodo hau ezabatu?';

  @override
  String get blockTypeDriveLabel => 'Fitxategi Drive';

  @override
  String get blockTypeDriveHint => 'Fitxategi kudeatzailea orri honetarako';

  @override
  String get driveBlockRowTitle => 'Fitxategi Drive';

  @override
  String driveBlockRowSubtitle(int files, int folders) {
    return '$files fitxategi · $folders karpeta';
  }

  @override
  String get driveNewFolder => 'Karpeta berria';

  @override
  String get driveUploadFile => 'Fitxategia igo';

  @override
  String get driveImportFromVault => 'Inportatu vault-etik';

  @override
  String get driveViewGrid => 'Sarea';

  @override
  String get driveViewList => 'Zerrenda';

  @override
  String get driveEditBlock => 'Blokea editatu';

  @override
  String get driveFolderEmpty => 'Karpeta honek ez dauka ezer';

  @override
  String get driveDeleteConfirm => 'Fitxategi hau ezabatu?';

  @override
  String get driveOpenFile => 'Fitxategia ireki';

  @override
  String get driveMoveTo => 'Mugitu hona…';

  @override
  String get driveClassicModeBanner =>
      'Bloke editorea: Drive blokea mugitu edo ezabatu dezakezu.';

  @override
  String get driveBackToDrive => 'Drive-ra itzuli';

  @override
  String get driveMultipleBlocksSnack =>
      'Orri honek Drive bloke bat baino gehiago ditu; lehena erabiltzen da.';

  @override
  String get driveDeleteOriginalsTitle => 'Originalak inportatzean ezabatu';

  @override
  String get driveDeleteOriginalsSubtitle =>
      'Fitxategiak drivera igotzerakoan, originalak automatikoki ezabatzen dira diskotik.';

  @override
  String get blockTypeEquationLabel => 'Ekuazioa (LaTeX)';

  @override
  String get blockTypeEquationHint => 'Matematika-formulak';

  @override
  String get blockTypeMermaidLabel => 'Diagrama (Mermaid)';

  @override
  String get blockTypeMermaidHint => 'Fluxu-diagrama edo eskema';

  @override
  String get blockTypeTocLabel => 'Eduki-taula';

  @override
  String get blockTypeTocHint => 'Indize automatikoa';

  @override
  String get blockTypeBreadcrumbLabel => 'Nabigazio-bidea';

  @override
  String get blockTypeBreadcrumbHint => 'Nabigazio-bidearen ibilbidea';

  @override
  String get blockTypeTemplateButtonLabel => 'Txantiloi-botoia';

  @override
  String get blockTypeTemplateButtonHint =>
      'Aurrez definitutako blokea txertatu';

  @override
  String get blockTypeColumnListLabel => 'Zutabeak';

  @override
  String get blockTypeColumnListHint => 'Zutabeen diseinua';

  @override
  String get blockTypeEmbedLabel => 'Web txertatua';

  @override
  String get blockTypeEmbedHint => 'YouTube, Figma, Docs…';

  @override
  String get integrationDialogTitleUpdatePermission =>
      'Eguneratu integrazio-baimena';

  @override
  String get integrationDialogTitleAllowConnect =>
      'Baimendu aplikazio honi konektatzea';

  @override
  String integrationDialogBodyUpdate(
    Object previousVersion,
    Object integrationVersion,
  ) {
    return 'Aplikazio hau dagoeneko onartuta zegoen $previousVersion integrazioarekin eta orain $integrationVersion bertsioarekin sarbidea eskatzen du.';
  }

  @override
  String integrationDialogBodyNew(
    Object appName,
    Object appVersion,
    Object integrationVersion,
  ) {
    return '«$appName» Folio-ren zubi lokalarekin erabili nahi du $appVersion aplikazio-bertsioarekin eta $integrationVersion integrazioarekin.';
  }

  @override
  String get integrationChipLocalhostOnly => 'Localhost soilik';

  @override
  String get integrationChipRevocableApproval =>
      'Bertan behera utz daitekeen onarpena';

  @override
  String get integrationChipNoSharedSecret => 'Partekatutako sekreturik gabe';

  @override
  String get integrationChipScopedByAppId => 'Baimena appId bidez';

  @override
  String get integrationMetaPreviouslyApprovedVersion =>
      'Aurretik onartutako bertsioa';

  @override
  String get integrationSectionWhatAppCanDo =>
      'Aplikazio honek egin ahal izango duena';

  @override
  String get integrationCapEphemeralSessionsTitle =>
      'Ireki saio lokal laburrak';

  @override
  String get integrationCapEphemeralSessionsBody =>
      'Saio aldi baterako bat has dezake Folio-ren zubi lokalarekin hitz egiteko gailu honetan.';

  @override
  String get integrationCapImportPagesTitle =>
      'Inportatu eta eguneratu bere orrialdeak';

  @override
  String get integrationCapImportPagesBody =>
      'Orrialdeak sor ditzake, zerrendatu eta eguneratu soilik aplikazio berak aurretik inportatu zituenak.';

  @override
  String get integrationCapCustomEmojisTitle =>
      'Kudeatu bere emoji pertsonalizatuak';

  @override
  String get integrationCapCustomEmojisBody =>
      'Bere emoji edo ikono inportatuen katalogoa soilik zerrendatu, sortu, ordezkatu eta ezabatu dezake.';

  @override
  String get integrationCapUnlockedVaultTitle =>
      'Lan egin koadernoa desblokeatuta dagoenean soilik';

  @override
  String get integrationCapUnlockedVaultBody =>
      'Eskaerak Folio irekita dagoenean, koadernoa erabilgarri dagoenean eta uneko saioa aktibo dagoenean soilik dabiltza.';

  @override
  String get integrationSectionWhatStaysBlocked =>
      'Blokeatuta jarraituko duena';

  @override
  String get integrationBlockNoSeeAllTitle => 'Ezin du zure eduki guztia ikusi';

  @override
  String get integrationBlockNoSeeAllBody =>
      'Ez du koadernorako sarbide orokorra. Bere appId bidez berak inportatu zuena soilik zerrendatu dezake.';

  @override
  String get integrationBlockNoBypassTitle =>
      'Ezin du blokeoa edo zifratzea saihestu';

  @override
  String get integrationBlockNoBypassBody =>
      'Koadernoa blokeatuta badago edo saiorik ez badago, Foliok eragiketa baztertuko du.';

  @override
  String get integrationBlockNoOtherAppsTitle =>
      'Ezin du beste aplikazio batzuen datuak ukitu';

  @override
  String get integrationBlockNoOtherAppsBody =>
      'Ezin ditu beste aplikazio onartuek inportatutako orrialdeak edo emojiak kudeatu.';

  @override
  String get integrationBlockNoRemoteTitle =>
      'Ezin du zure makinatik kanpotik sartu';

  @override
  String get integrationBlockNoRemoteBody =>
      'Zubia localhost-era mugatzen da eta onarpen hau geroago Ezarpenetatik bertan behera utzi daiteke.';

  @override
  String integrationSnackMarkdownImportDone(Object pageTitle) {
    return 'Inportazioa osatu da: $pageTitle.';
  }

  @override
  String integrationSnackJsonImportDone(Object pageTitle) {
    return 'JSON inportazioa osatu da: $pageTitle.';
  }

  @override
  String integrationSnackPageUpdateDone(Object pageTitle) {
    return 'Integrazio-eguneratzea osatu da: $pageTitle.';
  }

  @override
  String get markdownImportModeDialogTitle => 'Inportatu Markdown';

  @override
  String get markdownImportModeDialogBody =>
      'Aukeratu nola aplikatu Markdown fitxategia.';

  @override
  String get markdownImportModeNewPage => 'Orrialde berria';

  @override
  String get markdownImportModeAppend => 'Gehitu unekoari';

  @override
  String get markdownImportModeReplace => 'Ordeztu unekoa';

  @override
  String get markdownImportCouldNotReadPath =>
      'Ezin izan da fitxategiaren bidea irakurri.';

  @override
  String markdownImportedBlocks(Object pageTitle, int blockCount) {
    return 'Markdown inportatua: $pageTitle ($blockCount bloke).';
  }

  @override
  String markdownImportFailedWithError(Object error) {
    return 'Ezin izan da Markdown inportatu: $error';
  }

  @override
  String get importPage => 'Inportatu…';

  @override
  String get exportMarkdownFileDialogTitle =>
      'Esportatu orrialdea Markdown-era';

  @override
  String get markdownExportSuccess => 'Orrialdea Markdown-era esportatu da.';

  @override
  String markdownExportFailedWithError(Object error) {
    return 'Ezin izan da orrialdea esportatu: $error';
  }

  @override
  String get exportPageDialogTitle => 'Esportatu orrialdea';

  @override
  String get exportPageFormatMarkdown => 'Markdown (.md)';

  @override
  String get exportPageFormatHtml => 'HTML (.html)';

  @override
  String get exportPageFormatTxt => 'Testua (.txt)';

  @override
  String get exportPageFormatJson => 'JSON (.json)';

  @override
  String get exportPageFormatPdf => 'PDF (.pdf)';

  @override
  String get exportHtmlFileDialogTitle => 'Esportatu orrialdea HTML-ra';

  @override
  String get htmlExportSuccess => 'Orrialdea HTML-ra esportatu da.';

  @override
  String htmlExportFailedWithError(Object error) {
    return 'Ezin izan da orrialdea esportatu: $error';
  }

  @override
  String get exportTxtFileDialogTitle => 'Esportatu orrialdea testu gisa';

  @override
  String get txtExportSuccess => 'Orrialdea testu gisa esportatu da.';

  @override
  String txtExportFailedWithError(Object error) {
    return 'Ezin izan da orrialdea esportatu: $error';
  }

  @override
  String get exportJsonFileDialogTitle => 'Esportatu orrialdea JSON-era';

  @override
  String get jsonExportSuccess => 'Orrialdea JSON-era esportatu da.';

  @override
  String jsonExportFailedWithError(Object error) {
    return 'Ezin izan da orrialdea esportatu: $error';
  }

  @override
  String get exportPdfFileDialogTitle => 'Esportatu orrialdea PDF-era';

  @override
  String get pdfExportSuccess => 'Orrialdea PDF-era esportatu da.';

  @override
  String pdfExportFailedWithError(Object error) {
    return 'Ezin izan da orrialdea esportatu: $error';
  }

  @override
  String get firebaseUnavailablePublish => 'Firebase ez dago erabilgarri.';

  @override
  String get signInCloudToPublishWeb =>
      'Hasi saioa hodeiko kontuan (Ezarpenak) argitaratzeko.';

  @override
  String get planMissingWebPublish =>
      'Zure planak ez du web-argitalpenik edo harpidetza ez dago aktibo.';

  @override
  String get publishWebDialogTitle => 'Argitaratu webean';

  @override
  String get publishWebSlugLabel => 'URLa (slug)';

  @override
  String get publishWebSlugHint => 'nire-oharra';

  @override
  String get publishWebSlugHelper =>
      'Letrak, zenbakiak eta marratxoak. URL publikoan agertuko da.';

  @override
  String get publishWebAction => 'Argitaratu';

  @override
  String get publishWebEmptySlug => 'Slug hutsa.';

  @override
  String publishWebSuccessWithUrl(Object url) {
    return 'Argitaratuta: $url';
  }

  @override
  String publishWebFailedWithError(Object error) {
    return 'Ezin izan da argitaratu: $error';
  }

  @override
  String get publishWebMenuLabel => 'Argitaratu webean';

  @override
  String get mobileFabDone => 'Eginda';

  @override
  String get mobileFabEdit => 'Editatu';

  @override
  String get mobileFabAddBlock => 'Blokea';

  @override
  String get mermaidPreviewDialogTitle => 'Diagrama';

  @override
  String get mermaidDiagramSemanticsLabel =>
      'Mermaid diagrama, sakatu handitzeko';

  @override
  String get databaseSortAz => 'Ordenatu A-Z';

  @override
  String get databaseSortLabel => 'Ordenatu';

  @override
  String get databaseFilterAnd => 'ETA';

  @override
  String get databaseFilterOr => 'EDO';

  @override
  String get databaseSortDescending => 'Behera';

  @override
  String get databaseNewPropertyDialogTitle => 'Propietate berria';

  @override
  String databaseConfigurePropertyTitle(Object name) {
    return 'Konfiguratu: $name';
  }

  @override
  String get databaseLocalCurrentBadge => 'DB lokal aktiboa';

  @override
  String databaseRelateRowsTitle(Object name) {
    return 'Erlazionatu errenkadak ($name)';
  }

  @override
  String get databaseBoardNeedsGroupProperty =>
      'Konfiguratu talde-propietate bat taulerorako.';

  @override
  String get databaseGroupPropertyMissing => 'Talde-propietatea jada ez dago.';

  @override
  String get databaseCalendarNeedsDateProperty =>
      'Konfiguratu data-propietate bat egutegirako.';

  @override
  String get databaseNoDatedEvents => 'Ez dago data duten gertaerarik.';

  @override
  String get databaseConfigurePropertyTooltip => 'Konfiguratu propietatea';

  @override
  String get databaseFormulaHintExample =>
      'if(contains(Izena,\"x\"), add(1,2), 0)';

  @override
  String get createAction => 'Sortu';

  @override
  String get confirmAction => 'Berretsi';

  @override
  String get confirmRemoteEndpointTitle => 'Berretsi urruneko amaiera-puntua';

  @override
  String get shortcutGlobalSearchKeyChord => 'Ktrl + Maius + F';

  @override
  String get updateChannelRelease => 'Release';

  @override
  String get updateChannelBeta => 'Beta';

  @override
  String get blockActionChooseAudio => 'Aukeratu audioa…';

  @override
  String get blockActionCreateSubpage => 'Sortu azpi-orrialdea';

  @override
  String get blockActionLinkPage => 'Estekatu orrialdea…';

  @override
  String get defaultNewPageTitle => 'Orrialde berria';

  @override
  String defaultPageDuplicateTitle(Object title) {
    return '$title (kopia)';
  }

  @override
  String aiChatTitleNumbered(int n) {
    return 'Txat $n';
  }

  @override
  String get invalidFolioTemplateFile =>
      'Fitxategia ez da Folio txantiloi balioduna.';

  @override
  String get templateButtonDefaultLabel => 'Txantiloia';

  @override
  String get pageHtmlExportPublishedWithFolio => 'Foliorekin argitaratua';

  @override
  String get releaseReadinessSemverOk => 'SemVer bertsio balioduna';

  @override
  String get releaseReadinessEncryptedVault => 'Zifratutako koadernoa';

  @override
  String get releaseReadinessAiRemotePolicy =>
      'AA amaiera-puntuaren gidalerroa';

  @override
  String get releaseReadinessVaultUnlocked => 'Koadernoa desblokeatuta';

  @override
  String get releaseReadinessStableChannel => 'Kanal egonkorra hautatuta';

  @override
  String get aiPromptUserMessage => 'Erabiltzailearen mezua:';

  @override
  String get aiPromptOriginalMessage => 'Jatorrizko mezua:';

  @override
  String get aiPromptOriginalUserMessage =>
      'Erabiltzailearen jatorrizko mezua:';

  @override
  String get customIconImportEmptySource => 'Ikonaren iturburua hutsik dago.';

  @override
  String get customIconImportInvalidUrl => 'Ikonaren URLa ez da balioduna.';

  @override
  String get customIconImportInvalidSvg => 'Kopiatutako SVGa ez da balioduna.';

  @override
  String get customIconImportHttpHttpsOnly =>
      'Http edo https URLak soilik onartzen dira.';

  @override
  String get customIconImportDataUriMimeList =>
      'data:image/svg+xml, data:image/gif, data:image/webp edo data:image/png soilik onartzen dira.';

  @override
  String get customIconImportUnsupportedFormat =>
      'Formatu bateraezina. Erabili SVG, PNG, GIF edo WebP.';

  @override
  String get customIconImportSvgTooLarge => 'SVGa handiegia da inportatzeko.';

  @override
  String get customIconImportEmbeddedImageTooLarge =>
      'Txertatutako irudia handiegia da inportatzeko.';

  @override
  String customIconImportDownloadFailed(Object code) {
    return 'Ezin izan da ikonoa deskargatu ($code).';
  }

  @override
  String get customIconImportRemoteTooLarge => 'Urruneko ikonoa handiegia da.';

  @override
  String get customIconImportConnectFailed =>
      'Ezin izan da konektatu ikonoa deskargatzeko.';

  @override
  String get customIconImportCertFailed =>
      'Ziurtagiria huts egin du ikonoa deskargatzean.';

  @override
  String get customIconLabelDefault => 'Ikonoa pertsonalizatua';

  @override
  String get customIconLabelImported => 'Inportatutako ikonoa';

  @override
  String get customIconImportSucceeded => 'Ikono ongi inportatu da.';

  @override
  String get customIconClipboardEmpty => 'Arbela hutsik dago.';

  @override
  String get customIconRemoved => 'Ikono kendu da.';

  @override
  String get whisperModelTiny => 'Tiny (azkarra)';

  @override
  String get whisperModelBaseQ8 => 'Base q8 (orekatua)';

  @override
  String get whisperModelSmallQ8 =>
      'Small q8 (zehaztasun handia, disko gutxiago)';

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
  String get codeLangPlainText => 'Testu laua';

  @override
  String settingsAppRevoked(Object appId) {
    return 'Aplikazioa ezeztatuta: $appId';
  }

  @override
  String get settingsDeviceRevokedSnack => 'Gailua ezeztatuta.';

  @override
  String get settingsAiConnectionOk => 'AA konexioa OK';

  @override
  String settingsAiConnectionError(Object error) {
    return 'Konexio-errorea: $error';
  }

  @override
  String settingsAiListModelsFailed(Object error) {
    return 'Ezin izan dira modeloak zerrendatu: $error';
  }

  @override
  String get folioCloudCallableNotSignedIn =>
      'Cloud Functions deitzeko saioa hasi behar duzu';

  @override
  String get folioCloudCallableUnexpectedResponse =>
      'Cloud Functions-en erantzun ustekabekoa';

  @override
  String folioCloudCallableHttpError(int code, Object name) {
    return 'HTTP $code $name deitzerakoan';
  }

  @override
  String get folioCloudCallableNoIdToken =>
      'Ez dago ID tokenik Cloud Functions-erako. Hasi saioa berriro Folio Cloud-en.';

  @override
  String get folioCloudCallableUnexpectedFallback =>
      'Cloud Functions babesleko erantzun ustekabekoa';

  @override
  String folioCloudCallableHttpAiComplete(int code) {
    return 'HTTP $code folioCloudAiCompleteHttp deitzerakoan';
  }

  @override
  String get cloudAccountEmailMismatch =>
      'Posta elektronikoa ez dator bat uneko saioarekin.';

  @override
  String get cloudIdentityInvalidAuthResponse =>
      'Autentifikazio-erantzun baliogabea.';

  @override
  String get templateButtonPlaceholderText => 'Txantiloiaren testua…';

  @override
  String get aiProviderOllamaName => 'Ollama';

  @override
  String get aiProviderLmStudioName => 'LM Studio';

  @override
  String get blockAudioEmptyHint => 'Aukeratu audio-fitxategi bat';

  @override
  String get blockChildPageTitle => 'Orrialde-blokea';

  @override
  String get blockChildPageNoLink => 'Ez dago azpi-orrialderik estekatuta.';

  @override
  String get mermaidExpandedLoadError =>
      'Ezin izan da diagrama handitua erakutsi.';

  @override
  String get mermaidPreviewTooltip =>
      'Sakatu handitzeko eta zoom egiteko. PNG mermaid.ink bidez (kanpoko zerbitzua).';

  @override
  String get aiEndpointInvalidUrl =>
      'URL baliogabea. Erabili http://host:portua.';

  @override
  String get aiEndpointRemoteNotAllowed =>
      'Urruneko amaiera-puntua ez dago onartuta berrespenik gabe.';

  @override
  String get settingsAiSelectProviderFirst =>
      'Hautatu AA hornitzaile bat lehenik.';

  @override
  String get releaseReadinessAiSummaryDisabled => 'AA desgaituta';

  @override
  String get releaseReadinessAiSummaryQuillCloud =>
      'Folio Cloud AA (amaiera-puntu lokalik gabe)';

  @override
  String releaseReadinessAiSummaryEndpointOk(Object url) {
    return 'Amaiera-puntu balioduna: $url';
  }

  @override
  String get releaseReadinessDetailSemverInvalid =>
      'Instalatutako bertsioak ez ditu SemVer betetzen.';

  @override
  String get releaseReadinessDetailVaultNotEncrypted =>
      'Uneko koadernoa ez dago zifratuta.';

  @override
  String get releaseReadinessDetailVaultLocked =>
      'Desblokeatu koadernoa esportazio/inportazioa eta fluxu erreala balioztatzeko.';

  @override
  String get releaseReadinessDetailBetaChannel =>
      'Eguneratzeen beta kanala aktibo dago.';

  @override
  String get releaseReadinessReportTitle => 'Folio: argitaratzeko prestasuna';

  @override
  String releaseReadinessReportInstalledVersion(Object label) {
    return 'Instalatutako bertsioa: $label';
  }

  @override
  String releaseReadinessReportSemver(Object value) {
    return 'SemVer balioduna: $value';
  }

  @override
  String releaseReadinessReportChannel(Object value) {
    return 'Eguneratze kanala: $value';
  }

  @override
  String releaseReadinessReportActiveVault(Object id) {
    return 'Koaderno aktiboa: $id';
  }

  @override
  String releaseReadinessReportVaultPath(Object path) {
    return 'Koadernoaren bidea: $path';
  }

  @override
  String releaseReadinessReportUnlocked(Object value) {
    return 'Koadernoa desblokeatuta: $value';
  }

  @override
  String releaseReadinessReportEncrypted(Object value) {
    return 'Koadernoa zifratuta: $value';
  }

  @override
  String releaseReadinessReportAiEnabled(Object value) {
    return 'AA gaituta: $value';
  }

  @override
  String releaseReadinessReportAiPolicy(Object value) {
    return 'AA amaiera-puntuaren gidalerroa: $value';
  }

  @override
  String releaseReadinessReportAiDetail(Object detail) {
    return 'AA xehetasuna: $detail';
  }

  @override
  String releaseReadinessReportStatus(Object value) {
    return 'Argitaratze egoera: $value';
  }

  @override
  String releaseReadinessReportBlockers(int count) {
    return 'Zain blokeatzaileak: $count';
  }

  @override
  String releaseReadinessReportWarnings(int count) {
    return 'Zain abisuak: $count';
  }

  @override
  String get releaseReadinessExportWordYes => 'bai';

  @override
  String get releaseReadinessExportWordNo => 'ez';

  @override
  String get releaseReadinessChannelStable => 'egonkorra';

  @override
  String get releaseReadinessChannelBeta => 'beta';

  @override
  String get releaseReadinessStatusReady => 'prest';

  @override
  String get releaseReadinessStatusBlocked => 'blokeatuta';

  @override
  String get releaseReadinessPolicyOk => 'ondo';

  @override
  String get releaseReadinessPolicyError => 'errorea';

  @override
  String get settingsSignInFolioCloudSnack => 'Hasi saioa Folio Cloud-en.';

  @override
  String get settingsNotSyncedYet => 'Oraindik sinkronizatu gabe';

  @override
  String get settingsDeviceNameTitle => 'Gailuaren izena';

  @override
  String get settingsDeviceNameHintExample => 'Adibidea: Alejandraren Pixel';

  @override
  String get settingsPairingModeEnabledTwoMin =>
      'Lotura modua 2 minutuz aktibatuta.';

  @override
  String get settingsPairingEnableModeFirst =>
      'Lehenik aktibatu lotura modua eta hautatu detektatutako gailu bat.';

  @override
  String get settingsPairingSameEmojisBothDevices =>
      'Aktibatu lotura modua bi gailuetan eta itxaron emoji berdinak 3 agertu arte.';

  @override
  String get settingsPairingCouldNotStart =>
      'Ezin izan da lotura hasi. Aktibatu modua bi gailuetan eta itxaron emoji berdinak 3 agertu arte.';

  @override
  String get settingsConfirmPairingTitle => 'Berretsi lotura';

  @override
  String get settingsPairingCheckOtherDeviceEmojis =>
      'Egiaztatu bestean emoji berdin hauek 3 agertzen direla:';

  @override
  String get settingsPairingPopupInstructions =>
      'Popup hau bestean ere agertuko da. Lotura osatzeko, sakatu Lotu hemen eta gero Lotu bestean.';

  @override
  String get settingsLinkDevice => 'Lotu';

  @override
  String get settingsPairingConfirmationSent =>
      'Berrespena bidalita. Besteak bere popup-ean Lotu sakatu behar du.';

  @override
  String get settingsResolveConflictsTitle => 'Ebatzi gatazkak';

  @override
  String get settingsNoPendingConflicts => 'Ez dago gatazkarik zain.';

  @override
  String settingsSyncConflictCardSubtitle(
    Object fromPeerId,
    int remotePageCount,
    Object detectedAt,
  ) {
    return 'Jatorria: $fromPeerId\nUrruneko orriak: $remotePageCount\nDetektatuta: $detectedAt';
  }

  @override
  String get settingsSyncConflictHeading => 'Sinkronizazio gatazka';

  @override
  String get settingsLocalVersionKeptSnack => 'Bertsio lokala mantendu da.';

  @override
  String get settingsKeepLocal => 'Mantendu lokala';

  @override
  String get settingsRemoteVersionAppliedSnack =>
      'Urruneko bertsioa aplikatu da.';

  @override
  String get settingsCouldNotApplyRemoteSnack =>
      'Ezin izan da urruneko bertsioa aplikatu.';

  @override
  String get settingsAcceptRemote => 'Onartu urrunekoa';

  @override
  String get settingsClose => 'Itxi';

  @override
  String get settingsSectionDeviceSyncNav => 'Sinkronizazioa';

  @override
  String get settingsSectionVault => 'Koadernoa';

  @override
  String get settingsSectionVaultHeroDescription =>
      'Desblokeatzearen segurtasuna, babeskopiak, diskoan programatzea eta gailu honetako datuen kudeaketa.';

  @override
  String get settingsSectionUiWorkspace => 'Interfazea eta mahaigaina';

  @override
  String get settingsSectionUiWorkspaceHeroDescription =>
      'Gaia, hizkuntza, eskala, editorea, mahaigaineko aukerak eta teklatuko lasterbideak.';

  @override
  String get settingsSubsectionVaultBackupImport =>
      'Babeskopiak eta inportazioa';

  @override
  String get settingsSubsectionVaultScheduledLocal =>
      'Programatutako babeskopia (lokala)';

  @override
  String get settingsSubsectionDrive => 'Drive';

  @override
  String get settingsSubsectionVaultData => 'Datuak (arrisku-eremua)';

  @override
  String get folioCloudSubsectionAccount => 'Kontua';

  @override
  String get folioCloudSubsectionEncryptedBackups =>
      'Babeskopiak eta biltegiratzea (hodeia)';

  @override
  String get folioCloudBackupStorageSectionIntro =>
      'Erabilera inkrementala (cloud-pack) eta backups/ karpetako fitxategi oso zaharrak barne hartzen ditu. Liburutegi txiki, ertain edo handi batera harpidetu zaitezke (kuota extra hilabetean zehar, harpidetza aktibo dagoen bitartean).';

  @override
  String folioCloudBackupStoragePurchasedExtra(Object size) {
    return 'Erositako zabaltzeak: +$size';
  }

  @override
  String get folioCloudBackupStorageBarTitle => 'Biltegiratze-erabilera';

  @override
  String folioCloudBackupStorageBarPercent(int percent) {
    return '$percent %';
  }

  @override
  String folioCloudBackupStorageBarDetail(
    Object used,
    Object total,
    Object free,
  ) {
    return 'Erabilita: $used · Kuota osoa: $total · Librea: $free';
  }

  @override
  String get folioCloudSubsectionPublishing => 'Web argitalpena';

  @override
  String get settingsFolioCloudSubsectionScheduledCloud =>
      'Programatutako babeskopia Folio Cloud-era';

  @override
  String get settingsScheduledCloudUploadRequiresSchedule =>
      'Aurrez aktibatu programatutako babeskopia Koadernoan › Programatutako babeskopia (lokala).';

  @override
  String get settingsSyncHeroTitle => 'Gailuen arteko sinkronizazioa';

  @override
  String get settingsSyncHeroDescription =>
      'Parekatu ekipoak sare lokalean; relay-ak konexioa negoziatzen laguntzen du soilik eta ez du vault edukia bidaltzen.';

  @override
  String get settingsSyncChipPairingCode => 'Lotura kodea';

  @override
  String get settingsSyncChipAutoDiscovery => 'Detekzio automatikoa';

  @override
  String get settingsSyncChipOptionalRelay => 'Relay aukerakoa';

  @override
  String get settingsSyncEnableTitle => 'Gaitu gailuen arteko sinkronizazioa';

  @override
  String get settingsSyncSearchingSubtitle =>
      'Folio irekita duten gailuak bilatzen sare lokalean...';

  @override
  String settingsSyncDevicesFoundOnLan(int count) {
    return '$count gailu detektatu LANean.';
  }

  @override
  String get settingsSyncDisabledSubtitle => 'Sinkronizazioa desgaituta dago.';

  @override
  String get settingsSyncRelayTitle => 'Erabili seinaleztapen relay-a';

  @override
  String get settingsSyncRelaySubtitle =>
      'Ez du vault edukia bidaltzen; LAN-ak huts egiten duenean konexioa negoziatzen laguntzen du.';

  @override
  String get settingsEdit => 'Editatu';

  @override
  String get settingsSyncEmojiModeTitle => 'Gaitu emoji lotura modua';

  @override
  String get settingsSyncEmojiModeSubtitle =>
      'Gaitu bi gailuetan koderik idatzi gabe lotura hasteko.';

  @override
  String get settingsSyncPairingStatusTitle => 'Lotura moduaren egoera';

  @override
  String get settingsSyncPairingActiveSubtitle =>
      '2 minutuz aktibo. Detektatutako gailu batetik lotura hasi dezakezu.';

  @override
  String get settingsSyncPairingInactiveSubtitle =>
      'Inaktibo. Gaitu hemen eta bestean lotura hasteko.';

  @override
  String get settingsSyncLastSyncTitle => 'Azken sinkronizazioa';

  @override
  String get settingsSyncPendingConflictsTitle => 'Zain dauden gatazkak';

  @override
  String get settingsSyncNoConflictsSubtitle => 'Ez dago gatazkarik zain.';

  @override
  String settingsSyncConflictsNeedReview(int count) {
    return '$count gatazkak eskuzko berrikuspena behar dute.';
  }

  @override
  String get settingsResolve => 'Ebatzi';

  @override
  String get settingsSyncDiscoveredDevicesTitle => 'Detektatutako gailuak';

  @override
  String get settingsSyncNoDevicesYetHint =>
      'Oraindik ez da gailurik detektatu. Bi aplikazioak sare berean irekita daudela ziurtatu.';

  @override
  String get settingsSyncPeerReadyToLink => 'Lotzeko prest.';

  @override
  String get settingsSyncPeerOtherInPairingMode =>
      'Bestea lotura moduan dago. Gaitu hemen lotura hasteko.';

  @override
  String get settingsSyncPeerDetectedLan => 'Sare lokalean detektatuta.';

  @override
  String get settingsSyncLinkedDevicesTitle => 'Lotutako gailuak';

  @override
  String get settingsSyncNoLinkedDevicesYet =>
      'Oraindik ez dago gailurik lotuta.';

  @override
  String settingsSyncPeerIdLabel(Object peerId) {
    return 'ID: $peerId';
  }

  @override
  String get settingsRevoke => 'Indargabetu';

  @override
  String get sidebarPageIconTitle => 'Orriaren ikonoa';

  @override
  String get sidebarPageIconPickerHelper =>
      'Aukeratu ikono azkar bat, inportatutako bat edo ireki hautatzaile osoa.';

  @override
  String get sidebarPageIconCustomEmoji => 'Emoji pertsonalizatua';

  @override
  String get sidebarPageIconRemove => 'Kendu';

  @override
  String get sidebarPageIconTabQuick => 'Azkarrak';

  @override
  String get sidebarPageIconTabImported => 'Inportatuak';

  @override
  String get sidebarPageIconTabAll => 'Denak';

  @override
  String get sidebarPageIconEmptyImported =>
      'Oraindik ez duzu ikonorik inportatu Ezarpenetan.';

  @override
  String get sidebarDeletePageMenuTitle => 'Ezabatu orria';

  @override
  String get sidebarDeleteFolderMenuTitle => 'Kendu karpeta';

  @override
  String sidebarDeletePageConfirmInline(Object title) {
    return 'Ezabatu «$title»? Ezin da desegin.';
  }

  @override
  String sidebarDeleteFolderConfirmInline(Object title) {
    return 'Kendu «$title» karpeta? Azpiorreak koadernoaren errorera pasatuko dira.';
  }

  @override
  String get settingsStripeSubscriptionRefreshed =>
      'Folio Cloud-eko fakturazioa eguneratu da.';

  @override
  String get settingsStripeBillingPortalUnavailable =>
      'Fakturazio-portala ez dago erabilgarri.';

  @override
  String get settingsCouldNotOpenLink => 'Ezin izan da esteka ireki.';

  @override
  String get settingsStripeCheckoutUnavailable =>
      'Ordainketa ez dago erabilgarri (konfiguratu Stripe zerbitzarian).';

  @override
  String get settingsCloudBackupEnablePlanSnack =>
      'Gaitu Folio Cloud hodeiko babeskopiaren eginbidearekin, zure planean sartuta.';

  @override
  String get settingsNoActiveVault => 'Ez dago libreta aktiborik.';

  @override
  String get settingsCloudBackupsNeedPlan =>
      'Folio Cloud aktiboa behar duzu hodeiko babeskopiarekin.';

  @override
  String settingsCloudBackupsDialogTitle(int count) {
    return 'Hodeiko babeskopiak ($count/10)';
  }

  @override
  String get settingsCloudBackupsVaultLabel => 'Gorde-lekua';

  @override
  String get settingsCloudBackupsEmpty =>
      'Oraindik ez dago babeskopiarik kontu honetan.';

  @override
  String get settingsCloudBackupDownloadTooltip => 'Deskargatu';

  @override
  String get settingsCloudBackupActionDownload => 'Deskargatu';

  @override
  String get settingsCloudBackupActionImportOverwrite =>
      'Inportatu (gainidatzi)';

  @override
  String get settingsCloudBackupSaveDialogTitle => 'Gorde babeskopia';

  @override
  String get settingsCloudBackupDownloadedSnack => 'Babeskopia deskargatu da.';

  @override
  String get settingsCloudBackupDeletedSnack => 'Babeskopia ezabatu da.';

  @override
  String get settingsCloudBackupImportedSnack => 'Inportazioa osatu da.';

  @override
  String get settingsCloudBackupVaultMustBeUnlocked =>
      'Libreta desblokeatuta egon behar da.';

  @override
  String settingsCloudBackupsTotalLabel(Object size) {
    return 'Guztira: $size';
  }

  @override
  String get settingsCloudBackupImportOverwriteTitle =>
      'Inportatu (gainidatzi)';

  @override
  String get settingsCloudBackupImportOverwriteBody =>
      'Honek irekitako libretaren edukia gainidatziko du. Ziurtatu jarraitu aurretik kopia lokal bat duzula.';

  @override
  String get settingsCloudBackupImportRemoteCloudPackIntro =>
      'Inkrementu babeskopia hau zure Folio Cloud kontuko beste libreta batekoa da. Sartu libreta horren pasahitza deskargatzeko (hutsik utzi zifratu gabe badago).';

  @override
  String get settingsCloudBackupDeleteWarning =>
      'Ziur hodeiko babeskopia hau ezabatu nahi duzula? Ekintza hau ezin da desegin.';

  @override
  String get settingsPublishedRequiresPlan =>
      'Folio Cloud behar duzu web-argitalpen aktiborekin.';

  @override
  String get settingsPublishedPagesTitle => 'Argitaratutako orriak';

  @override
  String get settingsPublishedPagesEmpty =>
      'Oraindik ez dago orri argitaraturik.';

  @override
  String get settingsPublishedDeleteDialogTitle => 'Argitalpena ezabatu?';

  @override
  String get settingsPublishedDeleteDialogBody =>
      'HTML publikoa ezabatuko da eta estekak funtzionatzeari utziko dio.';

  @override
  String get settingsPublishedRemovedSnack => 'Argitalpena ezabatu da.';

  @override
  String get settingsCouldNotReadInstalledVersion =>
      'Ezin izan da instalatutako bertsioa irakurri.';

  @override
  String settingsCouldNotOpenReleaseNotes(Object error) {
    return 'Ezin izan dira bertsio-oharrak ireki: $error';
  }

  @override
  String settingsUpdateFailed(Object error) {
    return 'Ezin izan da eguneratu: $error';
  }

  @override
  String get settingsSessionEndedSnack => 'Saioa itxita';

  @override
  String get settingsLabelYes => 'Bai';

  @override
  String get settingsLabelNo => 'Ez';

  @override
  String get settingsSecurityEncryptedHeroDescription =>
      'Desblokeo azkarra, passkey, blokeo automatikoa eta giltzarako pasahitza zifratutako biltegian.';

  @override
  String get settingsUnencryptedVaultTitle => 'Zifratu gabeko biltegia';

  @override
  String get settingsUnencryptedVaultChipDataOnDisk => 'Datuak diskoan';

  @override
  String get settingsUnencryptedVaultChipEncryptionAvailable =>
      'Zifratzea erabilgarri';

  @override
  String get settingsAppearanceChipTheme => 'Gaia';

  @override
  String get settingsAppearanceChipZoom => 'Zoom';

  @override
  String get settingsAppearanceChipLanguage => 'Hizkuntza';

  @override
  String get settingsAppearanceChipEditorWorkspace => 'Editorea eta lan-eremua';

  @override
  String get settingsWindowsScaleFollowTitle => 'Jarraitu Windows-eko eskala';

  @override
  String get settingsWindowsScaleFollowSubtitle =>
      'Erabili automatikoki sistemaren eskala Windows-en.';

  @override
  String get settingsInterfaceZoomTitle => 'Interfazearen zooma';

  @override
  String get settingsInterfaceZoomSubtitle =>
      'Handitu edo txikitu aplikazioaren tamaina orokorra.';

  @override
  String get settingsUiZoomReset => 'Berrezarri';

  @override
  String get settingsEditorSubsection => 'Editorea';

  @override
  String get settingsEditorContentWidthTitle => 'Edukiaren zabalera';

  @override
  String get settingsEditorContentWidthSubtitle =>
      'Zehaztu blokeek editorean zenbat zabalera hartzen duten.';

  @override
  String get settingsEnterCreatesNewBlockTitle =>
      'Sartu bloke berria sortzen du';

  @override
  String get settingsEnterCreatesNewBlockSubtitleWhenEnabled =>
      'Desgaitu Enter lerro-jauzia txertatzeko.';

  @override
  String get settingsEnterCreatesNewBlockSubtitleWhenDisabled =>
      'Orain Enter-k lerro-jauzia txertatzen du. Maius+Enter-k ere funtzionatzen du.';

  @override
  String get settingsWorkspaceSubsection => 'Lan-eremua';

  @override
  String get settingsCustomIconsTitle => 'Ikon pertsonalizatuak';

  @override
  String get settingsCustomIconsDescription =>
      'Inportatu PNG, GIF edo WebP URL bat, edo notionicons.so bezalako guneetatik kopiatutako data:image bateragarri bat. Ondoren orri edo callout ikono gisa erabil dezakezu.';

  @override
  String settingsCustomIconsSavedCount(int count) {
    return '$count gordeta';
  }

  @override
  String get settingsCustomIconsChipUrl => 'PNG, GIF edo WebP URL';

  @override
  String get settingsCustomIconsChipDataImage => 'data:image/*';

  @override
  String get settingsCustomIconsChipPaste => 'Itsatsi arbelatik';

  @override
  String get settingsCustomIconsImportTitle => 'Inportatu ikono berria';

  @override
  String get settingsCustomIconsImportSubtitle =>
      'Izena eman eta iturburua eskuz itsatsi dezakezu edo zuzenean arbelatik ekarri.';

  @override
  String get settingsCustomIconsFieldNameLabel => 'Izena';

  @override
  String get settingsCustomIconsFieldNameHint => 'Aukerakoa';

  @override
  String get settingsCustomIconsFieldSourceLabel => 'URL edo data:image';

  @override
  String get settingsCustomIconsFieldSourceHint =>
      'https://…gif | …webp | …png edo data:image/…';

  @override
  String get settingsCustomIconsImportButton => 'Inportatu ikonoa';

  @override
  String get settingsCustomIconsFromClipboard => 'Arbelatik';

  @override
  String get settingsCustomIconsLibraryTitle => 'Liburutegia';

  @override
  String get settingsCustomIconsLibrarySubtitle =>
      'Aplikazio osoan erabiltzeko prest';

  @override
  String get settingsCustomIconsEmpty => 'Oraindik ez duzu ikonorik inportatu.';

  @override
  String get settingsCustomIconsDeleteTooltip => 'Ezabatu ikonoa';

  @override
  String get settingsCustomIconsReferenceCopiedSnack =>
      'Erreferentzia kopiatu da.';

  @override
  String get settingsCustomIconsCopyToken => 'Kopiatu tokena';

  @override
  String get settingsAiHeroQuillWithLocalAlt =>
      'AA Quill Cloud-en exekutatzen da (hodeiko AA harpidetza edo erositako tinta). Aukeratu beste hornitzaile bat behean Ollama edo LM Studio lokalarentzat.';

  @override
  String get settingsAiHeroQuillCloudOnly =>
      'AA Quill Cloud-en exekutatzen da (hodeiko AA harpidetza edo erositako tinta).';

  @override
  String get settingsAiHeroLocalDefault =>
      'Konektatu Ollama edo LM Studio lokalean; laguntzaileak hemen konfiguratzen duzun eredil eta testuingurua erabiltzen ditu.';

  @override
  String get settingsAiHeroQuillMobileOnly =>
      'Gailu honetan Quill-ek Quill Cloud soilik erabil dezake. Aukeratu Quill Cloud AA gaitzeko.';

  @override
  String get settingsAiChipCloud => 'Hodeian';

  @override
  String get settingsAiSnackFirebaseUnavailableBuild =>
      'Firebase ez dago erabilgarri konpilazio honetan.';

  @override
  String get settingsAiSnackSignInCloudAccount =>
      'Hasi saioa hodeiko kontuan (Ezarpenak).';

  @override
  String settingsAiProviderSwitchFailed(Object error) {
    return 'Ezin izan da AA hornitzailea aldatu: $error';
  }

  @override
  String get settingsAboutHeroDescription =>
      'Instalatutako bertsioa, eguneratzeen jatorria eta berritasunen eskuzko egiaztapena.';

  @override
  String get settingsOpenReleaseNotes => 'Ikusi bertsio-oharrak';

  @override
  String get settingsUpdateChannelLabel => 'Kanala';

  @override
  String get settingsUpdateChannelRelease => 'Release';

  @override
  String get settingsUpdateChannelBeta => 'Beta';

  @override
  String get settingsDataHeroDescription =>
      'Fitxategi lokalen gaineko ekintza iraunkorrak. Ezabatu aurretik egin babeskopia bat.';

  @override
  String get settingsDangerZoneTitle => 'Arrisku-eremua';

  @override
  String get settingsDesktopHeroDescription =>
      'Lasterbide orokorrak, erretilua eta leihoaren portaera mahaigainean.';

  @override
  String get settingsShortcutsHeroDescription =>
      'Folio barruko konbinazioak soilik. Probatu tekla bat gorde aurretik.';

  @override
  String get settingsShortcutsTestChip => 'Probatu';

  @override
  String get settingsIntegrationsChipApprovedPermissions =>
      'Onartutako baimenak';

  @override
  String get settingsIntegrationsChipRevocableAccess =>
      'Ezeztatu daitekeen sarbidea';

  @override
  String get settingsIntegrationsChipExternalApps => 'Kanpoko aplikazioak';

  @override
  String get settingsIntegrationsActiveConnectionsTitle => 'Konexio aktiboak';

  @override
  String get settingsIntegrationsActiveConnectionsSubtitle =>
      'Folio-rekin elkarreragin dezaketen aplikazioak';

  @override
  String get settingsViewInkUsageTable => 'Ikusi kontsumo-taula';

  @override
  String get settingsCloudInkUsageTableTitle =>
      'Tinta-kontsumo taula (Quill Cloud)';

  @override
  String get settingsCloudInkUsageTableIntro =>
      'Ekintzako oinarrizko kostua. Prompt luze eta irteerako tokenengatik gehigarriak aplika daitezke.';

  @override
  String get settingsCloudInkDrops => 'tanta';

  @override
  String get settingsCloudInkTableCachedNotice =>
      'Cache lokaleko taula erakusten (backend-erako konexiorik gabe).';

  @override
  String get settingsCloudInkOpRewriteBlock => 'Biridatzi blokea';

  @override
  String get settingsCloudInkOpSummarizeSelection => 'Laburbildu hautapena';

  @override
  String get settingsCloudInkOpExtractTasks => 'Atera zereginak';

  @override
  String get settingsCloudInkOpSummarizePage => 'Laburbildu orria';

  @override
  String get settingsCloudInkOpGenerateInsert => 'Sortu txertaketa';

  @override
  String get settingsCloudInkOpGeneratePage => 'Sortu orria';

  @override
  String get settingsCloudInkOpChatTurn => 'Txat-txanda';

  @override
  String get settingsCloudInkOpAgentMain => 'Agentearen exekuzio nagusia';

  @override
  String get settingsCloudInkOpAgentFollowup => 'Agentearen jarraipena';

  @override
  String get settingsCloudInkOpEditPagePanel => 'Orriaren edizioa (panela)';

  @override
  String get settingsCloudInkOpDefault => 'Lehenetsitako eragiketa';

  @override
  String get settingsDesktopRailSubtitle =>
      'Aukeratu kategoria bat zerrendatik edo egin gora-behera edukian.';

  @override
  String get settingsCloudInkViewTableButton => 'Ikusi taula';

  @override
  String get settingsCloudInkHostedAiQuillCloudHint =>
      'Quill Cloud-en hodeiko AArentzako erreferentzia-prezioak.';

  @override
  String get vaultStarterHomeTitle => 'Hasi hemen';

  @override
  String get vaultStarterHomeHeading => 'Zure koadernoa prest dago';

  @override
  String get vaultStarterHomeIntro =>
      'Foliok orriak zuhaitz batean antolatzen ditu, blokeetan editatzen du edukia eta datuak gailu honetan gordetzen ditu. Gida labur honek lehen minututik zer egin dezakezun erakusten dizu.';

  @override
  String get vaultStarterHomeCallout =>
      'Orri hauek ezabatu, berrizendatu edo mugitu ditzakezu noiznahi. Hasiera azkarragoa izateko oinarri bat besterik ez dira.';

  @override
  String get vaultStarterHomeSectionTips => 'Hasierako aholku erabilgarrienak';

  @override
  String get vaultStarterHomeBulletSlash =>
      'Sakatu / paragrafo batean goiburuak, zerrendak, taulak, kode-blokeak, Mermaid eta gehiago txertatzeko.';

  @override
  String get vaultStarterHomeBulletSidebar =>
      'Erabili panel albokorra orri eta azpiorriak sortzeko, eta antolatu zuhaitza zure lan modura.';

  @override
  String get vaultStarterHomeBulletSettings =>
      'Ireki Ezarpenak AA gaitzeko, babeskopia konfiguratzeko, hizkuntza aldatzeko edo desblokeo azkarra gehitzeko.';

  @override
  String get vaultStarterHomeTodo1 => 'Sortu nire lehen lan-orria';

  @override
  String get vaultStarterHomeTodo2 =>
      'Probatu / menua bloke berri bat txertatzeko';

  @override
  String get vaultStarterHomeTodo3 =>
      'Berrikusi Ezarpenak eta erabaki Quill edo desblokeo azkar bat gaitu nahi dudan';

  @override
  String get vaultStarterCapabilitiesTitle => 'Zer egin dezake Folio-k';

  @override
  String get vaultStarterCapabilitiesSectionMain => 'Gaitasun nagusiak';

  @override
  String get vaultStarterCapabilitiesBullet1 =>
      'Hartu oharrak egitura askearekin: paragrafoak, goiburuak, zerrendak, egikaratzeko zerrendak, aipamenak eta bereizleak.';

  @override
  String get vaultStarterCapabilitiesBullet2 =>
      'Lan egin bloke bereziekin: taulak, datu-baseak, fitxategiak, audioa, bideoa, kapsulak eta Mermaid diagramak.';

  @override
  String get vaultStarterCapabilitiesBullet3 =>
      'Bilatu edukia, ikusi orriaren historia eta mantendu berrikuspenak koaderno berean.';

  @override
  String get vaultStarterCapabilitiesBullet4 =>
      'Esportatu edo inportatu datuak, koadernoaren babeskopia eta Notion-etik inportazioa barne.';

  @override
  String get vaultStarterCapabilitiesSectionShortcuts => 'Laster-teklak';

  @override
  String get vaultStarterCapabilitiesShortcutN =>
      'Ctrl+N orri berria sortzen du.';

  @override
  String get vaultStarterCapabilitiesShortcutSearch =>
      'Ctrl+K edo Ctrl+F bilaketa irekitzen du.';

  @override
  String get vaultStarterCapabilitiesShortcutSettings =>
      'Ctrl+, Ezarpenak irekitzen ditu eta Ctrl+L koadernoa blokeatzen du.';

  @override
  String get vaultStarterCapabilitiesAiCallout =>
      'AA lehenespenez ez dago gaituta. Quill erabiltzen baduzu, konfiguratu Ezarpenetan—hornikailua, eredua eta testuinguruaren baimenak.';

  @override
  String get vaultStarterQuillTitle => 'Quill eta pribatutasuna';

  @override
  String get vaultStarterQuillSectionWhat => 'Zer egin dezake Quill-ek';

  @override
  String get vaultStarterQuillBullet1 =>
      'Laburtu, berridatzi edo zabaldu orri baten edukia.';

  @override
  String get vaultStarterQuillBullet2 =>
      'Erantzun blokeei, lasterbideei eta Folio-ko oharrak nola antolatu galderak.';

  @override
  String get vaultStarterQuillBullet3 =>
      'Lan egin irekitako orria testuinguru gisa edo hautatzen dituzun hainbat orri erreferentzia gisa.';

  @override
  String get vaultStarterQuillSectionPrivacy => 'Pribatutasuna eta segurtasuna';

  @override
  String get vaultStarterQuillPrivacyBody =>
      'Zure orriak gailu honetan bizi dira. AA gaitzen baduzu, egiaztatu zer testuinguru partekatzen duzun eta zein hornikailurekin. Koaderno zifratu baten pasahitz nagusia ahazten baduzu, Foliok ezin du berreskuratu.';

  @override
  String get vaultStarterQuillBackupCallout =>
      'Egin koadernoaren babeskopia edukia garrantzitsua duzunean. Babeskopeak datuak eta eranskinak gordetzen ditu, baina ez du Hello edo passkeys gailu artean transferitzen.';

  @override
  String get vaultStarterQuillMermaidCaption => 'Mermaid proba azkarra:';

  @override
  String get vaultStarterQuillMermaidSource =>
      'graph TD\nHasiera[Sortu koadernoa] --> Antolatu[Antolatu orriak]\nAntolatu --> Idatzi[Idatzi eta lotu ideiak]\nIdatzi --> Berrikusi[Bilatu, berrikusi eta hobetu]';

  @override
  String get settingsAccentColorTitle => 'Azentu-kolorea';

  @override
  String get settingsAccentFollowSystem => 'Windows';

  @override
  String get settingsAccentFolioDefault => 'Folio';

  @override
  String get settingsAccentCustom => 'Pertsonalizatua';

  @override
  String get settingsAccentPickColor => 'Aurrezarritako kolorea aukeratu';

  @override
  String get settingsPrivacySectionTitle => 'Pribatutasuna eta diagnostikoak';

  @override
  String get settingsTelemetryTitle => 'Erabilera-estatistika anonimoak';

  @override
  String get settingsTelemetrySubtitle =>
      'Instalazioak eta eginbideen erabilera neurtzen laguntzen du. Ez da koaderno-edukirik edo izenbururik bidaltzen.';

  @override
  String get onboardingTelemetryTitle => 'Erabilera estatistikak';

  @override
  String get onboardingTelemetryBody =>
      'Foliok analitika anonimoa bidali dezake aplikazioa nola erabiltzen den ulertzeko. Edozein unetan alda dezakezu Ezarpenetan.';

  @override
  String get onboardingTelemetrySwitchTitle =>
      'Erabilera-estatistika anonimoak';

  @override
  String get onboardingTelemetrySwitchSubtitle =>
      'Instalazioak eta eginbideen erabilera neurtzen laguntzen du. Ez da koaderno-edukirik edo izenbururik bidaltzen.';

  @override
  String get onboardingTelemetryFootnote =>
      'Ez da koaderno-edukirik edo orrien izenbururik bidaltzen.';

  @override
  String get settingsAutoCrashReportsTitle =>
      'Bidali hondamen-diagnostikoak automatikoki';

  @override
  String get settingsAutoCrashReportsSubtitle =>
      'Akats larri bat gertatzen bada, logaren zati bat bidaltzen zaio Folioren (aukerakoa, saio bakoitzeko mugatua).';

  @override
  String get settingsReportBugButton => 'Akats baten berri eman';

  @override
  String get settingsPrivacyFootnote =>
      'Ohar bat gehitu dezakezu; arazoen esteka nabigatzailean ireki daiteke.';

  @override
  String get settingsReportBugDialogTitle => 'Akats baten berri eman';

  @override
  String get settingsReportBugDialogBody =>
      'Metadatu anonimoak, logaren zati bat eta zure oharra bidaliko ditugu. Gero, arazoen kudeatzailea ireki dezakezu.';

  @override
  String get settingsReportBugNoteLabel => 'Zertan gertatu da? (aukerakoa)';

  @override
  String get settingsReportBugSend => 'Bidali eta jarraitu';

  @override
  String get settingsReportBugSentOk => 'Diagnostikoa bidalita.';

  @override
  String get settingsReportBugSentFail =>
      'Ezin izan da diagnostikoa bidali. Egiaztatu konexioa edo saiatu beranduago.';

  @override
  String get zenModeEnter => 'Zen modua';

  @override
  String get zenModeExit => 'Zen modutik irten';

  @override
  String get syncedBlockCreate => 'Blokea sinkronizatu';

  @override
  String get syncedBlockInsert => 'Txertatu bloke sinkronizatua…';

  @override
  String get syncedBlockBadge => 'Bloke sinkronizatua';

  @override
  String get syncedBlockCreated =>
      'Blokea sinkronizatuta. IDa arbelean kopiatuta.';

  @override
  String get syncedBlockInsertTitle => 'Txertatu bloke sinkronizatua';

  @override
  String get syncedBlockIdLabel => 'Sinkronizazio taldearen IDa';

  @override
  String get syncedBlockIdHint =>
      'Itsatsi beste bloke sinkronizatu batetik kopiatutako IDa';

  @override
  String get syncedBlockIdInvalid => 'Baliogabeko IDa edo ez da aurkitu';

  @override
  String get syncedBlockUnsync => 'Blokea desinkronizatu';

  @override
  String get syncedBlockUnsynced => 'Blokea desinkronizatuta';

  @override
  String syncedBlockGroupCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count kopia sinkronizatuta',
      one: '1 kopia sinkronizatuta',
    );
    return '$_temp0';
  }

  @override
  String get graphViewTitle => 'Grafo ikuspegia';

  @override
  String get graphViewEmpty => 'Ez dago orrien arteko loturarik';

  @override
  String get graphViewIncludeOrphans => 'Lotura gabeko orriak sartu';

  @override
  String get graphViewOpenPage => 'Orria ireki';

  @override
  String get importPdf => 'PDF inportatu…';

  @override
  String get importPdfDialogTitle => 'PDF orri gisa inportatu';

  @override
  String get importPdfAnnotationsOnly => 'Oharrak soilik';

  @override
  String get importPdfFullText => 'Testu osoa + oharrak';

  @override
  String importPdfSuccess(String title) {
    return 'PDF inportatuta: $title';
  }

  @override
  String importPdfFailed(String error) {
    return 'Ezin izan da PDFa inportatu: $error';
  }

  @override
  String get importPdfNoText => 'PDFak ez du testu erauzigarririk';

  @override
  String get downloadDesktopApp => 'Deskargatu mahaigaineko aplikazioa';

  @override
  String get appStoreTitle => 'App Denda';

  @override
  String get appStoreTabExplore => 'Arakatu';

  @override
  String appStoreTabInstalled(int count) {
    return 'Instalatuta ($count)';
  }

  @override
  String get appStoreTooltipRefresh => 'Freskatu';

  @override
  String get appStoreTooltipInstallFile => 'Instalatu fitxategitik (.folioapp)';

  @override
  String get appStoreSearchHint => 'Bilatu appak…';

  @override
  String get appStoreNoResults => 'Ez da appaik aurkitu.';

  @override
  String get appStoreSectionOfficials => 'Ofizialak';

  @override
  String get appStoreSectionOfficialsSubtitle =>
      'Folio-n integratuta · Deskargaketarik gabe';

  @override
  String get appStoreSectionCommunity => 'Community';

  @override
  String get appStoreSectionCommunitySubtitle =>
      'Erregistro publikoan argitaratuta';

  @override
  String get appStoreInstallConfirmTitle => 'Tokiko app instalatu';

  @override
  String get appStoreInstallConfirmBody =>
      'App hau ez da egiaztatu. Instalatu fidatzen zaren iturburuetako fitxategiak soilik.';

  @override
  String get appStoreInstallButton => 'Instalatu';

  @override
  String get appStoreInstalledChip => 'Instalatuta';

  @override
  String appStoreInstallSuccess(String name) {
    return '\"$name\" behar bezala instalatu da.';
  }

  @override
  String appStoreInstallError(String message) {
    return 'Errorea: $message';
  }

  @override
  String get appStoreUninstallTitle => 'Desinstalatu app';

  @override
  String appStoreUninstallBody(String name) {
    return '\"$name\" desinstalatu? Fitxategiak ezabatuko dira.';
  }

  @override
  String get appStoreUninstallButton => 'Desinstalatu';

  @override
  String get appStoreInstalledEmpty =>
      'Ez dago appaik instalatuta.\nArakatu denda edo instalatu .folioapp bat.';

  @override
  String get settingsIntegrationsNativeTitle => 'Jatorrizko integrazioak';
}
