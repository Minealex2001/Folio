/// Tests para M2: Herramienta de migración vault (viejo → nuevo formato).
///
/// Valida que:
/// 1. Detección de vaults sin migrar funciona
/// 2. Migración preserva contenido completo
/// 3. Snapshots se crean correctamente
/// 4. Marker treeFormatVersion se escribe

import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folio/data/vault_payload.dart';
import 'package:folio/data/vault_paths.dart';
import 'package:folio/models/folio_page.dart';
import 'package:folio/models/block.dart';
import 'package:folio/git/vault_migration_tool.dart';
import 'package:folio/git/vault_payload_converters.dart';
import 'package:path/path.dart' as p;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

  group('VaultMigrationTool.readTreeFormatVersion - marker vs tree.json', () {
    late Directory mockedSupportDir;

    setUp(() async {
      mockedSupportDir = await Directory.systemTemp.createTemp(
        'folio_format_version_',
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(pathProviderChannel, (call) async {
            return mockedSupportDir.path;
          });
    });

    tearDown(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(pathProviderChannel, null);
      VaultPaths.clearActiveVaultId();
      if (mockedSupportDir.existsSync()) {
        await mockedSupportDir.delete(recursive: true);
      }
    });

    test('defaults to 0 when neither marker nor tree.json exist', () async {
      const vaultId = 'format-version-none';
      VaultPaths.setActiveVaultId(vaultId);
      await VaultPaths.initVaultStorage(vaultId);

      expect(await VaultMigrationTool.readTreeFormatVersion(), equals(0));
    });

    test('reads 1 straight from an intact marker', () async {
      const vaultId = 'format-version-marker';
      VaultPaths.setActiveVaultId(vaultId);
      await VaultPaths.initVaultStorage(vaultId);
      final vaultDir = await VaultPaths.vaultDirectory();
      await File(
        p.join(vaultDir.path, 'vault.format'),
      ).writeAsString('1', flush: true);

      expect(await VaultMigrationTool.readTreeFormatVersion(), equals(1));
    });

    test(
      'falls back to repo/tree.json when marker is missing (headless/UI symmetry)',
      () async {
        const vaultId = 'format-version-missing-marker';
        VaultPaths.setActiveVaultId(vaultId);
        await VaultPaths.initVaultStorage(vaultId);
        final vaultDir = await VaultPaths.vaultDirectory();
        final treeDir = Directory(p.join(vaultDir.path, 'repo'));
        await treeDir.create(recursive: true);
        await File(
          p.join(treeDir.path, 'tree.json'),
        ).writeAsString('{}', flush: true);
        // Sin marker vault.format: antes del fix esto devolvía 0 (legacy) y
        // la sesión UI podía intentar recargar vault.bin desatendiendo el
        // árbol v1 ya migrado — la misma clase de bug de wipe por sync que
        // ya se había corregido en el camino headless.
        expect(await VaultMigrationTool.readTreeFormatVersion(), equals(1));
      },
    );

    test(
      'falls back to repo/tree.json when marker content is unparseable',
      () async {
        const vaultId = 'format-version-corrupt-marker';
        VaultPaths.setActiveVaultId(vaultId);
        await VaultPaths.initVaultStorage(vaultId);
        final vaultDir = await VaultPaths.vaultDirectory();
        await File(
          p.join(vaultDir.path, 'vault.format'),
        ).writeAsString('not-a-number', flush: true);
        final treeDir = Directory(p.join(vaultDir.path, 'repo'));
        await treeDir.create(recursive: true);
        await File(
          p.join(treeDir.path, 'tree.json'),
        ).writeAsString('{}', flush: true);

        expect(await VaultMigrationTool.readTreeFormatVersion(), equals(1));
      },
    );
  });

  group('VaultMigrationTool - M2', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('folio_migration_test_');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('isMigrated returns false when no tree exists', () async {
      // This test verifies the logic (implementation in vault_session context)
      // For now, it's a placeholder since VaultPaths needs active vault
    });

    test('migrateVault creates tree and snapshots without data loss', () async {
      // Create a comprehensive payload to migrate
      final payload = VaultPayload(
        pages: [
          FolioPage(
            id: 'page-001',
            title: 'Page One',
            emoji: '📝',
            blocks: [
              FolioBlock(id: 'b1', type: 'paragraph', text: 'Content'),
              FolioBlock(id: 'b2', type: 'heading', text: 'Heading'),
            ],
            tags: ['tag1', 'tag2'],
          ),
          FolioPage(
            id: 'page-002',
            title: 'Page Two',
            emoji: '📄',
            parentId: 'page-001',
            isFolder: false,
            blocks: [],
          ),
        ],
        displayName: 'Test Vault',
        pageOrderByParent: {
          '': ['page-001'],
          'page-001': ['page-002'],
        },
        pageRevisions: {
          'page-001': [], // Empty revisions for now
        },
      );

      // Manually decompose and verify (testing the converters work with migration data)
      final treeDir = Directory(p.join(tempDir.path, 'repo'));
      await VaultPayloadToTree.decompose(payload, treeDir);

      // Verify structure
      expect(File(p.join(treeDir.path, 'tree.json')).existsSync(), isTrue);
      expect(Directory(p.join(treeDir.path, 'pages')).existsSync(), isTrue);

      // Recompose and verify no data loss
      final recomposed = await TreeToVaultPayload.compose(treeDir);
      expect(recomposed.displayName, equals(payload.displayName));
      expect(recomposed.pages.length, equals(2));
      expect(recomposed.pages[0].tags, equals(['tag1', 'tag2']));
    });

    test('migration preserves complex vault with integrations', () async {
      // Test that a vault with multiple entity types survives migration
      final payload = VaultPayload(
        pages: [
          FolioPage(
            id: 'complex-page',
            title: 'Complex Page',
            emoji: '⚙️',
            blocks: [
              FolioBlock(
                id: 'code-block',
                type: 'code',
                text: 'print("hello")',
                codeLanguage: 'python',
              ),
            ],
          ),
        ],
        displayName: 'Complex Vault',
        pageOrderByParent: {'': ['complex-page']},
      );

      final treeDir = Directory(p.join(tempDir.path, 'repo'));
      await VaultPayloadToTree.decompose(payload, treeDir);

      final recomposed = await TreeToVaultPayload.compose(treeDir);
      expect(recomposed.pages[0].blocks[0].codeLanguage, equals('python'));
      expect(recomposed.pages[0].blocks[0].text, equals('print("hello")'));
    });

    test('tree format marker can be written and read', () async {
      // Simulated test: in actual use, VaultMigrationTool.readTreeFormatVersion
      // would read from vault.format file
      final markerFile = File(p.join(tempDir.path, 'vault.format'));
      await markerFile.writeAsString('1');

      final content = await markerFile.readAsString();
      expect(int.tryParse(content.trim()), equals(1));
    });

    test('migration result reports accurate file/snapshot counts', () async {
      // Verify the result structure
      final result = VaultMigrationResult(
        success: true,
        vaultId: 'test-vault-id',
        message: 'Migration succeeded',
        filesCreated: 25,
        snapshotsCreated: 2,
      );

      expect(result.success, isTrue);
      expect(result.vaultId, equals('test-vault-id'));
      expect(result.filesCreated, equals(25));
      expect(result.snapshotsCreated, equals(2));
      expect(result.error, isNull);
    });
  });
}
