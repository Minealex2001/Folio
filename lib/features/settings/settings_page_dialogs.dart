part of 'settings_page.dart';

class _CloudAuthDialog extends StatefulWidget {
  const _CloudAuthDialog({
    required this.initialRegister,
    required this.l10n,
    required this.cloudAuthController,
    required this.onAuthError,
    required this.onForgotPassword,
  });

  final bool initialRegister;
  final AppLocalizations l10n;
  final CloudAccountController cloudAuthController;
  final String Function(String code) onAuthError;
  final VoidCallback onForgotPassword;

  @override
  State<_CloudAuthDialog> createState() => _CloudAuthDialogState();
}

class _CloudAuthDialogState extends State<_CloudAuthDialog> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _emailFocus = FocusNode();
  late bool _modeRegister;
  var _obscurePassword = true;
  var _obscureConfirm = true;
  var _loading = false;

  @override
  void initState() {
    super.initState();
    _modeRegister = widget.initialRegister;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _emailFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    _emailFocus.dispose();
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
      if (_modeRegister) {
        await widget.cloudAuthController.createUserWithEmailAndPassword(
          email: email,
          password: pass,
        );
      } else {
        await widget.cloudAuthController.signInWithEmailAndPassword(
          email: email,
          password: pass,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(pass);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(widget.onAuthError(e.code)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(behavior: SnackBarBehavior.floating, content: Text('$e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    final scheme = Theme.of(context).colorScheme;
    final subtitle = _modeRegister
        ? l10n.cloudAuthSubtitleRegister
        : l10n.cloudAuthSubtitleSignIn;

    return FolioDialog(
      contentWidth: 420,
      title: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: scheme.primaryContainer.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.cloud_rounded, color: scheme.primary, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              l10n.cloudAuthDialogTitle,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            SegmentedButton<bool>(
              segments: [
                ButtonSegment<bool>(
                  value: false,
                  label: Text(l10n.cloudAuthModeSignIn),
                  icon: const Icon(Icons.login_rounded, size: 18),
                ),
                ButtonSegment<bool>(
                  value: true,
                  label: Text(l10n.cloudAuthModeRegister),
                  icon: const Icon(Icons.person_add_outlined, size: 18),
                ),
              ],
              selected: {_modeRegister},
              onSelectionChanged: (Set<bool> next) {
                if (_loading || next.isEmpty) return;
                setState(() {
                  _modeRegister = next.first;
                  _confirm.clear();
                });
              },
            ),
            const SizedBox(height: 18),
            AutofillGroup(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _email,
                      focusNode: _emailFocus,
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
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _password,
                      enabled: !_loading,
                      obscureText: _obscurePassword,
                      autofillHints: [
                        _modeRegister
                            ? AutofillHints.newPassword
                            : AutofillHints.password,
                      ],
                      textInputAction: _modeRegister
                          ? TextInputAction.next
                          : TextInputAction.done,
                      onFieldSubmitted: (_) {
                        if (_modeRegister) {
                          FocusScope.of(context).nextFocus();
                        } else {
                          unawaited(_submit());
                        }
                      },
                      decoration: InputDecoration(
                        labelText: l10n.cloudAccountPasswordLabel,
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          tooltip: _obscurePassword
                              ? l10n.showPassword
                              : l10n.hidePassword,
                          onPressed: _loading
                              ? null
                              : () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                                ),
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_rounded
                                : Icons.visibility_off_rounded,
                          ),
                        ),
                      ),
                      validator: (v) {
                        final s = v ?? '';
                        if (s.isEmpty) return l10n.cloudAuthValidationRequired;
                        if (s.length < 6) {
                          return l10n.cloudAuthValidationPasswordShort;
                        }
                        return null;
                      },
                    ),
                    if (_modeRegister) ...[
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _confirm,
                        enabled: !_loading,
                        obscureText: _obscureConfirm,
                        autofillHints: const [AutofillHints.newPassword],
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => unawaited(_submit()),
                        decoration: InputDecoration(
                          labelText: l10n.cloudAuthConfirmPasswordLabel,
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.lock_person_outlined),
                          suffixIcon: IconButton(
                            tooltip: _obscureConfirm
                                ? l10n.showPassword
                                : l10n.hidePassword,
                            onPressed: _loading
                                ? null
                                : () => setState(
                                    () => _obscureConfirm = !_obscureConfirm,
                                  ),
                            icon: Icon(
                              _obscureConfirm
                                  ? Icons.visibility_rounded
                                  : Icons.visibility_off_rounded,
                            ),
                          ),
                        ),
                        validator: (v) {
                          final s = v ?? '';
                          if (s.isEmpty) {
                            return l10n.cloudAuthValidationRequired;
                          }
                          if (s != _password.text) {
                            return l10n.cloudAuthValidationConfirmMismatch;
                          }
                          return null;
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (!_modeRegister) ...[
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _loading ? null : widget.onForgotPassword,
                  icon: const Icon(Icons.mail_outline_rounded, size: 18),
                  label: Text(l10n.cloudAccountForgotPassword),
                ),
              ),
            ],
          ],
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
              : Text(
                  _modeRegister
                      ? l10n.cloudAccountCreateAccount
                      : l10n.cloudAccountSignIn,
                ),
        ),
      ],
    );
  }
}

