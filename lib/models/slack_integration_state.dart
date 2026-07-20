import 'dart:convert';

/// Estado de la integración con Slack. Fase 1: solo conexiones vía Incoming
/// Webhook URL (sin OAuth). Slack no tiene concepto de "tablero" que
/// sincronizar, así que a diferencia de Jira/Trello/GitHub/GitLab este
/// estado no tiene `sources`.
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

/// Una conexión = un canal de Slack, identificado por su Incoming Webhook
/// URL, con sus propios interruptores de qué eventos notificar.
class SlackConnection {
  const SlackConnection({
    required this.id,
    required this.label,
    required this.webhookUrl,
    this.notifyOnStatusChange = true,
    this.notifyOnNewTask = true,
    this.notifyOnComment = true,
  });

  final String id;
  final String label;
  final String webhookUrl;
  final bool notifyOnStatusChange;
  final bool notifyOnNewTask;
  final bool notifyOnComment;

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'label': label,
        'webhookUrl': webhookUrl,
        'notifyOnStatusChange': notifyOnStatusChange,
        'notifyOnNewTask': notifyOnNewTask,
        'notifyOnComment': notifyOnComment,
      };

  static SlackConnection? tryParse(Map<String, dynamic> map) {
    final id = (map['id'] as String? ?? '').trim();
    final label = (map['label'] as String? ?? '').trim();
    final webhookUrl = (map['webhookUrl'] as String? ?? '').trim();
    if (id.isEmpty || label.isEmpty || webhookUrl.isEmpty) return null;
    return SlackConnection(
      id: id,
      label: label,
      webhookUrl: webhookUrl,
      notifyOnStatusChange: map['notifyOnStatusChange'] != false,
      notifyOnNewTask: map['notifyOnNewTask'] != false,
      notifyOnComment: map['notifyOnComment'] != false,
    );
  }

  SlackConnection copyWith({
    String? label,
    String? webhookUrl,
    bool? notifyOnStatusChange,
    bool? notifyOnNewTask,
    bool? notifyOnComment,
  }) {
    return SlackConnection(
      id: id,
      label: label ?? this.label,
      webhookUrl: webhookUrl ?? this.webhookUrl,
      notifyOnStatusChange: notifyOnStatusChange ?? this.notifyOnStatusChange,
      notifyOnNewTask: notifyOnNewTask ?? this.notifyOnNewTask,
      notifyOnComment: notifyOnComment ?? this.notifyOnComment,
    );
  }
}
