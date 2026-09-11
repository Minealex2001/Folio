import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../selectable.dart';
import 'inspector_number_field.dart';

/// Sección "radio de esquina" del inspector — override a nivel de
/// instancia (`WidgetInstanceConfig.settings['cornerRadiusOverride']`), no
/// del `ThemeConfig.shape` global (ver `WidgetInstanceSelectable`).
class CornerRadiusEditor extends StatelessWidget {
  const CornerRadiusEditor({super.key, required this.selectable});

  final Selectable selectable;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Radio de esquina',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            if (selectable.cornerRadius != null)
              TextButton(
                onPressed: () => selectable.setCornerRadius(null),
                child: Text(AppLocalizations.of(context).inspectorReset),
              ),
          ],
        ),
        const SizedBox(height: 8),
        InspectorNumberField(
          label: 'Radio',
          value: selectable.cornerRadius ?? 0,
          onChanged: (v) => selectable.setCornerRadius(v),
        ),
      ],
    );
  }
}
