import '../../models/slack_integration_state.dart';
import '../../models/teams_integration_state.dart';
import '../app_logger.dart';
import '../slack/slack_api_client.dart';
import '../teams/teams_api_client.dart';

/// Dispatcher compartido entre Slack y Teams para notificaciones salientes.
///
/// A diferencia del resto de integraciones (copiadas por proveedor), esto es
/// una única abstracción cross-provider deliberada: para Slack/Teams,
/// notificar es estructuralmente idéntico en ambos (formatear un mensaje y
/// hacer POST a un webhook), así que separar por proveedor solo duplicaría
/// código sin ganar nada.
///
/// El envío es "best-effort": nunca bloquea la acción del usuario que lo
/// disparó y nunca reintenta ni encola en caso de fallo (no existe
/// infraestructura de reintentos en Folio hoy); los errores solo se
/// registran vía [AppLogger].
class IntegrationNotificationDispatcher {
  const IntegrationNotificationDispatcher();

  void notifyTaskStatusChanged({
    required List<SlackConnection> slackConnections,
    required List<TeamsConnection> teamsConnections,
    required String message,
  }) {
    _dispatch(
      slackConnections: slackConnections.where((c) => c.notifyOnStatusChange),
      teamsConnections: teamsConnections.where((c) => c.notifyOnStatusChange),
      text: message,
    );
  }

  void notifyTaskCreated({
    required List<SlackConnection> slackConnections,
    required List<TeamsConnection> teamsConnections,
    required String message,
  }) {
    _dispatch(
      slackConnections: slackConnections.where((c) => c.notifyOnNewTask),
      teamsConnections: teamsConnections.where((c) => c.notifyOnNewTask),
      text: message,
    );
  }

  void notifyCommentAdded({
    required List<SlackConnection> slackConnections,
    required List<TeamsConnection> teamsConnections,
    required String message,
  }) {
    _dispatch(
      slackConnections: slackConnections.where((c) => c.notifyOnComment),
      teamsConnections: teamsConnections.where((c) => c.notifyOnComment),
      text: message,
    );
  }

  void _dispatch({
    required Iterable<SlackConnection> slackConnections,
    required Iterable<TeamsConnection> teamsConnections,
    required String text,
  }) {
    for (final c in slackConnections) {
      // ignore: discarded_futures
      SlackApiClient(connection: c).postMessage(text).catchError((Object e) {
        AppLogger.warn(
          'Slack notification failed',
          tag: 'slack',
          context: {'connectionId': c.id, 'error': '$e'},
        );
      });
    }
    for (final c in teamsConnections) {
      // ignore: discarded_futures
      TeamsApiClient(connection: c).postMessage(text).catchError((Object e) {
        AppLogger.warn(
          'Teams notification failed',
          tag: 'teams',
          context: {'connectionId': c.id, 'error': '$e'},
        );
      });
    }
  }
}
