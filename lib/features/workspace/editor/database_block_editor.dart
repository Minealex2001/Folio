import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../models/folio_database_data.dart';

class DatabaseBlockEditor extends StatefulWidget {
  const DatabaseBlockEditor({
    super.key,
    required this.json,
    required this.onChanged,
    required this.scheme,
    required this.textTheme,
    this.controlsVisible = true,
  });

  final String json;
  final ValueChanged<String> onChanged;
  final ColorScheme scheme;
  final TextTheme textTheme;
  final bool controlsVisible;

  @override
  State<DatabaseBlockEditor> createState() => _DatabaseBlockEditorState();
}

class _DatabaseBlockEditorState extends State<DatabaseBlockEditor> {
  _DatabaseViewMode _mode = _DatabaseViewMode.view;
  final TextEditingController _filterController = TextEditingController();

  static const _uuid = Uuid();
  late FolioDatabaseData _data;
  String _last = '';

  @override
  void initState() {
    super.initState();
    _bootstrap(widget.json);
  }

  @override
  void didUpdateWidget(covariant DatabaseBlockEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.json != widget.json && widget.json != _last) {
      _bootstrap(widget.json);
    }
  }

  @override
  void dispose() {
    _filterController.dispose();
    super.dispose();
  }

  void _bootstrap(String json) {
    _data = FolioDatabaseData.tryParse(json) ?? FolioDatabaseData.empty();
    _last = _data.encode();
    _filterController.text = '';
  }

  void _emit() {
    final encoded = _data.encode();
    if (encoded == _last) return;
    _last = encoded;
    widget.onChanged(encoded);
  }

  FolioDbView get _activeView {
    final id = _data.activeViewId;
    if (id != null) {
      final found = _data.views.where((v) => v.id == id).firstOrNull;
      if (found != null) return found;
    }
    return _data.views.first;
  }

  List<FolioDbRow> _visibleRowsFor(FolioDbView view) =>
      _data.materializeRows(view);

  void _addRow() {
    final row = FolioDbRow(id: 'r_${_uuid.v4()}');
    _data.rows.add(row);
    _emit();
    setState(() {});
  }

  void _addProperty() {
    _showCreatePropertyDialog();
  }

  void _addFilterCondition(FolioDbView view) {
    final first = _data.properties.firstOrNull;
    if (first == null) return;
    final root =
        view.filter ??
        FolioDbFilterGroup(logical: FolioDbLogicalOperator.and, conditions: []);
    root.conditions.add(
      FolioDbFilterCondition(
        propertyId: first.id,
        op: FolioDbFilterOperator.contains,
        value: '',
      ),
    );
    view.filter = root;
    _emit();
    setState(() {});
  }

  void _addSort(FolioDbView view) {
    final first = _data.properties.firstOrNull;
    if (first == null) return;
    view.sorts = [...view.sorts, FolioDbSortSpec(propertyId: first.id)];
    _emit();
    setState(() {});
  }

  void _setActiveView(String viewId) {
    if (_data.activeViewId == viewId) return;
    _data.activeViewId = viewId;
    _emit();
    setState(() {});
  }

  IconData _viewIcon(FolioDbViewType type) {
    switch (type) {
      case FolioDbViewType.table:
        return Icons.table_chart_rounded;
      case FolioDbViewType.list:
        return Icons.view_list_rounded;
      case FolioDbViewType.board:
        return Icons.view_kanban_rounded;
      case FolioDbViewType.calendar:
        return Icons.calendar_month_rounded;
    }
  }

  String _defaultViewName(FolioDbViewType type) {
    switch (type) {
      case FolioDbViewType.table:
        return _t('Tabla', 'Table');
      case FolioDbViewType.list:
        return _t('Lista', 'List');
      case FolioDbViewType.board:
        return _t('Tablero', 'Board');
      case FolioDbViewType.calendar:
        return _t('Calendario', 'Calendar');
    }
  }

  String _uniqueViewName(String base) {
    final names = _data.views.map((v) => v.name.trim().toLowerCase()).toSet();
    var candidate = base.trim();
    if (candidate.isEmpty) candidate = _t('Vista', 'View');
    if (!names.contains(candidate.toLowerCase())) return candidate;
    var n = 2;
    while (names.contains('$candidate $n'.toLowerCase())) {
      n++;
    }
    return '$candidate $n';
  }

  Future<void> _showCreateViewDialog() async {
    final active = _activeView;
    final nameCtrl = TextEditingController(
      text: _uniqueViewName('${active.name} ${_t('copia', 'copy')}'),
    );
    var selectedType = active.type;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_t('Nueva vista', 'New view')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(labelText: _t('Nombre', 'Name')),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<FolioDbViewType>(
              initialValue: selectedType,
              items: FolioDbViewType.values
                  .map(
                    (t) => DropdownMenuItem(
                      value: t,
                      child: Text(_defaultViewName(t)),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) selectedType = v;
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(_t('Cancelar', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(_t('Crear', 'Create')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final next = FolioDbView(
      id: 'v_${_uuid.v4()}',
      name: _uniqueViewName(nameCtrl.text.trim()),
      type: selectedType,
      groupByPropertyId: selectedType == FolioDbViewType.board
          ? active.groupByPropertyId
          : null,
      calendarDatePropertyId: selectedType == FolioDbViewType.calendar
          ? active.calendarDatePropertyId
          : null,
      filter: active.filter == null
          ? null
          : FolioDbFilterGroup.fromJson(active.filter!.toJson()),
      visiblePropertyIds: List<String>.from(active.visiblePropertyIds),
      sorts: active.sorts
          .map((s) => FolioDbSortSpec(propertyId: s.propertyId, desc: s.desc))
          .toList(),
    );
    _data.views.add(next);
    _data.activeViewId = next.id;
    _emit();
    setState(() {});
  }

  Future<void> _showRenameActiveViewDialog() async {
    final active = _activeView;
    final ctrl = TextEditingController(text: active.name);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_t('Renombrar vista', 'Rename view')),
        content: TextField(
          controller: ctrl,
          decoration: InputDecoration(labelText: _t('Nombre', 'Name')),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(_t('Cancelar', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(_t('Guardar', 'Save')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    active.name = _uniqueViewName(ctrl.text.trim());
    _emit();
    setState(() {});
  }

  void _deleteActiveView() {
    if (_data.views.length <= 1) return;
    final activeId = _activeView.id;
    _data.views.removeWhere((v) => v.id == activeId);
    _data.activeViewId = _data.views.first.id;
    _emit();
    setState(() {});
  }

  void _duplicateActiveView() {
    final active = _activeView;
    final clone = FolioDbView(
      id: 'v_${_uuid.v4()}',
      name: _uniqueViewName('${active.name} ${_t('copia', 'copy')}'),
      type: active.type,
      groupByPropertyId: active.groupByPropertyId,
      calendarDatePropertyId: active.calendarDatePropertyId,
      filter: active.filter == null
          ? null
          : FolioDbFilterGroup.fromJson(active.filter!.toJson()),
      visiblePropertyIds: List<String>.from(active.visiblePropertyIds),
      sorts: active.sorts
          .map((s) => FolioDbSortSpec(propertyId: s.propertyId, desc: s.desc))
          .toList(),
    );
    _data.views.add(clone);
    _data.activeViewId = clone.id;
    _emit();
    setState(() {});
  }

  List<FolioDbProperty> _visiblePropertiesFor(FolioDbView view) {
    if (view.visiblePropertyIds.isEmpty) return _data.properties;
    final set = view.visiblePropertyIds.toSet();
    final visible = _data.properties.where((p) => set.contains(p.id)).toList();
    return visible.isEmpty ? _data.properties : visible;
  }

  void _togglePropertyVisibility(
    FolioDbView view,
    String propertyId,
    bool visible,
  ) {
    if (view.visiblePropertyIds.isEmpty) {
      view.visiblePropertyIds = _data.properties.map((p) => p.id).toList();
    }
    final ids = List<String>.from(view.visiblePropertyIds);
    if (visible) {
      if (!ids.contains(propertyId)) ids.add(propertyId);
    } else {
      ids.remove(propertyId);
      if (ids.isEmpty) return;
    }
    view.visiblePropertyIds = ids;
    _emit();
    setState(() {});
  }

  Future<void> _showVisiblePropertiesSheet(FolioDbView view) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        final current = view.visiblePropertyIds.isEmpty
            ? _data.properties.map((p) => p.id).toSet()
            : view.visiblePropertyIds.toSet();
        return StatefulBuilder(
          builder: (context, setModalState) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              children: [
                Text(
                  _t('Propiedades visibles', 'Visible properties'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                for (final p in _data.properties)
                  CheckboxListTile(
                    value: current.contains(p.id),
                    title: Text(p.name),
                    subtitle: Text(p.type.name),
                    onChanged: (v) {
                      final nextVisible = v == true;
                      if (!nextVisible && current.length <= 1) return;
                      if (nextVisible) {
                        current.add(p.id);
                      } else {
                        current.remove(p.id);
                      }
                      _togglePropertyVisibility(view, p.id, nextVisible);
                      setModalState(() {});
                    },
                  ),
              ],
            );
          },
        );
      },
    );
  }

  void _moveRowToBoardGroup(
    FolioDbRow row,
    FolioDbProperty groupProperty,
    String groupKey,
    String emptyLabel,
  ) {
    final target = groupKey == emptyLabel ? '' : groupKey;
    _updateRowValue(row, groupProperty, target);
  }

  void _updateRowValue(
    FolioDbRow row,
    FolioDbProperty property,
    dynamic value,
  ) {
    row.values[property.id] = _data.sanitizedValue(property, value);
    _emit();
    setState(() {});
  }

  void _duplicateRow(FolioDbRow source) {
    final clonedValues = Map<String, dynamic>.from(source.values);
    _data.rows.add(FolioDbRow(id: 'r_${_uuid.v4()}', values: clonedValues));
    _emit();
    setState(() {});
  }

  void _deleteRow(FolioDbRow row) {
    _data.rows.removeWhere((r) => r.id == row.id);
    _emit();
    setState(() {});
  }

  void _applyQuickFilter(FolioDbView active) {
    final first = _data.properties.firstOrNull;
    if (first == null) return;
    final value = _filterController.text.trim();
    if (value.isEmpty) {
      active.filter = null;
    } else {
      active.filter = FolioDbFilterGroup(
        logical: FolioDbLogicalOperator.and,
        conditions: [
          FolioDbFilterCondition(
            propertyId: first.id,
            op: FolioDbFilterOperator.contains,
            value: value,
          ),
        ],
      );
    }
    _emit();
    setState(() {});
  }

  bool get _isEs => Localizations.localeOf(
    context,
  ).languageCode.toLowerCase().startsWith('es');

  bool get _isEditMode => _mode == _DatabaseViewMode.edit;

  Color get _canvasColor => Color.alphaBlend(
    widget.scheme.surface.withValues(alpha: 0.72),
    widget.scheme.surfaceContainerLowest,
  );

  Color get _panelColor => widget.scheme.surface;

  Color get _subtleBorder =>
      widget.scheme.outlineVariant.withValues(alpha: 0.55);

  String _t(String es, String en) => _isEs ? es : en;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final active = _activeView;
    final rows = _visibleRowsFor(active);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _canvasColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _subtleBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.controlsVisible) _buildTopBar(active),
          if (widget.controlsVisible) const SizedBox(height: 8),
          if (widget.controlsVisible)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                DropdownButton<FolioDbViewType>(
                  value: active.type,
                  items: FolioDbViewType.values
                      .map(
                        (t) => DropdownMenuItem(
                          value: t,
                          child: Row(
                            children: [
                              Icon(_viewIcon(t), size: 16),
                              const SizedBox(width: 6),
                              Text(_defaultViewName(t)),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (!_isEditMode) return;
                    if (v == null) return;
                    active.type = v;
                    _emit();
                    setState(() {});
                  },
                ),
                if (_isEditMode)
                  OutlinedButton.icon(
                    onPressed: _addProperty,
                    icon: const Icon(Icons.view_column_rounded, size: 18),
                    label: Text(_t('Añadir propiedad', 'Add property')),
                  ),
                OutlinedButton.icon(
                  onPressed: _isEditMode
                      ? () => _showVisiblePropertiesSheet(active)
                      : null,
                  icon: const Icon(Icons.tune_rounded, size: 18),
                  label: Text(_t('Propiedades visibles', 'Visible properties')),
                ),
                if (_isEditMode)
                  FilledButton.tonalIcon(
                    onPressed: _addRow,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: Text(_t('Nueva fila', 'New row')),
                  ),
                OutlinedButton.icon(
                  onPressed: () => _applyQuickFilter(active),
                  icon: const Icon(Icons.filter_alt_outlined, size: 18),
                  label: Text(_t('Aplicar filtro', 'Apply filter')),
                ),
                if (_isEditMode)
                  OutlinedButton.icon(
                    onPressed: () {
                      final first = _data.properties.firstOrNull;
                      if (first == null) return;
                      active.sorts = [
                        FolioDbSortSpec(propertyId: first.id, desc: false),
                      ];
                      _emit();
                      setState(() {});
                    },
                    icon: const Icon(Icons.sort_by_alpha_rounded, size: 18),
                    label: Text(l10n.databaseSortAz),
                  ),
              ],
            ),
          if (widget.controlsVisible) const SizedBox(height: 8),
          if (_isEditMode && widget.controlsVisible) _propertiesCard(),
          if (_isEditMode && widget.controlsVisible) const SizedBox(height: 8),
          if (widget.controlsVisible)
            TextField(
              controller: _filterController,
              decoration: InputDecoration(
                filled: true,
                fillColor: _panelColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: _subtleBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: _subtleBorder),
                ),
                isDense: true,
                prefixIcon: const Icon(Icons.search_rounded, size: 18),
                labelText: _t(
                  'Filtro rápido (columna principal)',
                  'Quick filter (main column)',
                ),
              ),
              onSubmitted: (_) {
                _applyQuickFilter(active);
              },
            ),
          if (widget.controlsVisible) const SizedBox(height: 8),
          if (_isEditMode && widget.controlsVisible) _queryBuilderCard(active),
          if (_isEditMode && widget.controlsVisible) const SizedBox(height: 8),
          _buildView(active, rows),
        ],
      ),
    );
  }

  Widget _buildTopBar(FolioDbView active) {
    final statusLabel = _isEditMode
        ? _t('Editable', 'Editable')
        : _t('Bloqueada', 'Locked');
    final statusIcon = _isEditMode
        ? Icons.lock_open_rounded
        : Icons.lock_rounded;

    Widget leftTabs = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final view in _data.views)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _buildViewTab(view, view.id == active.id),
            ),
          TextButton.icon(
            onPressed: _isEditMode ? _showCreateViewDialog : null,
            icon: const Icon(Icons.add_rounded, size: 16),
            label: Text(_t('Vista', 'View')),
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              foregroundColor: widget.scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );

    Widget rightActions = Wrap(
      spacing: 4,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        TextButton.icon(
          onPressed: () {
            setState(() {
              _mode = _isEditMode
                  ? _DatabaseViewMode.view
                  : _DatabaseViewMode.edit;
            });
          },
          icon: Icon(statusIcon, size: 16),
          label: Text(statusLabel),
          style: TextButton.styleFrom(
            visualDensity: VisualDensity.compact,
            foregroundColor: widget.scheme.onSurfaceVariant,
          ),
        ),
        IconButton(
          tooltip: _t('Aplicar filtro', 'Apply filter'),
          onPressed: () => _applyQuickFilter(active),
          icon: const Icon(Icons.filter_alt_outlined, size: 18),
        ),
        IconButton(
          tooltip: _t('Propiedades visibles', 'Visible properties'),
          onPressed: _isEditMode
              ? () => _showVisiblePropertiesSheet(active)
              : null,
          icon: const Icon(Icons.tune_rounded, size: 18),
        ),
        PopupMenuButton<String>(
          tooltip: _t('Opciones de vista', 'View options'),
          enabled: _isEditMode,
          onSelected: (value) {
            if (value == 'rename') {
              _showRenameActiveViewDialog();
            } else if (value == 'duplicate') {
              _duplicateActiveView();
            } else if (value == 'delete') {
              _deleteActiveView();
            }
          },
          itemBuilder: (_) => [
            PopupMenuItem(
              value: 'rename',
              child: Row(
                children: [
                  const Icon(Icons.drive_file_rename_outline_rounded, size: 18),
                  const SizedBox(width: 8),
                  Text(_t('Renombrar vista', 'Rename view')),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'duplicate',
              child: Row(
                children: [
                  const Icon(Icons.copy_all_rounded, size: 18),
                  const SizedBox(width: 8),
                  Text(_t('Duplicar vista', 'Duplicate view')),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              enabled: _data.views.length > 1,
              child: Row(
                children: [
                  const Icon(Icons.delete_outline_rounded, size: 18),
                  const SizedBox(width: 8),
                  Text(_t('Eliminar vista', 'Delete view')),
                ],
              ),
            ),
          ],
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Icon(Icons.more_horiz_rounded, size: 18),
          ),
        ),
        FilledButton.icon(
          onPressed: _isEditMode ? _addRow : null,
          style: FilledButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          icon: const Icon(Icons.add_rounded, size: 16),
          label: Text(_t('Nuevo', 'New')),
        ),
      ],
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: _panelColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _subtleBorder),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 920) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                leftTabs,
                const SizedBox(height: 6),
                Align(alignment: Alignment.centerRight, child: rightActions),
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: leftTabs),
              const SizedBox(width: 10),
              rightActions,
            ],
          );
        },
      ),
    );
  }

  Widget _buildViewTab(FolioDbView view, bool selected) {
    final selectedColor = widget.scheme.onSurface;
    final idleColor = widget.scheme.onSurfaceVariant;
    return TextButton.icon(
      onPressed: () => _setActiveView(view.id),
      icon: Icon(_viewIcon(view.type), size: 16),
      label: Text(view.name),
      style: TextButton.styleFrom(
        visualDensity: VisualDensity.compact,
        foregroundColor: selected ? selectedColor : idleColor,
        backgroundColor: selected
            ? widget.scheme.surfaceContainerHigh
            : Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _propertiesCard() {
    return Card(
      color: _panelColor,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: _subtleBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _t('Propiedades', 'Properties'),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            ..._data.properties.asMap().entries.map((entry) {
              final i = entry.key;
              final p = entry.value;
              return Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      initialValue: p.name,
                      decoration: InputDecoration(
                        isDense: true,
                        labelText: _t('Título', 'Title'),
                      ),
                      onChanged: (v) {
                        p.name = v.trim().isEmpty ? p.name : v.trim();
                        _emit();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<FolioDbPropertyType>(
                      initialValue: p.type,
                      isDense: true,
                      items: FolioDbPropertyType.values
                          .map(
                            (t) =>
                                DropdownMenuItem(value: t, child: Text(t.name)),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v == null) return;
                        p.type = v;
                        _emit();
                        setState(() {});
                      },
                    ),
                  ),
                  IconButton(
                    tooltip: _t('Configurar', 'Configure'),
                    onPressed: () => _showPropertyConfigDialog(p),
                    icon: const Icon(Icons.tune_rounded),
                  ),
                  IconButton(
                    tooltip: _t('Eliminar', 'Delete'),
                    onPressed: _data.properties.length <= 1
                        ? null
                        : () {
                            final removedId = p.id;
                            _data.properties.removeAt(i);
                            for (final row in _data.rows) {
                              row.values.remove(removedId);
                            }
                            for (final v in _data.views) {
                              if (v.groupByPropertyId == removedId) {
                                v.groupByPropertyId = null;
                              }
                              if (v.calendarDatePropertyId == removedId) {
                                v.calendarDatePropertyId = null;
                              }
                              v.visiblePropertyIds = v.visiblePropertyIds
                                  .where((id) => id != removedId)
                                  .toList();
                              v.sorts = v.sorts
                                  .where((s) => s.propertyId != removedId)
                                  .toList();
                              final f = v.filter;
                              if (f != null) {
                                f.conditions = f.conditions
                                    .where((c) => c.propertyId != removedId)
                                    .toList();
                              }
                            }
                            _emit();
                            setState(() {});
                          },
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _queryBuilderCard(FolioDbView active) {
    final l10n = AppLocalizations.of(context);
    final group = active.filter;
    return Card(
      color: _panelColor,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: _subtleBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.account_tree_outlined, size: 18),
                const SizedBox(width: 8),
                Text(_t('Constructor de consulta', 'Query builder')),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _addFilterCondition(active),
                  icon: const Icon(Icons.add, size: 16),
                  label: Text(_t('Filtro', 'Filter')),
                ),
                TextButton.icon(
                  onPressed: () => _addSort(active),
                  icon: const Icon(Icons.swap_vert, size: 16),
                  label: Text(l10n.databaseSortLabel),
                ),
                TextButton.icon(
                  onPressed: () {
                    active.filter = null;
                    _emit();
                    setState(() {});
                  },
                  icon: const Icon(Icons.filter_alt_off_outlined, size: 16),
                  label: Text(_t('Quitar filtros', 'Clear filters')),
                ),
              ],
            ),
            if (group != null) ...[
              Row(
                children: [
                  Text(_t('Lógica:', 'Logic:')),
                  const SizedBox(width: 8),
                  DropdownButton<FolioDbLogicalOperator>(
                    value: group.logical,
                    items: [
                      DropdownMenuItem(
                        value: FolioDbLogicalOperator.and,
                        child: Text(l10n.databaseFilterAnd),
                      ),
                      DropdownMenuItem(
                        value: FolioDbLogicalOperator.or,
                        child: Text(l10n.databaseFilterOr),
                      ),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      active.filter = FolioDbFilterGroup(
                        logical: v,
                        conditions: group.conditions,
                        groups: group.groups,
                      );
                      _emit();
                      setState(() {});
                    },
                  ),
                ],
              ),
              ...group.conditions.asMap().entries.map((entry) {
                final i = entry.key;
                final c = entry.value;
                return Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: c.propertyId,
                        items: _data.properties
                            .map(
                              (p) => DropdownMenuItem(
                                value: p.id,
                                child: Text(p.name),
                              ),
                            )
                            .toList(),
                        onChanged: (v) {
                          if (v == null) return;
                          group.conditions[i] = FolioDbFilterCondition(
                            propertyId: v,
                            op: c.op,
                            value: c.value,
                          );
                          _emit();
                          setState(() {});
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<FolioDbFilterOperator>(
                        initialValue: c.op,
                        items: FolioDbFilterOperator.values
                            .map(
                              (op) => DropdownMenuItem(
                                value: op,
                                child: Text(op.name),
                              ),
                            )
                            .toList(),
                        onChanged: (v) {
                          if (v == null) return;
                          group.conditions[i] = FolioDbFilterCondition(
                            propertyId: c.propertyId,
                            op: v,
                            value: c.value,
                          );
                          _emit();
                          setState(() {});
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        initialValue: '${c.value ?? ''}',
                        decoration: InputDecoration(
                          isDense: true,
                          labelText: _t('Valor', 'Value'),
                        ),
                        onChanged: (v) {
                          group.conditions[i] = FolioDbFilterCondition(
                            propertyId: c.propertyId,
                            op: c.op,
                            value: v,
                          );
                          _emit();
                        },
                      ),
                    ),
                    IconButton(
                      tooltip: _t('Quitar filtro', 'Remove filter'),
                      onPressed: () {
                        group.conditions.removeAt(i);
                        if (group.conditions.isEmpty && group.groups.isEmpty) {
                          active.filter = null;
                        }
                        _emit();
                        setState(() {});
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                );
              }),
            ],
            if (active.sorts.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...active.sorts.asMap().entries.map((entry) {
                final i = entry.key;
                final s = entry.value;
                return Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: s.propertyId,
                        items: _data.properties
                            .map(
                              (p) => DropdownMenuItem(
                                value: p.id,
                                child: Text(p.name),
                              ),
                            )
                            .toList(),
                        onChanged: (v) {
                          if (v == null) return;
                          active.sorts[i] = FolioDbSortSpec(
                            propertyId: v,
                            desc: s.desc,
                          );
                          _emit();
                          setState(() {});
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Switch(
                      value: s.desc,
                      onChanged: (v) {
                        active.sorts[i] = FolioDbSortSpec(
                          propertyId: s.propertyId,
                          desc: v,
                        );
                        _emit();
                        setState(() {});
                      },
                    ),
                    Text(l10n.databaseSortDescending),
                    IconButton(
                      tooltip: _t('Quitar sort', 'Remove sort'),
                      onPressed: () {
                        active.sorts.removeAt(i);
                        _emit();
                        setState(() {});
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildView(FolioDbView view, List<FolioDbRow> rows) {
    switch (view.type) {
      case FolioDbViewType.board:
        return _buildBoard(view, rows);
      case FolioDbViewType.calendar:
        return _buildCalendar(view, rows);
      case FolioDbViewType.list:
        return _buildList(view, rows);
      case FolioDbViewType.table:
        return _buildTable(view, rows);
    }
  }

  Widget _buildList(FolioDbView view, List<FolioDbRow> rows) {
    if (_data.properties.isEmpty) {
      return const SizedBox.shrink();
    }
    final visibleProps = _visiblePropertiesFor(view);
    final titleProp = visibleProps.first;
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: rows.length,
      separatorBuilder: (context, i) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final r = rows[i];
        final title = (r.values[titleProp.id] ?? '').toString();
        final rest = visibleProps
            .skip(1)
            .take(4)
            .map((p) {
              final v = (r.values[p.id] ?? '').toString();
              if (v.isEmpty) return null;
              return '${p.name}: $v';
            })
            .whereType<String>()
            .join(' · ');
        return Material(
          color: _panelColor,
          borderRadius: BorderRadius.circular(12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: _subtleBorder),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title.isEmpty ? '—' : title,
                        style: widget.textTheme.titleSmall,
                      ),
                    ),
                    if (_isEditMode)
                      PopupMenuButton<String>(
                        tooltip: _t('Acciones de fila', 'Row actions'),
                        onSelected: (value) {
                          if (value == 'duplicate') {
                            _duplicateRow(r);
                          } else if (value == 'delete') {
                            _deleteRow(r);
                          }
                        },
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            value: 'duplicate',
                            child: Text(_t('Duplicar fila', 'Duplicate row')),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Text(_t('Eliminar fila', 'Delete row')),
                          ),
                        ],
                      ),
                  ],
                ),
                if (rest.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    rest,
                    style: widget.textTheme.bodySmall?.copyWith(
                      color: widget.scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTable(FolioDbView view, List<FolioDbRow> rows) {
    final visibleProps = _visiblePropertiesFor(view);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStatePropertyAll(
          widget.scheme.surfaceContainerLow,
        ),
        dividerThickness: 0.6,
        columnSpacing: 14,
        horizontalMargin: 10,
        dataRowMinHeight: 52,
        dataRowMaxHeight: 96,
        rows: rows.map((r) {
          return DataRow(
            cells: [
              ...visibleProps.map(
                (p) => DataCell(
                  SizedBox(
                    width: 170,
                    child: _buildPropertyEditorCell(
                      r,
                      p,
                      editable: _isEditMode,
                    ),
                  ),
                ),
              ),
              if (_isEditMode)
                DataCell(
                  PopupMenuButton<String>(
                    tooltip: _t('Acciones de fila', 'Row actions'),
                    onSelected: (value) {
                      if (value == 'duplicate') {
                        _duplicateRow(r);
                      } else if (value == 'delete') {
                        _deleteRow(r);
                      }
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'duplicate',
                        child: Text(_t('Duplicar fila', 'Duplicate row')),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text(_t('Eliminar fila', 'Delete row')),
                      ),
                    ],
                    child: const Icon(Icons.more_horiz_rounded, size: 18),
                  ),
                ),
            ],
          );
        }).toList(),
        headingRowHeight: 44,
        columns: [
          ...visibleProps.map(
            (p) => DataColumn(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(p.name),
                  if (_isEditMode)
                    IconButton(
                      tooltip:
                          AppLocalizations.of(context).databaseConfigurePropertyTooltip,
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.tune_rounded, size: 16),
                      onPressed: () => _showPropertyConfigDialog(p),
                    ),
                ],
              ),
            ),
          ),
          if (_isEditMode) DataColumn(label: Text(_t('Acciones', 'Actions'))),
        ],
      ),
    );
  }

  Widget _buildPropertyEditorCell(
    FolioDbRow row,
    FolioDbProperty property, {
    required bool editable,
  }) {
    final resolved = _data.resolvedValue(row, property);
    final isComputed =
        property.type == FolioDbPropertyType.formula ||
        property.type == FolioDbPropertyType.rollup;
    if (isComputed) {
      return Text((resolved ?? '').toString());
    }
    if (!editable) {
      final raw = _data.sanitizedValue(property, row.values[property.id]);
      if (property.type == FolioDbPropertyType.checkbox) {
        return Icon(
          raw == true
              ? Icons.check_box_rounded
              : Icons.check_box_outline_blank_rounded,
          size: 18,
        );
      }
      if (property.type == FolioDbPropertyType.multiSelect && raw is List) {
        return Wrap(
          spacing: 4,
          runSpacing: 4,
          children: raw
              .map(
                (e) => Chip(
                  label: Text(e.toString()),
                  visualDensity: VisualDensity.compact,
                  side: BorderSide(color: _subtleBorder),
                  backgroundColor: widget.scheme.surfaceContainerLow,
                ),
              )
              .take(3)
              .toList(),
        );
      }
      return Text((raw ?? '').toString());
    }
    if (property.type == FolioDbPropertyType.relation) {
      return Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
          icon: const Icon(Icons.link_rounded, size: 14),
          label: Text(_relationSummary(row, property)),
          onPressed: () => _showRelationPicker(row, property),
        ),
      );
    }

    final raw = _data.sanitizedValue(property, row.values[property.id]);
    switch (property.type) {
      case FolioDbPropertyType.checkbox:
        return Checkbox(
          value: raw == true,
          onChanged: (v) => _updateRowValue(row, property, v == true),
        );
      case FolioDbPropertyType.select:
        final value = (raw ?? '').toString();
        final opts = property.options;
        if (opts.isEmpty) {
          return TextFormField(
            initialValue: value,
            decoration: const InputDecoration(
              isDense: true,
              border: InputBorder.none,
            ),
            onChanged: (v) => _updateRowValue(row, property, v),
          );
        }
        final selected = opts.contains(value) ? value : null;
        return DropdownButtonFormField<String>(
          initialValue: selected,
          isDense: true,
          decoration: const InputDecoration(
            border: InputBorder.none,
            isDense: true,
          ),
          items: opts
              .map((o) => DropdownMenuItem(value: o, child: Text(o)))
              .toList(),
          onChanged: (v) {
            if (v != null) _updateRowValue(row, property, v);
          },
        );
      case FolioDbPropertyType.multiSelect:
        final values = (raw is List ? raw : const <String>[])
            .map((e) => e.toString())
            .toList();
        return Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            for (final val in values)
              InputChip(
                label: Text(val),
                onDeleted: () {
                  final next = [...values]..remove(val);
                  _updateRowValue(row, property, next);
                },
              ),
            ActionChip(
              avatar: const Icon(Icons.add_rounded, size: 14),
              label: Text(_t('Añadir', 'Add')),
              onPressed: () async {
                final ctrl = TextEditingController();
                final tag = await showDialog<String>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(_t('Añadir etiqueta', 'Add tag')),
                    content: TextField(
                      controller: ctrl,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: _t('Etiqueta', 'Tag'),
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: Text(_t('Cancelar', 'Cancel')),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
                        child: Text(_t('Guardar', 'Save')),
                      ),
                    ],
                  ),
                );
                if (tag == null || tag.isEmpty) return;
                final next = {...values, tag}.toList();
                _updateRowValue(row, property, next);
              },
            ),
          ],
        );
      case FolioDbPropertyType.date:
        final value = (raw ?? '').toString();
        return OutlinedButton.icon(
          icon: const Icon(Icons.calendar_today_rounded, size: 14),
          label: Text(value.isEmpty ? _t('Sin fecha', 'No date') : value),
          onPressed: () async {
            final initial = DateTime.tryParse(value) ?? DateTime.now();
            final picked = await showDatePicker(
              context: context,
              initialDate: initial,
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            );
            if (picked == null) return;
            final iso =
                '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
            _updateRowValue(row, property, iso);
          },
        );
      case FolioDbPropertyType.number:
        return TextFormField(
          initialValue: raw?.toString() ?? '',
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            isDense: true,
            border: InputBorder.none,
          ),
          onChanged: (v) => _updateRowValue(row, property, v),
        );
      default:
        return TextFormField(
          initialValue: raw?.toString() ?? '',
          decoration: const InputDecoration(
            isDense: true,
            border: InputBorder.none,
          ),
          onChanged: (v) => _updateRowValue(row, property, v),
        );
    }
  }

  String _relationSummary(FolioDbRow row, FolioDbProperty relationProp) {
    final ids = _data.sanitizedValue(relationProp, row.values[relationProp.id]);
    if (ids is! List || ids.isEmpty) return 'Sin relación';
    return '${ids.length} vinculadas';
  }

  Future<void> _showCreatePropertyDialog() async {
    final l10n = AppLocalizations.of(context);
    final nameCtrl = TextEditingController(text: 'Propiedad');
    FolioDbPropertyType type = FolioDbPropertyType.text;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(l10n.databaseNewPropertyDialogTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(labelText: l10n.nameLabel),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<FolioDbPropertyType>(
                initialValue: type,
                items: FolioDbPropertyType.values
                    .map((t) => DropdownMenuItem(value: t, child: Text(t.name)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) type = v;
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.createAction),
            ),
          ],
        );
      },
    );
    if (ok != true) return;
    final p = FolioDbProperty(
      id: 'p_${_uuid.v4()}',
      name: nameCtrl.text.trim().isEmpty ? 'Propiedad' : nameCtrl.text.trim(),
      type: type,
    );
    _data.properties.add(p);
    _emit();
    setState(() {});
  }

  Future<void> _showPropertyConfigDialog(FolioDbProperty property) async {
    final nameCtrl = TextEditingController(text: property.name);
    final formulaCtrl = TextEditingController(
      text: property.formulaExpression ?? '',
    );
    final relPropId = ValueNotifier<String?>(property.rollupRelationPropertyId);
    final rollupTargetId = ValueNotifier<String?>(
      property.rollupTargetPropertyId,
    );
    final rollupOp = ValueNotifier<String>(property.rollupOperation ?? 'count');
    final relationTarget = ValueNotifier<String?>(
      property.relationTargetDatabaseId,
    );
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        final dlgL10n = AppLocalizations.of(ctx);
        return AlertDialog(
          title: Text(dlgL10n.databaseConfigurePropertyTitle(property.name)),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(labelText: dlgL10n.nameLabel),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<FolioDbPropertyType>(
                    initialValue: property.type,
                    items: FolioDbPropertyType.values
                        .map(
                          (t) =>
                              DropdownMenuItem(value: t, child: Text(t.name)),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) property.type = v;
                    },
                  ),
                  const SizedBox(height: 8),
                  if (property.type == FolioDbPropertyType.formula) ...[
                    TextField(
                      controller: formulaCtrl,
                      decoration: InputDecoration(
                        labelText: _t('Fórmula', 'Formula'),
                        hintText: dlgL10n.databaseFormulaHintExample,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Funciones: if, concat, upper, lower, contains, add/sub/mul/div, now, date, daysBetween',
                    ),
                  ],
                  if (property.type == FolioDbPropertyType.relation) ...[
                    ValueListenableBuilder<String?>(
                      valueListenable: relationTarget,
                      builder: (context, v, child) =>
                          DropdownButtonFormField<String>(
                            initialValue: v,
                            items: [
                              DropdownMenuItem(
                                value: 'local-db',
                                child: Text(dlgL10n.databaseLocalCurrentBadge),
                              ),
                            ],
                            onChanged: (nv) => relationTarget.value = nv,
                            decoration: const InputDecoration(
                              labelText: 'Target DB',
                            ),
                          ),
                    ),
                  ],
                  if (property.type == FolioDbPropertyType.rollup) ...[
                    ValueListenableBuilder<String?>(
                      valueListenable: relPropId,
                      builder: (context, v, child) =>
                          DropdownButtonFormField<String>(
                            initialValue: v,
                            items: _data.properties
                                .where(
                                  (p) => p.type == FolioDbPropertyType.relation,
                                )
                                .map(
                                  (p) => DropdownMenuItem(
                                    value: p.id,
                                    child: Text(p.name),
                                  ),
                                )
                                .toList(),
                            onChanged: (nv) => relPropId.value = nv,
                            decoration: const InputDecoration(
                              labelText: 'Propiedad relation',
                            ),
                          ),
                    ),
                    const SizedBox(height: 8),
                    ValueListenableBuilder<String?>(
                      valueListenable: rollupTargetId,
                      builder: (context, v, child) =>
                          DropdownButtonFormField<String>(
                            initialValue: v,
                            items: _data.properties
                                .where(
                                  (p) => p.type != FolioDbPropertyType.rollup,
                                )
                                .map(
                                  (p) => DropdownMenuItem(
                                    value: p.id,
                                    child: Text(p.name),
                                  ),
                                )
                                .toList(),
                            onChanged: (nv) => rollupTargetId.value = nv,
                            decoration: const InputDecoration(
                              labelText: 'Propiedad target',
                            ),
                          ),
                    ),
                    const SizedBox(height: 8),
                    ValueListenableBuilder<String>(
                      valueListenable: rollupOp,
                      builder: (context, v, child) =>
                          DropdownButtonFormField<String>(
                            initialValue: v,
                            items:
                                const [
                                      'count',
                                      'sum',
                                      'avg',
                                      'min',
                                      'max',
                                      'percent_checked',
                                    ]
                                    .map(
                                      (op) => DropdownMenuItem(
                                        value: op,
                                        child: Text(op),
                                      ),
                                    )
                                    .toList(),
                            onChanged: (nv) {
                              if (nv != null) rollupOp.value = nv;
                            },
                            decoration: const InputDecoration(
                              labelText: 'Operación rollup',
                            ),
                          ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(dlgL10n.cancel),
            ),
            FilledButton(
              onPressed: () {
                property.name = nameCtrl.text.trim().isEmpty
                    ? property.name
                    : nameCtrl.text.trim();
                property.formulaExpression = formulaCtrl.text.trim().isEmpty
                    ? null
                    : formulaCtrl.text.trim();
                property.relationTargetDatabaseId = relationTarget.value;
                property.rollupRelationPropertyId = relPropId.value;
                property.rollupTargetPropertyId = rollupTargetId.value;
                property.rollupOperation = rollupOp.value;
                _emit();
                setState(() {});
                Navigator.pop(ctx);
              },
              child: Text(dlgL10n.save),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showRelationPicker(
    FolioDbRow host,
    FolioDbProperty relationProp,
  ) async {
    final l10n = AppLocalizations.of(context);
    final current = _data
        .sanitizedValue(relationProp, host.values[relationProp.id])
        .cast<String>()
        .toSet();
    final allRows = _data.rows.where((r) => r.id != host.id).toList();
    final selected = Set<String>.from(current);
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(l10n.databaseRelateRowsTitle(relationProp.name)),
          content: SizedBox(
            width: 420,
            height: 360,
            child: ListView.builder(
              itemCount: allRows.length,
              itemBuilder: (_, i) {
                final row = allRows[i];
                final titleProp = _data.properties.first.id;
                final label = (row.values[titleProp] ?? row.id).toString();
                final checked = selected.contains(row.id);
                return CheckboxListTile(
                  value: checked,
                  title: Text(label),
                  subtitle: Text(row.id, style: const TextStyle(fontSize: 11)),
                  onChanged: (v) {
                    if (v == true) {
                      selected.add(row.id);
                    } else {
                      selected.remove(row.id);
                    }
                    (ctx as Element).markNeedsBuild();
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () {
                host.values[relationProp.id] = selected.toList();
                _emit();
                setState(() {});
                Navigator.pop(ctx);
              },
              child: Text(l10n.save),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBoard(FolioDbView view, List<FolioDbRow> rows) {
    final l10n = AppLocalizations.of(context);
    final groupId = view.groupByPropertyId;
    if (groupId == null) {
      return Text(l10n.databaseBoardNeedsGroupProperty);
    }
    final groupProperty = _data.properties
        .where((p) => p.id == groupId)
        .firstOrNull;
    if (groupProperty == null) {
      return Text(l10n.databaseGroupPropertyMissing);
    }
    final emptyLabel = _t('Sin estado', 'No status');
    final groups = <String, List<FolioDbRow>>{};
    if (groupProperty.type == FolioDbPropertyType.select &&
        groupProperty.options.isNotEmpty) {
      for (final option in groupProperty.options) {
        groups.putIfAbsent(option, () => <FolioDbRow>[]);
      }
      groups.putIfAbsent(emptyLabel, () => <FolioDbRow>[]);
    }
    for (final r in rows) {
      final raw = (r.values[groupId] ?? '').toString().trim();
      final key = raw.isEmpty ? emptyLabel : raw;
      groups.putIfAbsent(key, () => []).add(r);
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: groups.entries.map((e) {
          return DragTarget<FolioDbRow>(
            onAcceptWithDetails: (details) {
              _moveRowToBoardGroup(
                details.data,
                groupProperty,
                e.key,
                emptyLabel,
              );
            },
            builder: (context, candidates, rejected) {
              return Container(
                width: 260,
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: candidates.isNotEmpty
                        ? widget.scheme.primary
                        : _subtleBorder,
                  ),
                  color: candidates.isNotEmpty
                      ? widget.scheme.primaryContainer.withValues(alpha: 0.2)
                      : _panelColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '${e.key} (${e.value.length})',
                      style: widget.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    ...e.value.map((r) {
                      final titleProp = _data.properties.first.id;
                      final title =
                          (r.values[titleProp] ?? _t('Sin título', 'Untitled'))
                              .toString();
                      return LongPressDraggable<FolioDbRow>(
                        data: r,
                        feedback: Material(
                          elevation: 6,
                          borderRadius: BorderRadius.circular(8),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 220),
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Text(title),
                            ),
                          ),
                        ),
                        childWhenDragging: Opacity(
                          opacity: 0.35,
                          child: Card(
                            elevation: 0,
                            margin: const EdgeInsets.only(bottom: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: BorderSide(color: _subtleBorder),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Text(title),
                            ),
                          ),
                        ),
                        child: Card(
                          elevation: 0,
                          margin: const EdgeInsets.only(bottom: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(color: _subtleBorder),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Text(title),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              );
            },
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCalendar(FolioDbView view, List<FolioDbRow> rows) {
    final l10n = AppLocalizations.of(context);
    final datePropId = view.calendarDatePropertyId;
    if (datePropId == null) {
      return Text(l10n.databaseCalendarNeedsDateProperty);
    }
    final byDate = <String, List<FolioDbRow>>{};
    for (final r in rows) {
      final key = (r.values[datePropId] ?? '').toString().trim();
      if (key.isEmpty) continue;
      byDate.putIfAbsent(key, () => []).add(r);
    }
    final keys = byDate.keys.toList()..sort();
    if (keys.isEmpty) return Text(l10n.databaseNoDatedEvents);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: keys.map((k) {
        final group = byDate[k]!;
        return Card(
          color: _panelColor,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: _subtleBorder),
          ),
          margin: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(k, style: widget.textTheme.titleSmall),
                const SizedBox(height: 6),
                ...group.map((r) {
                  final titleProp = _data.properties.first.id;
                  return Text(
                    '- ${(r.values[titleProp] ?? 'Sin título').toString()}',
                  );
                }),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

enum _DatabaseViewMode { view, edit }
