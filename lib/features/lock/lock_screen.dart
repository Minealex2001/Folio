import 'dart:async';

import 'package:flutter/material.dart';
import 'package:passkeys/exceptions.dart';

import '../../app/app_settings.dart';
import '../../app/widgets/folio_password_field.dart';
import '../../app/ui_tokens.dart';
import '../../l10n/generated/app_localizations.dart';
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

  @override
  void initState() {
    super.initState();
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

  /// Primera vez que se muestra el bloqueo con Hello o passkey: lanza el flujo nativo sin pulsar el botón.
  Future<void> _maybeOfferInitialQuickUnlock(bool quick, bool passkey) async {
    if (!mounted) return;
    if (widget.appSettings.lockScreenAutoQuickUnlockDone) return;
    if (!quick && !passkey) return;
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
              if (_quickEnabled) ...[
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
                              if (_quickEnabled)
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
