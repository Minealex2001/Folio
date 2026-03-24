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
  });

  final String json;
  final ValueChanged<String> onChanged;
  final ColorScheme scheme;
  final TextTheme textTheme;

  @override
  State<DatabaseBlockEditor> createState() => _DatabaseBlockEditorState();
}

class _DatabaseBlockEditorState extends State<DatabaseBlockEditor> {
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

  bool get _isEs => Localizations.localeOf(
    context,
  ).languageCode.toLowerCase().startsWith('es');

  String _t(String es, String en) => _isEs ? es : en;

  @override
  Widget build(BuildContext context) {
    final active = _activeView;
    final rows = _visibleRowsFor(active);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            SegmentedButton<String>(
              segments: [
                ButtonSegment(value: 'table', label: Text('Tabla')),
                ButtonSegment(value: 'list', label: Text(_t('Lista', 'List'))),
                ButtonSegment(
                  value: 'board',
                  label: Text(_t('Tablero', 'Board')),
                ),
                ButtonSegment(
                  value: 'calendar',
                  label: Text(_t('Calendario', 'Calendar')),
                ),
              ],
              selected: {active.type.name},
              onSelectionChanged: (s) {
                final type = s.first;
                final next = _data.views.firstWhere(
                  (v) => v.type.name == type,
                  orElse: () => _data.views.first,
                );
                _data.activeViewId = next.id;
                _emit();
                setState(() {});
              },
            ),
            OutlinedButton.icon(
              onPressed: _addProperty,
              icon: const Icon(Icons.view_column_rounded, size: 18),
              label: Text(_t('Añadir propiedad', 'Add property')),
            ),
            FilledButton.tonalIcon(
              onPressed: _addRow,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(_t('Nueva fila', 'New row')),
            ),
            OutlinedButton.icon(
              onPressed: () {
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
              },
              icon: const Icon(Icons.filter_alt_outlined, size: 18),
              label: Text(_t('Aplicar filtro', 'Apply filter')),
            ),
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
              label: const Text('Sort A-Z'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _propertiesCard(),
        const SizedBox(height: 8),
        TextField(
          controller: _filterController,
          decoration: InputDecoration(
            border: OutlineInputBorder(),
            isDense: true,
            labelText: _t(
              'Filtro rápido (columna principal)',
              'Quick filter (main column)',
            ),
          ),
          onSubmitted: (_) {
            setState(() {});
          },
        ),
        const SizedBox(height: 8),
        _queryBuilderCard(active),
        const SizedBox(height: 8),
        _buildView(active, rows),
      ],
    );
  }

  Widget _propertiesCard() {
    return Card(
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
    final group = active.filter;
    return Card(
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
                  label: const Text('Sort'),
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
                    items: const [
                      DropdownMenuItem(
                        value: FolioDbLogicalOperator.and,
                        child: Text('AND'),
                      ),
                      DropdownMenuItem(
                        value: FolioDbLogicalOperator.or,
                        child: Text('OR'),
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
                    const Text('Desc'),
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
    final titleProp = _data.properties.first;
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: rows.length,
      separatorBuilder: (context, i) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final r = rows[i];
        final title = (r.values[titleProp.id] ?? '').toString();
        final rest = _data.properties
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
          color: widget.scheme.surfaceContainerHighest.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  title.isEmpty ? '—' : title,
                  style: widget.textTheme.titleSmall,
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
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: _data.properties
            .map(
              (p) => DataColumn(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(p.name),
                    IconButton(
                      tooltip: 'Configurar propiedad',
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.tune_rounded, size: 16),
                      onPressed: () => _showPropertyConfigDialog(p),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
        rows: rows.map((r) {
          return DataRow(
            cells: _data.properties.map((p) {
              final value = (r.values[p.id] ?? '').toString();
              final isComputed =
                  p.type == FolioDbPropertyType.formula ||
                  p.type == FolioDbPropertyType.rollup;
              final computed = _data.resolvedValue(r, p);
              final isRelation = p.type == FolioDbPropertyType.relation;
              return DataCell(
                SizedBox(
                  width: 160,
                  child: isComputed
                      ? Text((computed ?? '').toString())
                      : isRelation
                      ? Align(
                          alignment: Alignment.centerLeft,
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.link_rounded, size: 14),
                            label: Text(_relationSummary(r, p)),
                            onPressed: () => _showRelationPicker(r, p),
                          ),
                        )
                      : TextFormField(
                          initialValue: value,
                          decoration: const InputDecoration(
                            isDense: true,
                            border: InputBorder.none,
                          ),
                          onChanged: (v) {
                            r.values[p.id] = _data.sanitizedValue(p, v);
                            _emit();
                          },
                        ),
                ),
              );
            }).toList(),
          );
        }).toList(),
      ),
    );
  }

  String _relationSummary(FolioDbRow row, FolioDbProperty relationProp) {
    final ids = _data.sanitizedValue(relationProp, row.values[relationProp.id]);
    if (ids is! List || ids.isEmpty) return 'Sin relación';
    return '${ids.length} vinculadas';
  }

  Future<void> _showCreatePropertyDialog() async {
    final nameCtrl = TextEditingController(text: 'Propiedad');
    FolioDbPropertyType type = FolioDbPropertyType.text;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Nueva propiedad'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Nombre'),
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
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Crear'),
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
        return AlertDialog(
          title: Text('Configurar: ${property.name}'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Nombre'),
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
                      decoration: const InputDecoration(
                        labelText: 'Fórmula',
                        hintText: 'if(contains(Nombre,"x"), add(1,2), 0)',
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
                            items: const [
                              DropdownMenuItem(
                                value: 'local-db',
                                child: Text('DB local actual'),
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
              child: const Text('Cancelar'),
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
              child: const Text('Guardar'),
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
          title: Text('Relacionar filas (${relationProp.name})'),
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
    final groupId = view.groupByPropertyId;
    if (groupId == null) {
      return const Text('Configura una propiedad de grupo para tablero.');
    }
    final groups = <String, List<FolioDbRow>>{};
    for (final r in rows) {
      final key = (r.values[groupId] ?? 'Sin estado').toString();
      groups.putIfAbsent(key, () => []).add(r);
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: groups.entries.map((e) {
          return Container(
            width: 240,
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              border: Border.all(color: widget.scheme.outlineVariant),
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
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Text(
                        (r.values[titleProp] ?? 'Sin título').toString(),
                      ),
                    ),
                  );
                }),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCalendar(FolioDbView view, List<FolioDbRow> rows) {
    final datePropId = view.calendarDatePropertyId;
    if (datePropId == null) {
      return const Text('Configura una propiedad de fecha para calendario.');
    }
    final byDate = <String, List<FolioDbRow>>{};
    for (final r in rows) {
      final key = (r.values[datePropId] ?? '').toString().trim();
      if (key.isEmpty) continue;
      byDate.putIfAbsent(key, () => []).add(r);
    }
    final keys = byDate.keys.toList()..sort();
    if (keys.isEmpty) return const Text('Sin eventos con fecha.');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: keys.map((k) {
        final group = byDate[k]!;
        return Card(
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
