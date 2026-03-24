import 'dart:convert';
import 'folio_table_data.dart';

enum FolioDbPropertyType {
  text,
  number,
  select,
  multiSelect,
  date,
  checkbox,
  url,
  email,
  phone,
  files,
  relation,
  rollup,
  formula,
}

enum FolioDbViewType { table, board, calendar }

enum FolioDbFilterOperator {
  equals,
  notEquals,
  contains,
  notContains,
  greaterThan,
  lessThan,
  isEmpty,
  isNotEmpty,
  inList,
}

enum FolioDbLogicalOperator { and, or }

class FolioDbFilterCondition {
  FolioDbFilterCondition({
    required this.propertyId,
    required this.op,
    this.value,
  });

  final String propertyId;
  final FolioDbFilterOperator op;
  final dynamic value;

  Map<String, dynamic> toJson() => {
    'kind': 'condition',
    'propertyId': propertyId,
    'op': op.name,
    if (value != null) 'value': value,
  };

  factory FolioDbFilterCondition.fromJson(Map<String, dynamic> j) {
    final rawOp = j['op'] as String? ?? FolioDbFilterOperator.contains.name;
    return FolioDbFilterCondition(
      propertyId: j['propertyId'] as String? ?? '',
      op: FolioDbFilterOperator.values.firstWhere(
        (e) => e.name == rawOp,
        orElse: () => FolioDbFilterOperator.contains,
      ),
      value: j['value'],
    );
  }
}

class FolioDbFilterGroup {
  FolioDbFilterGroup({
    required this.logical,
    List<FolioDbFilterCondition>? conditions,
    List<FolioDbFilterGroup>? groups,
  }) : conditions = List<FolioDbFilterCondition>.from(conditions ?? const []),
       groups = List<FolioDbFilterGroup>.from(groups ?? const []);

  final FolioDbLogicalOperator logical;
  List<FolioDbFilterCondition> conditions;
  List<FolioDbFilterGroup> groups;

  Map<String, dynamic> toJson() => {
    'kind': 'group',
    'logical': logical.name,
    if (conditions.isNotEmpty)
      'conditions': conditions.map((c) => c.toJson()).toList(),
    if (groups.isNotEmpty) 'groups': groups.map((g) => g.toJson()).toList(),
  };

