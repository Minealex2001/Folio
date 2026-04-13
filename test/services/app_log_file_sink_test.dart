import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folio/services/app_log_file_sink.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

  group('AppLogFileSink', () {
    late Directory mockedSupportDir;

    setUp(() async {
      mockedSupportDir = await Directory.systemTemp.createTemp(
        'folio_support_',
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(pathProviderChannel, (call) async {
            return mockedSupportDir.path;
          });
    });

    tearDown(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(pathProviderChannel, null);
      if (mockedSupportDir.existsSync()) {
        await mockedSupportDir.delete(recursive: true);
      }
    });

    test('init crea directorio de logs y apunta a folio.log', () async {
      final sink = await AppLogFileSink.init();

      await sink.write('linea-init');
      final logFile = File(
        '${mockedSupportDir.path}${Platform.pathSeparator}logs${Platform.pathSeparator}folio.log',
      );
      expect(await logFile.exists(), isTrue);
      expect(await logFile.readAsString(), 'linea-init\n');
    });

    test('write agrega linea al archivo de log', () async {
      final dir = await Directory.systemTemp.createTemp('folio_log_sink_');
      try {
        final logFile = File('${dir.path}${Platform.pathSeparator}folio.log');
        final sink = AppLogFileSink.forFile(logFile);

        await sink.write('linea-1');
        await sink.write('linea-2');

        final text = await logFile.readAsString();
        expect(text, 'linea-1\nlinea-2\n');
      } finally {
        await dir.delete(recursive: true);
      }
    });

    test('rota archivos cuando folio.log supera el maximo', () async {
      final dir = await Directory.systemTemp.createTemp('folio_log_sink_');
      try {
        final sep = Platform.pathSeparator;
        final logFile = File('${dir.path}${sep}folio.log');
        final rot1 = File('${dir.path}${sep}folio.1.log');
        final rot2 = File('${dir.path}${sep}folio.2.log');

        await rot1.writeAsString('old-1');
        await rot2.writeAsString('old-2');
        await logFile.writeAsBytes(List<int>.filled(1024 * 1024, 65));

        final sink = AppLogFileSink.forFile(logFile);
        await sink.write('nueva-linea');

        expect(await File('${dir.path}${sep}folio.3.log').exists(), isTrue);
        expect(await rot2.readAsString(), 'old-1');
        expect(
          await File('${dir.path}${sep}folio.1.log').length(),
          1024 * 1024,
        );

        final current = await logFile.readAsString();
        expect(current, 'nueva-linea\n');
      } finally {
        await dir.delete(recursive: true);
      }
    });
  });
}
