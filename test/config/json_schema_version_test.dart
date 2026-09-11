import 'package:flutter_test/flutter_test.dart';
import 'package:folio/config/json_schema_version.dart';

void main() {
  group('runMigrations', () {
    test('leaves an already-current document unchanged', () {
      final doc = {'schemaVersion': 1, 'name': 'default'};
      final result = runMigrations(doc, 1);
      expect(result, doc);
    });

    test('applies a single migration step', () {
      final doc = {'schemaVersion': 1, 'width': 280};
      final migrations = [
        ConfigMigration(
          fromVersion: 1,
          migrate: (json) {
            final next = Map<String, dynamic>.from(json);
            next['panelWidth'] = next.remove('width');
            return next;
          },
        ),
      ];
      final result = runMigrations(doc, 2, registry: migrations);
      expect(result['schemaVersion'], 2);
      expect(result['panelWidth'], 280);
      expect(result.containsKey('width'), isFalse);
    });

    test('applies multiple sequential migrations in order', () {
      final doc = {'schemaVersion': 1, 'value': 1};
      final migrations = [
        ConfigMigration(
          fromVersion: 1,
          migrate: (json) => {...json, 'value': (json['value'] as int) + 10},
        ),
        ConfigMigration(
          fromVersion: 2,
          migrate: (json) => {...json, 'value': (json['value'] as int) * 2},
        ),
      ];
      final result = runMigrations(doc, 3, registry: migrations);
      expect(result['schemaVersion'], 3);
      expect(result['value'], 22); // (1 + 10) * 2
    });

    test('is idempotent when run twice on an already-migrated document', () {
      final doc = {'schemaVersion': 1, 'value': 1};
      final migrations = [
        ConfigMigration(
          fromVersion: 1,
          migrate: (json) => {...json, 'value': (json['value'] as int) + 1},
        ),
      ];
      final once = runMigrations(doc, 2, registry: migrations);
      final twice = runMigrations(once, 2, registry: migrations);
      expect(twice, once);
    });

    test('does not throw and returns best-effort result for an unknown '
        'future version with no migration path', () {
      final doc = {'schemaVersion': 5, 'value': 1};
      final result = runMigrations(doc, 2, registry: const []);
      expect(result['schemaVersion'], 5);
      expect(result['value'], 1);
    });

    test('missing schemaVersion is treated as version 0', () {
      final doc = {'value': 1};
      final migrations = [
        ConfigMigration(
          fromVersion: 0,
          migrate: (json) => {...json, 'value': (json['value'] as int) + 1},
        ),
      ];
      final result = runMigrations(doc, 1, registry: migrations);
      expect(result['schemaVersion'], 1);
      expect(result['value'], 2);
    });
  });
}
