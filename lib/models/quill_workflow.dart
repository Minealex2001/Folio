/// Fase A5 del plan Quill/MCP — "Workflows" son atajos nombrados y
/// parametrizados hacia el flujo propone→aprueba→ejecuta de Plan-mode que
/// ya existe (`agentChatWithAiPlanProposal`/`agentChatWithAiExecuteApprovedPlan`)
/// — no un ejecutor de pasos nuevo. `promptTemplate` es literalmente el
/// texto que normalmente se escribe en el chat, con `{{variable}}`
/// opcionales resueltas antes de enviar.
final RegExp _kWorkflowVariablePattern = RegExp(r'\{\{(\w+)\}\}');

/// Una versión archivada de un workflow — se crea automáticamente cada vez
/// que se edita `promptTemplate`, nunca se sobrescribe silenciosamente.
class QuillWorkflowVersion {
  const QuillWorkflowVersion({
    required this.version,
    required this.promptTemplate,
    required this.savedAt,
  });

  final int version;
  final String promptTemplate;
  final DateTime savedAt;

  Map<String, dynamic> toJson() => {
        'version': version,
        'promptTemplate': promptTemplate,
        'savedAt': savedAt.toIso8601String(),
      };

  factory QuillWorkflowVersion.fromJson(Map<String, dynamic> json) {
    return QuillWorkflowVersion(
      version: (json['version'] as num?)?.toInt() ?? 1,
      promptTemplate: json['promptTemplate'] as String? ?? '',
      savedAt: DateTime.tryParse(json['savedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class QuillWorkflow {
  const QuillWorkflow({
    required this.id,
    required this.name,
    required this.currentVersion,
    required this.promptTemplate,
    this.history = const [],
  });

  final String id;
  final String name;
  final int currentVersion;
  final String promptTemplate;

  /// Versiones anteriores, más antigua primero — nunca se pierde una al
  /// editar (ver `QuillWorkflow.edited`).
  final List<QuillWorkflowVersion> history;

  /// Ids de variable extraídos de `{{variable}}` en `promptTemplate`, en
  /// orden de aparición y sin duplicados.
  List<String> get variableIds {
    final seen = <String>{};
    final ids = <String>[];
    for (final m in _kWorkflowVariablePattern.allMatches(promptTemplate)) {
      final id = m.group(1)!;
      if (seen.add(id)) ids.add(id);
    }
    return ids;
  }

  /// Sustituye cada `{{variable}}` por la respuesta correspondiente en
  /// [answers] (vacío si falta) y devuelve el prompt final a enviar.
  String resolve(Map<String, String> answers) {
    return promptTemplate.replaceAllMapped(_kWorkflowVariablePattern, (m) {
      final id = m.group(1)!;
      return answers[id]?.trim() ?? '';
    });
  }

  /// Aplica una edición de `promptTemplate`: archiva la versión actual en
  /// `history` y sube `currentVersion`. Nunca sobrescribe en silencio.
  QuillWorkflow edited({required String newPromptTemplate, String? newName}) {
    if (newPromptTemplate == promptTemplate && newName == null) return this;
    return QuillWorkflow(
      id: id,
      name: newName ?? name,
      currentVersion: currentVersion + 1,
      promptTemplate: newPromptTemplate,
      history: [
        ...history,
        QuillWorkflowVersion(
          version: currentVersion,
          promptTemplate: promptTemplate,
          savedAt: DateTime.now(),
        ),
      ],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'currentVersion': currentVersion,
        'promptTemplate': promptTemplate,
        if (history.isNotEmpty) 'history': history.map((h) => h.toJson()).toList(),
      };

  factory QuillWorkflow.fromJson(Map<String, dynamic> json) {
    final rawHistory = json['history'] as List<dynamic>? ?? const [];
    return QuillWorkflow(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      currentVersion: (json['currentVersion'] as num?)?.toInt() ?? 1,
      promptTemplate: json['promptTemplate'] as String? ?? '',
      history: rawHistory
          .whereType<Map>()
          .map((h) => QuillWorkflowVersion.fromJson(Map<String, dynamic>.from(h)))
          .toList(),
    );
  }
}
