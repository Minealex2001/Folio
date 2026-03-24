import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:passkeys/exceptions.dart';

import '../../app/app_settings.dart';
import '../../app/folio_in_app_shortcuts.dart';
import 'in_app_shortcut_capture_dialog.dart';
import '../../data/notion_import/notion_importer.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../data/vault_backup.dart';
import '../../services/ai/ai_service.dart';
import '../../services/ai/ai_provider_detector.dart';
import '../../services/ai/ai_safety_policy.dart';
import '../../services/ai/lmstudio_ai_service.dart';
import '../../services/ai/ollama_ai_service.dart';
import '../../services/updater/github_release_updater.dart';
import '../../services/updater/update_release_channel.dart';
import '../../session/vault_session.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.session,
    required this.appSettings,
  });

  final VaultSession session;
  final AppSettings appSettings;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  static const _idleOptions = <int>[1, 5, 10, 15, 30, 60];
  VaultSession get _s => widget.session;
  AppSettings get _app => widget.appSettings;
  final ScrollController _settingsScrollController = ScrollController();
  final List<GlobalKey> _sectionKeys = List.generate(9, (_) => GlobalKey());
  int _selectedDesktopSection = 0;

  var _quickEnabled = false;
  var _passkeyRegistered = false;
  late final TextEditingController _aiBaseUrlController;
  late final TextEditingController _aiTimeoutController;
  late final TextEditingController _aiContextWindowController;
  List<String> _availableModels = const [];
  bool _loadingModels = false;
  bool _checkingUpdates = false;
  bool _detectingAiProvider = false;
  String _installedVersionLabel = '...';

  @override
  void initState() {
    super.initState();
    _aiBaseUrlController = TextEditingController(text: _app.aiBaseUrl);
    _aiTimeoutController = TextEditingController(
      text: _app.aiTimeoutMs.toString(),
    );
    _aiContextWindowController = TextEditingController(
      text: _app.aiContextWindowTokens.toString(),
    );
    _availableModels = _app.cachedAiModelsFor(_app.aiProvider);
    _refreshSecurityFlags();
    _loadInstalledVersionInfo();
  }

  @override
  void dispose() {
    _settingsScrollController.dispose();
    _aiBaseUrlController.dispose();
    _aiTimeoutController.dispose();
    _aiContextWindowController.dispose();
    super.dispose();
  }

  Future<void> _scrollToSection(int index) async {
    if (index < 0 || index >= _sectionKeys.length) return;
    if (mounted) {
      setState(() => _selectedDesktopSection = index);
    }
    final targetContext = _sectionKeys[index].currentContext;
    if (targetContext == null) return;
    await Scrollable.ensureVisible(
      targetContext,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      alignment: 0.03,
    );
  }

  Future<void> _refreshSecurityFlags() async {
    final q = await _s.quickUnlockEnabled;
    final p = await _s.hasPasskey;
    if (mounted) {
      setState(() {
        _quickEnabled = q;
        _passkeyRegistered = p;
      });
    }
  }

  Future<void> _loadInstalledVersionInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() {
        _installedVersionLabel = '${info.version}+${info.buildNumber}';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _installedVersionLabel = 'desconocida';
      });
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _revokeIntegrationApp(String appId) async {
    await _app.revokeIntegrationApp(appId);
    _snack('App revocada: $appId');
  }

  Future<void> _openEncryptPlainVaultDialog() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => _EncryptPlainVaultDialog(session: _s),
    );
    if (ok != true || !mounted) return;
    await _refreshSecurityFlags();
    if (!mounted) return;
    _snack(AppLocalizations.of(context).encryptPlainVaultSuccessSnack);
  }

  Future<void> _confirmRemoteEndpointIfNeeded() async {
    final uri = AiSafetyPolicy.parseAndNormalizeUrl(_app.aiBaseUrl);
    if (uri == null) return;
    final isRemote = !AiSafetyPolicy.isLocalhostHost(uri.host);
    if (!isRemote || _app.aiEndpointMode != AiEndpointMode.allowRemote) return;
    if (_app.aiRemoteEndpointConfirmed) return;
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar endpoint remoto'),
        content: Text(
          'Vas a habilitar IA con un host remoto (${uri.host}). '
          'El contenido que envíes puede salir del equipo.\n\n¿Continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    if (go == true) {
      await _app.setAiRemoteEndpointConfirmed(true);
      return;
    }
    await _app.setAiEnabled(false);
  }

  Future<void> _saveAiFields() async {
    await _app.setAiBaseUrl(_aiBaseUrlController.text);
    final timeout = int.tryParse(_aiTimeoutController.text.trim());
    if (timeout != null) {
      await _app.setAiTimeoutMs(timeout);
    }
    final ctxWin = int.tryParse(_aiContextWindowController.text.trim());
    if (ctxWin != null) {
      await _app.setAiContextWindowTokens(ctxWin);
    }
    await _confirmRemoteEndpointIfNeeded();
  }

  Future<bool> _confirmAiBetaEnable() async {
    final l10n = AppLocalizations.of(context);
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.aiBetaEnableTitle),
        content: Text(l10n.aiBetaEnableBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.aiBetaEnableConfirm),
          ),
        ],
      ),
    );
    return go == true;
  }

  String _providerLabel(AiProvider provider, AppLocalizations l10n) {
    switch (provider) {
      case AiProvider.ollama:
        return 'Ollama';
      case AiProvider.lmStudio:
        return 'LM Studio';
      case AiProvider.none:
        return l10n.aiProviderNone;
    }
  }

  Future<AiProvider?> _askUserProviderChoice() async {
    final l10n = AppLocalizations.of(context);
    return showDialog<AiProvider>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.aiSetupChooseProviderTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.aiSetupChooseProviderBody),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.hub_outlined),
              title: const Text('Ollama'),
              onTap: () => Navigator.pop(ctx, AiProvider.ollama),
            ),
            ListTile(
              leading: const Icon(Icons.hub_outlined),
              title: const Text('LM Studio'),
              onTap: () => Navigator.pop(ctx, AiProvider.lmStudio),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
        ],
      ),
    );
  }

  Future<bool> _autoDetectAndConfigureAiProvider() async {
    if (_detectingAiProvider) return false;
    setState(() => _detectingAiProvider = true);
    try {
      final detector = const AiProviderDetector();
      final summary = await detector.detect(preferredProvider: _app.aiProvider);
      final recommended = summary.recommendedProvider;
      if (recommended != null) {
        await _app.setAiProvider(recommended);
        final baseUrl = recommended == AiProvider.ollama
            ? AppSettings.defaultOllamaUrl
            : AppSettings.defaultLmStudioUrl;
        _aiBaseUrlController.text = baseUrl;
        await _app.setAiBaseUrl(baseUrl);
        await _saveAiFields();
        await _loadAiModels();
        if (mounted) {
          final l10n = AppLocalizations.of(context);
          _snack(
            l10n.aiProviderAutoConfigured(_providerLabel(recommended, l10n)),
          );
        }
        return true;
      }

      if (!mounted) return false;
      final l10n = AppLocalizations.of(context);
      final selectedProvider = await _askUserProviderChoice();
      if (!mounted || selectedProvider == null) return false;
      var retry = true;
      while (retry && mounted) {
        final action = await showDialog<_AiWizardAction>(
          context: context,
          builder: (ctx) => _AiSetupWizardDialog(
            summary: summary,
            selectedProvider: selectedProvider,
            title: l10n.aiSetupWizardTitle,
            noProviderTitle: l10n.aiSetupNoProviderTitle,
            noProviderBody: l10n.aiSetupNoProviderBody,
            ollamaInstallTitle: l10n.aiSetupOllamaTitle,
            ollamaInstallBody: l10n.aiSetupOllamaBody,
            lmStudioInstallTitle: l10n.aiSetupLmStudioTitle,
            lmStudioInstallBody: l10n.aiSetupLmStudioBody,
            openSettingsHint: l10n.aiSetupOpenSettingsHint,
            retryLabel: l10n.retry,
            closeLabel: l10n.cancel,
          ),
        );
        if (action == _AiWizardAction.retry) {
          final redetected = await detector.detect(
            preferredProvider: _app.aiProvider,
          );
          final selectedResult = selectedProvider == AiProvider.ollama
              ? redetected.ollama
              : redetected.lmStudio;
          if (selectedResult.reachable) {
            await _app.setAiProvider(selectedProvider);
            final baseUrl = selectedProvider == AiProvider.ollama
                ? AppSettings.defaultOllamaUrl
                : AppSettings.defaultLmStudioUrl;
            _aiBaseUrlController.text = baseUrl;
            await _app.setAiBaseUrl(baseUrl);
            await _saveAiFields();
            await _loadAiModels();
            if (mounted) {
              final l10n = AppLocalizations.of(context);
              _snack(
                l10n.aiProviderAutoConfigured(
                  _providerLabel(selectedProvider, l10n),
                ),
              );
            }
            return true;
          }
          retry = true;
          continue;
        }
        retry = false;
      }
      return false;
    } finally {
      if (mounted) setState(() => _detectingAiProvider = false);
    }
  }

  AiService _buildAiServiceFromInputs() {
    final uri = AiSafetyPolicy.parseAndNormalizeUrl(
      _aiBaseUrlController.text.trim(),
    );
    if (uri == null) {
      throw StateError('URL inválida. Usa http://localhost:1234');
    }
    final timeoutMs =
        int.tryParse(_aiTimeoutController.text.trim()) ?? _app.aiTimeoutMs;
    final timeout = Duration(milliseconds: timeoutMs.clamp(3000, 120000));
    switch (_app.aiProvider) {
      case AiProvider.ollama:
        return OllamaAiService(
          baseUrl: uri,
          timeout: timeout,
          defaultModel: _app.aiModel,
        );
      case AiProvider.lmStudio:
        return LmStudioAiService(
          baseUrl: uri,
          timeout: timeout,
          defaultModel: _app.aiModel,
        );
      case AiProvider.none:
        throw StateError('Selecciona un proveedor IA primero.');
    }
  }

  Future<void> _testAiConnection() async {
    await _saveAiFields();
    final err = AiSafetyPolicy.validateEndpoint(
      rawUrl: _app.aiBaseUrl,
      mode: _app.aiEndpointMode,
      remoteConfirmed: _app.aiRemoteEndpointConfirmed,
    );
    if (err != null) {
      _snack(err);
      return;
    }
    try {
      final service = _buildAiServiceFromInputs();
      await service.ping();
      await _loadAiModels();
      _snack('Conexión IA OK');
    } catch (e) {
      _snack('Error de conexión: $e');
    }
  }

  Future<void> _loadAiModels() async {
    setState(() => _loadingModels = true);
    try {
      final service = _buildAiServiceFromInputs();
      final models = await service.listModels();
      if (!mounted) return;
      setState(() {
        _availableModels = models;
      });
      await _app.setCachedAiModelsFor(_app.aiProvider, models);
      if (models.isNotEmpty) {
        final selected = models.contains(_app.aiModel)
            ? _app.aiModel
            : models.first;
        await _app.setAiModel(selected);
      }
    } catch (e) {
      if (!mounted) return;
      _snack('No se pudieron listar modelos: $e');
    } finally {
      if (mounted) {
        setState(() => _loadingModels = false);
      }
    }
  }

  String _suggestedBackupFileName() {
    final d = DateTime.now();
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return 'folio-cofre-$y-$m-$day.folio.zip';
  }

  Future<void> _openExportBackupFlow() async {
    final l10n = AppLocalizations.of(context);
    if (_s.state != VaultFlowState.unlocked) return;
    final verified = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _VaultIdentityVerifyDialog(
        session: _s,
        quickEnabled: _quickEnabled,
        passkeyRegistered: _passkeyRegistered,
        title: Text(l10n.exportVaultDialogTitle),
        body: Text(l10n.exportVaultDialogBody),
        passwordButtonLabel: l10n.verifyAndExport,
      ),
    );
    if (verified != true || !mounted) return;

    final path = await FilePicker.platform.saveFile(
      dialogTitle: l10n.saveVaultBackupDialogTitle,
      fileName: _suggestedBackupFileName(),
      type: FileType.custom,
      allowedExtensions: const ['zip'],
    );
    if (path == null || !mounted) return;

    try {
      await _s.exportVaultBackup(path);
      if (mounted) {
        _snack(l10n.backupSavedSuccessSnack);
      }
    } on VaultBackupException catch (e) {
      if (mounted) _snack(l10n.exportFailedError('$e'));
    } catch (e) {
      if (mounted) {
        _snack(l10n.exportFailedError('$e'));
      }
    }
  }

  Future<void> _openImportBackupFlow() async {
    final l10n = AppLocalizations.of(context);
    if (_s.state != VaultFlowState.unlocked) return;
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.importVaultDialogTitle),
        content: SingleChildScrollView(
          child: Text(
            l10n.importVaultDialogBody,
            style: const TextStyle(height: 1.45),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.continueAction),
          ),
        ],
      ),
    );
    if (go != true || !mounted) return;

    final verified = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _VaultIdentityVerifyDialog(
        session: _s,
        quickEnabled: _quickEnabled,
        passkeyRegistered: _passkeyRegistered,
        title: Text(l10n.confirmIdentity),
        body: Text(l10n.importIdentityBody),
        passwordButtonLabel: l10n.verifyAndContinue,
      ),
    );
    if (verified != true || !mounted) return;

    final pick = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['zip'],
      allowMultiple: false,
    );
    if (pick == null || pick.files.isEmpty || !mounted) return;
    final fp = pick.files.single.path;
    if (fp == null) {
      _snack(l10n.filePathReadError);
      return;
    }

    final password = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const _BackupPasswordDialog(),
    );
    if (password == null || password.isEmpty || !mounted) return;

    try {
      await _s.importVaultBackupAsNew(fp, password);
      await _refreshSecurityFlags();
      if (!mounted) return;
      _snack(l10n.importedVaultSuccessSnack);
      Navigator.of(context).pop();
    } on VaultBackupException catch (e) {
      if (mounted) _snack(l10n.importFailedGenericError('$e'));
    } catch (e) {
      if (mounted) _snack(l10n.importFailedGenericError('$e'));
    }
  }

  Future<void> _openImportNotionFlow() async {
    final l10n = AppLocalizations.of(context);
    if (_s.state != VaultFlowState.unlocked) return;

    final verified = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _VaultIdentityVerifyDialog(
        session: _s,
        quickEnabled: _quickEnabled,
        passkeyRegistered: _passkeyRegistered,
        title: const Text('Importar desde Notion'),
        body: const Text(
          'Importa un ZIP exportado por Notion. Puedes añadirlo al cofre actual o crear un cofre nuevo.',
        ),
        passwordButtonLabel: l10n.verifyAndContinue,
      ),
    );
    if (verified != true || !mounted) return;

    final pick = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['zip'],
      allowMultiple: false,
    );
    if (pick == null || pick.files.isEmpty || !mounted) return;
    final fp = pick.files.single.path;
    if (fp == null) {
      _snack(l10n.filePathReadError);
      return;
    }

    final mode = await showDialog<_NotionImportMode>(
      context: context,
      builder: (ctx) => const _NotionImportModeDialog(),
    );
    if (mode == null || !mounted) return;

    try {
      if (mode == _NotionImportMode.currentVault) {
        final report = await _s.importNotionIntoCurrentVault(fp);
        if (!mounted) return;
        final kind = report.format == NotionExportFormat.markdown
            ? 'Markdown'
            : 'HTML';
        _snack(
          'Importado desde Notion ($kind): ${report.pages.length} paginas.',
        );
      } else {
        final newPassword = await showDialog<String>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => const _NewVaultPasswordDialog(),
        );
        if (newPassword == null || newPassword.isEmpty || !mounted) return;
        await _s.importNotionAsNewVault(
          fp,
          masterPassword: newPassword,
          displayName: 'Notion importado',
        );
        if (!mounted) return;
        _snack('Cofre importado desde Notion creado correctamente.');
      }
    } on NotionImportException catch (e) {
      if (mounted) _snack('No se pudo importar Notion: $e');
    } catch (e) {
      if (mounted) _snack('No se pudo importar Notion: $e');
    }
  }

  Future<void> _openWipeFlow() async {
    final l10n = AppLocalizations.of(context);
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.wipeVaultDialogTitle),
        content: Text(l10n.wipeVaultDialogBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.continueAction),
          ),
        ],
      ),
    );
    if (go != true || !mounted) return;

    final verified = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _VaultIdentityVerifyDialog(
        session: _s,
        quickEnabled: _quickEnabled,
        passkeyRegistered: _passkeyRegistered,
        title: Text(l10n.confirmIdentity),
        body: Text(l10n.wipeIdentityBody),
        passwordButtonLabel: l10n.verifyAndDelete,
      ),
    );

    if (verified != true || !context.mounted) return;

    try {
      await _s.wipeVaultAndReset();
      if (!context.mounted) return;
      if (_s.state == VaultFlowState.needsOnboarding) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          Navigator.of(context, rootNavigator: true).popUntil((r) => r.isFirst);
        });
      } else {
        if (!mounted) return;
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (!context.mounted) return;
      _snack(l10n.wipeFailedError('$e'));
    }
  }

  GitHubReleaseUpdater _buildUpdater() {
    return GitHubReleaseUpdater(
      owner: _app.updaterGithubOwner,
      repo: _app.updaterGithubRepo,
    );
  }

  Future<void> _checkUpdatesNow() async {
    if (_checkingUpdates) return;
    setState(() => _checkingUpdates = true);
    try {
      final updater = _buildUpdater();
      final result = await updater.checkForUpdate(
        channel: _app.updateReleaseChannel,
      );
      if (!mounted) return;
      if (!result.supportedPlatform) {
        _snack('El actualizador integrado solo está disponible en Windows.');
        return;
      }
      if (!result.hasUpdate) {
        final r = result.reason;
        _snack(
          r != null && r.isNotEmpty ? r : 'Ya tienes la versión más reciente.',
        );
        return;
      }
      final betaNote = result.isPrerelease
          ? '\n\nEsta es una versión beta (pre-release).'
          : '';
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(
            result.isPrerelease
                ? 'Beta disponible'
                : 'Actualización disponible',
          ),
          content: Text(
            'Versión actual: ${result.currentVersion}\n'
            'Nueva versión: ${result.releaseVersion}$betaNote\n\n'
            '¿Descargar e instalar ahora?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Más tarde'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Actualizar ahora'),
            ),
          ],
        ),
      );
      if (go != true) return;
      final installer = await updater.downloadInstaller(result);
      await updater.launchInstallerAndExit(installer);
    } catch (e) {
      if (!mounted) return;
      _snack('No se pudo actualizar: $e');
    } finally {
      if (mounted) setState(() => _checkingUpdates = false);
    }
  }

  Future<void> _openChangeMasterPasswordFlow() async {
    if (_s.state != VaultFlowState.unlocked) return;
    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _ChangeMasterPasswordDialog(session: _s),
    );
    if (changed == true && mounted) {
      _snack(AppLocalizations.of(context).masterPasswordUpdatedSnack);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final desktopSections = <_SettingsSectionNavItem>[
      _SettingsSectionNavItem(label: l10n.appearance, keyIndex: 0),
      _SettingsSectionNavItem(label: l10n.security, keyIndex: 1),
      _SettingsSectionNavItem(label: l10n.desktopSection, keyIndex: 2),
      _SettingsSectionNavItem(
        label: l10n.keyboardShortcutsSection,
        keyIndex: 3,
      ),
      if (_app.isAiAvailable)
        _SettingsSectionNavItem(label: l10n.ai, keyIndex: 4),
      _SettingsSectionNavItem(label: l10n.vaultBackup, keyIndex: 5),
      _SettingsSectionNavItem(label: l10n.integrations, keyIndex: 6),
      _SettingsSectionNavItem(label: l10n.about, keyIndex: 7),
      _SettingsSectionNavItem(label: l10n.data, keyIndex: 8),
    ];
    return AnimatedBuilder(
      animation: _app,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: Text(l10n.settings)),
          body: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 1180;
              final settingsContent = ListenableBuilder(
                listenable: _s,
                builder: (context, _) {
                  return DecoratedBox(
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: scheme.outlineVariant.withValues(alpha: 0.35),
                      ),
                    ),
                    child: ListView(
                      controller: _settingsScrollController,
                      padding: const EdgeInsets.symmetric(
                        vertical: 24,
                        horizontal: 16,
                      ),
                      children: [
                        _SectionHeader(
                          key: _sectionKeys[0],
                          title: l10n.appearance,
                          scheme: scheme,
                        ),
                        Card(
                          margin: const EdgeInsets.only(bottom: 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  16,
                                  16,
                                  16,
                                ),
                                child: Text(
                                  l10n.settingsAppearanceHint,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: scheme.onSurfaceVariant,
                                      ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                child: SegmentedButton<ThemeMode>(
                                  segments: [
                                    ButtonSegment<ThemeMode>(
                                      value: ThemeMode.system,
                                      label: Text(l10n.systemTheme),
                                      icon: const Icon(
                                        Icons.brightness_auto,
                                        size: 18,
                                      ),
                                    ),
                                    ButtonSegment<ThemeMode>(
                                      value: ThemeMode.light,
                                      label: Text(l10n.lightTheme),
                                      icon: const Icon(
                                        Icons.light_mode_outlined,
                                        size: 18,
                                      ),
                                    ),
                                    ButtonSegment<ThemeMode>(
                                      value: ThemeMode.dark,
                                      label: Text(l10n.darkTheme),
                                      icon: const Icon(
                                        Icons.dark_mode_outlined,
                                        size: 18,
                                      ),
                                    ),
                                  ],
                                  selected: {_app.themeMode},
                                  onSelectionChanged: (s) {
                                    _app.setThemeMode(s.first);
                                  },
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Divider(height: 1),
                              ListTile(
                                leading: const Icon(Icons.translate_rounded),
                                title: Text(l10n.language),
                                subtitle: Text(
                                  _app.locale == null
                                      ? l10n.useSystemLanguage
                                      : (_app.locale!.languageCode == 'es'
                                            ? l10n.spanishLanguage
                                            : l10n.englishLanguage),
                                ),
                                trailing: DropdownButton<String?>(
                                  value: _app.locale?.languageCode,
                                  underline: const SizedBox.shrink(),
                                  onChanged: (code) {
                                    _app.setLocale(
                                      code == null ? null : Locale(code),
                                    );
                                  },
                                  items: [
                                    DropdownMenuItem<String?>(
                                      value: null,
                                      child: Text(l10n.useSystemLanguage),
                                    ),
                                    DropdownMenuItem<String?>(
                                      value: 'es',
                                      child: Text(l10n.spanishLanguage),
                                    ),
                                    DropdownMenuItem<String?>(
                                      value: 'en',
                                      child: Text(l10n.englishLanguage),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        _SectionHeader(
                          key: _sectionKeys[1],
                          title: l10n.security,
                          scheme: scheme,
                        ),
                        if (_s.vaultUsesEncryption)
                          Card(
                            margin: const EdgeInsets.only(bottom: 24),
                            child: Column(
                              children: [
                                ListTile(
                                  leading: const Icon(Icons.fingerprint),
                                  title: Text(l10n.quickUnlockTitle),
                                  subtitle: Text(
                                    _quickEnabled ? l10n.active : l10n.inactive,
                                  ),
                                  trailing: _quickEnabled
                                      ? TextButton(
                                          onPressed: () async {
                                            await _s.disableQuickUnlock();
                                            await _refreshSecurityFlags();
                                            _snack(
                                              l10n.quickUnlockDisabledSnack,
                                            );
                                          },
                                          child: Text(l10n.remove),
                                        )
                                      : FilledButton.tonal(
                                          onPressed: () async {
                                            try {
                                              await _s
                                                  .enableDeviceQuickUnlock();
                                              await _refreshSecurityFlags();
                                              _snack(
                                                l10n.quickUnlockEnabledSnack,
                                              );
                                            } catch (e) {
                                              _snack('');
                                            }
                                          },
                                          child: Text(l10n.enable),
                                        ),
                                ),
                                const Divider(height: 1),
                                ListTile(
                                  leading: const Icon(Icons.key_rounded),
                                  title: Text(l10n.passkey),
                                  subtitle: Text(l10n.passkeyThisDevice),
                                  trailing: _passkeyRegistered
                                      ? TextButton(
                                          onPressed: () async {
                                            await _s.revokePasskey();
                                            await _refreshSecurityFlags();
                                            _snack(l10n.passkeyRevokedSnack);
                                          },
                                          child: Text(l10n.revoke),
                                        )
                                      : FilledButton.tonal(
                                          onPressed: () async {
                                            try {
                                              await _s.registerPasskey();
                                              await _refreshSecurityFlags();
                                              _snack(
                                                l10n.passkeyRegisteredSnack,
                                              );
                                            } on PasskeyAuthCancelledException {
                                              // ignorar
                                            } catch (e) {
                                              _snack('Passkey: ');
                                            }
                                          },
                                          child: Text(l10n.register),
                                        ),
                                ),
                                const Divider(height: 1),
                                ListTile(
                                  leading: const Icon(Icons.lock_outline),
                                  title: Text(l10n.lockNow),
                                  onTap: () {
                                    _s.lock();
                                    Navigator.pop(context);
                                  },
                                ),
                                const Divider(height: 1),
                                ListTile(
                                  leading: const Icon(Icons.timer_outlined),
                                  title: Text(l10n.lockAutoByInactivity),
                                  subtitle: Text(
                                    l10n.minutesShort(
                                      _app.vaultIdleLockMinutes,
                                    ),
                                  ),
                                  trailing: DropdownButton<int>(
                                    value: _app.vaultIdleLockMinutes,
                                    underline: const SizedBox.shrink(),
                                    onChanged: (value) {
                                      if (value == null) return;
                                      _app.setVaultIdleLockMinutes(value);
                                    },
                                    items: _idleOptions
                                        .map(
                                          (m) => DropdownMenuItem<int>(
                                            value: m,
                                            child: Text(l10n.minutesShort(m)),
                                          ),
                                        )
                                        .toList(),
                                  ),
                                ),
                                const Divider(height: 1),
                                SwitchListTile(
                                  secondary: const Icon(Icons.minimize_rounded),
                                  title: Text(l10n.lockOnMinimize),
                                  value: _app.vaultLockOnMinimize,
                                  onChanged: _app.setVaultLockOnMinimize,
                                ),
                                const Divider(height: 1),
                                ListTile(
                                  leading: const Icon(Icons.password_rounded),
                                  title: Text(l10n.changeMasterPassword),
                                  subtitle: Text(l10n.requiresCurrentPassword),
                                  onTap: _openChangeMasterPasswordFlow,
                                ),
                              ],
                            ),
                          )
                        else
                          Card(
                            margin: const EdgeInsets.only(bottom: 24),
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    l10n.plainVaultSecurityNotice,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: scheme.onSurfaceVariant,
                                          height: 1.45,
                                        ),
                                  ),
                                  const SizedBox(height: 16),
                                  FilledButton.icon(
                                    onPressed: () =>
                                        _openEncryptPlainVaultDialog(),
                                    icon: const Icon(
                                      Icons.lock_rounded,
                                      size: 20,
                                    ),
                                    label: Text(l10n.encryptPlainVaultConfirm),
                                  ),
                                ],
                              ),
                            ),
                          ),

                        _SectionHeader(
                          key: _sectionKeys[2],
                          title: l10n.desktopSection,
                          scheme: scheme,
                        ),
                        Card(
                          margin: const EdgeInsets.only(bottom: 24),
                          child: Column(
                            children: [
                              SwitchListTile(
                                secondary: const Icon(Icons.keyboard_rounded),
                                title: Text(l10n.globalSearchHotkey),
                                subtitle: Text(
                                  _app.enableGlobalSearchHotkey
                                      ? _app.globalSearchHotkey
                                      : l10n.inactive,
                                ),
                                value: _app.enableGlobalSearchHotkey,
                                onChanged: _app.setEnableGlobalSearchHotkey,
                              ),
                              const Divider(height: 1),
                              ListTile(
                                leading: const Icon(Icons.tune_rounded),
                                title: Text(l10n.hotkeyCombination),
                                subtitle: Text(_app.globalSearchHotkey),
                                trailing: DropdownButton<String>(
                                  value: _app.globalSearchHotkey,
                                  underline: const SizedBox.shrink(),
                                  onChanged: _app.enableGlobalSearchHotkey
                                      ? (value) {
                                          if (value != null) {
                                            _app.setGlobalSearchHotkey(value);
                                          }
                                        }
                                      : null,
                                  items: [
                                    DropdownMenuItem(
                                      value: 'Alt+Space',
                                      child: Text(l10n.hotkeyAltSpace),
                                    ),
                                    DropdownMenuItem(
                                      value: 'Ctrl+Shift+Space',
                                      child: Text(l10n.hotkeyCtrlShiftSpace),
                                    ),
                                    DropdownMenuItem(
                                      value: 'Ctrl+Shift+K',
                                      child: Text(l10n.hotkeyCtrlShiftK),
                                    ),
                                    const DropdownMenuItem(
                                      value: 'Ctrl+Shift+F',
                                      child: Text('Ctrl + Shift + F'),
                                    ),
                                    const DropdownMenuItem(
                                      value: 'Ctrl+Alt+Space',
                                      child: Text('Ctrl + Alt + Space'),
                                    ),
                                  ],
                                ),
                              ),
                              const Divider(height: 1),
                              SwitchListTile(
                                secondary: const Icon(Icons.minimize_outlined),
                                title: Text(l10n.minimizeToTray),
                                value: _app.minimizeToTray,
                                onChanged: _app.setMinimizeToTray,
                              ),
                              const Divider(height: 1),
                              SwitchListTile(
                                secondary: const Icon(Icons.close_rounded),
                                title: Text(l10n.closeToTray),
                                value: _app.closeToTray,
                                onChanged: _app.setCloseToTray,
                              ),
                            ],
                          ),
                        ),

                        _SectionHeader(
                          key: _sectionKeys[3],
                          title: l10n.keyboardShortcutsSection,
                          scheme: scheme,
                        ),
                        Card(
                          margin: const EdgeInsets.only(bottom: 24),
                          child: Column(
                            children: [
                              for (final id in FolioInAppShortcut.values) ...[
                                if (id != FolioInAppShortcut.values.first)
                                  const Divider(height: 1),
                                ListTile(
                                  leading: const Icon(Icons.keyboard_rounded),
                                  title: Text(id.settingsLabel),
                                  subtitle: Text(
                                    _app.describeInAppShortcut(id),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      TextButton(
                                        onPressed: () {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                l10n.shortcutTestHint(
                                                  _app.describeInAppShortcut(
                                                    id,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                        child: Text(l10n.shortcutTestAction),
                                      ),
                                      TextButton(
                                        onPressed: () async {
                                          final next =
                                              await showDialog<SingleActivator>(
                                                context: context,
                                                builder: (ctx) =>
                                                    const InAppShortcutCaptureDialog(),
                                              );
                                          if (next != null && context.mounted) {
                                            await _app.setInAppShortcut(
                                              id,
                                              next,
                                            );
                                          }
                                        },
                                        child: Text(l10n.shortcutChangeAction),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              const Divider(height: 1),
                              ListTile(
                                leading: const Icon(Icons.restore_rounded),
                                title: Text(l10n.shortcutResetAllTitle),
                                subtitle: Text(l10n.shortcutResetAllSubtitle),
                                onTap: () async {
                                  await _app.resetInAppShortcutsToDefaults();
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          l10n.shortcutResetDoneSnack,
                                        ),
                                      ),
                                    );
                                  }
                                },
                              ),
                            ],
                          ),
                        ),

                        if (_app.isAiAvailable) ...[
                          _SectionHeader(
                            key: _sectionKeys[4],
                            title: 'IA',
                            scheme: scheme,
                          ),
                          Card(
                            margin: const EdgeInsets.only(bottom: 24),
                            child: Column(
                              children: [
                                SwitchListTile(
                                  secondary: const Icon(
                                    Icons.smart_toy_outlined,
                                  ),
                                  title: const Text('Habilitar IA'),
                                  subtitle: Text(
                                    _app.aiEnabled
                                        ? l10n.active
                                        : l10n.inactive,
                                  ),
                                  value: _app.aiEnabled,
                                  onChanged: _detectingAiProvider
                                      ? null
                                      : (v) async {
                                          if (v && !_app.aiEnabled) {
                                            final confirmed =
                                                await _confirmAiBetaEnable();
                                            if (!confirmed) return;
                                            await _app.setAiEnabled(true);
                                            await _saveAiFields();
                                            await _autoDetectAndConfigureAiProvider();
                                            return;
                                          }
                                          await _saveAiFields();
                                          await _app.setAiEnabled(v);
                                        },
                                ),
                                if (_detectingAiProvider)
                                  const Padding(
                                    padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                                    child: LinearProgressIndicator(),
                                  ),
                                const Divider(height: 1),
                                ListTile(
                                  leading: const Icon(
                                    Icons.assistant_navigation,
                                  ),
                                  title: Text(l10n.aiSetupAssistantTitle),
                                  subtitle: Text(l10n.aiSetupAssistantSubtitle),
                                  trailing: const Icon(
                                    Icons.chevron_right_rounded,
                                  ),
                                  onTap: _detectingAiProvider
                                      ? null
                                      : _autoDetectAndConfigureAiProvider,
                                ),
                                const Divider(height: 1),
                                SwitchListTile(
                                  secondary: const Icon(
                                    Icons.psychology_outlined,
                                  ),
                                  title: Text(l10n.aiAlwaysShowThought),
                                  subtitle: Text(l10n.aiAlwaysShowThoughtHint),
                                  value: _app.aiAlwaysShowThought,
                                  onChanged: _app.aiEnabled
                                      ? _app.setAiAlwaysShowThought
                                      : null,
                                ),
                                const Divider(height: 1),
                                SwitchListTile(
                                  secondary: const Icon(
                                    Icons.rocket_launch_outlined,
                                  ),
                                  title: Text(l10n.aiLaunchProviderWithApp),
                                  subtitle: Text(
                                    l10n.aiLaunchProviderWithAppHint,
                                  ),
                                  value: _app.aiLaunchProviderWithApp,
                                  onChanged: _app.aiEnabled
                                      ? (v) async {
                                          await _app.setAiLaunchProviderWithApp(
                                            v,
                                          );
                                        }
                                      : null,
                                ),
                                const Divider(height: 1),
                                ListTile(
                                  leading: const Icon(Icons.memory_outlined),
                                  title: Text(l10n.aiContextWindowTokens),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        l10n.aiContextWindowTokensHint,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: scheme.onSurfaceVariant,
                                            ),
                                      ),
                                      TextField(
                                        controller: _aiContextWindowController,
                                        enabled: _app.aiEnabled,
                                        keyboardType: TextInputType.number,
                                        decoration: const InputDecoration(
                                          hintText: '131072',
                                          border: InputBorder.none,
                                          enabledBorder: InputBorder.none,
                                          focusedBorder: InputBorder.none,
                                          contentPadding: EdgeInsets.zero,
                                        ),
                                        onSubmitted: (_) => _saveAiFields(),
                                      ),
                                    ],
                                  ),
                                ),
                                const Divider(height: 1),
                                ListTile(
                                  leading: const Icon(Icons.hub_outlined),
                                  title: const Text('Proveedor'),
                                  trailing: DropdownButton<AiProvider>(
                                    value: _app.aiProvider,
                                    underline: const SizedBox.shrink(),
                                    onChanged: (value) async {
                                      if (value == null) return;
                                      try {
                                        await _app.setAiProvider(value);
                                        if (!mounted) return;
                                        setState(() {
                                          _availableModels = _app
                                              .cachedAiModelsFor(value);
                                        });
                                        if (_availableModels.isNotEmpty &&
                                            !_availableModels.contains(
                                              _app.aiModel,
                                            )) {
                                          await _app.setAiModel(
                                            _availableModels.first,
                                          );
                                        }
                                        _aiBaseUrlController.text = _app
                                            .defaultUrlForProvider(value);
                                        await _saveAiFields();
                                      } catch (e) {
                                        if (!mounted) return;
                                        _snack('Error al cambiar proveedor: ');
                                      }
                                    },
                                    items: [
                                      DropdownMenuItem(
                                        value: AiProvider.none,
                                        child: Text(l10n.aiProviderNone),
                                      ),
                                      DropdownMenuItem(
                                        value: AiProvider.ollama,
                                        child: Text('Ollama'),
                                      ),
                                      DropdownMenuItem(
                                        value: AiProvider.lmStudio,
                                        child: Text('LM Studio'),
                                      ),
                                    ],
                                  ),
                                ),
                                const Divider(height: 1),
                                ListTile(
                                  leading: const Icon(Icons.link_rounded),
                                  title: Text(l10n.aiEndpoint),
                                  subtitle: TextField(
                                    controller: _aiBaseUrlController,
                                    decoration: const InputDecoration(
                                      hintText: 'http://127.0.0.1:11434',
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                    onSubmitted: (_) => _saveAiFields(),
                                  ),
                                ),
                                const Divider(height: 1),
                                ListTile(
                                  leading: const Icon(
                                    Icons.psychology_alt_outlined,
                                  ),
                                  title: Text(l10n.aiModel),
                                  subtitle: _loadingModels
                                      ? const Padding(
                                          padding: EdgeInsets.symmetric(
                                            vertical: 8,
                                          ),
                                          child: LinearProgressIndicator(),
                                        )
                                      : DropdownButton<String>(
                                          value:
                                              _availableModels.contains(
                                                _app.aiModel,
                                              )
                                              ? _app.aiModel
                                              : null,
                                          hint: Text(
                                            l10n.aiConnectToListModels,
                                          ),
                                          isExpanded: true,
                                          underline: const SizedBox.shrink(),
                                          onChanged: _availableModels.isEmpty
                                              ? null
                                              : (value) {
                                                  if (value != null) {
                                                    _app.setAiModel(value);
                                                  }
                                                },
                                          items: _availableModels
                                              .map(
                                                (m) => DropdownMenuItem<String>(
                                                  value: m,
                                                  child: Text(m),
                                                ),
                                              )
                                              .toList(),
                                        ),
                                ),
                                const Divider(height: 1),
                                ListTile(
                                  leading: const Icon(Icons.timer_outlined),
                                  title: Text(l10n.aiTimeoutMs),
                                  subtitle: TextField(
                                    controller: _aiTimeoutController,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      hintText: '30000',
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                    onSubmitted: (_) => _saveAiFields(),
                                  ),
                                ),
                                const Divider(height: 1),
                                SwitchListTile(
                                  secondary: const Icon(Icons.public_outlined),
                                  title: Text(l10n.aiAllowRemoteEndpoint),
                                  subtitle: Text(
                                    _app.aiEndpointMode ==
                                            AiEndpointMode.allowRemote
                                        ? l10n.aiAllowRemoteEndpointAllowed
                                        : l10n.aiAllowRemoteEndpointLocalhostOnly,
                                  ),
                                  value:
                                      _app.aiEndpointMode ==
                                      AiEndpointMode.allowRemote,
                                  onChanged: (v) async {
                                    await _app.setAiEndpointMode(
                                      v
                                          ? AiEndpointMode.allowRemote
                                          : AiEndpointMode.localhostOnly,
                                    );
                                    if (v) {
                                      await _confirmRemoteEndpointIfNeeded();
                                    }
                                  },
                                ),
                                if (_app.aiEndpointMode ==
                                        AiEndpointMode.allowRemote &&
                                    !_app.aiRemoteEndpointConfirmed)
                                  Padding(
                                    padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                                    child: Text(
                                      l10n.aiAllowRemoteEndpointNotConfirmed,
                                      style: TextStyle(color: Colors.orange),
                                    ),
                                  ),
                                const Divider(height: 1),
                                ListTile(
                                  leading: const Icon(
                                    Icons.network_check_rounded,
                                  ),
                                  title: Text(l10n.aiConnectToListModels),
                                  onTap: _testAiConnection,
                                ),
                              ],
                            ),
                          ),
                        ],

                        _SectionHeader(
                          key: _sectionKeys[5],
                          title: l10n.vaultBackup,
                          scheme: scheme,
                        ),
                        Card(
                          margin: const EdgeInsets.only(bottom: 24),
                          child: Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Text(
                                  l10n.backupInfoBody,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: scheme.onSurfaceVariant,
                                        height: 1.4,
                                      ),
                                ),
                              ),
                              const Divider(height: 1),
                              ListTile(
                                leading: const Icon(
                                  Icons.file_download_outlined,
                                ),
                                title: Text(l10n.exportZipTitle),
                                subtitle: Text(l10n.exportZipSubtitle),
                                onTap: _s.state == VaultFlowState.unlocked
                                    ? _openExportBackupFlow
                                    : null,
                              ),
                              const Divider(height: 1),
                              ListTile(
                                leading: const Icon(Icons.file_upload_outlined),
                                title: Text(l10n.importZipTitle),
                                subtitle: Text(l10n.importZipSubtitle),
                                onTap: _s.state == VaultFlowState.unlocked
                                    ? _openImportBackupFlow
                                    : null,
                              ),
                              const Divider(height: 1),
                              ListTile(
                                leading: const Icon(Icons.note_add_outlined),
                                title: Text(l10n.importNotionTitle),
                                subtitle: Text(l10n.importNotionSubtitle),
                                onTap: _s.state == VaultFlowState.unlocked
                                    ? _openImportNotionFlow
                                    : null,
                              ),
                            ],
                          ),
                        ),

                        _SectionHeader(
                          key: _sectionKeys[6],
                          title: l10n.integrations,
                          scheme: scheme,
                        ),
                        Card(
                          margin: const EdgeInsets.only(bottom: 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  16,
                                  16,
                                  8,
                                ),
                                child: Text(
                                  l10n.integrationsAppsApprovedHint,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: scheme.onSurfaceVariant,
                                        height: 1.4,
                                      ),
                                ),
                              ),
                              const Divider(height: 1),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  12,
                                  16,
                                  8,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      l10n.integrationsAppsApprovedTitle,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleSmall,
                                    ),
                                    const SizedBox(height: 8),
                                    if (_app
                                        .approvedIntegrationAppApprovals
                                        .isEmpty)
                                      Text(
                                        l10n.integrationsAppsApprovedNone,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: scheme.onSurfaceVariant,
                                            ),
                                      )
                                    else
                                      ..._app.approvedIntegrationAppApprovals.map(
                                        (entry) => ListTile(
                                          contentPadding: EdgeInsets.zero,
                                          leading: const Icon(
                                            Icons.verified_user_outlined,
                                          ),
                                          title: Text(entry.appName),
                                          subtitle: Text(
                                            l10n.integrationsApprovedAppDetails(
                                              entry.appId,
                                              entry.appVersion.isEmpty
                                                  ? l10n.integrationApprovalUnknownVersion
                                                  : entry.appVersion,
                                              entry.integrationVersion.isEmpty
                                                  ? l10n.integrationApprovalUnknownVersion
                                                  : entry.integrationVersion,
                                            ),
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  fontFamily: 'monospace',
                                                ),
                                          ),
                                          trailing: IconButton(
                                            tooltip: l10n
                                                .integrationsAppsApprovedRevoke,
                                            onPressed: () =>
                                                _revokeIntegrationApp(
                                                  entry.appId,
                                                ),
                                            icon: const Icon(
                                              Icons.delete_outline_rounded,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        _SectionHeader(
                          key: _sectionKeys[7],
                          title: l10n.about,
                          scheme: scheme,
                        ),
                        Card(
                          margin: const EdgeInsets.only(bottom: 24),
                          child: Column(
                            children: [
                              ListTile(
                                leading: const Icon(Icons.info_outline_rounded),
                                title: Text(l10n.installedVersion),
                                subtitle: Text(_installedVersionLabel),
                              ),
                              const Divider(height: 1),
                              ListTile(
                                leading: const Icon(Icons.cloud_outlined),
                                title: Text(l10n.updaterGithubRepository),
                                subtitle: Text(
                                  '${_app.updaterGithubOwner}/${_app.updaterGithubRepo}',
                                ),
                              ),
                              const Divider(height: 1),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  8,
                                  16,
                                  8,
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Text(
                                      'Canal',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleSmall,
                                    ),
                                    const SizedBox(height: 8),
                                    SegmentedButton<UpdateReleaseChannel>(
                                      segments: const [
                                        ButtonSegment<UpdateReleaseChannel>(
                                          value: UpdateReleaseChannel.stable,
                                          label: Text('Release'),
                                          icon: Icon(
                                            Icons.verified_outlined,
                                            size: 18,
                                          ),
                                        ),
                                        ButtonSegment<UpdateReleaseChannel>(
                                          value: UpdateReleaseChannel.beta,
                                          label: Text('Beta'),
                                          icon: Icon(
                                            Icons.science_outlined,
                                            size: 18,
                                          ),
                                        ),
                                      ],
                                      selected: {_app.updateReleaseChannel},
                                      onSelectionChanged: (s) {
                                        _app.setUpdateReleaseChannel(s.first);
                                      },
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _app.updateReleaseChannel ==
                                              UpdateReleaseChannel.beta
                                          ? l10n.updaterBetaDescription
                                          : l10n.updaterStableDescription,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: scheme.onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              const Divider(height: 1),
                              ListTile(
                                leading: const Icon(
                                  Icons.system_update_rounded,
                                ),
                                title: Text(l10n.checkUpdates),
                                trailing: _checkingUpdates
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : null,
                                onTap: _checkingUpdates
                                    ? null
                                    : _checkUpdatesNow,
                              ),
                            ],
                          ),
                        ),

                        _SectionHeader(
                          key: _sectionKeys[8],
                          title: l10n.data,
                          scheme: scheme,
                        ),
                        Card(
                          margin: const EdgeInsets.only(bottom: 24),
                          color: scheme.errorContainer.withValues(alpha: 0.2),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            side: BorderSide(
                              color: scheme.error.withValues(alpha: 0.5),
                            ),
                            borderRadius: const BorderRadius.all(
                              Radius.circular(24),
                            ),
                          ),
                          child: ListTile(
                            leading: Icon(
                              Icons.delete_forever_outlined,
                              color: scheme.error,
                            ),
                            title: Text(
                              l10n.wipeCardTitle,
                              style: TextStyle(
                                color: scheme.error,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              l10n.wipeCardSubtitle,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: scheme.error.withValues(alpha: 0.8),
                                  ),
                            ),
                            onTap: _openWipeFlow,
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  );
                },
              );
              if (!wide) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: settingsContent,
                );
              }
              return Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1480),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          width: 280,
                          child: _SettingsDesktopRail(
                            title: l10n.settings,
                            subtitle: l10n.settingsAppearanceHint,
                            currentSection: _selectedDesktopSection,
                            onSelectSection: _scrollToSection,
                            sections: desktopSections,
                          ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(child: settingsContent),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _BackupPasswordDialog extends StatefulWidget {
  const _BackupPasswordDialog();

  @override
  State<_BackupPasswordDialog> createState() => _BackupPasswordDialogState();
}

class _BackupPasswordDialogState extends State<_BackupPasswordDialog> {
  final _controller = TextEditingController();
  var _obscure = true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final t = _controller.text;
    if (t.isEmpty) return;
    Navigator.pop(context, t);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.backupPasswordDialogTitle),
      content: TextField(
        controller: _controller,
        obscureText: _obscure,
        autofocus: true,
        decoration: InputDecoration(
          labelText: l10n.backupFilePasswordLabel,
          helperText: l10n.backupFilePasswordHelper,
          suffixIcon: IconButton(
            onPressed: () => setState(() => _obscure = !_obscure),
            icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
            tooltip: _obscure ? l10n.showPassword : l10n.hidePassword,
          ),
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.importAction)),
      ],
    );
  }
}

