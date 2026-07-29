import 'package:flutter/material.dart';

import '../../app/widgets/folio_dialog.dart';
import '../../app/widgets/folio_password_field.dart';
import '../../app/widgets/folio_error_card.dart';
import '../../app/widgets/folio_skeletons.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../services/cloud_account/cloud_account_controller.dart';

import '../../services/folio_cloud/folio_cloud_exception.dart';
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
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  var _obscure = true;
  var _loading = false;

  String? _emailError;
  String? _passwordError;
  String? _generalError;

  bool get _emailLocked =>
      (widget.initialEmail?.trim().isNotEmpty ?? false);

  @override
  void initState() {
    super.initState();
    final e = widget.initialEmail?.trim();
    if (e != null && e.isNotEmpty) {
      _email.text = e;
    }
    _emailFocus.addListener(_onEmailFocusChange);
    _passwordFocus.addListener(_onPasswordFocusChange);
  }

  @override
  void dispose() {
    _emailFocus.removeListener(_onEmailFocusChange);
    _passwordFocus.removeListener(_onPasswordFocusChange);
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _onEmailFocusChange() {
    if (!_emailFocus.hasFocus) {
      _formKey.currentState?.validate();
    }
  }

  void _onPasswordFocusChange() {
    if (!_passwordFocus.hasFocus) {
      _formKey.currentState?.validate();
    }
  }

  bool _isValidEmail(String s) {
    final t = s.trim();
    if (t.isEmpty) return false;
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t);
  }

  Future<void> _submit() async {
    setState(() {
      _emailError = null;
      _passwordError = null;
      _generalError = null;
    });

    if (!(_formKey.currentState?.validate() ?? false)) return;

    final email = _email.text.trim();
    final pass = _password.text;
    setState(() => _loading = true);
    try {
      await widget.cloud.verifyPasswordForSensitiveCloudAction(
        email: email,
        password: pass,
      );
      if (mounted) Navigator.of(context).pop(pass);
    } on FolioAuthException catch (e) {
      if (mounted) {
        setState(() {
          final errorMsg = widget.onAuthError(e.code);
          if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
            _passwordError = errorMsg;
          } else if (e.code == 'invalid-email' || e.code == 'user-not-found') {
            _emailError = errorMsg;
          } else {
            _generalError = errorMsg;
          }
          _loading = false;
        });
        _formKey.currentState?.validate();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _generalError = '$e';
          _loading = false;
        });
      }
    } finally {
      if (mounted && _loading) {
        setState(() => _loading = false);
      }
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
          autovalidateMode: AutovalidateMode.onUserInteraction,
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
              if (_generalError != null) ...[
                FolioErrorCard(
                  title: 'Error de verificación',
                  message: _generalError!,
                  margin: const EdgeInsets.only(bottom: 12),
                ),
              ],
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
                  focusNode: _emailFocus,
                  enabled: !_loading,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  autofillHints: const [AutofillHints.email],
                  textInputAction: TextInputAction.next,
                  onChanged: (_) {
                    if (_emailError != null) {
                      setState(() => _emailError = null);
                    }
                  },
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
                    if (_emailError != null) return _emailError;
                    return null;
                  },
                ),
              const SizedBox(height: 12),
              FolioPasswordField(
                controller: _password,
                focusNode: _passwordFocus,
                labelText: l10n.cloudAccountPasswordLabel,
                obscureText: _obscure,
                onToggleObscure: () => setState(() => _obscure = !_obscure),
                showPasswordTooltip: l10n.showPassword,
                hidePasswordTooltip: l10n.hidePassword,
                enabled: !_loading,
                autofocus: _emailLocked,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                onChanged: (_) {
                  if (_passwordError != null) {
                    setState(() => _passwordError = null);
                  }
                },
                validator: (v) {
                  final s = v ?? '';
                  if (s.isEmpty) return l10n.cloudAuthValidationRequired;
                  if (_passwordError != null) return _passwordError;
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const FolioLoadingIndicator(size: FolioLoadingSize.small)
              : Text(l10n.verifyAndContinue),
        ),
      ],
    );
  }
}
