import 'package:flutter/material.dart';

import '../../app/app_settings.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../models/quill_workflow.dart';

/// Fase A5 del plan Quill/MCP — gestión de Workflows: crear/editar (edición
/// = nueva versión archivada, nunca sobrescribe en silencio)/borrar, y ver
/// el historial de versiones de cada uno.
class QuillWorkflowsPage extends StatefulWidget {
  const QuillWorkflowsPage({super.key, required this.appSettings});

  final AppSettings appSettings;

  @override
  State<QuillWorkflowsPage> createState() => _QuillWorkflowsPageState();
}

class _QuillWorkflowsPageState extends State<QuillWorkflowsPage> {
  /// Fase 6 de Quill 2.0 — `readOnly` para presets `isSystemDefault` (mismo
  /// guard que ya usa `_showEditQuillPromptDialog` para
  /// `QuillSystemPrompt.isSystemDefault`): se reinsertan en cada `load()` de
  /// `AppSettings`, así que editarlos/borrarlos no persistiría de verdad.
  Future<void> _showEditor({QuillWorkflow? existing, bool readOnly = false}) async {
    final l10n = AppLocalizations.of(context);
    final nameController = TextEditingController(text: existing?.name ?? '');
    final promptController = TextEditingController(text: existing?.promptTemplate ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          existing == null
              ? l10n.quillWorkflowsAddTitle
              : (readOnly ? l10n.quillWorkflowsViewTitle : l10n.quillWorkflowsEditTitle),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!readOnly) ...[
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: InputDecoration(hintText: l10n.quillWorkflowsNameHint),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: promptController,
              maxLines: 5,
              readOnly: readOnly,
              decoration: InputDecoration(hintText: l10n.quillWorkflowsPromptHint),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(readOnly ? l10n.quillPromptBack : l10n.cancel),
          ),
          if (!readOnly)
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(l10n.quillWorkflowsSave),
            ),
        ],
      ),
    );
    if (readOnly || saved != true) return;
    final name = nameController.text.trim();
    final prompt = promptController.text.trim();
    if (name.isEmpty || prompt.isEmpty) return;
    if (existing == null) {
      await widget.appSettings.addQuillWorkflow(
        QuillWorkflow(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          name: name,
          currentVersion: 1,
          promptTemplate: prompt,
        ),
      );
    } else {
      await widget.appSettings.updateQuillWorkflow(
        existing.edited(newPromptTemplate: prompt, newName: name),
      );
    }
  }

  void _showHistory(QuillWorkflow workflow) {
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Text(
                  l10n.quillWorkflowsHistoryTitle,
                  style: Theme.of(sheetContext).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (workflow.history.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Text(l10n.quillWorkflowsHistoryEmpty),
                )
              else
                for (final version in workflow.history.reversed)
                  ListTile(
                    title: Text(l10n.quillWorkflowsVersionLabel(version.version)),
                    subtitle: Text(
                      version.promptTemplate,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: TextButton(
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        widget.appSettings.updateQuillWorkflow(
                          workflow.edited(newPromptTemplate: version.promptTemplate),
                        );
                      },
                      child: Text(l10n.quillWorkflowsRestoreVersion),
                    ),
                  ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    return AnimatedBuilder(
      animation: widget.appSettings,
      builder: (context, _) {
        final workflows = widget.appSettings.quillWorkflows;
        return Scaffold(
          appBar: AppBar(title: Text(l10n.quillWorkflowsTitle)),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _showEditor(),
            child: const Icon(Icons.add_rounded),
          ),
          body: workflows.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      l10n.quillWorkflowsEmpty,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.only(bottom: 80),
                  children: [
                    for (final workflow in workflows)
                      ListTile(
                        leading: Icon(
                          workflow.isSystemDefault
                              ? Icons.auto_awesome_motion
                              : Icons.auto_awesome_motion_outlined,
                          color: workflow.isSystemDefault ? scheme.primary : null,
                        ),
                        title: Text(workflow.name),
                        subtitle: Text(
                          workflow.promptTemplate,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(l10n.quillWorkflowsVersionLabel(workflow.currentVersion)),
                            IconButton(
                              icon: const Icon(Icons.history_rounded),
                              tooltip: l10n.quillWorkflowsHistoryTitle,
                              onPressed: () => _showHistory(workflow),
                            ),
                            if (!workflow.isSystemDefault)
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded),
                                tooltip: l10n.quillWorkflowsDelete,
                                onPressed: () =>
                                    widget.appSettings.deleteQuillWorkflow(workflow.id),
                              ),
                          ],
                        ),
                        onTap: () => _showEditor(
                          existing: workflow,
                          readOnly: workflow.isSystemDefault,
                        ),
                      ),
                  ],
                ),
        );
      },
    );
  }
}
