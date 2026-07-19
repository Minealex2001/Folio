import '../../data/vault_payload.dart';
import '../../models/folio_page.dart';
import '../../models/jira_integration_state.dart';
import '../../models/youtrack_integration_state.dart';

/// Migra un [VaultPayload] leído de disco a [kVaultPayloadVersion].
VaultPayload migrateVaultPayload(VaultPayload raw) {
  if (raw.version >= kVaultPayloadVersion) {
    return raw;
  }
  var pages = raw.pages;
  var pageOrder = raw.pageOrderByParent;
  var pageRevisions = raw.pageRevisions;
  var pageAcl = raw.pageAcl;
  var localProfiles = raw.localProfiles;
  var comments = raw.comments;
  var aiChatThreads = raw.aiChatThreads;
  var aiActiveChatIndex = raw.aiActiveChatIndex;
  var pageTemplates = raw.pageTemplates;
  var jira = raw.jira;
  var youtrack = raw.youtrack;

  // v1–v3: sin campos adicionales obligatorios; fromJson ya aplica defaults.
  // v4: chats de IA.
  if (raw.version < 4) {
    if (aiChatThreads.isEmpty) {
      aiChatThreads = const [];
      aiActiveChatIndex = 0;
    }
  }
  // v5: comentarios collab y collabRoomId en páginas (opcional en FolioPage).
  if (raw.version < 5) {
    comments = comments.isEmpty ? const [] : comments;
  }
  // v6: orden del árbol por parentId.
  if (raw.version < 6) {
    if (pageOrder.isEmpty && pages.isNotEmpty) {
      pageOrder = _buildDefaultPageOrder(pages);
    }
  }
  // v7: integraciones Jira / YouTrack.
  if (raw.version < 7) {
    jira = jira.connections.isEmpty && jira.sources.isEmpty
        ? JiraIntegrationState.empty
        : jira;
    youtrack =
        youtrack.connections.isEmpty && youtrack.sources.isEmpty
        ? YouTrackIntegrationState.empty
        : youtrack;
  }

  return VaultPayload(
    version: kVaultPayloadVersion,
    pages: pages,
    displayName: raw.displayName,
    pageOrderByParent: pageOrder,
    pageRevisions: pageRevisions,
    pageAcl: pageAcl,
    localProfiles: localProfiles,
    comments: comments,
    aiChatThreads: aiChatThreads,
    aiActiveChatIndex: aiActiveChatIndex,
    pageTemplates: pageTemplates,
    jira: jira,
    youtrack: youtrack,
    trello: raw.trello,
    pageTombstones: raw.pageTombstones,
    syncClock: raw.syncClock,
    mcpReadablePageIds: raw.mcpReadablePageIds,
  );
}

Map<String, List<String>> _buildDefaultPageOrder(List<FolioPage> pages) {
  final order = <String, List<String>>{};
  for (final page in pages) {
    final key = page.parentId ?? '';
    order.putIfAbsent(key, () => <String>[]).add(page.id);
  }
  return order;
}