class _CloudPasswordResetDialog extends StatefulWidget {
  const _CloudPasswordResetDialog({required this.l10n, this.fixedEmail});

  final AppLocalizations l10n;
  final String? fixedEmail;

  @override
  State<_CloudPasswordResetDialog> createState() =>
      _CloudPasswordResetDialogState();
}

class _CloudPasswordResetDialogState extends State<_CloudPasswordResetDialog> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _focus = FocusNode();

  bool get _emailLocked =>
      widget.fixedEmail != null && widget.fixedEmail!.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    final locked = widget.fixedEmail?.trim();
    if (locked != null && locked.isNotEmpty) {
      _email.text = locked;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_emailLocked) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _email.dispose();
    _focus.dispose();
    super.dispose();
  }

  bool _isValidEmail(String s) {
    final t = s.trim();
    if (t.isEmpty) return false;
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t);
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(_email.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    final scheme = Theme.of(context).colorScheme;
    return FolioDialog(
      contentWidth: 400,
      title: Row(
        children: [
          Icon(Icons.lock_reset_rounded, color: scheme.primary, size: 26),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              l10n.cloudAuthDialogTitleReset,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.cloudAuthResetHint,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _email,
              focusNode: _focus,
              readOnly: _emailLocked,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              autofillHints: const [AutofillHints.email],
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: l10n.cloudAccountEmailLabel,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.email_outlined),
              ),
              validator: (v) {
                final s = v?.trim() ?? '';
                if (s.isEmpty) return l10n.cloudAuthValidationRequired;
                if (!_isValidEmail(s)) return l10n.cloudAuthErrorInvalidEmail;
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.continueAction)),
      ],
    );
  }
}

class _BackupPasswordDialog extends StatefulWidget {
  const _BackupPasswordDialog();

  @override
  State<_BackupPasswordDialog> createState() => _BackupPasswordDialogState();
}

class _BackupPasswordDialogState extends State<_BackupPasswordDialog> {
  final _controller = TextEditingController();
  var _obscure = true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final t = _controller.text;
    if (t.isEmpty) return;
    Navigator.pop(context, t);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return FolioDialog(
      title: Text(l10n.backupPasswordDialogTitle),
      content: FolioPasswordField(
        controller: _controller,
        obscureText: _obscure,
        autofocus: true,
        labelText: l10n.backupFilePasswordLabel,
        showPasswordTooltip: l10n.showPassword,
        hidePasswordTooltip: l10n.hidePassword,
        helperText: l10n.backupFilePasswordHelper,
        onToggleObscure: () => setState(() => _obscure = !_obscure),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.importAction)),
      ],
    );
  }
}

enum _NotionImportMode { currentVault, newVault }

