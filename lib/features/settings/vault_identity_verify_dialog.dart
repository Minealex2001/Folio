import 'package:flutter/material.dart';
import 'package:passkeys/exceptions.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../session/vault_session.dart';

/// Diálogo reutilizable: contraseña de la libreta (y opcionalmente Hello / passkey)
/// sin desbloquear de nuevo; usa [VaultSession.verifyPasswordMatchesUnlockedSession].
class VaultIdentityVerifyDialog extends StatefulWidget {
  const VaultIdentityVerifyDialog({
    super.key,
    required this.session,
    required this.quickEnabled,
    required this.passkeyRegistered,
    required this.title,
    required this.body,
    required this.passwordButtonLabel,
  });

  final VaultSession session;
  final bool quickEnabled;
  final bool passkeyRegistered;
  final Widget title;
  final Widget body;
  final String passwordButtonLabel;

  @override
  State<VaultIdentityVerifyDialog> createState() =>
      _VaultIdentityVerifyDialogState();
}

class _VaultIdentityVerifyDialogState extends State<VaultIdentityVerifyDialog> {
  final _password = TextEditingController();
  var _busy = false;
  var _obscure = true;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _verifyPassword() async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await widget.session.verifyPasswordMatchesUnlockedSession(
      _password.text,
    );
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context, true);
      return;
    }
    setState(() {
      _busy = false;
      _error = l10n.incorrectPasswordError;
    });
  }

  Future<void> _verifyHello() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.session.verifyQuickUnlockMatchesSession();
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = '$e';
        });
      }
    }
  }

  Future<void> _verifyPasskey() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.session.verifyPasskeyMatchesSession();
      if (mounted) Navigator.pop(context, true);
    } on PasskeyAuthCancelledException {
      if (mounted) setState(() => _busy = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = '$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: widget.title,
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DefaultTextStyle.merge(
              style: Theme.of(
                context,
              ).textTheme.bodyMedium!.copyWith(color: scheme.onSurfaceVariant),
              child: widget.body,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _password,
              obscureText: _obscure,
              enabled: !_busy,
              decoration: InputDecoration(
                labelText: l10n.masterPassword,
                suffixIcon: IconButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() => _obscure = !_obscure),
                  icon: Icon(
                    _obscure ? Icons.visibility : Icons.visibility_off,
                  ),
                  tooltip: _obscure ? l10n.showPassword : l10n.hidePassword,
                ),
              ),
              onSubmitted: (_) => _verifyPassword(),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _busy ? null : _verifyPassword,
              child: Text(widget.passwordButtonLabel),
            ),
            if (widget.quickEnabled) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _busy ? null : _verifyHello,
                icon: const Icon(Icons.fingerprint),
                label: Text(l10n.useHelloBiometrics),
              ),
            ],
            if (widget.passkeyRegistered) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _busy ? null : _verifyPasskey,
                icon: const Icon(Icons.key_rounded),
                label: Text(l10n.usePasskey),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: scheme.error)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: Text(l10n.cancel),
        ),
      ],
    );
  }
}
