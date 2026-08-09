import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/ui_tokens.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../services/cloud_account/folio_spring_auth_session.dart';

/// Formulario de restablecimiento en `…/reset-password?token=…`.
class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key, required this.token});

  final String token;

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _auth = FolioSpringAuthSession();
  bool _busy = false;
  bool _done = false;
  String? _error;
  bool _obscure = true;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _goHome() async {
    final uri = Uri.parse(Uri.base.origin);
    await launchUrl(uri, webOnlyWindowName: '_self');
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final token = widget.token.trim();
    if (token.isEmpty) {
      setState(() => _error = l10n.resetPasswordMissingToken);
      return;
    }
    final pass = _password.text;
    final confirm = _confirm.text;
    if (pass.length < 8) {
      setState(() => _error = l10n.resetPasswordTooShort);
      return;
    }
    if (pass != confirm) {
      setState(() => _error = l10n.resetPasswordMismatch);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _auth.resetPassword(token: token, newPassword: pass);
      if (!mounted) return;
      setState(() {
        _done = true;
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e is FolioSpringAuthException ? e.message : '$e';
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
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(FolioSpace.xl),
              child: _done
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Folio',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: FolioSpace.lg),
                        Text(
                          l10n.passwordUpdatedTitle,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: FolioSpace.sm),
                        Text(
                          l10n.passwordUpdatedBody,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: FolioSpace.xl),
                        FilledButton(
                          onPressed: _goHome,
                          child: Text(l10n.goToFolio),
                        ),
                      ],
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Folio',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: FolioSpace.lg),
                        Text(
                          l10n.resetPasswordTitle,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: FolioSpace.sm),
                        Text(
                          l10n.resetPasswordBody,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: FolioSpace.xl),
                        TextField(
                          controller: _password,
                          obscureText: _obscure,
                          enabled: !_busy,
                          decoration: InputDecoration(
                            labelText: l10n.newPasswordLabel,
                            suffixIcon: IconButton(
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                              icon: Icon(
                                _obscure
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                          ),
                          onSubmitted: (_) => _submit(),
                        ),
                        const SizedBox(height: FolioSpace.md),
                        TextField(
                          controller: _confirm,
                          obscureText: _obscure,
                          enabled: !_busy,
                          decoration: InputDecoration(
                            labelText: l10n.resetPasswordConfirmLabel,
                          ),
                          onSubmitted: (_) => _submit(),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: FolioSpace.md),
                          Text(
                            _error!,
                            style: TextStyle(color: scheme.error),
                          ),
                        ],
                        const SizedBox(height: FolioSpace.xl),
                        FilledButton(
                          onPressed: _busy ? null : _submit,
                          child: _busy
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(l10n.savePassword),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