class _NotionImportModeDialog extends StatelessWidget {
  const _NotionImportModeDialog();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return FolioDialog(
      title: Text(l10n.importNotionSelectTargetTitle),
      content: Text(l10n.importNotionSelectTargetBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        OutlinedButton(
          onPressed: () =>
              Navigator.pop(context, _NotionImportMode.currentVault),
          child: Text(l10n.importNotionTargetCurrent),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _NotionImportMode.newVault),
          child: Text(l10n.importNotionTargetNew),
        ),
      ],
    );
  }
}

class _NewVaultPasswordDialog extends StatefulWidget {
  const _NewVaultPasswordDialog();

  @override
  State<_NewVaultPasswordDialog> createState() =>
      _NewVaultPasswordDialogState();
}

class _NewVaultPasswordDialogState extends State<_NewVaultPasswordDialog> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  var _obscureA = true;
  var _obscureB = true;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _submit() {
    final l10n = AppLocalizations.of(context);
    final a = _password.text.trim();
    final b = _confirm.text.trim();
    if (a.length < 10) {
      setState(() => _error = l10n.minCharactersError(10));
      return;
    }
    if (a != b) {
      setState(() => _error = l10n.passwordMismatchError);
      return;
    }
    setState(() => _error = null);
    Navigator.pop(context, a);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return FolioDialog(
      title: Text(l10n.importNotionNewVaultPasswordTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FolioPasswordField(
            controller: _password,
            obscureText: _obscureA,
            labelText: l10n.passwordLabel,
            showPasswordTooltip: l10n.showPassword,
            hidePasswordTooltip: l10n.hidePassword,
            onToggleObscure: () => setState(() => _obscureA = !_obscureA),
          ),
          const SizedBox(height: 8),
          FolioPasswordField(
            controller: _confirm,
            obscureText: _obscureB,
            labelText: l10n.confirmPasswordLabel,
            showPasswordTooltip: l10n.showPassword,
            hidePasswordTooltip: l10n.hidePassword,
            onToggleObscure: () => setState(() => _obscureB = !_obscureB),
            onSubmitted: (_) => _submit(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.importAction)),
      ],
    );
  }
}

enum _PasswordStrength { veryWeak, weak, fair, strong }

_PasswordStrength _passwordStrengthFor(String text) {
  var score = 0;
  if (text.length >= 10) score++;
  if (text.length >= 14) score++;
  if (RegExp(r'[a-z]').hasMatch(text) && RegExp(r'[A-Z]').hasMatch(text)) {
    score++;
  }
  if (RegExp(r'\d').hasMatch(text)) score++;
  if (RegExp(r'[^A-Za-z0-9]').hasMatch(text)) score++;
  if (score <= 1) return _PasswordStrength.veryWeak;
  if (score == 2) return _PasswordStrength.weak;
  if (score == 3 || score == 4) return _PasswordStrength.fair;
  return _PasswordStrength.strong;
}

bool _meetsVaultMasterPasswordPolicy(_PasswordStrength strength) =>
    strength == _PasswordStrength.fair || strength == _PasswordStrength.strong;

class _EncryptPlainVaultDialog extends StatefulWidget {
  const _EncryptPlainVaultDialog({required this.session});

  final VaultSession session;

  @override
  State<_EncryptPlainVaultDialog> createState() =>
      _EncryptPlainVaultDialogState();
}

