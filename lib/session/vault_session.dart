import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

import '../application/page_tree_controller.dart';
import '../application/vault_ai_controller.dart';
import '../application/vault_persistence_controller.dart';
import '../application/vault_search_index.dart';
import '../core/errors/vault_corruption_exception.dart';
import '../crypto/vault_crypto.dart';
import '../data/vault_backup.dart';
import '../data/notion_import/notion_importer.dart';
import '../data/import/simple_html_blocks.dart';
import '../app/workspace_prefs_keys.dart';
import '../data/vault_paths.dart';
import '../data/vault_payload.dart';
import '../data/vault_registry.dart';
import '../data/vault_repository.dart';
import '../data/storage/vault_storage.dart';
import '../models/block.dart';
import '../models/folio_page.dart';
import '../models/folio_usage_intent.dart';
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
import '../models/youtrack_integration_state.dart';
import '../models/trello_integration_state.dart';
import '../models/github_integration_state.dart';
import '../models/gitlab_integration_state.dart';
import '../models/slack_integration_state.dart';
import '../models/teams_integration_state.dart';
import '../models/spotify_integration_state.dart';
import '../models/system_media_integration_state.dart';
import '../models/discord_integration_state.dart';
import '../services/integrations/integration_notification_dispatcher.dart';
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
import '../services/ai/ai_app_question_detector.dart';
import '../services/ai/ai_tool_json_emulation.dart';
import '../services/ai/ai_tool_loop.dart';
import '../services/ai/ai_types.dart';
import '../services/ai/folio_docs_grounding_loader.dart';
import '../services/ai/folio_tool_registry.dart';
import '../services/ai/json_lenient_decoder.dart';
import '../services/ai/quill_tools.dart';
import '../services/integrations/integrations_markdown_codec.dart';
import '../services/app_logger.dart';
import '../services/meeting_note_session_controller.dart';
import '../services/quick_unlock_storage.dart';
import '../services/unlock_attempt_throttle.dart';
import '../services/folio_cloud/device_sync_key_cache.dart';
import '../services/sync/sync_conflict_entry.dart';
import '../services/sync/sync_conflict_store.dart';
import '../services/sync/vault_sync_merge.dart';
import '../services/sync/vault_sync_pack.dart';
import '../l10n/generated/app_localizations.dart';
import 'workspace_navigation_history.dart';
// M5: Format handler
import '../git/vault_format_handler.dart';
import '../git/vault_snapshot.dart';
import '../git/vault_snapshot_manager.dart';
import '../data/vault_local_storage.dart';
import '../git/vault_migration_tool.dart';
import '../git/vault_integrity.dart';
import '../git/version_info.dart';

export '../services/sync/sync_conflict_entry.dart' show SyncConflictEntry;

part 'vault_session_ai.dart';

enum VaultFlowState {
  initializing,
  needsOnboarding,
  locked,
  unlocked,
  recovery,
}

enum VaultSearchMatchKind { title, content }

class VaultSearchResult {
  const VaultSearchResult({
    required this.pageId,
    required this.pageTitle,
    required this.snippet,
    required this.matchKind,
    this.blockId,
    this.blockType,
    this.pageLastEditedMs = 0,
    this.score = 0,
  });

  final String pageId;
  final String pageTitle;
  final String snippet;
  final VaultSearchMatchKind matchKind;
  final String? blockId;
  final String? blockType;
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
    final active = _pages.where((p) => !p.isTrashed).toList();
    if (active.isEmpty) {
      _selectedPageId = null;
      _navigationHistory.seed(null);
      return;
    }
    if (preferPersistedPreference) {
      final p = await SharedPreferences.getInstance();
      if (p.getBool(WorkspacePrefsKeys.openWorkspaceToHome) ?? false) {
        _selectedPageId = null;
        _navigationHistory.seed(null);
        return;
      }
      final key = _lastSelectedPagePrefsKey(VaultPaths.activeVaultId);
      if (key != null) {
        final saved = p.getString(key);
        if (saved != null &&
            saved.isNotEmpty &&
            active.any((pg) => pg.id == saved)) {
          _selectedPageId = saved;
          _navigationHistory.seed(saved);
          return;
        }
      }
    }
    final roots = active.where((p) => p.parentId == null).toList();
    _selectedPageId = roots.isNotEmpty ? roots.first.id : active.first.id;
    _navigationHistory.seed(_selectedPageId);
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
    _persistence = VaultPersistenceController(
      buildPayload: _buildVaultPayloadForPersist,
      savePayload: (payload) => _repo.savePayload(payload, _dek),
      canPersist: () =>
          _state == VaultFlowState.unlocked &&
          (!vaultUsesEncryption || _dek != null),
    );
    _persistence.addListener(_notifySessionListeners);
    _persistence.onPersisted = () {
      try {
        onPersisted?.call();
      } catch (_) {}
    };
    _pageTree = PageTreeController(
      pagesProvider: () => _pages,
      orderProvider: () => _pageOrderByParent,
      orderUpdater: (order) {
        _pageOrderByParent
          ..clear()
          ..addAll(order);
      },
      selectedIdProvider: () => _selectedPageId,
      selectedIdUpdater: (id) => _selectedPageId = id,
    );
    _aiController = VaultAiController()..initializeThreads(_aiChatThreads);
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
  /// Antes de abandonar la libreta activa (p. ej. `switchVault`), aún desbloqueada.
  Future<void> Function()? onBeforeLeaveVault;
  /// Antes de cambiar de página seleccionada (había otra página abierta).
  Future<void> Function()? onBeforeLeavePage;
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
  YouTrackIntegrationState _youtrack = YouTrackIntegrationState.empty;
  TrelloIntegrationState _trello = TrelloIntegrationState.empty;
  GitHubIntegrationState _github = GitHubIntegrationState.empty;
  GitLabIntegrationState _gitlab = GitLabIntegrationState.empty;
  SlackIntegrationState _slack = SlackIntegrationState.empty;
  TeamsIntegrationState _teams = TeamsIntegrationState.empty;
  SpotifyIntegrationState _spotify = SpotifyIntegrationState.empty;
  DiscordIntegrationState _discord = DiscordIntegrationState.empty;
  SystemMediaIntegrationState _systemMedia = SystemMediaIntegrationState.empty;
  final IntegrationNotificationDispatcher _notificationDispatcher =
      IntegrationNotificationDispatcher();
  String? _selectedPageId;
  final WorkspaceNavigationHistory _navigationHistory =
      WorkspaceNavigationHistory();
  bool _applyingHistoryNavigation = false;
  Timer? _revisionIdleTimer;
  Timer? _v1TreeSaveTimer;
  /// Mutex de escritura para `persistNow` en formato v1 (no había ninguno,
  /// a diferencia de `VaultPersistenceController._activeWrite` en v0). Sin
  /// esto, una llamada "suelta" (disparada por el debounce y no esperada por
  /// nadie, `unawaited`) puede seguir en vuelo mientras `lock()`/`switchVault`
  /// cambian la libreta activa — cuando esa llamada suelta por fin resuelve
  /// el directorio destino, puede resolver al de la libreta *nueva* y
  /// escribir ahí el contenido de la libreta vieja (contaminación cruzada
  /// real, visto en producción). El mutex obliga a que cualquier llamador
  /// (incluida la suelta) espere su turno antes de que `lock()` pueda
  /// terminar, así que `switchVault` nunca cambia de libreta activa mientras
  /// quede un guardado v1 pendiente de verdad en vuelo.
  Future<void>? _v1ActiveWrite;
  Timer? _idleLockTimer;
  final Set<String> _pageIdsPendingRevision = {};
  /// Soft-hide de snapshots por página: pageId → set de snapshotIds ocultos.
  final Map<String, Set<String>> _hiddenVersionsByPage = {};
  bool _hiddenVersionsLoaded = false;
  late final VaultPersistenceController _persistence;
  final VaultSearchIndex _searchIndex = VaultSearchIndex();
  late final PageTreeController _pageTree;
  late final VaultAiController _aiController;
  String _syncBaselineFingerprint = '';
  VaultPayload? _syncBaselinePayload;
  int _syncPendingConflicts = 0;
  final List<SyncConflictEntry> _syncConflicts = [];
  final SyncConflictStore _conflictStore = SyncConflictStore();
  final Map<String, int> _pageTombstones = {};
  final Set<String> _mcpReadablePageIds = {};
  int _syncClock = 0;
  static const VaultSyncMergeEngine _syncMerge = VaultSyncMergeEngine();
  Duration _idleLockDuration = const Duration(minutes: 15);
  bool _lockOnAppBackground = false;
  bool _vaultUsesEncryption = true;

  // M5: Dual format v0/v1 support
  late VaultFormatHandler _formatHandler;
  int _vaultFormatVersion = 0; // 0=legacy, 1=tree
  late VaultSnapshotManager _snapshotManager;
  String _deviceId = 'unknown-device';
  bool _justMigrated = false; // Marks if v0→v1 migration just happened
  bool _hasV0FilesToDelete = false; // vault.bin still on disk after migrating
  bool _formatHandlerInitialized = false; // Guards lazy init of the fields above

  /// Tras "Añadir libreta", se restaura al cancelar onboarding.
  String? _resumeVaultIdAfterNewVault;

  final VaultRegistry _registry = VaultRegistry.instance;

  String? get activeVaultId => VaultPaths.activeVaultId;

  bool get canCancelNewVaultOnboarding => _resumeVaultIdAfterNewVault != null;

  Future<List<VaultEntry>> listVaultEntries() async {
    await _registry.load();
    return _registry.vaults;
  }

