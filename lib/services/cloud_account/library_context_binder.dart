import '../../data/vault_paths.dart';
import '../../data/vault_registry.dart';
import '../../session/vault_session.dart';
import '../app_logger.dart';
import '../folio_cloud/folio_cloud_identity.dart';
import '../folio_cloud/folio_cloud_organizations.dart';
import 'cloud_account_controller.dart';
import 'organization_context_controller.dart';

/// Aplica las tres capas de contexto (cuenta → equipo → biblioteca).
///
/// Personal: solo vaults sin organizationId de la cuenta activa.
/// Equipo: materializa OrganizationWorkspaces como VaultEntry locales y oculta
/// las libretas personales.
class LibraryContextBinder {
  LibraryContextBinder._();

  static Future<void> apply({
    required CloudAccountController account,
    OrganizationContextController? organizationContext,
    VaultSession? session,
  }) async {
    final uid = account.uid ?? folioCloudCurrentUid();
    final active = organizationContext?.activeOrganization;
    final orgId = (active != null && !active.isPersonal) ? active.id : null;

    await VaultRegistry.instance.bindContext(
      accountUid: uid,
      organizationId: orgId,
    );

    if (uid != null && orgId != null) {
      await _syncTeamWorkspaces(
        accountUid: uid,
        organizationId: orgId,
      );
      await VaultRegistry.instance.bindContext(
        accountUid: uid,
        organizationId: orgId,
      );
    }

    if (session != null) {
      await _ensureActiveVaultInContext(session);
    }

    AppLogger.info(
      'library context applied',
      tag: 'org',
      context: {
        'accountUid': uid,
        'organizationId': orgId,
        'vaultCount': VaultRegistry.instance.vaults.length,
      },
    );
  }

  static Future<void> _syncTeamWorkspaces({
    required String accountUid,
    required String organizationId,
  }) async {
    try {
      final workspaces = await fetchOrganizationWorkspaces(organizationId);
      for (final ws in workspaces) {
        if (ws.archivedAt != null) continue;
        final existing = VaultRegistry.instance.entryFor(ws.id);
        final entry = VaultEntry(
          id: ws.id,
          displayName: ws.name,
          createdAtMs: ws.createdAt?.millisecondsSinceEpoch ??
              DateTime.now().millisecondsSinceEpoch,
          accountUid: accountUid,
          organizationId: organizationId,
          workspaceId: ws.id,
        );
        if (existing == null) {
          await VaultPaths.initVaultStorage(ws.id);
          await VaultRegistry.instance.add(entry);
        } else if (existing.displayName != ws.name ||
            existing.organizationId != organizationId ||
            existing.accountUid != accountUid) {
          await VaultRegistry.instance.upsert(
            existing.copyWith(
              displayName: ws.name,
              accountUid: accountUid,
              organizationId: organizationId,
              workspaceId: ws.id,
            ),
          );
        }
      }
    } catch (e, st) {
      AppLogger.warn(
        'sync team workspaces failed',
        tag: 'org',
        context: {'error': '$e', 'stack': '$st', 'orgId': organizationId},
      );
    }
  }

  static Future<void> _ensureActiveVaultInContext(VaultSession session) async {
    final vaults = VaultRegistry.instance.vaults;
    final activeId =
        session.activeVaultId ?? VaultRegistry.instance.activeVaultId;
    final stillValid =
        activeId != null && vaults.any((v) => v.id == activeId);
    if (stillValid) {
      if (VaultRegistry.instance.activeVaultId != activeId) {
        await VaultRegistry.instance.setActiveVaultId(activeId);
      }
      return;
    }
    if (vaults.isEmpty) {
      await VaultRegistry.instance.setActiveVaultId(null);
      return;
    }
    final next = vaults.first.id;
    await VaultRegistry.instance.setActiveVaultId(next);
    try {
      await session.switchVault(next);
    } catch (e, st) {
      AppLogger.warn(
        'switch vault after context change failed',
        tag: 'org',
        context: {'error': '$e', 'stack': '$st', 'vaultId': next},
      );
    }
  }
}
