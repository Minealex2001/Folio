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
      'Escolha o brilho do tema, a origem da cor de destaque (Windows, Folio ou personalizada), o zoom e o idioma.';

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
  String get backlinksTitle => 'Referências de entrada';

  @override
  String get backlinksEmpty => 'Nenhuma página aponta para aqui ainda.';

  @override
  String get showBacklinks => 'Mostrar referências';

  @override
  String get hideBacklinks => 'Ocultar referências';

  @override
  String get commentsTitle => 'Comentários';

  @override
  String get commentsEmpty => 'Sem comentários ainda. Seja o primeiro!';

  @override
  String get commentsAddHint => 'Adicione um comentário…';

  @override
  String get commentsResolve => 'Resolver';

  @override
  String get commentsReopen => 'Reabrir';

  @override
  String get commentsDelete => 'Eliminar';

  @override
  String get commentsResolved => 'Resolvido';

  @override
  String get showComments => 'Mostrar comentários';

  @override
  String get hideComments => 'Ocultar comentários';

  @override
  String get propTitle => 'Propriedades';

  @override
  String get propAdd => 'Adicionar propriedade';

  @override
  String get propRemove => 'Remover propriedade';

  @override
  String get propRename => 'Renomear';

  @override
  String get propTypeText => 'Texto';

  @override
  String get propTypeNumber => 'Número';

  @override
  String get propTypeDate => 'Data';

  @override
  String get propTypeSelect => 'Seleção';

  @override
  String get propTypeStatus => 'Estado';

  @override
  String get propTypeUrl => 'URL';

  @override
  String get propTypeCheckbox => 'Caixa de seleção';

  @override
  String get propNotSet => 'Vazio';

  @override
  String get propAddOption => 'Adicionar opção';

  @override
  String get propStatusNotStarted => 'Não iniciado';

  @override
  String get propStatusInProgress => 'Em progresso';

  @override
  String get propStatusDone => 'Concluído';

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
  String get meetingNoteCloudRequiresAiEnabled =>
      'Ative a IA em Definições para usar a transcrição na nuvem (Quill Cloud).';

  @override
  String meetingNoteHardwareSummary(int cpus, Object ramLabel) {
    return '$cpus núcleos · $ramLabel';
  }

  @override
  String get meetingNoteHardwareRamUnknown => 'RAM desconhecida';

  @override
  String meetingNoteHardwareRecommended(Object modelLabel) {
    return 'Modelo recomendado para este dispositivo: $modelLabel';
  }

  @override
  String get meetingNoteLocalTranscriptionNotViable =>
      'Este dispositivo não cumpre o mínimo para transcrição local. Só o áudio será guardado, a menos que ative «Forçar transcrição local» nas Definições ou use o Quill Cloud com IA ativada.';

  @override
  String get meetingNoteGenerateTranscription => 'Gerar transcrição';

  @override
  String get meetingNoteGenerateTranscriptionSubtitle =>
      'Desative para guardar apenas o áudio nesta nota.';

  @override
  String get meetingNoteSettingsAutoWhisperModel =>
      'Escolher o modelo automaticamente conforme o hardware';

  @override
  String get meetingNoteSettingsForceLocalTranscription =>
      'Forçar transcrição local (pode ser lenta ou instável)';

  @override
  String get meetingNoteSettingsHardwareIntro =>
      'Desempenho detetado para transcrição local.';

  @override
  String get meetingNoteRecordingAudioOnlyBadge => 'Só áudio';

  @override
  String get meetingNotePerNoteTranscriptionOffHint =>
      'A transcrição está desativada para esta nota.';

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
  String get meetingNoteModelMedium => 'Avançado';

  @override
  String get meetingNoteModelTurbo => 'Máxima qualidade';

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
  String get formatToolbarScrollPrevious => 'Ferramentas anteriores';

  @override
  String get formatToolbarScrollNext => 'Mais ferramentas';

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
  String get exportPage => 'Exportar…';

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
      'Instale o LM Studio, inicie seu servidor local e verifique se ele responde em http://127.0.0.1:1234.';

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
  String get tasksCaptureSettingsSection => 'Tarefas (captura rápida)';

  @override
  String get taskInboxPageTitle => 'Caixa de entrada de tarefas';

  @override
  String get taskInboxPageSubtitle =>
      'Página onde as tarefas da captura rápida são guardadas.';

  @override
  String get taskInboxNone => 'Não definida (criada ao guardar a primeira)';

  @override
  String get taskInboxDefaultTitle => 'Caixa de entrada de tarefas';

  @override
  String get taskAliasManageTitle => 'Aliases de destino';

  @override
  String get taskAliasManageSubtitle =>
      'Use `#etiqueta` ou `@etiqueta` no fim da captura. Defina a chave sem símbolo (ex. trabalho) e a página destino.';

  @override
  String get taskAliasAddButton => 'Adicionar alias';

  @override
  String get taskAliasTagLabel => 'Etiqueta';

  @override
  String get taskAliasTargetLabel => 'Página';

  @override
  String get taskAliasDeleteTooltip => 'Remover';

  @override
  String get taskQuickAddTitle => 'Captura rápida de tarefa';

  @override
  String get taskQuickAddHint =>
      'Ex.: Comprar leite amanhã alta #trabalho. Também: due:2026-04-20, p1, em progresso.';

  @override
  String get taskQuickAddConfirm => 'Adicionar';

  @override
  String get taskQuickAddSuccess => 'Tarefa adicionada.';

  @override
  String get taskQuickAddAliasTargetMissing =>
      'A página desse alias já não existe.';

  @override
  String get taskHubTitle => 'Todas as tarefas';

  @override
  String get taskHubClose => 'Fechar vista';

  @override
  String get taskHubDashboardHelpTitle => 'Ideias tipo dashboard';

  @override
  String get taskHubDashboardHelpBody =>
      'Crie uma página com o bloco de colunas ligando páginas de listas por contexto, ou use um bloco base de dados com datas e estados para um quadro.';

  @override
  String get taskHubEmpty => 'Não há tarefas neste caderno.';

  @override
  String get taskHubFilterAll => 'Todas';

  @override
  String get taskHubFilterActive => 'Pendentes';

  @override
  String get taskHubFilterDone => 'Concluídas';

  @override
  String get taskHubFilterDueToday => 'Vencem hoje';

  @override
  String get taskHubFilterDueWeek => 'Esta semana';

  @override
  String get taskHubFilterOverdue => 'Atrasadas';

  @override
  String get taskHubOpen => 'Abrir';

  @override
  String get taskHubMarkDone => 'Feito';

  @override
  String get taskHubIncludeTodos => 'Incluir checklists';

  @override
  String get sidebarQuickAddTask => 'Tarefa rápida';

  @override
  String get sidebarTaskHub => 'Todas as tarefas';

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
      'Enquanto o cofre estiver desbloqueado, o Folio faz backup automático no intervalo escolhido. Ative o backup em pasta, na nuvem, ou ambos.';

  @override
  String get scheduledVaultBackupFolderTitle => 'Backup em pasta';

  @override
  String get scheduledVaultBackupFolderSubtitle =>
      'Salva um backup cifrado em ZIP na pasta configurada a cada intervalo.';

  @override
  String get scheduledVaultBackupChooseFolder => 'Pasta de backup';

  @override
  String get scheduledVaultBackupClearFolderTooltip => 'Limpar pasta';

  @override
  String get scheduledVaultBackupCloudOnlyTitle =>
      'Backups agendados só na nuvem';

  @override
  String get scheduledVaultBackupCloudOnlySubtitle =>
      'Não guarda ZIPs no disco. Envia backups apenas para a nuvem.';

  @override
  String get scheduledVaultBackupIntervalLabel => 'Intervalo entre backups';

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
  String vaultBackupDiskSizeApprox(String size) {
    return 'Tamanho aproximado em disco: $size';
  }

  @override
  String get vaultBackupDiskSizeLoading => 'A calcular o tamanho em disco…';

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
  String get folioCloudMicrosoftStoreBillingTitle =>
      'Microsoft Store (Windows)';

  @override
  String get folioCloudMicrosoftStoreBillingSubtitle =>
      'A mesma assinatura e tinta que com o Stripe; a Loja cobra e o servidor valida a compra. Configure os ids de produto com --dart-define e Azure AD nas Cloud Functions.';

  @override
  String get folioCloudMicrosoftStoreSubscribeButton => 'Assinatura na Loja';

  @override
  String get folioCloudMicrosoftStoreSyncButton => 'Sincronizar com a Loja';

  @override
  String get folioCloudMicrosoftStoreInkTitle => 'Tinta — Microsoft Store';

  @override
  String get folioCloudMicrosoftStoreInkPackSmall => 'Tinteiro pequeno (Loja)';

  @override
  String get folioCloudMicrosoftStoreInkPackMedium => 'Tinteiro médio (Loja)';

  @override
  String get folioCloudMicrosoftStoreInkPackLarge => 'Tinteiro grande (Loja)';

  @override
  String get folioCloudMicrosoftStoreSyncedSnack =>
      'Sincronizado com a Microsoft Store.';

  @override
  String get folioCloudMicrosoftStoreAppliedSnack =>
      'Compra aplicada. Se algo faltar, toque em sincronizar.';

  @override
  String get folioCloudPurchaseChannelTitle => 'Onde quer pagar?';

  @override
  String get folioCloudPurchaseChannelBody =>
      'Use a Microsoft Store integrada no Windows ou pague com cartão no navegador (Stripe). O plano e a tinta são os mesmos.';

  @override
  String get folioCloudPurchaseChannelMicrosoftStore => 'Microsoft Store';

  @override
  String get folioCloudPurchaseChannelStripe => 'No navegador (Stripe)';

  @override
  String get folioCloudPurchaseChannelCancel => 'Cancelar';

  @override
  String get folioCloudPurchaseChannelStoreNotConfigured =>
      'A opção da Loja não está configurada nesta compilação (faltam ids de produto).';

  @override
  String get folioCloudPurchaseChannelStoreNotConfiguredHint =>
      'Compile com --dart-define=MS_STORE_… ou use o checkout no navegador.';

  @override
  String get folioCloudMicrosoftStoreSyncHint =>
      'No Windows, «Atualizar» também sincroniza a Microsoft Store (mesmo botão que o Stripe).';

  @override
  String get folioCloudUploadEncryptedBackup => 'Fazer backup na nuvem agora';

  @override
  String get folioCloudUploadEncryptedBackupSubtitle =>
      'O Folio cria um backup criptografado do seu cofre aberto e o envia — sem necessidade de exportação ZIP manual.';

  @override
  String get folioCloudUploadSnackOk => 'Backup do cofre salvo na nuvem.';

  @override
  String get scheduledVaultBackupCloudSyncTitle => 'Backup no Folio Cloud';

  @override
  String get scheduledVaultBackupCloudSyncSubtitle =>
      'Em cada intervalo agendado, envia automaticamente um backup cifrado para sua conta no Folio Cloud.';

  @override
  String get folioCloudCloudBackupsList => 'Backups na nuvem';

  @override
  String get folioCloudBackupsUsed => 'Usado';

  @override
  String get folioCloudBackupsLimit => 'Limite';

  @override
  String get folioCloudBackupsRemaining => 'Restante';

  @override
  String get folioCloudBackupStorageStatUsed => 'Usado (armazenamento)';

  @override
  String get folioCloudBackupStorageStatQuota => 'Quota';

  @override
  String get folioCloudBackupStorageStatRemaining => 'Restante';

  @override
  String get folioCloudBackupStorageExpansionTitle =>
      'Ampliar armazenamento de cópias';

  @override
  String get folioCloudBackupStorageLibrarySmallTitle => 'Biblioteca pequena';

  @override
  String get folioCloudBackupStorageLibrarySmallDetail => '+20 GB · 1,99 €/mês';

  @override
  String get folioCloudBackupStorageLibraryMediumTitle => 'Biblioteca média';

  @override
  String get folioCloudBackupStorageLibraryMediumDetail =>
      '+75 GB · 4,99 €/mês';

  @override
  String get folioCloudBackupStorageLibraryLargeTitle => 'Biblioteca grande';

  @override
  String get folioCloudBackupStorageLibraryLargeDetail =>
      '+250 GB · 9,99 €/mês';

  @override
  String get folioCloudSubscribeBackupStorageAddon => 'Subscrever';

  @override
  String get folioCloudBackupTypeIncremental =>
      'Cópia incremental (mais recente)';

  @override
  String get folioCloudBackupPackNoDownload =>
      'Cópias incrementais são restauradas com «Importar e substituir». Não há download de ficheiro separado.';

  @override
  String get folioCloudBackupQuotaExceeded =>
      'Armazenamento de cópias na nuvem insuficiente. Compre uma ampliação ou apague cópias completas antigas em backups/.';

  @override
  String get onboardingCloudBackupNeedLegacyArchive =>
      'Este caderno só tem uma cópia incremental na nuvem. Para configurar um dispositivo novo, descarregue um arquivo completo (.tar.gz) de outro dispositivo com Folio ou crie-o em Definições → exportar.';

  @override
  String get onboardingCloudBackupNeedRestoreWrap =>
      'Este backup incremental ainda não tem chave de recuperação na nuvem. No dispositivo em que o criou, abra Folio → Definições → envie o backup para a nuvem (digite a senha do cofre quando solicitado). Também pode usar um arquivo completo (.zip) se tiver um.';

  @override
  String get onboardingCloudBackupIncrementalRestoreBody =>
      'Backup incremental na nuvem selecionado. Digite a senha do cofre (a mesma que usa para desbloquear). Se o cofre não era criptografado, use a senha de recuperação definida ao enviar o backup.';

  @override
  String get settingsCloudBackupWrapPasswordTitle =>
      'Recuperação em outros dispositivos';

  @override
  String get settingsCloudBackupWrapPasswordBody =>
      'Digite a senha deste cofre. Ela será armazenada criptografada na sua conta para restaurar o backup incremental ao instalar o Folio em um dispositivo novo.';

  @override
  String get settingsCloudBackupWrapPasswordRequired =>
      'A senha do cofre é obrigatória.';

  @override
  String get settingsCloudBackupWrapPasswordBodyPlain =>
      'Opcional: defina uma senha de recuperação para restaurar este backup incremental em outro dispositivo. Deixe em branco se usar apenas este dispositivo.';

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
  String get updaterOpenApkDownloadQuestion =>
      'Abrir a transferência do APK agora?';

  @override
  String get updaterManualCheckUnsupportedPlatform =>
      'O atualizador integrado só está disponível no Windows e no Android.';

  @override
  String get updaterManualCheckAlreadyLatest => 'Já tem a versão mais recente.';

  @override
  String updaterDialogLineCurrentVersion(Object currentVersion) {
    return 'Versão atual: $currentVersion';
  }

  @override
  String updaterDialogLineNewVersion(Object releaseVersion) {
    return 'Nova versão: $releaseVersion';
  }

  @override
  String get updaterApkUrlInvalidSnack =>
      'Não foi encontrado um URL válido do APK na release.';

  @override
  String get updaterApkOpenFailedSnack =>
      'Não foi possível abrir a transferência do APK.';

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
  String get title => 'Título';

  @override
  String get description => 'Descrição';

  @override
  String get priority => 'Prioridade';

  @override
  String get status => 'Estado';

  @override
  String get none => 'Nenhuma';

  @override
  String get low => 'Baixa';

  @override
  String get medium => 'Média';

  @override
  String get high => 'Alta';

  @override
  String get startDate => 'Data de início';

  @override
  String get dueDate => 'Data de vencimento';

  @override
  String get timeSpentMinutes => 'Tempo gasto (minutos)';

  @override
  String get taskBlocked => 'Bloqueada';

  @override
  String get taskBlockedReason => 'Motivo do bloqueio';

  @override
  String get subtasks => 'Subtarefas';

  @override
  String get add => 'Adicionar';

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

  @override
  String get blockEditorEnterHintNewBlock =>
      'Enter: novo bloco (em código: Enter = linha)';

  @override
  String get blockEditorEnterHintNewLine => 'Enter: nova linha';

  @override
  String blockEditorShortcutsHintMobile(String enterHint) {
    return '$enterHint · / para blocos · toque no bloco para mais ações';
  }

  @override
  String blockEditorShortcutsHintDesktop(String enterHint) {
    return '$enterHint · Shift+Enter: linha · / tipos · # título (mesma linha) · - · * · [] · ``` espaço · tabela/imagem em / · formato: barra ao focar ou ** _ <u> ` ~~';
  }

  @override
  String blockEditorSelectedBlocksBanner(int count) {
    return '$count blocos selecionados · Shift: intervalo · Ctrl/Cmd: alternar';
  }

  @override
  String get blockEditorDuplicate => 'Duplicar';

  @override
  String get blockEditorClearSelectionTooltip => 'Limpar seleção';

  @override
  String get blockEditorMenuRewriteWithAi => 'Reescrever com IA…';

  @override
  String get blockEditorMenuMoveUp => 'Mover para cima';

  @override
  String get blockEditorMenuMoveDown => 'Mover para baixo';

  @override
  String get blockEditorMenuDuplicateBlock => 'Duplicar bloco';

  @override
  String get blockEditorMenuAppearance => 'Aparência…';

  @override
  String get blockEditorMenuCalloutIcon => 'Ícone do destaque…';

  @override
  String blockEditorCalloutMenuType(String typeName) {
    return 'Tipo: $typeName';
  }

  @override
  String get blockEditorCopyLink => 'Copiar ligação';

  @override
  String get blockEditorMenuCreateSubpage => 'Criar subpágina';

  @override
  String get blockEditorMenuLinkPage => 'Ligar página…';

  @override
  String get blockEditorMenuOpenSubpage => 'Abrir subpágina';

  @override
  String get blockEditorMenuPickImage => 'Escolher imagem…';

  @override
  String get blockEditorMenuRemoveImage => 'Remover imagem';

  @override
  String get blockEditorMenuCodeLanguage => 'Linguagem do código…';

  @override
  String get blockEditorMenuEditDiagram => 'Editar diagrama…';

  @override
  String get blockEditorMenuBackToPreview => 'Voltar à pré-visualização';

  @override
  String get blockEditorMenuChangeFile => 'Alterar ficheiro…';

  @override
  String get blockEditorMenuRemoveFile => 'Remover ficheiro';

  @override
  String get blockEditorMenuChangeVideo => 'Alterar vídeo…';

  @override
  String get blockEditorMenuRemoveVideo => 'Remover vídeo';

  @override
  String get blockEditorMenuChangeAudio => 'Alterar áudio…';

  @override
  String get blockEditorMenuRemoveAudio => 'Remover áudio';

  @override
  String get blockEditorMenuEditLabel => 'Editar etiqueta…';

  @override
  String get blockEditorMenuAddRow => 'Adicionar linha';

  @override
  String get blockEditorMenuRemoveLastRow => 'Remover última linha';

  @override
  String get blockEditorMenuAddColumn => 'Adicionar coluna';

  @override
  String get blockEditorMenuRemoveLastColumn => 'Remover última coluna';

  @override
  String get blockEditorMenuAddProperty => 'Adicionar propriedade';

  @override
  String get blockEditorMenuChangeBlockType => 'Alterar tipo de bloco…';

  @override
  String get blockEditorMenuDeleteBlock => 'Eliminar bloco';

  @override
  String get blockEditorAppearanceTitle => 'Aparência do bloco';

  @override
  String get blockEditorAppearanceSubtitle =>
      'Personalize o tamanho, a cor do texto e o fundo deste bloco.';

  @override
  String get blockEditorAppearanceSize => 'Tamanho';

  @override
  String get blockEditorAppearanceTextColor => 'Cor do texto';

  @override
  String get blockEditorAppearanceBackground => 'Fundo';

  @override
  String get blockEditorAppearancePreviewEmpty =>
      'É assim que o bloco vai parecer.';

  @override
  String get blockEditorReset => 'Repor';

  @override
  String get blockEditorCodeLanguageTitle => 'Linguagem do código';

  @override
  String get blockEditorCodeLanguageSubtitle =>
      'Realce de sintaxe conforme a linguagem escolhida.';

  @override
  String get blockEditorTemplateButtonTitle => 'Etiqueta do botão do modelo';

  @override
  String get blockEditorTemplateButtonFieldLabel => 'Texto do botão';

  @override
  String get blockEditorTemplateButtonDefaultLabel => 'Modelo';

  @override
  String get blockEditorTextColorDefault => 'Tema';

  @override
  String get blockEditorTextColorSubtle => 'Suave';

  @override
  String get blockEditorTextColorPrimary => 'Primária';

  @override
  String get blockEditorTextColorSecondary => 'Secundária';

  @override
  String get blockEditorTextColorTertiary => 'Acento';

  @override
  String get blockEditorTextColorError => 'Erro';

  @override
  String get blockEditorBackgroundNone => 'Sem fundo';

  @override
  String get blockEditorBackgroundSurface => 'Superfície';

  @override
  String get blockEditorBackgroundPrimary => 'Primário';

  @override
  String get blockEditorBackgroundSecondary => 'Secundário';

  @override
  String get blockEditorBackgroundTertiary => 'Acento';

  @override
  String get blockEditorBackgroundError => 'Erro';

  @override
  String get blockEditorCmdDuplicatePrev => 'Duplicar bloco anterior';

  @override
  String get blockEditorCmdDuplicatePrevHint =>
      'Clona o bloco imediatamente acima';

  @override
  String get blockEditorCmdInsertDate => 'Inserir data';

  @override
  String get blockEditorCmdInsertDateHint => 'Escreve a data de hoje';

  @override
  String get blockEditorCmdMentionPage => 'Mencionar página';

  @override
  String get blockEditorCmdMentionPageHint =>
      'Insere ligação interna a uma página';

  @override
  String get blockEditorCmdTurnInto => 'Converter bloco';

  @override
  String get blockEditorCmdTurnIntoHint => 'Escolher tipo de bloco no seletor';

  @override
  String get blockEditorMarkTaskComplete => 'Marcar tarefa como concluída';

  @override
  String get blockEditorCalloutIconPickerTitle => 'Ícone do destaque';

  @override
  String get blockEditorCalloutIconPickerHelper =>
      'Escolha um ícone para mudar o tom visual do bloco de destaque.';

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
      'Ainda não importou ícones nas Definições.';

  @override
  String get blockTypeSectionBasicText => 'Texto básico';

  @override
  String get blockTypeSectionLists => 'Listas';

  @override
  String get blockTypeSectionMedia => 'Multimédia e dados';

  @override
  String get blockTypeSectionAdvanced => 'Avançado e layout';

  @override
  String get blockTypeSectionEmbeds => 'Integrações';

  @override
  String get blockTypeParagraphLabel => 'Texto';

  @override
  String get blockTypeParagraphHint => 'Parágrafo';

  @override
  String get blockTypeChildPageLabel => 'Página';

  @override
  String get blockTypeChildPageHint => 'Subpágina ligada';

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
  String get blockTypeQuoteLabel => 'Citação';

  @override
  String get blockTypeQuoteHint => 'Texto citado';

  @override
  String get blockTypeDividerLabel => 'Divisor';

  @override
  String get blockTypeDividerHint => 'Separador · ---';

  @override
  String get blockTypeCalloutLabel => 'Destaque';

  @override
  String get blockTypeCalloutHint => 'Aviso com ícone';

  @override
  String get blockTypeBulletLabel => 'Lista com marcas';

  @override
  String get blockTypeBulletHint => 'Lista com pontos';

  @override
  String get blockTypeNumberedLabel => 'Lista numerada';

  @override
  String get blockTypeNumberedHint => 'Lista 1, 2, 3';

  @override
  String get blockTypeTodoLabel => 'Lista de tarefas';

  @override
  String get blockTypeTodoHint => 'Checklist';

  @override
  String get blockTypeTaskLabel => 'Tarefa avançada';

  @override
  String get blockTypeTaskHint => 'Estado / prioridade / data';

  @override
  String get blockTypeToggleLabel => 'Alternável';

  @override
  String get blockTypeToggleHint => 'Mostrar ou ocultar conteúdo';

  @override
  String get blockTypeImageLabel => 'Imagem';

  @override
  String get blockTypeImageHint => 'Imagem local ou externa';

  @override
  String get blockTypeBookmarkLabel => 'Marcador com pré-visualização';

  @override
  String get blockTypeBookmarkHint => 'Cartão com ligação';

  @override
  String get blockTypeVideoLabel => 'Vídeo';

  @override
  String get blockTypeVideoHint => 'Ficheiro ou URL';

  @override
  String get blockTypeAudioLabel => 'Áudio';

  @override
  String get blockTypeAudioHint => 'Leitor de áudio';

  @override
  String get blockTypeMeetingNoteLabel => 'Nota de reunião';

  @override
  String get blockTypeMeetingNoteHint => 'Gravar e transcrever uma reunião';

  @override
  String get blockTypeCodeLabel => 'Código (Java, Python…)';

  @override
  String get blockTypeCodeHint => 'Bloco com sintaxe';

  @override
  String get blockTypeFileLabel => 'Ficheiro / PDF';

  @override
  String get blockTypeFileHint => 'Anexo ou PDF';

  @override
  String get blockTypeTableLabel => 'Tabela';

  @override
  String get blockTypeTableHint => 'Linhas e colunas';

  @override
  String get blockTypeDatabaseLabel => 'Base de dados';

  @override
  String get blockTypeDatabaseHint => 'Vista de lista/tabela/quadro';

  @override
  String get blockTypeKanbanLabel => 'Kanban';

  @override
  String get blockTypeKanbanHint =>
      'Vista de quadro para as tarefas desta página';

  @override
  String get kanbanBlockRowTitle => 'Quadro Kanban';

  @override
  String get kanbanBlockRowSubtitle =>
      'Ao abrir a página vê o quadro. Na barra do quadro use «Abrir editor de blocos» para editar ou remover este bloco.';

  @override
  String get kanbanRowTodosExcluded => 'Sem checklists';

  @override
  String get kanbanToolbarOpenEditor => 'Abrir editor de blocos';

  @override
  String get kanbanToolbarAddTask => 'Adicionar tarefa';

  @override
  String get kanbanClassicModeBanner =>
      'Editor de blocos: pode mover ou eliminar o bloco Kanban.';

  @override
  String get kanbanBackToBoard => 'Voltar ao quadro';

  @override
  String get kanbanMultipleBlocksSnack =>
      'Esta página tem mais de um bloco Kanban; usa-se o primeiro.';

  @override
  String get kanbanEmptyColumn => 'Sem tarefas';

  @override
  String get blockTypeDriveLabel => 'Arquivo Drive';

  @override
  String get blockTypeDriveHint => 'Gestor de ficheiros integrado';

  @override
  String get driveBlockRowTitle => 'Arquivo Drive';

  @override
  String driveBlockRowSubtitle(int files, int folders) {
    return '$files ficheiros · $folders pastas';
  }

  @override
  String get driveNewFolder => 'Nova pasta';

  @override
  String get driveUploadFile => 'Enviar ficheiro';

  @override
  String get driveImportFromVault => 'Importar do vault';

  @override
  String get driveViewGrid => 'Grelha';

  @override
  String get driveViewList => 'Lista';

  @override
  String get driveEditBlock => 'Editar bloco';

  @override
  String get driveFolderEmpty => 'Esta pasta está vazia';

  @override
  String get driveDeleteConfirm => 'Eliminar este ficheiro?';

  @override
  String get driveOpenFile => 'Abrir ficheiro';

  @override
  String get driveMoveTo => 'Mover para…';

  @override
  String get driveClassicModeBanner =>
      'Editor de blocos: pode mover ou eliminar o bloco Drive.';

  @override
  String get driveBackToDrive => 'Voltar ao drive';

  @override
  String get driveMultipleBlocksSnack =>
      'Esta página tem mais de um bloco Drive; é usado o primeiro.';

  @override
  String get driveDeleteOriginalsTitle => 'Eliminar originais ao importar';

  @override
  String get driveDeleteOriginalsSubtitle =>
      'Ao enviar ficheiros para o drive, os originais são eliminados automaticamente do disco.';

  @override
  String get blockTypeEquationLabel => 'Equação (LaTeX)';

  @override
  String get blockTypeEquationHint => 'Fórmulas matemáticas';

  @override
  String get blockTypeMermaidLabel => 'Diagrama (Mermaid)';

  @override
  String get blockTypeMermaidHint => 'Fluxograma ou diagrama';

  @override
  String get blockTypeTocLabel => 'Índice';

  @override
  String get blockTypeTocHint => 'Índice automático';

  @override
  String get blockTypeBreadcrumbLabel => 'Trilho';

  @override
  String get blockTypeBreadcrumbHint => 'Caminho de navegação';

  @override
  String get blockTypeTemplateButtonLabel => 'Botão de modelo';

  @override
  String get blockTypeTemplateButtonHint => 'Inserir bloco predefinido';

  @override
  String get blockTypeColumnListLabel => 'Colunas';

  @override
  String get blockTypeColumnListHint => 'Layout em colunas';

  @override
  String get blockTypeEmbedLabel => 'Incorporação web';

  @override
  String get blockTypeEmbedHint => 'YouTube, Figma, Docs…';

  @override
  String get integrationDialogTitleUpdatePermission =>
      'Atualizar permissão de integração';

  @override
  String get integrationDialogTitleAllowConnect =>
      'Permitir que este app se conecte';

  @override
  String integrationDialogBodyUpdate(
    Object previousVersion,
    Object integrationVersion,
  ) {
    return 'Este app já estava aprovado com a integração $previousVersion e agora solicita acesso com a versão $integrationVersion.';
  }

  @override
  String integrationDialogBodyNew(
    Object appName,
    Object appVersion,
    Object integrationVersion,
  ) {
    return '«$appName» quer usar a ponte local do Folio com o app versão $appVersion e a integração $integrationVersion.';
  }

  @override
  String get integrationChipLocalhostOnly => 'Somente localhost';

  @override
  String get integrationChipRevocableApproval => 'Aprovação revogável';

  @override
  String get integrationChipNoSharedSecret => 'Sem segredo compartilhado';

  @override
  String get integrationChipScopedByAppId => 'Escopo por appId';

  @override
  String get integrationMetaPreviouslyApprovedVersion =>
      'Versão aprovada anteriormente';

  @override
  String get integrationSectionWhatAppCanDo => 'O que este app poderá fazer';

  @override
  String get integrationCapEphemeralSessionsTitle =>
      'Abrir sessões locais efêmeras';

  @override
  String get integrationCapEphemeralSessionsBody =>
      'Poderá iniciar uma sessão temporária para falar com a ponte local do Folio neste dispositivo.';

  @override
  String get integrationCapImportPagesTitle =>
      'Importar e atualizar suas próprias páginas';

  @override
  String get integrationCapImportPagesBody =>
      'Poderá criar páginas, listá-las e atualizar apenas as páginas que o mesmo app importou antes.';

  @override
  String get integrationCapCustomEmojisTitle =>
      'Gerenciar seus emojis personalizados';

  @override
  String get integrationCapCustomEmojisBody =>
      'Poderá listar, criar, substituir e excluir apenas seu próprio catálogo de emojis ou ícones importados.';

  @override
  String get integrationCapUnlockedVaultTitle =>
      'Trabalhar somente com o caderno desbloqueado';

  @override
  String get integrationCapUnlockedVaultBody =>
      'As solicitações só funcionam quando o Folio está aberto, o caderno está disponível e a sessão atual ainda está ativa.';

  @override
  String get integrationSectionWhatStaysBlocked => 'O que continuará bloqueado';

  @override
  String get integrationBlockNoSeeAllTitle =>
      'Não pode ver todo o seu conteúdo';

  @override
  String get integrationBlockNoSeeAllBody =>
      'Não obtém acesso geral ao caderno. Só pode listar o que importou pelo próprio appId.';

  @override
  String get integrationBlockNoBypassTitle =>
      'Não pode ignorar bloqueio nem criptografia';

  @override
  String get integrationBlockNoBypassBody =>
      'Se o caderno estiver bloqueado ou não houver sessão ativa, o Folio rejeitará a operação.';

  @override
  String get integrationBlockNoOtherAppsTitle =>
      'Não pode alterar dados de outros apps';

  @override
  String get integrationBlockNoOtherAppsBody =>
      'Também não pode gerenciar páginas importadas ou emojis registrados por outros apps aprovados.';

  @override
  String get integrationBlockNoRemoteTitle =>
      'Não pode conectar de fora do seu computador';

  @override
  String get integrationBlockNoRemoteBody =>
      'A ponte continua limitada ao localhost e esta aprovação pode ser revogada depois em Ajustes.';

  @override
  String integrationSnackMarkdownImportDone(Object pageTitle) {
    return 'Importação concluída: $pageTitle.';
  }

  @override
  String integrationSnackJsonImportDone(Object pageTitle) {
    return 'Importação JSON concluída: $pageTitle.';
  }

  @override
  String integrationSnackPageUpdateDone(Object pageTitle) {
    return 'Atualização de integração concluída: $pageTitle.';
  }

  @override
  String get markdownImportModeDialogTitle => 'Importar Markdown';

  @override
  String get markdownImportModeDialogBody =>
      'Escolha como aplicar o arquivo Markdown.';

  @override
  String get markdownImportModeNewPage => 'Página nova';

  @override
  String get markdownImportModeAppend => 'Anexar à atual';

  @override
  String get markdownImportModeReplace => 'Substituir a atual';

  @override
  String get markdownImportCouldNotReadPath =>
      'Não foi possível ler o caminho do arquivo.';

  @override
  String markdownImportedBlocks(Object pageTitle, int blockCount) {
    return 'Markdown importado: $pageTitle ($blockCount blocos).';
  }

  @override
  String markdownImportFailedWithError(Object error) {
    return 'Não foi possível importar o Markdown: $error';
  }

  @override
  String get importPage => 'Importar…';

  @override
  String get exportMarkdownFileDialogTitle => 'Exportar página para Markdown';

  @override
  String get markdownExportSuccess => 'Página exportada para Markdown.';

  @override
  String markdownExportFailedWithError(Object error) {
    return 'Não foi possível exportar a página: $error';
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
  String get exportHtmlFileDialogTitle => 'Exportar página para HTML';

  @override
  String get htmlExportSuccess => 'Página exportada para HTML.';

  @override
  String htmlExportFailedWithError(Object error) {
    return 'Não foi possível exportar a página: $error';
  }

  @override
  String get exportTxtFileDialogTitle => 'Exportar página para texto';

  @override
  String get txtExportSuccess => 'Página exportada para texto.';

  @override
  String txtExportFailedWithError(Object error) {
    return 'Não foi possível exportar a página: $error';
  }

  @override
  String get exportJsonFileDialogTitle => 'Exportar página para JSON';

  @override
  String get jsonExportSuccess => 'Página exportada para JSON.';

  @override
  String jsonExportFailedWithError(Object error) {
    return 'Não foi possível exportar a página: $error';
  }

  @override
  String get exportPdfFileDialogTitle => 'Exportar página para PDF';

  @override
  String get pdfExportSuccess => 'Página exportada para PDF.';

  @override
  String pdfExportFailedWithError(Object error) {
    return 'Não foi possível exportar a página: $error';
  }

  @override
  String get firebaseUnavailablePublish => 'Firebase não está disponível.';

  @override
  String get signInCloudToPublishWeb =>
      'Inicie sessão na conta na nuvem (Ajustes) para publicar.';

  @override
  String get planMissingWebPublish =>
      'Seu plano não inclui publicação web ou a assinatura não está ativa.';

  @override
  String get publishWebDialogTitle => 'Publicar na web';

  @override
  String get publishWebSlugLabel => 'URL (slug)';

  @override
  String get publishWebSlugHint => 'minha-nota';

  @override
  String get publishWebSlugHelper =>
      'Letras, números e hífens. Aparecerá na URL pública.';

  @override
  String get publishWebAction => 'Publicar';

  @override
  String get publishWebEmptySlug => 'Slug vazio.';

  @override
  String publishWebSuccessWithUrl(Object url) {
    return 'Publicado: $url';
  }

  @override
  String publishWebFailedWithError(Object error) {
    return 'Não foi possível publicar: $error';
  }

  @override
  String get publishWebMenuLabel => 'Publicar na web';

  @override
  String get mobileFabDone => 'Pronto';

  @override
  String get mobileFabEdit => 'Editar';

  @override
  String get mobileFabAddBlock => 'Bloco';

  @override
  String get mermaidPreviewDialogTitle => 'Diagrama';

  @override
  String get mermaidDiagramSemanticsLabel =>
      'Diagrama Mermaid, toque para ampliar';

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
  String get databaseNewPropertyDialogTitle => 'Nova propriedade';

  @override
  String databaseConfigurePropertyTitle(Object name) {
    return 'Configurar: $name';
  }

  @override
  String get databaseLocalCurrentBadge => 'BD local atual';

  @override
  String databaseRelateRowsTitle(Object name) {
    return 'Relacionar linhas ($name)';
  }

  @override
  String get databaseBoardNeedsGroupProperty =>
      'Configure uma propriedade de grupo para o quadro.';

  @override
  String get databaseGroupPropertyMissing =>
      'A propriedade de grupo não existe mais.';

  @override
  String get databaseCalendarNeedsDateProperty =>
      'Configure uma propriedade de data para o calendário.';

  @override
  String get databaseNoDatedEvents => 'Sem eventos com data.';

  @override
  String get databaseConfigurePropertyTooltip => 'Configurar propriedade';

  @override
  String get databaseFormulaHintExample =>
      'if(contains(Nome,\"x\"), add(1,2), 0)';

  @override
  String get createAction => 'Criar';

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
  String get blockActionChooseAudio => 'Escolher áudio…';

  @override
  String get blockActionCreateSubpage => 'Criar subpágina';

  @override
  String get blockActionLinkPage => 'Vincular página…';

  @override
  String get defaultNewPageTitle => 'Nova página';

  @override
  String defaultPageDuplicateTitle(Object title) {
    return '$title (cópia)';
  }

  @override
  String aiChatTitleNumbered(int n) {
    return 'Chat $n';
  }

  @override
  String get invalidFolioTemplateFile =>
      'O arquivo não é um modelo Folio válido.';

  @override
  String get templateButtonDefaultLabel => 'Modelo';

  @override
  String get pageHtmlExportPublishedWithFolio => 'Publicado com Folio';

  @override
  String get releaseReadinessSemverOk => 'Versão SemVer válida';

  @override
  String get releaseReadinessEncryptedVault => 'Caderno criptografado';

  @override
  String get releaseReadinessAiRemotePolicy => 'Política de endpoint de IA';

  @override
  String get releaseReadinessVaultUnlocked => 'Caderno desbloqueado';

  @override
  String get releaseReadinessStableChannel => 'Canal estável selecionado';

  @override
  String get aiPromptUserMessage => 'Mensagem do usuário:';

  @override
  String get aiPromptOriginalMessage => 'Mensagem original:';

  @override
  String get aiPromptOriginalUserMessage => 'Mensagem original do usuário:';

  @override
  String get customIconImportEmptySource => 'A fonte do ícone está vazia.';

  @override
  String get customIconImportInvalidUrl => 'A URL do ícone não é válida.';

  @override
  String get customIconImportInvalidSvg => 'O SVG copiado não é válido.';

  @override
  String get customIconImportHttpHttpsOnly =>
      'Apenas URLs http ou https são permitidas.';

  @override
  String get customIconImportDataUriMimeList =>
      'Apenas data:image/svg+xml, data:image/gif, data:image/webp ou data:image/png são permitidos.';

  @override
  String get customIconImportUnsupportedFormat =>
      'Formato não suportado. Use SVG, PNG, GIF ou WebP.';

  @override
  String get customIconImportSvgTooLarge =>
      'O SVG é demasiado grande para importar.';

  @override
  String get customIconImportEmbeddedImageTooLarge =>
      'A imagem incorporada é demasiado grande para importar.';

  @override
  String customIconImportDownloadFailed(Object code) {
    return 'Não foi possível transferir o ícone ($code).';
  }

  @override
  String get customIconImportRemoteTooLarge =>
      'O ícone remoto é demasiado grande.';

  @override
  String get customIconImportConnectFailed =>
      'Não foi possível ligar para transferir o ícone.';

  @override
  String get customIconImportCertFailed =>
      'Falha de certificado ao transferir o ícone.';

  @override
  String get customIconLabelDefault => 'Ícone personalizado';

  @override
  String get customIconLabelImported => 'Ícone importado';

  @override
  String get customIconImportSucceeded => 'Ícone importado com sucesso.';

  @override
  String get customIconClipboardEmpty => 'A área de transferência está vazia.';

  @override
  String get customIconRemoved => 'Ícone removido.';

  @override
  String get whisperModelTiny => 'Tiny (rápido)';

  @override
  String get whisperModelBaseQ8 => 'Base q8 (equilibrado)';

  @override
  String get whisperModelSmallQ8 => 'Small q8 (alta precisão, menos disco)';

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
  String get codeLangPlainText => 'Texto simples';

  @override
  String settingsAppRevoked(Object appId) {
    return 'App revogado: $appId';
  }

  @override
  String get settingsDeviceRevokedSnack => 'Dispositivo revogado.';

  @override
  String get settingsAiConnectionOk => 'Conexão de IA OK';

  @override
  String settingsAiConnectionError(Object error) {
    return 'Erro de conexão: $error';
  }

  @override
  String settingsAiListModelsFailed(Object error) {
    return 'Não foi possível listar modelos: $error';
  }

  @override
  String get folioCloudCallableNotSignedIn =>
      'É necessário iniciar sessão para chamar Cloud Functions';

  @override
  String get folioCloudCallableUnexpectedResponse =>
      'Resposta inesperada do Cloud Functions';

  @override
  String folioCloudCallableHttpError(int code, Object name) {
    return 'HTTP $code ao chamar $name';
  }

  @override
  String get folioCloudCallableNoIdToken =>
      'Sem token de ID para Cloud Functions. Inicie sessão no Folio Cloud novamente.';

  @override
  String get folioCloudCallableUnexpectedFallback =>
      'Resposta inesperada do fallback do Cloud Functions';

  @override
  String folioCloudCallableHttpAiComplete(int code) {
    return 'HTTP $code ao chamar folioCloudAiCompleteHttp';
  }

  @override
  String get cloudAccountEmailMismatch =>
      'O e-mail não corresponde à sessão atual.';

  @override
  String get cloudIdentityInvalidAuthResponse =>
      'Resposta de autenticação inválida.';

  @override
  String get templateButtonPlaceholderText => 'Texto do modelo…';

  @override
  String get aiProviderOllamaName => 'Ollama';

  @override
  String get aiProviderLmStudioName => 'LM Studio';

  @override
  String get blockAudioEmptyHint => 'Escolha um arquivo de áudio';

  @override
  String get blockChildPageTitle => 'Bloco de página';

  @override
  String get blockChildPageNoLink => 'Sem subpágina vinculada.';

  @override
  String get mermaidExpandedLoadError =>
      'Não foi possível mostrar o diagrama ampliado.';

  @override
  String get mermaidPreviewTooltip =>
      'Toque para ampliar e dar zoom. PNG via mermaid.ink (serviço externo).';

  @override
  String get aiEndpointInvalidUrl => 'URL inválida. Use http://host:porta.';

  @override
  String get aiEndpointRemoteNotAllowed =>
      'Endpoint remoto não é permitido sem confirmação.';

  @override
  String get settingsAiSelectProviderFirst =>
      'Selecione primeiro um provedor de IA.';

  @override
  String get releaseReadinessAiSummaryDisabled => 'IA desativada';

  @override
  String get releaseReadinessAiSummaryQuillCloud =>
      'Folio Cloud IA (sem endpoint local)';

  @override
  String releaseReadinessAiSummaryEndpointOk(Object url) {
    return 'Endpoint válido: $url';
  }

  @override
  String get releaseReadinessDetailSemverInvalid =>
      'A versão instalada não satisfaz SemVer.';

  @override
  String get releaseReadinessDetailVaultNotEncrypted =>
      'O caderno atual não está criptografado.';

  @override
  String get releaseReadinessDetailVaultLocked =>
      'Desbloqueie o caderno para validar exportação/importação e o fluxo real.';

  @override
  String get releaseReadinessDetailBetaChannel =>
      'O canal beta de atualizações está ativo.';

  @override
  String get releaseReadinessReportTitle => 'Folio: prontidão para release';

  @override
  String releaseReadinessReportInstalledVersion(Object label) {
    return 'Versão instalada: $label';
  }

  @override
  String releaseReadinessReportSemver(Object value) {
    return 'SemVer válido: $value';
  }

  @override
  String releaseReadinessReportChannel(Object value) {
    return 'Canal de atualizações: $value';
  }

  @override
  String releaseReadinessReportActiveVault(Object id) {
    return 'Caderno ativo: $id';
  }

  @override
  String releaseReadinessReportVaultPath(Object path) {
    return 'Caminho do caderno: $path';
  }

  @override
  String releaseReadinessReportUnlocked(Object value) {
    return 'Caderno desbloqueado: $value';
  }

  @override
  String releaseReadinessReportEncrypted(Object value) {
    return 'Caderno criptografado: $value';
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
    return 'Detalhe IA: $detail';
  }

  @override
  String releaseReadinessReportStatus(Object value) {
    return 'Estado do release: $value';
  }

  @override
  String releaseReadinessReportBlockers(int count) {
    return 'Bloqueadores pendentes: $count';
  }

  @override
  String releaseReadinessReportWarnings(int count) {
    return 'Avisos pendentes: $count';
  }

  @override
  String get releaseReadinessExportWordYes => 'sim';

  @override
  String get releaseReadinessExportWordNo => 'não';

  @override
  String get releaseReadinessChannelStable => 'estável';

  @override
  String get releaseReadinessChannelBeta => 'beta';

  @override
  String get releaseReadinessStatusReady => 'pronto';

  @override
  String get releaseReadinessStatusBlocked => 'bloqueado';

  @override
  String get releaseReadinessPolicyOk => 'ok';

  @override
  String get releaseReadinessPolicyError => 'erro';

  @override
  String get settingsSignInFolioCloudSnack => 'Inicie sessão no Folio Cloud.';

  @override
  String get settingsNotSyncedYet => 'Ainda sem sincronizar';

  @override
  String get settingsDeviceNameTitle => 'Nome do dispositivo';

  @override
  String get settingsDeviceNameHintExample => 'Exemplo: Pixel da Alejandra';

  @override
  String get settingsPairingModeEnabledTwoMin =>
      'Modo de vinculação ativo por 2 minutos.';

  @override
  String get settingsPairingEnableModeFirst =>
      'Primeiro ative o modo de vinculação e depois escolha um dispositivo detectado.';

  @override
  String get settingsPairingSameEmojisBothDevices =>
      'Ative o modo de vinculação em ambos os dispositivos e aguarde os mesmos 3 emojis.';

  @override
  String get settingsPairingCouldNotStart =>
      'Não foi possível iniciar a vinculação. Ative o modo em ambos os dispositivos e aguarde os mesmos 3 emojis.';

  @override
  String get settingsConfirmPairingTitle => 'Confirmar vinculação';

  @override
  String get settingsPairingCheckOtherDeviceEmojis =>
      'Verifique se no outro dispositivo aparecem estes mesmos 3 emojis:';

  @override
  String get settingsPairingPopupInstructions =>
      'Este popup também aparecerá no outro dispositivo. Para concluir a ligação, toque em Vincular aqui e depois em Vincular no outro.';

  @override
  String get settingsLinkDevice => 'Vincular';

  @override
  String get settingsPairingConfirmationSent =>
      'Confirmação enviada. Falta o outro dispositivo tocar em Vincular no popup dele.';

  @override
  String get settingsResolveConflictsTitle => 'Resolver conflitos';

  @override
  String get settingsNoPendingConflicts => 'Não há conflitos pendentes.';

  @override
  String settingsSyncConflictCardSubtitle(
    Object fromPeerId,
    int remotePageCount,
    Object detectedAt,
  ) {
    return 'Origem: $fromPeerId\nPáginas remotas: $remotePageCount\nDetectado: $detectedAt';
  }

  @override
  String get settingsSyncConflictHeading => 'Conflito de sincronização';

  @override
  String get settingsLocalVersionKeptSnack => 'A versão local foi mantida.';

  @override
  String get settingsKeepLocal => 'Manter local';

  @override
  String get settingsRemoteVersionAppliedSnack =>
      'A versão remota foi aplicada.';

  @override
  String get settingsCouldNotApplyRemoteSnack =>
      'Não foi possível aplicar a versão remota.';

  @override
  String get settingsAcceptRemote => 'Aceitar remota';

  @override
  String get settingsClose => 'Fechar';

  @override
  String get settingsSectionDeviceSyncNav => 'Sincronização';

  @override
  String get settingsSectionVault => 'Caderno';

  @override
  String get settingsSectionVaultHeroDescription =>
      'Segurança ao desbloquear, cópias, agendamento em disco e gestão de dados neste dispositivo.';

  @override
  String get settingsSectionUiWorkspace => 'Interface e área de trabalho';

  @override
  String get settingsSectionUiWorkspaceHeroDescription =>
      'Tema, idioma, escala, editor, opções de desktop e atalhos de teclado.';

  @override
  String get settingsSubsectionVaultBackupImport => 'Cópias e importação';

  @override
  String get settingsSubsectionVaultScheduledLocal => 'Backup agendado (local)';

  @override
  String get settingsSubsectionDrive => 'Drive';

  @override
  String get settingsSubsectionVaultData => 'Dados (zona de perigo)';

  @override
  String get folioCloudSubsectionAccount => 'Conta';

  @override
  String get folioCloudSubsectionEncryptedBackups =>
      'Backups e armazenamento (nuvem)';

  @override
  String get folioCloudBackupStorageSectionIntro =>
      'O uso inclui o backup incremental (cloud-pack) e arquivos completos antigos em backups/. Você pode assinar uma biblioteca pequena, média ou grande (cota extra mensal enquanto a assinatura estiver ativa).';

  @override
  String folioCloudBackupStoragePurchasedExtra(Object size) {
    return 'Pacotes comprados: +$size';
  }

  @override
  String get folioCloudBackupStorageBarTitle => 'Uso do armazenamento';

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
    return 'Em uso: $used · Cota total: $total · Livre: $free';
  }

  @override
  String get folioCloudSubsectionPublishing => 'Publicação web';

  @override
  String get settingsFolioCloudSubsectionScheduledCloud =>
      'Backup agendado para o Folio Cloud';

  @override
  String get settingsScheduledCloudUploadRequiresSchedule =>
      'Ative primeiro o backup agendado em Caderno › Backup agendado (local).';

  @override
  String get settingsSyncHeroTitle => 'Sincronização entre dispositivos';

  @override
  String get settingsSyncHeroDescription =>
      'Emparelhe equipamentos na rede local; o relay só ajuda a negociar a conexão e não envia o conteúdo do vault.';

  @override
  String get settingsSyncChipPairingCode => 'Código de ligação';

  @override
  String get settingsSyncChipAutoDiscovery => 'Deteção automática';

  @override
  String get settingsSyncChipOptionalRelay => 'Relay opcional';

  @override
  String get settingsSyncEnableTitle =>
      'Ativar sincronização entre dispositivos';

  @override
  String get settingsSyncSearchingSubtitle =>
      'À procura de dispositivos com o Folio aberto na rede local...';

  @override
  String settingsSyncDevicesFoundOnLan(int count) {
    return '$count dispositivos detetados na LAN.';
  }

  @override
  String get settingsSyncDisabledSubtitle => 'A sincronização está desativada.';

  @override
  String get settingsSyncRelayTitle => 'Usar relay de sinalização';

  @override
  String get settingsSyncRelaySubtitle =>
      'Não envia o conteúdo do vault; só ajuda a negociar a ligação quando a LAN falha.';

  @override
  String get settingsEdit => 'Editar';

  @override
  String get settingsSyncEmojiModeTitle =>
      'Ativar modo de vinculação por emojis';

  @override
  String get settingsSyncEmojiModeSubtitle =>
      'Ative nos dois dispositivos para iniciar a vinculação sem escrever códigos.';

  @override
  String get settingsSyncPairingStatusTitle => 'Estado do modo de vinculação';

  @override
  String get settingsSyncPairingActiveSubtitle =>
      'Ativo por 2 minutos. Já pode iniciar a vinculação a partir de um dispositivo detetado.';

  @override
  String get settingsSyncPairingInactiveSubtitle =>
      'Inativo. Ative aqui e no outro dispositivo para começar a vincular.';

  @override
  String get settingsSyncLastSyncTitle => 'Última sincronização';

  @override
  String get settingsSyncPendingConflictsTitle => 'Conflitos pendentes';

  @override
  String get settingsSyncNoConflictsSubtitle => 'Sem conflitos pendentes.';

  @override
  String settingsSyncConflictsNeedReview(int count) {
    return '$count conflitos requerem revisão manual.';
  }

  @override
  String get settingsResolve => 'Resolver';

  @override
  String get settingsSyncDiscoveredDevicesTitle => 'Dispositivos detetados';

  @override
  String get settingsSyncNoDevicesYetHint =>
      'Ainda não foram detetados dispositivos. Certifique-se de que ambas as apps estão abertas na mesma rede.';

  @override
  String get settingsSyncPeerReadyToLink => 'Pronto para vincular.';

  @override
  String get settingsSyncPeerOtherInPairingMode =>
      'O outro dispositivo está em modo de vinculação. Ative aqui para iniciar a ligação.';

  @override
  String get settingsSyncPeerDetectedLan => 'Detetado na rede local.';

  @override
  String get settingsSyncLinkedDevicesTitle => 'Dispositivos vinculados';

  @override
  String get settingsSyncNoLinkedDevicesYet =>
      'Ainda não há dispositivos ligados.';

  @override
  String settingsSyncPeerIdLabel(Object peerId) {
    return 'ID: $peerId';
  }

  @override
  String get settingsRevoke => 'Revogar';

  @override
  String get sidebarPageIconTitle => 'Ícone da página';

  @override
  String get sidebarPageIconPickerHelper =>
      'Escolha um ícone rápido, um importado ou abra o seletor completo.';

  @override
  String get sidebarPageIconCustomEmoji => 'Emoji personalizado';

  @override
  String get sidebarPageIconRemove => 'Remover';

  @override
  String get sidebarPageIconTabQuick => 'Rápidos';

  @override
  String get sidebarPageIconTabImported => 'Importados';

  @override
  String get sidebarPageIconTabAll => 'Todos';

  @override
  String get sidebarPageIconEmptyImported =>
      'Ainda não importou ícones em Definições.';

  @override
  String get sidebarDeletePageMenuTitle => 'Eliminar página';

  @override
  String get sidebarDeleteFolderMenuTitle => 'Remover pasta';

  @override
  String sidebarDeletePageConfirmInline(Object title) {
    return 'Eliminar «$title»? Não é possível anular.';
  }

  @override
  String sidebarDeleteFolderConfirmInline(Object title) {
    return 'Remover pasta «$title»? As subpáginas passam para a raiz do caderno.';
  }

  @override
  String get settingsStripeSubscriptionRefreshed =>
      'Faturação Folio Cloud atualizada.';

  @override
  String get settingsStripeBillingPortalUnavailable =>
      'Portal de faturação indisponível.';

  @override
  String get settingsCouldNotOpenLink => 'Não foi possível abrir a ligação.';

  @override
  String get settingsStripeCheckoutUnavailable =>
      'Pagamento indisponível (configure Stripe no servidor).';

  @override
  String get settingsCloudBackupEnablePlanSnack =>
      'Ative o Folio Cloud com a funcionalidade de cópia na nuvem incluída no seu plano.';

  @override
  String get settingsNoActiveVault => 'Não há caderno ativo.';

  @override
  String get settingsCloudBackupsNeedPlan =>
      'Precisa do Folio Cloud ativo com cópia na nuvem.';

  @override
  String settingsCloudBackupsDialogTitle(int count) {
    return 'Cópias na nuvem ($count/10)';
  }

  @override
  String get settingsCloudBackupsVaultLabel => 'Cofre';

  @override
  String get settingsCloudBackupsEmpty => 'Ainda não há cópias nesta conta.';

  @override
  String get settingsCloudBackupDownloadTooltip => 'Transferir';

  @override
  String get settingsCloudBackupActionDownload => 'Transferir';

  @override
  String get settingsCloudBackupActionImportOverwrite =>
      'Importar (substituir)';

  @override
  String get settingsCloudBackupSaveDialogTitle => 'Guardar cópia';

  @override
  String get settingsCloudBackupDownloadedSnack => 'Cópia transferida.';

  @override
  String get settingsCloudBackupDeletedSnack => 'Cópia eliminada.';

  @override
  String get settingsCloudBackupImportedSnack => 'Importação concluída.';

  @override
  String get settingsCloudBackupVaultMustBeUnlocked =>
      'O caderno tem de estar desbloqueado.';

  @override
  String settingsCloudBackupsTotalLabel(Object size) {
    return 'Total: $size';
  }

  @override
  String get settingsCloudBackupImportOverwriteTitle => 'Importar (substituir)';

  @override
  String get settingsCloudBackupImportOverwriteBody =>
      'Isto irá substituir o conteúdo do caderno aberto. Certifique-se de que tem uma cópia local antes de continuar.';

  @override
  String get settingsCloudBackupDeleteWarning =>
      'Tem a certeza de que quer eliminar esta cópia da nuvem? Esta ação não pode ser anulada.';

  @override
  String get settingsPublishedRequiresPlan =>
      'Precisa do Folio Cloud com publicação web ativa.';

  @override
  String get settingsPublishedPagesTitle => 'Páginas publicadas';

  @override
  String get settingsPublishedPagesEmpty => 'Ainda não há páginas publicadas.';

  @override
  String get settingsPublishedDeleteDialogTitle => 'Remover publicação?';

  @override
  String get settingsPublishedDeleteDialogBody =>
      'O HTML público será removido e a ligação deixará de funcionar.';

  @override
  String get settingsPublishedRemovedSnack => 'Publicação removida.';

  @override
  String get settingsCouldNotReadInstalledVersion =>
      'Não foi possível ler a versão instalada.';

  @override
  String settingsCouldNotOpenReleaseNotes(Object error) {
    return 'Não foi possível abrir as notas de versão: $error';
  }

  @override
  String settingsUpdateFailed(Object error) {
    return 'Não foi possível atualizar: $error';
  }

  @override
  String get settingsSessionEndedSnack => 'Sessão terminada';

  @override
  String get settingsLabelYes => 'Sim';

  @override
  String get settingsLabelNo => 'Não';

  @override
  String get settingsSecurityEncryptedHeroDescription =>
      'Desbloqueio rápido, passkey, bloqueio automático e palavra-passe mestra do cofre encriptado.';

  @override
  String get settingsUnencryptedVaultTitle => 'Cofre não encriptado';

  @override
  String get settingsUnencryptedVaultChipDataOnDisk => 'Dados em disco';

  @override
  String get settingsUnencryptedVaultChipEncryptionAvailable =>
      'Encriptação disponível';

  @override
  String get settingsAppearanceChipTheme => 'Tema';

  @override
  String get settingsAppearanceChipZoom => 'Zoom';

  @override
  String get settingsAppearanceChipLanguage => 'Idioma';

  @override
  String get settingsAppearanceChipEditorWorkspace => 'Editor e espaço';

  @override
  String get settingsWindowsScaleFollowTitle => 'Seguir escala do Windows';

  @override
  String get settingsWindowsScaleFollowSubtitle =>
      'Usa automaticamente a escala do sistema no Windows.';

  @override
  String get settingsInterfaceZoomTitle => 'Zoom da interface';

  @override
  String get settingsInterfaceZoomSubtitle =>
      'Aumenta ou reduz o tamanho geral da app.';

  @override
  String get settingsUiZoomReset => 'Repor';

  @override
  String get settingsEditorSubsection => 'Editor';

  @override
  String get settingsEditorContentWidthTitle => 'Largura do conteúdo';

  @override
  String get settingsEditorContentWidthSubtitle =>
      'Define quanta largura os blocos ocupam no editor.';

  @override
  String get settingsEnterCreatesNewBlockTitle => 'Enter cria um bloco novo';

  @override
  String get settingsEnterCreatesNewBlockSubtitleWhenEnabled =>
      'Desative para que Enter insira quebra de linha.';

  @override
  String get settingsEnterCreatesNewBlockSubtitleWhenDisabled =>
      'Agora Enter insere quebra de linha. Shift+Enter continua a funcionar.';

  @override
  String get settingsWorkspaceSubsection => 'Espaço de trabalho';

  @override
  String get settingsCustomIconsTitle => 'Ícones personalizados';

  @override
  String get settingsCustomIconsDescription =>
      'Importe um URL PNG, GIF ou WebP, ou um data:image compatível copiado de sites como notionicons.so. Depois pode usá-lo como ícone de página ou callout.';

  @override
  String settingsCustomIconsSavedCount(int count) {
    return '$count guardados';
  }

  @override
  String get settingsCustomIconsChipUrl => 'URL PNG, GIF ou WebP';

  @override
  String get settingsCustomIconsChipDataImage => 'data:image/*';

  @override
  String get settingsCustomIconsChipPaste => 'Colar da área de transferência';

  @override
  String get settingsCustomIconsImportTitle => 'Importar ícone novo';

  @override
  String get settingsCustomIconsImportSubtitle =>
      'Pode dar um nome e colar a fonte manualmente ou trazê-la diretamente da área de transferência.';

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
  String get settingsCustomIconsImportButton => 'Importar ícone';

  @override
  String get settingsCustomIconsFromClipboard => 'Da área de transferência';

  @override
  String get settingsCustomIconsLibraryTitle => 'Biblioteca';

  @override
  String get settingsCustomIconsLibrarySubtitle =>
      'Prontos para usar em toda a app';

  @override
  String get settingsCustomIconsEmpty => 'Ainda não importou ícones.';

  @override
  String get settingsCustomIconsDeleteTooltip => 'Eliminar ícone';

  @override
  String get settingsCustomIconsReferenceCopiedSnack => 'Referência copiada.';

  @override
  String get settingsCustomIconsCopyToken => 'Copiar token';

  @override
  String get settingsAiHeroQuillWithLocalAlt =>
      'A IA corre no Quill Cloud (subscrição com IA na nuvem ou tinta comprada). Escolha outro fornecedor abaixo para Ollama ou LM Studio local.';

  @override
  String get settingsAiHeroQuillCloudOnly =>
      'A IA corre no Quill Cloud (subscrição com IA na nuvem ou tinta comprada).';

  @override
  String get settingsAiHeroLocalDefault =>
      'Ligue Ollama ou LM Studio localmente; o assistente usa o modelo e o contexto que definir aqui.';

  @override
  String get settingsAiHeroQuillMobileOnly =>
      'Neste dispositivo o Quill só pode usar o Quill Cloud. Escolha Quill Cloud como fornecedor para ativar a IA.';

  @override
  String get settingsAiChipCloud => 'Na nuvem';

  @override
  String get settingsAiSnackFirebaseUnavailableBuild =>
      'Firebase não está disponível nesta compilação.';

  @override
  String get settingsAiSnackSignInCloudAccount =>
      'Inicie sessão na conta na nuvem (Definições).';

  @override
  String settingsAiProviderSwitchFailed(Object error) {
    return 'Não foi possível mudar o fornecedor de IA: $error';
  }

  @override
  String get settingsAboutHeroDescription =>
      'Versão instalada, origem de atualizações e verificação manual de novidades.';

  @override
  String get settingsOpenReleaseNotes => 'Ver notas de versão';

  @override
  String get settingsUpdateChannelLabel => 'Canal';

  @override
  String get settingsUpdateChannelRelease => 'Release';

  @override
  String get settingsUpdateChannelBeta => 'Beta';

  @override
  String get settingsDataHeroDescription =>
      'Ações permanentes em ficheiros locais. Faça uma cópia de segurança antes de apagar.';

  @override
  String get settingsDangerZoneTitle => 'Zona de perigo';

  @override
  String get settingsDesktopHeroDescription =>
      'Atalhos globais, bandeja do sistema e comportamento da janela no ambiente de trabalho.';

  @override
  String get settingsShortcutsHeroDescription =>
      'Combinações apenas dentro do Folio. Teste uma tecla antes de guardar.';

  @override
  String get settingsShortcutsTestChip => 'Testar';

  @override
  String get settingsIntegrationsChipApprovedPermissions =>
      'Permissões aprovadas';

  @override
  String get settingsIntegrationsChipRevocableAccess => 'Acesso revogável';

  @override
  String get settingsIntegrationsChipExternalApps => 'Apps externas';

  @override
  String get settingsIntegrationsActiveConnectionsTitle => 'Ligações ativas';

  @override
  String get settingsIntegrationsActiveConnectionsSubtitle =>
      'Apps que já podem interagir com o Folio';

  @override
  String get settingsViewInkUsageTable => 'Ver tabela de consumo';

  @override
  String get settingsCloudInkUsageTableTitle =>
      'Tabela de consumo de gotas (Quill Cloud)';

  @override
  String get settingsCloudInkUsageTableIntro =>
      'Custo base por ação. Podem aplicar-se suplementos por prompts longos e tokens de saída.';

  @override
  String get settingsCloudInkDrops => 'gotas';

  @override
  String get settingsCloudInkTableCachedNotice =>
      'A mostrar tabela em cache local (sem ligação ao backend).';

  @override
  String get settingsCloudInkOpRewriteBlock => 'Reescrever bloco';

  @override
  String get settingsCloudInkOpSummarizeSelection => 'Resumir seleção';

  @override
  String get settingsCloudInkOpExtractTasks => 'Extrair tarefas';

  @override
  String get settingsCloudInkOpSummarizePage => 'Resumir página';

  @override
  String get settingsCloudInkOpGenerateInsert => 'Gerar inserção';

  @override
  String get settingsCloudInkOpGeneratePage => 'Gerar página';

  @override
  String get settingsCloudInkOpChatTurn => 'Turno de chat';

  @override
  String get settingsCloudInkOpAgentMain => 'Execução do agente';

  @override
  String get settingsCloudInkOpAgentFollowup => 'Seguimento do agente';

  @override
  String get settingsCloudInkOpEditPagePanel => 'Edição da página (painel)';

  @override
  String get settingsCloudInkOpDefault => 'Operação por defeito';

  @override
  String get settingsDesktopRailSubtitle =>
      'Escolha uma categoria na lista ou percorra o conteúdo.';

  @override
  String get settingsCloudInkViewTableButton => 'Ver tabela';

  @override
  String get settingsCloudInkHostedAiQuillCloudHint =>
      'Preços de referência para IA na nuvem no Quill Cloud.';

  @override
  String get vaultStarterHomeTitle => 'Comece aqui';

  @override
  String get vaultStarterHomeHeading => 'O seu caderno está pronto';

  @override
  String get vaultStarterHomeIntro =>
      'O Folio organiza as páginas numa árvore, edita conteúdo em blocos e mantém os dados neste dispositivo. Este guia curto mostra o que pode fazer desde o primeiro minuto.';

  @override
  String get vaultStarterHomeCallout =>
      'Pode apagar, renomear ou mover estas páginas quando quiser. São apenas uma base para começar mais depressa.';

  @override
  String get vaultStarterHomeSectionTips => 'O mais útil para começar';

  @override
  String get vaultStarterHomeBulletSlash =>
      'Prima / dentro de um parágrafo para inserir títulos, listas, tabelas, blocos de código, Mermaid e mais.';

  @override
  String get vaultStarterHomeBulletSidebar =>
      'Use o painel lateral para criar páginas e subpáginas, e reorganize a árvore à sua maneira.';

  @override
  String get vaultStarterHomeBulletSettings =>
      'Abra Definições para ativar IA, configurar cópia de segurança, mudar idioma ou adicionar desbloqueio rápido.';

  @override
  String get vaultStarterHomeTodo1 =>
      'Criar a minha primeira página de trabalho';

  @override
  String get vaultStarterHomeTodo2 =>
      'Experimentar o menu / para inserir um bloco novo';

  @override
  String get vaultStarterHomeTodo3 =>
      'Rever Definições e decidir se quero ativar Quill ou desbloqueio rápido';

  @override
  String get vaultStarterCapabilitiesTitle => 'O que o Folio pode fazer';

  @override
  String get vaultStarterCapabilitiesSectionMain => 'Capacidades principais';

  @override
  String get vaultStarterCapabilitiesBullet1 =>
      'Tomar notas com estrutura livre: parágrafos, títulos, listas, checklists, citações e divisores.';

  @override
  String get vaultStarterCapabilitiesBullet2 =>
      'Trabalhar com blocos especiais como tabelas, bases de dados, ficheiros, áudio, vídeo, embeds e diagramas Mermaid.';

  @override
  String get vaultStarterCapabilitiesBullet3 =>
      'Procurar conteúdo, rever histórico da página e manter revisões no mesmo caderno.';

  @override
  String get vaultStarterCapabilitiesBullet4 =>
      'Exportar ou importar dados, incluindo cópia do caderno e importação do Notion.';

  @override
  String get vaultStarterCapabilitiesSectionShortcuts => 'Atalhos rápidos';

  @override
  String get vaultStarterCapabilitiesShortcutN =>
      'Ctrl+N cria uma página nova.';

  @override
  String get vaultStarterCapabilitiesShortcutSearch =>
      'Ctrl+K ou Ctrl+F abre a pesquisa.';

  @override
  String get vaultStarterCapabilitiesShortcutSettings =>
      'Ctrl+, abre Definições e Ctrl+L bloqueia o caderno.';

  @override
  String get vaultStarterCapabilitiesAiCallout =>
      'A IA não vem ativada por padrão. Se usar Quill, configure em Definições—provedor, modelo e permissões de contexto.';

  @override
  String get vaultStarterQuillTitle => 'Quill e privacidade';

  @override
  String get vaultStarterQuillSectionWhat => 'O que o Quill pode fazer';

  @override
  String get vaultStarterQuillBullet1 =>
      'Resumir, reescrever ou expandir o conteúdo de uma página.';

  @override
  String get vaultStarterQuillBullet2 =>
      'Responder dúvidas sobre blocos, atalhos e formas de organizar notas no Folio.';

  @override
  String get vaultStarterQuillBullet3 =>
      'Trabalhar com a página aberta como contexto ou com várias páginas que escolher como referência.';

  @override
  String get vaultStarterQuillSectionPrivacy => 'Privacidade e segurança';

  @override
  String get vaultStarterQuillPrivacyBody =>
      'As páginas ficam neste dispositivo. Se ativar IA, veja que contexto partilha e com que provedor. Se esquecer a palavra-passe mestra de um caderno encriptado, o Folio não pode recuperá-la.';

  @override
  String get vaultStarterQuillBackupCallout =>
      'Faça uma cópia do caderno quando tiver conteúdo importante. A cópia mantém dados e anexos, mas não transfere Hello nem passkeys entre dispositivos.';

  @override
  String get vaultStarterQuillMermaidCaption => 'Teste rápido de Mermaid:';

  @override
  String get vaultStarterQuillMermaidSource =>
      'graph TD\nInicio[Criar caderno] --> Organizar[Organizar páginas]\nOrganizar --> Escrever[Escrever e ligar ideias]\nEscrever --> Rever[Procurar, rever e melhorar]';

  @override
  String get settingsAccentColorTitle => 'Cor de destaque';

  @override
  String get settingsAccentFollowSystem => 'Windows';

  @override
  String get settingsAccentFolioDefault => 'Folio';

  @override
  String get settingsAccentCustom => 'Personalizado';

  @override
  String get settingsAccentPickColor => 'Escolher cor predefinida';

  @override
  String get settingsPrivacySectionTitle => 'Privacidade e diagnósticos';

  @override
  String get settingsTelemetryTitle => 'Estatísticas de uso anónimas';

  @override
  String get settingsTelemetrySubtitle =>
      'Ajuda a medir instalações e utilização. Não é enviado conteúdo do caderno nem títulos.';

  @override
  String get onboardingTelemetryTitle => 'Estatísticas de utilização';

  @override
  String get onboardingTelemetryBody =>
      'O Folio pode enviar analytics anónimos para perceber como a app é usada. Pode alterar isto em qualquer momento nas Definições.';

  @override
  String get onboardingTelemetrySwitchTitle => 'Estatísticas de uso anónimas';

  @override
  String get onboardingTelemetrySwitchSubtitle =>
      'Ajuda a medir instalações e utilização. Não é enviado conteúdo do caderno nem títulos.';

  @override
  String get onboardingTelemetryFootnote =>
      'Não é enviado conteúdo do caderno nem títulos de páginas.';

  @override
  String get settingsAutoCrashReportsTitle =>
      'Enviar diagnósticos de falhas automaticamente';

  @override
  String get settingsAutoCrashReportsSubtitle =>
      'Se ocorrer um erro grave, envia-se um excerto do registo para o Folio (opcional, limitado por sessão).';

  @override
  String get settingsReportBugButton => 'Reportar um erro';

  @override
  String get settingsPrivacyFootnote =>
      'Pode acrescentar uma nota; pode abrir-se a página de incidências no navegador.';

  @override
  String get settingsReportBugDialogTitle => 'Reportar um erro';

  @override
  String get settingsReportBugDialogBody =>
      'Enviaremos metadados anónimos, um excerto do registo e a sua nota. Depois pode abrir o gestor de incidências.';

  @override
  String get settingsReportBugNoteLabel => 'O que aconteceu? (opcional)';

  @override
  String get settingsReportBugSend => 'Enviar e continuar';

  @override
  String get settingsReportBugSentOk => 'Diagnóstico enviado.';

  @override
  String get settingsReportBugSentFail =>
      'Não foi possível enviar o diagnóstico. Verifique a ligação ou tente mais tarde.';
}
