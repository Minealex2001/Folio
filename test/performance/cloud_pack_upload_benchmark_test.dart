// Fase de investigación de freezes (0.8.5) — mide el coste de la fase de
// PREPARACIÓN de `uploadOpenVaultCloudPack()` ANTES de la primera subida de
// blob, usando las funciones de PRODUCCIÓN reales, y compara:
//
//   PATH A "directo"  — todo en el isolate llamante (comportamiento < Paso 3):
//       vaultBinEquivalentBytes → computeVaultCloudPackContentFingerprintCore
//       → derivePlainPackKey → buildVaultPackSnapshotCore
//
//   PATH B "isolate"  — fingerprint y build vía `compute()` (Paso 3), igual
//       que producción: la serialización y la derivación de pack key se
//       quedan en el UI isolate; el trabajo CPU pesado (SHA-256 de todo,
//       gzip nivel 6 síncrono, AES-GCM, adjuntos) va al worker.
//
// Para cada escenario se reporta, por path:
//   wall   — reloj de pared de toda la preparación
//   UIblk  — tiempo que el isolate llamante estuvo BLOQUEADO (sonda Timer:
//            ticks perdidos × periodo). En PATH B debe tender a ~0.
//   RSSpk  — pico de RSS observado durante la preparación (MB)
//
// NO toca red. Ejecutar con la traza para ver además `folio.perf`:
//   flutter test --dart-define=FOLIO_PERF_TRACE=true \
//     test/performance/cloud_pack_upload_benchmark_test.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folio/data/vault_backup.dart';
import 'package:folio/data/vault_payload.dart';
import 'package:folio/data/vault_paths.dart';
import 'package:folio/models/block.dart';
import 'package:folio/models/folio_page.dart';
import 'package:folio/services/vault_pack/vault_pack_builder.dart';
import 'package:shared_preferences/shared_preferences.dart';

// --- Shims de nivel superior: equivalentes a los `_fingerprintPackInIsolate` /
//     `_buildPackInIsolate` privados de `folio_cloud_pack_sync.dart`. ---
Future<String> _fpShim(Map<String, Object?> m) =>
    computeVaultCloudPackContentFingerprintCore(
      vaultBinBytes: m['vaultBinBytes'] as Uint8List,
      wrappedDekPath: m['wrappedDekPath'] as String,
      vaultModePath: m['vaultModePath'] as String,
      vaultDirPath: m['vaultDirPath'] as String,
    );

Future<({List<VaultPackPreparedBlob> blobs, dynamic manifest})> _buildShim(
        Map<String, Object?> m) =>
    buildVaultPackSnapshotCore(
      vaultDirPath: m['vaultDirPath'] as String,
      wrappedDekPath: m['wrappedDekPath'] as String,
      vaultModePath: m['vaultModePath'] as String,
      keyMaterial: m['keyMaterial'] as Uint8List,
      isPlain: false,
      contentFingerprint: m['contentFingerprint'] as String,
      vaultBinBytes: m['vaultBinBytes'] as Uint8List,
    );

class _Probe {
  _Probe._(this.wallMs, this.maxGapMs, this.lostMs, this.peakRssMb);
  final double wallMs;

  /// El intervalo MÁS LARGO en que el event loop del isolate llamante no pudo
  /// atender un tick de 2ms — es decir, el "congelón" máximo que percibiría la
  /// UI. En PATH A ≈ toda la operación (un `await` que no cede). En PATH B debe
  /// quedar en el coste de la serialización + derivación de pack key, que se
  /// hacen antes de `compute()`.
  final double maxGapMs;

  /// Ticks perdidos × periodo (contención acumulada; incluye jitter del
  /// scheduler cuando el worker satura los núcleos, así que sobreestima).
  final double lostMs;
  final int peakRssMb;

  static const _periodMs = 2;

  static Future<_Probe> run(Future<void> Function() body) async {
    var ticks = 0;
    var maxGapUs = 0;
    var peakRss = ProcessInfo.currentRss;
    final gap = Stopwatch()..start();
    final t = Timer.periodic(const Duration(milliseconds: _periodMs), (_) {
      ticks++;
      final g = gap.elapsedMicroseconds;
      if (g > maxGapUs) maxGapUs = g;
      gap.reset();
      final r = ProcessInfo.currentRss;
      if (r > peakRss) peakRss = r;
    });
    final sw = Stopwatch()..start();
    await body();
    sw.stop();
    t.cancel();
    final wall = sw.elapsedMicroseconds / 1000.0;
    final ideal = wall / _periodMs;
    final lost = ((ideal - ticks) * _periodMs).clamp(0.0, wall);
    return _Probe._(
      wall,
      maxGapUs / 1000.0,
      lost.toDouble(),
      peakRss ~/ (1024 * 1024),
    );
  }
}

