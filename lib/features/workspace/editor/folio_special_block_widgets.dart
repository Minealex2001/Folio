import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:uuid/uuid.dart';

import '../../../app/ui_tokens.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../history/page_outline.dart';
import '../../../models/block.dart';
import '../../../models/folio_page.dart';
import '../../../models/folio_columns_data.dart';
import '../../../models/folio_task_data.dart';
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
  Timer? _progressTimer;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    await _player.setSource(DeviceFileSource(widget.file.path));
    final duration = await _player.getDuration();
    if (mounted && duration != null) {
      setState(() => _dur = duration);
    }
  }

  void _startPollingProgress() {
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(milliseconds: 250), (
      _,
    ) async {
      final pos = await _player.getCurrentPosition();
      final dur = await _player.getDuration();
      if (!mounted) return;
      setState(() {
        if (pos != null) _pos = pos;
        if (dur != null) _dur = dur;
        if (_dur > Duration.zero && _pos >= _dur) {
          _playing = false;
          _progressTimer?.cancel();
        }
      });
    });
  }

  void _stopPollingProgress() {
    _progressTimer?.cancel();
    _progressTimer = null;
  }

  @override
  void dispose() {
    _stopPollingProgress();
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
              _stopPollingProgress();
              if (mounted) setState(() => _playing = false);
            } else {
              if (_pos == Duration.zero) {
                await _player.play(DeviceFileSource(widget.file.path));
              } else {
                await _player.resume();
              }
              _startPollingProgress();
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
                  value: _pos.inMilliseconds
                      .clamp(0, _dur.inMilliseconds)
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
        child: Math.tex(t, textStyle: textStyle),
      );
    } catch (_) {
      return Text(t, style: textStyle?.copyWith(color: scheme.error));
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
          FolioToggleData.tryParse(widget.block.text) ??
          FolioToggleData.empty();
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
    final l10n = AppLocalizations.of(context);
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
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: l10n.toggleTitleHint,
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
            decoration: InputDecoration(
              border: OutlineInputBorder(),
              hintText: l10n.toggleBodyHint,
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
    final l10n = AppLocalizations.of(context);
    final entries = pageOutlineEntriesFromBlocks(blocks);
    if (entries.isEmpty) {
      return Text(
        l10n.pageOutlineEmpty,
        style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.tocBlockTitle,
          style: textTheme.labelLarge?.copyWith(color: scheme.primary),
        ),
        const SizedBox(height: 8),
        ...entries.map((e) {
          final pad = 12.0 * (e.level - 1);
          return InkWell(
            onTap: () => session.requestScrollToBlock(e.id),
            child: Padding(
              padding: EdgeInsetsDirectional.only(
                start: pad,
                top: 4,
                bottom: 4,
              ),
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
    required this.showActions,
  });

  final String pageId;
  final FolioBlock block;
  final VaultSession session;
  final ColorScheme scheme;
  final TextTheme textTheme;
  final bool showActions;

  @override
  State<FolioColumnListBlockBody> createState() =>
      _FolioColumnListBlockBodyState();
}

class _FolioColumnListBlockBodyState extends State<FolioColumnListBlockBody> {
  static const _uuid = Uuid();
  static const _allowedTypes = <String>[
    'paragraph',
    'h1',
    'h2',
    'h3',
    'bullet',
    'numbered',
    'todo',
    'quote',
    'callout',
    'code',
    'equation',
    'divider',
  ];

  late FolioColumnsData _data;
  final Map<String, TextEditingController> _controllers = {};
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void didUpdateWidget(covariant FolioColumnListBlockBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.block.text != widget.block.text) {
      _bootstrap();
    }
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  void _disposeControllers() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();
  }

  void _bootstrap() {
    _data =
        FolioColumnsData.tryParse(widget.block.text) ??
        FolioColumnsData.empty();
    _syncControllers();
  }

  void _setEditing(bool value) {
    if (_editing == value) return;
    setState(() => _editing = value);
  }

  void _syncControllers() {
    final liveIds = <String>{};
    for (final column in _data.columns) {
      for (final block in column.blocks) {
        liveIds.add(block.id);
        final current = _controllers[block.id];
        if (current == null) {
          _controllers[block.id] = TextEditingController(text: block.text);
        } else if (current.text != block.text) {
          current.value = TextEditingValue(
            text: block.text,
            selection: TextSelection.collapsed(offset: block.text.length),
          );
        }
      }
    }
    final staleIds = _controllers.keys
        .where((id) => !liveIds.contains(id))
        .toList();
    for (final id in staleIds) {
      _controllers.remove(id)?.dispose();
    }
  }

  String _t(String es, String en) {
    return Localizations.localeOf(
          context,
        ).languageCode.toLowerCase().startsWith('es')
        ? es
        : en;
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'h1':
        return 'H1';
      case 'h2':
        return 'H2';
      case 'h3':
        return 'H3';
      case 'bullet':
        return _t('Lista', 'Bullets');
      case 'numbered':
        return _t('Numerada', 'Numbered');
      case 'todo':
        return _t('Tarea', 'Todo');
      case 'quote':
        return _t('Cita', 'Quote');
      case 'callout':
        return _t('Callout', 'Callout');
      case 'code':
        return _t('Código', 'Code');
      case 'equation':
        return _t('Ecuación', 'Equation');
      case 'divider':
        return _t('Divisor', 'Divider');
      default:
        return _t('Texto', 'Text');
    }
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'h1':
      case 'h2':
      case 'h3':
        return Icons.title_rounded;
      case 'bullet':
        return Icons.format_list_bulleted_rounded;
      case 'numbered':
        return Icons.format_list_numbered_rounded;
      case 'todo':
        return Icons.check_box_outlined;
      case 'quote':
        return Icons.format_quote_rounded;
      case 'callout':
        return Icons.campaign_outlined;
      case 'code':
        return Icons.code_rounded;
      case 'equation':
        return Icons.functions_rounded;
      case 'divider':
        return Icons.horizontal_rule_rounded;
      default:
        return Icons.notes_rounded;
    }
  }

  void _emit() {
    widget.session.updateBlockText(
      widget.pageId,
      widget.block.id,
      _data.encode(),
    );
  }

  void _setBlockText(FolioBlock block, String text) {
    block.text = text;
    _emit();
  }

  void _setBlockChecked(FolioBlock block, bool value) {
    block.checked = value;
    _emit();
    setState(() {});
  }

  void _changeBlockType(FolioBlock block, String type) {
    setState(() {
      block.type = type;
      if (type == 'todo') {
        block.checked ??= false;
      } else {
        block.checked = null;
      }
      if (type == 'divider') {
        block.text = '';
        _controllers[block.id]?.text = '';
      } else if ((type == 'code' || type == 'equation') &&
          _controllers[block.id]?.text.trim().isEmpty == true) {
        final seed = type == 'equation' ? r'E = mc^2' : '';
        block.text = seed;
        _controllers[block.id]?.text = seed;
      }
      _emit();
    });
  }

  void _addBlock(int columnIndex, {String type = 'paragraph'}) {
    setState(() {
      _data.columns[columnIndex].blocks.add(
        FolioBlock(
          id: 'col_${_uuid.v4()}',
          type: type,
          text: type == 'equation' ? r'E = mc^2' : '',
          checked: type == 'todo' ? false : null,
        ),
      );
      _syncControllers();
      _emit();
    });
  }

  void _removeBlock(int columnIndex, int blockIndex) {
    setState(() {
      final blocks = _data.columns[columnIndex].blocks;
      if (blocks.length == 1) {
        blocks[blockIndex] = FolioBlock(
          id: 'col_${_uuid.v4()}',
          type: 'paragraph',
          text: '',
        );
      } else {
        final removed = blocks.removeAt(blockIndex);
        _controllers.remove(removed.id)?.dispose();
      }
      _emit();
    });
  }

  void _addColumn() {
    if (_data.columns.length >= 3) return;
    setState(() {
      _data.columns.add(FolioColumnData.empty());
      _syncControllers();
      _emit();
    });
  }

  void _removeColumn(int columnIndex) {
    if (_data.columns.length <= 2) return;
    setState(() {
      final removed = _data.columns.removeAt(columnIndex);
      for (final block in removed.blocks) {
        _controllers.remove(block.id)?.dispose();
      }
      _emit();
    });
  }

  Widget _buildBlockEditor(FolioBlock block) {
    final controller = _controllers[block.id]!;
    final isCodeLike = block.type == 'code' || block.type == 'equation';
    if (block.type == 'divider') {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        child: Divider(color: widget.scheme.outlineVariant),
      );
    }
    if (block.type == 'todo') {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: block.checked ?? false,
            onChanged: (value) => _setBlockChecked(block, value ?? false),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 6,
              style: widget.textTheme.bodyMedium,
              decoration: InputDecoration(
                labelText: _t('Contenido', 'Content'),
                border: const OutlineInputBorder(),
              ),
              onChanged: (value) => _setBlockText(block, value),
            ),
          ),
        ],
      );
    }
    return TextField(
      controller: controller,
      minLines: isCodeLike ? 4 : 1,
      maxLines: isCodeLike ? 12 : 6,
      style: (block.type == 'h1')
          ? widget.textTheme.headlineSmall
          : (block.type == 'h2')
          ? widget.textTheme.titleLarge
          : (block.type == 'h3')
          ? widget.textTheme.titleMedium
          : isCodeLike
          ? widget.textTheme.bodyMedium?.copyWith(fontFamily: 'monospace')
          : widget.textTheme.bodyMedium,
      decoration: InputDecoration(
        labelText: _t('Contenido', 'Content'),
        border: const OutlineInputBorder(),
        alignLabelWithHint: isCodeLike,
      ),
      onChanged: (value) => _setBlockText(block, value),
    );
  }

  Widget _buildColumnBlockCard(
    int columnIndex,
    int blockIndex,
    FolioBlock block,
  ) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: widget.scheme.surface,
        borderRadius: BorderRadius.circular(FolioRadius.lg),
        border: Border.all(
          color: widget.scheme.outlineVariant.withValues(
            alpha: FolioAlpha.panel,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                _typeIcon(block.type),
                size: 18,
                color: widget.scheme.primary,
              ),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                onSelected: (value) => _changeBlockType(block, value),
                itemBuilder: (context) => _allowedTypes
                    .map(
                      (type) => PopupMenuItem<String>(
                        value: type,
                        child: Row(
                          children: [
                            Icon(_typeIcon(type), size: 18),
                            const SizedBox(width: 8),
                            Text(_typeLabel(type)),
                          ],
                        ),
                      ),
                    )
                    .toList(),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: widget.scheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(FolioRadius.xl),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _typeLabel(block.type),
                        style: widget.textTheme.labelLarge,
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_drop_down_rounded, size: 18),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: _t('Eliminar bloque', 'Remove block'),
                onPressed: () => _removeBlock(columnIndex, blockIndex),
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildBlockEditor(block),
        ],
      ),
    );
  }

  Widget _buildPreviewBlock(FolioBlock block, int index) {
    final base = widget.textTheme.bodyMedium?.copyWith(
      color: widget.scheme.onSurface,
      height: 1.35,
    );
    switch (block.type) {
      case 'h1':
        return Text(
          block.text.isEmpty ? 'H1' : block.text,
          style: widget.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        );
      case 'h2':
        return Text(
          block.text.isEmpty ? 'H2' : block.text,
          style: widget.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        );
      case 'h3':
        return Text(
          block.text.isEmpty ? 'H3' : block.text,
          style: widget.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        );
      case 'bullet':
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('• ', style: base),
            Expanded(child: Text(block.text, style: base)),
          ],
        );
      case 'numbered':
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${index + 1}. ', style: base),
            Expanded(child: Text(block.text, style: base)),
          ],
        );
      case 'todo':
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              block.checked == true
                  ? Icons.check_box_rounded
                  : Icons.check_box_outline_blank_rounded,
              size: 18,
              color: widget.scheme.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                block.text,
                style: base?.copyWith(
                  decoration: block.checked == true
                      ? TextDecoration.lineThrough
                      : TextDecoration.none,
                ),
              ),
            ),
          ],
        );
      case 'quote':
        return Container(
          padding: const EdgeInsets.only(left: 12),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: widget.scheme.outlineVariant, width: 3),
            ),
          ),
          child: Text(
            block.text,
            style: base?.copyWith(fontStyle: FontStyle.italic),
          ),
        );
      case 'callout':
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: widget.scheme.secondaryContainer.withValues(
              alpha: FolioAlpha.border,
            ),
            borderRadius: BorderRadius.circular(FolioRadius.lg),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.campaign_outlined,
                size: 18,
                color: widget.scheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(block.text, style: base)),
            ],
          ),
        );
      case 'code':
      case 'equation':
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: widget.scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(FolioRadius.lg),
          ),
          child: Text(
            block.text,
            style: widget.textTheme.bodySmall?.copyWith(
              fontFamily: 'monospace',
            ),
          ),
        );
      case 'divider':
        return Divider(color: widget.scheme.outlineVariant);
      default:
        return Text(block.text, style: base);
    }
  }

  Widget _buildPreviewColumn(int columnIndex) {
    final blocks = _data.columns[columnIndex].blocks;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: widget.scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(FolioRadius.xl),
        border: Border.all(
          color: widget.scheme.outlineVariant.withValues(
            alpha: FolioAlpha.track,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < blocks.length; i++) ...[
            _buildPreviewBlock(blocks[i], i),
            if (i < blocks.length - 1) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _syncControllers();
    return FocusScope(
      onFocusChange: (hasFocus) {
        if (!hasFocus) _setEditing(false);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: (_editing || widget.showActions)
                ? Row(
                    key: const ValueKey('columns_toolbar'),
                    children: [
                      Text(
                        _t('Columnas', 'Columns'),
                        style: widget.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      if (!_editing)
                        FilledButton.tonalIcon(
                          onPressed: () => _setEditing(true),
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          label: Text(_t('Editar', 'Edit')),
                        )
                      else ...[
                        if (_data.columns.length < 3)
                          FilledButton.tonalIcon(
                            onPressed: _addColumn,
                            icon: const Icon(
                              Icons.view_week_outlined,
                              size: 18,
                            ),
                            label: Text(_t('Añadir columna', 'Add column')),
                          ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () {
                            FocusScope.of(context).unfocus();
                            _setEditing(false);
                          },
                          icon: const Icon(Icons.check_rounded, size: 18),
                          label: Text(_t('Hecho', 'Done')),
                        ),
                      ],
                    ],
                  )
                : const SizedBox.shrink(
                    key: ValueKey('columns_toolbar_hidden'),
                  ),
          ),
          if (_editing || widget.showActions) const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < _data.columns.length; i++) ...[
                if (i > 0) const SizedBox(width: 12),
                Expanded(
                  child: _editing
                      ? AnimatedContainer(
                          duration: const Duration(milliseconds: 240),
                          curve: Curves.easeOutCubic,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: widget.scheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: widget.scheme.outlineVariant.withValues(
                                alpha: 0.35,
                              ),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    '${_t('Columna', 'Column')} ${i + 1}',
                                    style: widget.textTheme.titleSmall
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                  const Spacer(),
                                  if (_data.columns.length > 2)
                                    IconButton(
                                      tooltip: _t(
                                        'Quitar columna',
                                        'Remove column',
                                      ),
                                      onPressed: () => _removeColumn(i),
                                      icon: const Icon(Icons.close_rounded),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              AnimatedSize(
                                duration: const Duration(milliseconds: 220),
                                curve: Curves.easeOutCubic,
                                child: Column(
                                  children: [
                                    for (
                                      var blockIndex = 0;
                                      blockIndex <
                                          _data.columns[i].blocks.length;
                                      blockIndex++
                                    )
                                      _buildColumnBlockCard(
                                        i,
                                        blockIndex,
                                        _data.columns[i].blocks[blockIndex],
                                      ),
                                  ],
                                ),
                              ),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: FilledButton.tonalIcon(
                                  onPressed: () => _addBlock(i),
                                  icon: const Icon(Icons.add_rounded, size: 18),
                                  label: Text(_t('Añadir bloque', 'Add block')),
                                ),
                              ),
                            ],
                          ),
                        )
                      : _buildPreviewColumn(i),
                ),
              ],
            ],
          ),
        ],
      ),
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
    final data =
        FolioTemplateButtonData.tryParse(block.text) ??
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

