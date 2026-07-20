import 'dart:convert';

class GitLabIntegrationState {
  const GitLabIntegrationState({
    this.connections = const [],
    this.sources = const [],
  });

  final List<GitLabConnection> connections;
  final List<GitLabSource> sources;

  static const GitLabIntegrationState empty = GitLabIntegrationState();

  Map<String, Object?> toJson() => <String, Object?>{
        'connections': connections.map((c) => c.toJson()).toList(growable: false),
        'sources': sources.map((s) => s.toJson()).toList(growable: false),
      };

  static GitLabIntegrationState fromJson(Object? raw) {
    if (raw is! Map) return empty;
    final m = Map<String, dynamic>.from(raw);
    final conns = <GitLabConnection>[];
    final sources = <GitLabSource>[];
    final rawConnections = m['connections'];
    if (rawConnections is List) {
      for (final item in rawConnections) {
        if (item is Map) {
          final c = GitLabConnection.tryParse(Map<String, dynamic>.from(item));
          if (c != null) conns.add(c);
        }
      }
    }
    final rawSources = m['sources'];
    if (rawSources is List) {
      for (final item in rawSources) {
        if (item is Map) {
          final s = GitLabSource.tryParse(Map<String, dynamic>.from(item));
          if (s != null) sources.add(s);
        }
      }
    }
    return GitLabIntegrationState(
      connections: List.unmodifiable(conns),
      sources: List.unmodifiable(sources),
    );
  }

  String encode() => jsonEncode(toJson());
}

class GitLabConnection {
  const GitLabConnection({
    required this.id,
    required this.label,
    required this.baseUrl,
    required this.token,
  });

  final String id;
  final String label;

  /// URL base de la instancia GitLab, p. ej. `https://gitlab.com` o una
  /// instancia self-hosted. Sin `/` final (normalizado al construir).
  final String baseUrl;

  /// Personal Access Token (scope `api`) pegado por el usuario.
  final String token;

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'label': label,
        'baseUrl': baseUrl,
        'token': token,
      };

  static GitLabConnection? tryParse(Map<String, dynamic> map) {
    final id = (map['id'] as String? ?? '').trim();
    final label = (map['label'] as String? ?? '').trim();
    final baseUrl = (map['baseUrl'] as String? ?? '').trim();
    final token = (map['token'] as String? ?? '').trim();
    if (id.isEmpty || label.isEmpty || baseUrl.isEmpty || token.isEmpty) return null;
    return GitLabConnection(id: id, label: label, baseUrl: baseUrl, token: token);
  }

  GitLabConnection copyWith({
    String? label,
    String? baseUrl,
    String? token,
  }) {
    return GitLabConnection(
      id: id,
      label: label ?? this.label,
      baseUrl: baseUrl ?? this.baseUrl,
      token: token ?? this.token,
    );
  }
}

class GitLabSource {
  const GitLabSource({
    required this.id,
    required this.connectionId,
    required this.name,
    required this.projectPath,
    this.includeMergeRequests = true,
    this.importOptions = const GitLabImportOptions(),
    this.columnMappings = const [],
    this.priorityLabelMappings = const [],
  });

  final String id;
  final String connectionId;
  final String name;

  /// Ruta completa del proyecto (namespace anidado incluido),
  /// p. ej. `group/subgroup/project`.
  final String projectPath;

  /// Si es `false`, el pull no trae Merge Requests, solo Issues.
  final bool includeMergeRequests;

