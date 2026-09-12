part of 'package:folio/features/workspace/editor/block_editor.dart';

/// Fase F1 del rediseño UX del editor — identidad visual de bloques
/// especiales (código, mermaid, base de datos, nota de reunión): cada uno
/// gana un acento distintivo (icono + franja de color + etiqueta) en vez de
/// mezclarse visualmente entre sí, tal y como ya ocurre con los callouts
/// (Fase A2). Reutiliza literalmente la resolución de color de
/// `CalloutStylePreset`/`calloutXForTone` en vez de inventar un sistema de
/// theming nuevo por-tipo — cada tipo especial se mapea a un
/// `BlockCalloutTone` fijo elegido para que se distingan entre sí, no por
/// significado semántico literal del tono. "Chart" queda fuera de alcance
/// (no existe como tipo de bloque, verificado antes de este plan).
BlockCalloutTone? _blockAccentToneFor(String blockType) {
  switch (blockType) {
    case 'code':
      return BlockCalloutTone.neutral;
    case 'mermaid':
      return BlockCalloutTone.info;
    case 'database':
      return BlockCalloutTone.success;
    case 'meeting_note':
      return BlockCalloutTone.warning;
    default:
      return null;
  }
}

IconData _blockAccentIconFor(String blockType) {
  switch (blockType) {
    case 'code':
      return Icons.code_rounded;
    case 'mermaid':
      return Icons.schema_outlined;
    case 'database':
      return Icons.table_chart_outlined;
    case 'meeting_note':
      return Icons.meeting_room_outlined;
    default:
      return Icons.widgets_outlined;
  }
}

/// Cabecera pequeña icono+etiqueta con el mismo lenguaje visual que un
/// callout (chip vía `calloutChipForTone`/`calloutBorderForTone`) — no un
/// widget de identidad nuevo desde cero.
Widget _blockAccentHeader(
  BuildContext context,
  ColorScheme scheme,
  CalloutStylePreset preset, {
  required BlockCalloutTone tone,
  required IconData icon,
  required String label,
}) {
  final chipColor = calloutChipForTone(scheme, tone, preset: preset);
  final borderColor = calloutBorderForTone(scheme, tone, preset: preset);
  return Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: chipColor,
            borderRadius: BorderRadius.circular(6),
            border: preset.showBorder ? Border.all(color: borderColor) : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (preset.showIcon) ...[
                Icon(icon, size: 13, color: scheme.onSurface),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                  color: scheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// Franja de color a la izquierda del contenido — el acento principal, más
/// sutil que la cabecera. Envuelve [child] sin alterar su padding interno.
Widget _blockAccentStripe(
  ColorScheme scheme,
  CalloutStylePreset preset,
  BlockCalloutTone tone, {
  required Widget child,
}) {
  final stripeColor = calloutBorderForTone(scheme, tone, preset: preset);
  return Container(
    decoration: BoxDecoration(
      border: Border(
        left: BorderSide(
          color: preset.showBorder ? stripeColor : Colors.transparent,
          width: 3,
        ),
      ),
    ),
    padding: const EdgeInsetsDirectional.only(start: 10),
    child: child,
  );
}
