/// Puntos de quiebre responsive genéricos para [LayoutConfig.
/// responsiveOverrides] (Fase 7) — consolidados como constantes propias,
/// alineados con (pero no reemplazando) los umbrales ya dispersos en
/// `lib/app/ui_tokens.dart` (`FolioDesktop.compactBreakpoint = 900`,
/// `FolioAdaptive.androidPhoneLikeBreakpoint = 700`). No se migran esos
/// call sites existentes a esta clase — decenas de sitios ya los usan
/// directamente y no hay necesidad de tocarlos para que el motor de layout
/// tenga su propio sistema de 4 niveles.
enum Breakpoint { mobile, tablet, desktop, ultrawide }

abstract final class Breakpoints {
  static const double mobile = 0;
  static const double tablet = 700;
  static const double desktop = 900;
  static const double ultrawide = 1600;

  /// Resuelve un ancho de viewport al [Breakpoint] correspondiente.
  /// Límites inclusivos por abajo: `width == desktop` ya cuenta como
  /// desktop, no tablet.
  static Breakpoint resolve(double width) {
    if (width >= ultrawide) return Breakpoint.ultrawide;
    if (width >= desktop) return Breakpoint.desktop;
    if (width >= tablet) return Breakpoint.tablet;
    return Breakpoint.mobile;
  }
}
