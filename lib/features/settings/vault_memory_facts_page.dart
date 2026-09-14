import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_settings.dart';
import '../../app/ui_tokens.dart';
import '../../app/widgets/folio_dialog.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../models/vault_memory_fact.dart';

/// Fase A4 del plan Quill/MCP — gestión de los hechos que Quill incluye
/// automáticamente como contexto. Dos grupos separados (temporal/permanente,
/// ver `vault_memory_fact.dart`) con una acción rápida de "vaciar
/// temporales" — mismo patrón de pantalla que la gestión de presets de
/// `QuillSystemPrompt` (lista + añadir + borrar), sin diseñar una nueva.
///
/// Fase 5 de Quill 2.0 — los hechos están aislados por libreta (`vaultId`),
/// así que la lectura pasa a ser asíncrona (`AppSettings.getVaultMemoryFacts`)
/// en vez del getter síncrono que antes devolvía la única lista global.
class VaultMemoryFactsPage extends StatefulWidget {
  const VaultMemoryFactsPage({
    super.key,
    required this.appSettings,
    required this.vaultId,
  });

  final AppSettings appSettings;
  final String? vaultId;

  @override
  State<VaultMemoryFactsPage> createState() => _VaultMemoryFactsPageState();
}

class _VaultMemoryFactsPageState extends State<VaultMemoryFactsPage> {
  List<VaultMemoryFact> _facts = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    widget.appSettings.addListener(_onAppSettingsChanged);
    unawaited(_reload());
  }

  @override
  void dispose() {
    widget.appSettings.removeListener(_onAppSettingsChanged);
    super.dispose();
  }

  void _onAppSettingsChanged() {
    unawaited(_reload());
  }

  Future<void> _reload() async {
    final facts = await widget.appSettings.getVaultMemoryFacts(widget.vaultId);
    if (!mounted) return;
    setState(() {
      _facts = facts;
      _loading = false;
    });
  }

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
      widget.vaultId,
      VaultMemoryFact(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        text: trimmed,
        createdAt: DateTime.now(),
        scope: scope,
      ),
    );
  }

  /// Fase 8 de Quill 2.0 — antes, borrar un hecho (o vaciar todos los
  /// temporales) era inmediato, sin confirmación ni undo, pese a que Quill
  /// los usa activamente como contexto en cada mensaje. Mismo patrón de
  /// diálogo destructivo que `vault_trash_sheet.dart` (`FolioDialog` +
  /// botón en `scheme.error`).
  Future<bool> _confirmDestructive({
    required String title,
    required String body,
    required String confirmLabel,
  }) async {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => FolioDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: scheme.error,
              foregroundColor: scheme.onError,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _deleteFact(VaultMemoryFact fact) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await _confirmDestructive(
      title: l10n.vaultMemoryFactsDelete,
      body: l10n.vaultMemoryFactsDeleteConfirm,
      confirmLabel: l10n.vaultMemoryFactsDelete,
    );
    if (!confirmed) return;
    await widget.appSettings.deleteVaultMemoryFact(widget.vaultId, fact.id);
  }

  Future<void> _clearTemporary() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await _confirmDestructive(
      title: l10n.vaultMemoryFactsClearTemporary,
      body: l10n.vaultMemoryFactsClearTemporaryConfirm,
      confirmLabel: l10n.vaultMemoryFactsClearTemporary,
    );
    if (!confirmed) return;
    await widget.appSettings.clearTemporaryVaultMemoryFacts(widget.vaultId);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.vaultMemoryFactsTitle)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final facts = _facts;
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
          onPressed: () => _deleteFact(fact),
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
                          onPressed: _clearTemporary,
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
  }
}
