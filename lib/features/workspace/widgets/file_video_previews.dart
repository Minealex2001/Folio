import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:video_player/video_player.dart';

import 'folio_text_format.dart';

const int _kPreviewMaxChars = 120000;

class FolioEmbeddedVideoPlayer extends StatefulWidget {
  const FolioEmbeddedVideoPlayer({
    super.key,
    required this.file,
    required this.scheme,
    required this.onOpenExternal,
  });

  final File file;
  final ColorScheme scheme;
  final Future<void> Function() onOpenExternal;

  @override
  State<FolioEmbeddedVideoPlayer> createState() => _FolioEmbeddedVideoPlayerState();
}

class _FolioEmbeddedVideoPlayerState extends State<FolioEmbeddedVideoPlayer> {
  VideoPlayerController? _controller;
  String? _error;
  bool _muted = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void didUpdateWidget(covariant FolioEmbeddedVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.file.path != widget.file.path) {
      unawaited(_disposeController());
      _init();
    }
  }

  Future<void> _init() async {
    try {
      final controller = VideoPlayerController.file(widget.file);
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      controller.setLooping(false);
      setState(() {
        _controller = controller;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _controller = null;
        _error = 'No se pudo cargar el video';
      });
    }
  }

  Future<void> _disposeController() async {
    final c = _controller;
    _controller = null;
    if (c != null) {
      await c.dispose();
    }
  }

  @override
  void dispose() {
    unawaited(_disposeController());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    if (_error != null) {
      return _VideoFallback(
        scheme: widget.scheme,
        title: _error!,
        onOpenExternal: widget.onOpenExternal,
      );
    }
    if (c == null || !c.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(
          color: Colors.black,
          child: FittedBox(
            fit: BoxFit.contain,
            child: SizedBox(
              width: c.value.size.width,
              height: c.value.size.height,
              child: VideoPlayer(c),
            ),
          ),
        ),
        Positioned(
          left: 8,
          right: 8,
          bottom: 8,
          child: Material(
            color: Colors.black.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  IconButton(
                    tooltip: c.value.isPlaying ? 'Pausar' : 'Reproducir',
                    onPressed: () {
                      if (c.value.isPlaying) {
                        c.pause();
                      } else {
                        c.play();
                      }
                      setState(() {});
                    },
                    icon: Icon(
                      c.value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: Colors.white,
                    ),
                  ),
                  Expanded(
                    child: VideoProgressIndicator(
                      c,
                      allowScrubbing: true,
                      colors: VideoProgressColors(
                        playedColor: widget.scheme.primary,
                        bufferedColor: Colors.white54,
                        backgroundColor: Colors.white24,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: _muted ? 'Activar sonido' : 'Silenciar',
                    onPressed: () {
                      _muted = !_muted;
                      c.setVolume(_muted ? 0 : 1);
                      setState(() {});
                    },
                    icon: Icon(
                      _muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                      color: Colors.white,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Abrir externo',
                    onPressed: () => unawaited(widget.onOpenExternal()),
                    icon: const Icon(Icons.open_in_new_rounded, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class FolioFilePreviewCard extends StatelessWidget {
  const FolioFilePreviewCard({
    super.key,
    required this.file,
    required this.theme,
    required this.scheme,
    required this.onOpenExternal,
    required this.onReplace,
    required this.onClear,
  });

  final File file;
  final ThemeData theme;
  final ColorScheme scheme;
  final Future<void> Function() onOpenExternal;
  final VoidCallback onReplace;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final ext = p.extension(file.path).toLowerCase();
    final fileName = p.basename(file.path);
    final canPreviewText = {'.txt', '.md', '.json'}.contains(ext);
    final canPreviewPdf = ext == '.pdf' && _supportsEmbeddedPdfPreview;

    Widget preview;
    if (canPreviewPdf) {
      preview = _PdfPreview(file: file, scheme: scheme);
    } else if (canPreviewText) {
      preview = _TextLikePreview(file: file, ext: ext, theme: theme, scheme: scheme);
    } else {
      preview = _UnsupportedPreview(theme: theme, scheme: scheme, fileName: fileName);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.insert_drive_file_outlined, color: scheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                fileName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium,
              ),
            ),
            TextButton.icon(
              onPressed: () => unawaited(onOpenExternal()),
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: const Text('Abrir'),
            ),
            TextButton(
              onPressed: onReplace,
              child: const Text('Cambiar'),
            ),
            TextButton(
              onPressed: onClear,
              child: const Text('Quitar'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: scheme.surfaceContainer.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
            ),
            clipBehavior: Clip.antiAlias,
            child: preview,
          ),
        ),
      ],
    );
  }
}

bool get _supportsEmbeddedPdfPreview {
  if (kIsWeb) return false;
  return Platform.isAndroid || Platform.isIOS || Platform.isMacOS;
}

class _PdfPreview extends StatefulWidget {
  const _PdfPreview({required this.file, required this.scheme});

  final File file;
  final ColorScheme scheme;

  @override
  State<_PdfPreview> createState() => _PdfPreviewState();
}

class _PdfPreviewState extends State<_PdfPreview> {
  String? _error;

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            _error!,
            textAlign: TextAlign.center,
            style: TextStyle(color: widget.scheme.error),
          ),
        ),
      );
    }
    return SfPdfViewer.file(
      widget.file,
      onDocumentLoadFailed: (details) {
        if (!mounted) return;
        setState(() {
          _error = 'No se pudo previsualizar el PDF';
        });
      },
    );
  }
}

