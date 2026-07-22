import 'package:flutter_test/flutter_test.dart';

import 'package:folio/services/integrations/integration_command_parser.dart';

void main() {
  const parser = IntegrationCommandParser();

  test('parse link command', () {
    final r = parser.parse('/folio link AB12CD34');
    expect(r, isA<IntegrationCommandLink>());
    expect((r as IntegrationCommandLink).code, 'AB12CD34');
  });

  test('parse create task command', () {
    final r = parser.parse('/folio create task "Buy milk"');
    expect(r, isA<IntegrationCommandCreateTask>());
    expect((r as IntegrationCommandCreateTask).title, 'Buy milk');
  });

  test('parse teams mention prefix', () {
    final r = parser.parse('@Folio /folio link XY987654');
    expect(r, isA<IntegrationCommandLink>());
    expect((r as IntegrationCommandLink).code, 'XY987654');
  });

  test('parse list tasks command', () {
    expect(parser.parse('/folio list tasks'), isA<IntegrationCommandListTasks>());
  });

  test('parse complete task command', () {
    final r = parser.parse('/folio complete task "Buy milk"');
    expect(r, isA<IntegrationCommandCompleteTask>());
    expect((r as IntegrationCommandCompleteTask).title, 'Buy milk');
  });

  test('parse done alias', () {
    final r = parser.parse('/folio done "Ship it"');
    expect(r, isA<IntegrationCommandCompleteTask>());
    expect((r as IntegrationCommandCompleteTask).title, 'Ship it');
  });

  test('reject empty title', () {
    expect(parser.parse('/folio create task ""'), isA<IntegrationCommandUnknown>());
  });

  test('reject unknown command', () {
    expect(parser.parse('/folio delete all'), isA<IntegrationCommandUnknown>());
  });
}
