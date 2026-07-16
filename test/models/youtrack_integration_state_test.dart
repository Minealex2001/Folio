import 'package:flutter_test/flutter_test.dart';
import 'package:folio/models/youtrack_integration_state.dart';

void main() {
  group('YouTrackIntegrationState', () {
    test('serializa y parsea conexiones y fuentes', () {
      const state = YouTrackIntegrationState(
        connections: [
          YouTrackConnection(
            id: 'c1',
            label: 'YouTrack Standalone',
            baseUrl: 'https://youtrack.example.com',
            token: 'perm:my-token',
          ),
        ],
        sources: [
          YouTrackSource(
            id: 's1',
            connectionId: 'c1',
            type: YouTrackSourceType.query,
            name: 'Sprint Backlog',
            query: 'project: DEMO State: -Fixed, -Done',
            importOptions: YouTrackImportOptions(
              includeComments: true,
              includeAttachments: false,
            ),
            columnMappings: [
              YouTrackColumnMapping(columnId: 'todo', stateName: 'To Do'),
              YouTrackColumnMapping(columnId: 'in_progress', stateName: 'In Progress'),
              YouTrackColumnMapping(columnId: 'done', stateName: 'Fixed'),
            ],
          ),
        ],
      );

      final encoded = state.encode();
      final parsed = YouTrackIntegrationState.fromJson(state.toJson());
      expect(encoded, isNotEmpty);
      expect(parsed.connections.length, 1);
      expect(parsed.sources.length, 1);
      expect(parsed.connections.first.label, 'YouTrack Standalone');
      expect(parsed.sources.first.type, YouTrackSourceType.query);
      expect(parsed.sources.first.importOptions.includeAttachments, isFalse);
      expect(parsed.sources.first.columnMappings.length, 3);
      expect(parsed.sources.first.columnMappings.first.columnId, 'todo');
      expect(parsed.sources.first.columnMappings.first.stateName, 'To Do');
    });
  });
}
