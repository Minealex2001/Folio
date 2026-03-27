import 'package:flutter/material.dart';

class FolioRadius {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
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
