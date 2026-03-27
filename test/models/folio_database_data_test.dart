import 'package:flutter_test/flutter_test.dart';
import 'package:folio/models/folio_database_data.dart';
import 'package:folio/models/folio_table_data.dart';

void main() {
  group('FolioDatabaseData', () {
    test('migrates from legacy table and drops fully empty rows', () {
      final t = FolioTableData(cols: 2, cells: ['A', '1', '', '']);
      final db = FolioDatabaseData.fromLegacyTable(t, rowIdPrefix: 'row');
      expect(db.properties.length, 2);
      expect(db.rows.length, 1);
      expect(db.rows.first.values['p_title'], 'A');
    });

    test('materializeRows applies contains filter and sort', () {
      final db = FolioDatabaseData.empty();
      final title = db.properties.first;
      db.rows = [
        FolioDbRow(id: 'r1', values: {title.id: 'Bravo'}),
        FolioDbRow(id: 'r2', values: {title.id: 'Alpha'}),
        FolioDbRow(id: 'r3', values: {title.id: 'Charlie'}),
      ];
      final v = db.views.first;
      v.filter = FolioDbFilterGroup(
        logical: FolioDbLogicalOperator.and,
        conditions: [
          FolioDbFilterCondition(
            propertyId: title.id,
            op: FolioDbFilterOperator.contains,
            value: 'a',
          ),
        ],
      );
      v.sorts = [FolioDbSortSpec(propertyId: title.id)];

      final out = db.materializeRows(v);
      expect(out.map((e) => e.values[title.id]), ['Alpha', 'Bravo', 'Charlie']);
    });

    test('formula concat and rollup count/sum resolve', () {
      final db = FolioDatabaseData.empty();
      final title = db.properties.first;
      final numProp = FolioDbProperty(
        id: 'p_num',
        name: 'Amount',
        type: FolioDbPropertyType.number,
      );
      final relProp = FolioDbProperty(
        id: 'p_rel',
        name: 'Rel',
        type: FolioDbPropertyType.relation,
      );
      final formulaProp = FolioDbProperty(
        id: 'p_formula',
        name: 'Formula',
        type: FolioDbPropertyType.formula,
      )..formulaExpression = 'concat(Nombre, " - ok")';
      final rollupCount =
          FolioDbProperty(
              id: 'p_roll_count',
              name: 'Roll Count',
              type: FolioDbPropertyType.rollup,
            )
            ..rollupRelationPropertyId = relProp.id
            ..rollupTargetPropertyId = numProp.id
            ..rollupOperation = 'count';
      final rollupSum =
          FolioDbProperty(
              id: 'p_roll_sum',
              name: 'Roll Sum',
              type: FolioDbPropertyType.rollup,
            )
            ..rollupRelationPropertyId = relProp.id
            ..rollupTargetPropertyId = numProp.id
            ..rollupOperation = 'sum';

      db.properties = [
        ...db.properties,
        numProp,
        relProp,
        formulaProp,
        rollupCount,
        rollupSum,
      ];
      db.rows = [
        FolioDbRow(id: 'r1', values: {title.id: 'Row 1', numProp.id: 10}),
        FolioDbRow(id: 'r2', values: {title.id: 'Row 2', numProp.id: 15}),
        FolioDbRow(
          id: 'r3',
          values: {
            title.id: 'Host',
            relProp.id: ['r1', 'r2'],
          },
        ),
      ];

      expect(db.resolvedValue(db.rows[0], formulaProp), 'Row 1 - ok');
      expect(db.resolvedValue(db.rows[2], rollupCount), 2);
      expect(db.resolvedValue(db.rows[2], rollupSum), 25);
    });

    test(
      'formula if/math/date helpers and rollup avg/min/max/percent_checked',
      () {
        final db = FolioDatabaseData.empty();
        final title = db.properties.first;
        final amount = FolioDbProperty(
          id: 'p_amount',
          name: 'Amount',
          type: FolioDbPropertyType.number,
        );
        final done = FolioDbProperty(
          id: 'p_done',
          name: 'Done',
          type: FolioDbPropertyType.checkbox,
        );
        final rel = FolioDbProperty(
          id: 'p_rel',
          name: 'Rel',
          type: FolioDbPropertyType.relation,
        );
        final formula = FolioDbProperty(
          id: 'p_formula',
          name: 'Formula',
          type: FolioDbPropertyType.formula,
        )..formulaExpression = 'if(contains(Nombre,"Row"), add(2,3), 0)';
        final avg =
            FolioDbProperty(
                id: 'p_avg',
                name: 'Avg',
                type: FolioDbPropertyType.rollup,
              )
              ..rollupRelationPropertyId = rel.id
              ..rollupTargetPropertyId = amount.id
              ..rollupOperation = 'avg';
        final min =
            FolioDbProperty(
                id: 'p_min',
                name: 'Min',
                type: FolioDbPropertyType.rollup,
              )
              ..rollupRelationPropertyId = rel.id
              ..rollupTargetPropertyId = amount.id
              ..rollupOperation = 'min';
        final max =
            FolioDbProperty(
                id: 'p_max',
                name: 'Max',
                type: FolioDbPropertyType.rollup,
              )
              ..rollupRelationPropertyId = rel.id
              ..rollupTargetPropertyId = amount.id
              ..rollupOperation = 'max';
        final percentChecked =
            FolioDbProperty(
                id: 'p_pct',
                name: 'PercentChecked',
                type: FolioDbPropertyType.rollup,
              )
              ..rollupRelationPropertyId = rel.id
              ..rollupTargetPropertyId = done.id
              ..rollupOperation = 'percent_checked';

        db.properties = [
          ...db.properties,
          amount,
          done,
          rel,
          formula,
          avg,
          min,
          max,
          percentChecked,
        ];
        db.rows = [
          FolioDbRow(
            id: 'r1',
            values: {title.id: 'Row 1', amount.id: 10, done.id: true},
          ),
          FolioDbRow(
            id: 'r2',
            values: {title.id: 'Row 2', amount.id: 20, done.id: false},
          ),
          FolioDbRow(
            id: 'r3',
            values: {
              title.id: 'Host',
              rel.id: ['r1', 'r2'],
            },
          ),
        ];

        expect(db.resolvedValue(db.rows[0], formula), 5);
        expect(db.resolvedValue(db.rows[2], avg), 15);
        expect(db.resolvedValue(db.rows[2], min), 10);
        expect(db.resolvedValue(db.rows[2], max), 20);
        expect(db.resolvedValue(db.rows[2], percentChecked), 50);
      },
    );

    test('materializeRows supports OR nested groups', () {
      final db = FolioDatabaseData.empty();
      final title = db.properties.first;
      db.rows = [
        FolioDbRow(id: 'r1', values: {title.id: 'Alpha'}),
        FolioDbRow(id: 'r2', values: {title.id: 'Beta'}),
        FolioDbRow(id: 'r3', values: {title.id: 'Gamma'}),
      ];
      final v = db.views.first;
      v.filter = FolioDbFilterGroup(
        logical: FolioDbLogicalOperator.or,
        conditions: [
          FolioDbFilterCondition(
            propertyId: title.id,
            op: FolioDbFilterOperator.contains,
            value: 'alp',
          ),
          FolioDbFilterCondition(
            propertyId: title.id,
            op: FolioDbFilterOperator.contains,
            value: 'gam',
          ),
        ],
      );
      final out = db.materializeRows(v);
      expect(out.map((e) => e.id).toList(), ['r1', 'r3']);
    });

    test('view visiblePropertyIds are encoded and parsed', () {
      final db = FolioDatabaseData.empty();
      final titleId = db.properties.first.id;
      final statusId = db.properties[1].id;
      final view = db.views.first;
      view.visiblePropertyIds = [titleId, statusId];

      final parsed = FolioDatabaseData.tryParse(db.encode());
      expect(parsed, isNotNull);
      expect(parsed!.views.first.visiblePropertyIds, [titleId, statusId]);
    });

    test('migrates pre-v5 payload to include visiblePropertyIds', () {
      const raw = '''
{
  "v": 4,
  "schemaVersion": 4,
  "properties": [
    {"id":"p_title","name":"Nombre","type":"text"},
    {"id":"p_status","name":"Estado","type":"select","options":["A","B"]}
  ],
  "rows": [],
  "views": [
    {"id":"v_table","name":"Tabla","type":"table"}
  ],
  "activeViewId": "v_table"
}
''';
      final parsed = FolioDatabaseData.tryParse(raw);
      expect(parsed, isNotNull);
      expect(parsed!.schemaVersion, 5);
      expect(
        parsed.views.first.visiblePropertyIds,
        containsAll(['p_title', 'p_status']),
      );
    });
  });
}