class _EncryptPlainVaultDialogState extends State<_EncryptPlainVaultDialog> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  var _busy = false;
  var _obscurePw = true;
  var _obscureConfirm = true;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final pw = _password.text;
    final c = _confirm.text;
    final l10n = AppLocalizations.of(context);
    if (pw.isEmpty || c.isEmpty) {
      setState(() => _error = l10n.fillAllFieldsError);
      return;
    }
    if (pw != c) {
      setState(() => _error = l10n.passwordMismatchError);
      return;
    }
    if (!_meetsVaultMasterPasswordPolicy(_passwordStrengthFor(pw))) {
      setState(() => _error = l10n.passwordMustBeStrongError);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.session.enableVaultEncryption(pw);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final strength = _passwordStrengthFor(_password.text);
    final strengthValue = switch (strength) {
      _PasswordStrength.veryWeak => 0.25,
      _PasswordStrength.weak => 0.5,
      _PasswordStrength.fair => 0.75,
      _PasswordStrength.strong => 1.0,
    };
    final strengthLabel = switch (strength) {
      _PasswordStrength.veryWeak => l10n.passwordStrengthVeryWeak,
      _PasswordStrength.weak => l10n.passwordStrengthWeak,
      _PasswordStrength.fair => l10n.passwordStrengthFair,
      _PasswordStrength.strong => l10n.passwordStrengthStrong,
    };
    return FolioDialog(
      title: Text(l10n.encryptPlainVaultTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.encryptPlainVaultBody,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _password,
              obscureText: _obscurePw,
              enabled: !_busy,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: l10n.newPasswordLabel,
                suffixIcon: IconButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() => _obscurePw = !_obscurePw),
                  icon: Icon(
                    _obscurePw ? Icons.visibility : Icons.visibility_off,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: strengthValue),
            const SizedBox(height: 4),
            Text(l10n.passwordStrengthWithValue(strengthLabel)),
            const SizedBox(height: 12),
            TextField(
              controller: _confirm,
              obscureText: _obscureConfirm,
              enabled: !_busy,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: l10n.confirmNewPasswordLabel,
                suffixIcon: IconButton(
                  onPressed: _busy
                      ? null
                      : () =>
                            setState(() => _obscureConfirm = !_obscureConfirm),
                  icon: Icon(
                    _obscureConfirm ? Icons.visibility : Icons.visibility_off,
                  ),
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: Text(l10n.encryptPlainVaultConfirm),
        ),
      ],
    );
  }
}

class _ChangeMasterPasswordDialog extends StatefulWidget {
  const _ChangeMasterPasswordDialog({required this.session});

  final VaultSession session;

  @override
  State<_ChangeMasterPasswordDialog> createState() =>
      _ChangeMasterPasswordDialogState();
}

