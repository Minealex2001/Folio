/// Mapeo callable Firebase → ruta REST Spring Boot (`/api/v1/...`).
///
/// El body del callable (`request.data`) se envía como JSON del POST/PATCH;
/// la respuesta es el JSON directo del endpoint (sin envelope `{result}`).
class FolioSpringApiRoute {
  const FolioSpringApiRoute({
    required this.method,
    required this.pathBuilder,
    this.omitBody = false,
    this.requiresAuth = true,
  });

  /// `GET` | `POST` | `PATCH` | `PUT` | `DELETE`
  final String method;

  /// Construye el path relativo a `/api/v1` (sin barra inicial obligatoria).
  final String Function(Map<String, dynamic> params) pathBuilder;

  /// Si true, no se envía body (p. ej. GET o POST vacíos).
  final bool omitBody;

  /// Si false, se puede llamar sin JWT (endpoints públicos del SecurityConfig).
  final bool requiresAuth;
}

/// Rutas conocidas. Callables sin entrada → [resolveFolioSpringApiRoute] = null.
final Map<String, FolioSpringApiRoute> kFolioSpringCallableRoutes =
    <String, FolioSpringApiRoute>{
  // Account
  'ensureUserDocExists': FolioSpringApiRoute(
    method: 'POST',
    pathBuilder: (_) => 'account/ensure',
    omitBody: true,
  ),
  'updateAccountDisplayName': FolioSpringApiRoute(
    method: 'PATCH',
    pathBuilder: (_) => 'account/display-name',
  ),
  'requestAccountDeletion': FolioSpringApiRoute(
    method: 'POST',
    pathBuilder: (_) => 'account/deletion/request',
    omitBody: true,
  ),
  'cancelAccountDeletion': FolioSpringApiRoute(
    method: 'POST',
    pathBuilder: (_) => 'account/deletion/cancel',
    omitBody: true,
  ),
  'exportAccountData': FolioSpringApiRoute(
    method: 'GET',
    pathBuilder: (_) => 'account/export',
    omitBody: true,
  ),

  // Billing
  'createCheckoutSession': FolioSpringApiRoute(
    method: 'POST',
    pathBuilder: (_) => 'billing/checkout-session',
  ),
  'createBillingPortalSession': FolioSpringApiRoute(
    method: 'POST',
    pathBuilder: (_) => 'billing/portal-session',
  ),
  'syncFolioCloudSubscriptionFromStripe': FolioSpringApiRoute(
    method: 'POST',
    pathBuilder: (_) => 'billing/sync',
  ),
  'folioCloudCatalogPrices': FolioSpringApiRoute(
    method: 'POST',
    pathBuilder: (_) => 'billing/catalog-prices',
    requiresAuth: false,
  ),
  'validateMicrosoftStoreEntitlements': FolioSpringApiRoute(
    method: 'POST',
    pathBuilder: (_) => 'billing/microsoft-store/validate',
  ),

  // Family
  'inviteFamilyMember': FolioSpringApiRoute(
    method: 'POST',
    pathBuilder: (_) => 'family/invite',
  ),
  'removeFamilyMember': FolioSpringApiRoute(
    method: 'POST',
    pathBuilder: (_) => 'family/remove',
  ),
  'getFamilyDetails': FolioSpringApiRoute(
    method: 'GET',
    pathBuilder: (_) => 'family/details',
    omitBody: true,
  ),
  'verifyStudentStatus': FolioSpringApiRoute(
    method: 'POST',
    pathBuilder: (_) => 'family/verify-student',
  ),

  // AI
  'folioCloudAiPricing': FolioSpringApiRoute(
    method: 'GET',
    pathBuilder: (_) => 'ai/pricing',
    omitBody: true,
  ),
  'folioCloudAiComplete': FolioSpringApiRoute(
    method: 'POST',
    pathBuilder: (_) => 'ai/complete',
  ),
  'folioCloudAiCompleteHttp': FolioSpringApiRoute(
    method: 'POST',
    pathBuilder: (_) => 'ai/complete',
  ),
  'folioCloudGenerateImage': FolioSpringApiRoute(
    method: 'POST',
    pathBuilder: (_) => 'ai/generate-image',
  ),
  'folioCloudTranscribeChunk': FolioSpringApiRoute(
    method: 'POST',
    pathBuilder: (_) => 'ai/transcribe',
  ),
  'folioCloudTranscribeStart': FolioSpringApiRoute(
    method: 'POST',
    pathBuilder: (_) => 'ai/transcribe-async',
  ),
  'folioCloudTranscribeStatus': FolioSpringApiRoute(
    method: 'GET',
    pathBuilder: (p) => 'ai/transcribe-async/${_req(p, 'jobId')}',
    omitBody: true,
  ),

  // Vault backups
  'folioFinalizeCloudPack': FolioSpringApiRoute(
    method: 'POST',
    pathBuilder: (_) => 'vault/backups/cloud-pack/finalize',
  ),
  'folioGetLatestCloudPackMeta': FolioSpringApiRoute(
    method: 'POST',
    pathBuilder: (_) => 'vault/backups/cloud-pack/latest-meta',
  ),
  'folioGetCloudPackRestoreWrap': FolioSpringApiRoute(
    method: 'POST',
    pathBuilder: (_) => 'vault/backups/cloud-pack/restore-wrap',
  ),
  'folioCheckCloudPackBlobsExist': FolioSpringApiRoute(
    method: 'POST',
    pathBuilder: (_) => 'vault/backups/cloud-pack/blobs-exist',
  ),
  'folioDeleteVaultCloudPack': FolioSpringApiRoute(
    method: 'POST',
    pathBuilder: (_) => 'vault/backups/cloud-pack/delete',
  ),
  'folioDeleteVaultLegacyBackup': FolioSpringApiRoute(
    method: 'POST',
    pathBuilder: (_) => 'vault/backups/legacy/delete',
  ),
  'folioGetBackupStorageUsage': FolioSpringApiRoute(
    method: 'POST',
    pathBuilder: (_) => 'vault/backups/usage',
    omitBody: true,
  ),
  'folioListVaultBackups': FolioSpringApiRoute(
    method: 'POST',
    pathBuilder: (_) => 'vault/backups/list',
  ),
  'folioTrimVaultBackups': FolioSpringApiRoute(
    method: 'POST',
    pathBuilder: (_) => 'vault/backups/trim',
  ),
  'folioTrimVaultBackupsByBytes': FolioSpringApiRoute(
    method: 'POST',
    pathBuilder: (_) => 'vault/backups/trim-by-bytes',
  ),
  'folioListBackupVaults': FolioSpringApiRoute(
    method: 'POST',
    pathBuilder: (_) => 'vault/backups/vaults',
    omitBody: true,
  ),
  'folioUpsertVaultBackupIndex': FolioSpringApiRoute(
    method: 'POST',
    pathBuilder: (_) => 'vault/backups/index/upsert',
  ),
  'folioGetLatestVaultBackupMeta': FolioSpringApiRoute(
    method: 'POST',
    pathBuilder: (_) => 'vault/backups/latest-meta',
  ),
  'folioRecordVaultBackupMeta': FolioSpringApiRoute(
    method: 'POST',
    pathBuilder: (_) => 'vault/backups/record-meta',
  ),

  // Device sync
  'folioGetDeviceSyncMeta': FolioSpringApiRoute(
    method: 'POST',
    pathBuilder: (_) => 'vault/device-sync/meta',
  ),
  'folioFinalizeDeviceSync': FolioSpringApiRoute(
    method: 'POST',
    pathBuilder: (_) => 'vault/device-sync/finalize',
  ),
  'folioListDeviceSyncVaults': FolioSpringApiRoute(
    method: 'POST',
    pathBuilder: (_) => 'vault/device-sync/vaults',
    omitBody: true,
  ),
  'folioEnsurePlainVaultSyncSecret': FolioSpringApiRoute(
    method: 'POST',
    pathBuilder: (_) => 'vault/device-sync/plain-secret/ensure',
  ),
  'folioTrashDeviceSyncVault': FolioSpringApiRoute(
    method: 'POST',
    pathBuilder: (_) => 'vault/device-sync/trash',
  ),
  'folioRestoreDeviceSyncVault': FolioSpringApiRoute(
    method: 'POST',
    pathBuilder: (_) => 'vault/device-sync/restore',
  ),
  'folioPurgeDeviceSyncVault': FolioSpringApiRoute(
    method: 'POST',
    pathBuilder: (_) => 'vault/device-sync/purge',
  ),

  // Profiles
  'folioGetAppProfileMeta': FolioSpringApiRoute(
    method: 'POST',
    pathBuilder: (_) => 'vault/profiles/app/meta',
    omitBody: true,
  ),
  'folioGetAppProfileRestoreWrap': FolioSpringApiRoute(
    method: 'POST',
    pathBuilder: (_) => 'vault/profiles/app/restore-wrap',
    omitBody: true,
  ),
  'folioFinalizeAppProfile': FolioSpringApiRoute(
    method: 'POST',
    pathBuilder: (_) => 'vault/profiles/app/finalize',
  ),
  'folioGetVaultProfileMeta': FolioSpringApiRoute(
    method: 'POST',
    pathBuilder: (_) => 'vault/profiles/vault/meta',
  ),
  'folioFinalizeVaultProfile': FolioSpringApiRoute(
    method: 'POST',
    pathBuilder: (_) => 'vault/profiles/vault/finalize',
  ),

  // Collab control-plane
  'createCollabRoom': FolioSpringApiRoute(
    method: 'POST',
    pathBuilder: (_) => 'collab/rooms',
  ),
  'joinCollabRoomByCode': FolioSpringApiRoute(
    method: 'POST',
    pathBuilder: (_) => 'collab/rooms/join',
  ),
  'inviteCollabMember': FolioSpringApiRoute(
    method: 'POST',
    pathBuilder: (p) => 'collab/rooms/${_req(p, 'roomId')}/invite',
  ),
  'removeCollabMember': FolioSpringApiRoute(
    method: 'POST',
    pathBuilder: (p) => 'collab/rooms/${_req(p, 'roomId')}/remove-member',
  ),
  'closeCollabRoom': FolioSpringApiRoute(
    method: 'POST',
    pathBuilder: (p) => 'collab/rooms/${_req(p, 'roomId')}/close',
    omitBody: true,
  ),
  'prepareCollabMediaUpload': FolioSpringApiRoute(
    method: 'POST',
    pathBuilder: (p) => 'collab/rooms/${_req(p, 'roomId')}/media/prepare',
  ),
  'commitCollabMediaUpload': FolioSpringApiRoute(
    method: 'POST',
    pathBuilder: (p) => 'collab/rooms/${_req(p, 'roomId')}/media/commit',
  ),

  // Integrations
  'folioUpsertIntegrationWebhookConnection': FolioSpringApiRoute(
    method: 'POST',
    pathBuilder: (_) => 'integrations/webhook-connection',
  ),
  'folioIntegrationWebhookProxy': FolioSpringApiRoute(
    method: 'POST',
    pathBuilder: (_) => 'integrations/webhook-proxy',
  ),
  'folioEnqueueIntegrationNotification': FolioSpringApiRoute(
    method: 'POST',
    pathBuilder: (_) => 'integrations/notifications/enqueue',
  ),
  'folioRegisterIntegrationLinkCode': FolioSpringApiRoute(
    method: 'POST',
    pathBuilder: (_) => 'integrations/link-code',
  ),
  'folioListPendingIntegrationCommands': FolioSpringApiRoute(
    method: 'POST',
    pathBuilder: (_) => 'integrations/pending-commands',
  ),
  'folioAckIntegrationCommand': FolioSpringApiRoute(
    method: 'POST',
    pathBuilder: (_) => 'integrations/ack-command',
  ),
  'folioSlackExchangeOAuth': FolioSpringApiRoute(
    method: 'POST',
    pathBuilder: (_) => 'integrations/slack/oauth-exchange',
  ),
  'folioTeamsExchangeOAuth': FolioSpringApiRoute(
    method: 'POST',
    pathBuilder: (_) => 'integrations/teams/oauth-exchange',
  ),
  'folioJiraExchangeOAuth': FolioSpringApiRoute(
    method: 'POST',
    pathBuilder: (_) => 'integrations/jira/oauth-exchange',
    requiresAuth: false,
  ),
  'folioSpotifyExchangeOAuth': FolioSpringApiRoute(
    method: 'POST',
    pathBuilder: (_) => 'integrations/spotify/oauth-exchange',
  ),
  'folioSpotifyApiProxy': FolioSpringApiRoute(
    method: 'POST',
    pathBuilder: (_) => 'integrations/spotify/api-proxy',
  ),

  // Diagnostics
  'folioReportDiagnostic': FolioSpringApiRoute(
    method: 'POST',
    pathBuilder: (_) => 'diagnostics/report',
    requiresAuth: false,
  ),
};

String _req(Map<String, dynamic> p, String key) {
  final v = p[key]?.toString().trim() ?? '';
  if (v.isEmpty) {
    throw ArgumentError('Spring route requires param "$key"');
  }
  return Uri.encodeComponent(v);
}

FolioSpringApiRoute? resolveFolioSpringApiRoute(String callableName) {
  return kFolioSpringCallableRoutes[callableName];
}

/// Callables sin puerto REST todavía (siguen en Firebase o quedan pendientes).
const Set<String> kFolioSpringPendingCallables = <String>{};
