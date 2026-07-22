import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../models/trello_integration_state.dart';

class TrelloApiException implements Exception {
  const TrelloApiException(
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
    return 'TrelloApiException($code): $m$message$u$b';
  }
}

class TrelloBoard {
  TrelloBoard({required this.id, required this.name});

  final String id;
  final String name;

  static TrelloBoard fromJson(Map<String, dynamic> json) {
    return TrelloBoard(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
    );
  }
}

class TrelloList {
  TrelloList({required this.id, required this.name, this.closed = false});

  final String id;
  final String name;
  final bool closed;

  static TrelloList fromJson(Map<String, dynamic> json) {
    return TrelloList(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      closed: json['closed'] == true,
    );
  }
}

class TrelloLabel {
  TrelloLabel({required this.id, required this.name, required this.color});

  final String id;
  final String name;
  final String? color;

  static TrelloLabel fromJson(Map<String, dynamic> json) {
    return TrelloLabel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      color: json['color'] as String?,
    );
  }
}

class TrelloCheckItem {
  TrelloCheckItem({
    required this.id,
    required this.name,
    required this.state,
    this.pos = 0,
  });

  final String id;
  final String name;
  /// `complete` | `incomplete` (API Trello).
  final String state;
  final double pos;

  bool get isComplete => state.trim().toLowerCase() == 'complete';

  static TrelloCheckItem fromJson(Map<String, dynamic> json) {
    final rawPos = json['pos'];
    final pos = rawPos is num ? rawPos.toDouble() : 0.0;
    return TrelloCheckItem(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      state: json['state'] as String? ?? 'incomplete',
      pos: pos,
    );
  }
}

class TrelloChecklist {
  TrelloChecklist({
    required this.id,
    required this.idCard,
    required this.name,
    this.pos = 0,
    this.checkItems = const [],
  });

  final String id;
  final String idCard;
  final String name;
  final double pos;
  final List<TrelloCheckItem> checkItems;