class FolioTaskBlockBody extends StatefulWidget {
  const FolioTaskBlockBody({
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
  State<FolioTaskBlockBody> createState() => _FolioTaskBlockBodyState();
}

class _FolioTaskBlockBodyState extends State<FolioTaskBlockBody> {
  static const _uuid = Uuid();
  late TextEditingController _title;
  late FolioTaskData _data;

  @override
  void initState() {
    super.initState();
    _data =
        FolioTaskData.tryParse(widget.block.text) ?? FolioTaskData.defaults();
    _title = TextEditingController(text: _data.title);
  }

  @override
  void didUpdateWidget(covariant FolioTaskBlockBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.block.text != widget.block.text) {
      _data =
          FolioTaskData.tryParse(widget.block.text) ?? FolioTaskData.defaults();
      if (_title.text != _data.title) _title.text = _data.title;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  void _emit(FolioTaskData updated) {
    widget.session.updateBlockText(
      widget.pageId,
      widget.block.id,
      updated.encode(),
    );
  }

  void _setSubtaskDone(String subtaskId, bool done) {
    final next = _data.subtasks
        .map(
          (s) => s.id == subtaskId
              ? s.copyWith(status: done ? 'done' : 'todo')
              : s,
        )
        .toList(growable: false);
    setState(() => _data = _data.copyWith(subtasks: next));
    _emit(_data);
  }

  void _setSubtaskTitle(String subtaskId, String title) {
    final next = _data.subtasks
        .map((s) => s.id == subtaskId ? s.copyWith(title: title) : s)
        .toList(growable: false);
    _data = _data.copyWith(subtasks: next);
    _emit(_data);
  }

  void _removeSubtask(String subtaskId) {
    final next = _data.subtasks
        .where((s) => s.id != subtaskId)
        .toList(growable: false);
    setState(() => _data = _data.copyWith(subtasks: next));
    _emit(_data);
  }

  void _addSubtask() {
    final next = [
      ..._data.subtasks,
      FolioTaskSubtask(id: 'st_${_uuid.v4()}', title: '', status: 'todo'),
    ];
    setState(() => _data = _data.copyWith(subtasks: next));
    _emit(_data);
  }

  /// Formatea 'YYYY-MM-DD' o 'YYYY-MM-DDTHH:MM' para mostrarlo en la UI.
  static String _fmtDue(String due) => due.replaceFirst('T', ' ');

  Color _priorityColor(String? priority) {
    switch (priority) {
      case 'high':
        return widget.scheme.error;
      case 'medium':
        return Colors.orange;
      case 'low':
        return widget.scheme.onSurfaceVariant;
      default:
        return widget.scheme.outlineVariant;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = widget.scheme;
    final tt = widget.textTheme;
    final statusLabels = {
      'todo': l10n.taskStatusTodo,
      'in_progress': l10n.taskStatusInProgress,
      'done': l10n.taskStatusDone,
    };
    final priorityLabels = <String?, String?>{
      null: l10n.taskPriorityNone,
      'low': l10n.taskPriorityLow,
      'medium': l10n.taskPriorityMedium,
      'high': l10n.taskPriorityHigh,
    };
    final totalSubtasks = _data.subtasks.length;
    final doneSubtasks = _data.subtasks.where((s) => s.status == 'done').length;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(FolioRadius.md),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          FolioSpace.sm,
          FolioSpace.xs,
          FolioSpace.sm,
          FolioSpace.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status chips row
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final entry in statusLabels.entries)
                    Padding(
                      padding: const EdgeInsets.only(right: FolioSpace.xs),
                      child: ChoiceChip(
                        label: Text(entry.value),
                        selected: _data.status == entry.key,
                        onSelected: (_) {
                          setState(
                            () => _data = _data.copyWith(status: entry.key),
                          );
                          _emit(_data);
                        },
                        selectedColor: entry.key == 'done'
                            ? scheme.primaryContainer
                            : entry.key == 'in_progress'
                            ? scheme.secondaryContainer
                            : scheme.surfaceContainerHighest,
                        labelStyle: tt.labelSmall,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: FolioSpace.xs),
            // Title text field
            TextField(
              controller: _title,
              style: tt.bodyMedium,
              maxLines: null,
              decoration: InputDecoration.collapsed(
                hintText: l10n.taskTitleHint,
                hintStyle: tt.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              onChanged: (v) {
                _data = _data.copyWith(title: v);
                _emit(_data);
              },
            ),
            const SizedBox(height: FolioSpace.sm),
            // Priority + due date row
            Row(
              children: [
                // Priority selector
                PopupMenuButton<String?>(
                  initialValue: _data.priority,
                  tooltip: l10n.taskPriorityTooltip,
                  onSelected: (p) {
                    setState(() => _data = _data.copyWith(priority: p));
                    _emit(_data);
                  },
                  itemBuilder: (_) => [
                    for (final entry in priorityLabels.entries)
                      PopupMenuItem<String?>(
                        value: entry.key,
                        child: Row(
                          children: [
                            Icon(
                              Icons.flag_rounded,
                              size: 16,
                              color: _priorityColor(entry.key),
                            ),
                            const SizedBox(width: FolioSpace.xs),
                            Text(entry.value ?? l10n.taskPriorityNone),
                          ],
                        ),
                      ),
                  ],
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.flag_rounded,
                        size: 16,
                        color: _priorityColor(_data.priority),
                      ),
                      const SizedBox(width: FolioSpace.xxs),
                      Text(
                        priorityLabels[_data.priority] ?? l10n.taskPriorityNone,
                        style: tt.labelSmall?.copyWith(
                          color: _priorityColor(_data.priority),
                        ),
                      ),
                      const Icon(Icons.arrow_drop_down, size: 16),
                    ],
                  ),
                ),
                const SizedBox(width: FolioSpace.md),
                // Due date
                InkWell(
                  borderRadius: BorderRadius.circular(FolioRadius.xs),
                  onTap: () async {
                    final initial = _data.dueDate != null
                        ? DateTime.tryParse(_data.dueDate!) ?? DateTime.now()
                        : DateTime.now();
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: initial,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (!mounted || picked == null) return;
                    final existingDt = _data.dueDate != null
                        ? DateTime.tryParse(_data.dueDate!)
                        : null;
                    final pickedTime = await showTimePicker(
                      context: context,
                      initialTime:
                          existingDt != null && (_data.dueDate!.contains('T'))
                          ? TimeOfDay(
                              hour: existingDt.hour,
                              minute: existingDt.minute,
                            )
                          : TimeOfDay.now(),
                    );
                    if (!mounted) return;
                    final dateStr =
                        '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                    final iso = pickedTime != null
                        ? '${dateStr}T${pickedTime.hour.toString().padLeft(2, '0')}:${pickedTime.minute.toString().padLeft(2, '0')}'
                        : dateStr;
                    setState(() => _data = _data.copyWith(dueDate: iso));
                    _emit(_data);
                  },
                  onLongPress: () {
                    if (_data.dueDate != null) {
                      setState(() => _data = _data.copyWith(dueDate: null));
                      _emit(_data);
                    }
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.calendar_today_rounded,
                        size: 14,
                        color: _data.dueDate != null
                            ? scheme.primary
                            : scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: FolioSpace.xxs),
                      Text(
                        _data.dueDate != null
                            ? _fmtDue(_data.dueDate!)
                            : l10n.taskNoDueDate,
                        style: tt.labelSmall?.copyWith(
                          color: _data.dueDate != null
                              ? scheme.primary
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: FolioSpace.md),
                // Recurrence selector
                _RecurrenceSelector(
                  value: _data.recurrence,
                  l10n: l10n,
                  scheme: scheme,
                  tt: tt,
                  onChanged: (r) {
                    setState(() => _data = _data.copyWith(recurrence: r));
                    _emit(_data);
                  },
                ),
                const SizedBox(width: FolioSpace.sm),
                // Reminder toggle
                Tooltip(
                  message: _data.reminderEnabled
                      ? l10n.taskReminderOnTooltip
                      : l10n.taskReminderTooltip,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(FolioRadius.xs),
                    onTap: () {
                      setState(
                        () => _data = _data.copyWith(
                          reminderEnabled: !_data.reminderEnabled,
                        ),
                      );
                      _emit(_data);
                    },
                    child: Icon(
                      _data.reminderEnabled
                          ? Icons.notifications_rounded
                          : Icons.notifications_none_rounded,
                      size: 18,
                      color: _data.reminderEnabled
                          ? scheme.primary
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const Spacer(),
                if (totalSubtasks > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: FolioSpace.xs,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(FolioRadius.xs),
                    ),
                    child: Text(
                      '$doneSubtasks/$totalSubtasks',
                      style: tt.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: FolioSpace.sm),
            if (_data.subtasks.isNotEmpty)
              Column(
                children: [
                  for (final s in _data.subtasks)
                    Row(
                      key: ValueKey(s.id),
                      children: [
                        Checkbox(
                          value: s.status == 'done',
                          visualDensity: VisualDensity.compact,
                          onChanged: (v) => _setSubtaskDone(s.id, v == true),
                        ),
                        Expanded(
                          child: TextFormField(
                            initialValue: s.title,
                            decoration: InputDecoration(
                              isDense: true,
                              border: InputBorder.none,
                              hintText: l10n.taskSubtaskHint,
                              hintStyle: tt.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                            onChanged: (v) => _setSubtaskTitle(s.id, v),
                          ),
                        ),
                        IconButton(
                          tooltip: l10n.taskRemoveSubtask,
                          visualDensity: VisualDensity.compact,
                          onPressed: () => _removeSubtask(s.id),
                          icon: const Icon(Icons.close_rounded, size: 18),
                        ),
                      ],
                    ),
                ],
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _addSubtask,
                icon: const Icon(Icons.add_task_rounded, size: 16),
                label: Text(l10n.taskAddSubtask),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Selector de recurrencia compacto para bloques de tarea.
class _RecurrenceSelector extends StatelessWidget {
  const _RecurrenceSelector({
    required this.value,
    required this.l10n,
    required this.scheme,
    required this.tt,
    required this.onChanged,
  });

  final String? value;
  final AppLocalizations l10n;
  final ColorScheme scheme;
  final TextTheme tt;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final isSet = value != null;
    final label = switch (value) {
      'daily' => l10n.taskRecurrenceDaily,
      'weekly' => l10n.taskRecurrenceWeekly,
      'monthly' => l10n.taskRecurrenceMonthly,
      'yearly' => l10n.taskRecurrenceYearly,
      _ => null,
    };

    return PopupMenuButton<String?>(
      tooltip: '',
      initialValue: value,
      onSelected: onChanged,
      itemBuilder: (_) => [
        PopupMenuItem<String?>(
          value: null,
          child: Text(l10n.taskRecurrenceNone),
        ),
        PopupMenuItem<String?>(
          value: 'daily',
          child: Text(l10n.taskRecurrenceDaily),
        ),
        PopupMenuItem<String?>(
          value: 'weekly',
          child: Text(l10n.taskRecurrenceWeekly),
        ),
        PopupMenuItem<String?>(
          value: 'monthly',
          child: Text(l10n.taskRecurrenceMonthly),
        ),
        PopupMenuItem<String?>(
          value: 'yearly',
          child: Text(l10n.taskRecurrenceYearly),
        ),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.repeat_rounded,
            size: 16,
            color: isSet ? scheme.primary : scheme.onSurfaceVariant,
          ),
          if (label != null) ...[
            const SizedBox(width: FolioSpace.xxs),
            Text(label, style: tt.labelSmall?.copyWith(color: scheme.primary)),
          ],
        ],
      ),
    );
  }
}
