import 'package:cloud_firestore/cloud_firestore.dart';

/// Tipo de evento de telemetría.
enum TelemetryEventType {
  featureOpened,
  contentAction,
  navigation,
  search,
  sync,
  performance,
  error,
  usageStats,
}

/// Evento de telemetría base. Serializable a JSON para Firestore.
abstract class TelemetryEvent {
  final String id;
  final DateTime timestamp;
  final TelemetryEventType type;

  TelemetryEvent({
    required this.id,
    required this.timestamp,
    required this.type,
  });

  /// Convertir a Map para Firestore
  Map<String, dynamic> toFirestore({
    required String userId,
    required String appVersion,
    required String buildNumber,
  }) {
    return {
      'id': id,
      'timestamp': Timestamp.fromDate(timestamp),
      'type': type.toString().split('.').last,
      'userId': userId,
      'appVersion': appVersion,
      'buildNumber': buildNumber,
      ...toDataMap(),
    };
  }

  /// Datos específicos del evento (override en subclases)
  Map<String, dynamic> toDataMap();
}

/// Evento: Feature abierto/usado
class FeatureEvent extends TelemetryEvent {
  final String featureName;

  FeatureEvent({
    required super.id,
    required super.timestamp,
    required this.featureName,
  }) : super(type: TelemetryEventType.featureOpened);

  @override
  Map<String, dynamic> toDataMap() => {'featureName': featureName};
}

/// Evento: Acción sobre contenido (crear, editar, eliminar, ver)
class ContentActionEvent extends TelemetryEvent {
  final String action; // 'create', 'edit', 'delete', 'view'
  final String contentType; // 'note', 'board', 'task', etc.
  final Map<String, dynamic> metadata;

  ContentActionEvent({
    required super.id,
    required super.timestamp,
    required this.action,
    required this.contentType,
    this.metadata = const {},
  }) : super(type: TelemetryEventType.contentAction);

  @override
  Map<String, dynamic> toDataMap() => {
    'action': action,
    'contentType': contentType,
    'metadata': metadata,
  };
}

/// Evento: Navegación entre pantallas
class NavigationEvent extends TelemetryEvent {
  final String fromScreen;
  final String toScreen;

  NavigationEvent({
    required super.id,
    required super.timestamp,
    required this.fromScreen,
    required this.toScreen,
  }) : super(type: TelemetryEventType.navigation);

  @override
  Map<String, dynamic> toDataMap() => {
    'fromScreen': fromScreen,
    'toScreen': toScreen,
  };
}

/// Evento: Búsqueda/filtrado
class SearchEvent extends TelemetryEvent {
  final String queryType; // 'fulltext', 'filter', 'sort'
  final int resultCount;
  final int? durationMs;

  SearchEvent({
    required super.id,
    required super.timestamp,
    required this.queryType,
    required this.resultCount,
    this.durationMs,
  }) : super(type: TelemetryEventType.search);

  @override
  Map<String, dynamic> toDataMap() => {
    'queryType': queryType,
    'resultCount': resultCount,
    if (durationMs != null) 'durationMs': durationMs,
  };
}

/// Evento: Sincronización
class SyncEvent extends TelemetryEvent {
  final String syncType; // 'push', 'import', 'conflict_detected'
  final bool success;
  final String? errorMessage;
  final int? durationMs;

  SyncEvent({
    required super.id,
    required super.timestamp,
    required this.syncType,
    required this.success,
    this.errorMessage,
    this.durationMs,
  }) : super(type: TelemetryEventType.sync);

  @override
  Map<String, dynamic> toDataMap() => {
    'syncType': syncType,
    'success': success,
    if (errorMessage?.isNotEmpty ?? false) 'errorMessage': errorMessage,
    if (durationMs != null) 'durationMs': durationMs,
  };
}

/// Evento: Rendimiento de operación
class PerformanceEvent extends TelemetryEvent {
  final String operationName;
  final int durationMs;
  final Map<String, dynamic> metadata;

  PerformanceEvent({
    required super.id,
    required super.timestamp,
    required this.operationName,
    required this.durationMs,
    this.metadata = const {},
  }) : super(type: TelemetryEventType.performance);

  @override
  Map<String, dynamic> toDataMap() => {
    'operationName': operationName,
    'durationMs': durationMs,
    'metadata': metadata,
  };
}

/// Evento: Error o excepción
class ErrorEvent extends TelemetryEvent {
  final String errorType;
  final String errorMessage;
  final String context;
  final String? stackTrace;

  ErrorEvent({
    required super.id,
    required super.timestamp,
    required this.errorType,
    required this.errorMessage,
    required this.context,
    this.stackTrace,
  }) : super(type: TelemetryEventType.error);

  @override
  Map<String, dynamic> toDataMap() => {
    'errorType': errorType,
    'errorMessage': errorMessage,
    'context': context,
    if (stackTrace?.isNotEmpty ?? false) 'stackTrace': stackTrace,
  };
}

/// Evento: Estadísticas de uso (cantidad de notas, tamaño, etc.)
class UsageStatsEvent extends TelemetryEvent {
  final Map<String, dynamic> stats;

  UsageStatsEvent({
    required super.id,
    required super.timestamp,
    required this.stats,
  }) : super(type: TelemetryEventType.usageStats);

  @override
  Map<String, dynamic> toDataMap() => {'stats': stats};
}

/// Resumen diario de estadísticas (para agregaciones)
class DailyStatsSnapshot {
  final String date; // YYYY-MM-DD
  final int totalEvents;
  final Map<String, int> eventsByType;
  final int errorCount;
  final int totalSyncTimeMs;
  final int totalPerformanceTimeMs;
  final DateTime lastUpdate;

  DailyStatsSnapshot({
    required this.date,
    required this.totalEvents,
    required this.eventsByType,
    required this.errorCount,
    required this.totalSyncTimeMs,
    required this.totalPerformanceTimeMs,
    required this.lastUpdate,
  });

  Map<String, dynamic> toFirestore() => {
    'date': date,
    'totalEvents': totalEvents,
    'eventsByType': eventsByType,
    'errorCount': errorCount,
    'totalSyncTimeMs': totalSyncTimeMs,
    'totalPerformanceTimeMs': totalPerformanceTimeMs,
    'lastUpdate': Timestamp.fromDate(lastUpdate),
  };
}
