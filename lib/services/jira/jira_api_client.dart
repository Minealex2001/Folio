import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' as http_parser;

import '../../models/jira_integration_state.dart';
import '../app_logger.dart';
import 'jira_auth_service.dart';

class JiraApiException implements Exception {
  const JiraApiException(
    this.message, {
    this.statusCode,
    this.body,
    this.uri,
    this.method,
  });
  final String message;
  final int? statusCode;
  final String? body;
  final String? uri;
  final String? method;
  @override
  String toString() {
    final code = statusCode;
    final m = (method ?? '').trim().isEmpty ? '' : '${method!.trim()} ';
    final u = (uri ?? '').trim().isEmpty ? '' : ' ${uri!.trim()}';
    final b = (body ?? '').trim().isEmpty ? '' : ' | body=${body!.trim()}';
    return 'JiraApiException($code): $m$message$u$b';
  }
}

class JiraApiClient {
  JiraApiClient({
    required JiraConnection connection,
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client(),
       _connection = connection;

  final http.Client _http;
  JiraConnection _connection;

  JiraConnection get connection => _connection;

  Uri _cloudBase() {
    final cloudId = (_connection.cloudId ?? '').trim();
    if (cloudId.isEmpty) {
      throw const JiraApiException('Missing cloudId for Jira Cloud connection.');
    }
    return Uri.parse('https://api.atlassian.com/ex/jira/$cloudId');
  }

  Uri _serverBase() {
    final base = (_connection.baseUrl ?? '').trim();
    if (base.isEmpty) {
      throw const JiraApiException('Missing baseUrl for Jira Server connection.');
    }
    return Uri.parse(base);
  }

  Uri _restBase() {
    if (_connection.deployment == JiraDeployment.cloud) {
      return _cloudBase().replace(path: '${_cloudBase().path}/rest/api/3');
    }
    return _serverBase().replace(path: '${_serverBase().path}/rest/api/2');
  }

  Uri _agileBase() {
    // Jira Software Agile API.
    final base = _connection.deployment == JiraDeployment.cloud
        ? _cloudBase()
        : _serverBase();
    return base.replace(path: '${base.path}/rest/agile/1.0');
  }

  Future<void> _ensureValidAuth() async {
    if (_connection.deployment != JiraDeployment.cloud) return;
    final expiresAt = _connection.expiresAtMs ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (expiresAt == 0 || now < expiresAt - 30 * 1000) return;
    final refresh = (_connection.refreshToken ?? '').trim();
    if (refresh.isEmpty) return;
    final clientId = JiraAuthService.jiraCloudClientId();
    if (clientId.isEmpty) return;
    final clientSecret = JiraAuthService.jiraCloudClientSecret();
    if (clientSecret.trim().isEmpty) {
      AppLogger.warn(
        'Jira token refresh skipped (missing client secret)',
        tag: 'jira',
      );
      return;
    }
    try {
      final resp = await _http.post(
        Uri.https('auth.atlassian.com', '/oauth/token'),
        headers: {
          'content-type': 'application/json',
          'authorization':
              'Basic ${base64Encode(utf8.encode('$clientId:${clientSecret.trim()}'))}',
        },
        body: jsonEncode({
          'grant_type': 'refresh_token',
          'client_id': clientId,
          'client_secret': clientSecret,
          'refresh_token': refresh,
        }),
      );
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        AppLogger.warn(
          'Jira token refresh failed',
          tag: 'jira',
          context: {'status': resp.statusCode, 'body': resp.body},
        );
        return;
      }
      final j = jsonDecode(resp.body) as Map;
      final accessToken = (j['access_token'] as String? ?? '').trim();
      final refreshToken = (j['refresh_token'] as String? ?? '').trim();
      final expiresIn = (j['expires_in'] as num?)?.toInt() ?? 0;
      if (accessToken.isEmpty) return;
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      _connection = _connection.copyWith(
        accessToken: accessToken,
        refreshToken: refreshToken.isEmpty ? null : refreshToken,
        expiresAtMs: expiresIn > 0 ? nowMs + expiresIn * 1000 : null,
      );
    } catch (e) {
      AppLogger.warn(
        'Jira token refresh exception',
        tag: 'jira',
        context: {'error': '$e'},
      );
    }
  }

  Map<String, String> _authHeaders() {
    if (_connection.deployment == JiraDeployment.cloud) {
      final token = (_connection.accessToken ?? '').trim();
      if (token.isEmpty) {
        throw const JiraApiException('Missing accessToken for Jira Cloud.');
      }
      return {'authorization': 'Bearer $token'};
    }
    final pat = (_connection.pat ?? '').trim();
    if (pat.isEmpty) {
      throw const JiraApiException('Missing PAT for Jira Server/DC.');
    }
    // Many Jira Server/DC instances accept Bearer PAT.
    return {'authorization': 'Bearer $pat'};
  }

  Future<Map<String, dynamic>> _getJson(Uri uri) async {
    await _ensureValidAuth();
    final resp = await _http.get(uri, headers: _authHeaders());
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      final body = resp.body;
      final isAgile = uri.path.contains('/rest/agile/');
      final scopeMismatch =
          resp.statusCode == 401 && body.contains('scope does not match');
      throw JiraApiException(
        scopeMismatch && isAgile
            ? 'GET failed (scope mismatch: reconecta Jira Cloud añadiendo scopes: read:board-scope:jira-software, read:project:jira y read:issue-details:jira)'
            : 'GET failed',
        statusCode: resp.statusCode,
        body: body,
        uri: uri.toString(),
        method: 'GET',
      );
    }
    final decoded = jsonDecode(resp.body);
    if (decoded is! Map) {
      throw const JiraApiException('Invalid JSON object response.');
    }
    return Map<String, dynamic>.from(decoded);
  }