  static TrelloChecklist fromJson(Map<String, dynamic> json) {
    final rawPos = json['pos'];
    final pos = rawPos is num ? rawPos.toDouble() : 0.0;
    final rawItems = json['checkItems'] as List?;
    final items = <TrelloCheckItem>[];
    if (rawItems != null) {
      for (final item in rawItems) {
        if (item is Map) {
          items.add(TrelloCheckItem.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }
    items.sort((a, b) => a.pos.compareTo(b.pos));
    return TrelloChecklist(
      id: json['id'] as String? ?? '',
      idCard: json['idCard'] as String? ?? '',
      name: json['name'] as String? ?? '',
      pos: pos,
      checkItems: items,
    );
  }
}

class TrelloCard {
  TrelloCard({
    required this.id,
    required this.name,
    required this.desc,
    required this.idList,
    required this.idBoard,
    required this.updatedAtMs,
    this.due,
    this.closed = false,
    this.labels = const [],
    this.memberNames,
    this.checklistItemCount = 0,
    this.checklistCheckedCount = 0,
    this.commentCount = 0,
    this.attachmentCount = 0,
    this.shortUrl,
    this.shortLink,
  });

  final String id;
  final String name;
  final String desc;
  final String idList;
  final String idBoard;
  final int updatedAtMs;
  final String? due;
  final bool closed;
  final List<TrelloLabel> labels;
  final String? memberNames;
  final int checklistItemCount;
  final int checklistCheckedCount;
  final int commentCount;
  final int attachmentCount;
  final String? shortUrl;
  final String? shortLink;

  /// Prefer API shortUrl; otherwise build from shortLink or card id.
  String? get browseUrl {
    final u = (shortUrl ?? '').trim();
    if (u.isNotEmpty) return u;
    final link = (shortLink ?? '').trim();
    if (link.isNotEmpty) return 'https://trello.com/c/$link';
    final idTrim = id.trim();
    if (idTrim.isNotEmpty) return 'https://trello.com/c/$idTrim';
    return null;
  }

  static TrelloCard fromJson(Map<String, dynamic> json) {
    final rawLabels = json['labels'] as List?;
    final labels = <TrelloLabel>[];
    if (rawLabels != null) {
      for (final l in rawLabels) {
        if (l is Map) labels.add(TrelloLabel.fromJson(Map<String, dynamic>.from(l)));
      }
    }

    final rawMembers = json['members'] as List?;
    String? memberNames;
    if (rawMembers != null && rawMembers.isNotEmpty) {
      final names = <String>[];
      for (final m in rawMembers) {
        if (m is Map) {
          final n = m['fullName'] as String? ?? m['username'] as String? ?? '';
          if (n.isNotEmpty) names.add(n);
        }
      }
      if (names.isNotEmpty) memberNames = names.join(', ');
    }

    final badges = json['badges'] as Map?;
    final checkItems = badges != null && badges['checkItems'] is num ? (badges['checkItems'] as num).toInt() : 0;
    final checkItemsChecked =
        badges != null && badges['checkItemsChecked'] is num ? (badges['checkItemsChecked'] as num).toInt() : 0;
    final comments = badges != null && badges['comments'] is num ? (badges['comments'] as num).toInt() : 0;
    final attachments =
        badges != null && badges['attachments'] is num ? (badges['attachments'] as num).toInt() : 0;

    final dateLastActivity = json['dateLastActivity'] as String?;
    var updatedAtMs = 0;
    if (dateLastActivity != null && dateLastActivity.isNotEmpty) {
      updatedAtMs = DateTime.tryParse(dateLastActivity)?.millisecondsSinceEpoch ?? 0;
    }

    final shortUrl = (json['shortUrl'] as String?)?.trim();
    final shortLink = (json['shortLink'] as String?)?.trim();

    return TrelloCard(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      desc: json['desc'] as String? ?? '',
      idList: json['idList'] as String? ?? '',
      idBoard: json['idBoard'] as String? ?? '',
      updatedAtMs: updatedAtMs,
      due: json['due'] as String?,
      closed: json['closed'] == true,
      labels: labels,
      memberNames: memberNames,
      checklistItemCount: checkItems,
      checklistCheckedCount: checkItemsChecked,
      commentCount: comments,
      attachmentCount: attachments,
      shortUrl: (shortUrl?.isEmpty ?? true) ? null : shortUrl,
      shortLink: (shortLink?.isEmpty ?? true) ? null : shortLink,
    );
  }
}

class TrelloComment {
  TrelloComment({
    required this.id,
    required this.text,
    required this.authorName,
    required this.createdMs,
  });

  final String id;
  final String text;
  final String authorName;
  final int createdMs;

  static TrelloComment fromActionJson(Map<String, dynamic> json) {
    final data = json['data'];
    final text = data is Map ? (data['text'] as String? ?? '') : '';
    final member = json['memberCreator'];
    var author = '';
    if (member is Map) {
      author = (member['fullName'] as String? ?? member['username'] as String? ?? '').trim();
    }
    final date = json['date'] as String?;
    var createdMs = 0;
    if (date != null && date.isNotEmpty) {
      createdMs = DateTime.tryParse(date)?.millisecondsSinceEpoch ?? 0;
    }
    return TrelloComment(
      id: json['id'] as String? ?? '',
      text: text,
      authorName: author,
      createdMs: createdMs,
    );
  }
}

class TrelloApiClient {
  TrelloApiClient({
    required TrelloConnection connection,
    http.Client? httpClient,
  })  : _http = httpClient ?? http.Client(),
        _connection = connection;

  static const Duration _httpTimeout = Duration(seconds: 30);
  static const String _base = 'https://api.trello.com/1';

  static const String _cardFields =
      'id,name,desc,idList,idBoard,dateLastActivity,due,closed,idLabels,shortUrl,shortLink';

  final http.Client _http;
  final TrelloConnection _connection;

  TrelloConnection get connection => _connection;

  Uri _uri(String path, [Map<String, String> extra = const {}]) {
    return Uri.parse('$_base$path').replace(queryParameters: {
      'key': _connection.apiKey.trim(),
      'token': _connection.token.trim(),
      ...extra,
    });
  }

  Future<Map<String, dynamic>> _getJson(Uri uri) async {
    final resp = await _http.get(uri).timeout(_httpTimeout);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw TrelloApiException(
        'GET failed',
        statusCode: resp.statusCode,
        body: resp.body,
        uri: uri.toString(),
        method: 'GET',
      );
    }
    final decoded = jsonDecode(resp.body);
    if (decoded is! Map) {
      throw const TrelloApiException('Invalid JSON object response.');
    }
    return Map<String, dynamic>.from(decoded);
  }

  Future<List<dynamic>> _getList(Uri uri) async {
    final resp = await _http.get(uri).timeout(_httpTimeout);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw TrelloApiException(
        'GET failed',
        statusCode: resp.statusCode,
        body: resp.body,
        uri: uri.toString(),
        method: 'GET',
      );
    }
    final decoded = jsonDecode(resp.body);
    if (decoded is! List) {
      throw const TrelloApiException('Invalid JSON list response.');
    }
    return decoded;
  }

  Future<Map<String, dynamic>> _post(Uri uri) async {
    final resp = await _http.post(uri).timeout(_httpTimeout);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw TrelloApiException(
        'POST failed',
        statusCode: resp.statusCode,
        body: resp.body,
        uri: uri.toString(),
        method: 'POST',
      );
    }
    final decoded = jsonDecode(resp.body);
    if (decoded is! Map) {
      throw const TrelloApiException('Invalid JSON object response.');
    }
    return Map<String, dynamic>.from(decoded);
  }

