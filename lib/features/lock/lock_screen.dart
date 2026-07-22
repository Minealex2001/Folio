import 'dart:async';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:passkeys/exceptions.dart';

import '../../app/app_settings.dart';
import '../../app/widgets/folio_password_field.dart';
import '../../app/ui_tokens.dart';
import '../../data/vault_registry.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../services/unlock_attempt_throttle.dart';
import '../../session/vault_session.dart';

class LockScreen extends StatefulWidget {
  const LockScreen({super.key, required this.session, required this.appSettings});

  final VaultSession session;
  final AppSettings appSettings;

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final _password = TextEditingController();
  var _busy = false;
  var _obscurePassword = true;
  String? _error;
  var _quickEnabled = false;
  var _passkeyRegistered = false;
  var _switchingVault = false;
  List<VaultEntry> _vaults = const [];
  String? _activeVaultId;

  @override
  void initState() {
    super.initState();
    _vaults = VaultRegistry.instance.vaults;
    _activeVaultId = VaultRegistry.instance.activeVaultId;
    _refreshFlags();
  }

  Future<void> _refreshFlags() async {
    final q = await widget.session.quickUnlockEnabled;
    final p = await widget.session.hasPasskey;
    if (mounted) {
      setState(() {
        _quickEnabled = q;
        _passkeyRegistered = p;
      });
      await _maybeOfferInitialQuickUnlock(q, p);
    }
  }

  Future<void> _switchVault(String vaultId) async {
    if (vaultId == _activeVaultId || _busy || _switchingVault) return;
    setState(() {
      _switchingVault = true;
      _error = null;
    });
    try {
      await widget.session.switchVault(vaultId);
    } finally {
      if (mounted) {
        setState(() => _switchingVault = false);
      }
    }
  }

