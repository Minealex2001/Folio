import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform;

class FolioRadius {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

/// Iconos de marca Folio reutilizados en la UI.
class FolioIcons {
  /// Quill: pluma de escribir (feather / quill).
  static const IconData quill = Icons.history_edu_rounded;

  /// Variante outlined de [quill] para rails y list tiles.
  static const IconData quillOutlined = Icons.history_edu_outlined;
}

class FolioSpace {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 40;
}

class FolioMotion {
  static const Duration short1 = Duration(milliseconds: 120);
  static const Duration short2 = Duration(milliseconds: 200);
  static const Duration medium1 = Duration(milliseconds: 280);
  static const Curve emphasized = Curves.easeOutCubic;
}

class FolioAlpha {
  static const double faint = 0.08;
  static const double soft = 0.18;
  static const double panel = 0.45;
  static const double emphasis = 0.6;
  static const double border = 0.5;
  static const double track = 0.35;
  static const double scrim = 0.4;
  static const double thumb = 0.55;
  static const double thumbHover = 0.85;
}

class FolioElevation {
  static const double none = 0;
  static const double appBarScrolled = 1;
  static const double menu = 4;
}

class FolioShadows {
  static List<BoxShadow> card(ColorScheme scheme) {
    return [
      BoxShadow(
        color: scheme.shadow.withValues(alpha: FolioAlpha.faint),
        blurRadius: 12,
        offset: const Offset(0, 4),
      ),
    ];
  }
}

class FolioDesktop {
  static const double compactBreakpoint = 900;
  static const double mediumBreakpoint = 1180;
  static const double sidebarWidth = 320;
  static const double sidebarWideWidth = 336;
  static const double aiPanelWidth = 380;
  static const double editorMaxWidth = 920;
  static const double settingsRailWidth = 264;
  static const double pageMaxWidth = 1440;
}

/// Modo de presentación del panel de chat Quill según viewport y ajustes.
enum QuillChatLayoutMode {
  mobile,
  dockNarrow,
  dockWide,
  split,
}

/// Límites y defaults del panel Quill conscientes del tamaño de ventana.
class QuillChatLayout {
  static const double dockWideBreakpoint = 1280;

  static const double absoluteMinWidth = 280;
  static const double absoluteMaxWidth = 720;
  static const double absoluteMinHeight = 320;
  static const double absoluteMaxHeight = 1000;

  static QuillChatLayoutMode resolve({
    required double viewportWidth,
    required bool splitView,
    bool forceMobile = false,
  }) {
    if (forceMobile || viewportWidth < FolioDesktop.compactBreakpoint) {
      return QuillChatLayoutMode.mobile;
    }
    if (splitView) return QuillChatLayoutMode.split;
    if (viewportWidth < dockWideBreakpoint) {
      return QuillChatLayoutMode.dockNarrow;
    }
    return QuillChatLayoutMode.dockWide;
  }

  static double minWidth(QuillChatLayoutMode mode) => switch (mode) {
    QuillChatLayoutMode.mobile => absoluteMinWidth,
    QuillChatLayoutMode.dockNarrow => 300,
    QuillChatLayoutMode.dockWide => 340,
    QuillChatLayoutMode.split => 320,
  };

  static double maxWidth(double viewportWidth, QuillChatLayoutMode mode) {
    final relative = switch (mode) {
      QuillChatLayoutMode.mobile => viewportWidth,
      QuillChatLayoutMode.dockNarrow =>
        (viewportWidth * 0.42).clamp(0.0, 420.0),
      QuillChatLayoutMode.dockWide =>
        (viewportWidth * 0.45).clamp(0.0, 560.0),
      QuillChatLayoutMode.split => (viewportWidth * 0.40).clamp(0.0, 480.0),
    };
    return relative.clamp(minWidth(mode), absoluteMaxWidth).toDouble();
  }

  static double minHeight(QuillChatLayoutMode mode) => switch (mode) {
    QuillChatLayoutMode.mobile => absoluteMinHeight,
    QuillChatLayoutMode.dockNarrow => 360,
    QuillChatLayoutMode.dockWide => 400,
    QuillChatLayoutMode.split => absoluteMinHeight,
  };

  static double maxHeight(double viewportHeight, QuillChatLayoutMode mode) {
    final relative = switch (mode) {
      QuillChatLayoutMode.mobile => viewportHeight * 0.95,
      QuillChatLayoutMode.dockNarrow =>
        (viewportHeight * 0.80).clamp(0.0, 640.0),
      QuillChatLayoutMode.dockWide =>
        (viewportHeight * 0.85).clamp(0.0, 780.0),
      QuillChatLayoutMode.split => viewportHeight,
    };
    return relative.clamp(minHeight(mode), absoluteMaxHeight).toDouble();
  }

  /// Altura máxima del dock dentro del *body* del workspace (bajo el AppBar).
  /// [availableBodyHeight] es la altura del [Stack] del shell, no de la ventana.
  static double maxDockHeightForBody(
    double availableBodyHeight, {
    double bottomMargin = FolioSpace.md,
    double topGap = FolioSpace.sm,
  }) {
    final fit = availableBodyHeight - bottomMargin - topGap;
    return fit.clamp(56.0, absoluteMaxHeight).toDouble();
  }