  Future<Map<String, dynamic>> _put(Uri uri) async {
    final resp = await _http.put(uri).timeout(_httpTimeout);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw TrelloApiException(
        'PUT failed',
        statusCode: resp.statusCode,
        body: resp.body,
        uri: uri.toString(),
        method: 'PUT',
      );
    }
    final decoded = jsonDecode(resp.body);
    if (decoded is! Map) {
      throw const TrelloApiException('Invalid JSON object response.');
    }
    return Map<String, dynamic>.from(decoded);
  }

  Future<void> _delete(Uri uri) async {
    final resp = await _http.delete(uri).timeout(_httpTimeout);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw TrelloApiException(
        'DELETE failed',
        statusCode: resp.statusCode,
        body: resp.body,
        uri: uri.toString(),
        method: 'DELETE',
      );
    }
  }

  Future<void> verifyConnection() async {
    await _getJson(_uri('/members/me', {'fields': 'id,username'}));
  }

  Future<List<TrelloBoard>> getBoards() async {
    final list = await _getList(_uri('/members/me/boards', {
      'fields': 'id,name',
      'filter': 'open',
    }));
    return list.map((e) => TrelloBoard.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<List<TrelloList>> getLists(String boardId) async {
    final list = await _getList(_uri('/boards/$boardId/lists', {
      'fields': 'id,name,closed',
      'filter': 'open',
    }));
    return list.map((e) => TrelloList.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<List<TrelloLabel>> getBoardLabels(String boardId) async {
    final list = await _getList(_uri('/boards/$boardId/labels', {
      'fields': 'id,name,color',
      'limit': '1000',
    }));
    return list.map((e) => TrelloLabel.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<List<TrelloCard>> getCards(String boardId) async {
    final list = await _getList(_uri('/boards/$boardId/cards', {
      'fields': _cardFields,
      'filter': 'open',
      'labels': 'true',
      'members': 'true',
      'member_fields': 'fullName,username',
      'badges': 'true',
    }));
    return list.map((e) => TrelloCard.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  /// All checklists on a board (includes check items). Group by [TrelloChecklist.idCard].
  Future<List<TrelloChecklist>> getBoardChecklists(String boardId) async {
    final list = await _getList(_uri('/boards/$boardId/checklists', {
      'fields': 'id,idCard,name,pos',
      'checkItems': 'all',
      'checkItem_fields': 'id,name,state,pos',
    }));
    final checklists = list
        .map((e) => TrelloChecklist.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    checklists.sort((a, b) => a.pos.compareTo(b.pos));
    return checklists;
  }

  Future<List<TrelloChecklist>> getCardChecklists(String cardId) async {
    final list = await _getList(_uri('/cards/$cardId/checklists', {
      'fields': 'id,idCard,name,pos',
      'checkItems': 'all',
      'checkItem_fields': 'id,name,state,pos',
    }));
    final checklists = list
        .map((e) => TrelloChecklist.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    checklists.sort((a, b) => a.pos.compareTo(b.pos));
    return checklists;
  }

  Future<TrelloCard> getCard(String cardId) async {
    final json = await _getJson(_uri('/cards/$cardId', {
      'fields': _cardFields,
      'labels': 'true',
      'members': 'true',
      'member_fields': 'fullName,username',
      'badges': 'true',
    }));
    return TrelloCard.fromJson(json);
  }

  Future<TrelloCard> createCard({
    required String listId,
    required String name,
    required String desc,
    List<String>? idLabels,
  }) async {
    final json = await _post(_uri('/cards', {
      'idList': listId,
      'name': name,
      'desc': desc,
      if (idLabels != null && idLabels.isNotEmpty) 'idLabels': idLabels.join(','),
    }));
    return TrelloCard.fromJson(json);
  }

  Future<void> updateCard({
    required String cardId,
    required String name,
    required String desc,
    String? idList,
    String? due,
  }) async {
    await _put(_uri('/cards/$cardId', {
      'name': name,
      'desc': desc,
      if ((idList ?? '').trim().isNotEmpty) 'idList': idList!.trim(),
      if (due != null) 'due': due,
    }));
  }

  Future<void> updateCardLabels({
    required String cardId,
    required List<String> idLabels,
  }) async {
    await _put(_uri('/cards/$cardId', {
      'idLabels': idLabels.join(','),
    }));
  }

  /// Updates a check item state on a card (`complete` / `incomplete`).
  Future<void> updateCheckItemState({
    required String cardId,
    required String checkItemId,
    required bool complete,
  }) async {
    final id = checkItemId.trim();
    if (id.isEmpty) return;
    await _put(_uri('/cards/$cardId/checkItem/$id', {
      'state': complete ? 'complete' : 'incomplete',
    }));
  }

  Future<void> updateCheckItem({
    required String cardId,
    required String checkItemId,
    String? name,
    bool? complete,
  }) async {
    final id = checkItemId.trim();
    if (id.isEmpty) return;
    await _put(_uri('/cards/$cardId/checkItem/$id', {
      if (name != null) 'name': name,
      if (complete != null) 'state': complete ? 'complete' : 'incomplete',
    }));
  }

  Future<TrelloChecklist> createChecklist({
    required String cardId,
    required String name,
  }) async {
    final json = await _post(_uri('/checklists', {
      'idCard': cardId,
      'name': name,
    }));
    return TrelloChecklist.fromJson(json);
  }

  Future<TrelloCheckItem> createCheckItem({
    required String checklistId,
    required String name,
    bool checked = false,
  }) async {
    final json = await _post(_uri('/checklists/$checklistId/checkItems', {
      'name': name,
      'checked': checked ? 'true' : 'false',
    }));
    return TrelloCheckItem.fromJson(json);
  }

  Future<void> deleteCheckItem({
    required String checklistId,
    required String checkItemId,
  }) async {
    final id = checkItemId.trim();
    if (id.isEmpty) return;
    await _delete(_uri('/checklists/$checklistId/checkItems/$id'));
  }

  Future<void> addComment({
    required String cardId,
    required String text,
  }) async {
    await _post(_uri('/cards/$cardId/actions/comments', {'text': text}));
  }

  Future<List<TrelloComment>> getCardComments(String cardId) async {
    final list = await _getList(_uri('/cards/$cardId/actions', {
      'filter': 'commentCard',
      'fields': 'id,data,date,idMemberCreator',
      'memberCreator': 'true',
      'memberCreator_fields': 'fullName,username',
    }));
    final comments = <TrelloComment>[];
    for (final e in list) {
      if (e is Map) {
        comments.add(TrelloComment.fromActionJson(Map<String, dynamic>.from(e)));
      }
    }
    comments.sort((a, b) => a.createdMs.compareTo(b.createdMs));
    return comments;
  }

  Future<void> archiveCard(String cardId) async {
    await _put(_uri('/cards/$cardId', {'closed': 'true'}));
  }
}
