import 'package:flutter/material.dart';
import 'package:passkeys/exceptions.dart';

import '../../session/vault_session.dart';
import 'widgets/block_editor.dart';
import 'widgets/sidebar.dart';

class WorkspacePage extends StatefulWidget {
  const WorkspacePage({super.key, required this.session});

  final VaultSession session;

  @override
  State<WorkspacePage> createState() => _WorkspacePageState();
}

class _WorkspacePageState extends State<WorkspacePage> {
  late final TextEditingController _titleController;

  VaultSession get _s => widget.session;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _s.addListener(_onSession);
    _syncTitleFromSession();
  }

  @override
  void dispose() {
    _s.removeListener(_onSession);
    _titleController.dispose();
    super.dispose();
  }

  void _onSession() {
    if (!mounted) return;
    _syncTitleFromSession();
    setState(() {});
  }

  void _syncTitleFromSession() {
    final p = _s.selectedPage;
    final next = p?.title ?? '';
    if (_titleController.text != next) {
      _titleController.value = TextEditingValue(
        text: next,
        selection: TextSelection.collapsed(offset: next.length),
      );
    }
  }

  Future<void> _openSettings(BuildContext context) async {
    final quick = await _s.quickUnlockEnabled;
    final pk = await _s.hasPasskey;
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              const ListTile(title: Text('Seguridad')),
              ListTile(
                leading: const Icon(Icons.fingerprint),
                title: const Text('Desbloqueo rápido (Hello / biometría)'),
                subtitle: Text(quick ? 'Activado' : 'Desactivado'),
                trailing: quick
                    ? TextButton(
                        onPressed: () async {
                          await _s.disableQuickUnlock();
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Desbloqueo rápido desactivado')),
                            );
                          }
                        },
                        child: const Text('Quitar'),
                      )
                    : FilledButton.tonal(
                        onPressed: () async {
                          try {
                            await _s.enableDeviceQuickUnlock();
                            if (ctx.mounted) Navigator.pop(ctx);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Desbloqueo rápido activado')),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('$e')),
                              );
                            }
                          }
                        },
                        child: const Text('Activar'),
                      ),
              ),
              ListTile(
                leading: const Icon(Icons.key_rounded),
                title: const Text('Registrar passkey'),
                subtitle: const Text('WebAuthn en este dispositivo'),
                trailing: pk
                    ? TextButton(
                        onPressed: () async {
                          await _s.revokePasskey();
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Passkey revocada'),
                              ),
                            );
                          }
                        },
                        child: const Text('Revocar'),
                      )
                    : FilledButton.tonal(
                        onPressed: () async {
                          try {
                            await _s.registerPasskey();
                            if (ctx.mounted) Navigator.pop(ctx);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Passkey registrada')),
                              );
                            }
                          } on PasskeyAuthCancelledException {
                            // ignorar
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Passkey: $e')),
                              );
                            }
                          }
                        },
                        child: const Text('Registrar'),
                      ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.lock_outline),
                title: const Text('Bloquear ahora'),
                onTap: () {
                  Navigator.pop(ctx);
                  _s.lock();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final page = _s.selectedPage;

    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: const Text('Folio'),
        actions: [
          IconButton(
            tooltip: 'Ajustes',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => _openSettings(context),
          ),
          IconButton(
            tooltip: 'Bloquear',
            icon: const Icon(Icons.lock_outline),
            onPressed: () => _s.lock(),
          ),
        ],
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 300,
            child: Material(
              color: scheme.surfaceContainerLow,
              child: Sidebar(session: _s),
            ),
          ),
          VerticalDivider(
            width: 1,
            thickness: 1,
            color: scheme.outlineVariant,
          ),
          Expanded(
            child: Material(
              color: scheme.surface,
              child: page == null
                  ? const Center(child: Text('Sin páginas'))
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(28, 20, 28, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: _titleController,
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: scheme.onSurface,
                                ),
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              filled: false,
                              hintText: 'Sin título',
                              isDense: true,
                              hintStyle: TextStyle(
                                color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                              ),
                            ),
                            onChanged: (v) {
                              if (page.id == _s.selectedPageId) {
                                _s.renamePage(page.id, v);
                              }
                            },
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: BlockEditor(
                              key: ValueKey(page.id),
                              session: _s,
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
