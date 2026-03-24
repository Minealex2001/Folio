import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:path/path.dart' as p;
import 'package:passkeys/authenticator.dart';
import 'package:passkeys/types.dart';
import 'package:uuid/uuid.dart';

import '../data/vault_backup.dart';
import '../data/notion_import/notion_importer.dart';
import '../data/vault_paths.dart';
import '../data/vault_payload.dart';
import '../data/vault_registry.dart';
import '../data/vault_repository.dart';
import '../models/block.dart';
import '../models/folio_page.dart';
import '../models/folio_page_revision.dart';
import '../models/folio_database_data.dart';
import '../models/local_collab.dart';
import '../models/folio_table_data.dart';
import '../models/folio_toggle_data.dart';
import '../models/folio_columns_data.dart';
import '../models/folio_template_button_data.dart';
import '../services/folio_rp_server.dart';
import '../services/ai/ai_safety_policy.dart';
import '../services/ai/ai_service.dart';
import '../services/ai/ai_intent_hints.dart';
import '../services/ai/ai_types.dart';
import '../services/run2doc/run2doc_markdown_codec.dart';
import '../services/app_logger.dart';
import '../services/quick_unlock_storage.dart';

enum VaultFlowState { initializing, needsOnboarding, locked, unlocked }

class VaultSearchResult {
  const VaultSearchResult({
    required this.pageId,
    required this.pageTitle,
    required this.snippet,
    this.blockId,
  });

  final String pageId;
  final String pageTitle;
  final String snippet;
  final String? blockId;
}

class VaultSession extends ChangeNotifier {
  /// Nombre de la asistente en la app; se repite en los prompts para que el modelo lo mantenga.
  static const String _quillIdentityLeadEs =
      'Tu nombre es Quill. Eres la asistente de IA integrada en Folio.\n\n';
  static const String _quillIdentityLeadEn =
      "Your name is Quill. You are Folio's built-in AI assistant.\n\n";

  bool _isManagedAttachmentPath(String? path) {
    final p = path?.trim();
    return p != null && p.startsWith('${VaultPaths.attachmentsDirName}/');
  }

  Iterable<String> _managedAttachmentPathsOfBlock(FolioBlock b) sync* {
    if (b.type == 'image' && _isManagedAttachmentPath(b.text)) {
      yield b.text.trim();
    }
    if ((b.type == 'file' || b.type == 'video') &&
        _isManagedAttachmentPath(b.url)) {
      yield b.url!.trim();
    }
  }

  bool _isAttachmentReferencedAnywhere(
    String relativePath, {
    String? excludingPageId,
    String? excludingBlockId,
  }) {
    final target = relativePath.trim();
    if (target.isEmpty) return false;

    for (final p in _pages) {
      for (final b in p.blocks) {
        if (excludingPageId == p.id && excludingBlockId == b.id) {
          continue;
        }
        if (_managedAttachmentPathsOfBlock(b).contains(target)) {
          return true;
        }
      }
    }

    for (final entry in _pageRevisions.entries) {
      for (final rev in entry.value) {
        for (final bj in rev.blocksJson) {
          final b = FolioBlock.fromJson(bj);
          if (_managedAttachmentPathsOfBlock(b).contains(target)) {
            return true;
          }
        }
      }
    }
    return false;
  }

  void _deleteManagedAttachmentIfUnused(
    String relativePath, {
    String? excludingPageId,
    String? excludingBlockId,
  }) {
    if (!_isManagedAttachmentPath(relativePath)) return;
    final inUse = _isAttachmentReferencedAnywhere(
      relativePath,
      excludingPageId: excludingPageId,
      excludingBlockId: excludingBlockId,
    );
    if (!inUse) {
      unawaited(VaultPaths.deleteAttachmentIfExists(relativePath));
    }
  }

  VaultSession({
    VaultRepository? repository,
    QuickUnlockStorage? quickUnlock,
    FolioRpServer? rpServer,
    PasskeyAuthenticator? passkeys,
    LocalAuthentication? localAuth,
  }) : _repo = repository ?? VaultRepository(),
       _quick = quickUnlock ?? QuickUnlockStorage(),
       _rp = rpServer ?? FolioRpServer(),
       _passkeys = passkeys ?? PasskeyAuthenticator(),
       _localAuth = localAuth ?? LocalAuthentication();

  final VaultRepository _repo;
  final QuickUnlockStorage _quick;
  final FolioRpServer _rp;
  final PasskeyAuthenticator _passkeys;
  final LocalAuthentication _localAuth;
  AiService? _aiService;

  static const _uuid = Uuid();

  VaultFlowState _state = VaultFlowState.initializing;
  List<int>? _dek;
  List<FolioPage> _pages = [];

  /// Historial de revisiones por `pageId` (orden cronológico ascendente).
  final Map<String, List<FolioPageRevision>> _pageRevisions = {};
  final Map<String, Map<String, String>> _pageAcl = {};
  final List<LocalProfile> _localProfiles = [];
  final List<LocalPageComment> _comments = [];
  final List<AiChatThreadData> _aiChatThreads = [
    const AiChatThreadData(id: 'chat_0', title: 'Chat 1', messages: []),
  ];
  int _aiActiveChatIndex = 0;
  String? _selectedPageId;
  Timer? _saveDebounce;
  Timer? _revisionIdleTimer;
  Timer? _idleLockTimer;
  final Set<String> _pageIdsPendingRevision = {};
  int _persistDepth = 0;
  Duration _idleLockDuration = const Duration(minutes: 15);
  bool _lockOnAppBackground = false;
  bool _vaultUsesEncryption = true;

  /// Tras "Añadir cofre", se restaura al cancelar onboarding.
  String? _resumeVaultIdAfterNewVault;

  final VaultRegistry _registry = VaultRegistry.instance;

  String? get activeVaultId => VaultPaths.activeVaultId;

  bool get canCancelNewVaultOnboarding => _resumeVaultIdAfterNewVault != null;

  Future<List<VaultEntry>> listVaultEntries() async {
    await _registry.load();
    return _registry.vaults;
  }

  String? get _vaultId => VaultPaths.activeVaultId;

  /// Tras dejar de editar, se crea una entrada de historial (además del guardado rápido).
  static const Duration _revisionIdleDelay = Duration(milliseconds: 2500);

  /// Hay un guardado al disco programado (debounce) y aún no se ha ejecutado.
  bool get hasPendingDiskSave => _saveDebounce != null;

  /// Escritura cifrada del cofre en curso (puede anidarse si varias rutas llaman a [persistNow]).
  bool get isPersistingToDisk => _persistDepth > 0;

  VaultFlowState get state => _state;
  List<FolioPage> get pages => List.unmodifiable(_pages);
  String? get selectedPageId => _selectedPageId;
  List<LocalPageComment> commentsForPage(String pageId) =>
      _comments.where((c) => c.pageId == pageId).toList()
        ..sort((a, b) => b.createdAtMs.compareTo(a.createdAtMs));
  Duration get idleLockDuration => _idleLockDuration;
  bool get lockOnAppBackground => _lockOnAppBackground;
  bool get aiEnabled => _aiService != null;
  bool get vaultUsesEncryption => _vaultUsesEncryption;
  bool get isUnlocked => _state == VaultFlowState.unlocked;
  List<AiChatThreadData> get aiChatThreads => List.unmodifiable(_aiChatThreads);
  int get aiActiveChatIndex => _aiActiveChatIndex;
  AiChatThreadData get activeAiChat => _aiChatThreads[_aiActiveChatIndex];

  /// Se incrementa al restaurar una revisión para forzar remount del editor
  /// cuando los ids de bloque coinciden pero el texto cambió.
  int get contentEpoch => _contentEpoch;
  int _contentEpoch = 0;

  /// El editor hace scroll a este bloque tras el siguiente frame (TOC / enlaces internos).
  String? pendingScrollToBlockId;

  FolioPage? get selectedPage {
    if (_selectedPageId == null) return null;
    try {
      return _pages.firstWhere((p) => p.id == _selectedPageId);
    } catch (_) {
      return null;
    }
  }

  FolioRpServer get rpServer => _rp;

  void setAiService(AiService? service) {
    _aiService = service;
  }

  Future<void> pingAi() async {
    final ai = _aiService;
    if (ai == null) throw StateError('IA no configurada.');
    try {
      await ai.ping();
    } catch (e) {
      throw AiServiceUnreachableException(e);
    }
  }

  Future<List<String>> listAiModels() async {
    final ai = _aiService;
    if (ai == null) throw StateError('IA no configurada.');
    return ai.listModels();
  }

  Future<bool> get quickUnlockEnabled async {
    final id = _vaultId;
    if (id == null) return false;
    return _quick.isEnabled(id);
  }

  Future<bool> get hasPasskey async {
    await _rp.loadFromDisk();
    return _rp.hasPasskey;
  }

  FolioPage? _pageById(String id) {
    for (final p in _pages) {
      if (p.id == id) return p;
    }
    return null;
  }

  FolioBlock? _blockById(FolioPage page, String blockId) {
    for (final b in page.blocks) {
      if (b.id == blockId) return b;
    }
    return null;
  }

  Future<void> bootstrap() async {
    _state = VaultFlowState.initializing;
    notifyListeners();

    await _registry.migrateFromLegacyIfNeeded();
    await _registry.load();

    if (_registry.vaults.isEmpty) {
      VaultPaths.clearActiveVaultId();
      _dek = null;
      _pages = [];
      _selectedPageId = null;
      _state = VaultFlowState.needsOnboarding;
      notifyListeners();
      return;
    }

    var active = _registry.activeVaultId;
    if (active == null || !_registry.containsVault(active)) {
      active = _registry.vaults.first.id;
      await _registry.setActiveVaultId(active);
    }
    VaultPaths.setActiveVaultId(active);

    await _rp.loadFromDisk();

    final exists = await VaultPaths.vaultExists();
    if (!exists) {
      _vaultUsesEncryption = true;
      _dek = null;
      _pages = [];
      _selectedPageId = null;
      _state = VaultFlowState.needsOnboarding;
    } else {
      final plain = await _repo.isPlaintextVault();
      _vaultUsesEncryption = !plain;
      if (plain) {
        final payload = await _repo.loadPayload(null);
        _dek = null;
        _pages = List.from(payload.pages);
        _loadRevisionsFromPayload(payload);
        _pickInitialSelection();
        _state = VaultFlowState.unlocked;
        _restartIdleLockTimer();
      } else {
        _state = VaultFlowState.locked;
        _dek = null;
      }
    }
    notifyListeners();
  }

  void _loadRevisionsFromPayload(VaultPayload payload) {
    _pageRevisions
      ..clear()
      ..addEntries(
        payload.pageRevisions.entries.map(
          (e) => MapEntry(e.key, List<FolioPageRevision>.from(e.value)),
        ),
      );
    _pageAcl
      ..clear()
      ..addEntries(
        payload.pageAcl.entries.map(
          (e) => MapEntry(e.key, Map<String, String>.from(e.value)),
        ),
      );
    _localProfiles
      ..clear()
      ..addAll(payload.localProfiles);
    if (_localProfiles.isEmpty) {
      _localProfiles.add(LocalProfile(id: 'local-default', name: 'Local user'));
    }
    _comments
      ..clear()
      ..addAll(payload.comments);
    _aiChatThreads
      ..clear()
      ..addAll(payload.aiChatThreads);
    if (_aiChatThreads.isEmpty) {
      _aiChatThreads.add(
        const AiChatThreadData(id: 'chat_0', title: 'Chat 1', messages: []),
      );
    }
    _aiActiveChatIndex = payload.aiActiveChatIndex.clamp(
      0,
      _aiChatThreads.length - 1,
    );
  }

  Future<void> completeOnboarding({
    String? password,
    bool encrypted = true,
  }) async {
    await _registry.load();
    var id = VaultPaths.activeVaultId;
    if (id == null) {
      id = _uuid.v4();
      VaultPaths.setActiveVaultId(id);
    }
    await VaultPaths.vaultDirectoryForId(id);
    if (!_registry.containsVault(id)) {
      final ordinal = _registry.vaults.length + 1;
      await _registry.add(
        VaultEntry(
          id: id,
          displayName: 'Cofre $ordinal',
          createdAtMs: DateTime.now().millisecondsSinceEpoch,
        ),
      );
    }
    await _registry.setActiveVaultId(id);

    final dek = await _repo.createVault(
      password: password,
      encrypted: encrypted,
    );
    _vaultUsesEncryption = encrypted;
    _dek = dek?.toList();
    final payload = await _repo.loadPayload(_dek);
    _pages = List.from(payload.pages);
    _loadRevisionsFromPayload(payload);
    _pickInitialSelection();
    _state = VaultFlowState.unlocked;
    _restartIdleLockTimer();
    _resumeVaultIdAfterNewVault = null;
    notifyListeners();
    await persistNow();
  }

