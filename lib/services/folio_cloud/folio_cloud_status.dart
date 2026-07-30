import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config/folio_status_urls.dart';
import 'folio_cloud_http_client.dart';

const Duration _kStatusTimeout = Duration(seconds: 8);

/// Snapshot del endpoint público Minealex `/api/folio/status`.
class FolioCloudStatusSnapshot {
  const FolioCloudStatusSnapshot({
    required this.status,
    required this.checkedAt,
    required this.services,
    required this.incidents,
    required this.history,
  });

  /// Agregado: `ok` | `degraded` | `down`.
  final String status;
  final DateTime? checkedAt;
  final Map<String, FolioCloudServiceStatus> services;
  final List<FolioCloudIncident> incidents;
  final List<FolioCloudHistoryDay> history;

  bool get isUnhealthy =>
      status == 'degraded' || status == 'partial' || status == 'down';

  List<FolioCloudIncident> get activeIncidents =>
      incidents.where((i) => i.isActive).toList(growable: false);

  bool get hasActiveIncident => primaryIncident != null;

  /// IDs de servicios visibles en `degraded` / `partial` / `down`.
  List<String> get unhealthyServiceIds {
    return folioCloudStatusVisibleServiceIds(this)
        .where((id) {
          final s = displayStatusFor(id);
          return s == 'degraded' || s == 'partial' || s == 'down';
        })
        .toList(growable: false);
  }

  /// Servicios a listar en el banner.
  /// Prioridad 1: afectados por la incidencia abierta.
  /// Prioridad 2: servicios unhealthy del status (sin incidencia).
  List<String> get bannerAffectedServiceIds {
    final incident = primaryIncident;
    final visible = folioCloudStatusVisibleServiceIds(this);
    if (incident != null) {
      if (incident.affectedServices.isNotEmpty) {
        return visible
            .where((id) => incident.affectedServices.contains(id))
            .toList(growable: false);
      }
      return visible
          .where((id) {
            final embedded = services[id]?.activeIncident;
            if (embedded == null) return false;
            if (incident.id.isNotEmpty && embedded.id == incident.id) {
              return true;
            }
            return embedded.title == incident.title &&
                embedded.impact == incident.impact;
          })
          .toList(growable: false);
    }
    return unhealthyServiceIds;
  }

  /// Severidad visual agregada: `ok` | `degraded` | `partial` | `down`.
  String get uiSeverity {
    var worst = normalizeCloudStatus(status);
    if (worst != 'ok' &&
        worst != 'degraded' &&
        worst != 'partial' &&
        worst != 'down') {
      worst = 'down';
    }
    for (final id in folioCloudStatusVisibleServiceIds(this)) {
      worst = worseStatus(worst, displayStatusFor(id));
    }
    final incident = primaryIncident;
    if (incident != null) {
      final fromImpact = statusFromIncidentImpact(incident.impact);
      if (fromImpact != null) worst = worseStatus(worst, fromImpact);
    }
    return worst;
  }

  /// Severidad del banner: impacto de incidencia (prio 1) o status agregado (prio 2).
  String get bannerSeverity {
    final incident = primaryIncident;
    if (incident != null) {
      return statusFromIncidentImpact(incident.impact) ?? uiSeverity;
    }
    return uiSeverity;
  }

  /// Banner: 1) incidencia abierta, 2) status unhealthy sin incidencia.
  bool get shouldShowBanner {
    if (primaryIncident != null) return true;
    if (isUnhealthy) return true;
    return unhealthyServiceIds.isNotEmpty;
  }

  /// Estado a mostrar para [serviceId]: live check + overlay de incidencias.
  /// Nunca mejora un live `down`; sí puede empeorar un `ok` por impacto de incidencia.
  String displayStatusFor(String serviceId) {
    final live = normalizeCloudStatus(services[serviceId]?.status ?? 'ok');
    final overlay = _incidentOverlayFor(serviceId);
    if (overlay == null) return live;
    return worseStatus(live, overlay);
  }

  /// Motivo del estado del servicio (`incident`, `maintenance`, …) si viene en el API.
  String? statusReasonFor(String serviceId) {
    final reason = services[serviceId]?.statusReason?.trim();
    if (reason != null && reason.isNotEmpty) return reason.toLowerCase();
    final incident = activeIncidentFor(serviceId);
    if (incident == null) return null;
    return incident.type.isNotEmpty ? incident.type : 'incident';
  }

