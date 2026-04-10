import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../app/widgets/folio_dialog.dart';
import '../../app/widgets/folio_password_field.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../services/cloud_account/cloud_account_controller.dart';

class CloudSignInDialog extends StatefulWidget {
  const CloudSignInDialog({
    super.key,
    required this.l10n,
    required this.cloud,
    required this.onAuthError,
  });

  final AppLocalizations l10n;
  final CloudAccountController cloud;
  final String Function(String code) onAuthError;

  @override
  State<CloudSignInDialog> createState() => _CloudSignInDialogState();
}

class _CloudSignInDialogState extends State<CloudSignInDialog> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  var _obscure = true;
  var _loading = false;

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
    setState(() => _loading = true);
    try {
      await widget.cloud.signInWithEmailAndPassword(
        email: _email.text,
        password: _password.text,
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
      contentWidth: 440,
      title: Text(
        l10n.cloudAuthDialogTitleSignIn,
        style: Theme.of(context)
            .textTheme
            .titleLarge
            ?.copyWith(fontWeight: FontWeight.w800),
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.cloudAuthSubtitleSignIn,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.45,
                    ),
              ),
              const SizedBox(height: 16),
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
                  if (!_isValidEmail(s)) return l10n.cloudAuthErrorInvalidEmail;
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
              : Text(l10n.cloudAccountSignIn),
        ),
      ],
    );
  }
}

