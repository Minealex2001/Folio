import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folio/features/workspace/editor/command_palette/palette_command.dart';
import 'package:folio/features/workspace/editor/command_palette/palette_command_registry.dart';
import 'package:folio/features/workspace/editor/command_palette/palette_filter.dart';

/// Fase C1 del rediseño UX del editor — tests puros del filtro/registro del
/// Command Palette, sin widget pump (mismo patrón que
/// `block_editor_callout_test.dart`/`folio_slash_filter_test.dart`).
void main() {
  PaletteCommand cmd(String id, String label, {String hint = ''}) =>
      PaletteCommand(
        id: id,
        label: label,
        hint: hint,
        icon: Icons.abc,
        category: PaletteCommandCategory.navigation,
        execute: () {},
      );

  group('filterPaletteCommands', () {
    test('query vacía devuelve todos los comandos en orden original', () {
      final commands = [cmd('a', 'Abrir página'), cmd('b', 'Buscar')];
      final result = filterPaletteCommands(commands, '');
      expect(result.map((c) => c.id).toList(), ['a', 'b']);
    });

    test('filtra por coincidencia en label (case-insensitive)', () {
      final commands = [cmd('a', 'Abrir página'), cmd('b', 'Buscar')];
      final result = filterPaletteCommands(commands, 'ABRIR');
      expect(result.map((c) => c.id).toList(), ['a']);
    });

    test('filtra por coincidencia en hint', () {
      final commands = [
        cmd('a', 'Uno', hint: 'ejecuta la primera acción'),
        cmd('b', 'Dos', hint: 'irrelevante'),
      ];
      final result = filterPaletteCommands(commands, 'primera');
      expect(result.map((c) => c.id).toList(), ['a']);
    });

    test('sin coincidencias devuelve lista vacía', () {
      final commands = [cmd('a', 'Uno')];
      expect(filterPaletteCommands(commands, 'zzz'), isEmpty);
    });

    test('recentScores desempata por frecuencia de uso reciente, no por '
        'orden alfabético', () {
      final commands = [cmd('a', 'Alfa'), cmd('b', 'Beta'), cmd('c', 'Gamma')];
      final result = filterPaletteCommands(
        commands,
        '',
        recentScores: {'c': 5, 'a': 1},
      );
      expect(result.map((c) => c.id).toList(), ['c', 'a', 'b']);
    });

    group('capa de intención en lenguaje natural (Fase 1 del roadmap)', () {
      test('frase sin match literal cae al fallback por sinónimos', () {
        final commands = [
          cmd('cmd_workspace_new_page', 'Nuevo folio'),
          cmd('cmd_workspace_settings', 'Ajustes'),
        ];
        final result = filterPaletteCommands(
          commands,
          'necesito crear pagina para esto',
        );
        expect(result.map((c) => c.id).toList(), ['cmd_workspace_new_page']);
      });

      test('funciona igual en inglés', () {
        final commands = [
          cmd('cmd_workspace_search', 'Search'),
          cmd('cmd_workspace_settings', 'Settings'),
        ];
        final result = filterPaletteCommands(commands, 'search for something');
        expect(result.map((c) => c.id).toList(), ['cmd_workspace_search']);
      });

      test('un match literal gana y el fallback NL no se activa (aunque la '
          'frase también dispararía un sinónimo de otro comando)', () {
        final commands = [
          cmd('a', 'crear pagina nueva'),
          cmd('cmd_workspace_new_page', 'Nuevo folio'),
        ];
        // La frase completa hace match literal en el label de 'a' — el
        // fallback ni se evalúa, así que cmd_workspace_new_page (que
        // también dispararía por sinónimo) no debe aparecer.
        final result = filterPaletteCommands(commands, 'crear pagina nueva');
        expect(result.map((c) => c.id).toList(), ['a']);
      });

      test('frase sin ningún sinónimo conocido sigue sin resultados', () {
        final commands = [cmd('cmd_workspace_new_page', 'Nuevo folio')];
        expect(
          filterPaletteCommands(commands, 'algo totalmente distinto'),
          isEmpty,
        );
      });

      test('una sola palabra sin match no activa el fallback NL '
          '(reservado a frases)', () {
        final commands = [cmd('cmd_workspace_new_page', 'Nuevo folio')];
        expect(filterPaletteCommands(commands, 'pagina'), isEmpty);
      });
    });
  });

  group('PaletteCommandRegistry', () {
    test('resolve concatena todos los proveedores registrados', () {
      final registry = PaletteCommandRegistry(
        providers: [
          () => [cmd('a', 'Uno')],
        ],
      );
      registry.addProvider(() => [cmd('b', 'Dos')]);

      final resolved = registry.resolve();
      expect(resolved.map((c) => c.id).toList(), ['a', 'b']);
    });

    test('resolve NO filtra comandos con isAvailable == false — siguen '
        'apareciendo (el overlay los pinta deshabilitados, no los oculta)', () {
      final registry = PaletteCommandRegistry(
        providers: [
          () => [
            PaletteCommand(
              id: 'a',
              label: 'Disponible',
              icon: Icons.abc,
              category: PaletteCommandCategory.navigation,
              execute: () {},
            ),
            PaletteCommand(
              id: 'b',
              label: 'No disponible',
              icon: Icons.abc,
              category: PaletteCommandCategory.navigation,
              execute: () {},
              isAvailable: () => false,
            ),
          ],
        ],
      );
      final resolved = registry.resolve();
      expect(resolved.map((c) => c.id).toList(), ['a', 'b']);
      expect(resolved.firstWhere((c) => c.id == 'b').isCurrentlyAvailable, isFalse);
    });

    test('isCurrentlyAvailable se re-evalúa en cada llamada a resolve '
        '(no se congela en el momento de registro)', () {
      var flag = false;
      final registry = PaletteCommandRegistry(
        providers: [
          () => [
            PaletteCommand(
              id: 'a',
              label: 'Dinámico',
              icon: Icons.abc,
              category: PaletteCommandCategory.navigation,
              execute: () {},
              isAvailable: () => flag,
            ),
          ],
        ],
      );
      expect(registry.resolve().single.isCurrentlyAvailable, isFalse);
      flag = true;
      expect(registry.resolve().single.isCurrentlyAvailable, isTrue);
    });
  });
}
