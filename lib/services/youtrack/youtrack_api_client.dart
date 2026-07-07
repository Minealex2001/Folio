import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../models/youtrack_integration_state.dart';
import '../app_logger.dart';

class YouTrackApiException implements Exception {
  const YouTrackApiException(
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
    return 'YouTrackApiException($code): $m$message$u$b';
  }
}

class YouTrackComment {
  YouTrackComment({
    required this.id,
    required this.text,
    required this.authorName,
    required this.createdMs,
  });

  final String id;
  final String text;
  final String authorName;
  final int createdMs;

  static YouTrackComment fromJson(Map<String, dynamic> json) {
    final author = json['author'] as Map?;
    final authorName = author != null
        ? (author['name'] as String? ?? author['displayName'] as String? ?? author['login'] as String? ?? '')
        : '';
    return YouTrackComment(
      id: json['id'] as String? ?? '',
      text: json['text'] as String? ?? '',
      authorName: authorName,
      createdMs: json['created'] is num ? (json['created'] as num).toInt() : 0,
    );
  }
}

class YouTrackIssue {
  YouTrackIssue({
    required this.id,
    required this.idReadable,
    required this.summary,
    required this.description,
    required this.updatedAtMs,
    required this.projectId,
    required this.projectShortName,
    this.projectName,
    this.stateName,
    this.priorityName,
    this.assigneeName,
    this.subsystemName,
    this.typeName,
    this.fixVersions,
    this.affectedVersions,
    this.fixedInBuild,
    this.estimation,
    this.spentTime,
    this.commentCount = 0,
    this.attachmentCount = 0,
    this.comments = const [],
    this.customFieldIds = const {},
  });

  final String id;
  final String idReadable;
  final String summary;
  final String description;
  final int updatedAtMs;
  final String projectId;
  final String projectShortName;
  final String? projectName;
  final String? stateName;
  final String? priorityName;
  final String? assigneeName;
  final String? subsystemName;
  final String? typeName;
  final String? fixVersions;
  final String? affectedVersions;
  final String? fixedInBuild;
  final String? estimation;
  final String? spentTime;
  final int commentCount;
  final int attachmentCount;
  final List<YouTrackComment> comments;
  final Map<String, String> customFieldIds;

  static YouTrackIssue fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String? ?? '';
    final idReadable = json['idReadable'] as String? ?? '';
    final summary = json['summary'] as String? ?? '';
    final description = json['description'] as String? ?? '';
    final updated = json['updated'] is num ? (json['updated'] as num).toInt() : 0;

    final project = json['project'] as Map?;
    final projectId = project != null ? (project['id'] as String? ?? '') : '';
    final projectShortName = project != null ? (project['shortName'] as String? ?? '') : '';
    final projectName = project != null ? (project['name'] as String? ?? '') : '';

    String? stateName;
    String? priorityName;
    String? assigneeName;
    String? subsystemName;
    String? typeName;
    String? fixVersions;
    String? affectedVersions;
    String? fixedInBuild;
    String? estimation;
    String? spentTime;
    final customFieldIds = <String, String>{};

    final customFields = json['customFields'] as List?;
    if (customFields != null) {
      for (final f in customFields) {
        if (f is Map) {
          final name = (f['name'] as String? ?? '').toLowerCase();
          final fieldId = f['id'] as String? ?? '';
          if (name.isNotEmpty && fieldId.isNotEmpty) {
            customFieldIds[name] = fieldId;
          }
          final val = f['value'];
          String? valName;
          if (val is Map) {
            valName = val['name'] as String? ??
                val['displayName'] as String? ??
                val['login'] as String? ??
                val['presentation'] as String? ??
                '';
          } else if (val is List && val.isNotEmpty) {
            final names = <String>[];
            for (final item in val) {
              if (item is Map) {
                final n = item['name'] as String? ??
                    item['displayName'] as String? ??
                    item['login'] as String? ??
                    item['presentation'] as String? ??
                    '';
                if (n.isNotEmpty) names.add(n);
              } else if (item != null) {
                names.add(item.toString());
              }
            }
            valName = names.join(', ');
          } else if (val is String) {
            valName = val;
          } else if (val is num) {
            valName = val.toString();
          }

          if (valName != null) {
            if (name == 'state') {
              stateName = valName;
            } else if (name == 'priority') {
              priorityName = valName;
            } else if (name == 'assignee') {
              assigneeName = valName;
            } else if (name == 'subsystem') {
              subsystemName = valName;
            } else if (name == 'type') {
              typeName = valName;
            } else if (name == 'fix versions') {
              fixVersions = valName;
            } else if (name == 'affected versions') {
              affectedVersions = valName;
            } else if (name == 'fixed in build') {
              fixedInBuild = valName;
            } else if (name == 'estimation') {
              estimation = valName;
            } else if (name == 'spent time') {
              spentTime = valName;
            }
          }
        }
      }
    }