  Future<bool> containsVault(String vaultId) async {
    await _registry.load();
    return _registry.containsVault(vaultId);
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

  /// M5: Get vault format version (0=legacy, 1=tree)
  int get vaultFormatVersion => _vaultFormatVersion;

  /// M5: Check if vault was just migrated (for UI notification)
  bool get justMigrated => _justMigrated;

  /// M5: Check if the legacy vault.bin is still on disk after migrating
  /// (only true if there's actually something to clean up).
  bool get hasV0FilesToDelete => _hasV0FilesToDelete;

  /// M5: Reset migration flag after showing notification
  void resetMigrationFlag() {
    _justMigrated = false;
    _hasV0FilesToDelete = false;
  }

  /// M5: Tras una sincronización (nube o P2P) que subió con éxito la libreta
  /// ya en v1 **y** con marker `vault.v1-verified`, borra el `vault.bin` legacy
  /// si sigue en disco. Nunca se borra en el mismo turno que la migración.
  /// Sobrevive a reinicios: no depende solo del flag en memoria.
  Future<void> cleanupV0AfterSuccessfulSync() async {
    if (_vaultFormatVersion != 1) return;
    final binExists = await VaultPaths.cipherPayloadExists();
    if (!binExists) {
      if (_hasV0FilesToDelete) resetMigrationFlag();
      return;
    }
    if (!await VaultMigrationTool.isV1Verified()) {
      AppLogger.info(
        'v0 vault.bin conservado: v1 aún no verificado en disco',
      );
      return;
    }
    final deleted = await deleteV0VaultBinary();
    if (deleted) {
      AppLogger.info('v0 vault.bin eliminado tras sync exitoso de v1');
      resetMigrationFlag();
    }
  }

  /// M5: Delete legacy v0 vault.bin after successful migration
  Future<bool> deleteV0VaultBinary() async {
    try {
      final vaultId = _vaultId;
      if (vaultId == null || vaultId.isEmpty) {
        AppLogger.error('Cannot delete v0: no active vault ID');
        return false;
      }
      await VaultStorage.instance.deleteVaultFile(vaultId, 'vault.bin');
      final stillExists = await VaultPaths.cipherPayloadExists();
      if (stillExists) {
        AppLogger.warn('vault.bin still exists after delete attempt');
        return false;
      }
      AppLogger.info('Deleted legacy v0 vault.bin');
      return true;
    } catch (e) {
      AppLogger.error('Failed to delete v0 vault.bin: $e');
      return false;
    }
  }

  String? get _vaultId => VaultPaths.activeVaultId;

  /// Tras dejar de editar, se crea una entrada de historial (además del guardado rápido).
  static const Duration _revisionIdleDelay = Duration(milliseconds: 2500);

  /// Debounce del árbol v1 (equivalente al de [_persistence] en v0).
  static const Duration _v1TreeSaveDebounce = Duration(milliseconds: 450);

  /// Hay un guardado al disco programado (debounce) y aún no se ha ejecutado.
  bool get hasPendingDiskSave =>
      _persistence.hasPendingDiskSave || (_v1TreeSaveTimer?.isActive ?? false);

  /// Escritura cifrada de la libreta en curso (puede anidarse si varias rutas llaman a [persistNow]).
  bool get isPersistingToDisk => _persistence.isPersistingToDisk;

  SaveStatus get saveStatus => _persistence.status;

  VaultPersistenceController get persistence => _persistence;

  PageTreeController get pageTree => _pageTree;

  VaultAiController get aiController => _aiController;

  VaultSearchIndex get searchIndex => _searchIndex;

  VaultFlowState get state => _state;
  List<FolioPage> get pages => List.unmodifiable(_pages);
  List<FolioPage> get activePages =>
      List.unmodifiable(_pages.where((p) => !p.isTrashed));
  List<FolioPage> get trashedPages {
    final list = _pages.where((p) => p.isTrashed).toList()
      ..sort((a, b) {
        final at = a.trashedAt!;
        final bt = b.trashedAt!;
        return bt.compareTo(at);
      });
    return List.unmodifiable(list);
  }

  /// Retención de la papelera (purga automática).
  static const Duration trashRetention = Duration(days: 30);

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
      if (page.isTrashed) continue;
      if (page.id == targetPageId) continue;
      var found = false;
      for (final block in page.blocks) {
        if (found) break;
        // Bloques child_page: su `text` es el id de la subpágina enlazada.
        if (block.type == 'child_page' && block.text.trim() == targetPageId) {
          found = true;
          break;
        }
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
  /// Libreta cifrada: usa la DEK en memoria. En claro: derivada del contenido
  /// actual (equivalente a `vault.bin`), sin depender de que ese archivo siga
  /// existiendo en disco (v1 no lo mantiene).
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
    final bytes = await vaultBinEquivalentBytes();
    final h = await Sha256().hash(bytes);
    final h2 = await Sha256().hash(
      Uint8List.fromList(utf8.encode('FolioCloudPackPlainV1') + h.bytes),
    );
    return SecretKey(h2.bytes);
  }

  /// M5: Bytes equivalentes a lo que `vault.bin` contendría para el estado
  /// actual en memoria (payload serializado, cifrado con la DEK si la libreta
  /// usa cifrado). Funciona igual en v0 y v1, y no depende de que el archivo
  /// `vault.bin` siga existiendo en disco (v1 deja de mantenerlo tras migrar).
  /// Usado por todo el pipeline de copias/sync en la nube en vez de leer el
  /// archivo legacy directamente.
  Future<Uint8List> vaultBinEquivalentBytes() async {
    if (!isUnlocked) {
      throw StateError('La libreta debe estar desbloqueada.');
    }
    final payload = _buildVaultPayloadForPersist();
    final plainBytes = Uint8List.fromList(payload.encodeUtf8());
    if (!vaultUsesEncryption) return plainBytes;
    if (_dek == null) {
      throw StateError('La libreta cifrada debe tener la DEK en memoria.');
    }
    final dek = await VaultCrypto.dekFromBytes(_dek!);
    return VaultCrypto.encryptPayload(plain: plainBytes, dek: dek);
  }

  /// Para tests que operan sobre el vault sin pasar por [bootstrap].
  /// [formatVersion] permite ejercitar el camino v1 (árbol) sin migrar de
  /// verdad; por defecto se mantiene v0 para no romper llamadores existentes.
  @visibleForTesting
  void debugMarkUnlockedForTests({int formatVersion = 0}) {
    _state = VaultFlowState.unlocked;
    _vaultUsesEncryption = false;
    _vaultFormatVersion = formatVersion;
  }

  List<AiChatThreadData> get aiChatThreads => List.unmodifiable(_aiChatThreads);
  int get aiActiveChatIndex => _aiActiveChatIndex;
  AiChatThreadData get activeAiChat => _aiChatThreads[_aiActiveChatIndex];
  List<FolioPageTemplate> get pageTemplates =>
      List.unmodifiable(_pageTemplates);
  JiraIntegrationState get jiraIntegrationState => _jira;
  List<JiraConnection> get jiraConnections => _jira.connections;
  List<JiraSource> get jiraSources => _jira.sources;
  YouTrackIntegrationState get youtrackIntegrationState => _youtrack;
  List<YouTrackConnection> get youtrackConnections => _youtrack.connections;
  List<YouTrackSource> get youtrackSources => _youtrack.sources;
  TrelloIntegrationState get trelloIntegrationState => _trello;
  List<TrelloConnection> get trelloConnections => _trello.connections;
  List<TrelloSource> get trelloSources => _trello.sources;
  GitHubIntegrationState get githubIntegrationState => _github;
  List<GitHubConnection> get githubConnections => _github.connections;
  List<GitHubSource> get githubSources => _github.sources;
  GitLabIntegrationState get gitlabIntegrationState => _gitlab;
  List<GitLabConnection> get gitlabConnections => _gitlab.connections;
  List<GitLabSource> get gitlabSources => _gitlab.sources;
  SlackIntegrationState get slackIntegrationState => _slack;
  List<SlackConnection> get slackConnections => _slack.connections;
  TeamsIntegrationState get teamsIntegrationState => _teams;
  List<TeamsConnection> get teamsConnections => _teams.connections;
  SpotifyIntegrationState get spotifyIntegrationState => _spotify;
  List<SpotifyConnection> get spotifyConnections => _spotify.connections;
  DiscordIntegrationState get discordIntegrationState => _discord;
  List<DiscordConnection> get discordConnections => _discord.connections;
  SystemMediaIntegrationState get systemMediaIntegrationState => _systemMedia;
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
      final p = _pages.firstWhere((p) => p.id == _selectedPageId);
      return p.isTrashed ? null : p;
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

    // M5: (Re)detect format for the (possibly new) active vault. Forzamos
    // una detección fresca aquí porque bootstrap() puede correr para una
    // libreta distinta a la de la última vez (p. ej. tras switchVault()).
    _formatHandlerInitialized = false;
    _hiddenVersionsLoaded = false;
    _hiddenVersionsByPage.clear();
    await _ensureFormatHandlerReady();

    final exists = await VaultPaths.vaultExists();
    if (!exists) {
      _vaultUsesEncryption = true;
      _dek = null;
      _pages = [];
      _selectedPageId = null;
      _state = VaultFlowState.needsOnboarding;
    } else {
      bool plain;
      try {
        plain = await _repo.isPlaintextVault();
      } catch (e) {
        AppLogger.error('isPlaintextVault failed: $e');
        _dek = null;
        _pages = [];
        _selectedPageId = null;
        _state = VaultFlowState.recovery;
        notifyListeners();
        return;
      }
      _vaultUsesEncryption = !plain;
      if (plain) {
        try {
          final payload = await _ensureV1AndLoad(() => _repo.loadPayload(null));
          _dek = null;
          _pages = List.from(payload.pages);
          _loadRevisionsFromPayload(payload);
          _ensureOrderForCurrentPages();
          await _applySyncedDisplayName(payload.displayName);
          await _applyInitialPageSelection(preferPersistedPreference: true);
          _state = VaultFlowState.unlocked;
          purgeExpiredTrash();
          _restartIdleLockTimer();

          // M5: Init snapshot manager for v1 (now always)
          await _initSnapshotManager();

          _rebuildSearchIndex();
          final vaultId = _vaultId;
          if (vaultId != null) {
            unawaited(_searchIndex.loadFromVault(vaultId));
          }
        } on VaultCorruptionException {
          _dek = null;
          _pages = [];
          _selectedPageId = null;
          _state = VaultFlowState.recovery;
        } catch (e, st) {
          // Cualquier otro error (p. ej. StateError de vault.bin no
          // encontrado durante la migración) no debe dejar la app colgada
          // en VaultFlowState.initializing.
          AppLogger.error('bootstrap: unexpected error loading vault: $e\n$st');
          _dek = null;
          _pages = [];
          _selectedPageId = null;
          _state = VaultFlowState.recovery;
        }
      } else {
        _state = VaultFlowState.locked;
        _dek = null;
      }
    }
    notifyListeners();
  }

  /// Restaura `vault.bin` desde la copia `.bak` local y reintenta el arranque.
  Future<bool> restoreVaultFromLocalBackup() async {
    final ok = await _repo.restoreCipherPayloadFromLocalBackup();
    if (!ok) return false;
    await bootstrap();
    return _state != VaultFlowState.recovery;
  }

  /// True si hay `vault.bin.pre-migration` (backup previo a migrar a v1).
  Future<bool> hasPreMigrationBackup() =>
      VaultMigrationTool.hasPreMigrationBackup();

  /// Restaura desde `vault.bin.pre-migration` (rollback de migración) y rearranca.
  Future<bool> restoreVaultFromPreMigrationBackup() async {
    final ok = await VaultMigrationTool.rollbackMigration();
    if (!ok) return false;
    _formatHandlerInitialized = false;
    _vaultFormatVersion = 0;
    _hasV0FilesToDelete = false;
    _justMigrated = false;
    await bootstrap();
    return _state != VaultFlowState.recovery;
  }

  /// Carpeta de datos de la libreta activa (nativo).
  Future<String?> activeVaultDataDirectoryPath() async {
    final id = _vaultId;
    if (id == null || id.isEmpty) return null;
    try {
      final dir = await VaultPaths.vaultDirectoryForId(id);
      return dir.path;
    } catch (_) {
      return null;
    }
  }

  /// Exporta una copia ZIP de emergencia de la libreta activa.
  Future<String> exportEmergencyBackupZip(String zipPath) async {
    await flushPendingSave();
    await exportVaultBackup(zipPath);
    return zipPath;
  }