  /// Añade un cofre vacío y pasa a onboarding (el usuario debe completar contraseña o import).
  Future<void> prepareNewVault() async {
    await _registry.load();
    final current = VaultPaths.activeVaultId;
    if (current == null) {
      throw StateError('No hay cofre activo');
    }
    _resumeVaultIdAfterNewVault = current;
    final newId = _uuid.v4();
    await VaultPaths.vaultDirectoryForId(newId);
    final ordinal = _registry.vaults.length + 1;
    await _registry.add(
      VaultEntry(
        id: newId,
        displayName: 'Cofre $ordinal',
        createdAtMs: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    VaultPaths.setActiveVaultId(newId);
    await _registry.setActiveVaultId(newId);
    _clearVaultSessionMemory();
    _state = VaultFlowState.initializing;
    notifyListeners();
    await bootstrap();
  }

  /// Cancela el onboarding de un cofre nuevo y vuelve al cofre anterior.
  Future<void> cancelPrepareNewVault() async {
    final resume = _resumeVaultIdAfterNewVault;
    if (resume == null) return;
    await _registry.load();
    final cur = VaultPaths.activeVaultId;
    final orphanId = cur != null && !await VaultPaths.vaultExistsForId(cur)
        ? cur
        : null;
    VaultPaths.setActiveVaultId(resume);
    await _registry.setActiveVaultId(resume);
    if (orphanId != null) {
      await VaultPaths.deleteVaultDirectory(orphanId);
      if (_registry.containsVault(orphanId)) {
        await _registry.remove(orphanId);
      }
    }
    _resumeVaultIdAfterNewVault = null;
    await bootstrap();
  }

  Future<void> switchVault(String vaultId) async {
    await _registry.load();
    if (!_registry.containsVault(vaultId)) return;
    lock();
    VaultPaths.setActiveVaultId(vaultId);
    await _registry.setActiveVaultId(vaultId);
    _resumeVaultIdAfterNewVault = null;
    await bootstrap();
  }

  Future<void> renameActiveVault(String displayName) async {
    final id = _vaultId;
    if (id == null) return;
    await _registry.rename(id, displayName);
    notifyListeners();
  }

  /// Elimina otro cofre (no el activo). Requiere que no sea el abierto.
  Future<void> deleteVaultById(String vaultId) async {
    await _registry.load();
    if (vaultId == VaultPaths.activeVaultId) {
      throw StateError(
        'No se puede borrar el cofre activo desde aquí; usa Borrar cofre.',
      );
    }
    if (!_registry.containsVault(vaultId)) return;
    await _quick.disable(vaultId);
    await VaultPaths.deleteVaultDirectory(vaultId);
    await _registry.remove(vaultId);
    notifyListeners();
  }

  /// La UI debe haber verificado la identidad del cofre **actual** (contraseña / Hello / passkey).
  /// [zipPath] ruta del `.zip` a crear.
  Future<void> exportVaultBackup(String zipPath) async {
    await persistNow();
    await exportVaultZip(File(zipPath));
  }

  /// Importa el ZIP como **cofre nuevo**; el cofre activo no se modifica.
  /// Devuelve el id del cofre creado.
  Future<String> importVaultBackupAsNew(
    String zipPath,
    String backupPassword, {
    String? displayName,
  }) async {
    final temp = Directory.systemTemp.createTempSync('folio_import_new_');
    try {
      await extractBackupZipToDirectory(File(zipPath), temp);
      await validateImportZip(temp, backupPassword);
      final newId = _uuid.v4();
      final root = await VaultPaths.vaultDirectoryForId(newId);
      await applyImportToVaultRoot(temp, root);
      await _registry.load();
      await _registry.add(
        VaultEntry(
          id: newId,
          displayName: displayName ?? 'Cofre importado',
          createdAtMs: DateTime.now().millisecondsSinceEpoch,
        ),
      );
      notifyListeners();
      return newId;
    } finally {
      try {
        if (temp.existsSync()) {
          await temp.delete(recursive: true);
        }
      } catch (_) {}
    }
  }

  String _newBlockId(String pageId) => '${pageId}_${_uuid.v4()}';

  Future<List<FolioPage>> _materializeNotionPages(
    NotionParsedExport parsed,
  ) async {
    final sourceToPageId = <String, String>{};
    final pages = <FolioPage>[];
    for (final src in parsed.pages) {
      final pageId = _uuid.v4();
      sourceToPageId[src.sourcePath] = pageId;
      pages.add(
        FolioPage(
          id: pageId,
          title: src.title.trim().isEmpty ? 'Untitled' : src.title.trim(),
          blocks: [
            FolioBlock(id: _newBlockId(pageId), type: 'paragraph', text: ''),
          ],
        ),
      );
    }

    for (var i = 0; i < parsed.pages.length; i++) {
      final src = parsed.pages[i];
      final page = pages[i];
      final parentSource = src.parentSourcePath;
      if (parentSource != null && parentSource.isNotEmpty) {
        page.parentId = sourceToPageId[parentSource];
      }
      page.blocks = [];
      for (final b in src.blocks) {
        final copied = FolioBlock(
          id: _newBlockId(page.id),
          type: b.type,
          text: b.text,
          checked: b.checked,
          expanded: b.expanded,
          codeLanguage: b.codeLanguage,
          depth: b.depth,
          icon: b.icon,
          url: b.url,
        );
        await _importBlockAttachmentIfNeeded(
          copied,
          baseDir: src.sourceDirPath,
        );
        page.blocks.add(copied);
      }
      if (page.blocks.isEmpty) {
        page.blocks.add(
          FolioBlock(id: _newBlockId(page.id), type: 'paragraph', text: ''),
        );
      }
    }

    // Importar bases de datos CSV de Notion como páginas con un bloque database.
    for (final db in parsed.databases) {
      final pageId = _uuid.v4();
      pages.add(
        FolioPage(
          id: pageId,
          title: db.title.trim().isEmpty ? 'Database' : db.title.trim(),
          blocks: [
            FolioBlock(
              id: _newBlockId(pageId),
              type: 'database',
              text: db.data.encode(),
            ),
          ],
        ),
      );
    }
    return pages;
  }

  Future<void> _importBlockAttachmentIfNeeded(
    FolioBlock block, {
    required String baseDir,
  }) async {
    Future<String?> importPath(String rawPath) async {
      if (rawPath.startsWith('http://') || rawPath.startsWith('https://')) {
        return rawPath;
      }
      final candidate = File(p.normalize(p.join(baseDir, rawPath)));
      if (!candidate.existsSync()) return rawPath;
      return VaultPaths.importAttachmentFile(
        candidate,
        preserveExtension: true,
        preserveFileName: true,
      );
    }

    if (block.type == 'image' && block.text.trim().isNotEmpty) {
      final imported = await importPath(block.text.trim());
      if (imported != null) block.text = imported;
    }
    if ((block.type == 'file' ||
            block.type == 'video' ||
            block.type == 'audio') &&
        (block.url?.trim().isNotEmpty ?? false)) {
      final imported = await importPath(block.url!.trim());
      if (imported != null) block.url = imported;
    }
  }

  /// Importa un ZIP exportado por Notion al cofre actual (debe estar desbloqueado).
  Future<NotionParsedExport> importNotionIntoCurrentVault(
    String zipPath,
  ) async {
    if (_state != VaultFlowState.unlocked ||
        (vaultUsesEncryption && _dek == null)) {
      throw StateError('Debes desbloquear el cofre para importar.');
    }
    final temp = await Directory.systemTemp.createTemp('folio_notion_import_');
    try {
      await extractNotionZipToDirectory(File(zipPath), temp);
      final parsed = parseNotionExportDirectory(temp);
      final pages = await _materializeNotionPages(parsed);
      _pages.addAll(pages);
      if (_selectedPageId == null && _pages.isNotEmpty) {
        _selectedPageId = _pages.first.id;
      }
      notifyListeners();
      await persistNow();
      return parsed;
    } finally {
      try {
        if (temp.existsSync()) {
          await temp.delete(recursive: true);
        }
      } catch (_) {}
    }
  }

  /// Importa un ZIP exportado por Notion creando un cofre nuevo.
  Future<String> importNotionAsNewVault(
    String zipPath, {
    required String masterPassword,
    String? displayName,
  }) async {
    final temp = await Directory.systemTemp.createTemp('folio_notion_import_');
    final prevVaultId = VaultPaths.activeVaultId;
    final newId = _uuid.v4();
    final createdAt = DateTime.now().millisecondsSinceEpoch;
    try {
      await extractNotionZipToDirectory(File(zipPath), temp);
      final parsed = parseNotionExportDirectory(temp);
      await _registry.load();
      VaultPaths.setActiveVaultId(newId);
      await VaultPaths.vaultDirectoryForId(newId);
      final newDek = await _repo.createVault(
        password: masterPassword,
        encrypted: true,
      );
      final oldDek = _dek;
      final oldPages = _pages;
      final oldSelected = _selectedPageId;
      _dek = newDek!.toList();
      _pages = [];
      _selectedPageId = null;
      final pages = await _materializeNotionPages(parsed);
      _pages = pages;
      _pickInitialSelection();
      await _repo.savePayload(
        VaultPayload(
          version: kVaultPayloadVersion,
          pages: _pages,
          pageRevisions: const {},
          pageAcl: const {},
          localProfiles: [
            LocalProfile(id: 'local-default', name: 'Local user'),
          ],
          comments: const [],
        ),
        _dek!,
      );
      _dek = oldDek;
      _pages = oldPages;
      _selectedPageId = oldSelected;

      await _registry.add(
        VaultEntry(
          id: newId,
          displayName: displayName ?? 'Notion importado',
          createdAtMs: createdAt,
        ),
      );
      if (prevVaultId != null) {
        VaultPaths.setActiveVaultId(prevVaultId);
      }
      notifyListeners();
      return newId;
    } catch (_) {
      await VaultPaths.deleteVaultDirectory(newId);
      rethrow;
    } finally {
      if (prevVaultId != null) {
        VaultPaths.setActiveVaultId(prevVaultId);
      }
      try {
        if (temp.existsSync()) {
          await temp.delete(recursive: true);
        }
      } catch (_) {}
    }
  }

  /// Onboarding por copia: escribe el cofre en el id activo (o nuevo) y registra.
  Future<void> completeOnboardingFromBackup(
    String zipPath,
    String backupPassword,
  ) async {
    await _registry.load();
    if (VaultPaths.activeVaultId != null && await VaultPaths.vaultExists()) {
      throw StateError('Ya hay datos en el cofre actual.');
    }
    final temp = Directory.systemTemp.createTempSync('folio_onboard_import_');
    try {
      await extractBackupZipToDirectory(File(zipPath), temp);
      await validateImportZip(temp, backupPassword);

      var id = VaultPaths.activeVaultId;
      if (id == null) {
        id = _uuid.v4();
        VaultPaths.setActiveVaultId(id);
      }
      final root = await VaultPaths.vaultDirectoryForId(id);
      await applyImportToVaultRoot(temp, root);

      if (!_registry.containsVault(id)) {
        final ordinal = _registry.vaults.length + 1;
        await _registry.add(
          VaultEntry(
            id: id,
            displayName: 'Cofre $ordinal',
            createdAtMs: DateTime.now().millisecondsSinceEpoch,
          ),
        );
      }
      await _registry.setActiveVaultId(id);

      await unlockWithPassword(backupPassword);
      _resumeVaultIdAfterNewVault = null;
    } finally {
      try {
        if (temp.existsSync()) {
          await temp.delete(recursive: true);
        }
      } catch (_) {}
    }
  }

  Future<void> unlockWithPassword(String password) async {
    if (!vaultUsesEncryption) {
      _dek = null;
      final payload = await _repo.loadPayload(null);
      _pages = List.from(payload.pages);
      _loadRevisionsFromPayload(payload);
      _pickInitialSelection();
      _state = VaultFlowState.unlocked;
      _restartIdleLockTimer();
      notifyListeners();
      return;
    }
    final dek = await _repo.unlockWithPassword(password);
    _dek = dek.toList();
    final payload = await _repo.loadPayload(_dek);
    _pages = List.from(payload.pages);
    _loadRevisionsFromPayload(payload);
    _pickInitialSelection();
    _state = VaultFlowState.unlocked;
    _restartIdleLockTimer();
    notifyListeners();
  }

  Future<void> unlockWithDeviceAuth() async {
    final supported = await _localAuth.isDeviceSupported();
    if (!supported) {
      throw StateError('Este dispositivo no admite biometría o Windows Hello');
    }
    final ok = await _localAuth.authenticate(
      localizedReason: 'Desbloquea Folio para acceder a tus notas cifradas',
    );
    if (!ok) {
      throw StateError('Autenticación cancelada');
    }
    final vid = _vaultId;
    if (vid == null) {
      throw StateError('No hay cofre activo');
    }
    final dek = await _quick.readDek(vid);
    if (dek == null) {
      throw StateError(
        'Primero configura el desbloqueo rápido desde la app (Ajustes)',
      );
    }
    _dek = dek.toList();
    final payload = await _repo.loadPayload(_dek);
    _pages = List.from(payload.pages);
    _loadRevisionsFromPayload(payload);
    _pickInitialSelection();
    _state = VaultFlowState.unlocked;
    _restartIdleLockTimer();
    notifyListeners();
  }

  Future<void> unlockWithPasskey() async {
    await _rp.loadFromDisk();
    final jsonRequest = _rp.startPasskeyLogin();
    final request = AuthenticateRequestType.fromJsonString(jsonRequest);
    final response = await _passkeys.authenticate(request);
    await _rp.finishPasskeyLogin(response: response.toJsonString());
    final vid = _vaultId;
    if (vid == null) {
      throw StateError('No hay cofre activo');
    }
    final dek = await _quick.readDek(vid);
    if (dek == null) {
      throw StateError(
        'No hay clave de desbloqueo rápido. Entra con contraseña y vuelve a registrar la passkey.',
      );
    }
    _dek = dek.toList();
    final payload = await _repo.loadPayload(_dek);
    _pages = List.from(payload.pages);
    _loadRevisionsFromPayload(payload);
    _pickInitialSelection();
    _state = VaultFlowState.unlocked;
    _restartIdleLockTimer();
    notifyListeners();
  }

  /// Vacía el estado en memoria del cofre (sin fijar [VaultFlowState]).
  void _clearVaultSessionMemory() {
    _saveDebounce?.cancel();
    _saveDebounce = null;
    _revisionIdleTimer?.cancel();
    _revisionIdleTimer = null;
    _idleLockTimer?.cancel();
    _idleLockTimer = null;
    _pageIdsPendingRevision.clear();
    _dek = null;
    _pages = [];
    _pageRevisions.clear();
    _pageAcl.clear();
    _localProfiles
      ..clear()
      ..add(LocalProfile(id: 'local-default', name: 'Local user'));
    _comments.clear();
    _aiChatThreads
      ..clear()
      ..add(
        const AiChatThreadData(id: 'chat_0', title: 'Chat 1', messages: []),
      );
    _aiActiveChatIndex = 0;
    _contentEpoch = 0;
    _selectedPageId = null;
  }

  void lock() {
    if (!vaultUsesEncryption) return;
    _clearVaultSessionMemory();
    _state = VaultFlowState.locked;
    notifyListeners();
  }

  void applySecurityPolicy({
    required int idleLockMinutes,
    required bool lockOnAppBackground,
  }) {
    final safeMinutes = idleLockMinutes <= 0 ? 15 : idleLockMinutes;
    _idleLockDuration = Duration(minutes: safeMinutes);
    _lockOnAppBackground = lockOnAppBackground;
    if (_state == VaultFlowState.unlocked) {
      _restartIdleLockTimer();
    }
  }

  void touchActivity() {
    if (_state != VaultFlowState.unlocked ||
        (vaultUsesEncryption && _dek == null)) {
      return;
    }
    _restartIdleLockTimer();
  }

  void onAppBackgrounded() {
    if (_state != VaultFlowState.unlocked) return;
    if (_lockOnAppBackground) {
      lock();
    }
  }

  void _restartIdleLockTimer() {
    _idleLockTimer?.cancel();
    _idleLockTimer = Timer(_idleLockDuration, () {
      lock();
    });
  }

  Future<void> enableDeviceQuickUnlock() async {
    if (!vaultUsesEncryption) {
      throw StateError('El desbloqueo rápido requiere cofre cifrado');
    }
    if (_dek == null) return;
    final supported = await _localAuth.isDeviceSupported();
    if (!supported) {
      throw StateError('No disponible en este dispositivo');
    }
    final ok = await _localAuth.authenticate(
      localizedReason:
          'Confirma para guardar el desbloqueo con Hello / biometría',
    );
    if (!ok) return;
    final vid = _vaultId;
    if (vid == null) return;
    await _quick.enableWithDek(vid, Uint8List.fromList(_dek!));
    notifyListeners();
  }

  Future<void> registerPasskey() async {
    if (!vaultUsesEncryption) {
      throw StateError('La passkey requiere cofre cifrado');
    }
    if (_dek == null) return;
    await _rp.loadFromDisk();
    final jsonRequest = _rp.startPasskeyRegister();
    final request = RegisterRequestType.fromJsonString(jsonRequest);
    final response = await _passkeys.register(request);
    await _rp.finishPasskeyRegister(response: response.toJsonString());
    final vid = _vaultId;
    if (vid == null) return;
    await _quick.enableWithDek(vid, Uint8List.fromList(_dek!));
    notifyListeners();
  }

  Future<void> disableQuickUnlock() async {
    final vid = _vaultId;
    if (vid == null) return;
    await _quick.disable(vid);
    notifyListeners();
  }

  Future<void> revokePasskey() async {
    await _rp.clearPasskey();
    notifyListeners();
  }

  void selectPage(String id) {
    if (_pages.every((p) => p.id != id)) return;
    touchActivity();
    _selectedPageId = id;
    notifyListeners();
  }

  void requestScrollToBlock(String blockId) {
    pendingScrollToBlockId = blockId;
    notifyListeners();
  }

  void clearPendingScrollToBlock() {
    if (pendingScrollToBlockId == null) return;
    pendingScrollToBlockId = null;
    notifyListeners();
  }

  void clearSelectedPage() {
    if (_selectedPageId == null) return;
    touchActivity();
    _selectedPageId = null;
    notifyListeners();
  }

  void selectAiChat(int index) {
    if (index < 0 || index >= _aiChatThreads.length) return;
    _aiActiveChatIndex = index;
    notifyListeners();
    scheduleSave();
  }

  static const _stringListEq = ListEquality<String>();

  /// Persiste las rutas de adjuntos del hilo de chat activo (p. ej. antes de cambiar de hilo).
  void syncActiveAiChatAttachmentPaths(List<String> paths) {
    if (_state != VaultFlowState.unlocked) return;
    final i = _aiActiveChatIndex;
    if (i < 0 || i >= _aiChatThreads.length) return;
    final cur = _aiChatThreads[i];
    if (_stringListEq.equals(cur.attachmentPaths, paths)) return;
    _aiChatThreads[i] = AiChatThreadData(
      id: cur.id,
      title: cur.title,
      messages: cur.messages,
      attachmentPaths: List<String>.from(paths),
      includePageContext: cur.includePageContext,
      contextPageIds: cur.contextPageIds,
    );
    scheduleSave();
  }

  void setActiveAiChatIncludePageContext(bool value) {
    if (_state != VaultFlowState.unlocked) return;
    final i = _aiActiveChatIndex;
    if (i < 0 || i >= _aiChatThreads.length) return;
    final cur = _aiChatThreads[i];
    if (cur.includePageContext == value) return;
    _aiChatThreads[i] = AiChatThreadData(
      id: cur.id,
      title: cur.title,
      messages: cur.messages,
      attachmentPaths: cur.attachmentPaths,
      includePageContext: value,
      contextPageIds: cur.contextPageIds,
    );
    notifyListeners();
    scheduleSave();
  }

  void setActiveAiChatContextPageIds(List<String> ids) {
    if (_state != VaultFlowState.unlocked) return;
    final i = _aiActiveChatIndex;
    if (i < 0 || i >= _aiChatThreads.length) return;
    final cur = _aiChatThreads[i];
    final next = List<String>.from(ids);
    if (_stringListEq.equals(cur.contextPageIds, next)) return;
    _aiChatThreads[i] = AiChatThreadData(
      id: cur.id,
      title: cur.title,
      messages: cur.messages,
      attachmentPaths: cur.attachmentPaths,
      includePageContext: cur.includePageContext,
      contextPageIds: next,
    );
    notifyListeners();
    scheduleSave();
  }

  static const int _maxAiChatTitleLength = 80;

  String _clampAiChatTitle(String raw) {
    var t = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (t.length > _maxAiChatTitleLength) {
      t = t.substring(0, _maxAiChatTitleLength).trim();
    }
    return t;
  }

  /// Renombra un hilo de chat (persiste con el cofre).
  void renameAiChatAt(int index, String title) {
    if (_state != VaultFlowState.unlocked) return;
    if (index < 0 || index >= _aiChatThreads.length) return;
    final t = _clampAiChatTitle(title);
    if (t.isEmpty) return;
    final cur = _aiChatThreads[index];
    if (cur.title == t) return;
    _aiChatThreads[index] = AiChatThreadData(
      id: cur.id,
      title: t,
      messages: cur.messages,
      attachmentPaths: cur.attachmentPaths,
      includePageContext: cur.includePageContext,
      contextPageIds: cur.contextPageIds,
    );
    notifyListeners();
    scheduleSave();
  }

  void _maybeApplyAgentThreadTitle(
    String? rawThreadTitle, {
    required List<AiChatMessage> conversationMessages,
  }) {
    final userCount = conversationMessages
        .where((m) => m.role == 'user')
        .length;
    if (userCount != 1) return;
    final t = _clampAiChatTitle(rawThreadTitle ?? '');
    if (t.isEmpty) return;
    renameAiChatAt(_aiActiveChatIndex, t);
  }

  void createNewAiChat() {
    final next = _aiChatThreads.length + 1;
    _aiChatThreads.add(
      AiChatThreadData(
        id: 'chat_${DateTime.now().microsecondsSinceEpoch}',
        title: 'Chat $next',
        messages: const [],
        includePageContext: true,
        contextPageIds: const [],
      ),
    );
    _aiActiveChatIndex = _aiChatThreads.length - 1;
    notifyListeners();
    scheduleSave();
  }

  void deleteActiveAiChat() {
    if (_aiChatThreads.length <= 1) {
      _aiChatThreads[0] = const AiChatThreadData(
        id: 'chat_0',
        title: 'Chat 1',
        messages: [],
      );
      _aiActiveChatIndex = 0;
      notifyListeners();
      scheduleSave();
      return;
    }
    _aiChatThreads.removeAt(_aiActiveChatIndex);
    if (_aiActiveChatIndex >= _aiChatThreads.length) {
      _aiActiveChatIndex = _aiChatThreads.length - 1;
    }
    notifyListeners();
    scheduleSave();
  }

  void appendMessageToActiveAiChat(AiChatMessage message) {
    final current = _aiChatThreads[_aiActiveChatIndex];
    final nextMessages = List<AiChatMessage>.from(current.messages)
      ..add(message);
    _aiChatThreads[_aiActiveChatIndex] = AiChatThreadData(
      id: current.id,
      title: current.title,
      messages: nextMessages,
      attachmentPaths: current.attachmentPaths,
      includePageContext: current.includePageContext,
      contextPageIds: current.contextPageIds,
    );
    notifyListeners();
    scheduleSave();
  }

  void addPage({String? parentId}) {
    final id = _uuid.v4();
    _pages.add(
      FolioPage(
        id: id,
        title: 'New page',
        parentId: parentId,
        blocks: [FolioBlock(id: '${id}_b0', type: 'paragraph', text: '')],
      ),
    );
    _selectedPageId = id;
    notifyListeners();
    scheduleSave(trackRevisionForPageId: id);
  }

  FolioMarkdownImportResult importMarkdownDocument(
    String markdown, {
    String? title,
    String? parentId,
    String? sourceApp,
    String? sourceUrl,
    FolioMarkdownImportMode mode = FolioMarkdownImportMode.newPage,
  }) {
    if (!isUnlocked) {
      throw StateError('Unlock Folio before importing.');
    }

    final trimmed = markdown.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Markdown vacío.');
    }

    final targetPageId = _selectedPageId;
    if (mode != FolioMarkdownImportMode.newPage && targetPageId == null) {
      throw StateError('No hay página activa para importar.');
    }

    switch (mode) {
      case FolioMarkdownImportMode.newPage:
        final id = _uuid.v4();
        final doc = FolioMarkdownCodec.parseDocument(
          trimmed,
          pageId: id,
          fallbackTitle: title,
          sourceApp: sourceApp,
          sourceUrl: sourceUrl,
        );
        _pages.add(
          FolioPage(
            id: id,
            title: doc.title.trim().isEmpty
                ? 'Imported page'
                : doc.title.trim(),
            parentId: parentId,
            blocks: doc.blocks,
          ),
        );
        _selectedPageId = id;
        notifyListeners();
        scheduleSave(trackRevisionForPageId: id);
        return FolioMarkdownImportResult(
          pageId: id,
          pageTitle: doc.title.trim().isEmpty
              ? 'Imported page'
              : doc.title.trim(),
          mode: mode,
          blockCount: doc.blocks.length,
        );
      case FolioMarkdownImportMode.replaceCurrentPage:
        final page = selectedPage;
        if (page == null) {
          throw StateError('No hay página activa para reemplazar.');
        }
        final doc = FolioMarkdownCodec.parseDocument(
          trimmed,
          pageId: page.id,
          fallbackTitle: title ?? page.title,
          sourceApp: sourceApp,
          sourceUrl: sourceUrl,
        );
        page.title = doc.title.trim().isEmpty ? page.title : doc.title.trim();
        page.blocks = doc.blocks;
        _selectedPageId = page.id;
        _contentEpoch++;
        notifyListeners();
        scheduleSave(trackRevisionForPageId: page.id);
        return FolioMarkdownImportResult(
          pageId: page.id,
          pageTitle: page.title,
          mode: mode,
          blockCount: doc.blocks.length,
        );
      case FolioMarkdownImportMode.appendToCurrentPage:
        final page = selectedPage;
        if (page == null) {
          throw StateError('No hay página activa para anexar contenido.');
        }
        final doc = FolioMarkdownCodec.parseDocument(
          trimmed,
          pageId: page.id,
          fallbackTitle: title ?? page.title,
          sourceApp: sourceApp,
          sourceUrl: sourceUrl,
        );
        final existingSingleEmpty =
            page.blocks.length == 1 &&
            page.blocks.first.type == 'paragraph' &&
            page.blocks.first.text.trim().isEmpty;
        if (existingSingleEmpty) {
          page.blocks = doc.blocks;
        } else {
          page.blocks.addAll(doc.blocks);
        }
        _selectedPageId = page.id;
        _contentEpoch++;
        notifyListeners();
        scheduleSave(trackRevisionForPageId: page.id);
        return FolioMarkdownImportResult(
          pageId: page.id,
          pageTitle: page.title,
          mode: mode,
          blockCount: doc.blocks.length,
        );
    }
  }

  String exportPageAsMarkdown(String pageId, {bool includeFrontMatter = true}) {
    final page = _pageById(pageId);
    if (page == null) {
      throw StateError('Página no encontrada.');
    }
    return FolioMarkdownCodec.exportPage(
      page,
      includeFrontMatter: includeFrontMatter,
    );
  }

  bool _hasChildren(String id) => _pages.any((p) => p.parentId == id);

  void deletePage(String id) {
    if (_pages.length <= 1) return;
    if (_hasChildren(id)) return;
    final idx = _pages.indexWhere((p) => p.id == id);
    if (idx < 0) return;
    final doomed = _pages[idx];
    for (final b in doomed.blocks) {
      if (b.type == 'image' && b.text.isNotEmpty) {
        _deleteManagedAttachmentIfUnused(
          b.text,
          excludingPageId: doomed.id,
          excludingBlockId: b.id,
        );
      }
      if ((b.type == 'file' || b.type == 'video' || b.type == 'audio') &&
          _isManagedAttachmentPath(b.url)) {
        _deleteManagedAttachmentIfUnused(
          b.url!,
          excludingPageId: doomed.id,
          excludingBlockId: b.id,
        );
      }
    }
    for (final p in _pages) {
      for (final b in p.blocks) {
        if (b.type == 'child_page' && b.text.trim() == id) {
          b.text = '';
        }
      }
    }
    final wasSelected = _selectedPageId == id;
    _pages.removeAt(idx);
    _pageRevisions.remove(id);
    _pageAcl.remove(id);
    _comments.removeWhere((c) => c.pageId == id);
    _pageIdsPendingRevision.remove(id);
    if (wasSelected) {
      _pickInitialSelection();
    }
    notifyListeners();
    scheduleSave();
  }

  void renamePage(String id, String title) {
    final p = _pageById(id);
    if (p == null) return;
    final t = title.trim();
    if (t.isEmpty) return;
    p.title = t;
    notifyListeners();
    scheduleSave(trackRevisionForPageId: id);
  }

  void setPageAclEntry({
    required String pageId,
    required String profileId,
    required String role,
  }) {
    final acl = _pageAcl.putIfAbsent(pageId, () => <String, String>{});
    acl[profileId] = role;
    notifyListeners();
    scheduleSave();
  }

  void addComment({
    required String pageId,
    required String text,
    String? blockId,
    String? authorProfileId,
  }) {
    final t = text.trim();
    if (t.isEmpty) return;
    final aid =
        authorProfileId ??
        (_localProfiles.isEmpty ? 'local-default' : _localProfiles.first.id);
    _comments.add(
      LocalPageComment(
        id: _uuid.v4(),
        pageId: pageId,
        authorProfileId: aid,
        text: t,
        createdAtMs: DateTime.now().millisecondsSinceEpoch,
        blockId: blockId,
      ),
    );
    notifyListeners();
    scheduleSave();
  }

  void setPageParent(String pageId, String? newParentId) {
    if (pageId == newParentId) return;
    if (newParentId != null) {
      if (!_pages.any((p) => p.id == newParentId)) return;
      if (_isDescendant(ancestorId: pageId, nodeId: newParentId)) return;
    }
    final p = _pages.firstWhere((e) => e.id == pageId);
    p.parentId = newParentId;
    notifyListeners();
    scheduleSave(trackRevisionForPageId: pageId);
  }

  /// Verdadero si [nodeId] está bajo [ancestorId] en el árbol.
  bool isUnderAncestor({required String ancestorId, required String nodeId}) {
    return _isDescendant(ancestorId: ancestorId, nodeId: nodeId);
  }

  bool _isDescendant({required String ancestorId, required String nodeId}) {
    var cur = _pageById(nodeId);
    while (cur != null) {
      if (cur.parentId == ancestorId) return true;
      if (cur.parentId == null) return false;
      cur = _pageById(cur.parentId!);
    }
    return false;
  }

  void updateBlockText(String pageId, String blockId, String text) {
    final page = _pageById(pageId);
    if (page == null) return;
    final b = _blockById(page, blockId);
    if (b == null) return;
    if (b.type == 'image' && b.text.isNotEmpty && b.text != text) {
      _deleteManagedAttachmentIfUnused(
        b.text,
        excludingPageId: pageId,
        excludingBlockId: blockId,
      );
    }
    b.text = text;
    notifyListeners();
    scheduleSave(trackRevisionForPageId: pageId);
  }

  void setBlockChecked(String pageId, String blockId, bool checked) {
    final page = _pageById(pageId);
    if (page == null) return;
    final b = _blockById(page, blockId);
    if (b == null || b.type != 'todo') return;
    b.checked = checked;
    notifyListeners();
    scheduleSave(trackRevisionForPageId: pageId);
  }

  void setBlockExpanded(String pageId, String blockId, bool expanded) {
    final page = _pageById(pageId);
    if (page == null) return;
    final b = _blockById(page, blockId);
    if (b == null || b.type != 'toggle') return;
    b.expanded = expanded;
    notifyListeners();
    scheduleSave(trackRevisionForPageId: pageId);
  }

  void updateBlockIcon(String pageId, String blockId, String? icon) {
    final page = _pageById(pageId);
    if (page == null) return;
    final b = _blockById(page, blockId);
    if (b == null) return;
    b.icon = icon;
    notifyListeners();
    scheduleSave(trackRevisionForPageId: pageId);
  }

  void updateBlockUrl(String pageId, String blockId, String? url) {
    final page = _pageById(pageId);
    if (page == null) return;
    final b = _blockById(page, blockId);
    if (b == null) return;
    final old = b.url;
    if (_isManagedAttachmentPath(old) && old != url) {
      _deleteManagedAttachmentIfUnused(
        old!,
        excludingPageId: pageId,
        excludingBlockId: blockId,
      );
    }
    b.url = url;
    notifyListeners();
    scheduleSave(trackRevisionForPageId: pageId);
  }

  void setBlockImageWidth(String pageId, String blockId, double width) {
    final page = _pageById(pageId);
    if (page == null) return;
    final b = _blockById(page, blockId);
    if (b == null) return;
    const mediaTypes = {'image', 'file', 'video', 'audio', 'bookmark', 'embed'};
    if (!mediaTypes.contains(b.type)) return;
    final clamped = width.clamp(0.2, 1.0);
    final current = b.imageWidth ?? 1.0;
    if ((current - clamped).abs() < 0.001) return;
    b.imageWidth = clamped;
    notifyListeners();
    scheduleSave(trackRevisionForPageId: pageId);
  }

  void changeBlockType(String pageId, String blockId, String newType) {
    final page = _pageById(pageId);
    if (page == null) return;
    final b = _blockById(page, blockId);
    if (b == null) return;
    final oldType = b.type;
    if (oldType == 'image' && newType != 'image' && b.text.isNotEmpty) {
      _deleteManagedAttachmentIfUnused(
        b.text,
        excludingPageId: pageId,
        excludingBlockId: blockId,
      );
    }
    if ((oldType == 'file' || oldType == 'video' || oldType == 'audio') &&
        newType != oldType &&
        _isManagedAttachmentPath(b.url)) {
      _deleteManagedAttachmentIfUnused(
        b.url!,
        excludingPageId: pageId,
        excludingBlockId: blockId,
      );
      b.url = null;
    }
    if (oldType == 'embed' && newType != 'embed') {
      final u = b.url?.trim() ?? '';
      if (u.isNotEmpty) {
        b.text = u;
      }
      b.url = null;
    }
    if (oldType == 'bookmark' && newType != 'bookmark') {
      final u = b.url?.trim() ?? '';
      final title = b.text.trim();
      if (u.isNotEmpty) {
        b.text = title.isEmpty ? u : '[$title]($u)';
      }
      b.url = null;
    }
    if (oldType == 'image' && newType != 'image') {
      b.text = '';
    } else if (oldType == 'table' && newType != 'table') {
      b.text = '';
    } else if (oldType == 'database' && newType != 'database') {
      b.text = '';
    }
    b.type = newType;
    if (newType != 'todo') {
      b.checked = null;
    } else {
      b.checked = b.checked ?? false;
    }
    if (newType != 'toggle') {
      b.expanded = null;
    } else {
      b.expanded = b.expanded ?? false;
    }
    if (newType == 'table') {
      if (b.text.isEmpty || FolioTableData.tryParse(b.text) == null) {
        b.text = FolioTableData.empty().encode();
      }
    } else if (newType == 'database') {
      if (oldType == 'table') {
        final t = FolioTableData.tryParse(b.text) ?? FolioTableData.empty();
        final db = FolioDatabaseData.fromLegacyTable(
          t,
          rowIdPrefix: '${pageId}_r_${_uuid.v4()}',
        );
        b.text = db.encode();
      } else if (b.text.isEmpty || FolioDatabaseData.tryParse(b.text) == null) {
        b.text = FolioDatabaseData.empty().encode();
      }
    } else if (newType == 'image' && oldType != 'image') {
      b.text = '';
    }
    if (newType == 'toggle' && oldType != 'toggle') {
      b.text = FolioToggleData.empty().encode();
    }
    if (newType == 'equation' &&
        oldType != 'equation' &&
        b.text.trim().isEmpty) {
      b.text = r'E = mc^2';
    }
    if (newType == 'toc' || newType == 'breadcrumb') {
      b.text = '';
    }
    if (newType == 'child_page' && oldType != 'child_page') {
      b.text = '';
    }
    if (newType == 'template_button' && oldType != 'template_button') {
      b.text = FolioTemplateButtonData.defaultNew().encode();
    }
    if (newType == 'column_list' && oldType != 'column_list') {
      b.text = FolioColumnsData.empty().encode();
    }
    if (newType == 'code' && oldType != 'code') {
      b.codeLanguage ??= 'dart';
    }
    if (newType == 'equation' && oldType != 'equation') {
      b.codeLanguage ??= 'plaintext';
    }
    if (newType != 'code' && newType != 'equation') {
      b.codeLanguage = null;
    }
    notifyListeners();
    scheduleSave(trackRevisionForPageId: pageId);
  }

  void setBlockCodeLanguage(String pageId, String blockId, String languageId) {
    final page = _pageById(pageId);
    if (page == null) return;
    final b = _blockById(page, blockId);
    if (b == null || b.type != 'code') return;
    b.codeLanguage = languageId;
    notifyListeners();
    scheduleSave(trackRevisionForPageId: pageId);
  }

  void insertBlockAfter({
    required String pageId,
    required String afterBlockId,
    required FolioBlock block,
  }) {
    final page = _pageById(pageId);
    if (page == null) return;
    final i = page.blocks.indexWhere((b) => b.id == afterBlockId);
    if (i < 0) return;
    page.blocks.insert(i + 1, block);
    notifyListeners();
    scheduleSave(trackRevisionForPageId: pageId);
  }

  void insertBlocksAfterMany({
    required String pageId,
    required String afterBlockId,
    required List<FolioBlock> blocks,
  }) {
    if (blocks.isEmpty) return;
    final page = _pageById(pageId);
    if (page == null) return;
    final i = page.blocks.indexWhere((b) => b.id == afterBlockId);
    if (i < 0) return;
    page.blocks.insertAll(i + 1, blocks);
    notifyListeners();
    scheduleSave(trackRevisionForPageId: pageId);
  }

  List<FolioBlock> cloneBlocksWithNewIds(
    String pageIdPrefix,
    List<FolioBlock> source,
  ) {
    return source
        .map(
          (b) => FolioBlock(
            id: '${pageIdPrefix}_${_uuid.v4()}',
            type: b.type,
            text: b.text,
            checked: b.checked,
            expanded: b.expanded,
            codeLanguage: b.codeLanguage,
            depth: b.depth,
            icon: b.icon,
            url: b.url,
            imageWidth: b.imageWidth,
          ),
        )
        .toList();
  }

  void insertTemplateFromButton({
    required String pageId,
    required String templateBlockId,
  }) {
    final page = _pageById(pageId);
    if (page == null) return;
    final b = _blockById(page, templateBlockId);
    if (b == null || b.type != 'template_button') return;
    final data = FolioTemplateButtonData.tryParse(b.text);
    if (data == null) return;
    final clones = cloneBlocksWithNewIds(pageId, data.blocks);
    insertBlocksAfterMany(
      pageId: pageId,
      afterBlockId: templateBlockId,
      blocks: clones,
    );
  }

  /// Crea una subpágina bajo la página actual y enlaza el bloque [child_page].
  void createChildPageLinkedToBlock({
    required String pageId,
    required String blockId,
  }) {
    final page = _pageById(pageId);
    if (page == null) return;
    final b = _blockById(page, blockId);
    if (b == null || b.type != 'child_page') return;
    final newId = _uuid.v4();
    _pages.add(
      FolioPage(
        id: newId,
        title: 'Subpágina',
        parentId: pageId,
        blocks: [FolioBlock(id: '${newId}_b0', type: 'paragraph', text: '')],
      ),
    );
    b.text = newId;
    notifyListeners();
    scheduleSave(trackRevisionForPageId: pageId);
    scheduleSave(trackRevisionForPageId: newId);
  }

  void appendBlock({required String pageId, required FolioBlock block}) {
    final page = _pageById(pageId);
    if (page == null) return;
    page.blocks.add(block);
    notifyListeners();
    scheduleSave(trackRevisionForPageId: pageId);
  }

  /// Divide un bloque en dos en el cursor: [before] queda en el actual, [after] en uno nuevo debajo.
  void splitBlockAtCaret({
    required String pageId,
    required String blockId,
    required String before,
    required String after,
  }) {
    final page = _pageById(pageId);
    if (page == null) return;
    final i = page.blocks.indexWhere((b) => b.id == blockId);
    if (i < 0) return;
    final cur = page.blocks[i];
    cur.text = before;
    final sameListType =
        cur.type == 'bullet' || cur.type == 'todo' || cur.type == 'numbered';
    final sameCode = cur.type == 'code' || cur.type == 'equation';
    final nextType = sameListType
        ? cur.type
        : (sameCode ? cur.type : 'paragraph');
    final newBlock = FolioBlock(
      id: '${pageId}_${_uuid.v4()}',
      type: nextType,
      text: after,
      checked: nextType == 'todo' ? false : null,
      expanded: nextType == 'toggle' ? false : null,
      codeLanguage: nextType == 'code' || nextType == 'equation'
          ? cur.codeLanguage
          : null,
      depth: cur.depth,
    );
    page.blocks.insert(i + 1, newBlock);
    notifyListeners();
    scheduleSave(trackRevisionForPageId: pageId);
  }

  /// Inserta un párrafo vacío justo después del bloque indicado.
  void insertEmptyParagraphAfter({
    required String pageId,
    required String afterBlockId,
  }) {
    insertBlockAfter(
      pageId: pageId,
      afterBlockId: afterBlockId,
      block: FolioBlock(
        id: '${pageId}_${_uuid.v4()}',
        type: 'paragraph',
        text: '',
      ),
    );
  }

  /// Fusiona el contenido del bloque actual con el anterior y elimina el actual.
  /// Devuelve `false` si la fusión no aplica (p. ej. tabla o imagen).
  bool mergeBlockUp(String pageId, String blockId) {
    final page = _pageById(pageId);
    if (page == null) return false;
    final i = page.blocks.indexWhere((b) => b.id == blockId);
    if (i <= 0) return false;
    final prev = page.blocks[i - 1];
    final cur = page.blocks[i];
    if (!folioBlocksCanMerge(prev, cur)) {
      return false;
    }
    prev.text = prev.text + cur.text;
    page.blocks.removeAt(i);
    notifyListeners();
    scheduleSave(trackRevisionForPageId: pageId);
    return true;
  }

  /// Mueve el bloque [delta] posiciones (-1 arriba, +1 abajo).
  void moveBlock(String pageId, String blockId, int delta) {
    final page = _pageById(pageId);
    if (page == null) return;
    final i = page.blocks.indexWhere((b) => b.id == blockId);
    final j = i + delta;
    if (i < 0 || j < 0 || j >= page.blocks.length) return;
    final b = page.blocks.removeAt(i);
    page.blocks.insert(j, b);
    notifyListeners();
    scheduleSave(trackRevisionForPageId: pageId);
  }

  /// Aumenta la indentación del bloque actual.
  void indentBlock(String pageId, String blockId) {
    final page = _pageById(pageId);
    if (page == null) return;
    final b = _blockById(page, blockId);
    if (b == null) return;
    if (b.depth < 3) {
      b.depth += 1;
      notifyListeners();
      scheduleSave(trackRevisionForPageId: pageId);
    }
  }

  /// Reduce la indentación del bloque actual.
  void unindentBlock(String pageId, String blockId) {
    final page = _pageById(pageId);
    if (page == null) return;
    final b = _blockById(page, blockId);
    if (b == null) return;
    if (b.depth > 0) {
      b.depth -= 1;
      notifyListeners();
      scheduleSave(trackRevisionForPageId: pageId);
    }
  }

  /// Reordena por arrastre. [newIndex] es el índice destino según [ReorderableListView].
  void reorderBlockAt(String pageId, int oldIndex, int newIndex) {
    final page = _pageById(pageId);
    if (page == null) return;
    final len = page.blocks.length;
    if (oldIndex < 0 || oldIndex >= len) return;
    if (newIndex < 0 || newIndex > len) return;
    var insertAt = newIndex;
    if (insertAt > oldIndex) insertAt -= 1;
    if (insertAt == oldIndex) return;
    final b = page.blocks.removeAt(oldIndex);
    page.blocks.insert(insertAt, b);
    notifyListeners();
    scheduleSave(trackRevisionForPageId: pageId);
  }

  void removeBlockIfMultiple(String pageId, String blockId) {
    final page = _pageById(pageId);
    if (page == null || page.blocks.length <= 1) return;
    FolioBlock? victim;
    for (final b in page.blocks) {
      if (b.id == blockId) {
        victim = b;
        break;
      }
    }
    if (victim != null && victim.type == 'image' && victim.text.isNotEmpty) {
      _deleteManagedAttachmentIfUnused(
        victim.text,
        excludingPageId: pageId,
        excludingBlockId: victim.id,
      );
    }
    if (victim != null &&
        (victim.type == 'file' || victim.type == 'video') &&
        _isManagedAttachmentPath(victim.url)) {
      _deleteManagedAttachmentIfUnused(
        victim.url!,
        excludingPageId: pageId,
        excludingBlockId: victim.id,
      );
    }
    page.blocks.removeWhere((b) => b.id == blockId);
    notifyListeners();
    scheduleSave(trackRevisionForPageId: pageId);
  }

  /// [trackRevisionForPageId]: tras [_revisionIdleDelay] sin más cambios en esa página,
  /// se añade una entrada al historial (si el contenido difiere de la última revisión).
  void scheduleSave({String? trackRevisionForPageId}) {
    if (vaultUsesEncryption && _dek == null) return;
    touchActivity();
    if (trackRevisionForPageId != null) {
      _pageIdsPendingRevision.add(trackRevisionForPageId);
      _revisionIdleTimer?.cancel();
      _revisionIdleTimer = Timer(_revisionIdleDelay, () {
        unawaited(_capturePendingRevisionsAndPersist());
      });
    }
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 450), () {
      _saveDebounce = null;
      notifyListeners();
      unawaited(persistNow());
    });
    notifyListeners();
  }

  Future<void> _capturePendingRevisionsAndPersist() async {
    if (vaultUsesEncryption && _dek == null) return;
    final ids = List<String>.from(_pageIdsPendingRevision);
    _pageIdsPendingRevision.clear();
    for (final id in ids) {
      final p = _pageById(id);
      if (p != null) {
        _appendRevisionSnapshotIfChanged(p);
      }
    }
    await persistNow();
  }

  void _appendRevisionSnapshotIfChanged(FolioPage page) {
    final fp = folioPageContentFingerprint(page);
    final list = _pageRevisions.putIfAbsent(page.id, () => []);
    if (list.isNotEmpty && list.last.contentFingerprint() == fp) {
      return;
    }
    list.add(
      FolioPageRevision(
        revisionId: _uuid.v4(),
        savedAtMs: DateTime.now().millisecondsSinceEpoch,
        title: page.title,
        blocksJson: page.blocks.map((b) => b.toJson()).toList(),
      ),
    );
  }

  /// Revisiones de una página, más recientes primero.
  List<FolioPageRevision> revisionsForPage(String pageId) {
    final list = _pageRevisions[pageId];
    if (list == null || list.isEmpty) return const [];
    final sorted = List<FolioPageRevision>.from(list)
      ..sort((a, b) => b.savedAtMs.compareTo(a.savedAtMs));
    return sorted;
  }

  /// Quita una entrada del historial sin modificar el contenido actual de la página.
  void deletePageRevision(String pageId, String revisionId) {
    if (vaultUsesEncryption && _dek == null) return;
    final list = _pageRevisions[pageId];
    if (list == null || list.isEmpty) return;
    final before = list.length;
    list.removeWhere((r) => r.revisionId == revisionId);
    if (list.isEmpty) {
      _pageRevisions.remove(pageId);
    }
    if (list.length == before) return;
    notifyListeners();
    scheduleSave();
  }

  /// Añade una copia de seguridad del estado actual y restaura [revisionId].
  void restorePageRevision(String pageId, String revisionId) {
    if (vaultUsesEncryption && _dek == null) return;
    final page = _pageById(pageId);
    if (page == null) return;
    final list = _pageRevisions[pageId];
    if (list == null) return;
    final target = list.firstWhereOrNull((r) => r.revisionId == revisionId);
    if (target == null) return;

    final curFp = folioPageContentFingerprint(page);
    final revs = _pageRevisions.putIfAbsent(pageId, () => []);
    if (revs.isEmpty || revs.last.contentFingerprint() != curFp) {
      revs.add(
        FolioPageRevision(
          revisionId: _uuid.v4(),
          savedAtMs: DateTime.now().millisecondsSinceEpoch,
          title: page.title,
          blocksJson: page.blocks.map((b) => b.toJson()).toList(),
        ),
      );
    }

    page.title = target.title;
    page.blocks = target.decodeBlocks();
    _contentEpoch++;
    notifyListeners();
    scheduleSave(trackRevisionForPageId: pageId);
  }

  Future<void> persistNow() async {
    if (vaultUsesEncryption && _dek == null) return;
    _persistDepth++;
    if (_persistDepth == 1) {
      notifyListeners();
    }
    try {
      await _repo.savePayload(
        VaultPayload(
          version: kVaultPayloadVersion,
          pages: _pages,
          pageRevisions: Map<String, List<FolioPageRevision>>.fromEntries(
            _pageRevisions.entries.map(
              (e) => MapEntry(e.key, List<FolioPageRevision>.from(e.value)),
            ),
          ),
          pageAcl: Map<String, Map<String, String>>.fromEntries(
            _pageAcl.entries.map(
              (e) => MapEntry(e.key, Map<String, String>.from(e.value)),
            ),
          ),
          localProfiles: List<LocalProfile>.from(_localProfiles),
          comments: List<LocalPageComment>.from(_comments),
          aiChatThreads: List<AiChatThreadData>.from(_aiChatThreads),
          aiActiveChatIndex: _aiActiveChatIndex,
        ),
        _dek,
      );
    } finally {
      _persistDepth--;
      if (_persistDepth == 0) {
        notifyListeners();
      }
    }
  }

  bool _dekMatchesQuickStorage(Uint8List dek) {
    if (!vaultUsesEncryption || _dek == null) return false;
    return const ListEquality<int>().equals(dek, _dek!);
  }

  /// Comprueba la contraseña contra el cofre y que coincida con la sesión abierta.
  Future<bool> verifyPasswordMatchesUnlockedSession(String password) async {
    if (_dek == null) return false;
    touchActivity();
    try {
      final dek = await _repo.unlockWithPassword(password);
      return const ListEquality<int>().equals(dek, _dek!);
    } catch (_) {
      return false;
    }
  }

  /// Hello / biometría + DEK almacenada debe coincidir con la sesión.
  Future<void> verifyQuickUnlockMatchesSession() async {
    if (_dek == null) {
      throw StateError('Cofre no desbloqueado');
    }
    touchActivity();
    final vid = _vaultId;
    if (vid == null) {
      throw StateError('No hay cofre activo');
    }
    final enabled = await _quick.isEnabled(vid);
    if (!enabled) {
      throw StateError('Desbloqueo rápido no configurado');
    }
    final supported = await _localAuth.isDeviceSupported();
    if (!supported) {
      throw StateError('No disponible en este dispositivo');
    }
    final ok = await _localAuth.authenticate(
      localizedReason: 'Confirma tu identidad para borrar el cofre',
    );
    if (!ok) {
      throw StateError('Autenticación cancelada');
    }
    final dek = await _quick.readDek(vid);
    if (dek == null || !_dekMatchesQuickStorage(dek)) {
      throw StateError('No se pudo verificar el desbloqueo rápido');
    }
  }

  /// Passkey + DEK almacenada debe coincidir con la sesión.
  Future<void> verifyPasskeyMatchesSession() async {
    if (_dek == null) {
      throw StateError('Cofre no desbloqueado');
    }
    touchActivity();
    await _rp.loadFromDisk();
    if (!_rp.hasPasskey) {
      throw StateError('No hay passkey registrada');
    }
    final jsonRequest = _rp.startPasskeyLogin();
    final request = AuthenticateRequestType.fromJsonString(jsonRequest);
    final response = await _passkeys.authenticate(request);
    await _rp.finishPasskeyLogin(response: response.toJsonString());
    final vid = _vaultId;
    if (vid == null) {
      throw StateError('No hay cofre activo');
    }
    final dek = await _quick.readDek(vid);
    if (dek == null || !_dekMatchesQuickStorage(dek)) {
      throw StateError('No coincide la clave tras la passkey');
    }
  }

  /// Borra el cofre **activo** por completo y actualiza el registro.
  Future<void> wipeVaultAndReset() async {
    _saveDebounce?.cancel();
    _saveDebounce = null;
    _revisionIdleTimer?.cancel();
    _revisionIdleTimer = null;
    _pageIdsPendingRevision.clear();

    final id = _vaultId;
    if (id == null) {
      _dek = null;
      _pages = [];
      _pageRevisions.clear();
      _aiChatThreads
        ..clear()
        ..add(
          const AiChatThreadData(id: 'chat_0', title: 'Chat 1', messages: []),
        );
      _aiActiveChatIndex = 0;
      _contentEpoch = 0;
      _selectedPageId = null;
      notifyListeners();
      await bootstrap();
      return;
    }

    await _quick.disable(id);
    await VaultPaths.deleteVaultDirectory(id);
    await _registry.remove(id);

    _dek = null;
    _pages = [];
    _pageRevisions.clear();
    _aiChatThreads
      ..clear()
      ..add(
        const AiChatThreadData(id: 'chat_0', title: 'Chat 1', messages: []),
      );
    _aiActiveChatIndex = 0;
    _contentEpoch = 0;
    _selectedPageId = null;
    _resumeVaultIdAfterNewVault = null;
    notifyListeners();

    await _registry.load();
    if (_registry.vaults.isEmpty) {
      VaultPaths.clearActiveVaultId();
      await _registry.setActiveVaultId(null);
    } else {
      final next = _registry.vaults.first.id;
      await _registry.setActiveVaultId(next);
      VaultPaths.setActiveVaultId(next);
    }
    await bootstrap();
  }

  Future<void> changeMasterPassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (!vaultUsesEncryption) {
      throw StateError('Este cofre no usa contraseña');
    }
    if (_dek == null) {
      throw StateError('Cofre no desbloqueado');
    }
    final currentOk = await verifyPasswordMatchesUnlockedSession(
      currentPassword,
    );
    if (!currentOk) {
      throw StateError('Contraseña actual incorrecta');
    }
    await _repo.rewrapDek(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
    final vid = _vaultId;
    if (vid != null) {
      final quickEnabled = await _quick.isEnabled(vid);
      if (quickEnabled) {
        await _quick.enableWithDek(vid, Uint8List.fromList(_dek!));
      }
    }
    touchActivity();
  }

  /// Cifra un cofre que estaba solo en disco en texto plano. La sesión sigue abierta.
  Future<void> enableVaultEncryption(String password) async {
    if (_state != VaultFlowState.unlocked) {
      throw StateError('Cofre no desbloqueado');
    }
    if (vaultUsesEncryption) {
      throw StateError('El cofre ya está cifrado');
    }
    if (!(await _repo.isPlaintextVault())) {
      throw StateError('Cofre no reconocido como texto plano');
    }
    if (password.isEmpty) {
      throw ArgumentError('Contraseña vacía');
    }

    final payload = VaultPayload(
      version: kVaultPayloadVersion,
      pages: _pages,
      pageRevisions: Map<String, List<FolioPageRevision>>.fromEntries(
        _pageRevisions.entries.map(
          (e) => MapEntry(e.key, List<FolioPageRevision>.from(e.value)),
        ),
      ),
      pageAcl: Map<String, Map<String, String>>.fromEntries(
        _pageAcl.entries.map(
          (e) => MapEntry(e.key, Map<String, String>.from(e.value)),
        ),
      ),
      localProfiles: List<LocalProfile>.from(_localProfiles),
      comments: List<LocalPageComment>.from(_comments),
      aiChatThreads: List<AiChatThreadData>.from(_aiChatThreads),
      aiActiveChatIndex: _aiActiveChatIndex,
    );

    final dekBytes = await _repo.encryptPlainVaultWithPassword(
      payload: payload,
      password: password,
    );
    _dek = dekBytes.toList();
    _vaultUsesEncryption = true;
    touchActivity();
    _restartIdleLockTimer();
    notifyListeners();
  }

  List<VaultSearchResult> searchGlobal(String query, {int limit = 80}) {
    final q = query.trim().toLowerCase();
    if (_state != VaultFlowState.unlocked ||
        (vaultUsesEncryption && _dek == null) ||
        q.isEmpty) {
      return const [];
    }
    touchActivity();
    final out = <VaultSearchResult>[];
    for (final page in _pages) {
      final pageTitle = page.title.trim().isEmpty ? 'Sin título' : page.title;
      if (pageTitle.toLowerCase().contains(q)) {
        out.add(
          VaultSearchResult(
            pageId: page.id,
            pageTitle: pageTitle,
            snippet: _snippetAround(pageTitle, q),
          ),
        );
      }
      for (final block in page.blocks) {
        final haystack = _blockSearchText(block);
        if (!haystack.toLowerCase().contains(q)) continue;
        out.add(
          VaultSearchResult(
            pageId: page.id,
            pageTitle: pageTitle,
            blockId: block.id,
            snippet: _snippetAround(haystack, q),
          ),
        );
        if (out.length >= limit) return out;
      }
      if (out.length >= limit) return out;
    }
    return out;
  }

  List<FolioPage> backlinksForPage(String pageId) {
    final target = _pageById(pageId);
    if (target == null) return const [];
    final key = '[[${target.title.trim()}]]'.toLowerCase();
    if (key == '[[]]') return const [];
    final out = <FolioPage>[];
    for (final p in _pages) {
      if (p.id == pageId) continue;
      final has = p.blocks.any((b) => b.text.toLowerCase().contains(key));
      if (has) out.add(p);
    }
    return out;
  }

  Future<List<AiFileAttachment>> buildAiAttachmentsFromPaths(
    List<String> filePaths,
  ) async {
    final out = <AiFileAttachment>[];
    for (final rawPath in filePaths) {
      final fp = rawPath.trim();
      if (fp.isEmpty) continue;
      final f = File(fp);
      if (!f.existsSync()) continue;
      final mimeType = AiSafetyPolicy.detectMimeType(fp);
      final content = AiSafetyPolicy.isImageMimeType(mimeType)
          ? await AiSafetyPolicy.readImageAsBase64(f)
          : await AiSafetyPolicy.readAttachmentAsContext(f);
      if (content == null || content.trim().isEmpty) continue;
      out.add(
        AiFileAttachment(
          name: f.uri.pathSegments.isEmpty ? fp : f.uri.pathSegments.last,
          mimeType: mimeType,
          content: content,
        ),
      );
    }
    return out;
  }

  Future<String> rewriteBlockWithAi({
    required String pageId,
    required String blockId,
    required String instruction,
    List<AiFileAttachment> attachments = const [],
  }) async {
    if (_state != VaultFlowState.unlocked ||
        (vaultUsesEncryption && _dek == null)) {
      throw StateError('Debes desbloquear el cofre para usar IA.');
    }
    final ai = _aiService;
    if (ai == null) throw StateError('IA no configurada.');
    final page = _pageById(pageId);
    if (page == null) throw StateError('Página no encontrada.');
    final block = _blockById(page, blockId);
    if (block == null) throw StateError('Bloque no encontrado.');
    final prompt =
        '$_quillIdentityLeadEs'
        'Tarea: reescribir un bloque sin resumir la página completa. '
        'Devuelve exclusivamente el texto final del bloque, sin markdown fences ni explicación.\n\n'
        'Página: ${page.title}\n'
        'Bloque actual:\n${block.text}\n\n'
        'Instrucción:\n${instruction.trim()}';
    final result = await ai.complete(
      AiCompletionRequest(
        prompt: prompt,
        model: 'auto',
        attachments: attachments,
      ),
    );
    final text = result.text.trim();
    if (text.isEmpty) throw StateError('La IA devolvió texto vacío.');
    updateBlockText(pageId, blockId, text);
    return text;
  }

  Future<({String text, AiTokenUsage? usage})> summarizePageWithAi(
    String pageId, {
    List<AiFileAttachment> attachments = const [],
  }) async {
    if (_state != VaultFlowState.unlocked ||
        (vaultUsesEncryption && _dek == null)) {
      throw StateError('Debes desbloquear el cofre para usar IA.');
    }
    final ai = _aiService;
    if (ai == null) throw StateError('IA no configurada.');
    final page = _pageById(pageId);
    if (page == null) throw StateError('Página no encontrada.');
    final prompt =
        '$_quillIdentityLeadEs'
        'Resume esta página en español de forma breve y accionable.\n'
        'Título: ${page.title}\n'
        'Contenido:\n${page.plainTextContent}';
    final result = await ai.complete(
      AiCompletionRequest(
        prompt: prompt,
        model: 'auto',
        attachments: attachments,
      ),
    );
    return (text: result.text.trim(), usage: result.usage);
  }

  Future<void> generateContentWithAi({
    required String pageId,
    required String prompt,
    List<AiFileAttachment> attachments = const [],
  }) async {
    if (_state != VaultFlowState.unlocked ||
        (vaultUsesEncryption && _dek == null)) {
      throw StateError('Debes desbloquear el cofre para usar IA.');
    }
    final ai = _aiService;
    if (ai == null) throw StateError('IA no configurada.');
    final page = _pageById(pageId);
    if (page == null) throw StateError('Página no encontrada.');
    final fullPrompt =
        '$_quillIdentityLeadEs'
        'Genera NUEVO contenido para insertar en una página existente. '
        'No hagas resumen del contexto salvo que se pida explícitamente.\n'
        'Salida preferida: JSON válido con forma {"blocks":[{"type":"paragraph|h1|h2|h3|bullet|todo|quote|code|divider","text":"...","checked":false,"codeLanguage":"dart"}]}.\n'
        'También puedes devolver markdown estructurado si no puedes JSON. Sin markdown fences.\n\n'
        'Contexto de la página: ${page.title}\n'
        'Contenido actual:\n${page.plainTextContent}\n\n'
        'Solicitud:\n${prompt.trim()}';
    final result = await ai.complete(
      AiCompletionRequest(
        prompt: fullPrompt,
        model: 'auto',
        attachments: attachments,
      ),
    );
    final parsed = _parseAiHybridOutput(result.text, defaultTitle: page.title);
    final generated = _materializeAiBlocks(page.id, parsed.blocks);
    for (final line in generated) {
      insertBlockAfter(
        pageId: page.id,
        afterBlockId: page.blocks.last.id,
        block: line,
      );
    }
  }

  Future<String> generateStandalonePageWithAi({
    required String prompt,
    String? parentId,
    List<AiFileAttachment> attachments = const [],
  }) async {
    if (_state != VaultFlowState.unlocked ||
        (vaultUsesEncryption && _dek == null)) {
      throw StateError('Debes desbloquear el cofre para usar IA.');
    }
    final ai = _aiService;
    if (ai == null) throw StateError('IA no configurada.');
    final result = await ai.complete(
      AiCompletionRequest(
        prompt:
            '$_quillIdentityLeadEs'
            'Genera una página completa de notas.\n'
            'Salida preferida: JSON válido con forma {"title":"...","blocks":[{"type":"paragraph|h1|h2|h3|bullet|todo|quote|code|divider","text":"...","checked":false,"codeLanguage":"dart"}]}.\n'
            'Si no puedes JSON, devuelve markdown estructurado. Sin markdown fences.\n\n'
            'Solicitud:\n${prompt.trim()}',
        model: 'auto',
        attachments: attachments,
      ),
    );
    final draft = _parseAiHybridOutput(
      result.text,
      defaultTitle: 'Nueva página IA',
    );
    final id = _uuid.v4();
    final blocks = _materializeAiBlocks(id, draft.blocks);
    _pages.add(
      FolioPage(
        id: id,
        title: draft.title.trim().isEmpty ? 'Nueva página IA' : draft.title,
        parentId: parentId,
        blocks: blocks,
      ),
    );
    _selectedPageId = id;
    notifyListeners();
    scheduleSave(trackRevisionForPageId: id);
    return id;
  }

  List<String> _resolveAiChatContextPageIds({
    required bool includePageContext,
    required List<String> contextPageIds,
    String? scopePageId,
  }) {
    if (!includePageContext) return const [];
    final seen = <String>{};
    final out = <String>[];
    void add(String id) {
      if (_pageById(id) == null) return;
      if (seen.add(id)) out.add(id);
    }

    if (contextPageIds.isNotEmpty) {
      for (final id in contextPageIds) {
        add(id);
      }
      return out;
    }
    if (scopePageId != null) add(scopePageId);
    return out;
  }

  String _buildAiChatPagesTextContext(
    List<String> pageIds, {
    required bool isEs,
  }) {
    if (pageIds.isEmpty) {
      return isEs
          ? '(No hay páginas de texto en el contexto.)'
          : '(No pages in the text context.)';
    }
    final buf = StringBuffer();
    for (var i = 0; i < pageIds.length; i++) {
      final p = _pageById(pageIds[i]);
      if (p == null) continue;
      if (buf.isNotEmpty) buf.writeln();
      buf.writeln('--- ${i + 1}. ${p.title} ---');
      buf.writeln(p.plainTextContent);
    }
    return buf.toString();
  }

  String _plainChatContextFromPageIds(List<String> pageIds) {
    if (pageIds.isEmpty) return '';
    final b = StringBuffer('\n\nContexto de páginas:\n');
    for (final id in pageIds) {
      final p = _pageById(id);
      if (p == null) continue;
      b.writeln('Título: ${p.title}');
      b.writeln(p.plainTextContent);
      b.writeln();
    }
    return b.toString();
  }

  /// Ayuda in-app inyectada en el agente: evita que «página» se interprete como web genérica.
  String _folioAgentInAppGuide({required bool isEs}) {
    if (isEs) {
      return '''
IDENTIDAD: Tu nombre es Quill. Si te presentas o hablas de ti, usa ese nombre.

=== Folio — no confundir con sitios web genéricos ===
En Folio, «página» = nota del árbol lateral con bloques (párrafo, imagen, tabla…). El usuario pregunta por Folio salvo que cite explícitamente WordPress, HTML, React, etc.
NO respondas con etiquetas HTML <img>, CMS ni frameworks web ante frases como «añadir imagen a la página», «bloque», «nota», «mi página en Folio».

Ayuda frecuente (respuestas breves y concretas):
• Imagen: con una página abierta, botón flotante + (abajo a la derecha) → bloque «Imagen». Alternativa: en un párrafo escribe / y elige «Imagen». En bloque vacío, «Elegir imagen»: en escritorio suele abrir el selector de archivos; en móvil, galería. Pegar una URL directa a un archivo de imagen en un bloque de texto puede convertirlo en bloque imagen. Menú ⋮ del bloque: cambiar o quitar imagen; puedes ajustar el ancho mostrado.
• Otros bloques: mismo botón + o comando / en párrafo (tabla, archivo, código, etc.).
• Panel de chat con Quill (si está activo): a la derecha; icono de libro incluye u omite texto de páginas en el contexto; otro icono elige varias páginas de referencia.
• Ajustes: engranaje. Búsqueda: lupa. Bloquear cofre: candado.
'''
          .trim();
    }
    return '''
IDENTITY: Your name is Quill. When you introduce yourself or refer to yourself, use that name.

=== Folio — not a generic website ===
In Folio a "page" is a sidebar note made of blocks. The user means Folio unless they explicitly name WordPress, HTML, React, etc.
Do NOT answer Folio how-to questions with HTML <img>, CMS steps, or web frameworks.

Quick help (be concise):
• Image: With a page open, floating + (bottom-right) → "Image" block. Or type / in a paragraph and pick Image. In an empty image block use "Choose image" (desktop: file picker; mobile: gallery). Pasting a direct image file URL in a text block may turn it into an image block. Block ⋮ menu: replace/clear; adjust width.
• Other blocks: same + button or / in a paragraph.
• Quill chat panel (when enabled): on the right; book icon toggles page text in context; another icon picks multiple reference pages.
• Settings: gear. Search: magnifying glass. Lock vault: padlock.
'''
        .trim();
  }

  Future<({String text, AiTokenUsage? usage})> chatWithAi({
    required List<AiChatMessage> messages,
    required String prompt,
    String? scopePageId,
    bool includePageContext = true,
    List<String> contextPageIds = const [],
    List<AiFileAttachment> attachments = const [],
    String languageCode = 'es',
  }) async {
    if (_state != VaultFlowState.unlocked ||
        (vaultUsesEncryption && _dek == null)) {
      throw StateError('Debes desbloquear el cofre para usar IA.');
    }
    final ai = _aiService;
    if (ai == null) throw StateError('IA no configurada.');
    final effective = _resolveAiChatContextPageIds(
      includePageContext: includePageContext,
      contextPageIds: contextPageIds,
      scopePageId: scopePageId,
    );
    final scopedContext = includePageContext
        ? _plainChatContextFromPageIds(effective)
        : '';
    final isEsChat = languageCode.toLowerCase().startsWith('es');
    final folioGuide = _folioAgentInAppGuide(isEs: isEsChat);
    final result = await ai.complete(
      AiCompletionRequest(
        prompt: '$folioGuide\n\n${prompt.trim()}$scopedContext',
        model: 'auto',
        messages: messages,
        attachments: attachments,
      ),
    );
    return (text: result.text.trim(), usage: result.usage);
  }

  Future<AgentChatOutcome> agentChatWithAi({
    required List<AiChatMessage> messages,
    required String prompt,
    String? scopePageId,
    bool includePageContext = true,
    List<String> contextPageIds = const [],
    List<AiFileAttachment> attachments = const [],
    String languageCode = 'es',
  }) async {
    if (_state != VaultFlowState.unlocked ||
        (vaultUsesEncryption && _dek == null)) {
      throw StateError('Debes desbloquear el cofre para usar IA.');
    }
    final ai = _aiService;
    if (ai == null) throw StateError('IA no configurada.');
    await pingAi();
    AiTokenUsage? lastUsage;
    AgentChatOutcome finish(String reply) =>
        AgentChatOutcome(reply: reply, usage: lastUsage);
    final isEs = languageCode.toLowerCase().startsWith('es');
    final scopePage = scopePageId == null ? null : _pageById(scopePageId);
    final effectiveContextIds = _resolveAiChatContextPageIds(
      includePageContext: includePageContext,
      contextPageIds: contextPageIds,
      scopePageId: scopePageId,
    );
    final wantsSubpage = _looksLikeSubpageIntent(
      prompt,
      languageCode: languageCode,
    );
    final promptTrimmed = prompt.trim();
    AppLogger.info(
      'Agent chat started',
      tag: 'ai.agent',
      context: {
        'languageCode': languageCode,
        'hasScopePage': scopePage != null,
        'includePageContext': includePageContext,
        'contextPageCount': effectiveContextIds.length,
        'wantsSubpage': wantsSubpage,
        'promptPreview': promptTrimmed.length > 140
            ? '${promptTrimmed.substring(0, 140)}...'
            : promptTrimmed,
      },
    );
    final referencePagesText = includePageContext
        ? _buildAiChatPagesTextContext(effectiveContextIds, isEs: isEs)
        : (isEs
              ? 'El usuario desactivó el contexto de páginas: no debes asumir ni citar contenido de notas.'
              : 'The user disabled page context: do not assume or quote note contents.');
    final pageBlocksContext = includePageContext && scopePage != null
        ? _buildAgentPageBlocksContext(scopePage)
        : '';
    final editTargetLine = scopePage == null
        ? (isEs
              ? 'Página en edición: ninguna abierta.'
              : 'Page under edit: none open.')
        : (isEs
              ? 'Página en edición (resumen/añadir/reemplazar/editar bloques aplican SOLO aquí): ${scopePage.title}'
              : 'Page under edit (summarize/append/replace/edit blocks apply ONLY here): ${scopePage.title}');
    try {
      final result = await ai.complete(
        AiCompletionRequest(
          prompt:
              '${isEs ? 'Eres Quill, la asistente de IA integrada en Folio (notas locales, árbol de páginas, editor por bloques, búsqueda, cofre con cifrado opcional, panel de chat a la derecha). Ayudas con el contenido de las notas y con cómo usar la app; en modo chat sé clara, útil y natural.' : 'You are Quill, Folio\'s built-in AI assistant (local notes, page tree, block editor, search, optional encrypted vault, chat panel on the side). You help with note content and how to use the app; in chat mode be clear, helpful, and natural.'}\n'
              '${_folioAgentInAppGuide(isEs: isEs)}\n\n'
              '${isEs ? 'Devuelve SOLO JSON válido con este esquema:' : 'Return ONLY valid JSON with this schema:'}\n'
              '{'
              '"mode":"chat|summarize_current|append_current|replace_current|edit_current|create_page",'
              '"reason":"${isEs ? 'explicación breve (1 frase) de por qué eliges ese modo' : 'brief explanation (1 sentence) of why you chose this mode'}",'
              '"reply":"${isEs ? 'texto breve para usuario' : 'brief user-facing text'}",'
              '"title":"${isEs ? 'solo para create_page' : 'only for create_page'}",'
              '"threadTitle":"${isEs ? 'opcional: título corto para la pestaña de ESTE chat (2-8 palabras), resume el tema de la pregunta; solo si en el hilo hay exactamente un mensaje del usuario (el actual); cadena vacía si no aplica o en turnos posteriores' : 'optional: short tab title for THIS chat (2-8 words) summarizing the question; only if the thread has exactly one user message (this one); empty string if N/A or on later turns'}",'
              '"blocks":[{"type":"paragraph|h1|h2|h3|bullet|todo|quote|code|divider|table","text":"...","checked":false,"codeLanguage":"dart","cols":2,"rows":[["a","b"]]}],'
              '"operations":[{"kind":"update_page_title|update_block_text|replace_block|insert_after|delete_block|table_add_column|table_set_cell","title":"${isEs ? 'nuevo título (solo update_page_title)' : 'new title (update_page_title only)'}","blockId":"id","text":"...","block":{},"blocks":[],"header":"...","values":[],"row":0,"col":0,"value":"..."}]'
              '}\n'
              '${isEs ? 'Reglas:' : 'Rules:'}\n'
              '- summarize_current: ${isEs ? 'resume la página activa' : 'summarize the active page'}.\n'
              '- append_current: ${isEs ? 'añade bloques a la página activa' : 'append blocks to the active page'}.\n'
              '- replace_current: ${isEs ? 'sustituye bloques de la página activa' : 'replace blocks in the active page'}.\n'
              '- edit_current: ${isEs ? 'edita con operations: bloques (blockId) y/o título de página (update_page_title + title)' : 'edit with operations: blocks (blockId) and/or page title (update_page_title + title)'}.\n'
              '- create_page: ${isEs ? 'crea una nueva página con title + blocks' : 'create a new page with title + blocks'}.\n'
              '- chat: ${isEs ? 'respuesta conversacional sin modificar datos; puedes referirte a ti como Quill cuando encaje; ayuda sobre Folio (interfaz, ajustes, atajos, páginas, bloques) cuando pregunte por la app' : 'conversational response without modifying data; you may refer to yourself as Quill when it fits; help with Folio (UI, settings, shortcuts, pages, blocks) when the user asks about the app'}.\n'
              '- ${isEs ? 'Preguntas del tipo «cómo hago…», «dónde está…», «qué es…» en Folio → modo chat; sé útil y directo; no inventes funciones: si no lo sabes, dilo y sugiere revisar Ajustes o probar en la interfaz' : 'Questions like how/where/what in Folio → chat mode; be helpful and direct; do not invent features—if unsure, say so and suggest Settings or exploring the UI'}.\n'
              '- ${isEs ? 'Para ayuda de uso de Folio, basa la respuesta en el bloque «=== Folio» de arriba. NUNCA des tutoriales de páginas web (HTML <img>, WordPress, Wix, React, FTP…) salvo que el usuario pida explícitamente eso.' : 'For Folio how-to, base answers on the «=== Folio» block above. NEVER give generic web tutorials (HTML <img>, WordPress, Wix, React, FTP…) unless the user explicitly asks for that.'}\n'
              '- ${isEs ? 'Si no hay página activa, NO uses summarize_current/append_current/replace_current/edit_current' : 'If there is no active page, DO NOT use summarize_current/append_current/replace_current/edit_current'}.\n'
              '- ${isEs ? 'Si el contexto de páginas está desactivado, usa solo modo chat (no resumas ni edites páginas).' : 'If page context is disabled, use chat mode only (do not summarize or edit pages).'}\n'
              '- ${isEs ? 'Si hay varias páginas en el texto de referencia, solo la «página en edición» y sus ids de bloque sirven para operaciones que modifican bloques.' : 'If multiple pages appear in reference text, only the page under edit and its block ids are valid for block-changing operations.'}\n'
              '- ${isEs ? 'threadTitle es distinto de title: threadTitle renombra la pestaña del chat; title solo sirve para create_page (nueva página de notas).' : 'threadTitle is not title: threadTitle renames the chat tab; title is only for create_page (new note page).'}\n'
              '- ${isEs ? 'Identidad: siempre eres Quill; no uses otro nombre para ti misma.' : 'Identity: you are always Quill; do not use another name for yourself.'}\n'
              '- ${isEs ? 'No uses markdown fences ni texto fuera del JSON' : 'Do not use markdown fences or extra text outside JSON'}.\n\n'
              '${isEs ? 'Contenido de páginas (referencia; puede haber varias):' : 'Page contents (reference; there may be several):'}\n$referencePagesText\n\n'
              '$editTargetLine\n'
              '${isEs ? 'Bloques de la página en edición (ids para edit_current y similares):' : 'Blocks of the page under edit (ids for edit_current, etc.):'}\n$pageBlocksContext\n\n'
              '${isEs ? 'Mensaje del usuario:' : 'User message:'}\n${prompt.trim()}',
          model: 'auto',
          messages: messages,
          attachments: attachments,
        ),
      );
      lastUsage = result.usage ?? lastUsage;
      final decoded = _decodeJsonObjectLenient(result.text);
      final mode = _normalizeAgentMode(decoded['mode'] as String?);
      final reason = (decoded['reason'] as String? ?? '').trim();
      final reply = (decoded['reply'] as String? ?? '').trim();
      final title = (decoded['title'] as String? ?? 'Nueva página IA').trim();
      final rawBlocks = decoded['blocks'];
      final rawOperations = decoded['operations'];
      final parsedBlocks = rawBlocks is List
          ? _parseAiBlocksFromDynamicList(rawBlocks)
          : const <_AiBlockSpec>[];
      AppLogger.info(
        'Agent mode selected',
        tag: 'ai.agent',
        context: {
          'mode': mode,
          'reason': reason,
          'blocksCount': parsedBlocks.length,
          'hasOperations': rawOperations is List && rawOperations.isNotEmpty,
        },
      );

      _maybeApplyAgentThreadTitle(
        decoded['threadTitle'] as String?,
        conversationMessages: messages,
      );

      if (mode == 'summarize_current') {
        if (scopePage == null) {
          return finish(
            _formatAgentDecisionReply(
              mode: mode,
              reason: reason,
              reply: reply.isNotEmpty
                  ? reply
                  : (isEs
                        ? 'No hay página activa para resumir.'
                        : 'There is no active page to summarize.'),
              isEs: isEs,
            ),
          );
        }
        final summary = await summarizePageWithAi(
          scopePage.id,
          attachments: attachments,
        );
        lastUsage = summary.usage ?? lastUsage;
        return finish(
          _formatAgentDecisionReply(
            mode: mode,
            reason: reason,
            reply: summary.text.isNotEmpty
                ? summary.text
                : (reply.isNotEmpty
                      ? reply
                      : (isEs ? 'Resumen vacío.' : 'Empty summary.')),
            isEs: isEs,
          ),
        );
      }

      if (mode == 'append_current' || mode == 'replace_current') {
        if (scopePage == null) {
          return finish(
            _formatAgentDecisionReply(
              mode: mode,
              reason: reason,
              reply: reply.isNotEmpty
                  ? reply
                  : (isEs
                        ? 'No hay página activa para editar.'
                        : 'There is no active page to edit.'),
              isEs: isEs,
            ),
          );
        }
        final materialized = _materializeAiBlocks(scopePage.id, parsedBlocks);
        if (mode == 'replace_current') {
          scopePage.blocks = materialized;
        } else {
          scopePage.blocks.addAll(materialized);
        }
        notifyListeners();
        scheduleSave(trackRevisionForPageId: scopePage.id);
        return finish(
          _formatAgentDecisionReply(
            mode: mode,
            reason: reason,
            reply: reply.isNotEmpty
                ? reply
                : (mode == 'replace_current'
                      ? 'He actualizado la página.'
                      : 'He añadido contenido a la página.'),
            isEs: isEs,
          ),
        );
      }

      if (mode == 'edit_current') {
        if (scopePage == null) {
          return finish(
            _formatAgentDecisionReply(
              mode: mode,
              reason: reason,
              reply: reply.isNotEmpty
                  ? reply
                  : (isEs
                        ? 'No hay página activa para editar.'
                        : 'There is no active page to edit.'),
              isEs: isEs,
            ),
          );
        }
        final changed = _applyAgentEditOperations(scopePage, rawOperations);
        if (changed) {
          notifyListeners();
          scheduleSave(trackRevisionForPageId: scopePage.id);
        }
        return finish(
          _formatAgentDecisionReply(
            mode: mode,
            reason: reason,
            reply: reply.isNotEmpty
                ? reply
                : (changed
                      ? (isEs
                            ? 'He editado bloques existentes de la página.'
                            : 'I edited existing page blocks.')
                      : (isEs
                            ? 'No se pudieron aplicar cambios en bloques existentes.'
                            : 'Could not apply edits to existing blocks.')),
            isEs: isEs,
          ),
        );
      }

      if (mode == 'create_page') {
        if (wantsSubpage && scopePage == null) {
          return finish(
            _formatAgentDecisionReply(
              mode: mode,
              reason: reason.isNotEmpty
                  ? reason
                  : (isEs
                        ? 'Solicitaste crear una subpágina pero no hay página activa.'
                        : 'You requested a subpage but there is no active page.'),
              reply: isEs
                  ? 'Selecciona una página y vuelvo a crear la subpágina dentro de ella.'
                  : 'Select a page and I will create the subpage inside it.',
              isEs: isEs,
            ),
          );
        }
        final id = _uuid.v4();
        final blocks = _materializeAiBlocks(id, parsedBlocks);
        _pages.add(
          FolioPage(
            id: id,
            title: title.isEmpty ? 'Nueva página IA' : title,
            parentId: wantsSubpage ? scopePage?.id : null,
            blocks: blocks,
          ),
        );
        _selectedPageId = id;
        notifyListeners();
        scheduleSave(trackRevisionForPageId: id);
        AppLogger.info(
          'Page created by agent',
          tag: 'ai.agent',
          context: {
            'pageId': id,
            'isSubpage': wantsSubpage,
            'parentId': wantsSubpage ? scopePage?.id : null,
            'title': title.isEmpty ? 'Nueva página IA' : title,
            'blocksCount': blocks.length,
          },
        );
        return finish(
          _formatAgentDecisionReply(
            mode: mode,
            reason: reason,
            reply: reply.isNotEmpty ? reply : 'He creado una nueva página.',
            isEs: isEs,
          ),
        );
      }

      if (reply.isNotEmpty) {
        if (mode == 'chat' &&
            _looksLikeCreatePageIntent(prompt, languageCode: languageCode)) {
          if (wantsSubpage && scopePage == null) {
            return finish(
              _formatAgentDecisionReply(
                mode: 'create_page',
                reason: isEs
                    ? 'Detecté intención de crear subpágina pero no hay página activa.'
                    : 'Detected subpage creation intent but there is no active page.',
                reply: isEs
                    ? 'Selecciona primero una página para crear la subpágina dentro.'
                    : 'Select a page first to create the subpage inside it.',
                isEs: isEs,
              ),
            );
          }
          final createdId = _createPageFromRecoveredReply(
            reply,
            isEs: isEs,
            parentId: wantsSubpage ? scopePage?.id : null,
          );
          if (createdId != null) {
            AppLogger.info(
              'Recovered page creation from agent reply',
              tag: 'ai.agent',
              context: {
                'pageId': createdId,
                'isSubpage': wantsSubpage,
                'parentId': wantsSubpage ? scopePage?.id : null,
              },
            );
            return finish(
              _formatAgentDecisionReply(
                mode: 'create_page',
                reason: isEs
                    ? 'Detecté intención de crear página y recuperé contenido HTML/Markdown.'
                    : 'Detected page-creation intent and recovered HTML/Markdown content.',
                reply: isEs
                    ? 'He creado una página con el contenido generado.'
                    : 'I created a page with the generated content.',
                isEs: isEs,
              ),
            );
          }
        }
        if (scopePage != null &&
            includePageContext &&
            mode == 'chat' &&
            _looksLikeEditIntent(prompt, languageCode: languageCode) &&
            _applyRecoveredEditFromChatReply(scopePage, reply)) {
          notifyListeners();
          scheduleSave(trackRevisionForPageId: scopePage.id);
          return finish(
            _formatAgentDecisionReply(
              mode: 'edit_current',
              reason: isEs
                  ? 'Detecté edición implícita y apliqué la tabla devuelta en Markdown.'
                  : 'Detected implicit edit intent and applied markdown table output.',
              reply: isEs
                  ? 'He actualizado la tabla existente de la página.'
                  : 'I updated the existing table in the page.',
              isEs: isEs,
            ),
          );
        }
        return finish(
          _formatAgentDecisionReply(
            mode: mode,
            reason: reason,
            reply: reply,
            isEs: isEs,
          ),
        );
      }
      final fallbackChat = await chatWithAi(
        messages: messages,
        prompt: prompt,
        scopePageId: scopePageId,
        includePageContext: includePageContext,
        contextPageIds: contextPageIds,
        attachments: attachments,
        languageCode: languageCode,
      );
      AppLogger.warn(
        'Agent returned non-actionable response, using chat fallback',
        tag: 'ai.agent',
        context: {'mode': mode, 'reason': reason},
      );
      lastUsage = fallbackChat.usage ?? lastUsage;
      return finish(
        _formatAgentDecisionReply(
          mode: mode,
          reason: reason,
          reply: fallbackChat.text,
          isEs: isEs,
        ),
      );
    } catch (e, st) {
      AppLogger.error(
        'Agent JSON flow failed, attempting recovery',
        tag: 'ai.agent',
        error: e,
        stackTrace: st,
      );
      if (scopePage != null && includePageContext) {
        try {
          final recovery = await ai.complete(
            AiCompletionRequest(
              prompt:
                  '${isEs ? _quillIdentityLeadEs : _quillIdentityLeadEn}'
                  '${isEs ? 'La respuesta anterior no fue JSON válido. Corrige y devuelve SOLO JSON para editar la página actual.' : 'The previous response was not valid JSON. Fix it and return ONLY JSON to edit the current page.'}\n'
                  '{'
                  '"mode":"edit_current",'
                  '"reason":"${isEs ? 'motivo breve' : 'short reason'}",'
                  '"reply":"${isEs ? 'texto breve' : 'short text'}",'
                  '"operations":[{"kind":"update_page_title|update_block_text|replace_block|insert_after|delete_block|table_add_column|table_set_cell","title":"...","blockId":"id","text":"...","block":{},"blocks":[],"header":"...","values":[],"row":0,"col":0,"value":"..."}]'
                  '}\n'
                  '${isEs ? 'No escribas explicación, solo JSON.' : 'Do not write explanations, only JSON.'}\n\n'
                  '${isEs ? 'Bloques de la página (ids):' : 'Page blocks (ids):'}\n${_buildAgentPageBlocksContext(scopePage)}\n\n'
                  '${isEs ? 'Mensaje original del usuario:' : 'Original user message:'}\n${prompt.trim()}',
              model: 'auto',
              messages: messages,
              attachments: attachments,
            ),
          );
          lastUsage = recovery.usage ?? lastUsage;
          final recovered = _decodeJsonObjectLenient(recovery.text);
          final mode = _normalizeAgentMode(recovered['mode'] as String?);
          final reason = (recovered['reason'] as String? ?? '').trim();
          final reply = (recovered['reply'] as String? ?? '').trim();
          if (mode == 'edit_current') {
            final changed = _applyAgentEditOperations(
              scopePage,
              recovered['operations'],
            );
            if (changed) {
              notifyListeners();
              scheduleSave(trackRevisionForPageId: scopePage.id);
              return finish(
                _formatAgentDecisionReply(
                  mode: mode,
                  reason: reason.isEmpty
                      ? (isEs
                            ? 'Recuperé una salida estructurada y apliqué la edición.'
                            : 'Recovered structured output and applied the edit.')
                      : reason,
                  reply: reply.isEmpty
                      ? (isEs
                            ? 'He editado bloques existentes de la página.'
                            : 'I edited existing page blocks.')
                      : reply,
                  isEs: isEs,
                ),
              );
            }
          }
        } catch (recoveryError, recoveryStack) {
          AppLogger.error(
            'Agent edit recovery failed',
            tag: 'ai.agent',
            error: recoveryError,
            stackTrace: recoveryStack,
            context: {'scopePageId': scopePage.id},
          );
          // Si también falla la recuperación, caemos a chat.
        }
      }
      final fallbackChat = await chatWithAi(
        messages: messages,
        prompt: prompt,
        scopePageId: scopePageId,
        includePageContext: includePageContext,
        contextPageIds: contextPageIds,
        attachments: attachments,
        languageCode: languageCode,
      );
      lastUsage = fallbackChat.usage ?? lastUsage;
      final wantsCreate = _looksLikeCreatePageIntent(
        prompt,
        languageCode: languageCode,
      );
      if (wantsCreate) {
        if (wantsSubpage && scopePage == null) {
          return finish(
            _formatAgentDecisionReply(
              mode: 'create_page',
              reason: isEs
                  ? 'Detecté intención de crear subpágina pero no hay página activa.'
                  : 'Detected subpage creation intent but there is no active page.',
              reply: isEs
                  ? 'Selecciona primero una página para crear la subpágina dentro.'
                  : 'Select a page first to create the subpage inside it.',
              isEs: isEs,
            ),
          );
        }
        final createdId = _createPageFromRecoveredReply(
          fallbackChat.text,
          isEs: isEs,
          parentId: wantsSubpage ? scopePage?.id : null,
        );
        if (createdId != null) {
          AppLogger.warn(
            'Created page from fallback chat recovery',
            tag: 'ai.agent',
            context: {
              'pageId': createdId,
              'isSubpage': wantsSubpage,
              'parentId': wantsSubpage ? scopePage?.id : null,
            },
          );
          return finish(
            _formatAgentDecisionReply(
              mode: 'create_page',
              reason: isEs
                  ? 'No pude estructurar JSON, pero recuperé el contenido y creé la página.'
                  : 'Could not structure JSON, but recovered content and created the page.',
              reply: isEs
                  ? 'He creado una página con el contenido generado.'
                  : 'I created a page with the generated content.',
              isEs: isEs,
            ),
          );
        }
      }
      return finish(
        _formatAgentDecisionReply(
          mode: 'chat',
          reason: isEs
              ? 'No pude estructurar la acción; respondo en modo conversación.'
              : 'I could not structure the action; responding in chat mode.',
          reply: fallbackChat.text,
          isEs: isEs,
        ),
      );
    }
  }

  String _buildAgentPageBlocksContext(FolioPage page) {
    final items = page.blocks.map((b) {
      final preview = _agentBlockPreview(b);
      final m = <String, dynamic>{
        'id': b.id,
        'type': b.type,
        'preview': preview,
      };
      if (b.type == 'table') {
        final t = FolioTableData.tryParse(b.text);
        if (t != null) {
          m['tableCols'] = t.cols;
          m['tableRows'] = t.rowCount;
        }
      }
      return m;
    }).toList();
    return jsonEncode(items);
  }

  String _agentBlockPreview(FolioBlock block) {
    final raw =
        (block.type == 'table'
                ? FolioTableData.plainTextFromJson(block.text)
                : block.text)
            .trim();
    if (raw.isEmpty) return '';
    return raw.length <= 140 ? raw : '${raw.substring(0, 140)}...';
  }

  bool _applyAgentEditOperations(FolioPage page, dynamic rawOperations) {
    if (rawOperations is! List) return false;
    var changed = false;
    for (final opRaw in rawOperations) {
      if (opRaw is! Map) continue;
      final op = Map<String, dynamic>.from(opRaw);
      final kind = (op['kind'] as String? ?? '').trim().toLowerCase();

      if (kind == 'update_page_title') {
        final newTitle = (op['title'] as String? ?? '').trim();
        if (newTitle.isNotEmpty) {
          page.title = newTitle;
          changed = true;
        }
        continue;
      }

      final blockId = (op['blockId'] as String? ?? '').trim();
      final index = blockId.isEmpty
          ? -1
          : page.blocks.indexWhere((b) => b.id == blockId);

      if (kind == 'update_block_text') {
        final text = (op['text'] as String? ?? '').trim();
        if (index >= 0 && text.isNotEmpty) {
          page.blocks[index].text = text;
          changed = true;
        }
        continue;
      }

      if (kind == 'replace_block') {
        final blockMap = op['block'];
        if (index >= 0 && blockMap is Map) {
          final parsed = _parseAiBlocksFromDynamicList([
            Map<String, dynamic>.from(blockMap),
          ]);
          final mats = _materializeAiBlocks(page.id, parsed);
          if (mats.isNotEmpty) {
            page.blocks[index] = mats.first;
            changed = true;
          }
        }
        continue;
      }

      if (kind == 'insert_after') {
        final blocks = op['blocks'];
        if (index >= 0 && blocks is List) {
          final parsed = _parseAiBlocksFromDynamicList(blocks);
          final mats = _materializeAiBlocks(page.id, parsed);
          if (mats.isNotEmpty) {
            page.blocks.insertAll(index + 1, mats);
            changed = true;
          }
        }
        continue;
      }

      if (kind == 'delete_block') {
        if (index >= 0 && page.blocks.length > 1) {
          page.blocks.removeAt(index);
          changed = true;
        }
        continue;
      }

      if (kind == 'table_add_column') {
        if (index < 0 || page.blocks[index].type != 'table') continue;
        final table = FolioTableData.tryParse(page.blocks[index].text);
        if (table == null) continue;
        final header = (op['header'] as String? ?? '').trim();
        final valuesRaw = op['values'];
        final values = valuesRaw is List
            ? valuesRaw.map((e) => e?.toString() ?? '').toList()
            : const <String>[];
        final previousCols = table.cols;
        table.addCol();
        final newCol = previousCols;
        if (header.isNotEmpty) {
          table.setCell(0, newCol, header);
        }
        for (var row = 1; row < table.rowCount; row++) {
          final i = row - 1;
          final value = i < values.length ? values[i] : '';
          if (value.isNotEmpty) {
            table.setCell(row, newCol, value);
          }
        }
        page.blocks[index].text = table.encode();
        changed = true;
        continue;
      }

      if (kind == 'table_set_cell') {
        if (index < 0 || page.blocks[index].type != 'table') continue;
        final table = FolioTableData.tryParse(page.blocks[index].text);
        if (table == null) continue;
        final row = (op['row'] as num?)?.toInt();
        final col = (op['col'] as num?)?.toInt();
        final value = (op['value'] as String? ?? '');
        if (row == null || col == null || row < 0 || col < 0) continue;
        table.setCell(row, col, value);
        page.blocks[index].text = table.encode();
        changed = true;
      }
    }
    return changed;
  }

  bool _looksLikeEditIntent(String prompt, {required String languageCode}) {
    final p = _normalizeIntentText(prompt);
    final hints = AiIntentHints.hintsFor(
      intent: AiIntentHints.edit,
      languageCode: languageCode,
    );
    return hints.any(p.contains);
  }

  bool _looksLikeCreatePageIntent(
    String prompt, {
    required String languageCode,
  }) {
    final p = _normalizeIntentText(prompt);
    final hints = AiIntentHints.hintsFor(
      intent: AiIntentHints.createPage,
      languageCode: languageCode,
    );
    if (hints.any(p.contains)) return true;
    final hasPagina = p.contains('pagina') || p.contains('page');
    final hasCreateVerb =
        p.contains('crea') ||
        p.contains('crear') ||
        p.contains('creame') ||
        p.contains('genera') ||
        p.contains('generate') ||
        p.contains('create') ||
        p.contains('hazme');
    return hasPagina && hasCreateVerb;
  }

  bool _looksLikeSubpageIntent(String prompt, {required String languageCode}) {
    final p = _normalizeIntentText(prompt);
    final hints = AiIntentHints.hintsFor(
      intent: AiIntentHints.subpage,
      languageCode: languageCode,
    );
    return hints.any(p.contains);
  }

  String _normalizeIntentText(String input) {
    return input
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ñ', 'n');
  }

  bool _applyRecoveredEditFromChatReply(FolioPage page, String reply) {
    final htmlSpecs = _parseHtmlToSpecs(reply);
    if (htmlSpecs.isNotEmpty) {
      final blocks = _materializeAiBlocks(page.id, htmlSpecs);
      final tableIdx = page.blocks.indexWhere((b) => b.type == 'table');
      if (tableIdx >= 0) {
        final firstTable = blocks.firstWhereOrNull((b) => b.type == 'table');
        if (firstTable != null) {
          page.blocks[tableIdx].text = firstTable.text;
          return true;
        }
      }
      page.blocks.addAll(blocks);
      return true;
    }
    final recoveredTable = _parseFirstMarkdownTable(reply);
    if (recoveredTable == null) return false;
    final tableIdx = page.blocks.indexWhere((b) => b.type == 'table');
    if (tableIdx >= 0) {
      page.blocks[tableIdx].text = recoveredTable.encode();
      return true;
    }
    page.blocks.add(
      FolioBlock(
        id: '${page.id}_${_uuid.v4()}',
        type: 'table',
        text: recoveredTable.encode(),
      ),
    );
    return true;
  }

  String? _createPageFromRecoveredReply(
    String reply, {
    required bool isEs,
    String? parentId,
  }) {
    final cleanedRaw = _stripAgentDecisionHeader(reply);
    final cleaned = _stripConversationalPreambleForRecoveredPage(cleanedRaw);
    final htmlSpecs = _parseHtmlToSpecs(cleaned);
    final markdownSpecs = _parseMarkdownToSpecs(cleaned);
    final chosen = htmlSpecs.isNotEmpty ? htmlSpecs : markdownSpecs;
    final finalSpecs = chosen.isEmpty
        ? <_AiBlockSpec>[_AiBlockSpec(type: 'paragraph', text: cleaned.trim())]
        : chosen;
    if (finalSpecs.isEmpty || cleaned.trim().isEmpty) return null;
    final id = _uuid.v4();
    final blocks = _materializeAiBlocks(id, finalSpecs);
    final title =
        _extractRecoveredPageTitle(cleanedRaw) ??
        _extractTitleFromHtml(cleaned) ??
        (isEs ? 'Nueva página IA' : 'New AI page');
    _pages.add(
      FolioPage(
        id: id,
        title: title.trim().isEmpty
            ? (isEs ? 'Nueva página IA' : 'New AI page')
            : title.trim(),
        parentId: parentId,
        blocks: blocks,
      ),
    );
    _selectedPageId = id;
    notifyListeners();
    scheduleSave(trackRevisionForPageId: id);
    return id;
  }

  String? _extractRecoveredPageTitle(String text) {
    final lines = text.replaceAll('\r\n', '\n').split('\n');
    final subpageRe = RegExp(
      r'^\s*(?:[-*]\s*)?(?:📌\s*)?(?:\*\*)?(?:subp[aá]gina|subpage|child page)(?:\*\*)?\s*:\s*["“]?(.+?)["”]?\s*$',
      caseSensitive: false,
    );
    final headingRe = RegExp(r'^\s*#{1,2}\s+(.+?)\s*$');
    for (final raw in lines) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      final sub = subpageRe.firstMatch(line);
      if (sub != null) {
        final t = _stripMarkdownInlineDecorations(sub.group(1) ?? '');
        if (t.isNotEmpty) return t;
      }
      final heading = headingRe.firstMatch(line);
      if (heading != null) {
        final t = _stripMarkdownInlineDecorations(heading.group(1) ?? '');
        if (t.isNotEmpty) return t;
      }
    }
    return null;
  }

  String _stripConversationalPreambleForRecoveredPage(String text) {
    final lines = text.replaceAll('\r\n', '\n').split('\n');
    final kept = <String>[];
    var started = false;
    final subpageRe = RegExp(
      r'^\s*(?:[-*]\s*)?(?:📌\s*)?(?:\*\*)?(?:subp[aá]gina|subpage|child page)(?:\*\*)?\s*:\s*',
      caseSensitive: false,
    );
    bool isStructural(String l) {
      final t = l.trimLeft();
      if (t.startsWith('#') ||
          t.startsWith('- ') ||
          t.startsWith('* ') ||
          t.startsWith('>') ||
          t.startsWith('|') ||
          t.startsWith('```')) {
        return true;
      }
      if (RegExp(r'^\d+\.\s').hasMatch(t)) return true;
      return subpageRe.hasMatch(t);
    }

    for (final line in lines) {
      final trimmed = line.trim();
      final normalized = _normalizeIntentText(trimmed);
      if (!started) {
        final looksPreamble =
            normalized.startsWith('aqui tienes') ||
            normalized.startsWith('te dejo') ||
            normalized.startsWith('a continuacion') ||
            normalized.startsWith('here is') ||
            normalized.startsWith('here you have') ||
            normalized.startsWith('i created');
        if (trimmed.isEmpty ||
            looksPreamble ||
            trimmed == '---' ||
            trimmed == '___') {
          continue;
        }
        if (isStructural(trimmed)) {
          started = true;
          if (!subpageRe.hasMatch(trimmed)) {
            kept.add(line);
          }
          continue;
        }
        started = true;
        kept.add(line);
        continue;
      }
      if (subpageRe.hasMatch(trimmed)) {
        // Ya usamos esta línea como posible título.
        continue;
      }
      kept.add(line);
    }
    return kept.join('\n').trim();
  }

  String _stripMarkdownInlineDecorations(String input) {
    var out = input.trim();
    out = out.replaceAll(RegExp(r'[*_`]+'), '');
    out = out.replaceAll(RegExp(r'\s+'), ' ');
    return out.trim();
  }

  String _stripAgentDecisionHeader(String text) {
    final lines = text.replaceAll('\r\n', '\n').split('\n');
    final out = <String>[];
    var skipping = true;
    for (final line in lines) {
      final t = line.trimLeft();
      if (skipping &&
          (t.startsWith('🧠') ||
              t.startsWith('💡') ||
              t.startsWith('**Decisión') ||
              t.startsWith('**Motivo') ||
              t.startsWith('**Agent decision') ||
              t.startsWith('**Reason'))) {
        continue;
      }
      if (skipping && t.isEmpty) {
        continue;
      }
      skipping = false;
      out.add(line);
    }
    return out.join('\n').trim();
  }

  String _normalizeAgentMode(String? raw) {
    const allowed = {
      'chat',
      'summarize_current',
      'append_current',
      'replace_current',
      'edit_current',
      'create_page',
    };
    final value = (raw ?? '').trim().toLowerCase();
    if (allowed.contains(value)) return value;
    final split = value
        .split(RegExp(r'[|,\s]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    for (final token in split) {
      if (allowed.contains(token)) return token;
    }
    if (value.contains('create_page')) return 'create_page';
    if (value.contains('edit_current')) return 'edit_current';
    if (value.contains('replace_current')) return 'replace_current';
    if (value.contains('append_current')) return 'append_current';
    if (value.contains('summarize_current')) return 'summarize_current';
    return 'chat';
  }

  String? _extractTitleFromHtml(String html) {
    final titleMatch = RegExp(
      r'<title[^>]*>([\s\S]*?)</title>',
      caseSensitive: false,
    ).firstMatch(html);
    if (titleMatch != null) {
      final t = _stripHtmlTags(titleMatch.group(1) ?? '').trim();
      if (t.isNotEmpty) return t;
    }
    final h1Match = RegExp(
      r'<h1[^>]*>([\s\S]*?)</h1>',
      caseSensitive: false,
    ).firstMatch(html);
    if (h1Match != null) {
      final t = _stripHtmlTags(h1Match.group(1) ?? '').trim();
      if (t.isNotEmpty) return t;
    }
    return null;
  }

  List<_AiBlockSpec> _parseHtmlToSpecs(String raw) {
    if (!_looksLikeHtml(raw)) return const [];
    var html = raw.replaceAll('\r\n', '\n');
    html = html.replaceAll(
      RegExp(r'<script[^>]*>.*?</script>', caseSensitive: false, dotAll: true),
      '',
    );
    html = html.replaceAll(
      RegExp(r'<style[^>]*>.*?</style>', caseSensitive: false, dotAll: true),
      '',
    );
    final specs = <_AiBlockSpec>[];

    final h1 = RegExp(
      r'<h1[^>]*>(.*?)</h1>',
      caseSensitive: false,
      dotAll: true,
    );
    final h2 = RegExp(
      r'<h2[^>]*>(.*?)</h2>',
      caseSensitive: false,
      dotAll: true,
    );
    final h3 = RegExp(
      r'<h3[^>]*>(.*?)</h3>',
      caseSensitive: false,
      dotAll: true,
    );
    final p = RegExp(r'<p[^>]*>(.*?)</p>', caseSensitive: false, dotAll: true);
    final li = RegExp(
      r'<li[^>]*>(.*?)</li>',
      caseSensitive: false,
      dotAll: true,
    );
    final bq = RegExp(
      r'<blockquote[^>]*>(.*?)</blockquote>',
      caseSensitive: false,
      dotAll: true,
    );
    final pre = RegExp(
      r'<pre[^>]*>(.*?)</pre>',
      caseSensitive: false,
      dotAll: true,
    );
    final hr = RegExp(r'<hr[^>]*/?>', caseSensitive: false, dotAll: true);

    final table = _parseFirstHtmlTable(html);
    if (table != null) {
      specs.add(
        _AiBlockSpec(
          type: 'table',
          text: '',
          tableCols: table.cols,
          tableRows: _tableRowsFromData(table),
        ),
      );
    }
    for (final m in h1.allMatches(html)) {
      final t = _stripHtmlTags(m.group(1) ?? '').trim();
      if (t.isNotEmpty) specs.add(_AiBlockSpec(type: 'h1', text: t));
    }
    for (final m in h2.allMatches(html)) {
      final t = _stripHtmlTags(m.group(1) ?? '').trim();
      if (t.isNotEmpty) specs.add(_AiBlockSpec(type: 'h2', text: t));
    }
    for (final m in h3.allMatches(html)) {
      final t = _stripHtmlTags(m.group(1) ?? '').trim();
      if (t.isNotEmpty) specs.add(_AiBlockSpec(type: 'h3', text: t));
    }
    for (final m in p.allMatches(html)) {
      final t = _stripHtmlTags(m.group(1) ?? '').trim();
      if (t.isNotEmpty) specs.add(_AiBlockSpec(type: 'paragraph', text: t));
    }
    for (final m in li.allMatches(html)) {
      final t = _stripHtmlTags(m.group(1) ?? '').trim();
      if (t.isNotEmpty) specs.add(_AiBlockSpec(type: 'bullet', text: t));
    }
    for (final m in bq.allMatches(html)) {
      final t = _stripHtmlTags(m.group(1) ?? '').trim();
      if (t.isNotEmpty) specs.add(_AiBlockSpec(type: 'quote', text: t));
    }
    for (final m in pre.allMatches(html)) {
      final t = _stripHtmlTags(m.group(1) ?? '').trim();
      if (t.isNotEmpty) {
        specs.add(_AiBlockSpec(type: 'code', text: t, codeLanguage: 'text'));
      }
    }
    if (hr.hasMatch(html)) {
      specs.add(const _AiBlockSpec(type: 'divider', text: ''));
    }
    return specs;
  }

  bool _looksLikeHtml(String s) {
    final t = s.toLowerCase();
    return t.contains('<html') ||
        t.contains('<body') ||
        t.contains('<p>') ||
        t.contains('<h1') ||
        t.contains('<table') ||
        t.contains('</');
  }

  String _stripHtmlTags(String s) {
    return s
        .replaceAll(
          RegExp(r'<br\s*/?>', caseSensitive: false, dotAll: true),
          '\n',
        )
        .replaceAll(RegExp(r'<[^>]+>', caseSensitive: false, dotAll: true), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .trim();
  }

  FolioTableData? _parseFirstHtmlTable(String html) {
    final tableMatch = RegExp(
      r'<table[^>]*>(.*?)</table>',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(html);
    if (tableMatch == null) return null;
    final tableHtml = tableMatch.group(1) ?? '';
    final rowMatches = RegExp(
      r'<tr[^>]*>(.*?)</tr>',
      caseSensitive: false,
      dotAll: true,
    ).allMatches(tableHtml).toList();
    if (rowMatches.isEmpty) return null;
    final rows = <List<String>>[];
    for (final rowMatch in rowMatches) {
      final rowHtml = rowMatch.group(1) ?? '';
      final cellMatches = RegExp(
        r'<t[hd][^>]*>(.*?)</t[hd]>',
        caseSensitive: false,
        dotAll: true,
      ).allMatches(rowHtml);
      final row = <String>[];
      for (final cell in cellMatches) {
        row.add(_stripHtmlTags(cell.group(1) ?? ''));
      }
      if (row.isNotEmpty) rows.add(row);
    }
    if (rows.isEmpty) return null;
    final cols = rows
        .fold<int>(0, (m, r) => r.length > m ? r.length : m)
        .clamp(1, 32);
    final cells = <String>[];
    for (final row in rows) {
      for (var c = 0; c < cols; c++) {
        cells.add(c < row.length ? row[c] : '');
      }
    }
    return FolioTableData(cols: cols, cells: cells);
  }

  List<List<String>> _tableRowsFromData(FolioTableData table) {
    final rows = <List<String>>[];
    for (var r = 0; r < table.rowCount; r++) {
      final row = <String>[];
      for (var c = 0; c < table.cols; c++) {
        row.add(table.cellAt(r, c));
      }
      rows.add(row);
    }
    return rows;
  }

  FolioTableData? _parseFirstMarkdownTable(String markdown) {
    final lines = markdown
        .replaceAll('\r\n', '\n')
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    for (var i = 0; i < lines.length - 1; i++) {
      final header = lines[i];
      final sep = lines[i + 1];
      if (!_isMarkdownTableRow(header) || !_isMarkdownTableSeparator(sep)) {
        continue;
      }
      final rows = <List<String>>[_splitMarkdownRow(header)];
      var j = i + 2;
      while (j < lines.length && _isMarkdownTableRow(lines[j])) {
        rows.add(_splitMarkdownRow(lines[j]));
        j++;
      }
      if (rows.isEmpty) return null;
      final cols = rows
          .fold<int>(0, (m, r) => r.length > m ? r.length : m)
          .clamp(1, 32);
      final cells = <String>[];
      for (final row in rows) {
        for (var c = 0; c < cols; c++) {
          cells.add(c < row.length ? row[c] : '');
        }
      }
      return FolioTableData(cols: cols, cells: cells);
    }
    return null;
  }

  bool _isMarkdownTableRow(String line) {
    return line.contains('|') && line.split('|').length >= 3;
  }

  bool _isMarkdownTableSeparator(String line) {
    if (!line.contains('|')) return false;
    final cells = _splitMarkdownRow(line);
    if (cells.isEmpty) return false;
    for (final c in cells) {
      final t = c.replaceAll(':', '').replaceAll('-', '').trim();
      if (t.isNotEmpty) return false;
    }
    return true;
  }

  List<String> _splitMarkdownRow(String line) {
    var work = line.trim();
    if (work.startsWith('|')) work = work.substring(1);
    if (work.endsWith('|')) work = work.substring(0, work.length - 1);
    return work.split('|').map((c) => c.trim()).toList();
  }

  String _formatAgentDecisionReply({
    required String mode,
    required String reason,
    required String reply,
    required bool isEs,
  }) {
    final cleanMode = mode.trim().isEmpty ? 'chat' : mode.trim();
    final cleanReason = reason.trim().isEmpty
        ? (isEs
              ? 'Selección automática según el contexto del mensaje.'
              : 'Automatic selection based on message context.')
        : reason.trim();
    final cleanReply = reply.trim().isEmpty
        ? (isEs ? 'Listo.' : 'Done.')
        : reply.trim();
    final decisionLabel = isEs ? 'Decisión de Quill' : "Quill's decision";
    final reasonLabel = isEs ? 'Motivo' : 'Reason';
    return '🧠 **$decisionLabel:** `$cleanMode`\n'
        '💡 **$reasonLabel:** $cleanReason\n\n'
        '$cleanReply';
  }

  Future<String> editPageWithAi({
    required String pageId,
    required String prompt,
    required List<AiChatMessage> messages,
    List<AiFileAttachment> attachments = const [],
  }) async {
    if (_state != VaultFlowState.unlocked ||
        (vaultUsesEncryption && _dek == null)) {
      throw StateError('Debes desbloquear el cofre para usar IA.');
    }
    final ai = _aiService;
    if (ai == null) throw StateError('IA no configurada.');
    final page = _pageById(pageId);
    if (page == null) throw StateError('Página no encontrada.');
    final result = await ai.complete(
      AiCompletionRequest(
        prompt:
            '$_quillIdentityLeadEs'
            'Decide si la solicitud del usuario es para editar la página activa o para responder en chat.\n'
            'Devuelve SOLO JSON válido con este esquema:\n'
            '{'
            '"mode":"edit|chat",'
            '"reply":"texto breve para el usuario",'
            '"operations":[{"kind":"update_page_title|append_blocks|replace_page","title":"nuevo título si renombrar","blocks":[...]}]'
            '}\n'
            'Para renombrar la página usa una operación {"kind":"update_page_title","title":"..."} (puede ir sola o junto a otras).\n'
            'Bloques permitidos: paragraph,h1,h2,h3,bullet,todo,quote,code,divider,table.\n'
            'Para table usa: {"type":"table","cols":N,"rows":[["c1","c2"],["v1","v2"]]}.\n'
            'Para code puedes añadir codeLanguage. Para todo puedes añadir checked.\n'
            'No uses markdown ni texto fuera del JSON.\n\n'
            'Página actual:\n'
            'Título: ${page.title}\n'
            'Contenido:\n${page.plainTextContent}\n\n'
            'Solicitud del usuario:\n${prompt.trim()}',
        model: 'auto',
        messages: messages,
        attachments: attachments,
      ),
    );
    final decoded = _decodeJsonObjectLenient(result.text);
    final mode = (decoded['mode'] as String? ?? 'chat').trim().toLowerCase();
    final reply = (decoded['reply'] as String? ?? '').trim();
    if (mode != 'edit') {
      if (reply.isNotEmpty) return reply;
      return 'Entendido.';
    }
    final ops = decoded['operations'];
    if (ops is! List || ops.isEmpty) {
      return reply.isNotEmpty ? reply : 'No encontré cambios para aplicar.';
    }
    var changed = false;
    for (final op in ops) {
      if (op is! Map<String, dynamic>) continue;
      final kind = (op['kind'] as String? ?? '').trim().toLowerCase();
      if (kind == 'update_page_title') {
        final newTitle = (op['title'] as String? ?? '').trim();
        if (newTitle.isNotEmpty) {
          page.title = newTitle;
          changed = true;
        }
        continue;
      }
      final rawBlocks = op['blocks'];
      if (rawBlocks is! List) continue;
      final parsedBlocks = _parseAiBlocksFromDynamicList(rawBlocks);
      final materialized = _materializeAiBlocks(page.id, parsedBlocks);
      if (kind == 'replace_page') {
        page.blocks = materialized;
        changed = true;
        continue;
      }
      if (kind == 'append_blocks') {
        for (final b in materialized) {
          page.blocks.add(b);
        }
        changed = true;
      }
    }
    if (changed) {
      notifyListeners();
      scheduleSave(trackRevisionForPageId: page.id);
      return reply.isNotEmpty ? reply : 'He aplicado los cambios en la página.';
    }
    return reply.isNotEmpty ? reply : 'No se aplicaron cambios.';
  }

  _AiPageDraft _parseAiHybridOutput(
    String raw, {
    required String defaultTitle,
  }) {
    final cleaned = raw
        .trim()
        .replaceAll('```json', '')
        .replaceAll('```', '')
        .trim();
    try {
      final map = _decodeJsonObjectLenient(cleaned);
      final title = (map['title'] as String? ?? defaultTitle).trim();
      final blocksRaw = map['blocks'] as List<dynamic>? ?? const [];
      final blocks = _parseAiBlocksFromDynamicList(blocksRaw);
      if (blocks.isEmpty) {
        blocks.addAll(_parseMarkdownToSpecs(cleaned));
      }
      return _AiPageDraft(title: title, blocks: blocks);
    } catch (_) {
      final recoveredBlocks = _recoverBlocksFromMalformedJson(cleaned);
      if (recoveredBlocks.isNotEmpty) {
        return _AiPageDraft(title: defaultTitle, blocks: recoveredBlocks);
      }
      final specs = _parseMarkdownToSpecs(cleaned);
      return _AiPageDraft(title: defaultTitle, blocks: specs);
    }
  }

  Map<String, dynamic> _decodeJsonObjectLenient(String raw) {
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      final first = raw.indexOf('{');
      final last = raw.lastIndexOf('}');
      if (first >= 0 && last > first) {
        final slice = raw.substring(first, last + 1);
        return jsonDecode(slice) as Map<String, dynamic>;
      }
      rethrow;
    }
  }

  List<_AiBlockSpec> _recoverBlocksFromMalformedJson(String raw) {
    final out = <_AiBlockSpec>[];
    final blockRegex = RegExp(
      r'"type"\s*:\s*"([^"]+)"[\s\S]*?"text"\s*:\s*"([^"]+)"',
      multiLine: true,
    );
    for (final m in blockRegex.allMatches(raw)) {
      final type = _normalizeAiBlockType(m.group(1) ?? 'paragraph');
      final text = (m.group(2) ?? '').replaceAll(r'\"', '"').trim();
      if (text.isEmpty && type != 'divider') continue;
      out.add(_AiBlockSpec(type: type, text: text));
    }
    return out;
  }

  List<_AiBlockSpec> _parseAiBlocksFromDynamicList(List<dynamic> blocksRaw) {
    final blocks = <_AiBlockSpec>[];
    for (final e in blocksRaw) {
      if (e is String) {
        final text = e.trim();
        if (text.isNotEmpty) {
          blocks.add(_AiBlockSpec(type: 'paragraph', text: text));
        }
        continue;
      }
      if (e is! Map) continue;
      final map = Map<String, dynamic>.from(e);
      final type = _normalizeAiBlockType(
        (map['type'] as String? ?? 'paragraph').trim(),
      );
      if (type == 'divider') {
        blocks.add(const _AiBlockSpec(type: 'divider', text: ''));
        continue;
      }
      if (type == 'table') {
        final cols = (map['cols'] as num?)?.toInt();
        final rawRows = map['rows'];
        final rows = <List<String>>[];
        if (rawRows is List) {
          for (final row in rawRows) {
            if (row is List) {
              rows.add(row.map((c) => c?.toString() ?? '').toList());
            }
          }
        }
        blocks.add(
          _AiBlockSpec(
            type: 'table',
            text: '',
            tableCols: cols,
            tableRows: rows,
          ),
        );
        continue;
      }
      final text = (map['text'] as String? ?? '').trim();
      if (text.isEmpty) continue;
      blocks.add(
        _AiBlockSpec(
          type: type,
          text: text,
          checked: map['checked'] as bool?,
          codeLanguage: map['codeLanguage'] as String?,
        ),
      );
    }
    return blocks;
  }

  List<_AiBlockSpec> _parseMarkdownToSpecs(String markdown) {
    final lines = markdown
        .replaceAll('\r\n', '\n')
        .split('\n')
        .map((e) => e.trimRight())
        .toList();
    final out = <_AiBlockSpec>[];
    final paragraphBuffer = <String>[];
    String? codeFenceLang;
    final codeBuffer = <String>[];

    void flushParagraph() {
      if (paragraphBuffer.isEmpty) return;
      final text = paragraphBuffer.join('\n').trim();
      paragraphBuffer.clear();
      if (text.isNotEmpty) {
        out.add(_AiBlockSpec(type: 'paragraph', text: text));
      }
    }

    void flushCode() {
      if (codeFenceLang == null) return;
      final text = codeBuffer.join('\n').trimRight();
      codeBuffer.clear();
      final lang = codeFenceLang!;
      codeFenceLang = null;
      if (text.isNotEmpty) {
        out.add(
          _AiBlockSpec(
            type: 'code',
            text: text,
            codeLanguage: lang.isEmpty ? 'dart' : lang,
          ),
        );
      }
    }

    for (final raw in lines) {
      final line = raw.trim();
      if (line.startsWith('```')) {
        if (codeFenceLang == null) {
          flushParagraph();
          codeFenceLang = line.substring(3).trim();
        } else {
          flushCode();
        }
        continue;
      }
      if (codeFenceLang != null) {
        codeBuffer.add(raw);
        continue;
      }
      if (line.isEmpty) {
        flushParagraph();
        continue;
      }
      if (line == '---' || line == '***') {
        flushParagraph();
        out.add(const _AiBlockSpec(type: 'divider', text: ''));
        continue;
      }
      if (line.startsWith('# ')) {
        flushParagraph();
        out.add(_AiBlockSpec(type: 'h1', text: line.substring(2).trim()));
        continue;
      }
      if (line.startsWith('## ')) {
        flushParagraph();
        out.add(_AiBlockSpec(type: 'h2', text: line.substring(3).trim()));
        continue;
      }
      if (line.startsWith('### ')) {
        flushParagraph();
        out.add(_AiBlockSpec(type: 'h3', text: line.substring(4).trim()));
        continue;
      }
      if (line.startsWith('- [ ] ') || line.startsWith('* [ ] ')) {
        flushParagraph();
        out.add(
          _AiBlockSpec(
            type: 'todo',
            text: line.substring(6).trim(),
            checked: false,
          ),
        );
        continue;
      }
      if (line.startsWith('- [x] ') || line.startsWith('* [x] ')) {
        flushParagraph();
        out.add(
          _AiBlockSpec(
            type: 'todo',
            text: line.substring(6).trim(),
            checked: true,
          ),
        );
        continue;
      }
      if (line.startsWith('- ') || line.startsWith('* ')) {
        flushParagraph();
        out.add(_AiBlockSpec(type: 'bullet', text: line.substring(2).trim()));
        continue;
      }
      if (line.startsWith('> ')) {
        flushParagraph();
        out.add(_AiBlockSpec(type: 'quote', text: line.substring(2).trim()));
        continue;
      }
      paragraphBuffer.add(line);
    }

    flushParagraph();
    flushCode();
    if (out.isEmpty) {
      final fallback = markdown.trim();
      out.add(
        _AiBlockSpec(
          type: 'paragraph',
          text: fallback.isEmpty ? 'Sin contenido' : fallback,
        ),
      );
    }
    return out;
  }

  List<FolioBlock> _materializeAiBlocks(
    String pageId,
    List<_AiBlockSpec> specs,
  ) {
    final out = <FolioBlock>[];
    for (final s in specs) {
      final type = _normalizeAiBlockType(s.type);
      final text = s.text.trim();
      if (type != 'divider' && type != 'table' && text.isEmpty) continue;
      out.add(
        FolioBlock(
          id: '${pageId}_${_uuid.v4()}',
          type: type,
          text: type == 'divider'
              ? ''
              : (type == 'table' ? _buildTableBlockText(s) : text),
          checked: type == 'todo' ? (s.checked ?? false) : null,
          codeLanguage: type == 'code'
              ? (s.codeLanguage?.trim().isEmpty ?? true
                    ? 'dart'
                    : s.codeLanguage)
              : null,
        ),
      );
    }
    if (out.isEmpty) {
      out.add(
        FolioBlock(id: '${pageId}_${_uuid.v4()}', type: 'paragraph', text: ''),
      );
    }
    return out;
  }

  @visibleForTesting
  List<FolioBlock> parseAiOutputForTesting(
    String output, {
    String pageId = 'test_page',
    String defaultTitle = 'Test',
  }) {
    final parsed = _parseAiHybridOutput(output, defaultTitle: defaultTitle);
    return _materializeAiBlocks(pageId, parsed.blocks);
  }

  String _normalizeAiBlockType(String raw) {
    const supported = {
      'paragraph',
      'h1',
      'h2',
      'h3',
      'bullet',
      'todo',
      'code',
      'quote',
      'divider',
      'callout',
      'table',
    };
    final normalized = raw.trim().toLowerCase();
    final type = normalized.contains('|')
        ? normalized.split('|').first.trim()
        : normalized;
    return supported.contains(type) ? type : 'paragraph';
  }

  String _buildTableBlockText(_AiBlockSpec spec) {
    final colsFromSpec = spec.tableCols ?? 0;
    var cols = colsFromSpec > 0 ? colsFromSpec : 0;
    final rows = spec.tableRows ?? const <List<String>>[];
    if (cols <= 0 && rows.isNotEmpty) {
      cols = rows.fold<int>(
        0,
        (maxCols, row) => row.length > maxCols ? row.length : maxCols,
      );
    }
    cols = cols.clamp(1, 32);
    final cells = <String>[];
    if (rows.isEmpty) {
      return FolioTableData.empty(cols: cols, rows: 2).encode();
    }
    for (final row in rows) {
      for (var c = 0; c < cols; c++) {
        cells.add(c < row.length ? row[c] : '');
      }
    }
    return FolioTableData(cols: cols, cells: cells).encode();
  }

  void createPageFromTemplate(String sourcePageId, {String? parentId}) {
    final src = _pageById(sourcePageId);
    if (src == null) return;
    final id = _uuid.v4();
    final copiedBlocks = src.blocks
        .map(
          (b) => FolioBlock(
            id: '${id}_${_uuid.v4()}',
            type: b.type,
            text: b.text,
            checked: b.checked,
            expanded: b.expanded,
            codeLanguage: b.codeLanguage,
            depth: b.depth,
            icon: b.icon,
            url: b.url,
            imageWidth: b.imageWidth,
          ),
        )
        .toList();
    _pages.add(
      FolioPage(
        id: id,
        title: '${src.title} (copy)',
        parentId: parentId,
        blocks: copiedBlocks,
      ),
    );
    _selectedPageId = id;
    notifyListeners();
    scheduleSave(trackRevisionForPageId: id);
  }

  String _blockSearchText(FolioBlock b) {
    final txt = b.text.trim();
    final url = b.url?.trim() ?? '';
    if (txt.isNotEmpty && url.isNotEmpty) return '$txt $url';
    return txt.isNotEmpty ? txt : url;
  }

  String _snippetAround(String text, String queryLower) {
    final clean = text.replaceAll('\n', ' ').trim();
    if (clean.isEmpty) return '';
    final lower = clean.toLowerCase();
    final idx = lower.indexOf(queryLower);
    if (idx < 0) {
      return clean.length <= 96 ? clean : '${clean.substring(0, 96)}...';
    }
    final start = (idx - 28).clamp(0, clean.length);
    final end = (idx + queryLower.length + 68).clamp(0, clean.length);
    final chunk = clean.substring(start, end).trim();
    final prefix = start > 0 ? '... ' : '';
    final suffix = end < clean.length ? ' ...' : '';
    return '$prefix$chunk$suffix';
  }

  void _pickInitialSelection() {
    if (_pages.isEmpty) {
      _selectedPageId = null;
      return;
    }
    final roots = _pages.where((p) => p.parentId == null).toList();
    _selectedPageId = roots.isNotEmpty ? roots.first.id : _pages.first.id;
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    _saveDebounce = null;
    _revisionIdleTimer?.cancel();
    _idleLockTimer?.cancel();
    super.dispose();
  }
}

class _AiPageDraft {
  const _AiPageDraft({required this.title, required this.blocks});

  final String title;
  final List<_AiBlockSpec> blocks;
}

class _AiBlockSpec {
  const _AiBlockSpec({
    required this.type,
    required this.text,
    this.checked,
    this.codeLanguage,
    this.tableCols,
    this.tableRows,
  });

  final String type;
  final String text;
  final bool? checked;
  final String? codeLanguage;
  final int? tableCols;
  final List<List<String>>? tableRows;
}
