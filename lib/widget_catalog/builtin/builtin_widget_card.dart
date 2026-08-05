import 'package:flutter/material.dart';

/// Chrome compartido por los plugins built-in del catálogo (Fase 4/8): una
/// tarjeta con icono + título + contenido. No es parte del contrato de
/// [FolioWidgetPlugin] — cada plugin es libre de construir lo que quiera en
/// `build()`; esto solo evita repetir el mismo `Card`/`Padding`/`Column` en
/// ~20 archivos.
class BuiltinWidgetCard extends StatelessWidget {
  const BuiltinWidgetCard({
    super.key,
    required this.icon,
    required this.title,
    required this.child,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: scheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 8),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

/// Empty state con datos reales ausentes (sin tareas, sin pistas, etc.).
class BuiltinWidgetEmpty extends StatelessWidget {
  const BuiltinWidgetEmpty({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Estado "feature no disponible todavía" — integración externa o modelo
/// que Folio no trae de fábrica. Distinto de [BuiltinWidgetEmpty].
class BuiltinWidgetComingSoon extends StatelessWidget {
  const BuiltinWidgetComingSoon({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
