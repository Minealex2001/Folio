import 'dart:convert';

class GitHubIntegrationState {
  const GitHubIntegrationState({
    this.connections = const [],
    this.sources = const [],
  });

  final List<GitHubConnection> connections;
  final List<GitHubSource> sources;

  static const GitHubIntegrationState empty = GitHubIntegrationState();

  Map<String, Object?> toJson() => <String, Object?>{
        'connections': connections.map((c) => c.toJson()).toList(growable: false),
        'sources': sources.map((s) => s.toJson()).toList(growable: false),
      };

  static GitHubIntegrationState fromJson(Object? raw) {
    if (raw is! Map) return empty;
    final m = Map<String, dynamic>.from(raw);
    final conns = <GitHubConnection>[];
    final sources = <GitHubSource>[];
    final rawConnections = m['connections'];
    if (rawConnections is List) {
      for (final item in rawConnections) {
        if (item is Map) {
          final c = GitHubConnection.tryParse(Map<String, dynamic>.from(item));
          if (c != null) conns.add(c);
        }
      }
    }
    final rawSources = m['sources'];
    if (rawSources is List) {
      for (final item in rawSources) {
        if (item is Map) {
          final s = GitHubSource.tryParse(Map<String, dynamic>.from(item));
          if (s != null) sources.add(s);
        }
      }
    }
    return GitHubIntegrationState(
      connections: List.unmodifiable(conns),
      sources: List.unmodifiable(sources),
    );
  }

  String encode() => jsonEncode(toJson());
}

class GitHubConnection {
  const GitHubConnection({
    required this.id,
    required this.label,
    required this.token,
  });

  final String id;
  final String label;

  /// Personal Access Token (fine-grained o classic) pegado por el usuario.
  final String token;

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'label': label,
        'token': token,
      };

  static GitHubConnection? tryParse(Map<String, dynamic> map) {
    final id = (map['id'] as String? ?? '').trim();
    final label = (map['label'] as String? ?? '').trim();
    final token = (map['token'] as String? ?? '').trim();
    if (id.isEmpty || label.isEmpty || token.isEmpty) return null;
    return GitHubConnection(id: id, label: label, token: token);
  }

  GitHubConnection copyWith({
    String? label,
    String? token,
  }) {
    return GitHubConnection(
      id: id,
      label: label ?? this.label,
      token: token ?? this.token,
    );
  }
}

class GitHubSource {
  const GitHubSource({
    required this.id,
    required this.connectionId,
    required this.name,
    required this.owner,
    required this.repo,
    this.includePullRequests = true,
    this.importOptions = const GitHubImportOptions(),
    this.columnMappings = const [],
    this.priorityLabelMappings = const [],
  });

  final String id;
  final String connectionId;
  final String name;
  final String owner;
  final String repo;

  /// Si es `false`, el pull filtra los items que traen `pull_request` en la
  /// respuesta de la API de Issues de GitHub (PRs y Issues comparten
  /// endpoint), quedándose sólo con Issues reales.
  final bool includePullRequests;

