import 'dart:convert';

class TrelloIntegrationState {
  const TrelloIntegrationState({
    this.connections = const [],
    this.sources = const [],
  });

  final List<TrelloConnection> connections;
  final List<TrelloSource> sources;

  static const TrelloIntegrationState empty = TrelloIntegrationState();

  Map<String, Object?> toJson() => <String, Object?>{
        'connections': connections.map((c) => c.toJson()).toList(growable: false),
        'sources': sources.map((s) => s.toJson()).toList(growable: false),
      };

  static TrelloIntegrationState fromJson(Object? raw) {
    if (raw is! Map) return empty;
    final m = Map<String, dynamic>.from(raw);
    final conns = <TrelloConnection>[];
    final sources = <TrelloSource>[];
    final rawConnections = m['connections'];
    if (rawConnections is List) {
      for (final item in rawConnections) {
        if (item is Map) {
          final c = TrelloConnection.tryParse(Map<String, dynamic>.from(item));
          if (c != null) conns.add(c);
        }
      }
    }
    final rawSources = m['sources'];
    if (rawSources is List) {
      for (final item in rawSources) {
        if (item is Map) {
          final s = TrelloSource.tryParse(Map<String, dynamic>.from(item));
          if (s != null) sources.add(s);
        }
      }
    }
    return TrelloIntegrationState(
      connections: List.unmodifiable(conns),
      sources: List.unmodifiable(sources),
    );
  }

  String encode() => jsonEncode(toJson());
}

class TrelloConnection {
  const TrelloConnection({
    required this.id,
    required this.label,
    required this.apiKey,
    required this.token,
  });

  final String id;
  final String label;
  final String apiKey;
  final String token;

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'label': label,
        'apiKey': apiKey,
        'token': token,
      };

  static TrelloConnection? tryParse(Map<String, dynamic> map) {
    final id = (map['id'] as String? ?? '').trim();
    final label = (map['label'] as String? ?? '').trim();
    final apiKey = (map['apiKey'] as String? ?? '').trim();
    final token = (map['token'] as String? ?? '').trim();
    if (id.isEmpty || label.isEmpty || apiKey.isEmpty || token.isEmpty) return null;
    return TrelloConnection(
      id: id,
      label: label,
      apiKey: apiKey,
      token: token,
    );
  }

  TrelloConnection copyWith({
    String? label,
    String? apiKey,
    String? token,
  }) {
    return TrelloConnection(
      id: id,
      label: label ?? this.label,
      apiKey: apiKey ?? this.apiKey,
      token: token ?? this.token,
    );
  }
}

class TrelloSource {
  const TrelloSource({
    required this.id,
    required this.connectionId,
    required this.name,
    required this.boardId,
    this.boardName,
    this.importOptions = const TrelloImportOptions(),
    this.columnMappings = const [],
    this.priorityLabelMappings = const [],
  });

  final String id;
  final String connectionId;
  final String name;
  final String boardId;
  final String? boardName;

  final TrelloImportOptions importOptions;
  final List<TrelloColumnMapping> columnMappings;
  final List<TrelloPriorityLabelMapping> priorityLabelMappings;

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'connectionId': connectionId,
        'name': name,
        'boardId': boardId,
        if ((boardName ?? '').trim().isNotEmpty) 'boardName': boardName,
        'importOptions': importOptions.toJson(),
        if (columnMappings.isNotEmpty)
          'columnMappings': columnMappings.map((m) => m.toJson()).toList(growable: false),
        if (priorityLabelMappings.isNotEmpty)
          'priorityLabelMappings':
              priorityLabelMappings.map((m) => m.toJson()).toList(growable: false),
      };

  static TrelloSource? tryParse(Map<String, dynamic> map) {
    final id = (map['id'] as String? ?? '').trim();
    final connectionId = (map['connectionId'] as String? ?? '').trim();
    final name = (map['name'] as String? ?? '').trim();
    final boardId = (map['boardId'] as String? ?? '').trim();
    if (id.isEmpty || connectionId.isEmpty || name.isEmpty || boardId.isEmpty) return null;
    final boardName = (map['boardName'] as String?)?.trim();
    final importOptions = TrelloImportOptions.tryParse(map['importOptions']);

    final rawMappings = map['columnMappings'];
    final mappings = <TrelloColumnMapping>[];
    if (rawMappings is List) {
      for (final item in rawMappings) {
        if (item is Map) {
          final parsed = TrelloColumnMapping.tryParse(Map<String, dynamic>.from(item));
          if (parsed != null) mappings.add(parsed);
        }
      }
    }

    final rawPriorityMappings = map['priorityLabelMappings'];
    final priorityMappings = <TrelloPriorityLabelMapping>[];
    if (rawPriorityMappings is List) {
      for (final item in rawPriorityMappings) {
        if (item is Map) {
          final parsed =
              TrelloPriorityLabelMapping.tryParse(Map<String, dynamic>.from(item));
          if (parsed != null) priorityMappings.add(parsed);
        }
      }
    }

    return TrelloSource(
      id: id,
      connectionId: connectionId,
      name: name,
      boardId: boardId,
      boardName: (boardName?.isEmpty ?? true) ? null : boardName,
      importOptions: importOptions ?? const TrelloImportOptions(),
      columnMappings: List.unmodifiable(mappings),
      priorityLabelMappings: List.unmodifiable(priorityMappings),
    );
  }
}

