// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get appTitle => 'Folio';

  @override
  String get loading => 'Carregando…';

  @override
  String get newVault => 'Novo cofre';

  @override
  String stepOfTotal(int current, int total) {
    return 'Passo $current de $total';
  }

  @override
  String get back => 'Voltar';

  @override
  String get continueAction => 'Continuar';

  @override
  String get cancel => 'Cancelar';

  @override
  String get retry => 'Tentar novamente';

  @override
  String get settings => 'Configurações';

  @override
  String get lockNow => 'Bloquear';

  @override
  String get pageHistory => 'Histórico da página';

  @override
  String get untitled => 'Sem título';

  @override
  String get noPages => 'Nenhuma página';

  @override
  String get createPage => 'Criar página';

  @override
  String get selectPage => 'Selecionar uma página';

  @override
  String get saveInProgress => 'Salvando…';

  @override
  String get savePending => 'Salvamento pendente';

  @override
  String get savingVaultTooltip => 'Salvando cofre criptografado no disco…';

  @override
  String get autosaveSoonTooltip => 'Salvamento automático em instantes…';

  @override
  String get welcomeTitle => 'Bem-vindo';

  @override
  String get welcomeBody =>
      'O Folio armazena suas páginas apenas neste dispositivo, criptografadas com uma senha mestra. Se você esquecê-la, não poderemos recuperar seus dados.\n\nNão há sincronização na nuvem.';

  @override
  String get createNewVault => 'Criar novo cofre';

  @override
  String get importBackupZip => 'Importar backup (.zip)';

  @override
  String get importBackupTitle => 'Importar backup';

  @override
  String get importBackupBody =>
      'O arquivo contém os mesmos dados criptografados do outro dispositivo. Você precisará da senha mestra usada para criar esse backup.\n\nPasskey e desbloqueio rápido (Hello) não estão incluídos e não são transferíveis; você pode configurá-los mais tarde nas Configurações.';

  @override
  String get chooseZipFile => 'Escolher arquivo .zip';

  @override
  String get changeFile => 'Alterar arquivo';

  @override
  String get backupPasswordLabel => 'Senha do backup';

  @override
  String get backupPlainNoPasswordHint =>
      'Este backup não está criptografado. Nenhuma senha é necessária para importá-lo.';

  @override
  String get importVault => 'Importar cofre';

  @override
  String get masterPasswordTitle => 'Sua senha mestra';

  @override
  String masterPasswordHint(int min) {
    return 'Pelo menos $min caracteres. Você a usará sempre que abrir o Folio.';
  }

  @override
  String get createStarterPagesTitle => 'Criar páginas de ajuda iniciais';

  @override
  String get createStarterPagesBody =>
      'Adiciona um pequeno guia com exemplos, atalhos e recursos do Folio. Você pode excluir essas páginas depois.';

  @override
  String get passwordLabel => 'Senha';

  @override
  String get confirmPasswordLabel => 'Confirmar senha';

  @override
  String get next => 'Próximo';

  @override
  String get readyTitle => 'Tudo pronto';

  @override
  String get readyBody =>
      'Um cofre criptografado será criado neste dispositivo. Mais tarde, você poderá adicionar o Windows Hello, biometria ou uma passkey para um desbloqueio mais rápido (Configurações).';

  @override
  String get quillIntroTitle => 'Conheça o Quill';

  @override
  String get quillIntroBody =>
      'O Quill é o assistente integrado do Folio. Ele pode ajudar você a escrever, editar e entender suas páginas, além de responder perguntas sobre como usar o aplicativo.';

  @override
  String get quillIntroCapabilityWrite =>
      'Ele pode redigir, resumir ou reescrever conteúdo dentro de suas páginas.';

  @override
  String get quillIntroCapabilityExplain =>
      'Também responde perguntas sobre o Folio, atalhos, blocos e como organizar suas notas.';

  @override
  String get quillIntroCapabilityContext =>
      'Você pode permitir que ele use a página atual como contexto ou escolher várias páginas de referência.';

  @override
  String get quillIntroCapabilityExamples =>
      'A melhor parte: fale naturalmente com ele e o Quill decidirá se deve responder ou editar.';

  @override
  String get quillIntroExamplesTitle => 'Exemplos rápidos';

  @override
  String get quillIntroExampleOne => 'Resuma esta página em três tópicos.';

  @override
  String get quillIntroExampleTwo => 'Altere o título e melhore a introdução.';

  @override
  String get quillIntroExampleThree =>
      'Como adiciono uma imagem ou uma tabela?';

  @override
  String get quillIntroFootnote =>
      'Se a IA ainda não estiver ativada, você pode ativá-la mais tarde. Esta introdução serve para que você entenda o que o Quill pode fazer quando você o utilizar.';

  @override
  String get createVault => 'Criar cofre';

  @override
  String minCharactersError(int min) {
    return 'Mínimo de $min caracteres.';
  }

  @override
  String get passwordMismatchError => 'As senhas não coincidem.';

  @override
  String get passwordMustBeStrongError =>
      'A senha deve ser Forte para continuar.';

  @override
  String get passwordStrengthLabel => 'Força';

  @override
  String get passwordStrengthVeryWeak => 'Muito fraca';

  @override
  String get passwordStrengthWeak => 'Fraca';

  @override
  String get passwordStrengthFair => 'Razoável';

  @override
  String get passwordStrengthStrong => 'Forte';

  @override
  String get showPassword => 'Mostrar senha';

  @override
  String get hidePassword => 'Ocultar senha';

  @override
  String get chooseZipError => 'Escolha um arquivo .zip.';

  @override
  String get enterBackupPasswordError => 'Digite a senha do backup.';

  @override
  String importFailedError(Object error) {
    return 'Não foi possível importar: $error';
  }

  @override
  String createVaultFailedError(Object error) {
    return 'Não foi possível criar o cofre: $error';
  }

  @override
  String get encryptedVault => 'Cofre criptografado';

  @override
  String get unlock => 'Desbloquear';

  @override
  String get quickUnlock => 'Hello / biometria';

  @override
  String get passkey => 'Passkey';

  @override
  String get unlockFailed => 'Senha incorreta ou cofre danificado.';

  @override
  String get appearance => 'Aparência';

  @override
  String get security => 'Segurança';

  @override
  String get vaultBackup => 'Backup do cofre';

  @override
  String get data => 'Dados';

  @override
  String get systemTheme => 'Sistema';

  @override
  String get lightTheme => 'Claro';

  @override
  String get darkTheme => 'Escuro';

  @override
  String get language => 'Idioma';

  @override
  String get useSystemLanguage => 'Usar idioma do sistema';

  @override
  String get spanishLanguage => 'Espanhol';

  @override
  String get englishLanguage => 'Inglês';

  @override
  String get brazilianPortugueseLanguage => 'Português (Brasil)';

  @override
  String get catalanLanguage => 'Catalão / Valenciano';

  @override
  String get galicianLanguage => 'Galego';

  @override
  String get basqueLanguage => 'Basco';

  @override
  String get active => 'Ativo';

  @override
  String get inactive => 'Inativo';

  @override
  String get remove => 'Remover';

  @override
  String get enable => 'Ativar';

  @override
  String get register => 'Registrar';

  @override
  String get revoke => 'Revogar';

  @override
  String get save => 'Salvar';

  @override
  String get delete => 'Excluir';

  @override
  String get rename => 'Renomear';

  @override
  String get change => 'Alterar';

  @override
  String get importAction => 'Importar';

  @override
  String get masterPassword => 'Senha mestra';

  @override
  String get confirmIdentity => 'Confirmar identidade';

  @override
  String get quickUnlockTitle => 'Desbloqueio rápido (Hello / biometria)';

  @override
  String get passkeyThisDevice => 'WebAuthn neste dispositivo';

  @override
  String get lockOnMinimize => 'Bloquear ao minimizar';

  @override
  String get changeMasterPassword => 'Alterar senha mestra';

  @override
  String get requiresCurrentPassword => 'Requer a senha atual';

  @override
  String get lockAutoByInactivity => 'Bloqueio automático por inatividade';

  @override
  String minutesShort(int minutes) {
    return '$minutes min';
  }

  @override
  String get settingsAppearanceHint =>
      'A cor principal segue a cor de destaque do Windows, quando disponível.';

  @override
  String get backupFilePasswordLabel => 'Senha do arquivo de backup';

  @override
  String get backupFilePasswordHelper =>
      'Use a senha mestra usada para criar este backup, não a de outro dispositivo.';

  @override
  String get backupPasswordDialogTitle => 'Senha do backup';

  @override
  String get currentPasswordLabel => 'Senha atual';

  @override
  String get newPasswordLabel => 'Nova senha';

  @override
  String get confirmNewPasswordLabel => 'Confirmar nova senha';

  @override
  String passwordStrengthWithValue(Object value) {
    return 'Força: $value';
  }

  @override
  String get fillAllFieldsError => 'Preencha todos os campos.';

  @override
  String get newPasswordsMismatchError => 'As novas senhas não coincidem.';

  @override
  String get newPasswordMustBeStrongError => 'A nova senha deve ser Forte.';

  @override
  String get newPasswordMustDifferError => 'A nova senha deve ser diferente.';

  @override
  String get incorrectPasswordError => 'Senha incorreta.';

  @override
  String get useHelloBiometrics => 'Usar Hello / biometria';

  @override
  String get usePasskey => 'Usar passkey';

  @override
  String get quickUnlockEnabledSnack => 'Desbloqueio rápido ativado';

  @override
  String get quickUnlockDisabledSnack => 'Desbloqueio rápido desativado';

  @override
  String get quickUnlockEnableFailed =>
      'Não foi possível ativar o desbloqueio rápido.';

  @override
  String get passkeyRevokeConfirmTitle => 'Remover passkey?';

  @override
  String get passkeyRevokeConfirmBody =>
      'Você precisará da sua senha mestra para desbloquear até registrar uma nova passkey neste dispositivo.';

  @override
  String get passkeyRegisteredSnack => 'Passkey registrada';

  @override
  String get passkeyRevokedSnack => 'Passkey revogada';

  @override
  String get masterPasswordUpdatedSnack => 'Senha mestra atualizada';

  @override
  String get backupSavedSuccessSnack => 'Backup salvo com sucesso.';

  @override
  String exportFailedError(Object error) {
    return 'Não foi possível exportar: $error';
  }

  @override
  String importFailedGenericError(Object error) {
    return 'Não foi possível importar: $error';
  }

  @override
  String wipeFailedError(Object error) {
    return 'Não foi possível excluir o cofre: $error';
  }

  @override
  String get filePathReadError => 'Não foi possível ler o caminho do arquivo.';

  @override
  String get importedVaultSuccessSnack =>
      'Cofre importado. Ele aparece no seletor de cofres da barra lateral; o atual permanece inalterado.';

  @override
  String get exportVaultDialogTitle => 'Exportar backup do cofre';

  @override
  String get exportVaultDialogBody =>
      'Para criar um arquivo de backup, confirme sua identidade com o cofre atualmente desbloqueado.';

  @override
  String get verifyAndExport => 'Verificar e exportar';

  @override
  String get saveVaultBackupDialogTitle => 'Salvar backup do cofre';

  @override
  String get importVaultDialogTitle => 'Importar backup do cofre';

  @override
  String get importVaultDialogBody =>
      'Um novo cofre será adicionado a partir do arquivo. Seu cofre aberto no momento não será excluído ou modificado.\n\nA senha do arquivo será a senha do cofre importado (usada ao abri-lo após trocar de cofre).\n\nPasskey e desbloqueio rápido (Hello / biometria) não estão incluídos nos backups e não são transferíveis; você poderá configurá-los mais tarde para esse cofre.\n\nContinuar?';

  @override
  String get verifyAndContinue => 'Verificar e continuar';

  @override
  String get verifyAndDelete => 'Verificar com senha e excluir';

  @override
  String get importIdentityBody =>
      'Prove que é você com o cofre desbloqueado no momento antes de importar.';

  @override
  String get wipeVaultDialogTitle => 'Excluir cofre';

  @override
  String get wipeVaultDialogBody =>
      'Todas as páginas serão excluídas e a senha mestra não será mais válida. Esta ação não pode ser desfeita.\n\nTem certeza de que deseja continuar?';

  @override
  String get wipeIdentityBody => 'Para excluir o cofre, prove sua identidade.';

  @override
  String get exportZipTitle => 'Exportar backup (.zip)';

  @override
  String get exportZipSubtitle => 'Senha, Hello ou passkey do cofre atual';

  @override
  String get importZipTitle => 'Importar backup (.zip)';

  @override
  String get importZipSubtitle =>
      'Adiciona um novo cofre · identidade atual + senha do arquivo';

  @override
  String get backupInfoBody =>
      'O arquivo contém os mesmos dados criptografados que estão no disco (vault.keys e vault.bin), sem expor o conteúdo em texto simples. Imagens em anexo são incluídas como estão.\n\nPasskey e desbloqueio rápido não estão incluídos nos backups e não são transferíveis entre dispositivos; você pode configurá-los novamente para cada cofre importado.\n\nA importação adiciona um novo cofre; ela não substitui o que está aberto no momento.';

  @override
  String get wipeCardTitle => 'Excluir cofre e recomeçar';

  @override
  String get wipeCardSubtitle => 'Requer senha, Hello ou passkey.';

  @override
  String get switchVaultTooltip => 'Trocar cofre';

  @override
  String get switchVaultTitle => 'Trocar cofre';

  @override
  String get switchVaultBody =>
      'Esta sessão do cofre será fechada e você precisará desbloquear o outro cofre com a senha dele, Hello ou passkey (se configurado lá).';

  @override
  String get renameVaultTitle => 'Renomear cofre';

  @override
  String get nameLabel => 'Nome';

  @override
  String get deleteOtherVaultTitle => 'Excluir outro cofre';

  @override
  String get deleteVaultConfirmTitle => 'Excluir cofre?';

  @override
  String deleteVaultConfirmBody(Object name) {
    return 'O cofre «$name» será completamente excluído. Isso não pode ser desfeito.';
  }

  @override
  String get vaultDeletedSnack => 'Cofre excluído.';

  @override
  String get noOtherVaultsSnack => 'Nenhum outro cofre para excluir.';

  @override
  String get addVault => 'Adicionar cofre';

  @override
  String get renameActiveVault => 'Renomear cofre ativo';

  @override
  String get deleteOtherVault => 'Excluir outro cofre…';

  @override
  String get activeVaultLabel => 'Cofre ativo';

  @override
  String get sidebarVaultsLoading => 'Carregando cofres…';

  @override
  String get sidebarVaultsEmpty => 'Nenhum cofre disponível';

  @override
  String get forceSyncTooltip => 'Forçar sincronização';

  @override
  String get searchDialogFooterHint =>
      'Enter abre o resultado destacado · Ctrl+↑ / Ctrl+↓ navegam · Esc fecha';

  @override
  String get searchFilterTasks => 'Tarefas';

  @override
  String get searchRecentQueries => 'Buscas recentes';

  @override
  String get searchShortcutsHelpTooltip => 'Atalhos de teclado';

  @override
  String get searchShortcutsHelpTitle => 'Busca global';

  @override
  String get searchShortcutsHelpBody =>
      'Enter: abrir o resultado destacado\nCtrl+↑ ou Ctrl+↓: resultado anterior / próximo\nEsc: fechar';

  @override
  String get renamePageTitle => 'Renomear página';

  @override
  String get titleLabel => 'Título';

  @override
  String get rootPage => 'Raiz';

  @override
  String movePageTitle(Object title) {
    return 'Mover “$title”';
  }

  @override
  String get subpage => 'Subpágina';

  @override
  String get move => 'Mover';

  @override
  String get pages => 'Páginas';

  @override
  String get pageOutlineTitle => 'Estrutura';

  @override
  String get pageOutlineEmpty =>
      'Adicione cabeçalhos (H1–H3) para construir a estrutura.';

  @override
  String get showPageOutline => 'Mostrar estrutura';

  @override
  String get hidePageOutline => 'Ocultar estrutura';

  @override
  String get tocBlockTitle => 'Sumário';

  @override
  String get showSidebar => 'Mostrar barra lateral';

  @override
  String get hideSidebar => 'Ocultar barra lateral';

  @override
  String get resizeSidebarHandle => 'Redimensionar barra lateral';

  @override
  String get resizeSidebarHandleHint =>
      'Arraste horizontalmente para alterar a largura da barra lateral';

  @override
  String get resizeAiPanelHeightHandle => 'Redimensionar altura do assistente';

  @override
  String get resizeAiPanelHeightHandleHint =>
      'Arraste verticalmente para alterar a altura do painel do assistente';

  @override
  String get sidebarAutoRevealTitle => 'Espiar barra lateral na borda esquerda';

  @override
  String get sidebarAutoRevealSubtitle =>
      'Quando a barra lateral estiver oculta, mova o ponteiro para a borda esquerda para mostrá-la temporariamente.';

  @override
  String get newRootPageTooltip => 'Nova página (raiz)';

  @override
  String get blockOptions => 'Opções do bloco';

  @override
  String get meetingNoteTitle => 'Nota de reunião';

  @override
  String get meetingNoteDesktopOnly => 'Disponível apenas no desktop.';

  @override
  String get meetingNoteStartRecording => 'Iniciar gravação';

  @override
  String get meetingNotePreparing => 'Preparando…';

  @override
  String get meetingNoteTranscriptionLanguage => 'Idioma da transcrição';

  @override
  String get meetingNoteLangAuto => 'Automático';

  @override
  String get meetingNoteLangEs => 'Espanhol';

  @override
  String get meetingNoteLangEn => 'Inglês';

  @override
  String get meetingNoteLangPt => 'Português';

  @override
  String get meetingNoteLangFr => 'Francês';

  @override
  String get meetingNoteLangIt => 'Italiano';

  @override
  String get meetingNoteLangDe => 'Alemão';

  @override
  String get meetingNoteDevicesInSettings =>
      'Dispositivos de entrada/saída são configurados em Configurações > Desktop.';

  @override
  String meetingNoteModelInSettings(Object model) {
    return 'Modelo de transcrição: $model (em Configurações > Desktop).';
  }

  @override
  String get meetingNoteDescription =>
      'Grava o microfone e o áudio do sistema. A transcrição é gerada localmente.';

  @override
  String meetingNoteWhisperInitError(Object error) {
    return 'Não foi possível inicializar o Whisper: $error';
  }

  @override
  String get meetingNoteAudioAccessError =>
      'Não foi possível acessar o microfone/dispositivos.';

  @override
  String get meetingNoteMicrophoneAccessError =>
      'Não foi possível acessar o microfone.';

  @override
  String get meetingNoteChunkTranscriptionError =>
      'Não foi possível transcrever este trecho de áudio.';

  @override
  String get meetingNoteProviderLocal => 'Local (Whisper)';

  @override
  String get meetingNoteProviderCloud => 'Quill Cloud';

  @override
  String get meetingNoteProviderCloudCost => '1 Ink por cada 5 min. gravados';

  @override
  String get meetingNoteCloudFallbackNotice =>
      'Nuvem indisponível. Usando Whisper local.';

  @override
  String get meetingNoteCloudInkExhaustedNotice =>
      'Ink insuficiente. Mudando para Whisper local.';

  @override
  String meetingNoteCloudRecordingBadge(Object language) {
    return 'Quill Cloud | Idioma: $language';
  }

  @override
  String get meetingNoteCloudProcessing => 'Processando com Quill Cloud…';

  @override
  String get meetingNoteCloudProcessingSubtitle =>
      'Detectando falantes e melhorando a qualidade. Por favor, aguarde.';

  @override
  String meetingNoteCloudProgress(int done, int total) {
    return 'Trechos processados: $done/$total';
  }

  @override
  String meetingNoteCloudEta(Object remaining) {
    return 'Tempo estimado restante: $remaining';
  }

  @override
  String get meetingNoteCloudEtaCalculating => 'Calculando tempo restante...';

  @override
  String get meetingNoteCloudRequiresAccount =>
      'Requer uma conta Folio Cloud com Ink.';

  @override
  String get meetingNoteTranscriptionProvider => 'Mecanismo de transcrição';

  @override
  String meetingNoteRecordingTime(Object mm, Object ss) {
    return 'Gravando  $mm:$ss';
  }

  @override
  String meetingNoteRecordingBadge(Object language, Object model) {
    return 'Idioma: $language | Modelo: $model';
  }

  @override
  String get meetingNoteSystemAudioCaptured => 'Áudio do sistema capturado';

  @override
  String get meetingNoteStop => 'Parar';

  @override
  String get meetingNoteWaitingTranscription => 'Aguardando transcrição…';

  @override
  String get meetingNoteTranscribing => 'Transcrevendo…';

  @override
  String get meetingNoteTranscriptionTitle => 'Transcrição';

  @override
  String get meetingNoteNoTranscription => 'Nenhuma transcrição disponível.';

  @override
  String get meetingNoteNewRecording => 'Nova gravação';

  @override
  String get meetingNoteSettingsSection => 'Nota de reunião (áudio)';

  @override
  String get meetingNoteSettingsDescription =>
      'Estes dispositivos são usados por padrão ao gravar uma nota de reunião.';

  @override
  String get meetingNoteSettingsMicrophone => 'Microfone';

  @override
  String get meetingNoteSettingsRefreshDevices => 'Atualizar lista';

  @override
  String get meetingNoteSettingsSystemDefault => 'Padrão do sistema';

  @override
  String get meetingNoteSettingsSystemOutput => 'Saída do sistema (loopback)';

  @override
  String get meetingNoteSettingsModel => 'Modelo de transcrição';

  @override
  String get meetingNoteDiarizationHint =>
      'Processamento 100% local no seu dispositivo.';

  @override
  String get meetingNoteModelTiny => 'Rápido';

  @override
  String get meetingNoteModelBase => 'Equilibrado';

  @override
  String get meetingNoteModelSmall => 'Preciso';

  @override
  String get meetingNoteCopyTranscript => 'Copiar transcrição';

  @override
  String get meetingNoteSendToAi => 'Enviar para IA…';

  @override
  String get meetingNoteAiPayloadLabel => 'O que enviar para a IA?';

  @override
  String get meetingNoteAiPayloadTranscript => 'Apenas transcrição';

  @override
  String get meetingNoteAiPayloadAudio => 'Apenas áudio';

  @override
  String get meetingNoteAiPayloadBoth => 'Transcrição + áudio';

  @override
  String get meetingNoteAiInstructionHint => 'ex: resuma os pontos principais';

  @override
  String get meetingNoteAiNoAudio => 'Nenhum áudio disponível para este modo';

  @override
  String get meetingNoteAiInstruction => 'Instrução para a IA';

  @override
  String get dragToReorder => 'Arraste para reordenar';

  @override
  String get addBlock => 'Adicionar bloco';

  @override
  String get blockMentionPageSubtitle => 'Mencionar página';

  @override
  String get blockTypesSheetTitle => 'Tipos de bloco';

  @override
  String get blockTypesSheetSubtitle => 'Escolha como este bloco aparecerá';

  @override
  String get blockTypeFilterEmpty => 'Nada corresponde à sua busca';

  @override
  String get fileNotFound => 'Arquivo não encontrado';

  @override
  String get couldNotLoadImage => 'Não foi possível carregar a imagem';

  @override
  String get noImageHint => 'Sem imagem · use o menu ⋮ ou o botão abaixo';

  @override
  String get chooseImage => 'Escolher imagem';

  @override
  String get replaceFile => 'Substituir arquivo';

  @override
  String get removeFile => 'Remover arquivo';

  @override
  String get replaceVideo => 'Substituir vídeo';

  @override
  String get removeVideo => 'Remover vídeo';

  @override
  String get openExternal => 'Abrir externamente';

  @override
  String get openVideoExternal => 'Abrir vídeo externamente';

  @override
  String get play => 'Reproduzir';

  @override
  String get pause => 'Pausar';

  @override
  String get mute => 'Mudo';

  @override
  String get unmute => 'Ativar som';

  @override
  String get fileResolveError => 'Erro ao resolver arquivo';

  @override
  String get videoResolveError => 'Erro ao resolver vídeo';

  @override
  String get fileMissing => 'Arquivo não encontrado';

  @override
  String get videoMissing => 'Vídeo não encontrado';

  @override
  String get chooseFile => 'Escolher arquivo';

  @override
  String get chooseVideo => 'Escolher vídeo';

  @override
  String get noEmbeddedPreview => 'Sem visualização incorporada para este tipo';

  @override
  String get couldNotReadFile => 'Não foi possível ler o arquivo';

  @override
  String get couldNotLoadVideo => 'Não foi possível carregar o vídeo';

  @override
  String get couldNotPreviewPdf => 'Não foi possível visualizar o PDF';

  @override
  String get openInYoutubeBrowser => 'Abrir no navegador';

  @override
  String get pasteUrlTitle => 'Colar link como';

  @override
  String get pasteAsUrl => 'URL';

  @override
  String get pasteAsEmbed => 'Incorporado';

  @override
  String get pasteAsBookmark => 'Indicador (Bookmark)';

  @override
  String get pasteAsMention => 'Menção';

  @override
  String get pasteAsUrlSubtitle => 'Inserir link markdown no texto';

  @override
  String get pasteAsEmbedSubtitle =>
      'Bloco de vídeo com visualização (YouTube) ou indicador';

  @override
  String get pasteAsBookmarkSubtitle => 'Cartão com título e link';

  @override
  String get pasteAsMentionSubtitle => 'Link para uma página neste cofre';

  @override
  String get tableAddRow => 'Linha';

  @override
  String get tableRemoveRow => 'Remover linha';

  @override
  String get tableAddColumn => 'Coluna';

  @override
  String get tableRemoveColumn => 'Remover col.';

  @override
  String get tablePasteFromClipboard => 'Colar tabela';

  @override
  String get pickPageForMention => 'Escolher página';

  @override
  String get bookmarkTitleHint => 'Título';

  @override
  String get bookmarkOpenLink => 'Abrir link';

  @override
  String get bookmarkSetUrl => 'Definir URL…';

  @override
  String get bookmarkBlockHint => 'Cole um link ou use o menu do bloco';

  @override
  String get bookmarkRemove => 'Remover indicador';

  @override
  String get embedUnavailable =>
      'A visualização da web incorporada não está disponível nesta plataforma. Abra o link no seu navegador.';

  @override
  String get embedOpenBrowser => 'Abrir no navegador';

  @override
  String get embedSetUrl => 'Definir URL de incorporação…';

  @override
  String get embedRemove => 'Remover incorporação';

  @override
  String get embedEmptyHint =>
      'Cole um link ou defina a URL pelo menu do bloco';

  @override
  String get blockSizeSmaller => 'Menor';

  @override
  String get blockSizeLarger => 'Maior';

  @override
  String get blockSizeHalf => '50%';

  @override
  String get blockSizeThreeQuarter => '75%';

  @override
  String get blockSizeFull => '100%';

  @override
  String get pasteAsEmbedSubtitleWeb =>
      'Mostrar a página dentro do bloco (quando suportado)';

  @override
  String get pasteAsMentionSubtitleRich =>
      'Link com título da página (ex: YouTube)';

  @override
  String get formatToolbar => 'Barra de formatação';

  @override
  String get linkTitle => 'Link';

  @override
  String get visibleTextLabel => 'Texto visível';

  @override
  String get urlLabel => 'URL';

  @override
  String get urlHint => 'https://…';

  @override
  String get insert => 'Inserir';

  @override
  String get defaultLinkText => 'texto';

  @override
  String get boldTip => 'Negrito (**)';

  @override
  String get italicTip => 'Itálico (_)';

  @override
  String get underlineTip => 'Sublinhado (<u>)';

  @override
  String get inlineCodeTip => 'Código em linha (`)';

  @override
  String get strikeTip => 'Tachado (~~)';

  @override
  String get linkTip => 'Link';

  @override
  String get pageHistoryTitle => 'Histórico de versões';

  @override
  String get restoreVersionTitle => 'Restaurar versão';

  @override
  String get restoreVersionBody =>
      'O título e o conteúdo da página serão substituídos por esta versão. O estado atual será salvo primeiro no histórico.';

  @override
  String get restore => 'Restaurar';

  @override
  String get deleteVersionTitle => 'Excluir versão';

  @override
  String get deleteVersionBody =>
      'Esta entrada será removida do histórico. O texto atual da página não muda.';

  @override
  String get noVersionsYet => 'Nenhuma versão ainda';

  @override
  String get historyAppearsHint =>
      'Após você parar de digitar por alguns segundos, o histórico de alterações aparecerá aqui.';

  @override
  String get versionControl => 'Controle de versão';

  @override
  String get historyHeaderBody =>
      'O cofre salva rapidamente; o histórico adiciona uma entrada quando você para de editar e o conteúdo foi alterado.';

  @override
  String versionsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'versões',
      one: 'versão',
    );
    return '$count $_temp0';
  }

  @override
  String get untitledFallback => 'Sem título';

  @override
  String get comparedWithPrevious => 'Comparado com a versão anterior';

  @override
  String get changesFromEmptyStart => 'Alterações desde o início vazio';

  @override
  String get contentLabel => 'Conteúdo';

  @override
  String get titleLabelSimple => 'Título';

  @override
  String get emptyValue => '(vazio)';

  @override
  String get noTextChanges => 'Nenhuma alteração de texto.';

  @override
  String get aiAssistantTitle => 'Quill';

  @override
  String get aiNoPageSelected => 'Nenhuma página selecionada';

  @override
  String get aiChatContextDisabledSubtitle =>
      'Texto da página não enviado para o modelo';

  @override
  String aiChatContextUsesCurrentPage(Object title) {
    return 'Contexto: página atual ($title)';
  }

  @override
  String get aiChatContextOnePageFallback => 'Contexto: 1 página';

  @override
  String aiChatContextNPages(int count) {
    return '$count páginas no contexto do chat';
  }

  @override
  String get aiChatPageContextTooltip =>
      'Incluir texto da página no contexto do modelo';

  @override
  String get aiChatChooseContextPagesTooltip =>
      'Escolher quais páginas adicionam texto ao contexto';

  @override
  String get aiChatContextPagesDialogTitle => 'Páginas no contexto do chat';

  @override
  String get aiChatContextPagesClear => 'Limpar lista';

  @override
  String get aiChatContextPagesApply => 'Aplicar';

  @override
  String get aiTypingSemantics => 'Quill está digitando';

  @override
  String get aiRenameChatTooltip => 'Renomear chat';

  @override
  String get aiRenameChatDialogTitle => 'Título do chat';

  @override
  String get aiRenameChatLabel => 'Título exibido na aba';

  @override
  String get quillWorkspaceTourTitle => 'O Quill pode ajudar daqui';

  @override
  String get quillWorkspaceTourBodyReady =>
      'Seu chat com o Quill está pronto para perguntas, edições de página e fluxos de contexto de notas.';

  @override
  String get quillWorkspaceTourBodyUnavailable =>
      'Mesmo que não esteja ativo agora, o Quill pertence a este espaço de trabalho e você pode ativá-lo mais tarde nas Configurações.';

  @override
  String get quillWorkspaceTourPointsTitle => 'O que vale a pena saber';

  @override
  String get quillWorkspaceTourPointOne =>
      'Ele funciona tanto como um assistente de conversação quanto como um editor para títulos e blocos.';

  @override
  String get quillWorkspaceTourPointTwo =>
      'Ele pode usar a página atual ou múltiplas páginas como contexto.';

  @override
  String get quillWorkspaceTourPointThree =>
      'Se você tocar em um exemplo abaixo, ele preencherá o chat quando o Quill estiver disponível.';

  @override
  String get quillWorkspaceTourExamplesTitle => 'Tente comandos como';

  @override
  String get quillWorkspaceTourExampleOne =>
      'Explique como organizar esta página.';

  @override
  String get quillWorkspaceTourExampleTwo =>
      'Use estas duas páginas para fazer um resumo compartilhado.';

  @override
  String get quillWorkspaceTourExampleThree =>
      'Reescreva este bloco em um tom mais claro.';

  @override
  String get quillTourDismiss => 'Entendi';

  @override
  String get aiExpand => 'Expandir';

  @override
  String get aiCollapse => 'Recolher';

  @override
  String get aiDeleteCurrentChat => 'Excluir chat atual';

  @override
  String get aiNewChat => 'Novo';

  @override
  String get aiAttach => 'Anexar';

  @override
  String get aiChatEmptyHint =>
      'Inicie uma conversa.\nO Quill decidirá automaticamente o que fazer com sua mensagem.\nVocê também pode perguntar como usar o Folio (atalhos, configurações, páginas ou este chat).';

  @override
  String get aiChatEmptyFocusComposer => 'Escreva uma mensagem';

  @override
  String get aiInputHint =>
      'Digite sua mensagem. O Quill agirá como um agente.';

  @override
  String get aiInputHintCopilot => 'Digite sua mensagem...';

  @override
  String get aiContextComposerHint => 'Nenhum contexto adicionado';

  @override
  String get aiContextComposerHelper => 'Use @ para adicionar contexto';

  @override
  String aiContextCurrentPageChip(Object title) {
    return 'Página atual: $title';
  }

  @override
  String get aiContextCurrentPageFallback => 'Página atual';

  @override
  String get aiContextAddFile => 'Anexar arquivo';

  @override
  String get aiContextAddPage => 'Anexar página';

  @override
  String get aiShowPanel => 'Mostrar painel de IA';

  @override
  String get aiHidePanel => 'Ocultar painel de IA';

  @override
  String get aiPanelResizeHandle => 'Redimensionar painel de IA';

  @override
  String get aiPanelResizeHandleHint =>
      'Arraste horizontalmente para alterar a largura do painel do assistente';

  @override
  String get importMarkdownPage => 'Importar Markdown';

  @override
  String get exportMarkdownPage => 'Exportar Markdown';

  @override
  String get workspaceUndoTooltip => 'Desfazer (Ctrl+Z)';

  @override
  String get workspaceRedoTooltip => 'Refazer (Ctrl+Y)';

  @override
  String get workspaceMoreActionsTooltip => 'Mais ações';

  @override
  String get closeCurrentPage => 'Fechar página atual';

  @override
  String aiErrorWithDetails(Object error) {
    return 'Erro de IA: $error';
  }

  @override
  String get aiServiceUnreachable =>
      'Não foi possível alcançar o serviço de IA no endpoint configurado. Inicie o Ollama ou LM Studio e verifique a URL.';

  @override
  String get aiLaunchProviderWithApp =>
      'Abrir app de IA quando o Folio iniciar';

  @override
  String get aiLaunchProviderWithAppHint =>
      'Tenta iniciar o Ollama ou LM Studio no Windows quando o endpoint é localhost. O LM Studio ainda pode precisar que seu servidor seja iniciado manualmente.';

  @override
  String get aiContextWindowTokens => 'Janela de contexto do modelo (tokens)';

  @override
  String get aiContextWindowTokensHint =>
      'Usado para a barra de contexto no chat de IA. Deve corresponder ao seu modelo (ex: 8192, 131072).';

  @override
  String get aiContextUsageUnavailable =>
      'O uso de tokens não foi relatado para a última resposta.';

  @override
  String aiContextUsageSummary(Object prompt, Object completion) {
    return 'Prompt $prompt · Resposta $completion';
  }

  @override
  String aiContextUsageTooltip(int window) {
    return 'Última requisição vs sua janela de contexto configurada ($window tokens).';
  }

  @override
  String get aiChatKeyboardHint =>
      'Enter para enviar · Ctrl+Enter para nova linha';

  @override
  String aiChatInkRemaining(int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: 'Restam $total gotas de ink',
      one: 'Resta 1 gota de ink',
    );
    return '$_temp0';
  }

  @override
  String aiChatInkBreakdownTooltip(int monthly, int purchased) {
    return 'Mensal $monthly · Comprado $purchased';
  }

  @override
  String get aiAgentThought => 'Pensamento do Quill';

  @override
  String get aiAlwaysShowThought => 'Sempre mostrar pensamento da IA';

  @override
  String get aiAlwaysShowThoughtHint =>
      'Se desativado, ele aparece recolhido com uma seta em cada mensagem.';

  @override
  String get aiBetaBadge => 'BETA';

  @override
  String get aiBetaEnableTitle => 'A IA está em BETA';

  @override
  String get aiBetaEnableBody =>
      'Este recurso está atualmente em BETA e pode falhar ou se comportar de forma inesperada.\n\nDeseja ativá-lo mesmo assim?';

  @override
  String get aiBetaEnableConfirm => 'Ativar BETA';

  @override
  String get ai => 'IA';

  @override
  String get aiEnableToggleTitle => 'Ativar IA';

  @override
  String get aiProviderLabel => 'Provedor';

  @override
  String get aiProviderNone => 'Nenhum';

  @override
  String get aiEndpoint => 'Endpoint';

  @override
  String get aiModel => 'Modelo';

  @override
  String get aiTimeoutMs => 'Tempo limite (ms)';

  @override
  String get aiAllowRemoteEndpoint => 'Permitir endpoint remoto';

  @override
  String get aiAllowRemoteEndpointAllowed => 'Hosts remotos permitidos';

  @override
  String get aiAllowRemoteEndpointLocalhostOnly => 'Apenas localhost';

  @override
  String get aiAllowRemoteEndpointNotConfirmed =>
      'O acesso ao endpoint remoto está ativado, mas ainda não foi confirmado.';

  @override
  String get aiConnectToListModels => 'Conectar para listar modelos';

  @override
  String aiProviderAutoConfigured(Object provider) {
    return 'Provedor de IA detectado e configurado: $provider';
  }

  @override
  String get aiSetupAssistantTitle => 'Assistente de configuração de IA';

  @override
  String get aiSetupAssistantSubtitle =>
      'Detectar e configurar Ollama ou LM Studio automaticamente.';

  @override
  String get aiSetupWizardTitle => 'Assistente de configuração de IA';

  @override
  String get aiSetupChooseProviderTitle => 'Escolha o provedor de IA';

  @override
  String get aiSetupChooseProviderBody =>
      'Primeiro escolha qual provedor você deseja usar. Depois, nós o guiaremos pela instalação e configuração.';

  @override
  String get aiSetupNoProviderTitle => 'Nenhum provedor ativo detectado';

  @override
  String get aiSetupNoProviderBody =>
      'Não encontramos o Ollama ou LM Studio em execução e acessível.\nSiga os passos para instalar/iniciar um deles e pressione Tentar novamente.';

  @override
  String get aiSetupOllamaTitle => 'Passo 1: Instalar Ollama';

  @override
  String get aiSetupOllamaBody =>
      'Instale o Ollama, execute o serviço local e verifique se ele responde em http://127.0.0.1:11434.';

  @override
  String get aiSetupLmStudioTitle => 'Passo 2: Instalar LM Studio';

  @override
  String get aiSetupLmStudioBody =>
      'Instale o LM Studio, inicie seu servidor local (compatível com OpenAI) e verifique se ele responde em http://127.0.0.1:1234.';

  @override
  String get aiSetupOpenSettingsHint =>
      'Quando um provedor estiver operacional, pressione Tentar novamente para configurá-lo automaticamente.';

  @override
  String get aiCompareCloudVsLocalTitle => 'Nuvem vs local';

  @override
  String get aiCompareCloudTitle => 'Folio Cloud';

  @override
  String get aiCompareLocalTitle => 'Local (Ollama / LM Studio)';

  @override
  String get aiCompareCloudBulletNoSetup =>
      'Sem configuração local: funciona após o login.';

  @override
  String get aiCompareCloudBulletNeedsSub =>
      'Assinatura Folio Cloud com IA na nuvem ou ink comprado.';

  @override
  String get aiCompareCloudBulletInk =>
      'Usa ink para IA na nuvem (pacotes + recarga mensal).';

  @override
  String get aiProviderFolioCloudBlockedSnack =>
      'Você precisa de um plano Folio Cloud ativo com IA na nuvem ou ink comprado — veja Configurações → Folio Cloud.';

  @override
  String get aiCompareLocalBulletPrivacy => 'Privacidade local (sua máquina).';

  @override
  String get aiCompareLocalBulletNoInk => 'Sem ink: não depende de saldo.';

  @override
  String get aiCompareLocalBulletSetup =>
      'Requer instalação e execução de um provedor no localhost.';

  @override
  String get quillGlobalScopeNoticeTitle =>
      'O Quill funciona em todos os cofres';

  @override
  String get quillGlobalScopeNoticeBody =>
      'O Quill é uma configuração em nível de aplicativo. Se você ativá-lo agora, ele estará disponível para qualquer cofre nesta instalação, não apenas para o atual.';

  @override
  String get quillGlobalScopeNoticeConfirm => 'Eu entendo';

  @override
  String get searchByNameOrShortcut => 'Buscar por nome ou atalho…';

  @override
  String get search => 'Buscar';

  @override
  String get open => 'Abrir';

  @override
  String get exit => 'Sair';

  @override
  String get trayMenuCloseApplication => 'Fechar aplicativo';

  @override
  String get keyboardShortcutsSection => 'Teclado (no app)';

  @override
  String get shortcutTestAction => 'Testar';

  @override
  String get shortcutChangeAction => 'Alterar';

  @override
  String shortcutTestHint(Object combo) {
    return 'Com o foco fora de um campo de texto, “$combo” deve funcionar no espaço de trabalho.';
  }

  @override
  String get shortcutResetAllTitle => 'Restaurar atalhos padrão';

  @override
  String get shortcutResetAllSubtitle =>
      'Redefine todos os atalhos do app para os padrões do Folio.';

  @override
  String get shortcutResetDoneSnack => 'Atalhos restaurados para os padrões.';

  @override
  String get desktopSection => 'Desktop';

  @override
  String get globalSearchHotkey => 'Atalho de busca global';

  @override
  String get hotkeyCombination => 'Combinação de teclas';

  @override
  String get hotkeyAltSpace => 'Alt + Espaço';

  @override
  String get hotkeyCtrlShiftSpace => 'Ctrl + Shift + Espaço';

  @override
  String get hotkeyCtrlShiftK => 'Ctrl + Shift + K';

  @override
  String get minimizeToTray => 'Minimizar para a bandeja';

  @override
  String get closeToTray => 'Fechar para a bandeja';

  @override
  String get searchAllVaultHint => 'Buscar em todo o cofre...';

  @override
  String get typeToSearch => 'Digite para buscar';

  @override
  String get noSearchResults => 'Nenhum resultado';

  @override
  String get searchFilterAll => 'Todos';

  @override
  String get searchFilterTitles => 'Títulos';

  @override
  String get searchFilterContent => 'Conteúdo';

  @override
  String get searchSortRelevance => 'Relevância';

  @override
  String get searchSortRecent => 'Recente';

  @override
  String get settingsSearchSections => 'Configurações de busca';

  @override
  String get settingsSearchSectionsHint =>
      'Categorias de filtro na barra lateral';

  @override
  String get scheduledVaultBackupTitle => 'Backup criptografado agendado';

  @override
  String get scheduledVaultBackupSubtitle =>
      'Enquanto o cofre estiver desbloqueado, cada backup é do cofre aberto no momento. O Folio salva um ZIP na pasta abaixo no intervalo escolhido.';

  @override
  String get scheduledVaultBackupChooseFolder => 'Pasta de backup';

  @override
  String get scheduledVaultBackupIntervalLabel => 'Intervalo (horas)';

  @override
  String scheduledVaultBackupLastRun(Object time) {
    return 'Último backup: $time';
  }

  @override
  String get scheduledVaultBackupSnackOk => 'Backup agendado salvo.';

  @override
  String scheduledVaultBackupSnackFail(Object error) {
    return 'Falha no backup agendado: $error';
  }

  @override
  String vaultBackupOpenVaultHint(String name) {
    return 'Backups são para o cofre aberto agora: “$name”.';
  }

  @override
  String get vaultBackupRunNowTile => 'Executar backup agendado agora';

  @override
  String get vaultBackupRunNowSubtitle =>
      'Executa o backup agendado agora (disco e/ou nuvem, dependendo das suas configurações) sem esperar pelo intervalo.';

  @override
  String get vaultBackupRunNowNeedFolder =>
      'Escolha uma pasta de backup local ou ative “Também enviar para o Folio Cloud” para backups apenas na nuvem.';

  @override
  String get vaultIdentitySyncTitle => 'Sincronização';

  @override
  String get vaultIdentitySyncBody =>
      'Digite a senha do seu cofre (ou Hello / passkey) para continuar.';

  @override
  String get vaultIdentityCloudBackupTitle => 'Backups na nuvem';

  @override
  String get vaultIdentityCloudBackupBody =>
      'Confirme a identidade do cofre para listar ou baixar backups criptografados.';

  @override
  String get aiRewriteDialogTitle => 'Reescrever com IA';

  @override
  String get aiPreviewTitle => 'Visualização';

  @override
  String get aiInstructionHint => 'Exemplo: torne mais claro e curto';

  @override
  String get aiApply => 'Aplicar';

  @override
  String get aiGenerating => 'Gerando…';

  @override
  String get aiSummarizeSelection => 'Resumir com IA…';

  @override
  String get aiExtractTasksDates => 'Extrair tarefas e datas…';

  @override
  String get aiPreviewReadOnlyHint =>
      'Você pode editar o texto abaixo antes de aplicar.';

  @override
  String get aiRewriteApplied => 'Bloco atualizado.';

  @override
  String get aiUndoRewrite => 'Desfazer';

  @override
  String get aiInsertBelow => 'Inserir abaixo';

  @override
  String get unlockVaultTitle => 'Desbloquear cofre';

  @override
  String get miniUnlockFailed => 'Não foi possível desbloquear.';

  @override
  String get importNotionTitle => 'Importar do Notion (.zip)';

  @override
  String get importNotionSubtitle => 'Exportação ZIP do Notion (Markdown/HTML)';

  @override
  String get importNotionDialogTitle => 'Importar do Notion';

  @override
  String get importNotionDialogBody =>
      'Importe um ZIP exportado pelo Notion. Você pode anexar ao cofre atual ou criar um novo.';

  @override
  String get importNotionSelectTargetTitle => 'Destino da importação';

  @override
  String get importNotionSelectTargetBody =>
      'Escolha se deseja importar a exportação do Notion para o seu cofre atual ou criar um novo cofre a partir dela.';

  @override
  String get importNotionTargetCurrent => 'Cofre atual';

  @override
  String get importNotionTargetNew => 'Novo cofre';

  @override
  String get importNotionDefaultVaultName => 'Importado do Notion';

  @override
  String get importNotionNewVaultPasswordTitle => 'Senha para o novo cofre';

  @override
  String get importNotionSuccessCurrent =>
      'Notion importado para o cofre atual.';

  @override
  String get importNotionSuccessNew => 'Novo cofre importado do Notion.';

  @override
  String importNotionError(Object error) {
    return 'Não foi possível importar do Notion: $error';
  }

  @override
  String get importNotionWarningsTitle => 'Avisos de importação';

  @override
  String get importNotionWarningsBody =>
      'A importação foi concluída com alguns avisos:';

  @override
  String get ok => 'OK';

  @override
  String get notionExportGuideTitle => 'Como exportar do Notion';

  @override
  String get notionExportGuideBody =>
      'No Notion, vá em Configurações -> Exportar todo o conteúdo do espaço de trabalho, escolha HTML ou Markdown e baixe o arquivo ZIP. Depois, use esta opção de importação no Folio.';

  @override
  String get appBetaBannerMessage =>
      'Você está usando uma versão beta. Você pode encontrar bugs; faça backup do seu cofre regularmente.';

  @override
  String get appBetaBannerDismiss => 'Entendi';

  @override
  String get integrations => 'Integrações';

  @override
  String get integrationsAppsApprovedHint =>
      'Aplicativos externos aprovados podem usar a ponte de integração local.';

  @override
  String get integrationsAppsApprovedTitle => 'Apps externos aprovados';

  @override
  String get integrationsAppsApprovedNone =>
      'Você ainda não aprovou nenhum aplicativo externo.';

  @override
  String get integrationsAppsApprovedRevoke => 'Revogar acesso';

  @override
  String integrationsApprovedAppDetails(
    Object appId,
    Object appVersion,
    Object integrationVersion,
  ) {
    return '$appId · App $appVersion · Integração $integrationVersion';
  }

  @override
  String get integrationApprovalTitle => 'Aprovar integração externa';

  @override
  String get integrationApprovalUpdateTitle =>
      'Aprovar atualização de integração';

  @override
  String integrationApprovalBody(
    Object appName,
    Object appVersion,
    Object integrationVersion,
  ) {
    return '\"$appName\" deseja se conectar ao Folio usando a versão do app $appVersion e a versão de integração $integrationVersion.';
  }

  @override
  String integrationApprovalUpdateBody(
    Object appName,
    Object previousVersion,
    Object integrationVersion,
  ) {
    return '\"$appName\" foi previamente aprovado com a versão de integração $previousVersion. Agora ele deseja se conectar com a versão de integração $integrationVersion, então o Folio precisa da sua aprovação novamente.';
  }

  @override
  String get integrationApprovalUnknownVersion => 'desconhecido';

  @override
  String get integrationApprovalAppId => 'ID do App';

  @override
  String get integrationApprovalAppVersion => 'Versão do App';

  @override
  String get integrationApprovalProtocolVersion => 'Versão da integração';

  @override
  String get integrationApprovalCanDoTitle =>
      'O que esta integração pode fazer';

  @override
  String get integrationApprovalCanDoSessions =>
      'Criar sessões de importação curtas no Folio.';

  @override
  String get integrationApprovalCanDoImport =>
      'Enviar documentação Markdown para criar ou atualizar páginas através da ponte de importação.';

  @override
  String get integrationApprovalCanDoMetadata =>
      'Armazenar procedência da importação, como o app cliente, sessão e metadados de origem nas páginas importadas.';

  @override
  String get integrationApprovalCanDoUnlockedVault =>
      'Importar apenas enquanto o cofre estiver disponível e a requisição incluir o segredo configurado.';

  @override
  String get integrationApprovalCannotDoTitle => 'O que ela NÃO pode fazer';

  @override
  String get integrationApprovalCannotDoRead =>
      'Ela não pode ler o conteúdo do seu cofre através desta ponte.';

  @override
  String get integrationApprovalCannotDoBypassLock =>
      'Ela não pode ignorar o bloqueio do cofre, a criptografia ou sua aprovação explícita.';

  @override
  String get integrationApprovalCannotDoWithoutSecret =>
      'Ela não pode acessar endpoints protegidos sem o segredo compartilhado.';

  @override
  String get integrationApprovalCannotDoRemoteAccess =>
      'Ela não pode usar a ponte fora do localhost.';

  @override
  String get integrationApprovalEncryptedChip => 'Conteúdo criptografado (v2)';

  @override
  String get integrationApprovalUnencryptedChip =>
      'Conteúdo não criptografado (v1)';

  @override
  String get integrationApprovalEncryptedTitle =>
      'Versão 2: criptografia de conteúdo obrigatória';

  @override
  String get integrationApprovalEncryptedDescription =>
      'Esta versão exige payloads criptografados para importar e atualizar conteúdo através da ponte local.';

  @override
  String get integrationApprovalUnencryptedTitle =>
      'Versão 1: conteúdo não criptografado';

  @override
  String get integrationApprovalUnencryptedDescription =>
      'Esta versão permite payloads em texto simples para o conteúdo. Se precisar de criptografia de transporte, atualize a integração para a versão 2.';

  @override
  String get integrationApprovalDeny => 'Negar';

  @override
  String get integrationApprovalApprove => 'Aprovar';

  @override
  String get integrationApprovalApproveUpdate => 'Aprovar esta atualização';

  @override
  String get about => 'Sobre';

  @override
  String get installedVersion => 'Versão instalada';

  @override
  String get updaterGithubRepository => 'Repositório de atualizações';

  @override
  String get updaterBetaDescription =>
      'Betas são lançamentos no GitHub marcados como pré-lançamento.';

  @override
  String get updaterStableDescription =>
      'Apenas o último lançamento estável é considerado.';

  @override
  String get checkUpdates => 'Verificar atualizações';

  @override
  String get noEncryptionConfirmTitle => 'Criar cofre sem criptografia';

  @override
  String get noEncryptionConfirmBody =>
      'Seus dados serão armazenados sem senha e sem criptografia. Qualquer pessoa com acesso a este dispositivo poderá lê-los.';

  @override
  String get createVaultWithoutEncryption => 'Criar sem criptografia';

  @override
  String get plainVaultSecurityNotice =>
      'Este cofre não está criptografado. Passkey, desbloqueio rápido (Hello), bloqueio automático, bloqueio ao minimizar e senha mestra não se aplicam.';

  @override
  String get encryptPlainVaultTitle => 'Criptografar este cofre';

  @override
  String get encryptPlainVaultBody =>
      'Escolha uma senha mestra. Todos os dados neste dispositivo serão criptografados. Se você esquecê-la, seus dados não poderão ser recuperados.';

  @override
  String get encryptPlainVaultConfirm => 'Criptografar cofre';

  @override
  String get encryptPlainVaultSuccessSnack =>
      'O cofre agora está criptografado';

  @override
  String get aiCopyMessage => 'Copiar';

  @override
  String get aiCopyCode => 'Copiar código';

  @override
  String get aiCopiedToClipboard => 'Copiado para a área de transferência';

  @override
  String get aiHelpful => 'Útil';

  @override
  String get aiNotHelpful => 'Não é útil';

  @override
  String get aiThinkingMessage => 'Quill está pensando...';

  @override
  String get aiMessageTimestampNow => 'agora';

  @override
  String aiMessageTimestampMinutes(int n) {
    return '$n min atrás';
  }

  @override
  String aiMessageTimestampHours(int n) {
    return '$n h atrás';
  }

  @override
  String aiMessageTimestampDays(int n) {
    return '$n dias atrás';
  }

  @override
  String get templateGalleryTitle => 'Modelos de Página';

  @override
  String get templateImport => 'Importar';

  @override
  String get templateImportPickTitle => 'Selecione um arquivo de modelo';

  @override
  String get templateImportSuccess => 'Modelo importado';

  @override
  String templateImportError(Object error) {
    return 'Erro ao importar: $error';
  }

  @override
  String get templateExportPickTitle => 'Salvar arquivo de modelo';

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
      'Nenhum modelo ainda.\nSalve uma página como modelo ou importe um.';

  @override
  String templateBlockCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'blocos',
      one: 'bloco',
    );
    return '$count $_temp0';
  }

  @override
  String get templateUse => 'Usar modelo';

  @override
  String get templateExport => 'Exportar';

  @override
  String get templateBlankPage => 'Página em branco';

  @override
  String get templateFromGallery => 'De modelo…';

  @override
  String get saveAsTemplate => 'Salvar como modelo';

  @override
  String get saveAsTemplateTitle => 'Salvar como modelo';

  @override
  String get templateNameHint => 'Nome do modelo';

  @override
  String get templateDescriptionHint => 'Descrição (opcional)';

  @override
  String get templateCategoryHint => 'Categoria (opcional)';

  @override
  String get templateSaved => 'Salvo como modelo';

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
    return 'Mostrando $visible de $total modelos';
  }

  @override
  String get templateSortRecent => 'Mais recentes';

  @override
  String get templateSortName => 'Nome';

  @override
  String get templateEdit => 'Editar modelo';

  @override
  String get templateUpdated => 'Modelo atualizado';

  @override
  String get templateDeleteConfirmTitle => 'Excluir modelo';

  @override
  String templateDeleteConfirmBody(Object name) {
    return 'O modelo \"$name\" será removido deste cofre.';
  }

  @override
  String templateCreatedOn(Object date) {
    return 'Criado em $date';
  }

  @override
  String get templatePreviewEmpty =>
      'Este modelo ainda não possui uma visualização de texto.';

  @override
  String get templateSelectHint =>
      'Selecione um modelo para inspecioná-lo, editar seus metadados ou exportá-lo.';

  @override
  String get templateGalleryTabLocal => 'Local';

  @override
  String get templateGalleryTabCommunity => 'Comunidade';

  @override
  String get templateCommunitySignInCta =>
      'Faça login para compartilhar e navegar pelos modelos da comunidade.';

  @override
  String get templateCommunitySignInButton => 'Entrar';

  @override
  String get templateCommunityUnavailable =>
      'Modelos da comunidade requerem Firebase. Verifique sua conexão ou configuração.';

  @override
  String get templateCommunityEmpty =>
      'Nenhum modelo da comunidade ainda. Seja o primeiro a compartilhar um pela aba Local.';

  @override
  String templateCommunityLoadError(Object error) {
    return 'Não foi possível carregar os modelos da comunidade: $error';
  }

  @override
  String get templateCommunityRetry => 'Tentar novamente';

  @override
  String get templateCommunityRefresh => 'Atualizar';

  @override
  String get templateCommunityShareTitle => 'Compartilhar com a comunidade';

  @override
  String get templateCommunityShareBody =>
      'Seu modelo ficará público para que qualquer pessoa possa ver e baixar. Remova conteúdos pessoais ou confidenciais antes de compartilhar.';

  @override
  String get templateCommunityShareConfirm => 'Compartilhar';

  @override
  String get templateCommunityShareSuccess =>
      'Modelo compartilhado com a comunidade';

  @override
  String templateCommunityShareError(Object error) {
    return 'Não foi possível compartilhar: $error';
  }

  @override
  String get templateCommunityAddToVault => 'Salvar nos meus modelos';

  @override
  String get templateCommunityAddedToVault => 'Salvo nos seus modelos';

  @override
  String get templateCommunityDeleteTitle => 'Remover da comunidade';

  @override
  String templateCommunityDeleteBody(Object name) {
    return 'Excluir \"$name\" da loja da comunidade? Isso não pode ser desfeito.';
  }

  @override
  String get templateCommunityDeleteSuccess => 'Removido da comunidade';

  @override
  String templateCommunityDeleteError(Object error) {
    return 'Não foi possível remover: $error';
  }

  @override
  String templateCommunityDownloadError(Object error) {
    return 'Não foi possível baixar o modelo: $error';
  }

  @override
  String get clear => 'Limpar';

  @override
  String get cloudAccountSectionTitle => 'Conta Folio Cloud';

  @override
  String get cloudAccountSectionDescription =>
      'Opcional. Entre para assinar backup na nuvem, IA hospedada e publicação na web. Seu cofre permanece local a menos que você use esses recursos.';

  @override
  String get cloudAccountChipOptional => 'Opcional';

  @override
  String get cloudAccountChipPaidCloud => 'Backups, IA e Web';

  @override
  String get cloudAccountUnavailable =>
      'O login na nuvem está indisponível (Firebase não iniciou). Verifique sua conexão ou execute flutterfire configure.';

  @override
  String get cloudAccountEmailLabel => 'E-mail';

  @override
  String get cloudAccountPasswordLabel => 'Senha';

  @override
  String get cloudAccountSignIn => 'Entrar';

  @override
  String get cloudAccountCreateAccount => 'Criar conta';

  @override
  String get cloudAccountForgotPassword => 'Esqueceu a senha?';

  @override
  String get cloudAccountSignOut => 'Sair';

  @override
  String cloudAccountSignedInAs(Object email) {
    return 'Logado como $email';
  }

  @override
  String cloudAccountUid(Object uid) {
    return 'ID do Usuário: $uid';
  }

  @override
  String get cloudAuthDialogTitleSignIn => 'Entrar no Folio Cloud';

  @override
  String get cloudAuthDialogTitleRegister => 'Criar conta Folio Cloud';

  @override
  String get cloudAuthDialogTitleReset => 'Redefinir senha';

  @override
  String get cloudPasswordResetSent =>
      'Se existir uma conta para esse e-mail, um link de redefinição foi enviado.';

  @override
  String get cloudAuthErrorInvalidEmail =>
      'Esse endereço de e-mail não é válido.';

  @override
  String get cloudAuthErrorWrongPassword => 'Senha incorreta.';

  @override
  String get cloudAuthErrorUserNotFound =>
      'Nenhuma conta encontrada para esse e-mail.';

  @override
  String get cloudAuthErrorUserDisabled => 'Esta conta foi desativada.';

  @override
  String get cloudAuthErrorEmailAlreadyInUse =>
      'Este e-mail já está registrado.';

  @override
  String get cloudAuthErrorWeakPassword => 'A senha é muito fraca.';

  @override
  String get cloudAuthErrorInvalidCredential => 'E-mail ou senha inválidos.';

  @override
  String get cloudAuthErrorNetwork => 'Erro de rede. Verifique sua conexão.';

  @override
  String get cloudAuthErrorTooManyRequests =>
      'Muitas tentativas. Tente novamente mais tarde.';

  @override
  String get cloudAuthErrorOperationNotAllowed =>
      'Este método de login não está ativado no Firebase.';

  @override
  String get cloudAuthErrorGeneric => 'Falha no login. Tente novamente.';

  @override
  String get cloudAuthDialogTitle => 'Folio Cloud';

  @override
  String get cloudAuthSubtitleSignIn =>
      'Use seu e-mail e senha do Folio Cloud. Nada aqui altera seu cofre local.';

  @override
  String get cloudAuthSubtitleRegister =>
      'Crie credenciais para o Folio Cloud. Suas notas neste dispositivo não serão enviadas até que você ative backups ou outros recursos pagos.';

  @override
  String get cloudAuthModeSignIn => 'Entrar';

  @override
  String get cloudAuthModeRegister => 'Registrar';

  @override
  String get cloudAuthConfirmPasswordLabel => 'Confirmar senha';

  @override
  String get cloudAuthValidationRequired => 'Este campo é obrigatório.';

  @override
  String get cloudAuthValidationPasswordShort => 'Use pelo menos 6 caracteres.';

  @override
  String get cloudAuthValidationConfirmMismatch => 'As senhas não coincidem.';

  @override
  String get cloudAccountSignedOutPrompt =>
      'Entre ou registre-se para assinar o Folio Cloud e usar backups, IA na nuvem e publicação.';

  @override
  String get cloudAuthResetHint =>
      'Enviaremos um link por e-mail para você definir uma nova senha.';

  @override
  String get cloudAccountEmailVerified => 'Verificado';

  @override
  String get cloudAccountSignOutHelp =>
      'Seu cofre local permanece neste dispositivo.';

  @override
  String get cloudAccountEmailUnverifiedBanner =>
      'Verifique seu e-mail para proteger sua conta Folio Cloud.';

  @override
  String get cloudAccountResendVerification => 'Reenviar e-mail de verificação';

  @override
  String get cloudAccountReloadVerification => 'Já verifiquei';

  @override
  String get cloudAccountVerificationSent => 'E-mail de verificação enviado.';

  @override
  String get cloudAccountVerificationStillPending =>
      'O e-mail ainda não foi verificado. Abra o link na sua caixa de entrada.';

  @override
  String get cloudAccountVerificationNowVerified => 'E-mail verificado.';

  @override
  String get cloudAccountResetPasswordEmail => 'Redefinir senha por e-mail';

  @override
  String get cloudAccountCopyEmail => 'Copiar e-mail';

  @override
  String get cloudAccountEmailCopied => 'E-mail copiado.';

  @override
  String get folioWebPortalSubsectionTitle => 'Conta Web';

  @override
  String get folioWebPortalLinkCodeLabel => 'Código de pareamento';

  @override
  String get folioWebPortalLinkHelp =>
      'Gere o código no web app em Configurações → Conta Folio e digite-o aqui em até 10 minutos.';

  @override
  String get folioWebPortalLinkButton => 'Vincular';

  @override
  String get folioWebPortalLinkSuccess => 'Conta web vinculada com sucesso.';

  @override
  String get folioWebPortalNeedSignIn =>
      'Entre no Folio Cloud para vincular sua conta web.';

  @override
  String get folioWebMirrorNote =>
      'Backups, IA e publicação ainda são governados pelo Folio Cloud (Firestore). O conteúdo abaixo reflete sua conta web.';

  @override
  String get folioWebEntitlementLinked => 'Conta web vinculada';

  @override
  String get folioWebEntitlementNotLinked => 'Conta web não vinculada';

  @override
  String folioWebEntitlementWebPlan(String value) {
    return 'Plano Folio Cloud (web): $value';
  }

  @override
  String folioWebEntitlementWebStatus(String value) {
    return 'Status (web): $value';
  }

  @override
  String folioWebEntitlementWebPeriodEnd(String value) {
    return 'Fim do período (web): $value';
  }

  @override
  String folioWebEntitlementWebInk(int count) {
    return 'Ink (web): $count';
  }

  @override
  String get folioWebPortalRefreshWeb => 'Atualizar status web';

  @override
  String get folioWebPortalErrorNetwork =>
      'Não foi possível alcançar o portal. Verifique sua conexão.';

  @override
  String get folioWebPortalErrorTimeout =>
      'O portal demorou muito para responder.';

  @override
  String get folioWebPortalErrorAdminNotConfigured =>
      'Folio Firebase Admin não está configurado no servidor.';

  @override
  String get folioWebPortalErrorUnauthorized =>
      'Sessão inválida. Entre no Folio Cloud novamente.';

  @override
  String get folioWebPortalErrorGeneric =>
      'Não foi possível concluir a requisição ao portal.';

  @override
  String folioWebPortalServerMessage(String message) {
    return '$message';
  }

  @override
  String get folioCloudSubsectionPlan => 'Plano e status';

  @override
  String get folioCloudSubsectionInk => 'Saldo de Ink';

  @override
  String get folioCloudSubsectionSubscription => 'Assinatura e cobrança';

  @override
  String get folioCloudSubsectionBackupPublish => 'Backups e publicação';

  @override
  String get folioCloudSubscriptionActive => 'Assinatura ativa';

  @override
  String folioCloudSubscriptionActiveWithStatus(String status) {
    return 'Assinatura ativa ($status)';
  }

  @override
  String get folioCloudSubscriptionNoneTitle => 'Sem assinatura Folio Cloud';

  @override
  String get folioCloudSubscriptionNoneSubtitle =>
      'Ative um plano para backup criptografado, IA na nuvem e publicação na web.';

  @override
  String get folioCloudFeatureBackup => 'Backup na nuvem';

  @override
  String get folioCloudFeatureCloudAi => 'IA na nuvem';

  @override
  String get folioCloudFeaturePublishWeb => 'Publicação na web';

  @override
  String get folioCloudFeatureOn => 'Incluído';

  @override
  String get folioCloudFeatureOff => 'Não incluído';

  @override
  String get folioCloudPostPaymentHint =>
      'Se você acabou de pagar e os recursos aparecem como desativados, toque em «Atualizar do Stripe».';

  @override
  String get folioCloudBackupCleanupWarning =>
      'Backup enviado, mas backups antigos não puderam ser limpos (será tentado novamente mais tarde).';

  @override
  String get folioCloudInkMonthly => 'Mensal';

  @override
  String get folioCloudInkPurchased => 'Comprado';

  @override
  String get folioCloudInkTotal => 'Total';

  @override
  String folioCloudInkCount(int count) {
    return '$count';
  }

  @override
  String get folioCloudPlanActiveHeadline => 'Plano mensal Folio Cloud ativo';

  @override
  String get folioCloudSubscribeMonthly => 'Folio Cloud €4,99/mês';

  @override
  String get folioCloudPitchScreenTitle => 'Folio Cloud';

  @override
  String get folioCloudPitchHeadline =>
      'Seu cofre permanece local. A nuvem funciona quando você quer.';

  @override
  String get folioCloudPitchSubhead =>
      'Um plano mensal desbloqueia backups criptografados, IA na nuvem com cota mensal de ink e publicação na web — apenas para o que você escolher compartilhar.';

  @override
  String get folioCloudPitchLearnMore => 'Veja o que está incluído';

  @override
  String get folioCloudPitchCtaNeedAccount => 'Entrar ou criar conta';

  @override
  String get folioCloudPitchGuestTeaserTitle => 'Conta Folio Cloud';

  @override
  String get folioCloudPitchGuestTeaserBody =>
      'Conta opcional: veja o que o plano inclui e entre quando desejar assinar.';

  @override
  String get folioCloudPitchOpenSettingsToSignIn =>
      'Abra as Configurações e entre no Folio Cloud para assinar.';

  @override
  String get folioCloudBuyInk => 'Comprar ink';

  @override
  String get folioCloudInkSmall => 'Ink Pequeno (€1,99)';

  @override
  String get folioCloudInkMedium => 'Ink Médio (€4,99)';

  @override
  String get folioCloudInkLarge => 'Ink Grande (€9,99)';

  @override
  String get folioCloudManageSubscription => 'Gerenciar assinatura';

  @override
  String get folioCloudRefreshFromStripe => 'Atualizar';

  @override
  String get folioCloudUploadEncryptedBackup => 'Fazer backup na nuvem agora';

  @override
  String get folioCloudUploadEncryptedBackupSubtitle =>
      'O Folio cria um backup criptografado do seu cofre aberto e o envia — sem necessidade de exportação ZIP manual.';

  @override
  String get folioCloudUploadSnackOk => 'Backup do cofre salvo na nuvem.';

  @override
  String get scheduledVaultBackupCloudSyncTitle =>
      'Também enviar para o Folio Cloud';

  @override
  String get scheduledVaultBackupCloudSyncSubtitle =>
      'Após cada backup agendado, envia automaticamente o mesmo ZIP para sua conta. Para backups apenas na nuvem, deixe a pasta local vazia.';

  @override
  String get folioCloudCloudBackupsList => 'Backups na nuvem';

  @override
  String get folioCloudBackupsUsed => 'Usado';

  @override
  String get folioCloudBackupsLimit => 'Limite';

  @override
  String get folioCloudBackupsRemaining => 'Restante';

  @override
  String get folioCloudPublishTestPage => 'Publicar página de teste';

  @override
  String get folioCloudPublishedPagesList => 'Páginas publicadas';

  @override
  String get folioCloudReauthDialogTitle => 'Confirmar conta Folio Cloud';

  @override
  String get folioCloudReauthDialogBody =>
      'Digite a senha da sua conta Folio Cloud (a usada para logar na nuvem) para listar e baixar backups. Esta não é a senha do seu cofre local.';

  @override
  String get folioCloudReauthRequiresPasswordProvider =>
      'Esta sessão não usa uma senha do Folio Cloud. Saia e entre novamente com e-mail e senha se precisar baixar backups.';

  @override
  String get folioCloudAiNoInkTitle => 'Sem ink de IA na nuvem restante';

  @override
  String get folioCloudAiNoInkBody =>
      'Compre um frasco de ink em Folio Cloud, aguarde sua recarga mensal ou mude para IA local (Ollama ou LM Studio).';

  @override
  String get folioCloudAiNoInkActionCloud => 'Folio Cloud e ink';

  @override
  String get folioCloudAiNoInkActionLocal => 'Provedor de IA';

  @override
  String get folioCloudAiZeroInkBanner =>
      'O ink de IA na nuvem é 0 — abra as Configurações para comprar ou use IA local.';

  @override
  String folioCloudInkPurchaseAppliedHint(Object purchased) {
    return 'Compra aplicada: $purchased ink comprado disponível para IA na nuvem.';
  }

  @override
  String get onboardingCloudBackupCta => 'Entrar e baixar um backup';

  @override
  String get onboardingCloudBackupPickVaultSubtitle =>
      'Escolha qual cofre você deseja restaurar.';

  @override
  String get onboardingFolioCloudTitle => 'Folio Cloud';

  @override
  String get onboardingFolioCloudBody =>
      'Ative recursos de nuvem quando precisar: backups criptografados, Quill hospedado e publicação na web. Seu cofre permanece local a menos que use esses recursos.';

  @override
  String get onboardingFolioCloudFeatureBackupTitle =>
      'Backups criptografados na nuvem';

  @override
  String get onboardingFolioCloudFeatureBackupBody =>
      'Armazene e baixe backups de cofres da sua conta. No desktop, a listagem e o download são feitos via Folio Cloud.';

  @override
  String get onboardingFolioCloudFeatureAiTitle => 'IA na nuvem + ink';

  @override
  String get onboardingFolioCloudFeatureAiBody =>
      'Quill hospedado com assinatura ou compra de ink. O ink é consumido pelo uso; você também pode usar IA local.';

  @override
  String get onboardingFolioCloudFeatureWebTitle => 'Publicação na web';

  @override
  String get onboardingFolioCloudFeatureWebBody =>
      'Publique páginas selecionadas e controle o que se torna público. O resto do seu cofre não é compartilhado.';

  @override
  String get onboardingFolioCloudLaterInSettings =>
      'Verificarei depois nas Configurações';

  @override
  String get collabMenuAction => 'Colaboração ao vivo';

  @override
  String get collabSheetTitle => 'Colaboração ao vivo';

  @override
  String get collabHeaderSubtitle =>
      'Conta Folio necessária. Hospedar requer um plano com colaboração; participar requer apenas um código. Conteúdo e chat são criptografados de ponta a ponta; o servidor nunca vê seu texto.';

  @override
  String get collabNoRoomHint =>
      'Crie uma sala (se seu plano incluir hospedagem) ou cole o código do anfitrião (emojis + dígitos).';

  @override
  String get collabCreateRoom => 'Criar sala';

  @override
  String get collabJoinCodeLabel => 'Código da sala';

  @override
  String get collabJoinCodeHint => 'ex: dois emojis + 4 dígitos';

  @override
  String get collabJoinRoom => 'Participar';

  @override
  String get collabJoinFailed => 'Código inválido ou sala cheia.';

  @override
  String get collabShareCodeLabel => 'Compartilhe este código';

  @override
  String get collabCopyJoinCode => 'Copiar código';

  @override
  String get collabCopied => 'Copiado';

  @override
  String get collabHostRequiresPlan =>
      'Criar salas requer Folio Cloud com colaboração. Você pode participar de salas de outros com um código sem esse plano.';

  @override
  String get collabChatEmptyHint =>
      'Nenhuma mensagem ainda. Diga oi para sua equipe.';

  @override
  String get collabMessageHint => 'Digite uma mensagem…';

  @override
  String get collabArchivedOk => 'Chat arquivado como comentários da página.';

  @override
  String get collabArchiveToPage => 'Arquivar chat na página';

  @override
  String get collabLeaveRoom => 'Sair da sala';

  @override
  String get collabNeedsJoinCode =>
      'Digite o código da sala para descriptografar esta sessão de colaboração.';

  @override
  String get collabMissingJoinCodeHint =>
      'Esta página está vinculada a uma sala, mas nenhum código foi salvo aqui. Cole o código do anfitrião para ver o conteúdo.';

  @override
  String get collabUnlockWithCode => 'Desbloquear com código';

  @override
  String get collabHidePanel => 'Ocultar painel de colaboração';

  @override
  String get shortcutsCaptureTitle => 'Novo atalho';

  @override
  String get shortcutsCaptureHint => 'Pressione as teclas (Esc cancela).';

  @override
  String get updaterStartupDialogTitleStable => 'Atualização disponível';

  @override
  String get updaterStartupDialogTitleBeta => 'Beta disponível';

  @override
  String updaterStartupDialogBody(Object releaseVersion) {
    return 'Uma nova versão ($releaseVersion) está disponível.';
  }

  @override
  String get updaterStartupDialogQuestion => 'Deseja baixar e instalar agora?';

  @override
  String get updaterStartupDialogLater => 'Depois';

  @override
  String get updaterStartupDialogUpdateNow => 'Atualizar agora';

  @override
  String get updaterStartupDialogBetaNote => 'Versão Beta (pré-lançamento).';

  @override
  String get toggleTitleHint => 'Título do alternador';

  @override
  String get toggleBodyHint => 'Conteúdo…';

  @override
  String get taskStatusTodo => 'A fazer';

  @override
  String get taskStatusInProgress => 'Em andamento';

  @override
  String get taskStatusDone => 'Concluído';

  @override
  String get taskPriorityNone => 'Sem prioridade';

  @override
  String get taskPriorityLow => 'Baixa';

  @override
  String get taskPriorityMedium => 'Média';

  @override
  String get taskPriorityHigh => 'Alta';

  @override
  String get taskTitleHint => 'Descrição da tarefa…';

  @override
  String get taskPriorityTooltip => 'Prioridade';

  @override
  String get taskNoDueDate => 'Sem data de entrega';

  @override
  String get taskSubtaskHint => 'Subtarefa…';

  @override
  String get taskRemoveSubtask => 'Remover subtarefa';

  @override
  String get taskAddSubtask => 'Adicionar subtarefa';

  @override
  String get templateEmojiLabel => 'Emoji';

  @override
  String aiGenericErrorWithReason(Object reason) {
    return 'Erro de IA: $reason';
  }

  @override
  String get calloutTypeTooltip => 'Tipo de destaque';

  @override
  String get calloutTypeInfo => 'Info';

  @override
  String get calloutTypeSuccess => 'Sucesso';

  @override
  String get calloutTypeWarning => 'Aviso';

  @override
  String get calloutTypeError => 'Erro';

  @override
  String get calloutTypeNote => 'Nota';
}
