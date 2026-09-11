/// Preset de estilo visual de callout (Fase 27) — modula (no reemplaza) la
/// derivación por-tono ya existente en `block_editor_callout.dart`:
/// multiplicadores de alfa sobre el fondo/borde/chip, más si se dibuja
/// borde/icono. Deliberadamente pequeño (solo lo que un callout realista
/// varía entre apps de notas) en vez de un sistema de theming exhaustivo.
class CalloutStylePreset {
  const CalloutStylePreset({
    required this.id,
    required this.backgroundAlphaScale,
    required this.borderAlphaScale,
    required this.chipAlphaScale,
    required this.showBorder,
    required this.showIcon,
  });

  final String id;
  final double backgroundAlphaScale;
  final double borderAlphaScale;
  final double chipAlphaScale;
  final bool showBorder;
  final bool showIcon;
}

/// 'notion' es el default y reproduce exactamente los alfas ya hardcodeados
/// en `block_editor_callout.dart` hoy (scale 1.0 = sin cambio) — parity
/// garantizada para quien no configure `calloutStyle`.
const CalloutStylePreset kCalloutStyleNotion = CalloutStylePreset(
  id: 'notion',
  backgroundAlphaScale: 1.0,
  borderAlphaScale: 1.0,
  chipAlphaScale: 1.0,
  showBorder: true,
  showIcon: true,
);

/// Obsidian: callouts más marcados — fondo más intenso, borde más grueso
/// visualmente (vía alfa más alto).
const CalloutStylePreset kCalloutStyleObsidian = CalloutStylePreset(
  id: 'obsidian',
  backgroundAlphaScale: 1.4,
  borderAlphaScale: 1.3,
  chipAlphaScale: 1.1,
  showBorder: true,
  showIcon: true,
);

/// Minimal: sin borde, fondo muy sutil, sin icono — un callout que casi no
/// interrumpe la lectura.
const CalloutStylePreset kCalloutStyleMinimal = CalloutStylePreset(
  id: 'minimal',
  backgroundAlphaScale: 0.5,
  borderAlphaScale: 0.0,
  chipAlphaScale: 0.7,
  showBorder: false,
  showIcon: false,
);

const List<CalloutStylePreset> kBuiltinCalloutStylePresets = [
  kCalloutStyleNotion,
  kCalloutStyleObsidian,
  kCalloutStyleMinimal,
];

/// Resuelve un id de preset (`EditorLayoutTokens.calloutStyle`) a su
/// [CalloutStylePreset] — nombre desconocido cae a `notion` (mismo patrón
/// de fallback-desconocido que `resolveMotionCurve`).
CalloutStylePreset calloutStylePresetFor(String id) {
  for (final preset in kBuiltinCalloutStylePresets) {
    if (preset.id == id) return preset;
  }
  return kCalloutStyleNotion;
}
