/// Helpers de formato/firma de auto-reports: dedupe, plataforma real, excerpt
/// estructurado y filtrado de DEBUG.
import 'package:flutter_test/flutter_test.dart';
import 'package:folio/services/folio_diagnostic_reporter.dart';

void main() {
  group('FolioDiagnosticReporter.signatureFor', () {
    test('el mismo error produce la misma firma', () {
      final a = FolioDiagnosticReporter.signatureFor(
        tag: 'vault',
        message: 'Failed to persist v1 vault: PathAccessException',
        error: StateError('x'),
      );
      final b = FolioDiagnosticReporter.signatureFor(
        tag: 'vault',
        message: 'Failed to persist v1 vault: PathAccessException',
        error: StateError('x'),
      );
      expect(a, b);
    });

    test('distinto tag da distinta firma', () {
      final a = FolioDiagnosticReporter.signatureFor(
        tag: 'vault',
        message: 'Blocked empty overwrite',
      );
      final b = FolioDiagnosticReporter.signatureFor(
        tag: 'cloud_sync',
        message: 'Blocked empty overwrite',
      );
      expect(a, isNot(b));
    });

    test('distinto tipo de error da distinta firma aunque el mensaje coincida', () {
      final a = FolioDiagnosticReporter.signatureFor(
        tag: 'vault',
        message: 'boom',
        error: StateError('boom'),
      );
      final b = FolioDiagnosticReporter.signatureFor(
        tag: 'vault',
        message: 'boom',
        error: ArgumentError('boom'),
      );
      expect(a, isNot(b));
    });

    test('mensajes con el mismo prefijo (>60 chars) pero cola distinta comparten firma', () {
      final base =
          'Failed to persist v1 vault: PathAccessException: Rename failed - ';
      expect(base.length, greaterThan(60));
      final a = FolioDiagnosticReporter.signatureFor(
        tag: 'vault',
        message: '${base}path=C:/foo',
      );
      final b = FolioDiagnosticReporter.signatureFor(
        tag: 'vault',
        message: '${base}path=C:/bar',
      );
      expect(a, b);
    });

    test('mensajes con prefijos realmente distintos dan firmas distintas', () {
      final a = FolioDiagnosticReporter.signatureFor(
        tag: 'vault',
        message: 'Blocked empty overwrite of vault tree',
      );
      final b = FolioDiagnosticReporter.signatureFor(
        tag: 'vault',
        message: 'Refusing empty tree load: latest known snapshot had pages',
      );
      expect(a, isNot(b));
    });
  });

  group('FolioDiagnosticReporter.platformLabel', () {
    test('web tiene prioridad', () {
      expect(
        FolioDiagnosticReporter.platformLabel(
          isWeb: true,
          operatingSystem: 'android',
        ),
        'web',
      );
    });

    test('usa el OS real en minúsculas', () {
      expect(
        FolioDiagnosticReporter.platformLabel(
          isWeb: false,
          operatingSystem: 'Android',
        ),
        'android',
      );
      expect(
        FolioDiagnosticReporter.platformLabel(
          isWeb: false,
          operatingSystem: 'macos',
        ),
        'macos',
      );
    });
  });

  group('FolioDiagnosticReporter.errorSummaryFor', () {
    test('combina tipo y mensaje en una línea', () {
      final s = FolioDiagnosticReporter.errorSummaryFor(
        loggedMessage: 'Flutter framework error',
        error: StateError('bad state'),
      );
      // StateError.toString() → "Bad state: …"
      expect(s, 'StateError: Bad state: bad state');
    });

    test('trunca a maxChars', () {
      final s = FolioDiagnosticReporter.errorSummaryFor(
        error: StateError('x' * 200),
        maxChars: 40,
      );
      expect(s.length, lessThanOrEqualTo(40));
      expect(s.endsWith('…'), isTrue);
    });

    test('cae al loggedMessage si no hay error', () {
      expect(
        FolioDiagnosticReporter.errorSummaryFor(
          loggedMessage: 'Uncaught zoned error',
        ),
        'Uncaught zoned error',
      );
    });
  });

  group('FolioDiagnosticReporter.alignLogTailToLineStart', () {
    test('descarta la primera línea incompleta', () {
      const raw = 'oGetAppProfileMeta","viaHttp":true}\n'
          '2026-08-01T10:00:00 [cloud_sync] [INFO] ok';
      final aligned = FolioDiagnosticReporter.alignLogTailToLineStart(raw);
      expect(aligned.startsWith('2026-08-01'), isTrue);
      expect(aligned.contains('oGetAppProfileMeta'), isFalse);
    });
  });

  group('FolioDiagnosticReporter.filterLogTail', () {
    test('excluye DEBUG y conserva WARN/ERROR/INFO', () {
      const raw = '''
2026-08-01T10:00:00 [cloud_sync] [DEBUG] callable ok
2026-08-01T10:00:01 [cloud_sync] [INFO] sync start
2026-08-01T10:00:02 [app] [WARN] slow
2026-08-01T10:00:03 [app] [ERROR] boom
''';
      final filtered = FolioDiagnosticReporter.filterLogTail(raw);
      expect(filtered.contains('[DEBUG]'), isFalse);
      expect(filtered.contains('[INFO]'), isTrue);
      expect(filtered.contains('[WARN]'), isTrue);
      expect(filtered.contains('[ERROR]'), isTrue);
    });

    test('respeta maxLines', () {
      final lines = List.generate(20, (i) => 'line $i [INFO] x');
      final filtered = FolioDiagnosticReporter.filterLogTail(
        lines.join('\n'),
        maxLines: 5,
      );
      expect(filtered.split('\n'), hasLength(5));
      expect(filtered, contains('line 19'));
      expect(filtered, isNot(contains('line 0')));
    });
  });

  group('FolioDiagnosticReporter.buildLogExcerpt', () {
    test('estructura Error / Stack / Recent logs y filtra DEBUG', () {
      final excerpt = FolioDiagnosticReporter.buildLogExcerpt(
        loggedTag: 'crash',
        loggedMessage: 'Uncaught zoned error',
        error: StateError('boom'),
        stackTrace: StackTrace.fromString('#0 main (file.dart:1:1)\n'),
        logTail: 't=1 [DEBUG] noise\nt=2 [ERROR] real\n',
      );
      expect(excerpt, contains('## Error'));
      expect(excerpt, contains('## Stack'));
      expect(excerpt, contains('## Recent logs'));
      expect(excerpt, contains('Bad state: boom'));
      expect(excerpt, contains('[ERROR] real'));
      expect(excerpt, isNot(contains('[DEBUG]')));
    });

    test('al truncar preserva Error y Stack', () {
      final longLogs = List.generate(
        200,
        (i) => '2026-08-01T10:00:00 [x] [INFO] line $i ${'y' * 40}',
      ).join('\n');
      final excerpt = FolioDiagnosticReporter.buildLogExcerpt(
        loggedTag: 'crash',
        loggedMessage: 'KEEP_ERROR_MARKER',
        error: StateError('KEEP_STACK_ERR'),
        stackTrace: StackTrace.fromString('KEEP_STACK_FRAME\n'),
        logTail: longLogs,
        maxChars: 2500,
      );
      expect(excerpt, contains('KEEP_ERROR_MARKER'));
      expect(excerpt, contains('KEEP_STACK_ERR'));
      expect(excerpt, contains('KEEP_STACK_FRAME'));
      expect(excerpt.length, lessThanOrEqualTo(2500));
      // El excerpt no debe empezar por cola de logs (truncado del final antiguo).
      expect(excerpt.trimLeft().startsWith('## Error'), isTrue);
    });
  });
}