  factory FolioDbFilterGroup.fromJson(Map<String, dynamic> j) {
    final rawLogical =
        j['logical'] as String? ?? FolioDbLogicalOperator.and.name;
    return FolioDbFilterGroup(
      logical: FolioDbLogicalOperator.values.firstWhere(
        (e) => e.name == rawLogical,
        orElse: () => FolioDbLogicalOperator.and,
      ),
      conditions: (j['conditions'] as List<dynamic>? ?? [])
          .whereType<Map>()
          .map(
            (e) =>
                FolioDbFilterCondition.fromJson(Map<String, dynamic>.from(e)),
          )
          .toList(),
      groups: (j['groups'] as List<dynamic>? ?? [])
          .whereType<Map>()
          .map((e) => FolioDbFilterGroup.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

class FolioDbSortSpec {
  FolioDbSortSpec({required this.propertyId, this.desc = false});

  final String propertyId;
  final bool desc;

  Map<String, dynamic> toJson() => {'propertyId': propertyId, 'desc': desc};

  factory FolioDbSortSpec.fromJson(Map<String, dynamic> j) {
    return FolioDbSortSpec(
      propertyId: j['propertyId'] as String? ?? '',
      desc: j['desc'] == true,
    );
  }
}

class FolioDbProperty {
  FolioDbProperty({
    required this.id,
    required this.name,
    required this.type,
    List<String>? options,
  }) : options = List<String>.from(options ?? const []);

  final String id;
  String name;
  FolioDbPropertyType type;
  List<String> options;
  String? formulaExpression;
  String? relationTargetDatabaseId;
  String? rollupRelationPropertyId;
  String? rollupTargetPropertyId;
  String? rollupOperation;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type.name,
    if (options.isNotEmpty) 'options': options,
    if (formulaExpression != null) 'formulaExpression': formulaExpression,
    if (relationTargetDatabaseId != null)
      'relationTargetDatabaseId': relationTargetDatabaseId,
    if (rollupRelationPropertyId != null)
      'rollupRelationPropertyId': rollupRelationPropertyId,
    if (rollupTargetPropertyId != null)
      'rollupTargetPropertyId': rollupTargetPropertyId,
    if (rollupOperation != null) 'rollupOperation': rollupOperation,
  };

  factory FolioDbProperty.fromJson(Map<String, dynamic> j) {
    final rawType = j['type'] as String? ?? 'text';
    return FolioDbProperty(
        id: j['id'] as String,
        name: j['name'] as String? ?? 'Propiedad',
        type: FolioDbPropertyType.values.firstWhere(
          (e) => e.name == rawType,
          orElse: () => FolioDbPropertyType.text,
        ),
        options: (j['options'] as List<dynamic>? ?? [])
            .map((e) => e.toString())
            .toList(),
      )
      ..formulaExpression = j['formulaExpression'] as String?
      ..relationTargetDatabaseId = j['relationTargetDatabaseId'] as String?
      ..rollupRelationPropertyId = j['rollupRelationPropertyId'] as String?
      ..rollupTargetPropertyId = j['rollupTargetPropertyId'] as String?
      ..rollupOperation = j['rollupOperation'] as String?;
  }
}

class FolioDbRow {
  FolioDbRow({required this.id, Map<String, dynamic>? values})
    : values = Map<String, dynamic>.from(values ?? const {});

  final String id;
  Map<String, dynamic> values;

  Map<String, dynamic> toJson() => {'id': id, 'values': values};

  factory FolioDbRow.fromJson(Map<String, dynamic> j) {
    return FolioDbRow(
      id: j['id'] as String,
      values: Map<String, dynamic>.from(j['values'] as Map? ?? const {}),
    );
  }
}

class FolioDbView {
  FolioDbView({
    required this.id,
    required this.name,
    required this.type,
    this.groupByPropertyId,
    this.calendarDatePropertyId,
    this.filter,
    List<FolioDbSortSpec>? sorts,
  }) : sorts = List<FolioDbSortSpec>.from(sorts ?? const []);

  final String id;
  String name;
  FolioDbViewType type;
  String? groupByPropertyId;
  String? calendarDatePropertyId;
  FolioDbFilterGroup? filter;
  List<FolioDbSortSpec> sorts;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type.name,
    if (groupByPropertyId != null) 'groupByPropertyId': groupByPropertyId,
    if (calendarDatePropertyId != null)
      'calendarDatePropertyId': calendarDatePropertyId,
    if (filter != null) 'filter': filter!.toJson(),
    if (sorts.isNotEmpty) 'sorts': sorts.map((s) => s.toJson()).toList(),
  };

  factory FolioDbView.fromJson(Map<String, dynamic> j) {
    final rawType = j['type'] as String? ?? 'table';
    return FolioDbView(
      id: j['id'] as String,
      name: j['name'] as String? ?? 'Vista',
      type: FolioDbViewType.values.firstWhere(
        (e) => e.name == rawType,
        orElse: () => FolioDbViewType.table,
      ),
      groupByPropertyId: j['groupByPropertyId'] as String?,
      calendarDatePropertyId: j['calendarDatePropertyId'] as String?,
      filter: () {
        final f = j['filter'];
        if (f is Map) {
          return FolioDbFilterGroup.fromJson(Map<String, dynamic>.from(f));
        }
        // Compatibilidad legacy: array plana de filtros contains.
        final legacy = (j['filters'] as List<dynamic>? ?? [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        if (legacy.isEmpty) return null;
        return FolioDbFilterGroup(
          logical: FolioDbLogicalOperator.and,
          conditions: legacy
              .map(
                (m) => FolioDbFilterCondition(
                  propertyId: m['propertyId'] as String? ?? '',
                  op: FolioDbFilterOperator.contains,
                  value: m['contains'],
                ),
              )
              .toList(),
        );
      }(),
      sorts: (j['sorts'] as List<dynamic>? ?? [])
          .whereType<Map>()
          .map((e) => FolioDbSortSpec.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

class FolioDatabaseData {
  FolioDatabaseData({
    required List<FolioDbProperty> properties,
    required List<FolioDbRow> rows,
    required List<FolioDbView> views,
    this.activeViewId,
    this.schemaVersion = currentVersion,
  }) : properties = List<FolioDbProperty>.from(properties),
       rows = List<FolioDbRow>.from(rows),
       views = List<FolioDbView>.from(views);

  static const int currentVersion = 3;

  List<FolioDbProperty> properties;
  List<FolioDbRow> rows;
  List<FolioDbView> views;
  String? activeViewId;
  int schemaVersion;

  factory FolioDatabaseData.empty() {
    final titleProp = FolioDbProperty(
      id: 'p_title',
      name: 'Nombre',
      type: FolioDbPropertyType.text,
    );
    final statusProp = FolioDbProperty(
      id: 'p_status',
      name: 'Estado',
      type: FolioDbPropertyType.select,
      options: const ['Pendiente', 'En curso', 'Hecho'],
    );
    final dateProp = FolioDbProperty(
      id: 'p_date',
      name: 'Fecha',
      type: FolioDbPropertyType.date,
    );
    final table = FolioDbView(
      id: 'v_table',
      name: 'Tabla',
      type: FolioDbViewType.table,
    );
    final board = FolioDbView(
      id: 'v_board',
      name: 'Tablero',
      type: FolioDbViewType.board,
      groupByPropertyId: statusProp.id,
    );
    final calendar = FolioDbView(
      id: 'v_calendar',
      name: 'Calendario',
      type: FolioDbViewType.calendar,
      calendarDatePropertyId: dateProp.id,
    );
    return FolioDatabaseData(
      properties: [titleProp, statusProp, dateProp],
      rows: [],
      views: [table, board, calendar],
      activeViewId: table.id,
    );
  }

  factory FolioDatabaseData.fromLegacyTable(
    FolioTableData t, {
    String rowIdPrefix = 'r',
  }) {
    final db = FolioDatabaseData.empty();
    db.properties = [
      FolioDbProperty(
        id: 'p_title',
        name: 'Columna 1',
        type: FolioDbPropertyType.text,
      ),
      for (var i = 1; i < t.cols; i++)
        FolioDbProperty(
          id: 'p_c$i',
          name: 'Columna ${i + 1}',
          type: FolioDbPropertyType.text,
        ),
    ];
    db.rows = [];
    for (var r = 0; r < t.rowCount; r++) {
      final row = FolioDbRow(id: '${rowIdPrefix}_$r');
      for (var c = 0; c < db.properties.length; c++) {
        row.values[db.properties[c].id] = t.cellAt(r, c).trim();
      }
      final isEmpty = row.values.values.every((v) => '$v'.trim().isEmpty);
      if (!isEmpty) db.rows.add(row);
    }
    return db;
  }

  String encode() => jsonEncode({
    'v': currentVersion,
    'schemaVersion': schemaVersion,
    'properties': properties.map((e) => e.toJson()).toList(),
    'rows': rows.map((e) => e.toJson()).toList(),
    'views': views.map((e) => e.toJson()).toList(),
    if (activeViewId != null) 'activeViewId': activeViewId,
  });

  static FolioDatabaseData? tryParse(String text) {
    if (text.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(text);
      if (decoded is! Map) return null;
      final m = Map<String, dynamic>.from(decoded);
      final version =
          (m['schemaVersion'] as num?)?.toInt() ??
          (m['v'] as num?)?.toInt() ??
          1;
      final properties = (m['properties'] as List<dynamic>? ?? [])
          .whereType<Map>()
          .map((e) => FolioDbProperty.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      final rows = (m['rows'] as List<dynamic>? ?? [])
          .whereType<Map>()
          .map((e) => FolioDbRow.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      final views = (m['views'] as List<dynamic>? ?? [])
          .whereType<Map>()
          .map((e) => FolioDbView.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      if (properties.isEmpty || views.isEmpty) return null;
      final db = FolioDatabaseData(
        properties: properties,
        rows: rows,
        views: views,
        activeViewId: m['activeViewId'] as String?,
        schemaVersion: version,
      );
      db._migrateUpToCurrent();
      return db;
    } catch (_) {
      return null;
    }
  }

  void _migrateUpToCurrent() {
    if (schemaVersion < 2) {
      // v1->v2: asegurar estructura de sorts como lista tipada ya parseada.
      schemaVersion = 2;
    }
    if (schemaVersion < 3) {
      // v2->v3: normalizar valores de filas por tipo para evitar estados inválidos.
      for (final row in rows) {
        for (final p in properties) {
          if (!row.values.containsKey(p.id)) continue;
          row.values[p.id] = sanitizedValue(p, row.values[p.id]);
        }
      }
      schemaVersion = 3;
    }
  }

  static String plainTextFromJson(String text) {
    final d = tryParse(text);
    if (d == null) return '';
    final buffer = StringBuffer();
    for (final row in d.rows) {
      for (final p in d.properties) {
        final v = row.values[p.id];
        if (v == null) continue;
        if (v is List) {
          for (final x in v) {
            final s = x.toString().trim();
            if (s.isNotEmpty) buffer.write('$s ');
          }
          continue;
        }
        final s = v.toString().trim();
        if (s.isNotEmpty) buffer.write('$s ');
      }
    }
    return buffer.toString().trim();
  }

  dynamic resolvedValue(FolioDbRow row, FolioDbProperty property) {
    final raw = sanitizedValue(property, row.values[property.id]);
    switch (property.type) {
      case FolioDbPropertyType.formula:
        return _evalFormula(row, property.formulaExpression ?? '');
      case FolioDbPropertyType.rollup:
        return _evalRollup(row, property);
      default:
        return raw;
    }
  }

  dynamic sanitizedValue(FolioDbProperty property, dynamic raw) {
    switch (property.type) {
      case FolioDbPropertyType.number:
        if (raw is num) return raw;
        return num.tryParse('${raw ?? ''}');
      case FolioDbPropertyType.checkbox:
        if (raw is bool) return raw;
        if (raw is String) {
          final s = raw.toLowerCase().trim();
          if (s == 'true' || s == '1' || s == 'yes') return true;
          if (s == 'false' || s == '0' || s == 'no') return false;
        }
        return false;
      case FolioDbPropertyType.multiSelect:
      case FolioDbPropertyType.files:
      case FolioDbPropertyType.relation:
        if (raw is List) return raw.map((e) => '$e').toList();
        if (raw == null) return <String>[];
        return ['$raw'];
      default:
        return raw?.toString() ?? '';
    }
  }

  List<FolioDbRow> materializeRows(FolioDbView view) {
    var out = List<FolioDbRow>.from(rows);
    final f = view.filter;
    if (f != null) {
      out = out.where((r) => _matchesGroup(r, f)).toList();
    }
    for (final s in view.sorts) {
      final p = properties.where((x) => x.id == s.propertyId).firstOrNull;
      if (p == null) continue;
      out.sort((a, b) {
        final av = resolvedValue(a, p);
        final bv = resolvedValue(b, p);
        final cmp = _compareValues(av, bv);
        return s.desc ? -cmp : cmp;
      });
    }
    return out;
  }

  bool _matchesGroup(FolioDbRow row, FolioDbFilterGroup group) {
    final results = <bool>[
      ...group.conditions.map((c) => _matchesCondition(row, c)),
      ...group.groups.map((g) => _matchesGroup(row, g)),
    ];
    if (results.isEmpty) return true;
    return group.logical == FolioDbLogicalOperator.and
        ? results.every((x) => x)
        : results.any((x) => x);
  }

  bool _matchesCondition(FolioDbRow row, FolioDbFilterCondition c) {
    final p = properties.where((x) => x.id == c.propertyId).firstOrNull;
    if (p == null) return false;
    final v = resolvedValue(row, p);
    final q = c.value;
    switch (c.op) {
      case FolioDbFilterOperator.equals:
        return '$v' == '${sanitizedValue(p, q)}';
      case FolioDbFilterOperator.notEquals:
        return '$v' != '${sanitizedValue(p, q)}';
      case FolioDbFilterOperator.contains:
        return '$v'.toLowerCase().contains('${q ?? ''}'.toLowerCase());
      case FolioDbFilterOperator.notContains:
        return !'$v'.toLowerCase().contains('${q ?? ''}'.toLowerCase());
      case FolioDbFilterOperator.greaterThan:
        return _compareValues(v, sanitizedValue(p, q)) > 0;
      case FolioDbFilterOperator.lessThan:
        return _compareValues(v, sanitizedValue(p, q)) < 0;
      case FolioDbFilterOperator.isEmpty:
        return _isEmptyValue(v);
      case FolioDbFilterOperator.isNotEmpty:
        return !_isEmptyValue(v);
      case FolioDbFilterOperator.inList:
        if (q is! List) return false;
        return q.map((e) => '$e').contains('$v');
    }
  }

  bool _isEmptyValue(dynamic v) {
    if (v == null) return true;
    if (v is String) return v.trim().isEmpty;
    if (v is List) return v.isEmpty;
    return false;
  }

  int _compareValues(dynamic a, dynamic b) {
    if (a == null && b == null) return 0;
    if (a == null) return -1;
    if (b == null) return 1;
    if (a is num && b is num) return a.compareTo(b);
    if (a is bool && b is bool) return (a ? 1 : 0).compareTo(b ? 1 : 0);
    final ad = DateTime.tryParse('$a');
    final bd = DateTime.tryParse('$b');
    if (ad != null && bd != null) return ad.compareTo(bd);
    return '$a'.toLowerCase().compareTo('$b'.toLowerCase());
  }

  dynamic _evalFormula(FolioDbRow row, String expression) {
    final expr = expression.trim();
    if (expr.isEmpty) return '';
    return _evalFormulaExpr(row, expr);
  }

  dynamic _evalFormulaExpr(FolioDbRow row, String expr) {
    final s = expr.trim();
    if (s.isEmpty) return '';
    if (s.startsWith('"') && s.endsWith('"') && s.length >= 2) {
      return s.substring(1, s.length - 1);
    }
    final asNum = num.tryParse(s);
    if (asNum != null) return asNum;
    if (s == 'true') return true;
    if (s == 'false') return false;
    final fn = _tryParseFunctionCall(s);
    if (fn != null) {
      final name = fn.$1;
      final args = fn.$2.map((e) => _evalFormulaExpr(row, e)).toList();
      return _evalFormulaFunction(name, args);
    }
    final prop = properties.where((p) => p.name == s || p.id == s).firstOrNull;
    if (prop == null) return '';
    return resolvedValue(row, prop);
  }

  (String, List<String>)? _tryParseFunctionCall(String expr) {
    final open = expr.indexOf('(');
    final close = expr.lastIndexOf(')');
    if (open <= 0 || close <= open || close != expr.length - 1) return null;
    final name = expr.substring(0, open).trim().toLowerCase();
    final body = expr.substring(open + 1, close);
    return (name, _splitArgs(body));
  }

  List<String> _splitArgs(String body) {
    final out = <String>[];
    final cur = StringBuffer();
    var depth = 0;
    var inQuote = false;
    for (var i = 0; i < body.length; i++) {
      final ch = body[i];
      if (ch == '"') {
        inQuote = !inQuote;
        cur.write(ch);
        continue;
      }
      if (!inQuote) {
        if (ch == '(') depth++;
        if (ch == ')') depth--;
        if (ch == ',' && depth == 0) {
          out.add(cur.toString().trim());
          cur.clear();
          continue;
        }
      }
      cur.write(ch);
    }
    final tail = cur.toString().trim();
    if (tail.isNotEmpty) out.add(tail);
    return out;
  }

  dynamic _evalFormulaFunction(String name, List<dynamic> args) {
    switch (name) {
      case 'concat':
        return args.map((e) => '${e ?? ''}').join();
      case 'if':
        if (args.length < 3) return '';
        return _truthy(args[0]) ? args[1] : args[2];
      case 'upper':
        return args.isEmpty ? '' : '${args.first ?? ''}'.toUpperCase();
      case 'lower':
        return args.isEmpty ? '' : '${args.first ?? ''}'.toLowerCase();
      case 'contains':
        if (args.length < 2) return false;
        return '${args[0] ?? ''}'.toLowerCase().contains(
          '${args[1] ?? ''}'.toLowerCase(),
        );
      case 'add':
        if (args.length < 2) return 0;
        return _asNum(args[0]) + _asNum(args[1]);
      case 'sub':
        if (args.length < 2) return 0;
        return _asNum(args[0]) - _asNum(args[1]);
      case 'mul':
        if (args.length < 2) return 0;
        return _asNum(args[0]) * _asNum(args[1]);
      case 'div':
        if (args.length < 2) return 0;
        final b = _asNum(args[1]);
        if (b == 0) return 0;
        return _asNum(args[0]) / b;
      case 'now':
        return DateTime.now().toIso8601String();
      case 'date':
        if (args.isEmpty) return '';
        return DateTime.tryParse('${args.first ?? ''}')?.toIso8601String() ??
            '';
      case 'daysbetween':
        if (args.length < 2) return 0;
        final a = DateTime.tryParse('${args[0] ?? ''}');
        final b = DateTime.tryParse('${args[1] ?? ''}');
        if (a == null || b == null) return 0;
        return b.difference(a).inDays;
      default:
        return '';
    }
  }

  bool _truthy(dynamic v) {
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) return v.trim().isNotEmpty && v.toLowerCase() != 'false';
    if (v is List) return v.isNotEmpty;
    return v != null;
  }

  num _asNum(dynamic v) {
    if (v is num) return v;
    return num.tryParse('${v ?? ''}') ?? 0;
  }

  dynamic _evalRollup(FolioDbRow row, FolioDbProperty property) {
    final relId = property.rollupRelationPropertyId;
    final targetId = property.rollupTargetPropertyId;
    final op = (property.rollupOperation ?? 'count').toLowerCase();
    if (relId == null || targetId == null) return null;
    final linked = row.values[relId];
    if (linked is! List) return null;
    final relatedRows = rows.where((r) => linked.contains(r.id)).toList();
    if (op == 'count') return relatedRows.length;
    if (op == 'percent_checked') {
      if (relatedRows.isEmpty) return 0;
      var checked = 0;
      for (final rr in relatedRows) {
        final v = rr.values[targetId];
        if (v == true || '$v'.toLowerCase() == 'true') checked++;
      }
      return (checked * 100) / relatedRows.length;
    }
    if (op == 'sum') {
      num total = 0;
      for (final rr in relatedRows) {
        final v = rr.values[targetId];
        if (v is num) total += v;
        if (v is String) total += num.tryParse(v) ?? 0;
      }
      return total;
    }
    if (op == 'avg') {
      if (relatedRows.isEmpty) return 0;
      num sum = 0;
      for (final rr in relatedRows) {
        final v = rr.values[targetId];
        if (v is num) sum += v;
        if (v is String) sum += num.tryParse(v) ?? 0;
      }
      return sum / relatedRows.length;
    }
    if (op == 'min' || op == 'max') {
      final nums = <num>[];
      for (final rr in relatedRows) {
        final v = rr.values[targetId];
        if (v is num) nums.add(v);
        if (v is String) {
          final p = num.tryParse(v);
          if (p != null) nums.add(p);
        }
      }
      if (nums.isEmpty) return null;
      nums.sort((a, b) => a.compareTo(b));
      return op == 'min' ? nums.first : nums.last;
    }
    return null;
  }
}

extension _FirstOrNullExt<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