  Future<Map<String, dynamic>> _postJson(Uri uri, Map<String, Object?> body) async {
    await _ensureValidAuth();
    final resp = await _http.post(
      uri,
      headers: {
        ..._authHeaders(),
        'content-type': 'application/json',
        'accept': 'application/json',
      },
      body: jsonEncode(body),
    );
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw JiraApiException(
        'POST failed',
        statusCode: resp.statusCode,
        body: resp.body,
        uri: uri.toString(),
        method: 'POST',
      );
    }
    final decoded = jsonDecode(resp.body);
    if (decoded is! Map) {
      throw const JiraApiException('Invalid JSON object response.');
    }
    return Map<String, dynamic>.from(decoded);
  }

  Future<void> _putJson(Uri uri, Map<String, Object?> body) async {
    await _ensureValidAuth();
    final resp = await _http.put(
      uri,
      headers: {
        ..._authHeaders(),
        'content-type': 'application/json',
        'accept': 'application/json',
      },
      body: jsonEncode(body),
    );
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw JiraApiException(
        'PUT failed',
        statusCode: resp.statusCode,
        body: resp.body,
        uri: uri.toString(),
        method: 'PUT',
      );
    }
  }

  Future<void> deleteIssue(String issueIdOrKey) async {
    await _ensureValidAuth();
    final uri = _restBase().replace(path: '${_restBase().path}/issue/$issueIdOrKey');
    final resp = await _http.delete(uri, headers: _authHeaders());
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw JiraApiException(
        'DELETE issue failed',
        statusCode: resp.statusCode,
        body: resp.body,
        uri: uri.toString(),
        method: 'DELETE',
      );
    }
  }

  Future<JiraIssue> getIssue(String issueIdOrKey) async {
    final uri = _restBase().replace(path: '${_restBase().path}/issue/$issueIdOrKey');
    final json = await _getJson(uri);
    return JiraIssue.fromJson(json);
  }

  Future<List<JiraIssue>> searchJql({
    required String jql,
    int startAt = 0,
    int maxResults = 50,
  }) async {
    final params = <String, String>{
      'jql': jql,
      'startAt': '$startAt',
      'maxResults': '$maxResults',
    };

    // Atlassian está migrando la búsqueda GET a `/search/jql` (CHANGE-2046).
    // Probamos primero el endpoint nuevo y hacemos fallback al antiguo.
    final uriNew = _restBase().replace(
      path: '${_restBase().path}/search/jql',
      queryParameters: params,
    );
    Map<String, dynamic> json;
    try {
      json = await _getJson(uriNew);
    } on JiraApiException catch (e) {
      final shouldFallback = e.statusCode == 404 || e.statusCode == 410;
      if (!shouldFallback) rethrow;
      final uriOld = _restBase().replace(
        path: '${_restBase().path}/search',
        queryParameters: params,
      );
      json = await _getJson(uriOld);
    }
    final issues = json['issues'];
    if (issues is! List) return const [];
    return issues
        .whereType<Map>()
        .map((e) => JiraIssue.fromJson(Map<String, dynamic>.from(e)))
        .toList(growable: false);
  }

  Future<List<JiraIssue>> listBoardIssues({
    required String boardId,
    int startAt = 0,
    int maxResults = 50,
    String? jql,
  }) async {
    final params = <String, String>{
      'startAt': '$startAt',
      'maxResults': '$maxResults',
      if ((jql ?? '').trim().isNotEmpty) 'jql': jql!.trim(),
    };
    final uri = _agileBase().replace(
      path: '${_agileBase().path}/board/$boardId/issue',
      queryParameters: params,
    );
    final json = await _getJson(uri);
    final issues = json['issues'];
    if (issues is! List) return const [];
    return issues
        .whereType<Map>()
        .map((e) => JiraIssue.fromJson(Map<String, dynamic>.from(e)))
        .toList(growable: false);
  }

  Future<JiraCreatedIssue> createIssue({
    required String projectKey,
    required String issueTypeName,
    required String summary,
    String? description,
  }) async {
    final uri = _restBase().replace(path: '${_restBase().path}/issue');
    final body = <String, Object?>{
      'fields': <String, Object?>{
        'project': <String, Object?>{'key': projectKey},
        'issuetype': <String, Object?>{'name': issueTypeName},
        'summary': summary,
        if ((description ?? '').trim().isNotEmpty)
          'description': _plainDescription(description!.trim()),
      },
    };
    final json = await _postJson(uri, body);
    return JiraCreatedIssue.fromJson(json);
  }

  Future<void> updateIssueFields({
    required String issueIdOrKey,
    String? summary,
    String? description,
    String? dueDateIso, // YYYY-MM-DD
    String? priorityName,
  }) async {
    final uri =
        _restBase().replace(path: '${_restBase().path}/issue/$issueIdOrKey');
    final fields = <String, Object?>{};
    if (summary != null) fields['summary'] = summary;
    if (description != null) {
      fields['description'] =
          description.trim().isEmpty ? null : _plainDescription(description);
    }
    if (dueDateIso != null) {
      fields['duedate'] = dueDateIso.trim().isEmpty ? null : dueDateIso.trim();
    }
    if (priorityName != null) {
      final name = priorityName.trim();
      fields['priority'] = name.isEmpty ? null : <String, Object?>{'name': name};
    }
    await _putJson(uri, {'fields': fields});
  }

  Future<List<JiraTransition>> listTransitions(String issueIdOrKey) async {
    final uri = _restBase().replace(
      path: '${_restBase().path}/issue/$issueIdOrKey/transitions',
    );
    final json = await _getJson(uri);
    final transitions = json['transitions'];
    if (transitions is! List) return const [];
    return transitions
        .whereType<Map>()
        .map((e) => JiraTransition.fromJson(Map<String, dynamic>.from(e)))
        .toList(growable: false);
  }

  Future<void> transitionIssue({
    required String issueIdOrKey,
    required String transitionId,
  }) async {
    final uri = _restBase().replace(
      path: '${_restBase().path}/issue/$issueIdOrKey/transitions',
    );
    await _postJson(uri, {
      'transition': {'id': transitionId},
    });
  }

  Future<List<JiraFieldMeta>> listFields() async {
    final uri = _restBase().replace(path: '${_restBase().path}/field');
    await _ensureValidAuth();
    final resp = await _http.get(uri, headers: _authHeaders());
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw JiraApiException(
        'GET /field failed',
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    final decoded = jsonDecode(resp.body);
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map>()
        .map((e) => JiraFieldMeta.fromJson(Map<String, dynamic>.from(e)))
        .toList(growable: false);
  }

  Future<List<JiraComment>> listComments({
    required String issueIdOrKey,
    int startAt = 0,
    int maxResults = 50,
  }) async {
    final uri = _restBase().replace(
      path: '${_restBase().path}/issue/$issueIdOrKey/comment',
      queryParameters: {
        'startAt': '$startAt',
        'maxResults': '$maxResults',
      },
    );
    final json = await _getJson(uri);
    final items = json['comments'];
    if (items is! List) return const [];
    return items
        .whereType<Map>()
        .map((e) => JiraComment.fromJson(Map<String, dynamic>.from(e)))
        .toList(growable: false);
  }

  Future<JiraComment> addComment({
    required String issueIdOrKey,
    required String bodyText,
  }) async {
    final uri = _restBase().replace(
      path: '${_restBase().path}/issue/$issueIdOrKey/comment',
    );
    final json = await _postJson(uri, {
      'body': _plainDescription(bodyText),
    });
    return JiraComment.fromJson(json);
  }

  Future<void> deleteComment({
    required String issueIdOrKey,
    required String commentId,
  }) async {
    final uri = _restBase().replace(
      path: '${_restBase().path}/issue/$issueIdOrKey/comment/$commentId',
    );
    await _ensureValidAuth();
    final resp = await _http.delete(uri, headers: _authHeaders());
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw JiraApiException(
        'DELETE comment failed',
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
  }

  Future<List<JiraWorklog>> listWorklogs(String issueIdOrKey) async {
    final uri = _restBase().replace(
      path: '${_restBase().path}/issue/$issueIdOrKey/worklog',
    );
    final json = await _getJson(uri);
    final items = json['worklogs'];
    if (items is! List) return const [];
    return items
        .whereType<Map>()
        .map((e) => JiraWorklog.fromJson(Map<String, dynamic>.from(e)))
        .toList(growable: false);
  }

  Future<JiraWorklog> addWorklog({
    required String issueIdOrKey,
    required int timeSpentSeconds,
    String? comment,
    DateTime? started,
  }) async {
    final uri = _restBase().replace(
      path: '${_restBase().path}/issue/$issueIdOrKey/worklog',
    );
    final body = <String, Object?>{
      'timeSpentSeconds': timeSpentSeconds,
      if ((comment ?? '').trim().isNotEmpty) 'comment': _plainDescription(comment!.trim()),
      if (started != null) 'started': started.toUtc().toIso8601String(),
    };
    final json = await _postJson(uri, body);
    return JiraWorklog.fromJson(json);
  }

  Future<void> assignIssue({
    required String issueIdOrKey,
    required String accountIdOrName,
  }) async {
    final uri = _restBase().replace(
      path: '${_restBase().path}/issue/$issueIdOrKey/assignee',
    );
    // Cloud expects accountId. Server can accept name (depending on config).
    final body = _connection.deployment == JiraDeployment.cloud
        ? <String, Object?>{'accountId': accountIdOrName}
        : <String, Object?>{'name': accountIdOrName};
    await _putJson(uri, body);
  }

  Future<List<JiraAttachment>> listAttachmentsFromIssue(String issueIdOrKey) async {
    final issue = await getIssueExpanded(issueIdOrKey);
    return issue.attachments;
  }

  Future<JiraIssueExpanded> getIssueExpanded(String issueIdOrKey) async {
    final uri = _restBase().replace(
      path: '${_restBase().path}/issue/$issueIdOrKey',
      queryParameters: {
        // Expand gives us transitions/operations when available; attachments are under fields.
        'expand': 'renderedFields,names,schema,transitions,operations',
      },
    );
    final json = await _getJson(uri);
    return JiraIssueExpanded.fromJson(json);
  }

  Future<List<JiraAttachment>> uploadAttachmentBytes({
    required String issueIdOrKey,
    required List<int> bytes,
    required String filename,
    String? contentType,
  }) async {
    await _ensureValidAuth();
    final uri = _restBase().replace(
      path: '${_restBase().path}/issue/$issueIdOrKey/attachments',
    );
    final req = http.MultipartRequest('POST', uri);
    req.headers.addAll({
      ..._authHeaders(),
      'X-Atlassian-Token': 'no-check',
      'accept': 'application/json',
    });
    req.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: filename,
        contentType: (contentType ?? '').trim().isEmpty ? null : http_parser.MediaType.parse(contentType!),
      ),
    );
    final streamed = await _http.send(req);
    final resp = await http.Response.fromStream(streamed);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw JiraApiException(
        'Upload attachment failed',
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    final decoded = jsonDecode(resp.body);
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map>()
        .map((e) => JiraAttachment.fromJson(Map<String, dynamic>.from(e)))
        .toList(growable: false);
  }

  Future<void> createIssueLink({
    required String inwardIssueKeyOrId,
    required String outwardIssueKeyOrId,
    required String linkTypeName, // e.g. "Blocks", "Relates"
    String? comment,
  }) async {
    final uri = _restBase().replace(path: '${_restBase().path}/issueLink');
    await _postJson(uri, {
      'type': {'name': linkTypeName},
      'inwardIssue': {'key': inwardIssueKeyOrId},
      'outwardIssue': {'key': outwardIssueKeyOrId},
      if ((comment ?? '').trim().isNotEmpty) 'comment': {'body': _plainDescription(comment!.trim())},
    });
  }

  Future<JiraCreatedIssue> createSubtask({
    required String projectKey,
    required String parentIssueKeyOrId,
    required String summary,
    String? description,
    String subtaskIssueTypeName = 'Sub-task',
  }) async {
    final uri = _restBase().replace(path: '${_restBase().path}/issue');
    final body = <String, Object?>{
      'fields': <String, Object?>{
        'project': <String, Object?>{'key': projectKey},
        'parent': <String, Object?>{'key': parentIssueKeyOrId},
        'issuetype': <String, Object?>{'name': subtaskIssueTypeName},
        'summary': summary,
        if ((description ?? '').trim().isNotEmpty)
          'description': _plainDescription(description!.trim()),
      },
    };
    final json = await _postJson(uri, body);
    return JiraCreatedIssue.fromJson(json);
  }

  Future<void> addIssuesToSprint({
    required String sprintId,
    required List<String> issueKeysOrIds,
  }) async {
    final uri = _agileBase().replace(path: '${_agileBase().path}/sprint/$sprintId/issue');
    await _postJson(uri, {'issues': issueKeysOrIds});
  }

  Future<void> addIssuesToBacklog({
    required List<String> issueKeysOrIds,
  }) async {
    final uri = _agileBase().replace(path: '${_agileBase().path}/backlog/issue');
    await _postJson(uri, {'issues': issueKeysOrIds});
  }

  /// Jira Cloud usa ADF para description. Esto construye un doc mínimo de texto plano.
  static Map<String, Object?> _plainDescription(String text) {
    return <String, Object?>{
      'type': 'doc',
      'version': 1,
      'content': [
        {
          'type': 'paragraph',
          'content': [
            {'type': 'text', 'text': text},
          ],
        },
      ],
    };
  }

  Future<List<JiraProjectMeta>> listProjects({int maxResults = 200}) async {
    // Cloud: /rest/api/3/project/search (paginated)
    // Server/DC: /rest/api/2/project (list)
    try {
      final out = <JiraProjectMeta>[];
      var startAt = 0;
      while (out.length < maxResults) {
        final take = (maxResults - out.length).clamp(1, 50);
        final uri = _restBase().replace(
          path: '${_restBase().path}/project/search',
          queryParameters: {
            'startAt': '$startAt',
            'maxResults': '$take',
          },
        );
        final json = await _getJson(uri);
        final values = json['values'];
        if (values is! List) break;
        for (final v in values.whereType<Map>()) {
          final m = Map<String, dynamic>.from(v);
          final parsed = JiraProjectMeta.tryParse(m);
          if (parsed != null) out.add(parsed);
        }
        final isLast = json['isLast'] == true;
        startAt += take;
        if (isLast || values.isEmpty) break;
      }
      return out;
    } catch (_) {
      // Fallback a Server/DC: /project devuelve una lista.
      await _ensureValidAuth();
      final uri = _restBase().replace(path: '${_restBase().path}/project');
      final resp = await _http.get(uri, headers: _authHeaders());
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        throw JiraApiException(
          'GET projects failed',
          statusCode: resp.statusCode,
          body: resp.body,
        );
      }
      final decoded = jsonDecode(resp.body);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((e) => JiraProjectMeta.tryParse(Map<String, dynamic>.from(e)))
          .whereType<JiraProjectMeta>()
          .toList(growable: false);
    }
  }

  Future<List<JiraBoardMeta>> listBoards({int maxResults = 200}) async {
    // Agile API (Jira Software). Some instances may not have it enabled.
    final out = <JiraBoardMeta>[];
    var startAt = 0;
    while (out.length < maxResults) {
      final take = (maxResults - out.length).clamp(1, 50);
      final uri = _agileBase().replace(
        path: '${_agileBase().path}/board',
        queryParameters: {
          'startAt': '$startAt',
          'maxResults': '$take',
        },
      );
      final json = await _getJson(uri);
      final values = json['values'];
      if (values is! List) break;
      for (final v in values.whereType<Map>()) {
        final m = Map<String, dynamic>.from(v);
        final parsed = JiraBoardMeta.tryParse(m);
        if (parsed != null) out.add(parsed);
      }
      final isLast = json['isLast'] == true;
      startAt += take;
      if (isLast || values.isEmpty) break;
    }
    return out;
  }

  Future<JiraBoardConfiguration> getBoardConfiguration(String boardId) async {
    final uri = _agileBase().replace(
      path: '${_agileBase().path}/board/$boardId/configuration',
    );
    final json = await _getJson(uri);
    return JiraBoardConfiguration.fromJson(json);
  }
}

