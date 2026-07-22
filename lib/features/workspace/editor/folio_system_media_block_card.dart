import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../services/media/system_media_block.dart';

/// Tarjeta de bloque `systemMedia` (pista capturada del Now Playing del SO).
class FolioSystemMediaBlockCard extends StatelessWidget {
  const FolioSystemMediaBlockCard({
    super.key,
    required this.text,
    required this.scheme,
  });

  final String text;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final payload = decodeSystemMediaBlockText(text);
    final title = '${payload['title'] ?? ''}'.trim();
    final artist = '${payload['artist'] ?? ''}'.trim();
    final appName = '${payload['appName'] ?? ''}'.trim();

    final displayTitle =
        title.isNotEmpty ? title : l10n.systemMediaBlockEmptyHint;
    final subtitleParts = <String>[
      if (artist.isNotEmpty) artist,
      if (appName.isNotEmpty) appName,
    ];

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: ColoredBox(
              color: scheme.surfaceContainerHighest,
              child: const SizedBox(
                width: 72,
                height: 72,
                child: Center(
                  child: Icon(Icons.album_rounded, size: 32),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.album_rounded,
                      size: 16,
                      color: scheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        l10n.systemMediaIntegrationTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  displayTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitleParts.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitleParts.join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
