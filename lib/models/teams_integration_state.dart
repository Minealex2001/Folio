import 'dart:convert';

/// Estado de la integración con Microsoft Teams. Fase 1: solo conexiones vía
/// webhook entrante de un Workflow ("Post to a channel when a webhook
/// request is received"), sin OAuth. Igual que Slack, Teams no tiene
/// concepto de "tablero" que sincronizar, así que este estado no tiene
/// `sources`.
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

/// Una conexión = un canal de Teams, identificado por su URL de webhook de
/// Workflow, con sus propios interruptores de qué eventos notificar.
class TeamsConnection {
  const TeamsConnection({
    required this.id,
    required this.label,
    required this.webhookUrl,
    this.outgoingWebhookToken = '',
    this.notifyOnStatusChange = true,
    this.notifyOnNewTask = true,
    this.notifyOnComment = true,
  });

  final String id;
  final String label;
  final String webhookUrl;
  /// Token HMAC del Outgoing Webhook de Teams (comandos entrantes Fase 3).
  final String outgoingWebhookToken;
  final bool notifyOnStatusChange;
  final bool notifyOnNewTask;
  final bool notifyOnComment;

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'label': label,
        'webhookUrl': webhookUrl,
        if (outgoingWebhookToken.trim().isNotEmpty)
          'outgoingWebhookToken': outgoingWebhookToken.trim(),
        'notifyOnStatusChange': notifyOnStatusChange,
        'notifyOnNewTask': notifyOnNewTask,
        'notifyOnComment': notifyOnComment,
      };

  static TeamsConnection? tryParse(Map<String, dynamic> map) {
    final id = (map['id'] as String? ?? '').trim();
    final label = (map['label'] as String? ?? '').trim();
    final webhookUrl = (map['webhookUrl'] as String? ?? '').trim();
    if (id.isEmpty || label.isEmpty || webhookUrl.isEmpty) return null;
    return TeamsConnection(
      id: id,
      label: label,
      webhookUrl: webhookUrl,
      outgoingWebhookToken: (map['outgoingWebhookToken'] as String? ?? '').trim(),
      notifyOnStatusChange: map['notifyOnStatusChange'] != false,
      notifyOnNewTask: map['notifyOnNewTask'] != false,
      notifyOnComment: map['notifyOnComment'] != false,
    );
  }

  TeamsConnection copyWith({
    String? label,
    String? webhookUrl,
    String? outgoingWebhookToken,
    bool? notifyOnStatusChange,
    bool? notifyOnNewTask,
    bool? notifyOnComment,
  }) {
    return TeamsConnection(
      id: id,
      label: label ?? this.label,
      webhookUrl: webhookUrl ?? this.webhookUrl,
      outgoingWebhookToken: outgoingWebhookToken ?? this.outgoingWebhookToken,
      notifyOnStatusChange: notifyOnStatusChange ?? this.notifyOnStatusChange,
      notifyOnNewTask: notifyOnNewTask ?? this.notifyOnNewTask,
      notifyOnComment: notifyOnComment ?? this.notifyOnComment,
    );
  }
}
