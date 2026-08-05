import '../config/models/widget_theme_tokens.dart';

/// Fusiona superficialmente el `defaultTheme` de un plugin con lo
/// configurado en [tokens] para [pluginId] — las claves configuradas ganan,
/// el resto cae al default declarado por el propio plugin.
Map<String, dynamic> themeFor(
  WidgetThemeTokens? tokens,
  String pluginId,
  Map<String, dynamic> pluginDefault,
) {
  final configured = tokens?.widgets[pluginId];
  if (configured == null || configured.isEmpty) return pluginDefault;
  return {...pluginDefault, ...configured};
}
