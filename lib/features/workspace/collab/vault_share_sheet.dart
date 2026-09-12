import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/ui_tokens.dart';
import '../../../config/folio_web_urls.dart';
import '../../../crypto/vault_share_crypto.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../services/folio_cloud/folio_cloud_entitlements.dart';
import '../../../services/folio_cloud/folio_cloud_identity.dart';
import '../../../services/folio_cloud/folio_cloud_vault_share.dart';
import '../../../session/vault_session.dart';

/// Sheet para compartir la libreta activa: enlace público vivo + invitar editor.
Future<void> showVaultShareSheet({
  required BuildContext context,
  required VaultSession session,
  FolioCloudSnapshot? entitlements,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) {
      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: VaultShareSheet(
          session: session,
          entitlements: entitlements,
        ),
      );
    },
  );
}

class VaultShareSheet extends StatefulWidget {
  const VaultShareSheet({
    super.key,
    required this.session,
    this.entitlements,
  });

  final VaultSession session;
  final FolioCloudSnapshot? entitlements;

  @override
  State<VaultShareSheet> createState() => _VaultShareSheetState();
}

class _VaultShareSheetState extends State<VaultShareSheet> {
  bool _loading = true;
  bool _busy = false;
  String? _error;
  VaultPublicShareState? _public;
  final _emailCtrl = TextEditingController();
  final _acceptIdCtrl = TextEditingController();
  final _acceptCodeCtrl = TextEditingController();
  List<Map<String, dynamic>> _members = const [];
  String? _lastInviteCode;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _acceptIdCtrl.dispose();
    _acceptCodeCtrl.dispose();
    super.dispose();
  }

  String _displayPublicUrl(VaultPublicShareState state) {
    return FolioWebUrls.resolveVaultPublicShareUrl(
      token: state.token,
      publicUrlFromApi: state.publicUrl,
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final vaultId = widget.session.vaultId;
      if (vaultId == null || vaultId.isEmpty) {
        throw StateError('No hay libreta activa');
      }
      final pub = await fetchVaultPublicShareMine(vaultId);
      List<Map<String, dynamic>> members = const [];
      try {
        members = await listVaultMembers(vaultId);
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _public = pub;
        _members = members;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _run(Future<void> Function() fn) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await fn();
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _enablePublic() async {
    await _run(() async {
      final vaultId = widget.session.vaultId!;
      final name = widget.session.vaultDisplayName;
      final enabled = await enableVaultPublicShare(
        vaultId: vaultId,
        displayName: name,
        entitlements: widget.entitlements,
      );
      final uid = folioCloudCurrentUid();
      if (uid == null || uid.isEmpty) {
        throw StateError('Not signed in');
      }
      final pack = buildVaultPublicViewPack(
        vaultId: vaultId,
        displayName: name,
        pages: widget.session.pages,
      );
      final updated = await publishVaultPublicViewContent(
        vaultId: vaultId,
        ownerUid: uid,
        viewPack: pack,
      );
      if (!mounted) return;
      setState(() => _public = updated.publicUrl != null ? updated : enabled);
      await _refresh();
    });
  }

  Future<void> _revokePublic() async {
    await _run(() async {
      await revokeVaultPublicShare(widget.session.vaultId!);
      await _refresh();
    });
  }

  Future<void> _publishNow() async {
    await _run(() async {
      final vaultId = widget.session.vaultId!;
      final uid = folioCloudCurrentUid();
      if (uid == null || uid.isEmpty) throw StateError('Not signed in');
      await syncVaultPublicViewIfEnabled(
        vaultId: vaultId,
        ownerUid: uid,
        displayName: widget.session.vaultDisplayName,
        pages: widget.session.pages,
        entitlements: widget.entitlements,
      );
      await _refresh();
    });
  }

  Future<void> _invite() async {
    await _run(() async {
      final email = _emailCtrl.text.trim();
      if (email.isEmpty || !email.contains('@')) {
        throw StateError('Introduce un correo válido');
      }
      final vaultId = widget.session.vaultId!;
      final uid = folioCloudCurrentUid();
      if (uid == null || uid.isEmpty) throw StateError('Not signed in');
      final keyBytes = await widget.session.exportSyncKeyBytesForSharing();
      final result = await inviteVaultMember(
        vaultId: vaultId,
        email: email,
        displayName: widget.session.vaultDisplayName,
        syncKeyBytes: keyBytes,
        ownerUid: uid,
      );
      if (!mounted) return;
      setState(() => _lastInviteCode = result.shareCode);
      _emailCtrl.clear();
      await Clipboard.setData(ClipboardData(text: result.shareCode));
      await _refresh();
    });
  }

  Future<void> _acceptInvite() async {
    await _run(() async {
      final id = _acceptIdCtrl.text.trim();
      final code = VaultShareCrypto.normalizeShareCode(_acceptCodeCtrl.text);
      if (id.isEmpty || code.isEmpty) {
        throw StateError('Faltan el id de invitación o el código');
      }
      final accepted = await acceptVaultShare(shareId: id, shareCode: code);
      await widget.session.materializeSharedVaultFromAccept(accepted, shareCode: code);
      if (!mounted) return;
      Navigator.of(context).maybePop();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final entry = widget.session.vaultId == null
        ? null
        : widget.session.registryEntryForActive();
    final isShared = entry?.isShared == true;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          FolioSpace.lg,
          FolioSpace.sm,
          FolioSpace.lg,
          FolioSpace.xl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.shareNotebookTooltip,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: FolioSpace.xs),
            Text(
              isShared
                  ? 'Esta libreta te la han compartido. Puedes editarla, pero no eliminarla.'
                  : 'Enlace público (solo lectura, se actualiza solo) o invita a alguien a editar.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
            if (_error != null) ...[
              const SizedBox(height: FolioSpace.sm),
              Text(_error!, style: TextStyle(color: scheme.error)),
            ],
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(FolioSpace.lg),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              if (!isShared) ...[
                const SizedBox(height: FolioSpace.lg),
                Text(l10n.vaultSharePublicLink, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: FolioSpace.xs),
                Text(
                  l10n.vaultSharePublicLinkBody,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: FolioSpace.sm),
                if (_public?.enabled == true) ...[
                  SelectableText(
                    _displayPublicUrl(_public!),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: FolioSpace.sm),
                  Wrap(
                    spacing: FolioSpace.sm,
                    runSpacing: FolioSpace.sm,
                    children: [
                      FilledButton.tonal(
                        onPressed: _busy
                            ? null
                            : () async {
                                final url = _displayPublicUrl(_public!);
                                if (url.isEmpty) return;
                                await Clipboard.setData(ClipboardData(text: url));
                              },
                        child: Text(l10n.vaultShareCopyLink),
                      ),
                      OutlinedButton(
                        onPressed: _busy ? null : _publishNow,
                        child: Text(l10n.vaultShareRefreshNow),
                      ),
                      TextButton(
                        onPressed: _busy ? null : _revokePublic,
                        child: Text(l10n.revoke, style: TextStyle(color: scheme.error)),
                      ),
                    ],
                  ),
                  Text(
                    l10n.vaultShareActiveRev('${_public?.rev ?? 0}'),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                ] else
                  FilledButton(
                    onPressed: _busy ? null : _enablePublic,
                    child: Text(l10n.vaultShareEnablePublicLink),
                  ),
                const SizedBox(height: FolioSpace.xl),
                Text(l10n.vaultShareInviteToEdit, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: FolioSpace.xs),
                Text(
                  l10n.vaultShareInviteBody,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: FolioSpace.sm),
                TextField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: l10n.vaultShareCloudEmail,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: FolioSpace.sm),
                FilledButton.tonal(
                  onPressed: _busy ? null : _invite,
                  child: Text(l10n.vaultShareInvite),
                ),
                if (_lastInviteCode != null) ...[
                  const SizedBox(height: FolioSpace.sm),
                  Text(
                    l10n.vaultShareInviteCodeAlsoEmail(_lastInviteCode!),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
                if (_members.isNotEmpty) ...[
                  const SizedBox(height: FolioSpace.md),
                  Text(l10n.vaultShareMembers, style: Theme.of(context).textTheme.titleSmall),
                  ..._members.map((m) {
                    final email = '${m['inviteEmail'] ?? ''}';
                    final status = '${m['status'] ?? ''}';
                    final id = '${m['id'] ?? ''}';
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(email),
                      subtitle: Text(status),
                      trailing: status == 'revoked'
                          ? null
                          : IconButton(
                              tooltip: l10n.remove,
                              onPressed: _busy
                                  ? null
                                  : () => _run(() async {
                                        await removeVaultMember(
                                          vaultId: widget.session.vaultId!,
                                          membershipId: id,
                                        );
                                        await _refresh();
                                      }),
                              icon: const Icon(Icons.person_remove_outlined),
                            ),
                    );
                  }),
                ],
              ],
              const SizedBox(height: FolioSpace.xl),
              Text(l10n.vaultShareAcceptInvite, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: FolioSpace.sm),
              TextField(
                controller: _acceptIdCtrl,
                decoration: InputDecoration(
                  labelText: l10n.vaultShareInviteId,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: FolioSpace.sm),
              TextField(
                controller: _acceptCodeCtrl,
                decoration: InputDecoration(
                  labelText: l10n.vaultShareInviteCode,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: FolioSpace.sm),
              OutlinedButton(
                onPressed: _busy ? null : _acceptInvite,
                child: Text(l10n.vaultShareAccept),
              ),
              if (isShared) ...[
                const SizedBox(height: FolioSpace.xl),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => _run(() async {
                            final owner = entry?.ownerUid;
                            if (owner == null || owner.isEmpty) {
                              throw StateError('Falta ownerUid');
                            }
                            await leaveSharedVault(
                              vaultId: widget.session.vaultId!,
                              ownerUid: owner,
                            );
                            await widget.session.leaveSharedVaultLocal();
                            if (context.mounted) Navigator.of(context).maybePop();
                          }),
                  child: Text(
                    'Abandonar libreta',
                    style: TextStyle(color: scheme.error),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
