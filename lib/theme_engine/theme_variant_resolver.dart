import '../config/models/theme_config.dart';
import '../config/models/theme_variant.dart';

/// Aplica [variant] sobre [base] — cada campo no-null de [variant] gana,
/// el resto hereda de [base]. Literalmente `base.copyWith(...)`: el mismo
/// mecanismo tipado que cada otra mutación de tema ya usa, así que "aplicar
/// una variante" es tan depurable como cualquier otra llamada a `copyWith`
/// (breakpoint normal, sin recorrido de `Map` dinámico).
ThemeConfig applyVariant(ThemeConfig base, ThemeVariant variant) {
  return base.copyWith(
    light: variant.light,
    dark: variant.dark,
    typography: variant.typography,
    shape: variant.shape,
    elevation: variant.elevation,
    spacing: variant.spacing,
    motion: variant.motion,
    icons: variant.icons,
    surfaceOpacity: variant.surfaceOpacity,
    accentMode: variant.accentMode,
    semanticColors: variant.semanticColors,
    componentStyles: variant.componentStyles,
    layers: variant.layers,
  );
}

/// Busca una variante por id en [config.variants]; null si no existe o si
/// [variantId] es null.
ThemeVariant? findVariant(ThemeConfig config, String? variantId) {
  if (variantId == null) return null;
  for (final variant in config.variants ?? const <ThemeVariant>[]) {
    if (variant.id == variantId) return variant;
  }
  return null;
}

/// Resuelve el [ThemeConfig] efectivo teniendo en cuenta
/// `config.activeVariantId` — el punto de entrada que
/// `ThemeConfigController`/`resolveThemeData` deberían usar en vez de leer
/// `config` a secas cuando las variantes estén conectadas a la UI.
ThemeConfig resolveActiveVariant(ThemeConfig config) {
  final variant = findVariant(config, config.activeVariantId);
  if (variant == null) return config;
  return applyVariant(config, variant);
}
