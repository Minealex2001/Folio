import 'dart:convert';

/// Configuración JSON del bloque `kanban` ([FolioBlock.text]).
class FolioKanbanColumnSpec {
  const FolioKanbanColumnSpec({
    required this.id,
    this.title = '',
    this.colorArgb,
  });

  /// Identificador estable de la columna (configurable por usuario).
  final String id;

  /// Título opcional; vacío = usar textos localizados por defecto.
  final String title;

  /// Color opcional en ARGB (int). Si es null, la UI usa un fallback.
  final int? colorArgb;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        if (colorArgb != null) 'colorArgb': colorArgb,
      };

  static FolioKanbanColumnSpec? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final id = (raw['id'] as String? ?? '').trim();
    if (id.isEmpty) return null;
    return FolioKanbanColumnSpec(
      id: id,
      title: (raw['title'] as String?) ?? '',
      colorArgb: raw['colorArgb'] is num ? (raw['colorArgb'] as num).toInt() : null,
    );
  }
}

enum FolioKanbanViewMode { kanban, list, grid, timeline }

class FolioKanbanData {
  FolioKanbanData({
    this.v = 2,
    this.includeSimpleTodos = true,
    this.viewMode = FolioKanbanViewMode.kanban,
    List<FolioKanbanColumnSpec>? columns,
  }) : columns = List.unmodifiable(columns ?? defaultColumns);

  static List<FolioKanbanColumnSpec> get defaultColumns => const [
        FolioKanbanColumnSpec(id: 'todo', colorArgb: 0xFF90A4AE),
        FolioKanbanColumnSpec(id: 'in_progress', colorArgb: 0xFF42A5F5),
        FolioKanbanColumnSpec(id: 'done', colorArgb: 0xFF66BB6A),
      ];

  final int v;
  final bool includeSimpleTodos;
  final FolioKanbanViewMode viewMode;
  final List<FolioKanbanColumnSpec> columns;

  static FolioKanbanData defaults() => FolioKanbanData();

  FolioKanbanData copyWith({
    int? v,
    bool? includeSimpleTodos,
    FolioKanbanViewMode? viewMode,
    List<FolioKanbanColumnSpec>? columns,
  }) {
    return FolioKanbanData(
      v: v ?? this.v,
      includeSimpleTodos: includeSimpleTodos ?? this.includeSimpleTodos,
      viewMode: viewMode ?? this.viewMode,
      columns: columns ?? this.columns,
    );
  }

  String encode() => jsonEncode({
        'v': v,
        'includeSimpleTodos': includeSimpleTodos,
        'viewMode': viewMode.name,
        'columns': columns.map((c) => c.toJson()).toList(),
      });

  static FolioKanbanData? tryParse(String raw) {
    if (raw.trim().isEmpty) return FolioKanbanData.defaults();
    try {
      final m = jsonDecode(raw);
      if (m is! Map) return null;
      final rawCols = m['columns'];
      final cols = <FolioKanbanColumnSpec>[];
      if (rawCols is List) {
        for (final c in rawCols) {
          final spec = FolioKanbanColumnSpec.tryParse(c);
          if (spec != null) cols.add(spec);
        }
      }
      final ids = cols.map((c) => c.id).toList();
      final uniqueIds = ids.toSet();
      final useDefaults = cols.isEmpty || uniqueIds.length != ids.length;

      final rawMode = (m['viewMode'] as String?)?.trim().toLowerCase();
      final mode = FolioKanbanViewMode.values.firstWhere(
        (e) => e.name == rawMode,
        orElse: () => FolioKanbanViewMode.kanban,
      );
      return FolioKanbanData(
        v: (m['v'] as num?)?.toInt() ?? 2,
        includeSimpleTodos: m['includeSimpleTodos'] as bool? ?? true,
        viewMode: mode,
        columns: useDefaults ? defaultColumns : cols,
      );
    } catch (_) {
      return null;
    }
  }
}
