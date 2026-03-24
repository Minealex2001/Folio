import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

import '../../../models/block.dart';
import '../../../models/folio_page.dart';
import '../../../models/folio_columns_data.dart';
import '../../../models/folio_template_button_data.dart';
import '../../../models/folio_toggle_data.dart';
import '../../../session/vault_session.dart';

/// Reproductor compacto para bloques de audio (adjunto local).
class FolioAudioBlockPlayer extends StatefulWidget {
  const FolioAudioBlockPlayer({
    super.key,
    required this.file,
    required this.scheme,
  });

  final File file;
  final ColorScheme scheme;

  @override
  State<FolioAudioBlockPlayer> createState() => _FolioAudioBlockPlayerState();
}

class _FolioAudioBlockPlayerState extends State<FolioAudioBlockPlayer> {
  final AudioPlayer _player = AudioPlayer();
  var _playing = false;
  Duration _pos = Duration.zero;
  Duration _dur = Duration.zero;

  @override
  void initState() {
    super.initState();
    _bind();
  }

  Future<void> _bind() async {
    await _player.setSource(DeviceFileSource(widget.file.path));
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playing = false);
    });
    _player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _dur = d);
    });
    _player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _pos = p);
    });
  }

  @override
  void dispose() {
    unawaited(_player.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        IconButton.filledTonal(
          onPressed: () async {
            if (_playing) {
              await _player.pause();
              if (mounted) setState(() => _playing = false);
            } else {
              if (_pos == Duration.zero) {
                await _player.play(DeviceFileSource(widget.file.path));
              } else {
                await _player.resume();
              }
              if (mounted) setState(() => _playing = true);
            }
          },
          icon: Icon(_playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.file.path.split(Platform.pathSeparator).last,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
              if (_dur > Duration.zero)
                Slider(
                  value: _pos.inMilliseconds.clamp(0, _dur.inMilliseconds)
                      .toDouble(),
                  max: _dur.inMilliseconds.toDouble(),
                  onChanged: (v) async {
                    await _player.seek(Duration(milliseconds: v.round()));
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ignore: avoid_classes_with_only_static_members
class FolioEquationPreview extends StatelessWidget {
  const FolioEquationPreview({
    super.key,
    required this.latex,
    required this.textStyle,
    required this.scheme,
  });

  final String latex;
  final TextStyle? textStyle;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final t = latex.trim();
    if (t.isEmpty) {
      return Text(
        'LaTeX…',
        style: textStyle?.copyWith(color: scheme.onSurfaceVariant),
      );
    }
    try {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Math.tex(
          t,
          textStyle: textStyle,
        ),
      );
    } catch (_) {
      return Text(
        t,
        style: textStyle?.copyWith(color: scheme.error),
      );
    }
  }
}

class FolioToggleBlockBody extends StatefulWidget {
  const FolioToggleBlockBody({
    super.key,
    required this.pageId,
    required this.block,
    required this.session,
    required this.colorScheme,
    required this.textTheme,
  });

  final String pageId;
  final FolioBlock block;
  final VaultSession session;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  @override
  State<FolioToggleBlockBody> createState() => _FolioToggleBlockBodyState();
}

class _FolioToggleBlockBodyState extends State<FolioToggleBlockBody> {
  late TextEditingController _title;
  late TextEditingController _body;

  @override
  void initState() {
    super.initState();
    final d =
        FolioToggleData.tryParse(widget.block.text) ?? FolioToggleData.empty();
    _title = TextEditingController(text: d.title);
    _body = TextEditingController(text: d.body);
  }

  @override
  void didUpdateWidget(covariant FolioToggleBlockBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.block.text != widget.block.text) {
      final d =
          FolioToggleData.tryParse(widget.block.text) ?? FolioToggleData.empty();
      if (_title.text != d.title) _title.text = d.title;
      if (_body.text != d.body) _body.text = d.body;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  void _emit() {
    final enc = FolioToggleData(title: _title.text, body: _body.text).encode();
    widget.session.updateBlockText(widget.pageId, widget.block.id, enc);
  }

  @override
  Widget build(BuildContext context) {
    final open = widget.block.expanded ?? false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              onPressed: () {
                widget.session.setBlockExpanded(
                  widget.pageId,
                  widget.block.id,
                  !open,
                );
              },
              icon: Icon(
                open ? Icons.expand_more_rounded : Icons.chevron_right_rounded,
              ),
            ),
            Expanded(
              child: TextField(
                controller: _title,
                style: widget.textTheme.bodyLarge,
                decoration: const InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: 'Título del desplegable',
                ),
                onChanged: (_) => _emit(),
              ),
            ),
          ],
        ),
        if (open) ...[
          const SizedBox(height: 6),
          TextField(
            controller: _body,
            minLines: 2,
            maxLines: 8,
            style: widget.textTheme.bodyMedium,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Contenido…',
              isDense: true,
            ),
            onChanged: (_) => _emit(),
          ),
        ],
      ],
    );
  }
}

class FolioTocBlockBody extends StatelessWidget {
  const FolioTocBlockBody({
    super.key,
    required this.pageId,
    required this.blocks,
    required this.session,
    required this.scheme,
    required this.textTheme,
  });