class JiraBoardConfiguration {
  const JiraBoardConfiguration({required this.columns});
  final List<JiraBoardColumnConfig> columns;

  static JiraBoardConfiguration fromJson(Map<String, dynamic> json) {
    final colCfg = json['columnConfig'];
    if (colCfg is! Map) return const JiraBoardConfiguration(columns: []);
    final m = Map<String, dynamic>.from(colCfg);
    final colsRaw = m['columns'];
    if (colsRaw is! List) return const JiraBoardConfiguration(columns: []);
    final cols = colsRaw
        .whereType<Map>()
        .map((e) => JiraBoardColumnConfig.fromJson(Map<String, dynamic>.from(e)))
        .where((c) => c.name.trim().isNotEmpty)
        .toList(growable: false);
    return JiraBoardConfiguration(columns: cols);
  }
}

class JiraBoardColumnConfig {
  const JiraBoardColumnConfig({
    required this.name,
    required this.statusIds,
    required this.statusNames,
  });

  final String name;
  final List<String> statusIds;
  final List<String> statusNames;

  static JiraBoardColumnConfig fromJson(Map<String, dynamic> json) {
    final name = (json['name'] as String? ?? '').trim();
    final statuses = json['statuses'];
    final ids = <String>[];
    final names = <String>[];
    if (statuses is List) {
      for (final s in statuses) {
        if (s is Map) {
          final sm = Map<String, dynamic>.from(s);
          final id = (sm['id'] as String? ?? '').trim();
          final n = (sm['name'] as String? ?? '').trim();
          if (id.isNotEmpty) ids.add(id);
          if (n.isNotEmpty) names.add(n);
        }
      }
    }
    return JiraBoardColumnConfig(
      name: name,
      statusIds: List.unmodifiable(ids),
      statusNames: List.unmodifiable(names),
    );
  }
}

