import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/folio_block_controls.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../models/folio_table_data.dart';

/// Rejilla editable para bloques `table`; notifica JSON serializado.
class TableBlockEditor extends StatefulWidget {
  const TableBlockEditor({
    super.key,
    required this.json,
    required this.onChanged,
    required this.scheme,
    required this.textTheme,
    this.firstCellFocusNode,
    this.showGutters = true,
  });

  final String json;
  final ValueChanged<String> onChanged;
  final ColorScheme scheme;
  final TextTheme textTheme;
  final FocusNode? firstCellFocusNode;
  /// When false, inline + gutters are hidden (read-only / unfocused).
  final bool showGutters;

  @override
  State<TableBlockEditor> createState() => _TableBlockEditorState();
}

class _TableBlockEditorState extends State<TableBlockEditor> {
  FolioTableData _data = FolioTableData.empty();
  final List<TextEditingController> _controllers = [];
  String _lastEmitted = '';

  @override
  void initState() {
    super.initState();
    _bootstrap(widget.json);
  }

  @override
  void didUpdateWidget(TableBlockEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.json != widget.json && widget.json != _lastEmitted) {
      _bootstrap(widget.json);
    }
  }

  void _disposeControllers() {
    for (final c in _controllers) {
      c.dispose();
    }
    _controllers.clear();
  }

  void _bootstrap(String json) {
    _data = FolioTableData.tryParse(json) ?? FolioTableData.empty();
    _data.normalize();
    _lastEmitted = _data.encode();
    _rebuildControllersFromData();
  }

  void _rebuildControllersFromData() {
    _disposeControllers();
    for (var i = 0; i < _data.cells.length; i++) {
      final c = TextEditingController(text: _data.cells[i]);
      c.addListener(_syncFromControllers);
      _controllers.add(c);
    }
  }

  void _mutateStructure(void Function(FolioTableData data) op) {
    op(_data);
    _data.normalize();
    _rebuildControllersFromData();
    final enc = _data.encode();
    if (enc == _lastEmitted) return;
    _lastEmitted = enc;
    widget.onChanged(enc);
    setState(() {});
  }

  Future<void> _pasteFromClipboard() async {
    final raw = await Clipboard.getData('text/plain');
    if (!mounted) return;
    final text = (raw?.text ?? '').trim();
    if (text.isEmpty) return;
    final rows = _parseDelimitedRows(text);
    if (rows.isEmpty) return;
    var cols = rows.fold<int>(
      0,
      (maxCols, row) => row.length > maxCols ? row.length : maxCols,
    );
    cols = cols.clamp(1, 32);
    final normalizedRows = rows.length.clamp(1, 200);
    final cells = <String>[];
    for (var r = 0; r < normalizedRows; r++) {
      final row = rows[r];
      for (var c = 0; c < cols; c++) {
        cells.add(c < row.length ? row[c] : '');
      }
    }
    _data = FolioTableData(cols: cols, cells: cells);
    _data.normalize();
    _rebuildControllersFromData();
    final enc = _data.encode();
    if (enc == _lastEmitted) return;
    _lastEmitted = enc;
    widget.onChanged(enc);
    setState(() {});
  }

  List<List<String>> _parseDelimitedRows(String text) {
    final lines = text
        .replaceAll('\r\n', '\n')
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .toList(growable: false);
    if (lines.isEmpty) return const [];
    final useTabs = lines.any((l) => l.contains('\t'));
    final delimiter = useTabs ? '\t' : ',';
    return lines
        .map((line) => line.split(delimiter).map((c) => c.trim()).toList())
        .toList(growable: false);
  }

  void _syncFromControllers() {
    _data.normalize();
    for (var i = 0; i < _controllers.length && i < _data.cells.length; i++) {
      _data.cells[i] = _controllers[i].text;
    }
    final enc = _data.encode();
    if (enc == _lastEmitted) return;
    _lastEmitted = enc;
    widget.onChanged(enc);
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  Widget _buildTable(int rows, int cols) {
    return Table(
      defaultColumnWidth: const FlexColumnWidth(1),
      border: TableBorder.all(
        color: widget.scheme.outlineVariant.withValues(alpha: 0.65),
        width: 0.5,
      ),
      children: List.generate(rows, (r) {
        return TableRow(
          children: List.generate(cols, (c) {
            final i = r * cols + c;
            final cellStyle = widget.textTheme.bodyMedium?.copyWith(
              fontSize: 14,
              height: 1.35,
            );
            final isFirst = r == 0 && c == 0;
            final ctrl = _controllers[i];
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              child: TextField(
                controller: ctrl,
                focusNode: isFirst ? widget.firstCellFocusNode : null,
                maxLines: null,
                minLines: 1,
                style: cellStyle,
                decoration: const InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            );
          }),
        );
      }),
    );
  }

  Widget _buildCornerMenu(AppLocalizations l10n, int rows, int cols) {
    return PopupMenuButton<String>(
      tooltip: l10n.tableMoreActions,
      padding: EdgeInsets.zero,
      icon: Icon(
        Icons.more_horiz_rounded,
        size: 18,
        color: widget.scheme.onSurfaceVariant,
      ),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'paste',
          child: Row(
            children: [
              const Icon(Icons.content_paste_rounded, size: 18),
              const SizedBox(width: 8),
              Text(l10n.tablePasteFromClipboard),
            ],
          ),
        ),
        if (rows > 1)
          PopupMenuItem(
            value: 'remove_row',
            child: Row(
              children: [
                const Icon(Icons.remove_circle_outline_rounded, size: 18),
                const SizedBox(width: 8),
                Text(l10n.tableRemoveRow),
              ],
            ),
          ),
        if (cols > 1)
          PopupMenuItem(
            value: 'remove_col',
            child: Row(
              children: [
                const Icon(Icons.view_column_outlined, size: 18),
                const SizedBox(width: 8),
                Text(l10n.tableRemoveColumn),
              ],
            ),
          ),
      ],
      onSelected: (value) {
        switch (value) {
          case 'paste':
            unawaited(_pasteFromClipboard());
          case 'remove_row':
            _mutateStructure((d) => d.removeLastRow());
          case 'remove_col':
            _mutateStructure((d) => d.removeLastCol());
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final rows = _data.rowCount;
    final cols = _data.cols;
    final showGutters = widget.showGutters;

    if (!showGutters) {
      return _buildTable(rows, cols);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTable(rows, cols),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FolioTableGutterButton(
                        tooltip: l10n.tableAddRow,
                        onPressed: () =>
                            _mutateStructure((d) => d.addRow()),
                      ),
                    ),
                  ),
                  _buildCornerMenu(l10n, rows, cols),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 4),
        Padding(
          padding: const EdgeInsets.only(top: 24),
          child: FolioTableGutterButton(
            tooltip: l10n.tableAddColumn,
            onPressed: () => _mutateStructure((d) => d.addCol()),
          ),
        ),
      ],
    );
  }
}