class TrelloImportOptions {
  const TrelloImportOptions({
    this.includeComments = true,
    this.includeAttachments = true,
    this.includeChecklists = true,
  });

  final bool includeComments;
  final bool includeAttachments;
  final bool includeChecklists;

  Map<String, Object?> toJson() => <String, Object?>{
        'includeComments': includeComments,
        'includeAttachments': includeAttachments,
        'includeChecklists': includeChecklists,
      };

  static TrelloImportOptions? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final m = Map<String, dynamic>.from(raw);
    return TrelloImportOptions(
      includeComments: m['includeComments'] != false,
      includeAttachments: m['includeAttachments'] != false,
      includeChecklists: m['includeChecklists'] != false,
    );
  }
}

class TrelloColumnMapping {
  const TrelloColumnMapping({
    required this.columnId,
    this.listId,
    this.listName,
  });

  final String columnId;
  final String? listId;
  final String? listName;

  Map<String, Object?> toJson() => <String, Object?>{
        'columnId': columnId,
        if ((listId ?? '').trim().isNotEmpty) 'listId': listId,
        if ((listName ?? '').trim().isNotEmpty) 'listName': listName,
      };

  static TrelloColumnMapping? tryParse(Map<String, dynamic> map) {
    final columnId = (map['columnId'] as String? ?? '').trim();
    if (columnId.isEmpty) return null;
    final listId = (map['listId'] as String?)?.trim();
    final listName = (map['listName'] as String?)?.trim();
    return TrelloColumnMapping(
      columnId: columnId,
      listId: (listId?.isEmpty ?? true) ? null : listId,
      listName: (listName?.isEmpty ?? true) ? null : listName,
    );
  }
}

/// Trello no tiene un campo nativo de prioridad; se modela vía un label
/// del tablero elegido por el usuario para cada nivel de prioridad de Folio.
class TrelloPriorityLabelMapping {
  const TrelloPriorityLabelMapping({
    required this.priority,
    required this.labelId,
    this.labelName,
    this.color,
  });

  final String priority;
  final String labelId;
  final String? labelName;
  final String? color;

  Map<String, Object?> toJson() => <String, Object?>{
        'priority': priority,
        'labelId': labelId,
        if ((labelName ?? '').trim().isNotEmpty) 'labelName': labelName,
        if ((color ?? '').trim().isNotEmpty) 'color': color,
      };

  static TrelloPriorityLabelMapping? tryParse(Map<String, dynamic> map) {
    final priority = (map['priority'] as String? ?? '').trim();
    final labelId = (map['labelId'] as String? ?? '').trim();
    if (priority.isEmpty || labelId.isEmpty) return null;
    final labelName = (map['labelName'] as String?)?.trim();
    final color = (map['color'] as String?)?.trim();
    return TrelloPriorityLabelMapping(
      priority: priority,
      labelId: labelId,
      labelName: (labelName?.isEmpty ?? true) ? null : labelName,
      color: (color?.isEmpty ?? true) ? null : color,
    );
  }
}
