import 'dart:convert';

/// Estado de la integración con Microsoft Teams.
///
/// Fase 1: webhook. Fase 2: OAuth Graph (tokens opcionales).
class TeamsIntegrationState {
  const TeamsIntegrationState({this.connections = const []});

  final List<TeamsConnection> connections;

  static const TeamsIntegrationState empty = TeamsIntegrationState();

  Map<String, Object?> toJson() => <String, Object?>{
        'connections': connections.map((c) => c.toJson()).toList(growable: false),
      };

  static TeamsIntegrationState fromJson(Object? raw) {
    if (raw is! Map) return empty;
    final m = Map<String, dynamic>.from(raw);
    final conns = <TeamsConnection>[];
    final rawConnections = m['connections'];
    if (rawConnections is List) {
      for (final item in rawConnections) {
        if (item is Map) {
          final c = TeamsConnection.tryParse(Map<String, dynamic>.from(item));
          if (c != null) conns.add(c);
        }
      }
    }
    return TeamsIntegrationState(connections: List.unmodifiable(conns));
  }

  String encode() => jsonEncode(toJson());
}

class TeamsConnection {
  const TeamsConnection({
    required this.id,
    required this.label,
    this.webhookUrl = '',
    this.outgoingWebhookToken = '',
    this.accessToken = '',
    this.refreshToken = '',
    this.expiresAt = '',
    this.tenantId = '',
    this.teamId = '',
    this.channelId = '',
    this.notifyOnStatusChange = true,
    this.notifyOnNewTask = true,
    this.notifyOnComment = true,
  });

  final String id;
  final String label;
  final String webhookUrl;
  final String outgoingWebhookToken;
  final String accessToken;
  final String refreshToken;
  final String expiresAt;
  final String tenantId;
  final String teamId;
  final String channelId;
  final bool notifyOnStatusChange;
  final bool notifyOnNewTask;
  final bool notifyOnComment;

  bool get hasGraphToken => accessToken.trim().isNotEmpty;
  bool get hasWebhook => webhookUrl.trim().isNotEmpty;

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'label': label,
        if (webhookUrl.trim().isNotEmpty) 'webhookUrl': webhookUrl,
        if (outgoingWebhookToken.trim().isNotEmpty)
          'outgoingWebhookToken': outgoingWebhookToken.trim(),
        if (accessToken.trim().isNotEmpty) 'accessToken': accessToken,
        if (refreshToken.trim().isNotEmpty) 'refreshToken': refreshToken,
        if (expiresAt.trim().isNotEmpty) 'expiresAt': expiresAt,
        if (tenantId.trim().isNotEmpty) 'tenantId': tenantId,
        if (teamId.trim().isNotEmpty) 'teamId': teamId,
        if (channelId.trim().isNotEmpty) 'channelId': channelId,
        'notifyOnStatusChange': notifyOnStatusChange,
        'notifyOnNewTask': notifyOnNewTask,
        'notifyOnComment': notifyOnComment,
      };

  static TeamsConnection? tryParse(Map<String, dynamic> map) {
    final id = (map['id'] as String? ?? '').trim();
    final label = (map['label'] as String? ?? '').trim();
    final webhookUrl = (map['webhookUrl'] as String? ?? '').trim();
    final accessToken = (map['accessToken'] as String? ?? '').trim();
    if (id.isEmpty || label.isEmpty) return null;
    if (webhookUrl.isEmpty && accessToken.isEmpty) return null;
    return TeamsConnection(
      id: id,
      label: label,
      webhookUrl: webhookUrl,
      outgoingWebhookToken:
          (map['outgoingWebhookToken'] as String? ?? '').trim(),
      accessToken: accessToken,
      refreshToken: (map['refreshToken'] as String? ?? '').trim(),
      expiresAt: (map['expiresAt'] as String? ?? '').trim(),
      tenantId: (map['tenantId'] as String? ?? '').trim(),
      teamId: (map['teamId'] as String? ?? '').trim(),
      channelId: (map['channelId'] as String? ?? '').trim(),
      notifyOnStatusChange: map['notifyOnStatusChange'] != false,
      notifyOnNewTask: map['notifyOnNewTask'] != false,
      notifyOnComment: map['notifyOnComment'] != false,
    );
  }

  TeamsConnection copyWith({
    String? label,
    String? webhookUrl,
    String? outgoingWebhookToken,
    String? accessToken,
    String? refreshToken,
    String? expiresAt,
    String? tenantId,
    String? teamId,
    String? channelId,
    bool? notifyOnStatusChange,
    bool? notifyOnNewTask,
    bool? notifyOnComment,
  }) {
    return TeamsConnection(
      id: id,
      label: label ?? this.label,
      webhookUrl: webhookUrl ?? this.webhookUrl,
      outgoingWebhookToken: outgoingWebhookToken ?? this.outgoingWebhookToken,
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      expiresAt: expiresAt ?? this.expiresAt,
      tenantId: tenantId ?? this.tenantId,
      teamId: teamId ?? this.teamId,
      channelId: channelId ?? this.channelId,
      notifyOnStatusChange: notifyOnStatusChange ?? this.notifyOnStatusChange,
      notifyOnNewTask: notifyOnNewTask ?? this.notifyOnNewTask,
      notifyOnComment: notifyOnComment ?? this.notifyOnComment,
    );
  }
}