class _Agg {
  final List<_Probe> runs = [];
  double get wall => runs.map((r) => r.wallMs).reduce(min);
  double get maxGap => runs.map((r) => r.maxGapMs).reduce(min);
  double get lost => runs.map((r) => r.lostMs).reduce(min);
  int get rss => runs.map((r) => r.peakRssMb).reduce(max);
  @override
  String toString() => 'wall=${wall.toStringAsFixed(0)}ms  '
      'maxFreeze=${maxGap.toStringAsFixed(0)}ms  '
      'lost=${lost.toStringAsFixed(0)}ms  RSSpk=${rss}MB';
}

String _deltaJson(int page, int block) => jsonEncode([
      {'insert': 'Bloque $block de la página $page con nota sobre '},
      {
        'insert': 'arquitectura',
        'attributes': {'bold': true}
      },
      {'insert': ', migración a PostgreSQL y rendimiento del roadmap.\n'},
    ]);

VaultPayload _payload({required int pages, int blocksPerPage = 30}) {
  return VaultPayload(
    pages: List.generate(pages, (pi) {
      final id = 'perf_page_$pi';
      return FolioPage(
        id: id,
        title: 'Página de rendimiento $pi sobre PostgreSQL y Folio',
        blocks: List.generate(blocksPerPage, (bi) {
          final todo = bi % 7 == 0;
          return FolioBlock(
            id: '${id}_b$bi',
            type: todo ? 'todo' : 'paragraph',
            text: 'Bloque $bi de la página $pi con una nota sobre arquitectura, '
                'migración a PostgreSQL y rendimiento. Pendiente revisar el '
                'roadmap del equipo de Folio.',
            richTextDeltaJson: todo ? null : _deltaJson(pi, bi),
            checked: todo ? false : null,
          );
        }),
      );
    }),
  );
}

