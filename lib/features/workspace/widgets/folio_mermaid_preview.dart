import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';

/// Construye la URL PNG del servicio [mermaid.ink](https://mermaid.ink) (el diagrama sale del dispositivo).
///
/// El formato debe coincidir con [Mermaid Live Editor](https://github.com/mermaid-js/mermaid-live-editor):
/// JSON del estado (`code` + config `mermaid`, etc.), comprimido con **zlib** (no deflate crudo),
/// codificado en base64url, y ruta `.../img/pako:<payload>` (véase la documentación de mermaid.ink).
Uri? folioMermaidInkImageUri(String source) {
  final t = source.trim();
  if (t.isEmpty) return null;
  try {
    final state = <String, Object?>{
      'code': t,
      'grid': true,
      'mermaid': '{\n  "theme": "default"\n}',
      'panZoom': true,
      'rough': false,
      'updateDiagram': true,
    };
    final payload = jsonEncode(state);
    final compressed = const ZLibEncoder().encode(
      utf8.encode(payload),
      level: 9,
    );
    var b64 = base64Url.encode(compressed);
    while (b64.endsWith('=')) {
      b64 = b64.substring(0, b64.length - 1);
    }
    return Uri.parse(
      'https://mermaid.ink/img/pako:$b64?type=png&bgColor=!white',
    );
  } catch (_) {
    return null;
  }
}

void _showFolioMermaidExpanded(BuildContext context, String imageUrl) {
  showDialog<void>(
    context: context,
    builder: (ctx) {
      return Dialog.fullscreen(
        backgroundColor: Colors.white,
        child: Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black87,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            title: const Text('Diagrama'),
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(ctx).pop(),
              tooltip: MaterialLocalizations.of(ctx).closeButtonTooltip,
            ),
          ),
          body: InteractiveViewer(
            boundaryMargin: const EdgeInsets.all(160),
            minScale: 0.25,
            maxScale: 5,
            child: Center(
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.medium,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const Padding(
                    padding: EdgeInsets.all(48),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'No se pudo mostrar el diagrama ampliado.',
                      style: Theme.of(ctx).textTheme.bodyLarge?.copyWith(
                            color: Colors.black54,
                          ),
                      textAlign: TextAlign.center,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
    },
  );
}

/// Vista previa de un diagrama Mermaid vía mermaid.ink como imagen PNG (requiere red).
class FolioMermaidPreview extends StatelessWidget {
  const FolioMermaidPreview({
    super.key,
    required this.source,
    this.maxHeight = 360,
  });

  final String source;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final mono = theme.textTheme.bodySmall?.copyWith(
      fontFamily: 'monospace',
      height: 1.35,
    );
    final uri = folioMermaidInkImageUri(source);
    if (uri == null) {
      return SelectableText(
        source.isEmpty ? '…' : source,
        style: mono,
      );
    }
    final url = uri.toString();
    return Semantics(
      label: 'Diagrama Mermaid, toca para ampliar',
      button: true,
      child: Tooltip(
        message:
            'Toca para ampliar y hacer zoom. PNG vía mermaid.ink (servicio externo).',
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Material(
            color: Colors.white,
            child: InkWell(
              onTap: () => _showFolioMermaidExpanded(context, url),
              child: Stack(
                alignment: Alignment.topRight,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: Image.network(
                      url,
                      height: maxHeight,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.medium,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return SizedBox(
                          height: maxHeight * 0.5,
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                value: loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                    : null,
                              ),
                            ),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.broken_image_outlined,
                                color: scheme.error,
                                size: 28,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'No se pudo mostrar el diagrama. Comprueba la sintaxis Mermaid o la conexión.',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(6),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(
                          Icons.zoom_out_map,
                          size: 18,
                          color: Colors.black45,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
