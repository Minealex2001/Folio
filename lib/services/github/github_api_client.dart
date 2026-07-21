import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../models/github_integration_state.dart';
import '../integrations/integration_api_exception.dart';

class GitHubApiException extends IntegrationApiException {
  const GitHubApiException(
    super.message, {
    super.statusCode,
    super.body,
    super.uri,
    super.method,
  });

  @override
  String get exceptionName => 'GitHubApiException';
}

class GitHubRepo {
  GitHubRepo({
    required this.id,
    required this.name,
    required this.owner,
    required this.fullName,
    this.private = false,
  });

  final int id;
  final String name;
  final String owner;
  final String fullName;
  final bool private;

  static GitHubRepo fromJson(Map<String, dynamic> json) {
    final ownerJson = json['owner'];
    final ownerLogin = ownerJson is Map ? (ownerJson['login'] as String? ?? '') : '';
    return GitHubRepo(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      owner: ownerLogin,
      fullName: json['full_name'] as String? ?? '',
      private: json['private'] == true,
    );
  }
}

class GitHubLabel {
  GitHubLabel({required this.name, this.color});

  final String name;
  final String? color;

  static GitHubLabel fromJson(Map<String, dynamic> json) {
    return GitHubLabel(
      name: json['name'] as String? ?? '',
      color: json['color'] as String?,
    );
  }
}

class GitHubIssue {
  GitHubIssue({
    required this.id,
    required this.number,
    required this.title,
    required this.body,
    required this.state,
    required this.isPullRequest,
    required this.updatedAtMs,
    this.labels = const [],
    this.assigneeLogin,
    this.htmlUrl,
  });

  /// Id numérico global, estable aunque cambie el número del issue/PR.
  final int id;
  final int number;
  final String title;
  final String body;

  /// `open` | `closed`.
  final String state;
  final bool isPullRequest;
  final int updatedAtMs;
  final List<GitHubLabel> labels;
  final String? assigneeLogin;
  final String? htmlUrl;

  static GitHubIssue fromJson(Map<String, dynamic> json) {
    final rawLabels = json['labels'] as List?;
    final labels = <GitHubLabel>[];
    if (rawLabels != null) {
      for (final l in rawLabels) {
        if (l is Map) labels.add(GitHubLabel.fromJson(Map<String, dynamic>.from(l)));
      }
    }
    final assignee = json['assignee'];
    final assigneeLogin = assignee is Map ? assignee['login'] as String? : null;
    final updatedAt = json['updated_at'] as String?;
    var updatedAtMs = 0;
    if (updatedAt != null && updatedAt.isNotEmpty) {
      updatedAtMs = DateTime.tryParse(updatedAt)?.millisecondsSinceEpoch ?? 0;
    }
    return GitHubIssue(
      id: (json['id'] as num?)?.toInt() ?? 0,
      number: (json['number'] as num?)?.toInt() ?? 0,
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      state: json['state'] as String? ?? 'open',
      isPullRequest: json.containsKey('pull_request'),
      updatedAtMs: updatedAtMs,
      labels: labels,
      assigneeLogin: assigneeLogin,
      htmlUrl: json['html_url'] as String?,
    );
  }
}

class GitHubComment {
  GitHubComment({
    required this.id,
    required this.body,
    required this.authorLogin,
    required this.createdMs,
  });

  final int id;
  final String body;
  final String authorLogin;
  final int createdMs;

  static GitHubComment fromJson(Map<String, dynamic> json) {
    final user = json['user'];
    final author = user is Map ? (user['login'] as String? ?? '') : '';
    final createdAt = json['created_at'] as String?;
    var createdMs = 0;
    if (createdAt != null && createdAt.isNotEmpty) {
      createdMs = DateTime.tryParse(createdAt)?.millisecondsSinceEpoch ?? 0;
    }
    return GitHubComment(
      id: (json['id'] as num?)?.toInt() ?? 0,
      body: json['body'] as String? ?? '',
      authorLogin: author,
      createdMs: createdMs,
    );
  }
}