/// Bytes semi-comprimibles (texto repetido + ruido) para simular imagen/audio
/// real: ni todo-cero (gzip lo aplasta) ni aleatorio puro.
Uint8List _fakeMedia(int bytes, int seed) {
  final r = Random(seed);
  final out = Uint8List(bytes);
  const chunk = 'RIFF....WEBP/JPEG payload chunk with some entropy ';
  for (var i = 0; i < bytes; i++) {
    out[i] = i % 64 == 0
        ? r.nextInt(256)
        : chunk.codeUnitAt(i % chunk.length) ^ (r.nextInt(8));
  }
  return out;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory supportDir;
  const vaultId = 'cloudpack-perf-vault';

  final results = <String>[];

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    supportDir = Directory.systemTemp.createTempSync('folio_cloudpack_perf_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      pathProviderChannel,
      (_) async => supportDir.path,
    );
    VaultPaths.setActiveVaultId(vaultId);
    await VaultPaths.initVaultStorage(vaultId);
    // Libreta en claro: reproduce el peor caso de gzip (JSON sin cifrar es muy
    // comprimible → nivel 6 trabaja más) y es el camino con 2ª serialización
    // que el Paso 3 elimina.
    final vdir = await VaultPaths.vaultDirectory();
    File('${vdir.path}/${VaultPaths.vaultModeFile}').writeAsStringSync('plain');
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
    VaultPaths.clearActiveVaultId();
    try {
      supportDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  tearDownAll(() {
    // ignore: avoid_print
    print('\n===== CLOUD PACK — preparación: PATH A directo vs PATH B isolate '
        '=====');
    for (final l in results) {
      // ignore: avoid_print
      print(l);
    }
    // ignore: avoid_print
    print('  (mejor de 2-3 iter + 1 warm-up; máquina de dev)\n'
        '  maxFreeze = congelón máximo del event loop llamante (métrica UX)\n'
        '  lost      = contención acumulada; sobreestima bajo saturación de '
        'núcleos por el worker\n');
  });

  Future<void> writeAttachments(List<(int, int)> sizes) async {
    final vdir = await VaultPaths.vaultDirectory();
    final adir = Directory('${vdir.path}/${VaultPaths.attachmentsDirName}')
      ..createSync(recursive: true);
    for (var i = 0; i < sizes.length; i++) {
      File('${adir.path}/att_$i.bin')
          .writeAsBytesSync(_fakeMedia(sizes[i].$1, sizes[i].$2));
    }
  }

  // Escenarios pedidos: (1) 250p/0 adj; (2) 250p + ~1.5MB img; (3) +8MB WAV;
  // (4) libreta representativa ~150p + ~10 img + 2 WAV ~25MB + relleno ~55MB.
  const kb = 1024;
  const mb = 1024 * 1024;
  final scenarios =
      <({String label, int pages, List<(int, int)> att, int iters})>[
    (label: '1) 250p · 0 adjuntos', pages: 250, att: const [], iters: 3),
    (
      label: '2) 250p · ~1.5MB img (6×256KB)',
      pages: 250,
      att: List.generate(6, (i) => (256 * kb, i)),
      iters: 3,
    ),
    (
      label: '3) 250p · ~1.5MB img + 8MB WAV',
      pages: 250,
      att: [...List.generate(6, (i) => (256 * kb, i)), (8 * mb, 90)],
      iters: 3,
    ),
    (
      label: '4) ~150p · 10 img + 2 WAV(25MB) + relleno (~56MB total)',
      pages: 150,
      att: [
        ...List.generate(10, (i) => (150 * kb, i)), // ~1.5MB imágenes
        (12 * mb + 512 * kb, 80), (12 * mb + 512 * kb, 81), // ~25MB WAV
        (10 * mb, 82), (10 * mb, 83), (9 * mb, 84), // ~29MB relleno
      ],
      iters: 2,
    ),
  ];

  for (final s in scenarios) {
    test('prepare · ${s.label}', () async {
      if (s.att.isNotEmpty) await writeAttachments(s.att);
      final payload = _payload(pages: s.pages);
      final vdirPath = (await VaultPaths.vaultDirectory()).path;
      final wrappedDekPath = (await VaultPaths.wrappedDekPath()).path;
      final vaultModePath = (await VaultPaths.vaultModePath()).path;

      // PATH A — todo en el isolate llamante.
      Future<void> pathDirect() async {
        final vbin = Uint8List.fromList(payload.encodeUtf8());
        final fp = await computeVaultCloudPackContentFingerprintCore(
          vaultBinBytes: vbin,
          wrappedDekPath: wrappedDekPath,
          vaultModePath: vaultModePath,
          vaultDirPath: vdirPath,
        );
        final keyBytes = Uint8List.fromList(
            await (await derivePlainPackKey(vbin)).extractBytes());
        await buildVaultPackSnapshotCore(
          vaultDirPath: vdirPath,
          wrappedDekPath: wrappedDekPath,
          vaultModePath: vaultModePath,
          keyMaterial: keyBytes,
          isPlain: false,
          contentFingerprint: fp,
          vaultBinBytes: vbin,
        );
      }

      // PATH B — igual que producción: serialización + derivación de pack key
      // en el isolate llamante; fingerprint y build vía compute().
      Future<void> pathIsolate() async {
        final vbin = Uint8List.fromList(payload.encodeUtf8());
        final fp = await compute(_fpShim, <String, Object?>{
          'vaultBinBytes': vbin,
          'wrappedDekPath': wrappedDekPath,
          'vaultModePath': vaultModePath,
          'vaultDirPath': vdirPath,
        });
        final keyBytes = Uint8List.fromList(
            await (await derivePlainPackKey(vbin)).extractBytes());
        await compute(_buildShim, <String, Object?>{
          'vaultBinBytes': vbin,
          'contentFingerprint': fp,
          'keyMaterial': keyBytes,
          'vaultDirPath': vdirPath,
          'wrappedDekPath': wrappedDekPath,
          'vaultModePath': vaultModePath,
        });
      }

      Future<_Agg> bench(Future<void> Function() body) async {
        await body(); // warm-up descartado
        final agg = _Agg();
        for (var i = 0; i < s.iters; i++) {
          agg.runs.add(await _Probe.run(body));
        }
        return agg;
      }

      final a = await bench(pathDirect);
      final b = await bench(pathIsolate);

      final vbinKb =
          (Uint8List.fromList(payload.encodeUtf8()).length / 1024).round();
      results.add(
        '${s.label}   (vaultBin ~$vbinKb KB)\n'
        '    PATH A directo  : $a\n'
        '    PATH B isolate  : $b',
      );
      // El punto del Paso 3: el congelón máximo del isolate llamante deja de
      // escalar con el trabajo CPU. Debe bajar mucho respecto a PATH A.
      expect(b.maxGap, lessThan(a.maxGap),
          reason: 'PATH B debería tener un congelón máximo menor que A');
    }, timeout: const Timeout(Duration(minutes: 6)));
  }
}
