// Fase 3 (optimización S1): persistencia incremental v1.
//
// Cuando el único cambio pendiente es contenido de bloques de páginas que YA
// existen en disco, `_doPersistV1` escribe solo esas páginas con
// `storePageAt` en vez de reescribir todo el árbol `repo/`. Estos tests
// demuestran que eso NO rompe ninguna garantía existente:
//
//  1. editar una página → guardar → recargar → contenido correcto
//  2. editar varias páginas antes del save → todas persisten
//  3. editar → undo → guardar → estado correcto
//  4. editar → redo → guardar → estado correcto
//  5. editar → "reabrir" (sesión nueva desde disco) → contenido correcto
//  6. contenido + operación estructural antes del save → ruta COMPLETA
//  7. crear / eliminar página → ruta COMPLETA, sin carpetas stale
//  8. borrar un bloque por la ruta incremental → sin líneas stale en blocks.jsonl
//  9. incremental deja el árbol byte-idéntico a un guardado completo
//     (⇒ snapshots / diffs / historial / recovery ven lo mismo)
// 10. el árbol nunca queda parcial: tree.json + vault/ + todas las páginas
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folio/data/vault_local_storage.dart';
import 'package:folio/data/vault_paths.dart';
import 'package:folio/session/vault_session.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory supportDir;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    supportDir = await Directory.systemTemp.createTemp('folio_inc_persist_');
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

  /// Añade una página con un párrafo de texto [text]; devuelve su id.
  String addPageWithText(VaultSession s, String text) {
    s.addPage(parentId: null);
    final page = s.pages.last;
    s.updateBlockText(page.id, page.blocks.first.id, text);
    return page.id;
  }

  String firstBlockId(VaultSession s, String pageId) =>
      s.pages.firstWhere((p) => p.id == pageId).blocks.first.id;

  test('1 · editar una página → guardar → recargar → contenido correcto', () async {
    final s = await newUnlockedSession('inc-1');
    final a = addPageWithText(s, 'A original');
    final b = addPageWithText(s, 'B original');
    await s.persistNow(); // completo (recién creadas)
    expect(s.debugFullPersistV1Count, 1);
    expect(s.debugIncrementalPersistV1Count, 0);

    s.updateBlockText(b, firstBlockId(s, b), 'B editado');
    await s.persistNow();
    expect(s.debugIncrementalPersistV1Count, 1, reason: 'debe ir incremental');
    expect(s.debugFullPersistV1Count, 1, reason: 'sin nuevo guardado completo');

    final loaded = await VaultLocalStorage.loadFromTreeAt(
      await VaultPaths.vaultDirectory(),
    );
    expect(loaded!.pages.firstWhere((p) => p.id == a).blocks.first.text,
        'A original');
    expect(loaded.pages.firstWhere((p) => p.id == b).blocks.first.text,
        'B editado');
  });

  test('2 · editar varias páginas antes del save → todas persisten', () async {
    final s = await newUnlockedSession('inc-2');
    final ids = [
      addPageWithText(s, 'p0'),
      addPageWithText(s, 'p1'),
      addPageWithText(s, 'p2'),
      addPageWithText(s, 'p3'),
    ];
    await s.persistNow();

    for (var i = 0; i < ids.length; i++) {
      s.updateBlockText(ids[i], firstBlockId(s, ids[i]), 'p$i editado');
    }
    await s.persistNow();
    expect(s.debugIncrementalPersistV1Count, 1);

    final loaded = await VaultLocalStorage.loadFromTreeAt(
      await VaultPaths.vaultDirectory(),
    );
    for (var i = 0; i < ids.length; i++) {
      expect(loaded!.pages.firstWhere((p) => p.id == ids[i]).blocks.first.text,
          'p$i editado');
    }
  });

  test('3 · editar → undo → guardar → ruta completa + disco == sesión', () async {
    final s = await newUnlockedSession('inc-3');
    final a = addPageWithText(s, 'v1');
    await s.persistNow();
    s.updateBlockText(a, firstBlockId(s, a), 'v2');
    await s.persistNow(); // incremental, disco = 'v2'
    final fullBefore = s.debugFullPersistV1Count;

    s.undoPageEdits(pageId: a);
    final undone = s.pages.first.blocks.first.text; // lo que decida el undo
    await s.persistNow();

    expect(s.debugFullPersistV1Count, fullBefore + 1,
        reason: 'undo → scheduleSave sin contentOnly → guardado completo');
    final loaded = await VaultLocalStorage.loadFromTreeAt(
      await VaultPaths.vaultDirectory(),
    );
    expect(loaded!.pages.first.blocks.first.text, undone);
  });

  test('4 · editar → redo → guardar → ruta completa + disco == sesión', () async {
    final s = await newUnlockedSession('inc-4');
    final a = addPageWithText(s, 'v1');
    await s.persistNow();
    s.updateBlockText(a, firstBlockId(s, a), 'v2');
    s.undoPageEdits(pageId: a);
    s.redoPageEdits(pageId: a);
    final redone = s.pages.first.blocks.first.text;
    final fullBefore = s.debugFullPersistV1Count;
    await s.persistNow();

    expect(s.debugFullPersistV1Count, fullBefore + 1);
    final loaded = await VaultLocalStorage.loadFromTreeAt(
      await VaultPaths.vaultDirectory(),
    );
    expect(loaded!.pages.first.blocks.first.text, redone);
  });

  test('5 · editar → sesión nueva desde disco → contenido correcto', () async {
    final s1 = await newUnlockedSession('inc-5');
    final a = addPageWithText(s1, 'antes');
    await s1.persistNow();
    s1.updateBlockText(a, firstBlockId(s1, a), 'después de reabrir');
    await s1.persistNow();

    // "Reabrir": cargar el árbol directamente (lo que hace unlock).
    final loaded = await VaultLocalStorage.loadFromTreeAt(
      await VaultPaths.vaultDirectory(),
    );
    expect(loaded!.pages, hasLength(1));
    expect(loaded.pages.first.blocks.first.text, 'después de reabrir');
  });

  test('6 · contenido + operación estructural antes del save → ruta completa',
      () async {
    final s = await newUnlockedSession('inc-6');
    final a = addPageWithText(s, 'a');
    await s.persistNow();
    final fullBefore = s.debugFullPersistV1Count;

    s.updateBlockText(a, firstBlockId(s, a), 'a editado');
    s.addPage(parentId: null); // operación estructural en el mismo turno
    final b = s.pages.last.id;
    await s.persistNow();

    expect(s.debugIncrementalPersistV1Count, 0, reason: 'nunca incremental');
    expect(s.debugFullPersistV1Count, fullBefore + 1);

    final loaded = await VaultLocalStorage.loadFromTreeAt(
      await VaultPaths.vaultDirectory(),
    );
    expect(loaded!.pages.map((p) => p.id), containsAll(<String>[a, b]));
    expect(loaded.pages.firstWhere((p) => p.id == a).blocks.first.text,
        'a editado');
  });

  test('7 · eliminar página → ruta completa, sin carpetas stale', () async {
    final s = await newUnlockedSession('inc-7');
    final a = addPageWithText(s, 'sobrevive');
    final b = addPageWithText(s, 'se borra');
    await s.persistNow();

    // sanity: guardado incremental disponible ahora
    s.updateBlockText(a, firstBlockId(s, a), 'sobrevive v2');
    await s.persistNow();
    expect(s.debugIncrementalPersistV1Count, 1);

    s.deletePage(b);
    await s.persistNow();
    expect(s.debugFullPersistV1Count, 2, reason: 'borrar página → completo');

    final treeDir = await VaultPaths.vaultTreeDirectory();
    final onDisk = VaultLocalStorage.listPageIdsOnDisk(treeDir);
    expect(onDisk, {a});
    final loaded = await VaultLocalStorage.loadFromTreeAt(
      await VaultPaths.vaultDirectory(),
    );
    expect(loaded!.pages, hasLength(1));
    expect(loaded.pages.first.id, a);
  });

  test('8 · incremental reescribe blocks.jsonl entero (sin contenido stale)',
      () async {
    final s = await newUnlockedSession('inc-8');
    final a = addPageWithText(s, 'TEXTO_LARGO_ORIGINAL_AAAAAAAAAAAAAAAAAAAA');
    await s.persistNow();

    s.updateBlockText(a, firstBlockId(s, a), 'x');
    await s.persistNow();
    expect(s.debugIncrementalPersistV1Count, 1);

    final blocksFile = File(
      '${(await VaultPaths.vaultTreeDirectory()).path}/pages/'
      '${a.substring(0, 2)}/$a/blocks.jsonl',
    );
    final raw = await blocksFile.readAsString();
    final lines = const LineSplitter()
        .convert(raw)
        .where((l) => l.trim().isNotEmpty)
        .toList();
    expect(lines, hasLength(1));
    expect(raw.contains('"x"'), isTrue);
    expect(raw.contains('TEXTO_LARGO_ORIGINAL'), isFalse,
        reason: 'no debe quedar rastro del contenido anterior');
  });

  test('9 · incremental deja el árbol byte-idéntico a un guardado completo',
      () async {
    Future<Map<String, String>> readTree(Directory treeDir) async {
      final out = <String, String>{};
      await for (final e in treeDir.list(recursive: true)) {
        if (e is File) {
          out[e.path.substring(treeDir.path.length)] = await e.readAsString();
        }
      }
      return out;
    }

    final s = await newUnlockedSession('inc-9');
    final a = addPageWithText(s, 'a');
    final b = addPageWithText(s, 'b');
    await s.persistNow(); // completo
    s.updateBlockText(a, firstBlockId(s, a), 'a final');
    await s.persistNow(); // incremental (solo A)
    s.updateBlockText(b, firstBlockId(s, b), 'b final');
    await s.persistNow(); // incremental (solo B)
    expect(s.debugIncrementalPersistV1Count, 2);
    final treeIncremental = await readTree(await VaultPaths.vaultTreeDirectory());

    // Ahora fuerza un guardado COMPLETO del MISMO estado en memoria.
    s.debugForceFullPersistNext();
    await s.persistNow();
    expect(s.debugFullPersistV1Count, 2);
    final treeFull = await readTree(await VaultPaths.vaultTreeDirectory());

    // El árbol tras 2 escrituras incrementales == el árbol reescrito entero:
    // mismos ficheros, mismos bytes ⇒ snapshots / diffs / historial / recovery
    // (que hashean estos ficheros) ven exactamente lo mismo.
    expect(treeIncremental.keys.toSet(), treeFull.keys.toSet());
    for (final k in treeFull.keys) {
      expect(treeIncremental[k], treeFull[k], reason: 'difiere $k');
    }
  });

  test('10 · el árbol nunca queda parcial tras un guardado incremental',
      () async {
    final s = await newUnlockedSession('inc-10');
    final a = addPageWithText(s, 'a');
    addPageWithText(s, 'b');
    await s.persistNow();
    s.updateBlockText(a, firstBlockId(s, a), 'a v2');
    await s.persistNow();
    expect(s.debugIncrementalPersistV1Count, 1);

    final treeDir = await VaultPaths.vaultTreeDirectory();
    expect(File('${treeDir.path}/tree.json').existsSync(), isTrue);
    expect(File('${treeDir.path}/vault/meta.json').existsSync(), isTrue);
    expect(VaultLocalStorage.listPageIdsOnDisk(treeDir).length, 2);
    // Recarga con la barrera anti-corrupción (rechaza árbol vacío espurio).
    final loaded = await VaultLocalStorage.loadFromTreeAt(
      await VaultPaths.vaultDirectory(),
    );
    expect(loaded, isNotNull);
    expect(loaded!.pages, hasLength(2));
  });
}
