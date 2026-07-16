import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:folio/data/storage/atomic_file_writer.dart';
import 'package:folio/data/vault_payload.dart';
import 'package:folio/domain/vault/vault_migration.dart';
import 'package:folio/models/folio_page.dart';
import 'package:folio/models/block.dart';

void main() {
  group('AtomicFileWriter', () {
    late Directory tempDir;
    late File target;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('folio_atomic_test_');
      target = File('${tempDir.path}/vault.bin');
      await target.writeAsBytes(Uint8List.fromList([1, 2, 3]));
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('keeps original file if tmp is not renamed', () async {
      final original = await target.readAsBytes();
      final tmp = File('${target.path}.tmp.stale');
      await tmp.writeAsBytes(Uint8List.fromList([9, 9, 9]));
      expect(await target.readAsBytes(), original);
    });

    test('writeAtomic rotates backup and replaces target', () async {
      await AtomicFileWriter.writeAtomic(
        target,
        Uint8List.fromList([4, 5, 6]),
      );
      expect(await target.readAsBytes(), Uint8List.fromList([4, 5, 6]));
      final bak = File(AtomicFileWriter.backupPathFor(target.path));
      expect(bak.existsSync(), isTrue);
      expect(await bak.readAsBytes(), Uint8List.fromList([1, 2, 3]));
    });

    test('restoreFromBackup recovers previous bytes', () async {
      await AtomicFileWriter.writeAtomic(
        target,
        Uint8List.fromList([7, 8]),
      );
      final restored = await AtomicFileWriter.restoreFromBackup(target);
      expect(restored, isTrue);
      expect(await target.readAsBytes(), Uint8List.fromList([1, 2, 3]));
    });
  });

  group('migrateVaultPayload', () {
    test('bumps legacy version to current', () {
      final legacy = VaultPayload(
        version: 3,
        pages: [
          FolioPage(
            id: 'p1',
            title: 'Hola',
            blocks: [
              FolioBlock(id: 'b1', type: 'paragraph', text: 'texto'),
            ],
          ),
        ],
      );
      final migrated = migrateVaultPayload(legacy);
      expect(migrated.version, kVaultPayloadVersion);
      expect(migrated.pages.length, 1);
    });
  });
}
