import 'dart:convert';

/// Estado de la integración con Discord (Incoming Webhook por canal).
class DiscordIntegrationState {
  const DiscordIntegrationState({this.connections = const []});

  final List<DiscordConnection> connections;

  static const DiscordIntegrationState empty = DiscordIntegrationState();

  Map<String, Object?> toJson() => <String, Object?>{
        'connections':
            connections.map((c) => c.toJson()).toList(growable: false),
      };

  static DiscordIntegrationState fromJson(Object? raw) {
    if (raw is! Map) return empty;
    final m = Map<String, dynamic>.from(raw);
    final conns = <DiscordConnection>[];
    final rawConnections = m['connections'];
    if (rawConnections is List) {
      for (final item in rawConnections) {
        if (item is Map) {
          final c = DiscordConnection.tryParse(Map<String, dynamic>.from(item));
          if (c != null) conns.add(c);
        }
      }
    }
    return DiscordIntegrationState(connections: List.unmodifiable(conns));
  }

  String encode() => jsonEncode(toJson());
}

class DiscordConnection {
  const DiscordConnection({
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

  static DiscordConnection? tryParse(Map<String, dynamic> map) {
    final id = (map['id'] as String? ?? '').trim();
    final label = (map['label'] as String? ?? '').trim();
    final webhookUrl = (map['webhookUrl'] as String? ?? '').trim();
    if (id.isEmpty || label.isEmpty || webhookUrl.isEmpty) return null;
    return DiscordConnection(
      id: id,
      label: label,
      webhookUrl: webhookUrl,
      notifyOnStatusChange: map['notifyOnStatusChange'] != false,
      notifyOnNewTask: map['notifyOnNewTask'] != false,
      notifyOnComment: map['notifyOnComment'] != false,
    );
  }

  DiscordConnection copyWith({
    String? label,
    String? webhookUrl,
    bool? notifyOnStatusChange,
    bool? notifyOnNewTask,
    bool? notifyOnComment,
  }) {
    return DiscordConnection(
      id: id,
      label: label ?? this.label,
      webhookUrl: webhookUrl ?? this.webhookUrl,
      notifyOnStatusChange: notifyOnStatusChange ?? this.notifyOnStatusChange,
      notifyOnNewTask: notifyOnNewTask ?? this.notifyOnNewTask,
      notifyOnComment: notifyOnComment ?? this.notifyOnComment,
    );
  }
}
