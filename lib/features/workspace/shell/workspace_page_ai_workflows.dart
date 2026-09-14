part of 'workspace_page.dart';

/// Fase A5 del plan Quill/MCP — "Workflows": atajos nombrados y
/// parametrizados hacia el Plan-mode que ya existe (`_sendAiChat` con
/// `_planModeEnabled` forzado), no un ejecutor nuevo. Cuando el workflow
/// tiene `{{variable}}`, reutiliza literalmente `SmartTemplateFlowOverlay`
/// (Fase G2) — el mismo mini-flujo secuencial de preguntas ya construido y
/// testeado para `/meeting`/`/sprint` — envolviendo el `QuillWorkflow` en un
/// `SmartTemplateDefinition` adaptador (el overlay nunca llama a
/// `buildBlocks`, así que un builder vacío es seguro).
extension _WorkspacePageAiWorkflowsModule on _WorkspacePageState {
  void _openQuillWorkflowsPicker() {
    final l10n = AppLocalizations.of(context);
    final workflows = widget.appSettings.quillWorkflows;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        if (workflows.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              l10n.quillWorkflowsEmptyPicker,
              textAlign: TextAlign.center,
            ),
          );
        }
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Text(
                  l10n.quillWorkflowsPickerTitle,
                  style: Theme.of(
                    sheetContext,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              for (final workflow in workflows)
                ListTile(
                  leading: const Icon(Icons.auto_awesome_motion_outlined),
                  title: Text(workflow.name),
                  subtitle: Text(
                    workflow.promptTemplate,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _runQuillWorkflow(workflow);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  void _runQuillWorkflow(QuillWorkflow workflow) {
    if (workflow.variableIds.isEmpty) {
      _sendQuillWorkflowPrompt(workflow.resolve(const {}));
      return;
    }
    _showQuillWorkflowVariableFlow(workflow);
  }

  void _showQuillWorkflowVariableFlow(QuillWorkflow workflow) {
    if (_quillWorkflowOverlayEntry != null) return;
    final adapter = SmartTemplateDefinition(
      key: 'workflow_${workflow.id}',
      labelOf: (_) => workflow.name,
      hintOf: (_) => workflow.name,
      icon: Icons.auto_awesome_motion_outlined,
      variables: [
        for (final id in workflow.variableIds)
          TemplateVariable(id: id, promptOf: (_) => humanizeWorkflowVariableId(id)),
      ],
      buildBlocks: (_, _, _) => const [],
    );
    final overlay = Overlay.of(context, rootOverlay: true);
    final entry = OverlayEntry(
      builder: (overlayContext) => SmartTemplateFlowOverlay(
        template: adapter,
        onComplete: (answers) {
          _dismissQuillWorkflowVariableFlow();
          _sendQuillWorkflowPrompt(workflow.resolve(answers));
        },
        onCancel: _dismissQuillWorkflowVariableFlow,
      ),
    );
    _quillWorkflowOverlayEntry = entry;
    overlay.insert(entry);
    if (mounted) _setStateSafe(() {});
  }

  void _dismissQuillWorkflowVariableFlow() {
    _quillWorkflowOverlayEntry?.remove();
    _quillWorkflowOverlayEntry = null;
    if (mounted) _setStateSafe(() {});
  }

  /// Fuerza el modo Plan para este envío (el propio diseño del plan: los
  /// workflows son atajos hacia Plan-mode, con su propuesta-antes-de-
  /// ejecutar) y reutiliza el envío normal del composer — mismo camino que
  /// si el usuario hubiera escrito el prompt a mano.
  void _sendQuillWorkflowPrompt(String prompt) {
    final trimmed = prompt.trim();
    if (trimmed.isEmpty) return;
    _planModeByChatId[_activeChat.id] = true;
    _chatInputController.text = trimmed;
    unawaited(_sendAiChat());
  }
}

/// Fase 8 de Quill 2.0 — antes, la variable `{{tema}}` de un workflow se
/// mostraba al usuario tal cual (el id interno), no como una etiqueta
/// legible. `QuillWorkflow` no guarda metadatos de variable (sería una
/// feature nueva, no "polish"), así que este es solo un fallback de
/// formato: guiones/guiones bajos a espacios, primera letra en mayúscula.
/// Función de nivel superior (no un método de `_WorkspacePageState`) para
/// poder testearla sin necesitar el árbol de widgets completo.
String humanizeWorkflowVariableId(String id) {
  final spaced = id.replaceAll(RegExp(r'[_-]+'), ' ').trim();
  if (spaced.isEmpty) return id;
  return spaced[0].toUpperCase() + spaced.substring(1);
}
