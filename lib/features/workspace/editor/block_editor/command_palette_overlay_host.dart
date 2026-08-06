part of 'package:folio/features/workspace/editor/block_editor.dart';

/// Fase C2/C3 del rediseño UX del editor — muestra/oculta el
/// `CommandPaletteOverlay` vía un `OverlayEntry`, mismo mecanismo ya
/// establecido por `_FormatToolbarOverlay` (show/hide/dismiss-on-outside-
/// click/Esc) para el popup de slash. El registro combina el proveedor de
/// IA de la Fase C1 con `widget.extraPaletteCommandsProvider` (Fase C3) —
/// comandos de nivel-workspace que `workspace_page.dart` inyecta porque el
/// editor no conoce esos controllers.
mixin _CommandPaletteOverlayHost on State<BlockEditor> {
  BlockEditorState get _paletteSelf => this as BlockEditorState;

  OverlayEntry? _commandPaletteOverlayEntry;
  final Map<String, int> _paletteRecentScores = {};
  PaletteCommandRegistry? _commandPaletteRegistry;

  /// Registro actual — reconstruido en cada `showCommandPaletteOverlay` (ver
  /// ahí por qué: el bloque enfocado se ancla en el momento de abrir, no se
  /// lee en vivo). Fuera de una sesión abierta, expone un registro vacío de
  /// IA-sin-ancla (`anchorBlockId: null`) para que sea seguro llamarlo desde
  /// tests sin haber abierto el overlay primero.
  PaletteCommandRegistry get commandPaletteRegistry {
    final st = _paletteSelf;
    return _commandPaletteRegistry ??= PaletteCommandRegistry(
      providers: [() => st._aiPaletteCommands(AppLocalizations.of(context))],
    );
  }

  bool get isCommandPaletteOpen => _commandPaletteOverlayEntry != null;

  void showCommandPaletteOverlay() {
    if (_commandPaletteOverlayEntry != null) return;
    final st = _paletteSelf;
    final anchorBlockId = st._focusedBlockId;
    final extraProvider = widget.extraPaletteCommandsProvider;
    _commandPaletteRegistry = PaletteCommandRegistry(
      providers: [
        () => st._aiPaletteCommands(
          AppLocalizations.of(context),
          anchorBlockId: anchorBlockId,
        ),
        ?extraProvider,
      ],
    );
    final overlay = Overlay.of(context, rootOverlay: true);
    final entry = OverlayEntry(
      builder: (context) => CommandPaletteOverlay(
        resolveCommands: () => commandPaletteRegistry.resolve(),
        recentScores: _paletteRecentScores,
        onDismiss: dismissCommandPaletteOverlay,
        onCommandExecuted: (id) {
          _paletteRecentScores.update(id, (v) => v + 1, ifAbsent: () => 1);
        },
      ),
    );
    _commandPaletteOverlayEntry = entry;
    overlay.insert(entry);
    if (mounted) setState(() {});
  }

  void dismissCommandPaletteOverlay() {
    _commandPaletteOverlayEntry?.remove();
    _commandPaletteOverlayEntry = null;
    if (mounted) setState(() {});
  }

  void toggleCommandPaletteOverlay() {
    if (isCommandPaletteOpen) {
      dismissCommandPaletteOverlay();
    } else {
      showCommandPaletteOverlay();
    }
  }
}
