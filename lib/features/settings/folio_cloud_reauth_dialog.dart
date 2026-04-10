import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../app/widgets/folio_dialog.dart';
import '../../app/widgets/folio_password_field.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../services/cloud_account/cloud_account_controller.dart';

/// Pide correo (si hace falta) y contraseña de **Folio Cloud** antes de listar/descargar copias.
class FolioCloudReauthDialog extends StatefulWidget {
  const FolioCloudReauthDialog({
    super.key,
    required this.l10n,
    required this.cloud,
    required this.onAuthError,
    this.initialEmail,
  });

  final AppLocalizations l10n;
  final CloudAccountController cloud;
  final String Function(String code) onAuthError;
  final String? initialEmail;

  @override
  State<FolioCloudReauthDialog> createState() => _FolioCloudReauthDialogState();
}

class _FolioCloudReauthDialogState extends State<FolioCloudReauthDialog> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  var _obscure = true;
  var _loading = false;

  bool get _emailLocked =>
      (widget.initialEmail?.trim().isNotEmpty ?? false);

  @override
  void initState() {
    super.initState();
    final e = widget.initialEmail?.trim();
    if (e != null && e.isNotEmpty) {
      _email.text = e;
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  bool _isValidEmail(String s) {
    final t = s.trim();
    if (t.isEmpty) return false;
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t);
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final email = _email.text.trim();
    final pass = _password.text;
    setState(() => _loading = true);
    try {
      await widget.cloud.verifyPasswordForSensitiveCloudAction(
        email: email,
        password: pass,
      );
      if (mounted) Navigator.of(context).pop(true);
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(widget.onAuthError(e.code)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('$e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    final scheme = Theme.of(context).colorScheme;
    return FolioDialog(
      contentWidth: 400,
      title: Text(
        l10n.folioCloudReauthDialogTitle,
        style: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.folioCloudReauthDialogBody,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 18),
              if (_emailLocked)
                InputDecorator(
                  decoration: InputDecoration(
                    labelText: l10n.cloudAccountEmailLabel,
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.alternate_email_rounded),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      _email.text,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                )
              else
                TextFormField(
                  controller: _email,
                  enabled: !_loading,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  autofillHints: const [AutofillHints.email],
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: l10n.cloudAccountEmailLabel,
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.alternate_email_rounded),
                  ),
                  validator: (v) {
                    final s = v?.trim() ?? '';
                    if (s.isEmpty) return l10n.cloudAuthValidationRequired;
                    if (!_isValidEmail(s)) {
                      return l10n.cloudAuthErrorInvalidEmail;
                    }
                    return null;
                  },
                ),
              const SizedBox(height: 12),
              FolioPasswordField(
                controller: _password,
                labelText: l10n.cloudAccountPasswordLabel,
                obscureText: _obscure,
                onToggleObscure: () => setState(() => _obscure = !_obscure),
                showPasswordTooltip: l10n.showPassword,
                hidePasswordTooltip: l10n.hidePassword,
                enabled: !_loading,
                autofocus: _emailLocked,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.verifyAndContinue),
        ),
      ],
    );
  }
}
