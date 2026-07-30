import 'package:folio/config/folio_status_urls.dart';
import 'package:folio/services/folio_cloud/folio_cloud_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FolioStatusUrls', () {
    test('statusPageUri usa idioma conocido y cae a es', () {
      expect(
        FolioStatusUrls.statusPageUri(languageCode: 'es').toString(),
        'https://minealexgames.com/es/folio/status',
      );
      expect(
        FolioStatusUrls.statusPageUri(languageCode: 'en').toString(),
        'https://minealexgames.com/en/folio/status',
      );
      expect(
        FolioStatusUrls.statusPageUri(languageCode: 'xx').toString(),
        'https://minealexgames.com/es/folio/status',
      );
    });

    test('apiUrl por defecto es Minealex', () {
      expect(
        FolioStatusUrls.apiUrl,
        'https://minealexgames.com/api/folio/status',
      );
    });
  });

  group('FolioCloudStatusSnapshot.fromJson', () {
    test('parsea services, incidents e history', () {
      final snap = FolioCloudStatusSnapshot.fromJson({
        'status': 'degraded',
        'checkedAt': '2026-07-30T12:30:00.000Z',
        'services': {
          'api': {'status': 'ok', 'latencyMs': 0},
          'database': {'status': 'ok', 'latencyMs': 4},
          'bucket': {'status': 'ok', 'latencyMs': 11},
          'quill': {'status': 'ok', 'latencyMs': 595},
        },
        'incidents': [
          {
            'id': 'uuid-1',
            'title': 'Mantenimiento Programado',
            'type': 'maintenance',
            'impact': 'degraded',
            'status': 'scheduled',
            'affected_services': ['api', 'database'],
            'scheduled_for': '2026-07-31T04:00:00.000Z',
            'created_at': '2026-07-30T10:00:00.000Z',
            'updates': [
              {
                'status': 'scheduled',
                'message': 'Actualizaci├│n de base de datos programada.',
                'created_at': '2026-07-30T10:00:00.000Z',
              },
            ],
          },
        ],
        'history': [
          {
            'log_date': '2026-07-30',
            'service_id': 'database',
            'total_checks': 140,
            'successful_checks': 140,
            'avg_latency_ms': 12,
            'uptime_percentage': 100.0,
          },
        ],
      });

      expect(snap.status, 'degraded');
      expect(snap.isUnhealthy, isTrue);
      expect(snap.shouldShowBanner, isTrue);
      expect(snap.services['api']!.status, 'ok');
      expect(snap.services['quill']!.latencyMs, 595);
      expect(snap.incidents, hasLength(1));
      expect(snap.activeIncidents, hasLength(1));
      expect(snap.primaryIncident?.title, 'Mantenimiento Programado');
      expect(snap.primaryIncident?.affectedServices, ['api', 'database']);
      expect(snap.history.single.uptimePercentage, 100.0);
      expect(snap.history.single.serviceId, 'database');
    });

    test('resolved no cuenta como incidencia activa', () {
      final snap = FolioCloudStatusSnapshot.fromJson({
        'status': 'ok',
        'services': {
          'api': {'status': 'ok', 'latencyMs': 1},
        },
        'incidents': [
          {
            'id': 'done',
            'title': 'Resuelto',
            'type': 'incident',
            'impact': 'down',
            'status': 'resolved',
            'affected_services': [],
            'updates': [],
          },
        ],
        'history': [],
      });
      expect(snap.hasActiveIncident, isFalse);
      expect(snap.shouldShowBanner, isFalse);
    });

    test('major_outage sin affected_services marca todos como down', () {
      final snap = FolioCloudStatusSnapshot.fromJson({
        'status': 'down',
        'services': {
          'api': {'status': 'ok', 'latencyMs': 1},
          'database': {'status': 'ok', 'latencyMs': 2},
          'bucket': {'status': 'ok', 'latencyMs': 3},
          'quill': {'status': 'ok', 'latencyMs': 4},
        },
        'incidents': [
          {
            'id': 'test',
            'title': 'TEST',
            'type': 'incident',
            'impact': 'major_outage',
            'status': 'investigating',
            'affected_services': [],
            'updates': [],
          },
        ],
        'history': [],
      });
      expect(snap.displayStatusFor('api'), 'down');
      expect(snap.displayStatusFor('database'), 'down');
      expect(snap.displayStatusFor('quill'), 'down');
      // latency intacta
      expect(snap.services['api']!.latencyMs, 1);
    });

    test('partial_outage en affected_services degrada solo esos', () {
      final snap = FolioCloudStatusSnapshot.fromJson({
        'status': 'degraded',
        'services': {
          'api': {'status': 'ok', 'latencyMs': 1},
          'database': {'status': 'ok', 'latencyMs': 2},
        },
        'incidents': [
          {
            'id': 'db',
            'title': 'DB lenta',
            'type': 'incident',
            'impact': 'partial_outage',
            'status': 'identified',
            'affected_services': ['database'],
            'updates': [],
          },
        ],
        'history': [],
      });
      expect(snap.displayStatusFor('api'), 'ok');
      expect(snap.displayStatusFor('database'), 'degraded');
    });

    test('live down no se mejora por incidencia degradada', () {
      final snap = FolioCloudStatusSnapshot.fromJson({
        'status': 'degraded',
        'services': {
          'api': {'status': 'down', 'latencyMs': 5},
        },
        'incidents': [
          {
            'id': 'x',
            'title': 'x',
            'type': 'incident',
            'impact': 'degraded',
            'status': 'monitoring',
            'affected_services': ['api'],
            'updates': [],
          },
        ],
        'history': [],
      });
      expect(snap.displayStatusFor('api'), 'down');
    });
    test('parsea payload Minealex con healthy y servicios core+opcionales', () {
      final snap = FolioCloudStatusSnapshot.fromJson({
        'status': 'ok',
        'checkedAt': '2026-07-30T13:05:00.000Z',
        'services': {
          'api': {'status': 'ok', 'latencyMs': 0, 'healthy': true},
          'database': {'status': 'ok', 'latencyMs': 6, 'healthy': true},
          'bucket': {'status': 'ok', 'latencyMs': 497, 'healthy': true},
          'quill': {'status': 'ok', 'latencyMs': 681, 'healthy': true},
          'stripe': {'status': 'ok', 'latencyMs': 349, 'healthy': true},
          'resend': {'status': 'ok', 'latencyMs': 319, 'healthy': true},
          'jira': {'status': 'unconfigured', 'latencyMs': null, 'healthy': false},
          'slack': {'status': 'unconfigured', 'latencyMs': null, 'healthy': false},
          'teams': {'status': 'unconfigured', 'latencyMs': null, 'healthy': false},
          'spotify': {
            'status': 'unconfigured',
            'latencyMs': null,
            'healthy': false,
          },
          'microsoft_store': {
            'status': 'unconfigured',
            'latencyMs': null,
            'healthy': false,
          },
        },
        'incidents': [],
        'history': [],
      });

      expect(snap.status, 'ok');
      expect(snap.shouldShowBanner, isFalse);
      expect(snap.services['stripe']!.healthy, isTrue);
      expect(snap.services['jira']!.status, 'unconfigured');
      expect(snap.services['jira']!.healthy, isFalse);
      expect(snap.services['jira']!.latencyMs, isNull);
      expect(snap.displayStatusFor('spotify'), 'unconfigured');
      expect(
        folioCloudStatusVisibleServiceIds(snap),
        ['api', 'database', 'bucket', 'quill', 'stripe', 'resend'],
      );
      expect(
        kFolioCloudStatusServiceOrder,
        containsAll([
          'stripe',
          'resend',
          'jira',
          'slack',
          'teams',
          'spotify',
          'microsoft_store',
        ]),
      );
    });
  });

  group('statusFromIncidentImpact', () {
    test('mapea major_outage y partial_outage', () {
      expect(statusFromIncidentImpact('major_outage'), 'down');
      expect(statusFromIncidentImpact('partial_outage'), 'degraded');
      expect(statusFromIncidentImpact('degraded'), 'degraded');
    });
  });
}
