import 'palette_command.dart';

/// Fase C1 del rediseño UX del editor — registro de comandos del Command
/// Palette. No es una lista estática: es una colección de "proveedores"
/// (`List<PaletteCommand> Function()`), cada uno resuelto en el momento de
/// abrir el Palette. Esto es lo que permite que comandos de plugin (o de
/// otras partes de la app, como el workspace-level "cambiar tema"/"abrir
/// página") se registren desde donde viven de verdad — el editor no
/// necesita conocer el `ThemeConfigController`/`LayoutEngineController`
/// para ofrecer "cambiar tema" en el Palette, solo necesita que quien sí
/// los tiene (`workspace_page.dart`, en una fase posterior) llame
/// `addProvider`.
class PaletteCommandRegistry {
  PaletteCommandRegistry({List<List<PaletteCommand> Function()>? providers})
    : _providers = List.of(providers ?? const []);

  final List<List<PaletteCommand> Function()> _providers;

  void addProvider(List<PaletteCommand> Function() provider) {
    _providers.add(provider);
  }

  /// Resuelve todos los proveedores. Deliberadamente NO filtra por
  /// `isCurrentlyAvailable` — un comando no disponible ahora mismo (ej. sin
  /// bloque enfocado) sigue apareciendo en el Palette, solo que
  /// deshabilitado (`CommandPaletteOverlay` lo pinta atenuado y no lo
  /// ejecuta al tocarlo) — el usuario ve que el comando existe, no que
  /// desaparece sin explicación.
  List<PaletteCommand> resolve() {
    final all = <PaletteCommand>[];
    for (final provider in _providers) {
      all.addAll(provider());
    }
    return all;
  }
}