class JiraProjectMeta {
  const JiraProjectMeta({
    required this.id,
    required this.key,
    required this.name,
  });

  final String id;
  final String key;
  final String name;

  static JiraProjectMeta? tryParse(Map<String, dynamic> json) {
    final id = '${json['id'] ?? ''}'.trim();
    final key = '${json['key'] ?? ''}'.trim();
    final name = '${json['name'] ?? ''}'.trim();
    if (key.isEmpty || name.isEmpty) return null;
    return JiraProjectMeta(id: id, key: key, name: name);
  }
}

class JiraBoardMeta {
  const JiraBoardMeta({
    required this.id,
    required this.name,
    this.type,
    this.projectKey,
    this.projectName,
  });

  final String id;
  final String name;
  final String? type;
  final String? projectKey;
  final String? projectName;

  static JiraBoardMeta? tryParse(Map<String, dynamic> json) {
    final id = '${json['id'] ?? ''}'.trim();
    final name = '${json['name'] ?? ''}'.trim();
    if (id.isEmpty || name.isEmpty) return null;
    final type = '${json['type'] ?? ''}'.trim();
    String? projectKey;
    String? projectName;
    final location = json['location'];
    if (location is Map) {
      final m = Map<String, dynamic>.from(location);
      final pk = '${m['projectKey'] ?? ''}'.trim();
      final pn = '${m['projectName'] ?? ''}'.trim();
      projectKey = pk.isEmpty ? null : pk;
      projectName = pn.isEmpty ? null : pn;
    }
    return JiraBoardMeta(
      id: id,
      name: name,
      type: type.isEmpty ? null : type,
      projectKey: projectKey,
      projectName: projectName,
    );
  }
}

