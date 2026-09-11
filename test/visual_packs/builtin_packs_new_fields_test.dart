import 'package:flutter_test/flutter_test.dart';
import 'package:folio/visual_packs/builtin/builtin_visual_packs.dart';
import 'package:folio/visual_packs/visual_pack.dart';

/// Fase 32: cada campo nuevo introducido desde la Fase 12 vive dentro de
/// `ThemeConfig`/`LayoutConfig`/`DashboardConfig` como campo aditivo
/// nullable, así que `VisualPack.toJson()`/`fromJson()` no necesitan
/// ningún cambio estructural — este test prueba justamente eso (round-trip
/// sin pérdida) para los packs que ya ejercitan contenido real de la Fase
/// 12-23 (`glass`, `macos`), no solo el esquema.
void main() {
  test('every builtin pack round-trips through toJson/fromJson without loss', () {
    for (final pack in builtinVisualPacks()) {
      final decoded = VisualPack.fromJson(pack.toJson());
      expect(decoded.manifest.id, pack.manifest.id, reason: pack.manifest.id);
      expect(decoded.theme.id, pack.theme.id, reason: pack.manifest.id);
      expect(decoded.layout.id, pack.layout.id, reason: pack.manifest.id);
      expect(decoded.dashboard.id, pack.dashboard.id, reason: pack.manifest.id);
    }
  });

  test('non-material3 packs expose at least one modern ThemeConfig field', () {
    for (final pack in builtinVisualPacks()) {
      if (pack.manifest.id == 'material3') continue;
      final t = pack.theme;
      final hasModern = t.visualStyle != null ||
          t.layers != null ||
          t.componentStyles != null ||
          t.semanticColors != null;
      expect(
        hasModern,
        isTrue,
        reason:
            '${pack.manifest.id}: expected visualStyle|layers|componentStyles|semanticColors',
      );
    }
  });

  test('glass pack\'s VisualStyle/ThemeLayerTokens/platformSupport survive '
      'the round-trip', () {
    final glass = builtinVisualPacks().firstWhere((p) => p.manifest.id == 'glass');
    final decoded = VisualPack.fromJson(glass.toJson());

    expect(decoded.theme.visualStyle, isNotNull);
    expect(decoded.theme.visualStyle!.glassDialogOpacity, isNotNull);
    expect(decoded.theme.visualStyle!.windowBackdrop, 'blur');
    expect(decoded.theme.layers, isNotNull);
    expect(decoded.theme.layers!.overlay.blurSigma, 16);
    expect(decoded.theme.layers!.panel.blurSigma, 14);
    expect(decoded.manifest.platformSupport?.supportsMobile, isFalse);
  });

  test('macos pack\'s VisualStyle survives the round-trip', () {
    final macos = builtinVisualPacks().firstWhere((p) => p.manifest.id == 'macos');
    final decoded = VisualPack.fromJson(macos.toJson());

    expect(decoded.theme.visualStyle, isNotNull);
    expect(decoded.theme.visualStyle!.windowTitleBar, 'hidden');
    expect(decoded.theme.visualStyle!.densityMode, 'compact');
    expect(decoded.theme.visualStyle!.glassSidebarOpacity, isNotNull);
    expect(decoded.theme.layers, isNotNull);
  });

  test('minealex_games modern fields survive the round-trip', () {
    final pack = builtinVisualPacks().firstWhere(
      (p) => p.manifest.id == 'minealex_games',
    );
    final decoded = VisualPack.fromJson(pack.toJson());
    expect(decoded.theme.visualStyle?.densityMode, 'compact');
    expect(decoded.theme.layers?.overlay.blurSigma, 8);
    expect(decoded.theme.semanticColors?.selection, isNotNull);
    expect(decoded.theme.componentStyles?.components['filledButton'], isNotNull);
  });
}
