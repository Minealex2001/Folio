import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../models/gitlab_integration_state.dart';
import '../integrations/integration_api_exception.dart';

class GitLabApiException extends IntegrationApiException {
  const GitLabApiException(
    super.message, {
    super.statusCode,
    super.body,
    super.uri,
    super.method,
  });

  @override
  String get exceptionName => 'GitLabApiException';
}

class GitLabProject {
  GitLabProject({
    required this.id,
    required this.pathWithNamespace,
    required this.name,
  });

  final int id;
  final String pathWithNamespace;
  final String name;

  static GitLabProject fromJson(Map<String, dynamic> json) {
    return GitLabProject(
      id: (json['id'] as num?)?.toInt() ?? 0,
      pathWithNamespace: json['path_with_namespace'] as String? ?? '',
      name: json['name'] as String? ?? '',
    );
  }
}

class GitLabLabel {
  GitLabLabel({required this.name, this.color});

  final String name;
  final String? color;

  static GitLabLabel fromJson(Map<String, dynamic> json) {
    return GitLabLabel(
      name: json['name'] as String? ?? '',
      color: json['color'] as String?,
    );
  }
}

class GitLabIssueOrMr {
  GitLabIssueOrMr({
    required this.id,
    required this.iid,
    required this.title,
    required this.description,
    required this.state,
    required this.isMergeRequest,
    required this.updatedAtMs,
    this.labels = const [],
    this.assigneeUsername,
    this.webUrl,
  });

  /// Id numérico global, estable aunque cambie el `iid`.
  final int id;

  /// Id interno (con ámbito de proyecto); es el número visible en la UI de GitLab.
  final int iid;
  final String title;
  final String description;

  /// `opened` | `closed` | `merged` | `locked` (MRs pueden traer más valores).
  final String state;
  final bool isMergeRequest;
  final int updatedAtMs;
  final List<GitLabLabel> labels;
  final String? assigneeUsername;
  final String? webUrl;

  static GitLabIssueOrMr fromJson(Map<String, dynamic> json, {required bool isMergeRequest}) {
    final rawLabels = json['labels'] as List?;
    final labels = <GitLabLabel>[];
    if (rawLabels != null) {
      for (final l in rawLabels) {
        if (l is String) {
          labels.add(GitLabLabel(name: l));
        } else if (l is Map) {
          labels.add(GitLabLabel.fromJson(Map<String, dynamic>.from(l)));
        }
      }
    }
    final assignee = json['assignee'];
    final assigneeUsername = assignee is Map ? assignee['username'] as String? : null;
    final updatedAt = json['updated_at'] as String?;
    var updatedAtMs = 0;
    if (updatedAt != null && updatedAt.isNotEmpty) {
      updatedAtMs = DateTime.tryParse(updatedAt)?.millisecondsSinceEpoch ?? 0;
    }
    return GitLabIssueOrMr(
      id: (json['id'] as num?)?.toInt() ?? 0,
      iid: (json['iid'] as num?)?.toInt() ?? 0,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      state: json['state'] as String? ?? 'opened',
      isMergeRequest: isMergeRequest,
      updatedAtMs: updatedAtMs,
      labels: labels,
      assigneeUsername: assigneeUsername,
      webUrl: json['web_url'] as String?,
    );
  }
}

class GitLabNote {
  GitLabNote({
    required this.id,
    required this.body,
    required this.authorUsername,
    required this.createdMs,
  });

  final int id;
  final String body;
  final String authorUsername;
  final int createdMs;

  static GitLabNote fromJson(Map<String, dynamic> json) {
    final author = json['author'];
    final username = author is Map ? (author['username'] as String? ?? '') : '';
    final createdAt = json['created_at'] as String?;
    var createdMs = 0;
    if (createdAt != null && createdAt.isNotEmpty) {
      createdMs = DateTime.tryParse(createdAt)?.millisecondsSinceEpoch ?? 0;
    }
    return GitLabNote(
      id: (json['id'] as num?)?.toInt() ?? 0,
      body: json['body'] as String? ?? '',
      authorUsername: username,
      createdMs: createdMs,
    );
  }
}

class GitLabApiClient {
  GitLabApiClient({
    required GitLabConnection connection,
    http.Client? httpClient,
  })  : _http = httpClient ?? http.Client(),
        _connection = connection;

  static const Duration _httpTimeout = Duration(seconds: 30);
  static const int _perPage = 100;
  static const int _maxPages = 10;

  final http.Client _http;
  final GitLabConnection _connection;

  GitLabConnection get connection => _connection;

  String get _base {
    final raw = _connection.baseUrl.trim();
    final trimmed = raw.endsWith('/') ? raw.substring(0, raw.length - 1) : raw;
    return '$trimmed/api/v4';
  }

  Map<String, String> get _headers => {
        'PRIVATE-TOKEN': _connection.token.trim(),
      };

  Uri _uri(String path, [Map<String, String> extra = const {}]) {
    return Uri.parse('$_base$path').replace(queryParameters: extra.isEmpty ? null : extra);
  }

  String _encodedProject(String projectPath) => Uri.encodeComponent(projectPath.trim());