  /// Incidencia activa embebida en el servicio, o la del listado top-level que le afecta.
  FolioCloudIncident? activeIncidentFor(String serviceId) {
    final embedded = services[serviceId]?.activeIncident;
    if (embedded != null) return embedded;
    FolioCloudIncident? best;
    for (final incident in activeIncidents) {
      final affects = incident.affectedServices.isEmpty ||
          incident.affectedServices.contains(serviceId);
      if (!affects) continue;
      if (best == null ||
          _incidentPriority(incident) < _incidentPriority(best)) {
        best = incident;
      }
    }
    return best;
  }

  String? _incidentOverlayFor(String serviceId) {
    String? worst;
    final embedded = services[serviceId]?.activeIncident;
    if (embedded != null) {
      final fromImpact = statusFromIncidentImpact(embedded.impact);
      if (fromImpact != null) worst = fromImpact;
    }
    for (final incident in activeIncidents) {
      final fromImpact = statusFromIncidentImpact(incident.impact);
      if (fromImpact == null) continue;
      final affects =
          incident.affectedServices.isEmpty ||
          incident.affectedServices.contains(serviceId);
      if (!affects) continue;
      worst = worst == null ? fromImpact : worseStatus(worst, fromImpact);
    }
    return worst;
  }

  FolioCloudIncident? get primaryIncident {
    final candidates = <FolioCloudIncident>[
      ...activeIncidents,
      for (final s in services.values)
        if (s.activeIncident != null) s.activeIncident!,
    ];
    if (candidates.isEmpty) return null;
    final byId = <String, FolioCloudIncident>{};
    for (final i in candidates) {
      final key = i.id.isNotEmpty ? i.id : '${i.title}|${i.impact}|${i.status}';
      final prev = byId[key];
      if (prev == null || _incidentPriority(i) < _incidentPriority(prev)) {
        byId[key] = i;
      }
    }
    FolioCloudIncident best = byId.values.first;
    for (final i in byId.values.skip(1)) {
      if (_incidentPriority(i) < _incidentPriority(best)) best = i;
    }
    return best;
  }

  static int _incidentPriority(FolioCloudIncident i) {
    // Menor = más urgente.
    final fromImpact = statusFromIncidentImpact(i.impact);
    final impact = switch (fromImpact) {
      'down' => 0,
      'partial' => 1,
      'degraded' => 2,
      _ => 3,
    };
    final type = i.type == 'incident' ? 0 : 1;
    return impact * 10 + type;
  }

  factory FolioCloudStatusSnapshot.fromJson(Map<String, dynamic> json) {
    final servicesRaw = json['services'];
    final services = <String, FolioCloudServiceStatus>{};
    if (servicesRaw is Map) {
      for (final e in servicesRaw.entries) {
        final key = e.key.toString();
        final val = e.value;
        if (val is Map) {
          services[key] = FolioCloudServiceStatus.fromJson(
            Map<String, dynamic>.from(val),
          );
        }
      }
    }

    final incidents = <FolioCloudIncident>[];
    final incidentsRaw = json['incidents'];
    if (incidentsRaw is List) {
      for (final item in incidentsRaw) {
        if (item is Map) {
          incidents.add(
            FolioCloudIncident.fromJson(Map<String, dynamic>.from(item)),
          );
        }
      }
    }

    final history = <FolioCloudHistoryDay>[];
    final historyRaw = json['history'];
    if (historyRaw is List) {
      for (final item in historyRaw) {
        if (item is Map) {
          history.add(
            FolioCloudHistoryDay.fromJson(Map<String, dynamic>.from(item)),
          );
        }
      }
    }

    return FolioCloudStatusSnapshot(
      status: normalizeCloudStatus(
        (json['status']?.toString() ?? 'down').trim().toLowerCase(),
      ),
      checkedAt: _parseInstant(json['checkedAt'] ?? json['checked_at']),
      services: services,
      incidents: incidents,
      history: history,
    );
  }
}

class FolioCloudServiceStatus {
  const FolioCloudServiceStatus({
    required this.status,
    this.latencyMs,
    bool? healthy,
    this.statusReason,
    this.activeIncident,
  }) : healthy = healthy ?? (status == 'ok');

  /// `ok` | `down` | `degraded` | `partial` | `unconfigured`.
  final String status;
  final int? latencyMs;

  /// Conveniencia del API Minealex (`healthy: true/false`).
  final bool healthy;

  /// Motivo del estado, p.ej. `incident` | `maintenance` (Minealex).
  final String? statusReason;

  /// Incidencia/mantenimiento activo asociado a este servicio (Minealex).
  final FolioCloudIncident? activeIncident;

  bool get isHealthy => healthy;

