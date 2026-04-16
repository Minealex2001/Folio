import 'dart:convert';

enum JiraDeployment { cloud, server }

enum JiraSourceType { jql, board, project }

class JiraIntegrationState {
  const JiraIntegrationState({
    this.connections = const [],
    this.sources = const [],
  });

  final List<JiraConnection> connections;
  final List<JiraSource> sources;

  static const JiraIntegrationState empty = JiraIntegrationState();

  Map<String, Object?> toJson() => <String, Object?>{
        'connections': connections.map((c) => c.toJson()).toList(growable: false),
        'sources': sources.map((s) => s.toJson()).toList(growable: false),
      };

  static JiraIntegrationState fromJson(Object? raw) {
    if (raw is! Map) return empty;
    final m = Map<String, dynamic>.from(raw);
    final conns = <JiraConnection>[];
    final sources = <JiraSource>[];
    final rawConnections = m['connections'];
    if (rawConnections is List) {
      for (final item in rawConnections) {
        if (item is Map) {
          final c = JiraConnection.tryParse(Map<String, dynamic>.from(item));
          if (c != null) conns.add(c);
        }
      }
    }
    final rawSources = m['sources'];
    if (rawSources is List) {
      for (final item in rawSources) {
        if (item is Map) {
          final s = JiraSource.tryParse(Map<String, dynamic>.from(item));
          if (s != null) sources.add(s);
        }
      }
    }
    return JiraIntegrationState(
      connections: List.unmodifiable(conns),
      sources: List.unmodifiable(sources),
    );
  }

  String encode() => jsonEncode(toJson());
}

class JiraConnection {
  const JiraConnection({
    required this.id,
    required this.deployment,
    required this.label,
    this.baseUrl,
    this.cloudId,
    this.siteUrl,
    this.accessToken,
    this.refreshToken,
    this.expiresAtMs,
    this.pat,
  });

  final String id;
  final JiraDeployment deployment;
  final String label;

  /// Para Server/DC: base URL `https://jira.example.com`
  final String? baseUrl;

  /// Para Cloud: `cloudId` del recurso accesible.
  final String? cloudId;

  /// Para Cloud: URL humana del sitio (opcional, informativo).
  final String? siteUrl;

  /// OAuth (Cloud): access token (bearer).
  final String? accessToken;
  final String? refreshToken;
  final int? expiresAtMs;

  /// Server/DC: token/PAT.
  final String? pat;

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'deployment': deployment.name,
        'label': label,
        if ((baseUrl ?? '').trim().isNotEmpty) 'baseUrl': baseUrl,
        if ((cloudId ?? '').trim().isNotEmpty) 'cloudId': cloudId,
        if ((siteUrl ?? '').trim().isNotEmpty) 'siteUrl': siteUrl,
        if ((accessToken ?? '').trim().isNotEmpty) 'accessToken': accessToken,
        if ((refreshToken ?? '').trim().isNotEmpty) 'refreshToken': refreshToken,
        if (expiresAtMs != null) 'expiresAtMs': expiresAtMs,
        if ((pat ?? '').trim().isNotEmpty) 'pat': pat,
      };

  static JiraConnection? tryParse(Map<String, dynamic> map) {
    final id = (map['id'] as String? ?? '').trim();
    final label = (map['label'] as String? ?? '').trim();
    final dep = (map['deployment'] as String? ?? '').trim().toLowerCase();
    if (id.isEmpty || label.isEmpty) return null;
    final deployment = dep == 'server' ? JiraDeployment.server : JiraDeployment.cloud;
    final baseUrl = (map['baseUrl'] as String?)?.trim();
    final cloudId = (map['cloudId'] as String?)?.trim();
    final siteUrl = (map['siteUrl'] as String?)?.trim();
    final accessToken = (map['accessToken'] as String?)?.trim();
    final refreshToken = (map['refreshToken'] as String?)?.trim();
    final expiresAtMs =
        map['expiresAtMs'] is num ? (map['expiresAtMs'] as num).toInt() : null;
    final pat = (map['pat'] as String?)?.trim();
    return JiraConnection(
      id: id,
      deployment: deployment,
      label: label,
      baseUrl: (baseUrl?.isEmpty ?? true) ? null : baseUrl,
      cloudId: (cloudId?.isEmpty ?? true) ? null : cloudId,
      siteUrl: (siteUrl?.isEmpty ?? true) ? null : siteUrl,
      accessToken: (accessToken?.isEmpty ?? true) ? null : accessToken,
      refreshToken: (refreshToken?.isEmpty ?? true) ? null : refreshToken,
      expiresAtMs: expiresAtMs,
      pat: (pat?.isEmpty ?? true) ? null : pat,
    );
  }

  JiraConnection copyWith({
    String? label,
    Object? baseUrl = _sentinel,
    Object? cloudId = _sentinel,
    Object? siteUrl = _sentinel,
    Object? accessToken = _sentinel,
    Object? refreshToken = _sentinel,
    Object? expiresAtMs = _sentinel,
    Object? pat = _sentinel,
  }) {
    return JiraConnection(
      id: id,
      deployment: deployment,
      label: label ?? this.label,
      baseUrl: baseUrl == _sentinel ? this.baseUrl : baseUrl as String?,
      cloudId: cloudId == _sentinel ? this.cloudId : cloudId as String?,
      siteUrl: siteUrl == _sentinel ? this.siteUrl : siteUrl as String?,
      accessToken:
          accessToken == _sentinel ? this.accessToken : accessToken as String?,
      refreshToken: refreshToken == _sentinel
          ? this.refreshToken
          : refreshToken as String?,
      expiresAtMs: expiresAtMs == _sentinel
          ? this.expiresAtMs
          : expiresAtMs as int?,
      pat: pat == _sentinel ? this.pat : pat as String?,
    );
  }

  static const Object _sentinel = Object();
}

