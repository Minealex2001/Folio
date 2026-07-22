import 'dart:async';
import 'dart:collection';

import '../../models/discord_integration_state.dart';
import '../../models/slack_integration_state.dart';
import '../../models/teams_integration_state.dart';
import '../app_logger.dart';
import '../discord/discord_api_client.dart';
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

/// Dispatcher compartido entre Slack, Teams y Discord para notificaciones
/// salientes.
///
/// Encola fallos con backoff exponencial (máx. 3 intentos). No bloquea la
/// mutación del vault que disparó el aviso.
class IntegrationNotificationDispatcher {
  IntegrationNotificationDispatcher();

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
    _enqueue(
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
    _enqueue(
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
    _enqueue(
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

  void _ensureTimer() {
    _timer ??= Timer.periodic(const Duration(seconds: 5), (_) {
      unawaited(_flushDue());
    });
  }

  void _enqueue({
    required Iterable<SlackConnection> slackConnections,
    required Iterable<TeamsConnection> teamsConnections,
    required Iterable<DiscordConnection> discordConnections,
    required String text,
  }) {
    final now = DateTime.now().toUtc();
    for (final c in slackConnections) {
      _queue.add(
        _PendingNotification(
          provider: 'slack',
          connectionId: c.id,
          text: text,
          attempts: 0,
          nextAttemptAt: now,
          slack: c,
        ),
      );
    }
    for (final c in teamsConnections) {
      _queue.add(
        _PendingNotification(
          provider: 'teams',
          connectionId: c.id,
          text: text,
          attempts: 0,
          nextAttemptAt: now,
          teams: c,
        ),
      );
    }
    for (final c in discordConnections) {
      _queue.add(
        _PendingNotification(
          provider: 'discord',
          connectionId: c.id,
          text: text,
          attempts: 0,
          nextAttemptAt: now,
          discord: c,
        ),
      );
    }
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
