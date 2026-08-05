import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:folio/config/models/design_tokens.dart';
import 'package:folio/config/models/design_variables.dart';
import 'package:folio/config/models/theme_config.dart';
import 'package:folio/config/models/token_ref.dart';
import 'package:folio/theme_engine/design_tokens_resolver.dart';
import 'package:folio/theme_engine/theme_variant_resolver.dart';

void main() {
  final dir = Directory('examples/showcase_f20');

  test('showcase_f20 JSON round-trips and resolves TokenRefs', () {
    final tokens = DesignTokens.fromJson(
      jsonDecode(File('${dir.path}/design_tokens.json').readAsStringSync())
          as Map<String, dynamic>,
    );
    final variables = DesignVariables.fromJson(
      jsonDecode(File('${dir.path}/design_variables.json').readAsStringSync())
          as Map<String, dynamic>,
    );
    final theme = ThemeConfig.fromJson(
      jsonDecode(File('${dir.path}/theme.json').readAsStringSync())
          as Map<String, dynamic>,
    );

    expect(theme.id, 'showcase_f20');
    expect(theme.semanticColors, isNotNull);
    expect(theme.componentStyles?.components['filledButton']?.states, isNotNull);
    expect(theme.layers?.panel.blurSigma, 14);
    expect(theme.variants, hasLength(3));
    expect(theme.activeVariantId, 'night-oled');
    expect(theme.visualStyle?.densityMode, 'comfortable');
    expect(theme.visualStyle?.windowBackdrop, 'blur');
    expect(theme.visualStyle?.iconSize?.refName, 'size.iconMd');

    final resolver = DesignTokensResolver(tokens, variables);
    expect(resolver.resolveDouble(const TokenRef.ref('radius.pill'), 0), 999);
    expect(resolver.resolveDouble(const TokenRef.ref('var.toolbarPadding'), 0), 16);
    expect(resolver.resolveColor(const TokenRef.ref('var.brandFocus'), 0), 0xFF00F3FF);
    expect(
      resolver.resolveDouble(theme.visualStyle!.glassSidebarOpacity!, 0),
      0.88,
    );

    final merged = resolveActiveVariant(theme);
    expect(merged.dark.surfaceStyle, 'oled');
    expect(merged.surfaceOpacity, 0.96);
  });
}