  final GitLabImportOptions importOptions;
  final List<GitLabColumnMapping> columnMappings;
  final List<GitLabPriorityLabelMapping> priorityLabelMappings;

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'connectionId': connectionId,
        'name': name,
        'projectPath': projectPath,
        'includeMergeRequests': includeMergeRequests,
        'importOptions': importOptions.toJson(),
        if (columnMappings.isNotEmpty)
          'columnMappings': columnMappings.map((m) => m.toJson()).toList(growable: false),
        if (priorityLabelMappings.isNotEmpty)
          'priorityLabelMappings':
              priorityLabelMappings.map((m) => m.toJson()).toList(growable: false),
      };

  static GitLabSource? tryParse(Map<String, dynamic> map) {
    final id = (map['id'] as String? ?? '').trim();
    final connectionId = (map['connectionId'] as String? ?? '').trim();
    final name = (map['name'] as String? ?? '').trim();
    final projectPath = (map['projectPath'] as String? ?? '').trim();
    if (id.isEmpty || connectionId.isEmpty || name.isEmpty || projectPath.isEmpty) {
      return null;
    }
    final includeMergeRequests = map['includeMergeRequests'] != false;
    final importOptions = GitLabImportOptions.tryParse(map['importOptions']);

    final rawMappings = map['columnMappings'];
    final mappings = <GitLabColumnMapping>[];
    if (rawMappings is List) {
      for (final item in rawMappings) {
        if (item is Map) {
          final parsed = GitLabColumnMapping.tryParse(Map<String, dynamic>.from(item));
          if (parsed != null) mappings.add(parsed);
        }
      }
    }

    final rawPriorityMappings = map['priorityLabelMappings'];
    final priorityMappings = <GitLabPriorityLabelMapping>[];
    if (rawPriorityMappings is List) {
      for (final item in rawPriorityMappings) {
        if (item is Map) {
          final parsed =
              GitLabPriorityLabelMapping.tryParse(Map<String, dynamic>.from(item));
          if (parsed != null) priorityMappings.add(parsed);
        }
      }
    }

    return GitLabSource(
      id: id,
      connectionId: connectionId,
      name: name,
      projectPath: projectPath,
      includeMergeRequests: includeMergeRequests,
      importOptions: importOptions ?? const GitLabImportOptions(),
      columnMappings: List.unmodifiable(mappings),
      priorityLabelMappings: List.unmodifiable(priorityMappings),
    );
  }
}

class GitLabImportOptions {
  const GitLabImportOptions({
    this.includeComments = true,
    this.includeAssignees = true,
  });

  final bool includeComments;
  final bool includeAssignees;

  Map<String, Object?> toJson() => <String, Object?>{
        'includeComments': includeComments,
        'includeAssignees': includeAssignees,
      };

  static GitLabImportOptions? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final m = Map<String, dynamic>.from(raw);
    return GitLabImportOptions(
      includeComments: m['includeComments'] != false,
      includeAssignees: m['includeAssignees'] != false,
    );
  }
}

/// GitLab Issues/MRs no tienen un concepto nativo de "lista" (a diferencia
/// de Trello). Por defecto una columna del Kanban se mapea al estado
/// `opened`/`closed` (vocabulario GitLab, distinto de `open` en GitHub);
/// opcionalmente se puede refinar con un label concreto.
class GitLabColumnMapping {
  const GitLabColumnMapping({
    required this.columnId,
    this.stateValue,
    this.labelName,
  });

  final String columnId;

  /// `opened` | `closed` (opcional si se usa sólo [labelName]).
  final String? stateValue;
  final String? labelName;

  Map<String, Object?> toJson() => <String, Object?>{
        'columnId': columnId,
        if ((stateValue ?? '').trim().isNotEmpty) 'stateValue': stateValue,
        if ((labelName ?? '').trim().isNotEmpty) 'labelName': labelName,
      };

  static GitLabColumnMapping? tryParse(Map<String, dynamic> map) {
    final columnId = (map['columnId'] as String? ?? '').trim();
    if (columnId.isEmpty) return null;
    final stateValue = (map['stateValue'] as String?)?.trim();
    final labelName = (map['labelName'] as String?)?.trim();
    return GitLabColumnMapping(
      columnId: columnId,
      stateValue: (stateValue?.isEmpty ?? true) ? null : stateValue,
      labelName: (labelName?.isEmpty ?? true) ? null : labelName,
    );
  }
}

/// GitLab tampoco tiene un campo nativo de prioridad; se modela vía un label
/// del proyecto elegido por el usuario para cada nivel de prioridad de Folio.
class GitLabPriorityLabelMapping {
  const GitLabPriorityLabelMapping({
    required this.priority,
    required this.labelName,
    this.color,
  });

  final String priority;
  final String labelName;
  final String? color;

  Map<String, Object?> toJson() => <String, Object?>{
        'priority': priority,
        'labelName': labelName,
        if ((color ?? '').trim().isNotEmpty) 'color': color,
      };

  static GitLabPriorityLabelMapping? tryParse(Map<String, dynamic> map) {
    final priority = (map['priority'] as String? ?? '').trim();
    final labelName = (map['labelName'] as String? ?? '').trim();
    if (priority.isEmpty || labelName.isEmpty) return null;
    final color = (map['color'] as String?)?.trim();
    return GitLabPriorityLabelMapping(
      priority: priority,
      labelName: labelName,
      color: (color?.isEmpty ?? true) ? null : color,
    );
  }
}
