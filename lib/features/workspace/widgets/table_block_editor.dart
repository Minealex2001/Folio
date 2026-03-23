import 'package:flutter/material.dart';

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
  });

  final String json;
  final ValueChanged<String> onChanged;
  final ColorScheme scheme;
  final TextTheme textTheme;
  final FocusNode? firstCellFocusNode;

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
    _disposeControllers();
    for (var i = 0; i < _data.cells.length; i++) {
      final c = TextEditingController(text: _data.cells[i]);
      c.addListener(_syncFromControllers);
      _controllers.add(c);
    }
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

  @override
  Widget build(BuildContext context) {
    final rows = _data.rowCount;
    final cols = _data.cols;

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
}