enum _NotionImportMode { currentVault, newVault }

class _NotionImportModeDialog extends StatelessWidget {
  const _NotionImportModeDialog();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.importNotionSelectTargetTitle),
      content: Text(l10n.importNotionSelectTargetBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        OutlinedButton(
          onPressed: () =>
              Navigator.pop(context, _NotionImportMode.currentVault),
          child: Text(l10n.importNotionTargetCurrent),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _NotionImportMode.newVault),
          child: Text(l10n.importNotionTargetNew),
        ),
      ],
    );
  }
}

class _NewVaultPasswordDialog extends StatefulWidget {
  const _NewVaultPasswordDialog();

  @override
  State<_NewVaultPasswordDialog> createState() =>
      _NewVaultPasswordDialogState();
}

class _NewVaultPasswordDialogState extends State<_NewVaultPasswordDialog> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  var _obscureA = true;
  var _obscureB = true;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _submit() {
    final a = _password.text.trim();
    final b = _confirm.text.trim();
    if (a.length < 10) {
      setState(
        () => _error = 'La contrasena debe tener al menos 10 caracteres.',
      );
      return;
    }
    if (a != b) {
      setState(() => _error = 'Las contrasenas no coinciden.');
      return;
    }
    setState(() => _error = null);
    Navigator.pop(context, a);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.importNotionNewVaultPasswordTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _password,
            obscureText: _obscureA,
            decoration: InputDecoration(
              labelText: l10n.passwordLabel,
              suffixIcon: IconButton(
                onPressed: () => setState(() => _obscureA = !_obscureA),
                icon: Icon(_obscureA ? Icons.visibility : Icons.visibility_off),
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _confirm,
            obscureText: _obscureB,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: l10n.confirmPasswordLabel,
              suffixIcon: IconButton(
                onPressed: () => setState(() => _obscureB = !_obscureB),
                icon: Icon(_obscureB ? Icons.visibility : Icons.visibility_off),
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.importAction)),
      ],
    );
  }
}

