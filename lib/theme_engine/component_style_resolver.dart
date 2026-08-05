import '../config/models/component_style_tokens.dart';
import '../config/models/theme_shape_tokens.dart';
import 'design_tokens_resolver.dart';

/// Resuelve el `ComponentStyleEntry` efectivo de un componente con nombre
/// (Fase 15). Cascada de tres niveles, sin borrar ningún nivel anterior:
/// `ComponentStyleTokens.components[name]` (nuevo) -> legacy
/// `ThemeShapeTokens.componentRadiusOverrides[name]` (Fase 1) -> el literal
/// por defecto que ya pasa cada call site de `theme_resolver.dart`.
class ComponentStyleResolver {
  const ComponentStyleResolver(
    this.componentStyles,
    this.shape, {
    this.tokensResolver,
  });

  final ComponentStyleTokens? componentStyles;
  final ThemeShapeTokens shape;
  final DesignTokensResolver? tokensResolver;

  ComponentStyleEntry? styleFor(String componentName) =>
      componentStyles?.components[componentName];

  /// Radio efectivo para [componentName], con [fallback] como el literal
  /// que `theme_resolver.dart` ya pasaba antes de la Fase 15.
  double radiusFor(String componentName, double fallback) {
    final entry = styleFor(componentName);
    final ref = entry?.radius;
    if (ref != null) {
      return tokensResolver?.resolveDouble(ref, fallback) ??
          (ref.isReference ? fallback : ref.literalValue!);
    }
    return shape.componentRadiusOverrides?[componentName] ?? fallback;
  }

  /// Color de fondo efectivo para [componentName], o null si ninguna capa
  /// (nueva ni legacy) lo configura — el call site decide su propio default.
  int? backgroundFor(String componentName) {
    final ref = styleFor(componentName)?.backgroundColor;
    if (ref == null) return null;
    if (!ref.isReference) return ref.literalValue;
    return tokensResolver?.resolveColor(ref, 0);
  }
}
