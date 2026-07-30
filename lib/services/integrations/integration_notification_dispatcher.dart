import 'dart:async';
import 'dart:collection';

import '../../models/discord_integration_state.dart';
import '../../models/slack_integration_state.dart';
import '../../models/teams_integration_state.dart';
import '../app_logger.dart';
import '../discord/discord_api_client.dart';
import '../folio_cloud/folio_cloud_callable.dart';
import '../folio_cloud/folio_cloud_exception.dart';
import '../integrations/integration_webhook_transport.dart';
import '../slack/slack_api_client.dart';
import '../teams/teams_api_client.dart';

class _PendingNotification {
  _PendingNotification({
    required this.provider,
    required this.connectionId,
    required this.text,
    required this.attempts,
    required this.nextAttemptAt,
    this.slack,
    this.teams,
    this.discord,
  });

  final String provider;
  final String connectionId;
  final String text;
  final int attempts;
  final DateTime nextAttemptAt;
  final SlackConnection? slack;
  final TeamsConnection? teams;
  final DiscordConnection? discord;
}

/// Dispatcher compartido entre Slack, Teams y Discord para notificaciones salientes.
///
/// Las conexiones basadas en webhook (el caso común) se encolan en el outbox
/// durable del backend (`POST /integrations/notifications/enqueue`), que
/// reintenta con backoff y sobrevive el cierre de la app — antes esto vivía
/// solo en memoria aquí y se perdía en silencio si la app se cerraba a mitad
/// de un backoff.
///
/// Las conexiones que usan Bot API/Graph API (token OAuth en vez de webhook)
/// no tienen equivalente server-side hoy (el backend no gestiona esos
/// tokens), así que siguen el camino anterior: envío directo desde el
/// cliente con reintento en memoria (máx. 3 intentos).
class IntegrationNotificationDispatcher {
  IntegrationNotificationDispatcher({IntegrationWebhookTransport? transport})
    : _transport = transport ?? IntegrationWebhookTransport();

  final IntegrationWebhookTransport _transport;

  static const _maxAttempts = 3;
  static const _backoff = <Duration>[
    Duration(seconds: 5),
    Duration(seconds: 15),
    Duration(seconds: 45),
  ];

  final Queue<_PendingNotification> _queue = Queue<_PendingNotification>();
  Timer? _timer;
  bool _flushing = false;

  void notifyTaskStatusChanged({
    required List<SlackConnection> slackConnections,
    required List<TeamsConnection> teamsConnections,
    List<DiscordConnection> discordConnections = const [],
    required String message,
  }) {
    _dispatch(
      slackConnections: slackConnections.where((c) => c.notifyOnStatusChange),
      teamsConnections: teamsConnections.where((c) => c.notifyOnStatusChange),
      discordConnections:
          discordConnections.where((c) => c.notifyOnStatusChange),
      text: message,
    );
  }

  void notifyTaskCreated({
    required List<SlackConnection> slackConnections,
    required List<TeamsConnection> teamsConnections,
    List<DiscordConnection> discordConnections = const [],
    required String message,
  }) {
    _dispatch(
      slackConnections: slackConnections.where((c) => c.notifyOnNewTask),
      teamsConnections: teamsConnections.where((c) => c.notifyOnNewTask),
      discordConnections: discordConnections.where((c) => c.notifyOnNewTask),
      text: message,
    );
  }

  void notifyCommentAdded({
    required List<SlackConnection> slackConnections,
    required List<TeamsConnection> teamsConnections,
    List<DiscordConnection> discordConnections = const [],
    required String message,
  }) {
    _dispatch(
      slackConnections: slackConnections.where((c) => c.notifyOnComment),
      teamsConnections: teamsConnections.where((c) => c.notifyOnComment),
      discordConnections: discordConnections.where((c) => c.notifyOnComment),
      text: message,
    );
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
    _queue.clear();
  }

  void _dispatch({
    required Iterable<SlackConnection> slackConnections,
    required Iterable<TeamsConnection> teamsConnections,
    required Iterable<DiscordConnection> discordConnections,
    required String text,
  }) {
    for (final c in slackConnections) {
      if (c.hasWebhook) {
        unawaited(
          _enqueueServerSide(
            provider: 'slack',
            connectionId: c.id,
            webhookUrl: c.webhookUrl,
            payload: {'text': text},
          ),
        );
      } else {
        _enqueueLocalFallback(
          provider: 'slack',
          connectionId: c.id,
          text: text,
          slack: c,
        );
      }
    }
    for (final c in teamsConnections) {
      if (c.hasWebhook) {
        unawaited(
          _enqueueServerSide(
            provider: 'teams',
            connectionId: c.id,
            webhookUrl: c.webhookUrl,
            payload: _teamsAdaptiveCard(text),
          ),
        );
      } else {
        _enqueueLocalFallback(
          provider: 'teams',
          connectionId: c.id,
          text: text,
          teams: c,
        );
      }
    }
    for (final c in discordConnections) {
      // Discord solo soporta Incoming Webhook en este cliente (ver
      // DiscordApiClient) — siempre hasWebhook.
      unawaited(
        _enqueueServerSide(
          provider: 'discord',
          connectionId: c.id,
          webhookUrl: c.webhookUrl,
          payload: {'content': text},
        ),
      );
    }
  }

