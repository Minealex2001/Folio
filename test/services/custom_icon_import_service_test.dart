import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:folio/services/custom_icon_import_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory supportDir;

  setUp(() async {
    supportDir = await Directory.systemTemp.createTemp('folio_custom_icon_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (call) async {
          return supportDir.path;
        });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
    if (supportDir.existsSync()) {
      await supportDir.delete(recursive: true);
    }
  });

  test('imports remote GIF icons', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));

    server.listen((request) async {
      request.response.headers.contentType = ContentType('image', 'gif');
      request.response.add(<int>[
        0x47,
        0x49,
        0x46,
        0x38,
        0x39,
        0x61,
        0x01,
        0x00,
        0x01,
        0x00,
        0x80,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0xff,
        0xff,
        0xff,
        0x21,
        0xf9,
        0x04,
        0x01,
        0x00,
        0x00,
        0x00,
        0x00,
        0x2c,
        0x00,
        0x00,
        0x00,
        0x00,
        0x01,
        0x00,
        0x01,
        0x00,
        0x00,
        0x02,
        0x02,
        0x44,
        0x01,
        0x00,
        0x3b,
      ]);
      await request.response.close();
    });

    final service = CustomIconImportService();
    final entry = await HttpOverrides.runZoned(
      () => service.importFromSource(
        source: 'http://127.0.0.1:${server.port}/party.gif',
        label: 'Party',
      ),
      createHttpClient: (context) => HttpClient(context: context),
    );

    expect(entry.label, 'Party');
    expect(entry.mimeType, 'image/gif');
    expect(entry.filePath.endsWith('.gif'), isTrue);
    expect(File(entry.filePath).existsSync(), isTrue);
  });
}