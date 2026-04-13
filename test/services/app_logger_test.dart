import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:folio/services/app_logger.dart';

class _CollectingSink implements AppLogSink {
  final lines = <String>[];
  Completer<void>? _nextWrite;

  Future<void> waitNextWrite() {
    _nextWrite = Completer<void>();
    return _nextWrite!.future;
  }

  @override
  Future<void> write(String line) async {
    lines.add(line);
    _nextWrite?.complete();
  }
}

void main() {
  group('AppLogger', () {
    tearDown(() {
      AppLogger.setSink(null);
    });

    test('escribe linea con nivel y contexto en sink', () async {
      final sink = _CollectingSink();
      AppLogger.setSink(sink);
      final waitWrite = sink.waitNextWrite();

      AppLogger.info(
        'mensaje de prueba',
        tag: 'test',
        context: {'feature': 'logger'},
      );

      await waitWrite;

      expect(sink.lines, hasLength(1));
      final line = sink.lines.single;
      expect(line, contains(' test '));
      expect(line, contains('[INFO] mensaje de prueba'));
      expect(line, contains('ctx={"feature":"logger"}'));
    });

    test('incluye error y stacktrace en salida de error', () async {
      final sink = _CollectingSink();
      AppLogger.setSink(sink);
      final waitWrite = sink.waitNextWrite();
      final st = StackTrace.current;

      AppLogger.error(
        'fallo controlado',
        tag: 'sync',
        error: StateError('boom'),
        stackTrace: st,
      );

      await waitWrite;

      expect(sink.lines, hasLength(1));
      final line = sink.lines.single;
      expect(line, contains('[ERROR] fallo controlado'));
      expect(line, contains('error=Bad state: boom'));
      expect(line, contains(st.toString().split('\n').first));
    });

    test('no falla si no hay sink configurado', () {
      AppLogger.setSink(null);

      expect(() => AppLogger.debug('solo consola'), returnsNormally);
      expect(() => AppLogger.warn('aviso'), returnsNormally);
    });
  });
}
