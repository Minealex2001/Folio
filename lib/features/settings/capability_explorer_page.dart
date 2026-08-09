import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/ui_tokens.dart';
import '../../app/widgets/folio_dialog.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../services/ai/ai_tool.dart';
import '../../services/ai/folio_tool_registry.dart';
import '../../session/vault_session.dart';

/// Fase B4 del plan Quill/MCP — explorador de capacidades interactivo, tipo
/// Swagger/Postman: para cada tool del `FolioToolRegistry` real de la app se
/// puede ver su metadata (categoría, complejidad, si es reversible/requiere
/// confirmación), rellenar sus parámetros, previsualizar (si soporta
/// `preview()`, Fase B1) y ejecutarla de verdad — pasando por el mismo gate
/// de confirmación que cualquier otro llamador (chat, MCP), nunca un atajo
/// especial para esta pantalla.
class CapabilityExplorerPage extends StatefulWidget {
  const CapabilityExplorerPage({super.key, required this.session});

  final VaultSession session;

  @override
  State<CapabilityExplorerPage> createState() => _CapabilityExplorerPageState();
}

class _CapabilityExplorerPageState extends State<CapabilityExplorerPage> {
  late final FolioToolRegistry _registry;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _registry = FolioToolRegistry(
      widget.session,
      onConfirmIrreversibleTool: _confirmIrreversible,
    );
  }

  Future<bool> _confirmIrreversible(
    String toolName,
    Map<String, dynamic> arguments,
  ) async {
    final preview = _registry.preview(
      AiToolCall(id: 'explorer_confirm', name: toolName, arguments: arguments),
    );
    if (!mounted) return false;
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => FolioDialog(
        title: Text(l10n.capabilityExplorerConfirmTitle),
        content: Text(preview?.summary ?? toolName),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.capabilityExplorerCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.capabilityExplorerExecute),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final query = _query.trim().toLowerCase();
    final grouped = <AiToolCategory, List<AiToolDefinition>>{};
    for (final def in _registry.definitions) {
      if (query.isNotEmpty &&
          !def.name.toLowerCase().contains(query) &&
          !def.description.toLowerCase().contains(query)) {
        continue;
      }
      grouped.putIfAbsent(def.category, () => []).add(def);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.capabilityExplorerTitle),
        actions: [
          IconButton(
            tooltip: l10n.capabilityExplorerExportAll,
            icon: const Icon(Icons.ios_share_rounded),
            onPressed: () => _exportToClipboard(
              context,
              _jsonEncodePretty([
                for (final def in _registry.definitions) def.toMetadataJson(),
              ]),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded),
                hintText: l10n.capabilityExplorerSearchHint,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(FolioRadius.lg),
                ),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: grouped.isEmpty
                ? Center(child: Text(l10n.capabilityExplorerNoResults))
                : ListView(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                    children: [
                      for (final category in AiToolCategory.values)
                        if (grouped[category]?.isNotEmpty == true) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(8, 12, 8, 6),
                            child: Text(
                              _categoryLabel(l10n, category),
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ),
                          for (final def in grouped[category]!)
                            _ToolCard(
                              definition: def,
                              registry: _registry,
                              onExport: (json) => _exportToClipboard(context, json),
                            ),
                        ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  String _categoryLabel(AppLocalizations l10n, AiToolCategory category) {
    switch (category) {
      case AiToolCategory.content:
        return l10n.capabilityExplorerCategoryContent;
      case AiToolCategory.organization:
        return l10n.capabilityExplorerCategoryOrganization;
      case AiToolCategory.task:
        return l10n.capabilityExplorerCategoryTask;
      case AiToolCategory.media:
        return l10n.capabilityExplorerCategoryMedia;
      case AiToolCategory.destructive:
        return l10n.capabilityExplorerCategoryDestructive;
      case AiToolCategory.experimental:
        return l10n.capabilityExplorerCategoryExperimental;
    }
  }

  void _exportToClipboard(BuildContext context, String json) {
    Clipboard.setData(ClipboardData(text: json));
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.capabilityExplorerExportedToClipboard)),
    );
  }
}

String _jsonEncodePretty(Object? value) =>
    const JsonEncoder.withIndent('  ').convert(value);

class _ToolCard extends StatefulWidget {
  const _ToolCard({
    required this.definition,
    required this.registry,
    required this.onExport,
  });

  final AiToolDefinition definition;
  final FolioToolRegistry registry;
  final void Function(String json) onExport;

  @override
  State<_ToolCard> createState() => _ToolCardState();
}

class _ToolCardState extends State<_ToolCard> {
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, bool> _boolValues = {};
  bool _busy = false;
  AiToolPreview? _lastPreview;
  AiToolResult? _lastResult;
  String? _formError;

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _controllerFor(String name) =>
      _controllers.putIfAbsent(name, TextEditingController.new);