  /// Acota el tamaño del dock al área disponible del body.
  static double clampDockHeight({
    required double desired,
    required double availableBodyHeight,
    required QuillChatLayoutMode mode,
  }) {
    final maxFit = maxDockHeightForBody(availableBodyHeight);
    final modeMax = maxHeight(availableBodyHeight, mode);
    final maxH = modeMax < maxFit ? modeMax : maxFit;
    // FAB colapsado (~56): no forzar el mínimo del modo (360/400).
    if (desired <= 64) {
      return desired.clamp(56.0, maxH).toDouble();
    }
    final minH = minHeight(mode) <= maxH ? minHeight(mode) : 56.0;
    return desired.clamp(minH, maxH).toDouble();
  }

  static double clampDockWidth({
    required double desired,
    required double availableBodyWidth,
    required QuillChatLayoutMode mode,
  }) {
    final maxFit = (availableBodyWidth - FolioSpace.md * 2)
        .clamp(56.0, absoluteMaxWidth)
        .toDouble();
    final modeMax = maxWidth(availableBodyWidth, mode);
    final maxW = modeMax < maxFit ? modeMax : maxFit;
    if (desired <= 64) {
      return desired.clamp(56.0, maxW).toDouble();
    }
    final minW = minWidth(mode) <= maxW ? minWidth(mode) : 56.0;
    return desired.clamp(minW, maxW).toDouble();
  }

  static double defaultWidth(double viewportWidth, QuillChatLayoutMode mode) {
    final preferred = switch (mode) {
      QuillChatLayoutMode.mobile => viewportWidth,
      QuillChatLayoutMode.dockNarrow => 340.0,
      QuillChatLayoutMode.dockWide => 380.0,
      QuillChatLayoutMode.split => 360.0,
    };
    return preferred
        .clamp(minWidth(mode), maxWidth(viewportWidth, mode))
        .toDouble();
  }

  static double defaultHeight(double viewportHeight, QuillChatLayoutMode mode) {
    final preferred = switch (mode) {
      QuillChatLayoutMode.mobile => viewportHeight * 0.92,
      QuillChatLayoutMode.dockNarrow => 480.0,
      QuillChatLayoutMode.dockWide => 560.0,
      QuillChatLayoutMode.split => maxHeight(viewportHeight, mode),
    };
    return preferred
        .clamp(minHeight(mode), maxHeight(viewportHeight, mode))
        .toDouble();
  }

  static bool useFlatChrome(QuillChatLayoutMode mode) =>
      mode == QuillChatLayoutMode.split || mode == QuillChatLayoutMode.mobile;
}

/// Umbrales de ancho específicos del panel lateral del workspace (no del
/// ancho de ventana completa — para eso usar [FolioDesktop]).
class FolioSidebar {
  /// Por debajo de este ancho, el panel se considera "casi cerrado" (durante
  /// la animación de apertura/cierre) y se omite el contenido para evitar
  /// overflow.
  static const double collapseThreshold = 32;

  /// Ancho mínimo de una fila de página para mostrar sus acciones inline
  /// (menú ⋯: renombrar, mover, borrar, …) sin overflow. En móvil/web el menú
  /// se muestra siempre; en escritorio nativo, al hover.
  static const double tileActionsMinWidth = 200;

  /// Ancho reservado para la zona de acciones inline (+ y ⋯) en cada fila del
  /// árbol. Se reserva siempre (aunque las acciones estén ocultas por opacidad)
  /// para evitar layout shift al hover en escritorio.
  /// Dos IconButton compactos (~40px c/u) necesitan ≥80px.
  static const double tileActionsSlotWidth = 80;
}

class FolioAdaptive {
  // En Android, este ancho activa una UX similar a escritorio (tablet/Dex).
  static const double androidDesktopLikeBreakpoint = 1000;
  static const double androidPhoneLikeBreakpoint = 700;

  static bool isAndroidDesktopLikeWidth(double width) {
    return defaultTargetPlatform == TargetPlatform.android &&
        width >= androidDesktopLikeBreakpoint;
  }

  static bool isAndroidPhoneWidth(double width) {
    return defaultTargetPlatform == TargetPlatform.android &&
        width < androidPhoneLikeBreakpoint;
  }

  static bool shouldUseDesktopSections(double width) {
    return defaultTargetPlatform != TargetPlatform.android ||
        isAndroidDesktopLikeWidth(width);
  }

  static bool shouldUseMobileWorkspace(double width) {
    return defaultTargetPlatform == TargetPlatform.android &&
        !isAndroidDesktopLikeWidth(width);
  }

  /// Nombre del sistema operativo actual (nombre de marca, no traducible),
  /// para etiquetas como "seguir acento del sistema". `defaultTargetPlatform`
  /// ya refleja el SO real también en web (se infiere del user agent).
  static String currentPlatformName() {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'Android';
      case TargetPlatform.iOS:
        return 'iOS';
      case TargetPlatform.macOS:
        return 'macOS';
      case TargetPlatform.linux:
        return 'Linux';
      case TargetPlatform.windows:
        return 'Windows';
      case TargetPlatform.fuchsia:
        return 'Fuchsia';
    }
  }
}