class JiraCreatedIssue {
  const JiraCreatedIssue({required this.id, required this.key});
  final String id;
  final String key;

  static JiraCreatedIssue fromJson(Map<String, dynamic> json) {
    return JiraCreatedIssue(
      id: (json['id'] as String? ?? '').trim(),
      key: (json['key'] as String? ?? '').trim(),
    );
  }
}

class JiraIssue {
  const JiraIssue({
    required this.id,
    required this.key,
    required this.summary,
    this.descriptionText,
    this.statusName,
    this.priorityId,
    this.priorityName,
    this.assigneeDisplayName,
    this.dueDateIso,
    this.updatedAt,
  });

  final String id;
  final String key;
  final String summary;
  final String? descriptionText;
  final String? statusName;
  final String? priorityId;
  final String? priorityName;
  final String? assigneeDisplayName;
  final String? dueDateIso;
  final String? updatedAt;

  static JiraIssue fromJson(Map<String, dynamic> json) {
    final fields = json['fields'] is Map ? Map<String, dynamic>.from(json['fields'] as Map) : const <String, dynamic>{};
    final status = fields['status'] is Map ? Map<String, dynamic>.from(fields['status'] as Map) : const <String, dynamic>{};
    final priority = fields['priority'] is Map ? Map<String, dynamic>.from(fields['priority'] as Map) : const <String, dynamic>{};
    final assignee = fields['assignee'] is Map ? Map<String, dynamic>.from(fields['assignee'] as Map) : const <String, dynamic>{};
    return JiraIssue(
      id: (json['id'] as String? ?? '').trim(),
      key: (json['key'] as String? ?? '').trim(),
      summary: (fields['summary'] as String? ?? '').trim(),
      descriptionText: _extractDescriptionPlain(fields['description']),
      statusName: (status['name'] as String?)?.trim(),
      priorityId: (priority['id'] as String?)?.trim(),
      priorityName: (priority['name'] as String?)?.trim(),
      assigneeDisplayName: (assignee['displayName'] as String?)?.trim(),
      dueDateIso: (fields['duedate'] as String?)?.trim(),
      updatedAt: (fields['updated'] as String?)?.trim(),
    );
  }

