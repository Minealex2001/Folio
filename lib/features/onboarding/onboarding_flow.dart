import 'package:flutter/material.dart';

import '../../session/vault_session.dart';

class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({super.key, required this.session});

  final VaultSession session;

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  final _pageController = PageController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  var _page = 0;
  String? _error;
  var _busy = false;

  @override
  void dispose() {
    _pageController.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  static const _minLen = 10;

  void _next() {
    setState(() {
      _error = null;
      if (_page == 1) {
        final p = _password.text;
        final c = _confirm.text;
        if (p.length < _minLen) {
          _error = 'Mínimo $_minLen caracteres.';
          return;
        }
        if (p != c) {
          _error = 'Las contraseñas no coinciden.';
          return;
        }
      }
      _page++;
      _pageController.animateToPage(
        _page,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _finish() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.session.completeOnboarding(_password.text);
    } catch (e) {
      setState(() {
        _busy = false;
        _error = 'No se pudo crear el cofre: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(
                    'Folio',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Paso ${_page + 1} de 3',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Colors.black54,
                    ),
              ),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _stepWelcome(context),
                    _stepPassword(context),
                    _stepReady(context),
                  ],
                ),
              ),
              if (_error != null) ...[
                Text(
                  _error!,
                  style: const TextStyle(color: Colors.redAccent),
                ),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _stepWelcome(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 32),
        Text(
          'Bienvenida',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Folio guarda tus páginas solo en este dispositivo, cifradas con la contraseña que vas a elegir. '
          'Si la olvidas, no podremos recuperar los datos.\n\n'
          'No hay sincronización en la nube.',
          style: TextStyle(height: 1.45, fontSize: 15),
        ),
        const Spacer(),
        FilledButton(
          onPressed: _next,
          child: const Text('Continuar'),
        ),
      ],
    );
  }

  Widget _stepPassword(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 32),
        Text(
          'Tu contraseña maestra',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 12),
        Text(
          'Al menos $_minLen caracteres. La usarás cada vez que abras Folio.',
          style: const TextStyle(color: Colors.black54, height: 1.4),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _password,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Contraseña',
            border: OutlineInputBorder(),
          ),
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _confirm,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Confirmar contraseña',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) => _next(),
        ),
        const Spacer(),
        Row(
          children: [
            TextButton(
              onPressed: () {
                setState(() {
                  _page = 0;
                  _pageController.jumpToPage(0);
                });
              },
              child: const Text('Atrás'),
            ),
            const Spacer(),
            FilledButton(
              onPressed: _next,
              child: const Text('Siguiente'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _stepReady(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 32),
        Text(
          'Todo listo',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Se creará un cofre cifrado en este equipo. Podrás añadir después '
          'Windows Hello, biometría o una passkey para desbloquear más rápido (Ajustes).',
          style: TextStyle(height: 1.45, fontSize: 15),
        ),
        const Spacer(),
        Row(
          children: [
            TextButton(
              onPressed: () {
                setState(() {
                  _page = 1;
                  _pageController.jumpToPage(1);
                });
              },
              child: const Text('Atrás'),
            ),
            const Spacer(),
            FilledButton(
              onPressed: _busy ? null : _finish,
              child: _busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Crear cofre'),
            ),
          ],
        ),
      ],
    );
  }
}