  /// Restaura desde un ZIP de copia sobre la libreta activa (modo recuperación).
  Future<void> restoreFromBackupZip(String zipPath, String password) async {
    if (kIsWeb) throw UnsupportedError('Backup import not available on web');
    final temp = Directory.systemTemp.createTempSync('folio_recovery_import_');
    try {
      await extractBackupZipToDirectory(File(zipPath), temp);
      await validateImportZip(temp, password);
      await applyImportFromDirectory(temp);
      await bootstrap();
    } finally {
      try {
        if (temp.existsSync()) await temp.delete(recursive: true);
      } catch (_) {}
    }
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
    _youtrack = payload.youtrack;
    _trello = payload.trello;
    _github = payload.github;
    _gitlab = payload.gitlab;
    _slack = payload.slack;
    _teams = payload.teams;
    _spotify = payload.spotify;
    _discord = payload.discord;
    _systemMedia = payload.systemMedia;
    _pageTombstones
      ..clear()
      ..addAll(payload.pageTombstones);
    _mcpReadablePageIds
      ..clear()
      ..addAll(payload.mcpReadablePageIds);
    _syncClock = payload.syncClock;
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

  void upsertYouTrackConnection(YouTrackConnection connection) {
    if (_state != VaultFlowState.unlocked) return;
    final next = List<YouTrackConnection>.from(_youtrack.connections);
    final i = next.indexWhere((c) => c.id == connection.id);
    if (i >= 0) {
      next[i] = connection;
    } else {
      next.add(connection);
    }
    _youtrack = YouTrackIntegrationState(
      connections: List.unmodifiable(next),
      sources: _youtrack.sources,
    );
    notifyListeners();
    scheduleSave();
  }

  void removeYouTrackConnection(String connectionId) {
    if (_state != VaultFlowState.unlocked) return;
    final nextConnections = _youtrack.connections
        .where((c) => c.id != connectionId)
        .toList();
    final nextSources = _youtrack.sources
        .where((s) => s.connectionId != connectionId)
        .toList();
    _youtrack = YouTrackIntegrationState(
      connections: List.unmodifiable(nextConnections),
      sources: List.unmodifiable(nextSources),
    );
    notifyListeners();
    scheduleSave();
  }

  void upsertYouTrackSource(YouTrackSource source) {
    if (_state != VaultFlowState.unlocked) return;
    final next = List<YouTrackSource>.from(_youtrack.sources);
    final i = next.indexWhere((s) => s.id == source.id);
    if (i >= 0) {
      next[i] = source;
    } else {
      next.add(source);
    }
    _youtrack = YouTrackIntegrationState(
      connections: _youtrack.connections,
      sources: List.unmodifiable(next),
    );
    notifyListeners();
    scheduleSave();
  }

  void removeYouTrackSource(String sourceId) {
    if (_state != VaultFlowState.unlocked) return;
    final next = _youtrack.sources.where((s) => s.id != sourceId).toList();
    _youtrack = YouTrackIntegrationState(
      connections: _youtrack.connections,
      sources: List.unmodifiable(next),
    );
    notifyListeners();
    scheduleSave();
  }

  void upsertTrelloConnection(TrelloConnection connection) {
    if (_state != VaultFlowState.unlocked) return;
    final next = List<TrelloConnection>.from(_trello.connections);
    final i = next.indexWhere((c) => c.id == connection.id);
    if (i >= 0) {
      next[i] = connection;
    } else {
      next.add(connection);
    }
    _trello = TrelloIntegrationState(
      connections: List.unmodifiable(next),
      sources: _trello.sources,
    );
    notifyListeners();
    scheduleSave();
  }

  void removeTrelloConnection(String connectionId) {
    if (_state != VaultFlowState.unlocked) return;
    final nextConnections = _trello.connections
        .where((c) => c.id != connectionId)
        .toList();
    final nextSources = _trello.sources
        .where((s) => s.connectionId != connectionId)
        .toList();
    _trello = TrelloIntegrationState(
      connections: List.unmodifiable(nextConnections),
      sources: List.unmodifiable(nextSources),
    );
    notifyListeners();
    scheduleSave();
  }

  void upsertTrelloSource(TrelloSource source) {
    if (_state != VaultFlowState.unlocked) return;
    final next = List<TrelloSource>.from(_trello.sources);
    final i = next.indexWhere((s) => s.id == source.id);
    if (i >= 0) {
      next[i] = source;
    } else {
      next.add(source);
    }
    _trello = TrelloIntegrationState(
      connections: _trello.connections,
      sources: List.unmodifiable(next),
    );
    notifyListeners();
    scheduleSave();
  }

  void removeTrelloSource(String sourceId) {
    if (_state != VaultFlowState.unlocked) return;
    final next = _trello.sources.where((s) => s.id != sourceId).toList();
    _trello = TrelloIntegrationState(
      connections: _trello.connections,
      sources: List.unmodifiable(next),
    );
    notifyListeners();
    scheduleSave();
  }

  void upsertGitHubConnection(GitHubConnection connection) {
    if (_state != VaultFlowState.unlocked) return;
    final next = List<GitHubConnection>.from(_github.connections);
    final i = next.indexWhere((c) => c.id == connection.id);
    if (i >= 0) {
      next[i] = connection;
    } else {
      next.add(connection);
    }
    _github = GitHubIntegrationState(
      connections: List.unmodifiable(next),
      sources: _github.sources,
    );
    notifyListeners();
    scheduleSave();
  }

  void removeGitHubConnection(String connectionId) {
    if (_state != VaultFlowState.unlocked) return;
    final nextConnections = _github.connections
        .where((c) => c.id != connectionId)
        .toList();
    final nextSources = _github.sources
        .where((s) => s.connectionId != connectionId)
        .toList();
    _github = GitHubIntegrationState(
      connections: List.unmodifiable(nextConnections),
      sources: List.unmodifiable(nextSources),
    );
    notifyListeners();
    scheduleSave();
  }

  void upsertGitHubSource(GitHubSource source) {
    if (_state != VaultFlowState.unlocked) return;
    final next = List<GitHubSource>.from(_github.sources);
    final i = next.indexWhere((s) => s.id == source.id);
    if (i >= 0) {
      next[i] = source;
    } else {
      next.add(source);
    }
    _github = GitHubIntegrationState(
      connections: _github.connections,
      sources: List.unmodifiable(next),
    );
    notifyListeners();
    scheduleSave();
  }

  void removeGitHubSource(String sourceId) {
    if (_state != VaultFlowState.unlocked) return;
    final next = _github.sources.where((s) => s.id != sourceId).toList();
    _github = GitHubIntegrationState(
      connections: _github.connections,
      sources: List.unmodifiable(next),
    );
    notifyListeners();
    scheduleSave();
  }

  void upsertGitLabConnection(GitLabConnection connection) {
    if (_state != VaultFlowState.unlocked) return;
    final next = List<GitLabConnection>.from(_gitlab.connections);
    final i = next.indexWhere((c) => c.id == connection.id);
    if (i >= 0) {
      next[i] = connection;
    } else {
      next.add(connection);
    }
    _gitlab = GitLabIntegrationState(
      connections: List.unmodifiable(next),
      sources: _gitlab.sources,
    );
    notifyListeners();
    scheduleSave();
  }

  void removeGitLabConnection(String connectionId) {
    if (_state != VaultFlowState.unlocked) return;
    final nextConnections = _gitlab.connections
        .where((c) => c.id != connectionId)
        .toList();
    final nextSources = _gitlab.sources
        .where((s) => s.connectionId != connectionId)
        .toList();
    _gitlab = GitLabIntegrationState(
      connections: List.unmodifiable(nextConnections),
      sources: List.unmodifiable(nextSources),
    );
    notifyListeners();
    scheduleSave();
  }

  void upsertGitLabSource(GitLabSource source) {
    if (_state != VaultFlowState.unlocked) return;
    final next = List<GitLabSource>.from(_gitlab.sources);
    final i = next.indexWhere((s) => s.id == source.id);
    if (i >= 0) {
      next[i] = source;
    } else {
      next.add(source);
    }
    _gitlab = GitLabIntegrationState(
      connections: _gitlab.connections,
      sources: List.unmodifiable(next),
    );
    notifyListeners();
    scheduleSave();
  }

  void removeGitLabSource(String sourceId) {
    if (_state != VaultFlowState.unlocked) return;
    final next = _gitlab.sources.where((s) => s.id != sourceId).toList();
    _gitlab = GitLabIntegrationState(
      connections: _gitlab.connections,
      sources: List.unmodifiable(next),
    );
    notifyListeners();
    scheduleSave();
  }

  void upsertSlackConnection(SlackConnection connection) {
    if (_state != VaultFlowState.unlocked) return;
    final next = List<SlackConnection>.from(_slack.connections);
    final i = next.indexWhere((c) => c.id == connection.id);
    if (i >= 0) {
      next[i] = connection;
    } else {
      next.add(connection);
    }
    _slack = SlackIntegrationState(connections: List.unmodifiable(next));
    notifyListeners();
    scheduleSave();
  }

  void removeSlackConnection(String connectionId) {
    if (_state != VaultFlowState.unlocked) return;
    final next = _slack.connections.where((c) => c.id != connectionId).toList();
    _slack = SlackIntegrationState(connections: List.unmodifiable(next));
    notifyListeners();
    scheduleSave();
  }

  void upsertTeamsConnection(TeamsConnection connection) {
    if (_state != VaultFlowState.unlocked) return;
    final next = List<TeamsConnection>.from(_teams.connections);
    final i = next.indexWhere((c) => c.id == connection.id);
    if (i >= 0) {
      next[i] = connection;
    } else {
      next.add(connection);
    }
    _teams = TeamsIntegrationState(connections: List.unmodifiable(next));
    notifyListeners();
    scheduleSave();
  }

  void removeTeamsConnection(String connectionId) {
    if (_state != VaultFlowState.unlocked) return;
    final next = _teams.connections.where((c) => c.id != connectionId).toList();
    _teams = TeamsIntegrationState(connections: List.unmodifiable(next));
    notifyListeners();
    scheduleSave();
  }

  void upsertSpotifyConnection(SpotifyConnection connection) {
    if (_state != VaultFlowState.unlocked) return;
    final next = List<SpotifyConnection>.from(_spotify.connections);
    final i = next.indexWhere((c) => c.id == connection.id);
    if (i >= 0) {
      next[i] = connection;
    } else {
      next.add(connection);
    }
    _spotify = SpotifyIntegrationState(connections: List.unmodifiable(next));
    notifyListeners();
    scheduleSave();
  }

  void removeSpotifyConnection(String connectionId) {
    if (_state != VaultFlowState.unlocked) return;
    final next =
        _spotify.connections.where((c) => c.id != connectionId).toList();
    _spotify = SpotifyIntegrationState(connections: List.unmodifiable(next));
    notifyListeners();
    scheduleSave();
  }

  void updateSystemMediaIntegration(SystemMediaIntegrationState state) {
    if (_state != VaultFlowState.unlocked) return;
    _systemMedia = state;
    notifyListeners();
    scheduleSave();
  }

  void upsertDiscordConnection(DiscordConnection connection) {
    if (_state != VaultFlowState.unlocked) return;
    final next = List<DiscordConnection>.from(_discord.connections);
    final i = next.indexWhere((c) => c.id == connection.id);
    if (i >= 0) {
      next[i] = connection;
    } else {
      next.add(connection);
    }
    _discord = DiscordIntegrationState(connections: List.unmodifiable(next));
    notifyListeners();
    scheduleSave();
  }

  void removeDiscordConnection(String connectionId) {
    if (_state != VaultFlowState.unlocked) return;
    final next =
        _discord.connections.where((c) => c.id != connectionId).toList();
    _discord = DiscordIntegrationState(connections: List.unmodifiable(next));
    notifyListeners();
    scheduleSave();
  }

  String _orderKeyForParent(String? parentId) => parentId ?? '';

  void _ensureOrderForCurrentPages() {
    _pageTree.ensureOrderForCurrentPages();
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
    List<FolioUsageIntent> usageIntents = const [FolioUsageIntent.notes],
    bool includeQuillStarterPage = false,
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
      usageIntents: usageIntents,
      includeQuillStarterPage: includeQuillStarterPage,
    );
    _vaultUsesEncryption = encrypted;
    _dek = dek?.toList();
    final payload = await _repo.loadPayload(_dek);
    _pages = List.from(payload.pages);
    _loadRevisionsFromPayload(payload);
    _ensureOrderForCurrentPages();
    await _applyInitialPageSelection(preferPersistedPreference: false);
    _state = VaultFlowState.unlocked;
    purgeExpiredTrash();
    _restartIdleLockTimer();
    _resumeVaultIdAfterNewVault = null;

    // M5: las libretas nuevas nacen directamente en v1 (Beta: sin v0 previo
    // que migrar, no tiene sentido crearlas en el formato legacy).
    await _ensureFormatHandlerReady();
    _vaultFormatVersion = 1;
    await _initSnapshotManager();

    notifyListeners();
    await persistNow();
    await VaultMigrationTool.writeTreeFormatVersion(1);
    final fp = VaultIntegrity.fingerprintPages(
      _buildVaultPayloadForPersist(),
    );
    await VaultMigrationTool.writeV1VerifiedMarker(fp);
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
    await VaultPaths.initVaultStorage(newId);
    if (!kIsWeb) {
      await VaultPaths.vaultDirectoryForId(newId);
    }
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
    if (!_registry.containsVault(vaultId)) {
      AppLogger.warn(
        'switchVault: vault not in registry',
        tag: 'vault',
        context: {'vaultId': vaultId},
      );
      return;
    }
    AppLogger.info(
      'switchVault',
      tag: 'vault',
      context: {'vaultId': vaultId, 'from': _vaultId},
    );
    final leavingId = _vaultId;
    if (leavingId != null &&
        leavingId.isNotEmpty &&
        leavingId != vaultId &&
        _state == VaultFlowState.unlocked) {
      try {
        await onBeforeLeaveVault?.call();
      } catch (e, st) {
        AppLogger.warn(
          'onBeforeLeaveVault failed; continuing switch',
          tag: 'vault',
          context: {'vaultId': leavingId, 'error': '$e', 'stack': '$st'},
        );
      }
    }
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
    // Persistir en el payload para que el sync multi-dispositivo propague el nombre.
    scheduleSave();
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
    await exportVaultZip(
      File(zipPath),
      vaultBinBytes: await vaultBinEquivalentBytes(),
    );
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
      return importVaultBackupAsNewFromExtractedDir(
        temp,
        backupPassword,
        displayName: displayName,
        deleteExtractedDir: false,
      );
    } finally {
      try {
        if (temp.existsSync()) {
          await temp.delete(recursive: true);
        }
      } catch (_) {}
    }
  }

  /// Como [importVaultBackupAsNew] pero el árbol de copia ya está materializado
  /// (p. ej. pack incremental local/WebDAV).
  Future<String> importVaultBackupAsNewFromExtractedDir(
    Directory extractedDir,
    String backupPassword, {
    String? displayName,
    bool deleteExtractedDir = false,
  }) async {
    try {
      await validateImportZip(extractedDir, backupPassword);
      final newId = _uuid.v4();
      await applyImportToVaultId(extractedDir, newId);
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
      if (deleteExtractedDir) {
        try {
          if (extractedDir.existsSync()) {
            await extractedDir.delete(recursive: true);
          }
        } catch (_) {}
      }
    }
  }

  /// Importa un cloud-pack/ZIP ya extraído usando el [cloudVaultId] remoto
  /// (no genera un UUID nuevo). No desbloquea la libreta.
  ///
  /// Si [overwriteIfExists] y hay una libreta local vacía con otro id, se
  /// elimina ese slot y se registra [cloudVaultId].
  Future<void> importCloudVaultAsLocal({
    required String cloudVaultId,
    required Directory extractedDir,
    required String password,
    String? displayName,
    bool overwriteIfExists = false,
    bool setActive = false,
  }) async {
    final id = cloudVaultId.trim();
    if (id.isEmpty) {
      throw ArgumentError('cloudVaultId vacío');
    }
    await validateImportZip(extractedDir, password);
    await _prepareCloudVaultSlot(
      id: id,
      overwriteIfExists: overwriteIfExists,
    );
    await applyImportToVaultId(extractedDir, id);
    await _registerImportedCloudVault(
      id: id,
      displayName: displayName,
      setActive: setActive,
    );
  }

  /// Igual que [importCloudVaultAsLocal] con árbol en memoria (web / IndexedDB).
  Future<void> importCloudVaultAsLocalFromMemory({
    required String cloudVaultId,
    required ExtractedVaultBackup backup,
    required String password,
    String? displayName,
    bool overwriteIfExists = false,
    bool setActive = false,
  }) async {
    final id = cloudVaultId.trim();
    if (id.isEmpty) {
      throw ArgumentError('cloudVaultId vacío');
    }
    AppLogger.info(
      'importCloudVaultAsLocalFromMemory start',
      tag: 'vault',
      context: {
        'vaultId': id,
        'overwrite': overwriteIfExists,
        'setActive': setActive,
      },
    );
    await validateImportBackup(backup, password);
    await _prepareCloudVaultSlot(
      id: id,
      overwriteIfExists: overwriteIfExists,
    );
    await applyImportToVaultIdFromMemory(backup, id);
    await _registerImportedCloudVault(
      id: id,
      displayName: displayName,
      setActive: setActive,
    );
    AppLogger.info(
      'importCloudVaultAsLocalFromMemory ok',
      tag: 'vault',
      context: {'vaultId': id},
    );
  }

  Future<void> _prepareCloudVaultSlot({
    required String id,
    required bool overwriteIfExists,
  }) async {
    await _registry.load();

    final already =
        _registry.containsVault(id) || await VaultPaths.vaultExistsForId(id);
    if (already && !overwriteIfExists) {
      throw StateError('La libreta $id ya existe en este dispositivo.');
    }

    if (overwriteIfExists) {
      final activeId = VaultPaths.activeVaultId;
      if (activeId != null &&
          activeId != id &&
          await isLocalVaultEmptyForCloudImport()) {
        await VaultPaths.deleteVaultDirectory(activeId);
        if (_registry.containsVault(activeId)) {
          await _registry.remove(activeId);
        }
      }
      if (already) {
        await VaultPaths.deleteVaultDirectory(id);
      }
    }
  }

  Future<void> _registerImportedCloudVault({
    required String id,
    required String? displayName,
    required bool setActive,
  }) async {
    if (!_registry.containsVault(id)) {
      final ordinal = _registry.vaults.length + 1;
      await _registry.add(
        VaultEntry(
          id: id,
          displayName: displayName ?? 'Libreta $ordinal',
          createdAtMs: DateTime.now().millisecondsSinceEpoch,
        ),
      );
    } else if (displayName != null && displayName.trim().isNotEmpty) {
      await _registry.rename(id, displayName.trim());
    }

    if (setActive) {
      VaultPaths.setActiveVaultId(id);
      await _registry.setActiveVaultId(id);
    }
    notifyListeners();
  }

  /// Heurística 2B: slot vacío / onboarding / solo páginas starter.
  Future<bool> isLocalVaultEmptyForCloudImport() async {
    await _registry.load();
    if (_state == VaultFlowState.needsOnboarding) return true;
    final activeId = VaultPaths.activeVaultId;
    if (activeId == null || activeId.isEmpty) return true;
    if (!await VaultPaths.vaultExistsForId(activeId)) return true;
    if (_state == VaultFlowState.unlocked) {
      if (_pages.isEmpty) return true;
      final onlyStarter = _pages.every((p) => p.id.startsWith('starter_'));
      if (onlyStarter) {
        // Sin adjuntos de usuario ≈ libreta recién creada con páginas iniciales.
        return true;
      }
      return false;
    }
    // Locked / initializing: si hay payload real, no está vacía.
    return !(await VaultPaths.vaultExists());
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
      // Evita que un autosave pendiente pise los archivos recién importados.
      _persistence.cancelPendingSave();
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
    // Evita que un autosave pendiente pise los archivos recién importados.
    _persistence.cancelPendingSave();
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
    // Volcar cambios pendientes para que el backup pre-import los incluya.
    await flushPendingSave();
    try {
      await createPreImportBackupZip(
        vaultBinBytes: await vaultBinEquivalentBytes(),
      );
    } catch (e) {
      AppLogger.warn(
        'No se pudo crear el backup pre-import',
        tag: 'vault',
        context: {'error': '$e'},
      );
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
          displayName: displayName ?? 'Notion importado',
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
    await applyImportToVaultId(extractedDir, id);

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

  /// Onboarding por copia en memoria (cloud-pack en web / IndexedDB).
  Future<void> completeOnboardingFromMemory(
    ExtractedVaultBackup backup,
    String backupPassword,
  ) async {
    await _registry.load();
    if (VaultPaths.activeVaultId != null && await VaultPaths.vaultExists()) {
      throw StateError('Ya hay datos en la libreta actual.');
    }
    await validateImportBackup(backup, backupPassword);

    var id = VaultPaths.activeVaultId;
    if (id == null) {
      id = _uuid.v4();
      VaultPaths.setActiveVaultId(id);
    }
    await applyImportToVaultIdFromMemory(backup, id);

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
    AppLogger.info(
      'unlockWithPassword start',
      tag: 'vault',
      context: {
        'vaultId': _vaultId,
        'encrypted': vaultUsesEncryption,
      },
    );
    if (!vaultUsesEncryption) {
      _dek = null;
      try {
        final payload = await _ensureV1AndLoad(() => _repo.loadPayload(null));
        _pages = List.from(payload.pages);
        _loadRevisionsFromPayload(payload);
        _ensureOrderForCurrentPages();
        await _applySyncedDisplayName(payload.displayName);
        await _applyInitialPageSelection(preferPersistedPreference: true);
        _state = VaultFlowState.unlocked;
        purgeExpiredTrash();
        _restartIdleLockTimer();
        await _initSnapshotManager();
        await _cacheDeviceSyncKeyAfterUnlock();
        AppLogger.info(
          'unlockWithPassword ok (plain)',
          tag: 'vault',
          context: {'vaultId': _vaultId, 'pages': _pages.length},
        );
        notifyListeners();
      } on VaultCorruptionException {
        _state = VaultFlowState.recovery;
        AppLogger.error(
          'unlockWithPassword recovery (plain corruption)',
          tag: 'vault',
          context: {'vaultId': _vaultId},
        );
        notifyListeners();
      }
      return;
    }
    final throttle = UnlockAttemptThrottle();
    final vaultIdForThrottle = _vaultId ?? '';
    final wait = await throttle.remainingWait(vaultIdForThrottle);
    if (wait != null) {
      throw UnlockThrottledException(wait);
    }
    try {
      final Uint8List dek;
      try {
        dek = await _repo.unlockWithPassword(password);
      } on VaultCorruptionException {
        rethrow;
      } catch (e) {
        await throttle.recordFailure(vaultIdForThrottle);
        rethrow;
      }
      await throttle.recordSuccess(vaultIdForThrottle);
      _dek = dek.toList();
      final payload = await _ensureV1AndLoad(() => _repo.loadPayload(_dek));
      _pages = List.from(payload.pages);
      _loadRevisionsFromPayload(payload);
      _ensureOrderForCurrentPages();
      await _applySyncedDisplayName(payload.displayName);
      await _applyInitialPageSelection(preferPersistedPreference: true);
      _state = VaultFlowState.unlocked;
      purgeExpiredTrash();
      _restartIdleLockTimer();
      await _initSnapshotManager();
      await _cacheDeviceSyncKeyAfterUnlock();
      AppLogger.info(
        'unlockWithPassword ok',
        tag: 'vault',
        context: {'vaultId': _vaultId, 'pages': _pages.length},
      );
      notifyListeners();
    } on VaultCorruptionException {
      _dek = null;
      _state = VaultFlowState.recovery;
      AppLogger.error(
        'unlockWithPassword recovery (corruption)',
        tag: 'vault',
        context: {'vaultId': _vaultId},
      );
      notifyListeners();
    }
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
    try {
      final payload = await _ensureV1AndLoad(() => _repo.loadPayload(_dek));
      _pages = List.from(payload.pages);
      _loadRevisionsFromPayload(payload);
      _ensureOrderForCurrentPages();
      await _applySyncedDisplayName(payload.displayName);
      await _applyInitialPageSelection(preferPersistedPreference: true);
      _state = VaultFlowState.unlocked;
      purgeExpiredTrash();
      _restartIdleLockTimer();
      await _initSnapshotManager();
      await _cacheDeviceSyncKeyAfterUnlock();
      AppLogger.info(
        'unlockWithDeviceAuth ok',
        tag: 'vault',
        context: {'vaultId': _vaultId, 'pages': _pages.length},
      );
      notifyListeners();
    } on VaultCorruptionException {
      _dek = null;
      _state = VaultFlowState.recovery;
      AppLogger.error(
        'unlockWithDeviceAuth recovery (corruption)',
        tag: 'vault',
        context: {'vaultId': _vaultId},
      );
      notifyListeners();
    }
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
    try {
      final payload = await _ensureV1AndLoad(() => _repo.loadPayload(_dek));
      _pages = List.from(payload.pages);
      _loadRevisionsFromPayload(payload);
      _ensureOrderForCurrentPages();
      await _applySyncedDisplayName(payload.displayName);
      await _applyInitialPageSelection(preferPersistedPreference: true);
      _state = VaultFlowState.unlocked;
      purgeExpiredTrash();
      _restartIdleLockTimer();
      await _initSnapshotManager();
      await _cacheDeviceSyncKeyAfterUnlock();
      AppLogger.info(
        'unlockWithPasskey ok',
        tag: 'vault',
        context: {'vaultId': _vaultId, 'pages': _pages.length},
      );
      notifyListeners();
    } on VaultCorruptionException {
      _dek = null;
      _state = VaultFlowState.recovery;
      AppLogger.error(
        'unlockWithPasskey recovery (corruption)',
        tag: 'vault',
        context: {'vaultId': _vaultId},
      );
      notifyListeners();
    }
  }

  /// Guarda DEK / clave de sync estable para device-sync en segundo plano.
  Future<void> _cacheDeviceSyncKeyAfterUnlock() async {
    final vid = _vaultId;
    if (vid == null || vid.isEmpty) return;
    try {
      final cache = DeviceSyncKeyCache();
      if (vaultUsesEncryption) {
        if (_dek == null || _dek!.length != VaultCrypto.dekLength) {
          AppLogger.warn(
            'device sync key cache skipped: missing DEK',
            tag: 'vault',
            context: {'vaultId': vid},
          );
          return;
        }
        await cache.save(vid, _dek!);
      } else {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null && uid.isNotEmpty) {
          final secret = await DeviceSyncKeyCache.ensureAccountSyncSecret(vid);
          final key = await DeviceSyncKeyCache.plainPackKey(
            uid: uid,
            vaultId: vid,
            accountSecret: secret,
          );
          final raw = await key.extractBytes();
          await cache.save(vid, raw);
        } else {
          await cache.ensurePlainVaultSyncKey(vid);
        }
      }
      AppLogger.debug(
        'device sync key cached after unlock',
        tag: 'vault',
        context: {'vaultId': vid, 'encrypted': vaultUsesEncryption},
      );
    } catch (e, st) {
      AppLogger.warn(
        'device sync key cache failed after unlock',
        tag: 'vault',
        context: {'vaultId': vid, 'error': '$e'},
      );
      AppLogger.debug(
        'device sync key cache stack',
        tag: 'vault',
        context: {'stack': '$st'},
      );
    }
    await _restorePersistedSyncConflicts();
  }

  Future<void> _restorePersistedSyncConflicts() async {
    final vid = _vaultId;
    if (vid == null || vid.isEmpty) return;
    final loaded = await _conflictStore.load(vid);
    _syncConflicts
      ..clear()
      ..addAll(loaded);
    _notifySyncConflictCountChanged();
  }

  Future<void> _persistSyncConflicts() async {
    final vid = _vaultId;
    if (vid == null || vid.isEmpty) return;
    await _conflictStore.save(vid, List<SyncConflictEntry>.from(_syncConflicts));
  }

  /// Vacía el estado en memoria de la libreta (sin fijar [VaultFlowState]).
  void _clearVaultSessionMemory() {
    _persistence.cancelPendingSave();
    _revisionIdleTimer?.cancel();
    _revisionIdleTimer = null;
    _idleLockTimer?.cancel();
    _idleLockTimer = null;
    _pageIdsPendingRevision.clear();
    _dek = null;
    _pages = [];
    _pageRevisions.clear();
    _pageAcl.clear();
    // La cola sigue en prefs; se restaura al desbloquear. No tocar AppSettings.
    _syncConflicts.clear();
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
    _navigationHistory.clear();
    _applyingHistoryNavigation = false;
  }

  /// Hooks que vacían a la sesión estado editable con debounce propio (p. ej.
  /// los documentos Quill del editor de bloques) antes de un guardado forzado.
  void addPendingFlushHook(void Function() hook) {
    _persistence.addPendingFlushHook(hook);
  }

  void removePendingFlushHook(void Function() hook) {
    _persistence.removePendingFlushHook(hook);
  }

  Future<void> flushPendingSave() async {
    if (_vaultFormatVersion == 1) {
      _v1TreeSaveTimer?.cancel();
      _v1TreeSaveTimer = null;
      // También vaciar revisiones pendientes (idle) si las hay.
      if (_pageIdsPendingRevision.isNotEmpty ||
          (_revisionIdleTimer?.isActive ?? false)) {
        _revisionIdleTimer?.cancel();
        _revisionIdleTimer = null;
        await _capturePendingRevisionsAndPersist();
      } else {
        await persistNow();
      }
      return;
    }
    await _persistence.flushPendingSave();
  }

  Future<void> lock() async {
    // Vaciar SIEMPRE el guardado v1 pendiente, incluso en libretas sin
    // cifrar: de lo contrario un guardado debounced (_v1TreeSaveTimer) de la
    // libreta que se abandona puede completarse después de que switchVault()
    // ya cambió el vault activo, escribiendo el contenido de la libreta vieja
    // dentro del árbol de la libreta nueva (contaminación cruzada entre
    // libretas). Las libretas cifradas ya quedaban cubiertas por el
    // flushPendingSave() de más abajo; esto extiende la misma protección a
    // las libretas en claro, para las que este método retorna antes de
    // llegar a él.
    await flushPendingSave();
    if (!vaultUsesEncryption) return;
    unawaited(MeetingNoteSessionController.instance.cancelAndTeardown());
    await _persistLastSelectedPageBeforeLock();
    // Asegura DEK en caché para sync en segundo plano tras bloquear.
    await _cacheDeviceSyncKeyAfterUnlock();
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
    // Secuencial: primero volcar cambios pendientes y solo después bloquear.
    // Si corrieran en paralelo, lock() podría vaciar la DEK/páginas mientras
    // el guardado aún construye el payload (riesgo de corrupción/pérdida).
    unawaited(() async {
      try {
        await flushPendingSave();
      } catch (_) {
        // No impedir el bloqueo si el volcado falla.
      }
      if (_lockOnAppBackground && _state == VaultFlowState.unlocked) {
        await lock();
      }
    }());
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
    // Seguridad: al revocar la passkey, la DEK de desbloqueo rápido asociada
    // deja de ser válida; se elimina para exigir la contraseña maestra.
    final vid = _vaultId;
    if (vid != null && vid.isNotEmpty) {
      await _quick.disable(vid);
    }
    notifyListeners();
  }

  void selectPage(String id) {
    final page = _pageById(id);
    if (page == null || page.isTrashed) return;
    final previousId = _selectedPageId;
    if (previousId != null && previousId != id) {
      unawaited(() async {
        try {
          await onBeforeLeavePage?.call();
        } catch (e, st) {
          AppLogger.warn(
            'onBeforeLeavePage failed',
            tag: 'workspace',
            context: {'from': previousId, 'to': id, 'error': '$e', 'stack': '$st'},
          );
        }
      }());
    }
    touchActivity();
    _selectedPageId = id;
    if (!_applyingHistoryNavigation) {
      _navigationHistory.record(id);
    }
    AppLogger.debug(
      'selectPage',
      tag: 'workspace',
      context: {'pageId': id, 'vaultId': _vaultId},
    );
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
    if (!_applyingHistoryNavigation) {
      _navigationHistory.record(null);
    }
    notifyListeners();
  }

  bool get canNavigateHistoryBack => _navigationHistory.canGoBack;

  bool get canNavigateHistoryForward => _navigationHistory.canGoForward;

  bool _isNavigationHistoryVisitValid(String? pageId) {
    if (pageId == null) return true;
    final page = _pageById(pageId);
    return page != null && !page.isTrashed;
  }

  /// Aplica la entrada actual del historial sin volver a registrarla.
  void _applyNavigationHistoryCurrent() {
    final id = _navigationHistory.current;
    if (id == null) {
      if (_selectedPageId == null) return;
      _selectedPageId = null;
      notifyListeners();
      return;
    }
    final page = _pageById(id);
    if (page == null || page.isTrashed) return;
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

  /// Retrocede en el historial de páginas/home. No cierra rutas del [Navigator].
  bool navigateHistoryBack() {
    if (!_navigationHistory.canGoBack) return false;
    _applyingHistoryNavigation = true;
    try {
      if (!_navigationHistory.goBack(isValid: _isNavigationHistoryVisitValid)) {
        return false;
      }
      _applyNavigationHistoryCurrent();
      return true;
    } finally {
      _applyingHistoryNavigation = false;
    }
  }

  /// Avanza en el historial de páginas/home.
  bool navigateHistoryForward() {
    if (!_navigationHistory.canGoForward) return false;
    _applyingHistoryNavigation = true;
    try {
      if (!_navigationHistory.goForward(
        isValid: _isNavigationHistoryVisitValid,
      )) {
        return false;
      }
      _applyNavigationHistoryCurrent();
      return true;
    } finally {
      _applyingHistoryNavigation = false;
    }
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
    selectPage(id);
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
    selectPage(id);
    scheduleSave(trackRevisionForPageId: id);
  }

  /// Devuelve el id de la carpeta creada (los llamadores existentes que no lo
  /// necesitan simplemente ignoran el valor de retorno).
  String addFolder({String? parentId}) {
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
    return id;
  }

  /// Crea una página con [id], [title] y [blocks] específicos — a diferencia
  /// de [addPage], que siempre crea una página en blanco con título por
  /// defecto y la selecciona. Pensado para tools de creación de contenido
  /// del agente IA de Quill, donde el [id] ya se usó para construir los
  /// bloques antes de llamar a este método.
  void createPageWithId({
    required String id,
    required String title,
    String? parentId,
    required List<FolioBlock> blocks,
  }) {
    _pages.add(FolioPage(id: id, title: title, parentId: parentId, blocks: blocks));
    _pageOrderByParent
        .putIfAbsent(_orderKeyForParent(parentId), () => <String>[])
        .add(id);
    _mcpReadablePageIds.add(id);
    notifyListeners();
    scheduleSave(trackRevisionForPageId: id);
  }

  /// Páginas/carpetas explícitamente autorizadas para lectura MCP.
  Set<String> get mcpReadablePageIds => Set<String>.unmodifiable(_mcpReadablePageIds);

  /// True si [pageId] está en la allowlist o algún ancestro carpeta lo está.
  bool isMcpPageReadable(String pageId) {
    final id = pageId.trim();
    if (id.isEmpty) return false;
    if (_mcpReadablePageIds.contains(id)) return true;
    var cur = _pageById(id);
    final seen = <String>{};
    while (cur?.parentId != null) {
      final parentId = cur!.parentId!;
      if (!seen.add(parentId)) break;
      if (_mcpReadablePageIds.contains(parentId)) {
        final parent = _pageById(parentId);
        if (parent != null && parent.isFolder) return true;
      }
      cur = _pageById(parentId);
    }
    return false;
  }

  void grantMcpPageReadable(String pageId) {
    final id = pageId.trim();
    if (id.isEmpty || _pageById(id) == null) return;
    if (_mcpReadablePageIds.contains(id)) return;
    _mcpReadablePageIds.add(id);
    notifyListeners();
    scheduleSave();
  }

  void revokeMcpPageReadable(String pageId) {
    final id = pageId.trim();
    if (id.isEmpty || !_mcpReadablePageIds.remove(id)) return;
    notifyListeners();
    scheduleSave();
  }

  void clearMcpReadablePages() {
    if (_mcpReadablePageIds.isEmpty) return;
    _mcpReadablePageIds.clear();
    notifyListeners();
    scheduleSave();
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

  bool _hasChildren(String id) =>
      _pages.any((p) => p.parentId == id && !p.isTrashed);

  bool _hasAnyChildrenIncludingTrashed(String id) =>
      _pages.any((p) => p.parentId == id);

  /// Ids del subárbol (raíz incluida), solo entre páginas con el mismo
  /// criterio de "visible" que el árbol activo (no papelera).
  List<String> activeSubtreeIds(String rootId) {
    final root = _pageById(rootId);
    if (root == null || root.isTrashed) return const [];
    final byParent = <String?, List<String>>{};
    for (final p in _pages) {
      if (p.isTrashed) continue;
      (byParent[p.parentId] ??= <String>[]).add(p.id);
    }
    final out = <String>[];
    void walk(String id) {
      out.add(id);
      for (final childId in byParent[id] ?? const <String>[]) {
        walk(childId);
      }
    }

    walk(rootId);
    return out;
  }

  List<String> _trashedSubtreeIds(String rootId) {
    final root = _pageById(rootId);
    if (root == null || !root.isTrashed) return const [];
    final byParent = <String?, List<String>>{};
    for (final p in _pages) {
      if (!p.isTrashed) continue;
      (byParent[p.parentId] ??= <String>[]).add(p.id);
    }
    final out = <String>[];
    void walk(String id) {
      out.add(id);
      for (final childId in byParent[id] ?? const <String>[]) {
        walk(childId);
      }
    }

    walk(rootId);
    return out;
  }

  int _pageDepth(String id) {
    var depth = 0;
    var cur = _pageById(id);
    while (cur?.parentId != null) {
      depth++;
      cur = _pageById(cur!.parentId!);
      if (depth > 10000) break;
    }
    return depth;
  }

  bool canMovePageToTrash(String id) {
    final subtree = activeSubtreeIds(id);
    if (subtree.isEmpty) return false;
    return activePages.length - subtree.length >= 1;
  }

  /// Mueve la página y todo su subárbol activo a la papelera.
  void movePageToTrash(String id) {
    if (!canMovePageToTrash(id)) return;
    final subtree = activeSubtreeIds(id);
    AppLogger.info(
      'movePageToTrash',
      tag: 'workspace',
      context: {'pageId': id, 'subtreeCount': subtree.length},
    );
    final now = DateTime.now().toUtc();
    var selectionHit = false;
    for (final pageId in subtree) {
      final p = _pageById(pageId);
      if (p == null || p.isTrashed) continue;
      p.trashedAt = now;
      if (_selectedPageId == pageId) selectionHit = true;
    }
    if (selectionHit) {
      _pickInitialSelection();
      unawaited(_persistLastSelectedPageForActiveVault(_selectedPageId));
    }
    notifyListeners();
    scheduleSave();
  }

  /// Raíces de la papelera: páginas trashed cuyo padre no está también en papelera.
  List<FolioPage> get trashRootPages {
    final trashedIds = {
      for (final p in _pages)
        if (p.isTrashed) p.id,
    };
    final roots = _pages.where((p) {
      if (!p.isTrashed) return false;
      final parentId = p.parentId;
      if (parentId == null) return true;
      return !trashedIds.contains(parentId);
    }).toList()
      ..sort((a, b) {
        final at = a.trashedAt!;
        final bt = b.trashedAt!;
        return bt.compareTo(at);
      });
    return List.unmodifiable(roots);
  }

  void restoreFromTrash(String id) {
    final root = _pageById(id);
    if (root == null || !root.isTrashed) return;
    final subtree = _trashedSubtreeIds(id);
    if (subtree.isEmpty) return;
    AppLogger.info(
      'restoreFromTrash',
      tag: 'workspace',
      context: {'pageId': id, 'subtreeCount': subtree.length},
    );
    for (final pageId in subtree) {
      final p = _pageById(pageId);
      if (p == null) continue;
      p.trashedAt = null;
    }
    final parentId = root.parentId;
    final parent = parentId == null ? null : _pageById(parentId);
    if (parent == null || parent.isTrashed) {
      final oldParentId = root.parentId;
      root.parentId = null;
      if (oldParentId != null) {
        _pageOrderByParent[_orderKeyForParent(oldParentId)]?.remove(id);
      }
      final rootKey = _orderKeyForParent(null);
      final rootOrder = _pageOrderByParent.putIfAbsent(rootKey, () => <String>[]);
      if (!rootOrder.contains(id)) rootOrder.add(id);
    } else {
      final key = _orderKeyForParent(parentId);
      final order = _pageOrderByParent.putIfAbsent(key, () => <String>[]);
      if (!order.contains(id)) order.add(id);
    }
    _ensureOrderForCurrentPages();
    notifyListeners();
    scheduleSave();
  }

  void permanentlyDeleteFromTrash(String id) {
    final root = _pageById(id);
    if (root == null || !root.isTrashed) return;
    final ids = _trashedSubtreeIds(id);
    if (ids.isEmpty) return;
    final sorted = List<String>.from(ids)
      ..sort((a, b) => _pageDepth(b).compareTo(_pageDepth(a)));
    for (final pageId in sorted) {
      _hardDeletePage(pageId);
    }
    notifyListeners();
    scheduleSave();
  }

  void emptyTrash() {
    final roots = trashRootPages.map((p) => p.id).toList();
    if (roots.isEmpty) return;
    for (final id in roots) {
      if (_pageById(id)?.isTrashed != true) continue;
      final ids = _trashedSubtreeIds(id);
      final sorted = List<String>.from(ids)
        ..sort((a, b) => _pageDepth(b).compareTo(_pageDepth(a)));
      for (final pageId in sorted) {
        _hardDeletePage(pageId);
      }
    }
    notifyListeners();
    scheduleSave();
  }

  /// Elimina de forma definitiva las páginas en papelera más antiguas que [retention].
  void purgeExpiredTrash({Duration retention = trashRetention}) {
    final cutoff = DateTime.now().toUtc().subtract(retention);
    final expiredRoots = trashRootPages.where((p) {
      final t = p.trashedAt;
      return t != null && !t.isAfter(cutoff);
    }).map((p) => p.id).toList();
    if (expiredRoots.isEmpty) {
      // También purgar hojas huérfanas expiradas (por si el padre se restauró).
      final orphanExpired = _pages
          .where(
            (p) =>
                p.isTrashed &&
                p.trashedAt != null &&
                !p.trashedAt!.isAfter(cutoff),
          )
          .map((p) => p.id)
          .toList();
      if (orphanExpired.isEmpty) return;
      final sorted = orphanExpired
        ..sort((a, b) => _pageDepth(b).compareTo(_pageDepth(a)));
      for (final pageId in sorted) {
        if (_pageById(pageId)?.isTrashed == true) {
          _hardDeletePage(pageId);
        }
      }
      notifyListeners();
      scheduleSave();
      return;
    }
    for (final id in expiredRoots) {
      if (_pageById(id)?.isTrashed != true) continue;
      final ids = _trashedSubtreeIds(id);
      final sorted = List<String>.from(ids)
        ..sort((a, b) => _pageDepth(b).compareTo(_pageDepth(a)));
      for (final pageId in sorted) {
        _hardDeletePage(pageId);
      }
    }
    notifyListeners();
    scheduleSave();
  }

  void _hardDeletePage(String id) {
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
    _mcpReadablePageIds.remove(id);
    _pageTombstones[id] = DateTime.now().toUtc().millisecondsSinceEpoch;
    if (wasSelected) {
      _pickInitialSelection();
      unawaited(_persistLastSelectedPageForActiveVault(_selectedPageId));
    }
  }

  void deletePage(String id) {
    if (activePages.length <= 1) return;
    if (_hasAnyChildrenIncludingTrashed(id)) return;
    final page = _pageById(id);
    if (page == null) return;
    if (page.isTrashed) {
      _hardDeletePage(id);
      notifyListeners();
      scheduleSave();
      return;
    }
    // Compat: hard-delete solo de hojas; la UI usa [movePageToTrash].
    if (_hasChildren(id)) return;
    _hardDeletePage(id);
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
    if (_slack.connections.isNotEmpty ||
        _teams.connections.isNotEmpty ||
        _discord.connections.isNotEmpty) {
      final page = _pageById(pageId);
      final pageTitle = (page?.title.trim().isEmpty ?? true)
          ? _titleL10n.untitled
          : page!.title.trim();
      final comment = t.trim();
      final snippet = comment.length > 200
          ? '${comment.substring(0, 200)}…'
          : comment;
      _notificationDispatcher.notifyCommentAdded(
        slackConnections: _slack.connections,
        teamsConnections: _teams.connections,
        discordConnections: _discord.connections,
        message: _titleL10n.integrationNotifyNewComment(pageTitle, snippet),
      );
    }
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
    final seen = <String>{};
    var cur = _pageById(nodeId);
    while (cur != null) {
      if (!seen.add(cur.id)) return false; // ciclo parentId
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
    scheduleSave(trackRevisionForPageId: pageId, notify: false);
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
    scheduleSave(trackRevisionForPageId: pageId, notify: false);
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

  void setBlockCodeWrap(String pageId, String blockId, bool wrap) {
    final page = _pageById(pageId);
    if (page == null) return;
    final b = _blockById(page, blockId);
    if (b == null || b.type != 'code') return;
    _rememberUndoBeforePageMutation(pageId);
    b.codeWrap = wrap;
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

  void insertBlockBefore({
    required String pageId,
    required String beforeBlockId,
    required FolioBlock block,
  }) {
    final page = _pageById(pageId);
    if (page == null) return;
    final i = page.blocks.indexWhere((b) => b.id == beforeBlockId);
    if (i < 0) return;
    _rememberUndoBeforePageMutation(pageId);
    page.blocks.insert(i, block);
    notifyListeners();
    scheduleSave(trackRevisionForPageId: pageId);
  }

  /// Aplica una mutación arbitraria sobre la lista de bloques de [pageId],
  /// preservando undo/persistencia igual que el resto de mutaciones de bloque.
  /// Punto de extensión genérico para operaciones del agente IA (Fase 1/2 del
  /// tool-calling de Quill) que no tienen un método dedicado (borrar bloque,
  /// reemplazar bloque, mover dentro de la página, editar celdas de tabla...).
  void mutatePageBlocks(
    String pageId,
    void Function(List<FolioBlock> blocks) mutate,
  ) {
    final page = _pageById(pageId);
    if (page == null) return;
    _rememberUndoBeforePageMutation(pageId);
    mutate(page.blocks);
    notifyListeners();
    scheduleSave(trackRevisionForPageId: pageId);
  }

  /// Páginas hijas directas de [pageId] (no incluye descendientes indirectos).
  List<FolioPage> childrenOf(String pageId) =>
      _pages.where((p) => p.parentId == pageId).toList(growable: false);

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
            // Preserva el formato WYSIWYG (Quill Delta) al duplicar/clonar.
            // syncGroupId se omite a propósito: un clon es independiente y no
            // debe quedar vinculado en cascada al bloque original.
            richTextDeltaJson: b.richTextDeltaJson,
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
    if (_slack.connections.isNotEmpty ||
        _teams.connections.isNotEmpty ||
        _discord.connections.isNotEmpty) {
      final title = task.title.trim().isEmpty ? _titleL10n.untitled : task.title.trim();
      _notificationDispatcher.notifyTaskCreated(
        slackConnections: _slack.connections,
        teamsConnections: _teams.connections,
        discordConnections: _discord.connections,
        message: _titleL10n.integrationNotifyNewTask(title),
      );
    }
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
      _notifyTaskStatusChanged(b.text, status);
    } else if (b.type == 'task') {
      final t = FolioTaskData.tryParse(b.text) ?? FolioTaskData.defaults();
      final next = t.copyWith(status: status, columnId: status);
      b.text = _markTaskNeedsPushIfJiraLinked(next).encode();
      _notifyTaskStatusChanged(next.title, status);
    } else {
      return;
    }
    notifyListeners();
    scheduleSave(trackRevisionForPageId: pageId);
  }

  FolioTaskData _markTaskNeedsPushIfJiraLinked(FolioTaskData t) {
    final ext = t.external;
    if (ext == null || !const {'jira', 'youtrack', 'trello'}.contains(ext.provider)) return t;
    final cur = (ext.syncState ?? '').trim();
    if (cur == 'conflict') return t;
    return t.copyWith(external: ext.copyWith(syncState: 'needsPush'));
  }

  /// Notifica a las conexiones de Slack/Teams suscritas, en segundo plano y
  /// sin bloquear la mutación que lo disparó (ver `IntegrationNotificationDispatcher`).
  void _notifyTaskStatusChanged(String title, String status) {
    if (_slack.connections.isEmpty &&
        _teams.connections.isEmpty &&
        _discord.connections.isEmpty) {
      return;
    }
    final displayTitle = title.trim().isEmpty ? _titleL10n.untitled : title.trim();
    _notificationDispatcher.notifyTaskStatusChanged(
      slackConnections: _slack.connections,
      teamsConnections: _teams.connections,
      discordConnections: _discord.connections,
      message: _titleL10n.integrationNotifyTaskMoved(displayTitle, status),
    );
  }

  /// Primera configuración `kanban` de la página, o valores por defecto.
  FolioKanbanData kanbanDataForPage(String pageId) {
    final page = _pageById(pageId);
    if (page == null) return FolioKanbanData.defaults();
    for (final b in page.blocks) {
      if (b.type == 'kanban') {
        return FolioKanbanData.tryParse(b.text) ?? FolioKanbanData.defaults();
      }
    }
    return FolioKanbanData.defaults();
  }

  /// Mueve una tarjeta `task` a una columna Kanban (dinámica).
  void setTaskBlockColumnId(String pageId, String blockId, String columnId) {
    final page = _pageById(pageId);
    if (page == null) return;
    final b = _blockById(page, blockId);
    if (b == null || b.type != 'task') return;
    _rememberUndoBeforePageMutation(pageId);
    final t = FolioTaskData.tryParse(b.text) ?? FolioTaskData.defaults();
    final next = t.withKanbanColumn(columnId);
    b.text = _markTaskNeedsPushIfJiraLinked(next).encode();
    _notifyTaskStatusChanged(next.title, columnId);
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
    // El Delta previo cubría el texto completo; al partir, el Markdown `before`
    // pasa a ser la fuente de verdad. Limpiar el Delta evita que al recargar se
    // restaure el contenido completo anterior a la división.
    cur.richTextDeltaJson = null;
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
    // El Delta de `prev` solo cubría su contenido antiguo; tras fusionar, el
    // Markdown combinado es la fuente de verdad. Limpiarlo evita perder el
    // texto fusionado al recargar (donde el Delta tendría prioridad).
    prev.richTextDeltaJson = null;
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
  /// [notify]: si `false`, el llamador ya programó su propio aviso coalescido
  /// (ver [_scheduleCoalescedTypingNotify]) y este método no debe duplicarlo.
  void scheduleSave({String? trackRevisionForPageId, bool notify = true}) {
    if (vaultUsesEncryption && _dek == null) return;
    touchActivity();
    if (trackRevisionForPageId != null) {
      _pageIdsPendingRevision.add(trackRevisionForPageId);
      _revisionIdleTimer?.cancel();
      _revisionIdleTimer = Timer(_revisionIdleDelay, () {
        unawaited(_capturePendingRevisionsAndPersist());
      });
    }
    if (_vaultFormatVersion == 0) {
      _persistence.scheduleSave(notify: notify);
    } else {
      // v1: solo árbol en repo/; no escribir vault.bin.
      _scheduleV1TreeSave(notify: notify);
    }
    if (notify) notifyListeners();
  }

  void _scheduleV1TreeSave({bool notify = true}) {
    _v1TreeSaveTimer?.cancel();
    if (notify) {
      // Alinea el indicador de guardado con el flujo v0.
      // status se actualiza en persistNow vía notifyListeners del session.
    }
    _v1TreeSaveTimer = Timer(_v1TreeSaveDebounce, () {
      _v1TreeSaveTimer = null;
      unawaited(persistNow());
    });
  }

  Future<void> _capturePendingRevisionsAndPersist() async {
    if (vaultUsesEncryption && _dek == null) return;
    final ids = List<String>.from(_pageIdsPendingRevision);
    _pageIdsPendingRevision.clear();
    _v1TreeSaveTimer?.cancel();
    _v1TreeSaveTimer = null;

    if (ids.isEmpty) {
      await persistNow();
      return;
    }

    if (_vaultFormatVersion == 0) {
      // Format v0: capture page revisions to memory
      for (final id in ids) {
        final page = _pageById(id);
        if (page != null) {
          _appendRevisionSnapshotIfChanged(page);
        }
      }
      await persistNow();
      return;
    }

    // Format v1: persist tree, then one snapshot if page content changed.
    await persistNow();
    String? label;
    for (final id in ids) {
      final page = _pageById(id);
      if (page != null && page.title.trim().isNotEmpty) {
        label = page.title.trim();
        break;
      }
    }
    await _createVaultSnapshotSafe(
      label: label,
      pageIdsForDedupe: ids,
    );
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

  /// M5: Versions from memory (v0) or snapshots (v1)
  Future<List<VersionInfo>> versionsForPage(String pageId) async {
    if (_vaultFormatVersion == 0) {
      // Format v0: return from memory
      final list = _pageRevisions[pageId];
      if (list == null || list.isEmpty) return [];
      return list
          .map((r) => VersionInfo(
            versionId: r.revisionId,
            timestamp: r.savedAtMs,
            label: r.title,
            source: 'memory',
          ))
          .toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    } else {
      await _ensureHiddenVersionsLoaded();
      final hidden = _hiddenVersionsByPage[pageId] ?? const <String>{};
      // Format v1: los snapshots son de toda la libreta (como un commit),
      // pero solo nos interesan aquí los que realmente cambiaron ESTA
      // página (estilo `git log -- <path>`): comparamos el hash de sus
      // archivos entre snapshots consecutivos en vez de listarlos todos.
      final snapshots = await _snapshotManager.listSnapshots(); // más recientes primero
      if (snapshots.isEmpty) return [];

      final metaPath = _pageTreePath(pageId, 'meta.json');
      final blocksPath = _pageTreePath(pageId, 'blocks.jsonl');

      String? hashOf(VaultSnapshot s, String path) {
        for (final f in s.fileManifest) {
          if (f.path == path) return f.sha256;
        }
        return null;
      }

      final relevant = <VersionInfo>[];
      String? prevMeta;
      String? prevBlocks;
      var prevExisted = false;
      // De más antiguo a más reciente, para poder comparar "vs el anterior".
      for (final s in snapshots.reversed) {
        if (hidden.contains(s.snapshotId)) {
          prevMeta = hashOf(s, metaPath);
          prevBlocks = hashOf(s, blocksPath);
          prevExisted = prevMeta != null;
          continue;
        }
        final meta = hashOf(s, metaPath);
        final blocks = hashOf(s, blocksPath);
        final existsNow = meta != null;
        final changed = existsNow &&
            (!prevExisted || meta != prevMeta || blocks != prevBlocks);
        if (changed) {
          final title = await _pageTitleFromSnapshot(s.snapshotId, pageId) ??
              s.label;
          relevant.add(VersionInfo(
            versionId: s.snapshotId,
            timestamp: s.createdAtMs,
            label: (title != null && title.trim().isNotEmpty) ? title.trim() : '',
            source: 'snapshot',
            deviceId: s.deviceId,
          ));
        }
        prevMeta = meta;
        prevBlocks = blocks;
        prevExisted = existsNow;
      }
      return relevant.reversed.toList(); // más recientes primero
    }
  }

  /// Contenido de una página en un snapshot (para diffs v1).
  Future<FolioPageRevision?> pageContentAtVersion(
    String pageId,
    String versionId,
  ) async {
    if (_vaultFormatVersion != 1) {
      final list = _pageRevisions[pageId];
      return list?.firstWhereOrNull((r) => r.revisionId == versionId);
    }
    try {
      final metaPath = _pageTreePath(pageId, 'meta.json');
      final blocksPath = _pageTreePath(pageId, 'blocks.jsonl');
      final files = await _snapshotManager.extractFilesFromSnapshot(
        versionId,
        {metaPath, blocksPath},
      );
      final metaBytes = files[metaPath];
      if (metaBytes == null) return null;
      final meta = jsonDecode(utf8.decode(metaBytes)) as Map<String, dynamic>;
      final blocksJson = <Map<String, dynamic>>[];
      final blocksBytes = files[blocksPath];
      if (blocksBytes != null) {
        for (final line in utf8.decode(blocksBytes).split('\n')) {
          if (line.trim().isEmpty) continue;
          try {
            blocksJson.add(Map<String, dynamic>.from(jsonDecode(line) as Map));
          } catch (_) {}
        }
      }
      final snap = await _snapshotManager.getSnapshot(versionId);
      return FolioPageRevision(
        revisionId: versionId,
        savedAtMs: snap?.createdAtMs ?? 0,
        title: (meta['title'] as String?) ?? '',
        blocksJson: blocksJson,
      );
    } catch (e) {
      AppLogger.warn('pageContentAtVersion failed: $e');
      return null;
    }
  }

  Future<String?> _pageTitleFromSnapshot(
    String snapshotId,
    String pageId,
  ) async {
    try {
      final metaPath = _pageTreePath(pageId, 'meta.json');
      final files = await _snapshotManager.extractFilesFromSnapshot(
        snapshotId,
        {metaPath},
      );
      final bytes = files[metaPath];
      if (bytes == null) return null;
      final meta = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      return meta['title'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// M5: Ruta relativa dentro del árbol v1 para un archivo de página
  /// concreto (mismo esquema que `VaultPayloadToTree`: `pages/<id[0:2]>/<id>/`).
  String _pageTreePath(String pageId, String fileName) {
    final prefix = pageId.length >= 2 ? pageId.substring(0, 2) : 'xx';
    return 'pages/$prefix/$pageId/$fileName';
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

  /// M5: Elimina una entrada del historial unificado (revisión v0 en memoria
  /// o soft-hide de snapshot v1 para esa página), sin modificar el contenido
  /// actual ni borrar el snapshot global de la libreta.
  Future<bool> deleteVersion(String pageId, String versionId) async {
    if (vaultUsesEncryption && _dek == null) return false;
    if (_vaultFormatVersion == 0) {
      deletePageRevision(pageId, versionId);
      return true;
    }
    try {
      await _ensureHiddenVersionsLoaded();
      final set = _hiddenVersionsByPage.putIfAbsent(pageId, () => <String>{});
      set.add(versionId);
      await _persistHiddenVersions();
      notifyListeners();
      return true;
    } catch (e) {
      AppLogger.error('Failed to hide snapshot for page: $e');
      return false;
    }
  }

  Future<void> _ensureHiddenVersionsLoaded() async {
    if (_hiddenVersionsLoaded) return;
    _hiddenVersionsLoaded = true;
    try {
      final treeDir = await VaultPaths.vaultTreeDirectory();
      final file = File(p.join(treeDir.path, 'vault', 'hidden_versions.json'));
      if (!file.existsSync()) return;
      final raw = jsonDecode(await file.readAsString());
      if (raw is! Map) return;
      _hiddenVersionsByPage.clear();
      for (final entry in raw.entries) {
        final list = entry.value;
        if (list is List) {
          _hiddenVersionsByPage['${entry.key}'] =
              list.map((e) => '$e').toSet();
        }
      }
    } catch (e) {
      AppLogger.warn('Failed to load hidden_versions.json: $e');
    }
  }

  Future<void> _persistHiddenVersions() async {
    final treeDir = await VaultPaths.vaultTreeDirectory();
    final vaultMetaDir = Directory(p.join(treeDir.path, 'vault'));
    await vaultMetaDir.create(recursive: true);
    final file = File(p.join(vaultMetaDir.path, 'hidden_versions.json'));
    final json = <String, List<String>>{
      for (final e in _hiddenVersionsByPage.entries)
        if (e.value.isNotEmpty) e.key: e.value.toList()..sort(),
    };
    await file.writeAsString(jsonEncode(json), flush: true);
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

  /// M5: Restore from version (v0 memory or v1 snapshots).
  /// Restaura meta completa (title, emoji, tags, properties, blocks) de [pageId].
  Future<bool> restoreVersion(String pageId, String versionId) async {
    if (vaultUsesEncryption && _dek == null) return false;

    if (_vaultFormatVersion == 0) {
      restorePageRevision(pageId, versionId);
      return _pageById(pageId) != null;
    } else {
      // Format v1: restaura SOLO la página indicada desde el snapshot
      // (estilo `git checkout <rev> -- <path>`), no la libreta entera.
      try {
        final page = _pageById(pageId);
        if (page == null) return false;

        final metaPath = _pageTreePath(page.id, 'meta.json');
        final blocksPath = _pageTreePath(page.id, 'blocks.jsonl');
        final files = await _snapshotManager.extractFilesFromSnapshot(
          versionId,
          {metaPath, blocksPath},
        );
        final metaBytes = files[metaPath];
        if (metaBytes == null) return false; // la página no existía en ese snapshot

        final meta = jsonDecode(utf8.decode(metaBytes)) as Map<String, dynamic>;
        final blocks = <FolioBlock>[];
        final blocksBytes = files[blocksPath];
        if (blocksBytes != null) {
          for (final line in utf8.decode(blocksBytes).split('\n')) {
            if (line.trim().isEmpty) continue;
            try {
              blocks.add(
                FolioBlock.fromJson(
                  Map<String, dynamic>.from(jsonDecode(line)),
                ),
              );
            } catch (_) {
              // línea corrupta: se descarta, igual que en TreeToVaultPayload
            }
          }
        }

        // Snapshot de seguridad del estado actual antes de sobreescribir.
        await _createVaultSnapshotSafe(
          label: page.title.trim().isNotEmpty ? page.title.trim() : null,
          pageIdsForDedupe: [page.id],
        );

        page.title = (meta['title'] as String?) ?? page.title;
        final emojiRaw = meta['emoji'] as String?;
        page.emoji = (emojiRaw == null || emojiRaw.trim().isEmpty)
            ? null
            : emojiRaw.trim();
        page.tags = ((meta['tags'] ?? []) as List).cast<String>();
        page.properties = (meta['properties'] as List<dynamic>?)
                ?.whereType<Map>()
                .map(
                  (e) => FolioPageProperty.fromJson(
                    Map<String, dynamic>.from(e),
                  ),
                )
                .toList() ??
            [];
        if (meta['lastImportInfo'] != null) {
          final raw = meta['lastImportInfo'];
          if (raw is Map) {
            page.lastImportInfo =
                FolioPageImportInfo.fromJson(Map<String, dynamic>.from(raw));
          }
        }
        page.blocks = blocks;
        _contentEpoch++;
        _rebuildSearchIndex();
        notifyListeners();
        await persistNow();
        await _createVaultSnapshotSafe(
          label: page.title.trim().isNotEmpty ? page.title.trim() : null,
          pageIdsForDedupe: [page.id],
        );
        return true;
      } catch (e) {
        AppLogger.error('Snapshot restore failed: $e');
        return false;
      }
    }
  }

  VaultPayload _buildVaultPayloadForPersist() {
    final name = _vaultId == null
        ? ''
        : (_registry.entryFor(_vaultId!)?.displayName ?? '').trim();
    return VaultPayload(
      version: kVaultPayloadVersion,
      pages: _pages,
      displayName: name,
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
      youtrack: _youtrack,
      trello: _trello,
      github: _github,
      gitlab: _gitlab,
      slack: _slack,
      teams: _teams,
      spotify: _spotify,
      discord: _discord,
      systemMedia: _systemMedia,
      pageTombstones: Map<String, int>.from(_pageTombstones),
      syncClock: _syncClock,
      mcpReadablePageIds: Set<String>.from(_mcpReadablePageIds),
    );
  }

  Future<void> persistNow() async {
    if (_vaultFormatVersion == 0) {
      // Format v0: persist to vault.bin (existing)
      await _persistence.persistNow();
    } else {
      // Mutex: si ya hay una escritura v1 en vuelo (p. ej. una llamada suelta
      // del debounce que ya empezó), esperarla en vez de correr en paralelo
      // sobre el mismo `repo.tmp` — ver comentario en `_v1ActiveWrite`.
      while (_v1ActiveWrite != null) {
        try {
          await _v1ActiveWrite;
        } catch (_) {
          // El error pertenece a esa llamada; aquí solo esperamos turno.
        }
      }
      final write = _doPersistV1();
      _v1ActiveWrite = write;
      try {
        await write;
      } finally {
        if (identical(_v1ActiveWrite, write)) _v1ActiveWrite = null;
      }
    }
    _rebuildSearchIndex();
  }

  Future<void> _doPersistV1() async {
    // Format v1: solo árbol en repo/ (sin snapshot automático ni vault.bin).
    try {
      _v1TreeSaveTimer?.cancel();
      _v1TreeSaveTimer = null;
      final payload = _buildVaultPayloadForPersist();
      // Defensa: no persistir 0 páginas sobre un árbol que aún tiene datos
      // (p. ej. tras unlock fallido / carrera con sync headless).
      if (payload.pages.isEmpty) {
        final treeDir = await VaultPaths.vaultTreeDirectory();
        final onDisk = VaultLocalStorage.countPageDirs(treeDir);
        if (onDisk > 0) {
          AppLogger.error(
            'Blocked v1 persist of empty session over non-empty tree',
            context: {'onDiskPages': onDisk},
          );
          return;
        }
      }
      await VaultLocalStorage.decomposeAndStore(payload);
      // Nunca borrar vault.bin aquí: solo tras sync/verificación
      // (cleanupV0AfterSuccessfulSync).
    } on VaultEmptyOverwriteException catch (e) {
      AppLogger.error('Blocked empty vault tree overwrite: $e');
    } catch (e) {
      AppLogger.error('Failed to persist v1 vault: $e');
      rethrow;
    }
  }

  /// Persistencia inmediata respetando formato: v0 puede suprimir `onPersisted`
  /// (evitar bucles de sync); v1 siempre escribe solo el árbol.
  Future<void> _persistNowRespectingFormat({
    bool suppressPersistedCallback = false,
  }) async {
    if (_vaultFormatVersion == 0) {
      if (suppressPersistedCallback) {
        await _persistence.persistNowSuppressed();
      } else {
        await _persistence.persistNow();
      }
      return;
    }
    await persistNow();
  }

  /// Crea un snapshot del árbol si el contenido relevante cambió respecto
  /// al último (dedupe por hash). [label] suele ser el título de la página.
  Future<void> _createVaultSnapshotSafe({
    String? label,
    List<String>? pageIdsForDedupe,
  }) async {
    if (_vaultFormatVersion != 1) return;
    try {
      final treeDir = await VaultPaths.vaultTreeDirectory();
      if (pageIdsForDedupe != null && pageIdsForDedupe.isNotEmpty) {
        final paths = <String>{};
        for (final id in pageIdsForDedupe) {
          paths.add(_pageTreePath(id, 'meta.json'));
          paths.add(_pageTreePath(id, 'blocks.jsonl'));
        }
        if (await _snapshotManager.arePathsIdenticalToLatest(treeDir, paths)) {
          return;
        }
      } else if (await _snapshotManager.isTreeIdenticalToLatest(treeDir)) {
        return;
      }
      await _snapshotManager.createSnapshot(
        treeDir: treeDir,
        label: label,
      );
    } catch (e) {
      AppLogger.warn('Snapshot creation failed: $e');
      // Don't fail persistence
    }
  }

  void _rebuildSearchIndex() {
    if (_state != VaultFlowState.unlocked) return;
    _searchIndex.rebuildFromPages(_pages.where((p) => !p.isTrashed).toList());
    final id = _vaultId;
    if (id == null) return;
    if (_vaultUsesEncryption) {
      // Seguridad: nunca persistir el índice (títulos/fragmentos en claro)
      // de una libreta cifrada; se regenera en memoria al desbloquear.
      unawaited(VaultSearchIndex.deleteFromVault(id));
    } else {
      unawaited(_searchIndex.persistToVault(id));
    }
  }

  Future<List<int>?> exportSyncSnapshotBytes() async {
    if (_state != VaultFlowState.unlocked) return null;
    if (vaultUsesEncryption && _dek == null) return null;
    final payload = _buildVaultPayloadForPersist();
    if (kIsWeb) {
      return VaultSyncPack(
        payload: payload,
        attachments: const [],
      ).encodeUtf8();
    }
    try {
      final pack = await buildVaultSyncPackFromDisk(payload: payload);
      return pack.encodeUtf8();
    } catch (_) {
      return VaultSyncPack(
        payload: payload,
        attachments: const [],
      ).encodeUtf8();
    }
  }

  /// Aplica un pack/snapshot remoto con merge semántico (Cloud + P2P).
  /// Aplica un snapshot de sync. [changed] es true solo si el merge escribió estado local.
  Future<({bool ok, bool changed})> applySyncSnapshotBytes(
    List<int> rawBytes, [
    String fromPeerId = '',
  ]) async {
    if (_state != VaultFlowState.unlocked) {
      return (ok: false, changed: false);
    }
    if (vaultUsesEncryption && _dek == null) {
      return (ok: false, changed: false);
    }
    try {
      final pack = VaultSyncPack.decodeFlexible(rawBytes);
      await materializeVaultSyncPackAttachments(pack);

      final localPayload = _buildVaultPayloadForPersist();
      final remotePayload = pack.payload;
      final localFp = VaultSyncMergeEngine.payloadFingerprint(localPayload);
      final remoteFp = VaultSyncMergeEngine.payloadFingerprint(remotePayload);
      if (localFp == remoteFp) {
        if (_syncBaselineFingerprint.isEmpty) {
          _syncBaselineFingerprint = localFp;
          _syncBaselinePayload = VaultPayload.decodeUtf8(
            localPayload.encodeUtf8(),
          );
        }
        await _applySyncedDisplayName(remotePayload.displayName);
        return (ok: true, changed: false);
      }

      // No dejar que un remoto vacío borre contenido local vía merge (mismo
      // riesgo de wipe por sync que el camino headless, pero por la ruta de
      // sesión desbloqueada / P2P): el merge de 3 vías infiere "borrado" de
      // toda página ausente en remoto respecto al baseline, así que un
      // remoto espuriamente vacío vaciaría _pages antes de persistir. Mismo
      // guard que HeadlessDeviceSyncVault.applyRemotePack.
      if (localPayload.pages.isNotEmpty && remotePayload.pages.isEmpty) {
        AppLogger.warn(
          'applySyncSnapshotBytes skipped: refuse empty remote over local pages',
          tag: 'sync',
          context: {'localPages': localPayload.pages.length},
        );
        return (ok: true, changed: false);
      }

      final result = _syncMerge.merge(
        local: localPayload,
        remote: remotePayload,
        baseline: _syncBaselinePayload,
      );

      for (final conflict in result.blockConflicts) {
        _registerBlockSyncConflict(
          fromPeerId: fromPeerId,
          conflict: conflict,
          remoteFingerprint: remoteFp,
          remoteSnapshotBytes: rawBytes,
          remotePageCount: remotePayload.pages.length,
        );
      }

      if (!result.changed && result.blockConflicts.isEmpty) {
        return (ok: true, changed: false);
      }

      await _applyResolvedSyncPayload(
        result.payload,
        remoteFingerprint: VaultSyncMergeEngine.payloadFingerprint(
          result.payload,
        ),
        setAsBaseline: true,
      );
      return (ok: true, changed: true);
    } catch (e, st) {
      AppLogger.error(
        'applySyncSnapshotBytes failed',
        tag: 'sync',
        error: e,
        stackTrace: st,
      );
      return (ok: false, changed: false);
    }
  }

  Future<void> resolveSyncConflictKeepLocal(String conflictId) async {
    final index = _syncConflicts.indexWhere((entry) => entry.id == conflictId);
    if (index == -1) return;
    _syncConflicts.removeAt(index);
    final localSnapshot = _buildVaultPayloadForPersist();
    _syncBaselineFingerprint = VaultSyncMergeEngine.payloadFingerprint(
      localSnapshot,
    );
    _syncBaselinePayload = VaultPayload.decodeUtf8(localSnapshot.encodeUtf8());
    _notifySyncConflictCountChanged();
    await _persistSyncConflicts();
    notifyListeners();
  }

  Future<bool> resolveSyncConflictAcceptRemote(String conflictId) async {
    final index = _syncConflicts.indexWhere((entry) => entry.id == conflictId);
    if (index == -1) return false;
    final entry = _syncConflicts[index];
    try {
      if (entry.isBlockConflict &&
          entry.remoteBlockJson != null &&
          entry.pageId != null &&
          entry.blockId != null) {
        final page = _pageById(entry.pageId!);
        if (page == null) return false;
        final bi = page.blocks.indexWhere((b) => b.id == entry.blockId);
        if (bi < 0) return false;
        page.blocks[bi] = FolioBlock.fromJson(
          Map<String, dynamic>.from(entry.remoteBlockJson!),
        );
        _contentEpoch++;
        notifyListeners();
        await _persistNowRespectingFormat(suppressPersistedCallback: true);
        _rebuildSearchIndex();
        final localSnapshot = _buildVaultPayloadForPersist();
        _syncBaselineFingerprint = VaultSyncMergeEngine.payloadFingerprint(
          localSnapshot,
        );
        _syncBaselinePayload = VaultPayload.decodeUtf8(
          localSnapshot.encodeUtf8(),
        );
        _syncConflicts.removeAt(index);
        _notifySyncConflictCountChanged();
        await _persistSyncConflicts();
        notifyListeners();
        return true;
      }

      final pack = VaultSyncPack.decodeFlexible(entry.remoteSnapshotBytes);
      await materializeVaultSyncPackAttachments(pack);
      final localPayload = _buildVaultPayloadForPersist();
      if (localPayload.pages.isNotEmpty && pack.payload.pages.isEmpty) {
        AppLogger.warn(
          'resolveSyncConflictAcceptRemote skipped: remote pack empty',
          tag: 'sync',
          context: {'localPages': localPayload.pages.length},
        );
        return false;
      }
      final result = _syncMerge.merge(
        local: localPayload,
        remote: pack.payload,
        baseline: _syncBaselinePayload,
      );
      await _applyResolvedSyncPayload(
        result.payload,
        remoteFingerprint: VaultSyncMergeEngine.payloadFingerprint(
          result.payload,
        ),
        setAsBaseline: true,
      );
      _syncConflicts.removeAt(index);
      _notifySyncConflictCountChanged();
      await _persistSyncConflicts();
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Aplica texto fusionado (merge por hunks) al bloque en conflicto.
  Future<bool> resolveSyncConflictWithMergedText(
    String conflictId,
    String mergedText,
  ) async {
    final index = _syncConflicts.indexWhere((entry) => entry.id == conflictId);
    if (index == -1) return false;
    final entry = _syncConflicts[index];
    if (!entry.isBlockConflict ||
        entry.pageId == null ||
        entry.blockId == null) {
      return false;
    }
    try {
      final page = _pageById(entry.pageId!);
      if (page == null) return false;
      final bi = page.blocks.indexWhere((b) => b.id == entry.blockId);
      if (bi < 0) return false;
      final current = page.blocks[bi];
      // Preferir metadatos locales; texto fusionado; delta rich se regenera desde plain.
      current.text = mergedText;
      current.richTextDeltaJson = null;
      _contentEpoch++;
      notifyListeners();
      await _persistNowRespectingFormat(suppressPersistedCallback: true);
      _rebuildSearchIndex();
      final localSnapshot = _buildVaultPayloadForPersist();
      _syncBaselineFingerprint = VaultSyncMergeEngine.payloadFingerprint(
        localSnapshot,
      );
      _syncBaselinePayload = VaultPayload.decodeUtf8(localSnapshot.encodeUtf8());
      _syncConflicts.removeAt(index);
      _notifySyncConflictCountChanged();
      await _persistSyncConflicts();
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  void _registerBlockSyncConflict({
    required String fromPeerId,
    required VaultSyncBlockConflict conflict,
    required String remoteFingerprint,
    required List<int> remoteSnapshotBytes,
    required int remotePageCount,
  }) {
    final existing = _syncConflicts.any(
      (entry) =>
          entry.pageId == conflict.pageId &&
          entry.blockId == conflict.blockId &&
          entry.remoteFingerprint == remoteFingerprint,
    );
    if (existing) return;
    _syncConflicts.add(
      SyncConflictEntry(
        id: _uuid.v4(),
        fromPeerId: fromPeerId,
        createdAtMs: DateTime.now().millisecondsSinceEpoch,
        remoteFingerprint: remoteFingerprint,
        remoteSnapshotBytes: List<int>.from(remoteSnapshotBytes),
        remotePageCount: remotePageCount,
        pageId: conflict.pageId,
        blockId: conflict.blockId,
        remoteBlockJson: conflict.remoteBlock.toJson(),
        localBlockJson: conflict.localBlock.toJson(),
      ),
    );
    _notifySyncConflictCountChanged();
    unawaited(_persistSyncConflicts());
    notifyListeners();
  }

  Future<void> _applyResolvedSyncPayload(
    VaultPayload payload, {
    required String remoteFingerprint,
    bool setAsBaseline = true,
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
    await _applySyncedDisplayName(payload.displayName);
    notifyListeners();
    await _persistNowRespectingFormat(suppressPersistedCallback: true);
    _rebuildSearchIndex();
    if (setAsBaseline) {
      _syncBaselineFingerprint = remoteFingerprint;
      _syncBaselinePayload = VaultPayload.decodeUtf8(payload.encodeUtf8());
    }
  }

  /// Actualiza el registro local si el pack trae un nombre de libreta.
  Future<void> _applySyncedDisplayName(String raw) async {
    final name = raw.trim();
    if (name.isEmpty) return;
    final id = _vaultId;
    if (id == null || id.isEmpty) return;
    final current = _registry.entryFor(id)?.displayName.trim() ?? '';
    if (current == name) return;
    await _registry.rename(id, name);
  }

  void _notifySyncConflictCountChanged() {
    _syncPendingConflicts = _syncConflicts.length;
    try {
      onSyncConflictCountChanged?.call(_syncPendingConflicts);
    } catch (_) {
      // No bloquea flujo si falla la notificación externa.
    }
  }

  bool _dekMatchesQuickStorage(Uint8List dek) {
    if (!vaultUsesEncryption || _dek == null) return false;
    return const ListEquality<int>().equals(dek, _dek!);
  }

  /// Comprueba la contraseña contra la libreta y que coincida con la sesión abierta.
  Future<bool> verifyPasswordMatchesUnlockedSession(String password) async {
    if (_dek == null) return false;
    touchActivity();
    final throttle = UnlockAttemptThrottle();
    final vaultIdForThrottle = _vaultId ?? '';
    final wait = await throttle.remainingWait(vaultIdForThrottle);
    if (wait != null) {
      throw UnlockThrottledException(wait);
    }
    try {
      final dek = await _repo.unlockWithPassword(password);
      final matches = const ListEquality<int>().equals(dek, _dek!);
      if (matches) {
        await throttle.recordSuccess(vaultIdForThrottle);
      } else {
        await throttle.recordFailure(vaultIdForThrottle);
      }
      return matches;
    } catch (_) {
      await throttle.recordFailure(vaultIdForThrottle);
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
    _persistence.cancelPendingSave();
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
      displayName: (_registry.entryFor(_vaultId ?? '')?.displayName ?? '')
          .trim(),
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
      pageTombstones: Map<String, int>.from(_pageTombstones),
      syncClock: _syncClock,
      mcpReadablePageIds: Set<String>.from(_mcpReadablePageIds),
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
    final queryLower = query.toLowerCase().trim();
    if (_state != VaultFlowState.unlocked ||
        (vaultUsesEncryption && _dek == null) ||
        queryLower.isEmpty ||
        (!includeTitleMatches && !includeContentMatches)) {
      return const [];
    }
    touchActivity();
    if (_searchIndex.version > 0) {
      return _searchIndex.search(
        query,
        limit: limit,
        includeTitleMatches: includeTitleMatches,
        includeContentMatches: includeContentMatches,
        sortByRecency: sortByRecency,
        tasksOnly: tasksOnly,
        lastEditedMs: _pageLastEditedMs,
      );
    }

    final terms = queryLower
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();
    if (terms.isEmpty) {
      return const [];
    }

    final out = <VaultSearchResult>[];
    for (final page in _pages) {
      final pageTitle = page.title.trim().isEmpty ? 'Sin título' : page.title;
      final pageLastEditedMs = _pageLastEditedMs(page.id);
      final titleLower = pageTitle.toLowerCase();
      
      final titleMatchesAll = terms.every((t) => titleLower.contains(t));
      if (includeTitleMatches && titleMatchesAll) {
        final exactIdx = titleLower.indexOf(queryLower);
        var titleScore = 200;
        if (exactIdx >= 0) {
          titleScore += 100 + (30 - exactIdx.clamp(0, 30)) * 2;
        } else {
          var sumIdx = 0;
          for (final t in terms) {
            sumIdx += titleLower.indexOf(t).clamp(0, 200);
          }
          titleScore += 50 - (sumIdx ~/ terms.length);
        }
        if (pageTitle.length <= 42) titleScore += 15;

        out.add(
          VaultSearchResult(
            pageId: page.id,
            pageTitle: pageTitle,
            snippet: _snippetAroundMulti(pageTitle, queryLower, terms),
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

          final blockMatchesAll = terms.every((t) => haystackLower.contains(t));
          if (!blockMatchesAll) continue;

          final exactIdx = haystackLower.indexOf(queryLower);
          var contentScore = 100;
          if (exactIdx >= 0) {
            contentScore += 50 + (30 - exactIdx.clamp(0, 30));
          } else {
            var sumIdx = 0;
            for (final t in terms) {
              sumIdx += haystackLower.indexOf(t).clamp(0, 100);
            }
            contentScore += 30 - (sumIdx ~/ terms.length);
          }

          final snippet = _snippetAroundMulti(haystack, queryLower, terms);
          if (snippet.length <= 88) contentScore += 8;

          out.add(
            VaultSearchResult(
              pageId: page.id,
              pageTitle: pageTitle,
              blockId: block.id,
              blockType: block.type,
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

  /// Devuelve el id de la copia creada, o `null` si [sourcePageId] no existe
  /// (los llamadores existentes que no lo necesitan ignoran el retorno).
  String? createPageFromTemplate(String sourcePageId, {String? parentId}) {
    final src = _pageById(sourcePageId);
    if (src == null) return null;
    final id = _uuid.v4();
    final copiedBlocks = src.blocks
        .map(
          (b) => FolioBlock(
            id: '${id}_${_uuid.v4()}',
            type: b.type,
            text: b.text,
            richTextDeltaJson: b.richTextDeltaJson,
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
    _mcpReadablePageIds.add(id);
    selectPage(id);
    scheduleSave(trackRevisionForPageId: id);
    return id;
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

  String _snippetAroundMulti(String text, String queryLower, List<String> terms) {
    final clean = text.replaceAll('\n', ' ').trim();
    if (clean.isEmpty) return '';
    final lower = clean.toLowerCase();
    
    var idx = lower.indexOf(queryLower);
    var matchedLength = queryLower.length;
    
    if (idx < 0 && terms.isNotEmpty) {
      for (final term in terms) {
        final tIdx = lower.indexOf(term);
        if (tIdx >= 0) {
          idx = tIdx;
          matchedLength = term.length;
          break;
        }
      }
    }
    
    if (idx < 0) {
      return clean.length <= 96 ? clean : '${clean.substring(0, 96)}...';
    }
    
    final start = (idx - 28).clamp(0, clean.length);
    final end = (idx + matchedLength + 68).clamp(0, clean.length);
    final chunk = clean.substring(start, end).trim();
    final prefix = start > 0 ? '... ' : '';
    final suffix = end < clean.length ? ' ...' : '';
    return '$prefix$chunk$suffix';
  }

  /// Selección por defecto sin leer preferencias (p. ej. tras borrar página).
  void _pickInitialSelection() {
    final active = _pages.where((p) => !p.isTrashed).toList();
    if (active.isEmpty) {
      _selectedPageId = null;
      return;
    }
    final roots = active.where((p) => p.parentId == null).toList();
    _selectedPageId = roots.isNotEmpty ? roots.first.id : active.first.id;
  }

  /// M5: Helpers
  Future<String> _getDeviceId() async {
    try {
      return Platform.localHostname;
    } catch (_) {
      return 'unknown-device';
    }
  }

  Future<void> _triggerMigrationPrompt(String vaultId) async {
    AppLogger.info('Migration available for vault $vaultId');
    // TODO: Show migration prompt dialog
  }

  /// M5: Inicializa `_formatHandler`/`_deviceId`/`_vaultFormatVersion` para la
  /// libreta activa si aún no se ha hecho en esta sesión. Es idempotente y
  /// segura de llamar desde cualquier punto de entrada (bootstrap, unlock,
  /// creación de libreta nueva) sin depender de que otro método ya la haya
  /// inicializado antes — evita `LateInitializationError` en flujos que no
  /// pasan por [bootstrap] primero (p. ej. onboarding con una libreta nueva).
  Future<void> _ensureFormatHandlerReady() async {
    if (_formatHandlerInitialized) return;
    _deviceId = await _getDeviceId();
    _formatHandler = VaultFormatHandler(
      deviceId: _deviceId,
      onMigrationNeeded: _triggerMigrationPrompt,
    );
    _vaultFormatVersion = await _formatHandler.detectFormat();
    _formatHandlerInitialized = true;
  }

  /// M5: Garantiza que la libreta activa esté en formato v1, migrando desde
  /// v0 si hace falta (migración obligatoria en Beta). Se llama tanto desde
  /// [bootstrap] (libretas en claro) como desde los métodos de desbloqueo de
  /// libretas cifradas, para que la migración se aplique sin importar el modo
  /// de la libreta. [loadV0Payload] solo se invoca si realmente hace falta el
  /// payload v0 (evita cargarlo dos veces cuando el árbol v1 ya es válido).
  Future<VaultPayload> _ensureV1AndLoad(
    Future<VaultPayload> Function() loadV0Payload,
  ) async {
    await _ensureFormatHandlerReady();
    if (_vaultFormatVersion == 1) {
      try {
        final loaded = await _formatHandler.loadPayload(1);
        if (loaded != null) return loaded;
      } on VaultCorruptionException {
        rethrow;
      }
      // Formato marcado v1 pero el árbol no carga: no usar vault.bin obsoleto
      // en silencio (riesgo de wipe por sync). Ir a recovery; la UI ofrece
      // `.pre-migration` / `.bak` si existen.
      final hasPre = await VaultMigrationTool.hasPreMigrationBackup();
      throw VaultCorruptionException(
        hasPre
            ? 'v1 tree unreadable; pre-migration backup available'
            : 'v1 tree unreadable; no usable page tree on disk',
      );
    }

    final v0Payload = await loadV0Payload();
    AppLogger.info('Auto-migrating v0 → v1 (mandatory for Beta)');
    final migrationResult = await VaultMigrationTool.migrateVault(
      payload: v0Payload,
      deviceId: _deviceId,
    );
    if (!migrationResult.success) {
      AppLogger.error('Migration failed: ${migrationResult.error}');
      throw VaultCorruptionException(
        'Migration failed: ${migrationResult.error ?? migrationResult.message}',
      );
    }
    AppLogger.info(
      'Migration OK fingerprint=${migrationResult.contentFingerprint}',
    );
    _justMigrated = true;
    // Conservar vault.bin hasta sync/verificación externa.
    _hasV0FilesToDelete = await VaultPaths.cipherPayloadExists();
    _vaultFormatVersion = 1;
    final loaded = await _formatHandler.loadPayload(1);
    if (loaded == null) {
      throw VaultCorruptionException(
        'Migration reported success but v1 tree could not be loaded',
      );
    }
    return loaded;
  }

  /// M5: Inicializa el gestor de snapshots para la libreta activa (v1).
  Future<void> _initSnapshotManager() async {
    final vaultDir = await VaultPaths.vaultDirectory();
    _snapshotManager = VaultSnapshotManager(
      vaultDir: vaultDir,
      deviceId: _deviceId,
    );
    await _snapshotManager.init();
  }

  @override
  void dispose() {
    unawaited(MeetingNoteSessionController.instance.cancelAndTeardown());
    _notificationDispatcher.dispose();
    _persistence.dispose();
    _revisionIdleTimer?.cancel();
    _v1TreeSaveTimer?.cancel();
    _idleLockTimer?.cancel();
    super.dispose();
  }
}
