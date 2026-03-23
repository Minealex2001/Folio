import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../data/vault_backup.dart';
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
  final _backupPassword = TextEditingController();

  var _page = 0;
  var _importMode = false;
  String? _backupZipPath;
  String? _error;
  var _busy = false;

  static const _minLen = 10;

  @override
  void dispose() {
    _pageController.dispose();
    _password.dispose();
    _confirm.dispose();
    _backupPassword.dispose();
    super.dispose();
  }

  String get _stepLabel {
    if (_importMode) {
      return 'Paso ${_page + 1} de 2';
    }
    return 'Paso ${_page + 1} de 3';
  }

  void _goPage(int i) {
    setState(() => _page = i);
    _pageController.animateToPage(
      i,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  void _chooseCreateNew() {
    setState(() {
      _error = null;
      _importMode = false;
    });
    _goPage(1);
  }

  void _chooseImport() {
    setState(() {
      _error = null;
      _importMode = true;
      _backupZipPath = null;
    });
    _goPage(1);
  }

  void _nextCreatePassword() {
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
      _page = 2;
      _pageController.animateToPage(
        2,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _pickBackupFile() async {
    setState(() => _error = null);
    final pick = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['zip'],
      allowMultiple: false,
    );
    if (!mounted) return;
    final path = pick?.files.single.path;
    if (path != null) {
      setState(() => _backupZipPath = path);
    }
  }

  Future<void> _finishImport() async {
    if (_backupZipPath == null) {
      setState(() => _error = 'Elige un archivo .zip.');
      return;
    }
    final pwd = _backupPassword.text;
    if (pwd.isEmpty) {
      setState(() => _error = 'Introduce la contraseña de la copia.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.session.completeOnboardingFromBackup(_backupZipPath!, pwd);
    } on VaultBackupException catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = '$e';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'No se pudo importar: $e';
        });
      }
    }
  }

  Future<void> _finishCreate() async {
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
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: widget.session.canCancelNewVaultOnboarding
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () async {
                  await widget.session.cancelPrepareNewVault();
                },
              ),
              title: const Text('Nuevo cofre'),
            )
          : null,
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
                      color: scheme.onSurface,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _stepLabel,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _stepWelcome(context),
                    _importMode
                        ? _stepImportBackup(context)
                        : _stepPassword(context),
                    _importMode ? const SizedBox.shrink() : _stepReady(context),
                  ],
                ),
              ),
              if (_error != null) ...[
                Text(_error!, style: TextStyle(color: scheme.error)),
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
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 16),
        const Text(
          'Folio guarda tus páginas solo en este dispositivo, cifradas con una contraseña maestra. '
          'Si la olvidas, no podremos recuperar los datos.\n\n'
          'No hay sincronización en la nube.',
          style: TextStyle(height: 1.45, fontSize: 15),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _chooseCreateNew,
          child: const Text('Crear cofre nuevo'),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: _chooseImport,
          child: const Text('Importar una copia (.zip)'),
        ),
      ],
    );
  }

  Widget _stepImportBackup(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 32),
        Text(
          'Importar copia',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Text(
          'El archivo contiene los mismos datos cifrados que en el otro equipo. '
          'Necesitas la contraseña maestra con la que se creó esa copia.\n\n'
          'La passkey y el desbloqueo rápido (Hello) no van en el archivo y no son transferibles; '
          'podrás configurarlos después en Ajustes.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            height: 1.45,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: _busy ? null : _pickBackupFile,
          icon: const Icon(Icons.folder_open_outlined),
          label: Text(
            _backupZipPath == null ? 'Elegir archivo .zip' : 'Cambiar archivo',
          ),
        ),
        if (_backupZipPath != null) ...[
          const SizedBox(height: 8),
          Text(
            _backupZipPath!,
            style: Theme.of(context).textTheme.bodySmall,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        const SizedBox(height: 16),
        TextField(
          controller: _backupPassword,
          obscureText: true,
          enabled: !_busy,
          decoration: const InputDecoration(
            labelText: 'Contraseña de la copia',
          ),
          onSubmitted: (_) {
            if (!_busy) _finishImport();
          },
        ),
        const Spacer(),
        Row(
          children: [
            TextButton(
              onPressed: _busy
                  ? null
                  : () {
                      setState(() {
                        _page = 0;
                        _pageController.jumpToPage(0);
                      });
                    },
              child: const Text('Atrás'),
            ),
            const Spacer(),
            FilledButton(
              onPressed: _busy ? null : _finishImport,
              child: _busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Importar cofre'),
            ),
          ],
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
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Text(
          'Al menos $_minLen caracteres. La usarás cada vez que abras Folio.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _password,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Contraseña'),
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _confirm,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Confirmar contraseña'),
          onSubmitted: (_) => _nextCreatePassword(),
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
              onPressed: _nextCreatePassword,
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
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
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
              onPressed: _busy ? null : _finishCreate,
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
