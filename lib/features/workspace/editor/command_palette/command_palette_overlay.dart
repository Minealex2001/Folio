import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../l10n/generated/app_localizations.dart';
import 'palette_command.dart';
import 'palette_filter.dart';

/// Fase C2 del rediseño UX del editor — la superficie del Command Palette:
/// campo de búsqueda + lista rankeada + navegación por teclado
/// (arriba/abajo/enter/esc). El overlay en sí (mostrar/ocultar/anclar,
/// cerrar al tocar fuera) vive en `BlockEditorState` (mismo mecanismo de
/// `OverlayEntry` ya establecido por `_FormatToolbarOverlay` para el popup
/// de slash) — este widget es solo el contenido.
class CommandPaletteOverlay extends StatefulWidget {
  const CommandPaletteOverlay({
    super.key,
    required this.resolveCommands,
    required this.recentScores,
    required this.onDismiss,
    required this.onCommandExecuted,
  });

  /// Se llama de nuevo en cada rebuild — permite que la disponibilidad
  /// (`PaletteCommand.isAvailable`) se reevalúe mientras el Palette está
  /// abierto (ej. el usuario cambia de bloque enfocado sin cerrar el
  /// Palette todavía).
  final List<PaletteCommand> Function() resolveCommands;
  final Map<String, int> recentScores;
  final VoidCallback onDismiss;

  /// Se llama justo antes de ejecutar un comando — el llamador decide cómo
  /// actualizar `recentScores` (mismo patrón que `_slashRecentByType`).
  final ValueChanged<String> onCommandExecuted;

  @override
  State<CommandPaletteOverlay> createState() => _CommandPaletteOverlayState();
}

class _CommandPaletteOverlayState extends State<CommandPaletteOverlay> {
  final _queryController = TextEditingController();
  final _queryFocusNode = FocusNode();
  int _selectedIndex = 0;

  List<PaletteCommand> get _filtered => filterPaletteCommands(
    widget.resolveCommands(),
    _queryController.text,
    recentScores: widget.recentScores,
  );

  @override
  void initState() {
    super.initState();
    _queryFocusNode.requestFocus();
    _queryController.addListener(() {
      setState(() => _selectedIndex = 0);
    });
  }

  @override
  void dispose() {
    _queryController.dispose();
    _queryFocusNode.dispose();
    super.dispose();
  }

  void _execute(PaletteCommand command) {
    if (!command.isCurrentlyAvailable) return;
    widget.onCommandExecuted(command.id);
    widget.onDismiss();
    // Ejecutar después de cerrar el overlay — igual que el slash menu, para
    // que el comando no interactúe con un árbol de foco a medio desmontar.
    command.execute();
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final items = _filtered;
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      widget.onDismiss();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      if (items.isEmpty) return KeyEventResult.handled;
      setState(() => _selectedIndex = (_selectedIndex + 1).clamp(0, items.length - 1));
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      if (items.isEmpty) return KeyEventResult.handled;
      setState(() => _selectedIndex = (_selectedIndex - 1).clamp(0, items.length - 1));
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter) {
      if (items.isEmpty) return KeyEventResult.handled;
      _execute(items[_selectedIndex.clamp(0, items.length - 1)]);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final items = _filtered;
    final selected = items.isEmpty ? -1 : _selectedIndex.clamp(0, items.length - 1);

    return Stack(
      children: [
        // Barrera para cerrar al tocar fuera — mismo patrón que el resto de
        // los popups del editor (slash/mention).
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onDismiss,
            child: const SizedBox.shrink(),
          ),
        ),
        Align(
          alignment: const Alignment(0, -0.55),
          child: Material(
            elevation: 12,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560, maxHeight: 560),
              child: Focus(
                onKeyEvent: _onKeyEvent,
                child: Column(
                  mainAxisSize: MainAxisSize.max,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: TextField(
                        controller: _queryController,
                        focusNode: _queryFocusNode,
                        decoration: InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          hintText: l10n.commandPaletteSearchHint,
                          prefixIcon: const Icon(Icons.search_rounded),
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    Flexible(
                      child: items.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(l10n.noSearchResults),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              itemCount: items.length,
                              itemBuilder: (context, index) {
                                final command = items[index];
                                final isSelected = index == selected;
                                return ListTile(
                                  dense: true,
                                  selected: isSelected,
                                  selectedTileColor:
                                      scheme.primary.withValues(alpha: 0.1),
                                  enabled: command.isCurrentlyAvailable,
                                  leading: Icon(command.icon, size: 20),
                                  title: Text(command.label),
                                  subtitle: command.hint.isEmpty
                                      ? null
                                      : Text(command.hint),
                                  trailing: command.shortcutLabel == null
                                      ? null
                                      : Text(
                                          command.shortcutLabel!,
                                          style: TextStyle(
                                            color: scheme.onSurfaceVariant,
                                            fontSize: 12,
                                          ),
                                        ),
                                  onTap: () => _execute(command),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
