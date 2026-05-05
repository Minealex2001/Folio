import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:local_auth/local_auth.dart';
import 'package:path/path.dart' as p;
import 'package:passkeys/authenticator.dart';
import 'package:passkeys/types.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cryptography/cryptography.dart';
import 'package:uuid/uuid.dart';

import '../crypto/vault_crypto.dart';
import '../data/vault_backup.dart';
import '../data/notion_import/notion_importer.dart';
import '../data/import/simple_html_blocks.dart';
import '../app/workspace_prefs_keys.dart';
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
import '../models/folio_task_data.dart';
import '../models/folio_drive_data.dart';
import '../models/folio_canvas_data.dart';
import '../models/folio_kanban_data.dart';
import '../models/jira_integration_state.dart';
import '../models/page_property.dart';
import '../models/vault_task_list_entry.dart';
import '../models/folio_columns_data.dart';
import '../models/folio_page_template.dart';
import '../models/folio_template_button_data.dart';
import '../models/folio_page_import_info.dart';
import '../data/folio_internal_link.dart';
import '../services/folio_rp_server.dart';
import '../services/ai/ai_safety_policy.dart';
import '../services/ai/ai_service.dart';
import '../services/ai/ai_intent_hints.dart';
import '../services/ai/ai_types.dart';
import '../services/integrations/integrations_markdown_codec.dart';
import '../services/app_logger.dart';
import '../services/quick_unlock_storage.dart';
import '../l10n/generated/app_localizations.dart';

part 'vault_session_ai.dart';

enum VaultFlowState { initializing, needsOnboarding, locked, unlocked }

enum VaultSearchMatchKind { title, content }

class VaultSearchResult {
  const VaultSearchResult({
    required this.pageId,
    required this.pageTitle,
    required this.snippet,
    required this.matchKind,
    this.blockId,
    this.pageLastEditedMs = 0,
    this.score = 0,
  });

  final String pageId;
  final String pageTitle;
  final String snippet;
  final VaultSearchMatchKind matchKind;
  final String? blockId;
  final int pageLastEditedMs;
  final int score;
}

class _PageUndoSnapshot {
  const _PageUndoSnapshot({
    required this.fingerprint,
    required this.title,
    required this.emoji,
    required this.blocks,
  });

  final String fingerprint;
  final String title;
  final String? emoji;
  final List<FolioBlock> blocks;
}

class SyncConflictEntry {
  const SyncConflictEntry({
    required this.id,
    required this.fromPeerId,
    required this.createdAtMs,
    required this.remoteFingerprint,
    required this.remoteSnapshotBytes,
    required this.remotePageCount,
  });

  final String id;
  final String fromPeerId;
  final int createdAtMs;
  final String remoteFingerprint;
  final List<int> remoteSnapshotBytes;
  final int remotePageCount;
}

class VaultSession extends ChangeNotifier {
  /// Nombre de la asistente en la app; se repite en los prompts para que el modelo lo mantenga.
  static const String _quillIdentityLeadEs =
      'Tu nombre es Quill. Eres la asistente de IA integrada en Folio.\n\n';
  static const String _quillIdentityLeadEn =
      "Your name is Quill. You are Folio's built-in AI assistant.\n\n";

  static const _prefsLastSelectedPagePrefix = 'folio_last_selected_page_';

  String? _lastSelectedPagePrefsKey(String? vaultId) {
    if (vaultId == null || vaultId.isEmpty) return null;
    return '$_prefsLastSelectedPagePrefix$vaultId';
  }

  int _selectedPagePersistRequestId = 0;

  Future<void> _persistLastSelectedPageForActiveVault(
    String? pageId, {
    String? vaultId,
    int? requestId,
  }) async {
    final targetVaultId = vaultId ?? VaultPaths.activeVaultId;
    final key = _lastSelectedPagePrefsKey(targetVaultId);
    if (key == null) return;
    if (requestId != null && requestId != _selectedPagePersistRequestId) {
      return;
    }
    final p = await SharedPreferences.getInstance();
    if (requestId != null && requestId != _selectedPagePersistRequestId) {
      return;
    }
    if (pageId != null &&
        pageId.isNotEmpty &&
        _pages.any((pg) => pg.id == pageId)) {
      await p.setString(key, pageId);
    } else {
      await p.remove(key);
    }
  }

  Future<void> _persistLastSelectedPageBeforeLock() async {
    final key = _lastSelectedPagePrefsKey(VaultPaths.activeVaultId);
    if (key == null) return;
    final id = _selectedPageId;
    final p = await SharedPreferences.getInstance();
    if (id != null && id.isNotEmpty && _pages.any((pg) => pg.id == id)) {
      await p.setString(key, id);
    }
  }

