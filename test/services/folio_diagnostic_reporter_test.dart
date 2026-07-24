/// signatureFor(...) es la base de la deduplicación de auto-reports (cliente
/// por sesión, servidor entre sesiones/dispositivos): mismo tag+tipo de
/// error+prefijo de mensaje debe dar la misma firma; cualquier diferencia
/// relevante debe darla distinta.
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
      // El detalle dinámico (ruta concreta) queda fuera del prefijo usado
      // para la firma, así que reintentos del mismo error no se ven como
      // errores distintos solo porque el mensaje interpolado varía.
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
}
