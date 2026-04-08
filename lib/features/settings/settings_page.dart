import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:passkeys/exceptions.dart';

import '../../app/app_settings.dart';
import '../../app/folio_in_app_shortcuts.dart';
import '../../app/ui_tokens.dart';
import '../../app/widgets/folio_dialog.dart';
import '../../app/widgets/folio_icon_token_view.dart';
import '../../app/widgets/folio_password_field.dart';
import 'in_app_shortcut_capture_dialog.dart';
import '../../crypto/vault_crypto.dart';
import '../../data/notion_import/notion_importer.dart';
import '../../data/vault_registry.dart';
import '../../data/vault_paths.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../data/vault_backup.dart';
import '../../services/ai/ai_service.dart';
import '../../services/ai/ai_provider_detector.dart';
import '../../services/ai/ai_safety_policy.dart';
import '../../services/ai/lmstudio_ai_service.dart';
import '../../services/ai/ollama_ai_service.dart';
import '../../services/custom_icon_import_service.dart';
import '../../services/device_sync/device_sync_controller.dart';
import '../../services/device_sync/device_sync_models.dart';
import '../../services/updater/github_release_updater.dart';
import '../../services/updater/update_release_channel.dart';
import '../../session/vault_session.dart';
import 'release_readiness.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.session,
    required this.appSettings,
    required this.deviceSyncController,
  });

  final VaultSession session;
  final AppSettings appSettings;
  final DeviceSyncController deviceSyncController;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  static const _idleOptions = <int>[1, 5, 10, 15, 30, 60];
  VaultSession get _s => widget.session;
  AppSettings get _app => widget.appSettings;
  DeviceSyncController get _sync => widget.deviceSyncController;
  final ScrollController _settingsScrollController = ScrollController();
  final List<GlobalKey> _sectionKeys = List.generate(10, (_) => GlobalKey());
  int _selectedDesktopSection = 0;
  bool _programmaticSectionScroll = false;

  var _quickEnabled = false;
  var _passkeyRegistered = false;
  late final TextEditingController _aiBaseUrlController;
  late final TextEditingController _aiTimeoutController;
  late final TextEditingController _aiContextWindowController;
  late final TextEditingController _customIconSourceController;
  late final TextEditingController _customIconLabelController;
  List<String> _availableModels = const [];
  bool _loadingModels = false;
  bool _checkingUpdates = false;
  bool _detectingAiProvider = false;
  bool _importingCustomIcon = false;
  String _installedVersionLabel = '...';
  bool _releaseStatusBusy = false;
  ReleaseReadinessSnapshot _releaseSnapshot = const ReleaseReadinessSnapshot(
    installedVersionLabel: '... ',
    isSemverValid: false,
    updateReleaseChannel: UpdateReleaseChannel.stable,
    activeVaultId: '-',
    activeVaultPath: '-',
    isVaultUnlocked: false,
    isVaultEncrypted: false,
    isAiEnabled: false,
    isAiEndpointPolicyValid: true,
    aiSummary: 'IA desactivada',
    checks: const <ReleaseCheckItem>[],
  );
  final CustomIconImportService _customIconImportService =
      CustomIconImportService();

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
    _customIconSourceController = TextEditingController();
    _customIconLabelController = TextEditingController();
    _availableModels = _app.cachedAiModelsFor(_app.aiProvider);
    _settingsScrollController.addListener(_handleSettingsScroll);
    _refreshSecurityFlags();
    _loadInstalledVersionInfo();
    _refreshReleaseReadiness();
  }

  @override
  void dispose() {
    _settingsScrollController.removeListener(_handleSettingsScroll);
    _settingsScrollController.dispose();
    _aiBaseUrlController.dispose();
    _aiTimeoutController.dispose();
    _aiContextWindowController.dispose();
    _customIconSourceController.dispose();
    _customIconLabelController.dispose();
    super.dispose();
  }

  Future<bool> _ensureSectionVisible(int index) async {
    if (!_settingsScrollController.hasClients) return false;
    final targetContext = _sectionKeys[index].currentContext;
    if (targetContext == null) return false;
    await Scrollable.ensureVisible(
      targetContext,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      alignment: 0.03,
    );
    return true;
  }

  Future<void> _scrollToSection(int index) async {
    if (index < 0 || index >= _sectionKeys.length) return;
    if (mounted) {
      setState(() => _selectedDesktopSection = index);
    }
    _programmaticSectionScroll = true;
    if (await _ensureSectionVisible(index)) {
      _programmaticSectionScroll = false;
      return;
    }

    // En algunos frames el target puede no tener context aun; reintenta una vez.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        if (!mounted) return;
        if (await _ensureSectionVisible(index)) return;
        if (!_settingsScrollController.hasClients) return;

        final max = _settingsScrollController.position.maxScrollExtent;
        if (max <= 0) return;
        final denom = (_sectionKeys.length - 1).clamp(1, _sectionKeys.length);
        final target = (index / denom) * max;
        await _settingsScrollController.animateTo(
          target.clamp(0.0, max),
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
        );
      } finally {
        _programmaticSectionScroll = false;
      }
    });
  }

  void _handleSettingsScroll() {
    if (!mounted || _programmaticSectionScroll) return;
    final active = _activeSectionFromViewport();
    if (active == null || active == _selectedDesktopSection) return;
    setState(() => _selectedDesktopSection = active);
  }

  int? _activeSectionFromViewport() {
    const thresholdTop = 156.0;
    final visible = <MapEntry<int, double>>[];
    for (var i = 0; i < _sectionKeys.length; i++) {
      final ctx = _sectionKeys[i].currentContext;
      if (ctx == null) continue;
      final render = ctx.findRenderObject();
      if (render is! RenderBox || !render.hasSize) continue;
      final dy = render.localToGlobal(Offset.zero).dy;
      visible.add(MapEntry(i, dy));
    }
    if (visible.isEmpty) return null;
    visible.sort((a, b) => a.value.compareTo(b.value));
    final passed = visible.where((s) => s.value <= thresholdTop).toList();
    if (passed.isNotEmpty) {
      return passed.last.key;
    }
    return visible.first.key;
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
      await _refreshReleaseReadiness();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _installedVersionLabel = 'desconocida';
      });
      await _refreshReleaseReadiness();
    }
  }

  Future<void> _refreshReleaseReadiness() async {
    if (mounted) setState(() => _releaseStatusBusy = true);

    final vaultId = _s.activeVaultId;
    var vaultPath = '-';
    try {
      final dir = await VaultPaths.vaultDirectory();
      vaultPath = dir.path;
    } catch (_) {
      vaultPath = '-';
    }

    final snapshot = evaluateReleaseReadiness(
      installedVersionLabel: _installedVersionLabel,
      updateReleaseChannel: _app.updateReleaseChannel,
      activeVaultId: vaultId,
      activeVaultPath: vaultPath,
      isVaultUnlocked: _s.state == VaultFlowState.unlocked,
      isVaultEncrypted: _s.vaultUsesEncryption,
      isAiEnabled: _app.aiEnabled,
      aiBaseUrl: _app.aiBaseUrl,
      aiEndpointMode: _app.aiEndpointMode,
      aiRemoteEndpointConfirmed: _app.aiRemoteEndpointConfirmed,
    );

    if (!mounted) return;
    setState(() {
      _releaseSnapshot = snapshot;
      _releaseStatusBusy = false;
    });
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _t(String es, String en) {
    final isEs = Localizations.localeOf(
      context,
    ).languageCode.toLowerCase().startsWith('es');
    return isEs ? es : en;
  }

  Future<void> _exportReleaseReadinessReport() async {
    final destination = await FilePicker.platform.saveFile(
      dialogTitle: 'Guardar reporte de release readiness',
      fileName: buildReleaseReadinessFileName(DateTime.now()),
      type: FileType.custom,
      allowedExtensions: const ['txt'],
    );
    if (destination == null || destination.trim().isEmpty) return;
    try {
      await File(destination).writeAsString(_releaseSnapshot.toReportText());
      if (!mounted) return;
      _snack('Reporte guardado correctamente.');
    } catch (e) {
      if (!mounted) return;
      _snack('No se pudo guardar el reporte: $e');
    }
  }

  Future<void> _revokeIntegrationApp(String appId) async {
    await _app.revokeIntegrationApp(appId);
    _snack('App revocada: $appId');
  }

  String _formatLastSyncLabel() {
    final ms = _app.syncLastSuccessMs;
    if (ms <= 0) {
      return _t('Aun sin sincronizar', 'Not synced yet');
    }
    final at = DateTime.fromMillisecondsSinceEpoch(ms).toLocal();
    final two = (int value) => value.toString().padLeft(2, '0');
    return '${two(at.day)}/${two(at.month)}/${at.year} ${two(at.hour)}:${two(at.minute)}';
  }

  Future<void> _editSyncDeviceName() async {
    var draft = _app.syncDeviceName;
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(_t('Nombre del dispositivo', 'Device name')),
          content: TextFormField(
            initialValue: draft,
            autofocus: true,
            maxLength: 40,
            decoration: InputDecoration(
              hintText: _t(
                'Ejemplo: Pixel de Alejandra',
                'Example: Alejandra Pixel',
              ),
            ),
            onChanged: (v) => draft = v,
            onFieldSubmitted: (_) => Navigator.of(ctx).pop(draft.trim()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(AppLocalizations.of(context).cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(draft.trim()),
              child: Text(AppLocalizations.of(context).save),
            ),
          ],
        );
      },
    );
    if (result == null) return;
    await _app.setSyncDeviceName(result);
  }

  void _activateEmojiPairingMode() {
    _sync.generatePairingCode();
    _snack(
      _t(
        'Modo vinculacion activado durante 2 minutos.',
        'Pairing mode enabled for 2 minutes.',
      ),
    );
  }

  Future<void> _submitPairingCodeDialog({SyncPeer? peer}) async {
    final targetPeer = peer;
    if (targetPeer == null) {
      _snack(
        _t(
          'Primero activa el modo vinculacion y luego elige un dispositivo detectado.',
          'First enable pairing mode and then choose a discovered device.',
        ),
      );
      return;
    }
    if (!_sync.isPairingModeActive) {
      _sync.generatePairingCode();
    }
    final sharedEmojis = _sync.sharedPairingEmojisForPeer(targetPeer);
    if (sharedEmojis.isEmpty) {
      _snack(
        _t(
          'Activa el modo vinculacion en ambos dispositivos y espera a que aparezcan los mismos 3 emojis.',
          'Enable pairing mode on both devices and wait until the same 3 emojis appear.',
        ),
      );
      return;
    }
    final started = await _sync.submitEmojiPairingRequest(targetPeer);
    if (!started) {
      if (!mounted) return;
      _snack(
        _t(
          'No se pudo iniciar la vinculacion. Activa el modo vinculacion en ambos dispositivos y espera a ver los mismos 3 emojis.',
          'Could not start pairing. Enable pairing mode on both devices and wait until the same 3 emojis appear.',
        ),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(_t('Confirmar vinculacion', 'Confirm pairing')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _t(
                  'Comprueba que en el otro dispositivo aparecen estos mismos 3 emojis:',
                  'Check that the other device shows these same 3 emojis:',
                ),
              ),
              const SizedBox(height: 12),
              SelectableText(
                sharedEmojis.join(' '),
                style: Theme.of(ctx).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _t(
                  'Este popup tambien aparecera en el otro dispositivo. Para completar el enlace, pulsa Vincular aqui y luego Vincular en el otro.',
                  'This popup will also appear on the other device. To complete linking, press Link here and then Link on the other one.',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                _sync.cancelOutgoingPair(targetPeer.peerId);
                Navigator.of(ctx).pop(false);
              },
              child: Text(AppLocalizations.of(context).cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(_t('Vincular', 'Link')),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;
    await _sync.confirmOutgoingPair(targetPeer.peerId);
    if (!mounted) return;
    _snack(
      _t(
        'Confirmacion enviada. Falta que el otro dispositivo pulse Vincular en su popup.',
        'Confirmation sent. The other device still needs to press Link in its popup.',
      ),
    );
  }

  Future<void> _revokeSyncPeer(SyncPeer peer) async {
    await _sync.revokePeer(peer.peerId);
    if (!mounted) return;
    _snack(_t('Dispositivo revocado.', 'Device revoked.'));
  }

  String _formatSyncConflictTimestamp(int ms) {
    final at = DateTime.fromMillisecondsSinceEpoch(ms).toLocal();
    final two = (int value) => value.toString().padLeft(2, '0');
    return '${two(at.day)}/${two(at.month)} ${two(at.hour)}:${two(at.minute)}';
  }

  Future<void> _showSyncConflictsDialog() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(_t('Resolver conflictos', 'Resolve conflicts')),
          content: SizedBox(
            width: 560,
            child: ListenableBuilder(
              listenable: _s,
              builder: (context, _) {
                final conflicts = _s.syncConflicts;
                if (conflicts.isEmpty) {
                  return Text(
                    _t(
                      'No hay conflictos pendientes.',
                      'There are no pending conflicts.',
                    ),
                  );
                }
                return SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: conflicts.map((conflict) {
                      final subtitle = _t(
                        'Origen: ${conflict.fromPeerId}\nPaginas remotas: ${conflict.remotePageCount}\nDetectado: ${_formatSyncConflictTimestamp(conflict.createdAtMs)}',
                        'Source: ${conflict.fromPeerId}\nRemote pages: ${conflict.remotePageCount}\nDetected: ${_formatSyncConflictTimestamp(conflict.createdAtMs)}',
                      );
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Theme.of(
                              context,
                            ).colorScheme.outlineVariant.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _t(
                                'Conflicto de sincronizacion',
                                'Sync conflict',
                              ),
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 8),
                            Text(subtitle),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                  onPressed: () async {
                                    await _s.resolveSyncConflictKeepLocal(
                                      conflict.id,
                                    );
                                    if (!mounted) return;
                                    _snack(
                                      _t(
                                        'Se conservo la version local.',
                                        'Local version kept.',
                                      ),
                                    );
                                  },
                                  child: Text(
                                    _t('Mantener local', 'Keep local'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                FilledButton.tonal(
                                  onPressed: () async {
                                    final ok = await _s
                                        .resolveSyncConflictAcceptRemote(
                                          conflict.id,
                                        );
                                    if (!mounted) return;
                                    _snack(
                                      ok
                                          ? _t(
                                              'Se aplico la version remota.',
                                              'Remote version applied.',
                                            )
                                          : _t(
                                              'No se pudo aplicar la version remota.',
                                              'Could not apply the remote version.',
                                            ),
                                    );
                                  },
                                  child: Text(
                                    _t('Aceptar remota', 'Accept remote'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(_t('Cerrar', 'Close')),
            ),
          ],
        );
      },
    );
  }

  Future<void> _importCustomIconFromSource(String source) async {
    final raw = source.trim();
    if (raw.isEmpty || _importingCustomIcon) return;
    setState(() => _importingCustomIcon = true);
    try {
      final entry = await _customIconImportService.importFromSource(
        source: raw,
        label: _customIconLabelController.text,
      );
      await _app.addOrUpdateCustomIcon(entry);
      if (!mounted) return;
      _customIconSourceController.clear();
      _customIconLabelController.clear();
      _snack(
        _t('Icono importado correctamente.', 'Icon imported successfully.'),
      );
    } catch (e) {
      if (!mounted) return;
      _snack('$e');
    } finally {
      if (mounted) setState(() => _importingCustomIcon = false);
    }
  }

  Future<void> _importCustomIconFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (text.isEmpty) {
      _snack(_t('El portapapeles está vacío.', 'Clipboard is empty.'));
      return;
    }
    _customIconSourceController.text = text;
    await _importCustomIconFromSource(text);
  }

  Future<void> _removeCustomIcon(CustomIconEntry entry) async {
    await _app.removeCustomIcon(entry.id);
    try {
      final file = File(entry.filePath);
      if (file.existsSync()) {
        await file.delete();
      }
    } catch (_) {
      // Ignorar: la referencia ya se eliminó de ajustes.
    }
    if (!mounted) return;
    _snack(_t('Icono eliminado.', 'Icon removed.'));
  }

  Future<bool> _vaultRequiresPassword(String vaultId) async {
    final dir = await VaultPaths.vaultDirectoryForId(vaultId);
    final modePath = File(
      '${dir.path}${Platform.pathSeparator}${VaultPaths.vaultModeFile}',
    );
    if (!modePath.existsSync()) return true;
    final raw = await modePath.readAsString();
    return raw.trim().toLowerCase() != 'plain';
  }

  Future<bool> _verifyVaultPasswordForDelete(String vaultId) async {
    final l10n = AppLocalizations.of(context);
    final dir = await VaultPaths.vaultDirectoryForId(vaultId);
    final keysPath = File(
      '${dir.path}${Platform.pathSeparator}${VaultPaths.wrappedDekFile}',
    );
    if (!keysPath.existsSync()) return true;

    final controller = TextEditingController();
    var obscure = true;
    String? password;
    while (mounted) {
      password = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDialogState) => FolioDialog(
            title: Text(l10n.confirmIdentity),
            content: FolioPasswordField(
              controller: controller,
              obscureText: obscure,
              autofocus: true,
              labelText: l10n.currentPasswordLabel,
              showPasswordTooltip: l10n.showPassword,
              hidePasswordTooltip: l10n.hidePassword,
              onToggleObscure: () {
                setDialogState(() => obscure = !obscure);
              },
              onSubmitted: (_) => Navigator.pop(ctx, controller.text.trim()),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, controller.text.trim()),
                child: Text(l10n.verifyAndDelete),
              ),
            ],
          ),
        ),
      );
      if (password == null) {
        controller.dispose();
        return false;
      }
      if (password.trim().isEmpty) {
        _snack(l10n.incorrectPasswordError);
        continue;
      }
      try {
        final wrapped = await keysPath.readAsBytes();
        await VaultCrypto.unwrapDek(
          wrapped: wrapped,
          password: password.trim(),
        );
        controller.dispose();
        return true;
      } catch (_) {
        _snack(l10n.incorrectPasswordError);
      }
    }
    controller.dispose();
    return false;
  }

  Future<void> _deleteOtherVault() async {
    final l10n = AppLocalizations.of(context);
    final active = _s.activeVaultId;
    final vaults = await _s.listVaultEntries();
    final others = vaults.where((e) => e.id != active).toList(growable: false);
    if (others.isEmpty) {
      _snack(l10n.noOtherVaultsSnack);
      return;
    }

    VaultEntry? picked;
    await showDialog<void>(
      context: context,
      builder: (ctx) => FolioDialog(
        title: Text(l10n.deleteOtherVaultTitle),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: others
                .map(
                  (e) => ListTile(
                    title: Text(e.displayName),
                    subtitle: Text(
                      e.id,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () {
                      picked = e;
                      Navigator.pop(ctx);
                    },
                  ),
                )
                .toList(growable: false),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
        ],
      ),
    );
    if (picked == null || !mounted) return;

    final target = picked!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => FolioDialog(
        title: Text(l10n.deleteVaultConfirmTitle),
        content: Text(l10n.deleteVaultConfirmBody(target.displayName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    final requiresPassword = await _vaultRequiresPassword(target.id);
    if (!mounted) return;
    if (requiresPassword) {
      final verified = await _verifyVaultPasswordForDelete(target.id);
      if (!verified || !mounted) return;
    }

    try {
      await _s.deleteVaultById(target.id);
      if (!mounted) return;
      _snack(l10n.vaultDeletedSnack);
    } catch (e) {
      if (!mounted) return;
      _snack('$e');
    }
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
      builder: (ctx) => FolioDialog(
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
    await _refreshReleaseReadiness();
  }

  Future<bool> _confirmAiBetaEnable() async {
    final l10n = AppLocalizations.of(context);
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => FolioDialog(
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

  Future<bool> _confirmQuillGlobalScopeIfNeeded() async {
    if (_app.hasAcceptedQuillGlobalScope) return true;
    final l10n = AppLocalizations.of(context);
    final accepted = await showDialog<bool>(
      context: context,
      builder: (ctx) => FolioDialog(
        title: Text(l10n.quillGlobalScopeNoticeTitle),
        content: Text(l10n.quillGlobalScopeNoticeBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.quillGlobalScopeNoticeConfirm),
          ),
        ],
      ),
    );
    if (accepted == true) {
      await _app.setHasAcceptedQuillGlobalScope(true);
      return true;
    }
    return false;
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
      builder: (ctx) => FolioDialog(
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
      builder: (ctx) => FolioDialog(
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
        title: Text(l10n.importNotionDialogTitle),
        body: Text(l10n.importNotionDialogBody),
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
        await _s.importNotionIntoCurrentVault(fp);
        if (!mounted) return;
        _snack(l10n.importNotionSuccessCurrent);
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
          displayName: l10n.importNotionDefaultVaultName,
        );
        if (!mounted) return;
        _snack(l10n.importNotionSuccessNew);
      }
    } on NotionImportException catch (e) {
      if (mounted) _snack(l10n.importNotionError('$e'));
    } catch (e) {
      if (mounted) _snack(l10n.importNotionError('$e'));
    }
    if (!mounted) return;
    final warnings = _s.lastImportWarnings;
    if (warnings.isNotEmpty) {
      await _showImportWarningsDialog(warnings);
    }
  }

  Future<void> _showImportWarningsDialog(
    List<NotionImportWarning> warnings,
  ) async {
    final l10n = AppLocalizations.of(context);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: Theme.of(ctx).colorScheme.tertiary,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(l10n.importNotionWarningsTitle)),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l10n.importNotionWarningsBody),
                const SizedBox(height: 12),
                ...warnings.map(
                  (w) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• '),
                        Expanded(child: Text(w.message)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.ok),
          ),
        ],
      ),
    );
  }

  Future<void> _openWipeFlow() async {
    final l10n = AppLocalizations.of(context);
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => FolioDialog(
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

    if (_s.vaultUsesEncryption) {
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
    }

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
        builder: (ctx) => FolioDialog(
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
    final windowWidth = MediaQuery.sizeOf(context).width;
    final showDesktopOnlySections = FolioAdaptive.shouldUseDesktopSections(
      windowWidth,
    );
    final desktopSections = <_SettingsSectionNavItem>[
      _SettingsSectionNavItem(label: l10n.appearance, keyIndex: 0),
      _SettingsSectionNavItem(label: l10n.security, keyIndex: 1),
      if (showDesktopOnlySections) ...[
        _SettingsSectionNavItem(label: l10n.desktopSection, keyIndex: 2),
        _SettingsSectionNavItem(
          label: l10n.keyboardShortcutsSection,
          keyIndex: 3,
        ),
      ],
      if (_app.isAiAvailable)
        _SettingsSectionNavItem(label: l10n.ai, keyIndex: 4),
      _SettingsSectionNavItem(label: l10n.vaultBackup, keyIndex: 5),
      if (showDesktopOnlySections)
        _SettingsSectionNavItem(label: l10n.integrations, keyIndex: 6),
      _SettingsSectionNavItem(
        label: _t('Sincronizacion', 'Device sync'),
        keyIndex: 7,
      ),
      _SettingsSectionNavItem(label: l10n.about, keyIndex: 8),
      _SettingsSectionNavItem(label: l10n.data, keyIndex: 9),
    ];
    return AnimatedBuilder(
      animation: _app,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: Text(l10n.settings)),
          body: LayoutBuilder(
            builder: (context, constraints) {
              final wide =
                  constraints.maxWidth >= FolioDesktop.mediumBreakpoint ||
                  FolioAdaptive.isAndroidDesktopLikeWidth(constraints.maxWidth);
              final settingsContent = ListenableBuilder(
                listenable: _s,
                builder: (context, _) {
                  return DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          scheme.surfaceContainer.withValues(alpha: 0.72),
                          scheme.surfaceContainerLow,
                        ],
                      ),
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
                        _SettingsOverviewBanner(appSettings: _app, session: _s),
                        const SizedBox(height: 8),
                        _SettingsPanel(
                          key: _sectionKeys[0],
                          margin: const EdgeInsets.only(bottom: 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _SettingsPanelHeroCard(
                                icon: Icons.palette_outlined,
                                title: l10n.appearance,
                                description: l10n.settingsAppearanceHint,
                                chips: [
                                  _SettingsInfoChip(
                                    icon: Icons.brightness_auto,
                                    label: _t('Tema', 'Theme'),
                                  ),
                                  _SettingsInfoChip(
                                    icon: Icons.translate_rounded,
                                    label: _t('Idioma', 'Language'),
                                  ),
                                  _SettingsInfoChip(
                                    icon: Icons.edit_outlined,
                                    label: _t(
                                      'Editor y espacio',
                                      'Editor & workspace',
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 1),
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
                              const SizedBox(height: 12),
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
                              _SettingsSubsectionTitle(
                                title: _t('Editor', 'Editor'),
                                scheme: scheme,
                              ),
                              const Divider(height: 1),
                              ListTile(
                                leading: const Icon(Icons.width_full_rounded),
                                title: Text(
                                  _t('Ancho del contenido', 'Content width'),
                                ),
                                subtitle: Text(
                                  _t(
                                    'Define cuánto ancho ocupan los bloques en el editor.',
                                    'Controls how wide blocks appear in the editor.',
                                  ),
                                ),
                                trailing: Text(
                                  '${_app.editorContentWidth.round()} px',
                                  style: Theme.of(context).textTheme.labelLarge
                                      ?.copyWith(
                                        color: scheme.onSurfaceVariant,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  0,
                                  16,
                                  8,
                                ),
                                child: Slider(
                                  value: _app.editorContentWidth,
                                  min: AppSettings.minEditorContentWidth,
                                  max: AppSettings.maxEditorContentWidth,
                                  divisions:
                                      ((AppSettings.maxEditorContentWidth -
                                                  AppSettings
                                                      .minEditorContentWidth) /
                                              20)
                                          .round(),
                                  label:
                                      '${_app.editorContentWidth.round()} px',
                                  onChanged: (value) {
                                    _app.setEditorContentWidth(value);
                                  },
                                ),
                              ),
                              const Divider(height: 1),
                              SwitchListTile(
                                secondary: const Icon(Icons.keyboard_return),
                                title: Text(
                                  _t(
                                    'Enter crea un bloque nuevo',
                                    'Enter creates a new block',
                                  ),
                                ),
                                subtitle: Text(
                                  _app.enterCreatesNewBlock
                                      ? _t(
                                          'Desactiva para que Enter inserte salto de línea.',
                                          'Disable to make Enter insert a line break.',
                                        )
                                      : _t(
                                          'Ahora Enter inserta salto de línea. Usa Shift+Enter igual.',
                                          'Enter now inserts a line break. Shift+Enter still works.',
                                        ),
                                ),
                                value: _app.enterCreatesNewBlock,
                                onChanged: _app.setEnterCreatesNewBlock,
                              ),
                              _SettingsSubsectionTitle(
                                title: _t('Espacio de trabajo', 'Workspace'),
                                scheme: scheme,
                              ),
                              const Divider(height: 1),
                              SwitchListTile(
                                secondary: const Icon(
                                  Icons.view_sidebar_rounded,
                                ),
                                title: Text(l10n.sidebarAutoRevealTitle),
                                subtitle: Text(l10n.sidebarAutoRevealSubtitle),
                                value: _app.workspaceSidebarAutoReveal,
                                onChanged: (v) =>
                                    _app.setWorkspaceSidebarAutoReveal(v),
                              ),
                            ],
                          ),
                        ),
                        _SettingsPanel(
                          margin: const EdgeInsets.only(bottom: 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _SettingsPanelHeroCard(
                                icon: Icons.emoji_symbols_rounded,
                                title: _t(
                                  'Iconos personalizados',
                                  'Custom icons',
                                ),
                                description: _t(
                                  'Importa una URL PNG, GIF o WebP, o un data:image compatible copiado desde páginas como notionicons.so. Después podrás usarlo como icono de página o de callout.',
                                  'Import a PNG, GIF, or WebP URL, or a compatible data:image copied from sites like notionicons.so. You can then use it as a page or callout icon.',
                                ),
                                trailingBadge: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: scheme.surface,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    _t(
                                      '${_app.customIcons.length} guardados',
                                      '${_app.customIcons.length} saved',
                                    ),
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelMedium
                                        ?.copyWith(
                                          color: scheme.primary,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                ),
                                chips: [
                                  _SettingsInfoChip(
                                    icon: Icons.link_rounded,
                                    label: _t(
                                      'URL PNG, GIF o WebP',
                                      'PNG, GIF, or WebP URL',
                                    ),
                                  ),
                                  _SettingsInfoChip(
                                    icon: Icons.code_rounded,
                                    label: 'data:image/*',
                                  ),
                                  _SettingsInfoChip(
                                    icon: Icons.content_paste_rounded,
                                    label: _t(
                                      'Pegar desde portapapeles',
                                      'Paste from clipboard',
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 1),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  0,
                                  16,
                                  16,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: scheme.surfaceContainerLow,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: scheme.outlineVariant.withValues(
                                        alpha: 0.45,
                                      ),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Text(
                                        _t(
                                          'Importar nuevo icono',
                                          'Import new icon',
                                        ),
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        _t(
                                          'Puedes ponerle nombre y pegar la fuente manualmente o traerla directamente desde el portapapeles.',
                                          'You can give it a name and paste the source manually or bring it directly from the clipboard.',
                                        ),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: scheme.onSurfaceVariant,
                                              height: 1.35,
                                            ),
                                      ),
                                      const SizedBox(height: 14),
                                      TextField(
                                        controller: _customIconLabelController,
                                        decoration: InputDecoration(
                                          labelText: _t('Nombre', 'Name'),
                                          hintText: _t('Opcional', 'Optional'),
                                          prefixIcon: const Icon(
                                            Icons.edit_outlined,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      TextField(
                                        controller: _customIconSourceController,
                                        minLines: 3,
                                        maxLines: 5,
                                        decoration: InputDecoration(
                                          labelText: _t(
                                            'URL o data:image',
                                            'URL or data:image',
                                          ),
                                          hintText:
                                              'https://...gif | ...webp | ...png o data:image/...',
                                          alignLabelWithHint: true,
                                          prefixIcon: const Padding(
                                            padding: EdgeInsets.only(
                                              bottom: 42,
                                            ),
                                            child: Icon(Icons.link_rounded),
                                          ),
                                        ),
                                        onSubmitted: (_) =>
                                            _importCustomIconFromSource(
                                              _customIconSourceController.text,
                                            ),
                                      ),
                                      const SizedBox(height: 14),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: FilledButton.icon(
                                              onPressed: _importingCustomIcon
                                                  ? null
                                                  : () => _importCustomIconFromSource(
                                                      _customIconSourceController
                                                          .text,
                                                    ),
                                              icon: _importingCustomIcon
                                                  ? const SizedBox(
                                                      width: 16,
                                                      height: 16,
                                                      child:
                                                          CircularProgressIndicator(
                                                            strokeWidth: 2,
                                                          ),
                                                    )
                                                  : const Icon(
                                                      Icons.download_rounded,
                                                    ),
                                              label: Text(
                                                _t(
                                                  'Importar icono',
                                                  'Import icon',
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: OutlinedButton.icon(
                                              onPressed: _importingCustomIcon
                                                  ? null
                                                  : _importCustomIconFromClipboard,
                                              icon: const Icon(
                                                Icons.content_paste_rounded,
                                              ),
                                              label: Text(
                                                _t(
                                                  'Desde portapapeles',
                                                  'From clipboard',
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  0,
                                  16,
                                  8,
                                ),
                                child: Row(
                                  children: [
                                    Text(
                                      _t('Biblioteca', 'Library'),
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _t(
                                        'Listos para usar en toda la app',
                                        'Ready to use across the app',
                                      ),
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
                              if (_app.customIcons.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    0,
                                    16,
                                    16,
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.all(18),
                                    decoration: BoxDecoration(
                                      color: scheme.surfaceContainerLow,
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(
                                        color: scheme.outlineVariant.withValues(
                                          alpha: 0.45,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 42,
                                          height: 42,
                                          decoration: BoxDecoration(
                                            color: scheme.surface,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Icon(
                                            Icons.inventory_2_outlined,
                                            color: scheme.onSurfaceVariant,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            _t(
                                              'Todavía no has importado iconos.',
                                              'No icons imported yet.',
                                            ),
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  color:
                                                      scheme.onSurfaceVariant,
                                                  height: 1.35,
                                                ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              else
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    0,
                                    16,
                                    16,
                                  ),
                                  child: Wrap(
                                    spacing: 12,
                                    runSpacing: 12,
                                    children: _app.customIcons.map((entry) {
                                      return Container(
                                        width: 182,
                                        padding: const EdgeInsets.all(14),
                                        decoration: BoxDecoration(
                                          color: scheme.surfaceContainerLow,
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          border: Border.all(
                                            color: scheme.outlineVariant,
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Row(
                                              children: [
                                                Container(
                                                  width: 44,
                                                  height: 44,
                                                  decoration: BoxDecoration(
                                                    color: scheme.surface,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          14,
                                                        ),
                                                  ),
                                                  child: Center(
                                                    child: FolioIconTokenView(
                                                      appSettings: _app,
                                                      token: entry.token,
                                                      fallbackText: '📄',
                                                      size: 26,
                                                    ),
                                                  ),
                                                ),
                                                const Spacer(),
                                                IconButton(
                                                  tooltip: _t(
                                                    'Eliminar icono',
                                                    'Delete icon',
                                                  ),
                                                  onPressed: () =>
                                                      _removeCustomIcon(entry),
                                                  icon: const Icon(
                                                    Icons
                                                        .delete_outline_rounded,
                                                    size: 20,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 10),
                                            Text(
                                              entry.label,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleSmall
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              entry.mimeType,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.copyWith(
                                                    color:
                                                        scheme.onSurfaceVariant,
                                                  ),
                                            ),
                                            const SizedBox(height: 10),
                                            SizedBox(
                                              width: double.infinity,
                                              child: OutlinedButton.icon(
                                                onPressed: () async {
                                                  await Clipboard.setData(
                                                    ClipboardData(
                                                      text: entry.token,
                                                    ),
                                                  );
                                                  if (!context.mounted) {
                                                    return;
                                                  }
                                                  _snack(
                                                    _t(
                                                      'Referencia copiada.',
                                                      'Reference copied.',
                                                    ),
                                                  );
                                                },
                                                icon: const Icon(
                                                  Icons.content_copy_rounded,
                                                  size: 18,
                                                ),
                                                label: Text(
                                                  _t(
                                                    'Copiar token',
                                                    'Copy token',
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                            ],
                          ),
                        ),

                        if (_s.vaultUsesEncryption)
                          _SettingsPanel(
                            key: _sectionKeys[1],
                            margin: const EdgeInsets.only(bottom: 24),
                            child: Column(
                              children: [
                                _SettingsPanelHeroCard(
                                  icon: Icons.shield_outlined,
                                  title: l10n.security,
                                  description: _t(
                                    'Desbloqueo rápido, passkey, bloqueo automático y contraseña maestra del vault cifrado.',
                                    'Quick unlock, passkey, auto-lock, and master password for your encrypted vault.',
                                  ),
                                  chips: [
                                    _SettingsInfoChip(
                                      icon: Icons.fingerprint,
                                      label: l10n.quickUnlockTitle,
                                    ),
                                    _SettingsInfoChip(
                                      icon: Icons.key_rounded,
                                      label: l10n.passkey,
                                    ),
                                    _SettingsInfoChip(
                                      icon: Icons.timer_outlined,
                                      label: l10n.lockAutoByInactivity,
                                    ),
                                  ],
                                ),
                                const Divider(height: 1),
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
                          _SettingsPanel(
                            key: _sectionKeys[1],
                            margin: const EdgeInsets.only(bottom: 24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _SettingsPanelHeroCard(
                                  icon: Icons.lock_open_rounded,
                                  title: _t(
                                    'Vault sin cifrar',
                                    'Unencrypted vault',
                                  ),
                                  description: l10n.plainVaultSecurityNotice,
                                  chips: [
                                    _SettingsInfoChip(
                                      icon: Icons.folder_open_outlined,
                                      label: _t(
                                        'Datos en disco',
                                        'Data on disk',
                                      ),
                                    ),
                                    _SettingsInfoChip(
                                      icon: Icons.enhanced_encryption_outlined,
                                      label: _t(
                                        'Cifrado disponible',
                                        'Encryption available',
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(height: 1),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    20,
                                    0,
                                    20,
                                    20,
                                  ),
                                  child: FilledButton.icon(
                                    onPressed: () =>
                                        _openEncryptPlainVaultDialog(),
                                    icon: const Icon(
                                      Icons.lock_rounded,
                                      size: 20,
                                    ),
                                    label: Text(l10n.encryptPlainVaultConfirm),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        if (showDesktopOnlySections) ...[
                          _SettingsPanel(
                            key: _sectionKeys[2],
                            margin: const EdgeInsets.only(bottom: 24),
                            child: Column(
                              children: [
                                _SettingsPanelHeroCard(
                                  icon: Icons.desktop_windows_rounded,
                                  title: l10n.desktopSection,
                                  description: _t(
                                    'Atajos globales, bandeja del sistema y comportamiento de la ventana en el escritorio.',
                                    'Global shortcuts, system tray, and window behavior on desktop.',
                                  ),
                                  chips: [
                                    _SettingsInfoChip(
                                      icon: Icons.search_rounded,
                                      label: l10n.globalSearchHotkey,
                                    ),
                                    _SettingsInfoChip(
                                      icon: Icons.minimize_rounded,
                                      label: l10n.minimizeToTray,
                                    ),
                                    _SettingsInfoChip(
                                      icon: Icons.close_rounded,
                                      label: l10n.closeToTray,
                                    ),
                                  ],
                                ),
                                const Divider(height: 1),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    12,
                                    16,
                                    12,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Icon(
                                            Icons.keyboard_rounded,
                                            color: scheme.onSurfaceVariant,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  l10n.globalSearchHotkey,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .titleMedium
                                                      ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  _app.enableGlobalSearchHotkey
                                                      ? l10n.hotkeyCombination
                                                      : l10n.inactive,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(
                                                        color: scheme
                                                            .onSurfaceVariant,
                                                      ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Switch(
                                            value:
                                                _app.enableGlobalSearchHotkey,
                                            onChanged: _app
                                                .setEnableGlobalSearchHotkey,
                                          ),
                                        ],
                                      ),
                                      if (_app.enableGlobalSearchHotkey) ...[
                                        const SizedBox(height: 12),
                                        Text(
                                          l10n.hotkeyCombination,
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelLarge
                                              ?.copyWith(
                                                color: scheme.onSurfaceVariant,
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                        const SizedBox(height: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                          ),
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                              color: scheme.outlineVariant,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: DropdownButton<String>(
                                            isExpanded: true,
                                            value: _app.globalSearchHotkey,
                                            underline: const SizedBox.shrink(),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            items: [
                                              DropdownMenuItem(
                                                value: 'Alt+Space',
                                                child: Text(
                                                  l10n.hotkeyAltSpace,
                                                ),
                                              ),
                                              DropdownMenuItem(
                                                value: 'Ctrl+Shift+Space',
                                                child: Text(
                                                  l10n.hotkeyCtrlShiftSpace,
                                                ),
                                              ),
                                              DropdownMenuItem(
                                                value: 'Ctrl+Shift+K',
                                                child: Text(
                                                  l10n.hotkeyCtrlShiftK,
                                                ),
                                              ),
                                              const DropdownMenuItem(
                                                value: 'Ctrl+Shift+F',
                                                child: Text('Ctrl + Shift + F'),
                                              ),
                                              const DropdownMenuItem(
                                                value: 'Ctrl+Alt+Space',
                                                child: Text(
                                                  'Ctrl + Alt + Space',
                                                ),
                                              ),
                                            ],
                                            onChanged: (value) {
                                              if (value != null) {
                                                _app.setGlobalSearchHotkey(
                                                  value,
                                                );
                                              }
                                            },
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const Divider(height: 1),
                                SwitchListTile(
                                  secondary: const Icon(
                                    Icons.minimize_outlined,
                                  ),
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

                          _SettingsPanel(
                            key: _sectionKeys[3],
                            margin: const EdgeInsets.only(bottom: 24),
                            child: Column(
                              children: [
                                _SettingsPanelHeroCard(
                                  icon: Icons.keyboard_rounded,
                                  title: l10n.keyboardShortcutsSection,
                                  description: _t(
                                    'Combinaciones solo dentro de Folio. Prueba una tecla antes de guardarla.',
                                    'Shortcuts only inside Folio. Test a key before saving it.',
                                  ),
                                  chips: [
                                    _SettingsInfoChip(
                                      icon: Icons.ads_click_rounded,
                                      label: _t('Probar', 'Test'),
                                    ),
                                    _SettingsInfoChip(
                                      icon: Icons.restart_alt_rounded,
                                      label: l10n.shortcutResetAllTitle,
                                    ),
                                  ],
                                ),
                                const Divider(height: 1),
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
                                                await showDialog<
                                                  SingleActivator
                                                >(
                                                  context: context,
                                                  builder: (ctx) =>
                                                      const InAppShortcutCaptureDialog(),
                                                );
                                            if (next != null &&
                                                context.mounted) {
                                              await _app.setInAppShortcut(
                                                id,
                                                next,
                                              );
                                            }
                                          },
                                          child: Text(
                                            l10n.shortcutChangeAction,
                                          ),
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
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
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
                        ],

                        if (_app.isAiAvailable) ...[
                          _SettingsPanel(
                            key: _sectionKeys[4],
                            margin: const EdgeInsets.only(bottom: 24),
                            child: Column(
                              children: [
                                _SettingsPanelHeroCard(
                                  icon: Icons.smart_toy_outlined,
                                  title: l10n.ai,
                                  description: _t(
                                    'Conecta Ollama o LM Studio en local; el asistente usa el modelo y el contexto que configures aquí.',
                                    'Connect Ollama or LM Studio locally; the assistant uses the model and context you set here.',
                                  ),
                                  chips: [
                                    _SettingsInfoChip(
                                      icon: Icons.hub_outlined,
                                      label: l10n.aiProviderLabel,
                                    ),
                                    _SettingsInfoChip(
                                      icon: Icons.psychology_outlined,
                                      label: l10n.aiModel,
                                    ),
                                    _SettingsInfoChip(
                                      icon: Icons.assistant_navigation,
                                      label: l10n.aiSetupAssistantTitle,
                                    ),
                                  ],
                                ),
                                const Divider(height: 1),
                                SwitchListTile(
                                  secondary: const Icon(
                                    Icons.smart_toy_outlined,
                                  ),
                                  title: Text(l10n.aiEnableToggleTitle),
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
                                            final acceptedScope =
                                                await _confirmQuillGlobalScopeIfNeeded();
                                            if (!acceptedScope) return;
                                            if (!_app.hasCompletedQuillSetup) {
                                              final configured =
                                                  await _autoDetectAndConfigureAiProvider();
                                              if (!configured) return;
                                              await _app
                                                  .setHasCompletedQuillSetup(
                                                    true,
                                                  );
                                            }
                                            await _saveAiFields();
                                            await _app.setAiEnabled(true);
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
                                  title: Text(l10n.aiProviderLabel),
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

                        _SettingsPanel(
                          key: _sectionKeys[5],
                          margin: const EdgeInsets.only(bottom: 24),
                          child: Column(
                            children: [
                              _SettingsPanelHeroCard(
                                icon: Icons.backup_outlined,
                                title: l10n.vaultBackup,
                                description: l10n.backupInfoBody,
                                chips: [
                                  _SettingsInfoChip(
                                    icon: Icons.file_download_outlined,
                                    label: l10n.exportZipTitle,
                                  ),
                                  _SettingsInfoChip(
                                    icon: Icons.file_upload_outlined,
                                    label: l10n.importZipTitle,
                                  ),
                                  _SettingsInfoChip(
                                    icon: Icons.note_add_outlined,
                                    label: l10n.importNotionTitle,
                                  ),
                                ],
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
                              const Divider(height: 1),
                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      l10n.notionExportGuideTitle,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      l10n.notionExportGuideBody,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: scheme.onSurfaceVariant,
                                            height: 1.4,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        if (showDesktopOnlySections) ...[
                          _SettingsPanel(
                            key: _sectionKeys[6],
                            margin: const EdgeInsets.only(bottom: 24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _IntegrationsHero(
                                  approvedCount: _app
                                      .approvedIntegrationAppApprovals
                                      .length,
                                  hintText: l10n.integrationsAppsApprovedHint,
                                  title: l10n.integrations,
                                  featureChips: [
                                    _SettingsInfoChip(
                                      icon: Icons.verified_user_outlined,
                                      label: _t(
                                        'Permisos aprobados',
                                        'Approved permissions',
                                      ),
                                    ),
                                    _SettingsInfoChip(
                                      icon: Icons.lock_open_outlined,
                                      label: _t(
                                        'Acceso revocable',
                                        'Revocable access',
                                      ),
                                    ),
                                    _SettingsInfoChip(
                                      icon: Icons.devices_outlined,
                                      label: _t(
                                        'Apps externas',
                                        'External apps',
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(height: 1),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    0,
                                    16,
                                    16,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            _t(
                                              'Conexiones activas',
                                              'Active connections',
                                            ),
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleSmall
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            _t(
                                              'Apps que ya pueden interactuar con Folio',
                                              'Apps already allowed to interact with Folio',
                                            ),
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  color:
                                                      scheme.onSurfaceVariant,
                                                ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      if (_app
                                          .approvedIntegrationAppApprovals
                                          .isEmpty)
                                        Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.all(18),
                                          decoration: BoxDecoration(
                                            color: scheme.surfaceContainerLow,
                                            borderRadius: BorderRadius.circular(
                                              18,
                                            ),
                                            border: Border.all(
                                              color: scheme.outlineVariant
                                                  .withValues(alpha: 0.45),
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Container(
                                                width: 44,
                                                height: 44,
                                                decoration: BoxDecoration(
                                                  color: scheme.surface,
                                                  borderRadius:
                                                      BorderRadius.circular(14),
                                                ),
                                                child: Icon(
                                                  Icons.hub_outlined,
                                                  color:
                                                      scheme.onSurfaceVariant,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Text(
                                                  l10n.integrationsAppsApprovedNone,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(
                                                        color: scheme
                                                            .onSurfaceVariant,
                                                        height: 1.35,
                                                      ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        )
                                      else
                                        Wrap(
                                          spacing: 12,
                                          runSpacing: 12,
                                          children: _app
                                              .approvedIntegrationAppApprovals
                                              .map(
                                                (entry) => _IntegrationAppCard(
                                                  entry: entry,
                                                  detailsText: l10n.integrationsApprovedAppDetails(
                                                    entry.appId,
                                                    entry.appVersion.isEmpty
                                                        ? l10n.integrationApprovalUnknownVersion
                                                        : entry.appVersion,
                                                    entry
                                                            .integrationVersion
                                                            .isEmpty
                                                        ? l10n.integrationApprovalUnknownVersion
                                                        : entry
                                                              .integrationVersion,
                                                  ),
                                                  revokeLabel: l10n
                                                      .integrationsAppsApprovedRevoke,
                                                  onRevoke: () =>
                                                      _revokeIntegrationApp(
                                                        entry.appId,
                                                      ),
                                                ),
                                              )
                                              .toList(),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        AnimatedBuilder(
                          key: _sectionKeys[7],
                          animation: _sync,
                          builder: (context, _) => _SettingsPanel(
                            margin: const EdgeInsets.only(bottom: 24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _SettingsPanelHeroCard(
                                  icon: Icons.sync_rounded,
                                  title: _t(
                                    'Sincronización entre dispositivos',
                                    'Device synchronization',
                                  ),
                                  description: _t(
                                    'Empareja equipos en la red local; el relay solo ayuda a negociar la conexión, no envía el contenido del vault.',
                                    'Pair machines on the local network; the relay only helps negotiate the connection and does not send vault content.',
                                  ),
                                  chips: [
                                    _SettingsInfoChip(
                                      icon: Icons.shield_outlined,
                                      label: _t(
                                        'Código de enlace',
                                        'Pairing code',
                                      ),
                                    ),
                                    _SettingsInfoChip(
                                      icon: Icons.search_rounded,
                                      label: _t(
                                        'Detección automática',
                                        'Auto discovery',
                                      ),
                                    ),
                                    _SettingsInfoChip(
                                      icon: Icons.cloud_outlined,
                                      label: _t(
                                        'Relay opcional',
                                        'Optional relay',
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(height: 1),
                                SwitchListTile(
                                  secondary: const Icon(Icons.sync_rounded),
                                  title: Text(
                                    _t(
                                      'Activar sincronizacion entre dispositivos',
                                      'Enable device sync',
                                    ),
                                  ),
                                  subtitle: Text(
                                    _app.syncEnabled
                                        ? (_sync.discoveredPeers.isEmpty
                                              ? _t(
                                                  'Buscando dispositivos con Folio abierto en la red local...',
                                                  'Searching for nearby devices with Folio open on local network...',
                                                )
                                              : _t(
                                                  '${_sync.discoveredPeers.length} dispositivos detectados en LAN.',
                                                  '${_sync.discoveredPeers.length} devices discovered on LAN.',
                                                ))
                                        : _t(
                                            'La sincronizacion esta desactivada.',
                                            'Synchronization is currently disabled.',
                                          ),
                                  ),
                                  value: _app.syncEnabled,
                                  onChanged: _app.setSyncEnabled,
                                ),
                                const Divider(height: 1),
                                SwitchListTile(
                                  secondary: const Icon(Icons.hub_outlined),
                                  title: Text(
                                    _t(
                                      'Usar relay de senalizacion',
                                      'Use signaling relay',
                                    ),
                                  ),
                                  subtitle: Text(
                                    _t(
                                      'No envia contenido del vault, solo ayuda a negociar la conexion si la LAN falla.',
                                      'Does not send vault content, only helps negotiate connectivity when LAN fails.',
                                    ),
                                  ),
                                  value: _app.syncRelayEnabled,
                                  onChanged: _app.syncEnabled
                                      ? _app.setSyncRelayEnabled
                                      : null,
                                ),
                                const Divider(height: 1),
                                ListTile(
                                  leading: const Icon(Icons.devices_outlined),
                                  title: Text(
                                    _t('Nombre del dispositivo', 'Device name'),
                                  ),
                                  subtitle: Text(_app.syncDeviceName),
                                  trailing: TextButton(
                                    onPressed: _editSyncDeviceName,
                                    child: Text(_t('Editar', 'Edit')),
                                  ),
                                ),
                                const Divider(height: 1),
                                ListTile(
                                  leading: const Icon(Icons.pin_outlined),
                                  title: Text(
                                    _t(
                                      'Activar modo vinculacion por emojis',
                                      'Enable emoji pairing mode',
                                    ),
                                  ),
                                  subtitle: Text(
                                    _t(
                                      'Activalo en ambos dispositivos para iniciar el proceso de vinculacion sin escribir codigos.',
                                      'Enable it on both devices to start pairing without typing codes.',
                                    ),
                                  ),
                                  onTap: _app.syncEnabled
                                      ? _activateEmojiPairingMode
                                      : null,
                                ),
                                const Divider(height: 1),
                                ListTile(
                                  leading: const Icon(
                                    Icons.emoji_emotions_outlined,
                                  ),
                                  title: Text(
                                    _t(
                                      'Estado del modo vinculacion',
                                      'Pairing mode status',
                                    ),
                                  ),
                                  subtitle: Text(
                                    _sync.isPairingModeActive
                                        ? _t(
                                            'Activo durante 2 minutos. Ya puedes iniciar la vinculacion desde un dispositivo detectado.',
                                            'Active for 2 minutes. You can now start pairing from a detected device.',
                                          )
                                        : _t(
                                            'Inactivo. Activalo aqui y en el otro dispositivo para empezar a vincular.',
                                            'Inactive. Enable it here and on the other device to start pairing.',
                                          ),
                                  ),
                                ),
                                const Divider(height: 1),
                                ListTile(
                                  leading: const Icon(Icons.history_toggle_off),
                                  title: Text(
                                    _t(
                                      'Ultima sincronizacion',
                                      'Last synchronization',
                                    ),
                                  ),
                                  subtitle: Text(_formatLastSyncLabel()),
                                ),
                                const Divider(height: 1),
                                ListTile(
                                  leading: const Icon(
                                    Icons.warning_amber_rounded,
                                  ),
                                  title: Text(
                                    _t(
                                      'Conflictos pendientes',
                                      'Pending conflicts',
                                    ),
                                  ),
                                  subtitle: Text(
                                    _app.syncPendingConflicts <= 0
                                        ? _t(
                                            'Sin conflictos pendientes.',
                                            'No pending conflicts.',
                                          )
                                        : _t(
                                            '${_app.syncPendingConflicts} conflictos requieren revision manual.',
                                            '${_app.syncPendingConflicts} conflicts require manual review.',
                                          ),
                                  ),
                                  trailing: _app.syncPendingConflicts > 0
                                      ? TextButton(
                                          onPressed: _showSyncConflictsDialog,
                                          child: Text(
                                            _t('Resolver', 'Resolve'),
                                          ),
                                        )
                                      : null,
                                  onTap: _app.syncPendingConflicts > 0
                                      ? _showSyncConflictsDialog
                                      : null,
                                ),
                                const Divider(height: 1),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    12,
                                    16,
                                    6,
                                  ),
                                  child: Text(
                                    _t(
                                      'Dispositivos detectados',
                                      'Discovered devices',
                                    ),
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    0,
                                    16,
                                    10,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      if (_sync.discoveredPeers.isEmpty)
                                        Text(
                                          _t(
                                            'No se detectaron dispositivos todavia. Asegura que ambas apps esten abiertas en la misma red.',
                                            'No devices detected yet. Make sure both apps are open on the same network.',
                                          ),
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodySmall,
                                        )
                                      else
                                        ..._sync.discoveredPeers.map((peer) {
                                          final hasActiveCode =
                                              (peer.pairingCode ?? '')
                                                  .trim()
                                                  .isNotEmpty;
                                          final pairingReady =
                                              _sync.isPairingModeActive &&
                                              hasActiveCode;
                                          final subtitle = pairingReady
                                              ? _t(
                                                  'Listo para vincular.',
                                                  'Ready to link.',
                                                )
                                              : hasActiveCode
                                              ? _t(
                                                  'El otro dispositivo esta en modo vinculacion. Activalo aqui para iniciar el enlace.',
                                                  'The other device is in pairing mode. Enable it here to start linking.',
                                                )
                                              : _t(
                                                  'Detectado en la red local.',
                                                  'Detected on the local network.',
                                                );
                                          return Container(
                                            margin: const EdgeInsets.only(
                                              bottom: 8,
                                            ),
                                            decoration: BoxDecoration(
                                              color: scheme.surfaceContainerLow,
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                              border: Border.all(
                                                color: scheme.outlineVariant
                                                    .withValues(alpha: 0.5),
                                              ),
                                            ),
                                            child: ListTile(
                                              dense: true,
                                              leading: const Icon(
                                                Icons.wifi_tethering,
                                              ),
                                              title: Text(peer.deviceName),
                                              subtitle: Text(subtitle),
                                              trailing: FilledButton.tonal(
                                                onPressed:
                                                    _app.syncEnabled &&
                                                        pairingReady
                                                    ? () =>
                                                          _submitPairingCodeDialog(
                                                            peer: peer,
                                                          )
                                                    : null,
                                                child: Text(
                                                  _t('Vincular', 'Link'),
                                                ),
                                              ),
                                            ),
                                          );
                                        }),
                                    ],
                                  ),
                                ),
                                const Divider(height: 1),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    12,
                                    16,
                                    16,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _t(
                                          'Dispositivos vinculados',
                                          'Linked devices',
                                        ),
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                      const SizedBox(height: 10),
                                      if (_sync.peers.isEmpty)
                                        Text(
                                          _t(
                                            'Aun no hay dispositivos enlazados.',
                                            'No linked devices yet.',
                                          ),
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodySmall,
                                        )
                                      else
                                        ..._sync.peers.map((peer) {
                                          return Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 8,
                                            ),
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color:
                                                    scheme.surfaceContainerLow,
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                                border: Border.all(
                                                  color: scheme.outlineVariant
                                                      .withValues(alpha: 0.5),
                                                ),
                                              ),
                                              child: ListTile(
                                                dense: true,
                                                leading: const Icon(
                                                  Icons.devices,
                                                ),
                                                title: Text(peer.deviceName),
                                                subtitle: Text(
                                                  '${_t('ID', 'ID')}: ${peer.peerId}',
                                                ),
                                                trailing: TextButton(
                                                  onPressed: () =>
                                                      _revokeSyncPeer(peer),
                                                  child: Text(
                                                    _t('Revocar', 'Revoke'),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          );
                                        }),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        _SettingsPanel(
                          key: _sectionKeys[8],
                          margin: const EdgeInsets.only(bottom: 24),
                          child: Column(
                            children: [
                              _SettingsPanelHeroCard(
                                icon: Icons.info_outline_rounded,
                                title: l10n.about,
                                description: _t(
                                  'Versión instalada, origen de actualizaciones y comprobación manual de novedades.',
                                  'Installed version, update source, and manual checks for new releases.',
                                ),
                                chips: [
                                  _SettingsInfoChip(
                                    icon: Icons.tag_rounded,
                                    label: l10n.installedVersion,
                                  ),
                                  _SettingsInfoChip(
                                    icon: Icons.system_update_rounded,
                                    label: l10n.checkUpdates,
                                  ),
                                ],
                              ),
                              const Divider(height: 1),
                              ListTile(
                                leading: const Icon(Icons.info_outline_rounded),
                                title: Text(l10n.installedVersion),
                                subtitle: Text(_installedVersionLabel),
                              ),
                              if (showDesktopOnlySections) ...[
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
                            ],
                          ),
                        ),

                        _SettingsPanel(
                          key: _sectionKeys[9],
                          margin: const EdgeInsets.only(bottom: 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _SettingsPanelHeroCard(
                                icon: Icons.storage_rounded,
                                title: l10n.data,
                                description: _t(
                                  'Acciones permanentes sobre archivos locales. Haz una copia de seguridad antes de borrar.',
                                  'Permanent actions on local files. Make a backup before deleting.',
                                ),
                                chips: [
                                  _SettingsInfoChip(
                                    icon: Icons.delete_forever_outlined,
                                    label: l10n.wipeCardTitle,
                                  ),
                                  _SettingsInfoChip(
                                    icon: Icons.delete_outline,
                                    label: l10n.deleteOtherVault,
                                  ),
                                ],
                              ),
                              const Divider(height: 1),
                              _SettingsSubsectionTitle(
                                title: _t('Zona de peligro', 'Danger zone'),
                                scheme: scheme,
                                topPadding: 8,
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  0,
                                  16,
                                  8,
                                ),
                                child: Card(
                                  color: scheme.errorContainer.withValues(
                                    alpha: 0.2,
                                  ),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    side: BorderSide(
                                      color: scheme.error.withValues(
                                        alpha: 0.5,
                                      ),
                                    ),
                                    borderRadius: const BorderRadius.all(
                                      Radius.circular(20),
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
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: scheme.error.withValues(
                                              alpha: 0.8,
                                            ),
                                          ),
                                    ),
                                    onTap: _openWipeFlow,
                                  ),
                                ),
                              ),
                              const Divider(height: 1),
                              ListTile(
                                leading: const Icon(Icons.delete_outline),
                                title: Text(l10n.deleteOtherVault),
                                subtitle: Text(l10n.deleteOtherVaultTitle),
                                onTap: _deleteOtherVault,
                              ),
                            ],
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
                            subtitle: _t(
                              'Elige una categoría en la lista o desplázate por el contenido.',
                              'Pick a category from the list or scroll the content.',
                            ),
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
    return FolioDialog(
      title: Text(l10n.backupPasswordDialogTitle),
      content: FolioPasswordField(
        controller: _controller,
        obscureText: _obscure,
        autofocus: true,
        labelText: l10n.backupFilePasswordLabel,
        showPasswordTooltip: l10n.showPassword,
        hidePasswordTooltip: l10n.hidePassword,
        helperText: l10n.backupFilePasswordHelper,
        onToggleObscure: () => setState(() => _obscure = !_obscure),
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
    return FolioDialog(
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
    final l10n = AppLocalizations.of(context);
    final a = _password.text.trim();
    final b = _confirm.text.trim();
    if (a.length < 10) {
      setState(() => _error = l10n.minCharactersError(10));
      return;
    }
    if (a != b) {
      setState(() => _error = l10n.passwordMismatchError);
      return;
    }
    setState(() => _error = null);
    Navigator.pop(context, a);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return FolioDialog(
      title: Text(l10n.importNotionNewVaultPasswordTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FolioPasswordField(
            controller: _password,
            obscureText: _obscureA,
            labelText: l10n.passwordLabel,
            showPasswordTooltip: l10n.showPassword,
            hidePasswordTooltip: l10n.hidePassword,
            onToggleObscure: () => setState(() => _obscureA = !_obscureA),
          ),
          const SizedBox(height: 8),
          FolioPasswordField(
            controller: _confirm,
            obscureText: _obscureB,
            labelText: l10n.confirmPasswordLabel,
            showPasswordTooltip: l10n.showPassword,
            hidePasswordTooltip: l10n.hidePassword,
            onToggleObscure: () => setState(() => _obscureB = !_obscureB),
            onSubmitted: (_) => _submit(),
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
    return FolioDialog(
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
    return FolioDialog(
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
    return FolioDialog(
      title: Text(widget.title),
      contentWidth: 520,
      content: Column(
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
            isOllama ? widget.ollamaInstallTitle : widget.lmStudioInstallTitle,
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

class _ReleaseCheckRow extends StatelessWidget {
  const _ReleaseCheckRow({
    required this.label,
    required this.ok,
    required this.severity,
    this.details,
  });

  final String label;
  final bool ok;
  final ReleaseCheckSeverity severity;
  final String? details;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = ok
        ? Colors.green
        : (severity == ReleaseCheckSeverity.blocker
              ? scheme.error
              : Colors.orange);
    final tagText = severity == ReleaseCheckSeverity.blocker
        ? 'Bloqueador'
        : 'Advertencia';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              ok ? Icons.check_circle_rounded : Icons.error_outline_rounded,
              size: 18,
              color: color,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(label)),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        tagText,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                if (details != null && details!.trim().isNotEmpty)
                  Text(
                    details!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
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

/// Tarjeta-resumen al inicio de un panel de ajustes (mismo lenguaje visual que
/// iconos personalizados e integraciones).
class _SettingsPanelHeroCard extends StatelessWidget {
  const _SettingsPanelHeroCard({
    required this.icon,
    required this.title,
    required this.description,
    this.trailingBadge,
    this.chips = const [],
  });

  final IconData icon;
  final String title;
  final String description;
  final Widget? trailingBadge;
  final List<Widget> chips;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primaryContainer.withValues(alpha: 0.55),
            scheme.surfaceContainerHigh,
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: scheme.primary, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        if (trailingBadge != null) ...[
                          const SizedBox(width: 8),
                          trailingBadge!,
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (chips.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(spacing: 8, runSpacing: 8, children: chips),
          ],
        ],
      ),
    );
  }
}

class _SettingsInfoChip extends StatelessWidget {
  const _SettingsInfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: scheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: scheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _IntegrationsHero extends StatelessWidget {
  const _IntegrationsHero({
    required this.approvedCount,
    required this.hintText,
    required this.title,
    required this.featureChips,
  });

  final int approvedCount;
  final String hintText;
  final String title;
  final List<Widget> featureChips;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _SettingsPanelHeroCard(
      icon: Icons.hub_rounded,
      title: title,
      description: hintText,
      trailingBadge: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          '$approvedCount',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: scheme.primary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      chips: featureChips,
    );
  }
}

class _IntegrationAppCard extends StatelessWidget {
  const _IntegrationAppCard({
    required this.entry,
    required this.detailsText,
    required this.revokeLabel,
    required this.onRevoke,
  });

  final IntegrationAppApproval entry;
  final String detailsText;
  final String revokeLabel;
  final VoidCallback onRevoke;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 260,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.verified_user_outlined,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  entry.appName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: scheme.primaryContainer.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              entry.appId,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: scheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            detailsText,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontFamily: 'monospace',
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onRevoke,
              icon: const Icon(Icons.delete_outline_rounded, size: 18),
              label: Text(revokeLabel),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsPanel extends StatelessWidget {
  const _SettingsPanel({super.key, required this.child, this.margin});

  final Widget child;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.surface, scheme.surfaceContainerLow],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
        boxShadow: FolioShadows.card(scheme),
      ),
      child: ClipRRect(borderRadius: BorderRadius.circular(24), child: child),
    );
  }
}

class _SettingsOverviewBanner extends StatelessWidget {
  const _SettingsOverviewBanner({
    required this.appSettings,
    required this.session,
  });

  final AppSettings appSettings;
  final VaultSession session;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final localeCode = appSettings.locale?.languageCode;
    final localeLabel = localeCode == null
        ? l10n.useSystemLanguage
        : (localeCode == 'es' ? l10n.spanishLanguage : l10n.englishLanguage);
    final aiLabel = appSettings.aiEnabled ? l10n.active : l10n.inactive;
    final vaultLabel = session.vaultUsesEncryption
        ? l10n.encryptedVault
        : (Localizations.localeOf(context).languageCode == 'es'
              ? 'Sin cifrar'
              : 'Unencrypted');
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primaryContainer.withValues(alpha: 0.72),
            scheme.tertiaryContainer.withValues(alpha: 0.36),
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: scheme.surface.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  Icons.tune_rounded,
                  color: scheme.primary,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.settings,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      Localizations.localeOf(context).languageCode == 'es'
                          ? 'Personaliza la app, gestiona seguridad, IA, copias e integraciones desde un único panel.'
                          : 'Customize the app, security, AI, backups, and integrations from one place.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _SettingsOverviewStat(
                icon: Icons.palette_outlined,
                label: l10n.language,
                value: localeLabel,
              ),
              _SettingsOverviewStat(
                icon: Icons.shield_outlined,
                label: Localizations.localeOf(context).languageCode == 'es'
                    ? 'Cofre'
                    : 'Vault',
                value: vaultLabel,
              ),
              _SettingsOverviewStat(
                icon: Icons.auto_awesome_outlined,
                label: Localizations.localeOf(context).languageCode == 'es'
                    ? 'IA'
                    : 'AI',
                value: aiLabel,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SettingsOverviewStat extends StatelessWidget {
  const _SettingsOverviewStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minWidth: 150),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: scheme.primary),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Agrupa opciones dentro de un panel (sin cambiar el índice de sección del rail).
class _SettingsSubsectionTitle extends StatelessWidget {
  const _SettingsSubsectionTitle({
    super.key,
    required this.title,
    required this.scheme,
    this.topPadding = 16,
  });

  final String title;
  final ColorScheme scheme;
  final double topPadding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, topPadding, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: scheme.onSurfaceVariant,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
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
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [scheme.surface, scheme.surfaceContainerHigh],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - 48,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          scheme.primaryContainer,
                          scheme.tertiaryContainer,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(
                      Icons.tune_rounded,
                      color: scheme.onPrimaryContainer,
                    ),
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
            ),
          );
        },
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