enum _PasswordStrength { veryWeak, weak, fair, strong }

_PasswordStrength _passwordStrengthFor(String text) {
  var score = 0;
  if (text.length >= 10) score++;
  if (text.length >= 14) score++;
  if (RegExp(r'[a-z]').hasMatch(text) && RegExp(r'[A-Z]').hasMatch(text)) {
    score++;
  }
  if (RegExp(r'\d').hasMatch(text)) score++;
  if (RegExp(r'[^A-Za-z0-9]').hasMatch(text)) score++;
  if (score <= 1) return _PasswordStrength.veryWeak;
  if (score == 2) return _PasswordStrength.weak;
  if (score == 3 || score == 4) return _PasswordStrength.fair;
  return _PasswordStrength.strong;
}

class _EncryptPlainVaultDialog extends StatefulWidget {
  const _EncryptPlainVaultDialog({required this.session});

  final VaultSession session;

  @override
  State<_EncryptPlainVaultDialog> createState() =>
      _EncryptPlainVaultDialogState();
}

class _EncryptPlainVaultDialogState extends State<_EncryptPlainVaultDialog> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  var _busy = false;
  var _obscurePw = true;
  var _obscureConfirm = true;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final pw = _password.text;
    final c = _confirm.text;
    final l10n = AppLocalizations.of(context);
    if (pw.isEmpty || c.isEmpty) {
      setState(() => _error = l10n.fillAllFieldsError);
      return;
    }
    if (pw != c) {
      setState(() => _error = l10n.passwordMismatchError);
      return;
    }
    if (_passwordStrengthFor(pw) != _PasswordStrength.strong) {
      setState(() => _error = l10n.passwordMustBeStrongError);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.session.enableVaultEncryption(pw);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final strength = _passwordStrengthFor(_password.text);
    final strengthValue = switch (strength) {
      _PasswordStrength.veryWeak => 0.25,
      _PasswordStrength.weak => 0.5,
      _PasswordStrength.fair => 0.75,
      _PasswordStrength.strong => 1.0,
    };
    final strengthLabel = switch (strength) {
      _PasswordStrength.veryWeak => l10n.passwordStrengthVeryWeak,
      _PasswordStrength.weak => l10n.passwordStrengthWeak,
      _PasswordStrength.fair => l10n.passwordStrengthFair,
      _PasswordStrength.strong => l10n.passwordStrengthStrong,
    };
    return AlertDialog(
      title: Text(l10n.encryptPlainVaultTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.encryptPlainVaultBody,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _password,
              obscureText: _obscurePw,
              enabled: !_busy,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: l10n.newPasswordLabel,
                suffixIcon: IconButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() => _obscurePw = !_obscurePw),
                  icon: Icon(
                    _obscurePw ? Icons.visibility : Icons.visibility_off,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: strengthValue),
            const SizedBox(height: 4),
            Text(l10n.passwordStrengthWithValue(strengthLabel)),
            const SizedBox(height: 12),
            TextField(
              controller: _confirm,
              obscureText: _obscureConfirm,
              enabled: !_busy,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: l10n.confirmNewPasswordLabel,
                suffixIcon: IconButton(
                  onPressed: _busy
                      ? null
                      : () =>
                            setState(() => _obscureConfirm = !_obscureConfirm),
                  icon: Icon(
                    _obscureConfirm ? Icons.visibility : Icons.visibility_off,
                  ),
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: Text(l10n.encryptPlainVaultConfirm),
        ),
      ],
    );
  }
}