  Future<http.Response> _send(String method, Uri uri, {Object? jsonBody}) async {
    final headers = {
      ..._headers,
      if (jsonBody != null) 'Content-Type': 'application/json',
    };
    final http.Response resp;
    final body = jsonBody == null ? null : jsonEncode(jsonBody);
    switch (method) {
      case 'GET':
        resp = await _http.get(uri, headers: headers).timeout(_httpTimeout);
      case 'PUT':
        resp = await _http.put(uri, headers: headers, body: body).timeout(_httpTimeout);
      case 'POST':
        resp = await _http.post(uri, headers: headers, body: body).timeout(_httpTimeout);
      default:
        throw ArgumentError('Unsupported method: $method');
    }
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw GitLabApiException(
        '$method failed',
        statusCode: resp.statusCode,
        body: resp.body,
        uri: uri.toString(),
        method: method,
      );
    }
    return resp;
  }

  Future<Map<String, dynamic>> _getJson(Uri uri) async {
    final resp = await _send('GET', uri);
    final decoded = jsonDecode(resp.body);
    if (decoded is! Map) {
      throw const GitLabApiException('Invalid JSON object response.');
    }
    return Map<String, dynamic>.from(decoded);
  }

  /// Sigue paginación por número de página hasta [_maxPages] o hasta que una
  /// página venga vacía, evitando depender del header `Link`.
  Future<List<dynamic>> _getPaginatedList(String path, Map<String, String> query) async {
    final results = <dynamic>[];
    for (var page = 1; page <= _maxPages; page++) {
      final uri = _uri(path, {
        ...query,
        'per_page': '$_perPage',
        'page': '$page',
      });
      final resp = await _send('GET', uri);
      final decoded = jsonDecode(resp.body);
      if (decoded is! List) {
        throw const GitLabApiException('Invalid JSON list response.');
      }
      results.addAll(decoded);
      if (decoded.length < _perPage) break;
    }
    return results;
  }

  Future<void> verifyConnection() async {
    await _getJson(_uri('/user'));
  }

  Future<List<GitLabProject>> listProjects() async {
    final list = await _getPaginatedList('/projects', {'membership': 'true'});
    return list
        .whereType<Map>()
        .map((e) => GitLabProject.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<GitLabIssueOrMr>> getIssues(String projectPath) async {
    final list = await _getPaginatedList(
      '/projects/${_encodedProject(projectPath)}/issues',
      {'scope': 'all'},
    );
    return list
        .whereType<Map>()
        .map((e) => GitLabIssueOrMr.fromJson(Map<String, dynamic>.from(e), isMergeRequest: false))
        .toList();
  }

  Future<List<GitLabIssueOrMr>> getMergeRequests(String projectPath) async {
    final list = await _getPaginatedList(
      '/projects/${_encodedProject(projectPath)}/merge_requests',
      {'scope': 'all'},
    );
    return list
        .whereType<Map>()
        .map((e) => GitLabIssueOrMr.fromJson(Map<String, dynamic>.from(e), isMergeRequest: true))
        .toList();
  }

  /// Trae un único issue por iid (evita paginar la lista completa solo para
  /// leer o confirmar un item ya conocido).
  Future<GitLabIssueOrMr> getIssue(String projectPath, int iid) async {
    final json = await _getJson(
      _uri('/projects/${_encodedProject(projectPath)}/issues/$iid'),
    );
    return GitLabIssueOrMr.fromJson(json, isMergeRequest: false);
  }

  /// Trae una única merge request por iid (ver [getIssue]).
  Future<GitLabIssueOrMr> getMergeRequest(String projectPath, int iid) async {
    final json = await _getJson(
      _uri('/projects/${_encodedProject(projectPath)}/merge_requests/$iid'),
    );
    return GitLabIssueOrMr.fromJson(json, isMergeRequest: true);
  }

  Future<List<GitLabLabel>> getLabels(String projectPath) async {
    final list = await _getPaginatedList(
      '/projects/${_encodedProject(projectPath)}/labels',
      const {},
    );
    return list
        .whereType<Map>()
        .map((e) => GitLabLabel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<GitLabNote>> getNotes(
    String projectPath,
    int iid, {
    required bool isMergeRequest,
  }) async {
    final kind = isMergeRequest ? 'merge_requests' : 'issues';
    final list = await _getPaginatedList(
      '/projects/${_encodedProject(projectPath)}/$kind/$iid/notes',
      const {},
    );
    final notes = list
        .whereType<Map>()
        .map((e) => GitLabNote.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    notes.sort((a, b) => a.createdMs.compareTo(b.createdMs));
    return notes;
  }

  /// Actualiza título/estado/labels de un issue o MR. `stateEvent` es el
  /// campo de escritura (`close`/`reopen`), distinto del campo `state` de
  /// lectura (`opened`/`closed`/`merged`/`locked`).
  Future<void> updateIssueOrMr(
    String projectPath,
    int iid, {
    required bool isMergeRequest,
    String? title,
    String? stateEvent,
    List<String>? labels,
  }) async {
    final body = <String, Object?>{
      'title': ?title,
      'state_event': ?stateEvent,
      'labels': ?labels?.join(','),
    };
    if (body.isEmpty) return;
    final kind = isMergeRequest ? 'merge_requests' : 'issues';
    await _send(
      'PUT',
      _uri('/projects/${_encodedProject(projectPath)}/$kind/$iid'),
      jsonBody: body,
    );
  }

  Future<void> addNote(
    String projectPath,
    int iid, {
    required bool isMergeRequest,
    required String body,
  }) async {
    final kind = isMergeRequest ? 'merge_requests' : 'issues';
    await _send(
      'POST',
      _uri('/projects/${_encodedProject(projectPath)}/$kind/$iid/notes'),
      jsonBody: {'body': body},
    );
  }
}
