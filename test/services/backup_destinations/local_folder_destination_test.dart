import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:folio/services/backup_destinations/backup_destination.dart';
import 'package:folio/services/backup_destinations/local_folder_destination.dart';

void main() {
  group('LocalFolderDestination', () {
    late Directory tempDir;
    late LocalFolderDestination destination;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('folio_folder_backup_');
      destination = LocalFolderDestination(directoryPath: tempDir.path);
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('ping escribe y borra archivo de prueba', () async {
      await destination.ping();
      expect(
        File('${tempDir.path}/.folio-write-test').existsSync(),
        isFalse,
      );
    });

    test('upload y listZipBackups', () async {
      final zip = File('${tempDir.path}/source.zip');
      await zip.writeAsBytes([1, 2, 3]);
      await destination.uploadZip(zip, 'folio-scheduled-test.zip');
      final listed = await destination.listZipBackups();
      expect(listed.map((e) => e.name), contains('folio-scheduled-test.zip'));
    });

    test('pruneOld conserva solo N copias', () async {
      for (var i = 0; i < 3; i++) {
        final f = File('${tempDir.path}/folio-scheduled-$i.zip');
        await f.writeAsBytes([i]);
      }
      await destination.pruneOld(2);
      final listed = await destination.listZipBackups();
      expect(listed.length, 2);
    });
  });
}
