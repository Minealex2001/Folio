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
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Padding(
              padding: const EdgeInsets.all(FolioSpace.lg),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Folio',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.encryptedVault,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 32),
                  TextField(
                    controller: _password,
                    obscureText: true,
                    enabled: !_busy,
                    decoration: InputDecoration(labelText: l10n.passwordLabel),
                    onSubmitted: (_) => _unlockPassword(),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _busy ? null : _unlockPassword,
                    child: Text(l10n.unlock),
                  ),
                  if (_quickEnabled) ...[
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _unlockDevice,
                      icon: const Icon(Icons.fingerprint),
                      label: Text(l10n.quickUnlock),
                    ),
                  ],
                  if (_passkeyRegistered) ...[
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _unlockPasskey,
                      icon: const Icon(Icons.key_rounded),
                      label: Text(l10n.passkey),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      style: TextStyle(color: scheme.error),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
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
    );
  }
}