  final GitHubImportOptions importOptions;
  final List<GitHubColumnMapping> columnMappings;
  final List<GitHubPriorityLabelMapping> priorityLabelMappings;

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'connectionId': connectionId,
        'name': name,
        'owner': owner,
        'repo': repo,
        'includePullRequests': includePullRequests,
        'importOptions': importOptions.toJson(),
        if (columnMappings.isNotEmpty)
          'columnMappings': columnMappings.map((m) => m.toJson()).toList(growable: false),
        if (priorityLabelMappings.isNotEmpty)
          'priorityLabelMappings':
              priorityLabelMappings.map((m) => m.toJson()).toList(growable: false),
      };

  static GitHubSource? tryParse(Map<String, dynamic> map) {
    final id = (map['id'] as String? ?? '').trim();
    final connectionId = (map['connectionId'] as String? ?? '').trim();
    final name = (map['name'] as String? ?? '').trim();
    final owner = (map['owner'] as String? ?? '').trim();
    final repo = (map['repo'] as String? ?? '').trim();
    if (id.isEmpty || connectionId.isEmpty || name.isEmpty || owner.isEmpty || repo.isEmpty) {
      return null;
    }
    final includePullRequests = map['includePullRequests'] != false;
    final importOptions = GitHubImportOptions.tryParse(map['importOptions']);

    final rawMappings = map['columnMappings'];
    final mappings = <GitHubColumnMapping>[];
    if (rawMappings is List) {
      for (final item in rawMappings) {
        if (item is Map) {
          final parsed = GitHubColumnMapping.tryParse(Map<String, dynamic>.from(item));
          if (parsed != null) mappings.add(parsed);
        }
      }
    }

    final rawPriorityMappings = map['priorityLabelMappings'];
    final priorityMappings = <GitHubPriorityLabelMapping>[];
    if (rawPriorityMappings is List) {
      for (final item in rawPriorityMappings) {
        if (item is Map) {
          final parsed =
              GitHubPriorityLabelMapping.tryParse(Map<String, dynamic>.from(item));
          if (parsed != null) priorityMappings.add(parsed);
        }
      }
    }

    return GitHubSource(
      id: id,
      connectionId: connectionId,
      name: name,
      owner: owner,
      repo: repo,
      includePullRequests: includePullRequests,
      importOptions: importOptions ?? const GitHubImportOptions(),
      columnMappings: List.unmodifiable(mappings),
      priorityLabelMappings: List.unmodifiable(priorityMappings),
    );
  }
}

class GitHubImportOptions {
  const GitHubImportOptions({
    this.includeComments = true,
    this.includeAssignees = true,
  });

  final bool includeComments;
  final bool includeAssignees;

  Map<String, Object?> toJson() => <String, Object?>{
        'includeComments': includeComments,
        'includeAssignees': includeAssignees,
      };

  static GitHubImportOptions? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final m = Map<String, dynamic>.from(raw);
    return GitHubImportOptions(
      includeComments: m['includeComments'] != false,
      includeAssignees: m['includeAssignees'] != false,
    );
  }
}

/// GitHub Issues no tiene un concepto nativo de "lista" (a diferencia de
/// Trello). Por defecto una columna del Kanban se mapea al estado
/// `open`/`closed` del issue; opcionalmente se puede refinar con un label
/// concreto (patrón habitual `status:*` en repos reales).
class GitHubColumnMapping {
  const GitHubColumnMapping({
    required this.columnId,
    this.stateValue,
    this.labelName,
  });

  final String columnId;

  /// `open` | `closed` (opcional si se usa sólo [labelName]).
  final String? stateValue;
  final String? labelName;

  Map<String, Object?> toJson() => <String, Object?>{
        'columnId': columnId,
        if ((stateValue ?? '').trim().isNotEmpty) 'stateValue': stateValue,
        if ((labelName ?? '').trim().isNotEmpty) 'labelName': labelName,
      };

  static GitHubColumnMapping? tryParse(Map<String, dynamic> map) {
    final columnId = (map['columnId'] as String? ?? '').trim();
    if (columnId.isEmpty) return null;
    final stateValue = (map['stateValue'] as String?)?.trim();
    final labelName = (map['labelName'] as String?)?.trim();
    return GitHubColumnMapping(
      columnId: columnId,
      stateValue: (stateValue?.isEmpty ?? true) ? null : stateValue,
      labelName: (labelName?.isEmpty ?? true) ? null : labelName,
    );
  }
}

/// GitHub tampoco tiene un campo nativo de prioridad; se modela vía un label
/// del repo elegido por el usuario para cada nivel de prioridad de Folio.
class GitHubPriorityLabelMapping {
  const GitHubPriorityLabelMapping({
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

  static GitHubPriorityLabelMapping? tryParse(Map<String, dynamic> map) {
    final priority = (map['priority'] as String? ?? '').trim();
    final labelName = (map['labelName'] as String? ?? '').trim();
    if (priority.isEmpty || labelName.isEmpty) return null;
    final color = (map['color'] as String?)?.trim();
    return GitHubPriorityLabelMapping(
      priority: priority,
      labelName: labelName,
      color: (color?.isEmpty ?? true) ? null : color,
    );
  }
}