  Future<void> _applyInitialPageSelection({
    required bool preferPersistedPreference,
  }) async {
    if (_pages.isEmpty) {
      _selectedPageId = null;
      return;
    }
    if (preferPersistedPreference) {
      final p = await SharedPreferences.getInstance();
      if (p.getBool(WorkspacePrefsKeys.openWorkspaceToHome) ?? false) {
        _selectedPageId = null;
        return;
      }
      final key = _lastSelectedPagePrefsKey(VaultPaths.activeVaultId);
      if (key != null) {
        final saved = p.getString(key);
        if (saved != null &&
            saved.isNotEmpty &&
            _pages.any((pg) => pg.id == saved)) {
          _selectedPageId = saved;
          return;
        }
      }
    }
    final roots = _pages.where((p) => p.parentId == null).toList();
    _selectedPageId = roots.isNotEmpty ? roots.first.id : _pages.first.id;
  }

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
    this.titleLocale,
  }) : _repo = repository ?? VaultRepository(),
       _quick = quickUnlock ?? QuickUnlockStorage(),
       _rp = rpServer ?? FolioRpServer(),
       _passkeysOverride = passkeys,
       _localAuth = localAuth ?? LocalAuthentication() {
    final l10n = lookupAppLocalizations(titleLocale ?? const Locale('es'));
    _aiChatThreads = [
      AiChatThreadData(
        id: 'chat_0',
        title: l10n.aiChatTitleNumbered(1),
        messages: const [],
      ),
    ];
  }

  /// Idioma para títulos por defecto (páginas nuevas, chats). Actualizar al cambiar el idioma de la app.
  Locale? titleLocale;

  AppLocalizations get _titleL10n =>
      lookupAppLocalizations(titleLocale ?? const Locale('es'));

  final VaultRepository _repo;
  final QuickUnlockStorage _quick;
  final FolioRpServer _rp;
  final PasskeyAuthenticator? _passkeysOverride;
  PasskeyAuthenticator? _passkeysLazy;

  /// PasskeysDoctor se engancha en el constructor de [PasskeyAuthenticator]; aplazar
  /// la creación evita trabajo nativo/Pigeon al arrancar la app (p. ej. Windows).
  PasskeyAuthenticator get _passkeys =>
      _passkeysOverride ?? (_passkeysLazy ??= PasskeyAuthenticator());

  final LocalAuthentication _localAuth;
  void Function()? onPersisted;
  void Function(int pendingConflicts)? onSyncConflictCountChanged;
  AiService? _aiService;

  static const _uuid = Uuid();

  VaultFlowState _state = VaultFlowState.initializing;
  List<int>? _dek;
  List<FolioPage> _pages = [];

  /// Orden persistido del árbol por `parentId`. La raíz se guarda como clave vacía `''`.
  final Map<String, List<String>> _pageOrderByParent = {};

  /// Historial de revisiones por `pageId` (orden cronológico ascendente).
  final Map<String, List<FolioPageRevision>> _pageRevisions = {};
  final Map<String, Map<String, String>> _pageAcl = {};
  final List<LocalProfile> _localProfiles = [];
  List<LocalPageComment> _comments = [];
  late final List<AiChatThreadData> _aiChatThreads;
  int _aiActiveChatIndex = 0;
  final List<FolioPageTemplate> _pageTemplates = [];
  JiraIntegrationState _jira = JiraIntegrationState.empty;
  String? _selectedPageId;
  Timer? _saveDebounce;
  Timer? _revisionIdleTimer;
  Timer? _idleLockTimer;
  final Set<String> _pageIdsPendingRevision = {};
  int _persistDepth = 0;
  int _suppressPersistedCallbackDepth = 0;
  String _syncBaselineFingerprint = '';
  int _syncPendingConflicts = 0;
  final List<SyncConflictEntry> _syncConflicts = [];
  Duration _idleLockDuration = const Duration(minutes: 15);
  bool _lockOnAppBackground = false;
  bool _vaultUsesEncryption = true;

  /// Tras "Añadir libreta", se restaura al cancelar onboarding.
  String? _resumeVaultIdAfterNewVault;

  final VaultRegistry _registry = VaultRegistry.instance;

  String? get activeVaultId => VaultPaths.activeVaultId;

  bool get canCancelNewVaultOnboarding => _resumeVaultIdAfterNewVault != null;

  Future<List<VaultEntry>> listVaultEntries() async {
    await _registry.load();
    return _registry.vaults;
  }

  /// Nombre de la libreta activa para mostrar en Ajustes (p. ej. copias).
  Future<String> getActiveVaultDisplayLabel() async {
    await _registry.load();
    final id = _vaultId;
    if (id == null || id.isEmpty) {
      return '—';
    }
    final e = _registry.entryFor(id);
    return e?.displayName ?? id;
  }

  String? get _vaultId => VaultPaths.activeVaultId;

  /// Tras dejar de editar, se crea una entrada de historial (además del guardado rápido).
  static const Duration _revisionIdleDelay = Duration(milliseconds: 2500);

  /// Hay un guardado al disco programado (debounce) y aún no se ha ejecutado.
  bool get hasPendingDiskSave => _saveDebounce != null;

  /// Escritura cifrada de la libreta en curso (puede anidarse si varias rutas llaman a [persistNow]).
  bool get isPersistingToDisk => _persistDepth > 0;

  VaultFlowState get state => _state;
  List<FolioPage> get pages => List.unmodifiable(_pages);
  String? get selectedPageId => _selectedPageId;

  /// ID del perfil local activo (el primero de la lista, o 'local-default').
  String get activeProfileId =>
      _localProfiles.isEmpty ? 'local-default' : _localProfiles.first.id;

  /// Nombre visible del perfil local activo.
  String get activeProfileName =>
      _localProfiles.isEmpty ? 'Yo' : _localProfiles.first.name;

  List<LocalPageComment> commentsForPage(String pageId) =>
      _comments.where((c) => c.pageId == pageId).toList()
        ..sort((a, b) => b.createdAtMs.compareTo(a.createdAtMs));

  /// Devuelve las páginas que contienen al menos un enlace `folio://open/<pageId>`
  /// apuntando a [targetPageId], excluyendo la propia página destino.
  List<FolioPage> backlinkPagesFor(String targetPageId) {
    // Regex para URIs folio://open/... dentro de texto markdown.
    final uriRe = RegExp(r'folio://[^\s)"]+');
    final result = <FolioPage>[];
    for (final page in _pages) {
      if (page.id == targetPageId) continue;
      var found = false;
      for (final block in page.blocks) {
        if (found) break;
        for (final match in uriRe.allMatches(block.text)) {
          final linked = folioPageIdFromFolioUri(match.group(0));
          if (linked == targetPageId) {
            found = true;
            break;
          }
        }
      }
      if (found) result.add(page);
    }
    return result;
  }

  Duration get idleLockDuration => _idleLockDuration;
  bool get lockOnAppBackground => _lockOnAppBackground;
  bool get aiEnabled => _aiService != null;
  AiService? get aiService => _aiService;
  bool get vaultUsesEncryption => _vaultUsesEncryption;
  bool get isUnlocked => _state == VaultFlowState.unlocked;

  /// DEK en bruto para el envoltorio de recuperación de copia incremental (libreta cifrada desbloqueada).
  List<int>? get cloudPackRestoreDekMaterial {
    if (!vaultUsesEncryption || !isUnlocked || _dek == null) return null;
    return _dek;
  }

  /// Clave AES-GCM para blobs y snapshots de copia incremental en la nube.
  /// Libreta cifrada: usa la DEK en memoria. En claro: derivada de `vault.bin`.
  Future<SecretKey> cloudPackEncryptionKey() async {
    if (!isUnlocked) {
      throw StateError('La libreta debe estar desbloqueada.');
    }
    if (vaultUsesEncryption) {
      if (_dek == null) {
        throw StateError('La libreta cifrada debe tener la DEK en memoria.');
      }
      return VaultCrypto.dekFromBytes(_dek!);
    }
    final bytes = await VaultPaths.readCipherPayload();
    if (bytes == null) {
      throw StateError('No hay libreta.');
    }
    final h = await Sha256().hash(bytes);
    final h2 = await Sha256().hash(
      Uint8List.fromList(utf8.encode('FolioCloudPackPlainV1') + h.bytes),
    );
    return SecretKey(h2.bytes);
  }

  /// Para tests que llaman a [collectTaskBlocks] sin [bootstrap].
  @visibleForTesting
  void debugMarkUnlockedForTests() {
    _state = VaultFlowState.unlocked;
  }

  List<AiChatThreadData> get aiChatThreads => List.unmodifiable(_aiChatThreads);
  int get aiActiveChatIndex => _aiActiveChatIndex;
  AiChatThreadData get activeAiChat => _aiChatThreads[_aiActiveChatIndex];
  List<FolioPageTemplate> get pageTemplates =>
      List.unmodifiable(_pageTemplates);
  JiraIntegrationState get jiraIntegrationState => _jira;
  List<JiraConnection> get jiraConnections => _jira.connections;
  List<JiraSource> get jiraSources => _jira.sources;
  List<SyncConflictEntry> get syncConflicts =>
      List.unmodifiable(_syncConflicts);

  /// Se incrementa al restaurar una revisión para forzar remount del editor
  /// cuando los ids de bloque coinciden pero el texto cambió.
  int get contentEpoch => _contentEpoch;
  int _contentEpoch = 0;

  static const int _maxUndoStepsPerPage = 100;
  static const Duration _undoTypingCoalesceWindow = Duration(milliseconds: 900);
  static const int _maxIconLength = 64;
  final Map<String, List<_PageUndoSnapshot>> _undoByPage = {};
  final Map<String, List<_PageUndoSnapshot>> _redoByPage = {};
  final Map<String, DateTime> _lastUndoTypingCaptureAt = {};

  /// Evita un `notifyListeners` por tecla: un único aviso al cerrar el frame.
  bool _typingNotifyFrameScheduled = false;

  SchedulerBinding? get _schedulerOrNull {
    try {
      return SchedulerBinding.instance;
    } catch (_) {
      return null;
    }
  }

  void _scheduleCoalescedTypingNotify() {
    if (_typingNotifyFrameScheduled) return;
    final scheduler = _schedulerOrNull;
    if (scheduler == null) {
      notifyListeners();
      return;
    }
    _typingNotifyFrameScheduled = true;
    scheduler.scheduleFrameCallback((_) {
      _typingNotifyFrameScheduled = false;
      notifyListeners();
    });
  }

  bool get canUndoSelectedPage => canUndoPage(_selectedPageId);
  bool get canRedoSelectedPage => canRedoPage(_selectedPageId);

  bool canUndoPage(String? pageId) {
    if (pageId == null) return false;
    final stack = _undoByPage[pageId];
    return stack != null && stack.isNotEmpty;
  }

  bool canRedoPage(String? pageId) {
    if (pageId == null) return false;
    final stack = _redoByPage[pageId];
    return stack != null && stack.isNotEmpty;
  }

  void undoPageEdits({String? pageId}) {
    final id = pageId ?? _selectedPageId;
    if (id == null) return;
    final page = _pageById(id);
    final undoStack = _undoByPage[id];
    if (page == null || undoStack == null || undoStack.isEmpty) return;

    final current = _snapshotOfPage(page);
    final redoStack = _redoByPage.putIfAbsent(id, () => []);
    redoStack.add(current);
    if (redoStack.length > _maxUndoStepsPerPage) {
      redoStack.removeAt(0);
    }

    final target = undoStack.removeLast();
    _restorePageFromSnapshot(page, target);
    _contentEpoch++;
    notifyListeners();
    scheduleSave(trackRevisionForPageId: id);
  }

  void redoPageEdits({String? pageId}) {
    final id = pageId ?? _selectedPageId;
    if (id == null) return;
    final page = _pageById(id);
    final redoStack = _redoByPage[id];
    if (page == null || redoStack == null || redoStack.isEmpty) return;

    final current = _snapshotOfPage(page);
    final undoStack = _undoByPage.putIfAbsent(id, () => []);
    undoStack.add(current);
    if (undoStack.length > _maxUndoStepsPerPage) {
      undoStack.removeAt(0);
    }

    final target = redoStack.removeLast();
    _restorePageFromSnapshot(page, target);
    _contentEpoch++;
    notifyListeners();
    scheduleSave(trackRevisionForPageId: id);
  }

  _PageUndoSnapshot _snapshotOfPage(FolioPage page) {
    return _PageUndoSnapshot(
      fingerprint: folioPageContentFingerprint(page),
      title: page.title,
      emoji: page.emoji,
      blocks: page.blocks
          .map(
            (b) => FolioBlock(
              id: b.id,
              type: b.type,
              text: b.text,
              checked: b.checked,
              expanded: b.expanded,
              codeLanguage: b.codeLanguage,
              depth: b.depth,
              icon: b.icon,
              url: b.url,
              imageWidth: b.imageWidth,
              appearance: b.appearance,
              meetingNoteProvider: b.meetingNoteProvider,
              meetingNoteTranscriptionEnabled:
                  b.meetingNoteTranscriptionEnabled,
            ),
          )
          .toList(),
    );
  }

  void _restorePageFromSnapshot(FolioPage page, _PageUndoSnapshot snap) {
    page.title = snap.title;
    page.emoji = snap.emoji;
    page.blocks = snap.blocks
        .map(
          (b) => FolioBlock(
            id: b.id,
            type: b.type,
            text: b.text,
            checked: b.checked,
            expanded: b.expanded,
            codeLanguage: b.codeLanguage,
            depth: b.depth,
            icon: b.icon,
            url: b.url,
            imageWidth: b.imageWidth,
            appearance: b.appearance,
            meetingNoteProvider: b.meetingNoteProvider,
            meetingNoteTranscriptionEnabled: b.meetingNoteTranscriptionEnabled,
          ),
        )
        .toList();
  }

  void _rememberUndoBeforePageMutation(String pageId, {bool isTyping = false}) {
    final page = _pageById(pageId);
    if (page == null) return;
    final now = DateTime.now();
    final stack = _undoByPage.putIfAbsent(pageId, () => []);
    final fp = folioPageContentFingerprint(page);
    if (stack.isNotEmpty && stack.last.fingerprint == fp) {
      if (isTyping) {
        _lastUndoTypingCaptureAt[pageId] = now;
      }
      return;
    }

    if (isTyping) {
      final lastAt = _lastUndoTypingCaptureAt[pageId];
      if (lastAt != null &&
          now.difference(lastAt) <= _undoTypingCoalesceWindow) {
        return;
      }
      _lastUndoTypingCaptureAt[pageId] = now;
    } else {
      _lastUndoTypingCaptureAt.remove(pageId);
    }

    stack.add(_snapshotOfPage(page));
    if (stack.length > _maxUndoStepsPerPage) {
      stack.removeAt(0);
    }
    _redoByPage.remove(pageId);
  }

  void _resetUndoRedoState() {
    _undoByPage.clear();
    _redoByPage.clear();
    _lastUndoTypingCaptureAt.clear();
  }

  /// El editor hace scroll a este bloque tras el siguiente frame (TOC / enlaces internos).
  String? pendingScrollToBlockId;

  /// Warnings generados en la última importación de Notion. Se vacía antes de
  /// cada importación y puede consultarse desde la UI tras llamar a los métodos
  /// de importación.
  List<NotionImportWarning> lastImportWarnings = const [];

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

  void _notifySessionListeners() {
    notifyListeners();
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
        _ensureOrderForCurrentPages();
        await _applyInitialPageSelection(preferPersistedPreference: true);
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
    _pageOrderByParent
      ..clear()
      ..addEntries(
        payload.pageOrderByParent.entries.map(
          (e) => MapEntry(e.key, List<String>.from(e.value)),
        ),
      );
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
        AiChatThreadData(
          id: 'chat_0',
          title: _titleL10n.aiChatTitleNumbered(1),
          messages: const [],
        ),
      );
    }
    _aiActiveChatIndex = payload.aiActiveChatIndex.clamp(
      0,
      _aiChatThreads.length - 1,
    );
    _pageTemplates
      ..clear()
      ..addAll(payload.pageTemplates);
    _jira = payload.jira;
    _resetUndoRedoState();
  }

  void upsertJiraConnection(JiraConnection connection) {
    if (_state != VaultFlowState.unlocked) return;
    final next = List<JiraConnection>.from(_jira.connections);
    final i = next.indexWhere((c) => c.id == connection.id);
    if (i >= 0) {
      next[i] = connection;
    } else {
      next.add(connection);
    }
    _jira = JiraIntegrationState(
      connections: List.unmodifiable(next),
      sources: _jira.sources,
    );
    notifyListeners();
    scheduleSave();
  }

  void removeJiraConnection(String connectionId) {
    if (_state != VaultFlowState.unlocked) return;
    final nextConnections = _jira.connections
        .where((c) => c.id != connectionId)
        .toList();
    final nextSources = _jira.sources
        .where((s) => s.connectionId != connectionId)
        .toList();
    _jira = JiraIntegrationState(
      connections: List.unmodifiable(nextConnections),
      sources: List.unmodifiable(nextSources),
    );
    notifyListeners();
    scheduleSave();
  }

  void upsertJiraSource(JiraSource source) {
    if (_state != VaultFlowState.unlocked) return;
    final next = List<JiraSource>.from(_jira.sources);
    final i = next.indexWhere((s) => s.id == source.id);
    if (i >= 0) {
      next[i] = source;
    } else {
      next.add(source);
    }
    _jira = JiraIntegrationState(
      connections: _jira.connections,
      sources: List.unmodifiable(next),
    );
    notifyListeners();
    scheduleSave();
  }

  void removeJiraSource(String sourceId) {
    if (_state != VaultFlowState.unlocked) return;
    final next = _jira.sources.where((s) => s.id != sourceId).toList();
    _jira = JiraIntegrationState(
      connections: _jira.connections,
      sources: List.unmodifiable(next),
    );
    notifyListeners();
    scheduleSave();
  }

  String _orderKeyForParent(String? parentId) => parentId ?? '';

  void _ensureOrderForCurrentPages() {
    final byId = <String, FolioPage>{for (final p in _pages) p.id: p};
    // 1) Quitar ids inexistentes.
    for (final entry in _pageOrderByParent.entries.toList()) {
      final next = List<String>.from(entry.value)
        ..removeWhere((id) => !byId.containsKey(id));
      if (next.isEmpty) {
        _pageOrderByParent.remove(entry.key);
      } else {
        _pageOrderByParent[entry.key] = next;
      }
    }
    // 2) Asegurar lista por cada parent que tenga hijos.
    final childrenByParent = <String, List<String>>{};
    for (final p in _pages) {
      final key = _orderKeyForParent(p.parentId);
      (childrenByParent[key] ??= <String>[]).add(p.id);
    }
    for (final entry in childrenByParent.entries) {
      final key = entry.key;
      final existing = _pageOrderByParent.putIfAbsent(key, () => <String>[]);
      // Preservar orden existente, y añadir faltantes al final siguiendo orden actual de _pages.
      final present = existing.toSet();
      for (final id in entry.value) {
        if (!present.contains(id)) {
          existing.add(id);
          present.add(id);
        }
      }
    }
  }

  List<String> pageOrderForParent(String? parentId) {
    _ensureOrderForCurrentPages();
    return List.unmodifiable(
      _pageOrderByParent[_orderKeyForParent(parentId)] ?? const <String>[],
    );
  }

  List<FolioPage> childrenForParent(String? parentId) {
    _ensureOrderForCurrentPages();
    final key = _orderKeyForParent(parentId);
    final order = _pageOrderByParent[key] ?? const <String>[];
    final byId = <String, FolioPage>{for (final p in _pages) p.id: p};
    return order
        .map((id) => byId[id])
        .whereType<FolioPage>()
        .toList(growable: false);
  }

  void movePage({
    required String pageId,
    required String? newParentId,
    required int newIndex,
  }) {
    if (pageId == newParentId) return;
    if (newParentId != null) {
      if (!_pages.any((p) => p.id == newParentId)) return;
      if (_isDescendant(ancestorId: pageId, nodeId: newParentId)) return;
    }
    _ensureOrderForCurrentPages();
    final p = _pages.firstWhere((e) => e.id == pageId);
    final oldParentId = p.parentId;
    final oldKey = _orderKeyForParent(oldParentId);
    final newKey = _orderKeyForParent(newParentId);
    _rememberUndoBeforePageMutation(pageId);
    _pageOrderByParent[oldKey]?.remove(pageId);
    final list = _pageOrderByParent.putIfAbsent(newKey, () => <String>[]);
    final idx = newIndex.clamp(0, list.length);
    list.insert(idx, pageId);
    p.parentId = newParentId;
    notifyListeners();
    scheduleSave(trackRevisionForPageId: pageId);
  }

  void reorderPageWithinParent({
    required String? parentId,
    required String pageId,
    required int newIndex,
  }) {
    movePage(pageId: pageId, newParentId: parentId, newIndex: newIndex);
  }

  Future<void> completeOnboarding({
    String? password,
    bool encrypted = true,
    bool createStarterPages = true,
  }) async {
    await _registry.load();
    var id = VaultPaths.activeVaultId;
    if (id == null) {
      id = _uuid.v4();
      VaultPaths.setActiveVaultId(id);
    }
    await VaultPaths.initVaultStorage(id);
    if (!_registry.containsVault(id)) {
      final ordinal = _registry.vaults.length + 1;
      await _registry.add(
        VaultEntry(
          id: id,
          displayName: 'Libreta $ordinal',
          createdAtMs: DateTime.now().millisecondsSinceEpoch,
        ),
      );
    }
    await _registry.setActiveVaultId(id);

    final dek = await _repo.createVault(
      password: password,
      encrypted: encrypted,
      starterContent: createStarterPages
          ? VaultStarterContent.enabled
          : VaultStarterContent.disabled,
      starterL10n: createStarterPages ? _titleL10n : null,
    );
    _vaultUsesEncryption = encrypted;
    _dek = dek?.toList();
    final payload = await _repo.loadPayload(_dek);
    _pages = List.from(payload.pages);
    _loadRevisionsFromPayload(payload);
    _ensureOrderForCurrentPages();
    await _applyInitialPageSelection(preferPersistedPreference: false);
    _state = VaultFlowState.unlocked;
    _restartIdleLockTimer();
    _resumeVaultIdAfterNewVault = null;
    notifyListeners();
    await persistNow();
  }

  /// Añade una libreta vacía y pasa a onboarding (el usuario debe completar contraseña o import).
  Future<void> prepareNewVault() async {
    await _registry.load();
    final current = VaultPaths.activeVaultId;
    if (current == null) {
      throw StateError('No hay libreta activa');
    }
    _resumeVaultIdAfterNewVault = current;
    final newId = _uuid.v4();
    await VaultPaths.vaultDirectoryForId(newId);
    final ordinal = _registry.vaults.length + 1;
    await _registry.add(
      VaultEntry(
        id: newId,
        displayName: 'Libreta $ordinal',
        createdAtMs: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    VaultPaths.setActiveVaultId(newId);
    await VaultPaths.initVaultStorage(newId);
    await _registry.setActiveVaultId(newId);
    _clearVaultSessionMemory();
    _state = VaultFlowState.initializing;
    notifyListeners();
    await bootstrap();
  }

  /// Cancela el onboarding de una libreta nueva y vuelve a la libreta anterior.
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
    await lock();
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

  /// Elimina otra libreta (no la activa). Requiere que no sea la abierta.
  Future<void> deleteVaultById(String vaultId) async {
    await _registry.load();
    if (vaultId == VaultPaths.activeVaultId) {
      throw StateError(
        'No se puede borrar la libreta activa desde aquí; usa Borrar libreta.',
      );
    }
    if (!_registry.containsVault(vaultId)) return;
    await _quick.disable(vaultId);
    await VaultPaths.deleteVaultDirectory(vaultId);
    await _registry.remove(vaultId);
    notifyListeners();
  }

  /// La UI debe haber verificado la identidad de la libreta **actual** (contraseña / Hello / passkey).
  /// [zipPath] ruta del `.zip` a crear.
  Future<void> exportVaultBackup(String zipPath) async {
    if (kIsWeb) throw UnsupportedError('Backup not available on web');
    await persistNow();
    await exportVaultZip(File(zipPath));
  }

  /// Importa el ZIP como **libreta nueva**; la libreta activa no se modifica.
  /// Devuelve el id de la libreta creada.
  Future<String> importVaultBackupAsNew(
    String zipPath,
    String backupPassword, {
    String? displayName,
  }) async {
    if (kIsWeb) throw UnsupportedError('Backup import not available on web');
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
          displayName: displayName ?? 'Libreta importada',
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

  /// Importa una copia (ZIP o TAR.GZ) y **machaca** la libreta activa.
  /// Requiere que la UI haya verificado identidad (la libreta debe estar desbloqueada).
  Future<void> importVaultBackupOverwriteActive(
    String archivePath,
    String backupPassword,
  ) async {
    if (!isUnlocked) {
      throw StateError('La libreta debe estar desbloqueada para importar.');
    }
    final temp = Directory.systemTemp.createTempSync('folio_import_overwrite_');
    try {
      await extractBackupArchiveToDirectory(File(archivePath), temp);
      await validateImportZip(temp, backupPassword);
      await applyImportFromDirectory(temp);
      await bootstrap();
    } finally {
      try {
        if (temp.existsSync()) {
          await temp.delete(recursive: true);
        }
      } catch (_) {}
    }
  }

  /// Como [importVaultBackupOverwriteActive] pero el árbol de copia ya está extraído
  /// (p. ej. cloud-pack incremental).
  Future<void> importVaultBackupOverwriteActiveFromExtractedDir(
    Directory extractedDir,
    String backupPassword,
  ) async {
    if (!isUnlocked) {
      throw StateError('La libreta debe estar desbloqueada para importar.');
    }
    await validateImportZip(extractedDir, backupPassword);
    await applyImportFromDirectory(extractedDir);
    await bootstrap();
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
          appearance: b.appearance,
          meetingNoteProvider: b.meetingNoteProvider,
          meetingNoteTranscriptionEnabled: b.meetingNoteTranscriptionEnabled,
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

  /// Importa un ZIP exportado por Notion a la libreta actual (debe estar desbloqueada).
  Future<NotionParsedExport> importNotionIntoCurrentVault(
    String zipPath,
  ) async {
    if (_state != VaultFlowState.unlocked ||
        (vaultUsesEncryption && _dek == null)) {
      throw StateError('Debes desbloquear la libreta para importar.');
    }
    final temp = await Directory.systemTemp.createTemp('folio_notion_import_');
    try {
      await extractNotionZipToDirectory(File(zipPath), temp);
      final parsed = parseNotionExportDirectory(temp);
      lastImportWarnings = parsed.warnings;
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

  /// Importa un ZIP exportado por Notion creando una libreta nueva.
  Future<String> importNotionAsNewVault(
    String zipPath, {
    required String masterPassword,
    String? displayName,
  }) async {
    if (kIsWeb) throw UnsupportedError('Notion import not available on web');
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
        starterContent: VaultStarterContent.disabled,
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
      lastImportWarnings = parsed.warnings;
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

  /// Onboarding por copia: escribe la libreta en el id activo (o nuevo) y registra.
  Future<void> completeOnboardingFromBackup(
    String zipPath,
    String backupPassword,
  ) async {
    if (kIsWeb) throw UnsupportedError('Backup import not available on web');
    await _registry.load();
    if (VaultPaths.activeVaultId != null && await VaultPaths.vaultExists()) {
      throw StateError('Ya hay datos en la libreta actual.');
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
            displayName: 'Libreta $ordinal',
            createdAtMs: DateTime.now().millisecondsSinceEpoch,
          ),
        );
      }
      await _registry.setActiveVaultId(id);

      final plainImported = await _repo.isPlaintextVault();
      _vaultUsesEncryption = !plainImported;

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

  /// Onboarding por copia ya extraída en disco (p. ej. cloud-pack descargado).
  Future<void> completeOnboardingFromExtractedDirectory(
    Directory extractedDir,
    String backupPassword,
  ) async {
    await _registry.load();
    if (VaultPaths.activeVaultId != null && await VaultPaths.vaultExists()) {
      throw StateError('Ya hay datos en la libreta actual.');
    }
    await validateImportZip(extractedDir, backupPassword);

    var id = VaultPaths.activeVaultId;
    if (id == null) {
      id = _uuid.v4();
      VaultPaths.setActiveVaultId(id);
    }
    final root = await VaultPaths.vaultDirectoryForId(id);
    await applyImportToVaultRoot(extractedDir, root);

    if (!_registry.containsVault(id)) {
      final ordinal = _registry.vaults.length + 1;
      await _registry.add(
        VaultEntry(
          id: id,
          displayName: 'Libreta $ordinal',
          createdAtMs: DateTime.now().millisecondsSinceEpoch,
        ),
      );
    }
    await _registry.setActiveVaultId(id);

    final plainImported = await _repo.isPlaintextVault();
    _vaultUsesEncryption = !plainImported;

    await unlockWithPassword(backupPassword);
    _resumeVaultIdAfterNewVault = null;
  }

  Future<void> unlockWithPassword(String password) async {
    if (!vaultUsesEncryption) {
      _dek = null;
      final payload = await _repo.loadPayload(null);
      _pages = List.from(payload.pages);
      _loadRevisionsFromPayload(payload);
      _ensureOrderForCurrentPages();
      await _applyInitialPageSelection(preferPersistedPreference: true);
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
    _ensureOrderForCurrentPages();
    await _applyInitialPageSelection(preferPersistedPreference: true);
    _state = VaultFlowState.unlocked;
    _restartIdleLockTimer();
    notifyListeners();
  }

  Future<void> unlockWithDeviceAuth() async {
    if (kIsWeb) {
      throw UnsupportedError('Device authentication is not available on web');
    }
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
      throw StateError('No hay libreta activa');
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
    _ensureOrderForCurrentPages();
    await _applyInitialPageSelection(preferPersistedPreference: true);
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
      throw StateError('No hay libreta activa');
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
    _ensureOrderForCurrentPages();
    await _applyInitialPageSelection(preferPersistedPreference: true);
    _state = VaultFlowState.unlocked;
    _restartIdleLockTimer();
    notifyListeners();
  }

  /// Vacía el estado en memoria de la libreta (sin fijar [VaultFlowState]).
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
        AiChatThreadData(
          id: 'chat_0',
          title: _titleL10n.aiChatTitleNumbered(1),
          messages: const [],
        ),
      );
    _aiActiveChatIndex = 0;
    _contentEpoch = 0;
    _selectedPageId = null;
  }

  Future<void> lock() async {
    if (!vaultUsesEncryption) return;
    await _persistLastSelectedPageBeforeLock();
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
      unawaited(lock());
    }
  }

  void _restartIdleLockTimer() {
    _idleLockTimer?.cancel();
    _idleLockTimer = Timer(_idleLockDuration, () {
      unawaited(lock());
    });
  }

  Future<void> enableDeviceQuickUnlock() async {
    if (kIsWeb) {
      throw UnsupportedError('Device authentication is not available on web');
    }
    if (!vaultUsesEncryption) {
      throw StateError('El desbloqueo rápido requiere libreta cifrada');
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
      throw StateError('La passkey requiere libreta cifrada');
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
    final requestId = ++_selectedPagePersistRequestId;
    final activeVaultId = VaultPaths.activeVaultId;
    unawaited(
      _persistLastSelectedPageForActiveVault(
        id,
        vaultId: activeVaultId,
        requestId: requestId,
      ),
    );
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

  /// Renombra un hilo de chat (persiste con la libreta).
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
        title: _titleL10n.aiChatTitleNumbered(next),
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
      _aiChatThreads[0] = AiChatThreadData(
        id: 'chat_0',
        title: _titleL10n.aiChatTitleNumbered(1),
        messages: const [],
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

  int _aiChatIndexById(String chatId) {
    return _aiChatThreads.indexWhere((t) => t.id == chatId);
  }

  void appendMessageToAiChatById(String chatId, AiChatMessage message) {
    final i = _aiChatIndexById(chatId);
    if (i < 0) return;
    final current = _aiChatThreads[i];
    final nextMessages = List<AiChatMessage>.from(current.messages)
      ..add(message);
    _aiChatThreads[i] = AiChatThreadData(
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

  void updateMessageInActiveAiChat(int index, AiChatMessage message) {
    final current = _aiChatThreads[_aiActiveChatIndex];
    if (index < 0 || index >= current.messages.length) return;
    final nextMessages = List<AiChatMessage>.from(current.messages)
      ..[index] = message;
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

  // ─── Page templates ──────────────────────────────────────────────────────────

  /// Guarda una página existente como template. En los bloques de tipo
  /// `image`, `file`, `video` o `audio` el campo `url` se conserva solo si
  /// apunta a una URL remota; las rutas locales se eliminan para evitar
  /// referencias rotas al compartir el template.
  FolioPageTemplate savePageAsTemplate(
    String pageId, {
    String? name,
    String? description,
    String? category,
  }) {
    final page = _pageById(pageId);
    if (page == null) throw StateError('Page $pageId not found');
    const localTypes = {'image', 'file', 'video', 'audio'};
    final blocks = cloneBlocksWithNewIds(
      'tpl_${_uuid.v4()}',
      page.blocks.map((b) {
        if (localTypes.contains(b.type)) {
          final url = b.url ?? '';
          final isRemote =
              url.startsWith('http://') || url.startsWith('https://');
          if (!isRemote) return b.copyWith(url: '');
        }
        return b;
      }).toList(),
    );
    final tpl = FolioPageTemplate(
      id: _uuid.v4(),
      name: name ?? page.title,
      description: description ?? '',
      emoji: page.emoji,
      category: category ?? '',
      blocks: blocks,
    );
    _pageTemplates.add(tpl);
    notifyListeners();
    scheduleSave();
    return tpl;
  }

  /// Añade un template importado desde archivo.
  void addTemplate(FolioPageTemplate template) {
    // Evita duplicados por ID.
    _pageTemplates.removeWhere((t) => t.id == template.id);
    _pageTemplates.add(template);
    notifyListeners();
    scheduleSave();
  }

  void deleteTemplate(String templateId) {
    _pageTemplates.removeWhere((t) => t.id == templateId);
    notifyListeners();
    scheduleSave();
  }

  void updateTemplate(FolioPageTemplate updated) {
    final i = _pageTemplates.indexWhere((t) => t.id == updated.id);
    if (i < 0) return;
    _pageTemplates[i] = updated;
    notifyListeners();
    scheduleSave();
  }

  /// Crea una nueva página a partir de un template y la selecciona.
  String addPageFromTemplate(FolioPageTemplate template, {String? parentId}) {
    final id = _uuid.v4();
    final blocks = cloneBlocksWithNewIds(id, template.blocks);
    _pages.add(
      FolioPage(
        id: id,
        title: template.name,
        emoji: template.emoji,
        parentId: parentId,
        blocks: blocks,
      ),
    );
    _selectedPageId = id;
    notifyListeners();
    scheduleSave(trackRevisionForPageId: id);
    return id;
  }

  /// Exporta el template a un archivo `.folio-template` en la ruta indicada.
  void exportTemplateToFile(FolioPageTemplate template, String filePath) {
    File(filePath).writeAsStringSync(template.encodeAsFile());
  }

  /// Parsea un archivo `.folio-template`. Devuelve el template o lanza
  /// [FormatException] si el contenido es inválido.
  FolioPageTemplate importTemplateFromFile(String filePath) {
    final raw = File(filePath).readAsStringSync();
    final tpl = FolioPageTemplate.tryParseFile(raw);
    if (tpl == null) {
      throw FormatException(_titleL10n.invalidFolioTemplateFile);
    }
    // Reasignar ID para evitar colisiones.
    final imported = FolioPageTemplate(
      id: _uuid.v4(),
      name: tpl.name,
      description: tpl.description,
      emoji: tpl.emoji,
      category: tpl.category,
      blocks: tpl.blocks,
      createdAtMs: tpl.createdAtMs,
    );
    addTemplate(imported);
    return imported;
  }

  // ─────────────────────────────────────────────────────────────────────────────

  void addPage({String? parentId}) {
    final id = _uuid.v4();
    _pages.add(
      FolioPage(
        id: id,
        title: _titleL10n.defaultNewPageTitle,
        parentId: parentId,
        blocks: [FolioBlock(id: '${id}_b0', type: 'paragraph', text: '')],
      ),
    );
    _pageOrderByParent
        .putIfAbsent(_orderKeyForParent(parentId), () => <String>[])
        .add(id);
    _selectedPageId = id;
    notifyListeners();
    scheduleSave(trackRevisionForPageId: id);
  }

  void addFolder({String? parentId}) {
    final id = _uuid.v4();
    _pages.add(
      FolioPage(
        id: id,
        title: _titleL10n.defaultNewPageTitle,
        parentId: parentId,
        isFolder: true,
        blocks: [FolioBlock(id: '${id}_b0', type: 'paragraph', text: '')],
      ),
    );
    _pageOrderByParent
        .putIfAbsent(_orderKeyForParent(parentId), () => <String>[])
        .add(id);
    notifyListeners();
    scheduleSave(trackRevisionForPageId: id);
  }

  FolioMarkdownImportResult importMarkdownDocument(
    String markdown, {
    String? title,
    String? parentId,
    String? sourceApp,
    String? sourceUrl,
    String? clientAppId,
    String? clientAppName,
    String? sessionId,
    Map<String, Object?> metadata = const <String, Object?>{},
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
            lastImportInfo: _buildImportInfo(
              clientAppId: clientAppId,
              clientAppName: clientAppName,
              sessionId: sessionId,
              sourceApp: sourceApp,
              sourceUrl: sourceUrl,
              metadata: metadata,
              mode: mode,
            ),
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
        page.lastImportInfo = _buildImportInfo(
          clientAppId: clientAppId,
          clientAppName: clientAppName,
          sessionId: sessionId,
          sourceApp: sourceApp,
          sourceUrl: sourceUrl,
          metadata: metadata,
          mode: mode,
        );
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
        page.lastImportInfo = _buildImportInfo(
          clientAppId: clientAppId,
          clientAppName: clientAppName,
          sessionId: sessionId,
          sourceApp: sourceApp,
          sourceUrl: sourceUrl,
          metadata: metadata,
          mode: mode,
        );
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

  List<FolioBlock> _reassignBlockIdsForPage(
    String pageId,
    List<FolioBlock> blocks, {
    int startIndex = 0,
  }) {
    final out = <FolioBlock>[];
    for (var i = 0; i < blocks.length; i++) {
      final b = FolioBlock.fromJson(blocks[i].toJson());
      out.add(
        FolioBlock.fromJson({
          ...b.toJson(),
          'id': '${pageId}_b${startIndex + i}',
        }),
      );
    }
    return out;
  }

  FolioMarkdownImportResult importHtmlDocument(
    String html, {
    String? title,
    String? parentId,
    FolioMarkdownImportMode mode = FolioMarkdownImportMode.newPage,
  }) {
    if (!isUnlocked) {
      throw StateError('Unlock Folio before importing.');
    }

    final trimmed = html.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('HTML vacío.');
    }

    final blocks = folioParseHtmlBlocks(trimmed);
    if (blocks.isEmpty) {
      throw ArgumentError('HTML vacío.');
    }

    final targetPageId = _selectedPageId;
    if (mode != FolioMarkdownImportMode.newPage && targetPageId == null) {
      throw StateError('No hay página activa para importar.');
    }

    switch (mode) {
      case FolioMarkdownImportMode.newPage:
        final id = _uuid.v4();
        final resolvedTitle = (title ?? 'Imported page').trim().isEmpty
            ? 'Imported page'
            : (title ?? 'Imported page').trim();
        final finalBlocks = _reassignBlockIdsForPage(id, blocks);
        _pages.add(
          FolioPage(
            id: id,
            title: resolvedTitle,
            parentId: parentId,
            blocks: finalBlocks,
          ),
        );
        _selectedPageId = id;
        notifyListeners();
        scheduleSave(trackRevisionForPageId: id);
        return FolioMarkdownImportResult(
          pageId: id,
          pageTitle: resolvedTitle,
          mode: mode,
          blockCount: finalBlocks.length,
        );
      case FolioMarkdownImportMode.replaceCurrentPage:
        final page = selectedPage;
        if (page == null) {
          throw StateError('No hay página activa para reemplazar.');
        }
        final finalBlocks = _reassignBlockIdsForPage(page.id, blocks);
        page.title = (title ?? page.title).trim().isEmpty
            ? page.title
            : (title ?? page.title).trim();
        page.blocks = finalBlocks;
        _selectedPageId = page.id;
        _contentEpoch++;
        notifyListeners();
        scheduleSave(trackRevisionForPageId: page.id);
        return FolioMarkdownImportResult(
          pageId: page.id,
          pageTitle: page.title,
          mode: mode,
          blockCount: finalBlocks.length,
        );
      case FolioMarkdownImportMode.appendToCurrentPage:
        final page = selectedPage;
        if (page == null) {
          throw StateError('No hay página activa para anexar contenido.');
        }
        final appended = _reassignBlockIdsForPage(
          page.id,
          blocks,
          startIndex: page.blocks.length,
        );
        final existingSingleEmpty =
            page.blocks.length == 1 &&
            page.blocks.first.type == 'paragraph' &&
            page.blocks.first.text.trim().isEmpty;
        page.blocks = existingSingleEmpty
            ? appended
            : [...page.blocks, ...appended];
        _selectedPageId = page.id;
        _contentEpoch++;
        notifyListeners();
        scheduleSave(trackRevisionForPageId: page.id);
        return FolioMarkdownImportResult(
          pageId: page.id,
          pageTitle: page.title,
          mode: mode,
          blockCount: appended.length,
        );
    }
  }

  FolioMarkdownImportResult importPageJsonDocument(
    String jsonString, {
    String? parentId,
    FolioMarkdownImportMode mode = FolioMarkdownImportMode.newPage,
  }) {
    if (!isUnlocked) {
      throw StateError('Unlock Folio before importing.');
    }
    final trimmed = jsonString.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('JSON vacío.');
    }
    dynamic raw;
    try {
      raw = jsonDecode(trimmed);
    } catch (e) {
      throw ArgumentError('JSON inválido: $e');
    }
    Map<String, dynamic> pageJson;
    if (raw is Map && raw['schema'] is String && raw['page'] is Map) {
      pageJson = Map<String, dynamic>.from(raw['page'] as Map);
    } else if (raw is Map) {
      pageJson = Map<String, dynamic>.from(raw);
    } else {
      throw ArgumentError('JSON inválido: se esperaba un objeto.');
    }
    final importedTitle = (pageJson['title'] as String?)?.trim();
    final rawBlocks = pageJson['blocks'];
    if (rawBlocks is! List) {
      throw ArgumentError('JSON inválido: falta blocks[].');
    }
    final blocks = rawBlocks
        .map((e) => FolioBlock.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    if (blocks.isEmpty) {
      throw ArgumentError('JSON inválido: blocks[] vacío.');
    }

    final targetPageId = _selectedPageId;
    if (mode != FolioMarkdownImportMode.newPage && targetPageId == null) {
      throw StateError('No hay página activa para importar.');
    }

    switch (mode) {
      case FolioMarkdownImportMode.newPage:
        final id = _uuid.v4();
        final title = (importedTitle == null || importedTitle.isEmpty)
            ? 'Imported page'
            : importedTitle;
        final finalBlocks = _reassignBlockIdsForPage(id, blocks);
        _pages.add(
          FolioPage(
            id: id,
            title: title,
            parentId: parentId,
            blocks: finalBlocks,
          ),
        );
        _selectedPageId = id;
        notifyListeners();
        scheduleSave(trackRevisionForPageId: id);
        return FolioMarkdownImportResult(
          pageId: id,
          pageTitle: title,
          mode: mode,
          blockCount: finalBlocks.length,
        );
      case FolioMarkdownImportMode.replaceCurrentPage:
        final page = selectedPage;
        if (page == null) {
          throw StateError('No hay página activa para reemplazar.');
        }
        final finalBlocks = _reassignBlockIdsForPage(page.id, blocks);
        if (importedTitle != null && importedTitle.isNotEmpty) {
          page.title = importedTitle;
        }
        page.blocks = finalBlocks;
        _selectedPageId = page.id;
        _contentEpoch++;
        notifyListeners();
        scheduleSave(trackRevisionForPageId: page.id);
        return FolioMarkdownImportResult(
          pageId: page.id,
          pageTitle: page.title,
          mode: mode,
          blockCount: finalBlocks.length,
        );
      case FolioMarkdownImportMode.appendToCurrentPage:
        final page = selectedPage;
        if (page == null) {
          throw StateError('No hay página activa para anexar contenido.');
        }
        final appended = _reassignBlockIdsForPage(
          page.id,
          blocks,
          startIndex: page.blocks.length,
        );
        final existingSingleEmpty =
            page.blocks.length == 1 &&
            page.blocks.first.type == 'paragraph' &&
            page.blocks.first.text.trim().isEmpty;
        page.blocks = existingSingleEmpty
            ? appended
            : [...page.blocks, ...appended];
        _selectedPageId = page.id;
        _contentEpoch++;
        notifyListeners();
        scheduleSave(trackRevisionForPageId: page.id);
        return FolioMarkdownImportResult(
          pageId: page.id,
          pageTitle: page.title,
          mode: mode,
          blockCount: appended.length,
        );
    }
  }

  /// Actualiza el contenido de una página existente desde una app externa.
  ///
  /// Solo la app que importó originalmente la página puede actualizarla
  /// (`page.lastImportInfo.clientAppId` debe coincidir con [clientAppId]).
  /// Las páginas creadas de forma nativa (sin [FolioPageImportInfo]) son
  /// siempre rechazadas.
  ///
  /// Lanza [StateError] con mensaje `'NOT_OWNER'` si la app no es la dueña,
  /// `'PAGE_NOT_FOUND'` si el id no existe, o
  /// `'Unlock Folio before importing.'` si el vault está bloqueado.
  FolioMarkdownImportResult updatePageContent(
    String pageId,
    String markdown, {
    String? title,
    String? sourceApp,
    String? sourceUrl,
    String? clientAppId,
    String? clientAppName,
    String? sessionId,
    Map<String, Object?> metadata = const <String, Object?>{},
    FolioMarkdownImportMode mode = FolioMarkdownImportMode.replaceCurrentPage,
  }) {
    if (!isUnlocked) {
      throw StateError('Unlock Folio before importing.');
    }

    final page = _pageById(pageId);
    if (page == null) {
      throw StateError('PAGE_NOT_FOUND');
    }

    final ownerId = page.lastImportInfo?.clientAppId;
    final requesterId = clientAppId?.trim().isNotEmpty == true
        ? clientAppId!.trim()
        : null;
    if (ownerId == null || requesterId == null || ownerId != requesterId) {
      throw StateError('NOT_OWNER');
    }

    if (mode == FolioMarkdownImportMode.newPage) {
      throw ArgumentError(
        'importMode "newPage" no está soportado en updatePageContent.',
      );
    }

    final trimmed = markdown.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Markdown vacío.');
    }

    switch (mode) {
      case FolioMarkdownImportMode.newPage:
        throw ArgumentError(
          'importMode "newPage" no está soportado en updatePageContent.',
        );
      case FolioMarkdownImportMode.replaceCurrentPage:
        final doc = FolioMarkdownCodec.parseDocument(
          trimmed,
          pageId: page.id,
          fallbackTitle: title ?? page.title,
          sourceApp: sourceApp,
          sourceUrl: sourceUrl,
        );
        page.title = doc.title.trim().isEmpty ? page.title : doc.title.trim();
        page.blocks = doc.blocks;
        page.lastImportInfo = _buildImportInfo(
          clientAppId: clientAppId,
          clientAppName: clientAppName,
          sessionId: sessionId,
          sourceApp: sourceApp,
          sourceUrl: sourceUrl,
          metadata: metadata,
          mode: mode,
        );
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
        page.lastImportInfo = _buildImportInfo(
          clientAppId: clientAppId,
          clientAppName: clientAppName,
          sessionId: sessionId,
          sourceApp: sourceApp,
          sourceUrl: sourceUrl,
          metadata: metadata,
          mode: mode,
        );
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

  /// Returns metadata for every page that was imported by [clientAppId].
  List<Map<String, Object?>> listPagesByApp(String clientAppId) {
    if (!isUnlocked) {
      throw StateError('Unlock Folio before accessing pages.');
    }
    final id = clientAppId.trim();
    return _pages
        .where((p) => p.lastImportInfo?.clientAppId == id)
        .map(
          (p) => <String, Object?>{
            'pageId': p.id,
            'title': p.title,
            if (p.emoji != null && p.emoji!.trim().isNotEmpty) 'emoji': p.emoji,
            'parentId': p.parentId,
            'blockCount': p.blocks.length,
            'icons': p.blocks
                .map((b) => _normalizeIconValue(b.icon))
                .whereType<String>()
                .toSet()
                .toList(),
            'importedAtMs': p.lastImportInfo!.importedAtMs,
            'importMode': p.lastImportInfo!.importMode,
            if (p.lastImportInfo!.sourceApp != null)
              'sourceApp': p.lastImportInfo!.sourceApp,
            if (p.lastImportInfo!.sourceUrl != null)
              'sourceUrl': p.lastImportInfo!.sourceUrl,
          },
        )
        .toList();
  }

  /// Creates a new page from a list of pre-parsed [FolioBlock] objects.
  /// Block `id`s that are empty are replaced with generated UUIDs.
  FolioMarkdownImportResult importBlocksDocument(
    String title,
    List<FolioBlock> blocks, {
    String? parentId,
    String? sourceApp,
    String? sourceUrl,
    String? clientAppId,
    String? clientAppName,
    String? sessionId,
    Map<String, Object?> metadata = const <String, Object?>{},
  }) {
    if (!isUnlocked) {
      throw StateError('Unlock Folio before importing.');
    }
    if (blocks.isEmpty) {
      throw ArgumentError('blocks no puede estar vacío.');
    }
    final pageId = _uuid.v4();
    final resolvedBlocks = blocks.map((b) {
      if (b.id.trim().isEmpty) {
        return FolioBlock(
          id: _newBlockId(pageId),
          type: b.type,
          text: b.text,
          checked: b.checked,
          expanded: b.expanded,
          codeLanguage: b.codeLanguage,
          depth: b.depth,
          icon: b.icon,
          url: b.url,
          imageWidth: b.imageWidth,
          appearance: b.appearance,
          meetingNoteProvider: b.meetingNoteProvider,
          meetingNoteTranscriptionEnabled: b.meetingNoteTranscriptionEnabled,
        );
      }
      return b;
    }).toList();
    final resolvedTitle = title.trim().isEmpty ? 'Imported page' : title.trim();
    _pages.add(
      FolioPage(
        id: pageId,
        title: resolvedTitle,
        parentId: parentId,
        lastImportInfo: _buildImportInfo(
          clientAppId: clientAppId,
          clientAppName: clientAppName,
          sessionId: sessionId,
          sourceApp: sourceApp,
          sourceUrl: sourceUrl,
          metadata: metadata,
          mode: FolioMarkdownImportMode.newPage,
        ),
        blocks: resolvedBlocks,
      ),
    );
    _selectedPageId = pageId;
    notifyListeners();
    scheduleSave(trackRevisionForPageId: pageId);
    return FolioMarkdownImportResult(
      pageId: pageId,
      pageTitle: resolvedTitle,
      mode: FolioMarkdownImportMode.newPage,
      blockCount: resolvedBlocks.length,
    );
  }

  /// Updates an existing page with pre-parsed [FolioBlock] objects.
  /// Only the app that originally imported the page may call this.
  /// Block `id`s that are empty are replaced with generated UUIDs.
  FolioMarkdownImportResult updatePageBlocks(
    String pageId,
    List<FolioBlock> blocks, {
    String? title,
    String? sourceApp,
    String? sourceUrl,
    String? clientAppId,
    String? clientAppName,
    String? sessionId,
    Map<String, Object?> metadata = const <String, Object?>{},
    FolioMarkdownImportMode mode = FolioMarkdownImportMode.replaceCurrentPage,
  }) {
    if (!isUnlocked) {
      throw StateError('Unlock Folio before importing.');
    }
    final page = _pageById(pageId);
    if (page == null) {
      throw StateError('PAGE_NOT_FOUND');
    }
    final ownerId = page.lastImportInfo?.clientAppId;
    final requesterId = clientAppId?.trim().isNotEmpty == true
        ? clientAppId!.trim()
        : null;
    if (ownerId == null || requesterId == null || ownerId != requesterId) {
      throw StateError('NOT_OWNER');
    }
    if (mode == FolioMarkdownImportMode.newPage) {
      throw ArgumentError(
        'importMode "newPage" no está soportado en updatePageBlocks.',
      );
    }
    if (blocks.isEmpty) {
      throw ArgumentError('blocks no puede estar vacío.');
    }
    final resolvedBlocks = blocks.map((b) {
      if (b.id.trim().isEmpty) {
        return FolioBlock(
          id: _newBlockId(page.id),
          type: b.type,
          text: b.text,
          checked: b.checked,
          expanded: b.expanded,
          codeLanguage: b.codeLanguage,
          depth: b.depth,
          icon: b.icon,
          url: b.url,
          imageWidth: b.imageWidth,
          appearance: b.appearance,
          meetingNoteProvider: b.meetingNoteProvider,
          meetingNoteTranscriptionEnabled: b.meetingNoteTranscriptionEnabled,
        );
      }
      return b;
    }).toList();
    switch (mode) {
      case FolioMarkdownImportMode.newPage:
        throw ArgumentError(
          'importMode "newPage" no está soportado en updatePageBlocks.',
        );
      case FolioMarkdownImportMode.replaceCurrentPage:
        _rememberUndoBeforePageMutation(page.id);
        if (title != null && title.trim().isNotEmpty) {
          page.title = title.trim();
        }
        page.blocks = resolvedBlocks;
        page.lastImportInfo = _buildImportInfo(
          clientAppId: clientAppId,
          clientAppName: clientAppName,
          sessionId: sessionId,
          sourceApp: sourceApp,
          sourceUrl: sourceUrl,
          metadata: metadata,
          mode: mode,
        );
        _contentEpoch++;
        notifyListeners();
        scheduleSave(trackRevisionForPageId: page.id);
        return FolioMarkdownImportResult(
          pageId: page.id,
          pageTitle: page.title,
          mode: mode,
          blockCount: resolvedBlocks.length,
        );
      case FolioMarkdownImportMode.appendToCurrentPage:
        _rememberUndoBeforePageMutation(page.id);
        final existingSingleEmpty =
            page.blocks.length == 1 &&
            page.blocks.first.type == 'paragraph' &&
            page.blocks.first.text.trim().isEmpty;
        if (existingSingleEmpty) {
          page.blocks = resolvedBlocks;
        } else {
          page.blocks.addAll(resolvedBlocks);
        }
        page.lastImportInfo = _buildImportInfo(
          clientAppId: clientAppId,
          clientAppName: clientAppName,
          sessionId: sessionId,
          sourceApp: sourceApp,
          sourceUrl: sourceUrl,
          metadata: metadata,
          mode: mode,
        );
        _contentEpoch++;
        notifyListeners();
        scheduleSave(trackRevisionForPageId: page.id);
        return FolioMarkdownImportResult(
          pageId: page.id,
          pageTitle: page.title,
          mode: mode,
          blockCount: page.blocks.length,
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

  FolioPageImportInfo _buildImportInfo({
    String? clientAppId,
    String? clientAppName,
    String? sessionId,
    String? sourceApp,
    String? sourceUrl,
    required Map<String, Object?> metadata,
    required FolioMarkdownImportMode mode,
  }) {
    final appId = clientAppId?.trim().isNotEmpty == true
        ? clientAppId!.trim()
        : 'unknown-client';
    final appName = clientAppName?.trim().isNotEmpty == true
        ? clientAppName!.trim()
        : appId;
    return FolioPageImportInfo(
      clientAppId: appId,
      clientAppName: appName,
      sessionId: sessionId?.trim().isEmpty ?? true ? null : sessionId!.trim(),
      sourceApp: sourceApp?.trim().isEmpty ?? true ? null : sourceApp!.trim(),
      sourceUrl: sourceUrl?.trim().isEmpty ?? true ? null : sourceUrl!.trim(),
      importedAtMs: DateTime.now().millisecondsSinceEpoch,
      importMode: mode.name,
      metadata: metadata,
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
    for (final entry in _pageOrderByParent.entries.toList()) {
      entry.value.remove(id);
      if (entry.value.isEmpty) _pageOrderByParent.remove(entry.key);
    }
    _pageRevisions.remove(id);
    _undoByPage.remove(id);
    _redoByPage.remove(id);
    _lastUndoTypingCaptureAt.remove(id);
    _pageAcl.remove(id);
    _comments.removeWhere((c) => c.pageId == id);
    _pageIdsPendingRevision.remove(id);
    if (wasSelected) {
      _pickInitialSelection();
      unawaited(_persistLastSelectedPageForActiveVault(_selectedPageId));
    }
    notifyListeners();
    scheduleSave();
  }

  void renamePage(String id, String title) {
    final p = _pageById(id);
    if (p == null) return;
    final t = title.trim();
    if (t.isEmpty) return;
    if (p.title == t) return;
    _rememberUndoBeforePageMutation(id);
    p.title = t;
    notifyListeners();
    scheduleSave(trackRevisionForPageId: id);
  }

  void updatePageTitleLive(String id, String title) {
    final p = _pageById(id);
    if (p == null) return;
    if (p.title == title) return;
    _rememberUndoBeforePageMutation(id);
    p.title = title;
    notifyListeners();
    scheduleSave(trackRevisionForPageId: id);
  }

  void setPageEmoji(String id, String? emoji) {
    final p = _pageById(id);
    if (p == null) return;
    final next = _normalizeIconValue(emoji);
    _rememberUndoBeforePageMutation(id);
    p.emoji = (next == null || next.isEmpty) ? null : next;
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

  void setPageCollabRoomId(String pageId, String? roomId, {String? joinCode}) {
    final p = _pageById(pageId);
    if (p == null) return;
    final next = roomId?.trim();
    p.collabRoomId = (next == null || next.isEmpty) ? null : next;
    if (p.collabRoomId == null) {
      p.collabJoinCode = null;
    } else if (joinCode != null) {
      final c = joinCode.trim();
      p.collabJoinCode = c.isEmpty ? null : c;
    }
    notifyListeners();
    scheduleSave();
  }

  void setPageCollabJoinCode(String pageId, String? joinCode) {
    final p = _pageById(pageId);
    if (p == null) return;
    final c = joinCode?.trim();
    p.collabJoinCode = (c == null || c.isEmpty) ? null : c;
    notifyListeners();
    scheduleSave();
  }

  /// Aplica estado remoto de colaboración (sin deshacer local explícito).
  ///
  /// Sustituye título y bloques por el snapshot remoto. Si el par remoto
  /// está desactualizado, un bloque de texto (p. ej. cita) puede verse vacío
  /// hasta la siguiente sincronización; el editor alineará controladores en
  /// el siguiente frame.
  void applyRemoteCollabPageState({
    required String pageId,
    required String title,
    required List<FolioBlock> blocks,
  }) {
    if (vaultUsesEncryption && _dek == null) return;
    final page = _pageById(pageId);
    if (page == null) return;
    page.title = title;
    page.blocks = blocks;
    _contentEpoch++;
    notifyListeners();
    scheduleSave(trackRevisionForPageId: pageId);
  }

  /// Archiva mensajes del chat de colaboración como comentarios locales de la página.
  void archiveCollabChatToComments({
    required String pageId,
    required List<
      ({
        String messageId,
        String authorUid,
        String authorName,
        String text,
        int createdAtMs,
      })
    >
    messages,
  }) {
    if (vaultUsesEncryption && _dek == null) return;
    if (_pageById(pageId) == null) return;
    final existing = _comments
        .where((c) => c.pageId == pageId)
        .map((c) => c.collabMessageId)
        .whereType<String>()
        .toSet();
    for (final m in messages) {
      if (existing.contains(m.messageId)) continue;
      _comments.add(
        LocalPageComment(
          id: _uuid.v4(),
          pageId: pageId,
          authorProfileId: m.authorUid,
          text: m.text,
          createdAtMs: m.createdAtMs,
          collabMessageId: m.messageId,
          authorDisplayName: m.authorName,
        ),
      );
    }
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

  void deleteComment(String commentId) {
    final idx = _comments.indexWhere((c) => c.id == commentId);
    if (idx == -1) return;
    _comments.removeAt(idx);
    notifyListeners();
    scheduleSave();
  }

  void updateComment(String commentId, String newText) {
    final t = newText.trim();
    if (t.isEmpty) return;
    final c = _comments.firstWhere(
      (c) => c.id == commentId,
      orElse: () => throw StateError('Comment not found'),
    );
    c.text = t;
    notifyListeners();
    scheduleSave();
  }

  void resolveComment(String commentId, {bool resolved = true}) {
    final idx = _comments.indexWhere((c) => c.id == commentId);
    if (idx == -1) return;
    _comments[idx].resolved = resolved;
    _comments[idx].resolvedAtMs = resolved
        ? DateTime.now().millisecondsSinceEpoch
        : null;
    notifyListeners();
    scheduleSave();
  }

  List<LocalPageComment> commentsForBlock(String blockId) =>
      _comments.where((c) => c.blockId == blockId).toList()
        ..sort((a, b) => a.createdAtMs.compareTo(b.createdAtMs));

  // ---------------------------------------------------------------------------
  // Page properties (frontmatter)
  // ---------------------------------------------------------------------------

  void addPageProperty(String pageId, FolioPageProperty prop) {
    final p = _pageById(pageId);
    if (p == null) return;
    p.properties.add(prop);
    notifyListeners();
    scheduleSave();
  }

  void updatePagePropertyValue(String pageId, String propId, dynamic value) {
    final p = _pageById(pageId);
    if (p == null) return;
    final idx = p.properties.indexWhere((pr) => pr.id == propId);
    if (idx == -1) return;
    p.properties[idx].value = value;
    notifyListeners();
    scheduleSave();
  }

  void removePageProperty(String pageId, String propId) {
    final p = _pageById(pageId);
    if (p == null) return;
    p.properties.removeWhere((pr) => pr.id == propId);
    notifyListeners();
    scheduleSave();
  }

  void renamePageProperty(String pageId, String propId, String newName) {
    final p = _pageById(pageId);
    if (p == null) return;
    final idx = p.properties.indexWhere((pr) => pr.id == propId);
    if (idx == -1) return;
    final trimmed = newName.trim();
    if (trimmed.isEmpty) return;
    p.properties[idx].name = trimmed;
    notifyListeners();
    scheduleSave();
  }

  void addPagePropertyOption(String pageId, String propId, String option) {
    final p = _pageById(pageId);
    if (p == null) return;
    final idx = p.properties.indexWhere((pr) => pr.id == propId);
    if (idx == -1) return;
    final o = option.trim();
    if (o.isEmpty || p.properties[idx].options.contains(o)) return;
    p.properties[idx].options.add(o);
    notifyListeners();
    scheduleSave();
  }

  void reorderPageProperties(String pageId, int oldIndex, int newIndex) {
    final p = _pageById(pageId);
    if (p == null) return;
    if (oldIndex < 0 || oldIndex >= p.properties.length) return;
    final item = p.properties.removeAt(oldIndex);
    final insertAt = (newIndex > oldIndex ? newIndex - 1 : newIndex).clamp(
      0,
      p.properties.length,
    );
    p.properties.insert(insertAt, item);
    notifyListeners();
    scheduleSave();
  }

  // ---------------------------------------------------------------------------
  // Tags
  // ---------------------------------------------------------------------------

  /// All unique tags across all pages, sorted alphabetically.
  List<String> get allTags {
    final tags = <String>{};
    for (final p in _pages) {
      tags.addAll(p.tags);
    }
    return tags.toList()..sort();
  }

  void addPageTag(String pageId, String tag) {
    final t = tag.trim();
    if (t.isEmpty) return;
    final p = _pageById(pageId);
    if (p == null) return;
    if (p.tags.contains(t)) return;
    p.tags.add(t);
    notifyListeners();
    scheduleSave();
  }

  void removePageTag(String pageId, String tag) {
    final p = _pageById(pageId);
    if (p == null) return;
    p.tags.remove(tag);
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
    final oldParentId = p.parentId;
    _rememberUndoBeforePageMutation(pageId);
    p.parentId = newParentId;
    if (oldParentId != newParentId) {
      final oldKey = _orderKeyForParent(oldParentId);
      final newKey = _orderKeyForParent(newParentId);
      _pageOrderByParent[oldKey]?.remove(pageId);
      (_pageOrderByParent[newKey] ??= <String>[]).add(pageId);
    }
    notifyListeners();
    scheduleSave(trackRevisionForPageId: pageId);
  }

  void deleteFolderMoveChildrenToRoot(String folderId) {
    final folder = _pageById(folderId);
    if (folder == null || !folder.isFolder) return;
    if (_pages.length <= 1) return;
    final children = _pages.where((p) => p.parentId == folderId).toList();
    _rememberUndoBeforePageMutation(folderId);
    for (final child in children) {
      child.parentId = null;
      final rootKey = _orderKeyForParent(null);
      (_pageOrderByParent[rootKey] ??= <String>[]).add(child.id);
    }
    // Quitar ids movidos del orden antiguo del folder.
    _pageOrderByParent[_orderKeyForParent(folderId)]?.removeWhere(
      (id) => children.any((c) => c.id == id),
    );
    // Borrar folder si ya se puede.
    if (!_hasChildren(folderId)) {
      deletePage(folderId);
    } else {
      // Si algo dejó hijos (defensivo), al menos desmarca como folder.
      folder.isFolder = false;
      notifyListeners();
      scheduleSave(trackRevisionForPageId: folderId);
    }
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
    _rememberUndoBeforePageMutation(pageId, isTyping: true);
    if (b.type == 'image' && b.text.isNotEmpty && b.text != text) {
      _deleteManagedAttachmentIfUnused(
        b.text,
        excludingPageId: pageId,
        excludingBlockId: blockId,
      );
    }
    b.text = text;
    _scheduleCoalescedTypingNotify();
    scheduleSave(trackRevisionForPageId: pageId);
  }

  /// Actualiza texto y Delta de un bloque de forma atómica.
  /// Si el bloque pertenece a un grupo de sincronización, propaga
  /// los cambios a todos los bloques del mismo grupo.
  void updateBlockTextFull(
    String pageId,
    String blockId,
    String text,
    String? richTextDeltaJson,
  ) {
    final page = _pageById(pageId);
    if (page == null) return;
    final b = _blockById(page, blockId);
    if (b == null) return;
    _rememberUndoBeforePageMutation(pageId, isTyping: true);
    if (b.type == 'image' && b.text.isNotEmpty && b.text != text) {
      _deleteManagedAttachmentIfUnused(
        b.text,
        excludingPageId: pageId,
        excludingBlockId: blockId,
      );
    }
    b.text = text;
    b.richTextDeltaJson = richTextDeltaJson;
    final groupId = b.syncGroupId;
    if (groupId != null) {
      _propagateSyncedBlockContent(
        groupId,
        sourceBlockId: blockId,
        text: text,
        richTextDeltaJson: richTextDeltaJson,
      );
    }
    _scheduleCoalescedTypingNotify();
    scheduleSave(trackRevisionForPageId: pageId);
  }

  void _propagateSyncedBlockContent(
    String groupId, {
    required String sourceBlockId,
    required String text,
    required String? richTextDeltaJson,
  }) {
    final pagesChanged = <String>{};
    for (final p in _pages) {
      for (final block in p.blocks) {
        if (block.id != sourceBlockId && block.syncGroupId == groupId) {
          block.text = text;
          block.richTextDeltaJson = richTextDeltaJson;
          pagesChanged.add(p.id);
        }
      }
    }
    for (final pid in pagesChanged) {
      scheduleSave(trackRevisionForPageId: pid);
    }
  }

  /// Asigna un nuevo UUID de sincronización al bloque y devuelve el UUID
  /// para que el llamador pueda copiarlo al portapapeles.
  String createSyncGroup(String pageId, String blockId) {
    final page = _pageById(pageId);
    if (page == null) return '';
    final b = _blockById(page, blockId);
    if (b == null) return '';
    final groupId = b.syncGroupId ?? _uuid.v4();
    b.syncGroupId = groupId;
    notifyListeners();
    scheduleSave(trackRevisionForPageId: pageId);
    return groupId;
  }

  /// Inserta una nueva copia sincronizada de [syncGroupId] después de [afterBlockId].
  /// Devuelve `true` si encontró el grupo y lo insertó; `false` si no existe.
  bool insertSyncedBlock(
    String pageId,
    String afterBlockId,
    String syncGroupId,
  ) {
    FolioBlock? source;
    for (final p in _pages) {
      for (final blk in p.blocks) {
        if (blk.syncGroupId == syncGroupId) {
          source = blk;
          break;
        }
      }
      if (source != null) break;
    }
    if (source == null) return false;
    final newBlock = FolioBlock(
      id: _newBlockId(pageId),
      type: source.type,
      text: source.text,
      richTextDeltaJson: source.richTextDeltaJson,
      syncGroupId: syncGroupId,
      checked: source.checked,
      depth: source.depth,
      icon: source.icon,
      appearance: source.appearance,
    );
    insertBlockAfter(
      pageId: pageId,
      afterBlockId: afterBlockId,
      block: newBlock,
    );
    return true;
  }

  /// Elimina el syncGroupId del bloque (desincroniza sin borrar contenido).
  void unsyncBlock(String pageId, String blockId) {
    final page = _pageById(pageId);
    if (page == null) return;
    final b = _blockById(page, blockId);
    if (b == null) return;
    b.syncGroupId = null;
    notifyListeners();
    scheduleSave(trackRevisionForPageId: pageId);
  }

  /// Número de bloques en un grupo de sincronización.
  int syncGroupBlockCount(String syncGroupId) {
    var count = 0;
    for (final p in _pages) {
      for (final blk in p.blocks) {
        if (blk.syncGroupId == syncGroupId) count++;
      }
    }
    return count;
  }

  void setBlockChecked(String pageId, String blockId, bool checked) {
    final page = _pageById(pageId);
    if (page == null) return;
    final b = _blockById(page, blockId);
    if (b == null || b.type != 'todo') return;
    _rememberUndoBeforePageMutation(pageId);
    b.checked = checked;
    notifyListeners();
    scheduleSave(trackRevisionForPageId: pageId);
  }

  void setBlockExpanded(String pageId, String blockId, bool expanded) {
    final page = _pageById(pageId);
    if (page == null) return;
    final b = _blockById(page, blockId);
    if (b == null || b.type != 'toggle') return;
    _rememberUndoBeforePageMutation(pageId);
    b.expanded = expanded;
    notifyListeners();
    scheduleSave(trackRevisionForPageId: pageId);
  }

  void updateBlockIcon(String pageId, String blockId, String? icon) {
    final page = _pageById(pageId);
    if (page == null) return;
    final b = _blockById(page, blockId);
    if (b == null) return;
    _rememberUndoBeforePageMutation(pageId);
    b.icon = _normalizeIconValue(icon);
    notifyListeners();
    scheduleSave(trackRevisionForPageId: pageId);
  }

  String? _normalizeIconValue(String? raw) {
    if (raw == null) return null;
    final normalized = raw.trim();
    if (normalized.isEmpty) return null;
    if (normalized.length > _maxIconLength) {
      return normalized.substring(0, _maxIconLength);
    }
    return normalized;
  }

  void setBlockAppearance(
    String pageId,
    String blockId,
    FolioBlockAppearance? appearance,
  ) {
    final page = _pageById(pageId);
    if (page == null) return;
    final b = _blockById(page, blockId);
    if (b == null) return;
    _rememberUndoBeforePageMutation(pageId);
    b.appearance = FolioBlockAppearance.normalizeOrNull(appearance);
    notifyListeners();
    scheduleSave(trackRevisionForPageId: pageId);
  }

  void updateBlockMeetingNoteProvider(
    String pageId,
    String blockId,
    String? value,
  ) {
    final page = _pageById(pageId);
    if (page == null) return;
    final b = _blockById(page, blockId);
    if (b == null) return;
    b.meetingNoteProvider = value;
    notifyListeners();
    scheduleSave(trackRevisionForPageId: pageId);
  }

  void updateBlockMeetingNoteTranscriptionEnabled(
    String pageId,
    String blockId,
    bool? enabled,
  ) {
    final page = _pageById(pageId);
    if (page == null) return;
    final b = _blockById(page, blockId);
    if (b == null) return;
    b.meetingNoteTranscriptionEnabled = enabled;
    notifyListeners();
    scheduleSave(trackRevisionForPageId: pageId);
  }

  void updateBlockUrl(String pageId, String blockId, String? url) {
    final page = _pageById(pageId);
    if (page == null) return;
    final b = _blockById(page, blockId);
    if (b == null) return;
    _rememberUndoBeforePageMutation(pageId);
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
    _rememberUndoBeforePageMutation(pageId);
    b.imageWidth = clamped;
    notifyListeners();
    scheduleSave(trackRevisionForPageId: pageId);
  }

  void changeBlockType(String pageId, String blockId, String newType) {
    final page = _pageById(pageId);
    if (page == null) return;
    final b = _blockById(page, blockId);
    if (b == null) return;
    _rememberUndoBeforePageMutation(pageId);
    final oldType = b.type;
    if (oldType == 'image' && newType != 'image' && b.text.isNotEmpty) {
      _deleteManagedAttachmentIfUnused(
        b.text,
        excludingPageId: pageId,
        excludingBlockId: blockId,
      );
    }
    if ((oldType == 'file' ||
            oldType == 'video' ||
            oldType == 'audio' ||
            oldType == 'meeting_note') &&
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
    } else if (oldType == 'kanban' && newType != 'kanban') {
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
    } else if (newType == 'kanban') {
      if (b.text.isEmpty || FolioKanbanData.tryParse(b.text) == null) {
        b.text = FolioKanbanData.defaults().encode();
      }
    } else if (newType == 'drive') {
      if (b.text.isEmpty || FolioFileDriveData.tryParse(b.text) == null) {
        b.text = FolioFileDriveData.defaults().encode();
      }
    } else if (newType == 'canvas') {
      if (b.text.isEmpty || FolioCanvasData.tryParse(b.text) == null) {
        b.text = FolioCanvasData.defaults().encode();
      }
    } else if (newType == 'image' && oldType != 'image') {
      b.text = '';
    }
    if (newType == 'toggle' && oldType != 'toggle') {
      b.text = FolioToggleData.empty().encode();
    }
    if (newType == 'task' && oldType != 'task') {
      b.text = FolioTaskData.defaults().encode();
    }
    if (oldType == 'task' && newType != 'task') {
      b.text = '';
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
      b.text = FolioTemplateButtonData.localizedDefault(_titleL10n).encode();
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
    _rememberUndoBeforePageMutation(pageId);
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
    _rememberUndoBeforePageMutation(pageId);
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
    _rememberUndoBeforePageMutation(pageId);
    page.blocks.insertAll(i + 1, blocks);
    notifyListeners();
    scheduleSave(trackRevisionForPageId: pageId);
  }

  /// Pega bloques Markdown en la posición del caret de forma atómica (un único
  /// punto de deshacer). El texto del bloque actual se trunca a [textBefore];
  /// los [pastedBlocks] se insertan a continuación y, si [textAfter] no está
  /// vacío, se añade un párrafo adicional con ese texto al final.
  void pasteMarkdownBlocksAtCaret({
    required String pageId,
    required String blockId,
    required String textBefore,
    required List<FolioBlock> pastedBlocks,
    required String textAfter,
  }) {
    if (pastedBlocks.isEmpty && textAfter.isEmpty) return;
    final page = _pageById(pageId);
    if (page == null) return;
    final i = page.blocks.indexWhere((b) => b.id == blockId);
    if (i < 0) return;
    _rememberUndoBeforePageMutation(pageId);
    page.blocks[i].text = textBefore;
    final toInsert = <FolioBlock>[...pastedBlocks];
    if (textAfter.isNotEmpty) {
      toInsert.add(
        FolioBlock(
          id: '${pageId}_${_uuid.v4()}',
          type: 'paragraph',
          text: textAfter,
        ),
      );
    }
    page.blocks.insertAll(i + 1, toInsert);
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
            appearance: b.appearance,
            meetingNoteProvider: b.meetingNoteProvider,
            meetingNoteTranscriptionEnabled: b.meetingNoteTranscriptionEnabled,
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
    _rememberUndoBeforePageMutation(pageId);
    final newId = _uuid.v4();
    _pages.add(
      FolioPage(
        id: newId,
        title: _titleL10n.subpage,
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
    _rememberUndoBeforePageMutation(pageId);
    page.blocks.add(block);
    notifyListeners();
    scheduleSave(trackRevisionForPageId: pageId);
  }

  /// Añade un bloque `task` y devuelve su id, o cadena vacía si falla.
  String appendTaskBlockReturningId({
    required String pageId,
    required FolioTaskData task,
  }) {
    final page = _pageById(pageId);
    if (page == null) return '';
    final bid = '${pageId}_${_uuid.v4()}';
    _rememberUndoBeforePageMutation(pageId);
    page.blocks.add(FolioBlock(id: bid, type: 'task', text: task.encode()));
    notifyListeners();
    scheduleSave(trackRevisionForPageId: pageId);
    return bid;
  }

  /// Crea una página raíz pensada como bandeja de tareas (emoji bandeja de entrada).
  String createTaskInboxPage({required String title}) {
    final id = _uuid.v4();
    _pages.add(
      FolioPage(
        id: id,
        title: title,
        parentId: null,
        emoji: '📥',
        blocks: [FolioBlock(id: '${id}_b0', type: 'paragraph', text: '')],
      ),
    );
    _pageOrderByParent
        .putIfAbsent(_orderKeyForParent(null), () => <String>[])
        .add(id);
    notifyListeners();
    scheduleSave(trackRevisionForPageId: id);
    return id;
  }

  /// Lista bloques `task` y opcionalmente `todo`.
  ///
  /// Si [pageId] no es null, solo se considera esa página (si existe).
  List<VaultTaskListEntry> collectTaskBlocks({
    bool includeSimpleTodos = true,
    String? pageId,
  }) {
    if (_state != VaultFlowState.unlocked) return const [];
    final out = <VaultTaskListEntry>[];
    final pages = pageId == null
        ? _pages
        : () {
            final p = _pageById(pageId);
            return p == null ? const <FolioPage>[] : <FolioPage>[p];
          }();
    for (final page in pages) {
      final pageTitle = page.title.trim().isEmpty
          ? _titleL10n.untitled
          : page.title;
      for (final block in page.blocks) {
        if (block.type == 'task') {
          final task = FolioTaskData.tryParse(block.text);
          if (task == null) continue;
          out.add(
            VaultTaskListEntry(
              pageId: page.id,
              pageTitle: pageTitle,
              blockId: block.id,
              blockType: 'task',
              task: task,
            ),
          );
        } else if (includeSimpleTodos && block.type == 'todo') {
          out.add(
            VaultTaskListEntry(
              pageId: page.id,
              pageTitle: pageTitle,
              blockId: block.id,
              blockType: 'todo',
              todoChecked: block.checked,
              todoText: block.text,
            ),
          );
        }
      }
    }
    return out;
  }

  void setTaskBlockDone(String pageId, String blockId, {required bool done}) {
    final page = _pageById(pageId);
    if (page == null) return;
    final b = _blockById(page, blockId);
    if (b == null) return;
    _rememberUndoBeforePageMutation(pageId);
    if (b.type == 'todo') {
      b.checked = done;
    } else if (b.type == 'task') {
      final t = FolioTaskData.tryParse(b.text) ?? FolioTaskData.defaults();
      b.text = t.copyWith(status: done ? 'done' : 'todo').encode();
    } else {
      return;
    }
    notifyListeners();
    scheduleSave(trackRevisionForPageId: pageId);
  }

  /// Persiste la configuración del bloque `drive` de una página.
  void setPageDriveData(
    String pageId,
    String blockId,
    FolioFileDriveData data,
  ) {
    final page = _pageById(pageId);
    if (page == null) return;
    final b = _blockById(page, blockId);
    if (b == null || b.type != 'drive') return;
    _rememberUndoBeforePageMutation(pageId);
    b.text = data.encode();
    notifyListeners();
    scheduleSave(trackRevisionForPageId: pageId);
  }

  /// Actualiza el estado de una tarjeta `task` o `todo` para columnas Kanban.
  void setVaultTaskEntryKanbanStatus(
    String pageId,
    String blockId,
    String status,
  ) {
    final page = _pageById(pageId);
    if (page == null) return;
    final b = _blockById(page, blockId);
    if (b == null) return;
    _rememberUndoBeforePageMutation(pageId);
    if (b.type == 'todo') {
      b.checked = status == 'done';
    } else if (b.type == 'task') {
      final t = FolioTaskData.tryParse(b.text) ?? FolioTaskData.defaults();
      final next = t.copyWith(status: status, columnId: status);
      b.text = _markTaskNeedsPushIfJiraLinked(next).encode();
    } else {
      return;
    }
    notifyListeners();
    scheduleSave(trackRevisionForPageId: pageId);
  }

  FolioTaskData _markTaskNeedsPushIfJiraLinked(FolioTaskData t) {
    final ext = t.external;
    if (ext == null || ext.provider != 'jira') return t;
    final cur = (ext.syncState ?? '').trim();
    if (cur == 'conflict') return t;
    return t.copyWith(external: ext.copyWith(syncState: 'needsPush'));
  }

  /// Mueve una tarjeta `task` a una columna Kanban (dinámica).
  void setTaskBlockColumnId(String pageId, String blockId, String columnId) {
    final page = _pageById(pageId);
    if (page == null) return;
    final b = _blockById(page, blockId);
    if (b == null || b.type != 'task') return;
    _rememberUndoBeforePageMutation(pageId);
    final t = FolioTaskData.tryParse(b.text) ?? FolioTaskData.defaults();
    final normalized = columnId.trim();
    final nextStatus =
        (normalized == 'todo' ||
            normalized == 'in_progress' ||
            normalized == 'done')
        ? normalized
        : null;
    final next = t.copyWith(
      columnId: normalized.isEmpty ? null : normalized,
      status: nextStatus ?? t.status,
    );
    b.text = _markTaskNeedsPushIfJiraLinked(next).encode();
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
    _rememberUndoBeforePageMutation(pageId);
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
      appearance: nextType == cur.type ? cur.appearance : null,
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
    _rememberUndoBeforePageMutation(pageId);
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
    _rememberUndoBeforePageMutation(pageId);
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
      _rememberUndoBeforePageMutation(pageId);
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
      _rememberUndoBeforePageMutation(pageId);
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
    _rememberUndoBeforePageMutation(pageId);
    final b = page.blocks.removeAt(oldIndex);
    page.blocks.insert(insertAt, b);
    notifyListeners();
    scheduleSave(trackRevisionForPageId: pageId);
  }

  /// Mueve un bloque a otra página. Regenera el id del bloque y limpia
  /// [FolioTaskData.parentTaskId] / dependencias al cruzar de página.
  void moveBlockToPage({
    required String fromPageId,
    required String toPageId,
    required String blockId,
  }) {
    if (fromPageId == toPageId) return;
    final from = _pageById(fromPageId);
    final to = _pageById(toPageId);
    if (from == null || to == null) return;
    if (from.blocks.length <= 1) return;
    final i = from.blocks.indexWhere((b) => b.id == blockId);
    if (i < 0) return;
    final b = from.blocks[i];
    _rememberUndoBeforePageMutation(fromPageId);
    _rememberUndoBeforePageMutation(toPageId);
    from.blocks.removeAt(i);

    final newId = _newBlockId(toPageId);
    var payload = b.text;
    if (b.type == 'task') {
      final t = FolioTaskData.tryParse(b.text) ?? FolioTaskData.defaults();
      payload = t
          .copyWith(
            parentTaskId: null,
            blockedByTaskIds: const [],
          )
          .encode();
    }

    final moved = FolioBlock(
      id: newId,
      type: b.type,
      text: payload,
      richTextDeltaJson: b.richTextDeltaJson,
      checked: b.checked,
      expanded: b.expanded,
      codeLanguage: b.codeLanguage,
      depth: 0,
      icon: b.icon,
      url: b.url,
      imageWidth: b.imageWidth,
      appearance: b.appearance,
      meetingNoteProvider: b.meetingNoteProvider,
      meetingNoteTranscriptionEnabled: b.meetingNoteTranscriptionEnabled,
      syncGroupId: b.syncGroupId,
    );
    to.blocks.add(moved);
    notifyListeners();
    scheduleSave(trackRevisionForPageId: fromPageId);
    scheduleSave(trackRevisionForPageId: toPageId);
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
    _rememberUndoBeforePageMutation(pageId);
    page.blocks.removeWhere((b) => b.id == blockId);
    notifyListeners();
    scheduleSave(trackRevisionForPageId: pageId);
  }

  /// Elimina varios bloques en una sola mutacion (un unico punto de deshacer).
  /// Nunca deja la pagina vacia: como maximo borra [N - 1] bloques.
  void removeBlocksIfMultiple(String pageId, List<String> blockIds) {
    if (blockIds.isEmpty) return;
    final page = _pageById(pageId);
    if (page == null || page.blocks.length <= 1) return;

    final requested = blockIds.toSet();
    final existing = page.blocks
        .where((b) => requested.contains(b.id))
        .toList();
    if (existing.isEmpty) return;

    final maxDeletable = page.blocks.length - 1;
    final victims = existing.take(maxDeletable).toList();
    if (victims.isEmpty) return;
    final victimIds = victims.map((b) => b.id).toSet();

    for (final victim in victims) {
      if (victim.type == 'image' && victim.text.isNotEmpty) {
        _deleteManagedAttachmentIfUnused(
          victim.text,
          excludingPageId: pageId,
          excludingBlockId: victim.id,
        );
      }
      if ((victim.type == 'file' || victim.type == 'video') &&
          _isManagedAttachmentPath(victim.url)) {
        _deleteManagedAttachmentIfUnused(
          victim.url!,
          excludingPageId: pageId,
          excludingBlockId: victim.id,
        );
      }
    }

    _rememberUndoBeforePageMutation(pageId);
    page.blocks.removeWhere((b) => victimIds.contains(b.id));
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
    var persisted = false;
    _persistDepth++;
    if (_persistDepth == 1) {
      notifyListeners();
    }
    try {
      await _repo.savePayload(
        VaultPayload(
          version: kVaultPayloadVersion,
          pages: _pages,
          pageOrderByParent: _pageOrderByParent,
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
          pageTemplates: List<FolioPageTemplate>.from(_pageTemplates),
          jira: _jira,
        ),
        _dek,
      );
      persisted = true;
    } finally {
      _persistDepth--;
      if (_persistDepth == 0) {
        notifyListeners();
      }
    }
    if (persisted && _suppressPersistedCallbackDepth == 0) {
      try {
        onPersisted?.call();
      } catch (_) {
        // No bloquea el guardado local si falla un listener externo.
      }
    }
  }

  Future<List<int>?> exportSyncSnapshotBytes() async {
    if (_state != VaultFlowState.unlocked) return null;
    if (vaultUsesEncryption && _dek == null) return null;
    final payload = VaultPayload(
      version: kVaultPayloadVersion,
      pages: _pages,
      pageOrderByParent: _pageOrderByParent,
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
      pageTemplates: List<FolioPageTemplate>.from(_pageTemplates),
      jira: _jira,
    );
    return payload.encodeUtf8();
  }

  Future<bool> applySyncSnapshotBytes(
    List<int> rawBytes, [
    String fromPeerId = '',
  ]) async {
    if (_state != VaultFlowState.unlocked) return false;
    if (vaultUsesEncryption && _dek == null) return false;
    try {
      final localSnapshot = await exportSyncSnapshotBytes();
      if (localSnapshot == null) return false;
      final localFingerprint = _syncFingerprintBytes(localSnapshot);
      final remoteFingerprint = _syncFingerprintBytes(rawBytes);
      if (localFingerprint == remoteFingerprint) {
        if (_syncBaselineFingerprint.isEmpty) {
          _syncBaselineFingerprint = localFingerprint;
        }
        // Snapshot idéntico: confirmamos sync sin tocar estado ni persistir.
        return true;
      }

      if (_syncBaselineFingerprint.isEmpty) {
        _syncBaselineFingerprint = localFingerprint;
      }

      final localChanged = localFingerprint != _syncBaselineFingerprint;
      final remoteChanged = remoteFingerprint != _syncBaselineFingerprint;

      if (localChanged && remoteChanged) {
        _registerSyncConflict(
          fromPeerId: fromPeerId,
          remoteFingerprint: remoteFingerprint,
          remoteSnapshotBytes: rawBytes,
        );
        // Conflicto concurrente: prioriza no sobrescribir el estado local.
        return true;
      }

      if (localChanged && !remoteChanged) {
        // El remoto está atrasado respecto a lo local; conservar local evita rollback.
        return true;
      }

      final payload = VaultPayload.decodeUtf8(rawBytes);
      await _applyResolvedSyncPayload(
        payload,
        remoteFingerprint: remoteFingerprint,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> resolveSyncConflictKeepLocal(String conflictId) async {
    final index = _syncConflicts.indexWhere((entry) => entry.id == conflictId);
    if (index == -1) return;
    _syncConflicts.removeAt(index);
    final localSnapshot = await exportSyncSnapshotBytes();
    if (localSnapshot != null) {
      _syncBaselineFingerprint = _syncFingerprintBytes(localSnapshot);
    }
    _notifySyncConflictCountChanged();
    notifyListeners();
  }

  Future<bool> resolveSyncConflictAcceptRemote(String conflictId) async {
    final index = _syncConflicts.indexWhere((entry) => entry.id == conflictId);
    if (index == -1) return false;
    final entry = _syncConflicts[index];
    try {
      final payload = VaultPayload.decodeUtf8(entry.remoteSnapshotBytes);
      await _applyResolvedSyncPayload(
        payload,
        remoteFingerprint: entry.remoteFingerprint,
      );
      _syncConflicts.removeAt(index);
      _notifySyncConflictCountChanged();
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  void _registerSyncConflict({
    required String fromPeerId,
    required String remoteFingerprint,
    required List<int> remoteSnapshotBytes,
  }) {
    final existing = _syncConflicts.any(
      (entry) =>
          entry.fromPeerId == fromPeerId &&
          entry.remoteFingerprint == remoteFingerprint,
    );
    if (existing) return;
    var remotePageCount = 0;
    try {
      remotePageCount = VaultPayload.decodeUtf8(
        remoteSnapshotBytes,
      ).pages.length;
    } catch (_) {
      remotePageCount = 0;
    }
    _syncConflicts.add(
      SyncConflictEntry(
        id: _uuid.v4(),
        fromPeerId: fromPeerId,
        createdAtMs: DateTime.now().millisecondsSinceEpoch,
        remoteFingerprint: remoteFingerprint,
        remoteSnapshotBytes: List<int>.from(remoteSnapshotBytes),
        remotePageCount: remotePageCount,
      ),
    );
    _notifySyncConflictCountChanged();
    notifyListeners();
  }

  Future<void> _applyResolvedSyncPayload(
    VaultPayload payload, {
    required String remoteFingerprint,
  }) async {
    final previousSelectedPageId = _selectedPageId;
    _pages = List<FolioPage>.from(payload.pages);
    _comments = List<LocalPageComment>.from(payload.comments);
    _loadRevisionsFromPayload(payload);
    _ensureOrderForCurrentPages();
    final canKeepSelection =
        previousSelectedPageId != null &&
        _pages.any((p) => p.id == previousSelectedPageId);
    if (canKeepSelection) {
      _selectedPageId = previousSelectedPageId;
    } else {
      _pickInitialSelection();
      _contentEpoch++;
    }
    notifyListeners();
    _suppressPersistedCallbackDepth++;
    try {
      await persistNow();
    } finally {
      _suppressPersistedCallbackDepth--;
    }
    _syncBaselineFingerprint = remoteFingerprint;
  }

  void _notifySyncConflictCountChanged() {
    _syncPendingConflicts = _syncConflicts.length;
    try {
      onSyncConflictCountChanged?.call(_syncPendingConflicts);
    } catch (_) {
      // No bloquea flujo si falla la notificación externa.
    }
  }

  String _syncFingerprintBytes(List<int> data) {
    // FNV-1a 32-bit for lightweight snapshot change detection (JS-safe).
    var hash = 0x811c9dc5;
    const prime = 0x01000193;
    const mask = 0xffffffff;
    for (final b in data) {
      hash ^= b;
      hash = (hash * prime) & mask;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  bool _dekMatchesQuickStorage(Uint8List dek) {
    if (!vaultUsesEncryption || _dek == null) return false;
    return const ListEquality<int>().equals(dek, _dek!);
  }

  /// Comprueba la contraseña contra la libreta y que coincida con la sesión abierta.
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
      throw StateError('Libreta no desbloqueada');
    }
    touchActivity();
    final vid = _vaultId;
    if (vid == null) {
      throw StateError('No hay libreta activa');
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
      localizedReason: 'Confirma tu identidad para borrar la libreta',
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
      throw StateError('Libreta no desbloqueada');
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
      throw StateError('No hay libreta activa');
    }
    final dek = await _quick.readDek(vid);
    if (dek == null || !_dekMatchesQuickStorage(dek)) {
      throw StateError('No coincide la clave tras la passkey');
    }
  }

  /// Borra la libreta **activa** por completo y actualiza el registro.
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
          AiChatThreadData(
            id: 'chat_0',
            title: _titleL10n.aiChatTitleNumbered(1),
            messages: const [],
          ),
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
        AiChatThreadData(
          id: 'chat_0',
          title: _titleL10n.aiChatTitleNumbered(1),
          messages: const [],
        ),
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
      throw StateError('Esta libreta no usa contraseña');
    }
    if (_dek == null) {
      throw StateError('Libreta no desbloqueada');
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

  /// Cifra una libreta que estaba solo en disco en texto plano. La sesión sigue abierta.
  Future<void> enableVaultEncryption(String password) async {
    if (_state != VaultFlowState.unlocked) {
      throw StateError('Libreta no desbloqueada');
    }
    if (vaultUsesEncryption) {
      throw StateError('La libreta ya está cifrada');
    }
    if (!(await _repo.isPlaintextVault())) {
      throw StateError('Libreta no reconocida como texto plano');
    }
    if (password.isEmpty) {
      throw ArgumentError('Contraseña vacía');
    }

    final payload = VaultPayload(
      version: kVaultPayloadVersion,
      pages: _pages,
      pageOrderByParent: _pageOrderByParent,
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

  List<VaultSearchResult> searchGlobal(
    String query, {
    int limit = 80,
    bool includeTitleMatches = true,
    bool includeContentMatches = true,
    bool sortByRecency = false,
    bool tasksOnly = false,
  }) {
    final q = query.trim().toLowerCase();
    if (_state != VaultFlowState.unlocked ||
        (vaultUsesEncryption && _dek == null) ||
        q.isEmpty ||
        (!includeTitleMatches && !includeContentMatches)) {
      return const [];
    }
    touchActivity();
    final out = <VaultSearchResult>[];
    for (final page in _pages) {
      final pageTitle = page.title.trim().isEmpty ? 'Sin título' : page.title;
      final pageLastEditedMs = _pageLastEditedMs(page.id);
      final titleLower = pageTitle.toLowerCase();
      if (includeTitleMatches && titleLower.contains(q)) {
        final startsAt = titleLower.indexOf(q);
        final titleScore =
            220 - (startsAt.clamp(0, 200)) + (pageTitle.length <= 42 ? 15 : 0);
        out.add(
          VaultSearchResult(
            pageId: page.id,
            pageTitle: pageTitle,
            snippet: _snippetAround(pageTitle, q),
            matchKind: VaultSearchMatchKind.title,
            pageLastEditedMs: pageLastEditedMs,
            score: titleScore,
          ),
        );
      }
      if (includeContentMatches) {
        for (final block in page.blocks) {
          if (tasksOnly && block.type != 'todo' && block.type != 'task') {
            continue;
          }
          final haystack = _blockSearchText(block);
          final haystackLower = haystack.toLowerCase();
          final idx = haystackLower.indexOf(q);
          if (idx < 0) continue;
          final snippet = _snippetAround(haystack, q);
          final contentScore =
              120 - (idx.clamp(0, 100)) + (snippet.length <= 88 ? 8 : 0);
          out.add(
            VaultSearchResult(
              pageId: page.id,
              pageTitle: pageTitle,
              blockId: block.id,
              snippet: snippet,
              matchKind: VaultSearchMatchKind.content,
              pageLastEditedMs: pageLastEditedMs,
              score: contentScore,
            ),
          );
        }
      }
    }
    out.sort((a, b) {
      if (sortByRecency) {
        final byRecency = b.pageLastEditedMs.compareTo(a.pageLastEditedMs);
        if (byRecency != 0) return byRecency;
      }
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      return a.pageTitle.toLowerCase().compareTo(b.pageTitle.toLowerCase());
    });
    if (out.length <= limit) return out;
    return out.take(limit).toList(growable: false);
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
            appearance: b.appearance,
            meetingNoteProvider: b.meetingNoteProvider,
            meetingNoteTranscriptionEnabled: b.meetingNoteTranscriptionEnabled,
          ),
        )
        .toList();
    _pages.add(
      FolioPage(
        id: id,
        title: _titleL10n.defaultPageDuplicateTitle(src.title),
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

  int _pageLastEditedMs(String pageId) {
    final list = _pageRevisions[pageId];
    if (list == null || list.isEmpty) return 0;
    var latest = 0;
    for (final rev in list) {
      if (rev.savedAtMs > latest) latest = rev.savedAtMs;
    }
    return latest;
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

  /// Selección por defecto sin leer preferencias (p. ej. tras borrar página).
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
