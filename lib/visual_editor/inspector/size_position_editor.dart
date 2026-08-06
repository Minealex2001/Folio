import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../selectable.dart';
import 'inspector_number_field.dart';

/// Sección "tamaño y posición" del inspector — siempre visible (todo
/// [Selectable] soporta tamaño); la fila de posición solo aparece cuando
/// el elemento tiene coordenadas libres (paneles flotantes).
class SizePositionEditor extends StatelessWidget {
  const SizePositionEditor({super.key, required this.selectable});

  final Selectable selectable;

  @override
  Widget build(BuildContext context) {
    final hasPosition = selectable.x != null || selectable.y != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(AppLocalizations.of(context).inspectorSize, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: InspectorNumberField(
                label: 'Ancho',
                value: selectable.width,
                onChanged: (v) => selectable.setSize(width: v),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: InspectorNumberField(
                label: 'Alto',
                value: selectable.height,
                onChanged: (v) => selectable.setSize(height: v),
              ),
            ),
          ],
        ),
        if (hasPosition) ...[
          const SizedBox(height: 12),
          Text(AppLocalizations.of(context).inspectorPosition, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: InspectorNumberField(
                  label: 'X',
                  value: selectable.x,
                  onChanged: (v) =>
                      selectable.setPosition(x: v, y: selectable.y ?? 0),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InspectorNumberField(
                  label: 'Y',
                  value: selectable.y,
                  onChanged: (v) =>
                      selectable.setPosition(x: selectable.x ?? 0, y: v),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