class GitHubApiClient {
  GitHubApiClient({
    required GitHubConnection connection,
    http.Client? httpClient,
  })  : _http = httpClient ?? http.Client(),
        _connection = connection;

  static const Duration _httpTimeout = Duration(seconds: 30);
  static const String _base = 'https://api.github.com';
  static const int _perPage = 100;
  static const int _maxPages = 10;

  final http.Client _http;
  final GitHubConnection _connection;

  GitHubConnection get connection => _connection;

  Map<String, String> get _headers => {
        'Authorization': 'Bearer ${_connection.token.trim()}',
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
        'User-Agent': 'Folio-App',
      };

  Uri _uri(String path, [Map<String, String> extra = const {}]) {
    return Uri.parse('$_base$path').replace(queryParameters: extra.isEmpty ? null : extra);
  }

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
      case 'PATCH':
        resp = await _http.patch(uri, headers: headers, body: body).timeout(_httpTimeout);
      case 'POST':
        resp = await _http.post(uri, headers: headers, body: body).timeout(_httpTimeout);
      default:
        throw ArgumentError('Unsupported method: $method');
    }
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw GitHubApiException(
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
      throw const GitHubApiException('Invalid JSON object response.');
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
        throw const GitHubApiException('Invalid JSON list response.');
      }
      results.addAll(decoded);
      if (decoded.length < _perPage) break;
    }
    return results;
  }

  Future<void> verifyConnection() async {
    await _getJson(_uri('/user'));
  }

  Future<List<GitHubRepo>> listRepos() async {
    final list = await _getPaginatedList('/user/repos', {'sort': 'updated'});
    return list
        .whereType<Map>()
        .map((e) => GitHubRepo.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Trae issues y PRs (comparten endpoint en la API de GitHub; una PR trae
  /// la clave `pull_request`, un issue real no).
  Future<List<GitHubIssue>> getIssuesAndPRs(String owner, String repo) async {
    final list = await _getPaginatedList('/repos/$owner/$repo/issues', {'state': 'all'});
    return list
        .whereType<Map>()
        .map((e) => GitHubIssue.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Trae un único issue/PR por número (evita paginar la lista completa
  /// solo para leer o confirmar un item ya conocido).
  Future<GitHubIssue> getIssue(String owner, String repo, int number) async {
    final json = await _getJson(_uri('/repos/$owner/$repo/issues/$number'));
    return GitHubIssue.fromJson(json);
  }

  Future<List<GitHubLabel>> getLabels(String owner, String repo) async {
    final list = await _getPaginatedList('/repos/$owner/$repo/labels', const {});
    return list
        .whereType<Map>()
        .map((e) => GitHubLabel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<GitHubComment>> getComments(String owner, String repo, int number) async {
    final list = await _getPaginatedList('/repos/$owner/$repo/issues/$number/comments', const {});
    final comments = list
        .whereType<Map>()
        .map((e) => GitHubComment.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    comments.sort((a, b) => a.createdMs.compareTo(b.createdMs));
    return comments;
  }

  /// Actualiza título/estado/labels de un issue o PR. Válida para ambos en
  /// la API de GitHub, ya que sólo toca metadatos — nunca el diff/rama de
  /// una PR, que Folio no gestiona.
  Future<void> updateIssue({
    required String owner,
    required String repo,
    required int number,
    String? title,
    String? state,
    List<String>? labels,
  }) async {
    final body = <String, Object?>{
      'title': ?title,
      'state': ?state,
      'labels': ?labels,
    };
    if (body.isEmpty) return;
    await _send(
      'PATCH',
      _uri('/repos/$owner/$repo/issues/$number'),
      jsonBody: body,
    );
  }

  Future<void> addComment({
    required String owner,
    required String repo,
    required int number,
    required String body,
  }) async {
    await _send(
      'POST',
      _uri('/repos/$owner/$repo/issues/$number/comments'),
      jsonBody: {'body': body},
    );
  }
}
