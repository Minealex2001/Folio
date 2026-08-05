import '../app/ui_tokens.dart';
import '../config/models/design_tokens.dart';
import '../config/models/design_variables.dart';

/// [DesignTokens] que reproduce exactamente los literales ya hardcodeados en
/// `ui_tokens.dart` (`FolioRadius`/`FolioSpace`) — mismo patrón de
/// guardia-contra-drift que `theme_config_defaults.dart`: si alguien cambia
/// un valor en `ui_tokens.dart` sin actualizar este archivo, el test de
/// round-trip lo detecta.
final DesignTokens kFolioDefaultDesignTokens = DesignTokens(
  id: 'default',
  radius: const {
    'xs': FolioRadius.xs,
    'sm': FolioRadius.sm,
    'md': FolioRadius.md,
    'lg': FolioRadius.lg,
    'xl': FolioRadius.xl,
    'xxl': FolioRadius.xxl,
  },
  space: const {
    'xxs': FolioSpace.xxs,
    'xs': FolioSpace.xs,
    'sm': FolioSpace.sm,
    'md': FolioSpace.md,
    'lg': FolioSpace.lg,
    'xl': FolioSpace.xl,
  },
  opacity: const {'glassLight': 0.85, 'glassHeavy': 0.6},
  motionMs: const {'fast': 120, 'medium': 200, 'slow': 280},
);

/// Cadena semántica de ejemplo del brief (punto 6): `space.md -> editor
/// padding -> sidebar padding -> toolbar padding` — sembrada como default
/// enviado para que la feature esté demostrablemente viva de fábrica, no
/// solo plumbing.
final DesignVariables kFolioDefaultDesignVariables = DesignVariables(
  id: 'default',
  entries: const {
    'editorPadding': '@space.md',
    'sidebarPadding': '@var.editorPadding',
    'toolbarPadding': '@var.sidebarPadding',
  },
);