class _TextLikePreview extends StatelessWidget {
  const _TextLikePreview({
    required this.file,
    required this.ext,
    required this.theme,
    required this.scheme,
  });

  final File file;
  final String ext;
  final ThemeData theme;
  final ColorScheme scheme;

  Future<String> _readText() async {
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) return '';
    final decoded = utf8.decode(bytes, allowMalformed: true);
    if (decoded.length > _kPreviewMaxChars) {
      return '${decoded.substring(0, _kPreviewMaxChars)}\n\n… (vista previa recortada)';
    }
    return decoded;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _readText(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(
            child: Text(
              'No se pudo leer el archivo',
              style: theme.textTheme.bodyMedium?.copyWith(color: scheme.error),
            ),
          );
        }
        final raw = snap.data ?? '';
        if (ext == '.md') {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: FolioMarkdownPreview(
              data: raw,
              styleSheet: folioMarkdownStyleSheet(context, theme.textTheme.bodyMedium!, scheme),
            ),
          );
        }
        String shown = raw;
        if (ext == '.json') {
          try {
            final parsed = jsonDecode(raw);
            shown = const JsonEncoder.withIndent('  ').convert(parsed);
          } catch (_) {
            shown = raw;
          }
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: SelectableText(
            shown,
            style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace', height: 1.45),
          ),
        );
      },
    );
  }
}

class _UnsupportedPreview extends StatelessWidget {
  const _UnsupportedPreview({
    required this.theme,
    required this.scheme,
    required this.fileName,
  });

  final ThemeData theme;
  final ColorScheme scheme;
  final String fileName;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.preview_outlined, size: 36, color: scheme.onSurfaceVariant),
            const SizedBox(height: 8),
            Text(
              'Sin preview embebido para este tipo',
              style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 4),
            Text(
              fileName,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _VideoFallback extends StatelessWidget {
  const _VideoFallback({
    required this.scheme,
    required this.title,
    required this.onOpenExternal,
  });

  final ColorScheme scheme;
  final String title;
  final Future<void> Function() onOpenExternal;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.videocam_off_outlined, size: 42, color: scheme.onSurfaceVariant),
          const SizedBox(height: 8),
          Text(title),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => unawaited(onOpenExternal()),
            icon: const Icon(Icons.open_in_new_rounded),
            label: const Text('Abrir video externo'),
          ),
        ],
      ),
    );
  }
}