  Map<String, dynamic>? _collectArguments() {
    final args = <String, dynamic>{};
    for (final p in widget.definition.parameters) {
      if (p.type == 'boolean') {
        final v = _boolValues[p.name];
        if (v != null) args[p.name] = v;
        continue;
      }
      final raw = _controllers[p.name]?.text.trim() ?? '';
      if (raw.isEmpty) {
        if (p.required) {
          setState(() => _formError = 'Falta "${p.name}".');
          return null;
        }
        continue;
      }
      switch (p.type) {
        case 'number':
        case 'integer':
          final n = num.tryParse(raw);
          if (n == null) {
            setState(() => _formError = '"${p.name}" debe ser numérico.');
            return null;
          }
          args[p.name] = p.type == 'integer' ? n.toInt() : n;
        case 'array':
        case 'object':
          try {
            args[p.name] = jsonDecode(raw);
          } catch (_) {
            setState(() => _formError = '"${p.name}" debe ser JSON válido.');
            return null;
          }
        default:
          args[p.name] = raw;
      }
    }
    setState(() => _formError = null);
    return args;
  }

  Future<void> _onPreview() async {
    final args = _collectArguments();
    if (args == null) return;
    final call = AiToolCall(id: 'explorer_preview', name: widget.definition.name, arguments: args);
    setState(() {
      _lastResult = null;
      _lastPreview = widget.registry.preview(call);
    });
  }

  Future<void> _onExecute() async {
    final args = _collectArguments();
    if (args == null) return;
    setState(() {
      _busy = true;
      _lastPreview = null;
    });
    final call = AiToolCall(id: 'explorer_execute', name: widget.definition.name, arguments: args);
    final result = await widget.registry.execute(call);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _lastResult = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final def = widget.definition;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: ExpansionTile(
        title: Text(def.name, style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()])),
        subtitle: Text(def.description, maxLines: 2, overflow: TextOverflow.ellipsis),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _MetaChip(label: def.complexity.name, color: scheme.secondary),
              if (!def.isReversible)
                _MetaChip(label: l10n.capabilityExplorerNotReversible, color: scheme.error),
              if (def.requiresConfirmation)
                _MetaChip(label: l10n.capabilityExplorerRequiresConfirmation, color: scheme.error),
              if (def.supportsPreview)
                _MetaChip(label: l10n.capabilityExplorerSupportsPreview, color: scheme.primary),
              if (def.estimatedDuration != null)
                _MetaChip(
                  label: '~${def.estimatedDuration!.inMilliseconds}ms',
                  color: scheme.tertiary,
                ),
            ],
          ),
          const SizedBox(height: 12),
          for (final p in def.parameters)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: p.type == 'boolean'
                  ? SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text(p.name + (p.required ? ' *' : '')),
                      subtitle: Text(p.description),
                      value: _boolValues[p.name] ?? false,
                      onChanged: (v) => setState(() => _boolValues[p.name] = v),
                    )
                  : TextField(
                      controller: _controllerFor(p.name),
                      decoration: InputDecoration(
                        labelText: p.name + (p.required ? ' *' : ''),
                        helperText: p.description,
                        helperMaxLines: 2,
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      maxLines: (p.type == 'array' || p.type == 'object') ? 3 : 1,
                    ),
            ),
          if (_formError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(_formError!, style: TextStyle(color: scheme.error)),
            ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (def.supportsPreview)
                OutlinedButton.icon(
                  onPressed: _busy ? null : _onPreview,
                  icon: const Icon(Icons.visibility_outlined, size: 18),
                  label: Text(l10n.capabilityExplorerPreview),
                ),
              FilledButton.icon(
                onPressed: _busy ? null : _onExecute,
                icon: _busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.play_arrow_rounded, size: 18),
                label: Text(l10n.capabilityExplorerExecute),
              ),
              OutlinedButton.icon(
                onPressed: () => widget.onExport(_jsonEncodePretty(def.toMetadataJson())),
                icon: const Icon(Icons.ios_share_rounded, size: 18),
                label: Text(l10n.capabilityExplorerExport),
              ),
            ],
          ),
          if (_lastPreview != null) ...[
            const SizedBox(height: 12),
            _ResultPanel(
              title: l10n.capabilityExplorerPreviewResultTitle,
              body: _lastPreview!.affectedItems.isEmpty
                  ? _lastPreview!.summary
                  : '${_lastPreview!.summary}\n'
                      '${_lastPreview!.affectedItems.map((e) => '• $e').join('\n')}',
              isError: false,
            ),
          ],
          if (_lastResult != null) ...[
            const SizedBox(height: 12),
            _ResultPanel(
              title: l10n.capabilityExplorerExecuteResultTitle,
              body: _lastResult!.content,
              isError: _lastResult!.isError,
            ),
          ],
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(FolioRadius.md),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ResultPanel extends StatelessWidget {
  const _ResultPanel({required this.title, required this.body, required this.isError});

  final String title;
  final String body;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isError
            ? scheme.errorContainer.withValues(alpha: 0.3)
            : scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(FolioRadius.md),
        border: Border.all(
          color: isError
              ? scheme.error.withValues(alpha: 0.4)
              : scheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          SelectableText(
            body,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
