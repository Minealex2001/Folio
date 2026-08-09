import 'package:flutter/material.dart';

import '../../app/app_settings.dart';
import '../../app/ui_tokens.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../models/vault_memory_fact.dart';

/// Fase A4 del plan Quill/MCP — gestión de los hechos que Quill incluye
/// automáticamente como contexto. Dos grupos separados (temporal/permanente,
/// ver `vault_memory_fact.dart`) con una acción rápida de "vaciar
/// temporales" — mismo patrón de pantalla que la gestión de presets de
/// `QuillSystemPrompt` (lista + añadir + borrar), sin diseñar una nueva.
class VaultMemoryFactsPage extends StatefulWidget {
  const VaultMemoryFactsPage({super.key, required this.appSettings});

  final AppSettings appSettings;

  @override
  State<VaultMemoryFactsPage> createState() => _VaultMemoryFactsPageState();
}

class _VaultMemoryFactsPageState extends State<VaultMemoryFactsPage> {
  Future<void> _addFact(MemoryFactScope scope) async {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          scope == MemoryFactScope.temporary
              ? l10n.vaultMemoryFactsAddTemporaryTitle
              : l10n.vaultMemoryFactsAddPermanentTitle,
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: InputDecoration(hintText: l10n.vaultMemoryFactsAddHint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: Text(l10n.vaultMemoryFactsAddConfirm),
          ),
        ],
      ),
    );
    final trimmed = text?.trim() ?? '';
    if (trimmed.isEmpty) return;
    await widget.appSettings.addVaultMemoryFact(
      VaultMemoryFact(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        text: trimmed,
        createdAt: DateTime.now(),
        scope: scope,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    return AnimatedBuilder(
      animation: widget.appSettings,
      builder: (context, _) {
        final facts = widget.appSettings.vaultMemoryFacts;
        final temporary = facts.where((f) => f.scope == MemoryFactScope.temporary).toList();
        final permanent = facts.where((f) => f.scope == MemoryFactScope.permanent).toList();

        Widget factTile(VaultMemoryFact fact) {
          return ListTile(
            leading: Icon(
              fact.scope == MemoryFactScope.temporary
                  ? Icons.schedule_rounded
                  : Icons.push_pin_rounded,
              color: scheme.onSurfaceVariant,
            ),
            title: Text(fact.text),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              tooltip: l10n.vaultMemoryFactsDelete,
              onPressed: () => widget.appSettings.deleteVaultMemoryFact(fact.id),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(title: Text(l10n.vaultMemoryFactsTitle)),
          body: facts.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      l10n.vaultMemoryFactsEmpty,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.only(bottom: 24),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              l10n.vaultMemoryFactsTemporarySection,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ),
                          if (temporary.isNotEmpty)
                            TextButton(
                              onPressed: () =>
                                  widget.appSettings.clearTemporaryVaultMemoryFacts(),
                              child: Text(l10n.vaultMemoryFactsClearTemporary),
                            ),
                        ],
                      ),
                    ),
                    if (temporary.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          l10n.vaultMemoryFactsTemporaryEmpty,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    else
                      for (final fact in temporary) factTile(fact),
                    const Divider(height: 24),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                      child: Text(
                        l10n.vaultMemoryFactsPermanentSection,
                        style: Theme.of(
                          context,
                        ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    if (permanent.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          l10n.vaultMemoryFactsPermanentEmpty,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    else
                      for (final fact in permanent) factTile(fact),
                  ],
                ),
          floatingActionButton: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FloatingActionButton.extended(
                heroTag: 'add_temp_fact',
                onPressed: () => _addFact(MemoryFactScope.temporary),
                icon: const Icon(Icons.schedule_rounded),
                label: Text(l10n.vaultMemoryFactsAddTemporaryShort),
              ),
              const SizedBox(width: FolioSpace.sm),
              FloatingActionButton.extended(
                heroTag: 'add_permanent_fact',
                onPressed: () => _addFact(MemoryFactScope.permanent),
                icon: const Icon(Icons.push_pin_rounded),
                label: Text(l10n.vaultMemoryFactsAddPermanentShort),
              ),
            ],
          ),
        );
      },
    );
  }
}
