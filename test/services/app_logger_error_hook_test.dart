/// AppLogger.error(...) debe disparar el hook registrado con setOnError
/// (usado para el auto-report a YouTrack); debug/info/warn no deben
/// dispararlo, y un hook que lance no debe tumbar el logging.
import 'package:flutter_test/flutter_test.dart';
import 'package:folio/services/app_logger.dart';

void main() {
  tearDown(() {
    AppLogger.setOnError(null);
  });

  group('AppLogger error hook', () {
    test('error() invoca el hook con tag/message/error/stackTrace/context', () {
      String? gotTag;
      String? gotMessage;
      Object? gotError;
      StackTrace? gotStack;
      Map<String, Object?>? gotContext;

      AppLogger.setOnError((tag, message, error, stackTrace, context) {
        gotTag = tag;
        gotMessage = message;
        gotError = error;
        gotStack = stackTrace;
        gotContext = context;
      });

      final st = StackTrace.current;
      AppLogger.error(
        'Algo se rompió',
        tag: 'vault',
        error: StateError('boom'),
        stackTrace: st,
        context: {'vaultId': 'v1'},
      );

      expect(gotTag, 'vault');
      expect(gotMessage, 'Algo se rompió');
      expect(gotError, isA<StateError>());
      expect(gotStack, st);
      expect(gotContext, {'vaultId': 'v1'});
    });

    test('debug/info/warn no invocan el hook', () {
      var calls = 0;
      AppLogger.setOnError((_, _, _, _, _) => calls++);

      AppLogger.debug('d');
      AppLogger.info('i');
      AppLogger.warn('w');

      expect(calls, 0);
    });

    test('una excepción dentro del hook no interrumpe el logging', () {
      AppLogger.setOnError((_, _, _, _, _) {
        throw StateError('el hook explota');
      });

      // No debe lanzar hacia el llamador.
      expect(() => AppLogger.error('sigue funcionando'), returnsNormally);
    });

    test('sin hook registrado, error() no falla', () {
      expect(() => AppLogger.error('sin hook'), returnsNormally);
    });
  });
}