class _ChangeMasterPasswordDialog extends StatefulWidget {
  const _ChangeMasterPasswordDialog({required this.session});

  final VaultSession session;

  @override
  State<_ChangeMasterPasswordDialog> createState() =>
      _ChangeMasterPasswordDialogState();
}

class _ChangeMasterPasswordDialogState
    extends State<_ChangeMasterPasswordDialog> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  var _busy = false;
  var _obscureCurrent = true;
  var _obscureNext = true;
  var _obscureConfirm = true;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final currentPassword = _current.text;
    final nextPassword = _next.text;
    final confirmPassword = _confirm.text;
    if (currentPassword.isEmpty ||
        nextPassword.isEmpty ||
        confirmPassword.isEmpty) {
      setState(() => _error = AppLocalizations.of(context).fillAllFieldsError);
      return;
    }
    if (nextPassword != confirmPassword) {
      setState(
        () => _error = AppLocalizations.of(context).newPasswordsMismatchError,
      );
      return;
    }
    if (_passwordStrengthFor(nextPassword) != _PasswordStrength.strong) {
      setState(
        () =>
            _error = AppLocalizations.of(context).newPasswordMustBeStrongError,
      );
      return;
    }
    if (currentPassword == nextPassword) {
      setState(
        () => _error = AppLocalizations.of(context).newPasswordMustDifferError,
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.session.changeMasterPassword(
        currentPassword: currentPassword,
        newPassword: nextPassword,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final strength = _passwordStrengthFor(_next.text);
    final strengthValue = switch (strength) {
      _PasswordStrength.veryWeak => 0.25,
      _PasswordStrength.weak => 0.5,
      _PasswordStrength.fair => 0.75,
      _PasswordStrength.strong => 1.0,
    };
    final strengthLabel = switch (strength) {
      _PasswordStrength.veryWeak => l10n.passwordStrengthVeryWeak,
      _PasswordStrength.weak => l10n.passwordStrengthWeak,
      _PasswordStrength.fair => l10n.passwordStrengthFair,
      _PasswordStrength.strong => l10n.passwordStrengthStrong,
    };
    return AlertDialog(
      title: Text(l10n.changeMasterPassword),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _current,
              obscureText: _obscureCurrent,
              enabled: !_busy,
              decoration: InputDecoration(
                labelText: l10n.currentPasswordLabel,
                suffixIcon: IconButton(
                  onPressed: _busy
                      ? null
                      : () =>
                            setState(() => _obscureCurrent = !_obscureCurrent),
                  icon: Icon(
                    _obscureCurrent ? Icons.visibility : Icons.visibility_off,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _next,
              obscureText: _obscureNext,
              enabled: !_busy,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: l10n.newPasswordLabel,
                suffixIcon: IconButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() => _obscureNext = !_obscureNext),
                  icon: Icon(
                    _obscureNext ? Icons.visibility : Icons.visibility_off,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: strengthValue),
            const SizedBox(height: 4),
            Text(l10n.passwordStrengthWithValue(strengthLabel)),
            const SizedBox(height: 12),
            TextField(
              controller: _confirm,
              obscureText: _obscureConfirm,
              enabled: !_busy,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: l10n.confirmNewPasswordLabel,
                suffixIcon: IconButton(
                  onPressed: _busy
                      ? null
                      : () =>
                            setState(() => _obscureConfirm = !_obscureConfirm),
                  icon: Icon(
                    _obscureConfirm ? Icons.visibility : Icons.visibility_off,
                  ),
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: Text(l10n.cancel),
        ),
        FilledButton(onPressed: _busy ? null : _submit, child: Text(l10n.save)),
      ],
    );
  }
}

enum _AiWizardAction { close, retry }

class _AiSetupWizardDialog extends StatefulWidget {
  const _AiSetupWizardDialog({
    required this.summary,
    required this.selectedProvider,
    required this.title,
    required this.noProviderTitle,
    required this.noProviderBody,
    required this.ollamaInstallTitle,
    required this.ollamaInstallBody,
    required this.lmStudioInstallTitle,
    required this.lmStudioInstallBody,
    required this.openSettingsHint,
    required this.retryLabel,
    required this.closeLabel,
  });

  final AiProviderDetectionSummary summary;
  final AiProvider selectedProvider;
  final String title;
  final String noProviderTitle;
  final String noProviderBody;
  final String ollamaInstallTitle;
  final String ollamaInstallBody;
  final String lmStudioInstallTitle;
  final String lmStudioInstallBody;
  final String openSettingsHint;
  final String retryLabel;
  final String closeLabel;

  @override
  State<_AiSetupWizardDialog> createState() => _AiSetupWizardDialogState();
}

class _AiSetupWizardDialogState extends State<_AiSetupWizardDialog> {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isOllama = widget.selectedProvider == AiProvider.ollama;
    final selectedStatus = isOllama
        ? widget.summary.ollama
        : widget.summary.lmStudio;
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.noProviderTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(widget.noProviderBody),
            const SizedBox(height: 12),
            _ProviderStatusLine(
              label: isOllama ? 'Ollama' : 'LM Studio',
              installed: selectedStatus.installed,
              reachable: selectedStatus.reachable,
            ),
            const SizedBox(height: 12),
            Text(
              isOllama
                  ? widget.ollamaInstallTitle
                  : widget.lmStudioInstallTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              isOllama ? widget.ollamaInstallBody : widget.lmStudioInstallBody,
            ),
            const SizedBox(height: 10),
            SelectableText(
              isOllama ? 'https://ollama.com/download' : 'https://lmstudio.ai/',
              style: TextStyle(color: scheme.primary),
            ),
            const SizedBox(height: 14),
            Text(
              widget.openSettingsHint,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, _AiWizardAction.close),
          child: Text(widget.closeLabel),
        ),
        FilledButton.tonal(
          onPressed: () => Navigator.pop(context, _AiWizardAction.retry),
          child: Text(widget.retryLabel),
        ),
      ],
    );
  }
}

