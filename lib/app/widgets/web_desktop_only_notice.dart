import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/generated/app_localizations.dart';

/// Fila que sustituye a una función no disponible en la versión web: explica
/// que solo existe en la app de escritorio y enlaza a su descarga.
///
/// Reutiliza el mismo destino que el botón de descarga de la sidebar
/// (`https://minealexgames.com/folio`).
class WebDesktopOnlyNotice extends StatelessWidget {
  const WebDesktopOnlyNotice({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  static const _downloadUrl = 'https://minealexgames.com/folio';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(icon, color: scheme.onSurfaceVariant),
      title: Text(title),
      subtitle: Text(subtitle ?? l10n.webDesktopOnlyNotice),
      trailing: TextButton.icon(
        onPressed: () => launchUrl(
          Uri.parse(_downloadUrl),
          mode: LaunchMode.externalApplication,
        ),
        icon: const Icon(Icons.download_rounded, size: 18),
        label: Text(l10n.downloadDesktopApp),
      ),
    );
  }
}