  static String? _extractDescriptionPlain(Object? raw) {
    // Best-effort: Jira Cloud returns ADF object, Server may return string.
    if (raw == null) return null;
    if (raw is String) return raw;
    if (raw is Map) {
      try {
        // Traverse ADF (very shallow) for text nodes.
        final content = raw['content'];
        if (content is! List) return null;
        final buffer = StringBuffer();
        void visit(Object? node) {
          if (node is Map) {
            final type = node['type'];
            if (type == 'text' && node['text'] is String) {
              if (buffer.isNotEmpty) buffer.write('');
              buffer.write(node['text'] as String);
              return;
            }
            final children = node['content'];
            if (children is List) {
              for (final c in children) {
                visit(c);
              }
              if (type == 'paragraph') buffer.write('\n');
            }
          } else if (node is List) {
            for (final c in node) {
              visit(c);
            }
          }
        }

        visit(content);
        final out = buffer.toString().trim();
        return out.isEmpty ? null : out;
      } catch (_) {
        return null;
      }
    }
    return null;
  }
}

class JiraIssueExpanded extends JiraIssue {
  const JiraIssueExpanded({
    required super.id,
    required super.key,
    required super.summary,
    super.descriptionText,
    super.statusName,
    super.priorityId,
    super.priorityName,
    super.assigneeDisplayName,
    super.dueDateIso,
    super.updatedAt,
    this.projectKey,
    this.issueTypeName,
    this.isSubtask = false,
    this.parentId,
    this.parentKey,
    this.statusId,
    this.labels = const [],
    this.components = const [],
    this.assigneeAccountId,
    this.reporterAccountId,
    this.reporterDisplayName,
    this.attachments = const [],
    this.timetracking,
    this.rawFields = const <String, Object?>{},
  });

