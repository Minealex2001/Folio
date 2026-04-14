import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:folio/services/custom_icon_import_service.dart';
import 'package:folio/l10n/generated/app_localizations_en.dart';

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
    final service = CustomIconImportService();
    final entry = await service.importFromSource(
      l10n: AppLocalizationsEn(),
      source: 'https://example.invalid/party.gif',
      label: 'Party',
      fetchRemote: (uri) async => (
        statusCode: 200,
        contentType: 'image/gif',
        bytes: <int>[
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
        ],
      ),
    );

    expect(entry.label, 'Party');
    expect(entry.mimeType, 'image/gif');
    expect(entry.filePath.endsWith('.gif'), isTrue);
    expect(File(entry.filePath).existsSync(), isTrue);
  });
}