    final commentsList = <YouTrackComment>[];
    final rawComments = json['comments'] as List?;
    if (rawComments != null) {
      for (final c in rawComments) {
        if (c is Map) {
          commentsList.add(YouTrackComment.fromJson(Map<String, dynamic>.from(c)));
        }
      }
    }
    final commentCount = commentsList.length;

    final attachments = json['attachments'] as List?;
    final attachmentCount = attachments?.length ?? 0;

    return YouTrackIssue(
      id: id,
      idReadable: idReadable,
      summary: summary,
      description: description,
      updatedAtMs: updated,
      projectId: projectId,
      projectShortName: projectShortName,
      projectName: projectName.isEmpty ? null : projectName,
      stateName: stateName,
      priorityName: priorityName,
      assigneeName: assigneeName,
      subsystemName: subsystemName,
      typeName: typeName,
      fixVersions: fixVersions,
      affectedVersions: affectedVersions,
      fixedInBuild: fixedInBuild,
      estimation: estimation,
      spentTime: spentTime,
      commentCount: commentCount,
      attachmentCount: attachmentCount,
      comments: commentsList,
      customFieldIds: customFieldIds,
    );
  }
}

class YouTrackProject {
  YouTrackProject({
    required this.id,
    required this.name,
    required this.shortName,
  });

  final String id;
  final String name;
  final String shortName;

  static YouTrackProject fromJson(Map<String, dynamic> json) {
    return YouTrackProject(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      shortName: json['shortName'] as String? ?? '',
    );
  }
}

class YouTrackApiClient {
  YouTrackApiClient({
    required YouTrackConnection connection,
    http.Client? httpClient,
  })  : _http = httpClient ?? http.Client(),
        _connection = connection;

  final http.Client _http;
  final YouTrackConnection _connection;

  YouTrackConnection get connection => _connection;

  Uri _apiBase() {
    var rawUrl = _connection.baseUrl.trim();
    if (rawUrl.endsWith('/')) {
      rawUrl = rawUrl.substring(0, rawUrl.length - 1);
    }
    if (rawUrl.endsWith('/api')) {
      rawUrl = rawUrl.substring(0, rawUrl.length - 4);
    }
    return Uri.parse('$rawUrl/api');
  }

  Map<String, String> _headers() {
    var token = _connection.token.trim();
    if (!token.startsWith('Bearer ') && !token.startsWith('perm:')) {
      // standard YouTrack tokens start with perm:
    }
    return {
      'authorization': 'Bearer $token',
      'content-type': 'application/json',
      'accept': 'application/json',
    };
  }

