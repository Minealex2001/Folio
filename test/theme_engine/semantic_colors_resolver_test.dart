import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folio/config/models/design_tokens.dart';
import 'package:folio/config/models/design_variables.dart';
import 'package:folio/config/models/semantic_color_tokens.dart';
import 'package:folio/config/models/token_ref.dart';
import 'package:folio/theme_engine/design_tokens_resolver.dart';
import 'package:folio/theme_engine/semantic_colors_resolver.dart';

void main() {
  final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF3366CC));

  group('resolveSemanticColors', () {
    test('with null tokens, every role derives from ColorScheme', () {
      final result = resolveSemanticColors(null, scheme);
      expect(result.editorBackground, scheme.surface);
      expect(result.sidebarBackground, scheme.surfaceContainerLow);
      expect(result.cardBackground, scheme.surfaceContainerLow);
      expect(result.selection, scheme.secondaryContainer);
      expect(result.focus, scheme.primary);
    });

    test('a literal override wins over the ColorScheme-derived default', () {
      final tokens = const SemanticColorTokens(
        sidebarBackground: TokenRef.literal(0xFF112233),
      );
      final result = resolveSemanticColors(tokens, scheme);
      expect(result.sidebarBackground, const Color(0xFF112233));
      // Untouched fields still fall back normally.
      expect(result.cardBackground, scheme.surfaceContainerLow);
    });

    test('a token reference resolves via the DesignTokensResolver', () {
      final tokens = const SemanticColorTokens(
        warning: TokenRef.ref('color.danger'),
      );
      final designTokens = DesignTokens(color: const {'danger': 0xFFFF0000});
      final resolver = DesignTokensResolver(designTokens, DesignVariables());
      final result = resolveSemanticColors(
        tokens,
        scheme,
        tokensResolver: resolver,
      );
      expect(result.warning, const Color(0xFFFF0000));
    });

    test('a token reference without a resolver falls back to the derived default', () {
      final tokens = const SemanticColorTokens(
        warning: TokenRef.ref('color.danger'),
      );
      final result = resolveSemanticColors(tokens, scheme);
      // Falls back to the tertiary-derived warning color, not a crash.
      expect(result.warning, isNot(scheme.tertiary));
    });

    test('warning/success/info are distinct hues derived from tertiary', () {
      final result = resolveSemanticColors(null, scheme);
      expect(result.warning, isNot(result.success));
      expect(result.success, isNot(result.info));
      expect(result.warning, isNot(result.info));
    });
  });
}
