import 'package:flutter_test/flutter_test.dart';
import 'package:folio/models/jira_integration_state.dart';

void main() {
  group('JiraIntegrationState', () {
    test('serializa y parsea conexiones y fuentes', () {
      const state = JiraIntegrationState(
        connections: [
          JiraConnection(
            id: 'c1',
            deployment: JiraDeployment.cloud,
            label: 'Cloud',
            cloudId: 'cloud_1',
            siteUrl: 'https://example.atlassian.net',
            accessToken: 'at',
            refreshToken: 'rt',
            expiresAtMs: 123,
          ),
          JiraConnection(
            id: 'c2',
            deployment: JiraDeployment.server,
            label: 'Server',
            baseUrl: 'https://jira.example.com',
            pat: 'pat',
          ),
        ],
        sources: [
          JiraSource(
            id: 's1',
            connectionId: 'c1',
            type: JiraSourceType.jql,
            name: 'Mis issues',
            jql: 'assignee=currentUser() ORDER BY updated DESC',
            importOptions: JiraImportOptions(
              includeComments: true,
              includeAttachments: false,
              includeSubtasks: true,
              includeLinks: true,
              includeWorklog: false,
            ),
            customFieldIds: ['customfield_10016'],
            columnMappings: [
              JiraColumnMapping(columnId: 'todo', statusName: 'To Do'),
              JiraColumnMapping(columnId: 'in_progress', transitionId: '31'),
            ],
          ),
        ],
      );

      final encoded = state.encode();
      final parsed = JiraIntegrationState.fromJson(state.toJson());
      expect(encoded, isNotEmpty);
      expect(parsed.connections.length, 2);
      expect(parsed.sources.length, 1);
      expect(parsed.connections.first.deployment, JiraDeployment.cloud);
      expect(parsed.sources.first.type, JiraSourceType.jql);
      expect(parsed.sources.first.importOptions.includeAttachments, isFalse);
      expect(parsed.sources.first.customFieldIds, ['customfield_10016']);
      expect(parsed.sources.first.columnMappings.length, 2);
      expect(parsed.sources.first.columnMappings.first.columnId, 'todo');
    });
  });
}