class _ProviderStatusLine extends StatelessWidget {
  const _ProviderStatusLine({
    required this.label,
    required this.installed,
    required this.reachable,
  });

  final String label;
  final bool installed;
  final bool reachable;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(child: Text(label)),
        Icon(
          installed ? Icons.download_done_rounded : Icons.download_for_offline,
          size: 16,
          color: installed ? scheme.primary : scheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Icon(
          reachable ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
          size: 16,
          color: reachable ? Colors.green : scheme.onSurfaceVariant,
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({super.key, required this.title, required this.scheme});

  final String title;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: scheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SettingsDesktopRail extends StatelessWidget {
  const _SettingsDesktopRail({
    required this.title,
    required this.subtitle,
    required this.sections,
    required this.currentSection,
    required this.onSelectSection,
  });

  final String title;
  final String subtitle;
  final List<_SettingsSectionNavItem> sections;
  final int currentSection;
  final ValueChanged<int> onSelectSection;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(Icons.tune_rounded, color: scheme.onPrimaryContainer),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 24),
          const SizedBox(height: 8),
          ...sections.asMap().entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => onSelectSection(entry.value.keyIndex),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: currentSection == entry.value.keyIndex
                          ? scheme.primaryContainer
                          : scheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: currentSection == entry.value.keyIndex
                            ? scheme.primary.withValues(alpha: 0.35)
                            : Colors.transparent,
                      ),
                    ),
                    child: Text(
                      entry.value.label,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: currentSection == entry.value.keyIndex
                            ? scheme.onPrimaryContainer
                            : scheme.onSurface,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsSectionNavItem {
  const _SettingsSectionNavItem({required this.label, required this.keyIndex});

  final String label;
  final int keyIndex;
}

class _VaultIdentityVerifyDialog extends StatefulWidget {
  const _VaultIdentityVerifyDialog({
    required this.session,
    required this.quickEnabled,
    required this.passkeyRegistered,
    required this.title,
    required this.body,
    required this.passwordButtonLabel,
  });

  final VaultSession session;
  final bool quickEnabled;
  final bool passkeyRegistered;
  final Widget title;
  final Widget body;
  final String passwordButtonLabel;

  @override
  State<_VaultIdentityVerifyDialog> createState() =>
      _VaultIdentityVerifyDialogState();
}

class _VaultIdentityVerifyDialogState
    extends State<_VaultIdentityVerifyDialog> {
  final _password = TextEditingController();
  var _busy = false;
  var _obscure = true;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _verifyPassword() async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await widget.session.verifyPasswordMatchesUnlockedSession(
      _password.text,
    );
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context, true);
      return;
    }
    setState(() {
      _busy = false;
      _error = l10n.incorrectPasswordError;
    });
  }

  Future<void> _verifyHello() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.session.verifyQuickUnlockMatchesSession();
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = '$e';
        });
      }
    }
  }

  Future<void> _verifyPasskey() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.session.verifyPasskeyMatchesSession();
      if (mounted) Navigator.pop(context, true);
    } on PasskeyAuthCancelledException {
      if (mounted) setState(() => _busy = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = '$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: widget.title,
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DefaultTextStyle.merge(
              style: Theme.of(
                context,
              ).textTheme.bodyMedium!.copyWith(color: scheme.onSurfaceVariant),
              child: widget.body,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _password,
              obscureText: _obscure,
              enabled: !_busy,
              decoration: InputDecoration(
                labelText: l10n.masterPassword,
                suffixIcon: IconButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() => _obscure = !_obscure),
                  icon: Icon(
                    _obscure ? Icons.visibility : Icons.visibility_off,
                  ),
                  tooltip: _obscure ? l10n.showPassword : l10n.hidePassword,
                ),
              ),
              onSubmitted: (_) => _verifyPassword(),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _busy ? null : _verifyPassword,
              child: Text(widget.passwordButtonLabel),
            ),
            if (widget.quickEnabled) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _busy ? null : _verifyHello,
                icon: const Icon(Icons.fingerprint),
                label: Text(l10n.useHelloBiometrics),
              ),
            ],
            if (widget.passkeyRegistered) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _busy ? null : _verifyPasskey,
                icon: const Icon(Icons.key_rounded),
                label: Text(l10n.usePasskey),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: scheme.error)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: Text(l10n.cancel),
        ),
      ],
    );
  }
}
