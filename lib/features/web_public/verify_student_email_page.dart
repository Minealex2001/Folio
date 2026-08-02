import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/ui_tokens.dart';
import '../../services/cloud_account/folio_spring_auth_session.dart';

/// Confirmación de correo estudiante en `…/verify-student-email?token=…`.
class VerifyStudentEmailPage extends StatefulWidget {
  const VerifyStudentEmailPage({super.key, required this.token});

  final String token;

  @override
  State<VerifyStudentEmailPage> createState() => _VerifyStudentEmailPageState();
}

class _VerifyStudentEmailPageState extends State<VerifyStudentEmailPage> {
  final _auth = FolioSpringAuthSession();
  bool _loading = true;
  bool _ok = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _goHome() async {
    final uri = Uri.parse(Uri.base.origin);
    await launchUrl(uri, webOnlyWindowName: '_self');
  }

  Future<void> _run() async {
    final token = widget.token.trim();
    if (token.isEmpty) {
      setState(() {
        _loading = false;
        _ok = false;
        _message =
            'Falta el token del enlace. Solicita un nuevo correo de verificación.';
      });
      return;
    }
    try {
      await _auth.confirmStudentEmailToken(token);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _ok = true;
        _message =
            'Tu elegibilidad de estudiante en Folio Cloud está activa durante 4 años. '
            'Puedes volver a la app y contratar la tarifa de estudiante.';
      });
    } catch (e) {
      if (!mounted) return;
      final msg = e is FolioSpringAuthException ? e.message : '$e';
      setState(() {
        _loading = false;
        _ok = false;
        _message = msg;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(FolioSpace.xl),
              child: Column(
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
                  if (_loading)
                    const Center(child: CircularProgressIndicator())
                  else ...[
                    Icon(
                      _ok
                          ? Icons.school_outlined
                          : Icons.error_outline,
                      size: 48,
                      color: _ok ? scheme.primary : scheme.error,
                    ),
                    const SizedBox(height: FolioSpace.md),
                    Text(
                      _ok
                          ? 'Correo de estudiante verificado'
                          : 'No se pudo verificar',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: FolioSpace.sm),
                    Text(
                      _message ?? '',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: FolioSpace.xl),
                    FilledButton(
                      onPressed: _goHome,
                      child: const Text('Ir a Folio'),
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