  /// Primera vez que se muestra el bloqueo con Hello o passkey: lanza el flujo nativo sin pulsar el botón.
  Future<void> _maybeOfferInitialQuickUnlock(bool quick, bool passkey) async {
    if (!mounted) return;
    if (widget.appSettings.lockScreenAutoQuickUnlockDone) return;
    if (!quick && !passkey) return;
    // En Windows, abrir WebAuthn automáticamente al mostrar el bloqueo ha provocado
    // cierres del proceso en algunos equipos. Hello puede seguir ofreciéndose en auto
    // si está activo; la passkey sigue en el botón.
    final windowsNoAutoPasskey =
        !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.windows &&
        passkey &&
        !quick;
    if (windowsNoAutoPasskey) {
      await widget.appSettings.setLockScreenAutoQuickUnlockDone();
      return;
    }
    await widget.appSettings.setLockScreenAutoQuickUnlockDone();
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _busy) return;
      if (quick) {
        unawaited(_unlockDevice());
      } else if (passkey) {
        unawaited(_unlockPasskey());
      }
    });
  }

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _unlockPassword() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.session.unlockWithPassword(_password.text);
    } on UnlockThrottledException catch (e) {
      final seconds = (e.retryAfter.inMilliseconds / 1000).ceil();
      setState(() {
        _error = '${AppLocalizations.of(context).cloudAuthErrorTooManyRequests} (${seconds}s)';
        _busy = false;
      });
    } catch (e) {
      setState(() {
        _error = AppLocalizations.of(context).unlockFailed;
        _busy = false;
      });
    }
  }

  Future<void> _unlockDevice() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.session.unlockWithDeviceAuth();
    } catch (e) {
      setState(() {
        _error = '$e';
        _busy = false;
      });
    }
  }

  Future<void> _unlockPasskey() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.session.unlockWithPasskey();
    } on PasskeyAuthCancelledException {
      setState(() => _busy = false);
    } catch (e) {
      setState(() {
        _error = '$e';
        _busy = false;
      });
    }
  }

  Widget _buildVaultSelector(BuildContext context) {
    if (_vaults.length <= 1) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    VaultEntry? current;
    for (final e in _vaults) {
      if (e.id == _activeVaultId) {
        current = e;
        break;
      }
    }
    current ??= _vaults.first;
    return Padding(
      padding: const EdgeInsets.only(bottom: FolioSpace.lg),
      child: Center(
        child: PopupMenuButton<String>(
          enabled: !_busy && !_switchingVault,
          tooltip: l10n.switchVaultTooltip,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(FolioRadius.md),
          ),
          onSelected: _switchVault,
          itemBuilder: (ctx) => [
            for (final e in _vaults)
              PopupMenuItem(
                value: e.id,
                child: ListTile(
                  leading: const Icon(Icons.lock_outline_rounded),
                  title: Text(e.displayName),
                  trailing: e.id == _activeVaultId
                      ? const Icon(Icons.check_rounded)
                      : null,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
          ],
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: FolioSpace.md,
              vertical: FolioSpace.xs,
            ),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: scheme.outlineVariant.withValues(
                  alpha: FolioAlpha.border,
                ),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.menu_book_rounded,
                  size: 16,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: FolioSpace.xs),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 180),
                  child: Text(
                    current.displayName,
                    style: textTheme.labelLarge?.copyWith(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: FolioSpace.xs),
                Icon(
                  Icons.unfold_more_rounded,
                  size: 16,
                  color: scheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final formCard = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 430),
      child: Card.filled(
        margin: const EdgeInsets.all(FolioSpace.lg),
        color: scheme.surface,
        elevation: FolioElevation.none,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FolioRadius.xxl),
        ),
        child: Padding(
          padding: const EdgeInsets.all(FolioSpace.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildVaultSelector(context),
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(FolioRadius.lg),
                ),
                child: Icon(
                  Icons.lock_outline_rounded,
                  size: 28,
                  color: scheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: FolioSpace.md),
              Text(
                'Folio',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: FolioSpace.xs),
              Text(
                l10n.encryptedVault,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: FolioSpace.xl),
              FolioPasswordField(
                controller: _password,
                obscureText: _obscurePassword,
                enabled: !_busy,
                labelText: l10n.passwordLabel,
                showPasswordTooltip: l10n.showPassword,
                hidePasswordTooltip: l10n.hidePassword,
                onToggleObscure: () {
                  setState(() => _obscurePassword = !_obscurePassword);
                },
                onSubmitted: (_) => _unlockPassword(),
              ),
              const SizedBox(height: FolioSpace.lg),
              FilledButton(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.all(FolioSpace.md),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(FolioRadius.lg),
                  ),
                ),
                onPressed: _busy ? null : _unlockPassword,
                child: Text(l10n.unlock),
              ),
              if (!kIsWeb && _quickEnabled) ...[
                const SizedBox(height: FolioSpace.md),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.all(FolioSpace.md),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(FolioRadius.lg),
                    ),
                  ),
                  onPressed: _busy ? null : _unlockDevice,
                  icon: const Icon(Icons.fingerprint),
                  label: Text(l10n.quickUnlock),
                ),
              ],
              if (_passkeyRegistered) ...[
                const SizedBox(height: FolioSpace.sm),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.all(FolioSpace.md),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(FolioRadius.lg),
                    ),
                  ),
                  onPressed: _busy ? null : _unlockPasskey,
                  icon: const Icon(Icons.key_rounded),
                  label: Text(l10n.passkey),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: FolioSpace.lg),
                Container(
                  padding: const EdgeInsets.all(FolioSpace.md),
                  decoration: BoxDecoration(
                    color: scheme.errorContainer,
                    borderRadius: BorderRadius.circular(FolioRadius.lg),
                  ),
                  child: Text(
                    _error!,
                    style: TextStyle(color: scheme.onErrorContainer),
                  ),
                ),
                const SizedBox(height: FolioSpace.sm),
                TextButton.icon(
                  onPressed: _busy ? null : _unlockPassword,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(l10n.retry),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 960;
            if (!wide) {
              return Center(child: formCard);
            }
            return Padding(
              padding: const EdgeInsets.all(FolioSpace.xl),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.only(right: FolioSpace.xl),
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer.withValues(
                          alpha: FolioAlpha.panel,
                        ),
                        borderRadius: BorderRadius.circular(FolioRadius.xxl),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: scheme.surface,
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Icon(
                              Icons.shield_moon_outlined,
                              size: 34,
                              color: scheme.primary,
                            ),
                          ),
                          const SizedBox(height: FolioSpace.xl),
                          Text(
                            'Folio',
                            style: Theme.of(context).textTheme.displaySmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: scheme.onSurface,
                                ),
                          ),
                          const SizedBox(height: FolioSpace.md),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 520),
                            child: Text(
                              l10n.encryptedVault,
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                    height: 1.35,
                                  ),
                            ),
                          ),
                          const SizedBox(height: FolioSpace.lg),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              if (!kIsWeb && _quickEnabled)
                                Chip(
                                  avatar: const Icon(
                                    Icons.fingerprint,
                                    size: 18,
                                  ),
                                  label: Text(l10n.quickUnlock),
                                ),
                              if (_passkeyRegistered)
                                Chip(
                                  avatar: const Icon(
                                    Icons.key_rounded,
                                    size: 18,
                                  ),
                                  label: Text(l10n.passkey),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  Center(child: formCard),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