  Future<Map<String, dynamic>> _getJson(Uri uri) async {
    final resp = await _http.get(uri, headers: _headers());
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw YouTrackApiException(
        'GET failed',
        statusCode: resp.statusCode,
        body: resp.body,
        uri: uri.toString(),
        method: 'GET',
      );
    }
    final decoded = jsonDecode(resp.body);
    if (decoded is! Map) {
      throw const YouTrackApiException('Invalid JSON object response.');
    }
    return Map<String, dynamic>.from(decoded);
  }

  Future<List<dynamic>> _getList(Uri uri) async {
    final resp = await _http.get(uri, headers: _headers());
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw YouTrackApiException(
        'GET failed',
        statusCode: resp.statusCode,
        body: resp.body,
        uri: uri.toString(),
        method: 'GET',
      );
    }
    final decoded = jsonDecode(resp.body);
    if (decoded is! List) {
      throw const YouTrackApiException('Invalid JSON list response.');
    }
    return decoded;
  }

  Future<Map<String, dynamic>> _postJson(Uri uri, Map<String, Object?> body) async {
    final resp = await _http.post(
      uri,
      headers: _headers(),
      body: jsonEncode(body),
    );
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw YouTrackApiException(
        'POST failed',
        statusCode: resp.statusCode,
        body: resp.body,
        uri: uri.toString(),
        method: 'POST',
      );
    }
    final decoded = jsonDecode(resp.body);
    if (decoded is! Map) {
      throw const YouTrackApiException('Invalid JSON object response.');
    }
    return Map<String, dynamic>.from(decoded);
  }

  Future<void> verifyConnection() async {
    final uri = _apiBase().replace(path: '${_apiBase().path}/users/me', queryParameters: {'fields': 'id,login,name'});
    await _getJson(uri);
  }

  Future<List<YouTrackProject>> getProjects() async {
    final uri = _apiBase().replace(path: '${_apiBase().path}/admin/projects', queryParameters: {'fields': 'id,name,shortName'});
    final list = await _getList(uri);
    return list.map((e) => YouTrackProject.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  static const String _issueFields =
      'id,idReadable,summary,description,updated,project(id,name,shortName),customFields(name,value(name,login,displayName,presentation,minutes)),comments(id,text,created,author(name,login,displayName)),attachments(id,name)';

  Future<YouTrackIssue> getIssue(String issueIdOrReadableId) async {
    final uri = _apiBase().replace(
      path: '${_apiBase().path}/issues/$issueIdOrReadableId',
      queryParameters: {'fields': _issueFields},
    );
    final json = await _getJson(uri);
    return YouTrackIssue.fromJson(json);
  }

  Future<List<YouTrackIssue>> searchIssues({
    required String query,
    int top = 50,
  }) async {
    final uri = _apiBase().replace(
      path: '${_apiBase().path}/issues',
      queryParameters: {
        'query': query,
        'fields': _issueFields,
        '\$top': '$top',
      },
    );
    final list = await _getList(uri);
    return list.map((e) => YouTrackIssue.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<YouTrackIssue> createIssue({
    required String projectId,
    required String summary,
    required String description,
  }) async {
    final uri = _apiBase().replace(
      path: '${_apiBase().path}/issues',
      queryParameters: {'fields': _issueFields},
    );
    final body = {
      'summary': summary,
      'description': description,
      'project': {'id': projectId},
    };
    final json = await _postJson(uri, body);
    return YouTrackIssue.fromJson(json);
  }

  Future<void> updateIssueFields({
    required String issueIdOrKey,
    required String summary,
    required String description,
    String? stateFieldId,
    String? stateName,
    String? priorityFieldId,
    String? priorityName,
    Map<String, String>? customFieldIds,
    Map<String, String?>? customFieldValues,
  }) async {
    final uri = _apiBase().replace(
      path: '${_apiBase().path}/issues/$issueIdOrKey',
    );
    final customFields = <Map<String, dynamic>>[];
    if (stateName != null && stateName.isNotEmpty) {
      customFields.add({
        if (stateFieldId != null && stateFieldId.isNotEmpty) 'id': stateFieldId,
        'name': 'State',
        '\$type': 'StateIssueCustomField',
        'value': {'name': stateName},
      });
    }
    if (priorityName != null && priorityName.isNotEmpty) {
      customFields.add({
        if (priorityFieldId != null && priorityFieldId.isNotEmpty) 'id': priorityFieldId,
        'name': 'Priority',
        '\$type': 'SingleEnumIssueCustomField',
        'value': {'name': priorityName},
      });
    }

    if (customFieldIds != null && customFieldValues != null) {
      customFieldValues.forEach((fieldName, val) {
        final normalizedName = fieldName.toLowerCase();
        final fieldId = customFieldIds[normalizedName];
        if (fieldId != null && val != null && val.isNotEmpty) {
          final alreadyAdded = customFields.any((f) => f['id'] == fieldId);
          if (!alreadyAdded) {
            if (normalizedName == 'state') {
              customFields.add({
                'id': fieldId,
                '\$type': 'StateIssueCustomField',
                'value': {'name': val},
              });
            } else if (normalizedName == 'assignee') {
              customFields.add({
                'id': fieldId,
                '\$type': 'SingleUserIssueCustomField',
                'value': {'name': val},
              });
            } else if (normalizedName == 'priority') {
              customFields.add({
                'id': fieldId,
                '\$type': 'SingleEnumIssueCustomField',
                'value': {'name': val},
              });
            } else {
              customFields.add({
                'id': fieldId,
                'value': {'name': val},
              });
            }
          }
        }
      });
    }

    final body = {
      'summary': summary,
      'description': description,
      if (customFields.isNotEmpty) 'customFields': customFields,
    };
    await _postJson(uri, body);
  }

  Future<void> addComment({
    required String issueIdOrKey,
    required String text,
  }) async {
    final uri = _apiBase().replace(
      path: '${_apiBase().path}/issues/$issueIdOrKey/comments',
    );
    await _postJson(uri, {'text': text});
  }

  Future<void> deleteIssue(String issueIdOrKey) async {
    final uri = _apiBase().replace(
      path: '${_apiBase().path}/issues/$issueIdOrKey',
    );
    final resp = await _http.delete(uri, headers: _headers());
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw YouTrackApiException(
        'DELETE issue failed',
        statusCode: resp.statusCode,
        body: resp.body,
        uri: uri.toString(),
        method: 'DELETE',
      );
    }
  }
}
