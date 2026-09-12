import 'package:flutter_test/flutter_test.dart';
import 'package:folio/config/models/design_tokens.dart';
import 'package:folio/config/models/design_variables.dart';
import 'package:folio/config/models/token_ref.dart';
import 'package:folio/theme_engine/design_tokens_resolver.dart';

void main() {
  final tokens = DesignTokens(
    radius: const {'lg': 16, 'sm': 8},
    space: const {'md': 16},
    color: const {'danger': 0xFFFF0000},
  );

  group('DesignTokensResolver', () {
    test('literal passthrough — no lookup involved', () {
      final resolver = DesignTokensResolver(tokens, DesignVariables());
      expect(
        resolver.resolveDouble(const TokenRef.literal(42), -1),
        42,
      );
    });

    test('simple token reference resolves to the token value', () {
      final resolver = DesignTokensResolver(tokens, DesignVariables());
      expect(
        resolver.resolveDouble(const TokenRef.ref('radius.lg'), -1),
        16,
      );
    });

    test('unknown token reference falls back', () {
      final resolver = DesignTokensResolver(tokens, DesignVariables());
      expect(
        resolver.resolveDouble(const TokenRef.ref('radius.doesNotExist'), -1),
        -1,
      );
    });

    test('color reference resolves to the ARGB token value', () {
      final resolver = DesignTokensResolver(tokens, DesignVariables());
      expect(
        resolver.resolveColor(const TokenRef.ref('color.danger'), 0),
        0xFFFF0000,
      );
    });

    test('variable chain resolves through var. indirection', () {
      final variables = DesignVariables(
        entries: const {
          'editorPadding': '@space.md',
          'sidebarPadding': '@var.editorPadding',
          'toolbarPadding': '@var.sidebarPadding',
        },
      );
      final resolver = DesignTokensResolver(tokens, variables);
      expect(
        resolver.resolveDouble(const TokenRef.ref('var.toolbarPadding'), -1),
        16,
      );
    });

    test('cyclic variable reference falls back instead of looping forever', () {
      final variables = DesignVariables(
        entries: const {'a': '@var.b', 'b': '@var.a'},
      );
      final resolver = DesignTokensResolver(tokens, variables);
      expect(resolver.resolveDouble(const TokenRef.ref('var.a'), -1), -1);
    });

    test('chain deeper than kMaxVariableChainDepth falls back', () {
      final variables = DesignVariables(
        entries: const {
          'a': '@var.b',
          'b': '@var.c',
          'c': '@var.d',
          'd': '@var.e',
          'e': '@space.md',
        },
      );
      final resolver = DesignTokensResolver(tokens, variables);
      // a -> b -> c -> d -> e -> space.md is 5 hops, above the 4-hop cap.
      expect(resolver.resolveDouble(const TokenRef.ref('var.a'), -1), -1);
    });

    test('chain within kMaxVariableChainDepth resolves normally', () {
      final variables = DesignVariables(
        entries: const {'a': '@var.b', 'b': '@var.c', 'c': '@space.md'},
      );
      final resolver = DesignTokensResolver(tokens, variables);
      // a -> b -> c -> space.md is 3 hops, within the cap.
      expect(resolver.resolveDouble(const TokenRef.ref('var.a'), -1), 16);
    });

    test('variable pointing at a missing entry falls back', () {
      final variables = DesignVariables(entries: const {});
      final resolver = DesignTokensResolver(tokens, variables);
      expect(resolver.resolveDouble(const TokenRef.ref('var.missing'), -1), -1);
    });
  });

  group('TokenRef JSON round-trip', () {
    test('legacy bare literal JSON decodes as a literal TokenRef', () {
      const converter = TokenRefDoubleConverter();
      final ref = converter.fromJson(16.0);
      expect(ref.isReference, isFalse);
      expect(ref.literalValue, 16.0);
      expect(converter.toJson(ref), 16.0);
    });

    test('@-prefixed string JSON decodes as a reference TokenRef', () {
      const converter = TokenRefDoubleConverter();
      final ref = converter.fromJson('@radius.lg');
      expect(ref.isReference, isTrue);
      expect(ref.refName, 'radius.lg');
      expect(converter.toJson(ref), '@radius.lg');
    });
  });
}