  factory FolioCloudServiceStatus.fromJson(Map<String, dynamic> json) {
    final latency = json['latencyMs'] ?? json['latency_ms'];
    int? latencyMs;
    if (latency is num) {
      latencyMs = latency.round();
    } else if (latency != null) {
      latencyMs = int.tryParse(latency.toString());
    }
    final status = normalizeCloudStatus(
      (json['status']?.toString() ?? 'down').trim().toLowerCase(),
    );
    bool? healthy;
    final rawHealthy = json['healthy'];
    if (rawHealthy is bool) {
      healthy = rawHealthy;
    }
    final reasonRaw =
        json['statusReason'] ?? json['status_reason'];
    final reason = reasonRaw?.toString().trim();
    FolioCloudIncident? activeIncident;
    final rawIncident =
        json['activeIncident'] ?? json['active_incident'];
    if (rawIncident is Map) {
      activeIncident = FolioCloudIncident.fromJson(
        Map<String, dynamic>.from(rawIncident),
      );
    }
    return FolioCloudServiceStatus(
      status: status,
      latencyMs: latencyMs,
      healthy: healthy,
      statusReason: (reason == null || reason.isEmpty)
          ? null
          : reason.toLowerCase(),
      activeIncident: activeIncident,
    );
  }
}

class FolioCloudIncident {
  const FolioCloudIncident({
    required this.id,
    required this.title,
    required this.type,
    required this.impact,
    required this.status,
    required this.affectedServices,
    this.scheduledFor,
    this.createdAt,
    required this.updates,
  });

  final String id;
  final String title;

  /// `incident` | `maintenance`.
  final String type;

  /// p.ej. `degraded` | `down`.
  final String impact;

  /// `investigating` | `identified` | `monitoring` | `resolved` | `scheduled` | `in_progress`
  final String status;
  final List<String> affectedServices;
  final DateTime? scheduledFor;
  final DateTime? createdAt;
  final List<FolioCloudIncidentUpdate> updates;

  bool get isActive => status != 'resolved';

  factory FolioCloudIncident.fromJson(Map<String, dynamic> json) {
    final affected = <String>[];
    final rawAffected =
        json['affected_services'] ?? json['affectedServices'];
    if (rawAffected is List) {
      for (final a in rawAffected) {
        final s = a?.toString().trim() ?? '';
        if (s.isNotEmpty) affected.add(s);
      }
    }

    final updates = <FolioCloudIncidentUpdate>[];
    final rawUpdates = json['updates'];
    if (rawUpdates is List) {
      for (final u in rawUpdates) {
        if (u is Map) {
          updates.add(
            FolioCloudIncidentUpdate.fromJson(Map<String, dynamic>.from(u)),
          );
        }
      }
    }

    return FolioCloudIncident(
      id: (json['id']?.toString() ?? '').trim(),
      title: (json['title']?.toString() ?? '').trim(),
      type: (json['type']?.toString() ?? 'incident').trim().toLowerCase(),
      impact: (json['impact']?.toString() ?? '').trim().toLowerCase(),
      status: (json['status']?.toString() ?? '').trim().toLowerCase(),
      affectedServices: affected,
      scheduledFor: _parseInstant(
        json['scheduled_for'] ?? json['scheduledFor'],
      ),
      createdAt: _parseInstant(json['created_at'] ?? json['createdAt']),
      updates: updates,
    );
  }
}

class FolioCloudIncidentUpdate {
  const FolioCloudIncidentUpdate({
    required this.status,
    required this.message,
    this.createdAt,
  });

  final String status;
  final String message;
  final DateTime? createdAt;

  factory FolioCloudIncidentUpdate.fromJson(Map<String, dynamic> json) {
    return FolioCloudIncidentUpdate(
      status: (json['status']?.toString() ?? '').trim().toLowerCase(),
      message: (json['message']?.toString() ?? '').trim(),
      createdAt: _parseInstant(json['created_at'] ?? json['createdAt']),
    );
  }
}

class FolioCloudHistoryDay {
  const FolioCloudHistoryDay({
    required this.logDate,
    required this.serviceId,
    required this.totalChecks,
    required this.successfulChecks,
    this.avgLatencyMs,
    required this.uptimePercentage,
  });

  final String logDate;
  final String serviceId;
  final int totalChecks;
  final int successfulChecks;
  final double? avgLatencyMs;
  final double uptimePercentage;

