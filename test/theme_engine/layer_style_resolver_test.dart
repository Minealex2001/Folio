import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folio/config/models/theme_layer_tokens.dart';
import 'package:folio/config/models/token_ref.dart';
import 'package:folio/theme_engine/layer_style_resolver.dart';

void main() {
  group('resolveLayer', () {
    test('maps layer names to the matching field', () {
      const tokens = ThemeLayerTokens(
        surface: LayerStyle(border: true),
        panel: LayerStyle(shadow: true),
        overlay: LayerStyle(shadow: true, border: true),
      );
      expect(resolveLayer(tokens, 'surface').border, isTrue);
      expect(resolveLayer(tokens, 'panel').shadow, isTrue);
      expect(resolveLayer(tokens, 'overlay').border, isTrue);
    });

    test('an unknown layer name falls back to a plain LayerStyle', () {
      const tokens = ThemeLayerTokens();
      final style = resolveLayer(tokens, 'does-not-exist');
      expect(style.shadow, isFalse);
      expect(style.border, isFalse);
    });
  });

  group('decorationFor', () {
    final scheme = ColorScheme.fromSeed(seedColor: Colors.blue);

    test('opaque style keeps the background color exactly, no border/shadow', () {
      const style = LayerStyle();
      final decoration = decorationFor(style, scheme, Colors.red);
      expect(decoration.color, Colors.red);
      expect(decoration.border, isNull);
      expect(decoration.boxShadow, isNull);
    });

    test('border: true adds a Border, shadow: true adds a BoxShadow', () {
      const style = LayerStyle(border: true, shadow: true);
      final decoration = decorationFor(style, scheme, Colors.red);
      expect(decoration.border, isNotNull);
      expect(decoration.boxShadow, isNotNull);
    });

    test('a literal opacity token applies alpha to the background color', () {
      const style = LayerStyle(opacity: TokenRef.literal(0.5));
      final decoration = decorationFor(style, scheme, Colors.red);
      expect((decoration.color as Color).a, closeTo(0.5, 0.01));
    });
  });
}
