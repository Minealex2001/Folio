import 'dart:convert';

enum YouTrackSourceType { query, project }

class YouTrackIntegrationState {
  const YouTrackIntegrationState({
    this.connections = const [],
    this.sources = const [],
  });

  final List<YouTrackConnection> connections;
  final List<YouTrackSource> sources;

  static const YouTrackIntegrationState empty = YouTrackIntegrationState();

  Map<String, Object?> toJson() => <String, Object?>{
        'connections': connections.map((c) => c.toJson()).toList(growable: false),
        'sources': sources.map((s) => s.toJson()).toList(growable: false),
      };

  static YouTrackIntegrationState fromJson(Object? raw) {
    if (raw is! Map) return empty;
    final m = Map<String, dynamic>.from(raw);
    final conns = <YouTrackConnection>[];
    final sources = <YouTrackSource>[];
    final rawConnections = m['connections'];
    if (rawConnections is List) {
      for (final item in rawConnections) {
        if (item is Map) {
          final c = YouTrackConnection.tryParse(Map<String, dynamic>.from(item));
          if (c != null) conns.add(c);
        }
      }
    }
    final rawSources = m['sources'];
    if (rawSources is List) {
      for (final item in rawSources) {
        if (item is Map) {
          final s = YouTrackSource.tryParse(Map<String, dynamic>.from(item));
          if (s != null) sources.add(s);
        }
      }
    }
    return YouTrackIntegrationState(
      connections: List.unmodifiable(conns),
      sources: List.unmodifiable(sources),
    );
  }

  String encode() => jsonEncode(toJson());
}

class YouTrackConnection {
  const YouTrackConnection({
    required this.id,
    required this.label,
    required this.baseUrl,
    required this.token,
  });

  final String id;
  final String label;
  final String baseUrl;
  final String token;

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'label': label,
        'baseUrl': baseUrl,
        'token': token,
      };

  static YouTrackConnection? tryParse(Map<String, dynamic> map) {
    final id = (map['id'] as String? ?? '').trim();
    final label = (map['label'] as String? ?? '').trim();
    final baseUrl = (map['baseUrl'] as String? ?? '').trim();
    final token = (map['token'] as String? ?? '').trim();
    if (id.isEmpty || label.isEmpty || baseUrl.isEmpty || token.isEmpty) return null;
    return YouTrackConnection(
      id: id,
      label: label,
      baseUrl: baseUrl,
      token: token,
    );
  }

  YouTrackConnection copyWith({
    String? label,
    String? baseUrl,
    String? token,
  }) {
    return YouTrackConnection(
      id: id,
      label: label ?? this.label,
      baseUrl: baseUrl ?? this.baseUrl,
      token: token ?? this.token,
    );
  }
}

class YouTrackSource {
  const YouTrackSource({
    required this.id,
    required this.connectionId,
    required this.type,
    required this.name,
    this.query,
    this.projectId,
    this.projectShortName,
    this.importOptions = const YouTrackImportOptions(),
    this.columnMappings = const [],
  });

  final String id;
  final String connectionId;
  final YouTrackSourceType type;
  final String name;

  final String? query;
  final String? projectId;
  final String? projectShortName;

  final YouTrackImportOptions importOptions;
  final List<YouTrackColumnMapping> columnMappings;

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'connectionId': connectionId,
        'type': type.name,
        'name': name,
        if ((query ?? '').trim().isNotEmpty) 'query': query,
        if ((projectId ?? '').trim().isNotEmpty) 'projectId': projectId,
        if ((projectShortName ?? '').trim().isNotEmpty) 'projectShortName': projectShortName,
        'importOptions': importOptions.toJson(),
        if (columnMappings.isNotEmpty)
          'columnMappings': columnMappings.map((m) => m.toJson()).toList(growable: false),
      };

  static YouTrackSource? tryParse(Map<String, dynamic> map) {
    final id = (map['id'] as String? ?? '').trim();
    final connectionId = (map['connectionId'] as String? ?? '').trim();
    final name = (map['name'] as String? ?? '').trim();
    final rawType = (map['type'] as String? ?? '').trim().toLowerCase();
    if (id.isEmpty || connectionId.isEmpty || name.isEmpty) return null;
    final type = YouTrackSourceType.values.firstWhere(
      (t) => t.name == rawType,
      orElse: () => YouTrackSourceType.query,
    );
    final query = (map['query'] as String?)?.trim();
    final projectId = (map['projectId'] as String?)?.trim();
    final projectShortName = (map['projectShortName'] as String?)?.trim();
    final importOptions = YouTrackImportOptions.tryParse(map['importOptions']);
    final rawMappings = map['columnMappings'];
    final mappings = <YouTrackColumnMapping>[];
    if (rawMappings is List) {
      for (final item in rawMappings) {
        if (item is Map) {
          final parsed = YouTrackColumnMapping.tryParse(Map<String, dynamic>.from(item));
          if (parsed != null) mappings.add(parsed);
        }
      }
    }
    return YouTrackSource(
      id: id,
      connectionId: connectionId,
      type: type,
      name: name,
      query: (query?.isEmpty ?? true) ? null : query,
      projectId: (projectId?.isEmpty ?? true) ? null : projectId,
      projectShortName: (projectShortName?.isEmpty ?? true) ? null : projectShortName,
      importOptions: importOptions ?? const YouTrackImportOptions(),
      columnMappings: List.unmodifiable(mappings),
    );
  }
}

class YouTrackImportOptions {
  const YouTrackImportOptions({
    this.includeComments = true,
    this.includeAttachments = true,
  });

  final bool includeComments;
  final bool includeAttachments;

  Map<String, Object?> toJson() => <String, Object?>{
        'includeComments': includeComments,
        'includeAttachments': includeAttachments,
      };

  static YouTrackImportOptions? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final m = Map<String, dynamic>.from(raw);
    return YouTrackImportOptions(
      includeComments: m['includeComments'] != false,
      includeAttachments: m['includeAttachments'] != false,
    );
  }
}

class YouTrackColumnMapping {
  const YouTrackColumnMapping({
    required this.columnId,
    this.stateName,
  });

  final String columnId;
  final String? stateName;

  Map<String, Object?> toJson() => <String, Object?>{
        'columnId': columnId,
        if ((stateName ?? '').trim().isNotEmpty) 'stateName': stateName,
      };

  static YouTrackColumnMapping? tryParse(Map<String, dynamic> map) {
    final columnId = (map['columnId'] as String? ?? '').trim();
    if (columnId.isEmpty) return null;
    final stateName = (map['stateName'] as String?)?.trim();
    return YouTrackColumnMapping(
      columnId: columnId,
      stateName: (stateName?.isEmpty ?? true) ? null : stateName,
    );
  }
}