  factory FolioCloudHistoryDay.fromJson(Map<String, dynamic> json) {
    double? avg;
    final rawAvg = json['avg_latency_ms'] ?? json['avgLatencyMs'];
    if (rawAvg is num) {
      avg = rawAvg.toDouble();
    } else if (rawAvg != null) {
      avg = double.tryParse(rawAvg.toString());
    }

    double uptime = 0;
    final rawUp = json['uptime_percentage'] ?? json['uptimePercentage'];
    if (rawUp is num) {
      uptime = rawUp.toDouble();
    } else if (rawUp != null) {
      uptime = double.tryParse(rawUp.toString()) ?? 0;
    }

    int asInt(Object? v) {
      if (v is num) return v.round();
      return int.tryParse(v?.toString() ?? '') ?? 0;
    }

    return FolioCloudHistoryDay(
      logDate: (json['log_date'] ?? json['logDate'] ?? '').toString(),
      serviceId: (json['service_id'] ?? json['serviceId'] ?? '').toString(),
      totalChecks: asInt(json['total_checks'] ?? json['totalChecks']),
      successfulChecks: asInt(
        json['successful_checks'] ?? json['successfulChecks'],
      ),
      avgLatencyMs: avg,
      uptimePercentage: uptime,
    );
  }
}

DateTime? _parseInstant(Object? raw) {
  if (raw == null) return null;
  if (raw is DateTime) return raw.toUtc();
  final s = raw.toString().trim();
  if (s.isEmpty) return null;
  return DateTime.tryParse(s)?.toUtc();
}

/// Orden canónico de servicios en UI (core primero, luego integraciones).
const List<String> kFolioCloudStatusServiceOrder = [
  'api',
  'database',
  'bucket',
  'quill',
  'stripe',
  'resend',
  'jira',
  'slack',
  'teams',
  'spotify',
  'microsoft_store',
];

/// Servicios visibles en UI (omite `unconfigured`).
List<String> folioCloudStatusVisibleServiceIds(
  FolioCloudStatusSnapshot snap,
) {
  final keys = <String>[
    ...kFolioCloudStatusServiceOrder.where(snap.services.containsKey),
    ...snap.services.keys.where(
      (k) => !kFolioCloudStatusServiceOrder.contains(k),
    ),
  ];
  return keys
      .where((id) => snap.services[id]?.status != 'unconfigured')
      .toList(growable: false);
}

/// Normaliza estados Minealex (`partial_outage`, `major_outage`, …) a la UI.
String normalizeCloudStatus(String raw) {
  final s = raw.trim().toLowerCase();
  if (s.isEmpty) return 'down';
  switch (s) {
    case 'ok':
    case 'operational':
    case 'normal':
      return 'ok';
    case 'degraded':
      return 'degraded';
    case 'partial':
    case 'partial_outage':
    case 'minor_outage':
      return 'partial';
    case 'down':
    case 'outage':
    case 'major_outage':
    case 'full_outage':
      return 'down';
    case 'unconfigured':
      return 'unconfigured';
    default:
      return s;
  }
}

/// Mapea impacto de incidencia Minealex → estado de servicio para UI.
String? statusFromIncidentImpact(String impact) {
  final i = impact.trim().toLowerCase();
  if (i.isEmpty) return null;
  switch (i) {
    case 'major_outage':
    case 'down':
    case 'outage':
    case 'full_outage':
      return 'down';
    case 'partial_outage':
    case 'minor_outage':
      return 'partial';
    case 'degraded':
      return 'degraded';
    default:
      return 'degraded';
  }
}

int statusSeverityRank(String status) {
  switch (status) {
    case 'down':
      return 4;
    case 'partial':
      return 3;
    case 'degraded':
      return 2;
    case 'unconfigured':
      return 1;
    case 'ok':
    default:
      return 0;
  }
}

/// El peor de dos estados (nunca “mejora” hacia ok).
String worseStatus(String a, String b) {
  return statusSeverityRank(a) >= statusSeverityRank(b) ? a : b;
}

/// GET público a Minealex status.
Future<FolioCloudStatusSnapshot> fetchFolioCloudStatus({
  http.Client? client,
  String? apiUrl,
  Duration timeout = _kStatusTimeout,
}) async {
  final httpClient = client ?? folioCloudHttpClient;
  final uri = Uri.parse(apiUrl ?? FolioStatusUrls.apiUrl);
  final response = await httpClient
      .get(
        uri,
        headers: const {
          'Accept': 'application/json',
        },
      )
      .timeout(timeout);

  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw FolioCloudStatusException(
      'HTTP ${response.statusCode}',
      statusCode: response.statusCode,
    );
  }

  final body = response.body;
  final decoded = jsonDecode(body);
  if (decoded is! Map) {
    throw const FolioCloudStatusException('Invalid status JSON');
  }
  return FolioCloudStatusSnapshot.fromJson(Map<String, dynamic>.from(decoded));
}

class FolioCloudStatusException implements Exception {
  const FolioCloudStatusException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'FolioCloudStatusException: $message';
}
