import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../l10n/generated/app_localizations.dart';

/// Extrae el id de vídeo de URLs conocidas de YouTube; si no aplica, `null`.
String? folioYoutubeVideoIdFromUrl(String? raw) {
  if (raw == null) return null;
  final u = raw.trim();
  if (u.isEmpty) return null;
  final uri = Uri.tryParse(u);
  if (uri == null || !uri.hasScheme) return null;
  if (uri.scheme != 'http' && uri.scheme != 'https') return null;
  final host = uri.host.toLowerCase();
  if (host == 'youtu.be') {
    final seg = uri.pathSegments;
    if (seg.isEmpty) return null;
    final id = seg.first.split('&').first;
    return id.isEmpty ? null : id;
  }
  if (host.endsWith('youtube.com') || host == 'youtube.com') {
    if (uri.pathSegments.isNotEmpty && uri.pathSegments.first == 'embed') {
      if (uri.pathSegments.length < 2) return null;
      return uri.pathSegments[1].split('&').first;
    }
    final v = uri.queryParameters['v'];
    if (v != null && v.isNotEmpty) return v.split('&').first;
  }
  return null;
}

String folioYoutubeThumbnailUrl(String videoId) =>
    'https://img.youtube.com/vi/$videoId/hqdefault.jpg';

/// Tarjeta compacta para bloque vídeo o enlaces: miniatura + abrir en navegador.
class FolioYoutubePreviewCard extends StatelessWidget {
  const FolioYoutubePreviewCard({
    super.key,
    required this.pageUrl,
    required this.videoId,
    required this.scheme,
    this.compact = false,
  });

  final String pageUrl;
  final String videoId;
  final ColorScheme scheme;
  final bool compact;

  Future<void> _open() async {
    final u = Uri.tryParse(pageUrl.trim());
    if (u != null) {
      await launchUrl(u, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final thumb = folioYoutubeThumbnailUrl(videoId);
    final h = compact ? 120.0 : 160.0;
    return Material(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _open,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Image.network(
                  thumb,
                  height: h,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => SizedBox(
                    height: h,
                    child: Center(
                      child: Icon(
                        Icons.play_circle_outline_rounded,
                        size: 48,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                Icon(
                  Icons.play_circle_fill_rounded,
                  size: compact ? 44 : 56,
                  color: Colors.white.withValues(alpha: 0.92),
                  shadows: const [
                    Shadow(blurRadius: 8, color: Colors.black54),
                  ],
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.open_in_new_rounded, size: 18, color: scheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context).openInYoutubeBrowser,
                      style: TextStyle(
                        color: scheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
