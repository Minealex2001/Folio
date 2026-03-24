import 'package:flutter/material.dart';
import 'package:passkeys/exceptions.dart';

import '../../app/ui_tokens.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../session/vault_session.dart';

class LockScreen extends StatefulWidget {
  const LockScreen({super.key, required this.session});

  final VaultSession session;

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
    }
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
    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Card.filled(
              margin: const EdgeInsets.all(FolioSpace.lg),
              color: scheme.surfaceContainerHighest,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Padding(
                padding: const EdgeInsets.all(FolioSpace.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      Icons.lock_outline_rounded,
                      size: 48,
                      color: scheme.primary,
                    ),
                    const SizedBox(height: FolioSpace.md),
                    Text(
                      'Folio',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: scheme.onSurface,
                          ),
                    ),
                    const SizedBox(height: FolioSpace.xs),
                    Text(
                      l10n.encryptedVault,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: FolioSpace.xl),
                    TextField(
                      controller: _password,
                      obscureText: _obscurePassword,
                      enabled: !_busy,
                      decoration: InputDecoration(
                        labelText: l10n.passwordLabel,
                        border: const OutlineInputBorder(),
                        filled: true,
                        fillColor: scheme.surface,
                        suffixIcon: IconButton(
                          onPressed: _busy
                              ? null
                              : () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                                ),
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                          tooltip: _obscurePassword
                              ? l10n.showPassword
                              : l10n.hidePassword,
                        ),
                      ),
                      onSubmitted: (_) => _unlockPassword(),
                    ),
                    const SizedBox(height: FolioSpace.lg),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.all(FolioSpace.md),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
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
                            borderRadius: BorderRadius.circular(12),
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
                            borderRadius: BorderRadius.circular(12),
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
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _error!,
                          style: TextStyle(color: scheme.onErrorContainer),
                          textAlign: TextAlign.center,
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
          ),
        ),
      ),
    );
  }
}