  static Map<String, Object?> _teamsAdaptiveCard(String text) => {
    'type': 'message',
    'attachments': [
      {
        'contentType': 'application/vnd.microsoft.card.adaptive',
        'content': {
          r'$schema': 'http://adaptivecards.io/schemas/adaptive-card.json',
          'type': 'AdaptiveCard',
          'version': '1.4',
          'body': [
            {'type': 'TextBlock', 'text': text, 'wrap': true},
          ],
        },
      },
    ],
  };

  Future<void> _enqueueServerSide({
    required String provider,
    required String connectionId,
    required String webhookUrl,
    required Map<String, Object?> payload,
  }) async {
    Future<void> callEnqueue() => callFolioHttpsCallable(
      'folioEnqueueIntegrationNotification',
      {'provider': provider, 'connectionId': connectionId, 'payload': payload},
    );
    try {
      await callEnqueue();
    } on FolioCloudException catch (e) {
      // La conexión puede no estar registrada server-side todavía (creada
      // antes de que el registro fuera multiplataforma, o primera vez que se
      // usa) — auto-sana registrándola y reintentando una vez, mismo patrón
      // que IntegrationWebhookTransport.postJson en Web.
      if (e.code.toLowerCase() != 'not-found') {
        AppLogger.warn(
          '$provider notification enqueue failed',
          tag: provider,
          context: {'connectionId': connectionId, 'error': '$e'},
        );
        return;
      }
      try {
        await _transport.registerConnection(
          provider: provider,
          connectionId: connectionId,
          webhookUrl: webhookUrl,
        );
        await callEnqueue();
      } catch (e2) {
        AppLogger.warn(
          '$provider notification enqueue failed after re-register',
          tag: provider,
          context: {'connectionId': connectionId, 'error': '$e2'},
        );
      }
    } catch (e) {
      AppLogger.warn(
        '$provider notification enqueue failed',
        tag: provider,
        context: {'connectionId': connectionId, 'error': '$e'},
      );
    }
  }

  // --- Fallback en memoria para conexiones sin webhook (Bot/Graph token) ---

  void _ensureTimer() {
    _timer ??= Timer.periodic(const Duration(seconds: 5), (_) {
      unawaited(_flushDue());
    });
  }

  void _enqueueLocalFallback({
    required String provider,
    required String connectionId,
    required String text,
    SlackConnection? slack,
    TeamsConnection? teams,
    DiscordConnection? discord,
  }) {
    _queue.add(
      _PendingNotification(
        provider: provider,
        connectionId: connectionId,
        text: text,
        attempts: 0,
        nextAttemptAt: DateTime.now().toUtc(),
        slack: slack,
        teams: teams,
        discord: discord,
      ),
    );
    _ensureTimer();
    unawaited(_flushDue());
  }

  Future<void> _flushDue() async {
    if (_flushing) return;
    _flushing = true;
    try {
      final now = DateTime.now().toUtc();
      final due = <_PendingNotification>[];
      final deferred = <_PendingNotification>[];
      while (_queue.isNotEmpty) {
        final item = _queue.removeFirst();
        if (item.nextAttemptAt.isAfter(now)) {
          deferred.add(item);
        } else {
          due.add(item);
        }
      }
      for (final d in deferred) {
        _queue.add(d);
      }
      for (final item in due) {
        await _send(item);
      }
      if (_queue.isEmpty) {
        _timer?.cancel();
        _timer = null;
      }
    } finally {
      _flushing = false;
    }
  }

  Future<void> _send(_PendingNotification item) async {
    try {
      switch (item.provider) {
        case 'slack':
          final c = item.slack;
          if (c == null) return;
          await SlackApiClient(connection: c).postMessage(item.text);
        case 'teams':
          final c = item.teams;
          if (c == null) return;
          await TeamsApiClient(connection: c).postMessage(item.text);
        case 'discord':
          final c = item.discord;
          if (c == null) return;
          await DiscordApiClient(connection: c).postMessage(item.text);
        default:
          return;
      }
    } catch (e) {
      final nextAttempt = item.attempts + 1;
      AppLogger.warn(
        '${item.provider} notification failed',
        tag: item.provider,
        context: {
          'connectionId': item.connectionId,
          'attempt': '$nextAttempt',
          'error': '$e',
        },
      );
      if (nextAttempt >= _maxAttempts) return;
      final delay = _backoff[nextAttempt.clamp(0, _backoff.length - 1)];
      _queue.add(
        _PendingNotification(
          provider: item.provider,
          connectionId: item.connectionId,
          text: item.text,
          attempts: nextAttempt,
          nextAttemptAt: DateTime.now().toUtc().add(delay),
          slack: item.slack,
          teams: item.teams,
          discord: item.discord,
        ),
      );
      _ensureTimer();
    }
  }
}