  final String pageId;
  final List<FolioBlock> blocks;
  final VaultSession session;
  final ColorScheme scheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    final entries = <({String id, String text, int level})>[];
    for (final b in blocks) {
      final level = switch (b.type) {
        'h1' => 1,
        'h2' => 2,
        'h3' => 3,
        _ => 0,
      };
      if (level == 0) continue;
      final t = b.text.trim();
      if (t.isEmpty) continue;
      entries.add((id: b.id, text: t, level: level));
    }
    if (entries.isEmpty) {
      return Text(
        'Añade encabezados (H1–H3) para generar el índice.',
        style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Tabla de contenidos',
          style: textTheme.labelLarge?.copyWith(color: scheme.primary),
        ),
        const SizedBox(height: 8),
        ...entries.map((e) {
          final pad = 12.0 * (e.level - 1);
          return InkWell(
            onTap: () => session.requestScrollToBlock(e.id),
            child: Padding(
              padding: EdgeInsetsDirectional.only(start: pad, top: 4, bottom: 4),
              child: Text(
                e.text,
                style: textTheme.bodyMedium?.copyWith(
                  color: scheme.primary,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}

class FolioBreadcrumbBlockBody extends StatelessWidget {
  const FolioBreadcrumbBlockBody({
    super.key,
    required this.pageId,
    required this.session,
    required this.scheme,
    required this.textTheme,
  });

  final String pageId;
  final VaultSession session;
  final ColorScheme scheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    FolioPage? byId(String id) {
      try {
        return session.pages.firstWhere((p) => p.id == id);
      } catch (_) {
        return null;
      }
    }

    final chain = <FolioPage>[];
    String? curId = pageId;
    while (curId != null) {
      final p = byId(curId);
      if (p == null) break;
      chain.add(p);
      curId = p.parentId;
    }
    final ordered = chain.reversed.toList();
    if (ordered.isEmpty) {
      return const SizedBox.shrink();
    }
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (var i = 0; i < ordered.length; i++) ...[
          if (i > 0)
            Icon(
              Icons.chevron_right_rounded,
              size: 16,
              color: scheme.onSurfaceVariant,
            ),
          TextButton(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: () => session.selectPage(ordered[i].id),
            child: Text(
              ordered[i].title,
              style: textTheme.bodySmall?.copyWith(color: scheme.primary),
            ),
          ),
        ],
      ],
    );
  }
}

class FolioColumnListBlockBody extends StatefulWidget {
  const FolioColumnListBlockBody({
    super.key,
    required this.pageId,
    required this.block,
    required this.session,
    required this.scheme,
    required this.textTheme,
  });

  final String pageId;
  final FolioBlock block;
  final VaultSession session;
  final ColorScheme scheme;
  final TextTheme textTheme;

  @override
  State<FolioColumnListBlockBody> createState() =>
      _FolioColumnListBlockBodyState();
}

class _FolioColumnListBlockBodyState extends State<FolioColumnListBlockBody> {
  late List<TextEditingController> _cols;

  @override
  void initState() {
    super.initState();
    final d =
        FolioColumnsData.tryParse(widget.block.text) ?? FolioColumnsData.empty();
    _cols = d.columns.map((c) => TextEditingController(text: c)).toList();
  }

  @override
  void didUpdateWidget(covariant FolioColumnListBlockBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.block.text != widget.block.text) {
      final d = FolioColumnsData.tryParse(widget.block.text) ??
          FolioColumnsData.empty();
      for (final c in _cols) {
        c.dispose();
      }
      _cols = d.columns.map((c) => TextEditingController(text: c)).toList();
    }
  }

  @override
  void dispose() {
    for (final c in _cols) {
      c.dispose();
    }
    super.dispose();
  }

  void _emit() {
    final data = FolioColumnsData(
      columns: _cols.map((c) => c.text).toList(),
    );
    widget.session.updateBlockText(
      widget.pageId,
      widget.block.id,
      data.encode(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < _cols.length; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _cols[i],
              minLines: 3,
              maxLines: 12,
              style: widget.textTheme.bodyMedium,
              decoration: InputDecoration(
                labelText: 'Columna ${i + 1}',
                border: const OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              onChanged: (_) => _emit(),
            ),
          ),
        ],
      ],
    );
  }
}

class FolioTemplateButtonBlockBody extends StatelessWidget {
  const FolioTemplateButtonBlockBody({
    super.key,
    required this.pageId,
    required this.block,
    required this.session,
    required this.scheme,
    required this.textTheme,
  });

  final String pageId;
  final FolioBlock block;
  final VaultSession session;
  final ColorScheme scheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    final data = FolioTemplateButtonData.tryParse(block.text) ??
        FolioTemplateButtonData.defaultNew();
    return Align(
      alignment: Alignment.centerLeft,
      child: FilledButton.tonalIcon(
        onPressed: () => session.insertTemplateFromButton(
          pageId: pageId,
          templateBlockId: block.id,
        ),
        icon: const Icon(Icons.post_add_rounded),
        label: Text(data.label.isEmpty ? 'Plantilla' : data.label),
      ),
    );
  }
}
