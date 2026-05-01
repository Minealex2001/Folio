import 'package:flutter/material.dart';

import '../../../app/app_settings.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../models/folio_canvas_data.dart';
import '../../../session/vault_session.dart';
import 'folio_canvas_board.dart';

/// Página completa de lienzo infinito.
/// Se activa cuando una página contiene un bloque de tipo 'canvas',
/// igual que [KanbanBoardPage] o [DrivePage].
class CanvasPage extends StatefulWidget {
  const CanvasPage({
    super.key,
    required this.pageId,
    required this.session,
    required this.appSettings,
    required this.onOpenClassicEditor,
  });

  final String pageId;
  final VaultSession session;
  final AppSettings appSettings;
  final VoidCallback onOpenClassicEditor;

  @override
  State<CanvasPage> createState() => _CanvasPageState();
}

class _CanvasPageState extends State<CanvasPage> {
  var _warnedMultipleCanvas = false;
  String? _lastKnownCanvasText;

  @override
  void initState() {
    super.initState();
    widget.session.addListener(_onSession);
    _lastKnownCanvasText = _canvasBlockText();
    _warnMultipleCanvasIfNeeded();
  }

  @override
  void dispose() {
    widget.session.removeListener(_onSession);
    super.dispose();
  }

  void _onSession() {
    if (!mounted) return;
    final next = _canvasBlockText();
    if (_lastKnownCanvasText != null &&
        next != null &&
        next != _lastKnownCanvasText) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.canvasCollabRemoteUpdate)),
        );
      });
    }
    _lastKnownCanvasText = next;
    setState(() {});
    _warnMultipleCanvasIfNeeded();
  }

  String? _canvasBlockText() {
    final page = widget.session.pages.where((p) => p.id == widget.pageId).firstOrNull;
    final block = page?.blocks.where((b) => b.type == 'canvas').firstOrNull;
    return block?.text;
  }

  void _warnMultipleCanvasIfNeeded() {
    if (_warnedMultipleCanvas) return;
    final page = widget.session.pages.where((p) => p.id == widget.pageId).firstOrNull;
    if (page == null) return;
    final count = page.blocks.where((b) => b.type == 'canvas').length;
    if (count > 1 && mounted) {
      _warnedMultipleCanvas = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.canvasMultipleBlocksSnack)),
        );
      });
    }
  }

  FolioCanvasData _loadData() {
    final page = widget.session.pages.where((p) => p.id == widget.pageId).firstOrNull;
    final block = page?.blocks.where((b) => b.type == 'canvas').firstOrNull;
    if (block == null) return FolioCanvasData.defaults();
    return FolioCanvasData.tryParse(block.text) ?? FolioCanvasData.defaults();
  }

  String? _blockId() {
    final page = widget.session.pages.where((p) => p.id == widget.pageId).firstOrNull;
    return page?.blocks.where((b) => b.type == 'canvas').firstOrNull?.id;
  }

  void _saveData(FolioCanvasData data) {
    final id = _blockId();
    if (id == null) return;
    final encoded = data.encode();
    _lastKnownCanvasText = encoded;
    widget.session.updateBlockText(widget.pageId, id, encoded);
  }

  @override
  Widget build(BuildContext context) {
    return FolioCanvasBoard(
      key: ValueKey(widget.pageId),
      initialData: _loadData(),
      onDataChanged: _saveData,
      onOpenClassicEditor: widget.onOpenClassicEditor,
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull {
    final it = iterator;
    if (it.moveNext()) return it.current;
    return null;
  }
}