class JiraSource {
  const JiraSource({
    required this.id,
    required this.connectionId,
    required this.type,
    required this.name,
    this.jql,
    this.boardId,
    this.projectKey,
    this.importOptions = const JiraImportOptions(),
    this.customFieldIds = const [],
    this.columnMappings = const [],
  });

  final String id;
  final String connectionId;
  final JiraSourceType type;
  final String name;

  final String? jql;
  final String? boardId;
  final String? projectKey;

  /// Qué se importa/pushea para esta fuente (sin auto-sync).
  final JiraImportOptions importOptions;

  /// Lista de fieldIds (p. ej. `customfield_10016`) que se guardan en snapshot.
  final List<String> customFieldIds;

  /// Mapping manual Folio columnId -> transición/status Jira.
  final List<JiraColumnMapping> columnMappings;

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'connectionId': connectionId,
        'type': type.name,
        'name': name,
        if ((jql ?? '').trim().isNotEmpty) 'jql': jql,
        if ((boardId ?? '').trim().isNotEmpty) 'boardId': boardId,
        if ((projectKey ?? '').trim().isNotEmpty) 'projectKey': projectKey,
        'importOptions': importOptions.toJson(),
        if (customFieldIds.isNotEmpty) 'customFieldIds': customFieldIds,
        if (columnMappings.isNotEmpty)
          'columnMappings': columnMappings.map((m) => m.toJson()).toList(growable: false),
      };

  static JiraSource? tryParse(Map<String, dynamic> map) {
    final id = (map['id'] as String? ?? '').trim();
    final connectionId = (map['connectionId'] as String? ?? '').trim();
    final name = (map['name'] as String? ?? '').trim();
    final rawType = (map['type'] as String? ?? '').trim().toLowerCase();
    if (id.isEmpty || connectionId.isEmpty || name.isEmpty) return null;
    final type = JiraSourceType.values.firstWhere(
      (t) => t.name == rawType,
      orElse: () => JiraSourceType.jql,
    );
    final jql = (map['jql'] as String?)?.trim();
    final boardId = (map['boardId'] as String?)?.trim();
    final projectKey = (map['projectKey'] as String?)?.trim();
    final importOptions = JiraImportOptions.tryParse(map['importOptions']);
    final rawCf = map['customFieldIds'];
    final customFieldIds = <String>[];
    if (rawCf is List) {
      for (final v in rawCf) {
        final s = '$v'.trim();
        if (s.isNotEmpty) customFieldIds.add(s);
      }
    }
    final rawMappings = map['columnMappings'];
    final mappings = <JiraColumnMapping>[];
    if (rawMappings is List) {
      for (final item in rawMappings) {
        if (item is Map) {
          final parsed = JiraColumnMapping.tryParse(Map<String, dynamic>.from(item));
          if (parsed != null) mappings.add(parsed);
        }
      }
    }
    return JiraSource(
      id: id,
      connectionId: connectionId,
      type: type,
      name: name,
      jql: (jql?.isEmpty ?? true) ? null : jql,
      boardId: (boardId?.isEmpty ?? true) ? null : boardId,
      projectKey: (projectKey?.isEmpty ?? true) ? null : projectKey,
      importOptions: importOptions ?? const JiraImportOptions(),
      customFieldIds: List.unmodifiable(customFieldIds),
      columnMappings: List.unmodifiable(mappings),
    );
  }
}

class JiraImportOptions {
  const JiraImportOptions({
    this.includeComments = true,
    this.includeAttachments = true,
    this.includeSubtasks = true,
    this.includeLinks = true,
    this.includeWorklog = true,
  });

  final bool includeComments;
  final bool includeAttachments;
  final bool includeSubtasks;
  final bool includeLinks;
  final bool includeWorklog;

  Map<String, Object?> toJson() => <String, Object?>{
        'includeComments': includeComments,
        'includeAttachments': includeAttachments,
        'includeSubtasks': includeSubtasks,
        'includeLinks': includeLinks,
        'includeWorklog': includeWorklog,
      };

  static JiraImportOptions? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final m = Map<String, dynamic>.from(raw);
    return JiraImportOptions(
      includeComments: m['includeComments'] != false,
      includeAttachments: m['includeAttachments'] != false,
      includeSubtasks: m['includeSubtasks'] != false,
      includeLinks: m['includeLinks'] != false,
      includeWorklog: m['includeWorklog'] != false,
    );
  }
}

class JiraColumnMapping {
  const JiraColumnMapping({
    required this.columnId,
    this.transitionId,
    this.statusId,
    this.statusName,
  });

  final String columnId;
  final String? transitionId;
  final String? statusId;
  final String? statusName;

  Map<String, Object?> toJson() => <String, Object?>{
        'columnId': columnId,
        if ((transitionId ?? '').trim().isNotEmpty) 'transitionId': transitionId,
        if ((statusId ?? '').trim().isNotEmpty) 'statusId': statusId,
        if ((statusName ?? '').trim().isNotEmpty) 'statusName': statusName,
      };

  static JiraColumnMapping? tryParse(Map<String, dynamic> map) {
    final columnId = (map['columnId'] as String? ?? '').trim();
    if (columnId.isEmpty) return null;
    final transitionId = (map['transitionId'] as String?)?.trim();
    final statusId = (map['statusId'] as String?)?.trim();
    final statusName = (map['statusName'] as String?)?.trim();
    return JiraColumnMapping(
      columnId: columnId,
      transitionId: (transitionId?.isEmpty ?? true) ? null : transitionId,
      statusId: (statusId?.isEmpty ?? true) ? null : statusId,
      statusName: (statusName?.isEmpty ?? true) ? null : statusName,
    );
  }
}