  final String? projectKey;
  final String? issueTypeName;
  final bool isSubtask;
  final String? parentId;
  final String? parentKey;
  final String? statusId;
  final List<String> labels;
  final List<String> components;

  final String? assigneeAccountId;
  final String? reporterAccountId;
  final String? reporterDisplayName;

  final List<JiraAttachment> attachments;
  final JiraTimeTracking? timetracking;
  final Map<String, Object?> rawFields;

  static JiraIssueExpanded fromJson(Map<String, dynamic> json) {
    final base = JiraIssue.fromJson(json);
    final fields = json['fields'] is Map ? Map<String, dynamic>.from(json['fields'] as Map) : const <String, dynamic>{};
    final project = fields['project'] is Map ? Map<String, dynamic>.from(fields['project'] as Map) : const <String, dynamic>{};
    final issuetype = fields['issuetype'] is Map ? Map<String, dynamic>.from(fields['issuetype'] as Map) : const <String, dynamic>{};
    final status = fields['status'] is Map ? Map<String, dynamic>.from(fields['status'] as Map) : const <String, dynamic>{};
    final priority = fields['priority'] is Map ? Map<String, dynamic>.from(fields['priority'] as Map) : const <String, dynamic>{};
    final assignee = fields['assignee'] is Map ? Map<String, dynamic>.from(fields['assignee'] as Map) : const <String, dynamic>{};
    final reporter = fields['reporter'] is Map ? Map<String, dynamic>.from(fields['reporter'] as Map) : const <String, dynamic>{};
    final parent = fields['parent'] is Map ? Map<String, dynamic>.from(fields['parent'] as Map) : const <String, dynamic>{};
    final labelsRaw = fields['labels'];
    final labels = labelsRaw is List
        ? labelsRaw.map((e) => '$e').where((e) => e.trim().isNotEmpty).toList(growable: false)
        : const <String>[];
    final componentsRaw = fields['components'];
    final components = componentsRaw is List
        ? componentsRaw
            .whereType<Map>()
            .map((e) => (e['name'] as String? ?? '').trim())
            .where((e) => e.isNotEmpty)
            .toList(growable: false)
        : const <String>[];
    final attachmentsRaw = fields['attachment'];
    final attachments = attachmentsRaw is List
        ? attachmentsRaw
            .whereType<Map>()
            .map((e) => JiraAttachment.fromJson(Map<String, dynamic>.from(e)))
            .toList(growable: false)
        : const <JiraAttachment>[];
    final tt = fields['timetracking'];
    return JiraIssueExpanded(
      id: base.id,
      key: base.key,
      summary: base.summary,
      descriptionText: base.descriptionText,
      statusName: base.statusName,
      priorityId: (priority['id'] as String?)?.trim(),
      priorityName: (priority['name'] as String?)?.trim(),
      assigneeDisplayName: base.assigneeDisplayName,
      dueDateIso: base.dueDateIso,
      updatedAt: base.updatedAt,
      projectKey: (project['key'] as String?)?.trim(),
      issueTypeName: (issuetype['name'] as String?)?.trim(),
      isSubtask: issuetype['subtask'] == true,
      parentId: (parent['id'] as String?)?.trim(),
      parentKey: (parent['key'] as String?)?.trim(),
      statusId: (status['id'] as String?)?.trim(),
      labels: labels,
      components: components,
      assigneeAccountId: (assignee['accountId'] as String?)?.trim(),
      reporterAccountId: (reporter['accountId'] as String?)?.trim(),
      reporterDisplayName: (reporter['displayName'] as String?)?.trim(),
      attachments: attachments,
      timetracking: tt is Map ? JiraTimeTracking.fromJson(Map<String, dynamic>.from(tt)) : null,
      rawFields: Map<String, Object?>.from(fields),
    );
  }
}

