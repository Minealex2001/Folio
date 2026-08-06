import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../selectable.dart';

/// Sección "color y opacidad" del inspector — solo aplica a instancias de
/// widget (Fase 5); los paneles no tienen color propio, así que
/// [Selectable.colorArgb]/[Selectable.opacity] son siempre null para ellos
/// y esta sección no debería montarse (el caller decide con
/// `selectable.kind`, ver `PropertyInspectorPanel`).
class ColorOpacityEditor extends StatelessWidget {
  const ColorOpacityEditor({super.key, required this.selectable});

  final Selectable selectable;

  static const List<int> _presetSwatches = [
    0xFFF44336,
    0xFFFF9800,
    0xFFFFEB3B,
    0xFF4CAF50,
    0xFF2196F3,
    0xFF9C27B0,
    0xFF607D8B,
  ];

  @override
  Widget build(BuildContext context) {
    final currentColor = selectable.colorArgb;
    final currentOpacity = selectable.opacity ?? 1.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(AppLocalizations.of(context).inspectorColor, style: Theme.of(context).textTheme.titleSmall),
            ),
            if (currentColor != null)
              TextButton(
                onPressed: () => selectable.setColorArgb(null),
                child: Text(AppLocalizations.of(context).inspectorReset),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final argb in _presetSwatches)
              _Swatch(
                argb: argb,
                selected: currentColor == argb,
                onTap: () => selectable.setColorArgb(argb),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Text(AppLocalizations.of(context).inspectorOpacity, style: Theme.of(context).textTheme.titleSmall),
        Slider(
          value: currentOpacity.clamp(0.0, 1.0),
          onChanged: (v) => selectable.setOpacity(v),
          label: '${(currentOpacity * 100).round()}%',
        ),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.argb, required this.selected, required this.onTap});

  final int argb;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: Color(argb),
          shape: BoxShape.circle,
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Colors.transparent,
            width: 2,
          ),
        ),
      ),
    );
  }
}
