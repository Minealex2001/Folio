import 'package:flutter/foundation.dart' show TargetPlatform;

/// Efectos con gating de plataforma conocido (Fase 32, anexo del brief) —
/// hoy solo el backdrop de ventana (`VisualStyle.windowBackdrop`), pero el
/// mecanismo es genérico para lo que venga después.
const String kEffectWindowBackdropBlur = 'windowBackdropBlur';
const String kEffectGlassOpacity = 'glassOpacity';

const Set<TargetPlatform> _mobilePlatforms = {
  TargetPlatform.android,
  TargetPlatform.iOS,
};

/// `false` cuando [effectId] es un efecto conocido como no recomendado en
/// [platform] por defecto (ej. backdrop blur de ventana en móvil — coste de
/// composición alto, look de "ventana flotante de escritorio" que no
/// encaja en una app de pantalla completa). Cualquier efecto no listado, o
/// cualquier plataforma no cubierta, se considera permitido — el gating es
/// una lista de excepciones curada, no un allowlist.
bool isEffectAllowed(String effectId, TargetPlatform platform) {
  final isMobile = _mobilePlatforms.contains(platform);
  if (!isMobile) return true;

  switch (effectId) {
    case kEffectWindowBackdropBlur:
    case kEffectGlassOpacity:
      return false;
    default:
      return true;
  }
}
