import 'dart:convert';

/// Estado de la integración con Slack.
///
/// Fase 1: Incoming Webhook. Fase 2: OAuth bot token (campos opcionales).
class SlackIntegrationState {
  const SlackIntegrationState({this.connections = const []});

  final List<SlackConnection> connections;

  static const SlackIntegrationState empty = SlackIntegrationState();

  Map<String, Object?> toJson() => <String, Object?>{
        'connections': connections.map((c) => c.toJson()).toList(growable: false),
      };

  static SlackIntegrationState fromJson(Object? raw) {
    if (raw is! Map) return empty;
    final m = Map<String, dynamic>.from(raw);
    final conns = <SlackConnection>[];
    final rawConnections = m['connections'];
    if (rawConnections is List) {
      for (final item in rawConnections) {
        if (item is Map) {
          final c = SlackConnection.tryParse(Map<String, dynamic>.from(item));
          if (c != null) conns.add(c);
        }
      }
    }
    return SlackIntegrationState(connections: List.unmodifiable(conns));
  }

  String encode() => jsonEncode(toJson());
}

class SlackConnection {
  const SlackConnection({
    required this.id,
    required this.label,
    this.webhookUrl = '',
    this.accessToken = '',
    this.refreshToken = '',
    this.expiresAt = '',
    this.teamId = '',
    this.botUserId = '',
    this.channelId = '',
    this.notifyOnStatusChange = true,
    this.notifyOnNewTask = true,
    this.notifyOnComment = true,
  });

  final String id;
  final String label;
  final String webhookUrl;
  final String accessToken;
  final String refreshToken;
  final String expiresAt;
  final String teamId;
  final String botUserId;
  final String channelId;
  final bool notifyOnStatusChange;
  final bool notifyOnNewTask;
  final bool notifyOnComment;

  bool get hasBotToken => accessToken.trim().isNotEmpty;
  bool get hasWebhook => webhookUrl.trim().isNotEmpty;

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'label': label,
        if (webhookUrl.trim().isNotEmpty) 'webhookUrl': webhookUrl,
        if (accessToken.trim().isNotEmpty) 'accessToken': accessToken,
        if (refreshToken.trim().isNotEmpty) 'refreshToken': refreshToken,
        if (expiresAt.trim().isNotEmpty) 'expiresAt': expiresAt,
        if (teamId.trim().isNotEmpty) 'teamId': teamId,
        if (botUserId.trim().isNotEmpty) 'botUserId': botUserId,
        if (channelId.trim().isNotEmpty) 'channelId': channelId,
        'notifyOnStatusChange': notifyOnStatusChange,
        'notifyOnNewTask': notifyOnNewTask,
        'notifyOnComment': notifyOnComment,
      };

  static SlackConnection? tryParse(Map<String, dynamic> map) {
    final id = (map['id'] as String? ?? '').trim();
    final label = (map['label'] as String? ?? '').trim();
    final webhookUrl = (map['webhookUrl'] as String? ?? '').trim();
    final accessToken = (map['accessToken'] as String? ?? '').trim();
    if (id.isEmpty || label.isEmpty) return null;
    if (webhookUrl.isEmpty && accessToken.isEmpty) return null;
    return SlackConnection(
      id: id,
      label: label,
      webhookUrl: webhookUrl,
      accessToken: accessToken,
      refreshToken: (map['refreshToken'] as String? ?? '').trim(),
      expiresAt: (map['expiresAt'] as String? ?? '').trim(),
      teamId: (map['teamId'] as String? ?? '').trim(),
      botUserId: (map['botUserId'] as String? ?? '').trim(),
      channelId: (map['channelId'] as String? ?? '').trim(),
      notifyOnStatusChange: map['notifyOnStatusChange'] != false,
      notifyOnNewTask: map['notifyOnNewTask'] != false,
      notifyOnComment: map['notifyOnComment'] != false,
    );
  }

  SlackConnection copyWith({
    String? label,
    String? webhookUrl,
    String? accessToken,
    String? refreshToken,
    String? expiresAt,
    String? teamId,
    String? botUserId,
    String? channelId,
    bool? notifyOnStatusChange,
    bool? notifyOnNewTask,
    bool? notifyOnComment,
  }) {
    return SlackConnection(
      id: id,
      label: label ?? this.label,
      webhookUrl: webhookUrl ?? this.webhookUrl,
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      expiresAt: expiresAt ?? this.expiresAt,
      teamId: teamId ?? this.teamId,
      botUserId: botUserId ?? this.botUserId,
      channelId: channelId ?? this.channelId,
      notifyOnStatusChange: notifyOnStatusChange ?? this.notifyOnStatusChange,
      notifyOnNewTask: notifyOnNewTask ?? this.notifyOnNewTask,
      notifyOnComment: notifyOnComment ?? this.notifyOnComment,
    );
  }
}
