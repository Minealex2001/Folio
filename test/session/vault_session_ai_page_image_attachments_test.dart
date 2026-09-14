// Fase 7 de Quill 2.0 — imágenes de página en el contexto de Quill.
//
// `buildAiAttachmentsForPageImages` adjunta como `AiFileAttachment`s las
// imágenes ya presentes en las páginas de contexto (las mismas que ya
// aportan texto vía `QuillContextEngine`), para que Quill "vea" imágenes que
// ya están en una página de Folio, no solo las adjuntadas a mano en el chat.
//
// Reutiliza el arnés de vault real ya establecido para tests que necesitan
// leer/escribir adjuntos gestionados (`VaultPaths.readAttachmentBytes`),
// mismo patrón que `vault_session_incremental_persist_test.dart`.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folio/data/vault_paths.dart';
import 'package:folio/models/block.dart';
import 'package:folio/session/vault_session.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory supportDir;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    supportDir = await Directory.systemTemp.createTemp('folio_page_images_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (_) async {
          return supportDir.path;
        });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
    VaultPaths.clearActiveVaultId();
    try {
      if (supportDir.existsSync()) await supportDir.delete(recursive: true);
    } catch (_) {}
  });

  Future<VaultSession> newUnlockedSession(String vaultId) async {
    VaultPaths.setActiveVaultId(vaultId);
    await VaultPaths.initVaultStorage(vaultId);
    final s = VaultSession();
    s.debugMarkUnlockedForTests(formatVersion: 1);
    return s;
  }

  /// Crea una página con un bloque `image` cuyo `text` apunta a un
  /// adjunto local gestionado real, con [bytes] de contenido. Devuelve el id
  /// de la página.
  Future<String> addPageWithImage(VaultSession s, List<int> bytes, {String ext = '.png'}) async {
    final relPath = await VaultPaths.importAttachmentBytes(
      Uint8List.fromList(bytes),
      ext,
    );
    s.addPage(parentId: null);
    final page = s.pages.last;
    s.appendBlock(
      pageId: page.id,
      block: FolioBlock(id: '${page.id}_img', type: 'image', text: relPath),
    );
    return page.id;
  }

  test('incluye una imagen local gestionada de una página de contexto', () async {
    final s = await newUnlockedSession('vault-a');
    final pageId = await addPageWithImage(s, [1, 2, 3, 4]);

    final out = await s.buildAiAttachmentsForPageImages([pageId]);

    expect(out, hasLength(1));
    expect(out.single.mimeType, 'image/png');
    expect(base64Decode(out.single.content), [1, 2, 3, 4]);
  });

  test('excluye imágenes remotas (http/https)', () async {
    final s = await newUnlockedSession('vault-a');
    s.addPage(parentId: null);
    final page = s.pages.last;
    s.appendBlock(
      pageId: page.id,
      block: FolioBlock(id: '${page.id}_img', type: 'image', text: 'https://example.com/a.png'),
    );

    final out = await s.buildAiAttachmentsForPageImages([page.id]);

    expect(out, isEmpty);
  });

  test('excluye referencias que no son adjuntos gestionados del vault', () async {
    final s = await newUnlockedSession('vault-a');
    s.addPage(parentId: null);
    final page = s.pages.last;
    s.appendBlock(
      pageId: page.id,
      block: FolioBlock(id: '${page.id}_img', type: 'image', text: 'collab://media/abc123'),
    );

    final out = await s.buildAiAttachmentsForPageImages([page.id]);

    expect(out, isEmpty);
  });

  test(
    'límite global de cantidad: 5 páginas con varias imágenes cada una nunca superan el máximo total, '
    'nunca N por página',
    () async {
      final s = await newUnlockedSession('vault-a');
      final pageIds = <String>[];
      for (var p = 0; p < 5; p++) {
        // 2 imágenes por página → 10 en total, muy por encima del límite global.
        final relA = await VaultPaths.importAttachmentBytes(Uint8List.fromList([p, 0]), '.png');
        final relB = await VaultPaths.importAttachmentBytes(Uint8List.fromList([p, 1]), '.png');
        s.addPage(parentId: null);
        final page = s.pages.last;
        s.appendBlock(pageId: page.id, block: FolioBlock(id: '${page.id}_imgA', type: 'image', text: relA));
        s.appendBlock(pageId: page.id, block: FolioBlock(id: '${page.id}_imgB', type: 'image', text: relB));
        pageIds.add(page.id);
      }

      final out = await s.buildAiAttachmentsForPageImages(pageIds);

      // El límite global documentado es 4 — nunca 4 por página (que daría 20).
      expect(out.length, lessThanOrEqualTo(4));
      expect(out.length, lessThan(pageIds.length * 2));
    },
  );

  test(
    'límite global de bytes: una imagen que por sí sola excede el tope restante se omite '
    'sin romper el resto del envío',
    () async {
      final s = await newUnlockedSession('vault-a');
      // Imagen pequeña, cabe de sobra.
      final small = await VaultPaths.importAttachmentBytes(Uint8List.fromList(List.filled(100, 1)), '.png');
      // Imagen mayor que el tope global (~8MB) — debe omitirse sin excepción.
      final huge = await VaultPaths.importAttachmentBytes(
        Uint8List.fromList(List.filled(9 * 1024 * 1024, 2)),
        '.png',
      );
      // Otra pequeña después de la enorme — debe seguir incluyéndose.
      final smallAfter = await VaultPaths.importAttachmentBytes(Uint8List.fromList(List.filled(100, 3)), '.png');

      s.addPage(parentId: null);
      final page = s.pages.last;
      s.appendBlock(pageId: page.id, block: FolioBlock(id: 'b1', type: 'image', text: small));
      s.appendBlock(pageId: page.id, block: FolioBlock(id: 'b2', type: 'image', text: huge));
      s.appendBlock(pageId: page.id, block: FolioBlock(id: 'b3', type: 'image', text: smallAfter));

      final out = await s.buildAiAttachmentsForPageImages([page.id]);

      expect(out, hasLength(2));
      expect(out.map((a) => base64Decode(a.content).length), [100, 100]);
    },
  );

  test('páginas sin bloques de imagen no aportan adjuntos', () async {
    final s = await newUnlockedSession('vault-a');
    s.addPage(parentId: null);
    final page = s.pages.last;
    s.updateBlockText(page.id, page.blocks.first.id, 'solo texto');

    final out = await s.buildAiAttachmentsForPageImages([page.id]);

    expect(out, isEmpty);
  });
}