class JiraComment {
  const JiraComment({
    required this.id,
    this.authorDisplayName,
    this.created,
    this.updated,
    this.bodyText,
  });
  final String id;
  final String? authorDisplayName;
  final String? created;
  final String? updated;
  final String? bodyText;

  static JiraComment fromJson(Map<String, dynamic> json) {
    final author = json['author'] is Map ? Map<String, dynamic>.from(json['author'] as Map) : const <String, dynamic>{};
    return JiraComment(
      id: (json['id'] as String? ?? '').trim(),
      authorDisplayName: (author['displayName'] as String?)?.trim(),
      created: (json['created'] as String?)?.trim(),
      updated: (json['updated'] as String?)?.trim(),
      bodyText: JiraIssue._extractDescriptionPlain(json['body']),
    );
  }
}

class JiraAttachment {
  const JiraAttachment({
    required this.id,
    required this.filename,
    this.mimeType,
    this.size,
    this.contentUrl,
    this.created,
    this.authorDisplayName,
  });
  final String id;
  final String filename;
  final String? mimeType;
  final int? size;
  final String? contentUrl;
  final String? created;
  final String? authorDisplayName;

  static JiraAttachment fromJson(Map<String, dynamic> json) {
    final author = json['author'] is Map ? Map<String, dynamic>.from(json['author'] as Map) : const <String, dynamic>{};
    return JiraAttachment(
      id: (json['id'] as String? ?? '').trim(),
      filename: (json['filename'] as String? ?? '').trim(),
      mimeType: (json['mimeType'] as String?)?.trim(),
      size: json['size'] is num ? (json['size'] as num).toInt() : null,
      contentUrl: (json['content'] as String?)?.trim(),
      created: (json['created'] as String?)?.trim(),
      authorDisplayName: (author['displayName'] as String?)?.trim(),
    );
  }
}

class JiraWorklog {
  const JiraWorklog({
    required this.id,
    this.authorDisplayName,
    this.started,
    this.timeSpentSeconds,
    this.commentText,
  });
  final String id;
  final String? authorDisplayName;
  final String? started;
  final int? timeSpentSeconds;
  final String? commentText;

  static JiraWorklog fromJson(Map<String, dynamic> json) {
    final author = json['author'] is Map ? Map<String, dynamic>.from(json['author'] as Map) : const <String, dynamic>{};
    return JiraWorklog(
      id: (json['id'] as String? ?? '').trim(),
      authorDisplayName: (author['displayName'] as String?)?.trim(),
      started: (json['started'] as String?)?.trim(),
      timeSpentSeconds: json['timeSpentSeconds'] is num ? (json['timeSpentSeconds'] as num).toInt() : null,
      commentText: JiraIssue._extractDescriptionPlain(json['comment']),
    );
  }
}

class JiraTimeTracking {
  const JiraTimeTracking({
    this.originalEstimateSeconds,
    this.remainingEstimateSeconds,
    this.timeSpentSeconds,
  });

  final int? originalEstimateSeconds;
  final int? remainingEstimateSeconds;
  final int? timeSpentSeconds;

  static JiraTimeTracking fromJson(Map<String, dynamic> json) {
    int? asInt(Object? v) => v is num ? v.toInt() : null;
    return JiraTimeTracking(
      originalEstimateSeconds: asInt(json['originalEstimateSeconds']),
      remainingEstimateSeconds: asInt(json['remainingEstimateSeconds']),
      timeSpentSeconds: asInt(json['timeSpentSeconds']),
    );
  }
}

class JiraFieldMeta {
  const JiraFieldMeta({
    required this.id,
    required this.name,
    this.custom = false,
    this.schemaType,
  });
  final String id;
  final String name;
  final bool custom;
  final String? schemaType;

  static JiraFieldMeta fromJson(Map<String, dynamic> json) {
    final schema = json['schema'] is Map ? Map<String, dynamic>.from(json['schema'] as Map) : const <String, dynamic>{};
    return JiraFieldMeta(
      id: (json['id'] as String? ?? '').trim(),
      name: (json['name'] as String? ?? '').trim(),
      custom: json['custom'] == true,
      schemaType: (schema['type'] as String?)?.trim(),
    );
  }
}

class JiraTransition {
  const JiraTransition({
    required this.id,
    required this.name,
    this.toStatusId,
    this.toStatusName,
  });
  final String id;
  final String name;
  final String? toStatusId;
  final String? toStatusName;

  static JiraTransition fromJson(Map<String, dynamic> json) {
    final to = json['to'] is Map ? Map<String, dynamic>.from(json['to'] as Map) : const <String, dynamic>{};
    return JiraTransition(
      id: (json['id'] as String? ?? '').trim(),
      name: (json['name'] as String? ?? '').trim(),
      toStatusId: (to['id'] as String?)?.trim(),
      toStatusName: (to['name'] as String?)?.trim(),
    );
  }
}