class _ChangeMasterPasswordDialogState
    extends State<_ChangeMasterPasswordDialog> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  var _busy = false;
  var _obscureCurrent = true;
  var _obscureNext = true;
  var _obscureConfirm = true;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final currentPassword = _current.text;
    final nextPassword = _next.text;
    final confirmPassword = _confirm.text;
    if (currentPassword.isEmpty ||
        nextPassword.isEmpty ||
        confirmPassword.isEmpty) {
      setState(() => _error = AppLocalizations.of(context).fillAllFieldsError);
      return;
    }
    if (nextPassword != confirmPassword) {
      setState(
        () => _error = AppLocalizations.of(context).newPasswordsMismatchError,
      );
      return;
    }
    if (!_meetsVaultMasterPasswordPolicy(_passwordStrengthFor(nextPassword))) {
      setState(
        () =>
            _error = AppLocalizations.of(context).newPasswordMustBeStrongError,
      );
      return;
    }
    if (currentPassword == nextPassword) {
      setState(
        () => _error = AppLocalizations.of(context).newPasswordMustDifferError,
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.session.changeMasterPassword(
        currentPassword: currentPassword,
        newPassword: nextPassword,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final strength = _passwordStrengthFor(_next.text);
    final strengthValue = switch (strength) {
      _PasswordStrength.veryWeak => 0.25,
      _PasswordStrength.weak => 0.5,
      _PasswordStrength.fair => 0.75,
      _PasswordStrength.strong => 1.0,
    };
    final strengthLabel = switch (strength) {
      _PasswordStrength.veryWeak => l10n.passwordStrengthVeryWeak,
      _PasswordStrength.weak => l10n.passwordStrengthWeak,
      _PasswordStrength.fair => l10n.passwordStrengthFair,
      _PasswordStrength.strong => l10n.passwordStrengthStrong,
    };
    return FolioDialog(
      title: Text(l10n.changeMasterPassword),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _current,
              obscureText: _obscureCurrent,
              enabled: !_busy,
              decoration: InputDecoration(
                labelText: l10n.currentPasswordLabel,
                suffixIcon: IconButton(
                  onPressed: _busy
                      ? null
                      : () =>
                            setState(() => _obscureCurrent = !_obscureCurrent),
                  icon: Icon(
                    _obscureCurrent ? Icons.visibility : Icons.visibility_off,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _next,
              obscureText: _obscureNext,
              enabled: !_busy,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: l10n.newPasswordLabel,
                suffixIcon: IconButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() => _obscureNext = !_obscureNext),
                  icon: Icon(
                    _obscureNext ? Icons.visibility : Icons.visibility_off,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: strengthValue),
            const SizedBox(height: 4),
            Text(l10n.passwordStrengthWithValue(strengthLabel)),
            const SizedBox(height: 12),
            TextField(
              controller: _confirm,
              obscureText: _obscureConfirm,
              enabled: !_busy,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: l10n.confirmNewPasswordLabel,
                suffixIcon: IconButton(
                  onPressed: _busy
                      ? null
                      : () =>
                            setState(() => _obscureConfirm = !_obscureConfirm),
                  icon: Icon(
                    _obscureConfirm ? Icons.visibility : Icons.visibility_off,
                  ),
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: Text(l10n.cancel),
        ),
        FilledButton(onPressed: _busy ? null : _submit, child: Text(l10n.save)),
      ],
    );
  }
}

enum _AiWizardAction { close, retry }

class _AiSetupWizardDialog extends StatefulWidget {
  const _AiSetupWizardDialog({
    required this.summary,
    required this.selectedProvider,
    required this.title,
    required this.noProviderTitle,
    required this.noProviderBody,
    required this.ollamaInstallTitle,
    required this.ollamaInstallBody,
    required this.lmStudioInstallTitle,
    required this.lmStudioInstallBody,
    required this.openSettingsHint,
    required this.retryLabel,
    required this.closeLabel,
  });

  final AiProviderDetectionSummary summary;
  final AiProvider selectedProvider;
  final String title;
  final String noProviderTitle;
  final String noProviderBody;
  final String ollamaInstallTitle;
  final String ollamaInstallBody;
  final String lmStudioInstallTitle;
  final String lmStudioInstallBody;
  final String openSettingsHint;
  final String retryLabel;
  final String closeLabel;

  @override
  State<_AiSetupWizardDialog> createState() => _AiSetupWizardDialogState();
}

class _AiSetupWizardDialogState extends State<_AiSetupWizardDialog> {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isOllama = widget.selectedProvider == AiProvider.ollama;
    final selectedStatus = isOllama
        ? widget.summary.ollama
        : widget.summary.lmStudio;
    return FolioDialog(
      title: Text(widget.title),
      contentWidth: 520,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.noProviderTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(widget.noProviderBody),
          const SizedBox(height: 12),
          _ProviderStatusLine(
            label: isOllama ? 'Ollama' : 'LM Studio',
            installed: selectedStatus.installed,
            reachable: selectedStatus.reachable,
          ),
          const SizedBox(height: 12),
          Text(
            isOllama ? widget.ollamaInstallTitle : widget.lmStudioInstallTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            isOllama ? widget.ollamaInstallBody : widget.lmStudioInstallBody,
          ),
          const SizedBox(height: 10),
          SelectableText(
            isOllama ? 'https://ollama.com/download' : 'https://lmstudio.ai/',
            style: TextStyle(color: scheme.primary),
          ),
          const SizedBox(height: 14),
          Text(
            widget.openSettingsHint,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, _AiWizardAction.close),
          child: Text(widget.closeLabel),
        ),
        FilledButton.tonal(
          onPressed: () => Navigator.pop(context, _AiWizardAction.retry),
          child: Text(widget.retryLabel),
        ),
      ],
    );
  }
}

